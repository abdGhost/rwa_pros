import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

Widget _buildSkeletonBody(ThemeData theme) {
  return ListView(
    padding: const EdgeInsets.all(16),
    children: List.generate(6, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: theme.cardColor.withOpacity(0.3),
          highlightColor: theme.cardColor.withOpacity(0.1),
          child: Container(
            height: index == 1 ? 200 : 80,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }),
  );
}
