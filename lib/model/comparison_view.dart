import 'package:stock_compare/model/ticker_price_loader.dart';
import 'package:stock_compare/model/visible_range_preset.dart';

class const ComparisonView({
  required final String id,
  required final String name,
  required final List<String> tickers,
  required final VisibleRangePreset rangePreset,
  final DateTime? startDate,
  final int sortOrder = 0,
  required final DateTime createdAt,
  required final DateTime updatedAt,
}) {
  factory fromRow(Map<String, dynamic> row) {
    final String? startDateRaw = row['start_date'] as String?;
    return ComparisonView(
      id: row['id'] as String,
      name: row['name'] as String,
      tickers: TickerPriceLoader.tickersFromField(
        (row['tickers'] as String?) ?? '',
      ),
      rangePreset: VisibleRangePreset.fromSavedName(
        row['range_preset'] as String?,
      ),
      startDate: startDateRaw == null || startDateRaw.isEmpty
          ? null
          : DateTime.tryParse(startDateRaw),
      sortOrder: (row['sort_order'] as int?) ?? 0,
      createdAt:
          DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse((row['updated_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get tickersField => tickers.join(', ');

  String? get startDateIso {
    if (startDate == null) return null;
    final String year = startDate!.year.toString().padLeft(4, '0');
    final String month = startDate!.month.toString().padLeft(2, '0');
    final String day = startDate!.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String get summaryCaption {
    final String startCaption = startDateIso == null
        ? rangePreset.chipLabel
        : 'from $startDateIso · ${rangePreset.chipLabel}';
    return '$tickersField · $startCaption';
  }

  ComparisonView copyWith({
    String? name,
    List<String>? tickers,
    VisibleRangePreset? rangePreset,
    DateTime? startDate,
    bool clearStartDate = false,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return ComparisonView(
      id: id,
      name: name ?? this.name,
      tickers: tickers ?? this.tickers,
      rangePreset: rangePreset ?? this.rangePreset,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
