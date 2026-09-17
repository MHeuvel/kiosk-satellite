import { catalogs } from './catalogs.js';

// Messages are bundled. The browser language never changes the tablet locale.
export function resolveLanguage(preferred, available = Object.keys(catalogs)) {
  for (const tag of preferred) {
    const exact = available.find(locale => locale.toLowerCase() === tag.toLowerCase());
    if (exact) return exact;
    const language = tag.split('-')[0].toLowerCase();
    if (available.includes(language)) return language;
  }
  return 'en';
}

export function formatMessage(pattern, values = {}) {
  return pattern.replace(/\{([a-z][A-Za-z0-9]*)\}/g, (match, name) => {
    if (!Object.hasOwn(values, name)) throw new Error(`Missing message placeholder: ${name}`);
    return String(values[name]);
  });
}

export function t(id, values = {}, fallback = id) {
  const locale = resolveLanguage(globalThis.navigator?.languages || ['en']);
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
