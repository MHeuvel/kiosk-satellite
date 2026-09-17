"""ESPHome setup preserves IDs, credentials and picker drafts across locale updates."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import copy
import json
import os
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect
APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k:v for p in (APP/'l10n/source').glob('*_en.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated = {k:'TEST '+v for k,v in english.items()}
if os.environ.get('KS_TEST_SPANISH'):
    translated = {k:v for p in (APP.parents[1]/'kiosk-satellite-localization/translations/es').glob('*_es.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
mapping=json.loads((APP/'l10n/settings.json').read_text())
hints=json.loads((APP/'l10n/setting_placeholders.json').read_text())
settings=[dict(key='ui.language',value='es',type='string',category='Device',hidden=True)]
for key,value in [('esphome.enabled',True),('esphome.entities',True),('esphome.excluded_entities','["missing.id"]'),('esphome.node_name','kitchen-tablet'),('btproxy.key','Original+Key=='),('btproxy.port',''),('esphome.real_mac',True),('esphome.mac_override','')]:
    ids=mapping[key]
    s=dict(key=key,value=value,type='boolean' if isinstance(value,bool) else 'string',category='ESPHome',title=english[ids['title']],description=english[ids['description']],titleMessageId=ids['title'],descriptionMessageId=ids['description'])
    if key!='esphome.enabled':s['dependsOn']='esphome.entities' if key=='esphome.excluded_entities' else 'esphome.enabled'
    if key in ['esphome.real_mac','esphome.mac_override']:s['subpage']='Advanced settings'
    if key=='esphome.mac_override':s.update(hidden=True,dependsOn='esphome.real_mac')
    if key in hints:s.update(placeholder=english[hints[key]],placeholderMessageId=hints[key])
    settings.append(s)
settings.append(dict(key='btproxy.enabled',value=False,type='boolean',title='Enable Bluetooth proxy',description='',category='ESPHome',subpage='Bluetooth Proxy'))
entities=[dict(objectId='screen',name='Control',categoryLabel='Control',type='light'),dict(objectId='battery',name='<b>Original battery</b>',categoryLabel='Diagnostics',type='sensor')]
status=dict(realMac=None,realMacSource='none',startError='<b>RAW_PORT_ERROR</b>')
commands=[];writes=[];fail_entities=False;fail_save=False

def api(route):
    path=route.request.url.split('/api/',1)[1]
    if path=='settings':
        if route.request.method=='GET':return route.fulfill(json=dict(settings=settings,subpageHints={'Advanced settings':'Real or spoofed Wi-Fi MAC address'}))
        data=route.request.post_data_json;writes.append(copy.deepcopy(data))
        for key,value in data.items():
            error=None
            if key=='esphome.excluded_entities' and fail_save:error='Could not save exclusions. Try again.'
            if key=='btproxy.port' and value=='1':error='Enter a port between 1024 and 65535, or leave it empty'
            if key=='esphome.mac_override' and value=='invalid':error='Enter a valid MAC address.'
            if error:return route.fulfill(json=dict(ok=False,rejected=[key],errors={key:error}))
            if key=='esphome.mac_override':
                value=value.upper().replace('-',':');status.update(realMac=value or None,realMacSource='manual' if value else 'none')
            next(s for s in settings if s['key']==key)['value']=value
        return route.fulfill(json=dict(ok=True))
    name=path.removeprefix('commands/');params=route.request.post_data_json or {};commands.append((name,params))
    if name=='getEspHomeEntities' and fail_entities:return route.fulfill(json=dict(ok=False,error='RAW unavailable'))
    data={'getEspHomeEntities':entities,'esphomeStatus':status,'getAudioDevices':dict(inputs=[],outputs=[]),'getBleSupport':dict(supported=True),'bluetoothAdapterOn':dict(on=True),'hasDeviceCamera':False}.get(name,{})
    route.fulfill(json=dict(ok=True,data=data))
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page(viewport=dict(width=1200,height=1400));errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda r:r.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda r:r.fulfill(body='export const catalogs = '+json.dumps({'en':english,'es':translated})+';',content_type='text/javascript'))
        page.route('**/api/**',api);page.goto(base+'/')
        page.evaluate("""async()=>{(await import('/static/core.js')).showView('app');await (await import('/static/settings.js')).loadSettings();(await import('/static/tabs.js')).showTab('esphome',{refresh:false});}""")
        root=page.locator('#tab-esphome')
        def row(key):return root.locator(f'[data-key="{key}"]')
        def language(value):
            settings[0]['value']=value
            page.evaluate("async s=>(await import('/static/settings.js')).applySettingsUpdate({settings:[s]})",copy.deepcopy(settings[0]))
        def show(path):page.evaluate("async path=>(await import('/static/tabs.js')).showTab(path,{refresh:false})",path)
        expect(row('esphome.enabled').locator('.name')).to_have_text(translated[mapping['esphome.enabled']['title']])
        expect(root.locator('.esphome-start-error')).to_have_text(translated['esphomeStartFailed'].replace('{error}',status['startError']))
        assert root.locator('.esphome-start-error b').count()==0
        expect(row('btproxy.key')).to_contain_text('Original+Key==')
        selection=row('esphome.excluded_entities')
        selection.get_by_role('button').click();modal=page.locator('.modal-card')
        expect(modal.get_by_text('<b>Original battery</b>',exact=True)).to_be_visible()
        assert modal.locator('b').count()==0
        expect(modal.get_by_text(translated['esphomeEntityUnavailable'],exact=True)).to_be_visible()
        modal.locator('[data-entity-id="battery"]').check()
        search=modal.locator('input[type=search]');search.fill('battery');search.focus()
        before=len(writes);reads=sum(n=='getEspHomeEntities' for n,_ in commands)
        language('en');expect(modal.locator('.modal-title')).to_have_text('Excluded entities')
        expect(search).to_have_value('battery');expect(search).to_be_focused()
        expect(modal.locator('[data-entity-id="battery"]')).to_be_checked()
        assert len(writes)==before
        language('es');expect(modal.locator('.modal-title')).to_have_text(translated[mapping['esphome.excluded_entities']['title']])
        assert sum(n=='getEspHomeEntities' for n,_ in commands)==reads
        modal.get_by_role('button',name=translated['commonSave'],exact=True).click()
        expect(selection.locator('.device')).to_have_text(translated['esphomeExcludedCount'].replace('{count}','2'))
        assert json.loads(writes[-1]['esphome.excluded_entities'])==['battery','missing.id']
        # A failed save after a locale rebuild must report on the current row.
        selection.get_by_role('button').click();expect(modal.locator('[data-entity-id="screen"]')).to_be_visible()
        modal.locator('[data-entity-id="screen"]').check();language('en');expect(modal.locator('.modal-title')).to_have_text('Excluded entities')
        fail_save=True;modal.get_by_role('button',name='Save',exact=True).click()
        expect(selection.locator('.row-error')).to_contain_text('Could not save exclusions. Try again.')
        assert json.loads(next(s for s in settings if s['key']=='esphome.excluded_entities')['value'])==['battery','missing.id']
        fail_save=False;language('es');expect(selection.locator('.name')).to_have_text(translated[mapping['esphome.excluded_entities']['title']])
        fail_entities=True;selection.get_by_role('button').click()
        expect(modal).to_contain_text(translated['esphomeEntityLoadFailed']);language('en')
        expect(modal).to_contain_text(english['esphomeEntityLoadFailed']);modal.get_by_role('button',name='Cancel',exact=True).click();fail_entities=False
        language('es');expect(row('esphome.node_name').locator('.name')).to_have_text(translated[mapping['esphome.node_name']['title']])
        with page.expect_response('**/api/settings'):
            node=row('esphome.node_name').locator('input');node.fill('cocina-principal');node.press('Tab')
        assert writes[-1]=={'esphome.node_name':'cocina-principal'}
        with page.expect_response('**/api/settings'):
            port=row('btproxy.port').locator('input');port.fill('1');port.press('Tab')
        expect(row('btproxy.port').locator('.row-error')).to_contain_text(translated['dlnaPortInvalid'])
        with page.expect_response('**/api/settings'):
            port.fill('6054');port.press('Tab')
        assert writes[-1]=={'btproxy.port':'6054'}
        show('esphome/advanced-settings')
        expect(root.locator('.real-mac-note')).to_have_text(translated['esphomeMacUnavailable'])
        with page.expect_response('**/api/settings'):
            mac=row('esphome.mac_override').locator('input');mac.fill('invalid');mac.press('Tab')
        expect(row('esphome.mac_override').locator('.row-error')).to_contain_text(translated['esphomeMacInvalid'])
        with page.expect_response('**/api/settings'):
            mac.fill('80-30-49-cd-d6-5f');mac.press('Tab')
        expect(root.locator('.real-mac-note')).to_have_text(translated['esphomeMacManual'].replace('{mac}','80:30:49:CD:D6:5F'))
        expect(row('esphome.mac_override').locator('input')).to_have_value('80:30:49:CD:D6:5F')
        before=len(writes);language('en')
        expect(root.locator('.real-mac-note')).to_have_text(english['esphomeMacManual'].replace('{mac}','80:30:49:CD:D6:5F'))
        language('es');expect(root.locator('.real-mac-note')).to_have_text(translated['esphomeMacManual'].replace('{mac}','80:30:49:CD:D6:5F'))
        assert len(writes)==before
        expect(page.locator('#pageTitle')).to_contain_text(translated['esphomeAdvanced'])
        page.set_viewport_size(dict(width=390,height=900))
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        show('esphome');selection.get_by_role('button').click()
        expect(modal.get_by_text('Control',exact=True)).to_be_visible()
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        assert not errors,errors
        browser.close()
    print('ESPHome setup localization browser checks passed')
finally:server.shutdown()
