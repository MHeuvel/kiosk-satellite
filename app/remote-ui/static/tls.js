import { cmd } from './core.js';
import { deviceOperationError, deviceText, messageLanguage } from './localization.js';
import { banner, copyBox, hintRow, messageBox, modalShell } from './widgets.js';

const text = deviceText;
function element(tag, content = '', className = '') {
  const node = document.createElement(tag);
  node.textContent = content;
  node.className = className;
  return node;
}
function button(label, style, action) {
  const node = element('button', text(label), style);
  node.type = 'button';
  node.addEventListener('click', action);
  return node;
}
async function command(name, params = {}) {
  const result = await cmd(name, params);
  if (!result?.ok) throw new Error(result?.error || text('Certificate operation failed.'));
  return result.data;
}

export function renderTlsSettings(root) {
  const panel = element('div', '', 'tls-panel');
  root.append(panel);
  let busy = false;
  let info = null;
  const error = element('div');
  error.setAttribute('role', 'alert');

  async function run(action) {
    if (busy) return;
    busy = true;
    panel.querySelectorAll('button').forEach(node => node.disabled = true);
    error.replaceChildren();
    try { await action(); }
    catch (e) { error.replaceChildren(banner(deviceOperationError(e.message), { error: true })); }
    finally { busy = false; if (panel.isConnected) draw(); }
  }
  function actionRow(title, description, label, action, disabled = false) {
    const row = element('div', '', 'row device-action-row');
    const descriptionBox = element('div', '', 'info');
    descriptionBox.append(element('div', text(title), 'name'), element('div', text(description), 'desc'));
    const control = button(label, 'btn-ghost', action);
    control.disabled = disabled || busy;
    row.append(descriptionBox, control);
    return row;
  }
  function valueRow(title, value) {
    const row = element('div', '', 'row');
    const label = element('div', '', 'info');
    label.append(element('div', text(title), 'name'));
    row.append(label, element('span', value));
    return row;
  }
  function download() {
    const link = document.createElement('a');
    const url = URL.createObjectURL(new Blob([info.certificate], { type: 'application/x-pem-file' }));
    link.href = url;
    link.download = 'kiosk-satellite.pem';
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  function openImport() {
    let pending = false;
    const shell = modalShell({ title: text('Import certificate'), width: 560,
      onDismiss: () => { if (!pending) shell.close(); } });
    shell.body.append(hintRow(text('Paste the PEM certificate chain and its unencrypted private key. They are validated before replacing the current certificate.')));
    const form = element('form', '', 'modal-form tls-import');
    const field = (label) => {
      const row = element('label', '', 'form-field');
      row.append(element('span', text(label)));
      const input = element('textarea', '', 'field');
      input.rows = 4;
      input.required = true;
      input.autocomplete = 'off';
      input.spellcheck = false;
      row.append(input);
      form.append(row);
      return input;
    };
    const certificate = field('Certificate chain (PEM)');
    const privateKey = field('Private key (PEM)');
    const issue = element('div');
    issue.setAttribute('role', 'alert');
    form.append(issue);
    shell.body.append(form);
    const cancel = button('Cancel', 'btn-text', () => shell.close());
    const save = button('Import', 'btn-primary', () => form.requestSubmit());
    shell.foot.append(cancel, save);
    form.addEventListener('submit', async event => {
      event.preventDefault();
      if (pending || !form.reportValidity()) return;
      pending = true;
      cancel.disabled = save.disabled = certificate.disabled = privateKey.disabled = true;
      issue.replaceChildren();
      try {
        info = await command('importTlsCertificate', { certificate: certificate.value, privateKey: privateKey.value });
        privateKey.value = '';
        shell.close();
        if (panel.isConnected) draw();
      } catch (e) {
        issue.replaceChildren(banner(deviceOperationError(e.message), { error: true }));
      } finally {
        pending = false;
        cancel.disabled = save.disabled = certificate.disabled = privateKey.disabled = false;
      }
    });
    certificate.focus();
  }
  async function replace() {
    const choice = await messageBox({
      title: text('Replace certificate'),
      message: text('Generate a new private key and certificate? Active encrypted connections will close. Browsers may ask you to accept the new certificate.'),
      buttons: ['Cancel', 'Replace'],
    });
    if (choice === 'Replace') run(async () => { info = await command('replaceTlsIdentity'); });
  }
  function draw() {
    panel.replaceChildren(error);
    if (info) {
      const details = element('div', '', 'card');
      details.append(valueRow('Certificate type', text(info.imported ? 'Imported' : 'Self-signed')),
        valueRow('Expires', new Date(info.expires).toLocaleDateString(messageLanguage(), { year: 'numeric', month: 'short', day: 'numeric' })));
      if (info.expired) details.append(hintRow(text('Certificate expired. Renew or import a replacement.'), { warn: true }));
      const fingerprint = element('div', '', 'row tls-fingerprint');
      const label = element('div', '', 'info');
      label.append(element('div', text('SHA-256 fingerprint'), 'name'));
      fingerprint.append(label, copyBox(info.fingerprint).el);
      details.append(fingerprint);
      panel.append(details);
    }
    const actions = element('div', '', 'card');
    actions.append(actionRow('Download public certificate', 'Use this certificate in browsers and streaming clients.', 'Download', download, !info));
    if (!info?.imported) actions.append(actionRow('Renew certificate', 'Keep the current private key and update the certificate dates.', 'Renew',
      () => run(async () => { info = await command('renewTlsCertificate'); })));
    const canImport = location.protocol === 'https:';
    actions.append(actionRow('Import certificate', canImport ? 'Use a certificate issued for this device.' : 'Enable HTTPS before importing a private key remotely.', 'Import', openImport, !canImport),
      actionRow('Replace certificate', 'Generate a new private key and self-signed certificate.', 'Replace', replace));
    panel.append(element('h2', text('Certificate Management'), 'card-title'), actions);
  }
  draw();
  run(async () => { info = await command('tlsCertificate'); });
}


export function confirmRemoteProtocol(https) {
  const target = new URL(location.href);
  target.protocol = https ? 'https:' : 'http:';
  return new Promise(resolve => {
    const shell = modalShell({ title: text('Change connection protocol'),
      onDismiss: () => finish(false) });
    function finish(confirmed) { shell.close(); resolve(confirmed); }
    const address = copyBox(target.href).el;
    address.classList.add('tls-address');
    shell.body.append(hintRow(text('The current remote connection will close. Reconnect using the address below. You may need to sign in again.')), address);
    shell.foot.append(button('Cancel', 'btn-text', () => finish(false)),
      button('Confirm', 'btn-primary', () => finish(true)));
  });
}
