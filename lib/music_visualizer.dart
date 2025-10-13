// music_visualizer.dart

import 'package:flutter/material.dart';

class MusicVisualizer extends StatefulWidget {
  final bool isPlaying; // 接收播放狀態
  final Color color;
  final int barCount;
  final Duration duration;

  const MusicVisualizer({
    Key? key,
    required this.isPlaying,
    this.color = Colors.cyan,
    this.barCount = 3,
    this.duration = const Duration(milliseconds: 600),
  }) : super(key: key);

  @override
  _MusicVisualizerState createState() => _MusicVisualizerState();
}

class _MusicVisualizerState extends State<MusicVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animations = List.generate(widget.barCount, (index) {
      final double intervalStart = index / widget.barCount;
      final double intervalEnd = (index + 1) / widget.barCount;

      return Tween<double>(begin: 0.1, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(intervalStart, intervalEnd, curve: Curves.easeInOut),
        ),
      );
    });

    // 根据初始状态决定是否播放动画
    _updateAnimationState();
  }

  // 【新增】didUpdateWidget 生命周期方法
  // 当父 Widget 重建并传入新的 isPlaying 值时，这个方法会被调用
  @override
  void didUpdateWidget(covariant MusicVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当 isPlaying 的状态真正改变时，才更新动画控制器
    if (widget.isPlaying != oldWidget.isPlaying) {
      _updateAnimationState();
    }
  }

  // 【新增】一个封装了动画控制逻辑的方法
  void _updateAnimationState() {
    if (widget.isPlaying) {
      _controller.repeat(reverse: true); // 如果 isPlaying 是 true，就播放动画
    } else {
      _controller.stop(); // 如果 isPlaying 是 false，就停止动画
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.barCount, (index) {
        return AnimatedBuilder(
          animation: _controller, // <-- 改为监听 _controller 整体
          builder: (context, child) {
            // 如果动画停止了，我们希望它保持在一个较低的静态高度，而不是完全消失
            final height = widget.isPlaying ? (12.0 * _animations[index].value) : 2.0;
            return Container(
              width: 3.0,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(5),
              ),
            );
          },
        );
      }),
    );
  }
}