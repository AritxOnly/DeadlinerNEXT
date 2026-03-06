import { SnapshotRoot } from './SyncService'; // 记得导出你的 SnapshotRoot

export interface SyncResultProvider {
  success: boolean;
  snapshot: SnapshotRoot | null;
}

export interface ISyncProvider {
  // 获取远端快照
  getRemoteSnapshot(): Promise<SyncResultProvider>;
  // 覆盖/写入合并后的快照到远端
  putMergedSnapshot(merged: SnapshotRoot): Promise<boolean>;
  // 主动触发同步（主要针对华为云盘）
  triggerSync(): Promise<void>;
}