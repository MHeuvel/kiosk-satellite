"""Sonos translation preserves speaker names, addresses and IDs."""
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
settings = [dict(key='ui.language',value='es',category='Device',type='string',hidden=True)]
for key in ['sendspin.sonos_group_volume','sendspin.sonos_inputs']:
    ids = mapping[key]
    settings.append(dict(key=key,value=False,type='boolean',category='Sendspin',subpage='Sonos',section='Sonos',
        title=english[ids['title']],description=english[ids['description']],
        titleMessageId=ids['title'],descriptionMessageId=ids['description']))
speakers = []
requests = []
add_error = True
def api(route):
    global speakers
    path = route.request.url.split('/api/',1)[1]
    if path == 'settings':
        if route.request.method == 'PATCH':
            values = route.request.post_data_json
            requests.append(('settings',values))
            for item in settings:
                if item['key'] in values:item['value'] = values[item['key']]
            return route.fulfill(json={'ok':True})
        return route.fulfill(json={'settings':settings,'subpageHints':{'Sonos':'Speakers on the network, add one by address'}})
    name = path.removeprefix('commands/')
    values = route.request.post_data_json
    requests.append((name,values))
    if name == 'sonosAdd':
        if add_error:return route.fulfill(json={'ok':False,'error':'No Sonos answered at <raw-host> {host}.'})
        speakers = [{'id':'RINCON_raw-id','name':'Search <img src=x>','host':'192.0.2.40'}]
    if name == 'sonosForget':
        assert values == {'id':'RINCON_raw-id'}
        speakers = []
    data = {'sonosSpeakers':speakers,'sonosAdd':speakers,'sonosForget':speakers,
        'listPlugins':[],'listFiles':[],'mediaPlayers':{'players':[]},
        'getAudioDevices':{'inputs':[],'outputs':[]}}.get(name,{})
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
        root.locator('[data-subpage-entry="Sonos"]').click()
        panel = root.locator('[data-subpage="Sonos"]')
        expect(panel.get_by_text('TEST No speakers yet',exact=True)).to_be_visible()
        panel.get_by_role('button',name='TEST Search',exact=True).click()
        expect(page.get_by_text('TEST Nothing answered on this network. Add one by address.',exact=True)).to_be_visible()
        assert ('sonosSpeakers',{'discover':True}) in requests
        panel.get_by_role('button',name='TEST Add',exact=True).click()
        expect(page.get_by_text('TEST Add a Sonos by address',exact=True)).to_be_visible()
        page.get_by_placeholder('192.168.1.40').fill('  192.0.2.40  ')
        page.get_by_placeholder('192.168.1.40').press('Enter')
        expect(page.get_by_text('TEST No Sonos answered at <raw-host> {host}.',exact=True)).to_be_visible()
        assert ('sonosAdd',{'host':'192.0.2.40'}) in requests
        add_error = False
        page.get_by_placeholder('192.168.1.40').press('Enter')
        expect(panel.get_by_text('Search <img src=x>',exact=True)).to_be_visible()
        expect(panel.get_by_text('192.0.2.40 · RINCON_raw-id',exact=True)).to_be_visible()
        with page.expect_response('**/api/settings'):
            panel.locator('[data-key="sendspin.sonos_group_volume"] label').click()
        assert ('settings',{'sendspin.sonos_group_volume':True}) in requests
        for language in ['en','es']:
            settings[0]['value'] = language
            page.evaluate("async()=>await (await import('/static/settings.js')).loadSettings()")
            expect(panel.get_by_text('Search <img src=x>',exact=True)).to_be_visible()
            expect(panel.get_by_role('button',name=('TEST ' if language=='es' else '')+'Forget',exact=True)).to_be_visible()
            expect(panel.locator('[data-key="sendspin.sonos_group_volume"] input')).to_be_checked()
        panel.get_by_role('button',name='TEST Forget',exact=True).click()
        expect(panel.get_by_text('TEST No speakers yet',exact=True)).to_be_visible()
        assert ('sonosForget',{'id':'RINCON_raw-id'}) in requests
        assert page.locator('img[src="x"]').count()==0
        assert not errors,errors
        browser.close()
finally:
    server.shutdown()
print('Sonos localization browser checks passed')
