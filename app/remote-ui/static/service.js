import { deviceText, t } from './localization.js';
import { watchUpdates } from './live.js';
import { api, cmd } from './core.js';
import { readOnlyRow } from './device.js';

/* ---- Kiosk Satellite Service page ---- */
// The device's Settings -> Device -> Kiosk Satellite Service page, mirrored:
// what the keep-alive foreground service is doing right now, why it is
// running, and the OS grants it needs for that. The page's one setting (the
// CPU wake lock) is rendered by the schema like any other row; this wraps
// it with the live cards above and below.

let stopWatching = null;

const fmtUptime = (ms) => {
  if (ms == null) return null;
  let s = Math.floor(ms / 1000);
  const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600),
    m = Math.floor((s % 3600) / 60);
  return d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : m ? `${m}m` : `${s}s`;
};

const get = async (name, params = {}) => {
  try { const r = await cmd(name, params); return r.ok ? r.data : null; }
  catch { return null; }
};

const titled = (title) => {
  const h = document.createElement('h2');
  h.className = 'card-title';
  h.textContent = deviceText(title);
  const card = document.createElement('div');
  card.className = 'card';
  return [h, card];
};

export function renderServicePage(panel) {
  stopWatching?.();
  // Above the schema's own card: the status and the reasons.
  const [statusHead, statusCard] = titled(deviceText('Status'));
  const [whyHead, whyCard] = titled(deviceText('Keeping it running'));
  panel.prepend(statusHead, statusCard, whyHead, whyCard);
  // Below it: the grants, in the three-state shape of the Permissions
  // Manager on the same tab.
  const [permHead, permCard] = titled(deviceText('Required system permissions'));
  panel.append(permHead, permCard);

  const renderStatus = (st) => {
    statusCard.innerHTML = '';
    whyCard.innerHTML = '';
    if (!st) {
      statusCard.appendChild(readOnlyRow(deviceText('Service'),
        deviceText('Status unavailable.'), ''));
      return;
    }
    const running = st.running === true;
    const fg = st.foreground === true;
    const up = fmtUptime(st.uptimeMs);
    statusCard.appendChild(readOnlyRow(deviceText('Service'),
      !running
        ? (st.error ? t('deviceServiceStopped', {error: st.error}) : deviceText('Stopped.'))
        : fg
          ? (up ? t('deviceServiceRunning', {uptime: up}) : deviceText('Running.'))
          : deviceText('Running without the foreground exemption.'),
      running ? deviceText('Running') : deviceText('Stopped')));
    const types = (st.types || []);
    statusCard.appendChild(readOnlyRow(deviceText('Foreground service types'),
      deviceText('What the service declares to Android for the features it holds up.'),
      types.length ? types.join(', ') : deviceText('none')));
    statusCard.appendChild(readOnlyRow(deviceText('CPU wake lock'),
      st.cpuAwake === false
        ? deviceText('Off: the setting below is off.')
        : st.cpuLockHeld
          ? deviceText('Held: the screen is off.')
          : st.screenInteractive
            ? deviceText('Released while the screen is on.')
            : deviceText('Not held.'),
      st.cpuLockHeld ? deviceText('Held') : deviceText('Released')));
    statusCard.appendChild(readOnlyRow(deviceText('Wi-Fi lock'),
      deviceText('Keeps the radio out of power saving through screen-off.'),
      st.wifiLockHeld ? deviceText('Held') : deviceText('Released')));
    statusCard.appendChild(readOnlyRow(deviceText('Notification'),
      st.notificationsEnabled === false
        ? deviceText('Hidden: notifications are turned off for the app. The service '
          + 'runs regardless.')
        : deviceText('Shown in the notification shade while the service runs.'),
      st.notificationsEnabled === false ? deviceText('Hidden') : deviceText('Shown')));
    const reasons = st.reasons || [];
    for (const r of reasons) {
      const row = readOnlyRow(r.title, r.detail, '');
      row.querySelector('span').remove();
      whyCard.appendChild(row);
    }
  };

  // Three states, like the Permissions Manager: granted, missing (and
  // something switched on needs it), or merely not granted.
  const permRow = (name, held, missing, idle, ask) => {
    const row = document.createElement('div');
    row.className = 'row';
    const info = document.createElement('div');
    info.className = 'info';
    info.innerHTML = '<div class="name"></div><div class="desc"></div>';
    info.querySelector('.name').textContent = deviceText(name);
    info.querySelector('.desc').textContent = deviceText('Checking...');
    row.appendChild(info);
    const state = document.createElement('span');
    state.style.whiteSpace = 'nowrap';
    row.appendChild(state);
    row._render = (granted, needed, adbHint) => {
      const ok = granted === true;
      // The device has no screen for the grant: the adb command stands in
      // for the button, and the row is not an error nobody can fix.
      const urgent = needed && !adbHint;
      info.querySelector('.desc').textContent =
        deviceText(granted == null ? 'Status unavailable.' : ok ? held : adbHint || (needed ? missing : idle));
      info.querySelector('.desc').style.color =
        ok || urgent || granted == null ? '' : 'var(--muted)';
      state.textContent = granted == null ? '' : ok ? deviceText('Granted')
        : adbHint ? deviceText('Not offered') : needed ? deviceText('Missing') : deviceText('Not granted');
      state.style.color = ok ? 'var(--ok)' : urgent ? 'var(--error)' : 'var(--muted)';
      row.querySelector('button')?.remove();
      if (ok || granted == null || adbHint) return;
      const btn = document.createElement('button');
      btn.className = 'btn-ghost';
      btn.textContent = deviceText('Grant on device');
      btn.style.cssText = 'flex-shrink:0;';
      btn.addEventListener('click', async () => {
        btn.disabled = true;
        try {
          await api('/api/commands/requestOsPermissions', {
            method: 'POST', body: JSON.stringify({ which: ask }) });
        } catch (_) { }
        await refreshPerms();
      });
      row.appendChild(btn);
    };
    return row;
  };

  const ROWS = {
    batteryUnrestricted: permRow(deviceText('Unrestricted battery'),
      deviceText('Allows the process to run in the background without being paused or killed.'),
      deviceText('Android may pause the app when the screen is off, dropping the Home '
        + 'Assistant connection and the ESPHome entities with it.'),
      '', ['batteryOptimizations']),
    displayOverOtherApps: permRow(deviceText('Display over other apps'),
      deviceText('Kiosk Satellite can bring itself back in the foreground.'),
      deviceText('Without this the service cannot relaunch the kiosk after a crash or '
        + 'a close from recents.'),
      deviceText('Needed to relaunch the kiosk after a crash.'), ['overlay']),
    notification: permRow(deviceText('Notifications'),
      deviceText("Allows the Kiosk Satellite Service's ongoing notification, which says what it is keeping alive."),
      deviceText("Needed to show the Kiosk Satellite Service's ongoing notification."),
      '', ['notifications']),
    microphone: permRow(deviceText('Microphone'),
      deviceText('Allows microphone usage for wake word detection, speech to text and intercom calls.'),
      deviceText('Background listening is on and nothing is listening.'),
      deviceText('Needed by background listening.'), ['microphone']),
    camera: permRow(deviceText('Camera'),
      deviceText('Motion detection and snapshots can use the camera.'),
      deviceText('The camera is switched on and cannot be opened.'),
      deviceText('Needed by motion detection.'), ['camera']),
    bluetooth: permRow(deviceText('Nearby devices'),
      deviceText('The Bluetooth proxy can scan for nearby devices.'),
      deviceText('The Bluetooth proxy is switched on and cannot scan.'),
      deviceText('Needed by the Bluetooth proxy to scan for devices.'),
      ['bluetoothScan', 'bluetoothConnect']),
  };
  // Always: the three the service needs whatever runs. The feature rows
  // only appear while their feature is one of the reasons.
  const ALWAYS = ['batteryUnrestricted', 'displayOverOtherApps', 'notification'];
  // Grants a device may have no settings screen for: the payload flag that
  // says so, and the adb command shown instead of the button.
  const ADB = {
    batteryUnrestricted: ['batteryRequestable', deviceText("This device has no settings screen for it. Grant it over adb: adb shell dumpsys deviceidle whitelist +me.jxl.kiosk_satellite")],
    displayOverOtherApps: ['overlayRequestable', deviceText("This device has no settings screen for it. Grant it over adb: adb shell appops set me.jxl.kiosk_satellite SYSTEM_ALERT_WINDOW allow")],
  };
  const FEATURE = { microphone: 'listening', camera: 'camera', bluetooth: 'bluetooth' };

  let grants = {};
  let reasonIds = new Set();
  const placeRows = () => {
    permCard.innerHTML = '';
    for (const k of ALWAYS) permCard.appendChild(ROWS[k]);
    for (const [k, reason] of Object.entries(FEATURE)) {
      if (reasonIds.has(reason)) permCard.appendChild(ROWS[k]);
    }
  };

  // Returns whether every row now reads granted, for the button polls.
  const refreshPerms = async (results) => {
    const p = results?.getSystemPermissions?.data || await get('getSystemPermissions');
    if (!p) {
      for (const row of Object.values(ROWS)) row._render(null, false);
      return null;
    }
    let all = true;
    for (const [k, row] of Object.entries(ROWS)) {
      if (!row.isConnected) continue;
      const granted = p[k] === true;
      row._render(granted, grants[k] === true, !granted && ADB[k] && p[ADB[k][0]] === false ? ADB[k][1] : null);
      if (!granted) all = false;
    }
    return all;
  };

  const refresh = async (results) => {
    const st = results?.getServiceStatus?.data || await get('getServiceStatus');
    renderStatus(st);
    grants = st?.grants || {};
    reasonIds = new Set((st?.reasons || []).map((r) => r.id));
    placeRows();
    await refreshPerms(results);
  };

  refresh();
  stopWatching = watchUpdates(['service'], refresh, { owner: panel });
}
