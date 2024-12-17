import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

final yymmddDateFormat = DateFormat('yy-MM-dd');

class MyLineChart extends StatelessWidget {
  const MyLineChart(this.prices);

  final List<YahooFinanceCandleData> prices;

  final hideAxis = const AxisTitles(sideTitles: SideTitles(showTitles: false));

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minX: prices.first.date.millisecondsSinceEpoch.toDouble(),
        maxX: prices.last.date.millisecondsSinceEpoch.toDouble(),
        minY: 0,
        maxY: prices.map((e) => e.adjClose).reduce(math.max).ceilToDouble(),
        titlesData: axisTitles(),
        lineBarsData: [
          LineChartBarData(
            dotData: const FlDotData(show: false),
            isCurved: true,
            spots: prices
                .map((priceCandle) => FlSpot(
                      priceCandle.date.millisecondsSinceEpoch.toDouble(),
                      priceCandle.adjClose,
                    ))
                .toList(),
          )
        ],
      ),
    );
  }

  FlTitlesData axisTitles() {
    return FlTitlesData(
      topTitles: hideAxis,
      rightTitles: hideAxis,
      leftTitles: priceAxis(),
      bottomTitles: dateAxis(),
    );
  }

  AxisTitles priceAxis() {
    return AxisTitles(
      sideTitles: SideTitles(
        reservedSize: 40,
        showTitles: true,
        minIncluded: false,
        maxIncluded: false,
        interval: 40,
        getTitlesWidget: (double value, _) => Text('\$${value.toInt()}'),
      ),
    );
  }

  AxisTitles dateAxis() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        minIncluded: false,
        maxIncluded: false,
        interval: const Duration(days: 365).inMilliseconds.toDouble(),
        getTitlesWidget: (double value, _) => Transform.translate(
          offset: const Offset(0, 16),
          child: Transform.rotate(
            angle: .6,
            child: Text(
              yymmddDateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  value.floor(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
