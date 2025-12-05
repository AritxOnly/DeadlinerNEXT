import { ConfettiController } from "./ConfettiController";
import { ConfettiParticle } from "./ConfettiModel";

/**
 * ConfettiView.ets
 * 这是一个基于 Canvas 实现的高性能、物理模拟的礼花组件。
 * 移植自 canvas-confetti 核心算法 (Air drag, Tilt, Wobble).
 */
@Component
export struct ConfettiView {
  @ObjectLink controller: ConfettiController; // 使用 ObjectLink 确保响应

  // 可选：自定义配置
  colors: string[] = ['#26ccff', '#a25afd', '#ff5e7e', '#88ff5a', '#fcff42', '#ffa62d', '#ff3636'];
  particleCount: number = 100;

  // 内部状态
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private particles: ConfettiParticle[] = [];
  private timer: number = -1;
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;

  aboutToAppear() {
    // 绑定控制器触发事件
    this.controller._triggerAction = () => {
      this.fireConfetti();
    };
  }

  aboutToDisappear() {
    // 清理定时器，防止内存泄漏
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None) // 关键：点击穿透
      .onReady(() => {
        this.canvasWidth = this.context.width;
        this.canvasHeight = this.context.height;
      })
  }

  /**
   * 发射逻辑
   */
  private fireConfetti() {
    // 如果 Canvas 还没准备好（例如极快进入页面就触发），则忽略
    if (this.canvasWidth === 0) return;

    for (let i = 0; i < this.particleCount; i++) {
      // 1. 发射点：底部中心
      const x = this.canvasWidth / 2;
      const y = this.canvasHeight;

      // 2. 角度：270度(垂直向上) 左右散开 [235, 305]
      const angle = (Math.random() * (305 - 235) + 235) * (Math.PI / 180);

      // 3. 力度：随机初速度
      const velocity = Math.random() * 35 + 45; // 45-80 的力度

      this.particles.push(new ConfettiParticle(
        x,
        y,
        Math.cos(angle) * velocity,
        Math.sin(angle) * velocity,
        this.colors[Math.floor(Math.random() * this.colors.length)]
      ));
    }

    // 启动动画循环
    if (this.timer === -1) {
      this.startAnimation();
    }
  }

  /**
   * 动画帧循环 (约60FPS)
   */
  private startAnimation() {
    this.timer = setInterval(() => {
      // 1. 清空画布
      this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);

      // 2. 检查是否停止
      if (this.particles.length === 0) {
        clearInterval(this.timer);
        this.timer = -1;
        return;
      }

      // 3. 更新与绘制
      for (let i = this.particles.length - 1; i >= 0; i--) {
        const p = this.particles[i];
        p.update(); // 物理计算

        // 绘制逻辑
        this.drawParticle(p);

        // 边界检查与生命周期检查
        if (p.y > this.canvasHeight + 50 || p.opacity <= 0) {
          this.particles.splice(i, 1);
        }
      }
    }, 16);
  }

  /**
   * 绘制单个粒子 (含 3D 翻转效果)
   */
  private drawParticle(p: ConfettiParticle) {
    this.context.save();
    this.context.translate(p.x + p.wobbleX, p.y + p.wobbleY);
    this.context.rotate(p.rotation);

    // 模拟 3D 翻转 (Scale Y)
    const scaleY = Math.cos(p.tilt);
    this.context.scale(1, scaleY);

    this.context.globalAlpha = p.opacity;
    this.context.fillStyle = p.color;

    // 绘制 10x10 的纸片
    this.context.fillRect(-5, -5, 10, 10);
    this.context.restore();
  }
}