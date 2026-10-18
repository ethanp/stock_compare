import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_compare/model/compared_price_histories.dart';
import 'package:stock_compare/model/ticker_price_history.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

void main() {
  YahooFinanceCandleData candle(DateTime date, double adjClose) {
    return YahooFinanceCandleData(date: date, adjClose: adjClose);
  }

  test('rebases percent change at the first candle on or after from', () {
    final history = TickerPriceHistory(
      ticker: 'GOOG',
      candles: [
        candle(DateTime(2024, 1, 1), 100),
        candle(DateTime(2024, 2, 1), 110),
        candle(DateTime(2024, 3, 1), 90),
      ],
    );

    final points = history.percentChangePoints(from: DateTime(2024, 2, 1));

    expect(points, hasLength(2));
    expect(points.first.percentChange, 0);
    expect(points.last.percentChange, closeTo(-18.1818, 0.01));
    expect(points.last.adjClose, 90);
  });

  test('empty history has no percent-change points', () {
    const history = TickerPriceHistory(ticker: 'GOOG', candles: []);
    expect(history.percentChangePoints(from: DateTime(2024, 1, 1)), isEmpty);
    expect(history.percentChangeSince(DateTime(2024, 1, 1)), isNull);
  });

  test('single candle at the baseline is 0%', () {
    final history = TickerPriceHistory(
      ticker: 'AAPL',
      candles: [candle(DateTime(2024, 6, 1), 200)],
    );

    final points = history.percentChangePoints(from: DateTime(2024, 1, 1));

    expect(points, hasLength(1));
    expect(points.single.percentChange, 0);
    expect(points.single.signedPercentCaption, '0.0%');
  });

  test('comparison starts on the latest first candle among tickers', () {
    final goog = TickerPriceHistory(
      ticker: 'GOOG',
      candles: [
        candle(DateTime(2004, 8, 19), 50),
        candle(DateTime(2024, 6, 1), 180),
      ],
    );
    final newerIpo = TickerPriceHistory(
      ticker: 'XYZ',
      candles: [
        candle(DateTime(2020, 3, 15), 20),
        candle(DateTime(2024, 6, 1), 40),
      ],
    );

    final compared = [goog, newerIpo].asCompared;

    expect(compared.firstSharedDay, DateTime(2020, 3, 15).startOfDay);
    expect(compared.lastDay, DateTime(2024, 6, 1).startOfDay);
  });
}
