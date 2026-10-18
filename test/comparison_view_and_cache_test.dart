import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_compare/model/comparison_view.dart';
import 'package:stock_compare/model/ticker_price_history.dart';
import 'package:stock_compare/model/ticker_price_loader.dart';
import 'package:stock_compare/model/visible_range_preset.dart';
import 'package:stock_compare/services/ticker_candle_cache.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

class _FakeCandleStore() implements TickerCandleStore {
  final Map<String, List<YahooFinanceCandleData>> candlesByTicker = {};
  final Map<String, DateTime> fetchedAtByTicker = {};

  @override
  Future<TickerPriceHistory?> readHistory(
    String ticker, {
    DateTime? startDate,
  }) async {
    final candles = candlesByTicker[ticker];
    if (candles == null || candles.isEmpty) return null;
    final filtered = startDate == null
        ? candles
        : [
            for (final candle in candles)
              if (!candle.date.startOfDay.isBefore(startDate.startOfDay))
                candle,
          ];
    if (filtered.isEmpty) return null;
    return TickerPriceHistory(ticker: ticker, candles: filtered);
  }

  @override
  Future<DateTime?> lastFetchedAt(String ticker) async =>
      fetchedAtByTicker[ticker];

  @override
  Future<void> saveCandles({
    required String ticker,
    required List<YahooFinanceCandleData> candles,
    required DateTime fetchedAt,
  }) async {
    candlesByTicker[ticker] = candles;
    fetchedAtByTicker[ticker] = fetchedAt;
  }

  @override
  bool isFreshToday(DateTime? fetchedAt, {DateTime? now}) {
    if (fetchedAt == null) return false;
    final DateTime reference = (now ?? DateTime.now()).toLocal().startOfDay;
    return fetchedAt.toLocal().startOfDay == reference;
  }
}

class _FakeYahooFinanceService({final bool shouldThrow = false})
    implements YahooFinanceService {
  int downloadCalls = 0;

  @override
  Future<List<YahooFinanceCandleData>> getTickerData(
    String symbol, {
    bool useCache = true,
    DateTime? startDate,
    bool adjust = false,
  }) async {
    downloadCalls++;
    if (shouldThrow) throw StateError('network offline');
    return [
      YahooFinanceCandleData(date: DateTime(2024, 1, 1), adjClose: 100),
      YahooFinanceCandleData(date: DateTime(2025, 1, 1), adjClose: 150),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('ComparisonView maps from SQLite row and formats captions', () {
    final view = ComparisonView.fromRow({
      'id': 'view-1',
      'name': 'Big Tech',
      'tickers': 'goog, aapl, goog',
      'range_preset': 'fiveYears',
      'start_date': '2020-03-15',
      'sort_order': 2,
      'created_at': '2026-10-18T10:00:00.000Z',
      'updated_at': '2026-10-18T11:00:00.000Z',
      'is_deleted': 0,
    });

    expect(view.id, 'view-1');
    expect(view.name, 'Big Tech');
    expect(view.tickers, ['GOOG', 'AAPL']);
    expect(view.tickersField, 'GOOG, AAPL');
    expect(view.rangePreset, VisibleRangePreset.fiveYears);
    expect(view.startDateIso, '2020-03-15');
    expect(view.summaryCaption, 'GOOG, AAPL · from 2020-03-15 · 5Y');
  });

  test('ComparisonView handles null start date and unknown range preset', () {
    final view = ComparisonView.fromRow({
      'id': 'view-2',
      'name': 'Default View',
      'tickers': 'MSFT',
      'range_preset': 'unknownPreset',
      'start_date': null,
      'sort_order': 0,
      'created_at': '2026-10-18T10:00:00.000Z',
      'updated_at': '2026-10-18T10:00:00.000Z',
      'is_deleted': 0,
    });

    expect(view.rangePreset, VisibleRangePreset.oneYear);
    expect(view.startDate, isNull);
    expect(view.startDateIso, isNull);
    expect(view.summaryCaption, 'MSFT · 1Y');
  });

  test('TickerPriceLoader serves from SQLite cache when fetched today', () async {
    final store = _FakeCandleStore();
    final yahoo = _FakeYahooFinanceService();
    final today = DateTime(2026, 10, 18, 14, 30);
    await store.saveCandles(
      ticker: 'GOOG',
      candles: [
        YahooFinanceCandleData(date: DateTime(2024, 1, 1), adjClose: 110),
      ],
      fetchedAt: DateTime(2026, 10, 18, 9, 0),
    );

    final loader = TickerPriceLoader(
      yahoo: yahoo,
      candleStore: store,
      now: () => today,
    );
    final outcome = await loader.loadOutcome('goog');

    expect(outcome.succeeded, isTrue);
    expect(outcome.fellBackToCache, isFalse);
    expect(outcome.history!.candles.single.adjClose, 110);
    expect(yahoo.downloadCalls, 0);
  });

  test('TickerPriceLoader downloads and caches when cache is from yesterday', () async {
    final store = _FakeCandleStore();
    final yahoo = _FakeYahooFinanceService();
    final today = DateTime(2026, 10, 18, 14, 30);
    await store.saveCandles(
      ticker: 'GOOG',
      candles: [
        YahooFinanceCandleData(date: DateTime(2024, 1, 1), adjClose: 90),
      ],
      fetchedAt: DateTime(2026, 10, 17, 23, 0),
    );

    final loader = TickerPriceLoader(
      yahoo: yahoo,
      candleStore: store,
      now: () => today,
    );
    final outcome = await loader.loadOutcome('GOOG');

    expect(outcome.succeeded, isTrue);
    expect(outcome.fellBackToCache, isFalse);
    expect(outcome.history!.candles, hasLength(2));
    expect(yahoo.downloadCalls, 1);
    expect(await store.lastFetchedAt('GOOG'), today);
  });

  test('TickerPriceLoader falls back to stale cache when download fails', () async {
    final store = _FakeCandleStore();
    final yahoo = _FakeYahooFinanceService(shouldThrow: true);
    final today = DateTime(2026, 10, 18, 14, 30);
    await store.saveCandles(
      ticker: 'GOOG',
      candles: [
        YahooFinanceCandleData(date: DateTime(2024, 1, 1), adjClose: 95),
      ],
      fetchedAt: DateTime(2026, 10, 15, 10, 0),
    );

    final loader = TickerPriceLoader(
      yahoo: yahoo,
      candleStore: store,
      now: () => today,
    );
    final outcome = await loader.loadOutcome('GOOG');

    expect(outcome.succeeded, isTrue);
    expect(outcome.fellBackToCache, isTrue);
    expect(outcome.history!.candles.single.adjClose, 95);
    expect(yahoo.downloadCalls, 1);
  });
}
