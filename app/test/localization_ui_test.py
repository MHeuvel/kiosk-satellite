"""Exercise translated setup and settings search in the real browser modules."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread

from playwright.sync_api import sync_playwright, expect


APP = Path(__file__).resolve().parents[1]
ROOT = APP / "remote-ui"
english = {key: value for path in (APP / "l10n/source").glob("*_en.arb")
           for key, value in json.loads(path.read_text()).items() if not key.startswith("@")}
# Test markers keep this check independent of translation review status.
spanish = {"remoteWelcomeTitle": "TEST remote welcome", "settingHaUrlTitle": "TEST address",
           "settingsMenuDevice": "TEST dispositivo", "settingsSearchHint": "TEST buscar",
           "settingsGroupSystem": "TEST sistema", "settingsMenuThemeState": "TEST tema {theme}", "drawerThemeDark": "TEST oscuro", "settingsSearchEmpty": "TEST no match {query}"}


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{server.server_port}"
try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True, args=["--no-sandbox"])
        page = browser.new_page(locale="en-US", viewport={"width": 1200, "height": 900})
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        html = (ROOT / "index.html").read_text().replace(
            '<script type="module" src="static/main.js?v=__KSV__"></script>', "")
        page.route(base + "/", lambda route: route.fulfill(body=html, content_type="text/html"))
        page.route("**/static/catalogs.js", lambda route: route.fulfill(
            body="export const catalogs = " + json.dumps({"en": english, "es": spanish}) + ";",
            content_type="text/javascript"))
        page.route("**/api/commands/*", lambda route: route.fulfill(json={"ok": True, "data": {}}))
        page.goto(base + "/")
        result = page.evaluate("""async () => {
          const core = await import('/static/core.js');
          core.cacheSettings([{key: 'ha.url', type: 'string', category: 'Home Assistant',
            title: 'Home Assistant base URL', description: 'Connection address',
            titleMessageId: 'settingHaUrlTitle', value: 'https://example.test'}, {key: 'ui.language', value: 'es'}]);
          const tabs = await import('/static/tabs.js');
          tabs.refreshNavigationText();
          const search = await import('/static/search.js');
          if (!search.searchSettingsIndex('TEST dispositivo').some(row => row.tab === 'device' && row.isPage)) throw new Error('Translated page not searchable');
          if (!search.searchSettingsIndex('Device').some(row => row.tab === 'device' && row.isPage)) throw new Error('English page alias lost');
          if (document.querySelector('#settingsSearch').placeholder !== 'TEST buscar') throw new Error('Search placeholder not translated');
          if (document.querySelector('[data-tab="device"] .nav-title').textContent !== 'TEST dispositivo') throw new Error('Sidebar not translated');
          localStorage.setItem('ks_theme', 'dark');
          core.applyTheme();
          if (document.querySelector('#themeBtn').title !== 'TEST tema TEST oscuro') throw new Error('Theme tooltip lost its translation');
          const {setLanguagePreference} = await import('/static/localization.js');
          setLanguagePreference('en');
          tabs.refreshNavigationText();
          if (document.querySelector('[data-tab="device"] .nav-title').textContent !== 'Device') throw new Error('Sidebar did not switch back');
          setLanguagePreference('es');
          tabs.refreshNavigationText();
          const translated = search.searchSettingsIndex('TEST address');
          const english = search.searchSettingsIndex('Home Assistant base URL');
          const {wizard} = await import('/static/app.js');
          const {wizardSteps, wizardRender} = await import('/static/wizard.js');
          wizard.i = 0;
          wizard.needPassword = true;
          wizard.steps = wizardSteps();
          core.showView('wizard');
          wizardRender();
          return {translated: translated.some(row => row.key === 'ha.url'),
            english: english.some(row => row.key === 'ha.url'), value: core.state.settings[0].value};
        }""")
        assert result == {"translated": True, "english": True, "value": "https://example.test"}, result
        expect(page.locator("#wizardTitle")).to_have_text("TEST remote welcome")
        expect(page.locator("#wizardNext")).to_have_text("Next")
        assert errors == [], errors
        browser.close()
        print("Browser localization: setup, language selection, fallback and translated search passed")
finally:
    server.shutdown()
