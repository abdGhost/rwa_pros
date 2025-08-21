import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rwa_app/screens/html_content_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/screens/botttom_nav_screen.dart';
import 'package:rwa_app/screens/login_screen.dart';
import 'package:rwa_app/screens/setting_screen.dart';
import 'package:rwa_app/theme/theme.dart';
import 'package:rwa_app/widgets/social_auth_widget.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

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

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      _showSnackBar(context, "Signing in with Google...");
      await GoogleSignIn().signOut(); // Force account selection

      final googleUser =
          await GoogleSignIn(
            clientId:
                Platform.isIOS
                    ? '458920784247-1e7tebaeni9ovvgte529fg821ugd0ntb.apps.googleusercontent.com'
                    : null,
          ).signIn();

      if (googleUser == null) {
        _showSnackBar(context, "Google sign-in canceled");
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
      if (user == null) throw Exception("Firebase sign-in failed");

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

      debugPrint("🔐 Backend response: ${response.body}");

      // Parse body safely
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        _showSnackBar(context, "Invalid server response");
        return;
      }

      if (response.statusCode != 200 || json['status'] != true) {
        _showSnackBar(context, json['message'] ?? "Authentication failed");
        return;
      }

      // Prefer server values over client payload
      final token = (json['token'] ?? "") as String;
      final userId = (json['id'] ?? json['_id'] ?? user.uid) as String;
      final name = (json['name'] ?? payload['userName'] ?? "") as String;
      final email = (json['email'] ?? payload['email'] ?? "") as String;
      final profileImg =
          (json['profileImg'] ?? payload['profileImg'] ?? "") as String;
      final bannerImg = (json['bannerImg'] ?? "") as String;
      final description = (json['description'] ?? "") as String;
      final createdAt = (json['createdAt'] ?? "") as String;

      // Stats (with defaults)
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

      // Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('loginMethod', 'google');
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

      _showSnackBar(context, "Google sign-in successful!");

      // FCM upload with fresh JWT
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final savedFcmToken = prefs.getString('fcm_token');
      debugPrint('📲 New FCM Token: $fcmToken');
      debugPrint('📦 Stored FCM Token: $savedFcmToken');

      if (fcmToken != null &&
          fcmToken.isNotEmpty &&
          fcmToken != savedFcmToken &&
          token.isNotEmpty) {
        try {
          final fcmRes = await http.post(
            Uri.parse(
              "https://rwa-f1623a22e3ed.herokuapp.com/api/users/fcmtoken",
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'token': fcmToken}),
          );

          debugPrint('📡 FCM Upload Status: ${fcmRes.statusCode}');
          debugPrint('📡 FCM Upload Body: ${fcmRes.body}');

          if (fcmRes.statusCode == 200 || fcmRes.statusCode == 201) {
            await prefs.setString('fcm_token', fcmToken);
            debugPrint('✅ FCM token sent and saved locally');
          } else {
            debugPrint('❌ Failed to send FCM token: ${fcmRes.statusCode}');
          }
        } catch (e) {
          debugPrint('❌ Error sending FCM token: $e');
        }
      }

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavScreen()),
      );
    } catch (e) {
      _showSnackBar(context, "Google Sign-In failed");
      debugPrint("Google Sign-In Error: $e");
    }
  }

  Future<void> _handleAppleSignIn(BuildContext context) async {
    try {
      _showSnackBar(context, "Signing in with Apple...");

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

      // Apple may not provide name/email after first consent; use safe fallback.
      final fallbackDisplayName =
          ((appleCred.givenName ?? "").isNotEmpty ||
                  (appleCred.familyName ?? "").isNotEmpty)
              ? "${appleCred.givenName ?? ''} ${appleCred.familyName ?? ''}"
                  .trim()
              : "Apple User";

      final payload = {
        "userName":
            (user.displayName?.isNotEmpty == true)
                ? user.displayName
                : fallbackDisplayName,
        "profileImg": "", // Apple doesn't provide avatar
        "email": user.email ?? "", // Might be empty on subsequent logins
        "appleId": user.uid,
      };

      // 2) Backend auth
      final response = await http.post(
        Uri.parse(
          "https://rwa-f1623a22e3ed.herokuapp.com/api/users/auth/apple",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      debugPrint("🍎 Backend response: ${response.body}");

      // Parse safely
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        _showSnackBar(context, "Invalid server response");
        return;
      }
      if (response.statusCode != 200 || json['status'] != true) {
        _showSnackBar(context, json['message'] ?? "Authentication failed");
        return;
      }

      // 3) Prefer server values
      final token = (json['token'] ?? "") as String;
      final userId = (json['id'] ?? json['_id'] ?? user.uid) as String;
      final name =
          (json['name'] ?? payload['userName'] ?? "Apple User") as String;
      final email = (json['email'] ?? payload['email'] ?? "") as String;
      final profileImg = (json['profileImg'] ?? "") as String;
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

      // Canonical blob (handy for hydrate/refresh)
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

      _showSnackBar(context, "Apple sign-in successful!");

      // 5) FCM upload with fresh JWT
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final savedFcmToken = prefs.getString('fcm_token');
      debugPrint('📲 New FCM Token: $fcmToken');
      debugPrint('📦 Stored FCM Token: $savedFcmToken');

      if (fcmToken != null &&
          fcmToken.isNotEmpty &&
          fcmToken != savedFcmToken &&
          token.isNotEmpty) {
        try {
          final fcmRes = await http.post(
            Uri.parse(
              "https://rwa-f1623a22e3ed.herokuapp.com/api/users/fcmtoken",
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'token': fcmToken}),
          );

          debugPrint('📡 FCM Upload Status: ${fcmRes.statusCode}');
          debugPrint('📡 FCM Upload Body: ${fcmRes.body}');

          if (fcmRes.statusCode == 200 || fcmRes.statusCode == 201) {
            await prefs.setString('fcm_token', fcmToken);
            debugPrint('✅ FCM token sent and saved locally');
          } else {
            debugPrint('❌ Failed to send FCM token: ${fcmRes.statusCode}');
          }
        } catch (e) {
          debugPrint('❌ Error sending FCM token: $e');
        }
      }

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavScreen()),
      );
    } catch (e) {
      _showSnackBar(context, "Apple Sign-In failed");
      debugPrint("Apple Sign-In Error: $e");
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/rwapros/logo-white.png'
                        : 'assets/rwapros/logo.png',
                    width: 200,
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'The most Trusted app for\nReal World Assets',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 13,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 60),
                  SocialAuthButton(
                    label: 'Continue with Email & Password',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    backgroundColor: AppColors.primaryDark,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 40, child: Divider(thickness: 0.5)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "OR",
                          style: TextStyle(
                            color: textColor.withOpacity(0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40, child: Divider(thickness: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SocialAuthButton(
                    label: 'Continue with Google',
                    iconPath: 'assets/google-icon.png',
                    onPressed: () => _handleGoogleSignIn(context),
                    textColor: textColor,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<bool>(
                    future: SignInWithApple.isAvailable(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.data == true) {
                        return SocialAuthButton(
                          label: 'Continue with Apple',
                          iconPath: 'assets/apple-icon.png',
                          onPressed: () => _handleAppleSignIn(context),
                          textColor: textColor,
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                  const SizedBox(height: 20),

                  Text.rich(
                    TextSpan(
                      text: 'By proceeding, you agree to Condo’s ',
                      style: TextStyle(fontSize: 10, color: textColor),
                      children: [
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: primaryColor,
                            decorationThickness: 1.5,
                            color: primaryColor,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => HtmlContentModal(
                                          title: "Terms of Service",
                                          apiUrl:
                                              "https://rwa-f1623a22e3ed.herokuapp.com/api/admin/term/service",
                                          contentKey: "service",
                                        ),
                                  );
                                },
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: primaryColor,
                            decorationThickness: 1.5,
                            color: primaryColor,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => HtmlContentModal(
                                          title: "Privacy Policy",
                                          apiUrl:
                                              "https://rwa-f1623a22e3ed.herokuapp.com/api/admin/term/privacy",
                                          contentKey: "privacy",
                                        ),
                                  );
                                },
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Text.rich(
                  //   TextSpan(
                  //     text: 'By proceeding, you agree to Condo’s ',
                  //     style: TextStyle(fontSize: 10, color: textColor),
                  //     children: [
                  //       TextSpan(
                  //         text: 'Terms of Service',
                  //         style: TextStyle(
                  //           decoration: TextDecoration.underline,
                  //           decorationColor: primaryColor,
                  //           decorationThickness: 1.5,
                  //           color: primaryColor,
                  //         ),
                  //       ),
                  //       const TextSpan(text: ' and '),
                  //       TextSpan(
                  //         text: 'Privacy Policy',
                  //         style: TextStyle(
                  //           decoration: TextDecoration.underline,
                  //           decorationColor: primaryColor,
                  //           decorationThickness: 1.5,
                  //           color: primaryColor,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  //   textAlign: TextAlign.center,
                  // ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: textColor.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
