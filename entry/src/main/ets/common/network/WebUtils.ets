import { rcp } from '@kit.RemoteCommunicationKit';
import { util } from '@kit.ArkTS';
import { LocalValues } from '../local/LocalValues';

// 简单的自定义异常
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
  private session: rcp.Session;

  public static cloudSyncEnable: boolean = true;

  constructor(baseUrl: string, username?: string, password?: string) {
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl : baseUrl + '/';

    const headers: rcp.RequestHeaders = {};

    if (username && password) {
      const textEncoder = new util.TextEncoder();
      const origin = `${username}:${password}`;
      const uint8Array = textEncoder.encodeInto(origin);
      const base64Helper = new util.Base64Helper();
      const authHeader = `Basic ${base64Helper.encodeToStringSync(uint8Array)}`;

      headers['Authorization'] = authHeader;
    }

    this.session = rcp.createSession({
      headers: headers
    });
  }

  close() {
    this.session.close();
  }

  private ensureSyncEnabled() {
    const isEnabled = LocalValues.getInstance().getCloudSyncEnable();
    if (!isEnabled) {
      throw new Error("Cloud sync is disabled by user.");
    }
  }

  private joinUrl(path: string): string {
    const p = path.startsWith('/') ? path.substring(1) : path;
    return `${this.baseUrl}${p}`;
  }

  // ============== 核心方法 ==============

  async head(path: string): Promise<HeadReturnValues> {
    this.ensureSyncEnabled();
    const url = this.joinUrl(path);
    const req = new rcp.Request(url, "HEAD");

    try {
      const resp = await this.session.fetch(req);

      const etag = this.getHeader(resp.headers, 'ETag');
      const lenStr = this.getHeader(resp.headers, 'Content-Length');
      const len = lenStr ? parseInt(lenStr) : null;

      return { code: resp.statusCode, etag, len };
    } catch (e) {
      // 修复 1: 必须抛出 Error 对象
      throw new Error(`HEAD Request Failed: ${JSON.stringify(e)}`);
    }
  }

  async getBytes(path: string): Promise<GetBytesReturnValues> {
    this.ensureSyncEnabled();
    const url = this.joinUrl(path);
    const req = new rcp.Request(url, "GET");

    try {
      const resp = await this.session.fetch(req);

      if (resp.statusCode !== 200) {
        throw new Error(`GET ${path} -> ${resp.statusCode}`);
      }

      const etag = this.getHeader(resp.headers, 'ETag');

      let bytes: Uint8Array;
      if (resp.body) {
        bytes = new Uint8Array(resp.body);
      } else {
        bytes = new Uint8Array(0);
      }

      return { bytes, etag };
    } catch (e) {
      // 修复 1
      throw new Error(`GET Bytes Failed: ${JSON.stringify(e)}`);
    }
  }

  async getRange(path: string, from: number): Promise<GetRangeReturnValues> {
    this.ensureSyncEnabled();
    const url = this.joinUrl(path);

    const req = new rcp.Request(url, "GET");
    req.headers = {
      'Range': `bytes=${from}-`
    };

    try {
      const resp = await this.session.fetch(req);

      if (resp.statusCode !== 200 && resp.statusCode !== 206) {
        throw new Error(`GET Range ${path} -> ${resp.statusCode}`);
      }

      const etag = this.getHeader(resp.headers, 'ETag');

      let bytes: Uint8Array;
      if (resp.body) {
        bytes = new Uint8Array(resp.body);
      } else {
        bytes = new Uint8Array(0);
      }

      const newOffset = from + bytes.length;
      return { bytes, etag, newOffset };
    } catch (e) {
      // 修复 1
      throw new Error(`GET Range Failed: ${JSON.stringify(e)}`);
    }
  }

  async putBytes(
    path: string,
    bytes: Uint8Array | string,
    ifMatch?: string | null,
    ifNoneMatchStar: boolean = false
  ): Promise<string | null> {
    this.ensureSyncEnabled();

    const parentOk = await this.ensureParents(path);
    if (!parentOk) throw new Error(`MKCOL parents failed for ${path}`);

    const url = this.joinUrl(path);

    const req = new rcp.Request(url, "PUT");

    const headers: rcp.RequestHeaders = {
      'Content-Type': 'application/json; charset=utf-8'
    };
    if (ifMatch) headers['If-Match'] = ifMatch;
    if (ifNoneMatchStar) headers['If-None-Match'] = '*';
    req.headers = headers;

    if (typeof bytes === 'string') {
      req.content = bytes;
    } else {
      req.content = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    }

    try {
      const resp = await this.session.fetch(req);

      if (resp.statusCode === 412) {
        throw new PreconditionFailedError();
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw new Error(`PUT ${path} -> ${resp.statusCode}`);
      }

      return this.getHeader(resp.headers, 'ETag');
    } catch (e) {
      if (e instanceof PreconditionFailedError) {
        throw e; // 如果是已知 Error 类型，可以直接抛
      }
      // 修复 1
      throw new Error(`PUT Failed: ${JSON.stringify(e)}`);
    }
  }

  // ============== 目录操作 ==============

  async dirExists(dir: string): Promise<boolean> {
    const d = dir.endsWith('/') ? dir : dir + '/';
    try {
      const code = await this.propfind(d, "0");
      return [200, 207, 301, 302].includes(code);
    } catch (e) {
      return false;
    }
  }

  async propfind(path: string, depth: string = "0"): Promise<number> {
    this.ensureSyncEnabled();
    const url = this.joinUrl(path);

    const req = new rcp.Request(url, "PROPFIND");

    req.headers = {
      'Depth': depth,
      'Content-Type': 'application/xml'
    };

    try {
      const resp = await this.session.fetch(req);
      return resp.statusCode;
    } catch (e) {
      console.error(`PROPFIND failed: ${JSON.stringify(e)}`);
      return 0;
    }
  }

  async mkcol(dir: string): Promise<boolean> {
    const d = dir.endsWith('/') ? dir : dir + '/';
    const url = this.joinUrl(d);

    const req = new rcp.Request(url, "MKCOL");

    try {
      const resp = await this.session.fetch(req);
      return [201, 405, 409].includes(resp.statusCode);
    } catch (e) {
      console.error(`MKCOL failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  async ensureParents(filePath: string): Promise<boolean> {
    let cleanPath = filePath.trim();
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);

    const parts = cleanPath.split('/');
    if (parts.length === 0) return true;

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
    const exists = await this.dirExists(dirname);
    if (exists) return true;
    return await this.mkcol(dirname);
  }

  // 修复 2: 严格处理类型
  private getHeader(headers: rcp.ResponseHeaders, key: string): string | null {
    if (!headers) return null;
    const lowerKey = key.toLowerCase();

    const keys = Object.keys(headers);
    for (const k of keys) {
      if (k.toLowerCase() === lowerKey) {
        const val = headers[k];

        // 显式处理 undefined
        if (val === undefined || val === null) {
          return null;
        }

        // ArkTS 不允许 undefined 分配给 string | null，所以上面必须拦截
        return Array.isArray(val) ? val[0] : val;
      }
    }
    return null;
  }
}