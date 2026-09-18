"""Translated screensaver editors preserve schedules, modes, colors and times."""
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
spanish = {'screensaverModeBlack':'TEST black mode', 'screensaverFontBlack':'TEST heavy font',
 'screensaverClockSection':'TEST clock settings', 'screensaverScheduleSection':'TEST schedule',
 'screensaverSummaryMotionOff':'TEST motion off', 'screensaverBrightnessPercent':'TEST brightness {percent}',
 'screensaverOn':'TEST on', 'screensaverNowPlaying':'TEST now playing', 'screensaverTime':'TEST time',
 'commonSave':'TEST save', 'commonCancel':'TEST cancel', 'commonSet':'TEST set', 'commonHour':'TEST hour',
 'commonColorRed':'TEST red', 'screensaverWarningTitle':'TEST warning',
 'screensaverScreenOffProceed':'TEST proceed', 'screensaverRefreshError':'TEST whole minutes',
 'screensaverMaxCharacters':'TEST max {count}'}
settings=[]
def setting(key,value,kind='boolean',subpage=None,**extra):
 settings.append(dict(key=key,value=value,type=kind,category='Screensaver',title=key,description='',
                      **({'subpage':subpage} if subpage else {}),**extra))
setting('ui.language','es','select',hidden=True)
setting('screensaver.enabled',True)
setting('screensaver.mode','clock','select',options=['black','clock','plugin:example:saver'],
 optionLabels={'black':'Black','clock':'Clock','plugin:example:saver':'Black'},
 optionMessageIds={'black':'screensaverModeBlack','clock':'screensaverModeClock'})
setting('screensaver.clock_style','digital','select','Clock screensaver',options=['digital'])
setting('screensaver.clock_font_weight','black','select','Clock screensaver',options=['black'],
 optionLabels={'black':'Black'},optionMessageIds={'black':'screensaverFontBlack'})
setting('screensaver.clock_color','250,250,250','string','Clock screensaver')
setting('screensaver.clock_background_refresh',0,'number','Clock screensaver')
setting('screensaver.screen_off_minutes',0,'number',min=0,max=60,step=1)
setting('screensaver.screen_off_black',False,dependsOn='screensaver.screen_off_minutes',dependsOnValue={'gt':0})
setting('screensaver.schedule_enabled',True,subpage='Scheduled Screensavers')
original={'at':'19:00','mode':'black','brightness':.2,'motion':False,'screen_off':5,'person':True}
setting('screensaver.schedule',json.dumps([original]),'string','Scheduled Screensavers')
setting('screensaver.dismiss_on_person',False,hidden=True)
requests=[]
def api(route):
 path=route.request.url.split('/api/',1)[1]
 if path=='settings':
  if route.request.method=='PATCH':
   values=route.request.post_data_json;requests.append(values)
   if values.get('screensaver.clock_background_refresh')==1441:
    return route.fulfill(status=400,json={'ok':False,'errors':{'screensaver.clock_background_refresh':'Enter whole minutes from 0 to 1440'}})
   for item in settings:
    if item['key'] in values:item['value']=values[item['key']]
   return route.fulfill(json={'ok':True})
  return route.fulfill(json={'settings':settings,'subpageHints':{}})
 name=path.removeprefix('commands/')
 data={'listPlugins':[], 'listFiles':[], 'mediaPlayers':{'players':[]},
       'getAudioDevices':{'inputs':[],'outputs':[]},'getSystemPermissions':{'deviceAdmin':False}}.get(name,{})
 route.fulfill(json={'ok':True,'data':data})
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start()
base=f'http://127.0.0.1:{server.server_port}'
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(headless=True,args=['--no-sandbox'])
  page=browser.new_page(viewport={'width':1200,'height':1400})
  errors=[];page.on('pageerror',lambda error:errors.append(str(error)))
  html=(ROOT/'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>','')
  page.route(base+'/',lambda route:route.fulfill(body=html,content_type='text/html'))
  page.route('**/static/catalogs.js',lambda route:route.fulfill(body='export const catalogs = '+json.dumps({'en':english,'es':spanish})+';',content_type='text/javascript'))
  page.route('**/api/**',api)
  page.goto(base+'/')
  page.evaluate("""async () => {
    (await import('/static/core.js')).showView('app');
    await (await import('/static/settings.js')).loadSettings();
    (await import('/static/tabs.js')).showTab('screensaver',{refresh:false});
  }""")
  root=page.locator('#tab-screensaver')
  expect(root.locator('[data-key="screensaver.mode"] option[value="black"]')).to_have_text('TEST black mode')
  expect(root.locator('[data-key="screensaver.mode"] option[value="plugin:example:saver"]')).to_have_text('Black')
  root.locator('[data-subpage-entry="Clock screensaver"]').click()
  expect(page.locator('#pageTitle')).to_contain_text('TEST clock settings')
  expect(root.locator('[data-key="screensaver.clock_font_weight"] option:checked')).to_have_text('TEST heavy font')
  root.locator('[data-key="screensaver.clock_color"] .swatch').click()
  page.get_by_role('button',name='TEST red',exact=True).click()
  with page.expect_response('**/api/settings'):
   page.get_by_role('button',name='TEST save',exact=True).click()
  assert {'screensaver.clock_color':'239,83,80'} in requests
  field=root.locator('[data-key="screensaver.clock_background_refresh"] input')
  field.fill('1441');field.press('Tab')
  expect(page.get_by_text('TEST whole minutes',exact=False)).to_be_visible()
  page.evaluate("(async () => (await import('/static/tabs.js')).showTab('screensaver',{refresh:false}))()")
  root.locator('[data-subpage-entry="Scheduled Screensavers"]').click()
  expect(page.locator('#pageTitle')).to_contain_text('TEST schedule')
  expect(root.get_by_text('TEST black mode · TEST brightness 20 · TEST motion off · Person on · Screen off after 5 min',exact=True)).to_be_visible()
  root.get_by_text('19:00',exact=True).click()
  page.locator('.modal-form .time-box').click()
  expect(page.get_by_text('TEST hour',exact=True)).to_be_visible()
  digits=page.locator('.time-digits');digits.nth(0).fill('21');digits.nth(1).fill('35')
  page.get_by_role('button',name='TEST set',exact=True).click()
  page.locator('.modal-form .form-field').filter(has_text='TEST now playing').locator('select').select_option(label='TEST on')
  with page.expect_response('**/api/settings'):
   page.get_by_role('button',name='TEST save',exact=True).click()
  saved=json.loads(next(item['screensaver.schedule'] for item in reversed(requests) if 'screensaver.schedule' in item))
  assert saved==[{**original,'at':'21:35','now_playing':True}],saved
  page.evaluate("(async () => (await import('/static/tabs.js')).showTab('screensaver',{refresh:false}))()")
  slider=root.locator('[data-key="screensaver.screen_off_minutes"] input[type="range"]')
  slider.evaluate("el => el.dataset.preserved = 'yes'")
  notice=root.locator('.screen-off-admin-notice')
  expect(notice).to_be_visible()
  def echo(key):
   page.evaluate("""async setting => {
    (await import('/static/settings.js')).applySettingsUpdate({settings:[setting]});
    await new Promise(resolve => setTimeout(resolve, 50));
   }""", next(item for item in settings if item['key']==key))
   expect(slider).to_have_attribute('data-preserved','yes')
  slider.evaluate("el => {el.value='5';el.dispatchEvent(new Event('input'));el.dispatchEvent(new Event('change'));}")
  expect(page.get_by_text('TEST warning',exact=True)).to_be_visible()
  page.get_by_role('button',name='TEST cancel',exact=True).click()
  expect(slider).to_have_value('0')
  assert not any('screensaver.screen_off_minutes' in item for item in requests)
  blank=root.locator('[data-key="screensaver.screen_off_black"] input[type="checkbox"]')
  expect(blank).to_have_count(0)
  slider.evaluate("el => {el.value='5';el.dispatchEvent(new Event('input'));el.dispatchEvent(new Event('change'));}")
  with page.expect_response('**/api/settings'):
   page.get_by_role('button',name='TEST proceed',exact=True).click()
  expect(root.locator('[data-key="screensaver.screen_off_black"]')).to_be_visible()
  echo('screensaver.screen_off_minutes')
  blank_row=root.locator('[data-key="screensaver.screen_off_black"]')
  blank_row.evaluate("el => el.dataset.preserved = 'yes'")
  blank_y=blank_row.bounding_box()['y']
  assert notice.bounding_box()['y'] > blank_y
  with page.expect_response('**/api/settings'):
   root.locator('[data-key="screensaver.screen_off_black"] label.switch').click()
  expect(blank).to_be_checked()
  echo('screensaver.screen_off_black')
  expect(blank_row).to_have_attribute('data-preserved','yes')
  assert blank_row.bounding_box()['y']==blank_y
  expect(root.locator('.screen-off-admin-notice')).to_have_count(0)
  with page.expect_response('**/api/settings'):
   slider.evaluate("el => {el.value='0';el.dispatchEvent(new Event('input'));el.dispatchEvent(new Event('change'));}")
  expect(blank).to_have_count(0)
  with page.expect_response('**/api/settings'):
   slider.evaluate("el => {el.value='5';el.dispatchEvent(new Event('input'));el.dispatchEvent(new Event('change'));}")
  expect(blank).to_be_checked()
  expect(page.get_by_text('TEST warning',exact=True)).to_have_count(0)
  echo('screensaver.screen_off_minutes')
  blank_y=blank_row.bounding_box()['y']
  with page.expect_response('**/api/settings'):
   blank_row.locator('label.switch').click()
  echo('screensaver.screen_off_black')
  expect(notice).to_be_visible()
  assert blank_row.bounding_box()['y']==blank_y
  notice.evaluate("el => el.dataset.preserved = 'yes'")
  # A device-side slider update must preserve the controls and permission notice.
  next(item for item in settings if item['key']=='screensaver.screen_off_minutes')['value']=10
  echo('screensaver.screen_off_minutes')
  expect(slider).to_have_value('10')
  expect(notice).to_have_attribute('data-preserved','yes')
  assert blank_row.bounding_box()['y']==blank_y
  assert page.evaluate("(async () => (await import('/static/search.js')).searchSettingsIndex('TEST schedule').some(row=>row.entry==='Scheduled Screensavers'))()")
  assert not errors,errors
  browser.close()
finally:
 server.shutdown()
print('Screensaver localization browser checks passed')
