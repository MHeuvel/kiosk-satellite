"""Lockdown translations preserve settings, permission commands and live updates."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import copy
import json
import os
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k: v for p in (APP / 'l10n/source').glob('*_en.arb') for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated = {k: 'TEST ' + v for k, v in english.items()}
if os.environ.get('KS_TEST_SPANISH'):
    translated = {k: v for p in (APP.parents[1] / 'kiosk-satellite-localization/translations/es').glob('*_es.arb') for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
mapping = json.loads((APP / 'l10n/settings.json').read_text())
options = json.loads((APP / 'l10n/setting_options.json').read_text())
settings = [dict(key='ui.language', value='es', type='string', category='Device', hidden=True)]
for key in ['lockdown.enabled', 'lockdown.menu', 'lockdown.blackout', 'lockdown.allow_screensaver', 'lockdown.exit_gesture']:
    ids = mapping[key]
    s = dict(key=key, value='taps7' if key.endswith('exit_gesture') else False,
             category='Lockdown', type='select' if key in options else 'boolean',
             title=english[ids['title']], description=english[ids['description']],
             titleMessageId=ids['title'], descriptionMessageId=ids['description'])
    if key in options:
        s.update(options=list(options[key]), optionLabels={v: english[k] for v, k in options[key].items()}, optionMessageIds=options[key])
    if key not in ['lockdown.enabled', 'lockdown.menu']:
        s['dependsOn'] = 'lockdown.enabled'
    settings.append(s)
permissions = {'overlay': False, 'guard': False}
commands, writes = [], []
def api(route):
    path = route.request.url.split('/api/', 1)[1]
    if path == 'settings':
        if route.request.method == 'PATCH':
            values = route.request.post_data_json
            writes.append(copy.deepcopy(values))
            for s in settings:
                if s['key'] in values:
                    s['value'] = values[s['key']]
            return route.fulfill(json=dict(ok=True))
        return route.fulfill(json=dict(settings=settings, subpageHints={}))
    name = path.removeprefix('commands/')
    params = route.request.post_data_json or {}
    commands.append((name, params))
    if name == 'requestOsPermissions': permissions['overlay'] = True
    if name == 'openUiGuardSettings': permissions['guard'] = True
    data = {'hasOverlayPermission': permissions['overlay'], 'hasUiGuard': permissions['guard'],
            'getAudioDevices': dict(inputs=[], outputs=[]), 'hasDeviceCamera': False}.get(name, {})
    route.fulfill(json=dict(ok=True, data=data))
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport=dict(width=1100, height=1300))
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        html = (ROOT / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
        page.route(base + '/', lambda r: r.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda r: r.fulfill(body='export const catalogs = ' + json.dumps({'en': english, 'es': translated}) + ';', content_type='text/javascript'))
        page.route('**/api/**', api)
        page.goto(base + '/')
        page.evaluate("""async () => {
          (await import('/static/core.js')).showView('app');
          await (await import('/static/settings.js')).loadSettings();
          (await import('/static/tabs.js')).showTab('lockdown', {refresh:false});
        }""")
        root = page.locator('#tab-lockdown')
        def row(key): return root.locator(f'[data-key="{key}"]')
        def live(key, value):
            s = next(s for s in settings if s['key'] == key)
            s['value'] = value
            page.evaluate("async setting => (await import('/static/settings.js')).applySettingsUpdate({settings:[setting]})", copy.deepcopy(s))
        expect(row('lockdown.enabled').locator('.name')).to_have_text(translated[mapping['lockdown.enabled']['title']])
        expect(row('lockdown.blackout')).to_have_count(0)
        expect(root.get_by_text(translated['lockdownExplanation'], exact=True)).to_be_visible()
        expect(root.get_by_text(translated['lockdownOverlayMissing'], exact=True)).to_be_visible()
        for key in ['lockdown.enabled', 'lockdown.menu', 'lockdown.blackout', 'lockdown.allow_screensaver']:
            with page.expect_response('**/api/settings'):
                row(key).locator('label').click()
            assert writes[-1] == {key: True}
        gesture = row('lockdown.exit_gesture').locator('select')
        for value in options['lockdown.exit_gesture']:
            with page.expect_response('**/api/settings'):
                gesture.select_option(value)
            assert writes[-1] == {'lockdown.exit_gesture': value}
            expect(gesture.locator('option:checked')).to_have_text(translated[options['lockdown.exit_gesture'][value]])
        root.get_by_role('button', name=translated['kioskGrantDevice'], exact=True).click()
        expect(root.get_by_text(translated['lockdownOverlayHeld'], exact=True)).to_be_visible()
        assert ('requestOsPermissions', {'which': ['overlay']}) in commands
        root.get_by_role('button', name=translated['kioskOpenSettingsDevice'], exact=True).click()
        expect(root.get_by_text(translated['kioskGuardHeld'], exact=True)).to_be_visible()
        assert ('openUiGuardSettings', {}) in commands
        saved = len(writes)
        for language in ['en', 'es']:
            live('ui.language', language)
            catalog = english if language == 'en' else translated
            expect(row('lockdown.enabled').locator('.name')).to_have_text(catalog[mapping['lockdown.enabled']['title']])
            expect(root.get_by_text(catalog['lockdownExplanation'], exact=True)).to_be_visible()
            expect(gesture).to_have_value('none')
            permissions['overlay'] = False
            page.evaluate("async () => (await import('/static/live.js')).receiveUpdate('service')")
            expect(root.get_by_text(catalog['lockdownOverlayMissing'], exact=True)).to_be_visible()
            permissions['overlay'] = True
            page.evaluate("async () => (await import('/static/live.js')).receiveUpdate('service')")
            expect(root.get_by_text(catalog['lockdownOverlayHeld'], exact=True)).to_be_visible()
        assert len(writes) == saved
        live('lockdown.enabled', False)
        expect(row('lockdown.blackout')).to_have_count(0)
        live('lockdown.enabled', True)
        expect(row('lockdown.blackout').locator('input')).to_be_checked()
        expect(gesture).to_have_value('none')
        expect(row('lockdown.enabled').locator('.name')).to_have_text(translated[mapping['lockdown.enabled']['title']])
        # Search must resolve the translated permission description and keep
        # the canonical route used to open the page.
        result = page.evaluate("""async () => {
          const {settingsPageText} = await import('/static/localization.js');
          const {SEARCH_EXTRAS} = await import('/static/search.js');
          const row = SEARCH_EXTRAS.find(s => s.tab === 'lockdown');
          return {...row, desc:settingsPageText(row.tab,row.desc)};
        }""")
        assert result['tab'] == 'lockdown'
        assert result['desc'] == translated['lockdownPermissionsSearch']
        page.set_viewport_size(dict(width=390, height=900))
        expect(root.get_by_text(translated['lockdownExplanation'], exact=True)).to_be_visible()
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        assert not errors, errors
        browser.close()
    print('Lockdown localization browser checks passed')
finally:
    server.shutdown()
