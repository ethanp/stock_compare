import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_compare/ui/candle_card.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

class YahooFinanceServiceWidget extends StatefulWidget {
  const YahooFinanceServiceWidget({super.key});

  @override
  State<YahooFinanceServiceWidget> createState() =>
      _YahooFinanceServiceWidgetState();
}

class _YahooFinanceServiceWidgetState extends State<YahooFinanceServiceWidget> {
  final TextEditingController controller =
      TextEditingController(text: 'SOL-USD');
  List<YahooFinanceCandleData> pricesList = [];
  List? cachedPrices;
  bool loading = true;
  bool adjust = true;
  DateTime? startDate;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void load() async {
    setState(() => loading = true);
    await downloadData();
    setState(() => loading = false);
  }

  Future<void> downloadData() async {
    try {
      // Get response for the first time
      pricesList = await YahooFinanceService().getTickerData(
        controller.text,
        startDate: startDate,
        // When referring to the Yahoo Finance API, "adjust" means that the
        // historical stock price data provided has been ADJUSTED to reflect
        // any stock splits or dividend distributions that occurred during the
        // time period, essentially giving you a "clean" price series that
        // accounts for these corporate actions and allows for accurate
        // comparisons across different timeframes despite the changes in
        // share count.
        adjust: adjust,
      );
    } catch (e) {
      showError(e);
    }
  }

  void showError(Object e) {
    debugPrint('Error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void deleteCache() async {
    setState(() => loading = true);

    try {
      await YahooFinanceDAO().removeDailyData(controller.text);
      cachedPrices = await YahooFinanceDAO().getAllDailyData(controller.text);
    } catch (e) {
      showError(e);
    }

    setState(() => loading = false);
  }

  void refresh() async {
    cachedPrices = await YahooFinanceDAO().getAllDailyData(controller.text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: pricesList.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          final List<String> tickerOptions = [
            'SOL-USD',
            'GOOG',
            'ES=F',
            'GC=F',
            'ES=F-0.5, GC=F-0.5',
            'ES=F, GC=F',
            'GOOG, AAPL',
            'AAPL',
            'AMZN',
            'BTC-USD',
          ];
          return tickerCard(tickerOptions, context);
        } else {
          final YahooFinanceCandleData candleData = pricesList[i - 1];
          return CandleCard(candleData);
        }
      },
    );
  }

  Widget tickerCard(List<String> tickerOptions, BuildContext context) {
    return Card(
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Column(children: [
          ticker(tickerOptions),
          datePicker(context),
          toggleAdjust(),
          const Text('Ticker from yahoo finance:'),
          TextField(controller: controller),
          actionButtons(context),
          if (pricesList.isNotEmpty) pricesInfo(),
          Text('Prices in the cache ${cachedPrices?.length}'),
          pricesList.isEmpty ? const Text('No data') : const SizedBox.shrink(),
        ]),
      ),
    );
  }

  Widget toggleAdjust() {
    return CheckboxListTile(
      title: const Text('Adjust'),
      value: adjust,
      onChanged: (value) => setState(() => adjust = value ?? false),
    );
  }

  Widget datePicker(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            startDate != null
                ? 'Selected Date:\n ${DateFormat('yyyy-MM-dd').format(startDate!)}'
                : 'No Date Selected',
          ),
          MaterialButton(
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: startDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (picked != null && picked != startDate) {
                setState(() => startDate = picked);
              }
            },
            child:
                const Text('Select Date', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget pricesInfo() {
    final double variation =
        ((pricesList.last.adjClose / pricesList.first.adjClose - 1) * 100);
    return Column(children: [
      Text('Prices in the service ${pricesList.length}'),
      Text('First date: ${pricesList.first.date}'),
      Text('First price: ${pricesList.first.adjClose}'),
      Text('Last date: ${pricesList.last.date}'),
      Text('Last price: ${pricesList.last.adjClose}'),
      Text('Variation: ${variation.toStringAsFixed(2)} %'),
    ]);
  }

  Widget ticker(List<String> tickerOptions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: tickerOptions.map(selectionButton).toList()),
    );
  }

  Widget selectionButton(option) {
    return Container(
      margin: const EdgeInsets.all(5),
      child: MaterialButton(
        onPressed: controller.text == option
            ? null
            : () {
                setState(() => controller.text = option);
                load();
              },
        color: Colors.amberAccent,
        child: Text(option),
      ),
    );
  }

  Widget actionButtons(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          MaterialButton(
            color: Theme.of(context).primaryColor,
            onPressed: load,
            child: const Text('Load'),
          ),
          const SizedBox(width: 10),
          MaterialButton(
            color: Theme.of(context).colorScheme.error,
            onPressed: deleteCache,
            child: const Text('Delete Cache'),
          ),
          const SizedBox(width: 10),
          MaterialButton(
            color: Theme.of(context).colorScheme.onPrimary,
            onPressed: refresh,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
