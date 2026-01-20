import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_manager_provider.dart';
import '../../core/services/android_background_service.dart';

class NotificationsManagerScreen extends StatelessWidget {
  static const routeName = '/notifications-manager';

  const NotificationsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChangeNotifierProvider(
      create: (_) => NotificationManagerProvider()..loadAll(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          title: Text('Gestore notifiche', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
              tooltip: 'Aggiorna tutto',
              onPressed: () async {
                final vm = Provider.of<NotificationManagerProvider>(context, listen: false);
                await vm.loadAll();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aggiornamento completato')));
              },
            ),
          ],
        ),
        body: Consumer<NotificationManagerProvider>(
          builder: (context, vm, child) {
            if (vm.loading) return const Center(child: CircularProgressIndicator());
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
                          Text('Gestore notifiche', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Monitora fermate e stazioni', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Fermate monitorate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                  if (vm.stops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: const [
                          Icon(Icons.directions_bus, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Nessuna fermata monitorata', style: TextStyle(color: Colors.grey)),
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
                                  title: const Text('Rimuovi monitoraggio'),
                                  content: Text('Rimuovere la fermata ${s.name}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
                                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Rimuovi')),
                                  ],
                                ),
                              ) ?? false;
                        },
                        onDismissed: (_) => vm.removeStop(s.id),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, 4)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Positioned(right: -20, top: -20, child: Icon(Icons.directions_bus, size: 120, color: theme.primaryColor.withOpacity(0.05))),
                                ListTile(
                                  leading: CircleAvatar(child: Icon(Icons.directions_bus)),
                                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.lastPreview, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Text('Aggiornato: ${s.lastUpdated}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      final vmRef = Provider.of<NotificationManagerProvider>(context, listen: false);
                                      if (action == 'refresh') {
                                        await vmRef.refreshStop(s.id);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aggiornamento forzato')));
                                      } else if (action == 'cancel') {
                                        await AndroidBackgroundService.cancelNotification(key: 'stop:${s.id}');
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifica cancellata')));
                                      } else if (action == 'remove') {
                                        await vmRef.removeStop(s.id);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'refresh', child: Text('Aggiorna')),
                                      PopupMenuItem(value: 'cancel', child: Text('Cancella notifica')),
                                      PopupMenuItem(value: 'remove', child: Text('Rimuovi')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),

                  const SizedBox(height: 16),
                  const Text('Stazioni monitorate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (vm.stations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: const [
                          Icon(Icons.train, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Nessuna stazione monitorata', style: TextStyle(color: Colors.grey)),
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
                                  title: const Text('Rimuovi monitoraggio'),
                                  content: Text('Rimuovere la stazione $sid?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
                                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Rimuovi')),
                                  ],
                                ),
                              ) ?? false;
                        },
                        onDismissed: (_) => vm.removeStation(sid),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, 4)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Positioned(right: -20, top: -20, child: Icon(Icons.train, size: 120, color: theme.primaryColor.withOpacity(0.05))),
                                ListTile(
                                  leading: CircleAvatar(child: Icon(Icons.train)),
                                  title: Text('Stazione $sid', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(vm.stationPreviews[sid] ?? 'Nessun dato', maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Text('Aggiornato: ${vm.stationLastUpdated[sid] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      final vmRef = Provider.of<NotificationManagerProvider>(context, listen: false);
                                      if (action == 'refresh') {
                                        await vmRef.refreshStation(sid);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aggiornamento forzato')));
                                      } else if (action == 'remove') {
                                        await vmRef.removeStation(sid);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'refresh', child: Text('Aggiorna')),
                                      PopupMenuItem(value: 'remove', child: Text('Rimuovi')),
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
