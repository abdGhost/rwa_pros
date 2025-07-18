import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AirdropDetailScreen extends StatelessWidget {
  final Map<String, dynamic> airdrop;

  const AirdropDetailScreen({super.key, required this.airdrop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color primary = const Color(0xFF0087E0);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          '${airdrop['project']}',
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 200,
              child: Image.network(airdrop['image'] ?? '', fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Card(
                  elevation: .2,
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${airdrop['project']} Airdrop',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildRichText(
                          isDark,
                          label: 'Ticker: ',
                          value: '${airdrop['token']}',
                        ),
                        const SizedBox(height: 2),
                        _buildRichText(
                          isDark,
                          label: 'Chain: ',
                          value: '${airdrop['chain']}',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              size: 18,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                            _buildRichText(
                              isDark,
                              label: 'Reward Pool: ',
                              value: '${airdrop['reward']}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 18,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                            _buildRichText(
                              isDark,
                              label: 'Date: ',
                              value: '${airdrop['date']}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user, size: 18, color: primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Eligibility:\n',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : Colors.black,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '${airdrop['eligibility']}',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 14,
                                        color:
                                            isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -12,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          airdrop['status'] == 'Live'
                              ? Colors.green
                              : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          airdrop['status'] == 'Live'
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          airdrop['status'],
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                airdrop['description'] ?? 'No description available.',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichText(
    bool isDark, {
    required String label,
    required String value,
  }) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 14),
        children: [
          TextSpan(
            text: label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          TextSpan(
            text: value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.normal,
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
