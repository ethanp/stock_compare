import 'package:stock_compare/services/ticker_candle_cache.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

import 'ticker_price_history.dart';

class const TickerLoadOutcome({
  required final String ticker,
  final TickerPriceHistory? history,
  final Object? error,
  final bool fellBackToCache = false,
}) {
  factory ok(TickerPriceHistory history, {bool fellBackToCache = false}) {
    return TickerLoadOutcome(
      ticker: history.ticker,
      history: history,
      fellBackToCache: fellBackToCache,
    );
  }

  factory failed({required String ticker, required Object error}) {
    return TickerLoadOutcome(ticker: ticker, error: error);
  }

  bool get succeeded => history != null;
}

class TickerPriceLoader({
  YahooFinanceService? yahoo,
  final TickerCandleStore? candleStore,
  DateTime Function()? now,
}) {
  final YahooFinanceService _yahoo = yahoo ?? YahooFinanceService();
  final DateTime Function() _now = now ?? DateTime.now;

  static List<String> tickersFromField(String text) {
    final seen = <String>{};
    final tickers = <String>[];
    for (final part in text.split(',')) {
      final String ticker = part.trim().toUpperCase();
      if (ticker.isEmpty || seen.contains(ticker)) continue;
      seen.add(ticker);
      tickers.add(ticker);
    }
    return tickers;
  }

  Future<TickerPriceHistory> load(
    String ticker, {
    DateTime? startDate,
  }) async {
    final outcome = await loadOutcome(ticker, startDate: startDate);
    if (outcome.history != null) return outcome.history!;
    throw outcome.error ?? StateError('Failed to load $ticker');
  }

  Future<List<TickerLoadOutcome>> loadAll(
    List<String> tickers, {
    DateTime? startDate,
  }) {
    return Future.wait([
      for (final ticker in tickers) loadOutcome(ticker, startDate: startDate),
    ]);
  }

  Future<TickerLoadOutcome> loadOutcome(
    String ticker, {
    DateTime? startDate,
  }) async {
    final String normalizedTicker = ticker.trim().toUpperCase();
    final TickerCandleStore? store = candleStore;
    if (store == null) {
      return _downloadDirectly(normalizedTicker, startDate: startDate);
    }
    final DateTime? fetchedAt = await store.lastFetchedAt(normalizedTicker);
    if (store.isFreshToday(fetchedAt, now: _now())) {
      final TickerPriceHistory? cached = await store.readHistory(
        normalizedTicker,
        startDate: startDate,
      );
      if (cached != null && cached.candles.isNotEmpty) {
        return TickerLoadOutcome.ok(cached);
      }
    }
    return _downloadAndCache(
      normalizedTicker,
      store: store,
      startDate: startDate,
    );
  }

  Future<TickerLoadOutcome> _downloadAndCache(
    String ticker, {
    required TickerCandleStore store,
    DateTime? startDate,
  }) async {
    try {
      // Download full history into SQLite so any later start-date query can
      // read from the cache without re-fetching.
      final List<YahooFinanceCandleData> candles = await _yahoo.getTickerData(
        ticker,
        adjust: true,
        useCache: false,
      );
      await store.saveCandles(
        ticker: ticker,
        candles: candles,
        fetchedAt: _now(),
      );
      final TickerPriceHistory? cached = await store.readHistory(
        ticker,
        startDate: startDate,
      );
      if (cached != null) return TickerLoadOutcome.ok(cached);
      return TickerLoadOutcome.ok(
        TickerPriceHistory(ticker: ticker, candles: candles),
      );
    } catch (error) {
      final TickerPriceHistory? fallback = await store.readHistory(
        ticker,
        startDate: startDate,
      );
      if (fallback != null && fallback.candles.isNotEmpty) {
        return TickerLoadOutcome.ok(fallback, fellBackToCache: true);
      }
      return TickerLoadOutcome.failed(ticker: ticker, error: error);
    }
  }

  Future<TickerLoadOutcome> _downloadDirectly(
    String ticker, {
    DateTime? startDate,
  }) async {
    try {
      final List<YahooFinanceCandleData> candles = await _yahoo.getTickerData(
        ticker,
        startDate: startDate,
        adjust: true,
        useCache: false,
      );
      return TickerLoadOutcome.ok(
        TickerPriceHistory(ticker: ticker, candles: candles),
      );
    } catch (error) {
      return TickerLoadOutcome.failed(ticker: ticker, error: error);
    }
  }
}
