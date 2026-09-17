"""Translated detection settings preserve hardware gating and protocol values."""
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
translated['screensaverDetectionClear'] = 'TEST unoccupied'
translated['commonClear'] = 'TEST clear action'
settings = []
mapping = json.loads((APP / 'l10n/settings.json').read_text())
options = json.loads((APP / 'l10n/setting_options.json').read_text())


def setting(key, value, subpage=None, kind='boolean', **extra):
    row = dict(key=key, value=value, type=kind, category='Screensaver',
               title=key, description='', **extra)
    if subpage:
        row['subpage'] = subpage
    if key in mapping:
        row.update(titleMessageId=mapping[key]['title'],
                   descriptionMessageId=mapping[key]['description'])
    if key in options:
        row['optionMessageIds'] = options[key]
    settings.append(row)
    return row


setting('ui.language', 'es', kind='string', hidden=True)
camera = setting('camera.enabled', False, hidden=True)
for suffix, page_name in [('motion', 'Motion Detection'), ('face', 'Face Detection'),
                          ('proximity', 'Proximity Detection'), ('person', 'Person Detection')]:
    setting('screensaver.dismiss_on_' + suffix, True, page_name)
    setting('screensaver.postpone_on_' + suffix, True, page_name)
setting('face.sensitivity', 50, 'Face Detection', 'number', min=1, max=100)
setting('face.preview', True, 'Face Detection', section='Camera Preview')
setting('face.preview_position', 'top_right', 'Face Detection', 'select',
        section='Camera Preview', options=['top_right', 'bottom_left'],
        optionLabels={'top_right': 'Top right', 'bottom_left': 'Bottom left'})
requests = []
commands = []
vision = {'faces': True, 'hands': True}
proximity = {'supported': False, 'hint': 'Not available on this device: it has no proximity sensor.'}
person = {'enabled': True, 'running': True, 'lastBeat': None, 'present': False,
          'logAccess': {'granted': False, 'effective': False}}


def api(route):
    path = route.request.url.split('/api/', 1)[1]
    if path == 'settings':
        if route.request.method == 'PATCH':
            values = route.request.post_data_json
            requests.append(values)
            for item in settings:
                if item['key'] in values:
                    item['value'] = values[item['key']]
            return route.fulfill(json={'ok': True})
        return route.fulfill(json={'settings': settings, 'subpageHints': {}})
    name = path.removeprefix('commands/')
    commands.append(name)
    data = {'getVisionSupport': vision, 'hasDeviceCamera': True,
            'getProximitySupport': proximity, 'getPersonSensor': person,
            'listPlugins': [], 'listFiles': [], 'mediaPlayers': {'players': []},
            'getAudioDevices': {'inputs': [], 'outputs': []}}.get(name, {})
    route.fulfill(json={'ok': True, 'data': data})


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1200, 'height': 1400})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        html = (ROOT / 'index.html').read_text().replace(
            '<script type="module" src="static/main.js?v=__KSV__"></script>', '')
        page.route(base + '/', lambda route: route.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda route: route.fulfill(
            body='export const catalogs = ' + json.dumps({'en': english, 'es': translated}) + ';',
            content_type='text/javascript'))
        page.route('**/api/**', api)
        page.goto(base + '/')
        page.evaluate("async () => (await import('/static/core.js')).showView('app')")
        root = page.locator('#tab-screensaver')

        def load():
            page.evaluate("""async () => {
                const {state} = await import('/static/core.js');
                state.proximitySupport = undefined;
                await (await import('/static/settings.js')).loadSettings();
            }""")

        def open_page(name):
            page.evaluate("async () => (await import('/static/tabs.js')).showTab('screensaver', {refresh:false})")
            root.locator('[data-subpage-entry="' + name + '"]').click()

        load()
        open_page('Motion Detection')
        expect(page.locator('#pageTitle')).to_contain_text('TEST Motion Detection')
        expect(root.locator('[data-key="screensaver.dismiss_on_motion"] input')).to_be_disabled()
        expect(root.get_by_text('TEST Requires the camera. Turn it on in the Camera settings first.', exact=True).first).to_be_visible()
        open_page('Proximity Detection')
        expect(root.locator('[data-key="screensaver.dismiss_on_proximity"] input')).to_be_disabled()
        expect(root.get_by_text('TEST Not available on this device: it has no proximity sensor.', exact=True)).to_be_visible()

        camera['value'] = True
        vision.update(faces=False, hint='Not available on this Android version.')
        load()
        open_page('Face Detection')
        expect(root.locator('[data-key="screensaver.dismiss_on_face"] input')).to_be_disabled()
        expect(root.get_by_text('TEST Not available on this Android version.', exact=True)).to_be_visible()

        vision.update(faces=True, hint=None)
        proximity.clear()
        proximity.update(supported=True, name='Clear')
        load()
        open_page('Face Detection')
        expect(root.get_by_text('TEST Dismiss on motion is on and takes precedence, so face detection stays idle until it is turned off.', exact=True)).to_be_visible()
        select = root.locator('[data-key="face.preview_position"] select')
        expect(select.locator('option:checked')).to_have_text('TEST Top right')
        with page.expect_response('**/api/settings'):
            select.select_option('bottom_left')
        assert requests[-1] == {'face.preview_position': 'bottom_left'}
        open_page('Proximity Detection')
        expect(root.get_by_text('Clear', exact=True)).to_be_visible()
        expect(root.locator('[data-key="screensaver.dismiss_on_proximity"] input')).to_be_enabled()

        open_page('Person Detection')
        expect(root.get_by_text('TEST unoccupied', exact=True)).to_be_visible()
        command = 'adb shell pm grant me.jxl.kiosk_satellite android.permission.READ_LOGS'
        expect(root.locator('.person-grant-command .copy-value')).to_have_text(command)
        person.update(error='Log access not granted.')
        page.evaluate("async () => (await import('/static/settings.js')).updatePersonSensorRows()")
        expect(root.get_by_text('TEST Log access not granted.', exact=True)).to_be_visible()
        person.pop('error')
        person['logAccess'] = {'granted': True, 'effective': False}
        page.evaluate("async () => (await import('/static/settings.js')).updatePersonSensorRows()")
        expect(root.get_by_text('TEST Granted. Restart Kiosk Satellite to apply it.', exact=True)).to_be_visible()
        with page.expect_response('**/api/commands/restartApp'):
            root.get_by_role('button', name='TEST Restart on device', exact=True).click()
        assert 'restartApp' in commands
        person['logAccess'] = {'granted': True, 'effective': True}
        person['lastBeat'] = page.evaluate('Date.now() - 120000')
        person['present'] = True
        page.evaluate("async () => (await import('/static/settings.js')).updatePersonSensorRows()")
        expect(root.get_by_text('TEST Last heartbeat TEST 2 min ago.', exact=True)).to_be_visible()
        expect(root.get_by_text('TEST Detected', exact=True)).to_be_visible()
        expect(root.get_by_text("TEST The device's person sensor can be read.", exact=True)).to_be_visible()
        assert not errors, errors
        browser.close()
finally:
    server.shutdown()
print('Screensaver detection localization browser checks passed')
