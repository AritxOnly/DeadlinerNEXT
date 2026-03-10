import { ISyncProvider, SyncResultProvider } from './SyncProvider';
import { SnapshotRoot } from './SyncService';
import { WebUtils, PreconditionFailedError } from '../network/WebUtils';
import { util } from '@kit.ArkTS';

export class WebDavProvider implements ISyncProvider {
  private web: WebUtils;
  private readonly path = "Deadliner/snapshot-v1.json";
  private currentEtag: string | null = null;
  private textDecoder = util.TextDecoder.create('utf-8');
  private textEncoder = new util.TextEncoder();

  constructor(web: WebUtils) {
    this.web = web;
  }

  async getRemoteSnapshot(): Promise<SyncResultProvider> {
    try {
      // 省略部分错误捕获细节，照搬你原来的逻辑
      const webHead = await this.web.head(this.path);
      if ([404, 409, 410].includes(webHead.code)) {
        return { success: true, snapshot: null }; // 需初始化
      }

      const webBytes = await this.web.getBytes(this.path);
      this.currentEtag = webBytes.etag;
      const jsonStr = this.textDecoder.decodeToString(webBytes.bytes);
      const snapshot = JSON.parse(jsonStr) as SnapshotRoot;

      if (!snapshot.items) snapshot.items = [];
      return { success: true, snapshot: snapshot };

    } catch (e) {
      return { success: false, snapshot: null };
    }
  }

  async putMergedSnapshot(merged: SnapshotRoot): Promise<boolean> {
    try {
      await this.web.ensureDir("Deadliner");
      const jsonStr = JSON.stringify(merged);
      const bytes = this.textEncoder.encodeInto(jsonStr);
      await this.web.putBytes(this.path, bytes, this.currentEtag, false);
      return true;
    } catch (e) {
      if (e instanceof PreconditionFailedError) {
        console.warn("[WebDAV] Conflict 412");
      }
      return false;
    }
  }

  async triggerSync(): Promise<void> {
    // WebDAV 的同步完全由应用控制，不需要触发系统底层
  }
}