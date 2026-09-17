"""ESPHome pages preserve wire values and device data across language/live updates."""
import ast
import copy
import json
import os
import re
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright, expect

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'remote-ui'
english = {k:v for p in (APP/'l10n/source').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
translated = {k:'TEST '+v for k,v in english.items()}
if os.environ.get('KS_TEST_SPANISH'):
    translated = {k:v for p in (APP.parents[1]/'kiosk-satellite-localization/translations/es').glob('*.arb') for k,v in json.loads(p.read_text()).items() if not k.startswith('@')}
ids=json.loads((APP/'l10n/esphome_text.json').read_text())
settings_ids=json.loads((APP/'l10n/settings.json').read_text())
options=json.loads((APP/'l10n/setting_options.json').read_text())
STR=r'''(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")'''
def field(block,name):
    m=re.search(r'\b'+name+r':\s*((?:'+STR+r'\s*)+),',block)
    return ''.join(ast.literal_eval(v) for v in re.findall(STR,m[1])) if m else None
settings=[dict(key='ui.language',value='es',type='string',category='Device',hidden=True)]
values={'btproxy.key':'Original+Key==','btproxy.scan_duty':'balanced','btproxy.nearby_sort':'last_seen','btproxy.min_connect_rssi':'-80','notifications.chime_file':'Connected.mp3','announcements.chime_file':'Connected.mp3','announcements.tts_engine':'','esphome.node_name':'test-tablet','esphome.excluded_entities':'[]','location.interval':60}
for block in re.findall(r'const \w+ = SettingDef<[^>]+>\((.*?)\n\);',(APP/'lib/managers/settings/definitions.dart').read_text(),re.S):
    if field(block,'category')!='ESPHome':continue
    key=field(block,'key');kind=re.search(r'type: SettingType\.(\w+)',block)[1]
    s={name:field(block,name) for name in ['key','title','description','category','section','subpage','dependsOn','placeholder']}
    s.update(type=kind,value=values.get(key,True if kind=='boolean' else 0.3 if kind=='number' else ''),hidden='hidden: true' in block)
    s.update(titleMessageId=settings_ids[key]['title'],descriptionMessageId=settings_ids[key]['description'])
    if key in options:s.update(options=list(options[key]),optionLabels={v:english[k] for v,k in options[key].items()},optionMessageIds=options[key])
    for prop in ['min','max','step']:
        m=re.search(r'\b'+prop+r': ([\d.]+)',block)
        if m:s[prop]=float(m[1])
    settings.append(s)
perms=dict(bluetooth=True,bluetoothPair=True,location=True,locationServicesOn=True)
ble=dict(supported=True);gps=dict(supported=True);adapter=dict(on=True)
fix=dict(enabled=True,fix=dict(latitude=45.5019,longitude=-73.5674,accuracy=8,time=int(time.time()*1000)-10000))
devices=[dict(mac='AA:BB:CC:DD:EE:01',identity='Unknown device',name='Unknown device',rssi=-50,connected=True,last_seen=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())),dict(mac='AA:BB:CC:DD:EE:02',identity='Unknown device',rotating=True,rssi=-85,last_seen=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())),dict(mac='AA:BB:CC:DD:EE:03',identity='Acme <b> device',vendor='Acme <b>',rssi=-70,last_seen=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()))]
engines=[dict(entity_id='tts.original',name='First available'),dict(entity_id='tts.raw',name='<b>Original engine</b>')]
commands=[];writes=[];settings_reads=0;tts_fail=False

def api(route):
    global settings_reads
    path=route.request.url.split('/api/',1)[1]
    if path=='settings':
        if route.request.method=='GET':
            settings_reads+=1
            return route.fulfill(json=dict(settings=settings,subpageHints={'Notifications':'Transparency, blur, notification sound, test notification','Announcements':'Spoken announcements from Home Assistant','GPS Sensor':'Expose GPS sensor data to Home Assistant','Bluetooth Proxy':'Relay nearby Bluetooth devices to Home Assistant'}))
        data=route.request.post_data_json;writes.append(copy.deepcopy(data))
        for key,value in data.items():next(s for s in settings if s['key']==key)['value']=value
        return route.fulfill(json=dict(ok=True))
    name=path.removeprefix('commands/');params=route.request.post_data_json or {};commands.append((name,params))
    if name=='announcementTtsEngines' and tts_fail:return route.fulfill(json=dict(ok=False,error='RAW unavailable'))
    if name=='requestOsPermissions':perms.update(bluetooth=True,bluetoothPair=True,location=True,locationServicesOn=True)
    data={'getBleSupport':ble,'getLocationSupport':gps,'getLocation':fix,'bluetoothAdapterOn':adapter,'getSystemPermissions':perms,'btProxyNearby':dict(devices=devices),'esphomeStatus':dict(connectionSlots=3),'listNotificationSounds':dict(sounds=['Connected.mp3','Other.wav']),'announcementTtsEngines':engines,'getAudioDevices':dict(inputs=[],outputs=[]),'hasDeviceCamera':False}.get(name,{})
    route.fulfill(json=dict(ok=True,data=data))

class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page(viewport=dict(width=1200,height=1600));errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
        page.route(base+'/',lambda r:r.fulfill(body=html,content_type='text/html'))
        page.route('**/static/catalogs.js',lambda r:r.fulfill(body='export const catalogs = '+json.dumps({'en':english,'es':translated})+';',content_type='text/javascript'))
        page.route('**/api/**',api);page.goto(base+'/')
        page.evaluate("async()=>{(await import('/static/core.js')).showView('app');await(await import('/static/settings.js')).loadSettings();}")
        root=page.locator('#tab-esphome')
        def show(name):page.evaluate("async name=>(await import('/static/tabs.js')).showTab('esphome/'+name,{refresh:false})",name)
        def language(value):
            settings[0]['value']=value
            page.evaluate("async s=>(await import('/static/settings.js')).applySettingsUpdate({settings:[s]})",copy.deepcopy(settings[0]))
            catalog=translated if value=='es' else english
            expect(root.locator('[data-key="esphome.enabled"] .name')).to_have_text(catalog[settings_ids['esphome.enabled']['title']])
        def label(en):return translated[ids[en]]
        def update(topic,data):page.evaluate("async ([topic,data])=>(await import('/static/live.js')).receiveUpdate(topic,data)",[topic,data])
        show('bluetooth-proxy');nearby=root.locator('#btproxy-nearby-card')
        expect(nearby).to_contain_text(label('Unknown device'))
        expect(nearby).to_contain_text('Unknown device')
        expect(nearby).to_contain_text(label('(rotating address)'))
        expect(nearby).to_contain_text(translated['esphomeIdentityVendor'].replace('{vendor}','Acme <b>'))
        assert nearby.locator('b').count()==0
        expect(root).to_contain_text(translated['esphomeSlots'].replace('{count}','3'))
        for key,value in [('btproxy.scan_duty','low_power'),('btproxy.nearby_sort','rssi'),('btproxy.min_connect_rssi','-90')]:
            with page.expect_response('**/api/settings'):
                root.locator(f'[data-key="{key}"] select').select_option(value)
            assert writes[-1]=={key:value}
        before=len(writes);language('en');expect(nearby).to_contain_text('(rotating address)');language('es');expect(nearby).to_contain_text(label('(rotating address)'))
        assert len(writes)==before
        update('bluetooth-nearby',dict(btProxyNearby=dict(ok=True,data=dict(devices=devices))))
        expect(nearby).to_contain_text(label('Connected'))
        adapter['on']=False;update('bluetooth',dict(bluetoothAdapterOn=dict(ok=True,data=adapter)))
        expect(root.locator('.bt-off-banner')).to_have_text(label('Bluetooth is off. Turn it on to use the proxy.'))
        adapter['on']=True;update('bluetooth',dict(bluetoothAdapterOn=dict(ok=True,data=adapter)));expect(root.locator('.bt-off-banner')).to_have_count(0)
        show('notifications');panel=root.locator('[data-subpage="Notifications"]')
        expect(panel).to_contain_text('esphome.test_tablet_notification')
        panel.get_by_role('button',name=label('Test'),exact=True).click()
        expect(panel.get_by_role('button',name=label('Sent'),exact=True)).to_be_visible()
        sent=next(data for name,data in reversed(commands) if name=='showNotification')
        assert sent==dict(title=label('Test notification'),message=label('This is what a notification from Home Assistant looks and sounds like.'),type='info',icon='mdi:bell-ring')
        expect(panel.locator('[data-key="notifications.chime_file"] select')).to_have_value('Connected.mp3')
        with page.expect_response('**/api/settings'):
            panel.locator('[data-key="notifications.chime_file"] select').select_option('Other.wav')
        assert writes[-1]=={'notifications.chime_file':'Other.wav'}
        show('announcements');box=root.locator('.tts-pick');expect(box).to_have_text(label('First available'));box.click();modal=page.locator('.modal-card')
        expect(modal).to_contain_text('<b>Original engine</b>');assert modal.locator('b').count()==0
        reads=sum(n=='announcementTtsEngines' for n,_ in commands);before=len(writes)
        language('en');expect(modal.locator('.modal-title')).to_have_text('Text to speech engine');language('es');expect(modal.locator('.modal-title')).to_have_text(label('Text to speech engine'))
        assert sum(n=='announcementTtsEngines' for n,_ in commands)==reads
        assert len(writes)==before
        with page.expect_response('**/api/settings'):
            modal.get_by_text('<b>Original engine</b>',exact=True).click()
        expect(box).to_have_text('<b>Original engine</b>');assert writes[-1]=={'announcements.tts_engine':'tts.raw'}
        box.click();modal.get_by_text(label('First available'),exact=True).click();expect(box).to_have_text(label('First available'))
        tts_fail=True;box.click();expect(page.locator('body')).to_contain_text(label('Could not reach Home Assistant'));tts_fail=False
        show('gps-sensor');status=root.locator('.location-status');expect(status).to_contain_text('45.50190, -73.56740')
        expect(status).to_contain_text(translated['esphomeSecondsAgo'].split('{count}')[0])
        fix['error']='GPS unavailable: <b>RAW detail</b>';update('location',{})
        expect(status).to_contain_text(translated['esphomeLocationError'].replace('{error}','<b>RAW detail</b>'));assert status.locator('b').count()==0
        language('en');expect(status).to_contain_text('GPS unavailable: <b>RAW detail</b>');language('es');expect(status).to_contain_text(translated['esphomeLocationError'].replace('{error}','<b>RAW detail</b>'))
        perms.update(location=False,locationServicesOn=False,bluetooth=False,bluetoothPair=False)
        language('en');language('es');expect(root.locator('[data-subpage="GPS Sensor"]')).to_contain_text(label('Without this the GPS receiver cannot be read and the location sensors stay unknown.'))
        root.locator('[data-subpage="GPS Sensor"]').get_by_role('button',name=label('Grant on device'),exact=True).click()
        expect(root.locator('[data-subpage="GPS Sensor"]')).to_contain_text(label('The location sensors can read the GPS receiver.'))
        assert ('requestOsPermissions',{'which':['location']}) in commands
        ble.update(supported=False,hint='Not available on this device: its Android build has no Bluetooth LE support.')
        gps.update(supported=False,hint='Not available on this device: it has no GPS receiver.')
        language('en');language('es')
        expect(root.locator('.ble-unsupported-note')).to_have_text(label(ble['hint']))
        expect(root.locator('.location-note')).to_have_text(label(gps['hint']))
        expect(root.locator('[data-key="location.enabled"] input')).to_be_disabled()
        page.set_viewport_size(dict(width=390,height=900))
        for path in ['bluetooth-proxy','notifications','announcements','gps-sensor']:
            show(path);assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'),path
        assert settings_reads==1,settings_reads
        assert not errors,errors
        browser.close()
    print('Remaining ESPHome localization browser checks passed')
finally:server.shutdown()
