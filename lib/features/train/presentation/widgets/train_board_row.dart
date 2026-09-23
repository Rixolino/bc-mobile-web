import 'package:flutter/material.dart';

/// Riga treno in stile tabellone arrivi/partenze, condivisa tra la lista
/// treni del pannello e i tabelloni dei provider regionali.
/// Stessa grafica ovunque: barra colorata/logo, categoria+numero, badge
/// ritardo (+ pallino spettatori), riga stazione, box binario ticket,
/// orario stimato colorato con programmato barrato.
class TrainBoardRow extends StatelessWidget {
  final String category;
  final String number;
  final int delay;
  final String title;
  final String? subtitle;
  final String? platform;
  final String timeStr;
  final String? estStr;
  final Color barColor;
  final String? logoUrl;
  final bool isDark;
  final Color textColor;
  final Color secondaryTextColor;
  final Color notchColor;
  final String platformLabel;
  final int viewers;
  final bool cancelled;
  final String cancelledLabel;
  final bool showOnTimeLabel;
  final String onTimeLabel;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const TrainBoardRow({
    super.key,
    required this.category,
    required this.number,
    required this.delay,
    required this.title,
    this.subtitle,
    this.platform,
    required this.timeStr,
    this.estStr,
    required this.barColor,
    this.logoUrl,
    required this.isDark,
    required this.textColor,
    required this.secondaryTextColor,
    required this.notchColor,
    this.platformLabel = 'Bin',
    this.viewers = 0,
    this.cancelled = false,
    this.cancelledLabel = 'CANC',
    this.showOnTimeLabel = false,
    this.onTimeLabel = 'In orario',
    this.titleStyle,
    this.subtitleStyle,
    this.trailing,
    this.onTap,
  });

  Color get _timeColor {
    if (delay <= 0) return Colors.green;
    if (delay <= 5) return Colors.orange;
    if (delay <= 15) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _delayBadge() {
    if (cancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          cancelledLabel,
          style: const TextStyle(
              color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (delay > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '+$delay\'',
          style: const TextStyle(
              color: Colors.orange,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
      );
    }
    if (delay < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$delay\'',
          style: const TextStyle(
              color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (showOnTimeLabel) {
      return Text(
        onTimeLabel,
        style: const TextStyle(
            fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _platformTicket(String bin) {
    final bg = isDark ? const Color(0xFF5A5A5A) : const Color(0xFF4A4A4A);
    return Semantics(
      label: '$platformLabel $bin',
      child: Container(
        width: 32,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  bin,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: notchColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: notchColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (logoUrl != null)
                Container(
                  height: 24,
                  constraints: const BoxConstraints(maxWidth: 50),
                  padding: isDark
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                      : EdgeInsets.zero,
                  decoration: isDark
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        )
                      : null,
                  child: Image.network(
                    logoUrl!,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, __, ___) => Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$category $number'.trim(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _delayBadge(),
                        if (viewers > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$viewers',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: subtitleStyle ??
                            TextStyle(
                                fontSize: 12, color: secondaryTextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      title.isNotEmpty ? title : '--',
                      style: titleStyle ??
                          TextStyle(
                              color: secondaryTextColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (platform != null && platform!.isNotEmpty) ...[
                    _platformTicket(platform!),
                    const SizedBox(width: 10),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        estStr != null && estStr != timeStr
                            ? estStr!
                            : timeStr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: estStr != null && estStr != timeStr
                              ? _timeColor
                              : textColor,
                          fontSize: 15,
                        ),
                      ),
                      if (estStr != null && estStr != timeStr)
                        Text(
                          timeStr,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    trailing!,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
