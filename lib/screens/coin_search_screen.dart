import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rwa_app/models/coin_model.dart' show Coin, CurrenciesResponse;
import 'package:rwa_app/screens/coin_details_screen.dart';

class CoinSearchScreen extends StatefulWidget {
  const CoinSearchScreen({super.key});

  @override
  State<CoinSearchScreen> createState() => _CoinSearchScreenState();
}

class _CoinSearchScreenState extends State<CoinSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _currentPage = 1;
  final int _pageSize = 25;

  List<Coin> coins = [];
  List<Coin> recentCoins = [];

  static const String _baseUrl = "https://rwa-f1623a22e3ed.herokuapp.com/api";

  @override
  void initState() {
    super.initState();
    fetchCoins(page: _currentPage);
    loadRecentCoins();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        if (!_isLoadingMore && !_isSearching && _hasMore) {
          _loadMoreCoins();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadRecentCoins() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('recent_coins') ?? [];

    setState(() {
      recentCoins = jsonList.map((e) => Coin.fromJson(json.decode(e))).toList();
    });
  }

  Future<void> saveRecentCoin(Coin coin) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('recent_coins') ?? [];

    jsonList.removeWhere((e) => Coin.fromJson(json.decode(e)).id == coin.id);
    jsonList.insert(0, json.encode(coin.toJson()));
    if (jsonList.length > 5) jsonList.removeLast();

    await prefs.setStringList('recent_coins', jsonList);
    loadRecentCoins();
  }

  Future<void> fetchCoins({int page = 1, bool append = false}) async {
    try {
      final uri = Uri.parse("$_baseUrl/currencies?page=$page&size=$_pageSize");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final parsed = CurrenciesResponse.fromJson(json);

        setState(() {
          if (append) {
            coins.addAll(parsed.currencies);
          } else {
            coins = parsed.currencies;
          }

          _hasMore = parsed.currencies.length == _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        throw Exception('Failed to load coins');
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreCoins() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await fetchCoins(page: _currentPage, append: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredCoins =
        _isSearching && _searchController.text.isNotEmpty
            ? coins.where((coin) {
              final query = _searchController.text.toLowerCase();
              return coin.name.toLowerCase().contains(query) ||
                  coin.symbol.toLowerCase().contains(query);
            }).toList()
            : coins;

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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF0087E0),
                  ),
                  cursorColor: const Color(0xFF0087E0),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon:
                        _isSearching
                            ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _isSearching = false);
                              },
                              child: const Icon(
                                Icons.close,
                                color: Colors.grey,
                              ),
                            )
                            : null,
                    hintText: "Search for coin",
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
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
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recentCoins.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          "Recently Added",
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 16),
                          itemCount: recentCoins.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final coin = recentCoins[i];
                            return GestureDetector(
                              onTap: () {
                                saveRecentCoin(coin);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => CoinDetailScreen(
                                          coin: coin.id,
                                          coindetils: coin,
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Image.network(
                                      coin.image,
                                      width: 24,
                                      height: 24,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      coin.symbol.toUpperCase(),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (filteredCoins.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          "All Coins",
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withAlpha(
                                (0.2 * 255).round(),
                              ),
                            ),
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredCoins.length,
                            separatorBuilder:
                                (_, __) => Divider(
                                  height: 0.5,
                                  color: theme.dividerColor.withAlpha(
                                    (0.2 * 255).round(),
                                  ),
                                ),
                            itemBuilder:
                                (_, i) =>
                                    _buildCoinTile(filteredCoins[i], theme),
                          ),
                        ),
                      ),
                    ],
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0087E0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildCoinTile(Coin coin, ThemeData theme) {
    final isUp = coin.priceChange24h >= 0;
    final changeColor =
        isUp ? const Color(0xFF16C784) : const Color(0xFFFF3B30);
    final icon = isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down;

    return InkWell(
      onTap: () {
        saveRecentCoin(coin);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CoinDetailScreen(coin: coin.id, coindetils: coin),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Image.network(coin.image, width: 34, height: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coin.symbol.toUpperCase(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    coin.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Icon(icon, size: 16, color: changeColor),
                Text(
                  "${coin.priceChange24h.abs().toStringAsFixed(2)}%",
                  style: TextStyle(
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
