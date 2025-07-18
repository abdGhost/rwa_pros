import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HtmlPreviewWithToggle extends StatefulWidget {
  final String html;
  final bool isExpanded;
  final VoidCallback onToggle;

  const HtmlPreviewWithToggle({
    super.key,
    required this.html,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<HtmlPreviewWithToggle> createState() => _HtmlPreviewWithToggleState();
}

class _HtmlPreviewWithToggleState extends State<HtmlPreviewWithToggle> {
  final GlobalKey _contentKey = GlobalKey();
  bool _showReadMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    final context = _contentKey.currentContext;
    if (context != null) {
      final box = context.findRenderObject();
      if (box is RenderBox) {
        if (mounted) {
          setState(() {
            _showReadMore = box.size.height > 86;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints:
              widget.isExpanded
                  ? const BoxConstraints()
                  : const BoxConstraints(maxHeight: 86),
          child: SingleChildScrollView(
            physics:
                widget.isExpanded
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
            child: Html(
              key: _contentKey,
              data: widget.html,
              onLinkTap: (url, _, __) async {
                if (url != null && await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  print('Could not launch $url');
                }
              },
              style: {
                // "*": Style(margin: Margins.zero),
                "body": Style(
                  fontSize: FontSize(12),
                  fontFamily: 'Inter',
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
                  lineHeight: LineHeight.number(1.3),
                  // margin: Margins.zero,
                  // padding: HtmlPaddings.zero,
                ),
                // "strong": Style(fontWeight: FontWeight.w600),
                // "p": Style(margin: Margins.zero, padding: HtmlPaddings.zero),
              },
            ),
          ),
        ),
        if (_showReadMore)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: widget.onToggle,
              child: Text(
                widget.isExpanded ? 'read less' : 'read more...',
                style: GoogleFonts.inter(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF0087E0),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
