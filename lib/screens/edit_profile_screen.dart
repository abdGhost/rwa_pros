import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rwa_app/screens/onboarding_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.initialName,
    this.initialEmail,
    this.initialProfileImgUrl,
    this.initialBannerImgUrl,
    this.initialLinks = const [],
  });

  final String? initialName;
  final String? initialEmail;
  final String? initialProfileImgUrl;
  final String? initialBannerImgUrl;
  final List<Map<String, String>> initialLinks; // [{platform,url}]

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final List<_LinkRow> _links = [];

  // images + flags
  String? _existingProfileUrl;
  String? _existingBannerUrl;
  File? _pickedProfileFile;
  File? _pickedBannerFile;
  bool _removeProfile = false;
  bool _removeBanner = false;

  bool _saving = false;
  String? _error;
  String token = '';

  static const _platforms = <String>[
    'Twitter',
    'X',
    'Telegram',
    'LinkedIn',
    'YouTube',
    'Medium',
    'Website',
  ];

  @override
  void initState() {
    super.initState();
    _hydrateInitials();
    _checkLoginStatus();
  }

  void _hydrateInitials() {
    _nameCtrl.text = widget.initialName ?? '';
    _emailCtrl.text = widget.initialEmail ?? '';
    _existingProfileUrl = widget.initialProfileImgUrl ?? '';
    _existingBannerUrl = widget.initialBannerImgUrl ?? '';
    for (final m in widget.initialLinks) {
      _links.add(_LinkRow(platform: m['platform'] ?? '', url: m['url'] ?? ''));
    }
    if (_links.isEmpty) _links.add(_LinkRow(platform: '', url: ''));
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => token = prefs.getString('token') ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // Only add Authorization; MultipartRequest will set proper content-type
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('token');
    return {if (jwt != null && jwt.isNotEmpty) 'Authorization': 'Bearer $jwt'};
  }

  Future<void> _pickImage(bool isProfile) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        if (isProfile) {
          _pickedProfileFile = File(picked.path);
          _removeProfile = false;
        } else {
          _pickedBannerFile = File(picked.path);
          _removeBanner = false;
        }
      });
    }
  }

  void _removeImage(bool isProfile) {
    setState(() {
      if (isProfile) {
        _pickedProfileFile = null;
        _existingProfileUrl = null;
        _removeProfile = true;
      } else {
        _pickedBannerFile = null;
        _existingBannerUrl = null;
        _removeBanner = true;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final links =
        _links
            .where(
              (e) => e.platform.trim().isNotEmpty && e.url.trim().isNotEmpty,
            )
            .map((e) => {"platform": e.platform.trim(), "url": e.url.trim()})
            .toList();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/users/update",
      );
      final req = http.MultipartRequest("PUT", uri);
      req.headers.addAll(await _authHeaders());

      // fields
      req.fields['userName'] = _nameCtrl.text.trim();
      req.fields['email'] = _emailCtrl.text.trim();
      req.fields['removeBannerImg'] = _removeBanner ? "true" : "false";
      req.fields['removeProfileImg'] = _removeProfile ? "true" : "false";
      req.fields['link'] = jsonEncode(links);

      // files (only if changed)
      if (_pickedProfileFile != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'profileImg',
            _pickedProfileFile!.path,
          ),
        );
      }
      if (_pickedBannerFile != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'bannerImg',
            _pickedBannerFile!.path,
          ),
        );
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception("HTTP ${res.statusCode}: ${res.body}");
      }
      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      if (payload['status'] != true) {
        throw Exception(payload['message'] ?? 'Unknown error');
      }

      // cache for instant UI refresh
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameCtrl.text.trim());
      await prefs.setString('email', _emailCtrl.text.trim());
      await prefs.setString(
        'profileImage',
        _removeProfile
            ? ""
            : (_pickedProfileFile != null ? '' : (_existingProfileUrl ?? '')),
      );
      await prefs.setString(
        'bannerImage',
        _removeBanner
            ? ""
            : (_pickedBannerFile != null ? '' : (_existingBannerUrl ?? '')),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
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
          'Edit Profile',
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
                              // Banner block
                              _label("Banner Image", theme),
                              const SizedBox(height: 6),
                              _imagePickerBlock(
                                theme: theme,
                                isCircle: false,
                                existingUrl: _existingBannerUrl,
                                pickedFile: _pickedBannerFile,
                                onPick: () => _pickImage(false),
                                onRemove: () => _removeImage(false),
                              ),
                              const SizedBox(height: 16),

                              // Avatar block
                              _label("Profile Image", theme),
                              const SizedBox(height: 6),
                              _imagePickerBlock(
                                theme: theme,
                                isCircle: true,
                                existingUrl: _existingProfileUrl,
                                pickedFile: _pickedProfileFile,
                                onPick: () => _pickImage(true),
                                onRemove: () => _removeImage(true),
                              ),
                              const SizedBox(height: 16),

                              _label("Display Name", theme),
                              const SizedBox(height: 6),
                              _inputField(
                                theme,
                                _nameCtrl,
                                "Enter your display name",
                                validator:
                                    (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? "Name cannot be empty"
                                            : null,
                              ),
                              const SizedBox(height: 16),

                              _label("Email", theme),
                              const SizedBox(height: 6),
                              _inputField(
                                theme,
                                _emailCtrl,
                                "Enter your email",
                                validator: (v) {
                                  final s = v?.trim() ?? '';
                                  if (s.isEmpty) return "Email cannot be empty";
                                  final ok = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(s);
                                  return ok ? null : "Invalid email";
                                },
                              ),
                              const SizedBox(height: 16),

                              _label("Social Links", theme),
                              const SizedBox(height: 6),
                              _linksBlock(theme),

                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // bottom primary button
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
                          onPressed: _saving ? null : _save,
                          child:
                              _saving
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    "Save",
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

  // ---------- UI blocks ----------

  Widget _buildLoginPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/rwapros/logo.png', width: 300, height: 300),
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

  Widget _imagePickerBlock({
    required ThemeData theme,
    required bool isCircle,
    required String? existingUrl,
    required File? pickedFile,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _imagePreview(
              isCircle: isCircle,
              existingUrl: existingUrl,
              pickedFile: pickedFile,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload),
                  label: const Text("Choose"),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("Remove"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreview({
    required bool isCircle,
    required String? existingUrl,
    required File? pickedFile,
  }) {
    Widget preview;
    if (pickedFile != null) {
      preview = Image.file(
        pickedFile,
        height: 90,
        width: 90,
        fit: BoxFit.cover,
      );
    } else if ((existingUrl ?? '').isNotEmpty) {
      preview = Image.network(
        existingUrl!,
        height: 90,
        width: 90,
        fit: BoxFit.cover,
      );
    } else {
      preview = Container(
        height: 90,
        width: 90,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image, size: 28, color: Colors.grey),
      );
    }
    if (isCircle) {
      preview = ClipOval(
        child: SizedBox(
          height: 90,
          width: 90,
          child: FittedBox(fit: BoxFit.cover, child: preview),
        ),
      );
    }
    return preview;
  }

  Widget _linksBlock(ThemeData theme) {
    return Column(
      children: [
        ...List.generate(_links.length, (i) {
          final row = _links[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: theme.dividerColor, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                // Dropdown (no-wrap + small fonts)
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      labelText: "Platform",
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                    value: row.platform.isEmpty ? null : row.platform,
                    // Make the selected value ALWAYS single-line with ellipsis
                    selectedItemBuilder:
                        (context) =>
                            _platforms.map((p) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  p,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                    items:
                        _platforms.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                    onChanged:
                        (v) => setState(
                          () => _links[i] = row.copyWith(platform: v ?? ''),
                        ),
                  ),
                ),
                const SizedBox(width: 8),

                // URL (small fonts)
                Expanded(
                  flex: 7,
                  child: TextFormField(
                    initialValue: row.url,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      labelText: "URL (with or without https)",
                      labelStyle: TextStyle(fontSize: 11),
                      hintStyle: TextStyle(fontSize: 11),
                    ),
                    onChanged: (v) => _links[i] = row.copyWith(url: v),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return null;
                      final ok = RegExp(
                        r'^[a-zA-Z]+://|^[\w\-]+\.[\w\-]+',
                      ).hasMatch(s);
                      return ok ? null : "Invalid URL";
                    },
                  ),
                ),

                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18, // a bit smaller
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  onPressed:
                      () => setState(() {
                        if (_links.length == 1) {
                          _links[0] = _LinkRow(platform: '', url: '');
                        } else {
                          _links.removeAt(i);
                        }
                      }),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: "Remove",
                ),
              ],
            ),
          );
        }),

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed:
                () =>
                    setState(() => _links.add(_LinkRow(platform: '', url: ''))),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              "Add another link",
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRow {
  final String platform;
  final String url;
  _LinkRow({required this.platform, required this.url});
  _LinkRow copyWith({String? platform, String? url}) =>
      _LinkRow(platform: platform ?? this.platform, url: url ?? this.url);
}
