"""Verify localized audio choices preserve hardware selectors and channel numbers."""
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
spanish = {'screenAudioAutomatic': 'TEST automatic', 'screenAudioDevices': 'TEST devices',
 'screenAudioDownmix': 'TEST downmix', 'screenAudioChannel': 'TEST channel {channel}',
 'screenAudioChannelMissing': 'TEST missing {channel}', 'screenAudioDisconnected': '{name} TEST disconnected',
 'screenAudioMicrophoneSettings': 'TEST microphone settings', 'screenAudioMicrophoneLevel': 'TEST meter',
 'screenAudioNoSensor': 'TEST no sensor', 'screenAudioAlwaysOnClock': 'TEST always on',
 'screenAudioBrightnessFallback': 'TEST fallback', 'screenAudioLuxLast': '{lux} TEST last lux',
 'settingAdaptiveBrightnessTitle': 'TEST adaptive', 'screenAudioReversePortrait': 'TEST reverse portrait'}
settings = []
def setting(key, value, kind='boolean', subpage=None, **extra):
 settings.append(dict(key=key, value=value, type=kind, category='Screen & Audio', title=key,
 description='', **({'subpage': subpage} if subpage else {}), **extra))
setting('ui.language', 'es', 'select', hidden=True)
setting('wake_word.enabled', True, hidden=True)
setting('screen.keep_on', True, section='Screen')
setting('screen.orientation', 'auto', 'select', section='Screen',
 options=['auto','reverse_portrait'], optionLabels={'auto':'Automatic','reverse_portrait':'Reverse portrait'},
 optionMessageIds={'auto':'screenAudioAutomatic','reverse_portrait':'screenAudioReversePortrait'})
setting('screen.adaptive_brightness', True, subpage='Adaptive brightness', titleMessageId='settingAdaptiveBrightnessTitle')
setting('screen.default_brightness', .5, 'number', section='Screen', min=0, max=1)
setting('audio.media_volume', .5, 'number', section='Audio Volume', min=0, max=1)
setting('audio.mic_source', 'voice_communication', 'select', 'Microphone settings', options=['voice_communication'])
setting('audio.mic_channel', 5, 'number', hidden=True)
setting('audio.mic_device', 'usb|1|Microphone', 'string', hidden=True)
setting('audio.speaker_device', 'usb|2|Speaker', 'string', hidden=True)
requests=[]
def api(route):
 path=route.request.url.split('/api/',1)[1]
 if path=='settings':
  if route.request.method=='PATCH':
   values=route.request.post_data_json;requests.append(('settings',values))
   for item in settings:
    if item['key'] in values:item['value']=values[item['key']]
   return route.fulfill(json={'ok':True})
  return route.fulfill(json={'settings':settings,'subpageHints':{}})
 name=path.removeprefix('commands/');args=route.request.post_data_json or {};requests.append((name,args))
 data={'getVolume':50, 'getLightLevel':{'present':True,'lux':12,'live':False},
 'getAmbientDisplay':True,'getSystemPermissions':{'writeSettings':False},
 'getAudioDevices':{'inputs':[{'selector':'usb|1|Microphone','label':'Automatic','channels':2}],
 'outputs':[], 'micSelected':'usb|1|Microphone','speakerSelected':'usb|2|Speaker'},
 'listPlugins':[], 'listFiles':[], 'mediaPlayers':{'players':[]}}.get(name,{})
 route.fulfill(json={'ok':True,'data':data})
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1200, 'height': 1000})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        html = (ROOT / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
        page.route(base+'/', lambda route: route.fulfill(body=html, content_type='text/html'))
        page.route('**/static/catalogs.js', lambda route: route.fulfill(
            body='export const catalogs = '+json.dumps({'en': english, 'es': spanish})+';', content_type='text/javascript'))
        page.route('**/api/**', api)
        page.goto(base+'/')
        page.evaluate("""async () => {
          (await import('/static/core.js')).showView('app');
          await (await import('/static/settings.js')).loadSettings();
          (await import('/static/tabs.js')).showTab('screenaudio', {refresh:false});
        }""")
        root = page.locator('#tab-screenaudio')
        expect(root.get_by_text('TEST devices', exact=True)).to_be_visible()
        expect(root.get_by_text('TEST always on', exact=True)).to_be_visible()
        expect(root.get_by_text('TEST fallback', exact=True)).to_be_visible()
        speaker=root.locator('[data-key="audio.speaker_device"] select')
        expect(speaker).to_have_value('usb|2|Speaker')
        expect(speaker.locator('option:checked')).to_have_text('Speaker TEST disconnected')
        mic=root.locator('[data-key="audio.mic_device"] select')
        expect(mic.locator('option:checked')).to_have_text('Automatic')
        expect(mic.locator('option').first).to_have_text('TEST automatic')
        orientation=root.locator('[data-key="screen.orientation"] select')
        orientation.select_option(label='TEST reverse portrait')
        page.wait_for_function("document.querySelector('[data-key=\"screen.orientation\"] select').value === 'reverse_portrait'")
        assert ('settings',{'screen.orientation':'reverse_portrait'}) in requests
        root.locator('[data-subpage-entry="Microphone settings"]').click()
        expect(page.locator('#pageTitle')).to_contain_text('TEST microphone settings')
        expect(root.get_by_text('TEST meter',exact=True)).to_be_visible()
        channel=root.locator('[data-key="audio.mic_channel"] select')
        expect(channel.locator('option:checked')).to_have_text('TEST missing 5')
        channel.select_option(label='TEST channel 2')
        page.wait_for_timeout(200)
        assert ('settings',{'audio.mic_channel':2}) in requests
        awaitable="""async () => {
          const tabs=await import('/static/tabs.js'); tabs.showTab('screenaudio', {refresh:false});
        }"""
        page.evaluate(awaitable)
        root.locator('[data-subpage-entry="Adaptive brightness"]').click()
        expect(page.locator('#pageTitle')).to_contain_text('TEST adaptive')
        expect(root.get_by_text('12 TEST last lux',exact=True)).to_be_visible()
        assert page.evaluate("(async () => (await import('/static/search.js')).searchSettingsIndex('TEST microphone settings').some(row => row.entry === 'Microphone settings'))()")
        page.evaluate("""async () => {
          (await import('/static/core.js')).state.lightSensor=false;
          await (await import('/static/notices.js')).updateAdaptiveBrightnessRows();
        }""")
        expect(root.get_by_text('TEST no sensor',exact=True)).to_be_visible()
        assert not errors, errors
        browser.close()
finally:
    server.shutdown()
print('Screen & Audio localization browser checks passed')
