import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rwa_app/models/category_model.dart';
import 'package:rwa_app/models/coin_model.dart';
import 'package:rwa_app/models/news_model.dart';
import 'package:rwa_app/models/portfolioToken_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = "https://rwa-f1623a22e3ed.herokuapp.com/api";

  Future<Map<String, dynamic>> signup({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    final url = Uri.parse("$_baseUrl/users/signup");

    final body = {
      "email": email,
      "userName": username,
      "password": password,
      "confirmPassword": confirmPassword,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Signup failed: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> signin({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse("$_baseUrl/users/signin");

    final body = {"email": email, "password": password};

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Signin failed: ${response.body}");
    }
  }

  /// ✅ Google Sign-In API
  Future<Map<String, dynamic>> googleAuth(Map<String, dynamic> payload) async {
    final url = Uri.parse("$_baseUrl/users/auth/google");

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Google Auth failed: ${response.body}");
    }
  }

  Future<List<Coin>> fetchCoins({int page = 1, int size = 25}) async {
    final uri = Uri.parse("$_baseUrl/currencies?page=$page&size=$size");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final parsed = CurrenciesResponse.fromJson(json);
      return parsed.currencies;
    } else {
      throw Exception("Failed to load coins: ${response.body}");
    }
  }

  Future<List<News>> fetchNews() async {
    final response = await http.get(Uri.parse("$_baseUrl/currencies/rwa/news"));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      final List<dynamic> newsList = jsonBody['news'];
      return newsList.map((newsJson) => News.fromJson(newsJson)).toList();
    } else {
      throw Exception('Failed to load news');
    }
  }

  Future<List<PortfolioToken>> fetchPortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse("$_baseUrl/user/token/portfolio"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List portfolioList = json['portfolioToken'];

      return portfolioList
          .map((item) => PortfolioToken.fromJson(item))
          .toList();
    } else {
      throw Exception('Failed to fetch portfolio');
    }
  }

  Future<Map<String, dynamic>> fetchHighlightData() async {
    final url = Uri.parse("$_baseUrl/currencies/rwa/highlight");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == true) {
        return json['highlightData'];
      } else {
        throw Exception("Highlight status false");
      }
    } else {
      throw Exception("Failed to fetch highlight data: ${response.body}");
    }
  }

  Future<Map<String, dynamic>?> fetchTopTrendingCoin() async {
    final url = Uri.parse("$_baseUrl/currencies/rwa/trend");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == true &&
          json['trend'] != null &&
          json['trend'] is List &&
          json['trend'].isNotEmpty) {
        return json['trend'][0];
      } else {
        throw Exception("No trending coins found or status false");
      }
    } else {
      throw Exception("Failed to fetch trending data: ${response.body}");
    }
  }

  Future<List<Coin>> fetchCoinsPaginated({int page = 1, int size = 25}) async {
    final uri = Uri.parse("$_baseUrl/currencies?page=$page&size=$size");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final parsed = CurrenciesResponse.fromJson(json);
      return parsed.currencies;
    } else {
      throw Exception("Failed to load coins: ${response.body}");
    }
  }

  Future<List<Coin>> fetchTrendingCoins() async {
    final url = Uri.parse("$_baseUrl/currencies/rwa/trend");
    final response = await http.get(url);
    print(response.body);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == true && json['trend'] is List) {
        return (json['trend'] as List)
            .map((item) => Coin.fromJson(item))
            .toList();
      } else {
        throw Exception("Invalid trending response structure");
      }
    } else {
      throw Exception("Failed to load trending coins");
    }
  }

  Future<List<Coin>> fetchWatchlists() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print(token);

    if (token == null || token.isEmpty) {
      throw Exception("No access token found.");
    }

    final url = Uri.parse(
      "https://rwa-f1623a22e3ed.herokuapp.com/api/mobile/currencies/watchlist",
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('WATCH LIST API , ${response.body}');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == true && json['watchList'] is List) {
        return (json['watchList'] as List)
            .map((item) => Coin.fromJson(item))
            .toList();
      } else {
        throw Exception("Watchlist format invalid or empty");
      }
    } else {
      throw Exception("Failed to load watchlist: ${response.body}");
    }
  }

  Future<List<Coin>> fetchTopGainers() async {
    final url = Uri.parse(
      "https://rwa-f1623a22e3ed.herokuapp.com/api/currencies/rwa/topGainer",
    );

    final response = await http.get(url);
    print("📡 Status Code: ${response.statusCode}");
    print("📥 Raw Body: ${response.body}");

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        print("✅ Decoded JSON: $json");
        print("🔎 JSON Type: ${json.runtimeType}");

        if (json.containsKey('topGainer')) {
          print(
            "🔍 topGainer: ${json['topGainer']} (${json['topGainer'].runtimeType})",
          );
        }

        if (json['status'] == true &&
            json['topGainer'] != null &&
            json['topGainer'] is List &&
            json['topGainer'].isNotEmpty) {
          final coins =
              (json['topGainer'] as List)
                  .map((data) => Coin.fromJson(data))
                  .toList();
          print("✅ Parsed Coins: ${coins.length}");
          return coins;
        } else {
          throw Exception("Top gainers format invalid or empty");
        }
      } catch (e) {
        print("❌ JSON Parsing Error: $e");
        throw Exception("Failed to parse top gainers response");
      }
    } else {
      throw Exception("Failed to fetch top gainers: ${response.statusCode}");
    }
  }

  Future<List<Category>> fetchCategories() async {
    final response = await http.get(
      Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/admin/category'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List categories = data['categories'];
      return categories.map((e) => Category.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  Future<List<Coin>> fetchCoinsByCategory(String categoryId) async {
    final response = await http.get(
      Uri.parse(
        'https://rwa-f1623a22e3ed.herokuapp.com/api/currencies/rwa/category/$categoryId',
      ),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List coins = data['tokens'];
      return coins.map((e) => Coin.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load category coins');
    }
  }
}
