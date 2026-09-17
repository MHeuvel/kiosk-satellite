"""Language changes preserve injected code and saved browser security choices."""
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
for key in ['browser.inject_js', 'browser.inject_js_external', 'browser.ignore_ssl_errors']:
    settings.append(dict(key=key, value=False if key.endswith('errors') else '',
        type='boolean' if key.endswith('errors') else 'string', category='Browser',
        title=english[mapping[key]['title']], description=english[mapping[key]['description']],
        titleMessageId=mapping[key]['title'], descriptionMessageId=mapping[key]['description'],
        multiline=key in hints, placeholder=english[hints[key]] if key in hints else None,
        placeholderMessageId=hints.get(key)))
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
    data = {'listPlugins':[], 'listFiles':[], 'mediaPlayers':{'players':[]},
            'getAudioDevices':{'inputs':[], 'outputs':[]}}.get(name,{})
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
          (await import('/static/tabs.js')).showTab('browser',{refresh:false});
        }""")

        root = page.locator('#tab-browser')
        code = "document.title = 'Panel de control <img src=x>';\nwindow.example = '{value}';"
        for key in ['browser.inject_js', 'browser.inject_js_external']:
            row = root.locator(f'[data-key="{key}"]')
            expect(row.locator('.name')).to_have_text(translated[mapping[key]['title']])
            editor = row.locator('textarea')
            expect(editor).to_have_attribute('placeholder', translated[hints[key]])
            with page.expect_response('**/api/settings'):
                editor.fill(code)
                editor.press('Tab')
            assert requests[-1] == {key:code}
        with page.expect_response('**/api/settings'):
            root.locator('[data-key="browser.ignore_ssl_errors"] label').click()
        assert requests[-1] == {'browser.ignore_ssl_errors':True}
        for language in ['en', 'es']:
            settings[0]['value'] = language
            page.evaluate("async()=>await (await import('/static/settings.js')).loadSettings()")
            for key in ['browser.inject_js', 'browser.inject_js_external']:
                row = root.locator(f'[data-key="{key}"]')
                expect(row.locator('.name')).to_have_text((english if language == 'en' else translated)[mapping[key]['title']])
                expect(row.locator('textarea')).to_have_value(code)
            expect(root.locator('[data-key="browser.ignore_ssl_errors"] input')).to_be_checked()
        assert root.locator('img[src="x"]').count() == 0
        assert not errors, errors
        browser.close()
finally:
    server.shutdown()
print('Web Browsing localization browser checks passed')
