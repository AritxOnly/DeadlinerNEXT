import { SettingsValue } from "../data/settings/SettingsValue"
import { vibrator } from "@kit.SensorServiceKit"

export class VibrationUtils {
  private static assureVibrationEnable(): boolean {
    console.debug(`[Vibration] ${SettingsValue.getInstance().getVibration()}`)
    return SettingsValue.getInstance().getVibration()
  }

  public static vibrateShort() {
    if (VibrationUtils.assureVibrationEnable()) {
      vibrator.startVibration({
        type: "time",
        duration: 50
      }, {
        usage: "communication"
      })
    }
  }

  public static vibrateMedium() {
    if (VibrationUtils.assureVibrationEnable()) {
      vibrator.startVibration({
        type: "time",
        duration: 100
      }, {
        usage: "communication"
      })
    }
  }
}