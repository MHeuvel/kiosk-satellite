"""Overview language changes preserve cached status, controls and command values."""
import copy
import json
import os
import base64
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k: v for p in (APP / 'l10n/source').glob('*.arb') for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated = {k: 'TEST ' + v for k, v in english.items()}
if os.environ.get('KS_TEST_SPANISH'):
    translated = {k: v for p in (APP.parents[1] / 'kiosk-satellite-localization/translations/es').glob('*.arb') for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
ids = json.loads((APP / 'l10n/overview_text.json').read_text())
settings = [dict(key=k, value=v) for k, v in {'ui.language': 'es', 'browser.ws_filter': True, 'wake_word.enabled': True, 'esphome.entities': True, 'btproxy.enabled': True, 'camera.enabled': True, 'screen.set_brightness_on_launch': True}.items()]
commands = []
status = {
    'haStatus': dict(configured=True, connected=True),
    'getWakeWordState': dict(listening=True, models=[dict(wakeWord='<b>Original wake word</b>')]),
    'esphomeStatus': dict(running=True, clients=1),
    'sendspinStatus': dict(enabled=True, playing=True, title='Original track', artist='Original artist'),
    'getServiceStatus': dict(running=True, reasons=['a', 'b']),
    'getUpdateStatus': dict(currentVersion='1.0-raw', availableVersion='2.0-raw', availableNotes='Original release notes', progress=None),
    'getSystemPermissions': dict(microphone=False), 'hasUiGuard': True,
    'fleetStatus': dict(invite=dict(leader=dict(name='<b>Original leader</b>'))),
    'getPluginStatusTiles': [dict(pluginId='original', key='status', title='Running', text='Off', pluginName='<b>Original plugin</b>')],
    'getVolume': 55, 'getDeviceRebootSupport': dict(supported=True),
    'intercomStatus': dict(enabled=True, available=True, dnd=True),
    'evalJs': json.dumps(dict(enabled=True, built=True, allow=7)),
    'haListDashboards': [dict(title='Original dashboard', url_path='raw-dashboard'), dict(title='Generated dashboard', url_path='generated')],
    'cameraGetConfig': dict(views=[dict(id='raw1', name='Default view', cameraIds=['cam1']), dict(id='raw2', name='<b>Original view</b>', cameraIds=['cam2'])], cameras=[dict(id='cam1', name='Original camera'), dict(id='cam2', name='<b>Original camera</b>')]),
}
png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')

def api(route):
    path = route.request.url.split('/api/', 1)[1]
    if path in ['camera/snapshot', 'screenshot']:
        return route.fulfill(body=png, content_type='image/png')
    name = path.removeprefix('commands/')
    params = route.request.post_data_json or {}
    commands.append((name, params))
    if name == 'intercomSetDnd': status['intercomStatus']['dnd'] = params['on']
    if name == 'installUpdate': status['getUpdateStatus']['progress'] = 0.3
    if name == 'cancelUpdateDownload': status['getUpdateStatus']['progress'] = None
    result = status.get(name, {})
    if name == 'haListDashboardViews': result = [dict(title='Default view', route='raw-view')] if params['url_path'] == 'raw-dashboard' else []
    route.fulfill(json=dict(ok=True, data=result))

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass

server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport=dict(width=1200, height=1400))
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        html = (ROOT / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
        page.route(base + '/', lambda r: r.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda r: r.fulfill(body='export const catalogs = ' + json.dumps({'en': english, 'es': translated}) + ';', content_type='text/javascript'))
        page.route('**/api/**', api)
        page.goto(base + '/')
        page.evaluate("async s=>{const c=await import('/static/core.js');c.showView('app');c.cacheSettings(s);(await import('/static/tabs.js')).showTab('dashboard',{refresh:false});await(await import('/static/overview.js')).initOverview();await(await import('/static/panels.js')).loadViewJump();}", settings)
        root = page.locator('#tab-dashboard')
        def label(en): return translated[ids[en]]
        def msg(key, **params):
            result = translated[key]
            for k, v in params.items(): result = result.replace('{' + k + '}', str(v))
            return result
        def language(value):
            settings[0]['value'] = value
            page.evaluate("async s=>(await import('/static/core.js')).cacheSettings(s)", copy.deepcopy(settings))
        def tile(key): return root.locator(f'[data-status="{key}"]')
        expect(tile('ha')).to_contain_text(msg('overviewWatchingMany', count=7))
        expect(tile('voice')).to_contain_text(msg('overviewListeningFor', words='<b>Original wake word</b>'))
        expect(tile('service')).to_contain_text(msg('overviewRunningMany', count=2))
        expect(tile('update')).to_contain_text(msg('overviewNewVersion', version='2.0-raw'))
        expect(root.locator('.status.plugin .s-name')).to_have_text('Running')
        expect(root.locator('.status.plugin .s-sub')).to_have_text('Off')
        expect(root.locator('.status.plugin .s-from')).to_have_text(msg('overviewPluginAttribution', name='<b>Original plugin</b>'))
        expect(root.locator('#shotFull')).to_have_attribute('aria-label', label('Full size'))
        expect(root.locator('#tileDnd')).to_contain_text(label('Do not disturb on'))
        expect(root.locator('#viewJump option[value="raw-dashboard/raw-view"]')).to_have_text('Default view')
        expect(root.locator('#viewJump option[value="generated"]')).to_have_text(label('Default view'))
        expect(root.locator('#attentionCard [data-key="fleet-invite"] .name')).to_have_text(msg('overviewInvitation', name='<b>Original leader</b>'))
        assert root.locator('b').count() == 0
        page.evaluate("window.originalInstall=document.querySelector('#attentionCard [data-key=update] button');window.originalPicker=document.querySelector('#viewJump');window.originalVolume=document.querySelector('#volumeRow input');")
        before = len(commands)
        language('en')
        expect(tile('ha')).to_contain_text('Watching 7 entities')
        expect(root.locator('#tileDnd')).to_contain_text('Do not disturb on')
        language('es')
        expect(tile('ha')).to_contain_text(msg('overviewWatchingMany', count=7))
        assert len(commands) == before, commands[before:]
        assert page.evaluate("originalInstall===document.querySelector('#attentionCard [data-key=update] button') && originalPicker===document.querySelector('#viewJump') && originalVolume===document.querySelector('#volumeRow input')")
        with page.expect_response('**/api/commands/haNavigate'):
            root.locator('#viewJump').select_option('raw-dashboard/raw-view')
        assert ('haNavigate', dict(path='raw-dashboard/raw-view')) in commands
        expect(root.locator('#viewJump')).to_have_value('')
        with page.expect_response('**/api/commands/intercomSetDnd'): root.locator('#tileDnd').click()
        assert ('intercomSetDnd', dict(on=False)) in commands
        expect(root.locator('#tileDnd')).to_contain_text(label('Do not disturb'))
        with page.expect_response('**/api/commands/setVolume'):
            root.locator('#volumeRow input').evaluate('(el)=>{el.value=65;el.dispatchEvent(new Event("change",{bubbles:true}));}')
        assert ('setVolume', dict(percent=65)) in commands
        permission = root.locator('#attentionCard [data-key="perm:microphone"]')
        device_ids = json.loads((APP / 'l10n/device_text.json').read_text())
        expect(permission.locator('.name')).to_have_text(msg('overviewPermissionMissing', permission=translated[device_ids['Microphone']]))
        with page.expect_response('**/api/commands/requestOsPermissions'):
            permission.get_by_role('button', name=label('Grant on device'), exact=True).click()
        assert ('requestOsPermissions', dict(which=['microphone'])) in commands
        # Live quick-state updates keep their wire commands and repaint badges.
        page.evaluate("async()=>{const p=await import('/static/panels.js');p.applyQuickEvent('screenoff');p.applyQuickEvent('screensaverstart');}")
        expect(root.locator('#shotBadge')).to_have_text(translated['overviewScreenOffState'])
        expect(root.locator('#tileScreen')).to_contain_text(label('Screen on'))
        expect(root.locator('#tileScreensaver')).to_contain_text(label('Dismiss screensaver'))
        language('en'); language('es')
        expect(root.locator('#tileScreen')).to_have_attribute('data-cmd', 'screenOn')
        expect(root.locator('#tileScreensaver')).to_have_attribute('data-cmd', 'stopScreensaver')
        page.evaluate("async()=>{const p=await import('/static/panels.js');p.applyQuickEvent('screenon');p.applyQuickEvent('screensaverstop');}")
        # A language change inside confirmation must preserve its command result.
        root.locator('#tileRestartDevice').click()
        modal = page.locator('.modal-back')
        expect(modal.locator('.modal-title')).to_have_text(label('Restart device'))
        language('en'); expect(modal.locator('.modal-title')).to_have_text('Restart device')
        language('es')
        with page.expect_response('**/api/commands/rebootDevice'):
            modal.get_by_role('button', name=label('Restart'), exact=True).click()
        root.locator('#tileRestartDevice').click()
        modal.get_by_role('button', name=label('Cancel'), exact=True).click()
        assert len([c for c in commands if c[0] == 'rebootDevice']) == 1
        root.locator('#tileCameraView').click()
        expect(modal.locator('.modal-title')).to_have_text(label('Show camera view'))
        language('en'); language('es')
        expect(modal).to_contain_text('<b>Original camera</b>')
        assert modal.locator('b').count() == 0
        with page.expect_response('**/api/commands/showCameraView'):
            modal.get_by_text('<b>Original view</b>', exact=True).click()
        assert ('showCameraView', dict(viewId='raw2')) in commands
        root.locator('#tileSnapshot').click()
        expect(modal.locator('img')).to_have_attribute('alt', label('Camera snapshot'))
        language('en'); expect(modal.locator('img')).to_have_attribute('alt', 'Camera snapshot')
        language('es'); modal.get_by_role('button', name=label('Close'), exact=True).click()
        # The existing update controller keeps ownership of download progress.
        root.locator('#attentionCard [data-key="update"] button').click()
        with page.expect_response('**/api/commands/installUpdate'):
            modal.get_by_role('button', name=translated['drawerUpdate'], exact=True).click()
        progress = root.locator('#attentionCard [data-key="update"] button').first
        expect(progress).to_have_text(msg('aboutDownloadProgress', percent=30))
        language('en'); expect(progress).to_have_text(english['aboutDownloadProgress'].replace('{percent}', '30'))
        language('es'); expect(progress).to_have_text(msg('aboutDownloadProgress', percent=30))
        expect(progress).to_be_disabled()
        assert page.evaluate("originalInstall===document.querySelector('#attentionCard [data-key=update] button')")
        assert len([c for c in commands if c[0] == 'installUpdate']) == 1
        with page.expect_response('**/api/commands/cancelUpdateDownload'):
            root.locator('#attentionCard [data-key="update"]').get_by_role('button', name=translated['commonCancel'], exact=True).click()
        page.evaluate("async()=>await(await import('/static/overview.js')).refreshHealth()")
        expect(tile('ha')).to_contain_text(msg('overviewWatchingMany', count=7))
        expect(tile('service')).to_contain_text(msg('overviewRunningMany', count=2))
        assert len([c for c in commands if c[0] == 'evalJs']) == 1
        page.set_viewport_size(dict(width=390, height=1000))
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        assert not errors, errors
        browser.close()
    print('Overview localization browser checks passed')
finally:
    server.shutdown()
