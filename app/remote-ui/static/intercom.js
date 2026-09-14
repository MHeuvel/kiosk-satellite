import { api, cmd, state } from './core.js';
import { attachSoundSelect, attachSoundUpload } from './settings.js';
import { gestureListModal } from './gestures.js';
import { currentPath, showTab } from './tabs.js';
import { copyBox, hintRow, modalShell, showToast } from './widgets.js';

/* ---- Intercom ----
   Kiosks on the same network talk to each other. The generic renderer
   draws the definition rows into the tab (enable, key, Answer, Talk).
   This module decorates them from the device's intercomStatus command,
   the same shape the device's own page draws, and redraws on the intercom
   event the device pushes over the socket. Nothing here can talk or take
   a call: a browser opens the microphone only on a secure origin and the
   remote admin is plain http, and a call is answered on the kiosk. The
   one thing it can do to a call is end it. */

let status = null;
let pollTimer = null;
let tickTimer = null;
let busy = false;
// The copy box on the key row, updated in place when the key changes.
let keyBox = null;

const byKey = (key) => (state.settings || []).find((s) => s.key === key);

async function loadStatus() {
  try {
    const r = await cmd('intercomStatus');
    if (r.ok) status = r.data;
  } catch (_) {}
  return status;
}

/* ---- pieces ---- */

const titled = (title) => {
  const h = document.createElement('h2');
  h.className = 'card-title intercom-built';
  h.textContent = title;
  const card = document.createElement('div');
  card.className = 'card intercom-built';
  return [h, card];
};

function tag(text, kind = '') {
  const t = document.createElement('span');
  t.className = 'tag' + (kind ? ' ' + kind : '');
  t.textContent = text;
  return t;
}

// A row with a name and a description, nothing trailing yet.
function infoRow(name, desc) {
  const row = document.createElement('div');
  row.className = 'row';
  const info = document.createElement('div');
  info.className = 'info';
  info.innerHTML = '<div class="name"></div><div class="desc"></div>';
  info.querySelector('.name').textContent = name;
  info.querySelector('.desc').textContent = desc;
  row.appendChild(info);
  return row;
}

// A kiosk row: the name on its own line, the address and its tags on the
// second. The switcher's shape, as on the Fleet Management page.
function kioskRow({ name, address, version, tags = [], dim = false }) {
  const row = document.createElement('div');
  row.className = 'row fleet-row self' + (dim ? ' dim' : '');
  const info = document.createElement('div');
  info.className = 'info';
  const nameEl = document.createElement('div');
  nameEl.className = 'name';
  const nameText = document.createElement('span');
  nameText.textContent = name || address;
  nameEl.appendChild(nameText);
  const desc = document.createElement('div');
  desc.className = 'desc';
  const ip = document.createElement('span');
  ip.textContent = address || '';
  desc.appendChild(ip);
  if (version) desc.appendChild(tag(version, ''));
  for (const t of tags) desc.appendChild(t);
  info.append(nameEl, desc);
  row.appendChild(info);
  return row;
}

function button(label, cls, onClick) {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = cls;
  b.textContent = label;
  b.style.flexShrink = '0';
  b.addEventListener('click', onClick);
  return b;
}

async function run(name, params = {}, { reload = true } = {}) {
  if (busy) return null;
  busy = true;
  let out;
  try { out = await cmd(name, params); }
  catch (_) { out = { ok: false, error: 'The device did not answer.' }; }
  busy = false;
  if (!out.ok) showToast({ title: 'Intercom', message: out.error || '', kind: 'error' });
  if (reload) { await loadStatus(); renderIntercomPage({ fetch: false }); }
  return out;
}

const mmss = (since) => {
  const s = Math.max(0, Math.floor((Date.now() - since) / 1000));
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(Math.floor(s / 60))}:${pad(s % 60)}`;
};

/* ---- the key ---- */

// Paste a key from another kiosk, or make a new one. Either lands on the
// device at once: there is no draft to lose, so the dialog closes on
// success and stays open with the toast on a refusal.
function openKeyDialog() {
  const current = `${byKey('intercom.key')?.value || ''}`;
  const shell = modalShell({ title: 'Intercom key', width: 480, onDismiss: () => shell.close() });
  const input = document.createElement('input');
  input.className = 'field';
  input.value = current;
  input.spellcheck = false;
  input.autocomplete = 'off';
  input.style.cssText = 'width:100%; font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;';
  shell.body.appendChild(input);
  shell.body.appendChild(hintRow('Kiosks with this key can call each other. A new key cuts this kiosk off from the others until they get it too.'));
  const apply = async (params) => {
    const out = await run('intercomSetKey', params, { reload: false });
    if (!out?.ok) return;
    const key = `${out.data?.key || ''}`;
    const def = byKey('intercom.key');
    if (def) def.value = key;
    if (keyBox) keyBox.set(key);
    showToast({ title: 'Key changed', kind: 'success' });
    shell.close();
    await loadStatus();
    renderIntercomPage({ fetch: false });
  };
  const save = () => {
    const key = input.value.trim();
    if (!key) { input.focus(); return; }
    apply({ key });
  };
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter') save(); });
  const regen = button('Regenerate', 'btn-ghost', () => apply({ regenerate: true }));
  regen.style.marginRight = 'auto';
  shell.foot.append(
    regen,
    button('Cancel', 'btn-text', () => shell.close()),
    button('Save', 'btn-primary', save),
  );
  input.focus();
  input.select();
}

/* ---- the definition rows ---- */

// The rows the generic renderer drew, made to match the device page: the
// key as a copy box with a Change row under it, the ring sound as a
// dropdown over the sounds folder, the talk mode locked to push to talk
// where the platform has no echo canceller. Each is done once per render
// of the rows and left alone on a status redraw.
function decorateRows(tab) {
  const keyRow = tab.querySelector('[data-key="intercom.key"]');
  const keyInput = keyRow?.querySelector('input');
  if (keyInput && !keyRow.querySelector('.copy-box')) {
    keyBox = copyBox(keyInput.value, { placeholder: keyInput.placeholder || 'Not set' });
    keyInput.replaceWith(keyBox.el);
    // Lives with the definition rows: wiped and redrawn with them on a
    // settings load, left alone on a status redraw.
    const change = infoRow('Change key', 'Paste the key from another kiosk, or make a new one.');
    change.appendChild(button('Change', 'btn-ghost', openKeyDialog));
    keyRow.insertAdjacentElement('afterend', change);
  }

  const soundRow = tab.querySelector('[data-key="intercom.ring_sound"]');
  const soundDef = byKey('intercom.ring_sound');
  if (soundRow && soundDef && !soundRow.querySelector('select')) {
    attachSoundUpload(soundRow, attachSoundSelect(soundRow, soundDef));
  }

  const talkRow = tab.querySelector('[data-key="intercom.talk_mode"]');
  const talkSel = talkRow?.querySelector('select');
  if (talkSel) {
    const desc = talkRow.querySelector('.desc');
    talkRow.dataset.desc ??= desc.textContent;
    const forced = status?.aec === false;
    talkSel.disabled = forced;
    desc.textContent = forced
      ? 'Push to talk only: this device has no echo canceller.'
      : talkRow.dataset.desc;
  }
}

/* ---- the live call ---- */

const LIVE = new Set(['calling', 'ringing', 'in_call', 'broadcasting', 'listening']);

function liveCard() {
  const call = status.call || {};
  const peer = call.peer || {};
  const name = peer.name || peer.address || 'a kiosk';
  const targets = call.targets || [];
  const heard = targets.filter((t) => t.status === 'listening').length || targets.length;
  const title = {
    calling: `Calling ${name}`,
    ringing: `${name} is calling`,
    in_call: `In a call with ${name}`,
    broadcasting: `Announcing to ${heard} kiosk${heard === 1 ? '' : 's'}`,
    listening: call.automated && call.message ? `Home Assistant: ${call.message}` : `${name} is announcing`,
  }[status.state];
  const card = document.createElement('div');
  card.className = 'card intercom-built';
  const tags = [];
  let clock = null;
  if (call.since) {
    clock = tag(mmss(call.since), 'device');
    tags.push(clock);
  }
  const row = kioskRow({ name: title, address: peer.address, tags });
  row.appendChild(button('End call', 'btn-ghost', () => run('intercomHangup')));
  card.appendChild(row);
  if (clock) {
    tickTimer = setInterval(() => {
      if (!clock.isConnected) { clearInterval(tickTimer); tickTimer = null; return; }
      clock.textContent = mmss(call.since);
    }, 1000);
  }
  return card;
}

/* ---- the page ---- */

// The built cards go after the fleet banner when a leader pushes this
// category, so the banner keeps the top of the tab.
function putTop(tab, nodes) {
  const banners = tab.querySelectorAll(':scope > .fleet-banner');
  const after = banners.length ? banners[banners.length - 1] : null;
  if (after) after.after(...nodes); else tab.prepend(...nodes);
}

export async function renderIntercomPage({ fetch = true } = {}) {
  const tab = document.getElementById('tab-intercom');
  if (!tab) return;
  if (fetch || !status) await loadStatus();
  // The hand-built parts go and come back: the definition rows stay.
  if (tickTimer) { clearInterval(tickTimer); tickTimer = null; }
  tab.querySelectorAll('.intercom-built').forEach((n) => n.remove());
  if (!status) {
    const h = hintRow('The device did not answer.');
    h.classList.add('intercom-built');
    tab.appendChild(h);
    return;
  }
  decorateRows(tab);

  const top = [];
  if (status.available === false) {
    const card = document.createElement('div');
    card.className = 'card intercom-built';
    const row = infoRow('The intercom needs the remote admin',
      'Kiosks find and reach each other through it. Turn on Remote management and Find other kiosks under Device, then come back.');
    row.appendChild(button('Open', 'btn-ghost', () => showTab('device')));
    card.appendChild(row);
    top.push(card);
  }
  if (LIVE.has(status.state)) top.push(liveCard());
  if (top.length) putTop(tab, top);

  // The roster is worth nothing with the intercom off.
  if (status.available !== false && status.enabled) {
    const [h, card] = titled('Kiosks');
    const kiosks = status.kiosks || [];
    if (!kiosks.length) {
      card.appendChild(infoRow('No kiosks heard', 'A kiosk shows up once its remote admin is on and it shares this network.'));
    }
    for (const k of kiosks) {
      const row = kioskRow({ name: k.name, address: k.address, version: k.version, dim: k.status === 'offline' });
      const st = document.createElement('span');
      st.className = 'fleet-status' + (k.status === 'ready' ? ' ok' : k.status === 'key' ? ' warn' : '');
      st.textContent = k.statusText || '';
      row.appendChild(st);
      card.appendChild(row);
    }
    card.appendChild(hintRow('Kiosks discovered on this network. A kiosk is ready once its intercom is on with the same key.'));
    tab.append(h, card);
  }
}

/* ---- lifecycle ---- */

export function intercomShown() {
  renderIntercomPage();
  if (pollTimer) clearInterval(pollTimer);
  // While the tab stays open: the device probes the other kiosks at the
  // fast cadence for as long as something asks and the rows follow.
  pollTimer = setInterval(() => {
    if (currentPath.split('/')[0] !== 'intercom') { clearInterval(pollTimer); pollTimer = null; return; }
    if (document.hidden || document.querySelector('.modal-back')) return;
    renderIntercomPage();
  }, 30000);
}

document.addEventListener('ks-event', (e) => {
  if (e.detail?.event !== 'intercom') return;
  // The event carries the status itself: no second read.
  if (e.detail.data && typeof e.detail.data === 'object') status = e.detail.data;
  // Not under an open modal: a redraw would pull the rows from under it.
  if (document.querySelector('.modal-back')) return;
  renderIntercomPage({ fetch: false });
});

/* ---- the Announcements page under ESPHome ----
   Its text to speech engine: a box with the picked entity's name that
   opens the list of every tts entity Home Assistant has, First available
   on top. Mirrors the device row. The chime sound select rides the same
   helper as the notification sound. */
export function decorateAnnouncementsPage() {
  const ttsRow = document.querySelector('[data-key="announcements.tts_engine"]');
  const ttsDef = byKey('announcements.tts_engine');
  if (ttsRow && ttsDef && !ttsRow.querySelector('.tts-pick')) {
    ttsRow.querySelector('input')?.remove();
    const box = document.createElement('button');
    box.type = 'button';
    box.className = 'btn-ghost tts-pick';
    const label = () => `${ttsDef.value || ''}`.trim() || 'First available';
    box.textContent = label();
    // The friendly name once Home Assistant answers; the id until then.
    if (`${ttsDef.value || ''}`.trim()) {
      cmd('announcementTtsEngines').then((r) => {
        const hit = r.ok && (r.data || []).find((e) => e.entity_id === `${ttsDef.value || ''}`.trim());
        if (hit) box.textContent = hit.name;
      }).catch(() => {});
    }
    box.addEventListener('click', async () => {
      let engines = [];
      try {
        const r = await cmd('announcementTtsEngines');
        if (r.ok) engines = r.data || [];
        else throw new Error(r.error || 'unreachable');
      } catch (_) {
        showToast({ title: 'Could not reach Home Assistant', kind: 'error' });
        return;
      }
      const current = `${ttsDef.value || ''}`.trim();
      const picked = await gestureListModal('Text to speech engine', [
        { name: 'First available', desc: '', value: '', selected: !current },
        ...engines.map((e) => ({ name: e.name, desc: e.entity_id, value: e.entity_id, selected: e.entity_id === current })),
      ]);
      if (picked === null) return;
      const res = await api('/api/settings', {
        method: 'PATCH',
        body: JSON.stringify({ 'announcements.tts_engine': picked }),
      });
      if (!res.ok) { showToast({ title: 'Not saved', kind: 'error' }); return; }
      ttsDef.value = picked;
      box.textContent = engines.find((e) => e.entity_id === picked)?.name || label();
    });
    ttsRow.appendChild(box);
  }

  const chimeRow = document.querySelector('[data-key="announcements.chime_file"]');
  const chimeDef = byKey('announcements.chime_file');
  if (chimeRow && chimeDef && !chimeRow.querySelector('select')) {
    attachSoundUpload(chimeRow, attachSoundSelect(chimeRow, chimeDef));
  }
}
