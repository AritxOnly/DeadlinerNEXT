import { webview } from '@kit.ArkWeb';
import { router } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavDestinationAttribute } from '@kit.UIDesignKit';

export interface WebParams {
  url: string;
  title: string;
  onClose?: () => void;
}

@Component
struct WebBrowserPage {
  controller: webview.WebviewController = new webview.WebviewController();
  targetUrl: string = '';
  title: string = '';

  pathStack: NavPathStack | null = null;

  private onCloseCallback?: () => void;

  build() {
    HdsNavDestination() {
      Column() {
        Web({ src: this.targetUrl, controller: this.controller })
          .domStorageAccess(true)
          .width('100%')
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: {
          mainTitle: this.title
        },
      },
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .onReady((context) => {
      this.pathStack = context.pathStack;

      // 获取传递的参数
      const params = context.pathInfo.param as WebParams;
      if (params) {
        this.targetUrl = params.url;
        this.title = params.title;
        this.onCloseCallback = params.onClose;
      }
    })
    .onBackPressed(() => {
      if (this.onCloseCallback) {
        this.onCloseCallback();
      }

      return false;
    })
  }
}

@Builder
export function WebBrowserPageBuilder() {
  WebBrowserPage()
}