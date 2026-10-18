import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:stock_compare/model/ticker_price_history.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

abstract interface class TickerCandleStore() {
  Future<TickerPriceHistory?> readHistory(
    String ticker, {
    DateTime? startDate,
  });

  Future<DateTime?> lastFetchedAt(String ticker);

  Future<void> saveCandles({
    required String ticker,
    required List<YahooFinanceCandleData> candles,
    required DateTime fetchedAt,
  });

  bool isFreshToday(DateTime? fetchedAt, {DateTime? now});
}

class SqliteTickerCandleCache(final PowerSyncDatabase _powerSync)
    implements TickerCandleStore {
  @override
  Future<TickerPriceHistory?> readHistory(
    String ticker, {
    DateTime? startDate,
  }) async {
    final String normalizedTicker = ticker.trim().toUpperCase();
    final String? startIso = startDate == null
        ? null
        : _formatIsoDate(startDate);
    final candleRows = startIso == null
        ? await _powerSync.getAll(
            'SELECT date, adj_close FROM daily_candles '
            'WHERE ticker = ? ORDER BY date ASC',
            [normalizedTicker],
          )
        : await _powerSync.getAll(
            'SELECT date, adj_close FROM daily_candles '
            'WHERE ticker = ? AND date >= ? ORDER BY date ASC',
            [normalizedTicker, startIso],
          );
    if (candleRows.isEmpty) return null;
    final candles = <YahooFinanceCandleData>[];
    for (final candleRow in candleRows) {
      final DateTime? date = DateTime.tryParse(candleRow['date'] as String);
      final num? adjClose = candleRow['adj_close'] as num?;
      if (date == null || adjClose == null) continue;
      candles.add(
        YahooFinanceCandleData(date: date, adjClose: adjClose.toDouble()),
      );
    }
    if (candles.isEmpty) return null;
    return TickerPriceHistory(ticker: normalizedTicker, candles: candles);
  }

  @override
  Future<DateTime?> lastFetchedAt(String ticker) async {
    final String normalizedTicker = ticker.trim().toUpperCase();
    final fetchRow = await _powerSync.getOptional(
      'SELECT fetched_at FROM ticker_price_fetches WHERE id = ?',
      [normalizedTicker],
    );
    if (fetchRow == null) return null;
    final String? raw = fetchRow['fetched_at'] as String?;
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  @override
  Future<void> saveCandles({
    required String ticker,
    required List<YahooFinanceCandleData> candles,
    required DateTime fetchedAt,
  }) async {
    final String normalizedTicker = ticker.trim().toUpperCase();
    await _powerSync.writeTransaction((transaction) async {
      for (final candle in candles) {
        if (candle.adjClose <= 0) continue;
        final String isoDate = _formatIsoDate(candle.date);
        final String candleId = '$normalizedTicker:$isoDate';
        await transaction.execute(
          'INSERT OR REPLACE INTO daily_candles (id, ticker, date, adj_close) '
          'VALUES (?, ?, ?, ?)',
          [candleId, normalizedTicker, isoDate, candle.adjClose],
        );
      }
      await transaction.execute(
        'INSERT OR REPLACE INTO ticker_price_fetches (id, ticker, fetched_at) '
        'VALUES (?, ?, ?)',
        [
          normalizedTicker,
          normalizedTicker,
          fetchedAt.toUtc().toIso8601String(),
        ],
      );
    });
  }

  @override
  bool isFreshToday(DateTime? fetchedAt, {DateTime? now}) {
    if (fetchedAt == null) return false;
    final DateTime reference = (now ?? DateTime.now()).toLocal().startOfDay;
    return fetchedAt.toLocal().startOfDay == reference;
  }

  String _formatIsoDate(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
