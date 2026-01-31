import { ThemeManager } from '../../../../common/theme/ThemeManager';
import { ThemeMap } from '../../../../common/theme/ThemeModel';

interface ThemeOption {
  key: string;
  name: string;
  previewBg: ResourceColor; // 卡片底色预览
}

const THEME_OPTIONS: ThemeOption[] = [
  { key: 'classic', name: '莫兰迪 (默认)', previewBg: ThemeMap['classic'].bgPrimary },
  { key: 'vibrant', name: '生动', previewBg: ThemeMap['vibrant'].bgPrimary },
  { key: 'nature', name: '清新', previewBg: ThemeMap['nature'].bgPrimary },
  { key: 'sunset', name: '暖阳', previewBg: ThemeMap['sunset'].bgPrimary },
  { key: 'lavender', name: '极光', previewBg: ThemeMap['lavender'].bgPrimary },
  { key: 'harmony', name: '星河 (鸿蒙OS)', previewBg: ThemeMap['harmony'].bgPrimary },
  // { key: 'custom', name: '自定义', previewBg: ... } // 暂时留空
];

@Component
export struct ThemeSelectSheet {
  // 订阅当前选中的 Key，用于显示边框高亮
  @StorageProp('currentThemeKey') currentKey: string = 'classic';

  // 用于关闭 Sheet 的回调（如果需要）
  // closeAction?: () => void;

  build() {
    Column() {
      // 使用 GridRow 自动适配布局
      GridRow({ columns: 2, gutter: 12 }) {
        ForEach(THEME_OPTIONS, (item: ThemeOption) => {
          GridCol() {
            this.ThemeItemBuilder(item)
          }
        })
      }
    }
    .padding(20)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  @Builder
  ThemeItemBuilder(item: ThemeOption) {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 卡片主体
      Column() {
        // 预览色块区域
        Stack({ alignContent: Alignment.BottomEnd }) {
          // 大圆：主色 (Brand)
          Circle({ width: 48, height: 48 })
            .fill(ThemeMap[item.key].brand)

          // 小圆：强调色 (Accent) - 放在右下角
          Circle({ width: 24, height: 24 })
            .fill(ThemeMap[item.key].accent)
            .stroke(item.previewBg) // 描边颜色与卡片底色一致，产生"切割"效果
            .strokeWidth(2)
            .margin({ right: -4, bottom: -4 }) // 微调位置让它溢出一点
        }
        .width('100%')
        .height(80)
        .alignContent(Alignment.Center)

        // 文字名称
        Text(item.name)
          .fontSize(14)
          .fontColor($r('app.color.font_primary'))
          .fontWeight(FontWeight.Medium)
          .margin({ top: 12 })
      }
      .width('100%')
      .padding(12)
      .borderRadius(20)
      .backgroundColor(item.previewBg)
      .border({
        width: 2,
        color: this.currentKey === item.key ? ThemeMap[item.key].brand : Color.Transparent
      })
      // 选中态阴影（可选）
      .shadow(this.currentKey === item.key ? { radius: 8, color: '#20000000', offsetY: 4 } : undefined)
      .animation({ duration: 300 }) // 动画过度
      .onClick(() => {
        // 点击切换
        ThemeManager.switchTheme(item.key);
      })

      // 2. 选中时的对勾图标 (右上角)
      if (this.currentKey === item.key) {
        Row() {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontColor([Color.White])
            .fontSize(10)
        }
        .width(20)
        .height(20)
        .borderRadius(10)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8, left: 8 }) // 放在左上角或者右上角
      }
    }
  }
}