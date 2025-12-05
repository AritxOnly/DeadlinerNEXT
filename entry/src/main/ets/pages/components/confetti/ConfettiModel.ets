export class ConfettiParticle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  color: string;

  // 物理参数
  gravity: number = 0.8;    // 重力
  drag: number = 0.93;      // 空气阻力 (0.93 阻力感比较强，比较飘)
  decay: number = 0.98;     // 消失速度

  // 动态参数
  rotation: number = 0;
  rotationSpeed: number = 0;
  tilt: number = 0;
  tiltAngle: number = 0;
  wobble: number = 0;
  wobbleSpeed: number = 0;
  wobbleX: number = 0;
  wobbleY: number = 0;
  opacity: number = 1;

  constructor(x: number, y: number, vx: number, vy: number, color: string) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.color = color;

    this.rotation = Math.random() * Math.PI * 2;
    this.rotationSpeed = (Math.random() - 0.5) * 0.2;
    this.tilt = Math.random() * Math.PI;
    this.tiltAngle = Math.random() * 0.1 + 0.05;
    this.wobble = Math.random() * Math.PI * 2;
    this.wobbleSpeed = Math.random() * 0.05 + 0.05;
  }

  update() {
    this.x += this.vx;
    this.y += this.vy;

    this.vy += this.gravity;
    this.vx *= this.drag;
    this.vy *= this.drag;

    this.wobble += this.wobbleSpeed;
    this.wobbleX = Math.sin(this.wobble) * 2;
    this.wobbleY = Math.cos(this.wobble) * 2;

    this.tilt += this.tiltAngle;
    this.rotation += this.rotationSpeed;

    // 下落一定距离后开始淡出
    if (this.y > 100 && this.vy > 0) {
      this.opacity *= this.decay;
    }
  }
}