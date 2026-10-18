import 'dart:io';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_compare/app_identity.dart';
import 'package:stock_compare/sync/powersync_schema.dart';

const _log = ELogger('StockCompareSync');

const _fkDependencies = <String, Set<String>>{
  'comparison_views': {},
};

Future<String> _resolveApplicationSupportDbPath(
  SharedPreferences preferences,
) async {
  const pathKey = '${AppIdentity.syncAppName}_powersync_database_path';
  const fileName = '${AppIdentity.syncAppName}_powersync.db';
  final cachedPath = preferences.getString(pathKey);
  if (cachedPath != null &&
      cachedPath.endsWith(fileName) &&
      !cachedPath.contains('/Documents/') &&
      Directory(p.dirname(cachedPath)).existsSync()) {
    return cachedPath;
  }
  final supportDirectory = await getApplicationSupportDirectory();
  await supportDirectory.create(recursive: true);
  final databasePath = p.join(supportDirectory.path, fileName);
  await preferences.setString(pathKey, databasePath);
  return databasePath;
}

SyncConfig buildStockCompareSyncConfig(SharedPreferences preferences) {
  return DotEnvSyncBootstrap.build(
    databasePath: () => _resolveApplicationSupportDbPath(preferences),
    appName: AppIdentity.syncAppName,
    powersyncPort: 8088,
    postgrestPort: 3011,
    schema: stockCompareSchema,
    upload: UploadSettings(
      strategy: TieredBatchUploadStrategy(dependencies: _fkDependencies),
    ),
    onSyncError: _log.warn,
  );
}
