package me.jxl.kiosk_satellite.btproxy

/**
 * The voice assistant half of the ESPHome native API: what makes this device
 * an Assist satellite in Home Assistant, the way a Voice PE is one. Field
 * numbers are aioesphomeapi's api.proto (VOICE ASSISTANT section).
 *
 * The device side of the conversation is small. It asks Home Assistant to run
 * a pipeline (VoiceAssistantRequest), streams microphone audio up
 * (VoiceAssistantAudio, API audio), plays what Home Assistant sends back as a
 * URL, and says when it finished playing (VoiceAssistantAnnounceFinished,
 * which Home Assistant also expects after a spoken answer). Everything else
 * arrives from Home Assistant: pipeline events, timer events, announcements
 * and the wake word configuration.
 */
internal object VoiceFeature {
    const val VOICE_ASSISTANT = 1 shl 0
    const val SPEAKER = 1 shl 1
    const val API_AUDIO = 1 shl 2
    const val TIMERS = 1 shl 3
    const val ANNOUNCE = 1 shl 4
    const val START_CONVERSATION = 1 shl 5

    /**
     * What the kiosk honors. No SPEAKER: the kiosk plays the answer from the
     * URL Home Assistant sends, through its own player, so Home Assistant
     * never streams audio down. No media player either.
     */
    const val KIOSK = VOICE_ASSISTANT or API_AUDIO or TIMERS or ANNOUNCE or START_CONVERSATION
}

/** VoiceAssistantRequestFlag bits for [VoiceCodec.request]. */
internal object VoiceRequestFlag {
    const val USE_VAD = 1
    const val USE_WAKE_WORD = 2
}

/** A timer event from Home Assistant (VoiceAssistantTimerEventResponse). */
internal class VoiceTimerEvent(
    /** 0 started, 1 updated, 2 cancelled, 3 finished. */
    val type: Int,
    val id: String,
    val name: String,
    val totalSeconds: Int,
    val secondsLeft: Int,
    val isActive: Boolean,
)

/** An announcement to play (VoiceAssistantAnnounceRequest). */
internal class VoiceAnnouncement(
    val mediaId: String,
    val text: String,
    val preannounceMediaId: String,
    /** Listen for a reply after playing: start_conversation and ask_question. */
    val startConversation: Boolean,
)

/** A wake word Home Assistant offers from config/custom_wake_words. */
internal class ExternalWakeWord(
    val id: String,
    val wakeWord: String,
    val trainedLanguages: List<String>,
    val modelType: String,
    val modelSize: Int,
    val modelHash: String,
    val url: String,
)

/** What the device answers a configuration request with. */
internal class VoiceConfiguration(
    /** id to phrase ("ok_nabu" to "Okay Nabu"), in the order to offer them. */
    val available: List<Pair<String, String>>,
    val active: List<String>,
    val maxActive: Int,
)

/**
 * Where the voice messages from Home Assistant land. Called on session
 * reader threads; implementations hop to their own thread.
 */
internal interface VoiceBackend {
    /** A Home Assistant session subscribed to (or dropped) the voice assistant. */
    fun onSubscribed(subscribed: Boolean)

    /** The answer to a pipeline request: port 0 with API audio, error when refused. */
    fun onPipelineResponse(port: Int, error: Boolean)

    /** One pipeline event: [type] is VoiceAssistantEvent, [data] its name/value pairs. */
    fun onEvent(type: Int, data: Map<String, String>)

    fun onTimerEvent(event: VoiceTimerEvent)

    fun onAnnounce(announcement: VoiceAnnouncement)

    /**
     * Home Assistant asks which wake words exist. [reply] must be called
     * exactly once, from any thread; Home Assistant waits for it before it
     * builds the wake word selects.
     */
    fun onConfigurationRequest(
        external: List<ExternalWakeWord>,
        reply: (VoiceConfiguration) -> Unit,
    )

    /** The wake word selects in Home Assistant changed the active set. */
    fun onSetConfiguration(active: List<String>)
}

internal object VoiceCodec {
    /** SubscribeVoiceAssistantRequest: 1=subscribe, 2=flags. */
    fun parseSubscribe(payload: ByteArray): Pair<Boolean, Int> {
        var subscribe = false
        var flags = 0
        val r = ProtoReader(payload)
        while (r.next()) when (r.field) {
            1 -> subscribe = r.asBool()
            2 -> flags = r.asInt()
        }
        return subscribe to flags
    }

    /** VoiceAssistantResponse: 1=port, 2=error. */
    fun parseResponse(payload: ByteArray): Pair<Int, Boolean> {
        var port = 0
        var error = false
        val r = ProtoReader(payload)
        while (r.next()) when (r.field) {
            1 -> port = r.asInt()
            2 -> error = r.asBool()
        }
        return port to error
    }

    /** VoiceAssistantEventResponse: 1=event_type, 2=repeated data {1=name, 2=value}. */
    fun parseEvent(payload: ByteArray): Pair<Int, Map<String, String>> {
        var type = 0
        val data = LinkedHashMap<String, String>()
        val r = ProtoReader(payload)
        while (r.next()) when (r.field) {
            1 -> type = r.asInt()
            2 -> {
                var name = ""
                var value = ""
                val d = ProtoReader(r.asBytes())
                while (d.next()) when (d.field) {
                    1 -> name = d.asString()
                    2 -> value = d.asString()
                }
                data[name] = value
            }
        }
        return type to data
    }

    /**
     * VoiceAssistantTimerEventResponse: 1=event_type, 2=timer_id, 3=name,
     * 4=total_seconds, 5=seconds_left, 6=is_active.
     */
    fun parseTimerEvent(payload: ByteArray): VoiceTimerEvent {
        var type = 0
        var id = ""
        var name = ""
        var total = 0
        var left = 0
        var active = false
        val r = ProtoReader(payload)
        while (r.next()) when (r.field) {
            1 -> type = r.asInt()
            2 -> id = r.asString()
            3 -> name = r.asString()
            4 -> total = r.asInt()
            5 -> left = r.asInt()
            6 -> active = r.asBool()
        }
        return VoiceTimerEvent(type, id, name, total, left, active)
    }

    /**
     * VoiceAssistantAnnounceRequest: 1=media_id, 2=text,
     * 3=preannounce_media_id, 4=start_conversation.
     */
    fun parseAnnounce(payload: ByteArray): VoiceAnnouncement {
        var media = ""
        var text = ""
        var preannounce = ""
        var start = false
        val r = ProtoReader(payload)
        while (r.next()) when (r.field) {
            1 -> media = r.asString()
            2 -> text = r.asString()
            3 -> preannounce = r.asString()
            4 -> start = r.asBool()
        }
        return VoiceAnnouncement(media, text, preannounce, start)
    }

    /**
     * VoiceAssistantConfigurationRequest: 1=repeated external_wake_words
     * {1=id, 2=wake_word, 3=repeated trained_languages, 4=model_type,
     * 5=model_size, 6=model_hash, 7=url}.
     */
    fun parseConfigurationRequest(payload: ByteArray): List<ExternalWakeWord> {
        val out = ArrayList<ExternalWakeWord>()
        val r = ProtoReader(payload)
        while (r.next()) {
            if (r.field != 1) continue
            var id = ""
            var wakeWord = ""
            val languages = ArrayList<String>()
            var modelType = ""
            var size = 0
            var hash = ""
            var url = ""
            val w = ProtoReader(r.asBytes())
            while (w.next()) when (w.field) {
                1 -> id = w.asString()
                2 -> wakeWord = w.asString()
                3 -> languages.add(w.asString())
                4 -> modelType = w.asString()
                5 -> size = w.asInt()
                6 -> hash = w.asString()
                7 -> url = w.asString()
            }
            out.add(ExternalWakeWord(id, wakeWord, languages, modelType, size, hash, url))
        }
        return out
    }

    /** VoiceAssistantSetConfiguration: 1=repeated active_wake_words. */
    fun parseSetConfiguration(payload: ByteArray): List<String> {
        val out = ArrayList<String>()
        val r = ProtoReader(payload)
        while (r.next()) if (r.field == 1) out.add(r.asString())
        return out
    }

    /**
     * VoiceAssistantRequest: 1=start, 2=conversation_id, 3=flags,
     * 4=audio_settings, 5=wake_word_phrase. The phrase is what Home
     * Assistant matches against its wake word selects to pick pipeline 1 or
     * 2, and what it dedupes simultaneous wakes across satellites on.
     */
    fun request(
        start: Boolean,
        conversationId: String = "",
        flags: Int = 0,
        wakeWordPhrase: String = "",
    ): ByteArray = ProtoWriter().run {
        bool(1, start)
        if (conversationId.isNotEmpty()) string(2, conversationId)
        if (flags != 0) varint(3, flags)
        // audio_settings: volume_multiplier 1.0, no noise suppression or
        // gain: the kiosk's own capture already did both.
        message(4, ProtoWriter().run {
            float(3, 1.0f)
            toByteArray()
        })
        if (wakeWordPhrase.isNotEmpty()) string(5, wakeWordPhrase)
        toByteArray()
    }

    /** VoiceAssistantAudio: 1=data, 2=end. */
    fun audio(data: ByteArray, end: Boolean = false): ByteArray = ProtoWriter().run {
        if (data.isNotEmpty()) bytes(1, data)
        if (end) bool(2, true)
        toByteArray()
    }

    /** VoiceAssistantAnnounceFinished: 1=success. */
    fun announceFinished(success: Boolean): ByteArray = ProtoWriter().run {
        bool(1, success)
        toByteArray()
    }

    /**
     * VoiceAssistantConfigurationResponse: 1=repeated available_wake_words
     * {1=id, 2=wake_word, 3=repeated trained_languages},
     * 2=repeated active_wake_words, 3=max_active_wake_words.
     */
    fun configurationResponse(config: VoiceConfiguration): ByteArray = ProtoWriter().run {
        for ((id, phrase) in config.available) {
            message(1, ProtoWriter().run {
                string(1, id)
                string(2, phrase)
                toByteArray()
            })
        }
        for (id in config.active) string(2, id)
        varint(3, config.maxActive)
        toByteArray()
    }
}
