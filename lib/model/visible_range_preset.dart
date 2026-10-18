import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';

enum VisibleRangePreset({
  final int? dayCount,
  required final String chipLabel,
}) {
  oneMonth(dayCount: 30, chipLabel: '1M'),
  sixMonths(dayCount: 182, chipLabel: '6M'),
  oneYear(dayCount: 365, chipLabel: '1Y'),
  fiveYears(dayCount: 1825, chipLabel: '5Y'),
  all(chipLabel: 'All');

  static VisibleRangePreset fromSavedName(String? rawName) {
    if (rawName == null) return VisibleRangePreset.oneYear;
    for (final preset in VisibleRangePreset.values) {
      if (preset.name == rawName) return preset;
    }
    return VisibleRangePreset.oneYear;
  }

  EChartVisibleRange rangeThrough({
    required DateTime earliest,
    required DateTime latest,
  }) {
    if (dayCount == null) {
      return EChartVisibleRange(start: earliest, end: latest);
    }
    return EChartVisibleRange(
      start: latest.shiftedByDays(-(dayCount! - 1)),
      end: latest,
    ).clampedTo(earliest: earliest, latest: latest);
  }
}
