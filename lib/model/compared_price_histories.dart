import 'package:ethan_utils/ethan_utils.dart';

import 'ticker_price_history.dart';

/// Histories being compared on one chart.
class const ComparedPriceHistories(final List<TickerPriceHistory> histories) {
  /// Latest first-candle day: the first day every ticker existed.
  DateTime? get firstSharedDay {
    DateTime? latestStart;
    for (final history in histories) {
      final firstCandle = history.firstCandle;
      if (firstCandle == null) return null;
      final DateTime firstDay = firstCandle.date.startOfDay;
      if (latestStart == null || firstDay.isAfter(latestStart)) {
        latestStart = firstDay;
      }
    }
    return latestStart;
  }

  DateTime? get lastDay {
    DateTime? latest;
    for (final history in histories) {
      final lastCandle = history.lastCandle;
      if (lastCandle == null) return null;
      final DateTime last = lastCandle.date.startOfDay;
      if (latest == null || last.isAfter(latest)) latest = last;
    }
    return latest;
  }
}

extension AsComparedPriceHistories on List<TickerPriceHistory> {
  ComparedPriceHistories get asCompared => ComparedPriceHistories(this);
}
