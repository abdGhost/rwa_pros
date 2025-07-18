import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/signup_response_model.dart';

class SignupController {
  final ApiService _apiService = ApiService();

  Future<SignupResponse> handleSignup(
    BuildContext context, {
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _apiService.signup(
      email: email,
      username: username,
      password: password,
      confirmPassword: confirmPassword,
    );

    return SignupResponse.fromJson(response);
  }
}
