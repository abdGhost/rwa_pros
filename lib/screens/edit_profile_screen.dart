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

  // Normalize any API/platform text to our dropdown labels
  static const Map<String, String> _platformCanonical = {
    'twitter': 'Twitter',
    'x': 'X',
    'telegram': 'Telegram',
    'linkedin': 'LinkedIn',
    'youtube': 'YouTube',
    'medium': 'Medium',
    'website': 'Website',
  };

  @override
  void initState() {
    super.initState();
    _hydrateInitials();
    _hydrateFromPrefsIfMissing(); // async fallback (no await in initState)
    _checkLoginStatus();
  }

  void _hydrateInitials() {
    _nameCtrl.text = widget.initialName ?? '';
    _emailCtrl.text = widget.initialEmail ?? '';
    _existingProfileUrl = widget.initialProfileImgUrl ?? '';
    _existingBannerUrl = widget.initialBannerImgUrl ?? '';

    for (final m in widget.initialLinks) {
      final raw = (m['platform'] ?? '').trim();
      final canon = _platformCanonical[raw.toLowerCase()] ?? raw;
      _links.add(_LinkRow(platform: canon, url: m['url'] ?? ''));
    }
    if (_links.isEmpty) _links.add(_LinkRow(platform: '', url: ''));
  }

  Future<void> _hydrateFromPrefsIfMissing() async {
    final prefs = await SharedPreferences.getInstance();

    if ((_nameCtrl.text).trim().isEmpty) {
      final savedName = prefs.getString('name') ?? '';
      if (savedName.isNotEmpty) _nameCtrl.text = savedName;
    }
    if ((_emailCtrl.text).trim().isEmpty) {
      final savedEmail = prefs.getString('email') ?? '';
      if (savedEmail.isNotEmpty) _emailCtrl.text = savedEmail;
    }

    // Restore saved links if widget didn't pass any (or only a single blank row)
    final savedLinksJson = prefs.getString('links');
    if (savedLinksJson != null && savedLinksJson.isNotEmpty) {
      final decoded = jsonDecode(savedLinksJson);
      if (decoded is List) {
        final restored = <_LinkRow>[];
        for (final e in decoded) {
          if (e is Map) {
            final raw = (e['platform'] ?? '').toString();
            final canon = _platformCanonical[raw.toLowerCase()] ?? raw;
            restored.add(
              _LinkRow(platform: canon, url: (e['url'] ?? '').toString()),
            );
          }
        }
        if (restored.isNotEmpty) {
          setState(() {
            _links
              ..clear()
              ..addAll(restored);
          });
        }
      }
    }

    // Also restore images if the parent didn't pass them
    if ((_existingProfileUrl ?? '').isEmpty) {
      _existingProfileUrl = prefs.getString('profileImage') ?? '';
      setState(() {});
    }
    if ((_existingBannerUrl ?? '').isEmpty) {
      _existingBannerUrl = prefs.getString('bannerImage') ?? '';
      setState(() {});
    }
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

  String _normalizeUrl(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*://').hasMatch(t);
    return hasScheme ? t : 'https://$t';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final links =
        _links
            .where(
              (e) => e.platform.trim().isNotEmpty && e.url.trim().isNotEmpty,
            )
            .map(
              (e) => {
                "platform": e.platform.trim(),
                "url": _normalizeUrl(e.url),
              },
            )
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

      // Debug logs
      print("=== EDIT PROFILE SAVE START ===");
      print("Request URL: $uri");
      print("Headers: ${req.headers}");
      print("UserName: ${_nameCtrl.text.trim()}");
      print("Email: ${_emailCtrl.text.trim()}");
      print("Remove Banner: $_removeBanner");
      print("Remove Profile: $_removeProfile");
      print("Links: $links");

      // fields
      req.fields['userName'] = _nameCtrl.text.trim();
      req.fields['email'] = _emailCtrl.text.trim();
      req.fields['removeBannerImg'] = _removeBanner ? "true" : "false";
      req.fields['removeProfileImg'] = _removeProfile ? "true" : "false";
      req.fields['link'] = jsonEncode(links);

      // files (only if changed)
      if (_pickedProfileFile != null) {
        print("Attaching profile image: ${_pickedProfileFile!.path}");
        req.files.add(
          await http.MultipartFile.fromPath(
            'profileImg',
            _pickedProfileFile!.path,
          ),
        );
      }
      if (_pickedBannerFile != null) {
        print("Attaching banner image: ${_pickedBannerFile!.path}");
        req.files.add(
          await http.MultipartFile.fromPath(
            'bannerImg',
            _pickedBannerFile!.path,
          ),
        );
      }

      final streamed = await req.send();
      print("Request sent, awaiting response...");

      final res = await http.Response.fromStream(streamed);
      print("Response Status: ${res.statusCode}");
      print("Response Body: ${res.body}");

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception("HTTP ${res.statusCode}: ${res.body}");
      }

      final payload = jsonDecode(res.body);
      if (payload is! Map) {
        throw Exception("Unexpected response shape");
      }
      final payloadMap = Map<String, dynamic>.from(payload);
      print("Decoded Payload: $payloadMap");

      if (payloadMap['status'] != true) {
        throw Exception(payloadMap['message'] ?? 'Unknown error');
      }

      // --- SAFE PARSE OF OPTIONAL `data` ---
      String? serverProfileUrl;
      String? serverBannerUrl;
      dynamic serverLinks;

      final rawData = payloadMap['data'];
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        serverProfileUrl =
            (data['profileImg'] ?? data['profileImage']) as String?;
        serverBannerUrl = (data['bannerImg'] ?? data['bannerImage']) as String?;
        serverLinks = data['link'] ?? data['links'];
      } else {
        serverProfileUrl = null;
        serverBannerUrl = null;
        serverLinks = null;
      }

      print("Parsed serverProfileUrl: $serverProfileUrl");
      print("Parsed serverBannerUrl: $serverBannerUrl");
      print("Parsed serverLinks: $serverLinks");

      // cache for instant UI refresh
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameCtrl.text.trim());
      await prefs.setString('email', _emailCtrl.text.trim());
      await prefs.setString('links', jsonEncode(links));

      await prefs.setString(
        'profileImage',
        _removeProfile
            ? ''
            : (serverProfileUrl ??
                (_pickedProfileFile != null
                    ? (_existingProfileUrl ?? '')
                    : (_existingProfileUrl ?? ''))),
      );

      await prefs.setString(
        'bannerImage',
        _removeBanner
            ? ''
            : (serverBannerUrl ??
                (_pickedBannerFile != null
                    ? (_existingBannerUrl ?? '')
                    : (_existingBannerUrl ?? ''))),
      );

      // If server sends back normalized links, prefer those (optional)
      if (serverLinks is List) {
        await prefs.setString('links', jsonEncode(serverLinks));
      }

      print("=== EDIT PROFILE SAVE SUCCESS ===");

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      print("Save Error: $e");
      print(st);
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
          final isInList = _platforms.contains(row.platform);
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
                    value: isInList ? row.platform : null,
                    hint:
                        (!isInList && row.platform.isNotEmpty)
                            ? Text(
                              row.platform,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            )
                            : null,
                    // Make the selected value ALWAYS single-line with ellipsis
                    selectedItemBuilder:
                        (context) =>
                            _platforms
                                .map(
                                  (p) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      p,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                    items:
                        _platforms
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
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
