import { overviewText } from './localization.js';
import { messageBox, modalShell } from './widgets.js';

const labels = new WeakMap();
export function overviewLabel(el, english, property = 'textContent') {
  if (!el) return;
  const record = labels.get(el) || {};
  el[property] = overviewText(english);
  record[property] = {english, rendered: el[property]};
  labels.set(el, record);
  el.dataset.overviewLabel = '';
}
export function refreshOverviewLabels() {
  document.querySelectorAll('[data-overview-text]').forEach(el => {
    overviewLabel(el, el.dataset.overviewText);
    el.removeAttribute('data-overview-text');
  });
  document.querySelectorAll('[data-overview-title]').forEach(el => {
    overviewLabel(el, el.dataset.overviewTitle, 'title');
    el.setAttribute('aria-label', el.title);
  });
  document.querySelectorAll('[data-overview-label]').forEach(el => {
    for (const [property, label] of Object.entries(labels.get(el) || {})) {
      // Another control may own this text now, such as download progress.
      if (el[property] !== label.rendered) continue;
      el[property] = overviewText(label.english);
      label.rendered = el[property];
    }
  });
}
export function overviewModalShell(options) {
  const shell = modalShell(options);
  overviewLabel(shell.head, options.title);
  return shell;
}
export function overviewMessageBox(options) {
  // Keep the original button values used by the caller's command logic.
  const result = messageBox(options);
  const shell = document.querySelector('.modal-back:last-child');
  overviewLabel(shell?.querySelector('.modal-title'), options.title);
  overviewLabel(shell?.querySelector('.modal-body p'), options.message);
  shell?.querySelectorAll('.modal-foot button').forEach((el, i) => {
    overviewLabel(el, (options.buttons || ['OK'])[i]);
  });
  return result;
}
document.addEventListener('ks-settings-cached', refreshOverviewLabels);
refreshOverviewLabels();
