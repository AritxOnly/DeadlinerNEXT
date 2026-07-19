import { promptAction, uiMaterial } from '@kit.ArkUI';
import { buildImmersiveMaterial, canUseSystemMaterial } from '../style/SystemMaterialCompat';

export interface ToastShowOptions {
  message: ResourceStr;
  duration?: number;
}

export class Toast {
  static show(options: ToastShowOptions): void {
    if (canUseSystemMaterial()) {
      promptAction.showToast({
        message: options.message,
        duration: options.duration,
        systemMaterial: buildImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THIN
        })
      });
      return;
    }

    promptAction.showToast({
      message: options.message,
      duration: options.duration
    });
  }
}
