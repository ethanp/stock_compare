import 'package:powersync/powersync.dart';
import 'package:stock_compare/model/comparison_view.dart';
import 'package:stock_compare/model/visible_range_preset.dart';
import 'package:uuid/uuid.dart';

class ComparisonViewsDao(final PowerSyncDatabase _powerSync) {
  static const _uuid = Uuid();

  Stream<List<ComparisonView>> watchAll() {
    return _powerSync
        .watch(
          'SELECT * FROM comparison_views '
          'WHERE is_deleted = 0 '
          'ORDER BY sort_order ASC, name COLLATE NOCASE ASC',
        )
        .map(
          (viewRows) => [
            for (final viewRow in viewRows) ComparisonView.fromRow(viewRow),
          ],
        );
  }

  Future<List<ComparisonView>> getAll() async {
    final viewRows = await _powerSync.getAll(
      'SELECT * FROM comparison_views '
      'WHERE is_deleted = 0 '
      'ORDER BY sort_order ASC, name COLLATE NOCASE ASC',
    );
    return [for (final viewRow in viewRows) ComparisonView.fromRow(viewRow)];
  }

  Future<ComparisonView> create({
    required String name,
    required List<String> tickers,
    required VisibleRangePreset rangePreset,
    DateTime? startDate,
    int sortOrder = 0,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final view = ComparisonView(
      id: _uuid.v4(),
      name: name.trim(),
      tickers: tickers,
      rangePreset: rangePreset,
      startDate: startDate,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
    await upsert(view);
    return view;
  }

  Future<void> upsert(ComparisonView view) async {
    await _powerSync.execute(
      'INSERT OR REPLACE INTO comparison_views '
      '(id, name, tickers, range_preset, start_date, sort_order, '
      'created_at, updated_at, is_deleted) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)',
      [
        view.id,
        view.name.trim(),
        view.tickersField,
        view.rangePreset.name,
        view.startDateIso,
        view.sortOrder,
        view.createdAt.toUtc().toIso8601String(),
        view.updatedAt.toUtc().toIso8601String(),
      ],
    );
  }

  Future<void> softDelete(String viewId) async {
    final String nowIso = DateTime.now().toUtc().toIso8601String();
    await _powerSync.execute(
      'UPDATE comparison_views '
      'SET is_deleted = 1, updated_at = ? '
      'WHERE id = ?',
      [nowIso, viewId],
    );
  }
}
