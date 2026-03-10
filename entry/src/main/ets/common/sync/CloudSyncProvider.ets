import { ISyncProvider, SyncResultProvider } from './SyncProvider';
import { SnapshotRoot } from './SyncService';
import { cloudSync, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export class CloudSyncProvider implements ISyncProvider {
  private readonly fileName = "snapshot-v1.json";
  private cloudBaseDir: string;
  private fileSync = new cloudSync.FileSync();

  constructor(context: common.Context) {
    this.cloudBaseDir = (context as common.UIAbilityContext).cloudFileDir;
  }

  private getFilePath(): string {
    return `${this.cloudBaseDir}/${this.fileName}`;
  }

  async getRemoteSnapshot(): Promise<SyncResultProvider> {
    const filePath = this.getFilePath();
    try {
      let exists = false;

      try {
        exists = fs.accessSync(filePath);
      } catch (e) {
        exists = false;
      }

      if (!exists) {
        return { success: true, snapshot: null };
      }

      const fileContent = fs.readTextSync(filePath);
      const snapshot = JSON.parse(fileContent) as SnapshotRoot;

      if (fileContent.length > 1000 && (!snapshot.items || !Array.isArray(snapshot.items))) {
        console.error("[CloudSync] Invalid JSON format from cloud file.");
        return { success: false, snapshot: null };
      }

      if (!snapshot.items) snapshot.items = [];
      return { success: true, snapshot: snapshot };

    } catch (e) {
      console.error(`[CloudSync] Read remote snapshot failed: ${e}`);
      return { success: false, snapshot: null };
    }
  }

  async putMergedSnapshot(merged: SnapshotRoot): Promise<boolean> {
    const filePath = this.getFilePath();
    const tmpPath = filePath + '.tmp';

    try {
      const jsonStr = JSON.stringify(merged);

      const file = fs.openSync(tmpPath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, jsonStr);
      fs.closeSync(file);

      try {
        if (fs.accessSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      } catch (e) {
      }

      fs.renameSync(tmpPath, filePath);

      console.info("[CloudSync] Write merged snapshot success (Atomic)");
      return true;
    } catch (e) {
      console.error(`[CloudSync] Write merged snapshot failed: ${e}`);
      return false;
    }
  }

  async triggerSync(): Promise<void> {
    try {
      await this.fileSync.start();
    } catch (e) {
      console.warn(`[CloudSync] triggerSync failed: ${JSON.stringify(e)}`);
    }
  }
}