import { ISyncProvider, SyncResultProvider } from './SyncProvider';
import { SnapshotRoot } from './SyncService';
import { cloudSync, fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';

export class CloudSyncProvider implements ISyncProvider {
  private readonly fileName = "snapshot-v1.json";
  private readonly dirName = "Deadliner";
  private cloudBaseDir: string;
  private fileSync = new cloudSync.FileSync();

  constructor(context: common.Context) {
    // 获取端云协同的沙箱根目录
    this.cloudBaseDir = (context as common.UIAbilityContext).cloudFileDir;
    this.ensureDirSync();
  }

  // 确保 Deadliner 文件夹存在
  private ensureDirSync() {
    const targetDir = `${this.cloudBaseDir}/${this.dirName}`;
    if (!fs.accessSync(targetDir)) {
      fs.mkdirSync(targetDir);
    }
  }

  private getFilePath(): string {
    return `${this.cloudBaseDir}/${this.dirName}/${this.fileName}`;
  }

  async getRemoteSnapshot(): Promise<SyncResultProvider> {
    const filePath = this.getFilePath();
    try {
      if (!fs.accessSync(filePath)) {
        return { success: true, snapshot: null }; // 首次运行，没有远端数据
      }

      const fileContent = fs.readTextSync(filePath);
      const snapshot = JSON.parse(fileContent) as SnapshotRoot;

      // 熔断保护：如果文件非空但解析不出 items，说明文件损坏
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
    try {
      const jsonStr = JSON.stringify(merged);
      // 打开文件，使用截断并写入模式 (TRUNC | WRITE)
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, jsonStr);
      fs.closeSync(file);

      // 注意：写入完成后，鸿蒙底层的云同步守护进程会自动把这个文件传上云端！
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