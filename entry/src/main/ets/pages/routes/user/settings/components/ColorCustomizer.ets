import { ColorGenerator, ColorSwatch } from '../../../../../utils/ColorGenerator';
import { ThemeManager } from '../../../../../common/theme/ThemeManager';

@Component
export struct ColorCustomizer {
  // 核心状态
  @State hue: number = 210;
  // 自动根据Hue生成的一组色板（包含不同饱和度、明度）
  @State generatedSwatches: ColorSwatch[] = [];

  // 选中的索引
  @State selectedBrandIndex: number = 4; // 默认选中中间某个比较好看的颜色
  @State selectedAccentIndex: number = 4;
  @State isAccentFollowBrand: boolean = true;

  // 初始化
  aboutToAppear() {
    this.updateSwatches();
  }

  // 重新生成颜色数据
  private updateSwatches() {
    this.generatedSwatches = ColorGenerator.generateGradientSwatches(this.hue);
  }

  // 获取当前选中的颜色值（防崩溃）
  private getSafeColor(index: number): string {
    return (this.generatedSwatches[index]) ? this.generatedSwatches[index].color : '#808080';
  }

  build() {
    Column({ space: 24 }) {

      // === 1. 色相控制 (Hue) ===
      Column({ space: 12 }) {
        Text("1. 调整基调 (Hue)")
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')

        // 滑动条组件
        HueSlider({
          hue: this.hue,
          onHueChange: (val) => {
            this.hue = val;
            this.updateSwatches(); // 滑动实时更新色板
          }
        })
      }
      .width('100%')

      // === 2. 品牌色选择 (3列网格) ===
      Column({ space: 12 }) {
        Text("2. 选择品牌色 (Brand)")
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')

        // 提取为独立组件，彻底解决状态不更新问题
        ColorGridSelector({
          swatches: this.generatedSwatches,
          selectedIndex: $selectedBrandIndex,
          onSelect: (index) => {
            this.selectedBrandIndex = index;
            // 如果开启了联动，Accent自动跟随
            if (this.isAccentFollowBrand) {
              this.selectedAccentIndex = index;
            }
          }
        })
      }

      // === 3. 强调色选择 (Accent) ===
      Column({ space: 12 }) {
        Row() {
          Text("3. 选择强调色 (Accent)")
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_secondary'))

          Blank()

          Row({ space: 8 }) {
            Text("跟随品牌色")
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))

            Toggle({ type: ToggleType.Switch, isOn: this.isAccentFollowBrand })
              .onChange((isOn) => {
                this.isAccentFollowBrand = isOn;
                if (isOn) this.selectedAccentIndex = this.selectedBrandIndex;
              })
              .height(20)
          }
        }
        .width('100%')

        // 只有当不跟随的时候才显示选择器
        if (!this.isAccentFollowBrand) {
          ColorGridSelector({
            swatches: this.generatedSwatches,
            selectedIndex: $selectedAccentIndex,
            onSelect: (index) => {
              this.selectedAccentIndex = index;
            }
          })
            .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }
      }

      // === 4. 预览与应用 ===
      Column({ space: 16 }) {
        // 简单的预览卡片
        ThemePreviewCard({
          brandColor: this.getSafeColor(this.selectedBrandIndex),
          accentColor: this.getSafeColor(this.selectedAccentIndex)
        })

        Button("应用主题")
          .width('100%')
          .height(48)
          .backgroundColor(this.getSafeColor(this.selectedBrandIndex))
          .onClick(() => {
            const brand = this.getSafeColor(this.selectedBrandIndex);
            const accent = this.getSafeColor(this.selectedAccentIndex);
            // 这里调用你的 ThemeManager
            // ThemeManager.applyCustomColors(brand, accent);
          })
      }
      .margin({ top: 12, bottom: 30 })

    }
    .padding(20)
    .height('100%')
  }
}

// =========================================
// 子组件：颜色网格选择器 (关键修复：组件化)
// =========================================
@Component
struct ColorGridSelector {
  @Prop swatches: ColorSwatch[];
  @Link selectedIndex: number;
  onSelect?: (index: number) => void;

  build() {
    Grid() {
      ForEach(this.swatches, (item: ColorSwatch, index: number) => {
        GridItem() {
          // 单个颜色块
          Stack({ alignContent: Alignment.Center }) {
            // 颜色圆球
            Circle({ width: 56, height: 56 })
              .fill(item.color)

            // 选中状态：外圈边框 + 对勾
            if (this.selectedIndex === index) {
              // 选中外圈
              Circle({ width: 64, height: 64 })
                .fill(Color.Transparent)
                .stroke(item.color)
                .strokeWidth(3)
                .opacity(0.5)

              // 对勾图标
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(24)
                .fontColor([item.isLight ? Color.Black : Color.White])
            }
          }
          .width('100%')
          .height(72)
          .animation({ duration: 200, curve: Curve.FastOutSlowIn }) // 添加动画
          .scale({ x: this.selectedIndex === index ? 1.05 : 1, y: this.selectedIndex === index ? 1.05 : 1 })
          .onClick(() => {
            // 显式更新 Link 状态
            this.selectedIndex = index;
            if (this.onSelect) this.onSelect(index);
          })
        }
      })
    }
    .columnsTemplate('1fr 1fr 1fr') // 固定三列
    .rowsGap(12)
    .columnsGap(12)
    .height(240) // 3行大概的高度
    .width('100%')
  }
}

// =========================================
// 子组件：Hue 滑动条 (UI优化版)
// =========================================
@Component
struct HueSlider {
  @Link hue: number;
  onHueChange?: (val: number) => void;

  @State trackWidth: number = 0;
  private thumbSize: number = 28;

  private startHue: number = 0;

  getThumbOffset(): number {
    if (this.trackWidth <= this.thumbSize) return 0;
    return (this.hue / 360) * (this.trackWidth - this.thumbSize);
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // 1. 彩虹轨道
      Row()
        .width('100%')
        .height(14)
        .borderRadius(7)
        .linearGradient({
          angle: 90,
          colors: [
            ['#FF0000', 0.0], ['#FFFF00', 0.17], ['#00FF00', 0.33],
            ['#00FFFF', 0.50], ['#0000FF', 0.67], ['#FF00FF', 0.83], ['#FF0000', 1.0]
          ]
        })

        .onAreaChange((_o, n) => {
          this.trackWidth = Number(n.width);
        })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.updateHueByX(e.touches[0].x);
          }
        })

      // 2. 镂空滑块
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: this.thumbSize, height: this.thumbSize })
          .fill(Color.White)

        Circle({ width: this.thumbSize - 8, height: this.thumbSize - 8 })
          .fill(this.getHueHex(this.hue))
      }
      .width(this.thumbSize)
      .height(this.thumbSize)
      .offset({ x: this.getThumbOffset(), y: 0 })
      .focusable(false)
      .gesture(
        PanGesture({ fingers: 1 })
          .onActionStart(() => {
            // ✅ 开始滑动时记录当前色相
            this.startHue = this.hue;
          })
          .onActionUpdate((event: GestureEvent) => {
            // ✅ 使用 offsetX 计算色相增量
            this.updateHueByOffset(event.offsetX);
          })
      )
    }
    .width('100%')
    .height(40)
  }

  // 根据绝对坐标更新（用于点击轨道）
  private updateHueByX(localX: number) {
    if (this.trackWidth <= this.thumbSize) return;
    const effectiveWidth = this.trackWidth - this.thumbSize;
    // 修正点击位置，使滑块中心移至手指处
    let touchX = localX - (this.thumbSize / 2);
    this.applyRatio(touchX / effectiveWidth);
  }

  // ✅ 根据偏移量更新（用于平滑拖拽）
  private updateHueByOffset(offsetX: number) {
    if (this.trackWidth <= this.thumbSize) return;
    const effectiveWidth = this.trackWidth - this.thumbSize;
    // 计算起始点对应的位移比例
    const startOffset = (this.startHue / 360) * effectiveWidth;
    // 当前总位移 = 起始位移 + 手势偏移
    const currentOffset = startOffset + offsetX;

    this.applyRatio(currentOffset / effectiveWidth);
  }

  private applyRatio(ratio: number) {
    let r = ratio;
    if (r < 0) r = 0;
    if (r > 1) r = 1;
    const newHue = r * 360;
    this.hue = newHue;
    if (this.onHueChange) {
      this.onHueChange(newHue);
    }
  }

  getHueHex(h: number): string {
    return ColorGenerator.hsvToHex(h, 100, 100);
  }
}



// =========================================
// 子组件：预览卡片 (简单展示效果)
// =========================================
@Component
struct ThemePreviewCard {
  @Prop brandColor: string;
  @Prop accentColor: string;

  build() {
    Column() {
      Row() {
        // 模拟头像
        Circle({ width: 40, height: 40 })
          .fill(this.brandColor)

        Column() {
          Blank().width('60%').height(12).borderRadius(6).backgroundColor('#F0F0F0')
          Blank().width('40%').height(12).borderRadius(6).backgroundColor('#F0F0F0').margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .padding(16)

      // 模拟按钮
      Row() {
        Button("取消")
          .backgroundColor('#F5F5F5')
          .fontColor('#666')
          .height(32)
          .fontSize(12)
          .margin({ right: 12 })

        Button("确定")
          .backgroundColor(this.accentColor) // 使用强调色
          .height(32)
          .fontSize(12)
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding(12)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}