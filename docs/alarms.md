# Alarms

Kiosk Satellite has alarms of its own. They live on the kiosk and ring without Home Assistant, a network or the dashboard. You get a list with a switch per alarm, a scroll wheel to pick the time, one page for the details and a full screen with Snooze and Stop when an alarm rings.

Open the list from **Alarms** in the kiosk menu, from **Manage alarms** under **Settings, Alarms**, from the **Next alarm** screensaver widget or from the **Alarms** page of the remote admin.

## Setting an alarm

1. Tap **Set an alarm** and pick the time on the wheel. A device set to 24 hour time shows two wheels, otherwise there is an AM or PM wheel too.
2. **Set** saves the alarm, turned on, and a toast says how long until it rings.
3. The details page adds the rest. Tap **Done** to keep the changes or **Delete** to remove the alarm.

| Detail | What it does |
| --- | --- |
| Repeat | The days the alarm rings on. With no day picked it rings once, at the next time the clock reads its time, then turns itself off and stays in the list. |
| Label | A name shown in the list and on the ringing screen. |
| Alarm tone | **Default** follows the Alarm tone setting. **Built-in alarm** is the sound bundled with the app. Any sound in the sounds folder works too. Picking a tone plays it once at the alarm volume. |
| Sunrise | The screen brightens gradually before the alarm rings. See [Sunrise](#sunrise). |

Tap the time on the details page to change it. The switch in the list turns an alarm on or off without opening it.

There is one alarm per time and repeat. Setting a time that already has an alarm on the same days opens that alarm, turned on, instead of adding a second one. The remote admin refuses the duplicate the same way.

## When an alarm rings

The alarm wakes the screen, comes in front of the dashboard or another app and plays its tone on the Android alarm stream, so a muted media volume does not silence it. It rings until one of these happens:

- **Stop** ends it. The stop word stops it too, the same way it stops a timer.
- **Snooze** holds it off for the snooze length, then it rings again. In the list a snoozed alarm says until when and carries a **Stop** button.
- **Silence after** runs out and it goes quiet on its own. It counts as stopped, not snoozed.

A tap anywhere else does nothing, so a brush of the hand never ends an alarm. Two alarms set to the same minute ring as one and show both labels. Under Lockdown Mode the screen takes no touch, so the stop word, Home Assistant or the remote admin stop the alarm there.

An alarm rings on its own full screen view, with one exception: when the screensaver is **Clock** or **Weather Mood** and its **Let alarms take over** switch is on (the default), the alarm rings on that screensaver instead. It keeps everything the screensaver is set to, including the font, colors, shadow, background, Night mode and corner widgets. The date line becomes the alarm's label and Snooze and Stop come in under the clock in the screensaver's own colors. A screensaver dimmed by its own brightness setting comes back to normal brightness while the alarm rings and dims again after Stop or Snooze. On Weather Mood the weather bar makes way for the two buttons. If something else is on screen, the alarm starts the screensaver first.

A kiosk that was switched off or restarted through the whole Silence after window skips the alarm rather than ring it late.

## Sunrise

A sunrise alarm starts before its time, as long as **Sunrise length** says. On the alarm's own view a glow rises from deep red to warm white while the screen brightens from its lowest level to full, then the alarm rings on the last color. A touch during the sunrise shows a **Stop** button for a few seconds, and Stop skips the ring too.

On a Clock or Weather Mood screensaver that lets alarms take over, the screensaver shows through the sunrise and only the brightness climbs. A touch that dismisses the screensaver ends the sunrise, and the alarm still rings at its time.

## Settings, Alarms

| Setting | What it does |
| --- | --- |
| Show in the kiosk menu | Adds the Alarms entry to the kiosk menu. On by default. |
| Manage alarms | Opens the alarm list. Shows when the next alarm rings. |
| Alarm volume | How loud alarms ring. It sets the Android alarm volume while an alarm rings and puts it back after, apart from the media and assistant volumes. |
| Alarm tone | The tone an alarm set to Default plays: the built-in alarm or a sound from the sounds folder. **Add a sound** copies a file into the folder, the same way the notification and announcement sounds work. |
| Snooze length | 5 to 30 minutes. |
| Silence after | How long an alarm rings when nobody stops it, 5 to 30 minutes. |
| Sunrise length | How long the screen takes to brighten before a sunrise alarm, 10 to 30 minutes. |

**Alarms** under **Kiosk Mode, Allowed Actions** decides whether the restricted kiosk menu offers the list too.

The screensaver waits while the alarm list is open, so it never cuts off an alarm being set.

[Fleet Management](fleet.md) syncs these defaults, Show in the kiosk menu included, under its Alarms category. The alarms themselves stay on each kiosk.

## Next alarm widget

**Next alarm** is a [screensaver widget](screensavers.md#widgets) that shows the next alarm when it rings within 24 hours, and the snooze while one runs. The corner stays empty the rest of the time. A tap on the widget opens the alarm list, the one spot on a screensaver that does more than dismiss it.

## Remote admin

The **Alarms** page lists every alarm with a switch, an edit button and a delete button. **Set an alarm** and the edit button open one dialog with the time, repeat days, label, tone and sunrise. The same defaults as the device follow the list, including an **Upload** button for sounds from your computer. While an alarm rings, sits in its sunrise or is snoozed, the Overview shows a banner with Snooze and Stop.

## Home Assistant

The kiosk's alarms reach Home Assistant through [ESPHome](esphome.md):

| Entity | Type | Notes |
| --- | --- | --- |
| **Next alarm** | timestamp | The next alarm on the device, the kiosk's own alarms included, since they are scheduled as Android alarm clocks. |
| **Alarm ringing** | binary sensor | On while an alarm rings. |
| **Alarm snoozed until** | timestamp | When a snooze runs out, unknown when nothing is snoozed. |
| **Stop alarm**, **Snooze alarm** | button | The same as the buttons on screen. |

A morning routine is an automation that triggers when **Alarm ringing** turns off.
