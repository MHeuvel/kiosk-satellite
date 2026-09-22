"""Exercise the bundled renderer in Chromium with software WebGL."""
import os
from pathlib import Path
from playwright.sync_api import sync_playwright

APP = Path(__file__).resolve().parents[1]
CONDITIONS = ['sunny', 'clear-night', 'partlycloudy', 'cloudy', 'rainy',
              'pouring', 'snowy', 'snowy-rainy', 'fog', 'hail', 'lightning',
              'lightning-rainy', 'windy', 'windy-variant', 'exceptional']

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        executable_path=os.environ.get('CHROMIUM_PATH', '/usr/bin/chromium'),
        headless=True, args=['--no-sandbox', '--enable-unsafe-swiftshader'])
    page = browser.new_page(viewport={'width': 640, 'height': 360})
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.set_content('<style>html,body{margin:0}canvas{position:absolute;inset:0;width:100%;height:100%}</style>'
                     '<canvas id="scene"></canvas><canvas id="particles"></canvas>')
    low_power = os.environ.get('WEATHER_MOOD_LOW_POWER') == '1'
    page.evaluate('lowPower => window.__weatherMoodLowPower = lowPower', low_power)
    page.add_script_tag(path=str(APP / 'assets/screensaver/weather-mood.js'))
    if low_power:
        performance = page.evaluate('window.weatherMood.getPerformance()')
        assert performance['lowPower'] and performance['steps'] == 40
        assert performance['width'] <= 560 and performance['height'] <= 350
        assert performance['targetFps'] == 15
    page.evaluate('window.weatherMood.setActive(false)')

    def uniform(name):
        return page.evaluate('''name => {
          const gl=document.querySelector('#scene').getContext('webgl');
          const value=gl.getUniform(gl.getParameter(gl.CURRENT_PROGRAM),
            gl.getUniformLocation(gl.getParameter(gl.CURRENT_PROGRAM),name));
          return typeof value==='number'?value:Array.from(value);
        }''', name)

    for condition in CONDITIONS:
        for night in [False, True]:
            page.evaluate('data => window.weatherMood.update(data)',
                          {'condition': condition, 'night': night, 'immediate': True})
            assert uniform('weather')[1] == int(night), (condition, night)
            assert page.evaluate("document.querySelector('#scene').getContext('webgl').getError()") == 0
            assert page.evaluate('''() => {
              const gl=document.querySelector('#scene').getContext('webgl');
              const pixel=new Uint8Array(4);
              window.weatherMood.update({night:'''+str(night).lower()+''',immediate:true});
              gl.readPixels(Math.floor(gl.canvas.width/2),Math.floor(gl.canvas.height/2),1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixel);
              return pixel[0]+pixel[1]+pixel[2]>0;
            }'''), condition
    for condition, weather_index, effects_index in [
            ('rainy', 2, None), ('fog', 3, None), ('snowy', None, None),
            ('hail', None, 3), ('windy', None, 0), ('pouring', 2, 1),
            ('lightning', None, 2)]:
        page.evaluate('condition => window.weatherMood.update({condition,night:false,immediate:true})', condition)
        if weather_index is not None:
            assert uniform('weather')[weather_index] > 0
        if effects_index is not None:
            assert uniform('effects')[effects_index] > 0
        if condition == 'snowy':
            assert uniform('snowfall') > 0
    previous = uniform('weather')
    for condition in ['unknown', 'unavailable', '__proto__', 'unexpected']:
        page.evaluate('condition => window.weatherMood.update({condition,night:false})', condition)
        assert uniform('weather') == previous
    page.evaluate("window.weatherMood.update({condition:'lightning-rainy',night:true,lightning:false,immediate:true})")
    assert uniform('effects')[2] == 0
    assert uniform('flash') == 0
    assert uniform('weather')[2] > 0
    page.evaluate('window.weatherMood.setActive(true)')
    initial = uniform('time')
    page.wait_for_function("""initial => {
      const gl=document.querySelector('#scene').getContext('webgl');
      return gl.getUniform(gl.getParameter(gl.CURRENT_PROGRAM),gl.getUniformLocation(gl.getParameter(gl.CURRENT_PROGRAM),'time'))>initial;
    }""", arg=initial)
    page.evaluate('window.weatherMood.setActive(false)')
    initial = uniform('time')
    page.wait_for_timeout(200)
    assert uniform('time') == initial
    for width, height in [(360, 640), (1280, 720)]:
        page.set_viewport_size({'width': width, 'height': height})
        page.wait_for_timeout(100)
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        assert page.evaluate('document.documentElement.scrollHeight<=innerHeight')
    page.emulate_media(reduced_motion='reduce')
    page.evaluate('window.weatherMood.setActive(true)')
    initial = uniform('time')
    page.wait_for_timeout(200)
    assert uniform('time') == initial
    assert not errors, errors
    # A slow device must reduce work before its WebView becomes unresponsive.
    adaptive = browser.new_page(viewport={'width': 640, 'height': 360})
    adaptive.set_content('<canvas id="scene"></canvas><canvas id="particles"></canvas>')
    adaptive.evaluate("""() => {
      window.__weatherMoodLowPower=true;
      window.requestAnimationFrame=callback=>{window.nextWeatherFrame=callback;return 1;};
      window.cancelAnimationFrame=()=>{window.nextWeatherFrame=null;};
    }""")
    adaptive.add_script_tag(path=str(APP / 'assets/screensaver/weather-mood.js'))
    adaptive.evaluate("window.weatherMood.update({condition:'clear-night',night:true,immediate:true})")
    # The moon's native-resolution edge must survive a drop in cloud resolution.
    def moon_edge():
        return adaptive.evaluate('''() => {
          window.weatherMood.update({condition:'clear-night',night:true,immediate:true});
          const canvas=document.querySelector('#scene'),gl=canvas.getContext('webgl');
          const width=Math.floor(canvas.height*.066),pixels=new Uint8Array(width*4);
          gl.readPixels(Math.floor(canvas.width*.67-width/2),Math.floor(canvas.height*.76),
            width,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
          return Array.from(pixels);
        }''')
    initial_moon = moon_edge()
    start = adaptive.evaluate('window.weatherMood.getPerformance()')
    for frame in range(13):
        adaptive.evaluate('time=>window.nextWeatherFrame(time)', 1000+frame*200)
    end = adaptive.evaluate('window.weatherMood.getPerformance()')
    assert end['width'] < start['width'] and end['height'] < start['height']
    assert .5 <= end['resolutionScale'] < 1
    assert end['frames'] > start['frames']
    assert end['outputWidth'] == start['outputWidth'] == 640
    assert end['outputHeight'] == start['outputHeight'] == 360
    assert end['outputWidth'] > end['width']
    assert max(abs(a-b) for a, b in zip(initial_moon, moon_edge())) <= 2
    # The sharper moon must still disappear behind dense fog and clouds.
    fog_moon = adaptive.evaluate('''() => {
      window.weatherMood.update({condition:'fog',night:true,immediate:true});
      const canvas=document.querySelector('#scene'),gl=canvas.getContext('webgl');
      const pixel=new Uint8Array(4);
      gl.readPixels(Math.floor(canvas.width*.67),Math.floor(canvas.height*.76),
        1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixel);
      return pixel[0]+pixel[1]+pixel[2];
    }''')
    middle = (len(initial_moon)//8)*4
    assert fog_moon < sum(initial_moon[middle:middle+3])*.6
    adaptive.close()
    # Android may load the page before its platform view has been laid out.
    startup = browser.new_page(viewport={'width': 640, 'height': 360})
    startup.set_content('<canvas id="scene"></canvas><canvas id="particles"></canvas>')
    startup.evaluate('''() => {
      window.__weatherMoodLowPower=true;
      Object.defineProperty(window,'innerWidth',{value:0,configurable:true});
      Object.defineProperty(window,'innerHeight',{value:0,configurable:true});
    }''')
    startup.add_script_tag(path=str(APP / 'assets/screensaver/weather-mood.js'))
    assert startup.evaluate('''() => {
      weatherMood.update({condition:'sunny',night:false,immediate:true});
      return document.querySelector('#scene').getContext('webgl').getError();
    }''') == 0
    assert startup.evaluate('weatherMood.getPerformance().frames') == 0
    startup.evaluate('''() => {
      Object.defineProperty(window,'innerWidth',{value:640,configurable:true});
      Object.defineProperty(window,'innerHeight',{value:360,configurable:true});
      dispatchEvent(new Event('resize'));
    }''')
    assert startup.evaluate('weatherMood.getPerformance().frames') > 0
    assert startup.evaluate("document.querySelector('#scene').getContext('webgl').getError()") == 0
    startup.close()
    browser.close()
print('Weather Mood: 30 day/night combinations, weather effects, fallback, lightning toggle, pause, resize and native moon detail passed')
