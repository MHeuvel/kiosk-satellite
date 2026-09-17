"""Translated overlay editors preserve widget config and Home Assistant values."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread

from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {
    k: v for p in (APP / 'l10n/source').glob('*_en.arb')
    for k, v in json.loads(p.read_text()).items() if not k.startswith('@')
}
translated = {k: 'TEST ' + v for k, v in english.items()}
settings = []
mapping = json.loads((APP / 'l10n/settings.json').read_text())
options = json.loads((APP / 'l10n/setting_options.json').read_text())


def setting(key, value, subpage=None, kind='string', **extra):
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


initial = [{'position': 'top_right', 'type': 'clock', 'config': {
    'color': '1,2,3', 'scale': 15, 'font': 'oswald', 'font_weight': 'black',
    'h24': True, 'date': False}}]
setting('ui.language', 'es', hidden=True)
setting('screensaver.widgets', json.dumps(initial), 'Widgets')
setting('screensaver.widget_font_weight', 'black', 'Widgets', 'select',
        options=['default', 'black'], optionLabels={'default': 'Default', 'black': 'Black'})
setting('screensaver.glance_enabled', True, 'At a Glance', 'boolean')
setting('screensaver.glance_entities', json.dumps([
    {'entity_id': 'sensor.raw', 'name': 'Weather', 'attribute': 'humidity'},
    {'entity_id': 'sensor.second', 'name': 'State'}]), 'At a Glance')
requests = []
fail_search = False


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
    args = route.request.post_data_json or {}
    if name == 'haSearchEntities':
        if fail_search:
            return route.fulfill(json={'ok': False})
        data = ([{'entity_id': 'weather.original', 'name': 'State', 'state': 'sunny'}]
                if args.get('query') == 'weather.' else
                [{'entity_id': 'sensor.original', 'name': 'Weather', 'state': '42'}])
    else:
        data = {'haEntityAttributes': {'humidity': 51, 'friendly_name': 'Weather'},
                'listPlugins': [], 'listFiles': [],
                'mediaPlayers': {'players': []},
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
        page = browser.new_page(viewport={'width': 1200, 'height': 1500})
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
        page.evaluate("""async () => {
            (await import('/static/core.js')).showView('app');
            await (await import('/static/settings.js')).loadSettings();
        }""")
        root = page.locator('#tab-screensaver')

        def open_page(name):
            page.evaluate("async () => (await import('/static/tabs.js')).showTab('screensaver', {refresh:false})")
            root.locator('[data-subpage-entry="' + name + '"]').click()

        def field(name):
            return page.locator('.modal-back .form-field').filter(
                has=page.get_by_text('TEST ' + name, exact=True))

        def save():
            with page.expect_response('**/api/settings'):
                page.get_by_role('button', name='TEST Save', exact=True).last.click()

        open_page('Widgets')
        expect(root.locator('[data-key="screensaver.widget_font_weight"] option:checked')).to_have_text('TEST Black')
        root.get_by_text('TEST Small clock', exact=True).click()
        expect(field('Font weight').locator('option:checked')).to_have_text('TEST Black')
        expect(field('Corner').locator('option:checked')).to_have_text('TEST Top right')
        save()
        assert json.loads(requests[-1]['screensaver.widgets']) == initial

        root.get_by_text('TEST Add widget', exact=True).click()
        field('Widget').locator('select').select_option('weather')
        expect(page.get_by_text('TEST Weather entity', exact=True)).to_be_visible()
        field('Weather entity').locator('select').select_option('weather.original')
        field('Location name').locator('input').fill('Custom city')
        save()
        # Entries sort by corner, so locate by type instead of display order.
        weather = next(w for w in json.loads(requests[-1]['screensaver.widgets']) if w['type'] == 'weather')
        assert weather['config']['entity'] == 'weather.original'
        assert weather['config']['name'] == 'State'
        assert weather['config']['label'] == 'Custom city'

        root.get_by_text('TEST Add widget', exact=True).click()
        field('Widget').locator('select').select_option('entity')
        page.get_by_role('button', name='TEST Choose', exact=True).click()
        page.get_by_placeholder('TEST Search by name or entity id').fill('Weather')
        page.locator('.modal-back').last.get_by_text('Weather', exact=True).click()
        expect(page.locator('.modal-back').get_by_text('Weather', exact=True)).to_be_visible()
        field('Displayed value').locator('select').select_option('humidity')
        field('Name').locator('input').fill('My entity')
        save()
        entity = next(w for w in json.loads(requests[-1]['screensaver.widgets']) if w['type'] == 'entity')
        assert entity['config']['entity'] == 'sensor.original'
        assert entity['config']['attribute'] == 'humidity'
        assert entity['config']['name'] == 'Weather'
        assert entity['config']['label'] == 'My entity'

        root.get_by_text('TEST Add widget', exact=True).click()
        field('Widget').locator('select').select_option('battery')
        expect(page.get_by_text('TEST Only when low', exact=True)).to_be_visible()
        save()
        assert len(json.loads(requests[-1]['screensaver.widgets'])) == 4

        open_page('At a Glance')
        expect(page.locator('#pageTitle')).to_contain_text('TEST At a Glance')
        root.get_by_role('button', name='TEST Choose', exact=True).click()
        expect(page.get_by_text('TEST Showing', exact=True)).to_be_visible()
        page.get_by_role('button', name='TEST Edit', exact=True).first.click()
        field('Name').locator('input').fill('My glance')
        field('Displayed value').locator('select').select_option('')
        page.get_by_role('button', name='TEST Save', exact=True).last.click()
        page.get_by_role('button', name='TEST Move down', exact=True).first.click()
        save()
        chosen = json.loads(requests[-1]['screensaver.glance_entities'])
        assert chosen == [{'entity_id': 'sensor.second', 'name': 'State'},
                          {'entity_id': 'sensor.raw', 'name': 'Weather', 'custom_name': 'My glance'}]

        root.get_by_role('button', name='TEST Choose', exact=True).click()
        fail_search = True
        page.get_by_placeholder('TEST Search by name or entity id').fill('error')
        expect(page.get_by_text('TEST Could not reach Home Assistant', exact=True)).to_be_visible()
        page.get_by_role('button', name='TEST Cancel', exact=True).click()
        assert not errors, errors
        browser.close()
finally:
    server.shutdown()
print('Screensaver overlay localization browser checks passed')
