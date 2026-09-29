# Wake word models

The models native Voice Satellite listens with, copied from the Voice Satellite
integration (`custom_components/voice_satellite/models`) so a kiosk needs
nothing in Home Assistant to serve them.

| Folder | Engine | Source |
| --- | --- | --- |
| `microwakeword/` | microWakeWord (`.tflite` with a `.json` manifest) | ESPHome's micro-wake-word-models, as Voice Satellite ships them |
| `openwakeword/` | openWakeWord (`.onnx`, plus the shared `melspectrogram` and `embedding_model`) | dscripka/openWakeWord, as Voice Satellite ships them |
| `vswakeword/` | vsWakeWord (`.onnx` with a `.json` manifest, quantized builds in `int8/`) | Voice Satellite, AGPL-3.0 per each manifest's attribution |

The stop classifiers are `microwakeword/stop`, `openwakeword/stop` and
`vswakeword/ok_stop`. Update these files together with Voice Satellite's.
