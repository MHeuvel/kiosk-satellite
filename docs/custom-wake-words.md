# Custom Wake Word Models

[Voice Satellite](voice-satellite.md) ships with wake words for all three of its engines. You can add your own models on top of those. They live on the kiosk, show up in **Wake word 1** and **Wake word 2** next to the built in ones and follow the kiosk's fleet leader when there is one.

## Add a model

On the device, open **Settings > Voice Satellite > Wake Word** and tap **Add models** under **Custom Models**. In the remote admin, open the same page and press **Add**. Pick every file of one or more models at once. The kiosk checks each model before it keeps it: the manifest has to parse and the model has to load. A file that fails is refused with the reason, and nothing about it reaches the wake word engine.

What each engine needs:

| Engine | Files |
| --- | --- |
| microWakeWord | `name.json` and `name.tflite` |
| openWakeWord | `name.onnx` or `name.tflite` |
| vsWakeWord | `name.json` and `name.onnx` |

The kiosk tells the engines apart by the files. A `.json` with a `micro` section is a microWakeWord manifest, the format [microWakeWord trainers](https://github.com/kahrendt/microWakeWord) produce. A `.json` with the `vs-wake-word-ctc-v1` format is a vsWakeWord manifest. A model without a manifest is an openWakeWord classifier, in either the ONNX or the TFLite format the [openWakeWord](https://github.com/dscripka/openWakeWord) training notebook exports. openWakeWord models follow the **Sensitivity** setting, as the built in ones do.

The file name is the model's id. A custom model with the id of a built in one (say `hey_jarvis.onnx`) replaces it. Adding a model with the name of one you already have replaces that too.

## Pick it

Custom models join the choices of **Wake word 1** and **Wake word 2**, higher on the same page, for the engine the kiosk runs. The list under **Custom Models** marks the models of the other engines as not in use. Those two rows are also the kiosk's Wake word selects in Home Assistant, so automations can change them. After you add or delete a model, or switch engines, the kiosk refreshes that list right away.

A model is named after the wake word in its manifest, or after its file name when there is none (`hey_computer.onnx` becomes Hey Computer). No two wake words can share a name, so a custom model named like one already offered goes by its file name instead.

## Fleets

A fleet leader passes its custom models to every follower whose profile syncs **Voice Satellite**. Followers mirror the leader: they get the models it has, lose the ones it deleted and cannot add or delete models themselves. A follower that was offline catches up on its next sync. Files are compared by their checksum, so an unchanged set costs one small request per sync.

## Home Assistant's own folder

Home Assistant offers microWakeWord models from its `config/custom_wake_words` folder to every ESPHome satellite, and this kiosk takes them too. That folder only works for microWakeWord and needs a Home Assistant restart to pick up new models. Models added on the kiosk work for every engine and appear right away.
