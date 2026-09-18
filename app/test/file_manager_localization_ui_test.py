"""File actions retain raw paths and pending state across language changes."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread
from urllib.parse import urlsplit, parse_qs
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
en = {k:v for p in (APP/'l10n/source').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
es = {k:v for p in (APP.parents[1]/'kiosk-satellite-localization/translations/es').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
requests = []
pending = []
failure = None
download_failure = False
delete_failure = False
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass
server = ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start()
base=f'http://127.0.0.1:{server.server_port}'
def api(route):
    path=urlsplit(route.request.url).path.removeprefix('/api/')
    data=route.request.post_data_json if path.startswith('commands/') or route.request.method=='PATCH' else None
    requests.append((path,data))
    if path=='commands/fileRoots':
        return route.fulfill(json={'ok':True,'data':{'roots':[{'id':'app','label':'App folder','available':True},{'id':'shared','label':'Shared storage','available':False,'grantNeeded':True}]}})
    if path=='commands/fileList':
        if failure: return route.fulfill(json={'ok':False,'error':failure})
        entries=[{'name':'Raw & folder','dir':True},{'name':'Raw <name>.txt','dir':False,'size':2048,'modified':1700000000000}] if not data['path'] else []
        return route.fulfill(json={'ok':True,'data':{'entries':entries}})
    if path=='commands/fileDelete':
        return route.fulfill(json={'ok':not delete_failure,'error':'no such file' if delete_failure else None})
    if path=='files/upload':
        assert parse_qs(urlsplit(route.request.url).query)=={'root':['app'],'path':['Raw & folder/Raw upload.txt']}
        assert route.request.post_data_buffer==b'original upload content'
        pending.append(route)
        return
    if path=='files/download':
        assert parse_qs(urlsplit(route.request.url).query)=={'root':['app'],'path':['Raw <name>.txt']}
        if download_failure: return route.fulfill(status=404,json={'error':'no such file'})
        return route.fulfill(body='original file content',content_type='application/octet-stream')
    route.fulfill(json={'ok':True,'data':{}})
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox'])
        page=browser.new_page(viewport={'width':390,'height':950})
        errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda r:r.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda r:r.fulfill(body='export const catalogs = '+json.dumps({'en':en,'es':es})+';',content_type='text/javascript'))
        page.route('**/api/**',api)
        page.goto(base+'/')
        page.evaluate("""async()=>{
          const c=await import('/static/core.js');c.showView('app');c.cacheSettings([{key:'ui.language',value:'es'}]);
          (await import('/static/tabs.js')).showTab('files',{refresh:false});
          await (await import('/static/files.js')).loadFiles();
        }""")
        def language(value): page.evaluate("async value=>(await import('/static/core.js')).cacheSettings([{key:'ui.language',value}])",value)
        root=page.locator('#tab-files')
        expect(root.get_by_role('button',name=es['filesApp'],exact=True)).to_be_visible()
        expect(root.get_by_text(es['filesPermissionMissing'],exact=True)).to_be_visible()
        expect(root.get_by_role('button',name=es['filesShared'],exact=True)).to_be_disabled()
        root.get_by_text('Raw & folder',exact=True).click()
        expect(root.get_by_text(es['filesEmpty'],exact=True)).to_be_visible()
        root.locator('input[type=file]').set_input_files({'name':'Raw upload.txt','mimeType':'text/plain','buffer':b'original upload content'})
        expect(root.get_by_role('button',name=es['filesUploading'],exact=True)).to_be_disabled()
        assert pending
        before=len(requests)
        language('en')
        expect(root.get_by_role('button',name=en['filesUploading'],exact=True)).to_be_disabled()
        expect(root.locator('.log-title')).to_have_text('/Raw & folder')
        assert len(requests)==before
        language('es')
        pending.pop().fulfill(json={'ok':True})
        expect(root.get_by_role('button',name=es['filesUpload'],exact=True)).to_be_enabled()
        expect(page.locator('.toast-title')).to_have_text(es['filesUploaded'])
        expect(page.locator('.toast-msg')).to_have_text('Raw upload.txt')
        root.get_by_role('button',name=es['filesUp'],exact=True).click()
        expect(root.get_by_text('Raw <name>.txt',exact=True)).to_be_visible()
        with page.expect_download() as download:
            root.get_by_role('button',name=es['filesDownload'],exact=True).click()
        assert download.value.suggested_filename=='Raw _name_.txt'  # Browser sanitizes reserved filename characters.
        assert Path(download.value.path()).read_bytes()==b'original file content'
        download_failure=True
        root.get_by_role('button',name=es['filesDownload'],exact=True).click()
        expect(page.locator('.toast-title')).to_have_text(es['filesDownloadFailed'])
        expect(page.locator('.toast-msg')).to_have_text(es['filesNoFile'])
        root.get_by_role('button',name=es['commonDelete'],exact=True).click()
        modal=page.locator('.modal-card')
        expect(modal.locator('.modal-title')).to_have_text(es['filesDeleteTitle'].replace('{name}','Raw <name>.txt'))
        before=len(requests)
        language('en')
        expect(modal.locator('.modal-title')).to_have_text(en['filesDeleteTitle'].replace('{name}','Raw <name>.txt'))
        assert modal.locator('name').count()==0
        modal.get_by_role('button',name=en['commonCancel'],exact=True).click()
        assert len(requests)==before
        root.get_by_role('button',name=en['commonDelete'],exact=True).click()
        language('es')
        delete_failure=True
        modal.get_by_role('button',name=es['commonDelete'],exact=True).click()
        expect(page.locator('.toast-title')).to_have_text(es['filesDeleteFailed'])
        expect(page.locator('.toast-msg')).to_have_text(es['filesNoFile'])
        assert requests[-1]==('commands/fileDelete',{'root':'app','path':'Raw <name>.txt'})
        failure='cannot read folder: EACCES <raw>'
        page.evaluate("async()=>await (await import('/static/files.js')).loadFiles()")
        expect(root.get_by_text(es['filesReadError'].replace('{error}','EACCES <raw>'),exact=True)).to_be_visible()
        before=len(requests);language('en')
        expect(root.get_by_text(en['filesReadError'].replace('{error}','EACCES <raw>'),exact=True)).to_be_visible()
        assert len(requests)==before
        assert root.locator('raw').count()==0
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        # Both warning dialogs retain their choices while the language changes.
        page.evaluate("""async()=>{
          const {settingRow}=await import('/static/rows.js');
          const host=document.createElement('div');host.id='audit-controls';document.body.appendChild(host);
          host.appendChild(settingRow({key:'screensaver.screen_off_minutes',type:'number',title:'Screen off',description:'',value:0,min:0,max:60,step:1}));
          host.appendChild(settingRow({key:'remote.enabled',type:'boolean',title:'Remote',description:'',value:true}));
        }""")
        host=page.locator('#audit-controls')
        slider=host.locator('input[type=range]')
        slider.evaluate("el=>{el.value='5';el.dispatchEvent(new Event('change'));}")
        modal=page.locator('.modal-card')
        expect(modal.locator('.modal-title')).to_have_text(en['screensaverWarningTitle'])
        before=len(requests);language('es')
        expect(modal.locator('.modal-title')).to_have_text(es['screensaverWarningTitle'])
        modal.get_by_role('button',name=es['commonCancel'],exact=True).click()
        expect(slider).to_have_value('0')
        assert len(requests)==before, 'Cancel must never save screen-off after a language change'
        switch=host.locator('input[type=checkbox]')
        host.locator('label.switch').click()
        expect(modal.locator('.modal-title')).to_have_text(es['remoteDisableTitle'])
        before=len(requests);language('en')
        modal.get_by_role('button',name=en['commonCancel'],exact=True).click()
        expect(switch).to_be_checked()
        assert len(requests)==before
        # Search includes translated hand-built entries while preserving navigation anchors.
        language('es')
        results=page.evaluate("async()=> (await import('/static/search.js')).searchSettingsIndex('Estado de la pantalla de inicio')")
        assert any(r['tab']=='home' and r['title']==es['searchHomeStatus'] for r in results),results
        results=page.evaluate("async()=> (await import('/static/search.js')).searchSettingsIndex('altavoces Sonos')")
        assert any(r['tab']=='sendspin' and r['sub']=='Sonos' and r['desc']==es['searchSonosSpeakers'] for r in results),results
        language('en')
        results=page.evaluate("async()=> (await import('/static/search.js')).searchSettingsIndex('Home screen status')")
        assert any(r['title']=='Home screen status' for r in results)
        assert not errors,errors
        browser.close()
finally: server.shutdown()
print('File Manager localization checks passed')
