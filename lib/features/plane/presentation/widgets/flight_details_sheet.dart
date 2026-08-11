import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/plane_model.dart';
import '../providers/plane_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/services/runtime_localizations.dart';
import '../../../../core/design_system.dart';

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
    final theme = Provider.of<ThemeProvider>(context);
    final f = provider.selectedFlight ?? widget.flight;

    final dep = f.estimatedDeparture ?? f.scheduledDeparture;
    final arr = f.estimatedArrival ?? f.scheduledArrival;

    double progress = 0.0;
    String statusText = 'In volo';
    Color statusColor = theme.primaryColor;
    if (dep != null && arr != null) {
      final now = DateTime.now();
      if (now.isAfter(arr)) {
        progress = 1.0;
        statusText = 'Atterrato';
        statusColor = theme.successColor;
      } else if (now.isAfter(dep)) {
        final total = arr.difference(dep).inSeconds;
        final elapsed = now.difference(dep).inSeconds;
        progress = (elapsed / total).clamp(0.0, 1.0);
        statusText = 'In volo';
        statusColor = AppTokens.planeColor;
      } else {
        statusText = 'In partenza';
        statusColor = theme.warningColor;
      }
    }

    String fmt(DateTime? dt) {
      if (dt == null) return '--:--';
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Column(
        children: [
          // ── HERO HEADER ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTokens.brandBlue.withValues(alpha: theme.isDark ? 0.3 : 0.15),
                  AppTokens.brandPurple.withValues(alpha: theme.isDark ? 0.2 : 0.08),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    // AppBar row
                    Row(
                      children: [
                        _CircleBackButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () {
                            provider.clearFlightSelection();
                            Navigator.of(context).pop();
                          },
                          theme: theme,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(f.flightNumber, style: AppTextStyle.headlineSmall(color: theme.textColor)),
                              const SizedBox(height: 2),
                              Text(f.airline, style: AppTextStyle.bodySmall(color: theme.secondaryTextColor)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Route
                    Row(
                      children: [
                        Expanded(
                          child: _RoutePoint(
                            code: f.origin ?? '???',
                            time: fmt(f.scheduledDeparture),
                            estimated: f.estimatedDeparture != null && f.estimatedDeparture != f.scheduledDeparture ? fmt(f.estimatedDeparture) : null,
                            theme: theme,
                            align: CrossAxisAlignment.start,
                          ),
                        ),
                        // Progress bar + plane
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: theme.borderColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      height: 3,
                                      margin: const EdgeInsets.symmetric(horizontal: 24),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.blueGradient,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment(progress * 2 - 1, 0),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTokens.planeColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: AppTokens.planeColor.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1),
                                      ],
                                    ),
                                    child: const Icon(Icons.airplanemode_active, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: _RoutePoint(
                            code: f.destination ?? '???',
                            time: fmt(f.scheduledArrival),
                            estimated: f.estimatedArrival != null && f.estimatedArrival != f.scheduledArrival ? fmt(f.estimatedArrival) : null,
                            theme: theme,
                            align: CrossAxisAlignment.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── BODY ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status pill
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: theme.isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(width: 12),
                          Text('${(progress * 100).toInt()}%', style: TextStyle(color: theme.secondaryTextColor, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details card
                  Text(
                    RuntimeLocalizations.t(context, 'flight_details') ?? 'Dettagli Volo',
                    style: AppTextStyle.titleMedium(color: theme.textColor),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                      border: Border.all(color: theme.borderColor.withValues(alpha: theme.isDark ? 0.15 : 0.1)),
                    ),
                    child: Column(
                      children: [
                        _DetailRow(label: 'Status', value: f.statusLocalized ?? f.status ?? 'N/A', theme: theme),
                        const Divider(height: 20),
                        _DetailRow(label: 'Callsign', value: f.callsign ?? 'N/A', theme: theme),
                        const Divider(height: 20),
                        _DetailRow(label: 'Terminal', value: f.terminal ?? 'N/A', theme: theme),
                        const Divider(height: 20),
                        _DetailRow(label: 'Gate', value: f.gate ?? 'N/A', theme: theme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeProvider theme;

  const _CircleBackButton({required this.icon, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.surfaceColor.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border: Border.all(color: theme.borderColor.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: theme.textColor, size: 18),
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String code;
  final String time;
  final String? estimated;
  final ThemeProvider theme;
  final CrossAxisAlignment align;

  const _RoutePoint({required this.code, required this.time, this.estimated, required this.theme, required this.align});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(code, style: AppTextStyle.headlineMedium(color: theme.textColor)),
        const SizedBox(height: 4),
        Text(time, style: AppTextStyle.bodyMedium(color: theme.secondaryTextColor)),
        if (estimated != null)
          Text(estimated!, style: AppTextStyle.bodySmall(color: theme.warningColor).copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeProvider theme;

  const _DetailRow({required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyle.bodyMedium(color: theme.secondaryTextColor)),
        Text(value, style: AppTextStyle.bodyMedium(color: theme.textColor).copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
