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

      final prefs = await SharedPreferences.getInstance();

      final payload = {
        "userName": user.displayName ?? "No Name",
        "profileImg": user.photoURL ?? "",
        "email": user.email ?? "",
        "googleId": user.uid,
      };

      print(payload);

      final response = await http.post(
        Uri.parse(
          "https://rwa-f1623a22e3ed.herokuapp.com/api/users/auth/google",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      debugPrint("🔐 Backend response: ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == true) {
          // ✅ Save user info
          await prefs.setString('token', json['token'] ?? "");
          await prefs.setString('email', payload['email'] ?? "");
          await prefs.setString('name', payload['userName'] ?? "");
          await prefs.setString('profileImage', payload['profileImg'] ?? "");
          await prefs.setString('loginMethod', 'google');
          await prefs.setString('userId', json['_id'] ?? "");

          // ✅ Save user stat info
          final stat = json['stat'];
          if (stat != null) {
            await prefs.setInt(
              'totalCommentGiven',
              stat['totalCommentGiven'] ?? 0,
            );
            await prefs.setInt(
              'totalCommentReceived',
              stat['totalCommentReceived'] ?? 0,
            );
            await prefs.setInt('totalFollower', stat['totalFollower'] ?? 0);
            await prefs.setInt('totalFollowing', stat['totalFollowing'] ?? 0);
            await prefs.setInt(
              'totalLikeReceived',
              stat['totalLikeReceived'] ?? 0,
            );
            await prefs.setInt(
              'totalThreadPosted',
              stat['totalThreadPosted'] ?? 0,
            );
            await prefs.setInt(
              'totalViewReceived',
              stat['totalViewReceived'] ?? 0,
            );
            await prefs.setString(
              'tieredProgression',
              stat['tieredProgression'] ?? "New user",
            );
          }

          _showSnackBar(context, "Google sign-in successful!");

          // 🔥 Get FCM token
          final fcmToken = await FirebaseMessaging.instance.getToken();
          final savedFcmToken = prefs.getString('fcm_token');
          final jwt = prefs.getString('token');

          print('📦 Stored FCM Token: $savedFcmToken');
          print('📲 New FCM Token: $fcmToken');
          print('🔐 JWT Token: $jwt');

          // Upload FCM token
          if (fcmToken != null && jwt != null && fcmToken != savedFcmToken) {
            try {
              final fcmRes = await http.post(
                Uri.parse(
                  "https://rwa-f1623a22e3ed.herokuapp.com/api/users/fcmtoken",
                ),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $jwt',
                },
                body: jsonEncode({'token': fcmToken}),
              );

              print('📡 FCM Token Upload Status: ${fcmRes.statusCode}');
              print('📡 FCM Token Upload Body: ${fcmRes.body}');

              if (fcmRes.statusCode == 200 || fcmRes.statusCode == 201) {
                await prefs.setString('fcm_token', fcmToken);
                print('✅ FCM token sent and saved locally');
              } else {
                print('❌ Failed to send FCM token: ${fcmRes.statusCode}');
              }
            } catch (e) {
              print('❌ Error sending FCM token: $e');
            }
          }

          // ✅ Navigate to home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BottomNavScreen()),
          );
        } else {
          _showSnackBar(context, json['message'] ?? "Authentication failed");
        }
      } else {
        _showSnackBar(context, "Internal server error");
      }
    } catch (e) {
      _showSnackBar(context, "Google Sign-In failed");
      debugPrint("Google Sign-In Error: $e");
    }
  }

  Future<void> _handleAppleSignIn(BuildContext context) async {
    try {
      _showSnackBar(context, "Signing in with Apple...");

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

      final payload = {
        "userName": user.displayName ?? appleCred.givenName ?? "Apple User",
        "profileImg": "",
        "email": user.email ?? "",
        "appleId": user.uid,
      };

      final response = await http.post(
        Uri.parse(
          "https://rwa-f1623a22e3ed.herokuapp.com/api/users/auth/apple",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final prefs = await SharedPreferences.getInstance();

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == true) {
          // ✅ Save user details
          await prefs.setString('token', json['token'] ?? "");
          await prefs.setString('email', payload['email'] ?? "");
          await prefs.setString('name', payload['userName'] ?? "");
          await prefs.setString('profileImage', "");
          await prefs.setString('loginMethod', 'apple');
          await prefs.setString('userId', json['_id'] ?? user.uid);

          // ✅ Save user stats
          final stat = json['stat'];
          if (stat != null) {
            await prefs.setInt(
              'totalCommentGiven',
              stat['totalCommentGiven'] ?? 0,
            );
            await prefs.setInt(
              'totalCommentReceived',
              stat['totalCommentReceived'] ?? 0,
            );
            await prefs.setInt('totalFollower', stat['totalFollower'] ?? 0);
            await prefs.setInt('totalFollowing', stat['totalFollowing'] ?? 0);
            await prefs.setInt(
              'totalLikeReceived',
              stat['totalLikeReceived'] ?? 0,
            );
            await prefs.setInt(
              'totalThreadPosted',
              stat['totalThreadPosted'] ?? 0,
            );
            await prefs.setInt(
              'totalViewReceived',
              stat['totalViewReceived'] ?? 0,
            );
            await prefs.setString(
              'tieredProgression',
              stat['tieredProgression'] ?? "New user",
            );
          }

          _showSnackBar(context, "Apple sign-in successful!");

          // ✅ FCM token upload
          final fcmToken = await FirebaseMessaging.instance.getToken();
          final savedFcmToken = prefs.getString('fcm_token');
          final jwt = prefs.getString('token');

          print('📦 Stored FCM Token: $savedFcmToken');
          print('📲 New FCM Token: $fcmToken');
          print('🔐 JWT Token: $jwt');

          if (fcmToken != null && jwt != null && fcmToken != savedFcmToken) {
            try {
              final fcmRes = await http.post(
                Uri.parse(
                  "https://rwa-f1623a22e3ed.herokuapp.com/api/users/fcmtoken",
                ),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $jwt',
                },
                body: jsonEncode({'token': fcmToken}),
              );

              print('📡 FCM Token Upload Status: ${fcmRes.statusCode}');
              print('📡 FCM Token Upload Body: ${fcmRes.body}');

              if (fcmRes.statusCode == 200 || fcmRes.statusCode == 201) {
                await prefs.setString('fcm_token', fcmToken);
                print('✅ FCM token sent and saved locally');
              } else {
                print('❌ Failed to send FCM token: ${fcmRes.statusCode}');
              }
            } catch (e) {
              print('❌ Error sending FCM token: $e');
            }
          }

          // ✅ Navigate to home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BottomNavScreen()),
          );
        } else {
          _showSnackBar(context, json['message'] ?? "Backend Auth Failed");
        }
      } else {
        _showSnackBar(context, "Server error during Apple Sign-In");
      }
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
