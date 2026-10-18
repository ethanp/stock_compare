import 'package:powersync/powersync.dart';

const Schema stockCompareSchema = Schema([
  Table('comparison_views', [
    Column.text('name'),
    Column.text('tickers'),
    Column.text('range_preset'),
    Column.text('start_date'),
    Column.integer('sort_order'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.integer('is_deleted'),
  ]),
  Table.localOnly('daily_candles', [
    Column.text('ticker'),
    Column.text('date'),
    Column.real('adj_close'),
  ]),
  Table.localOnly('ticker_price_fetches', [
    Column.text('ticker'),
    Column.text('fetched_at'),
  ]),
]);
