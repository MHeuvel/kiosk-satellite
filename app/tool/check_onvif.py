#!/usr/bin/env python3
"""Check ONVIF onboarding with Home Assistant's client library.

Install onvif-zeep-async==4.2.1 in a virtual environment before running.
For --discover also install WSDiscovery==2.1.2.
Set KS_ONVIF_PASSWORD when authentication is enabled. No settings are changed.
"""

import argparse
import asyncio
import os
from pathlib import Path
from urllib.parse import urlsplit

import onvif
from onvif import ONVIFCamera
from zeep.exceptions import Fault


async def check(host, port, username, password):
    device = ONVIFCamera(
        host, port, username, password,
        str(Path(onvif.__file__).parent / 'wsdl'), no_cache=True,
    )
    try:
        await device.update_xaddrs()
        print('Service discovery: passed')
        management = await device.create_devicemgmt_service()
        identity = None
        try:
            interfaces = await management.GetNetworkInterfaces()
            interface = next((item for item in interfaces if item.Enabled), None)
            if interface:
                identity = interface.Info.HwAddress
        except Fault as fault:
            # Home Assistant allows serial identity for devices whose network
            # interface operation is explicitly not implemented.
            if 'not implemented' not in fault.message:
                raise
        info = await management.GetDeviceInformation()
        if not identity:
            identity = info.SerialNumber
        if not identity:
            raise RuntimeError('No MAC address or persistent serial for onboarding')
        print('Network interfaces and device identity: passed')
        media = await device.create_media_service()
        profiles = await media.GetProfiles()
        profiles = [item for item in profiles if item.VideoEncoderConfiguration
                    and item.VideoEncoderConfiguration.Encoding == 'H264']
        if not profiles:
            raise RuntimeError('No H.264 profile available')
        print('H.264 profile discovery: passed')
        await device.get_capabilities()
        await management.GetSystemDateAndTime()
        await media.GetServiceCapabilities()
        print('Device and media capabilities: passed')
        for profile in profiles:
            result = await media.GetStreamUri({
                'ProfileToken': profile.token,
                'StreamSetup': {'Stream': 'RTP-Unicast', 'Transport': {'Protocol': 'RTSP'}},
            })
            uri = urlsplit(result.Uri)
            if uri.scheme != 'rtsp' or not uri.hostname:
                raise RuntimeError('Invalid RTSP stream URI')
            print(f'Stream URI for {profile.Name}: passed')
        print('Home Assistant ONVIF setup requests: passed')
    finally:
        await device.close()


def discover(host, port):
    from wsdiscovery.discovery import ThreadedWSDiscovery
    from wsdiscovery.qname import QName
    from wsdiscovery.scope import Scope

    discovery = ThreadedWSDiscovery(ttl=4, relates_to=True)
    try:
        discovery.start()
        services = discovery.searchServices(
            types=[QName('http://www.onvif.org/ver10/network/wsdl', 'NetworkVideoTransmitter', 'dp0')],
            scopes=[Scope('onvif://www.onvif.org/Profile/Streaming')], timeout=10,
        )
        for service in services:
            for address in service.getXAddrs():
                uri = urlsplit(address)
                if uri.hostname == host and (uri.port or 80) == port:
                    print('Home Assistant network discovery: passed')
                    return
        raise RuntimeError('Camera did not answer the Home Assistant discovery probe')
    finally:
        discovery.stop()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True)
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--username', default='')
    parser.add_argument('--discover', action='store_true', help='Check multicast discovery before setup')
    args = parser.parse_args()
    if args.discover:
        discover(args.host, args.port)
    asyncio.run(asyncio.wait_for(
        check(args.host, args.port, args.username, os.environ.get('KS_ONVIF_PASSWORD', '')),
        timeout=30,
    ))


if __name__ == '__main__':
    main()
