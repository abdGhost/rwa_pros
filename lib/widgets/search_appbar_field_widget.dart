import 'package:flutter/material.dart';

class SearchAppBarField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCancel;
  final ValueChanged<String>? onChanged; // 🔥 Added onChanged

  const SearchAppBarField({
    super.key,
    required this.controller,
    required this.onCancel,
    this.onChanged, // 🔥 Added onChanged optional
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF0087E0), width: 0.8),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: controller,
              autofocus: true,
              cursorColor: Color(0xFF0087E0),
              onChanged: onChanged, // 🔥 Listen when user types
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Color(0xFF0087E0),
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: "Search...",
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey,
                ),
                suffixIcon:
                    controller
                            .text
                            .isNotEmpty // 🔥 Show clear button
                        ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            controller.clear();
                            if (onChanged != null) {
                              onChanged!('');
                            }
                          },
                        )
                        : null,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        // const SizedBox(width: 8),
        // // GestureDetector(
        // //   onTap: onCancel,
        // //   child: Text(
        // //     'Cancel',
        // //     style: theme.textTheme.bodyMedium?.copyWith(
        // //       color: Color(0xFF0087E0),
        // //       fontWeight: FontWeight.w600,
        // //     ),
        // //   ),
        // // ),
      ],
    );
  }
}
