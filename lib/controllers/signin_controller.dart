import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SigninResult {
  final bool status;
  final String message;
  final String? token;
  final String? userId;
  final String? email;
  final String? name;

  SigninResult({
    required this.status,
    required this.message,
    this.token,
    this.userId,
    this.email,
    this.name,
  });

  factory SigninResult.fromJson(Map<String, dynamic> json) {
    return SigninResult(
      status: json['status'] ?? false,
      message: json['message'] ?? 'Unknown error',
      token: json['token'],
      userId: json['userId'],
      email: json['email'],
      name: json['name'],
    );
  }
}

class SigninController {
  Future<SigninResult> handleGoogleAuth(
    BuildContext context,
    Map<String, String> payload,
  ) async {
    final url = Uri.parse(
      "https://rwa-f1623a22e3ed.herokuapp.com/api/users/auth/google",
    );
    final body = jsonEncode(payload);

    print("➡️ Google Auth Request:\nURL: $url\nBody: $body");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print("✅ Google Auth Response: ${response.statusCode}");
      print("📦 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SigninResult.fromJson(json);
      } else {
        return SigninResult(
          status: false,
          message: "Server Error: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("❌ Google Auth Exception: $e");
      return SigninResult(status: false, message: "Network error: $e");
    }
  }

  Future<SigninResult> handleSignin(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    final url = Uri.parse(
      "https://rwa-f1623a22e3ed.herokuapp.com/api/users/auth/login",
    );
    final body = jsonEncode({"email": email, "password": password});

    print("➡️ Email Login Request:\nURL: $url\nBody: $body");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print("✅ Email Login Response: ${response.statusCode}");
      print("📦 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SigninResult.fromJson(json);
      } else {
        return SigninResult(
          status: false,
          message: "Login failed: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("❌ Email Login Exception: $e");
      return SigninResult(status: false, message: "Network error: $e");
    }
  }
}
