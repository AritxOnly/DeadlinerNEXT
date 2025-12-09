import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { LocalValues } from '../local/LocalValues';

// 简单的自定义异常，用于模拟 PreconditionFailed
export class PreconditionFailedError extends Error {
  constructor(message: string = "Precondition Failed") {
    super(message);
    this.name = "PreconditionFailedError";
  }
}

interface HeadReturnValues {
  code: number;
  etag: string | null;
  len: number | null;
}

interface GetBytesReturnValues {
  bytes: Uint8Array;
  etag: string | null;
}

interface GetRangeReturnValues {
  bytes: Uint8Array;
  etag: string | null;
  newOffset: number;
}

export class WebUtils {
  private baseUrl: string;
  private authHeader: string | null = null;
  // 模拟 GlobalUtils.cloudSyncEnable，实际请替换为你的配置读取逻辑
  public static cloudSyncEnable: boolean = true;

  constructor(baseUrl: string, username?: string, password?: string) {
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl : baseUrl + '/';
    if (username && password) {
      const textEncoder = new util.TextEncoder();
      const origin = `${username}:${password}`;
      const uint8Array = textEncoder.encodeInto(origin);
      const base64Helper = new util.Base64Helper();
      this.authHeader = `Basic ${base64Helper.encodeToStringSync(uint8Array)}`;
    }
  }

  private ensureSyncEnabled() {
    // 从 SettingsValue 获取真实配置
    const isEnabled = LocalValues.getInstance().getCloudSyncEnable();
    if (!isEnabled) {
      throw new Error("Cloud sync is disabled by user.");
    }
  }

  private joinUrl(path: string): string {
    const p = path.startsWith('/') ? path.substring(1) : path;
    return `${this.baseUrl}${p}`;
  }

  private getHeaders(extra: Record<string, string> = {}): Record<string, string> {
    const headers: Record<string, string> = {};
    if (this.authHeader) {
      headers['Authorization'] = this.authHeader;
    }
    Object.keys(extra).forEach((key) => {
      headers[key] = extra[key];
    });
    return headers;
  }

  // ============== 核心方法 ==============

  async head(path: string): Promise<HeadReturnValues> {
    this.ensureSyncEnabled();
    const httpRequest = http.createHttp();
    const url = this.joinUrl(path);

    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.HEAD,
        header: this.getHeaders(),
        expectDataType: http.HttpDataType.STRING
      });

      // Header key 可能是小写，需注意
      const etag = this.getHeader(resp.header, 'ETag');
      const lenStr = this.getHeader(resp.header, 'Content-Length');
      const len = lenStr ? parseInt(lenStr) : null;

      return { code: resp.responseCode, etag, len };
    } finally {
      httpRequest.destroy();
    }
  }

  async getBytes(path: string): Promise<GetBytesReturnValues> {
    this.ensureSyncEnabled();
    const httpRequest = http.createHttp();
    const url = this.joinUrl(path);

    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        expectDataType: http.HttpDataType.ARRAY_BUFFER // 👈 必须显式声明接收 ArrayBuffer
      });

      if (resp.responseCode !== 200) {
        throw new Error(`GET ${path} -> ${resp.responseCode}`);
      }

      const etag = this.getHeader(resp.header, 'ETag');

      // 🔥 修复：确保结果是 ArrayBuffer，并转为 Uint8Array
      let resultBuffer: ArrayBuffer;
      if (resp.result instanceof ArrayBuffer) {
        resultBuffer = resp.result;
      } else {
        //以此防范某些情况下返回非 ArrayBuffer
        throw new Error("Response is not ArrayBuffer");
      }

      const bytes = new Uint8Array(resultBuffer);
      return { bytes, etag };
    } finally {
      httpRequest.destroy();
    }
  }

  // 注意：ArkTS http 模块对 Range 支持取决于服务端响应，这里做基础实现
  // 原 Kotlin 代码返回了 newOffset，这里简化返回值结构
  async getRange(path: string, from: number): Promise<GetRangeReturnValues> {
    this.ensureSyncEnabled();
    const httpRequest = http.createHttp();
    const url = this.joinUrl(path);
    const headers = this.getHeaders({ 'Range': `bytes=${from}-` });

    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });

      if (resp.responseCode !== 200 && resp.responseCode !== 206) {
        throw new Error(`GET Range ${path} -> ${resp.responseCode}`);
      }

      const etag = this.getHeader(resp.header, 'ETag');
      const bytes = new Uint8Array(resp.result as ArrayBuffer);
      const newOffset = from + bytes.length;
      return { bytes, etag, newOffset };
    } finally {
      httpRequest.destroy();
    }
  }

  async putBytes(
    path: string,
    bytes: Uint8Array | string,
    ifMatch?: string | null,
    ifNoneMatchStar: boolean = false
  ): Promise<string | null> {
    this.ensureSyncEnabled();

    // 关键：先把父目录建好
    const parentOk = await this.ensureParents(path);
    if (!parentOk) throw new Error(`MKCOL parents failed for ${path}`);

    const httpRequest = http.createHttp();
    const url = this.joinUrl(path);

    const headers = this.getHeaders({
      'Content-Type': 'application/json; charset=utf-8' // 建议明确指定 JSON
    });
    if (ifMatch) headers['If-Match'] = ifMatch;
    if (ifNoneMatchStar) headers['If-None-Match'] = '*';

    // 🔥 关键修复：将 Uint8Array 转回 ArrayBuffer 传给 extraData
    // ArkTS 的 http 模块对 ArrayBuffer 的支持最稳定
    let payload: ArrayBuffer | string;
    if (typeof bytes === 'string') {
      payload = bytes;
    } else {
      // 这里的 slice 是为了防止 buffer 包含多余的 offset
      payload = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    }

    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: headers,
        extraData: payload // 👈 传入 ArrayBuffer
      });

      if (resp.responseCode === 412) {
        throw new PreconditionFailedError();
      }

      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        throw new Error(`PUT ${path} -> ${resp.responseCode}`);
      }

      return this.getHeader(resp.header, 'ETag');
    } finally {
      httpRequest.destroy();
    }
  }

  // ============== 目录操作 ==============

  async dirExists(dir: string): Promise<boolean> {
    const d = dir.endsWith('/') ? dir : dir + '/';
    try {
      const head = await this.head(d);
      const code = head.code;
      // 207 是 WebDAV Multi-Status，也代表存在
      return [200, 204, 207].includes(code);
    } catch (e) {
      return false;
    }
  }

  async mkcol(dir: string): Promise<boolean> {
    const httpRequest = http.createHttp();
    const d = dir.endsWith('/') ? dir : dir + '/';
    const url = this.joinUrl(d);

    try {
      const resp = await httpRequest.request(url, {
        method: 'MKCOL' as http.RequestMethod, // WebDAV 方法
        header: this.getHeaders(),
        extraData: '' // 必须有 body 否则某些 server 报错
      });
      // 201 Created, 405 Method Not Allowed (可能已存在), 409 Conflict (可能已存在)
      return [201, 405, 409].includes(resp.responseCode);
    } catch (e) {
      console.error(`MKCOL failed: ${e}`);
      return false;
    } finally {
      httpRequest.destroy();
    }
  }

  async ensureParents(filePath: string): Promise<boolean> {
    let cleanPath = filePath.trim();
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);

    const parts = cleanPath.split('/');
    if (parts.length === 0) return true;

    // 如果最后一段包含点（认为是文件），则去掉最后一段
    if (parts[parts.length - 1].includes('.')) {
      parts.pop();
    }
    if (parts.length === 0) return true;

    let cur = "";
    for (const seg of parts) {
      if (!seg) continue;
      cur = cur ? `${cur}/${seg}` : seg;

      const exists = await this.dirExists(cur);
      if (!exists) {
        const ok = await this.mkcol(cur);
        if (!ok) return false;
      }
    }
    return true;
  }

  async ensureDir(dirname: string): Promise<boolean> {
    if (!WebUtils.cloudSyncEnable) return false;
    // 1. HEAD
    const head = await this.head(dirname.endsWith('/') ? dirname : dirname + '/');
    const code = head.code;
    if ([200, 204, 301, 302, 207].includes(code)) return true;
    if (code === 401 || code === 403) return false;

    // 2. MKCOL
    return await this.mkcol(dirname);
  }

  // 辅助：不区分大小写获取 Header
  private getHeader(headers: Object, key: string): string | null {
    if (!headers) return null;
    const headerMap = headers as Record<string, string | string[]>;
    const lowerKey = key.toLowerCase();

    // Object.keys 在 ArkTS 中是允许的
    for (const k of Object.keys(headerMap)) {
      if (k.toLowerCase() === lowerKey) {
        const val = headerMap[k];
        return Array.isArray(val) ? val[0] : val;
      }
    }
    return null;
  }
}