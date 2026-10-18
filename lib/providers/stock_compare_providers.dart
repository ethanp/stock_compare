import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_compare/model/comparison_view.dart';
import 'package:stock_compare/model/ticker_price_loader.dart';
import 'package:stock_compare/services/comparison_views_dao.dart';
import 'package:stock_compare/services/ticker_candle_cache.dart';

final comparisonViewsDaoProvider = FutureProvider<ComparisonViewsDao>((
  ref,
) async {
  final powerSyncManager = await ref.watch(
    powerSyncDatabaseManagerProvider.future,
  );
  return ComparisonViewsDao(powerSyncManager.database);
});

final comparisonViewsStreamProvider = StreamProvider<List<ComparisonView>>((
  ref,
) async* {
  final dao = await ref.watch(comparisonViewsDaoProvider.future);
  yield* dao.watchAll();
});

final tickerCandleStoreProvider = FutureProvider<TickerCandleStore?>((
  ref,
) async {
  final powerSyncManager = await ref.watch(
    powerSyncDatabaseManagerProvider.future,
  );
  return SqliteTickerCandleCache(powerSyncManager.database);
});

final tickerPriceLoaderProvider = FutureProvider<TickerPriceLoader>((
  ref,
) async {
  final candleStore = await ref.watch(tickerCandleStoreProvider.future);
  return TickerPriceLoader(candleStore: candleStore);
});
