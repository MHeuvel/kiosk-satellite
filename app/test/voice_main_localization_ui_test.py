"""Voice Satellite main controls translate without changing names or HA writes."""
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
    result={'vsControls':data,'vsSetBrowserSettings':dict(config=data['browser']['config']),'haStatus':dict(connected=connected),'haDetectVoiceSatellite':installed,'getSystemPermissions':perms,'getAudioDevices':dict(inputs=[],outputs=[]),'getBleSupport':dict(supported=True),'esphomeStatus':{},'bluetoothAdapterOn':dict(on=True),'hasDeviceCamera':False}.get(name,{})
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
        root=page.locator('#tab-voicesatellite');general=root.locator('#vsGeneralCard')
        def label(en):return translated[ids[en]]
        def exact_row(en):return general.locator('.row').filter(has=page.get_by_text(label(en),exact=True))
        def language(value):
            settings[0]['value']=value
            page.evaluate("async s=>(await import('/static/settings.js')).applySettingsUpdate({settings:[s]})",copy.deepcopy(settings[0]))
            page.wait_for_function("async language=>(await import('/static/localization.js')).messageLanguage()===language",arg=value)
        def refresh():page.evaluate("async()=>await(await import('/static/vs.js')).renderVsControls(document.querySelector('#tab-voicesatellite'),{auto:true})")
        expect(exact_row('Engine')).to_contain_text(label('Stopped'))
        expect(exact_row('Assigned satellite').locator('select option:checked')).to_have_text('Disabled')
        expect(exact_row('Assist pipeline 1').locator('select option:checked')).to_have_text('Default')
        expect(exact_row('Finished speaking detection').locator('select option:checked')).to_have_text(label('Default'))
        expect(root.locator('#permsCard')).to_contain_text(label('Blocked. Android will not ask again, so allow it in the app settings.'))
        expect(root.locator('#permsCard')).to_contain_text(label('Grant these on the device itself: swipe in from the left edge → Settings → Voice Satellite → Required system permissions.'))
        for title,option,entity in [('Assist pipeline 1','<b>Original pipeline</b>','select.raw_pipeline'),('Finished speaking detection','relaxed','select.raw_vad_sensitivity')]:
            with page.expect_response('**/api/commands/haCallService'):
                exact_row(title).locator('select').select_option(option)
            assert ('haCallService',dict(domain='select',service='select_option',entity_id=entity,data=dict(option=option))) in commands
        with page.expect_response('**/api/commands/haCallService'):
            exact_row('Mute').locator('label.switch').click()
        assert ('haCallService',dict(domain='switch',service='turn_on',entity_id='switch.raw_mute')) in commands
        for title,key in [('Auto start','auto_start'),('Disable muted microphone warning','disable_muted_microphone_warning'),('Debug logging','debug')]:
            with page.expect_response('**/api/commands/vsSetBrowserSettings'):
                exact_row(title).locator('label.switch').click()
            assert ('vsSetBrowserSettings',dict(settings={key:key!='auto_start'})) in commands
        with page.expect_response('**/api/commands/vsEngine'):
            exact_row('Engine').get_by_role('button',name=label('Start'),exact=True).click()
        expect(exact_row('Engine')).to_contain_text(label('Running'))
        before=len([c for c in commands if c[0] in ['haCallService','vsEngine','vsSetBrowserSettings','vsSetSatellite']]);before_writes=len(writes)
        language('en');expect(general.get_by_text('Assigned satellite',exact=True)).to_be_visible()
        language('es');expect(exact_row('Assigned satellite')).to_be_visible()
        refresh();expect(exact_row('Engine')).to_contain_text(label('Running'))
        expect(exact_row('Assist pipeline 1').locator('select option:checked')).to_have_text('<b>Original pipeline</b>');assert general.locator('b').count()==0
        assert len([c for c in commands if c[0] in ['haCallService','vsEngine','vsSetBrowserSettings','vsSetSatellite']])==before
        assert len(writes)==before_writes
        expect(general.locator('[data-key="wake_word.background"]')).to_have_count(1)
        with page.expect_response('**/api/settings'):
            general.locator('[data-key="wake_word.background"] label.switch').click()
        assert writes[-1]=={'wake_word.background':False}
        with page.expect_response('**/api/commands/vsSetSatellite'):
            exact_row('Assigned satellite').locator('select').select_option('assist_satellite.other')
        assert ('vsSetSatellite',dict(entity_id='assist_satellite.other')) in commands
        page.locator('#pageTitle').click();refresh();expect(exact_row('Assigned satellite').locator('select option:checked')).to_have_text('<b>Original satellite</b>')
        data['entities']['pipeline_2']['available']=False
        refresh();expect(exact_row('Assist pipeline 2')).to_contain_text(label('Not available'))
        page.set_viewport_size(dict(width=390,height=1000));assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        connected=False;language('en');expect(root).to_contain_text('Home Assistant not connected');language('es');expect(root).to_contain_text(label('Home Assistant not connected'))
        connected=True;installed=False;language('en');expect(root).to_contain_text('Voice Satellite is not installed');language('es');expect(root).to_contain_text(label('Voice Satellite is not installed in Home Assistant'))
        expect(root.get_by_role('link',name=label('Voice Satellite on Github'))).to_have_attribute('href','https://github.com/jxlarrea/voice-satellite-card-integration')
        expect(root.locator('a[href="http://ha.example:8123/hacs/repository/1159616380"]')).to_have_count(1)
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        assert settings_reads==1,settings_reads
        assert not errors,errors
        browser.close()
    print('Voice Satellite main localization browser checks passed')
finally:server.shutdown()
