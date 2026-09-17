"""Remaining Media Player settings and overview keep values and commands stable."""
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

mapping = json.loads((APP / 'l10n/settings.json').read_text())
options = json.loads((APP / 'l10n/setting_options.json').read_text())
settings = [dict(key='ui.language', value='es', category='Device', type='string', hidden=True)]
def setting(key, value, kind='string', **extra):
    ids = mapping.get(key, {})
    row = dict(key=key, value=value, type=kind, category='Sendspin',
        title=english.get(ids.get('title'), key), description=english.get(ids.get('description'),''),
        titleMessageId=ids.get('title'), descriptionMessageId=ids.get('description'), **extra)
    if key in options: row['optionMessageIds'] = options[key]
    settings.append(row)
setting('sendspin.player_source','ma','select', options=['','ha','ma','sonos'],
        optionLabels={'':'This device','ha':'Home Assistant','ma':'Music Assistant','sonos':'Sonos'})
setting('sendspin.player','')
setting('sendspin.player_name','',hidden=True)
setting('sendspin.player_active',True,'boolean',hidden=True)
setting('sendspin.duck_percent',10,'number',min=0,max=25,step=5,unit='%')
setting('sendspin.ma_url','https://ma.example:8095',subpage='Music Assistant',section='Music Assistant')
setting('sendspin.ma_token','__set__','password',subpage='Music Assistant',section='Music Assistant')
setting('sendspin.enabled',False,'boolean',subpage='Sendspin Player',section='Sendspin Player')
setting('sendspin.codec','flac','select',subpage='Sendspin Player',section='Sendspin Player',
        options=['flac','opus','pcm'],optionLabels={'flac':'FLAC (lossless)','opus':'Opus (efficient)','pcm':'PCM (uncompressed)'})

setting('sendspin.show_player',True,'boolean',subpage='Floating Player',section='Floating Player')
setting('sendspin.player_size','compact','select',subpage='Floating Player',section='Floating Player',
        options=['compact','large'],optionLabels={'compact':'Compact','large':'Large with controls'})
setting('sendspin.fullscreen',True,'boolean',subpage='Now Playing',section='Screensaver')
setting('sendspin.fullscreen_photo_fill','always','select',subpage='Now Playing',section='Screensaver',
        options=['default','off','smart','always'],optionLabels={'default':'Default','off':'Off','smart':'Smart','always':'Always'})
setting('sendspin.fullscreen_text_scale',100,'number',subpage='Now Playing',section='User Interface',min=50,max=200,step=5,unit='%')
setting('sendspin.lyrics_enabled',True,'boolean',subpage='Lyrics',section='Lyrics')
setting('sendspin.lyrics_source','lrclib','select',subpage='Lyrics',section='Lyrics',
        options=['lrclib','ma'],optionLabels={'lrclib':'LRCLIB','ma':'Music Assistant'})
setting('sendspin.lyrics_offset',0.3,'number',subpage='Lyrics',section='Lyrics',min=-3,max=3,step=0.1,unit='s')
playback = dict(enabled=True,playing=True,title='Play <img src=x> {status}',artist='Lyrics',
                album='Now playing',serverName='Raw server',supportedCommands=['pause','play','next','previous'])
control_requests = []
control_error = False
players = [dict(id='ma:raw-id',name='Offline <img src=x> {player}',group='ma',available=False)]
requests = []
validation = {'ok':True,'data':{'version':'2.9.0'}}
cache = {'bytes':1024,'maxBytes':1048576}
def api(route):
    path = route.request.url.split('/api/',1)[1]
    if path == 'settings':
        if route.request.method == 'PATCH':
            values = route.request.post_data_json
            requests.append(values)
            for item in settings:
                if item['key'] in values: item['value'] = values[item['key']]
            return route.fulfill(json={'ok':True})
        return route.fulfill(json={'settings':settings,'subpageHints':{
            'Sendspin Player':'Make this device a synchronized Music Assistant player',
            'Music Assistant':'Server, token, kiosk menu shortcut'}})
    name = path.removeprefix('commands/')
    if name == 'sendspinControl':
        control_requests.append(route.request.post_data_json)
        if control_error:return route.fulfill(json={'ok':False,'error':'command not supported or not sent'})
    if name == 'maValidate': return route.fulfill(json=validation)
    if name == 'clearAlbumArtCache': cache['bytes'] = 0
    data = {'sendspinStatus':playback, 'mediaPlayers':{'players':players,'notes':{}},'albumArtCacheStats':cache,'clearAlbumArtCache':cache,
        'listPlugins':[],'listFiles':[],'getAudioDevices':{'inputs':[],'outputs':[]}}.get(name,{})
    route.fulfill(json={'ok':True,'data':data})

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
          (await import('/static/tabs.js')).showTab('sendspin',{refresh:false});
        }""")


        root = page.locator('#tab-sendspin')
        root.locator('[data-subpage-entry="Floating Player"]').click()
        expect(page.locator('#pageTitle')).to_contain_text('TEST Floating Player')
        size = root.locator('[data-key="sendspin.player_size"] select')
        expect(size.locator('option:checked')).to_have_text('TEST Compact')
        with page.expect_response('**/api/settings'):
            size.select_option('large')
        assert requests[-1] == {'sendspin.player_size':'large'}
        page.evaluate("async()=>(await import('/static/tabs.js')).showTab('sendspin',{refresh:false})")
        root.locator('[data-subpage-entry="Now Playing"]').click()
        expect(page.locator('#pageTitle')).to_contain_text('TEST Now Playing')
        fill = root.locator('[data-key="sendspin.fullscreen_photo_fill"] select')
        expect(fill.locator('option[value="smart"]')).to_have_text('TEST Smart')
        with page.expect_response('**/api/settings'):
            fill.select_option('smart')
        assert requests[-1] == {'sendspin.fullscreen_photo_fill':'smart'}
        page.evaluate("async()=>(await import('/static/tabs.js')).showTab('sendspin',{refresh:false})")
        root.locator('[data-subpage-entry="Lyrics"]').click()
        expect(page.locator('#pageTitle')).to_contain_text('TEST Lyrics')
        lyric_source = root.locator('[data-key="sendspin.lyrics_source"] select')
        expect(lyric_source.locator('option[value="ma"]')).to_have_text('Music Assistant')
        with page.expect_response('**/api/settings'):
            lyric_source.select_option('ma')
        assert requests[-1] == {'sendspin.lyrics_source':'ma'}
        for language in ['en','es']:
            settings[0]['value'] = language
            page.evaluate("async()=>await (await import('/static/settings.js')).loadSettings()")
            expect(lyric_source).to_have_value('ma')
            expect(fill).to_have_value('smart')
            expect(size).to_have_value('large')
        page.evaluate("""async()=>{
          (await import('/static/tabs.js')).showTab('dashboard',{refresh:false});
          await (await import('/static/overview.js')).initOverview();
        }""")
        expect(page.locator('#npTitle')).to_have_text('TEST Now playing')
        expect(page.locator('#npTrack')).to_have_text('Play <img src=x> {status}')
        expect(page.locator('#npArtist')).to_have_text('Lyrics · Now playing')
        expect(page.locator('#npPlay')).to_have_attribute('aria-label','TEST Pause')
        expect(page.locator('[data-status="media"] .s-sub')).to_have_text('TEST TEST Playing - Raw server')
        page.locator('#npPlay').click()
        assert control_requests[-1] == {'command':'pause'}
        playback['playing'] = False
        playback['playbackState'] = 'paused'
        page.evaluate("async()=>await (await import('/static/overview.js')).refreshHealth()")
        expect(page.locator('#npPlay')).to_have_attribute('aria-label','TEST Play')
        control_error = True
        page.locator('#npCard [data-np="next"]').click()
        expect(page.get_by_text('TEST command not supported or not sent',exact=True)).to_be_visible()
        assert control_requests[-1] == {'command':'next'}
        settings[0]['value'] = 'en'
        page.evaluate("""async()=>{
          await (await import('/static/settings.js')).loadSettings();
          await (await import('/static/overview.js')).refreshHealth();
        }""")
        expect(page.locator('#npTitle')).to_have_text('Now playing')
        expect(page.locator('#npPlay')).to_have_attribute('aria-label','Play')
        expect(page.locator('#npTrack')).to_have_text('Play <img src=x> {status}')
        assert page.locator('img[src="x"]').count()==0
        gestures = page.evaluate("""async()=>{
          const l = await import('/static/localization.js');
          const g = await import('/static/gestures.js');
          l.setLanguagePreference('es');
          return ['now_playing','sendspin_player','music_assistant'].map(type=>g.describeGestureAction({type}));
        }""")
        assert gestures == ['TEST Show Now Playing','TEST Show the floating player','TEST Open Music Assistant']
        assert not errors,errors
        browser.close()
finally:
    server.shutdown()
print('Remaining Media Player localization browser checks passed')
