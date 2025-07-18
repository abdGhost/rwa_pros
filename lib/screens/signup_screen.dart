import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rwa_app/screens/botttom_nav_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:rwa_app/api/api_service.dart';
import 'package:rwa_app/controllers/signup_controller.dart';
import 'package:rwa_app/models/signup_response_model.dart';
import 'package:rwa_app/theme/theme.dart';
import 'package:rwa_app/widgets/auth_divider_widget.dart';
import 'package:rwa_app/widgets/back_title_appbar_widget.dart';
import 'package:rwa_app/widgets/custom_textfield_widget.dart';
import 'package:rwa_app/widgets/social_auth_widget.dart';
import 'package:http/http.dart' as http;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black12;

    return Scaffold(
      appBar: const BackTitleAppBar(title: 'Signup'),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SocialAuthButton(
                label: 'Continue with Google',
                iconPath: 'assets/google-icon.png',
                onPressed: _signInWithGoogle,
                textColor: isDark ? Colors.white : const Color(0xFF1D1D1D),
              ),
              const SizedBox(height: 12),
              SocialAuthButton(
                label: 'Continue with Apple',
                iconPath: 'assets/apple-icon.png',
                onPressed: _signInWithApple,
                textColor: isDark ? Colors.white : const Color(0xFF1D1D1D),
              ),
              const SizedBox(height: 20),
              const AuthDivider(),
              const SizedBox(height: 20),

              _label("Email Address", textTheme),
              const SizedBox(height: 2),
              CustomTextField(
                controller: _emailController,
                hint: 'example@gmail.com',
                borderColor: borderColor,
                borderWidth: 0.6,
              ),

              const SizedBox(height: 14),
              _label("Username", textTheme),
              const SizedBox(height: 2),
              CustomTextField(
                controller: _usernameController,
                hint: 'Username',
                borderColor: borderColor,
                borderWidth: 0.6,
              ),

              const SizedBox(height: 14),
              _label("Password", textTheme),
              const SizedBox(height: 2),
              CustomTextField(
                controller: _passwordController,
                hint: 'Enter your password',
                obscure: _obscurePassword,
                borderColor: borderColor,
                borderWidth: 0.6,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: borderColor,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              const SizedBox(height: 14),
              _label("Confirm Password", textTheme),
              const SizedBox(height: 2),
              CustomTextField(
                controller: _confirmPasswordController,
                hint: 'Confirm Password',
                obscure: _obscureConfirmPassword,
                borderColor: borderColor,
                borderWidth: 0.6,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 20,
                    color: borderColor,
                  ),
                  onPressed:
                      () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                ),
              ),

              const SizedBox(height: 30),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _isLoading ? null : _onSignupPressed,
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text('Sign Up'),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Text("Already have an account? ", style: textTheme.bodySmall),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'LOGIN',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        color: AppColors.primaryLight,
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

  Widget _label(String text, TextTheme textTheme) {
    return Text(
      text,
      style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
    );
  }

  Future<void> _onSignupPressed() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar("Please fill in all fields");
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match");
      return;
    }

    _showSnackBar("Creating your account...");
    setState(() => _isLoading = true);

    try {
      final result = await SignupController().handleSignup(
        context,
        email: email,
        username: username,
        password: password,
        confirmPassword: confirmPassword,
      );

      _showSnackBar(result.message);
      if (result.status == true) {
        _showSnackBar("Signup successful!");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BottomNavScreen()),
        );
      }
    } catch (e) {
      _showSnackBar(_extractErrorMessage(e.toString()));
      debugPrint("Signup Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      _showSnackBar("Signing in with Google...");
      final googleSignIn =
          Platform.isIOS
              ? GoogleSignIn(
                clientId:
                    '458920784247-1e7tebaeni9ovvgte529fg821ugd0ntb.apps.googleusercontent.com',
              )
              : GoogleSignIn();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _showSnackBar("Google Sign-In canceled");
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
      if (user == null) {
        _showSnackBar("Google Sign-In failed");
        return;
      }

      final payload = {
        "userName": user.displayName ?? "Unknown",
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

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 && json['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', json['token']);
        await prefs.setString('email', user.email ?? "");
        await prefs.setString('userId', json['userId'] ?? user.uid);
        await prefs.setString('name', user.displayName ?? "");
        await prefs.setString('profileImg', user.photoURL ?? "");
        await prefs.setString('loginMethod', 'google');

        _showSnackBar("Google sign-in successful!");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BottomNavScreen()),
        );
      } else {
        _showSnackBar("Backend Auth Failed");
        debugPrint("API Error: ${json['message']}");
      }
    } catch (e) {
      _showSnackBar("Google Sign-In failed");
      debugPrint("Google Sign-In Error: $e");
    }
  }

  Future<void> _signInWithApple() async {
    try {
      _showSnackBar("Signing in with Apple...");

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

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 && json['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', json['token']);
        await prefs.setString('email', payload['email'] ?? "");
        await prefs.setString('userId', json['userId'] ?? user.uid);
        await prefs.setString('name', payload['userName'] ?? "");
        await prefs.setString('profileImg', "");
        await prefs.setString('loginMethod', 'apple');

        _showSnackBar("Apple sign-in successful!");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BottomNavScreen()),
        );
      } else {
        _showSnackBar("Backend Auth Failed");
        debugPrint("API Error: ${json['message']}");
      }
    } catch (e) {
      _showSnackBar("Apple Sign-In failed");
      debugPrint("Apple Sign-In Error: $e");
    }
  }

  String _extractErrorMessage(String error) {
    try {
      final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(error);
      return match?.group(1) ?? "Something went wrong";
    } catch (_) {
      return "Something went wrong";
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}
