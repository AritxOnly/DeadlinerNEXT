import { ThemeManager } from '../../../../../common/theme/ThemeManager';
import { ThemeMap, ITheme } from '../../../../../common/theme/ThemeModel';
import { ColorCustomizer } from './ColorCustomizer';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigation, HdsNavigationTitleMode, HdsNavigationAttribute, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../../components/TopSafeContainer';

interface ThemeOption {
  key: string;
  name: string;
  previewBg: ResourceColor;
}

const THEME_OPTIONS: ThemeOption[] = [
  { key: 'classic', name: '莫兰迪 (默认)', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'vibrant', name: '生动', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'nature', name: '清新', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'sunset', name: '暖阳', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'lavender', name: '极光', previewBg: $r('sys.color.search_container_focus_color') },
  { key: 'harmony', name: '星河 (鸿蒙OS)', previewBg: $r('sys.color.search_container_focus_color') },
];

@Component
export struct ThemeSelectSheet {
  @Provide('navPathStack') navStack: NavPathStack = new NavPathStack();
  @StorageProp('currentThemeKey') currentKey: string = 'classic';

  onDone?: () => void;

  @Builder
  navDestination(name: string) {
    if (name === 'ColorCustomizer') {
      HdsNavDestination() {
        Column() {
          TopSafeContainer({ topAvoidHeight: 72 }) {
            ColorCustomizer()
              .padding({ left: 16, right: 16, bottom: 20 })
          }
        }
      }
      .titleBar({
        content: {
          title: { mainTitle: "自定义颜色" },
          menu: {
            value: [
              {
                content: {
                  icon: $r('sys.symbol.xmark'),
                  action: () => { if (this.onDone) this.onDone(); }
                }
              }
            ]
          }
        },
      })
      .titleMode(HdsNavDestinationTitleMode.MODAL)
      .backgroundColor($r('sys.color.sheet_panel_background_color'))
    }
  }

  build() {
    HdsNavigation(this.navStack) {
      Column() {
        Blank().height(72)

        this.ThemePresetList()
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 20 })
    }
    .titleBar({
      content: {
        title: { mainTitle: "选择主题" },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.xmark'),
                action: () => { if (this.onDone) this.onDone(); }
              }
            }
          ]
        }
      },
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .navDestination(this.navDestination)
    .hideBackButton(true)
    .backgroundColor(Color.Transparent)
    .mode(NavigationMode.Stack)
  }

  // === 首页：预设列表内容 ===
  @Builder
  ThemePresetList() {
    GridRow({ columns: 2, gutter: 12 }) {
      ForEach(THEME_OPTIONS, (item: ThemeOption) => {
        GridCol() {
          this.ThemeItemBuilder(item)
        }
      })

      // 自定义入口卡片
      GridCol() {
        this.CustomEntryCardBuilder()
      }
    }
    .width('100%')
  }

  // === 组件：自定义入口卡片 ===
  @Builder
  CustomEntryCardBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 48, height: 48 })
            .fill(Color.Transparent)
            .border({ width: 2, color: $r('app.color.icon_secondary'), style: BorderStyle.Dashed })

          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(24)
            .fontColor([$r('app.color.icon_secondary')])
        }
        .width('100%')
        .height(80)

        Text('自定义')
          .fontSize(14)
          .fontColor($r('app.color.font_primary'))
          .fontWeight(FontWeight.Medium)
          .margin({ top: 12 })
      }
      .width('100%')
      .padding(12)
      .borderRadius(20)
      .backgroundColor($r('sys.color.search_container_focus_color'))
      .onClick(() => {
        this.navStack.pushPath({ name: 'ColorCustomizer' });
      })
    }
  }

  // === 组件：主题卡片 ===
  @Builder
  ThemeItemBuilder(item: ThemeOption) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Circle({ width: 48, height: 48 })
            .fill(ThemeMap[item.key].brand)

          Circle({ width: 24, height: 24 })
            .fill(ThemeMap[item.key].accent)
            .stroke(item.previewBg)
            .strokeWidth(2)
            .margin({ right: -4, bottom: -4 })
        }
        .width('100%')
        .height(80)
        .alignContent(Alignment.Center)

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
      .onClick(() => {
        ThemeManager.switchTheme(item.key);
      })

      if (this.currentKey === item.key) {
        Row() {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontColor([Color.White])
            .fontSize(10)
        }
        .width(20)
        .height(20)
        .borderRadius(10)
        .backgroundColor(ThemeMap[item.key].brand)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8, left: 8 })
      }
    }
  }
}