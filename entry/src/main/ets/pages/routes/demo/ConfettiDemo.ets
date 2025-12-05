import { matrix4 } from '@kit.ArkUI';

@Component
export struct ConfettiPage {
  // 获取 Canvas 上下文
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 粒子数组
  private particles: ConfettiParticle[] = [];
  // 动画计时器
  private timer: number = -1;
  // 屏幕尺寸（用于边界检测）
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;

  build() {
    Stack() {
      // 业务层
      Column() {
        Text("Deadliner 2.0")
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })

        Button("任务完成 (喷射！)")
          .onClick(() => {
            this.fireConfetti();
          })
          .height(50)
          .backgroundColor('#007DFF')
      }
      .zIndex(1)

      // 礼花层 (全屏 Canvas)
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None) // 点击穿透
        .onReady(() => {
          // 获取画布实际尺寸
          this.canvasWidth = this.context.width;
          this.canvasHeight = this.context.height;
        })
    }
  }

  // --- 核心逻辑：发射礼花 ---
  fireConfetti() {
    // 每次发射 100 个粒子
    const count = 100;
    // 预设颜色 (Deadliner 风格)
    const colors = ['#26ccff', '#a25afd', '#ff5e7e', '#88ff5a', '#fcff42', '#ffa62d', '#ff3636'];

    for (let i = 0; i < count; i++) {
      // 1. 初始化粒子位置：底部中心
      const x = this.canvasWidth / 2;
      const y = this.canvasHeight;

      // 2. 随机速度与角度 (向上喷射)
      // 角度：270度是正上方。我们在 [235, 305] 之间随机，形成扇形
      const angle = (Math.random() * (305 - 235) + 235) * (Math.PI / 180);

      // 速度：随机力度
      const velocity = Math.random() * 30 + 40; // 这里的数值决定喷射高度

      // 3. 创建粒子对象
      this.particles.push(new ConfettiParticle(
        x,
        y,
        Math.cos(angle) * velocity, // vx
        Math.sin(angle) * velocity, // vy
        colors[Math.floor(Math.random() * colors.length)]
      ));
    }

    // 启动动画循环（如果还没启动）
    if (this.timer === -1) {
      this.startAnimation();
    }
  }

  // --- 动画循环 ---
  startAnimation() {
    // 约 60FPS
    this.timer = setInterval(() => {
      this.updateAndDraw();
    }, 16);
  }

  updateAndDraw() {
    // 1. 清空画布
    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);

    // 2. 如果没有粒子了，停止动画
    if (this.particles.length === 0) {
      clearInterval(this.timer);
      this.timer = -1;
      return;
    }

    // 3. 更新并绘制每一个粒子
    // 倒序遍历以便安全移除
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];

      // 更新物理状态
      p.update();

      // 绘制
      this.drawParticle(p);

      // 移除由于重力掉出屏幕 或 寿命结束 的粒子
      if (p.y > this.canvasHeight + 50 || p.opacity <= 0) {
        this.particles.splice(i, 1);
      }
    }
  }

  // --- 绘制单个粒子 (模拟 3D 旋转的核心) ---
  drawParticle(p: ConfettiParticle) {
    this.context.save();

    // 移动坐标系到粒子中心
    this.context.translate(p.x + p.wobbleX, p.y + p.wobbleY);

    // 旋转 (2D 平面旋转)
    this.context.rotate(p.rotation);

    // *** 关键魔法 *** // 通过改变 ScaleY 来模拟 3D 翻转效果
    // 当 scaleY 从 1 变到 0 再到 -1 时，看起来就像纸片翻了一面
    const scaleY = Math.cos(p.tilt);
    this.context.scale(1, scaleY);

    // 设置颜色和透明度
    this.context.globalAlpha = p.opacity;
    this.context.fillStyle = p.color;

    // 绘制矩形 (纸片)
    // 居中绘制，所以是从 -width/2, -height/2 开始
    this.context.fillRect(-5, -5, 10, 10); // 10x10 的纸片

    this.context.restore();
  }
}

/**
 * 粒子类：包含物理状态
 * 移植自 canvas-confetti 核心物理逻辑
 */
class ConfettiParticle {
  x: number;
  y: number;
  vx: number; // X轴速度
  vy: number; // Y轴速度
  color: string;

  // 物理属性
  gravity: number = 0.8;    // 重力
  drag: number = 0.94;      // 空气阻力 (越小阻力越大，速度衰减越快)

  // 动态属性 (模拟飘落感)
  rotation: number = 0;     // 2D 旋转角度
  rotationSpeed: number = 0;

  tilt: number = 0;         // 3D 倾斜角度 (模拟翻转)
  tiltAngle: number = 0;    // 倾斜增量

  wobble: number = 0;       // 摇摆相位
  wobbleSpeed: number = 0;  // 摇摆速度
  wobbleX: number = 0;      // 计算出的 X 偏移
  wobbleY: number = 0;      // 计算出的 Y 偏移

  opacity: number = 1;      // 透明度 (用于淡出)
  decay: number = 0.995;    // 消失衰减速度 (寿命)

  constructor(x: number, y: number, vx: number, vy: number, color: string) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.color = color;

    // 随机初始化物理参数，让每个粒子看起来不一样
    this.rotation = Math.random() * Math.PI * 2;
    this.rotationSpeed = (Math.random() - 0.5) * 0.2; // 随机旋转速度

    this.tilt = Math.random() * Math.PI;
    this.tiltAngle = Math.random() * 0.1 + 0.05; // 翻转速度

    this.wobble = Math.random() * Math.PI * 2;
    this.wobbleSpeed = Math.random() * 0.05 + 0.05;
  }

  update() {
    // 1. 应用位移
    this.x += this.vx;
    this.y += this.vy;

    // 2. 应用物理力
    this.vy += this.gravity; // 加重力
    this.vx *= this.drag;    // 加阻力 (X轴减速)
    this.vy *= this.drag;    // 加阻力 (Y轴终端速度限制)

    // 3. 计算飘动效果
    this.wobble += this.wobbleSpeed;
    this.wobbleX = Math.sin(this.wobble) * 2; // 左右轻微摆动
    this.wobbleY = Math.cos(this.wobble) * 2; // 上下轻微浮动

    // 4. 计算 3D 翻转
    this.tilt += this.tiltAngle;

    // 5. 更新旋转
    this.rotation += this.rotationSpeed;

    // 6. 寿命衰减
    // 当粒子开始下落一段距离后，或者速度很慢时，开始加速老化，防止堆积
    if (this.y > 300) {
      this.opacity *= this.decay;
    }
  }
}