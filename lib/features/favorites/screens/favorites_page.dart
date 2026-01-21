import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // Per l'effetto Glassmorphism
import '../providers/favorites_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/train/presentation/providers/train_provider.dart';
import '../../../features/bus/presentation/providers/bus_provider.dart';
import '../../../features/train/presentation/widgets/train_details_sheet.dart';
import '../../../features/train/presentation/widgets/train_panel_content.dart';
import '../../../features/bus/presentation/widgets/bus_details_sheet.dart';
import '../../../features/bus/presentation/widgets/bus_stop_details_sheet.dart';
import '../../../features/train/data/models/train_model.dart';
import '../../../features/bus/data/models/bus_model.dart';
import '../models/favorite_item.dart';
import '../models/favorite_stop.dart';
import '../models/favorite_train.dart';
import '../models/favorite_bus_line.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  // Invece di TabController, usiamo una selezione per il filtro del feed
  String _selectedFilter = 'Tutti'; // Opzioni: 'Tutti', 'Fermate', 'Treni', 'Bus'
  final ScrollController _scrollController = ScrollController();

  // Stati per dati reali
  Map<String, dynamic> _realTimeData = {}; // Cache per dati in tempo reale
  bool _isLoadingRealTime = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadRealTimeData();
    });
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      favoritesProvider.loadFavorites(authProvider.currentUser!.id.toString());
    }
  }

  Future<void> _loadRealTimeData() async {
    if (_isLoadingRealTime) return;

    setState(() => _isLoadingRealTime = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
      final trainProvider = Provider.of<TrainProvider>(context, listen: false);
      final busProvider = Provider.of<BusProvider>(context, listen: false);

      if (authProvider.currentUser == null) return;

      // Carica dati per treni preferiti
      for (final train in favoritesProvider.favoriteTrains) {
        try {
          await trainProvider.searchTrainByNumber(train.trainNumber);
          if (trainProvider.searchResults.isNotEmpty) {
            _realTimeData[train.id] = trainProvider.searchResults.first;
          }
        } catch (e) {
          print('Errore caricamento treno ${train.trainNumber}: $e');
        }
      }

      // Carica dati per linee bus preferite
      for (final busLine in favoritesProvider.favoriteBusLines) {
        try {
          await busProvider.fetchVehicles();
          // Trova veicoli per questa linea
          final matchingVehicles = busProvider.vehicles
              .where((vehicle) => vehicle.line == busLine.lineCode)
              .toList();
          if (matchingVehicles.isNotEmpty) {
            _realTimeData[busLine.id] = matchingVehicles.first;
          }
        } catch (e) {
          print('Errore caricamento bus ${busLine.lineCode}: $e');
        }
      }

      // Carica dati per fermate preferite (differenziamo tra fermate bus e stazioni treno)
      for (final stop in favoritesProvider.favoriteStops) {
        try {
          if (stop.stopType == StopType.busStop) {
            await busProvider.fetchStops();
            final matchingStop = busProvider.stops
                .where((s) => s.stopName.toLowerCase().contains(stop.name.toLowerCase()) ||
                             s.stopId == stop.code)
                .toList();
            if (matchingStop.isNotEmpty) {
              _realTimeData[stop.id] = matchingStop.first;
            }
          } else if (stop.stopType == StopType.trainStation) {
            // Cerca la stazione treno
            await trainProvider.searchStations(stop.name);
            if (trainProvider.stationSuggestions.isNotEmpty) {
              _realTimeData[stop.id] = trainProvider.stationSuggestions.first;
            }
          }
        } catch (e) {
          print('Errore caricamento fermata ${stop.name}: $e');
        }
      }

    } catch (e) {
      print('Errore caricamento dati real-time: $e');
    } finally {
      setState(() => _isLoadingRealTime = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favoritesProvider = Provider.of<FavoritesProvider>(context);

    // Uniamo tutte le liste in base al filtro per creare un unico Feed
    List<FavoriteItem> feedItems = [];
    // Aggiungi fermate e stazioni in base al filtro
    if (_selectedFilter == 'Tutti' || _selectedFilter == 'Fermate') {
      // Solo fermate bus
      feedItems.addAll(favoritesProvider.favoriteStops.where((s) => s.stopType == StopType.busStop));
    }

    if (_selectedFilter == 'Tutti' || _selectedFilter == 'Treni') {
      // Treni e stazioni (stazioni salvate come FavoriteStop con StopType.trainStation)
      feedItems.addAll(favoritesProvider.favoriteTrains);
      feedItems.addAll(favoritesProvider.favoriteStops.where((s) => s.stopType == StopType.trainStation));
    }

    if (_selectedFilter == 'Tutti' || _selectedFilter == 'Bus') {
      feedItems.addAll(favoritesProvider.favoriteBusLines);
    }

    // Ordiniamo per data di aggiunta (opzionale, o per tipo)
    // feedItems.sort((a, b) => b.createdAt.compareTo(a.createdAt)); 

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. Modern Sliver App Bar con Saluto
          _buildSliverAppBar(context),

          // 2. Filtri orizzontali (Chips)
          SliverToBoxAdapter(
            child: _buildFilterChips(theme),
          ),

          // 3. Il Feed dei Preferiti
          favoritesProvider.isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : feedItems.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyFeedState(theme))
                  : SliverPadding(
                      padding: const EdgeInsets.only(bottom: 100, top: 10),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = feedItems[index];
                            // Allow swipe-to-delete for FavoriteTrain items
                            if (item is FavoriteTrain) {
                              final train = item;
                              return Dismissible(
                                key: ValueKey(train.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (direction) async {
                                  final removed = train;
                                  final success = await favoritesProvider.removeTrainFavorite(removed.trainNumber, removed.departureStation, removed.arrivalStation);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Treno rimosso dai preferiti'),
                                        action: SnackBarAction(
                                          label: 'Annulla',
                                          onPressed: () async {
                                            await favoritesProvider.addTrainFavorite(removed);
                                          },
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore durante la rimozione del preferito')));
                                  }
                                },
                                child: _buildFeedItem(context, item, favoritesProvider),
                              );
                            }

                            return _buildFeedItem(context, item, favoritesProvider);
                          },
                          childCount: feedItems.length,
                        ),
                      ),
                    ),
        ],
      ),
      // Floating Action Button per aggiungere rapidamente (opzionale)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            // Logica per navigare alla ricerca
        },
        label: const Text('Esplora'),
        icon: const Icon(Icons.add_location_alt_outlined),
        backgroundColor: theme.primaryColor,
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.currentUser?.nickname ?? 'Viaggiatore';
    
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      centerTitle: false,
      titleSpacing: 8.0,
      title: Text(
        'Preferiti',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: kToolbarHeight, top: 0),
        title: null,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                theme.primaryColor.withOpacity(0.15),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50), // Spazio tra titolo (toolbar) e saluto (min 30px)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ciao, $userName 👋',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pronto a partire?',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: _isLoadingRealTime
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          onPressed: _isLoadingRealTime ? null : () => _loadRealTimeData(),
          tooltip: 'Aggiorna dati real-time',
        ),
      ],
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final filters = ['Tutti', 'Fermate', 'Treni', 'Bus'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilterChip(
                selected: isSelected,
                label: Text(filter),
                onSelected: (bool selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                backgroundColor: theme.cardColor,
                selectedColor: theme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                elevation: isSelected ? 4 : 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : theme.dividerColor.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeedItem(BuildContext context, FavoriteItem item, FavoritesProvider provider) {
    if (item is FavoriteTrain) {
      return _buildLiveTrainCard(context, item, provider);
    } else if (item is FavoriteStop) {
      return _buildLiveStopCard(context, item, provider);
    } else if (item is FavoriteBusLine) {
      return _buildLiveBusCard(context, item, provider);
    }
    return const SizedBox.shrink();
  }

  // --- WIDGET CARD RIVOLUZIONATE ---

  Widget _buildLiveTrainCard(BuildContext context, FavoriteTrain train, FavoritesProvider provider) {
    final theme = Theme.of(context);
    final realTimeData = _realTimeData[train.id];
    final isFav = provider.isTrainFavorite(train.trainNumber, train.departureStation, train.arrivalStation);

    return GestureDetector(
      onTap: () => _showDetailSheet(context, train),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Sfondo decorativo
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Icons.train, size: 150, color: theme.primaryColor.withOpacity(0.05)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.train, size: 16, color: Colors.orange[800]),
                              const SizedBox(width: 6),
                              Text(
                                train.trainNumber,
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900]),
                              ),
                            ],
                          ),
                        ),
                        // Stato Live basato su dati reali + pulsante preferito
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLiveStatusIndicator(realTimeData),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: isFav ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
                              icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.orange : theme.colorScheme.onSurface),
                              onPressed: () async {
                                // toggle favorite and show snackbar with undo
                                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                if (isFav) {
                                  final success = await provider.removeTrainFavorite(train.trainNumber, train.departureStation, train.arrivalStation);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Treno rimosso dai preferiti'),
                                        action: SnackBarAction(
                                          label: 'Annulla',
                                          onPressed: () async {
                                            await provider.addTrainFavorite(train);
                                          },
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore durante la rimozione')));
                                  }
                                } else {
                                  final success = await provider.addTrainFavorite(train);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Treno aggiunto ai preferiti'),
                                        action: SnackBarAction(
                                          label: 'Annulla',
                                          onPressed: () async {
                                            await provider.removeTrainFavorite(train.trainNumber, train.departureStation, train.arrivalStation);
                                          },
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore durante l\'aggiunta')));
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Percorso
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStationInfo(theme, train.departureStation, train.departureTime, CrossAxisAlignment.start),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Divider(color: theme.dividerColor, thickness: 2),
                                Icon(Icons.directions_railway_filled, size: 16, color: theme.disabledColor),
                              ],
                            ),
                          ),
                        ),
                        _buildStationInfo(theme, train.arrivalStation, train.arrivalTime, CrossAxisAlignment.end),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Footer Azioni
                    Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          train.operator ?? 'Trenitalia',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14, color: theme.disabledColor),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusIndicator(dynamic realTimeData) {
    if (realTimeData is TrainDeparture) {
      // Logica per determinare lo stato basato sui dati reali
      final now = DateTime.now();
      final departureTime = realTimeData.scheduledTime;
      final delay = realTimeData.delayMinutes ?? 0;

      if (departureTime != null && departureTime.isBefore(now)) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.directions_run, size: 8, color: Colors.blue),
              SizedBox(width: 4),
              Text('In viaggio', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      } else if (delay > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 8, color: Colors.red),
              const SizedBox(width: 4),
              Text('+${delay}min', style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle, size: 8, color: Colors.green),
              SizedBox(width: 4),
              Text('In orario', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }
    }

    // Default quando non ci sono dati real-time
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: const [
          Icon(Icons.access_time, size: 8, color: Colors.grey),
          SizedBox(width: 4),
          Text('Caricamento...', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStationInfo(ThemeData theme, String station, String time, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          _formatTime(time),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 100,
          child: Text(
            station,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignment == CrossAxisAlignment.end ? TextAlign.right : TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStopCard(BuildContext context, FavoriteStop stop, FavoritesProvider provider) {
    final theme = Theme.of(context);
    final realTimeData = _realTimeData[stop.id];

    return GestureDetector(
      onTap: () => _showDetailSheet(context, stop),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.cardColor, theme.cardColor.withOpacity(0.95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.place, color: Colors.blue[700]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        // If we don't have city stored in the favorite, fall back to provider name (many bus stop models like BariStop don't include a city field)
                        stop.stopType == StopType.trainStation
                          ? 'Stazione${stop.city != null && stop.city!.isNotEmpty ? ' • ${_capitalizeFirst(stop.city)}' : ''}${stop.country != null && stop.country!.isNotEmpty ? ' • ${_capitalizeFirst(stop.country)}' : ''}'
                          : 'Città${stop.city != null && stop.city!.isNotEmpty ? ' • ${_capitalizeFirst(stop.city)}' : (stop.provider != null && stop.provider!.isNotEmpty ? ' • ${_capitalizeFirst(stop.provider)}' : '')}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptions(context, stop, provider),
                )
              ],
            ),
            const SizedBox(height: 16),
            // Partenze reali dalla fermata o stazione
            if (stop.stopType == StopType.busStop && realTimeData is BariStop)
              _buildRealDepartures(context, realTimeData)
            else if (stop.stopType == StopType.trainStation && realTimeData is TrainStation)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.train, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tocca per vedere arrivi/partenze della stazione',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tocca per vedere le partenze in tempo reale',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealDepartures(BuildContext context, BariStop stop) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus, size: 16, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Prossime partenze',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Qui dovremmo mostrare le partenze reali dalla BusStopDetailsSheet
          // Per ora mostriamo un placeholder che invita a vedere i dettagli
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, size: 16, color: theme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tocca per vedere tutte le partenze',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBusCard(BuildContext context, FavoriteBusLine bus, FavoritesProvider provider) {
    final theme = Theme.of(context);
    final realTimeData = _realTimeData[bus.id];

    return GestureDetector(
      onTap: () => _showDetailSheet(context, bus),
      child: Container(
        height: 100, // Compatto
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Text(
                  bus.lineCode,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.lineName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (realTimeData is BusVehicle) ...[
                          const Icon(Icons.check_circle, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'In orario',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                          ),
                        ] else ...[
                          const Icon(Icons.rss_feed, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Caricamento...',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ]
                      ],
                    )
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.star, color: Colors.amber[400]),
              onPressed: () => _showOptions(context, bus, provider),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFeedState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 80, color: theme.disabledColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            "Il tuo feed è vuoto",
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.disabledColor),
          ),
          const SizedBox(height: 8),
          Text(
            "Aggiungi fermate e treni per vederli qui.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
          ),
        ],
      ),
    );
  }

  // --- INTERAZIONI BOTTOM SHEET (Il "Details Sheet") ---

  Future<void> _showDetailSheet(BuildContext context, dynamic item) async {
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);

    if (item is FavoriteTrain) {
      // Usa il detail sheet del treno con dati reali
      final realTimeData = _realTimeData[item.id];
      if (realTimeData is TrainDeparture) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.transparent,
          builder: (context) => TrainDetailsSheet(
            departure: realTimeData,
            isArrivalMode: trainProvider.isArrivalMode,
          ),
        );
      } else {
        // Fallback: cerca il treno in tempo reale
        _showTrainSearchSheet(context, item);
      }
    } else if (item is FavoriteBusLine) {
      // Usa il detail sheet del bus con dati reali
      final realTimeData = _realTimeData[item.id];
      if (realTimeData is BusVehicle) {
        // Imposta il bus selezionato nel provider prima di mostrare il sheet
        final busProvider = Provider.of<BusProvider>(context, listen: false);
        busProvider.selectBus(realTimeData);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => BusDetailsSheet(bus: realTimeData, page: 'favorites'),
        );
      } else {
        // Fallback: cerca veicoli per questa linea
        _showBusSearchSheet(context, item);
      }
    } else if (item is FavoriteStop) {
      // Differenzia tra fermata bus e stazione treno
      final realTimeData = _realTimeData[item.id];
      if (item.stopType == StopType.trainStation) {
        // Apri il pannello stazione treni
        if (realTimeData is TrainStation) {
          // Se abbiamo la stazione, la selezioniamo e mostriamo il pannello treni
          trainProvider.selectStation(realTimeData);
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => FractionallySizedBox(heightFactor: 0.85, child: TrainPanelContent(showModeToggle: true)),
          );
        } else {
          // Fallback: mostra ricerca stazioni treno
          _showTrainStationSearchSheet(context, item);
        }
      } else {
        // Fermata bus
        if (realTimeData is BariStop) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => BusStopDetailsSheet(stop: realTimeData),
          );
        } else {
          // Fallback: cerca la fermata
          _showStopSearchSheet(context, item);
        }
      }
    }
  }

  void _showTrainSearchSheet(BuildContext context, FavoriteTrain train) {
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Maniglia per trascinare
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: Consumer<TrainProvider>(
                  builder: (context, provider, child) {
                    if (provider.isSearchingByNumber) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.searchResults.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.train, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Treno ${train.trainNumber} non trovato',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(24),
                      itemCount: provider.searchResults.length,
                      itemBuilder: (context, index) {
                        final result = provider.searchResults[index];
                        if (result is TrainDeparture) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(Icons.train, color: Colors.orange),
                              title: Text('Treno ${result.trainNumber}'),
                              subtitle: Text('${result.origin ?? 'N/A'} → ${result.destination ?? 'N/A'}'),
                              trailing: Text(result.scheduledTime != null ? '${result.scheduledTime!.hour.toString().padLeft(2, '0')}:${result.scheduledTime!.minute.toString().padLeft(2, '0')}' : 'N/A'),
                              onTap: () {
                                Navigator.pop(context);
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  barrierColor: Colors.transparent,
                                  builder: (context) => TrainDetailsSheet(
                                    departure: result,
                                    isArrivalMode: provider.isArrivalMode,
                                  ),
                                );
                              },
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Avvia la ricerca
    trainProvider.searchTrainByNumber(train.trainNumber);
  }

  void _showBusSearchSheet(BuildContext context, FavoriteBusLine busLine) {
    final busProvider = Provider.of<BusProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: Consumer<BusProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final matchingVehicles = provider.vehicles
                        .where((vehicle) => vehicle.line == busLine.lineCode)
                        .toList();

                    if (matchingVehicles.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_bus, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Linea ${busLine.lineCode} non trovata',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(24),
                      itemCount: matchingVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = matchingVehicles[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                vehicle.line,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            title: Text(vehicle.destination ?? 'Sconosciuta'),
                            subtitle: Text('ID: ${vehicle.id}'),
                            trailing: const Icon(Icons.check_circle, color: Colors.green),
                            onTap: () {
                              Navigator.pop(context);
                              // Imposta il bus selezionato nel provider prima di mostrare il sheet
                              final busProvider = Provider.of<BusProvider>(context, listen: false);
                              busProvider.selectBus(vehicle);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => BusDetailsSheet(bus: vehicle, page: 'favorites'),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Carica i veicoli
    busProvider.fetchVehicles();
  }

  void _showStopSearchSheet(BuildContext context, FavoriteStop stop) {
    final busProvider = Provider.of<BusProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: Consumer<BusProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoadingStops) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final matchingStops = provider.stops
                        .where((s) => s.stopName.toLowerCase().contains(stop.name.toLowerCase()) ||
                                     s.stopId == stop.code)
                        .toList();

                    if (matchingStops.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Fermata "${stop.name}" non trovata',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(24),
                      itemCount: matchingStops.length,
                      itemBuilder: (context, index) {
                        final foundStop = matchingStops[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.green),
                            title: Text(foundStop.stopName),
                            subtitle: Text('ID: ${foundStop.stopId}'),
                            onTap: () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => BusStopDetailsSheet(stop: foundStop),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Carica le fermate
    busProvider.fetchStops();
  }

  void _showTrainStationSearchSheet(BuildContext context, FavoriteStop stop) async {
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);

    // Cerca le stazioni basate sul nome e nel country salvato
    final countryArg = (stop.country != null && stop.country!.isNotEmpty) ? stop.country! : null;
    if (countryArg != null) {
      await trainProvider.searchStations(stop.name, country: countryArg);
    } else {
      await trainProvider.searchStations(stop.name);
    }

    // Se non trovi nulla e non abbiamo country salvato (vecchi preferiti), prova un fallback europeo
    if (trainProvider.stationSuggestions.isEmpty && (stop.country == null || stop.country!.isEmpty)) {
      await trainProvider.searchStations(stop.name, country: 'EU');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: Consumer<TrainProvider>(
                  builder: (context, provider, child) {
                    if (provider.stationSuggestions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_city, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Stazione "${stop.name}" non trovata',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(24),
                      itemCount: provider.stationSuggestions.length,
                      itemBuilder: (context, index) {
                        final s = provider.stationSuggestions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.location_city, color: Colors.blue),
                            title: Text(s.name),
                            subtitle: Text(s.country),
                            onTap: () async {
                              Navigator.pop(context);
                              trainProvider.selectStation(s);
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => FractionallySizedBox(heightFactor: 0.85, child: TrainPanelContent(showModeToggle: true)),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, FavoriteItem item, FavoritesProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Rimuovi dai preferiti'),
              onTap: () {
                Navigator.pop(context);
                provider.removeFavorite(item.id, item.userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timeString) {
    try {
      final dateTime = DateTime.parse(timeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeString;
    }
  }

  // Capitalize the first character of a string (preserve the rest of the text)
  String _capitalizeFirst(String? s) {
    if (s == null) return '';
    final t = s.trim();
    if (t.isEmpty) return '';
    return t[0].toUpperCase() + t.substring(1);
  }
}