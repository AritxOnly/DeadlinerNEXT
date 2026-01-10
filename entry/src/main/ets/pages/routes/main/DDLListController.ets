export interface DDLListController {
  requestBatchComplete: () => void;
  requestBatchArchive: () => void;
  requestBatchDelete: () => void;
  requestBatchEdit: () => void;
  requestExitSelection: () => void;
  requestSetAlarm: () => void;
  loadData: () => void;
}