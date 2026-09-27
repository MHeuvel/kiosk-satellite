import { t, voiceText, voiceVadOption } from './localization.js';
import { voiceTextMessageIds } from './voice_text_ids.js';
import { api, cmd } from './core.js';
import { readOnlyRow } from './device.js';
import { messageBox, modalShell, showToast } from './widgets.js';
import { vsSelectRow } from './vs.js';
import { watchUpdates } from './live.js';

/* ---- Native Voice Satellite (runs in the kiosk, not the dashboard) ---- */
// Mirrors the device's native page: the switch with the status and Home
// Assistant rows under it, the page entries in the device's order, Home
// Assistant's own selects on Assistant and Wake Word, the preview on
// Appearance and the way back while the integration is still installed.
// The migration notice and wizard live here too, for the dashboard runtime.

const ICONS = {
  warn: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>',
  ok: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m8 12 3 3 5-6"/></svg>',
  error: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><path d="M12 7v6M12 16.5v.5"/></svg>',
  pending: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/></svg>',
};

const PIPELINE_ROWS = [
  ['pipeline', 'Assistant 1', 'Answers wake word 1.'],
  ['pipeline_2', 'Assistant 2', 'Answers wake word 2.'],
  ['vad_sensitivity', 'Finished speaking detection', 'How long a pause ends a voice command.'],
];
const WAKE_ROWS = [
  ['wake_word', 'Wake word 1', 'The word that starts a voice command.'],
  ['wake_word_2', 'Wake word 2', 'A second wake word, answered by Assistant 2.'],
];
const PAGES = ['Assistant', 'Wake Word', 'Appearance', 'Conversation', 'Timers', 'Chimes'];

// voiceText for copy with placeholders.
function voiceFormat(english, values) {
  return t(voiceTextMessageIds[english], values, english);
}

function voiceRow(name, desc, value = '') {
  return readOnlyRow(voiceText(name), voiceText(desc), value, false);
}

function statusWord(row, text, color) {
  const span = row.lastElementChild;
  span.textContent = text;
  span.style.cssText = `white-space:nowrap; font-weight:500; color:${color}`;
}

/* The status and Home Assistant rows under the switch, read from the
   kiosk's voiceStatus and repainted on every settings render. */
async function paintStatus(card, byKey) {
  // A later paint supersedes this one, whichever read comes back first.
  const gen = (card._vsStatusGen || 0) + 1;
  card._vsStatusGen = gen;
  const enabledRow = card.querySelector('[data-key="voice.enabled"]');
  if (!enabledRow || byKey['voice.enabled']?.value !== true) {
    card.querySelectorAll('.vs-native-status').forEach((r) => r.remove());
    return;
  }
  let status = {};
  try {
    const r = await cmd('voiceStatus', {});
    if (r.ok) status = r.data || {};
  } catch (_) {}
  if (!enabledRow.isConnected || card._vsStatusGen !== gen) return;
  card.querySelectorAll('.vs-native-status').forEach((r) => r.remove());
  const esphome = byKey['esphome.enabled']?.value === true;
  const muted = byKey['voice.mute']?.value === true;
  const entity = `${status.satelliteEntity || ''}`;
  const added = esphome && status.subscribed === true;
  const statusRow = voiceRow('Status',
    !esphome ? 'The ESPHome server is off.'
      : !added ? 'This kiosk is not added to Home Assistant yet.'
        : muted ? 'The microphone is muted.'
          : 'Listening for the wake word.');
  statusWord(statusRow,
    !added ? voiceText('Not added') : muted ? voiceText('Muted')
      : status.listening ? voiceText('Listening') : voiceText('Busy'),
    !added ? 'var(--warn)' : muted ? 'var(--muted)' : 'var(--primary)');
  const haRow = voiceRow('Home Assistant', entity ? '' : esphome
    ? 'Add this kiosk under Settings, Devices & services in Home Assistant, where it shows up as discovered.'
    : 'Turn on the ESPHome server so Home Assistant can add this kiosk as a satellite.');
  if (entity) haRow.querySelector('.desc').textContent = entity;
  if (esphome) {
    statusWord(haRow, entity ? voiceText('Added') : voiceText('Not added'),
      entity ? 'var(--primary)' : 'var(--warn)');
  } else {
    haRow.lastElementChild.remove();
    const btn = document.createElement('button');
    btn.className = 'btn-primary';
    btn.textContent = voiceText('Turn on');
    btn.addEventListener('click', async () => {
      btn.disabled = true;
      await api('/api/settings', { method: 'PATCH', body: JSON.stringify({ 'esphome.enabled': true }) }).catch(() => null);
      btn.disabled = false;
    });
    haRow.appendChild(btn);
  }
  for (const row of [statusRow, haRow]) row.classList.add('vs-native-status');
  enabledRow.after(statusRow, haRow);
}

/* Play sounds on: this kiosk or a Home Assistant media player from the
   live list, in the place of the text field the definition draws, as the
   device's picker. Keeps the row's own (localized) title and its key. */
async function ttsOutputRow(row, current) {
  const title = row.querySelector('.name')?.textContent || 'Play sounds on';
  const desc = row.querySelector('.desc')?.textContent || '';
  let players = [];
  try {
    const r = await cmd('mediaPlayers', { source: 'ha' });
    const list = r.ok ? r.data?.players : null;
    players = (Array.isArray(list) ? list : []).filter((p) => p.group === 'ha');
  } catch (_) {}
  if (!row.isConnected) return;
  const options = [{ value: '', label: voiceText('This kiosk') },
    // The list's ids carry their source; the setting keeps the entity.
    ...players.map((p) => ({ value: `${p.id}`.replace(/^ha:/, ''), label: `${p.name}` }))];
  // A player Home Assistant no longer lists still shows as picked.
  if (current && !options.some((o) => o.value === current)) {
    options.push({ value: current, label: current });
  }
  const picker = vsSelectRow(title, desc, options, current, (value) => {
    api('/api/settings', { method: 'PATCH', body: JSON.stringify({ 'voice.tts_output': value }) })
      .catch(() => null);
  });
  picker.dataset.key = 'voice.tts_output';
  row.replaceWith(picker);
}

/* Home Assistant's selects on the kiosk's device, as dropdowns that write
   them live. `rows` is [key, title, description] per row. */
async function haSelectRows(container, rows) {
  let data = {};
  try {
    const r = await cmd('voiceHaSelects', {}, { timeoutMs: 15000 });
    if (r.ok) data = r.data || {};
  } catch (_) {}
  if (!container.isConnected) return;
  container.innerHTML = '';
  const label = (key, option) => option === 'preferred' ? voiceText('Preferred')
    : option === 'no_wake_word' ? voiceText('None')
      : key === 'vad_sensitivity' ? voiceVadOption(option) : option;
  for (const [key, title, desc] of rows) {
    const entity = data[key];
    const options = Array.isArray(entity?.options) ? entity.options.map(String) : [];
    if (!entity || entity.available !== true || !options.length) {
      container.appendChild(voiceRow(title, desc, voiceText('Not available')));
      continue;
    }
    container.appendChild(vsSelectRow(voiceText(title), voiceText(desc),
      options.map((o) => ({ value: o, label: label(key, o) })), `${entity.state ?? ''}`,
      async (option) => {
        const r = await cmd('voiceSelectOption', { key, option }).catch(() => null);
        if (!r?.ok) showToast({ title: 'Voice Satellite', message: voiceText('Could not change it in Home Assistant.'), kind: 'error' });
        setTimeout(() => haSelectRows(container, rows), 800);
      }));
  }
}

function selectsBlock(rows) {
  const block = document.createElement('div');
  block.className = 'vs-ha-selects';
  haSelectRows(block, rows);
  return block;
}

/* The native page, into a root render() already filled with the Voice
   Satellite settings: the generic rows stay, this adds and reorders. */
export async function renderNativeVs(root, byKey) {
  const enabled = byKey['voice.enabled']?.value === true;
  // The switch card: Enable, then the status rows, then Mute and background
  // listening, the device's order.
  const enabledRow = root.querySelector(':scope > .card [data-key="voice.enabled"]');
  const card = enabledRow?.closest('.card');
  if (card) {
    for (const key of ['voice.mute', 'wake_word.background', 'wake_word.return_to_background']) {
      // render() can leave them in a card of their own: a page entry
      // between them and the switch closes the card they started in.
      const row = root.querySelector(`:scope > .card [data-key="${key}"]`);
      if (!row) continue;
      const from = row.closest('.card');
      if (!enabled) row.remove();
      else card.appendChild(row);
      if (from !== card && !from.children.length) from.remove();
    }
    card.prepend(enabledRow);
    card.id = 'vsNativeCard';
    // The status follows the kiosk: Home Assistant taking the satellite a
    // few seconds after the switch turns on changes no setting, so it
    // arrives as a voice-status update rather than a settings render.
    card._vsByKey = byKey;
    if (card._vsStatusWatch) paintStatus(card, byKey);
    else {
      card._vsStatusWatch = watchUpdates(['voice-status'],
        () => paintStatus(card, card._vsByKey), { owner: card });
    }
  }
  const entryCard = (sub) => root.querySelector(`[data-subpage-entry="${sub}"]`)?.closest('.card');
  if (!enabled) {
    // Off: only the switch, as on the device.
    root.querySelectorAll('[data-subpage-entry]').forEach((row) => row.closest('.card')?.remove());
  } else {
    for (const sub of [...PAGES, 'Wake word diagnostics']) {
      const entry = entryCard(sub);
      if (entry) root.appendChild(entry);
    }
    // Debug after the pages, as on the device.
    const debugCard = root.querySelector(':scope > .card [data-key="voice.debug_logging"]')?.closest('.card');
    if (debugCard) {
      const heading = debugCard.previousElementSibling;
      if (heading?.classList.contains('card-title')) root.appendChild(heading);
      root.appendChild(debugCard);
    }
    const tab = root.closest('.tab') || root;
    const panel = (sub) => tab.querySelector(`.subpage[data-subpage="${sub}"]`);
    const assistant = panel('Assistant');
    if (assistant) {
      const h = document.createElement('h2');
      h.className = 'card-title';
      h.textContent = voiceText('Pipelines');
      const selects = document.createElement('div');
      selects.className = 'card';
      selects.appendChild(selectsBlock(PIPELINE_ROWS));
      assistant.prepend(h, selects);
    }
    const ttsRow = assistant?.querySelector('[data-key="voice.tts_output"]');
    if (ttsRow) ttsOutputRow(ttsRow, byKey['voice.tts_output']?.value || '');
    const wake = panel('Wake Word');
    if (wake) {
      // Engine, Home Assistant's wake words, then sensitivity, the noise
      // gate and the stop word in one card, the engine's own tuning after.
      const first = document.createElement('div');
      first.className = 'card';
      for (const key of ['voice.wake_word_engine', 'voice.wake_word_sensitivity', 'voice.noise_gate', 'voice.stop_word']) {
        const row = wake.querySelector(`[data-key="${key}"]`);
        if (row) first.appendChild(row);
        if (key === 'voice.wake_word_engine') first.appendChild(selectsBlock(WAKE_ROWS));
      }
      wake.querySelectorAll(':scope > .card').forEach((c) => { if (!c.children.length) c.remove(); });
      wake.prepend(first);
    }
    const reactive = panel('Appearance')?.querySelector('[data-key="voice.reactive_bar"]');
    if (reactive) {
      const row = voiceRow('Preview', 'Show the overlay on the kiosk screen for five seconds.');
      row.lastElementChild.remove();
      const btn = document.createElement('button');
      btn.className = 'btn-ghost';
      btn.textContent = voiceText('Preview');
      btn.addEventListener('click', () => cmd('voicePreview', {}).catch(() => null));
      row.appendChild(btn);
      reactive.after(row);
    }
  }
  // The way back, while the integration is still installed.
  let installed = false;
  try {
    const r = await cmd('haDetectVoiceSatellite', {});
    installed = r.ok && r.data === true;
  } catch (_) {}
  if (!installed || !root.isConnected || root.querySelector('#vsRollbackCard')) return;
  const back = document.createElement('div');
  back.className = 'card';
  back.id = 'vsRollbackCard';
  const row = voiceRow('Run from the dashboard again',
    'Go back to the Voice Satellite integration. Nothing set here is lost.');
  row.lastElementChild.remove();
  const btn = document.createElement('button');
  btn.className = 'btn-ghost';
  btn.textContent = voiceText('Switch back');
  btn.addEventListener('click', async () => {
    const pick = await messageBox({
      title: voiceText('Run from the dashboard again?'),
      message: voiceText('The dashboard runs Voice Satellite again through the integration, with the settings it had before. What you set here stays for next time.'),
      buttons: ['Cancel', 'Switch back'],
      buttonText: voiceText,
    });
    if (pick !== 'Switch back') return;
    btn.disabled = true;
    const r = await cmd('vsRollback', {}, { timeoutMs: 60000 }).catch(() => null);
    btn.disabled = false;
    if (!r?.ok) showToast({ title: 'Voice Satellite', message: r?.error || voiceText('Could not switch'), kind: 'error' });
  });
  row.appendChild(btn);
  back.appendChild(row);
  const perms = root.querySelector('#permsCard');
  if (perms) perms.before(back); else root.appendChild(back);
}

/* The notice at the top of the page while the dashboard still runs the
   integration's engine. */
export function vsMigrationNotice() {
  const banner = document.createElement('div');
  banner.className = 'banner warn vs-migrate-notice';
  banner.style.alignItems = 'center';
  banner.innerHTML = ICONS.warn;
  const text = document.createElement('div');
  text.style.flex = '1';
  text.textContent = voiceText('Voice Satellite is currently installed as an integration in Home Assistant. Migrate to a native experience inside Kiosk Satellite.');
  const btn = document.createElement('button');
  btn.className = 'btn-primary';
  btn.style.cssText = 'background:var(--on-tertiary-container); color:var(--tertiary-container)';
  btn.textContent = voiceText('Migrate');
  btn.addEventListener('click', () => openVsMigrationWizard());
  banner.append(text, btn);
  return banner;
}

/* ---- the migration wizard, the device's four steps ---- */

const GROUP_TITLES = {
  voice: 'Voice', appearance: 'Appearance', conversation: 'Conversation',
  assistant: 'Assistant', timers: 'Timers',
};
const STEP_TITLES = {
  save: 'Save the settings',
  stop: 'Stop the dashboard engine',
  start: 'Start listening here',
  entities: 'Set the kiosk\'s entities in Home Assistant',
  check: 'Check the satellite in Home Assistant',
};
const CHECKS = {
  homeAssistant: ['Home Assistant', 'Connected.', () => 'Not connected. Check Home Assistant Setup.'],
  esphome: ['This kiosk in Home Assistant', 'Added through ESPHome.', (c) => c.esphomeOn
    ? 'Not added yet. Home Assistant lists this kiosk as discovered under Settings, Devices & services. Add it there, then come back.'
    : 'The ESPHome server is off. Turn it on, then add this kiosk in Home Assistant.'],
  admin: ['Administrator token', 'Tool use and results will show.',
    () => 'The token is a regular user\'s. Voice Satellite works, tool use and results will not show.'],
  microphone: ['Microphone', 'Allowed.', () => 'Not allowed. Grant it under Required system permissions.'],
};

function spinner() {
  const s = document.createElement('div');
  s.className = 'fleet-spinner';
  s.style.cssText = 'width:28px; height:28px; margin:24px auto';
  return s;
}

function para(text, style = '') {
  const p = document.createElement('p');
  p.style.cssText = `margin:0 0 10px; line-height:1.5; ${style}`;
  p.textContent = text;
  return p;
}

function iconLine(icon, color, title, desc, extra = null) {
  const line = document.createElement('div');
  line.style.cssText = 'display:flex; gap:14px; align-items:flex-start; padding:8px 0';
  const i = document.createElement('span');
  i.style.cssText = `width:22px; height:22px; flex:none; color:${color}`;
  i.innerHTML = ICONS[icon];
  i.firstElementChild.style.cssText = 'width:22px; height:22px';
  const info = document.createElement('div');
  info.style.cssText = 'flex:1; min-width:0';
  const n = document.createElement('div');
  n.style.cssText = 'font-weight:500';
  n.textContent = title;
  info.appendChild(n);
  if (desc) {
    const d = document.createElement('div');
    d.style.cssText = `font-size:13px; margin-top:2px; color:${icon === 'ok' ? 'var(--muted)' : color}`;
    d.textContent = desc;
    info.appendChild(d);
  }
  line.append(i, info);
  if (extra) line.appendChild(extra);
  return line;
}

export function openVsMigrationWizard() {
  const shell = modalShell({ title: '', width: 560 });
  const w = {
    step: 0, check: null, plan: null, automations: null,
    groups: new Set(Object.keys(GROUP_TITLES)), result: null, steps: [],
  };
  const button = (label, kind, onClick, disabled = false) => {
    const b = document.createElement('button');
    b.className = kind;
    b.textContent = voiceText(label);
    b.disabled = disabled;
    b.addEventListener('click', onClick);
    shell.foot.appendChild(b);
    return b;
  };
  const stepper = (n) => {
    const bar = document.createElement('div');
    bar.style.cssText = 'display:flex; gap:8px; align-items:center; margin-bottom:14px';
    for (let i = 0; i < 4; i++) {
      const seg = document.createElement('div');
      seg.style.cssText = `flex:1; height:4px; border-radius:2px; background:${i < n ? 'var(--primary)' : 'var(--surface-2)'}`;
      bar.appendChild(seg);
    }
    const label = document.createElement('span');
    label.style.cssText = 'font-size:12.5px; color:var(--muted); white-space:nowrap';
    label.textContent = voiceFormat('Step {n} of 4', { n: String(n) });
    bar.appendChild(label);
    return bar;
  };
  const load = async (command, key, fallback) => {
    const r = await cmd(command, {}, { timeoutMs: 30000 }).catch(() => null);
    w[key] = r?.ok && r.data ? r.data : fallback;
    paint();
  };
  const runCheck = () => { w.check = null; paint(); load('voiceMigrationCheck', 'check', { checks: [], ready: false }); };

  const paint = () => {
    const { head, body, foot } = shell;
    body.innerHTML = '';
    foot.innerHTML = '';
    if (w.step === 0) {
      head.textContent = voiceText('Migrate Voice Satellite');
      body.append(stepper(1), para(voiceText('This kiosk becomes the voice satellite itself. The Voice Satellite integration is not needed after this.')));
      if (!w.check) body.appendChild(spinner());
      for (const c of w.check?.checks || []) {
        const [title, good, bad] = CHECKS[c.id] || [c.id, '', () => ''];
        const color = c.ok ? 'var(--primary)' : c.warnOnly ? 'var(--warn)' : 'var(--error)';
        let extra = null;
        if (c.id === 'esphome' && !c.esphomeOn) {
          extra = document.createElement('button');
          extra.className = 'btn-text';
          extra.textContent = voiceText('Turn on ESPHome');
          extra.addEventListener('click', async () => {
            extra.disabled = true;
            await api('/api/settings', { method: 'PATCH', body: JSON.stringify({ 'esphome.enabled': true }) }).catch(() => null);
            runCheck();
          });
        }
        body.appendChild(iconLine(c.ok ? 'ok' : c.warnOnly ? 'warn' : 'error', color,
          voiceText(title), voiceText(c.ok ? good : bad(c)), extra));
      }
      button('Cancel', 'btn-text', () => shell.close());
      if (w.check && w.check.ready !== true) button('Check again', 'btn-text', runCheck);
      button('Next', 'btn-primary', () => {
        w.step = 1;
        paint();
        load('voiceMigrationPlan', 'plan', { groups: [] });
      }, w.check?.ready !== true);
    } else if (w.step === 1) {
      head.textContent = voiceText('Settings to bring over');
      body.appendChild(stepper(2));
      if (!w.plan) body.appendChild(spinner());
      else {
        for (const g of w.plan.groups || []) {
          const label = document.createElement('label');
          label.style.cssText = 'display:flex; gap:12px; align-items:flex-start; padding:8px 0; cursor:pointer';
          const box = document.createElement('input');
          box.type = 'checkbox';
          box.checked = w.groups.has(g.id);
          box.style.marginTop = '3px';
          box.addEventListener('change', () => {
            if (box.checked) w.groups.add(g.id); else w.groups.delete(g.id);
          });
          const info = document.createElement('div');
          const n = document.createElement('div');
          n.style.fontWeight = '500';
          n.textContent = voiceText(GROUP_TITLES[g.id] || g.id);
          info.appendChild(n);
          if (g.values) {
            const d = document.createElement('div');
            d.style.cssText = 'font-size:13px; color:var(--muted); margin-top:2px';
            d.textContent = g.values;
            info.appendChild(d);
          }
          label.append(box, info);
          body.appendChild(label);
        }
        const note = para(voiceText('Not carried over: custom CSS, the browser microphone processing and the conversation memory length. Custom microWakeWord models work from config/custom_wake_words in Home Assistant.'),
          'margin-top:8px; padding:14px; border-radius:16px; background:var(--surface-2); font-size:13px');
        body.appendChild(note);
      }
      button('Back', 'btn-text', () => { w.step = 0; paint(); });
      button('Next', 'btn-primary', () => {
        w.step = 2;
        paint();
        load('voiceMigrationAutomations', 'automations', { items: [] });
      }, !w.plan);
    } else if (w.step === 2) {
      head.textContent = voiceText('Automations and scripts');
      body.appendChild(stepper(3));
      const items = w.automations?.items;
      if (!items) body.appendChild(spinner());
      else if (!items.length) {
        body.appendChild(iconLine('ok', 'var(--primary)', voiceText('Nothing in Home Assistant points at the old satellite.'), ''));
      } else {
        body.appendChild(para(voiceFormat('These still point at {satellite}. Edit them in Home Assistant to use this kiosk\'s satellite. The wizard does not change them.',
          { satellite: w.check?.satellite || '' })));
        for (const item of items) {
          const line = document.createElement('div');
          line.style.cssText = 'padding:8px 0; border-top:1px solid var(--divider)';
          const n = document.createElement('div');
          n.style.fontWeight = '500';
          n.textContent = item.name || '';
          const d = document.createElement('div');
          d.style.cssText = 'font-size:13px; color:var(--muted); margin-top:2px; overflow-wrap:anywhere';
          d.textContent = `${voiceText(item.kind || '')} · ${(item.refs || []).join(', ')}`;
          line.append(n, d);
          body.appendChild(line);
        }
      }
      button('Back', 'btn-text', () => { w.step = 1; paint(); });
      button('Next', 'btn-primary', () => { w.step = 3; paint(); }, !items);
    } else if (w.step === 3) {
      head.textContent = voiceText('Ready to switch');
      body.appendChild(stepper(4));
      for (const line of [
        'This kiosk listens, answers and draws the overlay.',
        'The dashboard stops running Voice Satellite on this kiosk.',
        'The old satellite stays in Home Assistant, unused.',
      ]) body.appendChild(para(`•  ${voiceText(line)}`, 'margin-bottom:6px'));
      button('Back', 'btn-text', () => { w.step = 2; paint(); });
      button('Switch now', 'btn-primary', () => switchNow());
    } else if (!w.result) {
      head.textContent = voiceText('Switching…');
      for (const s of w.steps) {
        const icon = s.state === 'done' ? 'ok' : s.state === 'failed' ? 'error' : 'pending';
        const color = s.state === 'done' ? 'var(--primary)' : s.state === 'failed' ? 'var(--error)'
          : s.state === 'run' ? 'var(--primary)' : 'var(--outline)';
        body.appendChild(iconLine(icon, color, voiceText(STEP_TITLES[s.id] || s.id), ''));
      }
      if (!w.steps.length) body.appendChild(spinner());
    } else {
      const ok = w.result.ok === true;
      head.textContent = ok ? voiceText('Voice Satellite runs here now') : voiceText('Could not switch');
      body.appendChild(para(ok
        ? voiceText('Say the wake word to try it. Once no other device uses the Voice Satellite integration, uninstall it from HACS.')
        : `${w.result.error || ''} ${voiceText('Voice Satellite runs from the dashboard again.')}`.trim()));
      if (!ok) button('Close', 'btn-text', () => shell.close());
      button(ok ? 'Done' : 'Try again', 'btn-primary', () => {
        if (ok) { shell.close(); return; }
        w.result = null;
        w.step = 3;
        paint();
      });
    }
  };

  const switchNow = async () => {
    w.step = 4;
    w.steps = [];
    paint();
    // The switch runs for a while on the kiosk: follow its steps.
    const poll = setInterval(async () => {
      const r = await cmd('voiceMigrationProgress', {}).catch(() => null);
      if (r?.ok && Array.isArray(r.data?.steps) && !w.result) {
        w.steps = r.data.steps;
        paint();
      }
    }, 700);
    const r = await cmd('vsMigrate', { groups: [...w.groups] }, { timeoutMs: 180000 }).catch((e) => ({ ok: false, error: `${e?.message || ''}` }));
    clearInterval(poll);
    w.result = { ok: r?.ok === true, error: r?.error };
    paint();
  };

  runCheck();
}

