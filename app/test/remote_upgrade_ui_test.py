"""Keep the previous build's HTTP cache while upgrading the remote server."""
import json
import sys
import time
from playwright.sync_api import sync_playwright, expect

base=sys.argv[1]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    context=browser.new_context(viewport={'width':1200,'height':1000})
    page=context.new_page()
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda msg: print('console:',msg.type,msg.text) if msg.type=='error' else None)
    page.on('response',lambda r: print('failed:',r.status,r.url) if r.status>=400 else None)
    page.goto(base+'/')
    page.wait_for_timeout(500)
    assert not errors,errors
    expect(page.locator('#loginBtn')).to_be_visible()
    legacy=page.evaluate("performance.getEntriesByType('resource').map(r=>r.name)")
    assert base+'/static/settings.js' in legacy, legacy
    assert any('?v=111111111111' in url for url in legacy)
    context.request.post(base+'/upgrade')
    for attempt in range(50):
        try:
            response=context.request.post(base+'/api/login',data=json.dumps({'password':'secret'}),timeout=1000)
            if response.ok:
                token=response.json()['token']
                break
        except Exception:pass
        time.sleep(.1)
    else:raise AssertionError('Upgraded server did not start')
    context.add_init_script('localStorage.setItem("ks_token",'+json.dumps(token)+')')
    errors.clear()
    page.goto(base+'/?upgrade=1#gestures')
    expect(page.locator('#app')).to_be_visible(timeout=30000)
    resources=page.evaluate("performance.getEntriesByType('resource').map(r=>r.name)")
    assert base+'/static/settings.js' not in resources, 'Old bare module loaded from cache'
    assert not any('?v=111111111111' in url for url in resources), resources
    # Use markers so this regression also runs with approved-only catalogs.
    page.evaluate("""async()=>{
      const urls=performance.getEntriesByType('resource').map(r=>r.name);
      const {catalogs}=await import(urls.find(u=>u.includes('/catalogs.js')));
      catalogs.es.gestureEmpty='TEST sin gestos';
      await (await import(urls.find(u=>u.includes('/gestures.js')))).loadGestures();
    }""")
    root=page.locator('#tab-gestures')
    expect(root.get_by_text('TEST sin gestos',exact=True)).to_be_visible()
    for _ in range(3):
        page.locator('#tabs button[data-tab="device"]').click()
        expect(page.locator('[data-key="device.name"] .name')).to_have_text('Nombre del dispositivo')
        page.locator('#tabs button[data-tab="gestures"]').click()
        expect(root.get_by_text('TEST sin gestos',exact=True)).to_be_visible()
    page.wait_for_timeout(1000)
    expect(root.get_by_text('TEST sin gestos',exact=True)).to_be_visible()
    assert not errors,errors
    browser.close()
print('Browser upgrade cache regression passed.')
