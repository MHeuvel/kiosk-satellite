# Raspberry Pi 4

This setup has been verified on a Raspberry Pi 4 Model B (2 GB) running KonstaKANG's LineageOS 23.2 (Android 16) with two USB microphones: a mono wireless headset microphone and a reSpeaker XVF3800 array. The WM8960 audio HAT section comes from a working setup on the same build. Other Android builds for the Pi, such as Emteria, may ship the same audio configuration, so check them for the two files covered below.

Out of the box no microphone works on this build. The built-in audio path hands apps generated audio and most USB microphones are refused. Two edits to `/vendor` fix both.

## Install

The build is a `userdebug` build with no Google accounts, so everything can be done over ADB, including root and device ownership.

Enable **Developer options** by tapping **Build number** seven times in the About screen. ADB over the network listens on port 5555. If that port refuses, turn on **Wireless debugging** and use the port it shows, which changes on every reboot. Tick **Always allow from this computer** on the authorization prompt: `adb root` restarts ADB and the prompt comes back otherwise.

## Setup in One Sitting

You can perform the complete setup from a computer on the same network. The grants below are the Android 16 subset of the standard [Permissions](permissions.md). Device ownership works on the Pi because the build has no accounts. The final block fixes the microphone and is explained further down this page.

```
adb connect <pi ip>:5555
adb install -r kiosk-satellite.apk
```

```
adb shell pm grant me.jxl.kiosk_satellite android.permission.RECORD_AUDIO
adb shell pm grant me.jxl.kiosk_satellite android.permission.CAMERA
adb shell pm grant me.jxl.kiosk_satellite android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant me.jxl.kiosk_satellite android.permission.ACCESS_FINE_LOCATION
adb shell pm grant me.jxl.kiosk_satellite android.permission.BLUETOOTH_SCAN
adb shell pm grant me.jxl.kiosk_satellite android.permission.BLUETOOTH_CONNECT
adb shell pm grant me.jxl.kiosk_satellite android.permission.POST_NOTIFICATIONS
adb shell pm grant me.jxl.kiosk_satellite android.permission.READ_MEDIA_IMAGES
adb shell pm grant me.jxl.kiosk_satellite android.permission.READ_MEDIA_VIDEO
adb shell appops set me.jxl.kiosk_satellite SYSTEM_ALERT_WINDOW allow
adb shell appops set me.jxl.kiosk_satellite WRITE_SETTINGS allow
adb shell appops set me.jxl.kiosk_satellite MANAGE_EXTERNAL_STORAGE allow
adb shell appops set me.jxl.kiosk_satellite GET_USAGE_STATS allow
adb shell dumpsys deviceidle whitelist +me.jxl.kiosk_satellite
adb shell dpm set-device-owner me.jxl.kiosk_satellite/.KioskAdminReceiver
```

```
adb root
adb shell mount -o remount,rw /vendor
# Built-in audio and HATs: stop Android from replacing the recording with generated audio
adb shell "sed -i 's/^ro.boot.audio.tinyalsa.simulate_input=true/#&/' /vendor/build.prop"
# USB microphones: let Android read each microphone's own formats
adb shell "sed -i '/tagName=\"USB Device In\"/,/<\/devicePort>/{/<profile/,/\/>/d}' /vendor/etc/usb_audio_policy_configuration.xml"
adb shell mount -o remount,ro /vendor
adb reboot
```

Optional: To enable the System UI guard behind Kiosk Mode's protections (as detailed in [Permissions](permissions.md)), run this:

```
adb shell settings put secure enabled_accessibility_services me.jxl.kiosk_satellite/me.jxl.kiosk_satellite.KioskAccessibilityService
adb shell settings put secure accessibility_enabled 1
```

Finally, finish the setup wizard on the Pi or from a browser at `http://<pi ip>:2324`.

## The Microphone

### Checking It

The **Microphone level** bar under Settings > Screen & Audio > Microphone settings shows the capture live, whether or not Voice Satellite is running. A bar that never moves while you talk means no audio reaches the app. The app log then says why, for example `capture delivered nothing for 3s from <microphone>` for the USB case below.

### Built-in Audio and HATs

The build's `vendor.prop` sets this line in `/vendor/build.prop`:

```
ro.boot.audio.tinyalsa.simulate_input=true
```

With it, Android's primary audio HAL hands apps generated audio instead of the sound card's recording. Any microphone on the built-in audio path, such as an I2S HAT, shows a constant level in a silent room and never triggers a wake word, whatever the app's settings. Tools that open the card directly, like `tinycap2`, record fine, which makes it look like an app problem. Comment the line out and reboot (the first command in the audio block above). USB microphones do not go through this path.

### USB Microphones

`/vendor/etc/usb_audio_policy_configuration.xml` gives the **USB Device In** port a fixed profile:

```xml
<devicePort tagName="USB Device In" type="AUDIO_DEVICE_IN_USB_DEVICE" role="source">
    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
        samplingRates="48000" channelMasks="AUDIO_CHANNEL_IN_STEREO"/>
</devicePort>
```

Android then opens every USB microphone at 48 kHz stereo. A microphone that cannot record exactly that refuses the open and the app receives silence. No **Capture format** setting helps, because every format ends at the same stereo open. The app log shows `capture delivered nothing for 3s from <microphone>` for each one. Stock Android leaves this port without a profile so it reads the microphone's own formats. The second command in the audio block above removes the profile. Only microphones that record 48 kHz stereo work without it.

| Microphone | Records | Stock profile | Profile removed |
| --- | --- | --- | --- |
| Antlion wireless microphone | Mono, 8 to 48 kHz | Silent | Works |
| reSpeaker XVF3800 4-Mic Array | 2 channels, 16 kHz only | Silent | Works, detected as soon as it is plugged in |

The XVF3800 hands over two processed channels, not its four raw microphones, so the **Microphone channel** row appears for it. See [Microphone Channel](microphone.md#microphone-channel) for which channel to pick.

To confirm a USB microphone hits this, check its channel count and the audio HAL's log:

```
adb shell cat /proc/asound/card*/stream0
adb logcat | grep -E "AlsaUtils|start failed"
```

A card without 48000 in its rates or with a channel count other than 2, together with `openProxyForExternalDevice: fail to prepare for device address=<N,0> error=-22`, is this issue. To apply the edit without a reboot, restart the audio services instead:

```
adb shell setprop ctl.restart vendor.audio-rpi
adb shell setprop ctl.restart audioserver
```

### WM8960 Audio HAT

A Waveshare WM8960 HAT works on this build with the `simulate_input` line commented out. This `/boot/config_user.txt` was reported working with the HAT and a Waveshare 10.1 inch DSI display:

```
dtparam=i2s=on
dtparam=audio=off

[gpio21=1]
dtoverlay=vc4-kms-v3d,noaudio

[gpio21=1]
dtoverlay=vc4-kms-dsi-waveshare-panel-v2,10_1_inch

[all]
dtoverlay=wm8960-soundcard
```

The codec boots with its capture path off, so its mixer has to be set at every boot. The same setup ran this from a boot script (`/data/adb/service.d/` needs Magisk or KernelSU). Control numbers depend on the kernel, so list yours with `tinymix2 -D 0` before copying them:

```
#!/system/bin/sh
sleep 15

# Playback
tinymix2 -D 0 set 9 255 255
tinymix2 -D 0 set 12 127 127
tinymix2 -D 0 set 14 5
tinymix2 -D 0 set 15 5
tinymix2 -D 0 set 51 1
tinymix2 -D 0 set 54 1

# Capture
tinymix2 -D 0 set 2 1 1
tinymix2 -D 0 set 0 32 32
tinymix2 -D 0 set 35 211 211

# Enable input 1
tinymix2 -D 0 set 45 1
tinymix2 -D 0 set 48 1

# Disable input 2
tinymix2 -D 0 set 43 0
tinymix2 -D 0 set 46 0

# Disable amplifier on LINPUT1/RINPUT1
tinymix2 -D 0 set 7 3
tinymix2 -D 0 set 8 3

# Enable input mixer
tinymix2 -D 0 set 49 1
tinymix2 -D 0 set 50 1
```

The Pi's I2S interface only carries stereo, so the HAT records at 48 kHz stereo. **Capture format** set to Automatic finds that on its own. Set it to 48 kHz stereo to skip the first attempt. See [Capture Format](microphone.md#capture-format).

For a cleaner signal, the kernel's WM8960 support can be patched. The device tree node only declares the AVDD and DVDD supplies, so the driver runs the DCVDD, DBVDD, SPKVDD1 and SPKVDD2 rails on dummy regulators (`dmesg` shows `supply DCVDD not found, using dummy regulator`). The driver's DAPM routes also lack the `MICB` bias dependency for the Left and Right Boost Mixers that Waveshare's own driver declares. Declaring the missing supplies and adding the two routes raised the silence to speech gap from about 1.5 dB to about 8.7 dB. This needs a kernel rebuild and is not required for the microphone to work.

## Updates

The Pi takes updates the same way as any device owner: the app downloads, installs and relaunches with no confirmation. See [Updates](updates.md).

Device ownership on most devices can only be removed with a factory reset. This build is debuggable, so it can also be removed over ADB:

```
adb shell dpm remove-active-admin me.jxl.kiosk_satellite/.KioskAdminReceiver
```

## What to Know Before Provisioning

| Quirk | Effect | What to do |
| --- | --- | --- |
| Built-in audio is simulated | Apps get generated audio instead of the sound card's recording. HAT microphones show a constant level and never detect a wake word. | Comment out `ro.boot.audio.tinyalsa.simulate_input=true` in `/vendor/build.prop` and reboot. |
| USB microphone input is pinned to 48 kHz stereo | USB microphones that cannot record 48 kHz stereo, mono ones and 16 kHz arrays like the reSpeaker XVF3800 alike, fail to open and the app receives silence. | Remove the profile from **USB Device In** in `/vendor/etc/usb_audio_policy_configuration.xml` and restart the audio services or reboot. |
| ROM updates restore `/vendor` | A reflash or ROM update brings back both audio lines. | Run the audio block again after every ROM update. |
| Wireless debugging changes its port on every reboot | A setup that ends in a reboot drops a Wireless debugging connection. | Use port 5555 or read the new port from the Wireless debugging screen. |
| `adb root` restarts ADB | The authorization prompt appears again unless the computer was always allowed. | Tick **Always allow from this computer** on the first prompt. |
| HDMI monitors have no backlight control | Brightness changes move Android's brightness value but an HDMI monitor keeps its own backlight. | Use the monitor's own controls or a screensaver that goes black. |
| No Play Store | Android System WebView only updates with the ROM. | Keep the ROM current. |
