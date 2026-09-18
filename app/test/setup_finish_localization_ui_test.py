"""Setup permissions and restores translate without changing authentication or payloads."""
import copy
import json
import os
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k:v for p in (APP/'l10n/source').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated = {k:'TEST '+v for k,v in english.items()}
if os.environ.get('KS_TEST_SPANISH'):
    translated = {k:v for p in (APP.parents[1]/'kiosk-satellite-localization/translations/es').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
ids = json.loads((APP/'l10n/setup_text.json').read_text())
perms = dict(batteryUnrestricted=False, batteryRequestable=True, displayOverOtherApps=False, overlayRequestable=False, notification=True, microphone=False, writeSettings=False, deviceAdmin=False)
grants = dict(batteryUnrestricted=True, displayOverOtherApps=True, notification=True)
requests = []
import_result = dict(ok=False, error='<b>Original import error</b>')
setup = dict(setupNeeded=True, importPending=False, language='es')
password_status = 200

def api(route):
    path = route.request.url.split('/api/',1)[1]
    params = route.request.post_data_json or {}
    requests.append((path,copy.deepcopy(params)))
    if path=='setup/status':return route.fulfill(json=setup)
    if path=='setup/grants':return route.fulfill(json=dict(permissions=perms,grants=grants))
    if path=='setup/password':return route.fulfill(status=password_status,json=dict(token='fixture-token',error='<b>Original password error</b>'))
    if path.startswith('config/import?'):return route.fulfill(status=200 if import_result['ok'] else 400,json=import_result)
    if path=='setup/grant':
        assert params==dict(which=['batteryOptimizations'])
        perms['batteryUnrestricted']=True
        return route.fulfill(json=dict(ok=True))
    name=path.removeprefix('commands/')
    if name=='requestOsPermissions':
        for k in ['microphone','batteryUnrestricted','notification','displayOverOtherApps','writeSettings','deviceAdmin']:perms[k]=True
    result={'getSystemPermissions':perms,'getServiceStatus':dict(grants=grants)}.get(name,{})
    route.fulfill(json=dict(ok=True,data=result))

class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page(viewport=dict(width=1200,height=1200));errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda r:r.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda r:r.fulfill(body='export const catalogs = '+json.dumps({'en':english,'es':translated})+';',content_type='text/javascript'))
        page.route('**/api/**',api);page.goto(base+'/')
        def label(en):return translated[ids[en]]
        def render(index, password=True):
            page.evaluate("async args=>{const c=await import('/static/core.js');c.showView('wizard');(await import('/static/localization.js')).setLanguagePreference('es');const {wizard:w}=await import('/static/app.js');w.i=args.index;w.needPassword=args.password;w.vsDetected=true;const m=await import('/static/wizard.js');w.steps=m.wizardSteps();m.wizardRender();}",dict(index=index,password=password))
        render(0)
        def narrow():
            page.set_viewport_size(dict(width=390,height=1000))
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
            page.set_viewport_size(dict(width=1200,height=1200))
        narrow()
        root=page.locator('#wizardBody')
        def row(en):return root.locator('.row').filter(has=page.get_by_text(label(en),exact=True))
        battery=row('Unrestricted battery')
        expect(battery).to_contain_text(label('Missing'))
        expect(row('Display over other apps')).to_contain_text(label('Not offered'))
        expect(row('Display over other apps')).to_contain_text('adb shell appops set me.jxl.kiosk_satellite SYSTEM_ALERT_WINDOW allow')
        expect(row('Display over other apps').get_by_role('button')).to_have_count(0)
        assert not any(path.startswith('commands/') for path,_ in requests),requests
        with page.expect_response('**/api/setup/grant'):
            battery.get_by_role('button',name=label('Grant on device'),exact=True).click()
        expect(battery).to_contain_text(label('Granted'))
        expect(battery).to_contain_text(label('Allows the process to run in the background without being paused or killed.'))
        # A later poll paints translated status again without resetting typed fields.
        page.locator('#wzPassword').fill('fixture-password')
        page.wait_for_timeout(5100)
        expect(battery).to_contain_text(label('Granted'))
        expect(page.locator('#wzPassword')).to_have_value('fixture-password')
        page.locator('#wizardThemeBtn').click()
        expect(page.locator('#wizardThemeBtn')).to_have_attribute('title',translated['settingsMenuThemeState'].replace('{theme}',translated['drawerThemeDark']))
        render(4,False)
        expect(root).to_contain_text(translated['setupNotificationListening'])
        expect(root).to_contain_text(translated['setupOverlayBoot'])
        narrow()
        with page.expect_response('**/api/commands/requestOsPermissions'):
            root.get_by_role('button',name=translated['setupGrantPermissions'],exact=True).click()
        expected=['microphone','batteryOptimizations','notifications','overlay','writeSettings','deviceAdmin']
        assert ('commands/requestOsPermissions',dict(which=expected)) in requests
        expect(root.get_by_role('button',name=translated['setupPermissionsRequested'],exact=True)).to_be_disabled()
        expect(root.get_by_text(label('Granted'),exact=True)).to_have_count(6)
        page.evaluate("async()=>{const {wizard:w}=await import('/static/app.js');w.rec['wake_word.background']=false;w.rec['kiosk.start_on_boot']=false;(await import('/static/wizard.js')).wizardRender();}")
        expect(root).to_contain_text(translated['deviceNotificationsHeld'])
        expect(root).to_contain_text(translated['setupOverlayCrash'])
        render(0)
        file=root.locator('input[type=file]')
        def upload(value):file.set_input_files(dict(name='backup.json',mimeType='application/json',buffer=value.encode()))
        upload('{broken')
        expect(page.locator('#wizardError')).to_contain_text(translated['setupNotBackup'])
        expect(page.locator('#wizardError')).to_contain_text(label('That file is not valid JSON.'))
        upload('{}')
        expect(page.locator('#wizardError')).to_contain_text(translated['setupWrongBackupKind'])
        backup=dict(kind='kiosk-satellite-config',settings={'device.name':'<b>Original kiosk</b>','remote.password':'backup-password','remote.enabled':False,'browser.start_url':'http://ha.example/raw/view'})
        modal=page.locator('.modal-back')
        before=len(requests)
        upload(json.dumps(backup))
        expect(modal).to_contain_text('<b>Original kiosk</b>')
        assert modal.locator('b').count()==0
        modal.get_by_role('button',name=translated['commonCancel'],exact=True).click()
        assert not any(path.startswith('config/import') for path,_ in requests[before:])
        upload(json.dumps(backup))
        modal.get_by_role('button',name=translated['commonImport'],exact=True).click()
        expect(page.locator('#wizardError')).to_contain_text(translated['setupPasswordFirst'])
        page.locator('#wzPassword').fill('fixture-password')
        upload(json.dumps(backup))
        modal.locator('input[type=radio]').nth(1).check()
        expect(modal.locator('#impLocal')).to_be_checked()
        modal.locator('#impLocal').uncheck()
        with page.expect_response('**/api/config/import?adoptIdentity=1&importLocalStorage=0'):
            modal.get_by_role('button',name=translated['commonImport'],exact=True).click()
        imports=[(path,value) for path,value in requests if path.startswith('config/import')]
        path,sent=imports[-1]
        assert sent['settings']=={'device.name':'<b>Original kiosk</b>','browser.start_url':'http://ha.example/raw/view'}
        assert ('setup/password',dict(password='fixture-password')) in requests
        expect(page.locator('#wizardError')).to_contain_text(translated['deviceImportFailed'])
        expect(page.locator('#wizardError .hint')).to_have_text('<b>Original import error</b>')
        assert page.locator('#wizardError .hint b').count()==0
        password_status=500
        before=len(requests)
        upload(json.dumps(backup))
        modal.get_by_role('button',name=translated['commonImport'],exact=True).click()
        expect(page.locator('#wizardError')).to_contain_text(translated['setupPasswordFailed'])
        expect(page.locator('#wizardError .hint')).to_have_text('<b>Original password error</b>')
        assert not any(path.startswith('config/import') for path,_ in requests[before:])
        password_status=200
        import_result=dict(ok=False,error='no settings in file')
        upload(json.dumps(backup))
        modal.get_by_role('button',name=translated['commonImport'],exact=True).click()
        expect(page.locator('#wizardError .hint')).to_have_text(translated['setupBackupSettings'])
        narrow()
        import_result=dict(ok=True,data=dict(pendingSetup=True))
        upload(json.dumps(backup))
        modal.get_by_role('button',name=translated['commonImport'],exact=True).click()
        expect(page.locator('#importPending h2')).to_have_text(translated['setupFinishOnDevice'])
        # Both cold boot and authenticated re-entry use setup's language.
        setup.update(importPending=True)
        page.reload()
        page.evaluate("async()=>{(await import('/static/localization.js')).setLanguagePreference('en');await import('/static/main.js');}")
        expect(page.locator('#importPending h2')).to_have_text(translated['setupFinishOnDevice'])
        page.reload()
        page.evaluate("async()=>{(await import('/static/localization.js')).setLanguagePreference('en');await(await import('/static/app.js')).start();}")
        expect(page.locator('#importPending h2')).to_have_text(translated['setupFinishOnDevice'])
        setup['language']='en'
        expect(page.locator('#importPending h2')).to_have_text(english['setupFinishOnDevice'])
        setup['language']='es'
        expect(page.locator('#importPending h2')).to_have_text(translated['setupFinishOnDevice'])
        page.set_viewport_size(dict(width=390,height=1000))
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        for raw in ['constructor','Granted','<b>Technical detail</b>']:
            assert page.evaluate("async raw=>(await import('/static/localization.js')).setupImportError(raw)",raw)==raw
        # A password created on the tablet sends the browser back to login.
        password_status=403
        page.evaluate("document.getElementById('importPending').remove()")
        render(0)
        page.locator('#wzPassword').fill('fixture-password')
        failure=page.evaluate("async()=>{try{await(await import('/static/wizard.js')).wizardSteps()[0].next()}catch(e){return {title:e.message,hint:e.hint}}}")
        assert translated['setupPasswordExists'] in str(failure),failure
        assert translated['setupPasswordExistsHelp'] in str(failure),failure
        assert not errors,errors
        browser.close()
    print('Setup permissions and restore browser checks passed')
finally:server.shutdown()
