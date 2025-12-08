import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { DbConstants as C } from './DbConstants';
import {
  DDLItem, DeadlineType, Habit, HabitPeriod, HabitGoalType, HabitStatus,
  HabitRecord, HabitRecordStatus, Ver
} from '../../model/DDLModels';

export interface DDLInsertParams {
  name: string;
  startTime: string;
  endTime: string;
  isCompleted: boolean;
  completeTime: string;
  note: string;
  isArchived: boolean;
  isStared: boolean;
  type: DeadlineType;
  calendarEventId: number | null;
}

export class DatabaseHelper {
  private static instance: DatabaseHelper;
  private rdbStore: relationalStore.RdbStore | null = null;
  private context: Context | null = null;

  private initPromise: Promise<void> | null = null;

  private constructor() {}

  public isReady(): boolean {
    return this.rdbStore !== null;
  }

  public static getInstance(): DatabaseHelper {
    if (!DatabaseHelper.instance) {
      DatabaseHelper.instance = new DatabaseHelper();
    }
    return DatabaseHelper.instance;
  }

  public getRdbStore(): relationalStore.RdbStore | null {
    return this.rdbStore
  }

  // 初始化数据库
  async init(context: Context): Promise<void> {
    this.context = context;
    if (this.rdbStore) return;

    if (this.initPromise) {
      return this.initPromise;
    }

    this.initPromise = this.doInit(context);
    return this.initPromise;
  }

  private async doInit(context: Context): Promise<void> {
    try {
      this.context = context;
      const store = await relationalStore.getRdbStore(context, {
        name: C.STORE_CONFIG.name,
        securityLevel: relationalStore.SecurityLevel.S1
      });

      if (store.version === 0) {
        await this.createTables(store);
        store.version = 13;
      }

      this.rdbStore = store;
      console.info('[DatabaseHelper] Init success');
    } catch (err) {
      console.error(`[DatabaseHelper] Init failed: ${err.message}`);
      // 🔥 关键：虽然我们打印了日志，但不要 throw，否则 await init() 的地方会崩溃。
      // 我们通过 rdbStore 是否为 null 来判断结果。
    } finally {
      this.initPromise = null;
    }
  }

  private async createTables(store: relationalStore.RdbStore) {
    // 1. DDL Items Table
    const createDDLTable = `
      CREATE TABLE IF NOT EXISTS ${C.TABLE_NAME} (
        ${C.COLUMN_ID} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${C.COLUMN_NAME} TEXT NOT NULL,
        ${C.COLUMN_START_TIME} TEXT NOT NULL,
        ${C.COLUMN_END_TIME} TEXT NOT NULL,
        ${C.COLUMN_IS_COMPLETED} INTEGER,
        ${C.COLUMN_COMPLETE_TIME} TEXT NOT NULL,
        ${C.COLUMN_NOTE} TEXT NOT NULL,
        ${C.COLUMN_IS_ARCHIVED} INTEGER,
        ${C.COLUMN_IS_STARED} INTEGER,
        ${C.COLUMN_TYPE} TEXT NOT NULL,
        ${C.COLUMN_HABIT_COUNT} INTEGER,
        ${C.COLUMN_HABIT_TOTAL_COUNT} INTEGER,
        ${C.COLUMN_CALENDAR_EVENT_ID} INTEGER,
        ${C.COLUMN_TIMESTAMP} TEXT,
        ${C.COLUMN_UID} TEXT UNIQUE,
        ${C.COLUMN_DELETED} INTEGER NOT NULL DEFAULT 0,
        ${C.COLUMN_VER_TS} TEXT NOT NULL DEFAULT '1970-01-01T00:00:00Z',
        ${C.COLUMN_VER_CTR} INTEGER NOT NULL DEFAULT 0,
        ${C.COLUMN_VER_DEV} TEXT NOT NULL DEFAULT ''
      )
    `;
    await store.executeSql(createDDLTable);
    await store.executeSql(`CREATE UNIQUE INDEX IF NOT EXISTS idx_ddl_uid ON ${C.TABLE_NAME}(${C.COLUMN_UID})`);

    // 2. Sync State Table
    const createSyncState = `
      CREATE TABLE IF NOT EXISTS sync_state(
        id INTEGER PRIMARY KEY CHECK(id=1),
        device_id TEXT NOT NULL,
        last_local_ts TEXT NOT NULL DEFAULT '1970-01-01T00:00:00Z',
        last_local_ctr INTEGER NOT NULL DEFAULT 0
      )
    `;
    await store.executeSql(createSyncState);
    // 初始化 Device ID (生成随机 Hex)
    const randomHex = this.generateRandomHex(6);
    await store.executeSql(`INSERT OR IGNORE INTO sync_state(id, device_id) VALUES(1, '${randomHex}')`);

    // 3. Habit Table
    const createHabitTable = `
      CREATE TABLE IF NOT EXISTS ${C.TABLE_HABIT} (
        ${C.HABIT_ID} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${C.HABIT_DDL_ID} INTEGER NOT NULL UNIQUE,
        ${C.HABIT_NAME} TEXT NOT NULL,
        ${C.HABIT_DESC} TEXT,
        ${C.HABIT_COLOR} INTEGER,
        ${C.HABIT_ICON_KEY} TEXT,
        ${C.HABIT_PERIOD} TEXT NOT NULL,
        ${C.HABIT_TIMES_PER_PERIOD} INTEGER NOT NULL DEFAULT 1,
        ${C.HABIT_GOAL_TYPE} TEXT NOT NULL DEFAULT 'PER_PERIOD',
        ${C.HABIT_TOTAL_TARGET} INTEGER,
        ${C.HABIT_CREATED_AT} TEXT NOT NULL,
        ${C.HABIT_UPDATED_AT} TEXT NOT NULL,
        ${C.HABIT_STATUS} TEXT NOT NULL DEFAULT 'ACTIVE',
        ${C.HABIT_SORT_ORDER} INTEGER NOT NULL DEFAULT 0,
        ${C.HABIT_ALARM_TIME} TEXT,
        FOREIGN KEY(${C.HABIT_DDL_ID}) REFERENCES ${C.TABLE_NAME}(${C.COLUMN_ID}) ON DELETE CASCADE
      )
    `;
    await store.executeSql(createHabitTable);

    // 4. Habit Record Table
    const createRecordTable = `
      CREATE TABLE IF NOT EXISTS ${C.TABLE_HABIT_RECORD} (
        ${C.HR_ID} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${C.HR_HABIT_ID} INTEGER NOT NULL,
        ${C.HR_DATE} TEXT NOT NULL,
        ${C.HR_COUNT} INTEGER NOT NULL DEFAULT 1,
        ${C.HR_STATUS} TEXT NOT NULL DEFAULT 'COMPLETED',
        ${C.HR_CREATED_AT} TEXT NOT NULL,
        FOREIGN KEY(${C.HR_HABIT_ID}) REFERENCES ${C.TABLE_HABIT}(${C.HABIT_ID}) ON DELETE CASCADE
      )
    `;
    await store.executeSql(createRecordTable);
    await store.executeSql(`CREATE INDEX IF NOT EXISTS idx_hr_habit_date ON ${C.TABLE_HABIT_RECORD}(${C.HR_HABIT_ID}, ${C.HR_DATE})`);
  }

  // ================= DDL Operations =================

  // DatabaseHelper.ets

  async insertDDL(item: DDLInsertParams): Promise<number> {
    if (!this.rdbStore) return -1;

    const now = new Date();
    const v = await this.nextVersionUTC(); // 获取版本号
    const deviceId = v.dev; // 直接复用 nextVersionUTC 返回的 devId，减少一次查询

    // 开启事务：从此开始，所有操作要么全成，要么全败
    this.rdbStore.beginTransaction();

    let insertId = -1;

    try {
      // 1. 准备插入数据 (暂时没有 UID)
      const bucket: relationalStore.ValuesBucket = {};
      bucket[C.COLUMN_NAME] = item.name;
      bucket[C.COLUMN_START_TIME] = item.startTime;
      bucket[C.COLUMN_END_TIME] = item.endTime;
      bucket[C.COLUMN_IS_COMPLETED] = item.isCompleted ? 1 : 0;
      bucket[C.COLUMN_COMPLETE_TIME] = item.completeTime || "";
      bucket[C.COLUMN_NOTE] = item.note;
      bucket[C.COLUMN_IS_ARCHIVED] = item.isArchived ? 1 : 0;
      bucket[C.COLUMN_IS_STARED] = item.isStared ? 1 : 0;
      bucket[C.COLUMN_TYPE] = item.type.toString().toLowerCase();
      bucket[C.COLUMN_HABIT_COUNT] = 0;
      bucket[C.COLUMN_HABIT_TOTAL_COUNT] = 0;
      bucket[C.COLUMN_CALENDAR_EVENT_ID] = item.calendarEventId ?? -1;
      bucket[C.COLUMN_TIMESTAMP] = this.formatLocalDateTime(now);
      bucket[C.COLUMN_DELETED] = 0;

      // 关键：先写入版本信息，防止为空，虽然 UID 暂时还没有
      bucket[C.COLUMN_VER_TS] = v.ts;
      bucket[C.COLUMN_VER_CTR] = v.ctr;
      bucket[C.COLUMN_VER_DEV] = v.dev;

      // 2. 执行插入，拿到 ID
      insertId = await this.rdbStore.insert(C.TABLE_NAME, bucket);

      if (insertId > 0) {
        // 3. 生成与 Android 格式完全一致的 UID
        const uid = `${deviceId}:${insertId}`;

        // 4. 更新回去
        const updateBucket: relationalStore.ValuesBucket = {};
        updateBucket[C.COLUMN_UID] = uid;

        const predicates = new relationalStore.RdbPredicates(C.TABLE_NAME);
        predicates.equalTo(C.COLUMN_ID, insertId);

        await this.rdbStore.update(updateBucket, predicates);

        // 5. 提交事务！此时数据才真正写入磁盘
        this.rdbStore.commit();
        console.info(`[DatabaseHelper] Insert success. UID: ${uid}`);
      } else {
        // 插入失败，回滚
        this.rdbStore.rollBack();
      }
    } catch (e) {
      console.error(`[DatabaseHelper] Insert failed: ${e}`);
      this.rdbStore.rollBack(); // 发生异常，回滚，就像什么都没发生过一样
      return -1;
    }

    return insertId;
  }

  async getAllDDLs(): Promise<DDLItem[]> {
    if (!this.rdbStore) return [];
    const predicates = new relationalStore.RdbPredicates(C.TABLE_NAME);
    predicates.equalTo(C.COLUMN_DELETED, 0); // 只查未删除的

    const resultSet = await this.rdbStore.query(predicates);
    return this.parseDDLResultSet(resultSet);
  }

  async getDDLsByType(type: DeadlineType): Promise<DDLItem[]> {
    if (!this.rdbStore) return [];
    const predicates = new relationalStore.RdbPredicates(C.TABLE_NAME);
    predicates.equalTo(C.COLUMN_DELETED, 0);
    predicates.equalTo(C.COLUMN_TYPE, type.toString().toLowerCase());
    predicates.orderByAsc(C.COLUMN_IS_COMPLETED);
    predicates.orderByAsc(C.COLUMN_END_TIME);

    const resultSet = await this.rdbStore.query(predicates);
    return this.parseDDLResultSet(resultSet);
  }

  async updateDDL(item: DDLItem): Promise<void> {
    if (!this.rdbStore) return;
    const v = await this.nextVersionUTC();
    const bucket: relationalStore.ValuesBucket = {}
    bucket[C.COLUMN_NAME] = item.name;
    bucket[C.COLUMN_START_TIME] = item.startTime;
    bucket[C.COLUMN_END_TIME] = item.endTime;
    bucket[C.COLUMN_IS_COMPLETED] = item.isCompleted ? 1 : 0;
    bucket[C.COLUMN_COMPLETE_TIME] = item.completeTime;
    bucket[C.COLUMN_NOTE] = item.note;
    bucket[C.COLUMN_IS_ARCHIVED] = item.isArchived ? 1 : 0;
    bucket[C.COLUMN_IS_STARED] = item.isStared ? 1 : 0;
    bucket[C.COLUMN_TYPE] = item.type.toString().toLowerCase();
    bucket[C.COLUMN_HABIT_COUNT] = item.habitCount;
    bucket[C.COLUMN_HABIT_TOTAL_COUNT] = item.habitTotalCount;
    bucket[C.COLUMN_CALENDAR_EVENT_ID] = item.calendarEventId ?? -1;
    bucket[C.COLUMN_TIMESTAMP] = this.formatLocalDateTime(new Date());
    // Sync update
    bucket[C.COLUMN_VER_TS] = v.ts;
    bucket[C.COLUMN_VER_CTR] = v.ctr;
    bucket[C.COLUMN_VER_DEV] = v.dev;

    const predicates = new relationalStore.RdbPredicates(C.TABLE_NAME);
    predicates.equalTo(C.COLUMN_ID, item.id);
    await this.rdbStore.update(bucket, predicates);
  }

  async deleteDDL(id: number): Promise<void> {
    if (!this.rdbStore) return;
    const v = await this.nextVersionUTC();
    const bucket: relationalStore.ValuesBucket = {};

    bucket[C.COLUMN_DELETED] = 1; // 软删除
    bucket[C.COLUMN_VER_TS] = v.ts;
    bucket[C.COLUMN_VER_CTR] = v.ctr;
    bucket[C.COLUMN_VER_DEV] = v.dev;

    const predicates = new relationalStore.RdbPredicates(C.TABLE_NAME);
    predicates.equalTo(C.COLUMN_ID, id);
    await this.rdbStore.update(bucket, predicates);
  }

  // ================= Sync Utilities =================

  async getDeviceId(): Promise<string> {
    if (!this.rdbStore) return "";
    const sql = "SELECT device_id FROM sync_state WHERE id=1";
    const resultSet = await this.rdbStore.querySql(sql);
    if (resultSet.goToFirstRow()) {
      const id = resultSet.getString(resultSet.getColumnIndex("device_id"));
      resultSet.close();
      return id;
    }
    resultSet.close();
    return "unknown";
  }

  async nextVersionUTC(): Promise<Ver> {
    if (!this.rdbStore) return { ts: "", ctr: 0, dev: "" };

    const now = new Date().toISOString(); // Instant.now()

    const sql = "SELECT last_local_ts, last_local_ctr, device_id FROM sync_state WHERE id=1";
    const rs = await this.rdbStore.querySql(sql);

    let lastTs = "";
    let lastCtr = 0;
    let devId = "";

    if (rs.goToFirstRow()) {
      lastTs = rs.getString(0);
      lastCtr = rs.getLong(1);
      devId = rs.getString(2);
    }
    rs.close();

    let newer: Ver;
    if (now > lastTs) {
      newer = { ts: now, ctr: 0, dev: devId };
    } else {
      newer = { ts: lastTs, ctr: lastCtr + 1, dev: devId };
    }

    const bucket: ValuesBucket = {
      "last_local_ts": newer.ts,
      "last_local_ctr": newer.ctr
    };
    const predicates = new relationalStore.RdbPredicates("sync_state");
    predicates.equalTo("id", 1);
    await this.rdbStore.update(bucket, predicates);

    return newer;
  }

  // ================= Private Helpers =================

  private generateRandomHex(bytes: number): string {
    // 简单模拟 hex(randomblob(3))
    const chars = '0123456789ABCDEF';
    let result = '';
    for (let i = 0; i < bytes * 2; i++) {
      result += chars.charAt(Math.floor(Math.random() * 16));
    }
    return result;
  }

  // 模拟 Java LocalDateTime.toString() (无 'Z', 毫秒如果为0可能省略，这里简化处理)
  // 实际上建议统一用 ISOString，但为了兼容你旧数据格式，尽量保持一致
  private formatLocalDateTime(date: Date): string {
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  }

  private parseDDLResultSet(resultSet: relationalStore.ResultSet): DDLItem[] {
    const list: DDLItem[] = [];
    while (resultSet.goToNextRow()) {
      const typeStr = resultSet.getString(resultSet.getColumnIndex(C.COLUMN_TYPE));
      const type = typeStr === 'habit' ? DeadlineType.HABIT : DeadlineType.TASK;

      list.push({
        id: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_ID)),
        name: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_NAME)),
        startTime: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_START_TIME)),
        endTime: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_END_TIME)),
        isCompleted: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_IS_COMPLETED)) === 1,
        completeTime: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_COMPLETE_TIME)),
        note: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_NOTE)),
        isArchived: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_IS_ARCHIVED)) === 1,
        isStared: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_IS_STARED)) === 1,
        type: type,
        habitCount: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_HABIT_COUNT)),
        habitTotalCount: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_HABIT_TOTAL_COUNT)),
        calendarEventId: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_CALENDAR_EVENT_ID)),
        timeStamp: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_TIMESTAMP)),
        // Sync
        uid: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_UID)),
        deleted: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_DELETED)) === 1,
        verTs: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_VER_TS)),
        verCtr: resultSet.getLong(resultSet.getColumnIndex(C.COLUMN_VER_CTR)),
        verDev: resultSet.getString(resultSet.getColumnIndex(C.COLUMN_VER_DEV)),
      });
    }
    resultSet.close();
    return list;
  }
}