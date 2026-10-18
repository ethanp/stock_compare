import 'dart:convert';
import 'dart:io';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_compare/model/comparison_view.dart';
import 'package:stock_compare/model/ticker_price_history.dart';
import 'package:stock_compare/model/ticker_price_loader.dart';
import 'package:stock_compare/model/visible_range_preset.dart';
import 'package:stock_compare/providers/stock_compare_providers.dart';
import 'package:stock_compare/services/ticker_candle_cache.dart';
import 'package:stock_compare/ui/pages/portfolio_page.dart';
import 'package:stock_compare/ui/pages/stock_compare_page.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

const _phoneSize = Size(390, 844);

void main() {
  late _HistoricalMarketFixture marketFixture;

  setUpAll(() async {
    await ETheme.loadFontsForWidgetTests();
    marketFixture = _HistoricalMarketFixture.loadFromDisk();
  });

  testWidgets('writes GOOG vs AAPL 1Y chart for README', (tester) async {
    await marketFixture.writeScreenshot(
      tester,
      home: const StockComparePage(),
      afterPump: (tester) async {
        await tester.tap(find.widgetWithText(EFilterChip, 'GOOG, AAPL'));
        await tester.pumpAndSettle();
      },
      screenshotFilename: 'goog-vs-aapl.png',
    );
  });

  testWidgets('writes multi-ticker 5Y comparison chart for README', (
    tester,
  ) async {
    await marketFixture.writeScreenshot(
      tester,
      home: StockComparePage(initialView: marketFixture.bigTechFiveYearView),
      screenshotFilename: 'big-tech-5y.png',
    );
  });

  testWidgets('writes saved comparisons portfolio for README', (tester) async {
    await marketFixture.writeScreenshot(
      tester,
      home: const PortfolioPage(),
      screenshotFilename: 'saved-comparisons.png',
    );
  });
}

class _HistoricalMarketFixture(
  final Map<String, List<YahooFinanceCandleData>> _candlesByTicker,
) {
  static final DateTime _snapshotTime = DateTime.utc(2026, 10, 16, 20);

  static _HistoricalMarketFixture loadFromDisk() {
    final String rawJson = File(
      'test/readme_screenshot_candles.json',
    ).readAsStringSync();
    final Map<String, dynamic> decoded =
        jsonDecode(rawJson) as Map<String, dynamic>;
    final candlesByTicker = <String, List<YahooFinanceCandleData>>{};
    for (final entry in decoded.entries) {
      final candleRows = (entry.value as List<dynamic>)
          .cast<Map<String, dynamic>>();
      candlesByTicker[entry.key] = [
        for (final candleRow in candleRows)
          YahooFinanceCandleData(
            date: DateTime.parse(candleRow['d'] as String),
            adjClose: (candleRow['c'] as num).toDouble(),
            close: (candleRow['c'] as num).toDouble(),
          ),
      ];
    }
    return _HistoricalMarketFixture(candlesByTicker);
  }

  ComparisonView get googVsAaplOneYearView => ComparisonView(
    id: 'view-goog-aapl-1y',
    name: 'GOOG vs AAPL',
    tickers: const ['GOOG', 'AAPL'],
    rangePreset: VisibleRangePreset.oneYear,
    sortOrder: 0,
    createdAt: _snapshotTime,
    updatedAt: _snapshotTime,
  );

  ComparisonView get bigTechFiveYearView => ComparisonView(
    id: 'view-big-tech-5y',
    name: 'Big Tech (5Y)',
    tickers: const ['GOOG', 'AAPL', 'AMZN'],
    rangePreset: VisibleRangePreset.fiveYears,
    sortOrder: 1,
    createdAt: _snapshotTime,
    updatedAt: _snapshotTime,
  );

  List<ComparisonView> get savedViews => [
    googVsAaplOneYearView,
    bigTechFiveYearView,
    ComparisonView(
      id: 'view-post-2023-rally',
      name: 'Post-2022 Recovery',
      tickers: const ['GOOG', 'AMZN', 'AAPL'],
      rangePreset: VisibleRangePreset.all,
      startDate: DateTime(2023, 1, 3),
      sortOrder: 2,
      createdAt: _snapshotTime,
      updatedAt: _snapshotTime,
    ),
    ComparisonView(
      id: 'view-six-month-check',
      name: 'Trailing 6 Months',
      tickers: const ['AAPL', 'GOOG'],
      rangePreset: VisibleRangePreset.sixMonths,
      sortOrder: 3,
      createdAt: _snapshotTime,
      updatedAt: _snapshotTime,
    ),
  ];

  TickerPriceLoader createPriceLoader() {
    return TickerPriceLoader(
      candleStore: _FixtureCandleStore(_candlesByTicker, _snapshotTime),
      now: () => _snapshotTime,
    );
  }

  Future<void> writeScreenshot(
    WidgetTester tester, {
    required Widget home,
    Future<void> Function(WidgetTester tester)? afterPump,
    required String screenshotFilename,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_phoneSize);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comparisonViewsStreamProvider.overrideWith(
              (ref) => Stream.value(savedViews),
            ),
            tickerPriceLoaderProvider.overrideWith(
              (ref) async => createPriceLoader(),
            ),
            syncStatusDetailsProvider.overrideWith(
              (ref) => SyncStatusDetails(
                phase: SyncPhase.synced,
                caption: 'Synced',
                connected: true,
                lastSyncedAt: _snapshotTime,
              ),
            ),
          ],
          child: MaterialApp(
            theme: ETheme.material3Dark,
            debugShowCheckedModeBanner: false,
            home: home,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (afterPump != null) {
        await afterPump(tester);
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../screenshots/$screenshotFilename'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }
}

class const _FixtureCandleStore(
  final Map<String, List<YahooFinanceCandleData>> _candlesByTicker,
  final DateTime _fetchedAt,
) implements TickerCandleStore {

  @override
  Future<DateTime?> lastFetchedAt(String ticker) async => _fetchedAt;

  @override
  bool isFreshToday(DateTime? fetchedAt, {DateTime? now}) => true;

  @override
  Future<TickerPriceHistory?> readHistory(
    String ticker, {
    DateTime? startDate,
  }) async {
    final List<YahooFinanceCandleData>? allCandles = _candlesByTicker[ticker];
    if (allCandles == null) return null;
    final List<YahooFinanceCandleData> filtered = startDate == null
        ? allCandles
        : [
            for (final candle in allCandles)
              if (!candle.date.isBefore(startDate)) candle,
          ];
    return TickerPriceHistory(ticker: ticker, candles: filtered);
  }

  @override
  Future<void> saveCandles({
    required String ticker,
    required List<YahooFinanceCandleData> candles,
    DateTime? fetchedAt,
  }) async {}
}
