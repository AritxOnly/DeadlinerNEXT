import { EntryOhos, Highlight, MarkerView, MPPointF, Paint, Style, Utils } from '@ohos/mpchart';

export class CustomMarkerView extends MarkerView {
  private tvContent: Paint = new Paint();
  private bgPaint: Paint = new Paint();

  constructor() {
    super();
    // 初始化文字画笔
    this.tvContent.setTextSize(12); // 文字大小
    this.tvContent.setColor(Color.White); // 文字颜色
    this.tvContent.setTextAlign('center');

    // 初始化背景画笔
    this.bgPaint.setColor(Color.Gray);
    this.bgPaint.setStyle(Style.FILL);
    // 如果需要圆角，需要在 draw 里自己画 roundedRect，Paint 本身只管样式
  }

  // 核心绘制方法
  draw(c: CanvasRenderingContext2D, posX: number, posY: number, e: EntryOhos, highlight: Highlight) {
    const value = e.getY().toString(); // 获取显示的数值
    const textWidth: number = Utils.calcTextWidth(this.tvContent, value);
    const padding = 10;
    const w = textWidth + padding * 2;
    const h = 25;

    // 为了防止标签画出屏幕边界，可以对 posX 做一些判断（这里简化处理）
    // 在横向图中，posY 是横向的位置，posX 是纵向的位置，容易搞混，
    // 但 MarkerView 传入的 posX/posY 已经是转换后的屏幕坐标。

    // 绘制背景气泡 (简单的矩形)
    // 偏移一下，让气泡在手指上方
    const offsetY = -h - 10;

    // 这里使用 Canvas 的原生 API 绘制圆角矩形
    c.beginPath();
    c.fillStyle = '#90000000'; // 半透明黑背景
    // roundRect(x, y, w, h, radius)
    // 注意：部分环境可能需要 polyfill，如果报错改成 rect
    if (c.roundRect) {
      c.roundRect(posX - w / 2, posY + offsetY, w, h, 4);
    } else {
      c.rect(posX - w / 2, posY + offsetY, w, h);
    }
    c.fill();
    c.closePath();

    // 绘制文字
    // 注意 Canvas 的 textBaseline
    c.fillStyle = '#FFFFFF';
    c.font = '12vp sans-serif';
    c.textAlign = 'center';
    c.textBaseline = 'middle';
    c.fillText(value, posX, posY + offsetY + h / 2);
  }

  // 偏移量，决定 Marker 相对于点击点的偏移
  getOffset(): MPPointF {
    return new MPPointF(0, 0); // 在 draw 里手动算过了，这里归零
  }
}