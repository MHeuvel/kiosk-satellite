"""Log controls and About follow locale without changing diagnostics or actions."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k: v for p in (APP / 'l10n/source').glob('*_en.arb')
           for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated = {k: 'TEST ' + v for k, v in english.items()}
if os.environ.get('KS_TEST_SPANISH'):
    translated = {k: v for p in (APP.parents[1] / 'kiosk-satellite-localization/translations/es').glob('*_es.arb')
                  for k, v in json.loads(p.read_text()).items() if not k.startswith('@')}
logcat = '09-17 12:01:02.000 E/Raw: <b>original error</b>\n  original stack trace\n09-17 12:01:03.000 I/Raw: original info'
commands = []
update = dict(availableVersion='2026.9.99-RAW', canRelaunch=False)
logcat_failure = False
installing = False
install_polls = 0

def api(route):
    global logcat_failure, installing, install_polls
    path = route.request.url.split('/api/', 1)[1]
    params = route.request.post_data_json or {}
    commands.append((path, params))
    if path == 'info':
        return route.fulfill(json=dict(appVersion='2026.9.59-RAW', buildNumber=258, buildMode='release', package='me.jxl.kiosk_satellite'))
    if path == 'logs':
        return route.fulfill(json=dict(logs=[dict(level='error', tag='RawTag', message='<b>Original log</b>', time='2026-09-17T12:00:00Z')]))
    if path == 'commands/getLogcat' and logcat_failure:
        return route.fulfill(json=dict(ok=False))
    if path == 'commands/installUpdate':
        installing = True
        install_polls = 0
    if path == 'commands/getUpdateStatus' and installing:
        install_polls += 1
        if install_polls == 1:
            return route.fulfill(json=dict(ok=True, data={**update, 'progress': .5}))
        installing = False
        return route.fulfill(json=dict(ok=True, data={**update, 'lastOutcome': 'cancelled'}))
    data = {'commands/getLogcat': logcat, 'commands/getUpdateStatus': update,
            'commands/checkUpdateNow': dict(reachable=True),
            'commands/evalJs': '<b>Original result</b>'}.get(path, {})
    route.fulfill(json=dict(ok=True, data=data))

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport=dict(width=1100, height=1000))
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        html = (ROOT / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
        page.route(base + '/', lambda r: r.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda r: r.fulfill(body='export const catalogs = ' + json.dumps({'en': english, 'es': translated}) + ';', content_type='text/javascript'))
        page.route('**/api/**', api)
        page.goto(base + '/')
        page.evaluate("""async () => {
          const core = await import('/static/core.js');
          core.showView('app');
          core.cacheSettings([{key:'ui.language',value:'es'}]);
          await import('/static/logs.js');
          document.getElementById('tab-logs').classList.add('active');
          await (await import('/static/logs.js')).loadLogs();
        }""")
        def language(value):
            page.evaluate("async value => (await import('/static/core.js')).cacheSettings([{key:'ui.language',value}])", value)
        def about():
            page.evaluate("""async () => {
              document.getElementById('tab-logs').classList.remove('active');
              document.getElementById('tab-about').classList.add('active');
              await (await import('/static/device.js')).loadAboutInfo();
            }""")

        expect(page.locator('#logMeta')).to_have_text(translated['logsEntries'].replace('{count}', '1'))
        expect(page.locator('#logsOut')).to_contain_text('RawTag: <b>Original log</b>')
        assert page.locator('#logsOut b').count() == 0
        page.locator('[data-log="logcat"]').click()
        expect(page.locator('#logsOut')).to_contain_text('original stack trace')
        expect(page.locator('#logsOut')).not_to_contain_text('original info')
        page.locator('#lcErrors').uncheck()
        expect(page.locator('#logsOut')).to_contain_text(translated['logsNoMatches'])
        language('en')
        expect(page.locator('#lcErrors')).not_to_be_checked()
        expect(page.locator('#logsOut')).to_contain_text(english['logsNoMatches'])
        language('es')
        page.locator('#lcErrors').check()
        page.locator('#lcInfo').check()
        expect(page.locator('#logsOut')).to_contain_text('original info')
        page.evaluate("window.copied = null; Object.defineProperty(navigator, 'clipboard', {value:{writeText:async value => {window.copied=value;}}});")
        page.locator('#copyLogs').click()
        page.wait_for_function("window.copied !== null")
        copied = page.evaluate('window.copied')
        assert '<b>original error</b>' in copied and 'original stack trace' in copied and 'original info' in copied
        assert 'TEST' not in copied
        logcat_failure = True
        page.locator('#refreshLogs').click()
        expect(page.locator('#logsOut')).to_contain_text(translated['logsUnavailable'])
        language('en')
        expect(page.locator('#logsOut')).to_contain_text(english['logsUnavailable'])
        language('es')
        page.locator('[data-log="console"]').click()
        command = 'window.rawName = "Do not translate"'
        page.locator('#consoleInput').fill(command)
        page.locator('#consoleInput').focus()
        before = len(commands)
        language('en')
        expect(page.locator('#consoleInput')).to_have_value(command)
        expect(page.locator('#consoleInput')).to_be_focused()
        assert len(commands) == before
        language('es')
        page.locator('#consoleInput').press('Enter')
        expect(page.locator('#consoleOut')).to_contain_text('<b>Original result</b>')
        assert ('commands/evalJs', {'code': command}) in commands
        assert page.locator('#consoleOut b').count() == 0
        language('en')
        page.locator('#consoleInput').press('ArrowUp')
        expect(page.locator('#consoleInput')).to_have_value(command)
        language('es')
        expect(page.locator('#consoleInput')).to_have_attribute('placeholder', translated['logsInputHistory'])
        page.locator('#clearConsole').click()
        expect(page.locator('#consoleOut')).to_be_empty()
        assert ('commands/clearConsole', {}) in commands
        about()
        root = page.locator('#about-info')
        expect(root).to_contain_text(translated['aboutAttribution'])
        expect(root).to_contain_text('2026.9.59-RAW (258)')
        expect(root).to_contain_text('me.jxl.kiosk_satellite')
        expect(root).to_contain_text('CC BY-NC-ND 4.0')
        expect(root.get_by_role('link', name='CC BY-NC-ND 4.0')).to_have_attribute('href', 'https://github.com/jxlarrea/kiosk-satellite/blob/main/LICENSE')
        install = root.get_by_role('button', name=translated['deviceInstallVersion'].replace('{version}', update['availableVersion']))
        expect(install).to_be_visible()
        install.click()
        expect(page.locator('.modal-card')).to_contain_text(translated['drawerNoReleaseNotes'])
        before = len(commands)
        language('en')
        expect(page.locator('.modal-card')).to_contain_text(english['drawerNoReleaseNotes'])
        assert len(commands) == before
        language('es')
        page.locator('.modal-card').get_by_role('button', name=translated['commonCancel'], exact=True).click()
        assert not any(path == 'commands/installUpdate' for path, _ in commands)
        install.click()
        page.locator('.modal-card').get_by_role('button', name=translated['drawerUpdate'], exact=True).click()
        expect(install).to_have_count(0)
        progress = root.get_by_role('button', name=translated['aboutDownloadProgress'].replace('{percent}', '50'))
        expect(progress).to_be_visible()
        language('en')
        expect(root.get_by_role('button', name=english['aboutDownloadProgress'].replace('{percent}', '50'))).to_be_visible()
        expect(root.get_by_role('button', name=english['deviceInstallVersion'].replace('{version}', update['availableVersion']))).to_be_enabled()
        language('es')
        expect(install).to_be_enabled()
        assert sum(path == 'commands/installUpdate' for path, _ in commands) == 1
        before = len(commands)
        language('en')
        expect(root).to_contain_text('Attribution')
        assert len(commands) == before
        language('es')
        expect(root).to_contain_text(translated['aboutLicenseSummary'])
        # A running download owns its status label. Locale refresh must not
        # restore the initial Install action or replace its DOM node.
        install.evaluate("el => {el.textContent='Download status from updater'; el.disabled=true; el.dataset.keep='yes';}")
        language('en')
        expect(root.locator('[data-keep="yes"]')).to_have_text('Download status from updater')
        expect(root.locator('[data-keep="yes"]')).to_be_disabled()
        language('es')
        page.set_viewport_size(dict(width=390, height=900))
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        update.clear()
        about()
        expect(root).to_contain_text(translated['drawerUpdateCurrent'])
        root.get_by_role('link', name='2026.9.59-RAW (258)').click()
        expect(page.get_by_text(translated['drawerUpdateCurrentHelp'], exact=True)).to_have_text(translated['drawerUpdateCurrentHelp'])
        assert ('commands/checkUpdateNow', {}) in commands
        assert not errors, errors
        browser.close()
    print('Logs and About localization browser checks passed')
finally:
    server.shutdown()
