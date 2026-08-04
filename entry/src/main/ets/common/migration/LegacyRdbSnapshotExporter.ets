import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from '../data/DatabaseHelper';

interface LegacySnapshotVersion {
  ts: string;
  dev: string;
}

interface LegacyEntityVersion {
  ts: string;
  ctr: number;
  dev: string;
}

interface LegacyTaskSubtask {
  id: string;
  content: string;
  is_completed: number;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

interface LegacyTaskDocument {
  id: number;
  name: string;
  start_time: string;
  end_time: string;
  state: string;
  complete_time: string;
  note: string;
  is_stared: number;
  type: string;
  habit_count: number;
  habit_total_count: number;
  calendar_event: number;
  timestamp: string;
  sub_tasks: LegacyTaskSubtask[];
}

interface LegacyTaskItem {
  uid: string;
  ver: LegacyEntityVersion;
  deleted: boolean;
  doc?: LegacyTaskDocument;
}

interface LegacyTaskRoot {
  version: LegacySnapshotVersion;
  items: LegacyTaskItem[];
}

interface LegacyHabitPayload {
  name: string;
  description: string | null;
  color: number | null;
  icon_key: string | null;
  period: string;
  times_per_period: number;
  goal_type: string;
  total_target: number | null;
  created_at: string;
  updated_at: string;
  status: string;
  sort_order: number;
  alarm_time: string | null;
}

interface LegacyHabitRecord {
  date: string;
  count: number;
  status: string;
  created_at: string;
}

interface LegacyHabitDocument {
  ddl_uid: string;
  habit: LegacyHabitPayload;
  records: LegacyHabitRecord[];
}

interface LegacyHabitItem {
  uid: string;
  ver: LegacyEntityVersion;
  deleted: boolean;
  doc?: LegacyHabitDocument;
}

interface LegacyHabitRoot {
  version: LegacySnapshotVersion;
  items: LegacyHabitItem[];
}

export class LegacyRdbSnapshotExport {
  public readonly taskPayload: string;
  public readonly habitPayload: string;
  public readonly taskItemCount: number;
  public readonly habitItemCount: number;

  constructor(taskPayload: string, habitPayload: string, taskItemCount: number, habitItemCount: number) {
    this.taskPayload = taskPayload;
    this.habitPayload = habitPayload;
    this.taskItemCount = taskItemCount;
    this.habitItemCount = habitItemCount;
  }
}

/**
 * Read-only projection of the current ArkTS RDB schema into the stable V2 snapshot wire format.
 * It never writes fallback UIDs or versions to the legacy database: generated fallbacks are only
 * used in the import payload and are deterministic for the same legacy row.
 */
export class LegacyRdbSnapshotExporter {
  private readonly database: DatabaseHelper = DatabaseHelper.getInstance();

  public async exportSnapshot(): Promise<LegacyRdbSnapshotExport> {
    const store: relationalStore.RdbStore | null = this.database.getRdbStore();
    if (store === null) {
      throw new Error('Legacy RDB is not initialized');
    }

    const exportedAt: string = new Date().toISOString();
    const deviceId: string = await this.database.getDeviceId();
    const rootVersion: LegacySnapshotVersion = {
      ts: exportedAt,
      dev: deviceId.length > 0 ? deviceId : 'legacy-rdb'
    };
    const taskRoot: LegacyTaskRoot = {
      version: rootVersion,
      items: await this.exportTaskItems(store, exportedAt)
    };
    const habitRoot: LegacyHabitRoot = {
      version: rootVersion,
      items: await this.exportHabitItems(store, exportedAt)
    };

    return new LegacyRdbSnapshotExport(
      JSON.stringify(taskRoot),
      JSON.stringify(habitRoot),
      await this.countExpectedKmpTaskItems(store),
      habitRoot.items.length
    );
  }

  /**
   * V2 stores habits twice: once as a DDL carrier in the task payload and once in the authoritative
   * habit payload. Core intentionally skips the carrier when the habit payload is present, so it
   * must not be counted as a KMP task during post-import validation.
   */
  private async countExpectedKmpTaskItems(store: relationalStore.RdbStore): Promise<number> {
    const resultSet: relationalStore.ResultSet = await store.querySql(
      "SELECT COUNT(*) AS item_count FROM ddl_items WHERE type <> 'habit'"
    );
    let count: number = 0;
    if (resultSet.goToNextRow()) {
      count = this.readNumber(resultSet, 'item_count', 0);
    }
    resultSet.close();
    return count;
  }

  private async exportTaskItems(store: relationalStore.RdbStore, fallbackTimestamp: string): Promise<LegacyTaskItem[]> {
    const sql: string = 'SELECT id, uid, COALESCE(deleted, 0) AS deleted, COALESCE(ver_ts, \'\') AS ver_ts, COALESCE(ver_ctr, 0) AS ver_ctr, COALESCE(ver_dev, \'\') AS ver_dev, name, start_time, end_time, state, is_completed, is_archived, complete_time, note, is_stared, type, habit_count, habit_total_count, calendar_event, timestamp FROM ddl_items ORDER BY id ASC';
    const resultSet: relationalStore.ResultSet = await store.querySql(sql);
    const items: LegacyTaskItem[] = [];
    while (resultSet.goToNextRow()) {
      const localId: number = this.readNumber(resultSet, 'id', 0);
      const uid: string = this.readUid(resultSet, 'uid', 'legacy-rdb:task:', localId);
      const deleted: boolean = this.readNumber(resultSet, 'deleted', 0) !== 0;
      const version: LegacyEntityVersion = this.readVersion(resultSet, fallbackTimestamp, uid);
      if (deleted) {
        const tombstone: LegacyTaskItem = { uid: uid, ver: version, deleted: true };
        items.push(tombstone);
        continue;
      }

      const document: LegacyTaskDocument = {
        id: localId,
        name: this.readString(resultSet, 'name', ''),
        start_time: this.readString(resultSet, 'start_time', ''),
        end_time: this.readString(resultSet, 'end_time', ''),
        state: this.readTaskState(resultSet),
        complete_time: this.readString(resultSet, 'complete_time', ''),
        note: this.readString(resultSet, 'note', ''),
        is_stared: this.readNumber(resultSet, 'is_stared', 0),
        type: this.readString(resultSet, 'type', 'task'),
        habit_count: this.readNumber(resultSet, 'habit_count', 0),
        habit_total_count: this.readNumber(resultSet, 'habit_total_count', 0),
        calendar_event: this.readNumber(resultSet, 'calendar_event', 0),
        timestamp: this.readString(resultSet, 'timestamp', fallbackTimestamp),
        sub_tasks: await this.exportSubtasks(store, localId, fallbackTimestamp)
      };
      const item: LegacyTaskItem = { uid: uid, ver: version, deleted: false, doc: document };
      items.push(item);
    }
    resultSet.close();
    return items;
  }

  private async exportHabitItems(store: relationalStore.RdbStore, fallbackTimestamp: string): Promise<LegacyHabitItem[]> {
    const sql: string = 'SELECT d.id AS ddl_id, d.uid AS ddl_uid, COALESCE(d.deleted, 0) AS ddl_deleted, COALESCE(d.ver_ts, \'\') AS ver_ts, COALESCE(d.ver_ctr, 0) AS ver_ctr, COALESCE(d.ver_dev, \'\') AS ver_dev, h.id AS habit_id, h.name AS habit_name, h.description AS habit_description, h.color AS habit_color, h.icon_key AS habit_icon_key, h.period AS habit_period, h.times_per_period AS habit_times_per_period, h.goal_type AS habit_goal_type, h.total_target AS habit_total_target, h.created_at AS habit_created_at, h.updated_at AS habit_updated_at, h.status AS habit_status, h.sort_order AS habit_sort_order, h.alarm_time AS habit_alarm_time FROM ddl_items d LEFT JOIN habits h ON h.ddl_id = d.id WHERE d.type = \'habit\' ORDER BY d.id ASC';
    const resultSet: relationalStore.ResultSet = await store.querySql(sql);
    const items: LegacyHabitItem[] = [];
    while (resultSet.goToNextRow()) {
      const localId: number = this.readNumber(resultSet, 'ddl_id', 0);
      const uid: string = this.readUid(resultSet, 'ddl_uid', 'legacy-rdb:habit:', localId);
      const deleted: boolean = this.readNumber(resultSet, 'ddl_deleted', 0) !== 0;
      const version: LegacyEntityVersion = this.readVersion(resultSet, fallbackTimestamp, uid);
      if (deleted) {
        const tombstone: LegacyHabitItem = { uid: uid, ver: version, deleted: true };
        items.push(tombstone);
        continue;
      }
      if (this.isNull(resultSet, 'habit_id')) {
        continue;
      }

      const habitId: number = this.readNumber(resultSet, 'habit_id', 0);
      const payload: LegacyHabitPayload = {
        name: this.readString(resultSet, 'habit_name', ''),
        description: this.readNullableString(resultSet, 'habit_description'),
        color: this.readNullableNumber(resultSet, 'habit_color'),
        icon_key: this.readNullableString(resultSet, 'habit_icon_key'),
        period: this.readString(resultSet, 'habit_period', 'DAILY'),
        times_per_period: this.readNumber(resultSet, 'habit_times_per_period', 1),
        goal_type: this.readString(resultSet, 'habit_goal_type', 'PER_PERIOD'),
        total_target: this.readNullableNumber(resultSet, 'habit_total_target'),
        created_at: this.readString(resultSet, 'habit_created_at', fallbackTimestamp),
        updated_at: this.readString(resultSet, 'habit_updated_at', fallbackTimestamp),
        status: this.readString(resultSet, 'habit_status', 'ACTIVE'),
        sort_order: this.readNumber(resultSet, 'habit_sort_order', 0),
        alarm_time: this.readNullableString(resultSet, 'habit_alarm_time')
      };
      const document: LegacyHabitDocument = {
        ddl_uid: uid,
        habit: payload,
        records: await this.exportHabitRecords(store, habitId)
      };
      const item: LegacyHabitItem = { uid: uid, ver: version, deleted: false, doc: document };
      items.push(item);
    }
    resultSet.close();
    return items;
  }

  private async exportSubtasks(store: relationalStore.RdbStore, ddlId: number, fallbackTimestamp: string): Promise<LegacyTaskSubtask[]> {
    const resultSet: relationalStore.ResultSet = await store.querySql('SELECT id, uid, content, is_completed, sort_order, ver_ts FROM subtasks WHERE ddl_id = ? AND COALESCE(deleted, 0) = 0 ORDER BY sort_order ASC, id ASC', [ddlId]);
    const subtasks: LegacyTaskSubtask[] = [];
    while (resultSet.goToNextRow()) {
      const localId: number = this.readNumber(resultSet, 'id', 0);
      const updatedAt: string = this.readString(resultSet, 'ver_ts', fallbackTimestamp);
      const subtask: LegacyTaskSubtask = {
        id: this.readUid(resultSet, 'uid', 'legacy-rdb:subtask:', localId),
        content: this.readString(resultSet, 'content', ''),
        is_completed: this.readNumber(resultSet, 'is_completed', 0),
        sort_order: this.readNumber(resultSet, 'sort_order', 0),
        created_at: updatedAt,
        updated_at: updatedAt
      };
      subtasks.push(subtask);
    }
    resultSet.close();
    return subtasks;
  }

  private async exportHabitRecords(store: relationalStore.RdbStore, habitId: number): Promise<LegacyHabitRecord[]> {
    const resultSet: relationalStore.ResultSet = await store.querySql('SELECT date, count, status, created_at FROM habit_records WHERE habit_id = ? ORDER BY date ASC, id ASC', [habitId]);
    const records: LegacyHabitRecord[] = [];
    while (resultSet.goToNextRow()) {
      const record: LegacyHabitRecord = {
        date: this.readString(resultSet, 'date', ''),
        count: this.readNumber(resultSet, 'count', 1),
        status: this.readString(resultSet, 'status', 'COMPLETED'),
        created_at: this.readString(resultSet, 'created_at', '')
      };
      records.push(record);
    }
    resultSet.close();
    return records;
  }

  private readVersion(resultSet: relationalStore.ResultSet, fallbackTimestamp: string, fallbackDeviceId: string): LegacyEntityVersion {
    return {
      ts: this.readString(resultSet, 'ver_ts', fallbackTimestamp),
      ctr: this.readNumber(resultSet, 'ver_ctr', 0),
      dev: this.readString(resultSet, 'ver_dev', fallbackDeviceId)
    };
  }

  private readTaskState(resultSet: relationalStore.ResultSet): string {
    const state: string = this.readString(resultSet, 'state', '');
    if (state === 'active' || state === 'completed' || state === 'archived' || state === 'abandoned' || state === 'abandonedArchived') {
      return state;
    }
    if (this.readNumber(resultSet, 'is_archived', 0) !== 0) {
      return 'archived';
    }
    if (this.readNumber(resultSet, 'is_completed', 0) !== 0) {
      return 'completed';
    }
    return 'active';
  }

  private readUid(resultSet: relationalStore.ResultSet, column: string, prefix: string, localId: number): string {
    return this.readString(resultSet, column, prefix + localId.toString());
  }

  private readString(resultSet: relationalStore.ResultSet, column: string, fallback: string): string {
    if (this.isNull(resultSet, column)) {
      return fallback;
    }
    return resultSet.getString(resultSet.getColumnIndex(column));
  }

  private readNullableString(resultSet: relationalStore.ResultSet, column: string): string | null {
    if (this.isNull(resultSet, column)) {
      return null;
    }
    return resultSet.getString(resultSet.getColumnIndex(column));
  }

  private readNumber(resultSet: relationalStore.ResultSet, column: string, fallback: number): number {
    if (this.isNull(resultSet, column)) {
      return fallback;
    }
    return resultSet.getLong(resultSet.getColumnIndex(column));
  }

  private readNullableNumber(resultSet: relationalStore.ResultSet, column: string): number | null {
    if (this.isNull(resultSet, column)) {
      return null;
    }
    return resultSet.getLong(resultSet.getColumnIndex(column));
  }

  private isNull(resultSet: relationalStore.ResultSet, column: string): boolean {
    const index: number = resultSet.getColumnIndex(column);
    return index < 0 || resultSet.isColumnNull(index);
  }
}
