import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/plane_model.dart';
import '../providers/plane_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';

class FlightDetailsSheet extends StatefulWidget {
  final Flight flight;
  const FlightDetailsSheet({super.key, required this.flight});

  @override
  State<FlightDetailsSheet> createState() => _FlightDetailsSheetState();
}

class _FlightDetailsSheetState extends State<FlightDetailsSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlaneProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final Flight f = provider.selectedFlight ?? widget.flight;

    final dep = f.estimatedDeparture ?? f.scheduledDeparture;
    final arr = f.estimatedArrival ?? f.scheduledArrival;

    double progress = 0.0;
    if (dep != null && arr != null) {
      final now = DateTime.now();
      if (now.isAfter(arr)) {
        progress = 1.0;
      } else if (now.isAfter(dep)) {
        final total = arr.difference(dep).inSeconds;
        final elapsed = now.difference(dep).inSeconds;
        progress = (elapsed / total).clamp(0.0, 1.0);
      }
    }

    String _formatTime(DateTime? dt) {
      if (dt == null) return "--:--";
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${f.flightNumber}", style: TextStyle(color: theme.textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.secondaryTextColor),
                    onPressed: () {
                      provider.clearFlightSelection();
                      Navigator.of(context).pop();
                    },
                  )
                ],
              ),
              const SizedBox(height: 6),
              Text(f.airline, style: TextStyle(color: theme.secondaryTextColor)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("ORIGINE", style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
                        Text(f.origin, style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(_formatTime(f.scheduledDeparture), style: TextStyle(color: theme.secondaryTextColor)),
                        if (f.estimatedDeparture != null && f.estimatedDeparture != f.scheduledDeparture)
                          Text("Est: ${_formatTime(f.estimatedDeparture)}", style: TextStyle(color: theme.warningColor, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.flight_takeoff, color: theme.primaryColor),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("DESTINAZIONE", style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
                        Text(f.destination, style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(_formatTime(f.scheduledArrival), style: TextStyle(color: theme.secondaryTextColor)),
                        if (f.estimatedArrival != null && f.estimatedArrival != f.scheduledArrival)
                          Text("Est: ${_formatTime(f.estimatedArrival)}", style: TextStyle(color: theme.warningColor, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(color: theme.surfaceColor.withOpacity(0.06), borderRadius: BorderRadius.circular(2)),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(gradient: theme.progressGradient, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(progress * 2 - 1, 0),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Icon(Icons.airplanemode_active, color: theme.textColor, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text("${(progress * 100).toInt()}% del viaggio completato", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.surfaceColor.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    _detailRow("Status", f.statusLocalized ?? f.status, theme),
                    _detailRow("Callsign", f.callsign, theme),
                    _detailRow("Terminal", f.terminal ?? '-', theme),
                    _detailRow("Gate", f.gate ?? '-', theme),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.secondaryTextColor)),
          Text(value, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
