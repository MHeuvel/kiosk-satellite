The Voice Satellite defaults are bundled from
`custom_components/voice_satellite/sounds/` in the Voice Satellite integration.

- `timer-alert.mp3` is `alert.mp3`.
- `voice-wake.mp3`, `voice-done.mp3`, `voice-error.mp3` and `voice-announce.mp3`
  keep their corresponding sounds with a `voice-` prefix.

Custom sounds are selected under Settings > Voice Satellite > Chimes and stored
in the app's `sounds` folder. They survive app updates. Home Assistant sound
replacements do not change the sounds played locally by Kiosk Satellite.
