import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:rwa_app/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddThreadScreen extends StatefulWidget {
  final Map<String, dynamic> forumData;

  const AddThreadScreen({super.key, required this.forumData});

  @override
  State<AddThreadScreen> createState() => _AddThreadScreenState();
}

class _AddThreadScreenState extends State<AddThreadScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();

  late quill.QuillController _descriptionController;
  final FocusNode _editorFocusNode = FocusNode();
  bool _isFocused = false;

  String token = '';
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    print('🟡 Forum Data: ${widget.forumData}');

    _descriptionController = quill.QuillController(
      document: quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _editorFocusNode.addListener(() {
      setState(() {
        _isFocused = _editorFocusNode.hasFocus;
      });
    });
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token') ?? '';
    print('User Token: $savedToken');

    setState(() {
      token = savedToken;
    });
  }

  Future<void> _submitThread() async {
    if (!_formKey.currentState!.validate()) return;

    final descriptionDeltaJson = jsonEncode(
      _descriptionController.document.toDelta().toJson(),
    );

    if (descriptionDeltaJson.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Description cannot be empty.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      return;
    }

    final requestBody = {
      "title": _titleController.text,
      "text":
          _descriptionController.document
              .toDelta()
              .toJson(), // send as raw delta
      "categoryId": widget.forumData['subCategoryId'],
    };

    // ✅ Print body before sending
    print('Submitting thread with body: ${jsonEncode(requestBody)}');

    setState(() {
      isSubmitting = true;
    });

    final response = await http.post(
      Uri.parse(
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/mobile/create',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    print(jsonEncode(requestBody));

    setState(() {
      isSubmitting = false;
    });

    print(response.body);

    if (response.statusCode == 200) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thread created successfully!',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create thread.', style: GoogleFonts.inter()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post Thread',
          style: GoogleFonts.inter(textStyle: theme.textTheme.titleMedium),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body:
          token.isEmpty
              ? _buildLoginPrompt(theme)
              : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label("Title", theme),
                              const SizedBox(height: 6),
                              _inputField(
                                theme,
                                _titleController,
                                "Enter thread title",
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Title cannot be empty';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _label("Description", theme),
                              const SizedBox(height: 6),

                              Container(
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  border: Border.all(
                                    color:
                                        _isFocused
                                            ? theme.primaryColor
                                            : theme.dividerColor,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  children: [
                                    // ✅ Toolbar Row 1
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: theme.cardColor,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: theme.dividerColor,
                                          ),
                                        ),
                                      ),
                                      child: quill.QuillSimpleToolbar(
                                        controller: _descriptionController,
                                        config: quill.QuillSimpleToolbarConfig(
                                          color: theme.cardColor,
                                          buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                                            base: quill.QuillToolbarBaseButtonOptions(
                                              iconSize: 12,
                                              iconButtonFactor: 2.0,
                                              iconTheme: quill.QuillIconTheme(
                                                iconButtonSelectedData:
                                                    quill.IconButtonData(
                                                      color: Colors.white,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      style: ButtonStyle(
                                                        backgroundColor:
                                                            MaterialStateProperty.all(
                                                              theme
                                                                  .primaryColor,
                                                            ),
                                                      ),
                                                    ),
                                                iconButtonUnselectedData:
                                                    quill.IconButtonData(
                                                      color:
                                                          theme.iconTheme.color,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      style: ButtonStyle(
                                                        backgroundColor:
                                                            MaterialStateProperty.all(
                                                              theme.brightness ==
                                                                      Brightness
                                                                          .dark
                                                                  ? Colors
                                                                      .grey[800]
                                                                  : Colors
                                                                      .grey[200],
                                                            ),
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                          showColorButton: false,
                                          showFontFamily: false,
                                          multiRowsDisplay: false,
                                          showBoldButton: true,
                                          showItalicButton: true,
                                          showUnderLineButton: true,
                                          showHeaderStyle: false,
                                          showListNumbers: false,
                                          showListBullets: false,
                                          showCodeBlock: false,
                                          showInlineCode: false,
                                          showBackgroundColorButton: false,
                                          showStrikeThrough: false,
                                          showQuote: false,
                                          showIndent: false,
                                          showLink: false,
                                          showUndo: false,
                                          showRedo: false,
                                          showDirection: false,
                                          showClearFormat: false,
                                          showAlignmentButtons: false,
                                          showSearchButton: false,
                                          showListCheck: false,
                                          showSubscript: false,
                                          showSuperscript: false,
                                        ),
                                      ),
                                    ),

                                    // ✅ Toolbar Row 2
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: theme.cardColor,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: theme.dividerColor,
                                          ),
                                        ),
                                      ),
                                      child: quill.QuillSimpleToolbar(
                                        controller: _descriptionController,
                                        config: quill.QuillSimpleToolbarConfig(
                                          color: theme.cardColor,
                                          buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                                            base: quill.QuillToolbarBaseButtonOptions(
                                              iconSize: 12,
                                              iconButtonFactor: 2.0,
                                              iconTheme: quill.QuillIconTheme(
                                                iconButtonSelectedData:
                                                    quill.IconButtonData(
                                                      color: Colors.white,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      style: ButtonStyle(
                                                        backgroundColor:
                                                            MaterialStateProperty.all(
                                                              theme
                                                                  .primaryColor,
                                                            ),
                                                      ),
                                                    ),
                                                iconButtonUnselectedData:
                                                    quill.IconButtonData(
                                                      color:
                                                          theme.iconTheme.color,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      style: ButtonStyle(
                                                        backgroundColor:
                                                            MaterialStateProperty.all(
                                                              theme.brightness ==
                                                                      Brightness
                                                                          .dark
                                                                  ? Colors
                                                                      .grey[800]
                                                                  : Colors
                                                                      .grey[200],
                                                            ),
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                          showColorButton: false,
                                          multiRowsDisplay: false,
                                          showFontFamily: false,
                                          showFontSize: false,
                                          showBoldButton: false,
                                          showItalicButton: false,
                                          showUnderLineButton: false,
                                          showHeaderStyle: true,
                                          showListNumbers: true,
                                          showListBullets: true,
                                          showCodeBlock: true,
                                          showInlineCode: false,
                                          showBackgroundColorButton: false,
                                          showStrikeThrough: false,
                                          showQuote: false,
                                          showIndent: false,
                                          showLink: false,
                                          showUndo: false,
                                          showRedo: false,
                                          showDirection: false,
                                          showClearFormat: false,
                                          showAlignmentButtons: false,
                                          showSearchButton: false,
                                          showListCheck: false,
                                          showSubscript: false,
                                          showSuperscript: false,
                                        ),
                                      ),
                                    ),

                                    // ✅ Editor Body
                                    Container(
                                      height: 300,
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.cardColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          textSelectionTheme:
                                              TextSelectionThemeData(
                                                cursorColor: theme.primaryColor,
                                                selectionColor: theme
                                                    .primaryColor
                                                    .withOpacity(0.4),
                                              ),
                                        ),
                                        child: quill.QuillEditor.basic(
                                          controller: _descriptionController,
                                          focusNode: _editorFocusNode,
                                          config: quill.QuillEditorConfig(
                                            placeholder:
                                                'Enter thread description...',
                                            textSelectionThemeData:
                                                TextSelectionThemeData(
                                                  cursorColor:
                                                      theme.primaryColor,
                                                ),
                                            customStyles: quill.DefaultStyles(
                                              placeHolder:
                                                  quill.DefaultTextBlockStyle(
                                                    GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color: Theme.of(context)
                                                          .hintColor
                                                          .withOpacity(0.7),
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                    const quill.HorizontalSpacing(
                                                      0,
                                                      0,
                                                    ),
                                                    const quill.VerticalSpacing(
                                                      4,
                                                      4,
                                                    ),
                                                    const quill.VerticalSpacing(
                                                      0,
                                                      0,
                                                    ),
                                                    null,
                                                  ),

                                              paragraph:
                                                  quill.DefaultTextBlockStyle(
                                                    TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.color,
                                                      height: 1.5,
                                                    ),
                                                    const quill.HorizontalSpacing(
                                                      0,
                                                      0,
                                                    ), // left & right
                                                    const quill.VerticalSpacing(
                                                      8,
                                                      8,
                                                    ), // top & bottom
                                                    const quill.VerticalSpacing(
                                                      0,
                                                      0,
                                                    ), // line spacing
                                                    null, // no BoxDecoration
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEBB411),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: isSubmitting ? null : _submitThread,
                          child:
                              isSubmitting
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    "Post",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildLoginPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/rwapros/logo.png', // your image path
              width: 300,
              height: 300,
              // color: theme.primaryColor,
            ),
            // Icon(Icons.lock_outline, size: 48, color: theme.primaryColor),
            const SizedBox(height: 12),
            Text(
              'Please login to use this feature.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0087E0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => OnboardingScreen()),
                  );
                },
                child: Text(
                  "Login",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, ThemeData theme) {
    return Text(
      text,
      style: GoogleFonts.inter(
        textStyle: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _inputField(
    ThemeData theme,
    TextEditingController controller,
    String hintText, {
    int maxLines = 1,
    int? minLines,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.inter(textStyle: theme.textTheme.bodyMedium),
      cursorColor: theme.primaryColor,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 0.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 0.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade600, width: 0.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.red.shade400, width: 0.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.red.shade600, width: 0.6),
        ),
      ),
    );
  }
}
