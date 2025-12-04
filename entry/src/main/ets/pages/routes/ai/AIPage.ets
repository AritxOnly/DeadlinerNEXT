import { HdsNavigation, HdsNavigationAttribute, BottomBuilderShowType } from '@kit.UIDesignKit';

@Component
export struct AiPage {
  @Builder
  StackBuilder() { // 自定义StackBuilder组件
    Column() {
      Button("Hello")
    }
    .height(56)
    .justifyContent(FlexAlign.Center)
  }


  @Builder
  BottomBuilder() { // 自定义BottomBuilder组件
    Column() {
      Search()
    }
    .width('100%')
    .height(56)
    .backgroundColor(Color.Orange)
  }


  build() {
    HdsNavigation() { // 创建HdsNavigation组件
    }.titleBar({
      content: { // 设置HdsNavigation组件内容区
        title: {mainTitle: 'MainTitle', subTitle: 'SubTitle'},
        // 设置HdsNavigation StackBuilder区域
        stackBuilder: this.StackBuilder.bind(this),
        // 设置HdsNavigation BottomBuilder区域，包括设置高度，显示类型
        bottomBuilder: { builder: this.BottomBuilder.bind(this), height: 56, showType: BottomBuilderShowType.DIRECTLY_SHOW, }
      }
    })
  }
}