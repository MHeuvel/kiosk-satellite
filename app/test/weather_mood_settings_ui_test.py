"""Weather Mood settings preserve HA entity IDs in every supported language."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
mapping = json.loads((APP / 'l10n/settings.json').read_text())
option_ids = json.loads((APP / 'l10n/setting_options.json').read_text())
english = json.loads((APP / 'l10n/effective/ui_en.arb').read_text())
settings = []
requests = []
fail_search = False

def setting(key, value, kind='string', **extra):
    ids = mapping.get(key, {})
    settings.append(dict(key=key, value=value, type=kind, category='Screensaver',
                         title=key, description='', titleMessageId=ids.get('title'),
                         descriptionMessageId=ids.get('description'), **extra))

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
        return route.fulfill(json={'settings': settings, 'subpageHints': {
            'Weather Mood screensaver': 'Weather entity, lightning, preview'}})
    name = path.removeprefix('commands/')
    if name == 'haSearchEntities':
        if fail_search:
            return route.fulfill(json={'ok': False})
        assert route.request.post_data_json == {'query': 'weather.'}
        data = [{'entity_id': 'weather.home', 'name': 'Garden weather'},
                {'entity_id': 'weather.coast', 'name': 'Coastal weather'},
                {'entity_id': 'sensor.weather_temperature', 'name': 'Excluded sensor'}]
    else:
        data = {'listPlugins': [], 'listFiles': [],
                'mediaPlayers': {'players': []},
                'getAudioDevices': {'inputs': [], 'outputs': []}}.get(name, {})
    route.fulfill(json={'ok': True, 'data': data})

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass

server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=os.environ.get('CHROMIUM_PATH', '/usr/bin/chromium'),
            headless=True, args=['--no-sandbox'])
        for locale in ['en', 'es', 'de', 'fr']:
            strings = json.loads((APP / f'l10n/effective/ui_{locale}.arb').read_text())
            settings.clear()
            setting('ui.language', locale, hidden=True)
            setting('ha.url', 'https://ha.example', hidden=True)
            setting('ha.token', '__set__', hidden=True)
            setting('screensaver.mode', 'weather_mood', 'select',
                    options=['black', 'weather_mood'],
                    optionLabels={'black': 'Black', 'weather_mood': 'Weather Mood'},
                    optionMessageIds={'weather_mood': 'screensaverWeatherMood'})
            for key, value, kind in [('entity', 'weather.home', 'string'),
                                     ('lightning', True, 'boolean')]:
                setting('screensaver.weather_'+key, value, kind,
                        subpage='Weather Mood screensaver', section='Weather Mood screensaver',
                        dependsOn='screensaver.mode', dependsOnValue='weather_mood')
            setting('screensaver.weather_preview', False, 'boolean',
                    subpage='Weather Mood screensaver', section='Weather Preview',
                    dependsOn='screensaver.mode', dependsOnValue='weather_mood')
            for suffix, value in [('condition', 'sunny'), ('period', 'day')]:
                key = 'screensaver.weather_preview_'+suffix
                setting(key, value, 'select',
                        subpage='Weather Mood screensaver', section='Weather Preview',
                        dependsOn='screensaver.weather_preview', dependsOnValue=True,
                        options=list(option_ids[key]), optionMessageIds=option_ids[key],
                        optionLabels={value: english[identifier] for value, identifier in option_ids[key].items()})
            page = browser.new_page(viewport={'width': 1200, 'height': 1000})
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            html = (ROOT/'index.html').read_text().replace(
                '<script type="module" src="static/main.js?v=__KSV__"></script>', '')
            page.route(base+'/', lambda route: route.fulfill(body=html, content_type='text/html'))
            page.route('**/api/**', api)
            page.goto(base+'/')
            page.evaluate("""async () => {
                (await import('/static/core.js')).showView('app');
                await (await import('/static/settings.js')).loadSettings();
                (await import('/static/tabs.js')).showTab('screensaver',{refresh:false});
            }""")
            root = page.locator('#tab-screensaver')
            expect(root.locator('[data-key="screensaver.mode"] option[value="weather_mood"]')).to_have_text(strings['screensaverWeatherMood'])
            root.locator('[data-subpage-entry="Weather Mood screensaver"]').click()
            expect(page.locator('#pageTitle')).to_contain_text(strings['screensaverWeatherMoodPage'])
            expect(root.locator('[data-key="screensaver.weather_lightning"] .name')).to_have_text(strings['settingScreensaverWeatherLightningTitle'])
            picker = root.locator('[data-key="screensaver.weather_entity"] select')
            expect(picker.locator('option[value="weather.coast"]')).to_have_text('Coastal weather')
            expect(picker.locator('option[value^="sensor."]')).to_have_count(0)
            with page.expect_response('**/api/settings'):
                picker.select_option('weather.coast')
            assert {'screensaver.weather_entity': 'weather.coast'} in requests
            with page.expect_response('**/api/settings'):
                root.locator('[data-key="screensaver.weather_lightning"] .switch').click()
            assert {'screensaver.weather_lightning': False} in requests
            expect(root.locator('.card-title', has_text=strings['screensaverWeatherPreviewGroup'])).to_be_visible()
            preview = root.locator('[data-key="screensaver.weather_preview"] .switch')
            weather = root.locator('[data-key="screensaver.weather_preview_condition"] select')
            period = root.locator('[data-key="screensaver.weather_preview_period"] select')
            expect(weather).to_have_count(0)
            expect(period).to_have_count(0)
            with page.expect_response('**/api/settings'):
                preview.click()
            expect(weather).to_be_visible()
            expect(period).to_be_visible()
            for key, picker_control in [('screensaver.weather_preview_condition', weather),
                                        ('screensaver.weather_preview_period', period)]:
                for value, identifier in option_ids[key].items():
                    expect(picker_control.locator(f'option[value="{value}"]')).to_have_text(strings[identifier])
            with page.expect_response('**/api/settings'):
                weather.select_option('snowy')
            with page.expect_response('**/api/settings'):
                period.select_option('night')
            assert {'screensaver.weather_preview_condition': 'snowy'} in requests
            assert {'screensaver.weather_preview_period': 'night'} in requests
            with page.expect_response('**/api/settings'):
                preview.click()
            expect(weather).to_have_count(0)
            expect(period).to_have_count(0)
            with page.expect_response('**/api/settings'):
                preview.click()
            expect(weather).to_have_value('snowy')
            expect(period).to_have_value('night')
            # A missing entity remains selected so transient HA failures cannot erase it.
            fail_search = True
            next(item for item in settings if item['key']=='screensaver.weather_entity')['value']='weather.missing'
            page.evaluate("async () => (await import('/static/settings.js')).loadSettings()")
            expect(picker).to_have_value('weather.missing')
            expect(root.locator('[data-key="screensaver.weather_entity"] .row-error')).to_be_visible()
            fail_search = False
            assert not errors, errors
            page.close()
        browser.close()
finally:
    server.shutdown()
print('Weather Mood remote settings passed in English, Spanish, German and French')
