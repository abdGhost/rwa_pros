import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rwa_app/screens/botttom_nav_screen.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  Future<void> _retryConnection(BuildContext context) async {
    final result = await Connectivity().checkConnectivity();
    final isNetworkConnected = result != ConnectivityResult.none;

    if (isNetworkConnected) {
      try {
        final lookup = await InternetAddress.lookup('example.com');
        final hasInternet =
            lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;

        if (hasInternet) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BottomNavScreen()),
          );
          return;
        }
      } on SocketException {
        // Still no internet
      }
    }

    // Clear any existing snackbar before showing a new one
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Still no internet connection.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                color: isDark ? Colors.red[300] : Colors.red,
                size: 80,
              ),
              const SizedBox(height: 20),
              Text(
                'No Internet Connection',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => _retryConnection(context),
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
