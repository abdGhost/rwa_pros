import 'dart:async';
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
  static const _brandYellow = Color(0xFFEBB411);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Search state
  bool _isSearchMode = false;
  bool _isSearchingRemote = false;

  int _currentPage = 1;
  final int _pageSize = 25;

  int _searchPage = 1;
  bool _searchHasMore = true;

  // Data
  List<Coin> coins = []; // paged All Coins
  List<Coin> recentCoins = []; // Recently Searched
  List<Coin> _searchResults = []; // search results

  static const String _baseUrl = "https://rwa-f1623a22e3ed.herokuapp.com/api";

  // We’ll use server-side search with the `filter` param
  static const String SEARCH_ENDPOINT_MODE = "remote_only";

  String _remoteSearchUri(String q, int page, int size) {
    return Uri.parse("$_baseUrl/currencies")
        .replace(
          queryParameters: {
            'page': '$page',
            'size': '$size',
            'filter': q, // <— search term
            'category': '',
            'sortBy': '',
            'order': '',
          },
        )
        .toString();
  }

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    fetchCoins(page: _currentPage);
    _loadRecentCoins();

    _scrollController.addListener(() {
      final nearBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100;

      if (!nearBottom) return;

      // Infinite scroll for All Coins
      if (!_isSearchMode && !_isLoadingMore && _hasMore) {
        _loadMoreCoins();
      }

      // Infinite scroll for search
      if (_isSearchMode && _searchHasMore && !_isSearchingRemote) {
        _searchPage++;
        _performRemoteSearch(_searchController.text, append: true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentCoins() async {
    final prefs = await SharedPreferences.getInstance();

    // migrate old key
    final old = prefs.getStringList('recent_coins') ?? [];
    final now = prefs.getStringList('recent_searches') ?? [];
    if (old.isNotEmpty && now.isEmpty) {
      await prefs.setStringList('recent_searches', old);
      await prefs.remove('recent_coins');
    }

    final raw = prefs.getStringList('recent_searches') ?? [];
    setState(() {
      recentCoins = raw.map((e) => Coin.fromJson(json.decode(e))).toList();
    });
  }

  Future<void> _saveRecentCoin(Coin coin) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('recent_searches') ?? [];

    jsonList.removeWhere((e) => Coin.fromJson(json.decode(e)).id == coin.id);
    jsonList.insert(0, json.encode(coin.toJson()));
    if (jsonList.length > 5) jsonList.removeLast();

    await prefs.setStringList('recent_searches', jsonList);
    _loadRecentCoins();
  }

  Future<void> fetchCoins({int page = 1, bool append = false}) async {
    try {
      final uri = Uri.parse("$_baseUrl/currencies?page=$page&size=$_pageSize");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final parsed = CurrenciesResponse.fromJson(jsonDecode(response.body));
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
      if (!mounted) return;
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

  // ============ SEARCH ============

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = value.trim();
      if (q.isEmpty) {
        setState(() {
          _isSearchMode = false;
          _searchResults.clear();
          _searchPage = 1;
          _searchHasMore = true;
        });
        return;
      }

      setState(() => _isSearchMode = true);

      // remote_only mode
      await _performRemoteSearch(q, append: false);
    });
  }

  Future<void> _performRemoteSearch(String q, {required bool append}) async {
    try {
      setState(() => _isSearchingRemote = true);
      if (!append) {
        _searchPage = 1;
        _searchHasMore = true;
      }

      final url = _remoteSearchUri(q, _searchPage, _pageSize);
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) {
        setState(() => _isSearchingRemote = false);
        return;
      }

      final parsed = CurrenciesResponse.fromJson(jsonDecode(res.body));
      setState(() {
        if (append) {
          _searchResults.addAll(parsed.currencies);
        } else {
          _searchResults = parsed.currencies;
        }
        _searchHasMore = parsed.currencies.length == _pageSize;
        _isSearchingRemote = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearchingRemote = false);
    }
  }

  // ============ UI ============

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  onChanged: _onQueryChanged,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _brandYellow,
                  ),
                  cursorColor: _brandYellow,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon:
                        _isSearchMode
                            ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _isSearchMode = false;
                                  _isSearchingRemote = false;
                                  _searchResults.clear();
                                });
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
              ? Center(child: CircularProgressIndicator(color: _brandYellow))
              : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recentCoins.isNotEmpty && !_isSearchMode) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          "Recently Searched",
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
                              onTap: () => _openCoin(coin),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    _coinImage(coin.image, size: 24),
                                    const SizedBox(width: 6),
                                    Text(
                                      coin.symbol.toUpperCase(),
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // SEARCH MODE
                    if (_isSearchMode) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Results for "${_searchController.text.trim()}"',
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis, // prevent overflow
                                softWrap: false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isSearchingRemote)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _brandYellow,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_searchResults.isEmpty && _isSearchingRemote)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _brandYellow,
                            ),
                          ),
                        ),
                      if (_searchResults.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildCoinsContainer(theme, _searchResults),
                        ),
                      if (_isSearchMode &&
                          _isSearchingRemote &&
                          _searchResults.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _brandYellow,
                            ),
                          ),
                        ),
                      if (_isSearchMode &&
                          !_isSearchingRemote &&
                          _searchResults.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: Text(
                            "No results found.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],

                    // ALL COINS (when not searching)
                    if (!_isSearchMode && coins.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          "All Coins",
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildCoinsContainer(theme, coins),
                      ),
                    ],
                    if (!_isSearchMode && _isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(color: _brandYellow),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildCoinsContainer(ThemeData theme, List<Coin> list) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder:
            (_, __) => Divider(
              height: 0.5,
              color: theme.dividerColor.withAlpha((0.2 * 255).round()),
            ),
        itemBuilder: (_, i) => _buildCoinTile(list[i], theme),
      ),
    );
  }

  Widget _buildCoinTile(Coin coin, ThemeData theme) {
    final isUp = coin.priceChange24h >= 0;
    final changeColor =
        isUp ? const Color(0xFF16C784) : const Color(0xFFFF3B30);
    final icon = isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down;

    return InkWell(
      onTap: () => _openCoin(coin),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _coinImage(coin.image, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Short symbol line
                  Text(
                    coin.symbol.toUpperCase(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Name (may be long)
                  Text(
                    coin.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // prevent row overflow
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
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

  // Safe image builder with fallback to avatar/icon
  Widget _coinImage(String? url, {double size = 34}) {
    final safe = _normalizeImageUrl(url);
    if (safe == null) {
      // Fallback avatar with a generic icon
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x11000000),
        ),
        child: const Icon(Icons.broken_image, size: 16, color: Colors.grey),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        safe,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x11000000),
            ),
            child: const Icon(Icons.broken_image, size: 16, color: Colors.grey),
          );
        },
      ),
    );
  }

  // Returns a usable http/https URL or null if invalid/empty/relative
  String? _normalizeImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final s = raw.trim();
    // Only allow http/https; relative like "missing_large.png" should fallback
    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    // Occasionally APIs return "data:image/..." or other unsupported schemes; ignore.
    return null;
  }

  void _openCoin(Coin coin) {
    _saveRecentCoin(coin);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoinDetailScreen(coin: coin.id, coindetils: coin),
      ),
    );
  }
}
