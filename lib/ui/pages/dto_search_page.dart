import 'package:flutter/material.dart';
import 'package:stock_compare/ui/candle_card.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

/// This is a quite a straightforward example. Enter the ticker, then hit load.
/// It will show the daily candles (unadjusted) since the beginning of time.
class DTOSearch extends StatefulWidget {
  const DTOSearch();

  @override
  State<DTOSearch> createState() => _DTOSearchState();
}

class _DTOSearchState extends State<DTOSearch> {
  final TextEditingController controller =
      TextEditingController(text: 'SOL-USD');
  late Future<YahooFinanceResponse> future;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Ticker from yahoo finance'),
        TextField(controller: controller),
        MaterialButton(
          onPressed: load,
          color: Theme.of(context).primaryColor,
          child: const Text('Load'),
        ),
        Expanded(
          child: FutureBuilder(
            future: future,
            builder: (_, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    height: 50,
                    width: 50,
                    child: CircularProgressIndicator(),
                  ),
                );
              } else if (snapshot.data == null) {
                return const Text('No data');
              }

              final candles = snapshot.data!.candlesData;
              return ListView.builder(
                itemCount: candles.length,
                itemBuilder: (_, idx) => CandleCard(candles[idx]),
              );
            },
          ),
        ),
      ],
    );
  }

  void load() {
    try {
      future = const YahooFinanceDailyReader().getDailyDTOs(controller.text);
    } catch (e) {
      debugPrint('Error: $e');
      // Show snackbar with error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {});
  }
}
