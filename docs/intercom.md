# Intercom

Kiosks on the same network can talk to each other. Pick a kiosk from the kiosk menu and it rings there, or announce to every kiosk at once. Each kiosk decides how it answers: ring, answer on its own after a chime, or not at all. Voice travels straight between the two kiosks over the remote admin port. No server and no Home Assistant sit in the path, and Home Assistant sees the state through ESPHome.

Configure it under **Settings, Intercom** on the kiosk, or the **Intercom** tab in the remote admin. Every kiosk on the intercom needs **Remote management** and **Find other kiosks** on (under Settings, Device, Remote Administration). Kiosks find and reach each other through the remote admin, the same way [Fleet Management](fleet.md) does.

## Setup

1. Turn on **Enable intercom**. The kiosk makes an **Intercom key** the first time.
2. Give every other kiosk the same key. In a fleet the leader syncs it as a credential and nothing needs typing. Outside a fleet, copy the key from the box and paste it on the other kiosk through **Change key**.
3. The **Kiosks** card lists every kiosk discovered on the network with a status word. A kiosk reads **Ready** once its intercom is on with the same key.

| Status | Meaning |
| --- | --- |
| Ready | The intercom is on there with the same key. |
| Intercom off | The kiosk is on the network but its intercom is off, or it runs a version without one. |
| Different key | Its intercom is on with another key. Paste this kiosk's key there, or the other way around. |
| Do not disturb | It is on the intercom but refuses calls right now. |
| Offline | It was heard before and has gone quiet for over a minute and a half. |

**Change key** opens a dialog to paste a key from another kiosk or **Regenerate** a fresh one. A new key cuts this kiosk off from the others until they get it too.

## Placing a call

The **Intercom** entry in the kiosk menu opens a sheet: **Announce to all** first, then the kiosks that are Ready. A tap calls. Kiosks with the intercom off, another key or offline are not listed. The settings page is where they show up with a reason.

The card names the kiosk, says Calling and offers Cancel. Nothing plays until the other side answers. Busy, Do not disturb, no answer and a different key end the call with one line on the card.

The **Open the intercom** [gesture action](gestures.md) opens the same sheet. **Show in the kiosk menu** on the Intercom page takes the entry out of the menu altogether, and the restricted menu has its own Intercom switch under **Kiosk Mode, Allowed Actions**, so a wall panel can keep the entry off while a gesture still opens the sheet.

## A call coming in

| Answer mode | What happens |
| --- | --- |
| Ring | The ring sound plays every four seconds with Decline and Answer on screen for as long as **Ring for** says. Then the call counts as missed and a toast offers Call back. |
| Answer automatically | One chime, a three second countdown with Decline on screen, then the call opens on its own. The card is always on screen: nobody is listened to without the kiosk saying who is there. |
| Do not disturb | Nothing rings. The caller sees Do not disturb. |

A kiosk in [Lockdown Mode](kiosk.md#lockdown-mode) answers as Do not disturb. A kiosk already in a call answers Busy. A call wakes a dark screen and draws over the screensaver, which picks up where it was once the call ends.

The **Ring sound** is a built-in telephone ring by default, or a file from the same sounds folder as the [notification sound](esphome.md#sounds). Either plays at the notification volume.

## In a call

| Talk mode | How it works |
| --- | --- |
| Push to talk | The default. One wide **Hold to talk** button and End. Held, this kiosk sends and the far kiosk hears you. Released, this kiosk listens. It never needs echo cancellation to work, so it is the safe choice on every device. |
| Hands free | The microphone stays open for the whole call with a Mute button. It relies on the platform echo canceller the wake word capture already runs on. A device without one is held to push to talk. |

Each kiosk picks its own talk mode. **Intercom volume** scales the other kiosk's voice on this one.

During a call the kiosk holds the screensaver, the dashboard rotation and the return to home timer the way a voice turn does, ducks the music the same way and pauses wake word detection, so neither voice triggers the assistant. End on either side closes both. The card shows the call's length for ten seconds with Call again and Close.

Voice is raw 16 kHz audio over one WebSocket per call, about 256 kbit/s each way on the local network, and reaches the other kiosk in roughly a quarter of a second.

## Announce to all

**Announce to all** is one way: every Ready kiosk gets your voice at once, whatever its own talk mode, and nothing comes back. With push to talk you hold, speak and let go. With hands free the microphone stays open, with Mute, until Done. Kiosks on Do not disturb, with Accept announcements off or in a call are skipped and the card names who is getting it.

On the receiving kiosks the card says who is announcing. The ring plays once before the voice. **Reply** calls the sender back as a normal call, **Dismiss** closes the card, which also closes on its own a few seconds after the sender is done. Receivers do not hear each other: an announcement is not a group call.

**Accept announcements** under Answer, on by default, is the receiver's switch. Off, the kiosk refuses every announcement, from another kiosk and from Home Assistant alike, whatever the sender asks.

## Announcements from Home Assistant

With the intercom on, the [ESPHome](esphome.md) device offers `esphome.<node name>_intercom_announce`. It speaks a message through Home Assistant's text to speech, or plays an audio URL, on one kiosk or on all of them, through the same one way path as Announce to all. The kiosk that receives the action does the work: it asks Home Assistant for the audio, decodes it and plays it to the targets, itself included when the target is all or its own address.

| Argument | Meaning |
| --- | --- |
| `target` | A kiosk's IP address (the one under its Kiosks row), or `all` for every kiosk on the intercom, this one included. This kiosk's own address announces on it alone. |
| `message` | What to say. Spoken with the **Text to speech engine** under Answer, or the first TTS entity Home Assistant has when that is empty. |
| `url` | An audio file to play instead of a message, MP3, WAV, OGG or AAC. Leave it empty to use the message. |
| `override` | `true` plays the announcement on kiosks set to Do not disturb. Accept announcements off still refuses it, and so does Lockdown Mode. |

```yaml
- action: esphome.kitchen_tablet_intercom_announce
  data:
    target: all
    message: Dinner is ready
    url: ""
    override: true
- action: esphome.kitchen_tablet_intercom_announce
  data:
    target: 192.168.1.71
    message: The laundry is done
    url: ""
    override: false
```

The action answers, through `response_variable`, with each target and what it did: `listening`, `busy`, `dnd`, `refused` (Accept announcements off), `off` or `unreachable`. A message needs the kiosk's Home Assistant connection, since the kiosk asks Home Assistant to speak it.

## The remote admin

The Intercom tab carries the same settings and the Kiosks card, without Call buttons. While a call is live a card at the top names the other kiosk with the length and **End call**. The remote admin never answers a call: a browser only opens the microphone on a secure origin, and the remote admin is plain http. The Overview gets a **Do not disturb** tile that flips the answer mode and back.

## Home Assistant

With the intercom on, the [ESPHome](esphome.md) device gains four entities.

| Entity | Type | Values |
| --- | --- | --- |
| **Intercom** | text sensor | `idle`, `calling`, `ringing`, `in_call`, `broadcasting`, `listening`, `missed`. Missed holds for a minute after a call nobody answered, so an automation can flash a light when the bedroom does not pick up. |
| **Intercom kiosk** | text sensor | The other kiosk's name during a call and the caller's during the minute of missed, else empty. |
| **Intercom do not disturb** | switch | The answer mode's Do not disturb as a switch. |
| **Intercom answer mode** | select | Ring, Answer automatically, Do not disturb. |

Home Assistant cannot start a call: the kiosks hold the microphones. Announcements from Home Assistant reach a kiosk through the [DLNA renderer](dlna.md) and Voice Satellite as before.

## Fleet Management

The Intercom category syncs like the others. The key travels only as a credential, on by default in new profiles, so a fleet shares one key without anyone typing it. The intercom volume stays out of new profiles like the other volumes.

## Remote API

The intercom's routes sit in front of the admin login. Every one of them except the identity carries a bearer token signed with the intercom key for that one call, good for a minute and once.

| Endpoint | Method | Description |
| --- | --- | --- |
| `/api/intercom/identity` | GET | `{id, name, version, enabled, key, dnd}`. `key` is the first eight hex digits of the key's SHA-256, what the status words compare. Public, one probe a second per client. |
| `/api/intercom/call` | POST | `{call, kind: call or broadcast, from: {id, name, address, port, version}}` answers `{status}`: `ringing`, `auto`, `listening`, `busy`, `dnd`, `off`, or 403 for another key. |
| `/api/intercom/call/<id>` | POST | `{action}`: `answer`, `decline`, `missed` from the callee, `cancel` and `hangup` from the caller. |
| `/api/intercom/audio/<id>` | WebSocket | `?token=` as above. Binary frames are 80 ms of PCM16 mono 16 kHz from the sender's microphone. Text frames: `{"type": "talk", "on": true}` and `{"type": "end"}`. |

Both pages use the commands `intercomStatus`, `intercomKiosks`, `intercomCall {id}`, `intercomBroadcast`, `intercomHangup`, `intercomTalk {on}`, `intercomMute {on}`, `intercomOpen`, `intercomSetDnd {on}`, `intercomSetKey {key}` or `{regenerate: true}` and `intercomDismiss`. `intercomAnswer` and `intercomDecline` are refused over the remote API: only the kiosk screen answers. The WebSocket feed carries an `intercom` event with the whole status on every change.

## Notes

- One call at a time per kiosk. A second caller gets Busy. A broadcast reaching a kiosk in a call skips that kiosk.
- Without the microphone permission a kiosk still takes calls and hears the other side. The card says it is listening only.
- A page that takes the microphone itself, such as a browser voice turn, ends the call.
- Voice is not compressed in this version. That keeps every Android the app runs on, Android 7 included, on the same footing.
