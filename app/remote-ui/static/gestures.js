import { gestureText, cameraText, localizeSetting, t } from './localization.js';
import { watchUpdates } from './live.js';
import {
  cameraAction,
  cameraEditor,
  cameraField,
  cameraIcon,
  cameraListRow,
  cameraSelectField,
} from './cameras.js';
import { api, cmd, state } from './core.js';
import { applyManagedBanners } from './fleetsync.js';
import { settingRow } from './rows.js';
import { fetchViews, radioRow } from './views.js';
import { messageBox, localizedMessageBox, modalShell } from './widgets.js';

/* ---- Gestures (issue #99) ----
   Mirror of the device's Gestures page (ui/gesture_settings.dart): the
   list of gestures and the actions they trigger, stored as the
   gestures.mappings JSON setting. The editor is two-staged there and
   here: the main modal owns the trigger, and each action type configures

   itself in its own modal. */

export const GESTURE_CORNERS = {
  tl: 'top-left', tr: 'top-right', bl: 'bottom-left', br: 'bottom-right',
};
export const GESTURE_TRIGGERS = [
  ['corner_taps', 'Taps in a corner'],
  ['corner_hold', 'Hold a corner'],
  ['finger_taps', 'Multi-finger tap'],
  ['finger_hold', 'Multi-finger hold'],
  ['corner_sequence', 'Corner sequence'],
  ['claps', 'Claps'],
  ['fingers', 'Show fingers'],
];
export const GESTURE_ACTION_GROUPS = [
  ['Kiosk Satellite', [
    ['navigate', 'Go to a dashboard view', 'grid'],
    ['url', 'Open a web page', 'globe'],
    ['camera_view', 'Show a camera view', 'video'],
    ['sendspin_player', 'Show the floating player', 'speaker'],
    ['now_playing', 'Show Now Playing', 'playCircle'],
    ['music_assistant', 'Open Music Assistant', 'music'],
    ['app_launcher', 'Open the app launcher', 'apps'],
    ['intercom_open', 'Open Call a kiosk', 'speaker'],
    ['intercom_call', 'Call a kiosk', 'speaker'],
    ['screensaver', 'Start the screensaver', 'moon'],
    ['screensaver_stop', 'Stop the screensaver', 'sun'],
    ['hold_mode', 'Toggle hold mode', 'pauseCircle'],
    ['ha_kiosk', 'Toggle HA kiosk mode', 'fullscreen'],
    ['plugin_action', 'Run a plugin action', 'playCircle'],
  ]],
  ['Android', [
    ['launch_app', 'Open another app', 'apps'],
    ['open_uri', 'Open a deep link', 'link'],
    ['android_settings', 'Open Android Settings', 'android'],
  ]],
  ['Home Assistant', [
    ['ha_service', 'Call a service', 'home'],
    ['ha_script', 'Run a script', 'doc'],
    ['ha_automation', 'Trigger an automation', 'playCircle'],
    ['ha_event', 'Fire an event', 'announce'],
  ]],
];

export function gestureCorner(corner) {
  const name = GESTURE_CORNERS[corner];
  return name ? gestureText(name[0].toUpperCase() + name.slice(1) + ' corner') : corner;
}

export function describeGestureTrigger(trigger) {
  const corner = gestureText(GESTURE_CORNERS[trigger.corner] || '');
  const seconds = () => {
    const value = (Number(trigger.holdMs) || 1500) / 1000;
    return Number.isInteger(value) ? String(value) : value.toFixed(1);
  };
  switch (trigger.type) {
    case 'corner_taps': return t('gestureDescribeCornerTaps', {count: trigger.taps, corner});
    case 'corner_hold': return t('gestureDescribeCornerHold', {corner, seconds: seconds()});
    case 'finger_taps': return t(Number(trigger.taps) === 2 ? 'gestureDescribeFingerDouble' : 'gestureDescribeFingerTap', {count: trigger.fingers});
    case 'finger_hold': return t('gestureDescribeFingerHold', {count: trigger.fingers, seconds: seconds()});
    case 'corner_sequence': return t('gestureDescribeSequence', {sequence: (trigger.sequence || []).map(gestureCorner).join(' > ')});
    case 'claps': return t('gestureDescribeClaps', {count: trigger.claps});
    case 'fingers': {
      const count = Number(trigger.fingers) || 5;
      return count === 5 ? gestureText('Show an open hand') : t(count === 1 ? 'gestureDescribeOneFinger' : 'gestureDescribeFingers', {count});
    }
  }
  return gestureText('Gesture');
}

export function describeGestureAction(a) {
  if (a.type === 'plugin_action') return `${a.pluginName || a.pluginId}: ${a.title || a.command}`;
  switch (a.type) {
    case 'navigate': return t('gestureGoTo', {value: a.path});
    case 'url': return t('gestureOpen', {value: a.url});
    case 'camera_view':
      if (a.mode === 'hide') return gestureText('Close the camera view');
      return a.viewName ? t('gestureCameraToggleName', {name: a.viewName}) : gestureText('Toggle the camera view');
    case 'sendspin_player': return gestureText('Show the floating player');
    case 'now_playing': return gestureText('Show Now Playing');
    case 'music_assistant': return gestureText('Open Music Assistant');
    case 'app_launcher': return gestureText('Open the app launcher');
    case 'intercom_open': return gestureText('Open Call a kiosk');
    case 'intercom_call': return t('gestureCall', {value: a.kioskName || a.kioskId});
    case 'screensaver': return gestureText('Start the screensaver');
    case 'screensaver_stop': return gestureText('Stop the screensaver');
    case 'hold_mode': return gestureText('Toggle hold mode');
    case 'ha_kiosk': return gestureText('Toggle HA kiosk mode');
    case 'launch_app': return t('gestureOpenApp', {package: a.package});
    case 'open_uri': return t('gestureOpen', {value: a.uri});
    case 'android_settings': return gestureText('Open Android Settings');
    case 'ha_service': return t('gestureCall', {value: `${a.domain}.${a.service}`});
    case 'ha_script': return t('gestureRun', {value: a.entityId});
    case 'ha_automation': return t('gestureTriggerAction', {value: a.entityId});
    case 'ha_event': return t('gestureFireEvent', {value: a.event});
  }
  return gestureText('Action');
}

export function readGestureMappings() {
  const setting = (state.settings || []).find((s) => s.key === 'gestures.mappings');
  try {
    const list = JSON.parse(setting?.value ?? '[]');
    return Array.isArray(list) ? list.filter((m) => m && m.id && m.trigger && m.action) : [];
  } catch (_) { return []; }
}

export async function saveGestureMappings(mappings) {
  const json = JSON.stringify(mappings);
  const cached = (state.settings || []).find((s) => s.key === 'gestures.mappings');
  if (cached) cached.value = json;
  await api('/api/settings', {
    method: 'PATCH',
    body: JSON.stringify({ 'gestures.mappings': json }),
  });
}

// A radio-list modal (the pickView shape): resolves the picked item's
// value, or null on close.
export function gestureListModal(title, items) {
  return new Promise((resolve) => {
    const { back, body, foot } = modalShell({
      title,
      onDismiss: () => { back.remove(); resolve(null); },
    });
    items.forEach((item) => {
      if (item.header) {
        const label = document.createElement('h2');
        label.className = 'card-title';
        label.textContent = item.header;
        label.style.cssText = 'margin:14px 0 4px; padding:0;';
        body.appendChild(label);
        return;
      }
      const row = radioRow(
        item.name, item.desc || '', !!item.selected,
        () => { back.remove(); resolve(item.value); });
      if (item.icon) {
        const icon = document.createElement('span');
        icon.className = 'camera-row-icon';
        icon.innerHTML = cameraIcon(item.icon);
        row.prepend(icon);
      }
      body.appendChild(row);
    });
    const cancel = document.createElement('button');
    cancel.className = 'btn-text';
    cancel.textContent = gestureText('Cancel');
    cancel.addEventListener('click', () => { back.remove(); resolve(null); });
    foot.appendChild(cancel);
  });
}

export function gestureTextarea(label, value = '', placeholder = '') {
  const wrap = document.createElement('label');
  wrap.className = 'form-field';
  const title = document.createElement('span');
  title.className = 'desc';
  title.textContent = label;
  const input = document.createElement('textarea');
  input.className = 'field';
  input.rows = 3;
  input.style.maxWidth = 'none';
  input.value = value;
  input.placeholder = placeholder;
  wrap.append(title, input);
  return { wrap, input };
}

// One required text field: the URL, app package and deep link dialogs.
export async function configureGestureText(current, spec) {
  const body = document.createElement('div');
  const field = cameraField(spec.label, current ? String(current[spec.field] || '') : '');
  field.input.placeholder = spec.placeholder;
  body.appendChild(field.wrap);
  let out = null;
  const saved = await cameraEditor({
    title: spec.title,
    body,
    save: async () => {
      const value = field.input.value.trim();
      const invalid = spec.validate(value);
      if (invalid) return { ok: false, error: invalid };
      out = { type: spec.type, [spec.field]: value };
      return { ok: true };
    },
  });
  return saved ? out : null;
}

// Run haValidateAction and reduce its answer to one sentence: [ok, message].
export async function validateGestureHaAction(domain, service, entity) {
  let result;
  try {
    result = await cmd('haValidateAction', {
      domain, service, ...(entity ? { entity_id: entity } : {}),
    });
  } catch (_) { result = null; }
  if (!result?.ok) return [false, result?.error || gestureText('Could not validate.')];
  const data = result.data || {};
  if (data.domain === false) return [false, t('gestureDomainMissing', {value: domain})];
  if (data.service === false) {
    return [false, t('gestureServiceMissing', {value: `${domain}.${service}`})];
  }
  if (data.entity === false) return [false, t('gestureEntityMissing', {value: entity})];
  return [true, gestureText('Looks good.')];
}

// The Validate row for the HA editors: ghost button plus status line.
// getCheck() returns {domain, service, entity} or a string error.
export function gestureValidateRow(getCheck) {
  const wrap = document.createElement('div');
  wrap.style.cssText = 'display:flex; align-items:center; gap:10px;';
  const status = document.createElement('span');
  status.className = 'desc';
  status.style.flex = '1';
  const button = cameraAction(gestureText('Validate'), async () => {
    const check = getCheck();
    if (typeof check === 'string') {
      status.style.color = 'var(--error)';
      status.textContent = check;
      return;
    }
    button.disabled = true;
    status.style.color = '';
    status.textContent = gestureText('Checking…');
    const [ok, message] =
      await validateGestureHaAction(check.domain, check.service, check.entity);
    button.disabled = false;
    status.style.color = ok ? 'var(--ok)' : 'var(--error)';
    status.textContent = message;
  });
  wrap.append(button, status);
  return wrap;
}

// One Home Assistant entity plus a Validate check: the script and
// automation dialogs. A bare name is qualified with the domain.
export async function configureGestureHaEntity(current, spec) {
  const body = document.createElement('div');
  const entity = cameraField(spec.label, current?.entityId || '');
  entity.input.placeholder = spec.hint;
  const qualified = () => {
    const value = entity.input.value.trim();
    return !value || value.includes('.') ? value : `${spec.domain}.${value}`;
  };
  body.append(entity.wrap, gestureValidateRow(() => qualified()
    ? { domain: spec.domain, service: spec.service, entity: qualified() }
    : t('gestureEntityRequired', {domain: spec.domain})));
  let out = null;
  const saved = await cameraEditor({
    title: spec.title,
    body,
    save: async () => {
      const value = qualified();
      if (!value.startsWith(`${spec.domain}.`)
        || value.length <= spec.domain.length + 1) {
        return { ok: false, error: t('gestureEntityRequired', {domain: spec.domain}) };
      }
      out = { type: spec.type, entityId: value };
      return { ok: true };
    },
  });
  return saved ? out : null;
}

export async function configureGestureNavigate(current) {
  // Every dashboard's views, flattened like the rotation picker. Strategy
  // dashboards expose no views; their root still makes a fine target.
  const entries = [];
  const dashboards = await cmd('haListDashboards').catch(() => null);
  if (dashboards?.ok && Array.isArray(dashboards.data)) {
    for (const d of dashboards.data) {
      if (!d.url_path) continue;
      const views = await fetchViews(d.url_path);
      if (views?.length) {
        for (const v of views) {
          if (!v.route) continue;
          entries.push({
            name: `${d.title || d.url_path} / ${v.title || v.route}`,
            value: `${d.url_path}/${v.route}`,
          });
        }
      } else {
        entries.push({ name: d.title || d.url_path, value: d.url_path });
      }
    }
  }
  if (!entries.length) {
    await messageBox({
      title: gestureText('No dashboards'),
      message: gestureText('Could not list dashboards. Is Home Assistant connected?'),
    });
    return null;
  }
  const path = await gestureListModal(gestureText('Go to a dashboard view'), entries.map((e) => ({
    ...e, selected: current?.path === e.value,
  })));
  return path ? { type: 'navigate', path } : null;
}

export async function configureGestureCameraView(current) {
  const result = await cmd('cameraGetConfig').catch(() => null);
  const views = result?.ok ? result.data.views : [];
  const items = views.map((view) => ({
    name: t('gestureCameraShow', {name: view.name}),
    selected: current?.mode === 'show' && current?.viewId === view.id,
    value: view,
  }));
  items.push({
    name: gestureText('Close the camera view'),
    selected: current?.mode === 'hide',
    value: 'hide',
  });
  const picked = await gestureListModal(gestureText('Camera view'), items);
  if (!picked) return null;
  if (picked === 'hide') return { type: 'camera_view', mode: 'hide' };
  return {
    type: 'camera_view', mode: 'show', viewId: picked.id, viewName: picked.name,
  };
}

// The kiosk a Call a kiosk gesture rings: every kiosk the intercom has
// heard, whatever its state today.
export async function configureGestureIntercomCall(current) {
  const result = await cmd('intercomStatus').catch(() => null);
  const kiosks = result?.ok ? (result.data.kiosks || []) : [];
  const items = kiosks.map((k) => ({
    name: k.name, desc: k.address,
    selected: current?.kioskId === k.id,
    value: k,
  }));
  if (!items.length) items.push({ name: gestureText('No kiosk found on the network yet.'), desc: '', value: null });
  const picked = await gestureListModal(gestureText('Call a kiosk'), items);
  if (!picked) return null;
  return { type: 'intercom_call', kioskId: picked.id, kioskName: picked.name };
}

// data must parse as a JSON object when present; shared by the two HA
// dialogs.
export function parseGestureData(text) {
  if (!text.trim()) return { ok: true, value: null };
  try {
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw 0;
    return { ok: true, value: parsed };
  } catch (_) { return { ok: false }; }
}

export async function configureGestureHaService(current) {
  const body = document.createElement('div');
  const domain = cameraField(gestureText('Domain'), current?.domain || '');
  domain.input.placeholder = 'light';
  const service = cameraField(gestureText('Service'), current?.service || '');
  service.input.placeholder = 'turn_on';
  const entity = cameraField(gestureText('Entity (optional)'), current?.entityId || '');
  entity.input.placeholder = 'light.kitchen';
  const data = gestureTextarea(gestureText('Service data (optional)'),
    current?.data ? JSON.stringify(current.data) : '', '{"brightness_pct": 60}');
  body.append(domain.wrap, service.wrap, entity.wrap, data.wrap,
    gestureValidateRow(() => domain.input.value.trim() && service.input.value.trim()
      ? {
        domain: domain.input.value.trim(),
        service: service.input.value.trim(),
        entity: entity.input.value.trim(),
      }
      : gestureText('Domain and service are required.')));
  let out = null;
  const saved = await cameraEditor({
    title: gestureText('Call a Home Assistant service'),
    body,
    save: async () => {
      if (!domain.input.value.trim() || !service.input.value.trim()) {
        return { ok: false, error: gestureText('Domain and service are required.') };
      }
      const parsed = parseGestureData(data.input.value);
      if (!parsed.ok) return { ok: false, error: gestureText('Service data must be a JSON object.') };
      out = {
        type: 'ha_service',
        domain: domain.input.value.trim(),
        service: service.input.value.trim(),
      };
      if (entity.input.value.trim()) out.entityId = entity.input.value.trim();
      if (parsed.value) out.data = parsed.value;
      return { ok: true };
    },
  });
  return saved ? out : null;
}

export async function configureGestureHaEvent(current) {
  const body = document.createElement('div');
  const event = cameraField(gestureText('Event type'), current?.event || '');
  event.input.placeholder = 'kiosk_satellite_gesture';
  const data = gestureTextarea(gestureText('Event data (optional)'),
    current?.data ? JSON.stringify(current.data) : '', '{"room": "kitchen"}');
  body.append(event.wrap, data.wrap);
  let out = null;
  const saved = await cameraEditor({
    title: gestureText('Fire a Home Assistant event'),
    body,
    save: async () => {
      if (!event.input.value.trim()) {
        return { ok: false, error: gestureText('Event type is required.') };
      }
      const parsed = parseGestureData(data.input.value);
      if (!parsed.ok) return { ok: false, error: gestureText('Event data must be a JSON object.') };
      out = { type: 'ha_event', event: event.input.value.trim() };
      if (parsed.value) out.data = parsed.value;
      return { ok: true };
    },
  });
  return saved ? out : null;
}

// The chooser, then the chosen type's own configuration dialog. Types with
// nothing to configure resolve directly.
export async function pickGestureAction(current) {
  const items = [];
  for (const [group, actions] of GESTURE_ACTION_GROUPS) {
    items.push({ header: group });
    for (const [value, label, icon] of actions) {
      items.push({
        name: gestureText(label), selected: current?.type === value, value, icon,
      });
    }
  }
  const type = await gestureListModal(gestureText('Action'), items);
  if (!type) return null;
  const carried = current?.type === type ? current : null;
  switch (type) {
    case 'plugin_action': {
      const result = await cmd('getPluginActions');
      if (!result.ok) { await messageBox({ title: gestureText('Plugin actions'), message: result.error || gestureText('Could not load plugin actions.') }); return null; }
      const actions = (result.data || []).filter((action) => action.available);
      if (!actions.length) { await messageBox({ title: gestureText('Plugin actions'), message: gestureText('Enable a plugin with actions in Plugin Manager first.') }); return null; }
      return gestureListModal(gestureText('Plugin action'), actions.map((action) => ({
        name: action.title, desc: action.pluginName,
        value: { type, pluginId: action.pluginId, command: action.command, pluginName: action.pluginName, title: action.title },
        selected: carried?.pluginId === action.pluginId && carried?.command === action.command,
      })));
    }
    case 'android_settings': case 'sendspin_player': case 'app_launcher':
    case 'screensaver': case 'screensaver_stop': case 'hold_mode':
    case 'ha_kiosk': case 'now_playing': case 'music_assistant':
    case 'intercom_open':
      return { type };
    case 'navigate': return configureGestureNavigate(carried);
    case 'url': return configureGestureText(carried, {
      type: 'url', title: gestureText('Open a web page'), field: 'url', label: 'URL',
      placeholder: 'https://example.com',
      validate: (v) => {
        try {
          const url = new URL(v);
          if ((url.protocol === 'http:' || url.protocol === 'https:')
            && url.hostname) return null;
        } catch (_) {}
        return gestureText('Enter a full http(s) URL.');
      },
    });
    case 'camera_view': return configureGestureCameraView(carried);
    case 'intercom_call': return configureGestureIntercomCall(carried);
    case 'launch_app': return configureGestureText(carried, {
      type: 'launch_app', title: gestureText('Open another app'), field: 'package',
      label: gestureText('Package name'), placeholder: 'com.android.deskclock',
      validate: (v) => v.includes('.') ? null : gestureText('Enter a package name.'),
    });
    case 'open_uri': return configureGestureText(carried, {
      type: 'open_uri', title: gestureText('Open a deep link'), field: 'uri', label: 'URI',
      placeholder: 'myapp://path',
      validate: (v) => /^[a-z][a-z0-9+.-]*:/i.test(v) ? null : gestureText('Enter a full URI.'),
    });
    case 'ha_service': return configureGestureHaService(carried);
    case 'ha_script': return configureGestureHaEntity(carried, {
      type: 'ha_script', title: gestureText('Run a script'), label: gestureText('Script entity'),
      hint: 'script.good_morning', domain: 'script', service: 'turn_on',
    });
    case 'ha_automation': return configureGestureHaEntity(carried, {
      type: 'ha_automation', title: gestureText('Trigger an automation'),
      label: gestureText('Automation entity'), hint: 'automation.lights_off',
      domain: 'automation', service: 'trigger',
    });
    case 'ha_event': return configureGestureHaEvent(carried);
  }
  return null;
}

// The main editor: the trigger's fields show and hide with its type, the
// action summarizes below with its own chooser.
export async function editGesture(existing) {
  const triggerValue = existing?.trigger || {};
  let action = existing?.action || null;
  const sequence = Array.isArray(triggerValue.sequence) ? triggerValue.sequence.map(String) : [];

  const body = document.createElement('div');
  // Show fingers needs a hand runtime this Android version cannot load
  // (issue #331): not offered, though an existing mapping still opens.
  const handsOk = !(state.visionSupport && state.visionSupport.hands === false);
  const typeSel = cameraSelectField(gestureText('Gesture'),
    GESTURE_TRIGGERS
      .filter(([value]) => handsOk || value !== 'fingers' || triggerValue.type === 'fingers')
      .map(([value, label]) => ({ value, label: gestureText(label) })),
    triggerValue.type || 'corner_taps');
  const cornerSel = cameraSelectField(gestureText('Corner'),
    Object.entries(GESTURE_CORNERS).map(([value, label]) => ({
      value, label: gestureCorner(value),
    })), GESTURE_CORNERS[triggerValue.corner] ? triggerValue.corner : 'tl');
  const tapsSel = cameraSelectField(gestureText('Taps'),
    [{ value: '2', label: gestureText('2 taps') }, { value: '3', label: gestureText('3 taps') },
      { value: '4', label: gestureText('4 taps') }],
    String(Math.min(Math.max(Number(triggerValue.taps) || 2, 2), 4)));
  const fingersSel = cameraSelectField(gestureText('Fingers'),
    [{ value: '2', label: gestureText('2 fingers') }, { value: '3', label: gestureText('3 fingers') }],
    String(Number(triggerValue.fingers) === 2 ? 2 : 3));
  const fingerTapsSel = cameraSelectField(gestureText('Taps'),
    [{ value: '1', label: gestureText('Single tap') }, { value: '2', label: gestureText('Double tap') }],
    String(Number(triggerValue.taps) === 2 ? 2 : 1));
  const clapsSel = cameraSelectField(gestureText('Claps'),
    [{ value: '2', label: gestureText('2 claps') }, { value: '3', label: gestureText('3 claps') },
      { value: '4', label: gestureText('4 claps') }],
    String(Math.min(Math.max(Number(triggerValue.claps) || 2, 2), 4)));
  const clapsNote = document.createElement('span');
  clapsNote.className = 'desc';
  clapsNote.textContent = gestureText('Claps are heard through the microphone, with or without wake word detection.');
  const fingerCountSel = cameraSelectField(gestureText('Fingers'),
    [{ value: '1', label: gestureText('1 finger') }, { value: '2', label: gestureText('2 fingers') },
      { value: '3', label: gestureText('3 fingers') }, { value: '4', label: gestureText('4 fingers') },
      { value: '5', label: gestureText('Open hand (5)') }],
    String(Math.min(Math.max(Number(triggerValue.fingers) || 5, 1), 5)));
  const palmNote = document.createElement('span');
  palmNote.className = 'desc';
  palmNote.textContent = handsOk
    ? gestureText('Requires the camera enabled and a well lit environment.')
    : gestureText(cameraText(state.visionSupport.hint || 'Not available on this device.'));

  const holdWrap = document.createElement('label');
  holdWrap.className = 'form-field';
  const holdLabel = document.createElement('span');
  holdLabel.className = 'desc';
  const holdInput = document.createElement('input');
  holdInput.type = 'range';
  holdInput.min = '500';
  holdInput.max = '3000';
  holdInput.step = '250';
  holdInput.value = String(Number(triggerValue.holdMs) || 1500);
  const holdText = () => {
    holdLabel.textContent = t('gestureHoldDuration', {seconds: (Number(holdInput.value) / 1000).toFixed(2)});
  };
  holdInput.addEventListener('input', holdText);
  holdText();
  holdWrap.append(holdLabel, holdInput);

  const seqWrap = document.createElement('div');
  seqWrap.className = 'form-field';
  const seqText = document.createElement('span');
  seqText.className = 'desc';
  const seqButtons = document.createElement('div');
  seqButtons.style.cssText = 'display:flex; gap:8px; flex-wrap:wrap;';
  const paintSeq = () => {
    seqText.textContent = sequence.length
      ? sequence.map(gestureCorner).join(' > ')
      : gestureText('Tap the corners in order (2 to 8 steps).');
  };
  for (const corner of Object.keys(GESTURE_CORNERS)) {
    seqButtons.appendChild(cameraAction(gestureCorner(corner), () => {
      if (sequence.length >= 8) return;
      sequence.push(corner);
      paintSeq();
    }));
  }
  seqButtons.appendChild(cameraAction(gestureText('Undo'), () => {
    sequence.pop();
    paintSeq();
  }));
  paintSeq();
  seqWrap.append(seqText, seqButtons);

  const actionRow = document.createElement('div');
  actionRow.className = 'row';
  actionRow.style.borderBottom = 'none';
  const actionInfo = document.createElement('div');
  actionInfo.className = 'info';
  const actionName = document.createElement('div');
  actionName.className = 'name';
  actionName.textContent = action ? describeGestureAction(action) : gestureText('Choose an action');
  const actionDesc = document.createElement('div');
  actionDesc.className = 'desc';
  actionDesc.textContent = gestureText('What this gesture triggers.');
  actionInfo.append(actionName, actionDesc);
  actionRow.append(actionInfo, cameraAction(gestureText('Choose'), async () => {
    const picked = await pickGestureAction(action);
    if (picked) {
      action = picked;
      actionName.textContent = describeGestureAction(action);
    }
  }));

  body.append(typeSel.wrap, cornerSel.wrap, tapsSel.wrap, fingersSel.wrap,
    fingerTapsSel.wrap, clapsSel.wrap, clapsNote, fingerCountSel.wrap,
    holdWrap, palmNote, seqWrap, actionRow);
  const update = () => {
    const type = typeSel.select.value;
    cornerSel.wrap.style.display =
      type === 'corner_taps' || type === 'corner_hold' ? '' : 'none';
    tapsSel.wrap.style.display = type === 'corner_taps' ? '' : 'none';
    fingersSel.wrap.style.display =
      type === 'finger_taps' || type === 'finger_hold' ? '' : 'none';
    fingerTapsSel.wrap.style.display = type === 'finger_taps' ? '' : 'none';
    clapsSel.wrap.style.display = type === 'claps' ? '' : 'none';
    clapsNote.style.display = type === 'claps' ? '' : 'none';
    fingerCountSel.wrap.style.display = type === 'fingers' ? '' : 'none';
    palmNote.style.display = type === 'fingers' ? '' : 'none';
    holdWrap.style.display =
      type === 'corner_hold' || type === 'finger_hold' ? '' : 'none';
    seqWrap.style.display = type === 'corner_sequence' ? '' : 'none';
  };
  typeSel.select.addEventListener('change', update);
  update();

  return cameraEditor({
    title: existing ? gestureText('Edit gesture') : gestureText('Add gesture'),
    body,
    save: async () => {
      const type = typeSel.select.value;
      if (!action) return { ok: false, error: gestureText('Choose an action.') };
      if (type === 'corner_sequence' && sequence.length < 2) {
        return { ok: false, error: gestureText('Add at least two corners.') };
      }
      const trigger = { type };
      if (type === 'corner_taps' || type === 'corner_hold') {
        trigger.corner = cornerSel.select.value;
      }
      if (type === 'corner_taps') trigger.taps = Number(tapsSel.select.value);
      if (type === 'finger_taps' || type === 'finger_hold') {
        trigger.fingers = Number(fingersSel.select.value);
      }
      if (type === 'finger_taps') trigger.taps = Number(fingerTapsSel.select.value);
      if (type === 'corner_hold' || type === 'finger_hold') {
        trigger.holdMs = Number(holdInput.value);
      }
      if (type === 'corner_sequence') trigger.sequence = [...sequence];
      if (type === 'claps') trigger.claps = Number(clapsSel.select.value);
      if (type === 'fingers') trigger.fingers = Number(fingerCountSel.select.value);
      const mappings = readGestureMappings();
      const mapping = {
        id: existing?.id || `g${Date.now()}`, trigger, action,
      };
      const index = mappings.findIndex((m) => m.id === mapping.id);
      if (index >= 0) mappings[index] = mapping;
      else mappings.push(mapping);
      await saveGestureMappings(mappings);
      return { ok: true };
    },
  });
}

export async function loadGestures() {
  const root = document.getElementById('tab-gestures');
  // Boot and live updates own the settings cache and language. A page visit
  // must not replace them with a separate settings response.
  const settings = (state.settings || []).map(setting =>
    Object.assign(setting, localizeSetting(setting)));
  root.innerHTML = '';
  // Rebuilt from scratch on every visit, so the banner a follower's synced
  // category wears goes back on first; the generic tabs keep theirs because
  // nothing redraws them between settings loads.
  applyManagedBanners();
  const value = (key) =>
    settings.find((s) => s.key === key)?.value;
  const refresh = () => loadGestures();

  if (value('kiosk.enabled') === true && value('kiosk.disable_gestures') === true) {
    const off = document.createElement('div');
    off.className = 'card';
    off.appendChild(cameraListRow(gestureText('Gestures are off'),
      gestureText('Disable Gestures is on in Kiosk Mode settings.'), []));
    root.appendChild(off);
  }

  const heading = document.createElement('h2');
  heading.className = 'card-title';
  heading.textContent = gestureText('Gestures');
  root.appendChild(heading);
  const card = document.createElement('div');
  card.className = 'card';
  root.appendChild(card);

  const mappings = readGestureMappings();
  if (!mappings.length) {
    card.appendChild(cameraListRow(gestureText('No gestures configured'),
      gestureText('A gesture triggers its action without any visible control.'),
      [], { icon: 'gesture' }));
  }
  for (const mapping of mappings) {
    card.appendChild(cameraListRow(
      describeGestureTrigger(mapping.trigger),
      describeGestureAction(mapping.action),
      [
        cameraAction(gestureText('Delete'), async () => {
          const choice = await localizedMessageBox({
            titleId:'gestureDeleteTitle', messageId:'gestureDeleteMessage',
            values:() => ({trigger:describeGestureTrigger(mapping.trigger), action:describeGestureAction(mapping.action)}),
            buttons:[{id:'commonCancel', value:'Cancel'}, {id:'commonDelete', value:'Delete'}],
          });
          if (choice !== 'Delete') return;
          await saveGestureMappings(
            readGestureMappings().filter((m) => m.id !== mapping.id));
          refresh();
        }, false, 'delete'),
      ],
      {
        icon: { claps: 'clap', fingers: 'hand' }[mapping.trigger?.type] || 'gesture',
        onClick: async () => {
          if (await editGesture(mapping)) refresh();
        },
      },
    ));
  }
  card.appendChild(cameraListRow(
    gestureText('Add gesture'), gestureText('Pick a gesture and the action it triggers.'), [],
    {
      icon: 'add',
      onClick: async () => {
        if (await editGesture(null)) refresh();
      },
    },
  ));

  const note = document.createElement('div');
  note.className = 'group-note';
  note.textContent = gestureText('Gestures are observed, not blocked: the taps also reach the dashboard, so corners and multi-finger shapes keep them from firing anything there.');
  root.appendChild(note);

  // Mirrors the device's Clapper section (ui/gesture_settings.dart).
  const strictness = settings.find((s) => s.key === 'gestures.clap_strictness');
  if (strictness) {
    const clapperHeading = document.createElement('h2');
    clapperHeading.className = 'card-title';
    // Follows the group note, which ends flush (no bottom margin); the
    // usual card-to-heading rhythm needs restoring by hand here.
    clapperHeading.style.marginTop = '22px';
    clapperHeading.textContent = gestureText('Clapper');
    root.appendChild(clapperHeading);
    const clapperCard = document.createElement('div');
    clapperCard.className = 'card';
    clapperCard.appendChild(settingRow(strictness));
    root.appendChild(clapperCard);
  }
  const hold = settings.find((s) => s.key === 'gestures.hand_hold_seconds');
  if (hold) {
    const heading = document.createElement('h2');
    heading.className = 'card-title';
    heading.textContent = gestureText('Hand Gestures');
    root.appendChild(heading);
    const group = document.createElement('div');
    group.className = 'card';
    group.appendChild(settingRow(hold));
    root.appendChild(group);
  }
}

/* ---- Settings ---- */
// One tab per category, mirroring the device's settings rail. Voice
// Satellite shares the Home Assistant tab, as it shares that pane on the
// device.
export const CATEGORY_TABS = [
  ['tab-browser', ['Browser']],
  ['tab-kiosk', ['Kiosk']],
  ['tab-lockdown', ['Lockdown']],
  ['tab-launcher', ['Launcher']],
  ['tab-home', ['Home']],
  ['tab-screenaudio', ['Screen & Audio']],
  ['tab-screensaver', ['Screensaver']],
  ['tab-camera', ['Camera']],
  ['tab-homeassistant', ['Home Assistant']],
  ['tab-sendspin', ['Sendspin']],
  ['tab-dlna', ['DLNA']],
  ['tab-intercom', ['Intercom']],
  ['tab-esphome', ['ESPHome']],
  ['device-settings', ['Device'],
    // Read-only reports, filled by loadDeviceInfo: no setting declares
    // them, so the tab names them here.
    { extra: ['Hardware', 'Home Assistant', 'WebView'],
      entryRoot: 'device-pages' }],
];

watchUpdates(['gestures'], loadGestures, { visible: () => !!document.querySelector('#tab-gestures.active') });
document.addEventListener('ks-settings-cached', () => {
  if (document.querySelector('#tab-gestures.active')) loadGestures();
});
