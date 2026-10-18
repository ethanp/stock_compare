import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/compared_price_histories.dart';
import '../model/ticker_price_history.dart';
import '../model/visible_range_preset.dart';

export '../model/visible_range_preset.dart';

abstract final class _TickerPalette() {
  static const colors = [
    EColors.accentGlow,
    EColors.success,
    EColors.warning,
    EColors.pending,
    EColors.danger,
    EColors.mono,
  ];

  static Color at(int index) => colors[index % colors.length];
}

class const StockPriceChart({
  required final List<TickerPriceHistory> histories,
  final VisibleRangePreset initialPreset = VisibleRangePreset.oneYear,
  final ValueChanged<VisibleRangePreset>? onPresetActivated,
}) extends StatefulWidget {
  @override
  State<StockPriceChart> createState() => _StockPriceChartState();
}

class _StockPriceChartState() extends State<StockPriceChart> {
  static final DateFormat _hoverDateFormat = DateFormat.yMMMd();

  EChartVisibleRange? _visible;
  EChartSelectedPoint<DateTime>? _hoveredPoint;

  @override
  void initState() {
    super.initState();
    _visible = _rangeForNewHistories();
  }

  @override
  void didUpdateWidget(StockPriceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibleRange(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final EChartVisibleRange? visible = _visible;
    final EChartVisibleRange? fullExtent = _fullExtent;
    if (visible == null || fullExtent == null) {
      return const EEmptyState(
        title: 'No prices',
        message: 'Load a ticker to see the chart.',
        icon: Icons.show_chart,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tickerSummaries(visible),
        const SizedBox(height: ELayout.spaceSm),
        Expanded(child: _mainChart(visible)),
        const SizedBox(height: ELayout.spaceSm),
        _rangePresetChips(fullExtent, visible),
        const SizedBox(height: ELayout.spaceXs),
        _scrubber(fullExtent, visible),
      ],
    );
  }

  Widget _tickerSummaries(EChartVisibleRange visible) {
    return Wrap(
      spacing: ELayout.spaceMd,
      runSpacing: ELayout.spaceXs,
      children: [
        for (var index = 0; index < widget.histories.length; index++)
          _tickerSummary(
            widget.histories[index],
            _TickerPalette.at(index),
            visible,
          ),
      ],
    );
  }

  Widget _tickerSummary(
    TickerPriceHistory history,
    Color color,
    EChartVisibleRange visible,
  ) {
    final lastCandle = history.lastCandle;
    final String lastPrice = lastCandle == null
        ? '—'
        : formatCents((lastCandle.adjClose * 100).round());
    final String lastDate = lastCandle == null
        ? ''
        : _hoverDateFormat.format(lastCandle.date);
    final String percentCaption =
        history.signedPercentChangeSince(visible.start) ?? '—';
    return Text(
      '${history.ticker}  $lastPrice  $percentCaption  $lastDate',
      style: EText.caption.copyWith(color: color),
    );
  }

  Widget _mainChart(EChartVisibleRange visible) {
    final List<EChartSeries<DateTime>> series = _percentSeries(visible);
    return Stack(
      children: [
        EChart<DateTime>(
          series: series,
          valueScale: _percentScale(series),
          start: visible.start,
          end: visible.end,
          leftPadding: 48,
          onHoveredPoint: (point) => setState(() => _hoveredPoint = point),
        ),
        if (_hoveredPoint != null) _hoverCaption(_hoveredPoint!),
      ],
    );
  }

  Widget _hoverCaption(EChartSelectedPoint<DateTime> hovered) {
    final TickerPriceHistory? history = _historyNamed(hovered.seriesId);
    final candle = history?.candleOn(hovered.date);
    final String price = candle == null
        ? ''
        : ' · ${formatCents((candle.adjClose * 100).round())}';
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: EColors.backgroundLift.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: EColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${hovered.seriesId} · ${_hoverDateFormat.format(hovered.date)} · '
              '${hovered.value > 0 ? '+' : ''}${hovered.value.toStringAsFixed(1)}%'
              '$price',
              style: EText.caption,
            ),
          ),
        ),
      ),
    );
  }

  Widget _rangePresetChips(
    EChartVisibleRange fullExtent,
    EChartVisibleRange visible,
  ) {
    return Wrap(
      spacing: ELayout.spaceXs,
      children: [
        for (final preset in VisibleRangePreset.values)
          EFilterChip(
            label: preset.chipLabel,
            color: EColors.accentGlow,
            compact: true,
            selected: _presetMatches(preset, fullExtent, visible),
            onActivated: () => _applyPreset(preset, fullExtent),
          ),
      ],
    );
  }

  Widget _scrubber(EChartVisibleRange fullExtent, EChartVisibleRange visible) {
    return EChartAllTimeRangeScrubber(
      rangeStart: fullExtent.start,
      rangeEnd: fullExtent.end,
      lines: _scrubberLines(),
      visible: visible,
      onVisibleRangeChanged: (range) => setState(() {
        _visible = range.clampedTo(
          earliest: fullExtent.start,
          latest: fullExtent.end,
        );
      }),
    );
  }

  List<EChartSeries<DateTime>> _percentSeries(EChartVisibleRange visible) {
    final DateTime endDay = visible.end.startOfDay;
    final series = <EChartSeries<DateTime>>[];
    for (var index = 0; index < widget.histories.length; index++) {
      final List<PercentChangePoint> points = _pointsInRange(
        widget.histories[index],
        visible,
        endDay,
      );
      if (points.isEmpty) continue;
      series.add(
        EChartSeries.line(
          id: widget.histories[index].ticker,
          color: _TickerPalette.at(index),
          strokeWidth: 1.8,
          points: [
            for (final point in points)
              EChartPoint(
                date: point.date,
                value: point.percentChange,
                id: point.date,
              ),
          ],
        ),
      );
    }
    return series;
  }

  List<PercentChangePoint> _pointsInRange(
    TickerPriceHistory history,
    EChartVisibleRange visible,
    DateTime endDay,
  ) {
    return [
      for (final point in history.percentChangePoints(from: visible.start))
        if (!point.date.startOfDay.isAfter(endDay)) point,
    ];
  }

  List<EChartAllTimeRangeLine> _scrubberLines() {
    final DateTime? firstSharedDay = widget.histories.asCompared.firstSharedDay;
    return [
      for (var index = 0; index < widget.histories.length; index++)
        EChartAllTimeRangeLine(
          color: _TickerPalette.at(index),
          samples: _ratioSamples(widget.histories[index], from: firstSharedDay),
        ),
    ];
  }

  List<EChartAllTimeRangeSample> _ratioSamples(
    TickerPriceHistory history, {
    DateTime? from,
  }) {
    final baseline = from == null
        ? history.firstCandle
        : history.candleOn(from) ?? history.firstCandle;
    if (baseline == null || baseline.adjClose == 0) return const [];
    final DateTime fromDay = (from ?? baseline.date).startOfDay;
    return [
      for (final candle in history.candles)
        if (!candle.date.startOfDay.isBefore(fromDay))
          EChartAllTimeRangeSample(
            date: candle.date,
            value: candle.adjClose / baseline.adjClose,
          ),
    ];
  }

  EChartValueScale _percentScale(List<EChartSeries<DateTime>> series) {
    var minPercent = 0.0;
    var maxPercent = 0.0;
    for (final line in series) {
      for (final point in line.points) {
        if (point.value < minPercent) minPercent = point.value;
        if (point.value > maxPercent) maxPercent = point.value;
      }
    }
    if (minPercent == 0 && maxPercent == 0) {
      return EChartValueScale.fixed(
        min: -1,
        max: 1,
        ticks: const [-1, 0, 1],
        tickSuffix: '%',
      );
    }
    final double span = (maxPercent - minPercent).clamp(1.0, double.infinity);
    final double step = (span / 4).niceNumber(round: true);
    final double niceMin = (minPercent / step).floor() * step;
    final double niceMax = (maxPercent / step).ceil() * step;
    return EChartValueScale.fixed(
      min: niceMin,
      max: niceMax,
      ticks: [
        for (var tick = niceMin; tick <= niceMax + step * 0.001; tick += step)
          tick,
      ],
      tickSuffix: '%',
    );
  }

  EChartVisibleRange? get _fullExtent {
    final DateTime? firstSharedDay = widget.histories.asCompared.firstSharedDay;
    final DateTime? lastDay = widget.histories.asCompared.lastDay;
    if (firstSharedDay == null || lastDay == null) return null;
    if (firstSharedDay.isAfter(lastDay)) return null;
    return EChartVisibleRange(start: firstSharedDay, end: lastDay);
  }

  EChartVisibleRange? _rangeForNewHistories() {
    final EChartVisibleRange? fullExtent = _fullExtent;
    if (fullExtent == null) return null;
    return widget.initialPreset.rangeThrough(
      earliest: fullExtent.start,
      latest: fullExtent.end,
    );
  }

  void _syncVisibleRange(StockPriceChart oldWidget) {
    final EChartVisibleRange? fullExtent = _fullExtent;
    if (fullExtent == null) {
      _visible = null;
      return;
    }
    if (_visible == null ||
        !_sameTickers(oldWidget.histories, widget.histories) ||
        oldWidget.initialPreset != widget.initialPreset) {
      _visible = widget.initialPreset.rangeThrough(
        earliest: fullExtent.start,
        latest: fullExtent.end,
      );
      return;
    }
    _visible = _visible!.clampedTo(
      earliest: fullExtent.start,
      latest: fullExtent.end,
    );
  }

  bool _sameTickers(
    List<TickerPriceHistory> left,
    List<TickerPriceHistory> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].ticker != right[index].ticker) return false;
    }
    return true;
  }

  bool _presetMatches(
    VisibleRangePreset preset,
    EChartVisibleRange fullExtent,
    EChartVisibleRange visible,
  ) {
    final EChartVisibleRange expected = preset.rangeThrough(
      earliest: fullExtent.start,
      latest: fullExtent.end,
    );
    return expected == visible;
  }

  void _applyPreset(VisibleRangePreset preset, EChartVisibleRange fullExtent) {
    setState(() {
      _visible = preset.rangeThrough(
        earliest: fullExtent.start,
        latest: fullExtent.end,
      );
    });
    widget.onPresetActivated?.call(preset);
  }

  TickerPriceHistory? _historyNamed(String ticker) {
    for (final history in widget.histories) {
      if (history.ticker == ticker) return history;
    }
    return null;
  }
}
