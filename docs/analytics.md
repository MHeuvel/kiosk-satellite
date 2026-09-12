# Kiosk Satellite Analytics

Kiosk Satellite can share anonymized information about your installation. It helps decide which devices to test on, which features to keep working on and which crashes to fix first.

Everything on this page is optional. Open **Settings > Device > Kiosk Satellite Analytics** on the device or **Device > Kiosk Satellite Analytics** in the remote admin to turn any part of it off.

## What each switch shares

| Switch | What is sent | Why |
|---|---|---|
| **Basic analytics** | Device model and manufacturer, Android version, app version, CPU architecture, screen size and density, system language and time zone. | Tells us which devices and Android releases to test on. |
| **Usage** | Which features are turned on, as switches and picks only: screensaver mode and wake triggers, Voice Satellite with its wake word engine, wake word names and skin, ESPHome, Bluetooth proxy and GPS sensor, media player source, device camera, gesture count, kiosk and lockdown mode, launchers, dashboard carousel and rotation, adaptive brightness, remote admin, fleet role, theme and installed plugin count. | Shows which features people use so work goes where it matters. |
| **Diagnostics** | A crash report when the app stops unexpectedly: the stack trace and the app and Android versions. Restarts the app's own frame watchdog forced after the screen stopped drawing are reported the same way. Restarts you asked for are not. Each report goes out once, on the next start. | Lets us fix crashes nobody reported. |

Basic analytics and Usage are sent together, at most once a day, and only while the app is running. Diagnostics are sent on the next start after a crash.

## What is never sent

- Your Home Assistant address, tokens, passwords, dashboards or entity names.
- Anything from the dashboard itself: screenshots, page content or what you tap.
- Voice audio, camera frames, photos or media.
- Your device name, hostname, Wi-Fi network, IP address, MAC address, location or account details.
- Crash reports strip URLs, entity ids and file paths before they leave the device.

## How it is identified

Each installation generates a random id when analytics first runs. It is not derived from the hardware, it cannot be traced back to you and it changes if you turn every switch off and back on. It only exists so the same kiosk is not counted as a new install every day.

## Where it goes

Analytics are sent over HTTPS to `analytics.kiosksatellite.com`, a service run for Kiosk Satellite. The hostname sits behind Cloudflare, which terminates the connection at its edge like it does for any site it fronts. No other party receives the data and no analytics SDK is bundled with the app. Blocking that domain on your network stops all of it, with no effect on the app.

The receiver looks up the country and city the connection came from and keeps those two names with the install. The address itself is not stored or logged.

## Fleet management

The three switches sync with the Device category like any other setting, so a fleet decides once on the leader. Exclude the Device category from a profile to let each kiosk choose for itself.
