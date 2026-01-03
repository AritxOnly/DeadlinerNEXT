import { promptAction } from '@kit.ArkUI';

@Component
export struct AITextInput {
  @Link text: string;
  @State isAiLoading: boolean = false;

  // Canvas 相关设置
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;

  // 1. 幻彩渐变色配置
  private readonly gradientColors: string[] = ['#6AA9FF', '#FFC36A', '#FF6AE6'];

  // 2. 核心尺寸常量
  private readonly borderRadiusA: number = 26; // 外圆角 (Canvas 边框的外边缘)
  private readonly borderWidthA: number = 2;    // 边框粗细 (您修改后的值)

  private triggerAI() {
    if (!this.text.trim()) return;
    this.isAiLoading = true;
    setTimeout(() => {
      this.isAiLoading = false;
      promptAction.showToast({ message: 'AI 指令已发送' });
    }, 1000);
  }

  // 绘制边框的逻辑 (修改为贝塞尔曲线平滑圆角)
  private drawBorder() {
    const ctx = this.context;
    const w = this.canvasWidth;
    const h = this.canvasHeight;

    // 基础尺寸计算 (保持不变)
    const outerR = this.borderRadiusA;
    const lw = this.borderWidthA;
    // Canvas 描边是居中的，所以路径应该向内缩进 线宽的一半
    const inset = lw / 2;
    // 路径半径 = 外圆角 - 线宽的一半
    const pathR = outerR - inset;

    ctx.clearRect(0, 0, w, h);
    if (w === 0 || h === 0) return;

    // 设置渐变笔刷 (保持不变)
    let grad = ctx.createLinearGradient(0, 0, w, h);
    grad.addColorStop(0.0, this.gradientColors[0]);
    grad.addColorStop(0.5, this.gradientColors[1]);
    grad.addColorStop(1.0, this.gradientColors[2]);

    ctx.lineWidth = lw;
    ctx.strokeStyle = grad;
    // 建议加上圆润的线帽和连接点，让过渡更自然
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    // --- 开始贝塞尔曲线绘制 ---

    // 定义平滑系数 k。标准圆约 0.552，0.6 左右会更平滑 (Squircle)
    const k = 0.6;

    // 计算实际绘制路径的边界
    const drawX = inset;
    const drawY = inset;
    const drawW = w - inset * 2;
    const drawH = h - inset * 2;
    const r = pathR;

    ctx.beginPath();

    // 1. 上边 + 右上角
    ctx.moveTo(drawX + r, drawY);
    ctx.lineTo(drawX + drawW - r, drawY);
    // cp1x, cp1y, cp2x, cp2y, endx, endy
    ctx.bezierCurveTo(
      drawX + drawW - r * (1 - k), drawY,
      drawX + drawW, drawY + r * (1 - k),
      drawX + drawW, drawY + r
    );

    // 2. 右边 + 右下角
    ctx.lineTo(drawX + drawW, drawY + drawH - r);
    ctx.bezierCurveTo(
      drawX + drawW, drawY + drawH - r * (1 - k),
      drawX + drawW - r * (1 - k), drawY + drawH,
      drawX + drawW - r, drawY + drawH
    );

    // 3. 下边 + 左下角
    ctx.lineTo(drawX + r, drawY + drawH);
    ctx.bezierCurveTo(
      drawX + r * (1 - k), drawY + drawH,
      drawX, drawY + drawH - r * (1 - k),
      drawX, drawY + drawH - r
    );

    // 4. 左边 + 左上角
    ctx.lineTo(drawX, drawY + r);
    ctx.bezierCurveTo(
      drawX, drawY + r * (1 - k),
      drawX + r * (1 - k), drawY,
      drawX + r, drawY
    );

    ctx.closePath();
    ctx.stroke();
  }

  build() {
    // 关键修正 1: 改为 Center 对齐，或者默认对齐，避免 BottomEnd 导致的左上角偏移
    Stack({ alignContent: Alignment.Center }) {

      // Layer 1: Canvas 绘制的完美边框
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onAreaChange((oldValue, newValue) => {
          this.canvasWidth = newValue.width as number;
          this.canvasHeight = newValue.height as number;
          this.drawBorder();
        })

      // Layer 2: 布局容器 (Padding Hack)
      // 使用一个容器设置 padding，确保内部内容严格向内缩进 borderWidth 的距离
      Column() {
        // Layer 3: 实际内容 (半透明背景 + 输入框)
        Stack({ alignContent: Alignment.BottomEnd }) {
          // 背景层
          Column()
            .width('100%')
            .height('100%')
            // 关键修正 2: 内圆角 = 外圆角 - 边框宽度 (26 - 2 = 24)
            .borderRadius(this.borderRadiusA - this.borderWidthA)
            .backgroundColor($r('sys.color.search_container_focus_color'))

          // 输入框
          TextArea({ text: this.text, placeholder: '使用 AI 提取任务或习惯...' })
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Transparent)
            .borderRadius(this.borderRadiusA)
            .padding(16)
            //.fontColor(Color.White) // 如果需要白色文字请取消注释
            .onChange((val) => this.text = val)
          // TextArea 不处理 onSubmit

          // 按钮
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph(this.isAiLoading ? $r('sys.symbol.arrow_clockwise') : $r('sys.symbol.wand_and_stars'))
              .fontSize(20)
              .effectStrategy(SymbolEffectStrategy.SCALE)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .margin({ right: 10, bottom: 10 })
          .linearGradient({
            angle: 135,
            colors: [
              [this.gradientColors[0], 0.0],
              [this.gradientColors[1], 0.5],
              [this.gradientColors[2], 1.0]
            ]
          })
          .onClick(() => this.triggerAI())
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .padding(this.borderWidthA)

    }
    .width('100%')
    .height(140)
  }
}