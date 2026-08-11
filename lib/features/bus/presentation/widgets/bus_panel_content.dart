import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:glassmorphism/glassmorphism.dart';
import 'dart:convert';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/map_state_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/api_constants.dart';
import '../../../../core/design_system.dart';
import '../../data/models/bus_model.dart';
import 'shimmer_and_toggle.dart';
import 'scrolling_text.dart';
import 'bus_details_sheet.dart';
import 'bus_stop_details_sheet.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../../../core/services/runtime_localizations.dart';

class BusPanelContent extends StatefulWidget {
  const BusPanelContent({super.key});

  @override
  State<BusPanelContent> createState() => _BusPanelContentState();
}

class _BusPanelContentState extends State<BusPanelContent> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _stopSearchController = TextEditingController();
  // String _stopSearchQuery = ""; // Removed local state
  int _selectedMode = 0; // 0: Fermate/Realtime, 1: Soluzioni

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      if (busProvider.savedStopSearchQuery.isNotEmpty) {
        _stopSearchController.text = busProvider.savedStopSearchQuery;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final busProvider = Provider.of<BusProvider>(context);
    final mapState = Provider.of<MapStateProvider>(context, listen: false);

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        final selectedProvider = _getSelectedProvider(busProvider);
        final supportsSolutions = selectedProvider?.supportsSolutions == true;
        final supportsLines = selectedProvider?.supportsLines == true;

        // Reset mode if selected mode is not supported
        if (!supportsSolutions && _selectedMode == 1) _selectedMode = 0;
        if (!supportsLines && _selectedMode == 2) _selectedMode = 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Operator Selection (Redesigned)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: GlassmorphicContainer(
                width: double.infinity,
                height: 120,
                borderRadius: 20,
                blur: 15,
                alignment: Alignment.center,
                border: 1.5,
                linearGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.surfaceColor.withOpacity(0.8),
                    theme.surfaceColor.withOpacity(0.6),
                  ],
                ),
                borderGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.secondaryTextColor.withOpacity(0.2),
                    theme.secondaryTextColor.withOpacity(0.05),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.operator ??
                                "Operatore",
                            style: TextStyle(
                                color: theme.textColor.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5),
                          ),
                          IconButton(
                            icon: Icon(Icons.reorder,
                                color: theme.secondaryTextColor),
                            tooltip: AppLocalizations.of(context)
                                    ?.reorderProviders ??
                                'Riordina provider',
                            onPressed: () async {
                              // Open bottom sheet with reorderable list
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (ctx) {
                                  return DraggableScrollableSheet(
                                    expand: false,
                                    initialChildSize: 0.6,
                                    maxChildSize: 0.95,
                                    minChildSize: 0.3,
                                    builder: (_, controller) {
                                      return _buildReorderSheet(
                                          ctx, busProvider, controller);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: busProvider.providers
                            .where((provider) =>
                                busProvider.isProviderVisible(provider))
                            .map((provider) {
                          final isSelected =
                              busProvider.selectedCity == provider.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                busProvider.selectCity(provider.name);
                                setState(() => _selectedMode = 0);
                                final p = busProvider.providers.firstWhere(
                                  (p) => p.name == provider.name,
                                  orElse: () => BusProviderConfig(
                                      name: provider.name,
                                      provider: '',
                                      endpoints: {}),
                                );
                                if (p.latitude != null && p.longitude != null) {
                                  // Imposta la categoria a Bus (1) sulla mappa
                                  mapState.setCategory(1);
                                  mapState.flyTo(p.latitude!, p.longitude!,
                                      zoom: p.zoom ?? 12.0);

                                  // Carica bus e fermate quando selezioni un provider
                                  busProvider.fetchVehicles();
                                  if (provider.name != "Flixbus") {
                                    busProvider.fetchStops();
                                  }
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.primaryColor.withOpacity(0.9)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : theme.secondaryTextColor
                                            .withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (isSelected)
                                      const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                    else
                                      Icon(Icons.directions_bus_outlined,
                                          size: 14,
                                          color: theme.secondaryTextColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      provider.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : theme.textColor,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Mode Toggle Chips
            if (supportsSolutions || supportsLines)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GlassmorphicContainer(
                  width: double.infinity,
                  height: 50,
                  borderRadius: 16,
                  blur: 15,
                  alignment: Alignment.center,
                  border: 1.0,
                  linearGradient: LinearGradient(colors: [
                    theme.surfaceColor.withOpacity(0.6),
                    theme.surfaceColor.withOpacity(0.4)
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderGradient: LinearGradient(colors: [
                    theme.secondaryTextColor.withOpacity(0.1),
                    theme.secondaryTextColor.withOpacity(0.05)
                  ]),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildGlassModeChip(
                              AppLocalizations.of(context)?.stops ?? "Fermate",
                              0,
                              theme)),
                      if (supportsLines) ...[
                        Container(
                            width: 1,
                            height: 24,
                            color: theme.secondaryTextColor.withOpacity(0.1)),
                        Expanded(
                            child: _buildGlassModeChip(
                                AppLocalizations.of(context)?.lines ?? "Linee",
                                2,
                                theme)),
                      ],
                      if (supportsSolutions) ...[
                        Container(
                            width: 1,
                            height: 24,
                            color: theme.secondaryTextColor.withOpacity(0.1)),
                        Expanded(
                            child: _buildGlassModeChip(
                                AppLocalizations.of(context)?.solutions ??
                                    "Soluzioni",
                                1,
                                theme)),
                      ],
                    ],
                  ),
                ),
              ),

            // 3. Action Area
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildActionArea(busProvider, theme, supportsSolutions),
            ),

            // 4. Results Area
            Expanded(
              child: busProvider.isLoading
                  ? ShimmerLoading(baseColor: theme.textColor)
                  : _buildResultsList(busProvider, mapState),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassModeChip(String label, int index, ThemeProvider theme) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = index);
        if (index == 2) {
          final busProvider = Provider.of<BusProvider>(context, listen: false);
          if (busProvider.busLines.isEmpty) {
            busProvider.fetchBusLines();
          }
        }
      },
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
              color: isSelected ? theme.primaryColor : theme.secondaryTextColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildActionArea(
      BusProvider busProvider, ThemeProvider theme, bool supportsSolutions) {
    // If Flixbus, it overrides standard logic (it's a special provider)
    if (busProvider.selectedCity == "Flixbus") {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildFlixbusSearch(busProvider),
      );
    }

    // If Solutions Mode selected
    if (_selectedMode == 1 && supportsSolutions) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildBariRouting(busProvider),
      );
    }

    // If Linee Mode selected
    if (_selectedMode == 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: GlassmorphicContainer(
          width: double.infinity,
          height: 56,
          borderRadius: 16,
          blur: 15,
          alignment: Alignment.center,
          border: 1.0,
          linearGradient: LinearGradient(colors: [
            theme.surfaceColor.withOpacity(0.8),
            theme.surfaceColor.withOpacity(0.6)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderGradient: LinearGradient(colors: [
            theme.secondaryTextColor.withOpacity(0.1),
            theme.secondaryTextColor.withOpacity(0.05)
          ]),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              // We use search controller for lines search
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)?.searchLineHint ??
                  "Cerca linea...",
              hintStyle:
                  TextStyle(color: theme.secondaryTextColor.withOpacity(0.7)),
              prefixIcon: Icon(Icons.search, color: theme.secondaryTextColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: theme.secondaryTextColor),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      })
                  : null,
              filled: false,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: theme.textColor),
          ),
        ),
      );
    }

    // Default (Realtime / Stops)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Box
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: 56,
            borderRadius: 16,
            blur: 15,
            alignment: Alignment.center,
            border: 1.0,
            linearGradient: LinearGradient(colors: [
              theme.surfaceColor.withOpacity(0.8),
              theme.surfaceColor.withOpacity(0.6)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderGradient: LinearGradient(colors: [
              theme.secondaryTextColor.withOpacity(0.1),
              theme.secondaryTextColor.withOpacity(0.05)
            ]),
            child: TextField(
              controller: _stopSearchController,
              onChanged: (val) {
                // Update global state
                busProvider.setSavedStopSearchQuery(val);
              },
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)?.searchStopHint ??
                    "Cerca fermata...",
                hintStyle:
                    TextStyle(color: theme.secondaryTextColor.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: theme.secondaryTextColor),
                suffixIcon: busProvider.savedStopSearchQuery.isNotEmpty
                    ? IconButton(
                        icon:
                            Icon(Icons.clear, color: theme.secondaryTextColor),
                        onPressed: () {
                          _stopSearchController.clear();
                          busProvider.setSavedStopSearchQuery("");
                        })
                    : null,
                filled: false,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: theme.textColor),
            ),
          ),
        ),

        // Show "Vicini a te" only if not searching
        if (busProvider.savedStopSearchQuery.isEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)?.nearYou ?? "Vicini a te",
                    style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontWeight: FontWeight.w600)),
                TextButton.icon(
                    onPressed: busProvider.isLoading
                        ? null
                        : () => busProvider.fetchVehicles(),
                    icon: busProvider.isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                        AppLocalizations.of(context)?.refresh ?? "Aggiorna"),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                    )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReorderSheet(BuildContext context, BusProvider busProvider,
      ScrollController controller) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
                AppLocalizations.of(context)?.reorderProviders ??
                    'Riordina provider',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: Consumer<BusProvider>(
              builder: (ctx, bp, _) {
                final providersLive = bp.providers;
                return ReorderableListView.builder(
                  scrollController: controller,
                  itemCount: providersLive.length,
                  onReorder: (oldIndex, newIndex) {
                    bp.reorderProviders(oldIndex, newIndex);
                  },
                  itemBuilder: (ctx, index) {
                    final p = providersLive[index];
                    final title = p.provider.isNotEmpty ? p.provider : p.name;
                    final subtitle = p.name;
                    final country = p.country ??
                        (p.apiPrefix != null && p.apiPrefix!.contains('/')
                            ? p.apiPrefix!.split('/').first
                            : 'it');
                    final visible = bp.isProviderVisible(p);
                    return ListTile(
                      key: ValueKey(p.name),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subtitle),
                          Text(country,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                        ],
                      ),
                      trailing: Switch(
                        value: visible,
                        onChanged: (v) async {
                          await bp.setProviderVisibility(p, v);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)?.close ?? 'Chiudi'),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFlixbusSearch(BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)
                  ?.searchStopHint
                  .replaceAll('...', ' Flixbus...') ??
              "Cerca fermata Flixbus...",
          hintStyle: TextStyle(color: theme.secondaryTextColor),
          prefixIcon: Icon(Icons.search, color: theme.primaryColor),
          suffixIcon: IconButton(
            icon: Icon(Icons.arrow_forward_rounded, color: theme.primaryColor),
            onPressed: () => busProvider.searchFlixbus(_searchController.text),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: TextStyle(color: theme.textColor),
        onSubmitted: (val) => busProvider.searchFlixbus(val),
      ),
    );
  }

  Widget _buildBariRouting(BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Card(
      elevation: 0,
      color: theme.surfaceColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.secondaryTextColor.withOpacity(0.1))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alt_route_rounded, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                    AppLocalizations.of(context)?.planJourney ??
                        "Pianifica Viaggio",
                    style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            _buildStopSelector(
                AppLocalizations.of(context)?.departure ?? "Partenza",
                busProvider.selectedFromStop,
                (BariStop? stop) => busProvider.selectFromStop(stop),
                busProvider),
            const SizedBox(height: 12),
            _buildStopSelector(
                AppLocalizations.of(context)?.arrival ?? "Arrivo",
                busProvider.selectedToStop,
                (BariStop? stop) => busProvider.selectToStop(stop),
                busProvider),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (busProvider.selectedFromStop != null &&
                        busProvider.selectedToStop != null &&
                        !busProvider.isLoadingSolutions)
                    ? () => busProvider.fetchBariSolutions()
                    : null,
                icon: busProvider.isLoadingSolutions
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded),
                label: Text(AppLocalizations.of(context)?.searchSolutions ??
                    "Cerca Soluzioni"),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopSelector(String label, BariStop? selectedStop,
      Function(BariStop?) onSelect, BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return InkWell(
      onTap: () =>
          _showStopSelectionDialog(context, label, busProvider, onSelect),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.secondaryTextColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
                selectedStop != null
                    ? Icons.my_location
                    : Icons.circle_outlined,
                color: selectedStop != null
                    ? theme.primaryColor
                    : theme.secondaryTextColor,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedStop?.stopName ??
                    "${AppLocalizations.of(context)?.select ?? 'Seleziona'} $label...",
                style: TextStyle(
                    color: selectedStop != null
                        ? theme.textColor
                        : theme.secondaryTextColor,
                    fontWeight: selectedStop != null
                        ? FontWeight.w500
                        : FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.unfold_more, color: theme.secondaryTextColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showStopSelectionDialog(BuildContext context, String label,
      BusProvider busProvider, Function(BariStop?) onSelect) {
    if (busProvider.stops.isEmpty && !busProvider.isLoadingStops) {
      busProvider.fetchStops();
    }

    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final theme = Provider.of<ThemeProvider>(context, listen: false);
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredStops = busProvider.stops
                .where((stop) => stop.stopName
                    .toLowerCase()
                    .contains(searchController.text.toLowerCase()))
                .toList();
            return AlertDialog(
              backgroundColor: theme.surfaceColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                title: Text(RuntimeLocalizations.t(context, 'select_item', params: {'label': label}),
                  style: TextStyle(color: theme.textColor)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: busProvider.isLoadingStops
                    ? Center(
                        child: CircularProgressIndicator(
                            color: theme.primaryColor))
                    : Column(
                        children: [
                          TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)
                                      ?.searchStopHint ??
                                  "Cerca fermata...",
                              hintStyle:
                                  TextStyle(color: theme.secondaryTextColor),
                              prefixIcon: Icon(Icons.search,
                                  color: theme.secondaryTextColor),
                              filled: true,
                              fillColor: theme.surfaceColor.withOpacity(0.1),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                            ),
                            style: TextStyle(color: theme.textColor),
                            onChanged: (value) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.separated(
                              itemCount: filteredStops.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: theme.secondaryTextColor
                                      .withOpacity(0.1)),
                              itemBuilder: (context, index) {
                                final stop = filteredStops[index];
                                return ListTile(
                                  title: Text(stop.stopName,
                                      style: TextStyle(color: theme.textColor)),
                                  leading: Icon(Icons.place_outlined,
                                      color: theme.secondaryTextColor,
                                      size: 20),
                                  onTap: () {
                                    onSelect(stop);
                                    Navigator.of(context).pop();
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)?.cancel ?? "Annulla",
                      style: TextStyle(color: theme.secondaryTextColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResultsList(BusProvider busProvider, MapStateProvider mapState) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    // Mode 2: Linee
    if (_selectedMode == 2) {
      if (busProvider.isLoadingLines && busProvider.busLines.isEmpty) {
        return Center(
            child: CircularProgressIndicator(color: theme.primaryColor));
      }

      final filteredLines = _searchController.text.isEmpty
          ? busProvider.busLines
          : busProvider.busLines
              .where((l) => l.lineNumber
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()))
              .toList();

      if (filteredLines.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus,
                  size: 48, color: theme.secondaryTextColor.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                busProvider.busLines.isEmpty
                    ? (AppLocalizations.of(context)?.noLinesLoaded ??
                        "Nessuna linea caricata")
                    : (AppLocalizations.of(context)?.noLinesFound ??
                        "Nessuna linea trovata"),
                style: TextStyle(color: theme.secondaryTextColor),
              ),
              if (busProvider.busLines.isEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => busProvider.fetchBusLines(),
                  child: Text(AppLocalizations.of(context)?.loadLines ??
                      "Carica Linee"),
                )
              ]
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: filteredLines.length + (busProvider.isLoadingLines ? 1 : 0),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 200),
        itemBuilder: (context, index) {
          if (index == filteredLines.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: theme.primaryColor),
                ),
              ),
            );
          }
          final line = filteredLines[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
              border:
                  Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
            ),
            child: ExpansionTile(
              leading: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  line.lineNumber,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                "Linea ${line.lineNumber}",
                style: TextStyle(
                    color: theme.textColor, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "${line.totalRoutes} percorsi, ${line.totalStops} fermate",
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
              ),
              children: line.routes.map((route) {
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.alt_route,
                      color: theme.secondaryTextColor, size: 18),
                  title: Text(
                    route.directionLabel,
                    style: TextStyle(color: theme.textColor, fontSize: 13),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 12, color: theme.secondaryTextColor),
                  onTap: () {
                    if (route.stops != null && route.stops!.isNotEmpty) {
                      _showRouteStops(context, line.lineNumber, route, theme);
                    }
                  },
                );
              }).toList(),
            ),
          );
        },
      );
    }

    // Mode 1: Solutions
    if (_selectedMode == 1) {
      if (busProvider.bariSolutions.isNotEmpty) {
        return _buildBariSolutionsList(busProvider, mapState);
      } else {
        if (busProvider.isLoadingSolutions) {
          return Center(
              child: CircularProgressIndicator(color: theme.primaryColor));
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alt_route,
                  size: 48, color: theme.secondaryTextColor.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.searchTravelSolution ??
                    "Cerca una soluzione di viaggio",
                style: TextStyle(color: theme.secondaryTextColor),
              )
            ],
          ),
        );
      }
    }

    // Search Results for Stops (Mode 0)
    if (_selectedMode == 0 && busProvider.savedStopSearchQuery.isNotEmpty) {
      final filteredStops = busProvider.stops
          .where((s) => s.stopName
              .toLowerCase()
              .contains(busProvider.savedStopSearchQuery.toLowerCase()))
          .toList();
      if (filteredStops.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off,
                  size: 48, color: theme.secondaryTextColor.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                  AppLocalizations.of(context)?.noStopsFound ??
                      "Nessuna fermata trovata",
                  style: TextStyle(color: theme.secondaryTextColor)),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: filteredStops.length,
        separatorBuilder: (_, __) => Divider(
            height: 1, color: theme.secondaryTextColor.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final stop = filteredStops[index];
          return ListTile(
            title: Text(stop.stopName,
                style: TextStyle(
                    color: theme.textColor, fontWeight: FontWeight.w500)),
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Icon(Icons.place, color: theme.primaryColor, size: 20),
            ),
            trailing: IconButton(
              icon: Icon(Icons.map_outlined, color: theme.primaryColor),
              onPressed: () {
                FocusScope.of(context).unfocus();
                // Save current query handled by provider already (via onChanged)

                mapState.flyTo(stop.latitude, stop.longitude, zoom: 16.0);
                busProvider.selectStop(
                    stop); // Seleziona la fermata (nasconde il pannello)

                // Se siamo in una schermata a schermo intero (es. BusSearchScreen), chiudiamola
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              tooltip:
                  AppLocalizations.of(context)?.showOnMap ?? "Mostra su mappa",
            ),
            onTap: () {
              mapState.flyTo(stop.latitude, stop.longitude, zoom: 16.0);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BusStopDetailsSheet(stop: stop)),
              );
            },
          );
        },
      );
    }

    if (busProvider.selectedCity == "Flixbus") {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: busProvider.flixbusStations.length,
        itemBuilder: (context, index) {
          final station = busProvider.flixbusStations[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.lightGreen.withOpacity(0.2),
              child: const Icon(Icons.directions_bus, color: Colors.lightGreen),
            ),
            title: Text(station['name'] ?? '',
                style: TextStyle(
                    color: theme.textColor, fontWeight: FontWeight.bold)),
            subtitle: Text(station['country_code'] ?? '',
                style: TextStyle(color: theme.secondaryTextColor)),
            onTap: () {
              final dynamic coords = station['coords'];
              if (coords != null &&
                  coords['lat'] != null &&
                  coords['lng'] != null) {
                mapState.flyTo((coords['lat'] as num).toDouble(),
                    (coords['lng'] as num).toDouble(),
                    zoom: 14);
              }
            },
          );
        },
      );
    }

    if (busProvider.vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_outlined,
                size: 48, color: theme.secondaryTextColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)
                      ?.noActiveBusFound(busProvider.selectedCity) ??
                  "Nessun autobus attivo trovato\nper ${busProvider.selectedCity}",
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: busProvider.vehicles.length,
      padding: const EdgeInsets.only(bottom: 100, top: 4),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final v = busProvider.vehicles[index];
        final cityColor = _getCityColor(busProvider.selectedCity);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
            border:
                Border.all(color: theme.secondaryTextColor.withOpacity(0.05)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (v.latitude != 0) {
                  mapState.flyTo(v.latitude, v.longitude, zoom: 15);
                }
                // Fetch bus details from API and show details sheet
                try {
                  final tripId = v.tripId ?? '';
                  final lineCode = v.line;
                  final selected = busProvider.selectedProvider!;
                  final apiPrefix = selected.apiPathPrefix;
                  final url =
                      '${ApiConstants.baseUrl}/api/$apiPrefix/realtime?tripId=${Uri.encodeComponent(tripId)}&lineCode=${Uri.encodeComponent(lineCode)}';
                  print('Fetching bus details from URL: $url');

                  final response = await http.get(Uri.parse(url));
                  if (response.statusCode == 200) {
                    final jsonData = jsonDecode(response.body);
                    if (jsonData['vehicles'] != null &&
                        jsonData['vehicles'].isNotEmpty) {
                      final vehicleData = jsonData['vehicles'][0];
                      final stops =
                          vehicleData['stops'] as List<dynamic>? ?? [];

                      // Update bus destination if available
                      final destination = vehicleData['destination'] as String?;
                      if (destination != null && destination.isNotEmpty) {
                        busProvider.updateBusDestination(v.id, destination);
                      }

                      // Convert stops to BusTripUpdate
                      final tripUpdates = stops.map((stop) {
                        return BusTripUpdate(
                          stopId: stop['stopId']?.toString() ?? '',
                          stopName: stop['stopName'] ?? '',
                          expectedTime: stop['scheduledTime'] ?? '',
                          delay: stop['delay'] ?? 0,
                          isRealtime: stop['isRealtime'] ?? false,
                          status: stop['status'] ?? 'future',
                          arrivalEstimate:
                              stop['estimatedArrivalUnix']?.toString(),
                        );
                      }).toList();

                      // Set the trip updates in the provider
                      busProvider.setApiTripUpdates(tripUpdates);
                    }
                  }
                  // Select the bus to show details sheet
                  await busProvider.selectBus(v);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BusDetailsSheet(bus: v)),
                    );
                  }
                } catch (e) {
                  print('Error fetching bus details: $e');
                  await busProvider.selectBus(v);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BusDetailsSheet(bus: v)),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Line Number Box
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: cityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: cityColor.withOpacity(0.3), width: 1.5)),
                      child: Text(
                        "${v.line}",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: cityColor),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Destination Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ScrollingText(
                            text:
                                v.destination ?? 'Destinazione non disponibile',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textColor),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: theme.successColor,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)?.inTransit ??
                                    "In transit",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.successColor),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    // Action Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: theme.surfaceColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4)
                          ]),
                      child: Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: theme.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBariSolutionsList(
      BusProvider busProvider, MapStateProvider mapState) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: busProvider.bariSolutions.length,
      itemBuilder: (context, index) {
        final solution = busProvider.bariSolutions[index];
        return Card(
          elevation: 0,
          color: theme.surfaceColor,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side:
                  BorderSide(color: theme.secondaryTextColor.withOpacity(0.1))),
          child: ExpansionTile(
            shape: Border.all(color: Colors.transparent),
            title: Text(
              "${solution.departureTime} - ${solution.arrivalTime}",
              style: TextStyle(
                  color: theme.textColor, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${solution.totalDuration} min, ${solution.transfers} cambi",
              style: TextStyle(color: theme.secondaryTextColor),
            ),
            children: solution.legs
                .map((leg) => ListTile(
                      leading:
                          Icon(Icons.directions_bus, color: theme.primaryColor),
                      title: Text("${leg.fromStop} → ${leg.toStop}",
                          style: TextStyle(color: theme.textColor)),
                      subtitle: Text(
                          "Linea ${leg.lineCode} - ${leg.duration} min",
                          style: TextStyle(color: theme.secondaryTextColor)),
                      onTap: () {},
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Color _getCityColor(String city) {
    switch (city) {
      case "Roma":
        return Provider.of<ThemeProvider>(context, listen: false).errorColor;
      case "Bari":
        return Provider.of<ThemeProvider>(context, listen: false).primaryColor;
      case "Emilia-Romagna":
        return Provider.of<ThemeProvider>(context, listen: false).warningColor;
      default:
        return Provider.of<ThemeProvider>(context, listen: false).primaryColor;
    }
  }

  BusProviderConfig? _getSelectedProvider(BusProvider busProvider) {
    return busProvider.providers.firstWhere(
      (p) => p.name == busProvider.selectedCity,
      orElse: () => BusProviderConfig(
        name: busProvider.selectedCity,
        provider: '',
        solutionsUrl: null,
        endpoints: {},
      ),
    );
  }

  void _showRouteStops(BuildContext context, String lineNumber, BusRoute route,
      ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.secondaryTextColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lineNumber,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          route.directionLabel,
                          style: TextStyle(
                              color: theme.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "${AppLocalizations.of(context)?.routeTowards ?? 'Percorso verso'} ${route.destination}",
                    style: TextStyle(
                        color: theme.secondaryTextColor, fontSize: 13),
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 60),
                    controller: scrollController,
                    itemCount: route.stops?.length ?? 0,
                    itemBuilder: (context, index) {
                      final stop = route.stops![index];
                      final isLast = index == (route.stops!.length - 1);
                      return IntrinsicHeight(
                        child: Row(
                          children: [
                            const SizedBox(width: 24),
                            Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: theme.surfaceColor, width: 2),
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      color:
                                          theme.primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      // Find full stop data to show details
                                      final busProvider =
                                          Provider.of<BusProvider>(context,
                                              listen: false);
                                      final fullStop =
                                          busProvider.stops.firstWhere(
                                        (s) => s.stopId == stop.stopId,
                                        orElse: () => BariStop(
                                            stopId: stop.stopId,
                                            stopName: stop.stopName,
                                            latitude: 0,
                                            longitude: 0),
                                      );
                                      if (fullStop.latitude != 0) {
                                        final mapState =
                                            Provider.of<MapStateProvider>(
                                                context,
                                                listen: false);
                                        mapState.flyTo(fullStop.latitude,
                                            fullStop.longitude,
                                            zoom: 16);
                                      }
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) =>
                                            BusStopDetailsSheet(stop: fullStop),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Text(
                                        stop.stopName,
                                        style: TextStyle(
                                            color: theme.textColor,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                  if (!isLast) const SizedBox(height: 8),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
