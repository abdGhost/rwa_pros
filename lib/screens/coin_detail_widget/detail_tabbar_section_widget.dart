import 'package:flutter/material.dart';

class DetailTabBarSection extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const DetailTabBarSection({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ['About', 'Reviews', 'Resources'];

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Full-width baseline line (no padding)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            color: theme.dividerColor.withOpacity(0.2),
          ),
        ),

        // Padded tab row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(labels.length, (index) {
              final isSelected = selectedIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[index],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color:
                              isSelected
                                  ? const Color(0xFF0087E0)
                                  : theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2,
                        width: 60,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? const Color(0xFF0087E0)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
