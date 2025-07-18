import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

Widget buildAppBar({
  required ThemeData theme,
  required BuildContext context,
  required VoidCallback onBack,
  required VoidCallback onShare,
  required VoidCallback onToggleFavorite,
  required bool isFavorite,
  required bool isFavoriteLoading,
  required bool watchlistChanged,
  required String imageUrl,
  required String symbol,
  required String name,
}) {
  final isDark = theme.brightness == Brightness.dark;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: onBack,
        ),
        if (imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Image.network(
              imageUrl,
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 18),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symbol.toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(name, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        if (isFavoriteLoading)
          SizedBox(
            width: 96,
            child: Shimmer.fromColors(
              baseColor: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              highlightColor: isDark ? Colors.grey[500]! : Colors.grey[100]!,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.share, size: 24),
                  SizedBox(width: 8),
                  Icon(Icons.favorite_border, size: 24),
                ],
              ),
            ),
          )
        else
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.grey),
                  onPressed: onShare,
                ),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.green : Colors.grey,
                  ),
                  onPressed: onToggleFavorite,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
