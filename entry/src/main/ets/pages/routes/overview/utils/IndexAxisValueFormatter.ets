import { IAxisValueFormatter, AxisBase } from '@ohos/mpchart';

export class IndexAxisValueFormatter implements IAxisValueFormatter {
  private labels: string[];

  constructor(labels: string[]) {
    this.labels = labels;
  }

  getFormattedValue(value: number, axis: AxisBase): string {
    const index = Math.round(value);
    if (index < 0 || index >= this.labels.length) {
      return "";
    }
    return this.labels[index];
  }
}