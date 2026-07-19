import { promptAction } from '@kit.ArkUI';
import { canUseSystemMaterial } from '../style/SystemMaterialCompat';

type AlertDialogCompatOptions =
  AlertDialogParamWithConfirm |
  AlertDialogParamWithButtons |
  AlertDialogParamWithOptions;

export class DialogCompat {
  static withAlertBlurStyle(
    options: AlertDialogCompatOptions,
    fallbackBlurStyle: BlurStyle = BlurStyle.Regular
  ): AlertDialogCompatOptions {
    if (!canUseSystemMaterial()) {
      options.backgroundBlurStyle = fallbackBlurStyle;
    }
    return options;
  }

  static withPromptBlurStyle(
    options: promptAction.ShowDialogOptions,
    fallbackBlurStyle: BlurStyle = BlurStyle.Regular
  ): promptAction.ShowDialogOptions {
    if (!canUseSystemMaterial()) {
      options.backgroundBlurStyle = fallbackBlurStyle;
    }
    return options;
  }

  static withTimePickerBlurStyle(
    options: TimePickerDialogOptions,
    fallbackBlurStyle: BlurStyle = BlurStyle.Regular
  ): TimePickerDialogOptions {
    if (!canUseSystemMaterial()) {
      options.backgroundBlurStyle = fallbackBlurStyle;
    }
    return options;
  }

  static withDatePickerBlurStyle(
    options: DatePickerDialogOptions,
    fallbackBlurStyle: BlurStyle = BlurStyle.Regular
  ): DatePickerDialogOptions {
    if (!canUseSystemMaterial()) {
      options.backgroundBlurStyle = fallbackBlurStyle;
    }
    return options;
  }
}
