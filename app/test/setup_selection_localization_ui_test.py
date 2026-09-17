"""Translated setup keeps dashboard routes, satellite IDs and recommendation keys."""
import json
import os
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
ids = json.loads((APP / 'l10n/setup_text.json').read_text())
commands = []
patches = []
vs = True
satellites = [dict(entity_id='assist_satellite.first', name='Apply all recommended settings'), dict(entity_id='assist_satellite.second', name='<b>Original satellite</b>')]
views = [dict(title='Choose a view', route='original'), dict(title='<b>Original view</b>', route='second')]

def api(route):
    path = route.request.url.split('/api/', 1)[1]
    params = route.request.post_data_json or {}
    if path == 'settings':
        patches.append(params)
        return route.fulfill(json=dict(ok=True))
    name = path.removeprefix('commands/')
    commands.append((name, params))
    result = {'haListDashboardViews': views, 'haDetectVoiceSatellite': vs, 'haListVoiceSatellites': satellites, 'getSystemPermissions': {}}.get(name, {})
    route.fulfill(json=dict(ok=True, data=result))

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass

server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport=dict(width=1200, height=1200))
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        html = (ROOT / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
        page.route(base + '/', lambda r: r.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda r: r.fulfill(body='export const catalogs = ' + json.dumps({'en': english, 'es': translated}) + ';', content_type='text/javascript'))
        page.route('**/api/**', api)
        page.goto(base + '/')
        page.evaluate("""async views => {
          const c=await import('/static/core.js');c.showView('wizard');
          (await import('/static/localization.js')).setLanguagePreference('es');
          const {wizard}=await import('/static/app.js');
          Object.assign(wizard,{i:2,base:'http://ha.example',dashboard:'raw-dashboard',dashboardView:'original',dashboardViews:views,
            dashboards:[{url_path:'raw-dashboard',title:'Choose a dashboard'},{url_path:'other-dashboard',title:'<b>Original dashboard</b>'}]});
          const w=await import('/static/wizard.js');wizard.steps=w.wizardSteps();w.wizardRender();
        }""", views)
        root = page.locator('#wizardBody')
        def label(en): return translated[ids[en]]
        def state(): return page.evaluate("async()=>{const {wizard:w}=await import('/static/app.js');return {dashboard:w.dashboard,view:w.dashboardView,satellite:w.satellite,rec:w.rec};}")
        def language(value):
            page.evaluate("async language=>{(await import('/static/localization.js')).setLanguagePreference(language);const {wizard}=await import('/static/app.js');const w=await import('/static/wizard.js');wizard.steps=w.wizardSteps();w.wizardRender();}", value)
        expect(page.locator('#wizardTitle')).to_have_text(label('Choose a dashboard'))
        expect(root.get_by_text('Choose a dashboard', exact=True)).to_be_visible()
        root.get_by_role('button', name=label('Change view'), exact=True).click()
        modal = page.locator('.modal-back')
        expect(modal.locator('.modal-title')).to_have_text(label('Choose a view'))
        expect(modal.get_by_text('Choose a view', exact=True)).to_be_visible()
        modal.get_by_text('<b>Original view</b>', exact=True).click()
        assert state()['view'] == 'second'
        before = len(commands)
        language('en'); expect(page.locator('#wizardTitle')).to_have_text('Choose a dashboard')
        language('es'); expect(page.locator('#wizardTitle')).to_have_text(label('Choose a dashboard'))
        assert state()['view'] == 'second'
        assert len(commands) == before
        with page.expect_response('**/api/commands/haListDashboardViews'):
            root.get_by_text('<b>Original dashboard</b>', exact=True).click()
        expect(root.get_by_text('other-dashboard/original', exact=True)).to_be_visible()
        assert ('haListDashboardViews', dict(url_path='other-dashboard')) in commands
        assert root.locator('b').count() == 0
        page.locator('#wizardNext').click()
        expect(page.locator('#wizardTitle')).to_have_text(label('Voice Satellite detected'))
        expect(root.get_by_text('Apply all recommended settings', exact=True)).to_be_visible()
        assert root.locator('input:disabled').count() == 2
        root.get_by_text('<b>Original satellite</b>', exact=True).click()
        master = root.locator('.row').filter(has=page.get_by_text(label('Apply all recommended settings'), exact=True))
        master.locator('label.switch').click()
        assert not any(state()['rec'].values())
        target = root.locator('.row').filter(has=page.get_by_text(label('Keep listening in the background'), exact=True))
        target.locator('label.switch').click()
        assert state()['rec']['wake_word.background'] is True
        selected = state()
        language('en'); language('es')
        assert state() == selected
        assert not patches
        assert root.locator('b').count() == 0
        page.set_viewport_size(dict(width=390, height=1000))
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        page.locator('#wizardBack').click()
        expect(page.locator('#wizardTitle')).to_have_text(label('Choose a dashboard'))
        page.locator('#wizardNext').click()
        expect(page.locator('#wizardTitle')).to_have_text(label('Voice Satellite detected'))
        assert state()['satellite'] == 'assist_satellite.second'
        assert state()['rec'] == selected['rec']
        # Empty data and a skipped integration keep translated guidance.
        page.evaluate("async()=>{const {wizard:w}=await import('/static/app.js');w.i=2;w.dashboards=[];w.dashboard=null;(await import('/static/wizard.js')).wizardRender();}")
        expect(root).to_contain_text(label('No dashboards found'))
        before = len(commands)
        page.locator('#wizardNext').click()
        expect(page.locator('#wizardError')).to_contain_text(label('Select a dashboard'))
        assert len(commands) == before
        page.evaluate("async()=>{const {wizard:w}=await import('/static/app.js');w.i=3;w.satellites=[];(await import('/static/wizard.js')).wizardRender();}")
        expect(root).to_contain_text(label('No satellites found'))
        expect(root).to_contain_text(label('Add an assist satellite in the Voice Satellite integration, or continue without one and pick it on the dashboard later.'))
        page.evaluate("async()=>{const {wizard:w}=await import('/static/app.js');w.i=4;w.vsDetected=false;(await import('/static/wizard.js')).wizardRender();}")
        expect(page.locator('#wizardStepsRail')).to_contain_text(label('Not installed, skipped'))
        page.evaluate("async()=>{const {wizard:w}=await import('/static/app.js');w.vsDetected=true;w.dashboard='other-dashboard';}")
        # Check the existing final-step write without resetting a real device.
        page.route(base + '/', lambda r: r.fulfill(body='<p>Setup complete</p>', content_type='text/html'))
        with page.expect_navigation():
            page.evaluate("async()=>{const {wizard}=await import('/static/app.js');await wizard.steps.at(-1).next();}")
        chosen, start = patches[-2:]
        assert chosen['ha.satellite_entity'] == 'assist_satellite.second'
        assert chosen['web.microphone'] is True and chosen['wake_word.enabled'] is True
        assert {k:chosen[k] for k in selected['rec']} == selected['rec']
        assert start == {'browser.start_url':'http://ha.example/other-dashboard/original'}
        assert not errors, errors
        browser.close()
    print('Setup dashboard and Voice Satellite browser checks passed')
finally:
    server.shutdown()
