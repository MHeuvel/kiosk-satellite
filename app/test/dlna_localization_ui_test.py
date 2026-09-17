"""DLNA settings preserve saved values and translate rejected port messages."""
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
for key in ['dlna.enabled', 'dlna.audio_background', 'dlna.port']:
    settings.append(dict(key=key, value='' if key == 'dlna.port' else True,
        type='string' if key == 'dlna.port' else 'boolean', category='DLNA',
        title=english[mapping[key]['title']], description=english[mapping[key]['description']],
        titleMessageId=mapping[key]['title'], descriptionMessageId=mapping[key]['description'],
        placeholder=english[hints[key]] if key in hints else None,
        placeholderMessageId=hints.get(key)))
requests = []


def api(route):
    path = route.request.url.split('/api/', 1)[1]
    if path == 'settings':
        if route.request.method == 'PATCH':
            values = route.request.post_data_json
            requests.append(values)
            port = values.get('dlna.port')
            if port and (not port.isdigit() or not 1024 <= int(port) <= 65535):
                return route.fulfill(status=400, json={'rejected':['dlna.port'],
                    'errors':{'dlna.port':english['dlnaPortInvalid']}})
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
          (await import('/static/tabs.js')).showTab('dlna',{refresh:false});
        }""")

        root = page.locator('#tab-dlna')
        port_row = root.locator('[data-key="dlna.port"]')
        port = port_row.locator('input')
        expect(port).to_have_attribute('placeholder', translated[hints['dlna.port']])
        with page.expect_response('**/api/settings'):
            port.fill('80')
            port.press('Tab')
        expect(port_row.locator('.row-error')).to_contain_text(translated['dlnaPortInvalid'])
        assert settings[-1]['value'] == ''
        with page.expect_response('**/api/settings'):
            port.fill('2456')
            port.press('Tab')
        assert requests[-1] == {'dlna.port':'2456'}
        expect(port_row.locator('.row-error')).to_have_count(0)
        with page.expect_response('**/api/settings'):
            root.locator('[data-key="dlna.audio_background"] label').click()
        assert requests[-1] == {'dlna.audio_background':False}
        for language in ['en', 'es']:
            settings[0]['value'] = language
            page.evaluate("async()=>await (await import('/static/settings.js')).loadSettings()")
            for key in ['dlna.enabled', 'dlna.audio_background', 'dlna.port']:
                row = root.locator(f'[data-key="{key}"]')
                expect(row.locator('.name')).to_have_text((english if language == 'en' else translated)[mapping[key]['title']])
            expect(port).to_have_value('2456')
            expect(root.locator('[data-key="dlna.audio_background"] input')).not_to_be_checked()
        with page.expect_response('**/api/settings'):
            port.fill('')
            port.press('Tab')
        assert requests[-1] == {'dlna.port':''}
        assert not errors, errors
        browser.close()
finally:
    server.shutdown()
print('DLNA localization browser checks passed')
