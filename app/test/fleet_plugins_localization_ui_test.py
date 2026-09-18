"""Localized Fleet and Plugin pages preserve IDs, names, drafts and live updates."""
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
maps = {group:json.loads((APP/f'l10n/{group}_text.json').read_text()) for group in ['fleet','plugin']}
def tr(group, text): return translated[maps[group][text]]
settings = [dict(key='ui.language',value='es',type='string',category='Device',hidden=True)]
mapping=json.loads((APP/'l10n/settings.json').read_text())
for key,value in [('fleet.leader',True),('fleet.auto_update',False)]:
    ids=mapping[key]
    settings.append(dict(key=key,value=value,type='boolean',category='Fleet',title=english[ids['title']],description=english[ids['description']],titleMessageId=ids['title'],descriptionMessageId=ids['description']))
profiles=[dict(id='default',name='Default',categories=['Kiosk'],credentials=['ha.token'],excluded=[],dashboard=False),
          dict(id='updates-only',name='Updates only',categories=[],credentials=[],excluded=[],dashboard=False),
          dict(id='own',name='Default',categories=[],credentials=[],excluded=[],dashboard=False)]
fleet=dict(enabled=True,leader=True,profiles=profiles,categories=[dict(id='Kiosk',title='Kiosk Mode',note='the PIN is also synced'),dict(id='Camera',title='Camera',note='the device camera')],credentials=[dict(key='ha.token',title='Home Assistant token')],followers=[dict(id='remote-id',name='<b>Keep NAME</b>',address='192.0.2.5',version='2026.9.59',profile='updates-only',profileName='Updates only',phase='synced',status='Synced just now',tone='ok')])
plugin=dict(id='raw-plugin',name='Original <b>NAME</b>',version='1.0.0',enabled=True,running=True,description='Community description',status='Community status',capabilities=['shizuku'],commands=[dict(id='raw-action',title='Raw Action')],actionOptions={},values={'raw-setting':'Original Value'},settings=[dict(key='raw-setting',title='Raw Setting',type='string',default='Default Value')])
plugins=dict(enabled=True,plugins=[plugin])
readings=[dict(type='text_sensor',key='text',name='Raw text',state='On'),dict(type='binary_sensor',key='bool',name='Raw bool',state=True)]
commands=[]
def api(route):
    path=route.request.url.split('/api/',1)[1]
    if path=='settings':return route.fulfill(json=dict(settings=settings,subpageHints={}))
    name=path.removeprefix('commands/');params=route.request.post_data_json or {}
    commands.append((name,copy.deepcopy(params)))
    data={'fleetStatus':fleet,'fleetCandidates':[],'getPluginState':plugins,'getPluginReadings':readings,'getPluginShizukuState':dict(status='permission_required'),'getPluginCharts':[],'getAudioDevices':dict(inputs=[],outputs=[])}.get(name,{})
    if name=='fleetLookup':
        if not params.get('address'):
            return route.fulfill(json=dict(ok=False,error='Enter a valid IP address.'))
        data=dict(id='manual-id',name='Manual <b>NAME</b>',address='192.0.2.80',port=2345,manual=True)
    if name=='fleetSetProfile':
        profile=params['profile'];profiles[next(i for i,p in enumerate(profiles) if p['id']==profile['id'])]=profile
    if name=='configurePluginAction':plugin['actionOptions'][params['command']]={k:params[k] for k in ['drawer','homeAssistant']}
    if name=='configurePlugin':plugin['values']=params['values']
    route.fulfill(json=dict(ok=True,data=data))
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page(viewport=dict(width=1200,height=1400))
        errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda route:route.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda route:route.fulfill(body='export const catalogs = '+json.dumps({'en':english,'es':translated})+';',content_type='text/javascript'))
        page.route('**/api/**',api);page.goto(base+'/')
        page.evaluate("""async()=>{
          (await import('/static/core.js')).showView('app');
          await (await import('/static/settings.js')).loadSettings();
          (await import('/static/tabs.js')).showTab('fleet',{refresh:false});
        }""")
        root=page.locator('#tab-fleet')
        expect(root.get_by_text(tr('fleet','Followers'),exact=True)).to_be_visible()
        expect(root.get_by_text('<b>Keep NAME</b>',exact=True).first).to_be_visible()
        assert root.locator('b').count()==0
        # Manual lookup stays available with no discovered kiosks and keeps
        # the address and profile through the invitation confirmation.
        page.set_viewport_size(dict(width=390,height=1100))
        root.get_by_role('button',name=tr('fleet','Add'),exact=True).first.click()
        page.locator('.modal-back').last.get_by_role('button',name=tr('fleet','Add by IP'),exact=True).click()
        modal=page.locator('.modal-back').last
        modal.get_by_role('button',name=tr('fleet','Find kiosk'),exact=True).click()
        expect(modal.get_by_role('alert')).to_have_text(tr('fleet','Enter a valid IP address.'))
        modal.get_by_label(tr('fleet','IP address'),exact=True).fill('192.0.2.80')
        modal.get_by_label(tr('fleet','Remote admin port'),exact=True).fill('2345')
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        modal.get_by_role('button',name=tr('fleet','Find kiosk'),exact=True).click()
        modal=page.locator('.modal-back').last
        expect(modal.get_by_text(translated['fleetSyncToName'].replace('{name}','Manual <b>NAME</b>'),exact=True)).to_be_visible()
        assert not any(n=='fleetInvite' for n,p in commands)
        modal.locator('input[type=radio]').nth(1).check()
        modal.get_by_role('button',name=tr('fleet','Send invitation'),exact=True).click()
        expect(page.locator('.modal-back')).to_have_count(0)
        page.wait_for_function("document.querySelector('#tab-fleet').getAttribute('aria-busy') !== 'true'")
        assert any(n=='fleetInvite' and p==dict(id='manual-id',profile='updates-only',address='192.0.2.80',port=2345) for n,p in commands)
        page.set_viewport_size(dict(width=1200,height=1400))
        # Built-in profile names translate by ID. An identically named custom profile stays raw.
        names=root.locator('.subpage-entry[data-subpage-entry] .name').all_text_contents()
        assert tr('fleet','Default') in names and 'Default' in names,names
        page.evaluate("async()=> (await import('/static/tabs.js')).showTab('fleet/Updates only',{refresh:false})")
        expect(root.get_by_text(tr('fleet','Nothing'),exact=True)).to_be_visible()
        expect(page.locator('#pageTitle')).to_have_text(tr('fleet','Updates only'))
        page.evaluate("async()=>{const core=await import('/static/core.js');core.cacheSettings(core.state.settings.map(s=>s.key==='ui.language'?{...s,value:'en'}:s));}")
        expect(page.locator('#pageTitle')).to_have_text('Updates only')
        page.evaluate("async()=>{const core=await import('/static/core.js');core.cacheSettings(core.state.settings.map(s=>s.key==='ui.language'?{...s,value:'es'}:s));}")
        expect(page.locator('#pageTitle')).to_have_text(tr('fleet','Updates only'))
        page.evaluate("async()=> (await import('/static/tabs.js')).showTab('fleet/Default',{refresh:false})")
        panel=root.locator('.subpage[data-subpage="Default"]').first
        panel.get_by_text(tr('fleet','Categories'),exact=True).click()
        modal=page.locator('.modal-back').last
        modal.locator('input[type=checkbox]').nth(1).check()
        modal.get_by_role('button',name=tr('fleet','Save'),exact=True).click()
        page.wait_for_function("!document.querySelector('.modal-back')")
        assert any(n=='fleetSetProfile' and p['profile']['id']=='default' and p['profile']['categories']==['Kiosk','Camera'] for n,p in commands)
        # Live status updates never replace the chosen language or fetch settings again.
        fleet['followers'][0]['status']='Sending 25%';fleet['followers'][0]['phase']='updating'
        page.evaluate("async()=>{(await import('/static/tabs.js')).showTab('fleet',{refresh:false});(await import('/static/live.js')).receiveUpdate('fleetsync');}")
        sending=translated['fleetSendingPercent'].replace('{percent}','25')
        expect(root.get_by_text(sending,exact=True)).to_be_visible()
        page.set_viewport_size(dict(width=390,height=1100))
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.set_viewport_size(dict(width=1200,height=1400))
        page.wait_for_timeout(1100)
        expect(root.get_by_text(tr('fleet','Followers'),exact=True)).to_be_visible()
        page.evaluate("""async()=>{
          await (await import('/static/plugins.js')).loadPlugins();
          (await import('/static/tabs.js')).showTab('plugins/raw-plugin',{refresh:false});
        }""")
        root=page.locator('#tab-plugins');panel=root.locator('.subpage[data-subpage="raw-plugin"]')
        expect(panel.get_by_text('Community description',exact=True)).to_be_visible()
        expect(panel.get_by_text(tr('plugin','Actions'),exact=True)).to_be_visible()
        expect(panel.locator('.plugin-readings dd').nth(0)).to_have_text('On')
        expect(panel.locator('.plugin-readings dd').nth(1)).to_have_text(tr('plugin','On'))
        action=panel.locator('[data-search-id="plugin:raw-plugin:action:raw-action"]')
        action.get_by_role('button').click();modal=page.locator('.modal-back').last
        modal.locator('label.switch').first.click()
        modal.get_by_role('button',name=tr('plugin','Save'),exact=True).click()
        expect(page.locator('.modal-back')).to_have_count(0)
        page.wait_for_function("document.querySelector('#tab-plugins').getAttribute('aria-busy') !== 'true'")
        assert any(n=='configurePluginAction' and p==dict(id='raw-plugin',command='raw-action',drawer=True,homeAssistant=False) for n,p in commands)
        field=panel.get_by_role('textbox',name='Raw Setting');field.fill('Keep CASE and unsaved data')
        readings[1]['state']=False
        page.evaluate("async()=> (await import('/static/live.js')).receiveUpdate('plugins')")
        expect(panel.locator('.plugin-readings dd').nth(1)).to_have_text(tr('plugin','Off'))
        expect(field).to_have_value('Keep CASE and unsaved data');expect(field).to_be_focused()
        # A cache language change retains drafts and does not write them.
        writes=sum(n=='configurePlugin' for n,_ in commands)
        page.evaluate("async()=>{const core=await import('/static/core.js');core.cacheSettings(core.state.settings.map(s=>s.key==='ui.language'?{...s,value:'en'}:s));}")
        expect(panel.get_by_text('Actions',exact=True)).to_be_visible()
        expect(panel.get_by_role('textbox',name='Raw Setting')).to_have_value('Keep CASE and unsaved data')
        page.evaluate("async()=>{const core=await import('/static/core.js');core.cacheSettings(core.state.settings.map(s=>s.key==='ui.language'?{...s,value:'es'}:s));}")
        expect(panel.get_by_text(tr('plugin','Actions'),exact=True)).to_be_visible()
        assert sum(n=='configurePlugin' for n,_ in commands)==writes
        page.set_viewport_size(dict(width=390,height=1100))
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        assert not errors,errors
        browser.close()
        print('PASS: Fleet profiles, live status, plugin actions, raw provider values, draft preservation and language changes.')
finally:server.shutdown()
