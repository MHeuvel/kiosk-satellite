"""Translate connection notices without changing authentication or recovery timing."""
import json
import os
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k:v for p in (APP/'l10n/source').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
spanish = {k:'TEST '+v for k,v in english.items()}
if os.environ.get('KS_TEST_SPANISH'):
    spanish = {k:v for p in (APP.parents[1]/'kiosk-satellite-localization/translations/es').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
setup = dict(setupNeeded=False, passwordNeeded=False, language='es')
login_status = 401
head_status = 200
requests = []
def api(route):
    path = route.request.url.split('/api/',1)[1]
    requests.append((path,route.request.post_data))
    if path == 'setup/status': return route.fulfill(json=setup)
    if path == 'login': return route.fulfill(status=login_status,json=dict(token='fixture-token'))
    if path == 'commands': return route.fulfill(status=head_status,body='')
    if path == 'setup/grants': return route.fulfill(json=dict(permissions={},grants={}))
    return route.fulfill(json=dict(ok=True,data={}))
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*_): pass
server = ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start()
base=f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox'])
        page=browser.new_page(viewport=dict(width=390,height=850),locale='en-US')
        errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda r:r.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda r:r.fulfill(body='export const catalogs = '+json.dumps(dict(en=english,es=spanish))+';',content_type='text/javascript'))
        page.route('**/api/**',api)
        page.add_init_script("""window.sockets=[];window.WebSocket=class {
          static OPEN=1;static CONNECTING=0;static CLOSED=3;
          constructor(url){this.url=url;this.readyState=0;window.sockets.push(this)}
          send(data){(this.sent??=[]).push(JSON.parse(data))}
          open(){this.readyState=1;this.onopen?.()}
          close(){this.readyState=3;return this.onclose?.({code:1006})}
        };""")
        page.goto(base+'/')
        page.evaluate("import('/static/main.js')")
        expect(page.locator('#login')).to_be_visible()
        expect(page.locator('#loginBtn')).to_have_text(spanish['remoteLogin'])
        expect(page.locator('#password')).to_have_attribute('placeholder',spanish['settingRemotePasswordTitle'])
        expect(page.locator('#password')).to_have_attribute('aria-label',spanish['settingRemotePasswordTitle'])
        expect(page.locator('#loginHeading')).to_have_text(spanish['setupRemoteHeading'])
        password=' Mi contraseña <Raw> '
        page.locator('#password').fill(password)
        page.locator('#loginBtn').click()
        expect(page.locator('#loginError')).to_have_text(spanish['remoteInvalidPassword'])
        assert json.loads([body for path,body in requests if path=='login'][-1])==dict(password=password)
        login_status=429
        page.locator('#password').press('Enter')
        expect(page.locator('#loginError')).to_have_text(spanish['remoteLoginThrottled'])
        expect(page.locator('#password')).to_have_value(password)
        page.evaluate("async()=>{const c=await import('/static/core.js');c.state.token='old';c.logout()}")
        expect(page.locator('#loginBtn')).to_have_text(spanish['remoteLogin'])
        expect(page.locator('#password')).to_have_value(password)
        assert page.evaluate("localStorage.getItem('ks_token')") is None
        # Successful authentication follows the existing setup decision.
        login_status=200;setup.update(setupNeeded=True)
        page.locator('#loginBtn').click()
        expect(page.locator('#wizard')).to_be_visible()
        assert page.evaluate("localStorage.getItem('ks_token')")=='fixture-token'
        assert not errors,errors
        # Fresh page: no automatic boot, and controllable connection failures.
        setup.update(setupNeeded=False)
        page.reload();page.clock.install()
        page.evaluate("""async()=>{const c=await import('/static/core.js');c.state.token='fixture-token';c.state.device={name:'<b>Kiosko Uno</b>'};c.showView('app');(await import('/static/localization.js')).setLanguagePreference('es');(await import('/static/ws.js')).connectWs();window.sockets[0].open();await window.sockets[0].close()}""")
        reconnect=page.locator('.reconnect-back')
        expect(reconnect.locator('.modal-title')).to_have_text(spanish['remoteReconnecting'])
        expect(reconnect).to_contain_text('<b>Kiosko Uno</b>')
        assert reconnect.locator('b').count()==0
        expect(reconnect.locator('button')).to_be_hidden()
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        page.clock.run_for(19000)
        expect(reconnect.locator('button')).to_be_hidden()
        # Translating the open notice must not restart its 20-second timer.
        page.evaluate("async()=>{(await import('/static/localization.js')).setLanguagePreference('en');document.dispatchEvent(new CustomEvent('ks-settings-cached'))}")
        expect(reconnect.locator('.modal-title')).to_have_text(english['remoteReconnecting'])
        page.clock.run_for(2000)
        expect(reconnect.locator('button')).to_be_visible()
        page.evaluate("async()=>{(await import('/static/localization.js')).setLanguagePreference('es');document.dispatchEvent(new CustomEvent('ks-settings-cached'))}")
        expect(reconnect.locator('button')).to_have_text(spanish['remoteReloadPage'])
        page.evaluate('window.sockets.at(-1).open()')
        expect(reconnect).to_have_count(0)
        # No name uses a complete sentence, without inserting English fallback words.
        page.evaluate("async()=>{(await import('/static/core.js')).state.device={};await window.sockets.at(-1).close()}")
        expect(reconnect.locator('.reconnect-text')).to_have_text(spanish['remoteConnectionLostUnnamed'])
        page.clock.run_for(2000)
        page.evaluate('window.sockets.at(-1).open()')
        head_status=401
        page.evaluate('window.sockets.at(-1).close()')
        expect(page.locator('#login')).to_be_visible()
        expect(reconnect).to_have_count(0)
        expect(page.locator('#loginBtn')).to_have_text(spanish['remoteLogin'])
        assert page.evaluate("localStorage.getItem('ks_token')") is None
        head_status=200
        # An update retains literal version data and the five-second reload.
        page.evaluate("async()=>{(await import('/static/ws.js')).showVersionMismatch({appVersion:'<b>2026.TEST</b>',buildNumber:259})}")
        notice=page.locator('.modal-card')
        expect(notice.locator('.modal-title')).to_have_text(spanish['remoteUpdated'])
        expect(notice).to_contain_text('<b>2026.TEST</b>')
        expect(notice).to_contain_text('259')
        assert notice.locator('b').count()==0
        expect(notice).to_contain_text('5 s.')
        page.clock.run_for(2000)
        page.evaluate("async()=>{(await import('/static/localization.js')).setLanguagePreference('en')}")
        page.clock.run_for(1000)
        expect(notice.locator('.modal-title')).to_have_text(english['remoteUpdated'])
        expect(notice).to_contain_text('2 s.')
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        with page.expect_navigation():page.clock.run_for(2000)
        expect(page.locator('.modal-card')).to_have_count(0)
        # A failed setup-status read falls back to English without blocking login.
        page.route('**/api/setup/status',lambda r:r.abort())
        page.evaluate("localStorage.removeItem('ks_token')")
        page.evaluate("import('/static/main.js')")
        expect(page.locator('#loginBtn')).to_have_text(english['remoteLogin'])
        expect(page.locator('#login')).to_be_visible()
        assert not errors,errors
        browser.close()
    print('Connection localization browser checks passed')
finally:server.shutdown()
