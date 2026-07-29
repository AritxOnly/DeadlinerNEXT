import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * HarmonyOS UI capability gates.
 *
 * Use the public SDK API level instead of parsing distribution version strings.
 * This keeps preview, emulator, phone, tablet and 2-in-1 behavior consistent.
 */
export class HarmonyOSCapabilities {
  static readonly IMMERSIVE_MATERIAL_API: number = 23;
  static readonly HARMONYOS_7_API: number = 26;

  static supportsImmersiveMaterial(): boolean {
    return deviceInfo.sdkApiVersion >= HarmonyOSCapabilities.IMMERSIVE_MATERIAL_API;
  }

  static isHarmonyOS7OrLater(): boolean {
    return deviceInfo.sdkApiVersion >= HarmonyOSCapabilities.HARMONYOS_7_API;
  }
}
