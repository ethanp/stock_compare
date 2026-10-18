import 'package:ethan_utils/ethan_utils.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

class const PercentChangePoint({
  required final DateTime date,
  required final double percentChange,
  required final double adjClose,
}) {
  String get signedPercentCaption {
    final String sign = percentChange > 0 ? '+' : '';
    return '$sign${percentChange.toStringAsFixed(1)}%';
  }
}

class const TickerPriceHistory({
  required final String ticker,
  required final List<YahooFinanceCandleData> candles,
}) {
  YahooFinanceCandleData? get firstCandle => candles.isEmpty ? null : candles.first;

  YahooFinanceCandleData? get lastCandle => candles.isEmpty ? null : candles.last;

  YahooFinanceCandleData? candleOn(DateTime date) {
    final DateTime day = date.startOfDay;
    for (final candle in candles) {
      if (candle.date.startOfDay == day) return candle;
    }
    return null;
  }

  /// % change versus the first candle at or after [from] (Google Finance rebase).
  List<PercentChangePoint> percentChangePoints({required DateTime from}) {
    final YahooFinanceCandleData? baseline = _baselineAtOrAfter(from);
    if (baseline == null || baseline.adjClose == 0) return const [];
    final DateTime fromDay = from.startOfDay;
    return [
      for (final candle in candles)
        if (!candle.date.startOfDay.isBefore(fromDay))
          PercentChangePoint(
            date: candle.date,
            percentChange: (candle.adjClose / baseline.adjClose - 1) * 100,
            adjClose: candle.adjClose,
          ),
    ];
  }

  double? percentChangeSince(DateTime from) {
    final List<PercentChangePoint> points = percentChangePoints(from: from);
    return points.isEmpty ? null : points.last.percentChange;
  }

  String? signedPercentChangeSince(DateTime from) {
    final List<PercentChangePoint> points = percentChangePoints(from: from);
    return points.isEmpty ? null : points.last.signedPercentCaption;
  }

  YahooFinanceCandleData? _baselineAtOrAfter(DateTime from) {
    final DateTime fromDay = from.startOfDay;
    for (final candle in candles) {
      if (!candle.date.startOfDay.isBefore(fromDay)) return candle;
    }
    return firstCandle;
  }
}
