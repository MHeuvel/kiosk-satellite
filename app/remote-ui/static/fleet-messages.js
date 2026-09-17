import { fleetText, t } from './localization.js';

export function profileName(p) {
  return p.id === 'default' ? fleetText('Default') : p.id === 'updates-only' ? fleetText('Updates only') : p.name;
}

export function fleetStatusText(value) {
  if (typeof value !== 'string') return value;
  if (value.startsWith('Synced ')) return t("fleetSyncedTime", {time: fleetStatusText(value.slice(7))});
  let match;
  match = /^Sending ([0-9]+)%$/.exec(value);
  if (match) return t("fleetSendingPercent", {percent: match[1]});
  match = /^Downloading ([0-9]+)%$/.exec(value);
  if (match) return t("fleetDownloadingPercent", {percent: match[1]});
  match = /^Runs (.+), this kiosk needs an update$/.exec(value);
  if (match) return t("fleetRunsVersionThisKioskNeedsAnUpdate", {version: match[1]});
  match = /^Needs (.+)$/.exec(value);
  if (match) return t("fleetNeedsVersion", {version: match[1]});
  match = /^([0-9]+) min ago$/.exec(value);
  if (match) return t("fleetCountMinAgo", {count: match[1]});
  match = /^([0-9]+) h ago$/.exec(value);
  if (match) return t("fleetCountHAgo", {count: match[1]});
  match = /^([0-9]+) days ago$/.exec(value);
  if (match) return t("fleetCountDaysAgo", {count: match[1]});
  match = /^A profile named (.+) exists$/.exec(value);
  if (match) return t('fleetProfileNameExists', {name:match[1]});
  match = /^already on (.+)$/.exec(value);
  if (match) return t('fleetAlreadyOnVersion', {version:match[1]});
  return fleetText(value);
}
