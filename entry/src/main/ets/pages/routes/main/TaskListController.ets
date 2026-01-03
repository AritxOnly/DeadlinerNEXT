import { DDLListController } from './DDLListController'

export class TaskListController implements DDLListController {
  requestBatchComplete: () => void = () => {};
  requestBatchArchive: () => void = () => {};
  requestBatchDelete: () => void = () => {};
  requestBatchEdit: () => void = () => {};
  requestExitSelection: () => void = () => {};
  loadData: () => void = () => {};
}