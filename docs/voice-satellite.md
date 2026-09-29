# Voice Satellite

Kiosk Satellite is a Home Assistant Assist satellite on its own, through its ESPHome server. It hears the wake word, streams your command to Home Assistant, plays the answer and draws the overlay itself. Nothing needs to be installed in Home Assistant and no dashboard has to be loaded for voice to work.

## Why native

Voice used to run inside the dashboard's WebView, through the [Voice Satellite integration](https://github.com/jxlarrea/voice-satellite-card-integration). Its engine loaded with the page, streamed the microphone through it and drew the overlay in HTML. On the wall tablets and Echo Shows most kiosks run on, that WebView was the bottleneck.

| | Voice Satellite integration | Native |
| --- | --- | --- |
| Needs | The integration from HACS and a dashboard running it | ESPHome on in Kiosk Satellite |
| Overlay | HTML and CSS in the WebView | Drawn natively on the GPU |
| Waveform skin on an Echo Show 8 | About 9 fps | 56 fps, the panel's full rate |
| Ink Blobs on an Echo Show 8 | Does not render | Renders |
| Screensaver during a turn | Dismissed | Paused under the overlay |
| Under the overlay | Keeps rendering | Pauses: Weather Mood, slideshows, web pages, camera grids and the dashboard hold |
| In Home Assistant | A satellite of the integration | A standard Assist satellite, like a Voice PE |

## Set up

1. On **Settings > ESPHome**, turn on the ESPHome server.
2. On **Settings > Voice Satellite**, turn on **Enable Voice Satellite**.
3. In Home Assistant, open **Settings > Devices & services**. The kiosk shows up as discovered. Add it.
4. Pick the **Assistant** and the **Wake word** on the Voice Satellite pages. Both are Home Assistant's own selects on the kiosk's device.

Onboarding does all of this for a new kiosk: it turns on Voice Satellite and ESPHome and asks for the Assistant, wake word engine and wake word. They are set on the kiosk's selects as soon as Home Assistant adds it.

The **Status** row under the switch says where the satellite stands:

| Status | Meaning | Fix |
| --- | --- | --- |
| Listening | Waiting for the wake word. | |
| Busy | A voice turn or an announcement is running. | |
| Muted | **Mute microphone** is on. | Turn it off, here or with the VS Mute switch in Home Assistant. |
| Not listening | The wake word engine is not running. | Check the microphone permission and the app log. |
| Not added | Home Assistant has not added the kiosk yet or ESPHome is off. | Follow the row's hint. |

The microphone permission is required. **Keep listening in the background** also needs a permanent notification and **Display over other apps**. The **Required system permissions** group on the page asks for each.

> **Note:** Tool use lines and result panels (weather, stock, images, videos) come from Home Assistant's conversation log, which only an administrator's token can read. With a regular user's token, voice works and those parts do not show.

## Migrate from the Voice Satellite integration

A kiosk that ran the integration keeps running it on the dashboard until you migrate. Nothing migrates on its own.

1. On **Settings > Voice Satellite**, tap **Migrate** on the notice at the top. The remote admin's Overview offers the same.
2. Pick the integration's satellite this kiosk takes over.
3. The wizard checks Home Assistant, the kiosk's ESPHome device, the token and the microphone.
4. Choose the settings to bring over: Voice, Appearance, Conversation, Assistant and Timers.
5. Review the automations and scripts that still point at the old satellite. The wizard lists them and never changes them.
6. Tap **Switch now**. The kiosk takes over the Assistant, wake words and Finished speaking detection picks of the old satellite.

Not carried over: custom CSS, the browser's microphone processing and the conversation memory length. The old satellite stays in Home Assistant, unused. Once no other device uses the integration, uninstall it from HACS.

**Run from the dashboard again**, at the bottom of the page while the integration is still installed, switches back. The settings made here stay for next time.

When Home Assistant runs the integration, onboarding offers the same migration instead of the basic setup. Its selects are set once Home Assistant adds the kiosk.

## Settings

| Page | Setting | What it does |
| --- | --- | --- |
| Voice Satellite | Mute microphone | Stops listening for the wake word. |
| | Keep listening in the background | Hears the wake word while another app is in front and comes back on a detection. **Return to the previous app** goes back when the turn ends. |
| Assistant | Assistant 1 and 2, Finished speaking detection | Home Assistant's selects: the pipeline that answers each wake word and how long a pause ends a command. |
| | Talk right after the wake word | Skips the wake sound and keeps what you say right after the wake word. |
| | Follow-up delay, Chime before a follow-up | A pause and a chime before listening for the answer to a question. |
| | Play sounds on, Play as | Where answers and chimes play. See [below](#play-sounds-on-a-media-player). |
| Wake Word | Wake word engine | vsWakeWord (default), microWakeWord or openWakeWord. All models ship with the app. |
| | Wake word 1 and 2 | Home Assistant's selects. Wake word 2 is answered by Assistant 2. |
| | Wake word sensitivity, Wake word noise gate | How easily the wake word triggers. The noise gate skips inference while the room is quiet to save CPU. |
| | Stop word interruption | Say "stop" to cut off an answer, a timer alert or an announcement. It also closes a result panel. |
| | Custom Models | Your own wake word models. See [Custom wake word models](custom-wake-words.md). |
| Appearance | Skin | Kiosk Satellite, Default, Google Home, Home Assistant, Alexa, Siri, Retro Terminal, Waveform, Lens Flares or Ink Blobs. **Preview** shows it for five seconds. |
| | Theme, Background, Text size, Reactive activity bar | Light or dark, how much of the dashboard shows through, the text size and the bar that follows your voice and the answer. |
| Conversation | Show what you said, Show the answer, Show tool use, Hide sentiment tags | What the overlay shows. |
| | Keep the answer on screen, Keep results on screen, Announcement time | How long each stays. Results at 0 stay until dismissed. |
| Timers | Show timer pills, Show the timer name, Timer pill scale | Running timers float over the screen. Drag them anywhere. |
| | Mute timer alerts, Show the name on the alert, Speak when a timer ends | What a finished timer does. |
| Chimes | Play chimes, per-event sounds | The wake, done, error, timer and announcement sounds, built in or from the sounds folder. |

The **Wake Word Tester** and **Wake word diagnostics** are covered in [Microphone settings](microphone.md).

## Play sounds on a media player

**Play sounds on** picks where the answers, chimes, announcements and timer alerts play: this kiosk or any Home Assistant media player. **Play as** picks how:

| Play as | Behavior |
| --- | --- |
| Announcement | The speaker pauses its music for the sound and resumes it after. |
| Normal playback | Plays the sound as media, then starts the music again. For speakers that ignore announcements. |

The speaker fetches the answer from Home Assistant and the chimes from the kiosk, over HTTP on port **2329**.

> **Warning:** A speaker that cannot reach the kiosk on port 2329 plays the answers but stays silent for the chimes. Speakers on a separate VLAN need a firewall rule from the speaker to the kiosk on that port.

## Timers, announcements and conversations

These come from Home Assistant through the kiosk's satellite entity, as they do on any Assist satellite.

| Feature | How |
| --- | --- |
| Timers | Ask for one by voice. Pills show while it runs and an alert when it ends. Tap a pill to pause it, double tap to cancel. |
| Announcements | `assist_satellite.announce` on the kiosk's satellite. |
| Start a conversation | `assist_satellite.start_conversation`: the kiosk speaks, then listens for the reply. |
| Ask a question | `assist_satellite.ask_question`: the kiosk speaks, listens and hands the reply to Home Assistant, as a Voice PE does. |

Double tap the overlay to end a turn or close what lingers. With **Stop word interruption** on, "stop" does the same while an answer, alert, announcement or result panel is up.

## Home Assistant entities and actions

Home Assistant adds these to the kiosk's device on its own:

| Entity | Type |
| --- | --- |
| Assist satellite | assist_satellite |
| Assistant, Assistant 2 | select |
| Wake word, Wake word 2 | select |
| Finished speaking detection | select |

With **Expose kiosk entities** on under **Settings > ESPHome**, the kiosk adds its own:

| Entity | Type | Setting |
| --- | --- | --- |
| VS Mute | switch | Mute microphone |
| VS Chimes | switch | Play chimes |
| VS Stop word | switch | Stop word interruption |
| VS Noise gate | switch | Wake word noise gate |
| VS Mute timers | switch | Mute timer alerts |
| VS Wake word engine | select | Wake word engine |
| VS Wake word sensitivity | select | Wake word sensitivity |
| VS Answer linger | number | Keep the answer on screen |
| VS Announcement linger | number | Announcement time |

And four actions, named after the kiosk's [node name](esphome.md#node-name):

```yaml
# Listen as if the wake word fired. Slot 2 runs Assistant 2.
action: esphome.kitchen_tablet_vs_wake
data:
  slot: 1
```

```yaml
# End the turn on screen, as a double tap does.
action: esphome.kitchen_tablet_vs_cancel
```

`vs_cancel` stops listening or speaking, takes down a lingering answer and silences a ringing timer.

```yaml
# Ask the assistant and show the answer and results on the kiosk.
action: esphome.kitchen_tablet_vs_show
data:
  prompt: What is the weather this week?
  speak: false
  pipeline: 1
  duration: 0
```

`speak: true` also says the answer. `pipeline` picks Assistant 1 or 2. `duration` is how long the answer stays in seconds, 0 until dismissed.

```yaml
# Start a timer on the kiosk, kept in Home Assistant like a spoken one.
action: esphome.kitchen_tablet_vs_start_timer
data:
  name: Pasta
  hours: 0
  minutes: 10
  seconds: 0
```

The entities and actions appear only while Voice Satellite runs natively and is on.

## Android broadcasts

Apps on the device can start and end a turn with a broadcast, without going through Home Assistant. This suits a remote's button mapper, Tasker, Automate or ADB:

```sh
# Listen as if the wake word fired. Slot 2 runs Assistant 2.
adb shell am broadcast -a me.jxl.kiosk_satellite.action.VOICE_WAKE --ei slot 1

# End the turn on screen, as a double tap does.
adb shell am broadcast -a me.jxl.kiosk_satellite.action.VOICE_CANCEL
```

`slot` is optional and defaults to 1. The broadcasts work while Kiosk Satellite is running, even with another app in front, and do nothing while Voice Satellite is off.

## Fleets

A fleet leader passes its Voice Satellite settings to followers whose profile syncs **Voice Satellite**, along with its custom wake word models and its Assistant, Wake word and Finished speaking detection picks. Each follower sets those picks on its own device in Home Assistant. Mute and Play sounds on stay per kiosk by default. See [Fleet Management](fleet.md).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Status says Not added | Turn on ESPHome, then add the kiosk under **Settings > Devices & services** in Home Assistant. |
| The wake word never triggers | Check the level on the [Wake Word Tester](microphone.md) and the permissions group. Try another sensitivity. |
| No tool lines or result panels | The Home Assistant token is a regular user's. Use an administrator's. |
| Assistant and Wake word say Reload needed | Home Assistant added the satellite but not its selects, and the kiosk's token is not an administrator's, so it cannot reload the ESPHome entry itself. Reload the kiosk's entry under **Settings > Devices & services > ESPHome** or restart Home Assistant. |
| Chimes silent on a media player | The speaker cannot reach the kiosk on port 2329. |
| The overlay shows a notice | It names what failed: the microphone, the wake word, the connection, text to speech or the pipeline. Each turn's steps are in the app log. |
