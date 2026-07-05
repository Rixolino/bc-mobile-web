import 'package:flutter/material.dart';
import '../../../../presentation/providers/theme_provider.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';

class ShimmerLoading extends StatefulWidget {
  final Color baseColor;
  const ShimmerLoading({super.key, required this.baseColor});
  
  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this, 
       duration: const Duration(seconds: 1)
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: 6,
        itemBuilder: (context, index) {
           return Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: Row(
               children: [
                 Container(
                   width: 42, height: 42,
                   decoration: BoxDecoration(
                     color: widget.baseColor.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(10),
                   ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Container(
                         width: double.infinity, height: 14,
                         decoration: BoxDecoration(
                           color: widget.baseColor.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(4),
                         ),
                       ),
                       const SizedBox(height: 8),
                       Container(
                         width: 100, height: 10,
                         decoration: BoxDecoration(
                           color: widget.baseColor.withOpacity(0.05),
                           borderRadius: BorderRadius.circular(4),
                         ),
                       ),
                     ],
                   ),
                 )
               ],
             )
           );
        },
      ),
    );
  }
}

class SlidingTabToggle extends StatelessWidget {
  final bool isArrival;
  final ValueChanged<bool> onChanged;
  final ThemeProvider theme;

  const SlidingTabToggle({
    super.key,
    required this.isArrival,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 280, // Fixed width for stability
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          // Background Slider
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            alignment: isArrival ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 136,
              height: 36,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
                ]
              ),
            ),
          ),
          
          // Foreground Text
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(false),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Montserrat', // Assuming app uses this
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: !isArrival ? Colors.white : theme.secondaryTextColor,
                      ),
                      child: Text(AppLocalizations.of(context)?.departures ?? 'Partenze'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(true),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isArrival ? Colors.white : theme.secondaryTextColor,
                      ),
                      child: Text(AppLocalizations.of(context)?.arrivals ?? 'Arrivi'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
