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
            setting('screensaver.weather_blur', 0, 'number',
                    subpage='Weather Mood screensaver', section='Weather Mood screensaver',
                    min=0, max=30, step=1, unit='px')
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
            for group, master in [('Clock', 'clock'), ('Weather information', 'bar')]:
                setting('screensaver.weather_'+master, False, 'boolean',
                        subpage='Weather Mood screensaver', section=group,
                        dependsOn='screensaver.mode', dependsOnValue='weather_mood')
            for suffix, value, kind in [('font', 'rubik', 'select'),
                                        ('font_weight', 'default', 'select'),
                                        ('24h', False, 'boolean'),
                                        ('show_date', True, 'boolean'),
                                        ('scale', 100, 'number'),
                                        ('color', '250,250,250', 'string'),
                                        ('shadow', True, 'boolean')]:
                key = 'screensaver.weather_clock_'+suffix
                choices = option_ids.get(key, {})
                if suffix == 'font':
                    choices = {'rubik': None, 'nunito': None}
                setting(key, value, kind, subpage='Weather Mood screensaver', section='Clock',
                        dependsOn='screensaver.weather_clock', dependsOnValue=True,
                        min=50, max=300, step=5,
                        options=list(choices), optionMessageIds={k:v for k,v in choices.items() if v},
                        optionLabels={value: english[identifier] if identifier else value.capitalize() for value, identifier in choices.items()})
            for suffix, value, kind in [('scale',100,'number'), ('opacity',50,'number'),
                                        ('color','255,255,255','string'), ('shadow',False,'boolean'),
                                        ('feels_like',False,'boolean')]:
                setting('screensaver.weather_bar_'+suffix, value, kind,
                        subpage='Weather Mood screensaver', section='Weather information',
                        dependsOn='screensaver.weather_bar', dependsOnValue=True,
                        min=0, max=200, step=5)
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
            expect(root.locator('[data-key="screensaver.weather_blur"] .name')).to_have_text(strings['settingScreensaverWeatherBlurTitle'])
            expect(root.locator('[data-key="screensaver.weather_blur"] input[type="range"]')).to_be_visible()
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
                period.select_option('twilight')
            assert {'screensaver.weather_preview_condition': 'snowy'} in requests
            assert {'screensaver.weather_preview_period': 'twilight'} in requests
            with page.expect_response('**/api/settings'):
                preview.click()
            expect(weather).to_have_count(0)
            expect(period).to_have_count(0)
            with page.expect_response('**/api/settings'):
                preview.click()
            expect(weather).to_have_value('snowy')
            expect(period).to_have_value('twilight')
            clock = root.locator('[data-key="screensaver.weather_clock"] .switch')
            bar = root.locator('[data-key="screensaver.weather_bar"] .switch')
            font = root.locator('[data-key="screensaver.weather_clock_font"] select')
            expect(font).to_have_count(0)
            expect(root.locator('[data-key="screensaver.weather_bar_scale"]')).to_have_count(0)
            with page.expect_response('**/api/settings'):
                clock.click()
            expect(font).to_be_visible()
            expect(root.locator('[data-key="screensaver.weather_clock_scale"] .name')).to_have_text(strings['settingScreensaverClockScaleTitle'])
            expect(root.locator('[data-key="screensaver.weather_clock_color"]')).to_be_visible()
            with page.expect_response('**/api/settings'):
                font.select_option('nunito')
            assert {'screensaver.weather_clock_font': 'nunito'} in requests
            with page.expect_response('**/api/settings'):
                bar.click()
            expect(root.locator('[data-key="screensaver.weather_bar_scale"] .name')).to_have_text(strings['settingScreensaverWeatherBarScaleTitle'])
            expect(root.locator('.card-title', has_text=strings['screensaverWeatherBarGroup'])).to_be_visible()
            feels_like = root.locator('[data-key="screensaver.weather_bar_feels_like"]')
            expect(feels_like).to_contain_text(strings['screensaverWeatherBarFeelsLikeDescription'])
            with page.expect_response('**/api/settings'):
                feels_like.locator('.switch').click()
            assert {'screensaver.weather_bar_feels_like': True} in requests
            assert 'screensaver.weather_bar_feels_like_only' not in mapping

            with page.expect_response('**/api/settings'):
                clock.click()
            expect(font).to_have_count(0)
            expect(root.locator('[data-key="screensaver.weather_bar_scale"]')).to_be_visible()
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
