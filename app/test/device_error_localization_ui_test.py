"""Device error dialogs translate without repeating commands or changing details."""
import json
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from threading import Thread
from playwright.sync_api import sync_playwright,expect
app=Path(__file__).resolve().parents[1];root=app/'remote-ui'
en={k:v for p in (app/'l10n/source').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
es={k:v for p in (app.parents[1]/'kiosk-satellite-localization/translations/es').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
calls=[]
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(root)))
Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
html=(root/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
error='Android has not confirmed this permission. Check Permissions Manager on the device.'
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page()
  page.route(base+'/',lambda r:r.fulfill(body=html,content_type='text/html'))
  page.route('**/static/catalogs.js',lambda r:r.fulfill(body='export const catalogs = '+json.dumps({'en':en,'es':es})+';',content_type='text/javascript'))
  errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  def api(route):
   path=route.request.url.split('/api/')[1];calls.append(path)
   if path=='update/upload':return route.fulfill(status=400,json={'ok':False,'error':'Bad state: The file is not an Android APK.'})
   data={'commands/getShizukuState':{'status':'ready','granted':True,'uid':2000},'commands/runShizukuAction':{'results':[{'key':'microphone','ok':False,'error':error}]}}.get(path,{})
   route.fulfill(json={'ok':True,'data':data})
  page.route('**/api/**',api);page.goto(base+'/')
  page.evaluate('''async()=>{
   (await import('/static/localization.js')).setLanguagePreference('es');
   document.querySelectorAll('body > section').forEach(x=>x.style.display='none');
   const b=document.createElement('button');b.id='audit-upload';b.textContent='Instalar';document.body.append(b);
   (await import('/static/device.js')).attachUploadInstall(b);
  }''')
  page.locator('#audit-upload + input').set_input_files({'name':'invalid.apk','mimeType':'application/vnd.android.package-archive','buffer':b'audit fixture'})
  expect(page.locator('.modal-body')).to_contain_text(es['updateInvalidApk'])
  count=len(calls)
  page.evaluate("async()=>{(await import('/static/core.js')).cacheSettings([{key:'ui.language',value:'en'}]);}")
  expect(page.locator('.modal-body')).to_contain_text(en['updateInvalidApk'])
  assert len(calls)==count
  page.evaluate("async()=>{(await import('/static/core.js')).cacheSettings([{key:'ui.language',value:'es'}]);}")
  expect(page.locator('.modal-body')).to_contain_text(es['updateInvalidApk'])
  page.locator('.modal-foot button').click()
  page.evaluate('''async()=>{
   const tabs=await import('/static/tabs.js');tabs.setCurrentPath('device/Shizuku');
   const panel=document.createElement('div');panel.id='audit-shizuku';document.body.append(panel);
   (await import('/static/shizuku.js')).renderShizukuPage(panel);
  }''')
  button=page.locator('#audit-shizuku [data-shizuku-action="grantAll"]');expect(button).to_be_enabled();button.click()
  expect(page.locator('.modal-body')).to_contain_text(es['shizukuPermissionUnconfirmed'])
  count=calls.count('commands/runShizukuAction')
  page.evaluate("async()=>{(await import('/static/core.js')).cacheSettings([{key:'ui.language',value:'en'}]);}")
  expect(page.locator('.modal-body')).to_contain_text(error)
  assert calls.count('commands/runShizukuAction')==count
  assert not errors,errors
  print('APK and Shizuku dialogs translate live without repeating operations.')
  browser.close()
finally:server.shutdown()
