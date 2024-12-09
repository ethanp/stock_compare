import 'package:flutter/material.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

class RawSearch extends StatefulWidget {
  const RawSearch();

  @override
  State<RawSearch> createState() => _RawSearchState();
}

class _RawSearchState extends State<RawSearch> {
  @override
  Widget build(BuildContext context) {
    const String ticker = 'SOL-USD';
    const YahooFinanceDailyReader yahooFinanceDataReader =
        YahooFinanceDailyReader();

    final Future<Map<String, dynamic>> future =
        yahooFinanceDataReader.getDailyData(ticker);
    debugPrint('getting data for $ticker');

    return FutureBuilder(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == null) return const Text('No data');
          final Map<String, dynamic> historicalData = snapshot.data!;
          return SingleChildScrollView(child: Text(historicalData.toString()));
        } else if (snapshot.hasError) {
          return Text('Error ${snapshot.error}');
        }

        return const Center(
          child: SizedBox(
            height: 50,
            width: 50,
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  String generateDescription(DateTime date, Map<String, dynamic> day) {
    final names = ['open', 'close', 'high', 'low', 'adjclose'];
    final values = names.map((n) => '$n: ${day[n]}').join('\n');
    return '$date\n$values';
  }
}
