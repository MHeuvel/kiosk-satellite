# TTS playback diagnostics

Use these diagnostics when a response reaches native playback but stays silent
or never finishes. App Logs now record the HTTP transfer, selected decoder,
audio position advancement and end-of-stream handling under the `sound` tag.
Each line includes the sound ID so concurrent sounds can be separated.
Voice Satellite debug logging is not required for these native diagnostics.

## Capture one response

The `soundDiagnostics` command can retain the next streamed sound in memory.
Capture is off by default, limited to one response of at most 8 MiB and cleared
when the app process exits. Arming it again replaces the previous capture.
It records the bytes from the original request, without fetching the URL again.
It does not record microphone audio.

Send the following JSON bodies to
`POST /api/commands/soundDiagnostics` using the regular
[remote API authentication](remote-api.md#authentication).

| Action | JSON body | Result |
| --- | --- | --- |
| Arm | `{"action":"arm"}` | Capture the next sound requested with `stream: true` |
| Inspect | `{"action":"status"}` | Return the sound ID, received bytes, HTTP status, completion flags and playback error |
| Export | `{"action":"export"}` | Return the completed clip as `data.base64` with its metadata |
| Replay with default decoders | `{"action":"replay","decoder":"default"}` | Play the captured bytes from a temporary file through ExoPlayer |
| Replay with software decoders | `{"action":"replay","decoder":"software"}` | Run the same path with only software decoders eligible |
| Clear | `{"action":"clear"}` | Disarm capture and discard retained audio |

1. Arm capture just before the voice command that fails. Local chimes do not
   consume the capture. Other streamed announcements can consume it.
2. Wait for the response to finish or time out. Inspect the capture and save
   App Logs for that sound ID. If the response worked, arm again for another attempt.
3. After a failure, export the clip if needed. The response contains audio from
   that interaction. For example, decode a saved export with
   `jq -r '.data.base64' capture.json | base64 --decode > capture.mp3` for MP3 audio.
4. Replay with the default decoder. Note whether it is audible and whether it ends.
   The result supplies the new playback ID. Save App Logs for that ID.
5. Wait for that replay to end before repeating with the software decoder.
   `stopSound` with the replay ID can stop an active comparison.
6. Clear the capture when finished.

Replay is Android-only. It requires a complete, nonempty HTTP 200 response and
the original playback to have ended. Partial or oversized captures cannot be
exported or replayed. Only one diagnostic replay can run at a time. Replays use
the current speaker and assistant volume. An optional `volume` parameter scales
the replay from 0 to 1. Bluetooth call routing is not supported for this test.
Temporary replay files are deleted when playback ends. Clearing the capture
does not stop a replay already in progress.

Both replay modes bypass the local short-clip player so the comparison uses
the same ExoPlayer pipeline as streamed TTS. A default replay does not retry on
software after a decoder error. A software replay fails if no software decoder
is available. The decoder name in App Logs identifies what actually ran.

## Read the results

| Evidence | What it tells us |
| --- | --- |
| HTTP headers and first bytes without `HTTP upstream complete` | The relay has not finished consuming the response. Check the source stream and transport before blaming playback completion. |
| `HTTP upstream complete` and `HTTP relay closed` | The response finished passing through the Dart relay. |
| `player load complete` | ExoPlayer completed a source load. |
| `player isPlaying=true` | ExoPlayer entered its playing state. This alone does not establish audible output. |
| `audio position advancing` | The audio sink reported advancing playback position. This still does not prove sound reached the selected speaker. |
| `renderer requested sink end of stream` | The renderer reached its end-of-stream path and asked the sink to drain. |
| `audio sink ended` | The sink reported completion after that request. |
| `discarded incomplete final PCM frame bytes=N` | The decoded stream ended with a partial PCM frame. The frame guard discarded those trailing bytes so AudioTrack can finish. Complete frames are preserved, including frames split across decoder buffers. |
| Timeout with `loadComplete=true sinkEos=false` | Focus on the renderer or decoder failing to reach end of stream after loading. |
| Timeout with `sinkEos=true sinkEnded=false` | Focus on draining the audio processor and output path. |
| Local default replay fails but software replay succeeds | Decoder selection affects the failure. Compare decoder names before attributing it to hardware. |
| Both local replays succeed | Investigate streaming delivery and timing. This does not rule out an intermittent decoder or routing failure. |

The error includes a snapshot of the decoder and completion flags. Collect App
Logs promptly because the shared log buffer is bounded. These diagnostics do
not change the player timeout or automatically retry silent playback.

## Acknowledgement sound investigation (#600)

The failed capture attached to [#600](https://github.com/jxlarrea/kiosk-satellite/issues/600)
is byte-for-byte identical to Home Assistant 2026.9.2's
[`acknowledge.mp3`](https://github.com/home-assistant/core/blob/2026.9.2/homeassistant/components/assist_pipeline/acknowledge.mp3):
50,991 bytes with SHA-256
`88762f0f72e04bab3b545d4852d0badd017bb4a8799cc4f3ef0cb4fc8e7ecdae`.
Home Assistant can substitute that sound for speech after an action on targets
in the satellite's area. Hearing a short acknowledgement instead of spoken text
is separate from playback failing to end.

The reporter's logs show completed HTTP delivery and decoder end of stream,
followed by `sinkEos=true sinkEnded=false`. The native decoder was
`OMX.MTK.AUDIO.DECODER.MP3`. The available Echo Show test device runs Android 11
and exposes Google's MP3 decoder instead, so it cannot reproduce that decoder's
behavior. The unchanged acknowledgement finishes on that device.

With Media3 1.10.1, an injected two-byte tail after stereo 16-bit PCM
reproduces a drain hang:
AudioTrack accepts only complete four-byte frames, leaving the final two bytes
unwritten while the sink continues waiting to finish. The unguarded test reaches
`ERROR_CODE_TIMEOUT` with `Player stuck playing without ending for 60000 ms`
at a playback position of 61,600 ms. With the frame guard, the same test discards
those two bytes and reaches the ended state at 1,593 ms. Both original samples
also finish with the guard enabled and no discarded bytes. This
establishes a possible cause of the reported symptoms, not confirmation of the
reporter's decoder output. Check for the incomplete-frame diagnostic and normal
completion when testing the acknowledgement on the affected device.
