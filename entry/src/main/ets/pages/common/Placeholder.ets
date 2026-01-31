import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { getImmersiveTitleBarStyle } from '../../common/style/NavStyles';
import { ITheme } from '../../common/theme/ThemeModel';

@Builder
export function PlaceholderBuilder() {
  PlaceHolder();
}

@Component
export struct PlaceHolder {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // 引入 isWideScreen 用于获取正确的背景色样式
  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  build() {
    HdsNavDestination() {
      Column() {
        Image($r('app.media.icon'))
          .size({ width: 86, height: 86 })
          .opacity(0.85)

        Text('Deadliner待办日历')
          .fontSize(18)
          .fontWeight(700)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ top: 12 })

        Text('未选择项目') // 可选：加个提示文字
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      // 内容居中
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      // 背景色设在这里
      .backgroundColor(this.theme.bgPrimary)
    }
    // 配置标题栏（即使隐藏也要配置，为了统一沉浸式行为）
    .titleBar({
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: '' } }
    })
    .hideTitleBar(true)   // 占位页通常不需要标题栏
    .hideBackButton(true) // 占位页绝不需要返回按钮
  }
}