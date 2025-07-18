import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rwa_app/screens/treasury_screen.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? change;
  final String? imageUrl;
  final Color changeColor;
  final double width;
  final bool isFirst;
  final bool isLast;
  final bool isFearGreed;
  final Widget? bottomWidget;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.change,
    this.imageUrl,
    required this.changeColor,
    required this.width,
    this.isFirst = false,
    this.isLast = false,
    this.isFearGreed = false,
    this.bottomWidget,
  });

  String _getFearGreedSvg(int index) {
    if (index < 20) return 'assets/fear_greed/fear-1.svg';
    if (index < 40) return 'assets/fear_greed/fear-2.svg';
    if (index < 60) return 'assets/fear_greed/neutral.svg';
    if (index < 80) return 'assets/fear_greed/greed-1.svg';
    return 'assets/fear_greed/greed-2.svg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isLoading = value == '...';
    final int indexValue =
        int.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0;

    return Container(
      width: width.clamp(0.0, double.infinity),
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF0087E0),
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(12) : Radius.zero,
          right: isLast ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      child:
          isFearGreed
              ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  isLoading
                      ? Text(
                        '...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                      : Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset(
                            _getFearGreedSvg(indexValue),
                            width: 42,
                            height: 42,
                            fit: BoxFit.contain,
                          ),
                          Text(
                            '$indexValue',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                ],
              )
              : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  isLoading
                      ? Text(
                        '...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  if (!isLoading && bottomWidget != null) bottomWidget!,
                  if (!isLoading && subtitle != null && subtitle!.isNotEmpty)
                    Row(
                      children: [
                        imageUrl != null
                            ? Image.network(
                              imageUrl!,
                              width: 14,
                              height: 14,
                              errorBuilder:
                                  (_, __, ___) => Image.asset(
                                    'assets/default-coin.png',
                                    width: 16,
                                    height: 16,
                                  ),
                            )
                            : Image.asset(
                              'assets/icons/${subtitle!.toLowerCase()}.png',
                              width: 14,
                              height: 14,
                              errorBuilder:
                                  (_, __, ___) => Image.asset(
                                    'assets/default-coin.png',
                                    width: 16,
                                    height: 16,
                                  ),
                            ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            subtitle!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (!isLoading && change != null)
                    GestureDetector(
                      onTap:
                          change == 'View More'
                              ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const TreasuryScreen(),
                                  ),
                                );
                              }
                              : null,

                      child: Row(
                        children: [
                          if (change!.contains('%'))
                            Icon(
                              change!.startsWith('+')
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 12,
                              color: changeColor,
                            ),
                          if (change!.contains('%')) const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              change!.replaceAll(RegExp(r'^[\+\-]'), ''),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: changeColor,
                                decoration:
                                    change == 'View More'
                                        ? TextDecoration.none
                                        : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (change == 'View More') ...[
                            const SizedBox(width: 1),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: changeColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
    );
  }
}
