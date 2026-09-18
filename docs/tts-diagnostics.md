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
| Timeout with `loadComplete=true sinkEos=false` | Focus on the renderer or decoder failing to reach end of stream after loading. |
| Timeout with `sinkEos=true sinkEnded=false` | Focus on draining the audio processor and output path. |
| Local default replay fails but software replay succeeds | Decoder selection affects the failure. Compare decoder names before attributing it to hardware. |
| Both local replays succeed | Investigate streaming delivery and timing. This does not rule out an intermittent decoder or routing failure. |

The error includes a snapshot of the decoder and completion flags. Collect App
Logs promptly because the shared log buffer is bounded. These diagnostics do
not change the player timeout or automatically retry silent playback.
