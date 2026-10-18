import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stock_compare/model/comparison_view.dart';
import 'package:stock_compare/model/ticker_price_history.dart';
import 'package:stock_compare/model/ticker_price_loader.dart';
import 'package:stock_compare/providers/stock_compare_providers.dart';
import 'package:stock_compare/ui/stock_price_chart.dart';

const _logger = ELogger('StockCompare');

class const StockComparePage({
  final ComparisonView? initialView,
  final TickerPriceLoader? priceLoader,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<StockComparePage> createState() => _StockComparePageState();
}

class _StockComparePageState() extends ConsumerState<StockComparePage> {
  static const tickerPresets = [
    'GOOG',
    'GOOG, AAPL',
    'AAPL',
    'AMZN',
    'BTC-USD',
  ];

  static final DateFormat _startDateFormat = DateFormat('yyyy-MM-dd');

  late final TextEditingController tickerField = TextEditingController(
    text: widget.initialView?.tickersField ?? 'GOOG',
  );
  late ComparisonView? activeView = widget.initialView;
  late VisibleRangePreset rangePreset =
      widget.initialView?.rangePreset ?? VisibleRangePreset.oneYear;
  late DateTime? startDate = widget.initialView?.startDate;
  List<TickerPriceHistory> priceHistories = [];
  bool pricesAreLoading = false;

  @override
  void initState() {
    super.initState();
    loadPrices();
  }

  @override
  void dispose() {
    tickerField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EScaffoldShell(
      appBar: EAppHeader(
        title: activeView?.name ?? 'Stock Compare',
        subtitle: 'Percent change from the visible start',
        actions: _headerActions(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ELayout.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _controlsCard(),
              const SizedBox(height: ELayout.spaceMd),
              Expanded(child: _chartArea()),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _headerActions() {
    return [
      IconButton(
        tooltip: activeView == null ? 'Save comparison' : 'Save or rename view',
        onPressed: _promptSaveComparison,
        icon: const Icon(Icons.bookmark_add_outlined),
      ),
      if (activeView != null)
        IconButton(
          tooltip: 'Delete view',
          onPressed: _deleteActiveView,
          icon: const Icon(Icons.delete_outline),
        ),
    ];
  }

  Widget _controlsCard() {
    return ECard(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tickerPresetChips(),
          const SizedBox(height: ELayout.spaceSm),
          _startDateRow(),
          const SizedBox(height: ELayout.spaceSm),
          ETextField(
            controller: tickerField,
            hintText: 'GOOG, AAPL',
            onSubmitted: (_) => loadPrices(),
          ),
          const SizedBox(height: ELayout.spaceSm),
          Row(
            children: [
              FilledButton(onPressed: loadPrices, child: const Text('Load')),
              const SizedBox(width: ELayout.spaceSm),
              OutlinedButton.icon(
                onPressed: _promptSaveComparison,
                icon: const Icon(Icons.bookmark_border, size: 16),
                label: Text(activeView == null ? 'Save view' : 'Update view'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tickerPresetChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in tickerPresets) ...[
            EFilterChip(
              label: preset,
              color: EColors.accentGlow,
              compact: true,
              selected: tickerField.text == preset,
              onActivated: () => _selectTickerPreset(preset),
            ),
            const SizedBox(width: ELayout.spaceXs),
          ],
        ],
      ),
    );
  }

  Widget _startDateRow() {
    final String dateCaption = startDate == null
        ? 'No start date'
        : _startDateFormat.format(startDate!);
    return Row(
      children: [
        Expanded(child: Text(dateCaption, style: EText.caption)),
        if (startDate != null)
          TextButton(
            onPressed: _clearStartDate,
            child: const Text('Clear date'),
          ),
        TextButton(onPressed: _pickStartDate, child: const Text('Select date')),
      ],
    );
  }

  Widget _chartArea() {
    if (pricesAreLoading) {
      return ELoadingState(message: 'Loading ${tickerField.text} …');
    }
    if (priceHistories.isEmpty) {
      return const EEmptyState(
        title: 'No prices',
        message: 'Load one or more tickers to compare percent change.',
        icon: Icons.show_chart,
      );
    }
    return StockPriceChart(
      histories: priceHistories,
      initialPreset: rangePreset,
      onPresetActivated: _persistPresetIfSaved,
    );
  }

  Future<TickerPriceLoader> _resolveLoader() async {
    if (widget.priceLoader != null) return widget.priceLoader!;
    return ref.read(tickerPriceLoaderProvider.future);
  }

  Future<void> loadPrices() async {
    if (pricesAreLoading) {
      _logger.log('already loading');
      return;
    }
    final List<String> tickers = TickerPriceLoader.tickersFromField(
      tickerField.text,
    );
    if (tickers.isEmpty) {
      if (mounted) context.textSnackBar('Enter at least one ticker');
      return;
    }
    setState(() => pricesAreLoading = true);
    try {
      final TickerPriceLoader loader = await _resolveLoader();
      final List<TickerLoadOutcome> outcomes = await loader.loadAll(
        tickers,
        startDate: startDate,
      );
      if (!mounted) return;
      _applyLoadOutcomes(outcomes);
    } finally {
      if (mounted) setState(() => pricesAreLoading = false);
    }
  }

  void _applyLoadOutcomes(List<TickerLoadOutcome> outcomes) {
    final loaded = <TickerPriceHistory>[];
    final cachedTickers = <String>[];
    for (final outcome in outcomes) {
      if (outcome.history != null) {
        loaded.add(outcome.history!);
        if (outcome.fellBackToCache) cachedTickers.add(outcome.ticker);
        continue;
      }
      context.textSnackBar('Failed to load ${outcome.ticker}: ${outcome.error}');
    }
    if (cachedTickers.isNotEmpty) {
      context.textSnackBar(
        'Showing cached prices for ${cachedTickers.join(', ')}',
      );
    }
    setState(() => priceHistories = loaded);
  }

  void _selectTickerPreset(String preset) {
    setState(() => tickerField.text = preset);
    loadPrices();
  }

  void _clearStartDate() {
    setState(() => startDate = null);
    loadPrices();
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked == null || picked == startDate) return;
    setState(() => startDate = picked);
    await loadPrices();
  }

  Future<void> _persistPresetIfSaved(VisibleRangePreset preset) async {
    setState(() => rangePreset = preset);
    final ComparisonView? current = activeView;
    if (current == null) return;
    final dao = await ref.read(comparisonViewsDaoProvider.future);
    final updated = current.copyWith(
      rangePreset: preset,
      updatedAt: DateTime.now().toUtc(),
    );
    await dao.upsert(updated);
    if (mounted) setState(() => activeView = updated);
  }

  Future<void> _promptSaveComparison() async {
    final List<String> tickers = TickerPriceLoader.tickersFromField(
      tickerField.text,
    );
    if (tickers.isEmpty) {
      context.textSnackBar('Enter at least one ticker before saving');
      return;
    }
    final String defaultName = activeView?.name ?? tickers.join(' vs ');
    final String? enteredName = await _showViewNameDialog(defaultName);
    if (enteredName == null || enteredName.trim().isEmpty || !mounted) return;
    await _saveViewNamed(enteredName.trim(), tickers);
  }

  Future<String?> _showViewNameDialog(String initialName) async {
    final nameController = TextEditingController(text: initialName);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            activeView == null ? 'Save comparison' : 'Update comparison',
          ),
          content: ETextField(
            controller: nameController,
            hintText: 'View name',
            autofocus: true,
            onSubmitted: (submitted) =>
                Navigator.of(dialogContext).pop(submitted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(nameController.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _saveViewNamed(String name, List<String> tickers) async {
    final dao = await ref.read(comparisonViewsDaoProvider.future);
    final ComparisonView? existing = activeView;
    if (existing == null) {
      final created = await dao.create(
        name: name,
        tickers: tickers,
        rangePreset: rangePreset,
        startDate: startDate,
      );
      if (!mounted) return;
      setState(() => activeView = created);
      context.textSnackBar('Saved "$name"');
      return;
    }
    final updated = existing.copyWith(
      name: name,
      tickers: tickers,
      rangePreset: rangePreset,
      startDate: startDate,
      clearStartDate: startDate == null,
      updatedAt: DateTime.now().toUtc(),
    );
    await dao.upsert(updated);
    if (!mounted) return;
    setState(() => activeView = updated);
    context.textSnackBar('Updated "$name"');
  }

  Future<void> _deleteActiveView() async {
    final ComparisonView? current = activeView;
    if (current == null) return;
    final dao = await ref.read(comparisonViewsDaoProvider.future);
    await dao.softDelete(current.id);
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => activeView = null);
  }
}
