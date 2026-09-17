"""Browser checks against the server started by remote_browser_test.dart."""
import json
import sys
from playwright.sync_api import sync_playwright, expect

base = sys.argv[1]
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    context = browser.new_context(viewport={"width": 1400, "height": 1000}, locale='en-US')
    response = context.request.post(base + '/api/login', data=json.dumps({'password': 'secret'}))
    token = response.json()['token']
    context.add_init_script('localStorage.setItem("ks_token", ' + json.dumps(token) + ')')
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    frames = []
    page.on('websocket', lambda socket: socket.on('framesent', lambda frame: frames.append(json.loads(frame))))
    boot_requests = []
    page.on('request', lambda request: boot_requests.append(request.url))
    page.goto(base + '/#camera/RTSP%20&%20ONVIF%20Streaming')
    expect(page.locator('#app')).to_be_visible(timeout=30000)
    # The boot reads everything through the socket: the only HTTP calls
    # are the public setup probe, the page and its static files and the
    # one-shot screenshot.
    polled = [url for url in boot_requests if any(part in url for part in
        ('/api/info', '/api/settings', '/api/commands/', '/api/console', '/api/logs'))]
    assert not polled, polled
    assert [frame for frame in frames if frame.get('type') == 'get' and frame.get('name') == 'info'], frames
    assert not [frame for frame in frames if frame.get('type') == 'get' and frame.get('name') == 'settings'], frames
    expect(page).to_have_url(base + '/#camera/rtsp-onvif-streaming')
    expect(page.locator('#pageTitle')).to_have_text('RTSP & ONVIF Streaming')
    expect(page.locator('#connDot')).to_have_class('dot on')
    requests = []
    page.on('request', lambda request: requests.append(request.url))

    def change(key, value):
        result = context.request.post(base + '/api/commands/testSetSetting',
            headers={'Authorization': 'Bearer ' + token},
            data=json.dumps({'key': key, 'value': value}))
        assert result.json()['ok'] and result.json()['data'] is True, result.text()

    # A device language change repaints the open admin without a page reload.
    page.locator('#tabs button[data-tab="device"]').click()
    name = page.locator('[data-key="device.name"] .name')
    language = page.locator('[data-key="ui.language"] select')
    expect(name).to_have_text('Device name')
    page.evaluate('window.languageTestMarker = true')
    change('ui.language', 'es')
    expect(name).to_have_text('Nombre del dispositivo')
    expect(language).to_have_value('es')
    assert page.evaluate('window.languageTestMarker') is True
    # The saved choice also wins over an English browser on a fresh load.
    page.reload()
    expect(name).to_have_text('Nombre del dispositivo')
    # Changing the dropdown in this browser applies the new language too.
    language.select_option('en')
    expect(name).to_have_text('Device name')
    language.select_option('es')
    expect(name).to_have_text('Nombre del dispositivo')
    expect(language.locator('option[value="system"]')).to_have_count(0)
    language.select_option('en')
    expect(name).to_have_text('Device name')

    page.locator('#tabs button[data-tab="screensaver"]').click()
    mode = page.locator('[data-key="screensaver.mode"] select')
    expect(mode).to_be_visible()
    change('screensaver.mode', 'black')
    expect(mode).to_have_value('black')
    change('screensaver.mode', 'clock')
    expect(mode).to_have_value('clock')
    expect(page.locator('[data-subpage-entry="Clock screensaver"]')).to_be_visible()

    # Visiting a page that reads settings must not disconnect existing sliders.
    page.locator('#tabs button[data-tab="gestures"]').click()
    expect(page.locator('[data-key="gestures.clap_strictness"]')).to_be_visible()
    page.locator('#tabs button[data-tab="sendspin"]').click()
    duck_row = page.locator('[data-key="sendspin.duck_percent"]')
    duck = duck_row.locator('input[type="range"]')
    expect(duck).to_have_value('10')
    duck_row.evaluate('row => row.dataset.preserved = "yes"')
    change('sendspin.duck_percent', 20)
    expect(duck).to_have_value('20')
    expect(duck_row.locator('.slider-value')).to_have_text('20%')
    expect(duck).to_have_css('--pct', '80.00%')
    expect(duck_row).to_have_attribute('data-preserved', 'yes')
    page.locator('#tabs button[data-tab="cameras"]').click()
    expect(page.locator('#tab-cameras').get_by_text('Import cameras from Home Assistant', exact=True)).to_be_visible()
    page.locator('#tabs button[data-tab="sendspin"]').click()
    frames.clear()
    change('sendspin.duck_percent', 5)
    expect(duck).to_have_value('5')
    expect(duck_row.locator('.slider-value')).to_have_text('5%')
    expect(duck).to_have_css('--pct', '20.00%')
    expect(duck_row).to_have_attribute('data-preserved', 'yes')
    assert not [frame for frame in frames if frame.get('type') == 'settings'], frames

    # A hand-built player select must follow both the chosen ID and source.
    page.locator('#tabs button[data-tab="sendspin"]').click()
    player = page.locator('[data-key="sendspin.player"] select')
    expect(player).to_have_value('ha:media_player.first')
    change('sendspin.player', 'ha:media_player.second')
    expect(player).to_have_value('ha:media_player.second')
    change('sendspin.player', 'ha:media_player.unlisted')
    expect(player).to_have_value('ha:media_player.unlisted')
    change('sendspin.player_name', 'Second speaker renamed')
    expect(page.locator('.player-warn')).to_contain_text('Second speaker renamed')
    change('sendspin.player_source', 'ma')
    expect(page.locator('[data-key="sendspin.player_source"] select')).to_have_value('ma')
    expect(player).to_have_attribute('data-source', 'ma')
    change('sendspin.player', 'ma:media_player.second')
    expect(player).to_have_value('ma:media_player.second')

    # The selected player's label and other sections stay in place.
    expect(player.locator('option:checked')).to_have_text('Second speaker renamed')
    page.locator('[data-key="sendspin.duck_percent"]').evaluate('el => el.dataset.kept = "yes"')
    change('sendspin.player_name', 'Office')
    expect(player.locator('option:checked')).to_have_text('Office')
    expect(page.locator('[data-key="sendspin.duck_percent"]')).to_have_attribute('data-kept', 'yes')

    def route(path):
        page.evaluate('(path) => { location.hash = path; }', path)

    # Every Media Player subpage, including dependent controls.
    for path, key, value, kind in [
        ('sendspin/floating-player', 'sendspin.show_player', True, 'checkbox'),
        ('sendspin/floating-player', 'sendspin.player_size', 'large', 'select'),
        ('sendspin/now-playing', 'sendspin.fullscreen', True, 'checkbox'),
        ('sendspin/now-playing', 'sendspin.fullscreen_text_scale', 120, 'range'),
        ('sendspin/music-assistant', 'sendspin.ma_open_fullscreen', True, 'checkbox'),
        ('sendspin/lyrics', 'sendspin.lyrics_enabled', True, 'checkbox'),
        ('sendspin/lyrics', 'sendspin.lyrics_source', 'ma', 'select'),
        ('sendspin/sonos', 'sendspin.sonos_inputs', True, 'checkbox'),
    ]:
        change(key, value)
        route(path)
        control = page.locator(f'[data-key="{key}"] ' + ('select' if kind == 'select' else f'input[type="{kind}"]'))
        expect(page.locator(f'[data-key="{key}"]')).to_be_visible()
        if kind == 'checkbox': expect(control).to_be_checked()
        else: expect(control).to_have_value(str(value))

    # Writes from another admin use the same socket path and update peers.
    peer = context.new_page()
    peer.goto(base + '/#sendspin/lyrics')
    expect(peer.locator('[data-key="sendspin.lyrics_source"] select')).to_have_value('ma')
    route('sendspin/lyrics')
    page.locator('[data-key="sendspin.lyrics_source"] select').select_option('lrclib')
    expect(peer.locator('[data-key="sendspin.lyrics_source"] select')).to_have_value('lrclib')
    expect(peer.locator('[data-key="sendspin.lyrics_fallback_ma"]')).to_be_visible()
    expect(page.locator('[data-key="sendspin.lyrics_fallback_ma"]')).to_be_visible()
    peer.close()
    route('sendspin/sonos')

    change('sendspin.sonos_hosts', json.dumps({'room': {'name': 'Kitchen Sonos', 'host': '192.0.2.3'}}))
    expect(page.locator('.sonos-speakers')).to_contain_text('Kitchen Sonos')
    change('sendspin.sonos_hosts', '{}')
    expect(page.locator('.sonos-speakers')).to_contain_text('No speakers yet')

    # Hand-built summaries, color pickers and dependent sections elsewhere.
    change('screensaver.mode', 'clock')
    route('screensaver/clock-screensaver')
    change('screensaver.clock_color', '10,20,30')
    expect(page.locator('[data-key="screensaver.clock_color"] .swatch')).to_have_css('background-color', 'rgb(10, 20, 30)')
    change('launcher.enabled', True)
    route('launcher')
    change('launcher.apps', json.dumps([{'package': 'example.app', 'label': 'Example app'}]))
    expect(page.locator('[data-key="launcher.apps"]')).to_contain_text('Example app')
    change('launcher.auto_return', True)
    expect(page.locator('#tab-launcher').get_by_text('Required system permissions', exact=True)).to_be_visible()
    change('launcher.auto_return', False)
    expect(page.locator('#tab-launcher').get_by_text('Required system permissions', exact=True)).to_be_hidden()
    route('screenaudio/microphone-settings')
    change('audio.mic_agc', True)
    expect(page.locator('[data-key="audio.mic_gain_db"]')).to_be_hidden()
    change('audio.mic_agc', False)
    expect(page.locator('[data-key="audio.mic_gain_db"]')).to_be_visible()
    route('screenaudio')
    context.request.post(base + '/api/commands/testAudioConnected', headers={'Authorization': 'Bearer ' + token}, data='{}')
    expect(page.locator('[data-key="audio.speaker_device"] option[value="usb|1|USB Speaker"]')).to_have_count(1)
    change('audio.speaker_device', 'usb|1|USB Speaker')
    expect(page.locator('[data-key="audio.speaker_device"] select')).to_have_value('usb|1|USB Speaker')
    change('dlna.enabled', True)
    route('dlna')
    change('dlna.audio_background', True)
    expect(page.locator('[data-key="dlna.audio_background"] input')).to_be_checked()
    route('browser')
    change('browser.zoom', 1.25)
    expect(page.locator('[data-key="browser.zoom"] input')).to_have_value('1.25')

    # A device update must not throw away an unfinished text edit.
    page.locator('#tabs button[data-tab="browser"]').click()
    field = page.locator('[data-key="browser.inject_js"] textarea')
    expect(field).to_be_visible()
    field.fill('window.unfinishedDraft = true;')
    change('screensaver.mode', 'black')
    expect(field).to_have_value('window.unfinishedDraft = true;')
    expect(field).to_be_focused()

    # Reconnect reads changes made while this browser had no event feed.
    context.set_offline(True)
    page.evaluate("""async () => {
      const url = performance.getEntriesByType('resource')
        .find(entry => new URL(entry.name).pathname === '/static/core.js').name;
      (await import(url)).state.ws.close();
    }""")
    expect(page.locator('#connDot')).to_have_class('dot off')
    # A dropped connection covers the page until the socket is back.
    expect(page.locator('.reconnect-back')).to_be_visible()
    expect(page.locator('.reconnect-back')).to_contain_text('Reconnecting')
    expect(page.locator('.reconnect-back')).to_contain_text('Test kiosk')
    # Browser contexts also take their request client offline, so use a
    # separate client while this one has no network.
    import urllib.request
    req = urllib.request.Request(base + '/api/commands/testSetSetting',
        data=json.dumps({'key': 'screensaver.mode', 'value': 'clock'}).encode(),
        headers={'Authorization': 'Bearer ' + token})
    with urllib.request.urlopen(req) as response:
        assert json.load(response)['ok']
    context.set_offline(False)
    expect(page.locator('#connDot')).to_have_class('dot on', timeout=30000)
    expect(page.locator('.reconnect-back')).to_have_count(0)
    page.locator('#tabs button[data-tab="screensaver"]').click()
    expect(page.locator('[data-key="screensaver.mode"] select')).to_have_value('clock')
    page.wait_for_timeout(1000)
    requests.clear()
    frames.clear()
    page.wait_for_timeout(6000)
    assert not [frame for frame in frames if frame.get('type') in ('command', 'settings')], frames
    assert not [url for url in requests if '/api/commands/' in url or '/api/settings' in url], requests

    # A settings flip repaints the Overview's tiles from the cache. Only a
    # setting a status command reads (the HA link) re-reads, and only that
    # one source.
    page.locator('#tabs button[data-tab="dashboard"]').click()
    expect(page.locator('#statusGrid [data-status="ha"]')).to_be_visible()
    page.wait_for_timeout(1500)
    frames.clear()
    change('screen.keep_on', True)
    change('browser.zoom', 1.1)
    page.wait_for_timeout(1500)
    assert not [f for f in frames if f.get('type') == 'command'], frames
    change('ha.url', 'http://ha.example/')
    page.wait_for_timeout(1500)
    assert [f.get('name') for f in frames if f.get('type') == 'command'] == ['haStatus'], frames

    # The app restarted on a new build: the reconnect's snapshot names it,
    # the page says so and reloads itself onto the new bundle.
    context.request.post(base + '/api/commands/testSetVersion',
        headers={'Authorization': 'Bearer ' + token}, data=json.dumps({'version': '2026.9.59'}))
    page.evaluate("""async () => {
      const url = performance.getEntriesByType('resource')
        .find(entry => new URL(entry.name).pathname === '/static/core.js').name;
      (await import(url)).state.ws.close();
    }""")
    notice = page.locator('.modal-card')
    expect(notice).to_contain_text('2026.9.59', timeout=15000)
    expect(notice).to_contain_text('reload in')
    expect(notice).to_have_count(0, timeout=15000)
    expect(page.locator('#app')).to_be_visible(timeout=30000)
    page.wait_for_timeout(2500)
    expect(page.locator('.modal-card')).to_have_count(0)
    assert page.evaluate("""async () => {
      const url = performance.getEntriesByType('resource')
        .find(entry => new URL(entry.name).pathname === '/static/core.js').name;
      return (await import(url)).state.appVersion;
    }""") == '2026.9.59+259'
    assert not errors, errors
    browser.close()
    print('Live settings across Media Player and other sections, peer writes, audio events, drafts, reconnects and idle traffic passed')
