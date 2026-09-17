"""Kiosk and Home localization preserve PINs, gesture values and Android commands."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k: v for p in (APP / 'l10n/source').glob('*_en.arb')
           for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated = {k: 'TEST ' + v for k, v in english.items()}

mapping = json.loads((APP / 'l10n/settings.json').read_text())
hints = json.loads((APP / 'l10n/setting_placeholders.json').read_text())
settings = [dict(key='ui.language', value='es', type='string', category='Device', hidden=True)]
options = json.loads((APP / 'l10n/setting_options.json').read_text())
for key in ['kiosk.enabled','kiosk.exit_gesture','kiosk.pin','kiosk.allow_drawer','kiosk.allow_apps','home.enabled','home.keep_pinning']:
    category = 'Home' if key.startswith('home.') else 'Kiosk'
    subpage = 'Allowed Actions' if key.startswith('kiosk.allow_') else None
    value = 'taps7' if key.endswith('exit_gesture') else '' if key.endswith('.pin') else True
    settings.append(dict(key=key, value=value, type='select' if key in options else 'password' if key.endswith('.pin') else 'boolean',
        category=category, section=subpage, subpage=subpage, secret=key.endswith('.pin'),
        title=english[mapping[key]['title']], description=english[mapping[key]['description']],
        titleMessageId=mapping[key]['title'], descriptionMessageId=mapping[key]['description'],
        options=list(options.get(key,{})), optionLabels={v:english[k] for v,k in options.get(key,{}).items()},
        optionMessageIds=options.get(key,{})))
status = {'supported':True,'enabled':True,'held':False}
permissions = {'overlay':False,'guard':False}
commands = []
requests = []


def api(route):
    path = route.request.url.split('/api/', 1)[1]
    if path == 'settings':
        if route.request.method == 'PATCH':
            values = route.request.post_data_json
            requests.append(values)
            for item in settings:
                if item['key'] in values:
                    item['value'] = values[item['key']]
            return route.fulfill(json={'ok':True})
        return route.fulfill(json={'settings':settings, 'subpageHints':{}})
    name = path.removeprefix('commands/')
    params = (route.request.post_data_json or {}) if route.request.method == 'POST' else {}
    commands.append((name,params))
    if name == 'requestOsPermissions': permissions['overlay'] = True
    if name == 'openUiGuardSettings': permissions['guard'] = True
    if name == 'acquireHomeRole': status['held'] = True
    data = {'homeLauncherStatus':status, 'hasOverlayPermission':permissions['overlay'],
            'hasUiGuard':permissions['guard'], 'listPlugins':[], 'listFiles':[],
            'mediaPlayers':{'players':[]}, 'getAudioDevices':{'inputs':[], 'outputs':[]}}.get(name,{})
    route.fulfill(json={'ok':True, 'data':data})


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass


server = ThreadingHTTPServer(('127.0.0.1',0), partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True,args=['--no-sandbox'])
        page = browser.new_page(viewport={'width':1200,'height':1500})
        errors = []
        page.on('pageerror',lambda e: errors.append(str(e)))
        html = (ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda route:route.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda route:route.fulfill(
            body='export const catalogs = '+json.dumps({'en':english,'es':translated})+';',content_type='text/javascript'))
        page.route('**/api/**',api)
        page.goto(base+'/')
        page.evaluate("""async()=>{
          (await import('/static/core.js')).showView('app');
          await (await import('/static/settings.js')).loadSettings();
          (await import('/static/tabs.js')).showTab('kiosk',{refresh:false});
        }""")

        root = page.locator('#tab-kiosk')
        gesture = root.locator('[data-key="kiosk.exit_gesture"] select')
        expect(gesture.locator('option[value="taps5hold"]')).to_have_text(translated[options['kiosk.exit_gesture']['taps5hold']])
        with page.expect_response('**/api/settings'):
            gesture.select_option('taps5hold')
        assert requests[-1] == {'kiosk.exit_gesture':'taps5hold'}
        pin = root.locator('[data-key="kiosk.pin"] input')
        expect(pin).to_have_attribute('type','password')
        with page.expect_response('**/api/settings'):
            pin.fill('0078')
            pin.press('Tab')
        assert requests[-1] == {'kiosk.pin':'0078'}
        root.get_by_role('button',name=translated['kioskGrantDevice'],exact=True).click()
        expect(root.get_by_text(translated['kioskForeground'],exact=True)).to_be_visible()
        assert ('requestOsPermissions',{'which':['overlay']}) in commands
        root.get_by_role('button',name=translated['kioskOpenSettingsDevice'],exact=True).click()
        expect(root.get_by_text(translated['kioskGuardHeld'],exact=True)).to_be_visible()
        assert ('openUiGuardSettings',{}) in commands
        page.evaluate("()=> (import('/static/tabs.js')).then(m=>m.showTab('kiosk/allowed-actions',{refresh:false}))")
        allowed = root.locator('[data-key="kiosk.allow_apps"]')
        expect(allowed.locator('.name')).to_have_text(translated[mapping['kiosk.allow_apps']['title']])
        with page.expect_response('**/api/settings'):
            allowed.locator('label').click()
        assert requests[-1] == {'kiosk.allow_apps':False}
        page.evaluate("()=> (import('/static/tabs.js')).then(m=>m.showTab('home',{refresh:false}))")
        home = page.locator('#tab-home')
        expect(home.get_by_text(translated['kioskWaitingRemote'],exact=True)).to_be_visible()
        assert not any(name == 'acquireHomeRole' for name,_ in commands)
        home.get_by_role('button',name=translated['kioskSetDevice'],exact=True).click()
        expect(home.get_by_text(translated['kioskHeld'],exact=True)).to_be_visible()
        assert ('acquireHomeRole',{}) in commands
        for language in ['en','es']:
            settings[0]['value'] = language
            page.evaluate("async()=>await (await import('/static/settings.js')).loadSettings()")
            catalog = english if language == 'en' else translated
            expect(home.get_by_text(catalog['kioskHeld'],exact=True)).to_be_visible()
            page.evaluate("async()=> (await import('/static/live.js')).receiveUpdate('home-role')")
            expect(home.get_by_text(catalog['kioskHeld'],exact=True)).to_be_visible()
            expect(gesture).to_have_value('taps5hold')
            assert next(s for s in settings if s['key']=='kiosk.pin')['value'] == '0078'
        assert sum(name == 'acquireHomeRole' for name,_ in commands) == 1
        status.update(held=False,enabled=False,storedFuseReason='<b>original reason')
        page.evaluate("async()=> (await import('/static/live.js')).receiveUpdate('home-role')")
        expect(home.get_by_text(translated['kioskRecovered'],exact=True)).to_be_visible()
        status.update(supported=False,reason='fireos')
        page.evaluate("async()=> (await import('/static/live.js')).receiveUpdate('home-role')")
        expect(home.get_by_text(translated['kioskFireOs'],exact=True)).to_be_visible()
        expect(home.get_by_role('button',name=translated['kioskSetDevice'],exact=True)).to_have_count(0)
        assert home.locator('b').count() == 0
        assert not errors, errors
        browser.close()
finally:
    server.shutdown()
print('Kiosk and Home localization browser checks passed')
