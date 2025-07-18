class SigninResponse {
  final bool status;
  final String message;
  final String? token;
  final String? email;
  final String? name;
  final String? userId;

  SigninResponse({
    required this.status,
    required this.message,
    this.token,
    this.email,
    this.name,
    this.userId,
  });

  factory SigninResponse.fromJson(Map<String, dynamic> json) {
    return SigninResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? 'Unknown error',
      token: json['token'],
      email: json['email'],
      name: json['name'],
      userId: json['_id'],
    );
  }
}
