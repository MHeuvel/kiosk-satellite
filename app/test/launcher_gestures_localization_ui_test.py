"""Localized app and gesture editors preserve package names and action data."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k:v for p in (APP/'l10n/source').glob('*_en.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated = {k:'TEST '+v for k,v in english.items()}
mapping = json.loads((APP/'l10n/settings.json').read_text())
options = json.loads((APP/'l10n/setting_options.json').read_text())
settings = [dict(key='ui.language',value='es',type='string',category='Device',hidden=True),
            dict(key='gestures.mappings',value='[]',type='string',category='Gestures',hidden=True)]
for key,value in [('launcher.enabled',True),('launcher.auto_return',True),('launcher.auto_return_seconds',300),('launcher.apps','[]'),('gestures.clap_strictness','standard'),('gestures.hand_hold_seconds',0)]:
    ids=mapping[key]
    settings.append(dict(key=key,value=value,type='select' if key in options else 'boolean' if type(value)==bool else 'number' if type(value)==int else 'string',
        category='Gestures' if key.startswith('gestures') else 'Launcher',title=english[ids['title']],description=english[ids['description']],
        titleMessageId=ids['title'],descriptionMessageId=ids['description'],options=list(options.get(key,{})),
        optionLabels={v:english[k] for v,k in options.get(key,{}).items()},optionMessageIds=options.get(key,{})))
next(s for s in settings if s['key']=='gestures.hand_hold_seconds').update(min=0,max=3,step=0.5,unit='s')
apps=[{'package':'com.example.raw','label':'<b>Original App</b>'}]
commands=[];writes=[]
settings_reads=[]
stale_reads=False
def api(route):
    path=route.request.url.split('/api/',1)[1]
    if path=='settings':
        if route.request.method=='PATCH':
            values=route.request.post_data_json;writes.append(values)
            for item in settings:
                if item['key'] in values:item['value']=values[item['key']]
            return route.fulfill(json={'ok':True})
        settings_reads.append(route.request.url)
        response=json.loads(json.dumps(settings))
        if stale_reads:
            response[0]['value']='en'
            response[1]['value']='[]'
        return route.fulfill(json={'settings':response,'subpageHints':{}})
    name=path.removeprefix('commands/');params=(route.request.post_data_json or {}) if route.request.method=='POST' else {}
    commands.append((name,params))
    data={'installedApps':apps,'hasOverlayPermission':True,'hasUiGuard':True,'hasBatteryUnrestricted':True,
          'haValidateAction':{'domain':True,'service':False,'entity':True},'listPlugins':[],'listFiles':[],
          'mediaPlayers':{'players':[]},'getAudioDevices':{'inputs':[],'outputs':[]}}.get(name,{})
    route.fulfill(json={'ok':True,'data':data})
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page(viewport={'width':1200,'height':1500})
        errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda route:route.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda route:route.fulfill(body='export const catalogs = '+json.dumps({'en':english,'es':translated})+';',content_type='text/javascript'))
        page.route('**/api/**',api);page.goto(base+'/')
        page.evaluate("""async()=>{
          (await import('/static/core.js')).showView('app');
          await (await import('/static/settings.js')).loadSettings();
          (await import('/static/tabs.js')).showTab('launcher',{refresh:false});
        }""")
        root=page.locator('#tab-launcher')
        expect(root.get_by_text(translated[mapping['launcher.enabled']['title']],exact=True)).to_be_visible()
        expect(root.get_by_text(translated['launcherOverlayHeld'],exact=True)).to_be_visible()
        root.locator('[data-key="launcher.apps"]').get_by_role('button',name=translated[json.loads((APP/'l10n/launcher_text.json').read_text())['Edit']]).click()
        expect(page.get_by_text(apps[0]['label'],exact=True)).to_be_visible()
        page.locator('.modal-back input[type="checkbox"]').check()
        page.locator('.modal-back').get_by_role('button',name=translated['commonSave'],exact=True).click()
        expect(root.get_by_text(apps[0]['label'],exact=True)).to_be_visible()
        assert json.loads(writes[-1]['launcher.apps'])==apps
        assert root.locator('b').count()==0
        stale_reads=True
        reads_before=len(settings_reads)
        page.evaluate("async()=>{(await import('/static/tabs.js')).showTab('gestures',{refresh:false});await (await import('/static/gestures.js')).loadGestures();}")
        gestures=page.locator('#tab-gestures')
        expect(gestures.get_by_text(translated['gestureEmpty'],exact=True)).to_be_visible()
        assert len(settings_reads)==reads_before, 'Page entry must not fetch a separate settings snapshot'
        stale_reads=False
        strictness=gestures.locator('[data-key="gestures.clap_strictness"] select')
        strictness.select_option('strict')
        page.wait_for_timeout(100)
        assert writes[-1]=={'gestures.clap_strictness':'strict'}
        hold=gestures.locator('[data-key="gestures.hand_hold_seconds"]')
        expect(gestures.get_by_text(translated['gestureHandGestures'],exact=True)).to_be_visible()
        expect(hold.get_by_text(translated['gestureHoldInstant'],exact=True)).to_be_visible()
        slider=hold.locator('input[type="range"]')
        expect(slider).to_have_attribute('min','0')
        expect(slider).to_have_attribute('max','3')
        expect(slider).to_have_attribute('step','0.5')
        slider.fill('1.5');slider.dispatch_event('change')
        page.wait_for_timeout(150)
        assert writes[-1]=={'gestures.hand_hold_seconds':1.5}
        expect(hold.get_by_text(translated['gestureHoldSeconds'].replace('{seconds}','1,5'),exact=True)).to_be_visible()
        # A localized hold editor preserves canonical type, corner and milliseconds.
        page.evaluate("async()=>{window.editor=(await import('/static/gestures.js')).editGesture({id:'raw-1',trigger:{type:'corner_hold',corner:'br',holdMs:1750},action:{type:'launch_app',package:'com.example.raw'}});}")
        dialog=page.locator('.modal-back').last
        expect(dialog.get_by_text(translated['gestureHoldDuration'].replace('{seconds}','1.75'),exact=True)).to_be_visible()
        expect(dialog.locator('select').first).to_have_value('corner_hold')
        expect(dialog.locator('select:visible')).to_have_count(2)
        expect(dialog.locator('input[type="range"]')).to_be_visible()
        dialog.get_by_role('button',name=translated['commonSave'],exact=True).click()
        page.wait_for_function('window.editor.then(v=>v===true)')
        saved=json.loads(writes[-1]['gestures.mappings'])[0]
        assert saved=={'id':'raw-1','trigger':{'type':'corner_hold','corner':'br','holdMs':1750},'action':{'type':'launch_app','package':'com.example.raw'}}
        # Validate and save HA service data with technical values intact.
        page.evaluate("async()=>{window.service=(await import('/static/gestures.js')).configureGestureHaService(null);}")
        dialog=page.locator('.modal-back').last
        inputs=dialog.locator('input')
        inputs.nth(0).fill('light');inputs.nth(1).fill('custom_on');inputs.nth(2).fill('light.KITCHEN')
        dialog.locator('textarea').fill('[]')
        dialog.get_by_role('button',name=translated['commonSave'],exact=True).click()
        expect(dialog.get_by_text(translated['gestureServiceJson'],exact=True)).to_be_visible()
        dialog.get_by_role('button',name=translated['mediaValidate'],exact=True).click()
        expect(dialog.get_by_text(translated['gestureServiceMissing'].replace('{value}','light.custom_on'),exact=True)).to_be_visible()
        assert ('haValidateAction',{'domain':'light','service':'custom_on','entity_id':'light.KITCHEN'}) in commands
        dialog.locator('textarea').fill('{"brightness_pct":60,"label":"Original"}')
        dialog.get_by_role('button',name=translated['commonSave'],exact=True).click()
        assert page.evaluate('()=>window.service')=={'type':'ha_service','domain':'light','service':'custom_on','entityId':'light.KITCHEN','data':{'brightness_pct':60,'label':'Original'}}
        for language in ['en','es']:
            settings[0]['value']=language
            page.evaluate("async snapshot => (await import('/static/settings.js')).applySettingsUpdate(snapshot)", {'settings':settings})
            page.wait_for_function("async language => (await import('/static/localization.js')).messageLanguage() === language",arg=language)
            catalog=english if language=='en' else translated
            expected=catalog['gestureOpenApp'].replace('{package}','com.example.raw')
            expect(gestures.get_by_text(expected,exact=True)).to_be_visible()
            stale_reads=True
            reads_before=len(settings_reads)
            page.evaluate("async()=>{const gestures=await import('/static/gestures.js');await gestures.loadGestures();await gestures.loadGestures();(await import('/static/live.js')).receiveUpdate('gestures');}")
            expect(gestures.get_by_text(expected,exact=True)).to_be_visible()
            assert json.loads(settings[1]['value'])[0]==saved
            assert len(settings_reads)==reads_before, 'Refresh must preserve the live settings snapshot'
            assert page.evaluate("async()=>JSON.parse((await import('/static/core.js')).state.settings.find(s=>s.key==='gestures.mappings').value)[0]")==saved
            stale_reads=False
        # Confirmation does not lowercase user-supplied names or package values.
        gestures.get_by_role('button',name=translated[json.loads((APP/'l10n/gesture_text.json').read_text())['Delete']],exact=True).click()
        dialog=page.locator('.modal-back').last
        expect(dialog.get_by_text('com.example.raw',exact=False)).to_be_visible()
        dialog.get_by_role('button',name=translated[json.loads((APP/'l10n/gesture_text.json').read_text())['Delete']],exact=True).click()
        expect(gestures.get_by_text(translated['gestureEmpty'],exact=True)).to_be_visible()
        assert json.loads(settings[1]['value'])==[]
        categories=page.evaluate("async()=> (await import('/static/gestures.js')).CATEGORY_TABS")
        assert ['tab-kiosk',['Kiosk']] in categories
        assert ['tab-screenaudio',['Screen & Audio']] in categories
        assert not errors,errors
        browser.close()
finally:server.shutdown()
print('App Launcher and Gestures browser localization passed.')
