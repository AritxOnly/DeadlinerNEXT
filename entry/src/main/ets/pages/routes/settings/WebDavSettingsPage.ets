@Builder
export function SettingsWebDavBuilder(name: string, param: Object) {
  SettingsWebDavPage()
}

@Component
export struct SettingsWebDavPage {
  // Navigation 路由栈引用
  pageStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Column() {
        Column() {
          Text('这里是 WebDAV 设置页内容（待实现）')
            .fontSize(16)
            .padding(24)
        }
        .layoutWeight(1)
      }
    }
    .title("WebDav设置")
    .onReady((context: NavDestinationContext) => {
      // 关键：拿到与 Index 共用的 NavPathStack
      this.pageStack = context.pathStack;
    })
  }
}