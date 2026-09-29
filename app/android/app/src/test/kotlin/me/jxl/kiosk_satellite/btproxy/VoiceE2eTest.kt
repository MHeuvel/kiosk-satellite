package me.jxl.kiosk_satellite.btproxy

import java.io.File
import java.util.Base64
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.Assume.assumeTrue

/**
 * The voice assistant against the real client: aioesphomeapi, the library
 * Home Assistant's ESPHome satellite drives the device through, performs
 * every exchange the kiosk depends on over a live [ApiServer]. Feature flags,
 * the wake word configuration, a pipeline request and its answer, microphone
 * audio, pipeline and timer events, an announcement awaited to its finish and
 * the stop request.
 *
 * Runs when a Python interpreter with aioesphomeapi is available (see
 * [AioesphomeapiE2eTest]); skips otherwise.
 */
class VoiceE2eTest {
    private val script = """
        import asyncio, sys

        async def main():
            from aioesphomeapi import (
                APIClient, VoiceAssistantEventType, VoiceAssistantTimerEventType,
            )
            port = int(sys.argv[1]); psk = sys.argv[2]
            cli = APIClient("127.0.0.1", port, None, noise_psk=psk)
            await cli.connect(login=True)
            info = await cli.device_info()
            flags = info.voice_assistant_feature_flags_compat(cli.api_version)
            # voice assistant, API audio, timers, announce, start conversation
            assert flags == 0x3D, hex(flags)
            print("FLAGS_OK", flush=True)

            config = await cli.get_voice_assistant_configuration(5, [])
            assert [(w.id, w.wake_word) for w in config.available_wake_words] == [
                ("ok_nabu", "Okay Nabu"), ("hey_jarvis", "Hey Jarvis")], config
            assert list(config.active_wake_words) == ["ok_nabu"], config
            assert config.max_active_wake_words == 2, config
            print("CONFIG_OK", flush=True)
            await cli.set_voice_assistant_configuration(["ok_nabu", "hey_jarvis"])

            loop = asyncio.get_running_loop()
            started = loop.create_future()
            stopped = loop.create_future()
            heard = loop.create_future()
            audio = bytearray()

            async def handle_start(conversation_id, flags, audio_settings, wake_word_phrase):
                if not started.done():
                    started.set_result((conversation_id, flags, wake_word_phrase))
                return 0

            async def handle_stop(abort):
                if not stopped.done():
                    stopped.set_result(abort)

            async def handle_audio(data, data2=None):
                audio.extend(data)
                if len(audio) >= 3 * 2560 and not heard.done():
                    heard.set_result(bytes(audio))

            async def handle_announcement_finished(msg):
                pass

            cli.subscribe_voice_assistant(
                handle_start=handle_start,
                handle_stop=handle_stop,
                handle_audio=handle_audio,
                handle_announcement_finished=handle_announcement_finished,
            )
            conversation, request_flags, phrase = await asyncio.wait_for(started, 10)
            assert phrase == "Hey Jarvis", phrase
            assert conversation == "conv-1", conversation
            print("START_OK", flush=True)

            data = await asyncio.wait_for(heard, 10)
            assert data[:2560] == bytes([7]) * 2560, data[:4]
            print("AUDIO_OK", flush=True)

            cli.send_voice_assistant_event(
                VoiceAssistantEventType.VOICE_ASSISTANT_STT_END,
                {"text": "turn on the kitchen lights"})
            cli.send_voice_assistant_timer_event(
                VoiceAssistantTimerEventType.VOICE_ASSISTANT_TIMER_STARTED,
                "t1", "pasta", 600, 600, True)
            finished = await cli.send_voice_assistant_announcement_await_response(
                "http://ha.local/api/tts_proxy/abc.mp3", 10, text="Dinner is ready",
                start_conversation=True)
            assert finished.success, finished
            print("ANNOUNCE_OK", flush=True)

            cli.send_voice_assistant_event(
                VoiceAssistantEventType.VOICE_ASSISTANT_RUN_END, None)
            await asyncio.wait_for(stopped, 10)
            print("STOP_OK", flush=True)
            await cli.disconnect()

        asyncio.run(main())
    """.trimIndent()

    @Test
    fun realClientVoiceAssistantRoundTrip() {
        val python = System.getenv("KS_AIOESPHOME_PYTHON") ?: "python3"
        val available = runCatching {
            ProcessBuilder(python, "-c", "import aioesphomeapi")
                .redirectErrorStream(true).start()
                .let { it.waitFor(30, TimeUnit.SECONDS) && it.exitValue() == 0 }
        }.getOrDefault(false)
        assumeTrue("aioesphomeapi not available for $python; skipping", available)

        val psk = ByteArray(32) { (it * 7 + 3).toByte() }
        val identity = ProxyIdentity(
            name = "kiosk-satellite-test",
            friendlyName = "Test Kiosk",
            macAddress = "02:11:22:33:44:55",
            esphomeVersion = "2026.8.0",
            model = "Test",
            manufacturer = "KS",
            projectName = "kiosk_satellite.bluetooth_proxy",
            projectVersion = "1.0",
        )
        val scanner = object : ScannerBackend {
            override fun onScanDemand(mode: ScannerMode) {}
            override fun onScanRelease() {}
        }
        val events = CopyOnWriteArrayList<Pair<Int, Map<String, String>>>()
        val timers = CopyOnWriteArrayList<VoiceTimerEvent>()
        val announcements = CopyOnWriteArrayList<VoiceAnnouncement>()
        val activeSets = CopyOnWriteArrayList<List<String>>()
        val subscriptions = CopyOnWriteArrayList<Boolean>()
        lateinit var server: ApiServer
        val voice = object : VoiceBackend {
            override fun onSubscribed(subscribed: Boolean) {
                subscriptions.add(subscribed)
                // What the kiosk does on a wake word: ask for a pipeline,
                // naming the wake word so Home Assistant picks pipeline 2.
                if (subscribed) {
                    server.sendVoiceRequest(
                        true, "conv-1", VoiceRequestFlag.USE_VAD, "Hey Jarvis")
                }
            }

            override fun onPipelineResponse(port: Int, error: Boolean) {
                // API audio: stream the command up.
                repeat(3) { server.sendVoiceAudio(ByteArray(2560) { 7 }) }
            }

            override fun onEvent(type: Int, data: Map<String, String>) {
                events.add(type to data)
                if (type == 2) server.sendVoiceRequest(false)
            }

            override fun onTimerEvent(event: VoiceTimerEvent) {
                timers.add(event)
            }

            override fun onAnnounce(announcement: VoiceAnnouncement) {
                announcements.add(announcement)
                server.sendAnnounceFinished(true)
            }

            override fun onConfigurationRequest(
                external: List<ExternalWakeWord>,
                reply: (VoiceConfiguration) -> Unit,
            ) = reply(VoiceConfiguration(
                listOf("ok_nabu" to "Okay Nabu", "hey_jarvis" to "Hey Jarvis"),
                listOf("ok_nabu"),
                2,
            ))

            override fun onSetConfiguration(active: List<String>) {
                activeSets.add(active)
            }
        }
        server = ApiServer(identity, "02:AA:BB:CC:DD:EE", 0, psk, scanner,
            log = {}, bluetoothProxy = false, voice = voice)
        server.start()
        try {
            val scriptFile = File.createTempFile("voice_e2e", ".py").apply {
                writeText(script)
                deleteOnExit()
            }
            val process = ProcessBuilder(
                python, scriptFile.absolutePath,
                server.boundPort.toString(),
                Base64.getEncoder().encodeToString(psk),
            ).redirectErrorStream(true).start()
            val finished = process.waitFor(60, TimeUnit.SECONDS)
            val output = process.inputStream.bufferedReader().readText()
            if (!finished) process.destroyForcibly()
            assertEquals(0, if (finished) process.exitValue() else -1,
                "aioesphomeapi voice round trip failed:\n$output")

            assertEquals(listOf(listOf("ok_nabu", "hey_jarvis")), activeSets.toList())
            val sttEnd = events.first { it.first == 4 }
            assertEquals("turn on the kitchen lights", sttEnd.second["text"])
            assertEquals("pasta", timers.single().name)
            assertEquals(600, timers.single().totalSeconds)
            val announce = announcements.single()
            assertEquals("Dinner is ready", announce.text)
            assertTrue(announce.startConversation)
            assertEquals(true, subscriptions.first())
        } finally {
            server.stop()
        }
    }
}
