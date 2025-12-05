export class ConfettiController {
  // 内部回调，由组件绑定
  _triggerAction: () => void = () => {};

  /**
   * 触发一次礼花喷射
   */
  fire() {
    this._triggerAction();
  }
}