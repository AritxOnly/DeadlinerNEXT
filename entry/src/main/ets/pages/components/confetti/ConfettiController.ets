import { LocalValues } from "../../../common/local/LocalValues";

export class ConfettiController {
  // 内部回调，由组件绑定
  _triggerAction: () => void = () => {};

  private enabled(): boolean {
    return LocalValues.getInstance().getConfettiAfterFinished();
  }

  /**
   * 触发一次礼花喷射
   */
  fire() {
    if (this.enabled()) this._triggerAction();
  }
}