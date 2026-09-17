"""Media setup keeps player identities, secrets and connection details unchanged."""
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
    if name == 'maValidate': return route.fulfill(json=validation)
    if name == 'clearAlbumArtCache': cache['bytes'] = 0
    data = {'mediaPlayers':{'players':players,'notes':{}},'albumArtCacheStats':cache,'clearAlbumArtCache':cache,
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
        expect(root.locator('.media-player-intro')).to_contain_text('TEST The floating player')
        picker = root.locator('[data-key="sendspin.player"] select')
        expect(picker.locator('option[value="ma:raw-id"]')).to_have_text('TEST Offline <img src=x> {player} (offline)')
        with page.expect_response('**/api/settings'):
            picker.select_option('ma:raw-id')
        assert requests[-1] == {'sendspin.player':'ma:raw-id',
            'sendspin.player_name':'Offline <img src=x> {player}', 'sendspin.player_active':True}
        expect(root.locator('.player-warn')).to_contain_text("TEST This device's own Sendspin player stays offline while Offline <img src=x> {player} is controlled.")
        expect(root.locator('[data-key="albumArtCache"] .desc')).to_have_text('TEST 1.0 KB used of 1.0 MB. Queue thumbnails are cached automatically.')
        root.locator('[data-key="albumArtCache"] button').click()
        expect(root.locator('[data-key="albumArtCache"] .desc')).to_have_text('TEST 0 B used of 1.0 MB. Queue thumbnails are cached automatically.')
        root.locator('[data-subpage-entry="Music Assistant"]').click()
        expect(root.locator('.ma-validate-row .name')).to_have_text('TEST Validate connection')
        root.locator('.ma-validate-row button').click()
        expect(root.locator('.ma-validate-row .desc')).to_have_text('TEST Connected to Music Assistant 2.9.0')
        validation = {'ok':False,'error':'Could not reach ma.example:8095: <img src=x> {error}'}
        root.locator('.ma-validate-row button').click()
        expect(root.locator('.ma-validate-row .desc')).to_have_text('TEST Could not reach ma.example:8095: <img src=x> {error}')
        for language in ['en','es']:
            settings[0]['value'] = language
            page.evaluate("async()=>{await (await import('/static/settings.js')).loadSettings(); (await import('/static/tabs.js')).showTab('sendspin',{refresh:false});}")
            expect(picker).to_have_value('ma:raw-id')
            expected = 'TEST ' if language == 'es' else ''
            expect(picker.locator('option:checked')).to_have_text(expected+'Offline <img src=x> {player} (offline)')
            root.locator('[data-subpage-entry="Sendspin Player"]').click()
            codec = root.locator('[data-key="sendspin.codec"] select')
            expect(codec.locator('option[value="flac"]')).to_have_text(expected+'FLAC (lossless)')
            with page.expect_response('**/api/settings'):
                codec.select_option('opus' if language == 'en' else 'pcm')
            assert requests[-1] == {'sendspin.codec':'opus' if language == 'en' else 'pcm'}
        assert next(s for s in settings if s['key']=='sendspin.ma_token')['value'] == '__set__'
        assert root.locator('img[src="x"]').count() == 0
        assert not errors, errors
        browser.close()
finally:
    server.shutdown()
print('Media connection localization browser checks passed')
