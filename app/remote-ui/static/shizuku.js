import { deviceText, deviceOperationError, t } from './localization.js';
import { watchUpdates } from './live.js';
import { settingRow } from './rows.js';
import { cmd, state as appState } from './core.js';
import { permissionSpecs } from './permissions.js';
import { currentPath } from './tabs.js';
import { hintRow, messageBox, showToast } from './widgets.js';

const permissions = permissionSpecs(() => false);
const actions = [
  ['grantAll', 'Grant all permissions', 'Grant all permissions used by KS, including features that are currently off.'],
  ...permissions.map(spec => [spec.key, spec.name, spec.held]),
];
const permissionNames = Object.fromEntries(permissions.map(spec => [spec.key, spec.name]));
let page, busy = false, loading = false, state = {};
function node(tag, className, text) {
  const el = document.createElement(tag);
  if (className) el.className = className;
  if (text !== undefined) el.textContent = deviceText(text);
  return el;
}
function row(title, hint, action, buttonLabel = 'Grant') {
  const el = node('div', 'row shizuku-action');
  el.dataset.searchId = `x:shizuku:${action}`;
  const info = node('div', 'info'); info.append(node('div', 'name', title), node('div', 'desc', hint)); el.append(info);
  const button = node('button', action === 'grantAll' ? 'btn-primary' : 'btn-ghost', buttonLabel); button.type = 'button'; button.dataset.shizukuAction = action;
  button.onclick = () => run(action, button); el.append(button); return el;
}
function paint() {
  if (!page?.isConnected) return;
  const ready = state.granted === true;
  const status = state.status || 'unavailable';
  const hint = { checking: deviceText('Checking availability'), ready: state.uid === 0 ? deviceText('Connected with root access') : deviceText('Connected with shell access'), permission_required: deviceText('Grant access and approve the request on this kiosk.'), denied: deviceText('Allow Kiosk Satellite in the Shizuku app.'), unsupported: deviceText('Shizuku 13 or later is required.'), unavailable: deviceText('Start Shizuku on this device.') }[status];
  page.querySelector('[data-connection] .desc').textContent = deviceText(hint);
  for (const button of page.querySelectorAll('[data-shizuku-action]')) {
    button.disabled = busy || (button.dataset.shizukuAction === 'permission' ? status !== 'permission_required' : !ready);
    if (button.dataset.shizukuAction === 'permission') button.style.display = ready ? 'none' : '';
  }
}
async function refresh() {
  if (!page?.isConnected || busy || loading) return;
  loading = true;
  const target = page;
  try {
    const result = await cmd('getShizukuState', {}, { timeoutMs: 5000 });
    if (target === page) { state = result.ok ? result.data : { status: 'unavailable' }; paint(); }
  } catch (_) {
    if (target === page) { state = { status: 'unavailable' }; paint(); }
  } finally { loading = false; }
}
async function run(action, button) {
  if (busy) return;
  busy = true; button.classList.add('plugin-busy'); paint();
  try {
    const result = await cmd(action === 'permission' ? 'requestShizukuPermission' : 'runShizukuAction', action === 'permission' ? {} : { action }, { timeoutMs: 185000 });
    if (!result.ok) throw new Error(result.error || deviceText('Shizuku request failed'));
    if (action === 'permission') {
      state = result.data;
      showToast({ title: 'Shizuku', message: deviceText('Approve the request on the kiosk.') });
    } else if (action === 'identity') {
      const data = result.data;
      await messageBox({ title: deviceText('Connection test'), message: data.exitCode === 0 && !data.timedOut ? t('deviceShizukuTestOk', {access: state.uid === 0 ? 'root' : 'shell'}) : deviceText('Shizuku could not complete the connection test.') });
    } else {
      const rows = result.data.results || [], failed = rows.filter(row => !row.ok);
      const message = () => !rows.length ? deviceText('All permissions are already granted.') : !failed.length ? deviceText('Android confirmed the requested permissions.') : failed.map(row => `${deviceText(permissionNames[row.key] || row.key)}: ${deviceOperationError(row.error)}`).join('\n');
      await messageBox({ title: () => deviceText('Permission results'), message });
    }
  } catch (error) { showToast({ title: 'Shizuku', message: deviceOperationError(error.message), kind: 'error' }); }
  finally { busy = false; button.classList.remove('plugin-busy'); paint(); await refresh(); }
}
export function renderShizukuPage(container) {
  if (!container) return;
  page = container; state = { status: 'checking' };
  container.replaceChildren();
  container.append(node('div', 'card-title', deviceText('Connection')));
  const connection = node('div', 'card'); const access = row(deviceText('Shizuku access'), deviceText('Checking availability'), 'permission'); access.dataset.connection = '';
  connection.append(access, row(deviceText('Test connection'), deviceText('Read the process identity without changing the device.'), 'identity', deviceText('Test')));
  const permissions = node('div', 'card');
  for (const [action, title, hint] of actions) permissions.append(row(title, hint, action));
  container.append(connection);
  const updateSetting = appState.settings?.find(s => s.key === 'shizuku.install_updates');
  if (updateSetting) {
    const updates = node('div', 'card'); updates.append(settingRow(updateSetting)); container.append(updates);
  }
  container.append(node('div', 'card-title', deviceText('Permissions')), permissions,
    node('div', 'card-title', deviceText('Help')));
  const help = node('div', 'card');
  const link = node('a', 'row plugin-guide-row'); link.dataset.searchId = 'x:shizuku:setup'; link.href = 'https://shizuku.rikka.app/guide/setup/'; link.target = '_blank'; link.rel = 'noopener noreferrer';
  const info = node('div', 'info'); info.append(node('div', 'name', deviceText('Set up Shizuku')), node('div', 'desc', deviceText('Read installation and startup instructions.'))); link.append(info);
  help.append(link, hintRow(deviceText('Shizuku started through ADB must be started again after a device reboot. Shell access does not provide root permissions.')));
  container.append(help); paint();
  if (currentPath === 'device/Shizuku') refresh();
}
watchUpdates(['shizuku'], refresh, { visible: () => currentPath === 'device/Shizuku' });
