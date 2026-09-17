"""Exercise translated Camera Streams editors without changing stored identifiers."""
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
config = dict(version=1,
    servers=[dict(id='server-raw', name='Name', baseUrl='https://go2rtc.example:1984',
                  username='user-raw', passwordSet=True, allowInvalidCertificate=False)],
    cameras=[dict(id='ha-raw', name='Cameras', kind='ha', entityId='camera.front_door',
                  preferredProtocol='hls', streamTypes=['hls'], missing=False),
             dict(id='go-raw', name='Views', kind='go2rtc', serverId='server-raw',
                  streamName='low_raw', fullscreenStreamName='high_raw', missing=True)],
    views=[dict(id='view-raw', name='Grid', cameraIds=['ha-raw', 'go-raw'],
                showCameraNames=False, grid=4)])
requests = []
failure = None


def api(route):
    path = route.request.url.split('/api/', 1)[1]
    if path == 'settings':
        requests.append(('unexpected-settings-read', {}))
        return route.fulfill(json={'settings': [{'key': 'ui.language', 'value': 'en', 'type': 'enum', 'title': 'Language', 'description': '', 'options': ['en', 'es']}], 'subpageHints': {}})
    name = path.removeprefix('commands/')
    params = route.request.post_data_json or {}
    requests.append((name, params))
    if name == 'cameraGetConfig':
        return route.fulfill(json={'ok': True, 'data': config})
    if name in ('cameraPutServer', 'cameraPutSource', 'cameraPutView') and failure:
        return route.fulfill(json={'ok': False, 'error': failure})
    data = {'added': 2, 'missing': 1} if name.startswith('cameraImport') else {}
    route.fulfill(json={'ok': True, 'data': data})


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass


server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1200, 'height': 1500})
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        html = (ROOT / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
        page.route(base + '/', lambda route: route.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda route: route.fulfill(
            body='export const catalogs = ' + json.dumps({'en': english, 'es': translated}) + ';',
            content_type='text/javascript'))
        page.route('**/api/**', api)
        page.goto(base + '/')
        page.evaluate("""async (config) => {
          window.cameraConfig = config;
          window.cameraEditors = await import('/static/cameras.js');
          const core = await import('/static/core.js');
          core.showView('app');
          core.cacheSettings([{key: 'ui.language', value: 'es'}]);
          (await import('/static/tabs.js')).showTab('cameras', {refresh: false});
          await cameraEditors.loadCameras();
        }""", config)
        root = page.locator('#tab-cameras')
        expect(root.get_by_text('TEST Go2RTC servers', exact=True)).to_be_visible()
        expect(root.get_by_text('https://go2rtc.example:1984', exact=True)).to_be_visible()
        expect(root.get_by_text('Cameras', exact=True)).to_be_visible()
        expect(root.get_by_text('Views', exact=True)).to_be_visible()
        expect(root.get_by_text('Grid', exact=True)).to_be_visible()
        expect(root.get_by_text('Home Assistant: camera.front_door · HLS, MJPEG', exact=True)).to_be_visible()
        # Server password is omitted unless the user changes it.
        page.evaluate('() => { window.editor = cameraEditors.editCameraServer(cameraConfig.servers[0]); }')
        modal = page.locator('.modal-card').last
        expect(modal.get_by_text('TEST Edit server', exact=True)).to_be_visible()
        expect(modal.get_by_label('TEST Name', exact=True)).to_have_value('Name')
        expect(modal.get_by_label('TEST Base URL', exact=True)).to_have_value('https://go2rtc.example:1984')
        failure = 'valid HTTP or HTTPS baseUrl required'
        modal.get_by_role('button', name='TEST Save', exact=True).click()
        expect(modal.locator('.msg-error')).to_have_text('TEST valid HTTP or HTTPS baseUrl required')
        failure = None
        modal.get_by_role('button', name='TEST Save', exact=True).click()
        page.wait_for_function('() => !document.querySelector(".modal-card")')
        assert requests[-1] == ('cameraPutServer', dict(id='server-raw', name='Name',
            baseUrl='https://go2rtc.example:1984', username='user-raw', allowInvalidCertificate=False))
        # Protocol labels translate but API values and entity IDs remain canonical.
        page.evaluate('() => { window.editor = cameraEditors.editCameraSource(cameraConfig, cameraConfig.cameras[0]); }')
        modal = page.locator('.modal-card').last
        expect(modal.get_by_role('combobox', name='TEST Type', exact=True)).to_have_value('ha')
        expect(modal.get_by_label('TEST Camera entity', exact=True)).to_have_value('camera.front_door')
        modal.get_by_role('combobox', name='TEST Preferred protocol', exact=True).select_option('auto')
        expect(modal.get_by_role('combobox', name='TEST Preferred protocol', exact=True).locator('option:checked')).to_have_text('TEST Auto')
        failure = 'could not read Home Assistant: <img src=x onerror=alert(1)>'
        modal.get_by_role('button', name='TEST Save', exact=True).click()
        expect(modal.locator('.msg-error')).to_have_text('TEST could not read Home Assistant: <img src=x onerror=alert(1)>')
        assert modal.locator('img').count() == 0
        failure = None
        modal.get_by_role('button', name='TEST Save', exact=True).click()
        page.wait_for_function('() => !document.querySelector(".modal-card")')
        assert requests[-1][1]['preferredProtocol'] == 'auto'
        assert requests[-1][1]['entityId'] == 'camera.front_door'
        assert requests[-1][1]['id'] == 'ha-raw'
        # Changing source type retains the exact WHEP URL.
        page.evaluate('() => { window.editor = cameraEditors.editCameraSource(cameraConfig, null); }')
        modal = page.locator('.modal-card').last
        modal.get_by_label('TEST Name', exact=True).fill('Name')
        modal.get_by_role('combobox', name='TEST Type', exact=True).select_option('whep')
        modal.get_by_label('TEST WHEP URL', exact=True).fill('https://example.test/whep?src=Raw')
        modal.get_by_role('button', name='TEST Save', exact=True).click()
        page.wait_for_function('() => !document.querySelector(".modal-card")')
        assert requests[-1][1]['kind'] == 'whep'
        assert requests[-1][1]['whepUrl'] == 'https://example.test/whep?src=Raw'
        assert 'preferredProtocol' not in requests[-1][1]
        # View ordering, grid size and custom names survive a translated editor.
        page.evaluate('() => { window.editor = cameraEditors.editCameraView(cameraConfig, cameraConfig.views[0]); }')
        modal = page.locator('.modal-card').last
        expect(modal.get_by_role('button', name='TEST 4 Cameras', exact=True)).to_be_visible()
        modal.locator('[data-id="go-raw"]').get_by_role('button', name='TEST Move up', exact=True).click()
        expect(modal.locator('[data-id]').first).to_have_attribute('data-id', 'go-raw')
        modal.get_by_role('button', name='TEST Save', exact=True).click()
        page.wait_for_function('() => !document.querySelector(".modal-card")')
        assert requests[-1] == ('cameraPutView', dict(id='view-raw', name='Grid',
            cameraIds=['go-raw', 'ha-raw'], showCameraNames=False, grid=4))
        root.get_by_role('button', name='TEST Import', exact=True).first.click()
        expect(page.get_by_text('TEST 2 added, 1 missing.', exact=True)).to_be_visible()
        page.locator('.modal-card').last.get_by_role('button').click()
        page.wait_for_function('() => !document.querySelector(".modal-card")')
        assert ('cameraImportHomeAssistant', {}) in requests
        assert page.evaluate("""async () => {
          const l = await import('/static/localization.js');
          return l.cameraStreamsError('Go2RTC returned HTTP 503');
        }""") == 'TEST Go2RTC returned HTTP 503'
        # A localized delete confirmation still sends only the selected raw ID.
        root.get_by_text('https://go2rtc.example:1984', exact=True).locator('xpath=ancestor::div[contains(@class,"camera-list-row")][1]').get_by_role('button', name='TEST Delete', exact=True).click()
        expect(page.get_by_text('TEST Delete Name?', exact=True)).to_be_visible()
        page.locator('.modal-card').last.get_by_role('button', name='TEST Delete', exact=True).click()
        page.wait_for_function('() => !document.querySelector(".modal-card")')
        assert ('cameraDeleteServer', {'id': 'server-raw'}) in requests
        assert not any(name == 'unexpected-settings-read' for name, _ in requests), requests
        assert not errors, errors
        browser.close()
        print('Camera Streams localization browser checks passed')
finally:
    server.shutdown()
