import { DatabaseHelper } from '../db/DatabaseHelper';
import { WebUtils, PreconditionFailedError } from '../network/WebUtils';
import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { DDLItem } from '../../model/DDLModels';

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

interface SnapshotRoot {
  version: SnapshotInterface;
  items: SnapshotItem[]; // 或使用 Array<SnapshotItem>
}

export class SyncService {
  private db: DatabaseHelper;
  private web: WebUtils;
  private readonly SNAPSHOT_PATH = "Deadliner/snapshot-v1.json";

  constructor(db: DatabaseHelper, web: WebUtils) {
    this.db = db;
    this.web = web;
  }

  // 业务层钩子
  onLocalInserted(newLocalId: number) {}
  onLocalUpdated(localId: number) {}
  onLocalDeleting(localId: number) {}

  async syncOnce(): Promise<boolean> {
    console.info("WebDAV: snapshot syncOnce start");
    try {
      return await this.syncSnapshotOnce();
    } catch (e) {
      console.warn(`Sync Failed: ${e}`);
      return false;
    }
  }

  // ============== 1) 构造“本地快照”（包含墓碑） ==============
  private async buildLocalSnapshot(): Promise<SnapshotRoot> {
    const store = this.db.getRdbStore(); // ⚠️ 需要在 DatabaseHelper 中暴露 getRdbStore()
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
  // 纯逻辑合并：不涉及 IO
  private mergeSnapshots(local: SnapshotRoot, remote: SnapshotRoot): SnapshotRoot {
    const map = new Map<string, SnapshotItem>();

    // 辅助：加载 items 到 map
    const load = (root: SnapshotRoot) => {
      if (root.items && Array.isArray(root.items)) {
        for (const item of root.items) {
          map.set(item.uid, item);
        }
      }
    };

    // 先全部加载 local
    load(local);

    // 遍历 remote 进行 LWW 决断
    if (remote.items && Array.isArray(remote.items)) {
      for (const rItem of remote.items) {
        const lItem = map.get(rItem.uid);
        if (!lItem) {
          // 本地没有，直接用远端
          map.set(rItem.uid, rItem);
        } else {
          // 冲突：LWW
          if (this.newer(rItem, lItem)) {
            map.set(rItem.uid, rItem);
          }
          // else: local is newer, keep local
        }
      }
    }

    // 转换为 Array
    const outItems = Array.from(map.values());

    // 返回合并后的结构 (版本号取 Local 的当前时间)
    return {
      version: {
        ts: local.version.ts, // Use local new timestamp
        dev: local.version.dev
      },
      items: outItems
    };
  }

  // ============== 3) 应用“最终快照”到本地 DB ==============
  // 提取 newer 逻辑，方便复用
  // 判断 a 是否比 b 新
  private isVerNewer(aVer: SnapshotVer, bVer: SnapshotVer): boolean {
    if (aVer.ts !== bVer.ts) return aVer.ts > bVer.ts;
    if (aVer.ctr !== bVer.ctr) return aVer.ctr > bVer.ctr;
    return aVer.dev >= bVer.dev;
  }

  // 修改原有的 newer 方法，调用上面的通用逻辑
  private newer(a: SnapshotItem, b: SnapshotItem): boolean {
    return this.isVerNewer(a.ver, b.ver);
  }

  // =====================================================
  // 🔥🔥🔥 核心修复：applySnapshotToLocal 🔥🔥🔥
  // =====================================================
  private async applySnapshotToLocal(merged: SnapshotRoot) {
    const store = this.db.getRdbStore();
    if (!store || !merged.items) return;

    store.beginTransaction();
    let insertCount = 0;
    let updateCount = 0;
    let skipCount = 0; // 统计被跳过的（保护本地新修改的）

    try {
      for (const item of merged.items) {
        const uid = item.uid;
        const mergedVer = item.ver; // 这是同步计算出的版本
        const deleted = item.deleted;

        // 1. 查询本地当前的实际状态
        const predicates = new relationalStore.RdbPredicates("ddl_items");
        predicates.equalTo("uid", uid);
        const resultSet = await store.query(predicates);
        const exists = resultSet.goToFirstRow();

        let localId: number | null = null;
        let currentLocalVer: SnapshotVer | null = null;

        if (exists) {
          localId = resultSet.getLong(resultSet.getColumnIndex("id"));
          // 读取当前 DB 里的版本号
          currentLocalVer = {
            ts: resultSet.getString(resultSet.getColumnIndex("ver_ts")),
            ctr: resultSet.getLong(resultSet.getColumnIndex("ver_ctr")),
            dev: resultSet.getString(resultSet.getColumnIndex("ver_dev"))
          };
        }
        resultSet.close();

        // 2. 🛡️🛡️🛡️ 竞态保护 🛡️🛡️🛡️
        // 如果本地存在，且本地现在的版本 比 合并结果的版本 还要新
        // 说明在同步期间，用户修改了这条数据。
        // 此时绝对不能覆盖，保留本地的修改！
        if (currentLocalVer && this.isVerNewer(currentLocalVer, mergedVer)) {
          console.warn(`[Sync] Race detected for uid=${uid.slice(0,6)}. Local is newer, skipping overwrite.`);
          skipCount++;
          continue; // 跳过这一条的写入
        }

        // 3. 正常写入逻辑 (和之前一样)
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
            // 插入墓碑
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
    } catch (e) {
      console.error(`[Sync] Apply failed: ${e}`);
      store.rollBack();
    }
  }

  // ============== 4) 核心流程：一次完整同步 ==============
  private async syncSnapshotOnce(): Promise<boolean> {
    const path = this.SNAPSHOT_PATH;

    // 1. 构建本地快照
    const localSnap = await this.buildLocalSnapshot();
    console.info(`[Sync] Local snapshot built. Items: ${localSnap.items.length}`);

    const textEncoder = new util.TextEncoder();
    const textDecoder = util.TextDecoder.create('utf-8');

    // 2. HEAD 探测
    let remoteCode = 0;
    try {
      const WebHead = await this.web.head(path);
      const code = WebHead.code;
      remoteCode = code;
      console.info(`[Sync] HEAD ${path} -> Code: ${code}`);
    } catch (e) {
      console.error(`[Sync] HEAD failed: ${e}`);
      return false;
    }

    // 3. 处理 404/409/410 -> 视为文件不存在，直接上传本地快照
    if ([404, 409, 410].includes(remoteCode)) {
      console.warn(`[Sync] Remote file not found (Code ${remoteCode}). Initializing cloud with local data...`);

      try {
        await this.web.ensureDir("Deadliner");
        const jsonStr = JSON.stringify(localSnap);
        const bytes = textEncoder.encodeInto(jsonStr);
        // If-None-Match: * 确保原子创建
        await this.web.putBytes(path, bytes, null, true);
        console.info(`[Sync] Uploaded local snapshot (Init).`);
        return true;
      } catch (e) {
        console.error(`[Sync] Init upload failed: ${e}`);
        return false;
      }
    }

    if (remoteCode >= 500) {
      console.warn("[Sync] Server Error, skip sync");
      return false;
    }

    // 4. GET 下载远端快照
    let remoteSnap: SnapshotRoot;
    let currentEtag: string | null = null;

    try {
      console.info(`[Sync] Downloading from ${path}...`);

      const webBytes = await this.web.getBytes(path);
      const bytes = webBytes.bytes;
      const etag = webBytes.etag;

      console.info(`[Sync] Downloaded ${bytes.length} bytes. ETag: ${etag}`);

      const jsonStr = textDecoder.decodeWithStream(bytes);
      remoteSnap = JSON.parse(jsonStr) as SnapshotRoot;

      console.info(`[Sync] Remote parsed. Items: ${remoteSnap.items?.length}`);

      currentEtag = etag;
    } catch (e) {
      const msg = `${e}`;
      // 如果 GET 变成了 409，当作空远端处理
      if (msg.includes('409')) {
        remoteSnap = { version: { ts: '1970', dev: 'unknown' }, items: [] };
      } else {
        console.error(`GET failed: ${e}`);
        return false;
      }
    }

    // 5. 合并
    let merged = this.mergeSnapshots(localSnap, remoteSnap);
    console.info(`[Sync] Merged result. Items: ${merged.items.length}`);

    let mergedJson = JSON.stringify(merged);
    let mergedBytes = textEncoder.encodeInto(mergedJson);

    // 6. PUT 回传 (带 If-Match 乐观锁)
    try {
      await this.web.putBytes(path, mergedBytes, currentEtag, false);
    } catch (e) {
      if (e instanceof PreconditionFailedError) {
        // 7. 发生冲突 (412)，重新下载 -> 再次合并 -> 再次上传
        console.warn("Conflict (412), retrying...");
        const retryGet = await this.web.getBytes(path);
        const retryRemoteSnap = JSON.parse(textDecoder.decodeWithStream(retryGet.bytes)) as SnapshotRoot;

        // 二次合并
        merged = this.mergeSnapshots(merged, retryRemoteSnap); // 用上次合并的结果再去合并新的远端
        mergedJson = JSON.stringify(merged);
        mergedBytes = textEncoder.encodeInto(mergedJson);

        // 强制上传 (或者再试一次 If-Match，这里简化为用新的 ETag 传)
        await this.web.putBytes(path, mergedBytes, retryGet.etag, false);
      } else {
        throw new Error(e);
      }
    }

    // 8. 应用最终结果到本地
    console.info(`[Sync] Applying to local DB...`);
    await this.applySnapshotToLocal(merged);
    console.info(`[Sync] Apply done.`);

    return true;
  }
}