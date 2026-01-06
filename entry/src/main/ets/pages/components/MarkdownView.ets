import { MarkdownParser, MdNode, MdType } from '../../utils/MarkdownParser';

@Component
export struct MarkdownView {
  @Prop content: string = '';
  @State nodes: MdNode[] = [];

  @Prop baseColor: string | ResourceColor = '';

  aboutToAppear() {
    // 组件加载时进行解析
    this.nodes = MarkdownParser.parse(this.content);
  }

  // --- 核心：渲染包含加粗语法的文本行 ---
  // 输入: "这是 **加粗** 的文字"
  // 逻辑: 按 "**" 分割 -> ["这是 ", "加粗", " 的文字"]
  // 偶数索引是普通文本，奇数索引是加粗文本
  @Builder
  RichTextBuilder(text: string, fontSize: number, normalFontColor: ResourceColor) {
    Text() {
      // 第一层循环：处理粗体 (**bold**)
      ForEach(text.split('**'), (part: string, index: number) => {
        // 【修正】这里不能写 const/let，直接接下一个 UI 组件或逻辑组件

        // 第二层循环：处理斜体 (*italic*)
        ForEach(part.split('*'), (subPart: string, subIndex: number) => {

          Span(subPart)
            .fontSize(fontSize)
            // 逻辑内联：奇数索引为粗体，使用 baseColor；否则用普通颜色
            .fontColor((index % 2 === 1) ? this.baseColor : normalFontColor)
            // 逻辑内联：奇数索引为粗体
            .fontWeight((index % 2 === 1) ? FontWeight.Bold : FontWeight.Regular)
            // 逻辑内联：奇数索引为斜体
            .fontStyle((subIndex % 2 === 1) ? FontStyle.Italic : FontStyle.Normal)

        })
      })
    }
    .lineHeight(fontSize * 1.6)
    .width('100%')
  }

  build() {
    Column({ space: 8 }) {
      ForEach(this.nodes, (node: MdNode) => {

        // 1. 一级标题 (# )
        if (node.type === MdType.HEADER1) {
          Text(node.content)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ top: 16, bottom: 8 })
            .width('100%')
        }

        // 2. 二级标题 (## )
        else if (node.type === MdType.HEADER2) {
          Text(node.content)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ top: 12, bottom: 4 })
            .width('100%')
        }

        // 3. 列表项 (- )
        else if (node.type === MdType.LIST_ITEM) {
          Row({ space: 8 }) {
            // 小圆点
            Circle({ width: 4, height: 4 })
              .fill($r('sys.color.ohos_id_color_text_secondary'))

            // 列表内容 (支持加粗)
            this.RichTextBuilder(node.content, 16, $r('sys.color.ohos_id_color_text_secondary'))
          }
          .alignItems(VerticalAlign.Center)
          .width('100%')
          .padding({ left: 8 })
        }

        // 4. 普通段落
        else if (node.type === MdType.PARAGRAPH) {
          this.RichTextBuilder(node.content, 16, $r('sys.color.ohos_id_color_text_primary'))
        }

        // 5. 空行 (用于调整间距)
        else if (node.type === MdType.SPACE) {
          Blank().height(4)
        }

        else if (node.type === MdType.IMAGE) {
          Column({ space: 4 }) {
            Image($rawfile(node.content))
              .width('100%')
              .constraintSize({ maxHeight: '280vp' })
              .borderRadius(20)
              .objectFit(ImageFit.Contain)
              .backgroundColor($r('app.color.background_primary'))

            if (node.alt) {
              Text(node.alt)
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          .margin({ top: 8, bottom: 8 })
        }

        else if (node.type === MdType.QUOTE) {
          Column() {
            this.RichTextBuilder(node.content, 14, $r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .backgroundColor($r('sys.color.ohos_id_color_hover'))
          .borderRadius(20)
          .border({
            width: { left: 4 },
            color: { left: this.baseColor || $r('app.color.brand_50') },
            style: { left: BorderStyle.Solid }
          })
          .padding({ left: 12, top: 12, bottom: 12, right: 12 })
          .margin({ top: 4, bottom: 4 })
        }

      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}