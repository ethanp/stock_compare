import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_compare/ui/my_line_chart.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

class FirstPage extends StatefulWidget {
  const FirstPage();

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  final TextEditingController customTickerC =
      TextEditingController(text: 'GOOG');
  List<YahooFinanceCandleData> _pricesList = [];
  bool _loading = false;
  DateTime? startDate;
  static final List<String> tickerOptions = [
    'GOOG',
    'GOOG, AAPL',
    'AAPL',
    'AMZN',
    'BTC-USD',
  ];

  @override
  void initState() {
    super.initState();
    downloadPrices();
  }

  @override
  void dispose() {
    customTickerC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tickerSelector(tickerOptions, context),
        if (_loading)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              Text('Loading ${customTickerC.text} ...'),
            ],
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 36, left: 10, right: 14),
            child: _pricesList.isNotEmpty
                ? MyLineChart(_pricesList)
                : const Text('no data'),
          ),
        ),
      ],
    );
  }

  Future<void> downloadPrices() async {
    if (_loading) return print('already loading');
    try {
      setState(() => _loading = true);
      _pricesList = await YahooFinanceService().getTickerData(
        customTickerC.text,
        startDate: startDate,
        // "adjust" - adjusts historical stock price data eg. for stock splits
        // or dividend distributions, leaving a price series. This can be
        // compared more accurately for most situations, from what I can tell.
        adjust: true,
      );
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget tickerSelector(List<String> tickerOptions, BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          selectableTickers(tickerOptions),
          datePicker(context),
          TextField(controller: customTickerC),
          MaterialButton(
            color: Theme.of(context).primaryColor,
            onPressed: downloadPrices,
            child: const Text('Load'),
          ),
          _pricesList.isEmpty ? const Text('No data') : pricesSummary(),
        ]),
      ),
    );
  }

  Widget datePicker(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(startDate != null
              ? 'Selected Date:\n ${DateFormat('yyyy-MM-dd').format(startDate!)}'
              : 'No Date Selected'),
          MaterialButton(
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: startDate ?? DateTime.now(),
                firstDate: DateTime(1980),
                lastDate: DateTime(2025),
              );
              if (picked != null && picked != startDate) {
                setState(() => startDate = picked);
              }
            },
            child: const Text(
              'Select Date',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget pricesSummary() {
    return Column(children: [
      Text('Prices in the service ${_pricesList.length}'),
      Text('First date: ${_pricesList.first.date}'),
      Text('First price: ${_pricesList.first.adjClose}'),
      Text('Last date: ${_pricesList.last.date}'),
      Text('Last price: ${_pricesList.last.adjClose}'),
    ]);
  }

  Widget selectableTickers(List<String> tickerOptions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: tickerOptions.map(selectTickerButton).toList()),
    );
  }

  Widget selectTickerButton(option) {
    return Container(
      margin: const EdgeInsets.all(5),
      child: MaterialButton(
        onPressed: customTickerC.text == option
            ? null
            : () {
                setState(() => customTickerC.text = option);
                downloadPrices();
              },
        color: Colors.amberAccent,
        child: Text(option),
      ),
    );
  }
}
