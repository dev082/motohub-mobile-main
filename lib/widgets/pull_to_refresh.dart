import 'package:flutter/material.dart';

/// A thin wrapper around [RefreshIndicator.adaptive] to standardize pull-to-refresh
/// across the app.
///
/// Notes:
/// - The [child] MUST be a scrollable (ListView/CustomScrollView/etc.).
/// - For empty states, prefer using a [ListView] with
///   `physics: const AlwaysScrollableScrollPhysics()` so the gesture still works.
class PullToRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double? edgeOffset;

  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      edgeOffset: edgeOffset ?? 0,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
