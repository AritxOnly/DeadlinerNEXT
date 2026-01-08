export enum LinkType {
  TEXT = 0,       // 普通文本
  HELP_LINK = 1,  // <文字>[id] -> 跳转帮助详情
  ROUTE_LINK = 2  // <文字>(route) -> 跳转路由
}

export interface LinkSegment {
  type: LinkType;
  text: string;   // 显示的文字
  target: string; // id 或 routeName
}

export class LinkParser {
  // 匹配 <文字>[id]
  private static readonly HELP_REGEX = /<([^>]+)>\[([^\]]+)\]/;
  // 匹配 <文字>(route)
  private static readonly ROUTE_REGEX = /<([^>]+)>\(([^)]+)\)/;

  /**
   * 将一行文本解析为片段数组
   * 输入: "请参考 <WebDAV>[webdav] 配置"
   * 输出: [ {TEXT, "请参考 "}, {HELP_LINK, "WebDAV", "webdav"}, {TEXT, " 配置"} ]
   */
  static parse(text: string): LinkSegment[] {
    const segments: LinkSegment[] = [];
    let remaining = text;

    while (remaining.length > 0) {
      // 寻找两种链接的匹配项
      const helpMatch = remaining.match(LinkParser.HELP_REGEX);
      const routeMatch = remaining.match(LinkParser.ROUTE_REGEX);

      // 找到最早出现的匹配项
      let bestMatch: RegExpMatchArray | null = null;
      let type = LinkType.TEXT;

      // 比较索引，谁靠前处理谁
      if (helpMatch && routeMatch) {
        if ((helpMatch.index || 0) < (routeMatch.index || 0)) {
          bestMatch = helpMatch;
          type = LinkType.HELP_LINK;
        } else {
          bestMatch = routeMatch;
          type = LinkType.ROUTE_LINK;
        }
      } else if (helpMatch) {
        bestMatch = helpMatch;
        type = LinkType.HELP_LINK;
      } else if (routeMatch) {
        bestMatch = routeMatch;
        type = LinkType.ROUTE_LINK;
      }

      // 如果没有匹配项，剩余部分全是文本
      if (!bestMatch) {
        segments.push({ type: LinkType.TEXT, text: remaining, target: '' });
        break;
      }

      // 处理匹配项前面的普通文本
      const index = bestMatch.index || 0;
      if (index > 0) {
        segments.push({
          type: LinkType.TEXT,
          text: remaining.substring(0, index),
          target: ''
        });
      }

      // 处理匹配项本身
      segments.push({
        type: type,
        text: bestMatch[1], // 捕获组1: 显示文字
        target: bestMatch[2] // 捕获组2: id 或 route
      });

      // 截断已处理部分，继续循环
      remaining = remaining.substring(index + bestMatch[0].length);
    }

    return segments;
  }
}