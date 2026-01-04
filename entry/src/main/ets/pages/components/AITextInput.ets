import { promptAction } from '@kit.ArkUI';

@Component
export struct AITextInput {
  @Link text: string;
  @State isAiLoading: boolean = false;
  @State placeholder: string = '问 AI...';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;

  private readonly gradientColors: string[] = ['#6AA9FF', '#FFC36A', '#FF6AE6'];

  // 核心尺寸
  private readonly borderRadiusA: number = 26; // 外圆角
  private readonly borderWidthA: number = 2;    // 边框粗细

  onAITriggered: () => Promise<void> = async () => {}

  private async triggerAI() {
    if (!this.text.trim()) return;
    this.isAiLoading = true;

    await this.onAITriggered();

    this.isAiLoading = false;
  }

  // 绘制边框逻辑 (贝塞尔平滑圆角)
  private drawBorder() {
    const ctx = this.context;
    const w = this.canvasWidth;
    const h = this.canvasHeight;

    // 基础尺寸
    const outerR = this.borderRadiusA;
    const lw = this.borderWidthA;
    const inset = lw / 2;
    const pathR = outerR - inset;

    ctx.clearRect(0, 0, w, h);
    if (w === 0 || h === 0) return;

    let grad = ctx.createLinearGradient(0, 0, w, h);
    grad.addColorStop(0.0, this.gradientColors[0]);
    grad.addColorStop(0.5, this.gradientColors[1]);
    grad.addColorStop(1.0, this.gradientColors[2]);

    ctx.lineWidth = lw;
    ctx.strokeStyle = grad;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    const k = 0.6;
    const drawX = inset;
    const drawY = inset;
    const drawW = w - inset * 2;
    const drawH = h - inset * 2;
    const r = pathR;

    ctx.beginPath();
    // 1. 上边 + 右上角
    ctx.moveTo(drawX + r, drawY);
    ctx.lineTo(drawX + drawW - r, drawY);
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
    Stack({ alignContent: Alignment.Center }) {

      // Layer 1: 内容层 (背景 + 输入框)
      // 【关键修改点 A】：调整顺序，把内容层放在 Canvas 之前（即 Z 轴的下层）
      // 这样 Canvas 的边框就会“压”在背景之上，遮住接缝
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          // 背景层
          Column()
            .width('100%')
            .height('100%')
            // 【关键修改点 B】：内圆角调整
            // 为了配合下面的 padding 1，半径改为 26 - 1 = 25
            .borderRadius(this.borderRadiusA - 1)
            .backgroundColor($r('sys.color.search_container_focus_color'))

          // 输入框
          TextArea({ text: this.text, placeholder: this.placeholder })
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Transparent)
            .borderRadius(this.borderRadiusA - 1) // 同步圆角
            .padding(16)
            //.fontColor(Color.White)
            .onChange((val) => this.text = val)

          // 按钮
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph(this.isAiLoading ? $r('sys.symbol.arrow_clockwise') : $r('sys.symbol.wand_and_stars'))
              .fontSize(20)
              .effectStrategy(SymbolEffectStrategy.SCALE)
              .fontColor([$r('app.color.font_primary')])
          }
          .width(32)
          .height(32)
          .margin({ right: 10, bottom: 10 })
          .backgroundColor($r('sys.color.normal_button_container_focus_color'))
          .onClick(() => this.triggerAI())
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      // 【关键修改点 C】：Padding 改为 1vp (即边框宽度的一半)
      // 边框总宽 2vp，中心在 1vp 处。
      // padding(1) 让背景延伸到了边框的中心线位置。
      // 边框覆盖了背景的边缘 1vp，彻底消除了缝隙。
      .padding(1)

      // Layer 2: Canvas 边框
      // 放在最后面，保证它渲染在最上层
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onAreaChange((oldValue, newValue) => {
          this.canvasWidth = newValue.width as number;
          this.canvasHeight = newValue.height as number;
          this.drawBorder();
        })
    }
    .width('100%')
    .height(140)
  }
}