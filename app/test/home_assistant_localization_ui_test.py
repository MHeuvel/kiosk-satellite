"""Check localized Home Assistant controls without translating stored paths or supplied names."""
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
spanish = {
    'haValidate': 'TEST validate', 'haInvalidToken': 'TEST invalid token',
    'haChangeView': 'TEST change view', 'haChooseView': 'TEST choose view',
    'haRotation': 'TEST rotation', 'haDefaultView': 'TEST default view',
    'settingHaThemeTitle': 'TEST theme', 'deviceThemeDark': 'TEST dark',
    'settingDeviceNameTitle': 'TEST device name', 'haProxy': 'TEST proxy',
    'haProxyRemoteNotice': 'TEST proxy explanation', 'commonOk': 'TEST OK',
}
settings = []
def setting(key, value, kind='boolean', subpage=None, **extra):
    settings.append(dict(key=key, value=value, type=kind, category='Home Assistant',
                         title=key, description='', **({'subpage': subpage} if subpage else {}), **extra))
setting('ui.language', 'es', 'select')
setting('ha.url', 'http://ha.example', 'string', titleMessageId='settingHaUrlTitle')
setting('ha.token', '__set__', 'password', titleMessageId='settingHaTokenTitle')
setting('browser.start_url', 'http://ha.example/dashboard-one/original', 'string', hidden=True)
setting('browser.secure_proxy', False, hidden=True)
setting('ha.auto_login', True, titleMessageId='settingHaAutoLoginTitle')
setting('ha.theme', 'dark', 'select', 'Theme', titleMessageId='settingHaThemeTitle',
        options=['auto', 'light', 'dark'], optionLabels={'auto': 'Auto', 'light': 'Light', 'dark': 'Dark'},
        optionMessageIds={'auto': 'haThemeAuto', 'light': 'deviceThemeLight', 'dark': 'deviceThemeDark'})
setting('ha.theme_auto', False, subpage='Theme')
setting('ha.rotation_enabled', True, subpage='Dashboard View Rotation', titleMessageId='settingHaRotationEnabledTitle')
setting('ha.rotation_dashboards', '[]', 'string', hidden=True)
setting('ha.rotation_urls', '[]', 'string', hidden=True)
requests = []

def api(route):
    path = route.request.url.split('/api/', 1)[1]
    if path == 'settings':
        if route.request.method == 'PATCH':
            values = route.request.post_data_json
            requests.append(('settings', values))
            for item in settings:
                if item['key'] in values: item['value'] = values[item['key']]
            return route.fulfill(json={'ok': True})
        return route.fulfill(json={'settings': settings, 'subpageHints': {}})
    name = path.removeprefix('commands/')
    args = route.request.post_data_json or {}
    requests.append((name, args))
    if name == 'haCheckConnection': return route.fulfill(json={'ok': False, 'error': 'invalid token'})
    data = {'haStatus': {'connected': True},
            'getUpdateInstallerStatus': {'nativeSilent': True},
            'haListDashboards': [{'title': 'Device name', 'url_path': 'dashboard-one'},
                                 {'title': 'Another dashboard', 'url_path': 'strategy'}],
            'haListDashboardViews': ([{'title': 'Default view', 'route': 'original'},
                                      {'title': 'Light', 'route': 'raw-target'}]
                                     if args.get('url_path') == 'dashboard-one' else []),
            'listPlugins': [], 'listFiles': [], 'mediaPlayers': {'players': []},
            'getAudioDevices': {'inputs': [], 'outputs': []}}.get(name, {})
    route.fulfill(json={'ok': True, 'data': data})

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1200, 'height': 1000})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        html = (ROOT / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
        page.route(base+'/', lambda route: route.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda route: route.fulfill(
            body='export const catalogs = '+json.dumps({'en': english, 'es': spanish})+';', content_type='text/javascript'))
        page.route('**/api/**', api)
        page.goto(base+'/')
        page.evaluate("""async () => {
          (await import('/static/core.js')).showView('app');
          await (await import('/static/settings.js')).loadSettings();
          (await import('/static/tabs.js')).showTab('homeassistant', {refresh:false});
        }""")
        root = page.locator('#tab-homeassistant')
        expect(root.get_by_text('Device name', exact=True).first).to_be_visible()
        root.get_by_role('button', name='TEST change view', exact=True).click()
        expect(page.get_by_text('TEST choose view', exact=True)).to_be_visible()
        expect(page.get_by_text('Default view', exact=True).last).to_be_visible()
        with page.expect_response('**/api/commands/loadUrl'):
            page.get_by_text('Light', exact=True).last.click()
        page.wait_for_function("document.querySelector('#tab-homeassistant').textContent.includes('dashboard-one/raw-target')")
        assert ('settings', {'browser.start_url': 'http://ha.example/dashboard-one/raw-target'}) in requests
        assert ('loadUrl', {'url': 'http://ha.example/dashboard-one/raw-target'}) in requests
        assert page.evaluate("(async () => (await import('/static/search.js')).searchSettingsIndex('TEST rotation').some(row => row.entry === 'Dashboard View Rotation'))()")
        root.locator('[data-subpage-entry="Theme"]').click()
        expect(page.locator('#pageTitle')).to_contain_text('TEST theme')
        expect(root.locator('[data-subpage="Theme"] select')).to_have_value('dark')
        expect(root.locator('[data-subpage="Theme"] option[value="dark"]')).to_have_text('TEST dark')
        page.evaluate("(async () => (await import('/static/tabs.js')).showTab('homeassistant/Dashboard View Rotation', {refresh:false}))()")
        expect(page.locator('#pageTitle')).to_contain_text('TEST rotation')
        panel = root.locator('[data-subpage="Dashboard View Rotation"]')
        expect(panel.get_by_text('Default view', exact=True)).to_be_visible()
        expect(panel.get_by_text('TEST default view', exact=True)).to_be_visible()
        expect(panel.get_by_text('Device name', exact=True)).to_be_visible()
        with page.expect_response('**/api/settings'):
            panel.get_by_text('Light', exact=True).click()
        assert ('settings', {'ha.rotation_dashboards': '["dashboard-one/raw-target"]'}) in requests
        page.evaluate("(async () => (await import('/static/tabs.js')).showTab('homeassistant', {refresh:false}))()")
        root.get_by_role('button', name='TEST validate', exact=True).click()
        expect(page.get_by_text('TEST proxy explanation', exact=True)).to_be_visible()
        assert ('settings', {'browser.secure_proxy': True}) not in requests
        page.get_by_role('button', name='TEST OK', exact=True).click()
        expect(root.get_by_text('TEST invalid token', exact=True)).to_be_visible()
        assert ('settings', {'browser.secure_proxy': True}) in requests
        assert errors == [], errors
        browser.close()
        print('Home Assistant localization: connection, proxy, theme, supplied names and stored view paths passed')
finally:
    server.shutdown()
