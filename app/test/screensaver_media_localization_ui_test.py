"""Localized media pickers preserve external names, IDs, dates and camera order."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect
APP=Path(__file__).resolve().parents[1];ROOT=APP/'remote-ui'
english={k:v for p in (APP/'l10n/source').glob('*_en.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
spanish={'settingScreensaverImmichApiKeyTitle':'TEST API key','haValidate':'TEST validate',
 'screensaverMediaScopeMissing':'TEST permission {scope}', 'screensaverMediaItems':'TEST items {count}',
 'screensaverMediaCached':'TEST cached {count} {size}', 'commonEdit':'TEST edit','commonSave':'TEST save',
 'commonCancel':'TEST cancel','commonBrowse':'TEST browse','commonAdd':'TEST add',
 'commonMoveUp':'TEST up','commonSet':'TEST set','commonClear':'TEST clear',
 'screensaverMediaHidden':'TEST hidden','screensaverMediaUseFolder':'TEST use folder',
 'screensaverMediaHaPage':'TEST HA media', 'screensaverMediaImmichPage':'TEST Immich',
 'screensaverMediaCameraPage':'TEST cameras','screensaverMediaBrowseError':'TEST browse error {error}',
 'screensaverMediaRoot':'TEST media', 'screensaverMediaTopLeft':'TEST top left',
 'screensaverMediaListError':'TEST list error {error}'}
settings=[];ids=json.loads((APP/'l10n/settings.json').read_text());options=json.loads((APP/'l10n/setting_options.json').read_text())
def setting(key,value,kind='string',subpage=None,**extra):
 row=dict(key=key,value=value,type=kind,category='Screensaver',title=key,description='',**({'subpage':subpage} if subpage else {}),**extra)
 if key in ids:row.update(titleMessageId=ids[key]['title'],descriptionMessageId=ids[key]['description'])
 if key in options:row['optionMessageIds']=options[key]
 settings.append(row)
setting('ui.language','es',hidden=True)
setting('screensaver.mode','immich','select',options=['immich','media','camera'])
setting('screensaver.immich_api_key','__set__','password','Immich Media screensaver')
setting('screensaver.immich_validated',True,'boolean',hidden=True)
setting('screensaver.immich_album','[]',subpage='Immich Media screensaver')
setting('screensaver.immich_people','[]',subpage='Immich Media screensaver')
setting('screensaver.immich_cache_max_items',50,'number','Immich Media screensaver')
setting('screensaver.immich_metadata_position','top_left','select','Immich Media screensaver',options=['top_left','bottom_right'],optionLabels={'top_left':'Top left','bottom_right':'Bottom right'})
setting('screensaver.immich_taken_from','2024-02-03',subpage='Immich Media screensaver')
setting('screensaver.media_id','',subpage='Home Assistant Media screensaver')
setting('screensaver.media_is_folder',False,'boolean',hidden=True)
setting('screensaver.camera_views','["v2"]',subpage='Camera Streams screensaver')
requests=[];fail_browse=False;fail_people=False
views=[{'id':'v1','name':'Media','cameraIds':['c1']},{'id':'v2','name':'Connected','cameraIds':['c1','c2']}]
def api(route):
 path=route.request.url.split('/api/',1)[1]
 if path=='settings':
  if route.request.method=='PATCH':
   values=route.request.post_data_json;requests.append(values)
   for item in settings:
    if item['key'] in values:item['value']=values[item['key']]
   return route.fulfill(json={'ok':True})
  return route.fulfill(json={'settings':settings,'subpageHints':{}})
 name=path.removeprefix('commands/');args=route.request.post_data_json or {}
 if name=='immichValidate':return route.fulfill(json={'ok':False,'error':'The API key is missing the asset.view permission.'})
 if name=='immichPeople' and fail_people:return route.fulfill(json={'ok':False,'error':'The API key is missing the person.read permission.'})
 if name=='haBrowseMedia':
  if fail_browse:return route.fulfill(json={'ok':False,'error':'<img src=x onerror=window.injected=true>'})
  folder=args.get('mediaContentId')
  return route.fulfill(json={'ok':True,'data':{'media_content_id':folder,'can_expand':True,'children':[] if folder else [{'title':'Media','media_content_id':'media-source://library/original','can_expand':True}]}})
 data={'immichAlbums':[{'id':'album-raw','name':'Connected','count':12}],
 'immichPeople':[{'id':'person-raw','name':'Hidden','hidden':True}],
 'immichCacheStats':{'items':3,'bytes':2048},'cameraGetConfig':{'views':views},
 'listPlugins':[],'listFiles':[],'mediaPlayers':{'players':[]},'getAudioDevices':{'inputs':[],'outputs':[]}}.get(name,{})
 route.fulfill(json={'ok':True,'data':data})
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page(viewport={'width':1200,'height':1400});errors=[]
  page.on('pageerror',lambda e:errors.append(str(e)))
  html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
  page.route(base+'/',lambda route:route.fulfill(body=html,content_type='text/html'))
  page.route('**/static/catalogs.js',lambda route:route.fulfill(body='export const catalogs = '+json.dumps({'en':english,'es':spanish})+';',content_type='text/javascript'))
  page.route('**/api/**',api);page.goto(base+'/')
  page.evaluate("""async()=>{(await import('/static/core.js')).showView('app');await (await import('/static/settings.js')).loadSettings();(await import('/static/tabs.js')).showTab('screensaver',{refresh:false});}""")
  root=page.locator('#tab-screensaver')
  def open_page(name):
   page.evaluate("(async()=>(await import('/static/tabs.js')).showTab('screensaver',{refresh:false}))()")
   root.locator('[data-subpage-entry="'+name+'"]').click()
  open_page('Immich Media screensaver')
  expect(page.locator('#pageTitle')).to_contain_text('TEST Immich')
  expect(root.get_by_text('TEST API key',exact=True)).to_be_visible()
  root.get_by_role('button',name='TEST validate',exact=True).click()
  expect(root.get_by_text('TEST permission asset.view',exact=True)).to_be_visible()
  expect(root.get_by_text('TEST cached 3 2.0 KB',exact=True)).to_be_visible()
  expect(root.locator('[data-key="screensaver.immich_metadata_position"] option:checked')).to_have_text('TEST top left')
  root.locator('[data-key="screensaver.immich_album"] button').click()
  expect(page.get_by_text('TEST items 12',exact=True)).to_be_visible()
  page.locator('.modal-back input[type="checkbox"]').check()
  with page.expect_response('**/api/settings'):page.get_by_role('button',name='TEST save',exact=True).click()
  assert json.loads(requests[-1]['screensaver.immich_album'])==[{'id':'album-raw','name':'Connected'}]
  root.locator('[data-key="screensaver.immich_people"] button').click()
  expect(page.get_by_text('Hidden',exact=True)).to_be_visible();expect(page.get_by_text('TEST hidden',exact=True)).to_be_visible()
  page.get_by_role('button',name='TEST cancel',exact=True).click()
  fail_people=True
  root.locator('[data-key="screensaver.immich_people"] button').click()
  expect(page.get_by_text('TEST list error TEST permission person.read',exact=True)).to_be_visible()
  page.get_by_role('button',name='TEST cancel',exact=True).click()
  root.locator('[data-key="screensaver.immich_taken_from"] button').click()
  expect(page.locator('.date-month')).to_contain_text('febrero de 2024')
  expect(page.locator('.date-weekday').first).to_have_text('D')
  with page.expect_response('**/api/settings'):page.get_by_role('button',name='TEST set',exact=True).click()
  assert requests[-1]=={'screensaver.immich_taken_from':'2024-02-03'}
  root.locator('[data-key="screensaver.immich_taken_from"] button').click()
  with page.expect_response('**/api/settings'):page.get_by_role('button',name='TEST clear',exact=True).click()
  assert requests[-1]=={'screensaver.immich_taken_from':''}
  open_page('Home Assistant Media screensaver');root.get_by_role('button',name='TEST browse',exact=True).click()
  page.locator('.modal-back .row').filter(has_text='Media').click()
  with page.expect_response('**/api/settings'):page.get_by_role('button',name='TEST use folder',exact=True).click()
  assert requests[-1]=={'screensaver.media_id':'media-source://library/original','screensaver.media_is_folder':True}
  fail_browse=True
  root.get_by_role('button',name='TEST browse',exact=True).click()
  expect(page.get_by_text('TEST browse error Error: <img src=x onerror=window.injected=true>',exact=True)).to_be_visible()
  assert page.locator('.modal-back img').count()==0
  page.locator('.modal-back').click(position={'x':1,'y':1})
  open_page('Camera Streams screensaver')
  expect(root.get_by_text('Media',exact=True)).to_be_visible()
  root.get_by_role('button',name='TEST add',exact=True).click()
  root.get_by_role('button',name='TEST up',exact=True).last.click()
  page.wait_for_function("document.querySelector('#tab-screensaver').textContent.includes('Position 1')")
  assert json.loads(next(r['screensaver.camera_views'] for r in reversed(requests) if 'screensaver.camera_views' in r))==['v1','v2']
  assert not errors,errors
  browser.close()
finally:server.shutdown()
print('Screensaver media localization browser checks passed')
