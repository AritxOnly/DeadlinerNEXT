import { DatabaseHelper } from '../data/DatabaseHelper';
import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { DDLItem } from '../../model/DDLModels';
// 引入你新建的 Provider 接口
import { ISyncProvider } from './SyncProvider';

// 定义快照的数据结构 (Interface)
interface SnapshotVer {
  ts: string;
  ctr: number;
  dev: string;
}
interface SnapshotDoc {
  id: number;
  name: string;
  start_time: string;
  end_time: string;
  is_completed: number;
  complete_time: string;
  note: string;
  is_archived: number;
  is_stared: number;
  type: string;
  habit_count: number;
  habit_total_count: number;
  calendar_event: number;
  timestamp: string;
}
interface SnapshotItem {
  uid: string;
  ver: SnapshotVer;
  deleted: boolean;
  doc: SnapshotDoc | null;
}

interface SnapshotInterface {
  ts: string;
  dev: string;
}

export interface SnapshotRoot {
  version: SnapshotInterface;
  items: SnapshotItem[]; // 或使用 Array<SnapshotItem>
}

export interface SyncResult {
  success: boolean;
  hasLocalChanges: boolean;
}

export class SyncService {
  private db: DatabaseHelper;
  private provider: ISyncProvider;

  // 构造函数改为接收 ISyncProvider
  constructor(db: DatabaseHelper, provider: ISyncProvider) {
    this.db = db;
    this.provider = provider;
  }

  // 动态切换 Provider 的能力
  public switchProvider(newProvider: ISyncProvider) {
    this.provider = newProvider;
  }

  // 业务层钩子
  onLocalInserted(newLocalId: number) {}
  onLocalUpdated(localId: number) {}
  onLocalDeleting(localId: number) {}

  async syncOnce(): Promise<SyncResult> {
    console.info("SyncService: snapshot syncOnce start");
    try {
      return await this.syncSnapshotOnce();
    } catch (e) {
      console.warn(`Sync Failed: ${e}`);
      return { success: false, hasLocalChanges: false };
    }
  }

  // ============== 1) 构造“本地快照”（包含墓碑） ==============
  private async buildLocalSnapshot(): Promise<SnapshotRoot> {
    const store = this.db.getRdbStore();
    if (!store) throw new Error("DB not initialized");

    const sql = `
      SELECT
        uid,
        COALESCE(deleted,0)             AS deleted,
        COALESCE(ver_ts,'1970-01-01T00:00:00Z') AS ver_ts,
        COALESCE(ver_ctr,0)             AS ver_ctr,
        COALESCE(ver_dev,'')            AS ver_dev,
        id, name, start_time, end_time, is_completed, complete_time, note,
        is_archived, is_stared, type, habit_count, habit_total_count, calendar_event, timestamp
      FROM ddl_items
    `;

    const resultSet = await store.querySql(sql);
    const items: SnapshotItem[] = [];

    while (resultSet.goToNextRow()) {
      const uid = resultSet.getString(resultSet.getColumnIndex("uid"));
      if (!uid) continue;

      const deleted = resultSet.getLong(resultSet.getColumnIndex("deleted")) !== 0;
      const ver: SnapshotVer = {
        ts: resultSet.getString(resultSet.getColumnIndex("ver_ts")),
        ctr: resultSet.getLong(resultSet.getColumnIndex("ver_ctr")),
        dev: resultSet.getString(resultSet.getColumnIndex("ver_dev"))
      };

      let doc: SnapshotDoc | null = null;
      if (!deleted) {
        doc = {
          id: resultSet.getLong(resultSet.getColumnIndex("id")),
          name: resultSet.getString(resultSet.getColumnIndex("name")),
          start_time: resultSet.getString(resultSet.getColumnIndex("start_time")),
          end_time: resultSet.getString(resultSet.getColumnIndex("end_time")),
          is_completed: resultSet.getLong(resultSet.getColumnIndex("is_completed")),
          complete_time: resultSet.getString(resultSet.getColumnIndex("complete_time")),
          note: resultSet.getString(resultSet.getColumnIndex("note")),
          is_archived: resultSet.getLong(resultSet.getColumnIndex("is_archived")),
          is_stared: resultSet.getLong(resultSet.getColumnIndex("is_stared")),
          type: resultSet.getString(resultSet.getColumnIndex("type")),
          habit_count: resultSet.getLong(resultSet.getColumnIndex("habit_count")),
          habit_total_count: resultSet.getLong(resultSet.getColumnIndex("habit_total_count")),
          calendar_event: resultSet.getLong(resultSet.getColumnIndex("calendar_event")),
          timestamp: resultSet.getString(resultSet.getColumnIndex("timestamp")),
        };
      }

      items.push({ uid, ver, deleted, doc });
    }
    resultSet.close();

    const deviceId = await this.db.getDeviceId();
    const nowTs = new Date().toISOString();

    return {
      version: { ts: nowTs, dev: deviceId },
      items: items
    };
  }

  // ============== 2) 合并（LWW：ts > ctr > dev） ==============
  private mergeSnapshots(local: SnapshotRoot, remote: SnapshotRoot): SnapshotRoot {
    const map = new Map<string, SnapshotItem>();

    const load = (root: SnapshotRoot) => {
      if (root.items && Array.isArray(root.items)) {
        for (const item of root.items) {
          map.set(item.uid, item);
        }
      }
    };

    load(local);

    if (remote.items && Array.isArray(remote.items)) {
      for (const rItem of remote.items) {
        const lItem = map.get(rItem.uid);
        if (!lItem) {
          map.set(rItem.uid, rItem);
        } else {
          if (this.newer(rItem, lItem)) {
            map.set(rItem.uid, rItem);
          }
        }
      }
    }

    const outItems = Array.from(map.values());

    return {
      version: {
        ts: local.version.ts,
        dev: local.version.dev
      },
      items: outItems
    };
  }

  // ============== 3) 应用“最终快照”到本地 DB ==============
  private isVerNewer(aVer: SnapshotVer, bVer: SnapshotVer): boolean {
    if (aVer.ts !== bVer.ts) return aVer.ts > bVer.ts;
    if (aVer.ctr !== bVer.ctr) return aVer.ctr > bVer.ctr;
    return aVer.dev >= bVer.dev;
  }

  private newer(a: SnapshotItem, b: SnapshotItem): boolean {
    return this.isVerNewer(a.ver, b.ver);
  }

  private async applySnapshotToLocal(merged: SnapshotRoot): Promise<boolean> {
    const store = this.db.getRdbStore();
    if (!store || !merged.items) return false;

    store.beginTransaction();
    let insertCount = 0;
    let updateCount = 0;
    let skipCount = 0;

    try {
      for (const item of merged.items) {
        const uid = item.uid;
        const mergedVer = item.ver;
        const deleted = item.deleted;

        const predicates = new relationalStore.RdbPredicates("ddl_items");
        predicates.equalTo("uid", uid);
        const resultSet = await store.query(predicates);
        const exists = resultSet.goToFirstRow();

        let localId: number | null = null;
        let currentLocalVer: SnapshotVer | null = null;

        if (exists) {
          localId = resultSet.getLong(resultSet.getColumnIndex("id"));
          currentLocalVer = {
            ts: resultSet.getString(resultSet.getColumnIndex("ver_ts")),
            ctr: resultSet.getLong(resultSet.getColumnIndex("ver_ctr")),
            dev: resultSet.getString(resultSet.getColumnIndex("ver_dev"))
          };
        }
        resultSet.close();

        if (currentLocalVer && this.isVerNewer(currentLocalVer, mergedVer)) {
          console.warn(`[Sync] Race detected for uid=${uid.slice(0,6)}. Local is newer, skipping overwrite.`);
          skipCount++;
          continue;
        }

        const bucket: ValuesBucket = {};
        bucket["ver_ts"] = mergedVer.ts;
        bucket["ver_ctr"] = mergedVer.ctr;
        bucket["ver_dev"] = mergedVer.dev;

        if (deleted) {
          bucket["deleted"] = 1;
          if (exists) {
            const upPred = new relationalStore.RdbPredicates("ddl_items");
            upPred.equalTo("id", localId);
            await store.update(bucket, upPred);
            updateCount++;
          } else {
            bucket["uid"] = uid;
            bucket["name"] = "(deleted)";
            bucket["start_time"] = ""; bucket["end_time"] = ""; bucket["complete_time"] = "";
            bucket["note"] = ""; bucket["type"] = "task"; bucket["timestamp"] = mergedVer.ts;
            bucket["is_completed"] = 1; bucket["is_archived"] = 1; bucket["is_stared"] = 0;
            bucket["habit_count"] = 0; bucket["habit_total_count"] = 0; bucket["calendar_event"] = -1;
            await store.insert("ddl_items", bucket);
            insertCount++;
          }
        } else {
          const doc = item.doc!;
          bucket["deleted"] = 0;
          bucket["name"] = doc.name;
          bucket["start_time"] = doc.start_time;
          bucket["end_time"] = doc.end_time;
          bucket["is_completed"] = doc.is_completed;
          bucket["complete_time"] = doc.complete_time;
          bucket["note"] = doc.note;
          bucket["is_archived"] = doc.is_archived;
          bucket["is_stared"] = doc.is_stared;
          bucket["type"] = doc.type;
          bucket["habit_count"] = doc.habit_count;
          bucket["habit_total_count"] = doc.habit_total_count;
          bucket["calendar_event"] = doc.calendar_event;
          bucket["timestamp"] = doc.timestamp;

          if (exists) {
            const upPred = new relationalStore.RdbPredicates("ddl_items");
            upPred.equalTo("id", localId);
            await store.update(bucket, upPred);
            updateCount++;
          } else {
            bucket["uid"] = uid;
            await store.insert("ddl_items", bucket);
            insertCount++;
          }
        }
      }
      store.commit();
      console.info(`[Sync] Apply done. Ins:${insertCount}, Upd:${updateCount}, Skipped(Race):${skipCount}`);

      return (insertCount > 0 || updateCount > 0);
    } catch (e) {
      console.error(`[Sync] Apply failed: ${e}`);
      store.rollBack();
      return false;
    }
  }

  // ============== 4) 核心同步流程 ==============
  private async syncSnapshotOnce(): Promise<SyncResult> {
    // 1. 构建本地快照
    const localSnap = await this.buildLocalSnapshot();

    // 2. 获取远端快照 (由具体的 Provider 实现，可能是 WebDAV 的 GET，也可能是 CloudSync 读本地映射)
    const remoteRes = await this.provider.getRemoteSnapshot();
    if (!remoteRes.success) {
      console.error("[Sync] Failed to get remote snapshot.");
      return { success: false, hasLocalChanges: false };
    }

    let merged: SnapshotRoot;
    if (remoteRes.snapshot === null) {
      // 远端为空/不存在，说明是首次同步或初始化，直接使用本地快照
      merged = localSnap;
      console.info("[Sync] Remote is empty, initializing with local snapshot.");
    } else {
      // 3. 远端有数据，进行 LWW 合并
      merged = this.mergeSnapshots(localSnap, remoteRes.snapshot);
      console.info("[Sync] Merge completed.");
    }

    // 4. 将合并后的结果覆盖写回远端 (由具体的 Provider 实现)
    const putSuccess = await this.provider.putMergedSnapshot(merged);
    if (!putSuccess) {
      console.error("[Sync] Failed to put merged snapshot to remote.");
      return { success: false, hasLocalChanges: false };
    }

    // 5. 应用最终结果到本地数据库
    const hasChanges = await this.applySnapshotToLocal(merged);

    // 6. 主动触发同步推流 (针对华为端云协同，WebDAV 实现为空操作)
    await this.provider.triggerSync();

    return { success: true, hasLocalChanges: hasChanges };
  }
}