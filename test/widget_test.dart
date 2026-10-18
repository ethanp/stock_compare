import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_compare/model/comparison_view.dart';
import 'package:stock_compare/model/ticker_price_history.dart';
import 'package:stock_compare/model/ticker_price_loader.dart';
import 'package:stock_compare/model/visible_range_preset.dart';
import 'package:stock_compare/providers/stock_compare_providers.dart';
import 'package:stock_compare/ui/pages/portfolio_page.dart';
import 'package:stock_compare/ui/pages/stock_compare_page.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

class _StubPriceLoader() extends TickerPriceLoader {
  @override
  Future<TickerLoadOutcome> loadOutcome(
    String ticker, {
    DateTime? startDate,
  }) async {
    return TickerLoadOutcome.ok(
      TickerPriceHistory(
        ticker: ticker,
        candles: [
          YahooFinanceCandleData(date: DateTime(2024, 1, 1), adjClose: 100),
          YahooFinanceCandleData(date: DateTime(2025, 1, 1), adjClose: 120),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    await ETheme.loadFontsForWidgetTests();
  });

  testWidgets('compare page shows header, ticker field, and preset chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ETheme.material3Dark,
          home: StockComparePage(priceLoader: _StubPriceLoader()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stock Compare'), findsOneWidget);
    expect(find.byType(ETextField), findsOneWidget);
    expect(find.text('GOOG, AAPL'), findsWidgets);
    expect(find.text('1Y'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('portfolio page renders seeded saved views', (tester) async {
    final seededView = ComparisonView(
      id: 'v1',
      name: 'Cloud Hyperscalers',
      tickers: const ['GOOG', 'AMZN'],
      rangePreset: VisibleRangePreset.fiveYears,
      createdAt: DateTime(2026, 10, 18),
      updatedAt: DateTime(2026, 10, 18),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comparisonViewsStreamProvider.overrideWith(
            (ref) => Stream.value([seededView]),
          ),
        ],
        child: MaterialApp(
          theme: ETheme.material3Dark,
          home: const PortfolioPage(showSyncStatus: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved comparisons'), findsOneWidget);
    expect(find.text('Cloud Hyperscalers'), findsOneWidget);
    expect(find.text('GOOG, AMZN · 5Y'), findsOneWidget);
  });
}
