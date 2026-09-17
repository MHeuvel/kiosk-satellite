import { launcherText } from './localization.js';
import { deviceText, screensaverText, immichError, t } from './localization.js';
import { cmd } from './core.js';
import { modalShell } from './widgets.js';

function mediaPickerStatus(list, message) {
  const text = document.createElement('div');
  text.className = 'desc';
  text.style.color = 'var(--muted)';
  text.textContent = message;
  list.replaceChildren(text);
}

/* ---- Media browser (screensaver) ---- */
// A modal that walks the Home Assistant media tree over haBrowseMedia, the
// same command and the same shape the device's native picker uses. Resolves to
// the chosen media-source id, or null if cancelled.
// The two questions a configuration import must ask (issue #25): does this
// device become the backup's device (name + ESPHome identity) or stay itself,
// and does the page's saved data (which carries the Voice Satellite
// selection) come along. Resolves {adopt, local} or null on cancel. The
// checkbox default follows the choice until the user touches it.
export function askImportOptions(backupName) {
  return new Promise((resolve) => {
    const { back, body, foot } = modalShell({
      title: deviceText('Import configuration'),
      width: 460,
      onDismiss: () => close(null),
    });
    const close = (val) => { back.remove(); resolve(val); };

    let adopt = false;
    let local = false;
    let localTouched = false;
    const replaceLabel = backupName && backupName.trim()
      ? t('deviceReplaceNamed', {name: backupName.trim()}) : deviceText('Replace the original device');

    body.innerHTML = `
      <div style="font-size:13.5px; margin-bottom:12px">Replace this device's settings with the file's? The page may reload.</div>
      <label style="display:block; margin-bottom:8px"><input type="radio" name="impid"> Set up as new device<div class="desc" style="margin-left:22px">Assign its own name and ESPHome identity, so both devices are unique.</div></label>
      <label style="display:block; margin-bottom:12px"><input type="radio" name="impid"> <span id="impReplaceLbl"></span><div class="desc" style="margin-left:22px">Keeps the backup's name and ESPHome identity; the original device must stay offline.</div></label>
      <label style="display:block"><input type="checkbox" id="impLocal"> Restore Webview's local storage<div class="desc" style="margin-left:22px">Includes the Home Assistant signed in session and the Voice Satellite assist_satellite selection - two devices must not share one satellite.</div></label>`;
    const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      const value = node.textContent.trim();
      if (value) node.textContent = node.textContent.replace(value, deviceText(value));
    }
    body.querySelector('#impReplaceLbl').textContent = replaceLabel;
    const radios = body.querySelectorAll('input[type=radio]');
    const localCb = body.querySelector('#impLocal');
    radios[0].checked = true;
    radios.forEach((r, i) => r.addEventListener('change', () => {
      adopt = i === 1;
      if (!localTouched) { local = adopt; localCb.checked = adopt; }
    }));
    localCb.addEventListener('change', () => {
      local = localCb.checked;
      localTouched = true;
    });
    const cancel = document.createElement('button');
    cancel.className = 'btn-text';
    cancel.textContent = deviceText('Cancel');
    cancel.addEventListener('click', () => close(null));
    const go = document.createElement('button');
    go.className = 'btn-primary';
    go.textContent = deviceText('Import');
    go.addEventListener('click', () => close({ adopt, local }));
    foot.append(cancel, go);
  });
}

export function openMediaBrowser() {
  return new Promise((resolve) => {
    const trail = [{ id: undefined, title: screensaverText('Media') }];

    const shell = modalShell({
      title: screensaverText('Media'),
      width: 520,
      onDismiss: () => close(null),
    });
    const close = (val) => { shell.close(); resolve(val); };

    // The breadcrumb trail stays visible above the scrolling list.
    const crumbs = document.createElement('div');
    crumbs.style.cssText =
      'flex:none; font-size:13px; color:var(--muted); margin-bottom:10px';
    shell.card.insertBefore(crumbs, shell.body);
    const list = shell.body;
    const foot = shell.foot;

    async function open(id, title, push) {
      if (push) trail.push({ id, title });
      crumbs.textContent = trail.map((c) => c.title).join('  ›  ');
      mediaPickerStatus(list, screensaverText('Loading…'));
      let node;
      try {
        const r = await cmd('haBrowseMedia', id ? { mediaContentId: id } : {});
        if (!r.ok) throw new Error(r.error || screensaverText('browse failed'));
        node = r.data;
      } catch (e) {
        list.textContent = '';
        const error = document.createElement('div');
        error.className = 'desc'; error.style.color = 'var(--error)';
        error.textContent = t('screensaverMediaBrowseError', {error: String(e)});
        list.appendChild(error);
        return;
      }
      list.innerHTML = '';
      for (const c of (node.children || [])) {
        const r = document.createElement('div'); r.className = 'row';
        const info = document.createElement('div'); info.className = 'info';
        const isCam = (c.media_content_id || '').startsWith('media-source://camera/');
        info.innerHTML = `<div class="name"></div><div class="desc"></div>`;
        info.querySelector('.name').textContent = c.title;
        info.querySelector('.desc').textContent =
          c.can_expand ? screensaverText('folder') : isCam ? screensaverText('camera') : (c.media_content_type || screensaverText('item'));
        r.appendChild(info);
        r.style.cursor = 'pointer';
        r.addEventListener('click', () => {
          if (c.can_expand) open(c.media_content_id, c.title, true);
          else if (c.can_play) close({ id: c.media_content_id, isFolder: false });
        });
        list.appendChild(r);
      }
      if (!node.children || !node.children.length)
        mediaPickerStatus(list, screensaverText('Nothing here.'));

      foot.innerHTML = '';
      const cancel = document.createElement('button');
      cancel.className = 'btn-text'; cancel.textContent = screensaverText('Cancel');
      cancel.addEventListener('click', () => close(null));
      const spacer = document.createElement('span'); spacer.className = 'spacer';
      foot.append(cancel, spacer);
      if (trail.length > 1 && node.can_expand) {
        const useFolder = document.createElement('button');
        useFolder.className = 'btn-ghost'; useFolder.textContent = screensaverText('Use this folder');
        useFolder.addEventListener('click', () => close({ id: node.media_content_id, isFolder: true }));
        foot.appendChild(useFolder);
      }
    }
    open(undefined, screensaverText('Media'), false);
  });
}

// The launcher whitelist picker: every launchable app on the device with a
// checkbox, resolving to the chosen [{package, label}] or null on cancel.
// Saving rebuilds the value from the device's list, so labels refresh and
// uninstalled leftovers drop out, same as the on-device picker.
export function openLauncherAppsPicker(current) {
  return new Promise((resolve) => {
    const selected = new Set((current || []).map((a) => a.package));

    const shell = modalShell({
      title: launcherText('Apps'),
      width: 520,
      onDismiss: () => close(null),
    });
    const close = (val) => { shell.close(); resolve(val); };
    const list = shell.body;
    list.innerHTML = '<div class="desc" style="color:var(--muted)"></div>';
    list.firstChild.textContent = launcherText('Loading…');

    const cancel = document.createElement('button');
    cancel.className = 'btn-text'; cancel.textContent = launcherText('Cancel');
    cancel.addEventListener('click', () => close(null));
    const okBtn = document.createElement('button');
    okBtn.className = 'btn-primary'; okBtn.textContent = launcherText('Save'); okBtn.disabled = true;
    shell.foot.append(cancel, okBtn);

    (async () => {
      let apps = [];
      try {
        const r = await cmd('installedApps');
        if (!r.ok) throw new Error(r.error || launcherText('listing failed'));
        apps = r.data || [];
      } catch (e) {
        list.innerHTML = '<div class="desc" style="color:var(--error)"></div>';
        list.firstChild.textContent = t('launcherListError', {error: String(e)});
        return;
      }
      list.innerHTML = '';
      for (const app of apps) {
        const r = document.createElement('label');
        r.className = 'row';
        r.style.cursor = 'pointer';
        const info = document.createElement('div'); info.className = 'info';
        info.innerHTML = `<div class="name"></div><div class="desc"></div>`;
        info.querySelector('.name').textContent = app.label;
        info.querySelector('.desc').textContent = app.package;
        const box = document.createElement('input');
        box.type = 'checkbox';
        box.checked = selected.has(app.package);
        box.addEventListener('change', () => {
          if (box.checked) selected.add(app.package);
          else selected.delete(app.package);
        });
        // The checkbox leads the row, the whole row toggles it.
        r.append(box, info);
        list.appendChild(r);
      }
      if (!apps.length) {
        list.innerHTML = '<div class="desc" style="color:var(--muted)"></div>';
        list.firstChild.textContent = launcherText('No launchable apps found.');
        return;
      }
      okBtn.disabled = false;
      okBtn.addEventListener('click', () => close(
        apps.filter((a) => selected.has(a.package))
          .map((a) => ({ package: a.package, label: a.label })),
      ));
    })();
  });
}


// The struck-out eye a person hidden in Immich wears, the device's
// Icons.visibility_off_outlined traced in the page's stroke style.
const HIDDEN_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"'
  + ' stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
  + '<path d="M10.6 6.2A9.9 9.9 0 0 1 12 6c5 0 9 4.5 10 6a15.6 15.6 0 0 1-3.2 3.7"/>'
  + '<path d="M6.6 8.3C4.2 9.8 2.5 11.6 2 12c1 1.5 5 6 10 6 1.7 0 3.2-.5 4.5-1.2"/>'
  + '<path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/><path d="m3 3 18 18"/></svg>';

// The Immich album, people and tag pickers (issue #345): every name the
// server lists with a checkbox, resolving to the chosen [{id, name}] or
// null on cancel. Names only, no face thumbnails: the list is the same the
// device's picker shows. Saving rebuilds the value from the server's list,
// so renamed entries refresh and merged or deleted ones drop out.
export function openImmichNamesPicker({ title, command, current, none }) {
  return new Promise((resolve) => {
    const selected = new Set((current || []).map((n) => n.id));

    const shell = modalShell({
      title,
      width: 520,
      onDismiss: () => close(null),
    });
    const close = (val) => { shell.close(); resolve(val); };
    const list = shell.body;
    mediaPickerStatus(list, screensaverText('Loading…'));

    const cancel = document.createElement('button');
    cancel.className = 'btn-text'; cancel.textContent = screensaverText('Cancel');
    cancel.addEventListener('click', () => close(null));
    const okBtn = document.createElement('button');
    okBtn.className = 'btn-primary'; okBtn.textContent = screensaverText('Save'); okBtn.disabled = true;
    shell.foot.append(cancel, okBtn);

    (async () => {
      let options = [];
      try {
        const r = await cmd(command);
        if (!r.ok) throw new Error(r.error || screensaverText('listing failed'));
        options = r.data || [];
      } catch (e) {
        list.innerHTML = '';
        const err = document.createElement('div');
        err.className = 'desc'; err.style.color = 'var(--error)';
        err.textContent = t('screensaverMediaListError', {error: immichError(String(e.message || e))});
        list.appendChild(err);
        return;
      }
      list.innerHTML = '';
      if (!options.length) {
        const empty = document.createElement('div');
        empty.className = 'desc'; empty.style.color = 'var(--muted)';
        empty.textContent = none;
        list.appendChild(empty);
        return;
      }
      for (const option of options) {
        const r = document.createElement('label');
        r.className = 'row';
        r.style.cursor = 'pointer';
        const info = document.createElement('div'); info.className = 'info';
        const name = document.createElement('div'); name.className = 'name';
        name.textContent = option.name;
        info.appendChild(name);
        // Albums carry their size, which tells two similarly named ones
        // apart, and a person hidden in Immich says so under a struck-out
        // eye: the filter still works on them (issue #382).
        if (option.count != null) {
          const desc = document.createElement('div'); desc.className = 'desc';
          desc.textContent = t('screensaverMediaItems', {count: String(option.count)});
          info.appendChild(desc);
        } else if (option.hidden) {
          const desc = document.createElement('div');
          desc.className = 'desc with-icon';
          desc.innerHTML = HIDDEN_ICON + '<span></span>';
          desc.querySelector('span').textContent = screensaverText('Hidden');
          info.appendChild(desc);
        }
        const box = document.createElement('input');
        box.type = 'checkbox';
        box.checked = selected.has(option.id);
        box.addEventListener('change', () => {
          if (box.checked) selected.add(option.id);
          else selected.delete(option.id);
        });
        r.append(box, info);
        list.appendChild(r);
      }
      okBtn.disabled = false;
      okBtn.addEventListener('click', () => close(
        options.filter((o) => selected.has(o.id))
          .map((o) => ({ id: o.id, name: o.name })),
      ));
    })();
  });
}
