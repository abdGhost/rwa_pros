import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HtmlContentModal extends StatefulWidget {
  final String title;
  final String apiUrl;
  final String contentKey;

  const HtmlContentModal({
    super.key,
    required this.title,
    required this.apiUrl,
    required this.contentKey,
  });

  @override
  State<HtmlContentModal> createState() => _HtmlContentModalState();
}

class _HtmlContentModalState extends State<HtmlContentModal> {
  String? htmlData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHtml();
  }

  Future<void> _fetchHtml() async {
    try {
      final response = await http.get(Uri.parse(widget.apiUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          htmlData = data[widget.contentKey];
          isLoading = false;
        });
      } else {
        setState(() {
          htmlData = "<p>Failed to load content.</p>";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        htmlData = "<p>Error: ${e.toString()}</p>";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: theme.cardColor,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 6,
              right: 6,
              left: 6,
              bottom: 8,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0087E0),
                        ),
                      )
                      : SingleChildScrollView(
                        child: Html(
                          data: htmlData ?? "<p>No data available</p>",
                        ),
                      ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              splashRadius: 20,
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }
}
