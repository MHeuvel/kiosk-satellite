import { fleetTextMessageIds } from './fleet_text_ids.js';
import { pluginTextMessageIds } from './plugin_text_ids.js';
import { launcherTextMessageIds } from './launcher_text_ids.js';
import { gestureTextMessageIds } from './gesture_text_ids.js';
import { kioskTextMessageIds } from './kiosk_text_ids.js';
import { intercomTextMessageIds } from './intercom_text_ids.js';
import { mediaTextMessageIds } from './media_text_ids.js';
import { screensaverTextMessageIds } from './screensaver_text_ids.js';
import { cameraTextMessageIds } from './camera_text_ids.js';
import { cameraStreamsTextMessageIds } from './camera_streams_text_ids.js';
import { screenAudioTextMessageIds } from './screen_audio_text_ids.js';
import { catalogs } from './catalogs.js';
import { navigationMessageIds } from './navigation_ids.js';
import { deviceTextMessageIds } from './device_text_ids.js';
import { haTextMessageIds } from './ha_text_ids.js';

export function launcherText(english) {
  return t(launcherTextMessageIds[english], {}, english);
}

export function gestureText(english) {
  return t(gestureTextMessageIds[english], {}, english);
}

export function haText(english) {
  return t(haTextMessageIds[english], {}, english);
}

export function screenAudioText(english) {
  return t(screenAudioTextMessageIds[english], {}, english);
}

export function screensaverText(english) {
  return t(screensaverTextMessageIds[english], {}, english);
}

export function cameraText(english) {
  return t(cameraTextMessageIds[english], {}, english);
}

export function mediaText(english) {
  return t(mediaTextMessageIds[english], {}, english);
}

export function mediaError(error) {
  const sonos = /^No Sonos answered at (.*)\.$/s.exec(error);
  if (sonos) return t('mediaSonosUnreachable', {host: sonos[1]});
  const ha = 'Home Assistant did not answer: ';
  if (error.startsWith(ha)) return t('mediaHaFailed', {error: error.slice(ha.length)});
  const connected = 'Connected to Music Assistant ';
  if (error.startsWith(connected)) return t('mediaConnectedVersion', {version: error.slice(connected.length)});
  const unreachable = /^Could not reach (.+?): (.*)$/s.exec(error);
  if (unreachable) return t('mediaUnreachable', {host: unreachable[1], error: unreachable[2]});
  return mediaText(error);
}

export function cameraStreamsText(english) {
  return t(cameraStreamsTextMessageIds[english], {}, english);
}

export function cameraStreamsError(error) {
  const http = /^Go2RTC returned HTTP (\d+)$/.exec(error);
  if (http) return t('cameraStreamsHttpError', {status: http[1]});
  const haPrefix = 'could not read Home Assistant: ';
  if (error.startsWith(haPrefix)) return t('cameraStreamsHaReadFailed', {error: error.slice(haPrefix.length)});
  const connection = /^could not connect to (.+?): (.*)$/s.exec(error);
  if (connection) return t('cameraStreamsConnectFailed', {server: connection[1], error: connection[2]});
  return cameraStreamsText(error);
}

export function cameraError(error) {
  return error.startsWith('Snapshot failed: ')
    ? t('cameraSnapshotError', {error: error.slice('Snapshot failed: '.length)}) : cameraText(error);
}

export function cameraResolutionNotice(notice) {
  notice = notice.replace('Motion detection, face detection and hand gestures pause while viewers are connected. Snapshots use video frames at the streaming resolution.', t('cameraAnalysisOff'));
  return notice.split(/(?<=\.) /).map((part) => {
    const extra = /^Turn off Motion analysis while streaming to also use (.+)\.$/.exec(part);
    if (extra) return t('cameraExtraSizes', {sizes: extra[1]});
    const rejected = /^The encoder cannot use (.+) at these settings\.$/.exec(part);
    if (rejected) return t('cameraRejectedSizes', {sizes: rejected[1]});
    const count = /^(\d+) camera sizes are excluded because the encoder cannot use them at these settings\.$/.exec(part);
    if (count) return t('cameraRejectedCount', {count: count[1]});
    return cameraText(part);
  }).join(' ');
}

export function screensaverError(error) {
  const match = /^Use at most ([0-9]+) characters$/.exec(error);
  return match ? t('screensaverMaxCharacters', {count: match[1]}) : screensaverText(error);
}

export function settingsPageText(category, english) {
  return category === 'Device' || category === 'device' ? deviceText(english)
    : category === 'Home Assistant' || category === 'homeassistant' ? haText(english)
    : category === 'Screen & Audio' || category === 'screenaudio' ? screenAudioText(english)
    : category === 'Screensaver' || category === 'screensaver' ? screensaverText(english)
    : category === 'Camera' || category === 'camera' ? cameraText(english)
    : ['Launcher', 'launcher'].includes(category) ? launcherText(english)
    : ['Gestures', 'gestures'].includes(category) ? gestureText(english)
    : ['Fleet', 'fleet'].includes(category) ? fleetText(english)
    : ['Plugins', 'plugins'].includes(category) ? pluginText(english)
    : ['Kiosk', 'kiosk', 'Home', 'home'].includes(category) ? kioskText(english)
    : category === 'Intercom' || category === 'intercom' ? (english === 'Answer' ? t('intercomAnswerSection') : english === 'Talk' ? t('intercomTalkSection') : intercomText(english))
    : category === 'Sendspin' || category === 'sendspin' ? mediaText(english) : english;
}

export function haConnectionError(error) {
  return error.startsWith('unreachable: ')
    ? t('haUnreachable', {error: error.slice('unreachable: '.length)}) : haText(error);
}

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
    englishOptionLabels: setting.englishOptionLabels ?? setting.optionLabels,
    englishPlaceholder: setting.englishPlaceholder ?? setting.placeholder,
    optionLabels: setting.optionMessageIds ? Object.fromEntries(
      Object.entries(setting.englishOptionLabels ?? setting.optionLabels ?? {}).map(([value, label]) =>
        [value, t(setting.optionMessageIds[value], {}, label)])) : setting.optionLabels,
    placeholder: setting.placeholderMessageId ? t(setting.placeholderMessageId, {}, setting.englishPlaceholder ?? setting.placeholder) : setting.placeholder,
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

export function deviceText(english) {
  return typeof english === 'string' ? t(deviceTextMessageIds[english], {}, english) : english;
}

export function messageLanguage() { return languagePreference; }

export function immichError(error) {
  let match = /^The API key is missing the (.+) permission\.$/.exec(error);
  if (match) return t('screensaverMediaScopeMissing', {scope: match[1]});
  const permission = 'The API key is missing a permission: ';
  if (error.startsWith(permission)) return t('screensaverMediaPermissionMissing', {error: error.slice(permission.length)});
  match = /^The server answered ([0-9]+): ([\s\S]*)$/.exec(error);
  if (match) return t('screensaverMediaServerError', {status: match[1], error: match[2]});
  match = /^Could not reach ([\s\S]+)\.$/.exec(error);
  if (match) return t('screensaverMediaUnreachable', {url: match[1]});
  const talk = 'Could not talk to the server: ';
  if (error.startsWith(talk)) return t('screensaverMediaTalkError', {error: error.slice(talk.length)});
  return screensaverText(error);
}

export function intercomText(english) {
  return t(intercomTextMessageIds[english], {}, english);
}
export function intercomError(error, status = null) {
  const targets = status?.call?.targets;
  if (Array.isArray(targets) && targets.length) {
    const statuses = {listening:'listening', busy:'busy', dnd:'do not disturb',
      off:'intercom off', refused:'announcements off', key:'a different key',
      unreachable:'unreachable', left:'done'};
    const label = (value) => Object.hasOwn(statuses, value) ? statuses[value] : value;
    const original = targets.map((target) => `${target.name}: ${label(target.status)}`).join(', ');
    if (error === original) return targets.map((target) =>
      `${target.name}: ${intercomError(label(target.status))}`).join(', ');
  }
  const labels = {
    ended: 'Call ended', declined: 'Declined', cancelled: 'Cancelled',
    busy: 'Busy', 'do not disturb': 'Do not disturb',
    'its intercom is off': 'Its intercom is off',
    'a different intercom key': 'Different intercom key',
    'no answer': 'No answer', missed: 'Missed call',
    'did not answer': 'Did not answer', 'the voice link failed': 'The voice link failed',
    'the page took the microphone': 'The page took the microphone',
    'nobody could take it': 'Nobody could take it', 'the broadcast ended': 'Done',
    listening: 'Listening', 'intercom off': 'Intercom off',
    'announcements off': 'Announcements off', 'a different key': 'Different key',
    unreachable: 'Unreachable', done: 'Done',
  };
  return intercomText(Object.hasOwn(labels, error) ? labels[error] : error);
}
export function intercomAnnouncing(count) {
  return count === 1 ? t('intercomAnnouncingOne') : t('intercomAnnouncingMany', {count});
}

export function kioskText(english) {
  return t(kioskTextMessageIds[english], {}, english);
}

export function fleetText(english) { return t(fleetTextMessageIds[english], {}, english); }
export function pluginText(english) { return t(pluginTextMessageIds[english], {}, english); }
