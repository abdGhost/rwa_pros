import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

mixin WatchlistMixin<T extends StatefulWidget> on State<T> {
  bool isFavorite = false;
  bool isFavoriteLoading = true;
  bool _watchlistChanged = false;

  Future<void> checkIfFavorite(
    String coin,
    void Function(bool, bool) onResult,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      onResult(false, false);
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final url = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/mobile/currencies/watchlist',
    );

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> watchlist = json['watchList'] ?? [];

        final isInWatchlist = watchlist.any((item) {
          return item['id']?.toString().toLowerCase() == coin.toLowerCase() ||
              item['symbol']?.toString().toLowerCase() == coin.toLowerCase();
        });

        onResult(isInWatchlist, false);
      } else {
        onResult(false, false);
      }
    } catch (e) {
      debugPrint('❌ Error checking favorite status: $e');
      onResult(false, false);
    }
  }

  Future<void> toggleFavorite(
    String coin,
    BuildContext context,
    void Function(bool, bool) onResult,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to add to Watchlist.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final favUrl = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/users/fav/coin/$coin',
    );

    try {
      final response = await http.get(favUrl, headers: headers);
      final json = jsonDecode(response.body);

      if (json['status'] == true) {
        final msg = json['message'].toString().toLowerCase();
        bool added = false;

        if (msg.contains("removed") || msg.contains("not in")) {
          added = false;
        } else if (msg.contains("added") || msg.contains("already")) {
          added = true;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                added ? 'Added to Watchlist' : 'Removed from Watchlist',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        onResult(added, true);
      }
    } catch (e) {
      debugPrint('❌ Favorite toggle error: $e');
    }
  }
}
