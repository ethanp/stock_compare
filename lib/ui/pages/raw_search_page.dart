import 'package:flutter/material.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

/// This example simply downloads daily data for a const `ticker` (viz. Solana),
/// then plops the raw response data on the screen.
class RawSearch extends StatefulWidget {
  const RawSearch();

  @override
  State<RawSearch> createState() => _RawSearchState();
}

class _RawSearchState extends State<RawSearch> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: const YahooFinanceDailyReader().getDailyData('SOL-USD'),
      builder: (_, snapshot) {
        if (snapshot.hasError) return Text('Error ${snapshot.error}');
        if (snapshot.connectionState != ConnectionState.done) return loading();
        if (snapshot.data == null) return const Text('No data');
        final Map<String, dynamic> historicalData = snapshot.data!;
        return SingleChildScrollView(child: Text(historicalData.toString()));
      },
    );
  }

  Widget loading() {
    return const Center(
      child: SizedBox(
        height: 50,
        width: 50,
        child: CircularProgressIndicator(),
      ),
    );
  }
}
