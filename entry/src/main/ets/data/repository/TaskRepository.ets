import { DatabaseHelper, DDLInsertParams } from '../db/DatabaseHelper';
import { SyncService } from '../sync/SyncService';
import { WebUtils } from '../network/WebUtils';
import { LocalValues } from '../local/LocalValues';
import { DDLItem, DeadlineType } from '../../model/DDLModels';
import { common } from '@kit.AbilityKit';
import { WidgetUpdater } from '../../utils/WidgetUpdater';

export class TaskRepository {
  private static instance: TaskRepository;
  private db: DatabaseHelper;
  private context: common.Context | null = null;

  // 去抖动定时器
  private syncTimer: number = -1;
  private readonly SYNC_DELAY_MS = 400;

  // Widget 更新的防抖定时器
  private widgetUpdateTimer: number = -1;
  private readonly WIDGET_UPDATE_DELAY_MS = 500;

  // 🔥 新增：并发控制状态
  private isSyncing: boolean = false;      // 是否正在同步中
  private hasPendingSync: boolean = false; // 是否在同步期间又有新请求

  private constructor() {
    this.db = DatabaseHelper.getInstance();
  }

  public static getInstance(): TaskRepository {
    if (!TaskRepository.instance) {
      TaskRepository.instance = new TaskRepository();
    }
    return TaskRepository.instance;
  }

  public setContext(context: common.Context) {
    this.context = context;
  }

  private async ensureDbReady(): Promise<void> {
    if (this.db.isReady()) return;

    console.warn('[TaskRepo] DB not ready. Polling...');
    if (this.context) {
      this.db.init(this.context);
    }

    const maxRetries = 40;
    for (let i = 0; i < maxRetries; i++) {
      if (this.db.isReady()) return;
      await new Promise<void>(resolve => setTimeout(resolve, 50));
    }
    throw new Error('[TaskRepo] Fatal: DB Init Timeout.');
  }

  // ==========================================
  // 核心：调度逻辑 (防抖 + 串行化)
  // ==========================================
  private scheduleSync() {
    // 1. 防抖：如果有未执行的定时器，重置它
    if (this.syncTimer !== -1) {
      clearTimeout(this.syncTimer);
    }

    // 2. 检查开关
    if (!LocalValues.getInstance().getCloudSyncEnable()) {
      return;
    }

    // 3. 启动定时器
    this.syncTimer = setTimeout(() => {
      this.performSync();
    }, this.SYNC_DELAY_MS);
  }

  /**
   * 真正执行同步的方法 (串行控制)
   */
  private async performSync() {
    // A. 如果当前正在同步，不要打断，标记“稍后再试”并退出
    if (this.isSyncing) {
      console.info('[TaskRepo] Sync is running. Marking pending...');
      this.hasPendingSync = true;
      return;
    }

    // B. 开始同步
    this.isSyncing = true;
    this.hasPendingSync = false; // 清除标记

    console.info('[TaskRepo] Starting auto-sync...');

    try {
      const GeneratedDestructObj_1 = LocalValues.getInstance().getWebDavAuth();
      const user = GeneratedDestructObj_1.user;
      const pass = GeneratedDestructObj_1.pass;
      const url = LocalValues.getInstance().getWebDavUrl();

      if (url) {
        const web = new WebUtils(url, user, pass);
        const syncService = new SyncService(this.db, web);

        await syncService.syncOnce();

        console.info('[TaskRepo] Auto-sync success.');

        // 🔥 修复：使用保存的 context 发送事件，通知 UI 刷新
        if (this.context) {
          this.context.eventHub.emit('sync_done');
        }
      }
    } catch (e) {
      console.error(`[TaskRepo] Auto-sync failed: ${e}`);
    } finally {
      // C. 同步结束，释放锁
      this.isSyncing = false;

      // D. 检查在同步期间是否有新请求
      if (this.hasPendingSync) {
        console.info('[TaskRepo] Found pending request. Syncing again immediately...');
        // 递归调用（或者再次 setTimeout），处理积压的变更
        this.performSync();
      }
    }
  }

  // ==========================================
  // 增删改查
  // ==========================================

  async insertDDL(params: DDLInsertParams): Promise<number> {
    await this.ensureDbReady();
    const id = await this.db.insertDDL(params);
    this.scheduleSync(); // 触发调度
    this.scheduleWidgetUpdate();
    return id;
  }

  async updateDDL(item: DDLItem): Promise<void> {
    await this.ensureDbReady();
    await this.db.updateDDL(item);
    this.scheduleSync(); // 触发调度
    this.scheduleWidgetUpdate();
  }

  async deleteDDL(id: number): Promise<void> {
    await this.ensureDbReady();
    await this.db.deleteDDL(id);
    this.scheduleSync(); // 触发调度
    this.scheduleWidgetUpdate();
  }

  async getAllDDLs(): Promise<DDLItem[]> {
    await this.ensureDbReady();
    return this.db.getAllDDLs();
  }

  async getDDLsByType(type: DeadlineType): Promise<DDLItem[]> {
    await this.ensureDbReady();
    return this.db.getDDLsByType(type);
  }

  private scheduleWidgetUpdate() {
    // 1. 如果已有挂起的更新任务，取消它（重新计时）
    if (this.widgetUpdateTimer !== -1) {
      clearTimeout(this.widgetUpdateTimer);
    }

    // 2. 启动新的定时器
    this.widgetUpdateTimer = setTimeout(() => {
      this.performWidgetUpdate();
    }, this.WIDGET_UPDATE_DELAY_MS);
  }

  private performWidgetUpdate() {
    const context = this.context;
    if (context) {
      console.info('[TaskRepo] Updating widgets now...');
      WidgetUpdater.updateAllWidgets(context);
    }
    this.widgetUpdateTimer = -1;
  }

  // ==========================================
  // 手动同步
  // ==========================================
  async syncNow(): Promise<boolean> {
    await this.ensureDbReady();

    // 取消由于防抖挂起的任务，直接插队执行
    if (this.syncTimer !== -1) {
      clearTimeout(this.syncTimer);
      this.syncTimer = -1;
    }

    // 复用串行逻辑，防止手动和自动冲突
    // 但 syncNow 需要返回结果，所以这里特殊处理一下，等待 performSync 完成不太容易
    // 简单起见，手动同步强制执行逻辑（需注意，如果正在自动同步，可能会冲突，
    // 更好的做法是让 syncNow 也走 performSync 逻辑，或者等待锁释放）

    // 这里采用简单策略：如果正在同步，直接报错或返回 false
    if (this.isSyncing) {
      console.warn('[TaskRepo] Sync already running. Manual sync ignored.');
      return false;
    }

    this.isSyncing = true;
    try {
      const webAuth = LocalValues.getInstance().getWebDavAuth();
      const user = webAuth.user;
      const pass = webAuth.pass;
      const url = LocalValues.getInstance().getWebDavUrl();
      if (!url) return false;

      const web = new WebUtils(url, user, pass);
      const syncService = new SyncService(this.db, web);
      const result = await syncService.syncOnce();

      if (result && this.context) {
        this.context.eventHub.emit('sync_done');
        this.performWidgetUpdate();
      }
      return result;
    } finally {
      this.isSyncing = false;
      // 手动同步完，也检查一下pending
      if (this.hasPendingSync) {
        this.performSync();
      }
    }
  }
}