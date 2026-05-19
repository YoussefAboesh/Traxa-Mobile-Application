import 'package:flutter/material.dart';
import 'app_skeleton.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final int itemCount;

  const LoadingIndicator({
    super.key,
    this.message,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonCardList(itemCount: itemCount);
  }
}
