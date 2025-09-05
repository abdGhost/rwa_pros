import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AirdropDetailScreen extends StatefulWidget {
  final Map<String, dynamic> airdrop;

  const AirdropDetailScreen({super.key, required this.airdrop});

  @override
  State<AirdropDetailScreen> createState() => _AirdropDetailScreenState();
}

class _AirdropDetailScreenState extends State<AirdropDetailScreen> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _logAirdropDetailScreenView();
  }

  void _logAirdropDetailScreenView() async {
    final projectName = (widget.airdrop['project'] ?? '').toString();
    final id = (widget.airdrop['_id'] ?? '').toString();

    await _analytics.logEvent(
      name: 'view_airdrop_detail',
      parameters: {'id': id, 'project': projectName},
    );

    await _analytics.logScreenView(
      screenName: '/airdrop/$id',
      screenClass: '/airdrop/$id',
    );
  }

  String stripHtml(String? input) {
    if (input == null) return '';
    final noTags = input.replaceAll(
      RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false),
      ' ',
    );
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Color statusColor(String s) {
    switch ((s).toString().toLowerCase()) {
      case 'live':
        return const Color(0xFF27AE60); // green
      case 'upcoming':
        return const Color(0xFFEBB411); // yellow
      case 'ended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String s) {
    switch ((s).toString().toLowerCase()) {
      case 'live':
        return Icons.flash_on; // lightning for Live
      case 'upcoming':
        return Icons.schedule; // ⏰ correct for Upcoming
      case 'ended':
        return Icons.history; // history for Ended
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color primary = const Color(0xFFEBB411);

    final status = (widget.airdrop['status'] ?? '').toString();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.airdrop['project']}',
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
              child: Image.network(
                (widget.airdrop['image'] ?? '').toString(),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      color:
                          isDark
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFFEFEFEF),
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    ),
              ),
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
                          '${widget.airdrop['project']} Airdrop',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Row 1: Ticker
                        Row(
                          children: [
                            Expanded(
                              child: _buildRichText(
                                isDark,
                                label: 'Ticker: ',
                                value: '${widget.airdrop['token']}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Row 2: Chain
                        Row(
                          children: [
                            Expanded(
                              child: _buildRichText(
                                isDark,
                                label: 'Chain: ',
                                value: '${widget.airdrop['chain']}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 3: Reward (icon + long text)  ✅ Expanded prevents overflow
                        Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              size: 18,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildRichText(
                                isDark,
                                label: 'Reward Pool: ',
                                value: '${widget.airdrop['reward']}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Row 4: Date (icon + long text) ✅ Expanded prevents overflow
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 18,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildRichText(
                                isDark,
                                label: 'Date: ',
                                value: '${widget.airdrop['date']}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Row 5: Eligibility (already Expanded) ✅
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
                                      text: stripHtml(
                                        (widget.airdrop['eligibility'] ?? '')
                                            .toString(),
                                      ),
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

                // Status badge (top-right) – keep compact so it never overflows
                Positioned(
                  top: -12,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor(status),
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
                      mainAxisSize: MainAxisSize.min, // ✅ important
                      children: [
                        Icon(statusIcon(status), size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                stripHtml(
                      (widget.airdrop['description'] ?? '').toString(),
                    ).isNotEmpty
                    ? stripHtml(
                      (widget.airdrop['description'] ?? '').toString(),
                    )
                    : 'No description available.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a **Text.rich** that ellipsizes long content to avoid overflow.
  Widget _buildRichText(
    bool isDark, {
    required String label,
    required String value,
  }) {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.inter(fontSize: 14, height: 1.25),
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis, // ✅ key to prevent tiny overflows
      softWrap: false,
    );
  }
}
