"""Exercise rejected quick controls and configuration imports with real UI modules."""
import json
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from playwright.sync_api import sync_playwright, expect

app = Path(__file__).resolve().parents[1]
root = app / 'remote-ui'
en = {k: v for p in (app / 'l10n/source').glob('*.arb') for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
es = {k: v for p in (app.parents[1] / 'kiosk-satellite-localization/translations/es').glob('*.arb') for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
calls = []
imports = []
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(root)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
html = (root / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page()
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.route(base + '/', lambda r: r.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda r: r.fulfill(body='export const catalogs = ' + json.dumps({'en': en, 'es': es}) + ';', content_type='text/javascript'))
        def api(route):
            path = route.request.url.split('/api/')[1].split('?')[0]
            calls.append(path)
            if path == 'commands/screenOff':
                return route.fulfill(json={'ok': False, 'error': en['deviceScreenOffPermission']})
            if path == 'commands/rebootDevice':
                return route.fulfill(json={'ok': False, 'error': en['deviceRebootPermission']})
            if path == 'settings':
                return route.fulfill(json={'settings': [{'key': 'ui.language', 'value': 'es', 'category': 'Device', 'type': 'string', 'title': 'Language', 'description': ''}], 'subpageHints': {}})
            if path == 'config/import':
                value = route.request.post_data_json
                imports.append((route.request.url, value))
                error = 'config must be an object' if not isinstance(value, dict) else 'not a Kiosk Satellite configuration file' if value.get('kind') != 'kiosk-satellite-config' else 'no settings in file'
                return route.fulfill(status=400, json={'ok': False, 'error': error})
            route.fulfill(json={'ok': True, 'data': {}})
        page.route('**/api/**', api)
        page.goto(base + '/')
        page.evaluate("async()=>{const c=await import('/static/core.js');c.showView('app');c.cacheSettings([{key:'ui.language',value:'es'}]);await import('/static/widgets.js');}")
        page.locator('#tileScreen').click()
        expect(page.locator('.modal-body')).to_contain_text(es['deviceScreenOffPermission'])
        page.evaluate("async()=>{(await import('/static/core.js')).cacheSettings([{key:'ui.language',value:'en'}]);}")
        expect(page.locator('.modal-body')).to_contain_text(en['deviceScreenOffPermission'])
        assert calls.count('commands/screenOff') == 1
        page.evaluate("async()=>{(await import('/static/core.js')).cacheSettings([{key:'ui.language',value:'es'}]);}")
        expect(page.locator('.modal-body')).to_contain_text(es['deviceScreenOffPermission'])
        page.locator('.modal-foot button').last.click()
        expect(page.locator('.modal-body')).to_contain_text(es['deviceScreenOffPermission'])
        assert calls.count('commands/screenOff') == 2
        page.locator('.modal-foot button').first.click()
        expect(page.locator('.modal-body')).to_have_count(0)
        assert calls.count('commands/screenOff') == 2
        page.evaluate("async()=>{await import('/static/overview.js');}")
        page.locator('#tileRestartDevice').evaluate('(b)=>{b.style.display="";b.click()}')
        page.locator('.modal-foot button').last.click()
        expect(page.locator('body')).to_contain_text(es['deviceRebootPermission'])
        assert calls.count('commands/rebootDevice') == 1
        page.evaluate("async()=>{await(await import('/static/settings.js')).loadSettings();(await import('/static/core.js')).cacheSettings([{key:'ui.language',value:'es'}]);(await import('/static/tabs.js')).showTab('device',{refresh:false});}")
        picker = page.locator('input[type=file][accept=".json,application/json"]')
        for value, key in [(None, 'setupBackupObject'), ({}, 'setupBackupKind'), ({'kind': 'kiosk-satellite-config'}, 'setupBackupSettings'), ({'kind': 'kiosk-satellite-config', 'settings': []}, 'setupBackupSettings')]:
            picker.set_input_files({'name': 'invalid.json', 'mimeType': 'application/json', 'buffer': json.dumps(value).encode()})
            page.locator('.modal-foot button').last.click()
            expect(page.locator('#device-settings')).to_contain_text(es[key])
            assert imports[-1][1] == value
            assert imports[-1][0].endswith('adoptIdentity=0&importLocalStorage=0')
        count = len(imports)
        picker.set_input_files({'name': 'cancel.json', 'mimeType': 'application/json', 'buffer': b'{"settings":{"device.name":123}}'})
        page.locator('.modal-foot button').first.click()
        assert len(imports) == count
        assert not errors, errors
        print('Quick-control errors translate live. Retry, Cancel and import validation preserve command behavior.')
        browser.close()
finally:
    server.shutdown()
