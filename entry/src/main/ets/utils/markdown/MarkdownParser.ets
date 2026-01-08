export enum MdType {
  HEADER1,
  HEADER2,
  HEADER3,
  LIST_ITEM,
  PARAGRAPH,
  SPACE,
  IMAGE,
  QUOTE,
  DIVIDER
}

// 解析后的结构单元
export interface MdNode {
  type: MdType;
  content: string;
  alt?: string;
  level?: number;
}

export class MarkdownParser {
  private static readonly IMG_REGEX = /^!\[(.*?)\]\((.*?)\)$/;

  /**
   * 将原始 Markdown 字符串解析为节点数组
   */
  static parse(text: string): MdNode[] {
    const lines = text.split('\n');
    const nodes: MdNode[] = [];

    for (const line of lines) {
      const trimLine = line.trim();

      if (trimLine.length === 0) {
        nodes.push({ type: MdType.SPACE, content: '' });
        continue;
      }

      const imgMatch = trimLine.match(MarkdownParser.IMG_REGEX);
      if (imgMatch) {
        nodes.push({
          type: MdType.IMAGE,
          alt: imgMatch[1],    // 捕获组1: alt text
          content: imgMatch[2] // 捕获组2: image url (通常是 rawfile 路径)
        });
        continue; // 识别成功跳过后续判断
      }

      if (trimLine === '---' || trimLine.startsWith('---')) {
        nodes.push({ type: MdType.DIVIDER, content: '' });
      } else if (trimLine.startsWith('> ')) {
        const content = trimLine.substring(2);

        const lastNode = nodes.length > 0 ? nodes[nodes.length - 1] : null;

        if (lastNode && lastNode.type === MdType.QUOTE) {
          lastNode.content += '\n' + content;
        } else {
          nodes.push({ type: MdType.QUOTE, content: content });
        }
      } else if (trimLine.startsWith('### ')) {
        nodes.push({ type: MdType.HEADER3, content: trimLine.substring(4) });
      } else if (trimLine.startsWith('## ')) {
        nodes.push({ type: MdType.HEADER2, content: trimLine.substring(3) });
      } else if (trimLine.startsWith('# ')) {
        nodes.push({ type: MdType.HEADER1, content: trimLine.substring(2) });
      } else if (trimLine.startsWith('- ')) {
        nodes.push({
          type: MdType.LIST_ITEM,
          content: trimLine.substring(2),
          level: 0
        });
      } else if (trimLine.startsWith('^ ')) {
        nodes.push({
          type: MdType.LIST_ITEM, // 类型还是 LIST_ITEM
          content: trimLine.substring(2),
          level: 1 // 标记为二级，缩进更多
        });
      } else {
        nodes.push({ type: MdType.PARAGRAPH, content: trimLine });
      }
    }
    return nodes;
  }
}