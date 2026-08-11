import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_manager_provider.dart';
import '../../core/services/android_background_service.dart';
import '../../core/design_system.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../core/services/runtime_localizations.dart';

class NotificationsManagerScreen extends StatelessWidget {
  static const routeName = '/notifications-manager';

  const NotificationsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    return ChangeNotifierProvider(
      create: (_) => NotificationManagerProvider()..loadAll(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          title: Text(loc?.notificationsManager ?? 'Gestore notifiche',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
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
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: loc?.refreshAll ?? 'Aggiorna tutto',
              onPressed: () async {
                final vm = Provider.of<NotificationManagerProvider>(context,
                    listen: false);
                await vm.loadAll();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        loc?.refreshCompleted ?? 'Aggiornamento completato')));
              },
            ),
          ],
        ),
        body: Consumer<NotificationManagerProvider>(
          builder: (context, vm, child) {
            if (vm.loading)
              return const Center(child: CircularProgressIndicator());
            return RefreshIndicator(
              onRefresh: vm.loadAll,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Container(
                    height: 140,
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
                            Text(
                                loc?.notificationsManager ??
                                    'Gestore notifiche',
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                                loc?.monitorStopsStations ??
                                    'Monitora fermate e stazioni',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(loc?.monitoredStops ?? 'Fermate monitorate',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (vm.stops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.directions_bus,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(RuntimeLocalizations.t(context, 'no_monitored_stops'),
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),

                  ...vm.stops.map((s) => Dismissible(
                        key: ValueKey('stop-${s.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(loc?.removeMonitoring ??
                                      'Rimuovi monitoraggio'),
                                  content: Text(
                                      loc?.removeStopQuestion(s.name) ??
                                          'Rimuovere la fermata ${s.name}?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(loc?.cancel ?? 'Annulla')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(loc?.remove ?? 'Rimuovi')),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) => vm.removeStop(s.id),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Positioned(
                                    right: -20,
                                    top: -20,
                                    child: Icon(Icons.directions_bus,
                                        size: 120,
                                        color: theme.primaryColor
                                            .withOpacity(0.05))),
                                ListTile(
                                  leading: CircleAvatar(
                                      child: Icon(Icons.directions_bus)),
                                  title: Text(s.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.lastPreview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Text(
                                          loc?.updatedAt(
                                                  s.lastUpdated.toString()) ??
                                              'Aggiornato: ${s.lastUpdated}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      final vmRef = Provider.of<
                                              NotificationManagerProvider>(
                                          context,
                                          listen: false);
                                      if (action == 'refresh') {
                                        await vmRef.refreshStop(s.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(loc
                                                        ?.forceRefresh ??
                                                    'Aggiornamento forzato')));
                                      } else if (action == 'cancel') {
                                        await AndroidBackgroundService
                                            .cancelNotification(
                                                key: 'stop:${s.id}');
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    loc?.notificationCancelled ??
                                                        'Notifica cancellata')));
                                      } else if (action == 'remove') {
                                        await vmRef.removeStop(s.id);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'refresh',
                                        child: Text(RuntimeLocalizations.t(context, 'refresh_label'))),
                                      PopupMenuItem(
                                        value: 'cancel',
                                        child: Text(RuntimeLocalizations.t(context, 'cancel_notification_label'))),
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text(RuntimeLocalizations.t(context, 'remove_label'))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),

                  const SizedBox(height: 16),
                  Text(loc?.monitoredStations ?? 'Stazioni monitorate',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (vm.stations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.train, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                              loc?.noMonitoredStations ??
                                  'Nessuna stazione monitorata',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),

                  // Treni monitorati
                  const SizedBox(height: 16),
                  Text(loc?.monitoredTrains ?? 'Treni monitorati',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (vm.trips.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.train, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                              loc?.noMonitoredTrains ??
                                  'Nessun treno monitorato',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),

                  ...vm.trips.map((t) => Dismissible(
                        key: ValueKey('trip-${t.tripId}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(loc?.removeMonitoring ??
                                      'Rimuovi monitoraggio'),
                                  content: Text(loc?.removeTrainQuestion(
                                          vm.tripTitles[t.tripId] ??
                                              t.tripId) ??
                                      'Rimuovere il monitoraggio per il treno ${vm.tripTitles[t.tripId] ?? t.tripId}?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(loc?.cancel ?? 'Annulla')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(loc?.remove ?? 'Rimuovi')),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) => vm.removeTrip(t.tripId),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Positioned(
                                    right: -20,
                                    top: -20,
                                    child: Icon(Icons.train,
                                        size: 120,
                                        color: theme.primaryColor
                                            .withOpacity(0.05))),
                                ListTile(
                                  leading:
                                      CircleAvatar(child: Icon(Icons.train)),
                                  title: Text(
                                      vm.tripTitles[t.tripId] ?? t.tripId,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          vm.tripPreviews[t.tripId] ??
                                              (loc?.noData ?? 'Nessun dato'),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                        if (t.endpoint != null)
                                        Text('${RuntimeLocalizations.t(context, 'url_label')}: ${t.endpoint}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)
                                        else if (t.country != null)
                                        Text('${RuntimeLocalizations.t(context, 'country_label')}: ${t.country}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                      const SizedBox(height: 6),
                                      Text(
                                          loc?.updatedAt(vm.tripLastUpdated[
                                                      t.tripId] ??
                                                  '') ??
                                              'Aggiornato: ${vm.tripLastUpdated[t.tripId] ?? ''}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      final vmRef = Provider.of<
                                              NotificationManagerProvider>(
                                          context,
                                          listen: false);
                                      if (action == 'refresh') {
                                        await vmRef.refreshTrip(t.tripId);
                                        ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                            content: Text(RuntimeLocalizations.t(context, 'force_refresh'))));
                                      } else if (action == 'cancel') {
                                        await AndroidBackgroundService
                                            .cancelNotification(
                                                key: 'train:${t.tripId}');
                                        ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                            content: Text(RuntimeLocalizations.t(context, 'notification_cancelled'))));
                                      } else if (action == 'remove') {
                                        await vmRef.removeTrip(t.tripId);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'refresh',
                                        child: Text(RuntimeLocalizations.t(context, 'refresh_label'))),
                                      PopupMenuItem(
                                        value: 'cancel',
                                        child: Text(RuntimeLocalizations.t(context, 'cancel_notification_label'))),
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text(RuntimeLocalizations.t(context, 'remove_label'))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),

                  if (vm.stations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.train, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                              loc?.noMonitoredStations ??
                                  'Nessuna stazione monitorata',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),

                  ...vm.stations.map((sid) => Dismissible(
                        key: ValueKey('station-$sid'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(loc?.removeMonitoring ??
                                      'Rimuovi monitoraggio'),
                                  content: Text(
                                      loc?.removeStationQuestion(sid) ??
                                          'Rimuovere la stazione $sid?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(loc?.cancel ?? 'Annulla')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(loc?.remove ?? 'Rimuovi')),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) => vm.removeStation(sid),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Positioned(
                                    right: -20,
                                    top: -20,
                                    child: Icon(Icons.train,
                                        size: 120,
                                        color: theme.primaryColor
                                            .withOpacity(0.05))),
                                ListTile(
                                  leading:
                                      CircleAvatar(child: Icon(Icons.train)),
                                  title: Text(
                                      loc?.stationWithId(sid) ??
                                          'Stazione $sid',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          vm.stationPreviews[sid] ??
                                              (loc?.noData ?? 'Nessun dato'),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Text(
                                          loc?.updatedAt(
                                                  vm.stationLastUpdated[sid] ??
                                                      '') ??
                                              'Aggiornato: ${vm.stationLastUpdated[sid] ?? ''}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      final vmRef = Provider.of<
                                              NotificationManagerProvider>(
                                          context,
                                          listen: false);
                                      if (action == 'refresh') {
                                        await vmRef.refreshStation(sid);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(loc
                                                        ?.forceRefresh ??
                                                    'Aggiornamento forzato')));
                                      } else if (action == 'remove') {
                                        await vmRef.removeStation(sid);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'refresh',
                                          child: Text('Aggiorna')),
                                      PopupMenuItem(
                                          value: 'remove',
                                          child: Text('Rimuovi')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 36),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
