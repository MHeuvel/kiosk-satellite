"""Voice Satellite remaining controls translate without changing names or HA writes."""
import copy
import json
import os
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect
APP=Path(__file__).resolve().parents[1];ROOT=APP/'remote-ui'
english={k:v for p in (APP/'l10n/source').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated={k:'TEST '+v for k,v in english.items()}
if os.environ.get('KS_TEST_SPANISH'):
    translated={k:v for p in (APP.parents[1]/'kiosk-satellite-localization/translations/es').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
ids=json.loads((APP/'l10n/voice_text.json').read_text());mapping=json.loads((APP/'l10n/settings.json').read_text())
settings=[dict(key='ui.language',value='es',type='string',category='Device',hidden=True),dict(key='ha.url',value='http://ha.example:8123',type='string',category='Home Assistant',title='Home Assistant URL',description=''),dict(key='wake_word.enabled',value=True,type='boolean',category='Voice Satellite',hidden=True),dict(key='wake_word.prefer_fp32',value=False,type='boolean',category='Voice Satellite',subpage='Wake Word',title='Prefer fp32 vsWakeWord models',description='')]
bg=mapping['wake_word.background'];settings.append(dict(key='wake_word.background',value=True,type='boolean',category='Voice Satellite',title=english[bg['title']],description=english[bg['description']],titleMessageId=bg['title'],descriptionMessageId=bg['description'],dependsOn='wake_word.enabled'))
data=dict(satellite='assist_satellite.original',satellites=[dict(entity_id='assist_satellite.original',name='Disabled'),dict(entity_id='assist_satellite.other',name='<b>Original satellite</b>')],version='9.8.7-raw',browser=dict(engine=dict(running=False,canStart=True),config=dict(auto_start=True,disable_muted_microphone_warning=False,debug=False),skins=[]),entities={})
for key,options in [('pipeline',['Default','<b>Original pipeline</b>']),('pipeline_2',['Second voice']),('vad_sensitivity',['default','relaxed','aggressive'])]:
    data['entities'][key]=dict(entity_id='select.raw_'+key,available=True,state=options[0],options=options)
data['entities']['mute']=dict(entity_id='switch.raw_mute',available=True,state='off')
for key,options in [('wake_word_detection',['On Device (vsWakeWord)','Home Assistant','Disabled']),('wake_word_model',['Very sensitive','<b>Original wake word</b>']),('wake_word_model_2',['Disabled','Stop']),('wake_word_sensitivity',['Slightly sensitive','Moderately sensitive','Very sensitive'])]:
    data['entities'][key]=dict(entity_id='select.raw_'+key,available=True,state=options[0],options=options)
for key in ['noise_gate','stop_word']:
    data['entities'][key]=dict(entity_id='switch.raw_'+key,available=True,state='off')
data['browser']['config'].update(skin='default',theme_mode='auto',reactive_bar=True,reactive_bar_update_interval_ms=33,text_scale=100)
data['browser']['skins']=[dict(value='default',label='Default'),dict(value='raw',label='<b>Original skin</b>')]
settings[3].update(title=english[mapping['wake_word.prefer_fp32']['title']],description=english[mapping['wake_word.prefer_fp32']['description']],titleMessageId=mapping['wake_word.prefer_fp32']['title'],descriptionMessageId=mapping['wake_word.prefer_fp32']['description'])
resume=mapping['wake_word.resume_timeout_seconds']
settings.append(dict(key='wake_word.resume_timeout_seconds',value=60,type='number',category='Voice Satellite',subpage='Wake Word',title=english[resume['title']],description=english[resume['description']],titleMessageId=resume['title'],descriptionMessageId=resume['description']))
perms=dict(required=True,background=True,microphone=False,microphoneBlocked=True,displayOverOtherApps=False,notification=False,batteryUnrestricted=False)
connected=True;installed=True;commands=[];writes=[];settings_reads=0

def api(route):
    global settings_reads
    path=route.request.url.split('/api/',1)[1]
    if path=='settings':
        if route.request.method=='GET':
            settings_reads+=1
            return route.fulfill(json=dict(settings=settings,subpageHints={}))
        values=route.request.post_data_json;writes.append(copy.deepcopy(values))
        for key,value in values.items():next(s for s in settings if s['key']==key)['value']=value
        return route.fulfill(json=dict(ok=True))
    name=path.removeprefix('commands/');params=route.request.post_data_json or {};commands.append((name,params))
    if name=='vsSetBrowserSettings':data['browser']['config'].update(params['settings'])
    if name=='vsEngine':data['browser']['engine']['running']=params['action']=='start'
    if name=='vsSetSatellite':data['satellite']=params['entity_id']
    if name=='haCallService':
        item=next(e for e in data['entities'].values() if e['entity_id']==params['entity_id'])
        item['state']=params['data']['option'] if params['domain']=='select' else 'on' if params['service']=='turn_on' else 'off'
    result={'clearWakeWordModels':dict(removed=4),'vsControls':data,'vsSetBrowserSettings':dict(config=(data['browser'] or {}).get('config',{})),'haStatus':dict(connected=connected),'haDetectVoiceSatellite':installed,'getSystemPermissions':perms,'getAudioDevices':dict(inputs=[],outputs=[]),'getBleSupport':dict(supported=True),'esphomeStatus':{},'bluetoothAdapterOn':dict(on=True),'hasDeviceCamera':False}.get(name,{})
    route.fulfill(json=dict(ok=True,data=result))
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)));Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page(viewport=dict(width=1200,height=1400));errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda r:r.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda r:r.fulfill(body='export const catalogs = '+json.dumps({'en':english,'es':translated})+';',content_type='text/javascript'))
        page.route('**/api/**',api);page.goto(base+'/')
        page.evaluate("async()=>{(await import('/static/core.js')).showView('app');await(await import('/static/settings.js')).loadSettings();(await import('/static/tabs.js')).showTab('voicesatellite',{refresh:false});}")
        root=page.locator('#tab-voicesatellite')
        def label(en):return translated[ids[en]]
        def row(en):return root.locator('.row').filter(has=page.get_by_text(label(en),exact=True))
        def language(value):
            settings[0]['value']=value
            page.evaluate("async s=>(await import('/static/settings.js')).applySettingsUpdate({settings:[s]})",copy.deepcopy(settings[0]))
            page.wait_for_function("async language=>(await import('/static/localization.js')).messageLanguage()===language",arg=value)
        def sub(value):page.evaluate("async sub=>(await import('/static/tabs.js')).showTab('voicesatellite/'+sub,{refresh:false})",value)
        def refresh():page.evaluate("async()=>await(await import('/static/vs.js')).renderVsControls(document.querySelector('#tab-voicesatellite'),{auto:true})")
        for query in [label('Wake word sensitivity'), 'Wake word sensitivity']:
            hits=page.evaluate("async query=>(await import('/static/search.js')).searchSettingsIndex(query)",query)
            hit=next(h for h in hits if h['tab']=='voicesatellite' and h.get('sub')=='Wake Word' and h['title']==label('Wake word sensitivity'))
            assert page.evaluate("async entry=>!!(await import('/static/search.js')).findSearchAnchor(entry.tab,entry)",hit)
        sub('Wake Word')
        expect(row('Wake word engine')).to_be_visible()
        expect(row('Wake word engine').locator('select option:checked')).to_have_text(translated['voiceOnDeviceEngine'].replace('{engine}','vsWakeWord'))
        expect(row('Wake word 1').locator('select option:checked')).to_have_text('Very sensitive')
        expect(row('Wake word 2').locator('select option:checked')).to_have_text(label('Disabled'))
        expect(row('Wake word sensitivity').locator('select option:checked')).to_have_text(label('Slightly sensitive'))
        with page.expect_response('**/api/commands/haCallService'):
            row('Wake word sensitivity').locator('select').select_option('Very sensitive')
        assert ('haCallService',dict(domain='select',service='select_option',entity_id='select.raw_wake_word_sensitivity',data=dict(option='Very sensitive'))) in commands
        for title,key in [('Wake word noise gate','noise_gate'),('Stop word interruption','stop_word')]:
            with page.expect_response('**/api/commands/haCallService'):row(title).locator('label.switch').click()
            assert ('haCallService',dict(domain='switch',service='turn_on',entity_id='switch.raw_'+key)) in commands
        with page.expect_response('**/api/commands/clearWakeWordModels'):
            row('Cached models').get_by_role('button',name=label('Clear cache'),exact=True).click()
        expect(row('Cached models')).to_contain_text(translated['voiceCacheCount'].replace('{count}','4'))
        with page.expect_response('**/api/settings'):
            root.locator('[data-key="wake_word.prefer_fp32"] label.switch').click()
        assert writes[-1]=={'wake_word.prefer_fp32':True}
        language('en');expect(root.get_by_text('Wake word engine',exact=True)).to_be_visible()
        language('es');expect(row('Wake word engine')).to_be_visible()
        page.locator('#pageTitle').click();refresh()
        expect(row('Wake word sensitivity').locator('select option:checked')).to_have_text(label('Very sensitive'))
        sub('Appearance')
        expect(row('Skin').locator('select option:checked')).to_have_text('Default')
        expect(row('Theme mode').locator('select option:checked')).to_have_text(label('Auto'))
        for title,value,key in [('Theme mode','dark','theme_mode'),('Skin','raw','skin')]:
            with page.expect_response('**/api/commands/vsSetBrowserSettings'):
                row(title).locator('select').select_option(value)
            assert ('vsSetBrowserSettings',dict(settings={key:value})) in commands
        with page.expect_response('**/api/commands/vsSetBrowserSettings'):
            row('Reactive activity bar').locator('label.switch').click()
        assert ('vsSetBrowserSettings',dict(settings={'reactive_bar':False})) in commands
        for title,value,key,sent in [('Reactive bar update rate',20,'reactive_bar_update_interval_ms',50),('Text scale',125,'text_scale',125)]:
            with page.expect_response('**/api/commands/vsSetBrowserSettings'):
                row(title).locator('input[type=range]').evaluate('(el,value)=>{el.value=value;el.dispatchEvent(new Event("input",{bubbles:true}));el.dispatchEvent(new Event("change",{bubbles:true}));}',value)
            assert ('vsSetBrowserSettings',dict(settings={key:sent})) in commands
        before=len([c for c in commands if c[0] in ['haCallService','vsSetBrowserSettings']]);before_writes=len(writes)
        language('en');expect(root.get_by_text('Theme mode',exact=True)).to_be_visible()
        language('es');expect(row('Theme mode')).to_be_visible()
        page.locator('#pageTitle').click();refresh()
        expect(row('Theme mode').locator('select option:checked')).to_have_text(label('Dark'))
        expect(row('Skin').locator('select option:checked')).to_have_text('<b>Original skin</b>')
        assert root.locator('b').count()==0
        assert len([c for c in commands if c[0] in ['haCallService','vsSetBrowserSettings']])==before
        assert len(writes)==before_writes
        page.set_viewport_size(dict(width=390,height=1000));assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        sub('Wake Word');page.locator('#pageTitle').click()
        data['entities']['wake_word_detection']['state']='Home Assistant';refresh()
        expect(row('Wake word engine')).to_be_visible();expect(row('Wake word 1')).to_have_count(0)
        data['entities']={};refresh();expect(root).to_contain_text(label('Assign a satellite to control these settings.'))
        data['browser']=None;data['browserState']='outdated';sub('Appearance');refresh()
        expect(root).to_contain_text(label('Update the Voice Satellite integration in Home Assistant to control these settings from the kiosk.'))
        assert settings_reads==1,settings_reads
        assert not errors,errors
        browser.close()
    print('Voice Satellite remaining localization browser checks passed')
finally:server.shutdown()
