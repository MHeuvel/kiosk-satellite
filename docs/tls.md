# TLS encryption

Kiosk Satellite can encrypt Remote Administration, camera streaming and intercom independently. Each feature has its own switch. All three use the certificate managed under **Settings > Device > TLS**, immediately below **Remote Administration**. The same controls are available in the remote admin.

| Feature | Setting | Location |
| --- | --- | --- |
| Remote admin, REST API and admin WebSocket | Use HTTPS | Device > Remote Administration |
| RTSP and ONVIF camera video and audio | Encrypt stream | Camera > RTSP & ONVIF Streaming |
| Intercom calls and announcements | Encrypt communications | Intercom > TLS |

Encryption is off by default. These switches stay on each device and are excluded from fleet synchronization.

## Remote Administration

**Use HTTPS** changes the existing admin port from HTTP to HTTPS. The API follows the same protocol and the admin WebSocket changes from WS to WSS.

Changing the switch opens a confirmation dialog before anything changes. The dialog explains that the current remote connection will close and shows the new address in a copyable box. **Cancel** keeps the current protocol. **Confirm** applies the change. In the browser, the page then reloads at the new address. The same confirmation appears when switching back to HTTP.

A browser may ask you to accept the self-signed certificate. You may also need to sign in again because HTTP and HTTPS use separate browser storage. Existing fleet connections discover the admin protocol automatically.

## Camera streaming

**Encrypt stream** in the **TLS** group works with both streaming protocols. In RTSP mode it changes the stream to `rtsps://DEVICE_IP:8554/camera`, using your configured streaming port. Commands, video and audio travel through TLS. Use a viewer that supports RTSPS with interleaved TCP media.

VLC 3.0.x, including 3.0.23, cannot open `rtsps://` URLs. VideoLAN lists RTSP over TLS under its [VLC 4.0 development changes](https://github.com/videolan/vlc/blob/master/NEWS). For encrypted playback, use an FFmpeg build with TLS support:

```sh
ffplay -rtsp_transport tcp "rtsps://DEVICE_IP:8554/camera"
```

To use VLC 3.0.x, turn off **Encrypt stream** and open the `rtsp://` address instead. That connection is unencrypted. Changing only the URL scheme while encryption is enabled will not work.

In ONVIF mode the service URL becomes `https://DEVICE_IP:8080/onvif/device_service` and the media profile returns `rtsps://DEVICE_IP:8080/camera`. Both use the configured ONVIF port. Discovery advertises the HTTPS address. WS-Discovery itself still uses unencrypted UDP multicast on port 3702 and carries device metadata, not video or audio.

The viewer must support HTTPS ONVIF services and RTSPS media and accept the device certificate. Clients that only support HTTP or plain RTSP cannot connect while encryption is enabled. RTSP tunneling over HTTP or HTTPS is not supported. Camera authentication remains a separate setting. Changing Remote Administration encryption does not change camera streaming.

## Intercom

**Encrypt communications** controls a separate listener for incoming intercom signaling and audio. It uses HTTPS and WSS when enabled and HTTP and WS when disabled. Enable it on each participating kiosk to encrypt signaling in both directions and the audio connection. It does not change the Remote Administration protocol.

Kiosks with different intercom encryption settings show **Encryption mismatch** and cannot call each other. Enable **Encrypt communications** on all participating kiosks for encrypted calls. **Announce to all** skips kiosks with incompatible encryption settings. The app never sends intercom credentials or audio over plaintext when encryption is enabled. Home Assistant announcements that play only on this kiosk keep their existing behavior.

The operating system assigns the listener a free TCP port. Other kiosks learn that port and its protocol from the public intercom identity endpoint on the admin port. Kiosks must be able to reach each other's intercom listener as well as the admin port. No extra port setting or manual address entry is needed on an unrestricted local network.

Remote Administration and **Find other kiosks** remain prerequisites for discovery. Older kiosks without a separate intercom listener continue to use their admin port. An encrypted kiosk refuses intercom calls and audio on a plaintext admin connection. Changing intercom encryption or its certificate closes active encrypted calls so they can reconnect using the new endpoint.

Fleet and intercom clients accept kiosk self-signed certificates automatically. There is no kiosk trust list or certificate pairing. TLS encrypts the traffic without verifying the peer certificate. Fleet tokens and the shared intercom key still control access. Home Assistant connections and external downloads keep their existing certificate checks.

## Certificate management

**Device > TLS** contains only certificate information and actions:

- **Copy public certificate** on the device or **Download public certificate** in the remote admin exports the public certificate without its private key.
- **Renew certificate** keeps the generated private key and updates the certificate dates and current device addresses.
- **Import certificate** accepts a PEM certificate chain and matching unencrypted EC or RSA private key. Remote import requires HTTPS. Invalid material leaves the current certificate in place.
- **Replace certificate** creates a new private key and self-signed certificate. Browsers may ask you to accept the new certificate. Other kiosks reconnect without updating a trust list.

Generated certificates last one year. While any encryption switch is enabled, the app checks every six hours and renews generated certificates within 30 days of expiration. Imported certificates must be renewed by their issuer and imported again. Renew manually after changing the hostname or when you need a new IP address included in the certificate.

Private keys are encrypted with an Android Keystore key and stored outside Android backup. They are not returned by the API, exported with configuration or copied through Fleet Management. Cloning a configuration keeps each device's own identity.

Certificate changes restart encrypted listeners. If certificate loading fails, the affected encrypted listener stays stopped rather than accepting plaintext. Local device settings remain available to renew or replace the certificate.
