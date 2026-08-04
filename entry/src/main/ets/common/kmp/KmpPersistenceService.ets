import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import {
  bridgeVersion,
  close,
  diagnosticsJson,
  health,
  initialize,
  importLegacyV2,
  importCapturesJson,
  mergeLegacyV2PayloadsJson,
  syncWebDavChangeLogJson,
  syncWebDavChangeLogJsonAsync,
  taskListViewModelJson,
  overviewViewModelJsonAsync,
  taskCreateJson,
  taskUpdateJson,
  taskActionJson,
  taskDeleteJson,
  habitStateJson,
  habitCreateJson,
  habitUpdateJson,
  habitStatusActionJson,
  habitToggleRecordJson,
  habitSaveRecordJson,
  habitClearRecordsJson,
  habitDeleteJson,
  captureStateJson,
  captureCreateJson,
  captureUpdateJson,
  captureDeleteJson,
  memoryProfileStateJson,
  importMemoryProfileJson,
  memorySaveJson,
  memoryDeleteJson,
  profileSaveJson,
  lifiProcessInputAsync,
  lifiSubmitToolResultAsync,
  lifiExtractTasksJsonAsync,
  lifiExtractHabitsJsonAsync,
  lifiGenerateMonthlyAnalysisJsonAsync,
  lifiDrainEventsJson,
  lifiPendingEventCount,
  lifiReset
} from 'libdeadliner_persistence.so';

export class KmpPersistenceService {
  private static instance: KmpPersistenceService;
  private static readonly PREFERENCE_NAME: string = 'kmp_persistence_state';
  private static readonly INSTALLATION_ID_KEY: string = 'installation_id';
  private static readonly DATABASE_DIRECTORY_NAME: string = 'kmp_persistence';
  private initialized: boolean = false;

  public static getInstance(): KmpPersistenceService {
    if (!KmpPersistenceService.instance) {
      KmpPersistenceService.instance = new KmpPersistenceService();
    }
    return KmpPersistenceService.instance;
  }

  public async initialize(context: common.Context): Promise<void> {
    if (this.initialized && health() === 1) {
      return;
    }

    const installationId: string = await this.getInstallationId(context);
    const databaseDirectory: string = context.filesDir + '/' + KmpPersistenceService.DATABASE_DIRECTORY_NAME;
    await this.ensureDatabaseDirectory(databaseDirectory);
    const result: number = initialize(databaseDirectory, installationId);
    if (result !== 1) {
      throw new Error('KMP persistence initialization failed');
    }
    this.initialized = true;
  }

  private async ensureDatabaseDirectory(databaseDirectory: string): Promise<void> {
    try {
      await fileIo.mkdir(databaseDirectory);
      return;
    } catch (err) {
      const stat = fileIo.statSync(databaseDirectory);
      if (!stat.isDirectory()) {
        throw new Error('KMP database path is not a directory: ' + databaseDirectory);
      }
    }
  }

  public isReady(): boolean {
    return this.initialized && health() === 1;
  }

  public bridgeVersion(): number {
    return bridgeVersion();
  }

  public importLegacyV2(taskPayload: string, habitPayload: string): number {
    if (!this.isReady()) {
      throw new Error('KMP persistence is not initialized');
    }

    const result: number = importLegacyV2(taskPayload, habitPayload);
    if (result < 0) {
      throw new Error('KMP persistence legacy import failed');
    }
    return result;
  }

  public importCapturesJson(payload: string): number {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const result: number = importCapturesJson(payload);
    if (result < 0) throw new Error('KMP capture import failed');
    return result;
  }

  public captureStateJson(): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const state: string = captureStateJson();
    if (state.length === 0) throw new Error('KMP capture ViewModel did not return state');
    return state;
  }

  public captureCreateJson(payload: string): string { return this.captureMutation(payload, true); }
  public captureUpdateJson(payload: string): string { return this.captureMutation(payload, false); }
  public captureDeleteJson(uid: string, updatedAt: string): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const state: string = captureDeleteJson(uid, updatedAt);
    if (state.length === 0) throw new Error('KMP capture deletion failed');
    return state;
  }

  public memoryProfileStateJson(): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const state: string = memoryProfileStateJson();
    if (state.length === 0) throw new Error('KMP memory/profile state unavailable');
    return state;
  }

  public importMemoryProfileJson(payload: string): number {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const result: number = importMemoryProfileJson(payload);
    if (result < 0) throw new Error('KMP memory/profile import failed');
    return result;
  }

  public memorySaveJson(payload: string): string { return this.memoryMutation(payload, true); }
  public profileSaveJson(payload: string): string { return this.memoryMutation(payload, false); }

  public memoryDeleteJson(uid: string, updatedAt: string): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const state: string = memoryDeleteJson(uid, updatedAt);
    if (state.length === 0) throw new Error('KMP memory deletion failed');
    return state;
  }

  public diagnosticsJson(): string {
    if (!this.isReady()) {
      throw new Error('KMP persistence is not initialized');
    }
    return diagnosticsJson();
  }

  public mergeLegacyV2PayloadsJson(taskPayload: string, habitPayload: string): string {
    if (!this.isReady()) {
      throw new Error('KMP persistence is not initialized');
    }
    const mergedPayload: string = mergeLegacyV2PayloadsJson(taskPayload, habitPayload);
    if (mergedPayload.length === 0) {
      throw new Error('KMP legacy V2 snapshot merge failed');
    }
    return mergedPayload;
  }

  public async syncWebDavChangeLogJson(baseUrl: string, username: string, password: string): Promise<string> {
    if (!this.isReady()) {
      throw new Error('KMP persistence is not initialized');
    }
    const resultPayload: string = await syncWebDavChangeLogJsonAsync(baseUrl, username, password);
    if (resultPayload.length === 0) {
      throw new Error('KMP WebDAV changelog sync failed');
    }
    return resultPayload;
  }

  public taskListViewModelJson(): string {
    if (!this.isReady()) {
      throw new Error('KMP persistence is not initialized');
    }
    const statePayload: string = taskListViewModelJson();
    if (statePayload.length === 0) {
      throw new Error('KMP task list ViewModel did not return state');
    }
    return statePayload;
  }

  public async overviewViewModelJson(): Promise<string> {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = await overviewViewModelJsonAsync();
    if (statePayload.length === 0) throw new Error('KMP overview ViewModel did not return state');
    return statePayload;
  }

  public async lifiProcessInput(configPayload: string, text: string): Promise<void> {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    if (await lifiProcessInputAsync(configPayload, text) !== 1) throw new Error('KMP Lifi input failed');
  }

  public async lifiSubmitToolResult(toolCallId: string, tool: string, payload: string): Promise<void> {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    if (await lifiSubmitToolResultAsync(toolCallId, tool, payload) !== 1) {
      throw new Error('KMP Lifi tool continuation failed');
    }
  }

  public async lifiExtractTasksJson(configPayload: string, text: string): Promise<string> {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const payload: string = await lifiExtractTasksJsonAsync(configPayload, text);
    if (payload.length === 0) throw new Error('KMP Lifi task extraction failed');
    return payload;
  }

  public async lifiExtractHabitsJson(configPayload: string, text: string): Promise<string> {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const payload: string = await lifiExtractHabitsJsonAsync(configPayload, text);
    if (payload.length === 0) throw new Error('KMP Lifi habit extraction failed');
    return payload;
  }

  public async lifiGenerateMonthlyAnalysisJson(configPayload: string, requestPayload: string): Promise<string> {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const payload: string = await lifiGenerateMonthlyAnalysisJsonAsync(configPayload, requestPayload);
    if (payload.length === 0) throw new Error('KMP Lifi monthly analysis failed');
    return payload;
  }

  public lifiDrainEventsJson(): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    return lifiDrainEventsJson();
  }

  public lifiPendingEventCount(): number {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    return lifiPendingEventCount();
  }

  public lifiReset(): void {
    if (this.isReady() && lifiReset() !== 1) throw new Error('KMP Lifi reset failed');
  }

  public taskCreateJson(taskPayload: string): string { return this.taskMutationJson(taskPayload, true); }
  public taskUpdateJson(taskPayload: string): string { return this.taskMutationJson(taskPayload, false); }

  public taskActionJson(uid: string, actionPayload: string): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = taskActionJson(uid, actionPayload);
    if (statePayload.length === 0) throw new Error('KMP task action failed');
    return statePayload;
  }

  public taskDeleteJson(uid: string, updatedAt: string): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = taskDeleteJson(uid, updatedAt);
    if (statePayload.length === 0) throw new Error('KMP task deletion failed');
    return statePayload;
  }

  public habitStateJson(): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = habitStateJson();
    if (statePayload.length === 0) throw new Error('KMP habit ViewModel did not return state');
    return statePayload;
  }

  public habitCreateJson(habitPayload: string): string { return this.habitMutationJson(habitPayload, true); }
  public habitUpdateJson(habitPayload: string): string { return this.habitMutationJson(habitPayload, false); }

  public habitStatusActionJson(uid: string, actionPayload: string): string {
    return this.habitKeyMutationJson(uid, actionPayload, true);
  }

  public habitToggleRecordJson(uid: string, recordPayload: string): string {
    return this.habitKeyMutationJson(uid, recordPayload, false);
  }

  public habitSaveRecordJson(recordPayload: string): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = habitSaveRecordJson(recordPayload);
    if (statePayload.length === 0) throw new Error('KMP habit record mutation failed');
    return statePayload;
  }

  public habitClearRecordsJson(uid: string, recordPayload: string): string {
    return this.habitKeyMutationJson(uid, recordPayload, false, true);
  }

  public habitDeleteJson(uid: string, updatedAt: string): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = habitDeleteJson(uid, updatedAt);
    if (statePayload.length === 0) throw new Error('KMP habit deletion failed');
    return statePayload;
  }

  private taskMutationJson(taskPayload: string, isCreate: boolean): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = isCreate ? taskCreateJson(taskPayload) : taskUpdateJson(taskPayload);
    if (statePayload.length === 0) throw new Error('KMP task mutation failed');
    return statePayload;
  }

  private captureMutation(payload: string, create: boolean): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const state: string = create ? captureCreateJson(payload) : captureUpdateJson(payload);
    if (state.length === 0) throw new Error('KMP capture mutation failed');
    return state;
  }

  private memoryMutation(payload: string, isMemory: boolean): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const state: string = isMemory ? memorySaveJson(payload) : profileSaveJson(payload);
    if (state.length === 0) throw new Error('KMP memory/profile mutation failed');
    return state;
  }

  private habitMutationJson(habitPayload: string, isCreate: boolean): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = isCreate ? habitCreateJson(habitPayload) : habitUpdateJson(habitPayload);
    if (statePayload.length === 0) throw new Error('KMP habit mutation failed');
    return statePayload;
  }

  private habitKeyMutationJson(uid: string, payload: string, isStatusAction: boolean, isClearRecords: boolean = false): string {
    if (!this.isReady()) throw new Error('KMP persistence is not initialized');
    const statePayload: string = isStatusAction ? habitStatusActionJson(uid, payload) :
      (isClearRecords ? habitClearRecordsJson(uid, payload) : habitToggleRecordJson(uid, payload));
    if (statePayload.length === 0) throw new Error('KMP habit mutation failed');
    return statePayload;
  }


  public close(): void {
    close();
    this.initialized = false;
  }

  private async getInstallationId(context: common.Context): Promise<string> {
    const store: preferences.Preferences = await preferences.getPreferences(context, KmpPersistenceService.PREFERENCE_NAME);
    const storedValue = await store.get(KmpPersistenceService.INSTALLATION_ID_KEY, '');
    if (typeof storedValue === 'string' && storedValue.length > 0) {
      return storedValue;
    }

    const generatedId: string = util.generateRandomUUID(true);
    await store.put(KmpPersistenceService.INSTALLATION_ID_KEY, generatedId);
    await store.flush();
    return generatedId;
  }
}
