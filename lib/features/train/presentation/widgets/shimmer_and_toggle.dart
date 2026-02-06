import 'package:flutter/material.dart';
import '../../../../presentation/providers/theme_provider.dart';

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
                      child: const Text("Partenze"),
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
                      child: const Text("Arrivi"),
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

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ScrollingText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> {
  late ScrollController _scrollController;
  // Track if animation is running to prevent duplicates
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndAnimate());
  }
  
  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndAnimate());
    }
  }

  void _checkAndAnimate() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0 && !_isAnimating) {
             _runAnimationLoop();
        }
    }
  }

  void _runAnimationLoop() async {
    if (_isAnimating) return;
    _isAnimating = true;

    while (mounted) {
      if (!_scrollController.hasClients) break;
      
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) break; 

      // 1. Pause at Start
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;

      // 2. Scroll to End
      // Calculate duration: ~30 pixels/sec for readability + damping
      final durationSeconds = (maxScroll / 30).toDouble().clamp(2.0, 10.0); 
      final duration = Duration(milliseconds: (durationSeconds * 1000).toInt());

      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: duration,
          curve: Curves.easeInOutQuad,
        );
      } catch (e) { break; }

      if (!mounted) break;

      // 3. Pause at End
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;

      // 4. Scroll Back
      try {
        await _scrollController.animateTo(
          0.0,
          duration: duration,
          curve: Curves.easeInOutQuad,
        );
      } catch (e) { break; }
    }
    
    _isAnimating = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), 
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
