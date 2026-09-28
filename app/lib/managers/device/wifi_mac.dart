import '../settings/definitions.dart' as defs;
import '../settings/settings_manager.dart';
import 'device_details.dart';

/// Where the reported hardware address came from.
enum WifiMacSource {
  /// The setting is off, or nothing usable was found: the generated
  /// identity stays in use.
  none,

  /// Read from the platform (and adopted for good).
  hardware,

  /// Typed in by hand (issue #300), because the platform would not reveal
  /// the address.
  manual,
}

typedef WifiMacIdentity = ({String? mac, WifiMacSource source});

/// The real-MAC identity (issue #252), with its source, or none while the
/// setting is off or nothing usable was found.
///
/// Hardware adoption is one-time: the first successful read is stored and
/// every later call returns the stored value without asking the platform
/// again. That keeps the identity stable across the ways the address could
/// later become unreadable (an OS upgrade past the API cutoffs, device
/// ownership removed) or change (a USB Wi-Fi adapter) — Home Assistant keys
/// the device entry on this value, and an identity that shifts under it
/// orphans the entry. Turning the setting off forgets the adoption (see
/// [forgetAdoptedWifiMac]), so turning it back on reads the hardware again.
///
/// The hand-typed address (issue #300) is the fallback, read live, and only
/// once the platform has come back empty: a working hardware read always
/// wins, so a typo can never override a good address, and someone who
/// typed the right address sees no change if the hardware read later
/// starts working. Read live rather than adopted because editing the field
/// is exactly how a wrong entry gets fixed.
///
/// Read by the ESPHome identity, so the kiosk lands on the same Home
/// Assistant device as the router integrations' entries.
Future<WifiMacIdentity> wifiMacIdentity(SettingsManager settings) async {
  if (!settings.get(defs.esphomeRealMac)) {
    return (mac: null, source: WifiMacSource.none);
  }
  final stored = settings.internal('esphome_adopted_mac');
  if (stored.isNotEmpty) return (mac: stored, source: WifiMacSource.hardware);
  final mac = await DeviceDetails.wifiMac();
  if (mac != null && mac.isNotEmpty) {
    await settings.setInternal('esphome_adopted_mac', mac);
    return (mac: mac, source: WifiMacSource.hardware);
  }
  // Re-normalized on read: the setting's normalizer already stores the
  // canonical form, but nothing downstream should trust a raw string for
  // an identity.
  final manual = defs.normalizeMacAddress(
    settings.get(defs.esphomeMacOverride),
  );
  if (manual != null) return (mac: manual, source: WifiMacSource.manual);
  return (mac: null, source: WifiMacSource.none);
}

/// Drops the stored hardware adoption (issue #736). Called when the
/// setting turns off: an address adopted once was otherwise kept for good,
/// so a ROM that first reported a placeholder (a Broadcom driver default)
/// and later the real address left the placeholder in place with no way
/// to replace it.
Future<void> forgetAdoptedWifiMac(SettingsManager settings) =>
    settings.setInternal('esphome_adopted_mac', '');

/// The reported address alone, or null for the generated identity.
Future<String?> adoptedWifiMac(SettingsManager settings) async =>
    (await wifiMacIdentity(settings)).mac;
