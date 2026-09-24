# Intercom

Kiosks on the same network can talk to each other. Pick a kiosk from the kiosk menu and it rings there, or announce to every kiosk at once. Each kiosk decides how it answers: ring, answer on its own after a chime, or not at all. Voice travels straight between the two kiosks through a dedicated intercom listener. Older kiosks use their remote admin port. No server and no Home Assistant sit in the path, and Home Assistant sees the state through ESPHome.

Configure it under **Settings, Intercom** on the kiosk, or the **Intercom** tab in the remote admin. Every kiosk on the intercom needs **Remote management** and **Find other kiosks** on (under Settings, Device, Remote Administration). Kiosks find and reach each other through the remote admin, the same way [Fleet Management](fleet.md) does.

## Setup

1. Turn on **Enable intercom**. The kiosk makes an **Intercom key** the first time.
2. Give every other kiosk the same key. In a fleet the leader syncs it as a credential and nothing needs typing. Outside a fleet, copy the key from the box and paste it on the other kiosk through **Change key**.
3. The **Kiosks** list includes discovered kiosks and saved fleet members with a status word. A kiosk reads **Ready** once its admin endpoint answers with intercom on, the same key and matching encryption settings. Saved fleet members remain listed and are probed even when their mDNS advertisements are missing.

| Status | Meaning |
| --- | --- |
| Ready | The intercom is on there with the same key. |
| Intercom off | The kiosk is on the network but its intercom is off, or it runs a version without one. |
| Different key | Its intercom is on with another key. Paste this kiosk's key there, or the other way around. |
| Encryption mismatch | The kiosks have different encryption settings. Enable **Encrypt communications** on both kiosks for encrypted calls. |
| Do not disturb | It is on the intercom but refuses calls right now. |
| Unreachable | The kiosk is discovered or saved in the fleet but its admin port does not answer from here. It remains listed so later probes can detect its return. |
| Offline | The kiosk is no longer discovered and is not in the saved fleet directory. |

**Change key** opens a dialog to paste a key from another kiosk or **Regenerate** a fresh one. A new key cuts this kiosk off from the others until they get it too.

## Placing a call

The **Intercom** entry in the kiosk menu opens the **Call a kiosk** screen, full screen like the app launcher: **Announce to all** at the top, then every kiosk as a row with its name and status. A tap on a Ready kiosk calls it. Kiosks with the intercom off, on Do not disturb, on another key or offline stay on the list dimmed with the reason and take no tap. The X, back or HOME closes the screen, and so does the screensaver.

The call takes the whole screen: the kiosk's name, Calling and Cancel. Nothing plays until the other side answers. Busy, Do not disturb, no answer and a different key end the call with one line on the screen.

The **Open Call a kiosk** [gesture action](gestures.md) opens the same screen, and **Call a kiosk** rings one kiosk picked when the gesture was set up. **Show in the kiosk menu** on the Intercom page takes the entry out of the menu altogether, and the restricted menu has its own Intercom switch under **Kiosk Mode, Allowed Actions**, so a wall panel can keep the entry off while a gesture still opens the screen.

## A call coming in

| Answer mode | What happens |
| --- | --- |
| Ring | The ring sound plays every four seconds with Decline and Answer on screen for as long as **Ring for** says. Then the call counts as missed and a toast offers Call back. |
| Answer automatically | One chime, a three second countdown with Decline on screen, then the call opens on its own. The call screen always shows: nobody is listened to without the kiosk saying who is there. |
| Do not disturb | Nothing rings. The caller sees Do not disturb. |

A kiosk in [Lockdown Mode](kiosk.md#lockdown-mode) answers as Do not disturb. A kiosk already in a call answers Busy. A call wakes a dark screen and draws over the screensaver, which picks up where it was once the call ends.

The **Ring sound** is a built-in telephone ring by default, or a file from the same sounds folder as the [notification sound](esphome.md#sounds), put there with the Add a sound row on the device or the remote admin. Either plays at the notification volume.

## In a call

| Talk mode | How it works |
| --- | --- |
| Push to talk | The default. One wide **Hold to talk** button and End. Held, this kiosk sends and the far kiosk hears you. Released, this kiosk listens. It never needs echo cancellation to work, so it is the safe choice on every device. |
| Hands free | The microphone stays open for the whole call with a Mute button. It leans on the same echo canceller the wake word capture runs on. Some devices do their echo cancellation without saying so, so the choice is always there. If the other kiosk hears itself back, use push to talk. |

Each kiosk picks its own talk mode. **Intercom volume** under Screen & Audio, beside the media and assistant volumes, is the share of the master volume the other kiosk's voice and announcements play at.

During a call the kiosk holds the screensaver, the dashboard rotation and the return to home timer the way a voice turn does, ducks the music the same way and pauses wake word detection, so neither voice triggers the assistant. End on either side closes both. The screen shows the call's length for ten seconds with Call again and Close.

Voice is raw 16 kHz audio over one WebSocket per call, about 256 kbit/s each way on the local network, and reaches the other kiosk in roughly a quarter of a second.

## Announce to all

**Announce to all** is one way: every Ready kiosk gets your voice at once, whatever its own talk mode, and nothing comes back. With push to talk you hold, speak and let go, and the line under the name says who hears you. With hands free the microphone stays open, with Mute, until Done. Kiosks on Do not disturb, with Accept announcements off or in a call are skipped and the screen names who is getting it.

On the receiving kiosks the screen says who is announcing. The ring plays once before the voice. **Reply** calls the sender back as a normal call, **Dismiss** closes it, and it also closes on its own a few seconds after the sender is done. Receivers do not hear each other: an announcement is not a group call.

**Accept announcements** under Answer, on by default, is the receiver's switch. Off, the kiosk refuses Announce to all. Spoken announcements from Home Assistant are a feature of their own under [ESPHome, Announcements](esphome.md#announcements), and need no other kiosk.

## The remote admin

The Intercom tab carries the same settings and the Kiosks card, without Call buttons. While a call is live a card at the top names the other kiosk with the length and **End call**. The remote admin never answers a call: a browser only opens the microphone on a secure origin, and the remote admin is plain http. The Overview gets a **Do not disturb** tile that flips the answer mode and back.

## Home Assistant

The [ESPHome](esphome.md) device carries an **Intercom enabled** switch, and with the intercom on four more entities.

| Entity | Type | Values |
| --- | --- | --- |
| **Intercom** | text sensor | `idle`, `calling`, `ringing`, `in_call`, `broadcasting`, `listening`, `missed`. Missed holds for a minute after a call nobody answered, so an automation can flash a light when the bedroom does not pick up. |
| **Intercom kiosk** | text sensor | The other kiosk's name during a call and the caller's during the minute of missed, else empty. |
| **Intercom do not disturb** | switch | The answer mode's Do not disturb as a switch. |
| **Intercom answer mode** | select | Ring, Answer automatically, Do not disturb. |

Two ESPHome actions put a call through from an automation or a dashboard button. `esphome.<node name>_intercom_call` rings another kiosk from this one, named by its `kiosk` argument, the kiosk's name as the Kiosks card lists it, any case, or its IP address. The call then runs the way one placed from the kiosk menu does: this kiosk's Talk mode, the other kiosk's Answer mode, and the Intercom sensor follows it. The action answers with the `id` and `kiosk` it rang through `response_variable`, and reports an error when the intercom is off here, no kiosk goes by that name, this kiosk is already in a call or the other kiosk refused with its reason (off, on another key, Do not disturb or busy). `esphome.<node name>_intercom_hangup` ends the call, cancels one still ringing or closes an announcement, and reports an error when there is none.

```yaml
- action: esphome.kitchen_tablet_intercom_call
  data:
    kiosk: Bedroom
```

Home Assistant cannot talk on a call: the kiosks hold the microphones. To speak on a kiosk from Home Assistant, use the [announce action](esphome.md#announcements) under ESPHome. On the [remote API](remote-api.md) the same two are `intercomCall {kiosk}` and `intercomHangup`.

## Fleet Management

The Intercom category syncs like the others. The key travels only as a credential, on by default in new profiles, so a fleet shares one key without anyone typing it. The intercom volume stays out of new profiles like the other volumes.

## Remote API

The intercom's routes sit in front of the admin login. Every one of them except the identity carries a bearer token signed with the intercom key for that one call, good for a minute and once.

| Endpoint | Method | Description |
| --- | --- | --- |
| `/api/intercom/identity` | GET | `{id, name, version, enabled, key, dnd, endpoint: {port, tls}}`. `key` is the first eight hex digits of the key's SHA-256, what the status words compare. Public, one probe a second per client. |
| `/api/intercom/call` | POST | `{call, kind: call or broadcast, from: {id, name, address, port, version, tls}}` answers `{status}`: `ringing`, `auto`, `listening`, `busy`, `dnd`, `off`, 409 with `status: tls` for incompatible encryption or 403 for another key. Plaintext requests are refused with 426 when encryption is required. |
| `/api/intercom/call/<id>` | POST | `{action}`: `answer`, `decline`, `missed` from the callee, `cancel` and `hangup` from the caller. |
| `/api/intercom/audio/<id>` | WebSocket | `?token=` as above. Binary frames are 80 ms of PCM16 mono 16 kHz from the sender's microphone. Text frames: `{"type": "talk", "on": true}` and `{"type": "end"}`. |

Both pages use the commands `intercomStatus`, `intercomKiosks`, `intercomCall {id}` or `{kiosk}` (a name or address), `intercomBroadcast`, `intercomHangup`, `intercomTalk {on}`, `intercomMute {on}`, `intercomOpen`, `intercomSetDnd {on}`, `intercomSetKey {key}` or `{regenerate: true}` and `intercomDismiss`. `intercomAnswer` and `intercomDecline` are refused over the remote API: only the kiosk screen answers. The WebSocket feed carries an `intercom` event with the whole status on every change.

## Notes

- One call at a time per kiosk. A second caller gets Busy. A broadcast reaching a kiosk in a call skips that kiosk.
- Without the microphone permission a kiosk still takes calls and hears the other side. The screen says it is listening only.
- A dashboard that holds the microphone itself, such as Voice Satellite streaming to Home Assistant for its wake word, is asked to let go for the call and gets it back when the call ends. Voice Satellite 2026.9.7 and later do that. An older one keeps it and the call is listen only, which the screen says. A page that takes the microphone during a call ends the call.
- Voice is not compressed in this version. That keeps every Android the app runs on, Android 7 included, on the same footing.

## Encryption

Turn on **Encrypt communications** under **Settings > Intercom > TLS** on each participating kiosk. This uses a separate HTTPS and WSS listener without changing Remote Administration. Kiosks discover its port automatically. Changing this setting ends active calls. See [TLS encryption](tls.md) for connection behavior, network requirements and certificate management.

Kiosks with different intercom encryption settings show **Encryption mismatch** and cannot call each other. Enable **Encrypt communications** on all participating kiosks for encrypted calls. **Announce to all** skips kiosks with incompatible encryption settings. The app never sends intercom credentials or audio over plaintext when encryption is enabled. Home Assistant announcements that play only on this kiosk keep their existing behavior.
