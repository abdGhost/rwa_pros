import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/models/coin_model.dart' show Coin, CurrenciesResponse;
import 'package:rwa_app/screens/portfolio_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddCoinToPortfolioScreen extends StatefulWidget {
  const AddCoinToPortfolioScreen({super.key});

  @override
  State<AddCoinToPortfolioScreen> createState() =>
      _AddCoinToPortfolioScreenState();
}

class _AddCoinToPortfolioScreenState extends State<AddCoinToPortfolioScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoading = true;
  bool _isAdding = false;
  String? _addingCoinId;

  List<Coin> coins = [];
  final List<int> recentlyAddedIndices = [0, 1];
  static const String _baseUrl = "https://rwa-f1623a22e3ed.herokuapp.com/api";

  @override
  void initState() {
    super.initState();
    fetchCoins();
  }

  Future<void> fetchCoins({int page = 1, int size = 25}) async {
    try {
      final uri = Uri.parse("$_baseUrl/currencies?page=$page&size=$size");
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final parsed = CurrenciesResponse.fromJson(json);
        setState(() {
          coins = parsed.currencies;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load coins: ${response.body}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredCoins =
        _isSearching && _searchController.text.isNotEmpty
            ? coins.where((coin) {
              final query = _searchController.text.toLowerCase();
              return coin.name.toLowerCase().contains(query) ||
                  coin.symbol.toLowerCase().contains(query);
            }).toList()
            : coins;

    final recentlyAdded =
        recentlyAddedIndices
            .where((index) => index < coins.length)
            .map((i) => coins[i])
            .toList();

    final others =
        filteredCoins.where((coin) => !recentlyAdded.contains(coin)).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged:
                      (value) =>
                          setState(() => _isSearching = value.isNotEmpty),
                  style: GoogleFonts.inter(color: const Color(0xFF16C784)),
                  cursorColor: const Color(0xFF16C784),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon:
                        _isSearching
                            ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _isSearching = false);
                              },
                              child: const Icon(Icons.close, size: 18),
                            )
                            : null,
                    hintText: "Search for coin",
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0087E0)),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recentlyAdded.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          "Recently Added",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 16),
                          itemCount: recentlyAdded.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final coin = recentlyAdded[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? Colors.white10
                                        : const Color(0xFFEEF1F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Image.network(
                                    coin.image,
                                    width: 24,
                                    height: 24,
                                    errorBuilder:
                                        (_, __, ___) => const Icon(Icons.image),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    coin.symbol.toUpperCase(),
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (others.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          "All Coins",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(5),
                                blurRadius: 1,
                                offset: const Offset(0, .5),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: others.length,
                            separatorBuilder:
                                (_, __) => Divider(
                                  color:
                                      isDark
                                          ? Colors.grey.shade800
                                          : Colors.black12,
                                  thickness: 0.1,
                                  height: 0.5,
                                ),
                            itemBuilder:
                                (_, i) => _buildCoinTile(context, others[i]),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildCoinTile(BuildContext context, Coin coin) {
    final isUp = coin.priceChange24h >= 0;
    final changeColor =
        isUp ? const Color(0xFF16C784) : const Color(0xFFFF3B30);
    final icon = isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down;

    return InkWell(
      onTap:
          _isAdding
              ? null
              : () async {
                setState(() {
                  _isAdding = true;
                  _addingCoinId = coin.id;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Adding ${coin.name} to portfolio...',
                      style: GoogleFonts.inter(),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );

                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token') ?? '';

                  if (token.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Authentication token missing.',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    );
                    return;
                  }

                  final response = await http.get(
                    Uri.parse(
                      'https://rwa-f1623a22e3ed.herokuapp.com/api/user/token/mobile/add/portfolio/${coin.id}',
                    ),
                    headers: {'Authorization': 'Bearer $token'},
                  );

                  final data = jsonDecode(response.body);
                  // if (response.statusCode == 200 && data['status'] == 200) {
                  //   ScaffoldMessenger.of(context).showSnackBar(
                  //     SnackBar(
                  //       content: Text(
                  //         '${data['message']}',
                  //         style: GoogleFonts.inter(),
                  //       ),
                  //     ),
                  //   );
                  //   Navigator.pop(context, true);
                  // }
                  if (response.statusCode == 200 && data['status'] == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${data['message']}',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    );
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${data['message']}',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    );
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error connecting to server.',
                        style: GoogleFonts.inter(),
                      ),
                    ),
                  );
                } finally {
                  setState(() {
                    _isAdding = false;
                    _addingCoinId = null;
                  });
                }
              },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Image.network(
              coin.image,
              width: 34,
              height: 34,
              errorBuilder: (_, __, ___) => const Icon(Icons.image),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coin.symbol.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    coin.name,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            _isAdding && _addingCoinId == coin.id
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0087E0),
                  ),
                )
                : Row(
                  children: [
                    Icon(icon, size: 16, color: changeColor),
                    const SizedBox(width: 2),
                    Text(
                      "${coin.priceChange24h.abs().toStringAsFixed(2)}%",
                      style: GoogleFonts.inter(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
