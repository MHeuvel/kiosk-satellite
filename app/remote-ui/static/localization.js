import { catalogs } from './catalogs.js';
import { navigationMessageIds } from './navigation_ids.js';

// The kiosk and remote administration share one explicit language choice.
let languagePreference = 'en';

export function setLanguagePreference(value) {
  languagePreference = Object.hasOwn(catalogs, value) ? value : 'en';
  if (globalThis.document) document.documentElement.lang = languagePreference;
}

export function formatMessage(pattern, values = {}) {
  return pattern.replace(/\{([a-z][A-Za-z0-9]*)\}/g, (match, name) => {
    if (!Object.hasOwn(values, name)) throw new Error(`Missing message placeholder: ${name}`);
    return String(values[name]);
  });
}

export function t(id, values = {}, fallback = id) {
  const locale = languagePreference;
  const pattern = catalogs[locale]?.[id] ?? catalogs.en[id] ?? fallback;
  return formatMessage(pattern, values);
}

export function localizeSetting(setting) {
  const englishTitle = setting.englishTitle ?? setting.title;
  const englishDescription = setting.englishDescription ?? setting.description;
  return {
    ...setting,
    englishTitle,
    englishDescription,
    title: setting.titleMessageId ? t(setting.titleMessageId, {}, englishTitle) : setting.title,
    description: setting.descriptionMessageId
      ? t(setting.descriptionMessageId, {}, englishDescription) : setting.description,
  };
}

// Menu labels are presentation only. Routes and setting categories stay stable.
export function navigationText(english) {
  return t(navigationMessageIds[english], {}, english);
}

export function localizeNavigation() {
  document.querySelectorAll('#tabs .nav-title, #tabs .nav-sub, #tabs .nav-head').forEach(element => {
    element.dataset.englishText ??= element.textContent;
    element.textContent = navigationText(element.dataset.englishText);
  });
  const search = document.getElementById('settingsSearch');
  if (search) {
    search.placeholder = t('settingsSearchHint');
    search.setAttribute('aria-label', t('settingsSearchHint'));
  }
  document.getElementById('settingsSearchClear')?.setAttribute('aria-label', t('settingsSearchClear'));
  document.getElementById('navToggle')?.setAttribute('aria-label', t('settingsMenuMenu'));
  document.querySelectorAll('[data-home]').forEach(element => {
    element.title = t('settingsMenuOverview');
    element.setAttribute('aria-label', element.title);
  });
  document.querySelectorAll('.js-fleet-pick').forEach(element => element.setAttribute('aria-label', t('settingsMenuSwitchKiosk')));
  const theme = document.getElementById('themeBtn');
  if (theme) {
    theme.title = themeLabel(localStorage.getItem('ks_theme') || 'light');
    theme.setAttribute('aria-label', theme.title);
  }
  const logout = document.getElementById('logoutBtn');
  if (logout) logout.textContent = t('settingsMenuLogout');
}

export function themeLabel(preference) {
  const theme = preference === 'dark' ? t('drawerThemeDark')
    : preference === 'light' ? t('drawerThemeLight') : t('settingsMenuThemeAuto');
  return t('settingsMenuThemeState', { theme });
}
