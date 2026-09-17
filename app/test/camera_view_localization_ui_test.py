"""Camera status changes language without restarting transports or changing names."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'assets/camera-view'
source = json.loads((APP / 'l10n/source/camera_view_status_en.arb').read_text())
messages = {key: 'TEST ' + value for key, value in source.items() if not key.startswith('@')}
config = dict(language='es', messages=messages, grid=8, showCameraNames=True, interactive=True,
    cameras=[dict(id=key, name=name, transports=transports) for key, name, transports in [
        ('login-raw', 'Camera view', ['webrtc']),
        ('missing-raw', '<img src=x onerror=alert(1)>', ['webrtc']),
        ('network-raw', 'Home Assistant', ['webrtc']),
        ('mjpeg-raw', 'MJPEG camera', ['mjpeg']),
        ('mse-raw', 'MSE camera', ['mse']),
        ('waiting-raw', 'Waiting camera', ['webrtc']),
        ('fallback-raw', 'Fallback camera', ['mse', 'webrtc']),
    ]])


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass


server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1280, 'height': 900})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.add_init_script('window.__ksCameraView = ' + json.dumps(config) + ';')
        page.add_init_script("""(() => {
          window.bridgeCalls = [];
          window.peerCreated = 0;
          window.peerClosed = 0;
          window.MediaSource = undefined;
          window.RTCPeerConnection = class {
            constructor() { window.peerCreated++; this.iceGatheringState = 'complete'; }
            addTransceiver() { return {}; }
            async createOffer() { return {type: 'offer', sdp: 'v=0\\r\\n'}; }
            async setLocalDescription(offer) { this.localDescription = offer; }
            close() { window.peerClosed++; }
          };
          window.flutter_inappwebview = {callHandler: async (name, args) => {
            bridgeCalls.push({name, args});
            if (name === 'cameraRtcConfig') {
              if (args.cameraId === 'waiting-raw') return new Promise(() => {});
              return null;
            }
            if (name === 'cameraOffer') return {ok: false, error: 'raw detail',
              ...(args.cameraId === 'network-raw' ? {kind: 'network'} :
                {kind: 'server', status: args.cameraId === 'login-raw' ? 401 : 404})};
            return {ok: false, error: 'raw detail'};
          }};
        })();""")
        page.goto(f'http://127.0.0.1:{server.server_port}/')
        def status(key): return page.locator(f'.tile[data-id="{key}"] .status')
        expect(status('login-raw')).to_have_text('TEST The camera server rejected the login. Retrying in 2s')
        expect(status('missing-raw')).to_have_text('TEST Stream not found on the camera server. Retrying in 2s')
        expect(status('network-raw')).to_have_text('TEST Cannot reach the camera server. Retrying in 2s')
        expect(status('mjpeg-raw')).to_have_text('TEST Cannot reach Home Assistant. Retrying in 2s')
        expect(status('mse-raw')).to_have_text('TEST This device cannot play MSE streams')
        expect(status('waiting-raw')).to_have_text('TEST Connecting...')
        expect(status('fallback-raw')).to_have_text('TEST Trying WebRTC...')
        expect(page.locator('.tile[data-id="missing-raw"] .name')).to_have_text('<img src=x onerror=alert(1)>')
        assert page.locator('img[src="x"]').count() == 0
        result = page.evaluate("""() => {
          const before = {created: peerCreated, closed: peerClosed, calls: bridgeCalls.length};
          const ids = [...sessions.keys()];
          const configBefore = JSON.stringify(CFG.cameras);
          window.ksSetMessages({}, 'en');
          const english = document.querySelector('.tile[data-id="waiting-raw"] .status').textContent;
          const title = document.title;
          setStatus('waiting-raw', viewStatus('cameraViewerCannotDecode', {codec: 'H.265 {seconds} <img src=x>'}));
          window.ksSetMessages({cameraViewerCannotDecode: 'TEST codec: {codec}'}, 'es');
          const codec = document.querySelector('.tile[data-id="waiting-raw"] .status').textContent;
          setStatus('mse-raw', '');
          window.ksSetMessages(CFG.messages, 'es');
          return {before, after: {created: peerCreated, closed: peerClosed, calls: bridgeCalls.length},
            ids, idsAfter: [...sessions.keys()], configBefore, configAfter: JSON.stringify(CFG.cameras),
            english, title, codec, lang: document.documentElement.lang,
            blank: document.querySelector('.tile[data-id="mse-raw"] .status').textContent};
        }""")
        assert result['before'] == result['after'], result
        assert result['ids'] == result['idsAfter']
        assert result['configBefore'] == result['configAfter']
        assert result['english'] == 'Connecting...'
        assert result['title'] == 'Camera view'
        assert result['codec'] == 'TEST codec: H.265 {seconds} <img src=x>'
        assert result['blank'] == '' and result['lang'] == 'es'
        assert not errors, errors
        page.evaluate('shutdown()')
        late = browser.new_page()
        late.goto(f'http://127.0.0.1:{server.server_port}/')
        # Older WebViews receive configuration after the page has loaded.
        late.evaluate('(config) => window.ksSetConfig(config)',
                      {'cameras': [], 'messages': messages, 'language': 'es'})
        expect(late).to_have_title('TEST Camera view')
        expect(late.locator('html')).to_have_attribute('lang', 'es')
        browser.close()
        print('Camera viewer localization browser checks passed')
finally:
    server.shutdown()
