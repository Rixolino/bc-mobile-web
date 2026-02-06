// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocity; // pixels per second
  final double pauseDuration; // seconds

  const ScrollingText({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 30.0,
    this.pauseDuration = 2.0,
  });

  @override
  _ScrollingTextState createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _scrollAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (mounted) {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        final double duration = maxScroll / widget.velocity;

        // Pause at start
        await Future.delayed(Duration(seconds: widget.pauseDuration.toInt()));
        if (!mounted) break;

        // Scroll to end
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: (duration * 1000).toInt()),
          curve: Curves.linear,
        );
        if (!mounted) break;

        // Pause at end
        await Future.delayed(Duration(seconds: widget.pauseDuration.toInt()));
        if (!mounted) break;

        // Jump back to start
        _scrollController.jumpTo(0.0);
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
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
      ),
    );
  }
}
