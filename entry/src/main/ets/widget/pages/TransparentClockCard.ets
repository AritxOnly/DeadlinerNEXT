@Entry
@Component
struct TransparentClockCard {
  /* ================= 模拟数据 ================= */
  @State timeStr: string = '16:00';
  @State dateStr: string = '今日 · 周四 / 1日';

  // 状态 B：有临近任务
  @State hasUrgent: boolean = true;
  @State urgentTaskName: string = '线性代数作业';

  // 统计数据
  @State imminentCount: number = 2; // 临近
  @State todoCount: number = 5;     // 待办
  @State totalCount: number = 12;   // 共
  @State habitCount: number = 3;    // 习惯

  // 样式常量 (直接取你的冰川色系)
  readonly COLOR_ACCENT: string = '#00ACC1'; // 亮青色，用于黑色背景或阴影
  readonly COLOR_BRAND: string = '#80DEEA';  // 冰凌色，用于高亮文字

  build() {
    Stack() {
      // 1. 背景：完全透明，不需要任何容器颜色

      // 2. 内容区域
      Column() {
        // --- 第一行：日期 & 临近任务 ---
        Row() {
          Text(this.dateStr)
            .fontSize(13)
            .fontColor(Color.White)
            .shadow(this.getTextShadow()) // 关键：智能阴影
            .opacity(0.9)

          if (this.hasUrgent) {
            // 分隔符
            Text(' · ')
              .fontSize(13)
              .fontColor(Color.White)
              .shadow(this.getTextShadow())

            // 沙漏图标 (使用 Symbol)
            SymbolGlyph($r('sys.symbol.hourglass'))
              .fontSize(13)
              .fontColor([Color.White]) // 或者用 brandColor 高亮
              .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
              .margin({ right: 4 })
              .shadow(this.getTextShadow())

            // 任务名称 (高亮显示)
            Text(this.urgentTaskName)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.COLOR_BRAND) // 使用冰川亮色，突出重点
              .shadow(this.getTextShadow(true)) // 加重阴影
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1) // 防止太长溢出
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // --- 第二行：统计概览 (Info Line) ---
        Row() {
          // 使用 TextSpan 或者拼接字符串，这里为了排版精细用 Row 拼接
          if (this.hasUrgent) {
            this.StatItem(this.imminentCount, '临近', true) // 红色/警示色
            this.Divider()
          }

          this.StatItem(this.todoCount, '待办')
          this.Divider()
          this.StatItem(this.totalCount, '共')
          this.Divider()
          this.StatItem(this.habitCount, '习惯')
        }
        .width('100%')
        .margin({ top: 6 })

        // --- 第三行：巨大的时间 (The Anchor) ---
        // 使用 Blank 撑开，或者直接放到底部
        Blank()

        TextClock()
          .fontSize(74)
          .fontWeight(FontWeight.Bold) // 粗体，更有质感
          .fontColor(Color.White)
          .shadow({
            radius: 15,
            color: 'rgba(0,0,0,0.3)',
            offsetY: 4
          })
          .margin({ bottom: -10, left: -4 }) // 微调位置，修正字体自带的留白
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start) // 左对齐布局
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    // 关键：不要设置 .backgroundColor，保持默认或显式 Transparent
  }

  // === 组件：统计小项 ===
  @Builder
  StatItem(count: number, label: string, isUrgent: boolean = false) {
    Row({ space: 2 }) {
      Text(count.toString())
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        // 临近任务用亮色，普通任务用白色
        .fontColor(isUrgent ? '#FF8A80' : Color.White)
        .shadow(this.getTextShadow())

      Text(label)
        .fontSize(12)
        .fontColor(Color.White)
        .opacity(0.7)
        .shadow(this.getTextShadow())
    }
  }

  // === 组件：微型分隔符 ===
  @Builder
  Divider() {
    Text(' / ')
      .fontSize(10)
      .fontColor(Color.White)
      .opacity(0.4)
      .margin({ left: 4, right: 4 })
      .shadow(this.getTextShadow())
  }

  // === 工具：统一阴影生成器 ===
  // 无论壁纸是黑是白，给文字加一个黑色的模糊阴影，都能保证可见性
  getTextShadow(isStrong: boolean = false): ShadowOptions {
    return {
      radius: isStrong ? 8 : 4,
      color: 'rgba(0,0,0,0.4)', // 半透明黑色阴影
      offsetX: 0,
      offsetY: 1
    };
  }
}