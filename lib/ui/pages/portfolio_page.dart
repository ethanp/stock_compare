import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_compare/model/comparison_view.dart';
import 'package:stock_compare/providers/stock_compare_providers.dart';
import 'package:stock_compare/ui/pages/stock_compare_page.dart';

class const PortfolioPage({final bool showSyncStatus = true})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ComparisonView>> viewsAsync = ref.watch(
      comparisonViewsStreamProvider,
    );
    return EScaffoldShell(
      appBar: EAppHeader(
        title: 'Stock Compare',
        subtitle: 'Saved comparisons',
        actions: [
          if (showSyncStatus) const ESyncPhaseIcon(),
          IconButton(
            tooltip: 'New comparison',
            onPressed: () => _openCompareScreen(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: viewsAsync.when(
          loading: () =>
              const ELoadingState(message: 'Loading saved comparisons …'),
          error: (error, _) => EEmptyState(
            title: 'Could not load comparisons',
            message: '$error',
            icon: Icons.error_outline,
          ),
          data: (views) => _portfolioBody(context, ref, views),
        ),
      ),
    );
  }

  Widget _portfolioBody(
    BuildContext context,
    WidgetRef ref,
    List<ComparisonView> views,
  ) {
    if (views.isEmpty) return _emptyState(context);
    return ListView.separated(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      itemCount: views.length,
      separatorBuilder: (_, _) => const SizedBox(height: ELayout.spaceSm),
      itemBuilder: (context, index) =>
          _comparisonRow(context, ref, views[index]),
    );
  }

  Widget _emptyState(BuildContext context) {
    return EEmptyState(
      title: 'No saved comparisons yet',
      message:
          'Start a comparison and save it to access the same tickers '
          'and range across devices.',
      icon: Icons.show_chart,
      action: FilledButton.icon(
        onPressed: () => _openCompareScreen(context),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('New comparison'),
      ),
    );
  }

  Widget _comparisonRow(
    BuildContext context,
    WidgetRef ref,
    ComparisonView view,
  ) {
    return EListRow(
      onActivated: () => _openCompareScreen(context, initialView: view),
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceMd,
        vertical: ELayout.spaceSm,
      ),
      gap: ELayout.spaceSm,
      leading: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: EColors.accentGlow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  view.name,
                  style: EText.label.medium.semibold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  view.summaryCaption,
                  style: EText.mono.copyWith(
                    fontSize: ELayout.typeSize(11.5),
                    color: EColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EStatusChip(
            label: view.rangePreset.chipLabel,
            tone: EStatusTone.accent,
          ),
          const SizedBox(width: ELayout.spaceXs),
          IconButton(
            tooltip: 'Delete ${view.name}',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () => _deleteView(ref, view),
            icon: const Icon(
              Icons.delete_outline,
              size: 15,
              color: EColors.textMuted,
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: EColors.textMuted),
        ],
      ),
    );
  }

  Future<void> _openCompareScreen(
    BuildContext context, {
    ComparisonView? initialView,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StockComparePage(initialView: initialView),
      ),
    );
  }

  Future<void> _deleteView(WidgetRef ref, ComparisonView view) async {
    final dao = await ref.read(comparisonViewsDaoProvider.future);
    await dao.softDelete(view.id);
  }
}
