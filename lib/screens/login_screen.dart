import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;

import 'package:rwa_app/api/api_service.dart';
import 'package:rwa_app/screens/botttom_nav_screen.dart';
import 'package:rwa_app/screens/signup_screen.dart';
import 'package:rwa_app/theme/theme.dart';
import 'package:rwa_app/widgets/auth_divider_widget.dart';
import 'package:rwa_app/widgets/custom_textfield_widget.dart';
import 'package:rwa_app/widgets/social_auth_widget.dart';
import 'package:rwa_app/widgets/back_title_appbar_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> sendFcmTokenToBackend(String jwtToken) async {
    final prefs = await SharedPreferences.getInstance();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final savedFcmToken = prefs.getString('fcm_token');

    debugPrint('📦 Stored FCM Token: $savedFcmToken');
    debugPrint('📲 Current FCM Token: $fcmToken');
    debugPrint('🔐 JWT Token: $jwtToken');

    if (fcmToken == null || jwtToken.isEmpty) {
      debugPrint("❌ Cannot send FCM token. Token or JWT missing.");
      return;
    }

    if (fcmToken == savedFcmToken) {
      debugPrint("⏩ FCM token already sent. Skipping...");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/users/fcmtoken'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'token': fcmToken}),
      );

      debugPrint("📡 FCM Upload Status: ${response.statusCode}");
      debugPrint("📡 FCM Upload Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setString('fcm_token', fcmToken);
        debugPrint("✅ FCM token saved to backend and local prefs");
      } else {
        debugPrint("⚠️ Failed to send FCM token: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Exception sending FCM token: $e");
    }
  }

  Future<void> _handleEmailPasswordSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Email and Password are required");
      return;
    }

    _showSnackBar("Signing in with Email...");
    setState(() => _isLoading = true);

    try {
      final resp = await _apiService.signin(email: email, password: password);

      // Basic success + token guard
      final bool ok =
          (resp['status'] == true) &&
          (resp['token'] is String && (resp['token'] as String).isNotEmpty);
      if (!ok) {
        _showSnackBar(resp['message'] ?? "Login failed");
        return;
      }

      // Extract with sensible defaults
      final token = resp['token'] as String;
      final userId = (resp['_id'] ?? "") as String;
      final name = (resp['name'] ?? "") as String;
      final emailFromApi =
          (resp['email'] ?? email) as String; // fallback to typed email
      final profileImg = (resp['profileImg'] ?? "") as String;
      final bannerImg = (resp['bannerImg'] ?? "") as String;
      final description = (resp['description'] ?? "") as String;
      final createdAt = (resp['createdAt'] ?? "") as String;

      // Links array -> JSON string
      final List<dynamic> links =
          (resp['link'] is List) ? (resp['link'] as List) : const [];
      final String linksJson = jsonEncode(links);

      // Stats (safe defaults)
      final Map<String, dynamic> stat =
          (resp['stat'] is Map<String, dynamic>)
              ? resp['stat'] as Map<String, dynamic>
              : {};
      final int totalCommentGiven = (stat['totalCommentGiven'] ?? 0) as int;
      final int totalCommentReceived =
          (stat['totalCommentReceived'] ?? 0) as int;
      final int totalFollower = (stat['totalFollower'] ?? 0) as int;
      final int totalFollowing = (stat['totalFollowing'] ?? 0) as int;
      final int totalLikeReceived = (stat['totalLikeReceived'] ?? 0) as int;
      final int totalThreadPosted = (stat['totalThreadPosted'] ?? 0) as int;
      final int totalViewReceived = (stat['totalViewReceived'] ?? 0) as int;
      final String tieredProgression =
          (stat['tieredProgression'] ?? "New user") as String;

      // Also keep a canonical blob for future-proofing
      final canonicalUserJson = jsonEncode({
        "id": userId,
        "name": name,
        "email": emailFromApi,
        "profileImg": profileImg,
        "bannerImg": bannerImg,
        "description": description,
        "createdAt": createdAt,
        "link": links, // keep as array in the blob
        "stat": {
          "totalCommentGiven": totalCommentGiven,
          "totalCommentReceived": totalCommentReceived,
          "totalFollower": totalFollower,
          "totalFollowing": totalFollowing,
          "totalLikeReceived": totalLikeReceived,
          "totalThreadPosted": totalThreadPosted,
          "totalViewReceived": totalViewReceived,
          "tieredProgression": tieredProgression,
        },
      });

      final prefs = await SharedPreferences.getInstance();

      // Tokens & identity
      await prefs.setString('token', token);
      await prefs.setString('loginMethod', 'email');
      await prefs.setString('userId', userId);
      await prefs.setString('name', name);
      await prefs.setString('email', emailFromApi);

      // Profile
      await prefs.setString('profileImage', profileImg);
      await prefs.setString('bannerImage', bannerImg);
      await prefs.setString('description', description);
      await prefs.setString('createdAt', createdAt);

      // Links & full user blob
      await prefs.setString('linksJson', linksJson);
      await prefs.setString('userJson', canonicalUserJson);

      // Forum stats
      await prefs.setInt('totalCommentGiven', totalCommentGiven);
      await prefs.setInt('totalCommentReceived', totalCommentReceived);
      await prefs.setInt('totalFollower', totalFollower);
      await prefs.setInt('totalFollowing', totalFollowing);
      await prefs.setInt('totalLikeReceived', totalLikeReceived);
      await prefs.setInt('totalThreadPosted', totalThreadPosted);
      await prefs.setInt('totalViewReceived', totalViewReceived);
      await prefs.setString('tieredProgression', tieredProgression);

      // Send FCM token with the fresh JWT
      await sendFcmTokenToBackend(token);

      _showSnackBar("Login successful!");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavScreen()),
      );
    } catch (e) {
      _showSnackBar("Sign-In failed");
      debugPrint("Email/Password Sign-In Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      _showSnackBar("Signing in with Google...");
      await GoogleSignIn().signOut(); // force account chooser

      final googleSignIn =
          Platform.isIOS
              ? GoogleSignIn(
                clientId:
                    '458920784247-1e7tebaeni9ovvgte529fg821ugd0ntb.apps.googleusercontent.com',
              )
              : GoogleSignIn();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _showSnackBar("Google Sign-In cancelled");
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCred.user;
      if (user == null) throw Exception("User not found");

      // Payload you send to your backend
      final payload = {
        "userName": user.displayName ?? "No Name",
        "profileImg": user.photoURL ?? "",
        "email": user.email ?? "",
        "googleId": user.uid,
      };

      final response = await http.post(
        Uri.parse(
          "https://rwa-f1623a22e3ed.herokuapp.com/api/users/auth/google",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      // Parse once
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception("Invalid server response (${response.statusCode})");
      }

      // Basic success guard (API returns { status: true, token, id, ... })
      final bool ok = response.statusCode == 200 && (json['status'] == true);
      if (!ok) {
        _showSnackBar(json['message'] ?? "Authentication failed");
        return;
      }

      // Prefer server values over client payload
      final token = (json['token'] ?? "") as String;
      final userId =
          (json['id'] ?? json['_id'] ?? user.uid)
              as String; // your sample uses "id"
      final name = (json['name'] ?? payload['userName'] ?? "") as String;
      final email = (json['email'] ?? payload['email'] ?? "") as String;
      final profileImg =
          (json['profileImg'] ?? payload['profileImg'] ?? "") as String;
      final bannerImg = (json['bannerImg'] ?? "") as String;
      final description = (json['description'] ?? "") as String;
      final createdAt = (json['createdAt'] ?? "") as String;

      // Stats (safe defaults)
      final Map<String, dynamic> stat =
          (json['stat'] is Map<String, dynamic>)
              ? json['stat'] as Map<String, dynamic>
              : const {};
      final totalCommentGiven = (stat['totalCommentGiven'] ?? 0) as int;
      final totalCommentReceived = (stat['totalCommentReceived'] ?? 0) as int;
      final totalFollower = (stat['totalFollower'] ?? 0) as int;
      final totalFollowing = (stat['totalFollowing'] ?? 0) as int;
      final totalLikeReceived = (stat['totalLikeReceived'] ?? 0) as int;
      final totalThreadPosted = (stat['totalThreadPosted'] ?? 0) as int;
      final totalViewReceived = (stat['totalViewReceived'] ?? 0) as int;
      final tieredProgression =
          (stat['tieredProgression'] ?? "New user") as String;

      // Canonical blob for easy hydrate/refresh later
      final userJson = jsonEncode({
        "id": userId,
        "name": name,
        "email": email,
        "profileImg": profileImg,
        "bannerImg": bannerImg,
        "description": description,
        "createdAt": createdAt,
        "stat": {
          "totalCommentGiven": totalCommentGiven,
          "totalCommentReceived": totalCommentReceived,
          "totalFollower": totalFollower,
          "totalFollowing": totalFollowing,
          "totalLikeReceived": totalLikeReceived,
          "totalThreadPosted": totalThreadPosted,
          "totalViewReceived": totalViewReceived,
          "tieredProgression": tieredProgression,
        },
      });

      final prefs = await SharedPreferences.getInstance();

      // Identity & tokens
      await prefs.setString('token', token);
      await prefs.setString('loginMethod', 'google');
      await prefs.setString('userId', userId);
      await prefs.setString('name', name);
      await prefs.setString('email', email);

      // Profile
      await prefs.setString('profileImage', profileImg);
      await prefs.setString('bannerImage', bannerImg);
      await prefs.setString('description', description);
      await prefs.setString('createdAt', createdAt);

      // Stats
      await prefs.setInt('totalCommentGiven', totalCommentGiven);
      await prefs.setInt('totalCommentReceived', totalCommentReceived);
      await prefs.setInt('totalFollower', totalFollower);
      await prefs.setInt('totalFollowing', totalFollowing);
      await prefs.setInt('totalLikeReceived', totalLikeReceived);
      await prefs.setInt('totalThreadPosted', totalThreadPosted);
      await prefs.setInt('totalViewReceived', totalViewReceived);
      await prefs.setString('tieredProgression', tieredProgression);

      // Canonical user blob
      await prefs.setString('userJson', userJson);

      // Send FCM with fresh JWT
      if (token.isNotEmpty) {
        await sendFcmTokenToBackend(token);
      }

      _showSnackBar("Google sign-in successful!");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavScreen()),
      );
    } catch (e) {
      _showSnackBar("Google Sign-In failed");
      debugPrint("Google Sign-In Error: $e");
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      _showSnackBar("Signing in with Apple...");

      // 1) Apple → Firebase
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCred = OAuthProvider("apple.com").credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        oauthCred,
      );
      final user = userCred.user;
      if (user == null) throw Exception("Apple Sign-In failed");

      // Apple may not provide name/email after first consent
      final fallbackDisplayName =
          (appleCred.givenName?.isNotEmpty == true ||
                  appleCred.familyName?.isNotEmpty == true)
              ? "${appleCred.givenName ?? ''} ${appleCred.familyName ?? ''}"
                  .trim()
              : "Apple User";

      final payload = {
        "userName":
            user.displayName?.isNotEmpty == true
                ? user.displayName
                : fallbackDisplayName,
        "profileImg":
            "", // you can’t get avatar from Apple; expect backend to fill
        "email": user.email ?? "", // may be empty on subsequent sign-ins
        "appleId": user.uid,
      };

      // 2) Hit your backend
      final response = await http.post(
        Uri.parse(
          "https://rwa-f1623a22e3ed.herokuapp.com/api/users/auth/apple",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception("Invalid server response (${response.statusCode})");
      }

      final ok = response.statusCode == 200 && (json['status'] == true);
      if (!ok) {
        _showSnackBar(json['message'] ?? "Authentication failed");
        return;
      }

      // 3) Prefer server values
      final token = (json['token'] ?? "") as String;
      final userId = (json['id'] ?? json['_id'] ?? user.uid) as String;
      final name =
          (json['name'] ?? payload['userName'] ?? "Apple User") as String;
      final email = (json['email'] ?? payload['email'] ?? "") as String;
      final profileImg =
          (json['profileImg'] ?? "") as String; // backend may set one
      final bannerImg = (json['bannerImg'] ?? "") as String;
      final description = (json['description'] ?? "") as String;
      final createdAt = (json['createdAt'] ?? "") as String;

      // Stats
      final Map<String, dynamic> stat =
          (json['stat'] is Map<String, dynamic>)
              ? json['stat'] as Map<String, dynamic>
              : const {};
      final totalCommentGiven = (stat['totalCommentGiven'] ?? 0) as int;
      final totalCommentReceived = (stat['totalCommentReceived'] ?? 0) as int;
      final totalFollower = (stat['totalFollower'] ?? 0) as int;
      final totalFollowing = (stat['totalFollowing'] ?? 0) as int;
      final totalLikeReceived = (stat['totalLikeReceived'] ?? 0) as int;
      final totalThreadPosted = (stat['totalThreadPosted'] ?? 0) as int;
      final totalViewReceived = (stat['totalViewReceived'] ?? 0) as int;
      final tieredProgression =
          (stat['tieredProgression'] ?? "New user") as String;

      // Canonical blob
      final userJson = jsonEncode({
        "id": userId,
        "name": name,
        "email": email,
        "profileImg": profileImg,
        "bannerImg": bannerImg,
        "description": description,
        "createdAt": createdAt,
        "stat": {
          "totalCommentGiven": totalCommentGiven,
          "totalCommentReceived": totalCommentReceived,
          "totalFollower": totalFollower,
          "totalFollowing": totalFollowing,
          "totalLikeReceived": totalLikeReceived,
          "totalThreadPosted": totalThreadPosted,
          "totalViewReceived": totalViewReceived,
          "tieredProgression": tieredProgression,
        },
      });

      // 4) Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('loginMethod', 'apple');
      await prefs.setString('userId', userId);
      await prefs.setString('name', name);
      await prefs.setString('email', email);

      await prefs.setString('profileImage', profileImg);
      await prefs.setString('bannerImage', bannerImg);
      await prefs.setString('description', description);
      await prefs.setString('createdAt', createdAt);

      await prefs.setInt('totalCommentGiven', totalCommentGiven);
      await prefs.setInt('totalCommentReceived', totalCommentReceived);
      await prefs.setInt('totalFollower', totalFollower);
      await prefs.setInt('totalFollowing', totalFollowing);
      await prefs.setInt('totalLikeReceived', totalLikeReceived);
      await prefs.setInt('totalThreadPosted', totalThreadPosted);
      await prefs.setInt('totalViewReceived', totalViewReceived);
      await prefs.setString('tieredProgression', tieredProgression);

      await prefs.setString('userJson', userJson);

      // 5) FCM with fresh JWT
      if (token.isNotEmpty) {
        await sendFcmTokenToBackend(token);
      }

      _showSnackBar("Apple sign-in successful!");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavScreen()),
      );
    } catch (e) {
      _showSnackBar("Apple Sign-In failed");
      debugPrint("Apple Sign-In Error: $e");
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController _resetEmailController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black12;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Email Address"),
                const SizedBox(height: 4),
                CustomTextField(
                  controller: _resetEmailController,
                  hint: "example@gmail.com",
                  borderColor: borderColor,
                  borderWidth: 0.6,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send'),
                onPressed: () async {
                  final email = _resetEmailController.text.trim();
                  if (email.isEmpty) {
                    _showSnackBar("Email is required");
                    return;
                  }

                  Navigator.pop(context); // Close dialog

                  try {
                    final response = await http.post(
                      Uri.parse(
                        'https://rwa-f1623a22e3ed.herokuapp.com/api/users/forgot-password',
                      ),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'email': email}),
                    );

                    final json = jsonDecode(response.body);
                    if (response.statusCode == 200 && json['status'] == true) {
                      _showSnackBar("Reset instructions sent to your email");
                    } else {
                      _showSnackBar(
                        json['message'] ?? "Failed to send reset email",
                      );
                    }
                  } catch (e) {
                    _showSnackBar("Something went wrong");
                    debugPrint("Forgot Password API error: $e");
                  }
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black12;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const BackTitleAppBar(title: 'Login'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SocialAuthButton(
                label: 'Continue with Google',
                iconPath: 'assets/google-icon.png',
                onPressed: _handleGoogleSignIn,
                textColor: isDark ? Colors.white : const Color(0xFF1D1D1D),
              ),
              const SizedBox(height: 12),
              SocialAuthButton(
                label: 'Continue with Apple',
                iconPath: 'assets/apple-icon.png',
                onPressed: _handleAppleSignIn,
                textColor: isDark ? Colors.white : const Color(0xFF1D1D1D),
              ),
              const SizedBox(height: 20),
              const AuthDivider(),
              const SizedBox(height: 20),
              Text(
                "Email",
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              CustomTextField(
                controller: _emailController,
                hint: "example@gmail.com",
                borderColor: borderColor,
                borderWidth: 0.6,
              ),

              const SizedBox(height: 14),
              Text(
                "Password",
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              CustomTextField(
                controller: _passwordController,
                hint: "Enter your password",
                obscure: _obscurePassword,
                borderColor: borderColor,
                borderWidth: 0.6,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: borderColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    "Forget Password?",
                    style: TextStyle(color: AppColors.primaryLight),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleEmailPasswordSignIn,
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text('Log In'),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Don't have an Account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: Text(
                      'SIGNUP',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
