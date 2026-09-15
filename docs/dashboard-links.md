# Dashboard Links

A dashboard button can open the kiosk's own features or another Android app by pointing its tap action at a link with one of two schemes Kiosk Satellite claims. The link never leaves the dashboard: the app intercepts it, runs what it names and the page stays put. Anything on a dashboard that takes a URL works, so a button card's `url` tap action, a picture elements icon, a tile card or a link in a markdown card all do the same thing.

```yaml
type: button
name: Apps
icon: mdi:apps
tap_action:
  action: url
  url_path: ks://apps
```

Only these two schemes are claimed. Chromium's `intent://` links are refused on purpose, since they can carry any component and extras.

## Kiosk features: `ks://`

A `ks://` link runs the same action a [gesture](gestures.md) can, with the same rules. The app launcher refuses when it is off or has no apps picked, the intercom refuses when it is off, and the outcome shows in a toast when the link cannot do what it names. The Allowed Actions of a restricted kiosk menu are not consulted: a link is one way to keep a feature reachable while its menu row is hidden.

| Link | What it does |
| --- | --- |
| `ks://apps` | Opens the [app launcher](kiosk.md) overlay. `ks://launcher` is the same thing. |
| `ks://now-playing` | Opens the full-screen Now Playing view for the selected media player. Requires Now Playing to be enabled and a track to be loaded. |
| `ks://player` | Shows the floating [media player](sendspin.md) card. |
| `ks://music-assistant` | Opens Music Assistant's web interface for the kiosk's player. Requires a Music Assistant server address. |
| `ks://camera` | Shows the default [camera view](cameras.md). |
| `ks://camera/<view id>` | Shows that camera view. The id is the one shown on the view's page under Camera streams. |
| `ks://camera/close` | Closes whatever camera view is showing. |
| `ks://intercom` | Opens the [intercom's](intercom.md) Call a kiosk sheet. |
| `ks://intercom/<kiosk id>` | Calls that kiosk straight away. The id is the one under Intercom, Kiosks. |
| `ks://screensaver` | Starts the screensaver. |
| `ks://screensaver/stop` | Stops it. |
| `ks://hold` | Toggles hold mode, which pins the current view. |
| `ks://ha-kiosk` | Toggles HA kiosk mode, the Home Assistant header and sidebar. |
| `ks://android-settings` | Opens the Android Settings app with the kiosk running behind it. |

Exit, restart and the settings pages are deliberately not offered. The first two the kiosk menu confirms with a dialog and the third sits behind the exit gesture and PIN, and a dashboard tap should not get around either.

## Other apps: `app://`

`app://<package name>` opens another installed app, keeping the kiosk running in the background so its Home Assistant entities and the wake word stay alive. The clock app to set an alarm, a music app, a browser, whatever is installed. Use the app's package name, for example `app://com.android.deskclock`. The [app launcher's](kiosk.md) return feature brings the kiosk back after the app goes untouched, when it is enabled.

A link that names an app which is not installed shows a toast saying so.
