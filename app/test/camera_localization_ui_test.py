"""Camera translation keeps protocols, stream addresses and hardware values intact."""
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
translated = {k: 'TEST ' + v for k, v in english.items()}
translated['cameraBack'] = 'TEST rear camera'
translated['commonBack'] = 'TEST go back'
settings = []
mapping = json.loads((APP / 'l10n/settings.json').read_text())
options = json.loads((APP / 'l10n/setting_options.json').read_text())


def setting(key, value, kind='string', **extra):
    row = dict(key=key, value=value, type=kind, category='Camera', title=key,
               description='', **extra)
    if key.startswith(('camera.rtsp.', 'camera.onvif.')):
        row['subpage'] = 'RTSP & ONVIF Streaming'
    if key in mapping:
        row.update(titleMessageId=mapping[key]['title'], descriptionMessageId=mapping[key]['description'])
    if key in options:
        row['optionMessageIds'] = options[key]
    settings.append(row)
    return row


setting('ui.language', 'es', hidden=True)
setting('camera.enabled', True, 'boolean')
setting('camera.device', 'back', 'select', options=['front', 'back'], optionLabels={'front':'Front', 'back':'Back'})
setting('camera.rtsp.enabled', True, 'boolean')
setting('camera.rtsp.protocol', 'rtsp', 'select', options=['rtsp', 'onvif'], optionLabels={'rtsp':'RTSP', 'onvif':'ONVIF'})
setting('camera.rtsp.port', 8554, 'number', dependsOn='camera.rtsp.protocol', dependsOnValue='rtsp')
setting('camera.onvif.port', 8080, 'number', dependsOn='camera.rtsp.protocol', dependsOnValue='onvif')
notice = ('Only sizes supported by the camera and H.264 encoder at the current streaming settings are listed. '
          'Turn off Motion analysis while streaming to also use 1920 × 1080. '
          'The encoder cannot use 3840 × 2160 at these settings.')
setting('camera.rtsp.resolution', '640x480', 'select', options=['640x480', '1280x720'],
        optionLabels={'640x480':'640 × 480', '1280x720':'1280 × 720'}, notice=notice)
setting('motion.sensor', True, 'boolean', subpage='Motion Sensor')
requests = []
status = dict(protocol='rtsp', encoding=True, clients=1, listening=True, resolution='640x480',
              resolutionFallback=True, requestedResolution='1280x720', captureResolution='640x480',
              audioEnabled=True, audioSuspended=True, urls=['rtsp://192.0.2.5:8554/live'],
              onvifUrls=['http://192.0.2.5:8080/onvif/device_service'],
              clientDetails=[dict(id='raw-id', ip='192.0.2.8', userAgent='Streaming',
                                  transport='TCP', port=52341, playing=True, connectedSeconds=125)])


def api(route):
    path = route.request.url.split('/api/', 1)[1]
    if path == 'settings':
        if route.request.method == 'PATCH':
            values = route.request.post_data_json
            requests.append(values)
            if values.get('camera.rtsp.port') == 1:
                return route.fulfill(status=400, json={'error':'Enter a whole port number from 1024 to 65535.'})
            for item in settings:
                if item['key'] in values:
                    item['value'] = values[item['key']]
            if 'camera.rtsp.protocol' in values:
                status['protocol'] = values['camera.rtsp.protocol']
            return route.fulfill(json={'ok':True})
        return route.fulfill(json={'settings':settings, 'subpageHints':{}})
    if path == 'camera/snapshot':
        return route.fulfill(status=404, body='')
    name = path.removeprefix('commands/')
    if name == 'takeCameraSnapshot':
        return route.fulfill(json={'ok':False, 'error':'Snapshot failed: <img src=x onerror=alert(1)>'})
    data = {'getRtspStatus':status, 'getVisionSupport':{'faces':True, 'hands':True},
            'hasDeviceCamera':True, 'getCameraFacings':['front','back'],
            'getSystemPermissions':{'camera':False},
            'listPlugins':[], 'listFiles':[], 'mediaPlayers':{'players':[]},
            'getAudioDevices':{'inputs':[], 'outputs':[]}}.get(name,{})
    route.fulfill(json={'ok':True, 'data':data})


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass


server = ThreadingHTTPServer(('127.0.0.1',0), partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True,args=['--no-sandbox'])
        page = browser.new_page(viewport={'width':1200,'height':1500})
        errors = []
        page.on('pageerror',lambda e: errors.append(str(e)))
        html = (ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda route:route.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda route:route.fulfill(
            body='export const catalogs = '+json.dumps({'en':english,'es':translated})+';',content_type='text/javascript'))
        page.route('**/api/**',api)
        page.goto(base+'/')
        page.evaluate("""async()=>{
          (await import('/static/core.js')).showView('app');
          await (await import('/static/settings.js')).loadSettings();
          (await import('/static/tabs.js')).showTab('camera',{refresh:false});
        }""")
        root = page.locator('#tab-camera')
        expect(root.locator('[data-key="camera.device"] option:checked')).to_have_text('TEST rear camera')
        expect(root.get_by_text('TEST Camera permission missing',exact=True)).to_be_visible()
        root.get_by_role('button',name='TEST Take snapshot',exact=True).click()
        expect(root.get_by_text('TEST Snapshot failed: <img src=x onerror=alert(1)>',exact=True)).to_be_visible()
        assert root.locator('img[src="x"]').count() == 0
        root.locator('[data-subpage-entry="RTSP & ONVIF Streaming"]').click()
        expect(page.locator('#pageTitle')).to_contain_text('TEST RTSP & ONVIF Streaming')
        expect(root.get_by_text('rtsp://192.0.2.5:8554/live',exact=True)).to_be_visible()
        expect(root.get_by_text('TEST 1 connected viewer. Actual video: 640x480.',exact=False)).to_be_visible()
        expect(root.get_by_text('TEST Requested 1280x720, camera supplied 640x480.',exact=False)).to_be_visible()
        expect(root.get_by_text('TEST Audio paused while the browser uses the microphone.',exact=False)).to_be_visible()
        expect(root.get_by_text('TEST Turn off Motion analysis while streaming to also use 1920 × 1080.',exact=False)).to_be_visible()
        expect(root.get_by_text('TEST The encoder cannot use 3840 × 2160 at these settings.',exact=False)).to_be_visible()
        expect(root.locator('.rtsp-client .name')).to_have_text('192.0.2.8')
        expect(root.locator('.rtsp-client .desc')).to_contain_text('Streaming\nTEST TEST Streaming · TCP · Port 52341')
        expect(root.locator('.rtsp-client .desc')).to_contain_text('TEST Connected for TEST 2m 5s')
        with page.expect_response('**/api/settings'):
            root.locator('[data-key="camera.rtsp.resolution"] select').select_option('1280x720')
        assert requests[-1] == {'camera.rtsp.resolution':'1280x720'}
        port = root.locator('[data-key="camera.rtsp.port"] input')
        port.fill('1')
        port.press('Tab')
        expect(root.locator('[data-key="camera.rtsp.port"] .row-error')).to_contain_text('TEST Enter a whole port number from 1024 to 65535.')
        with page.expect_response('**/api/settings'):
            port.fill('8555')
            port.press('Tab')
        with page.expect_response('**/api/settings'):
            root.locator('[data-key="camera.rtsp.protocol"] select').select_option('onvif')
        expect(root.get_by_text('http://192.0.2.5:8080/onvif/device_service',exact=True)).to_be_visible()
        assert requests[-1] == {'camera.rtsp.protocol':'onvif'}
        result = page.evaluate("""async () => {
          const l = await import('/static/localization.js');
          return l.cameraResolutionNotice('Motion detection, face detection and hand gestures pause while viewers are connected. Snapshots use video frames at the streaming resolution. 6 camera sizes are excluded because the encoder cannot use them at these settings.');
        }""")
        assert result.startswith('TEST Motion detection, face detection and hand gestures pause')
        assert 'TEST 6 camera sizes are excluded' in result
        assert not errors,errors
        browser.close()
finally:
    server.shutdown()
print('Camera localization browser checks passed')
