export interface DDLListController {
  requestBatchComplete: () => void;
  requestBatchArchive: () => void;
  requestBatchDelete: () => void;
  requestBatchEdit: () => void;
  requestExitSelection: () => void;
  loadData: () => void;
}