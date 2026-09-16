/// Notify the native bridge when Voice Satellite changes browser settings.
/// Storage behavior stays intact and a batch of writes sends one signal.
const remoteSettingsScript = r'''
  try {
    let settingsQueued = false;
    const storage = window.localStorage;
    for (const method of ['setItem', 'removeItem', 'clear']) {
      const original = Storage.prototype[method];
      Storage.prototype[method] = function () {
        const result = original.apply(this, arguments);
        const key = arguments[0];
        if (this === storage && (method === 'clear' ||
            (typeof key === 'string' && key.startsWith('vs-'))) && !settingsQueued) {
          settingsQueued = true;
          Promise.resolve().then(function () {
            settingsQueued = false;
            call('remoteSettingsChanged');
          });
        }
        return result;
      };
    }
  } catch (_) {}
''';
