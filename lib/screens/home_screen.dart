import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/api/api_service.dart';
import 'package:rwa_app/models/category_model.dart';
import 'package:rwa_app/models/coin_model.dart';
import 'package:rwa_app/screens/coin_search_screen.dart';
import 'package:rwa_app/screens/coins_table_widget.dart';
import 'package:rwa_app/screens/coming_soon.dart';
import 'package:rwa_app/screens/onboarding_screen.dart';
import 'package:rwa_app/screens/profile_screen.dart';
import 'package:rwa_app/widgets/stats_card_widget.dart';
import 'package:rwa_app/widgets/tabbar_section_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ==== LOGGING ====
  static const bool kEnableLogs = true;
  void _log(String msg) {
    if (!kEnableLogs) return;
    final ts = DateTime.now().toIso8601String();
    debugPrint('[HOME $ts] $msg');
  }

  // Small helpers to print list stats
  void _logList(String label, List<Coin> list) {
    if (!kEnableLogs) return;
    final n = list.length;
    final first = n > 0 ? list.first.id : '-';
    final last = n > 0 ? list.last.id : '-';
    _log('$label -> len=$n | first=$first | last=$last');
  }

  // ==== STATE ====
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  // All Coins (tab 0) paging
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;

  // Top Coins (tab 1) paging
  bool _topCoinsIsLoadingMore = false;
  bool _topCoinsHasMore = true;
  int _topCoinsPage = 1;

  // Categories (tab 5)
  bool _isCategoryLoading = false;

  int _selectedTabIndex = 0;
  final int _itemsPerPage = 25;

  List<Coin> allCoinsTab = [];
  List<Coin> topCoinsTab = [];
  List<Coin> watchlistTab = [];
  List<Coin> trendingTab = [];
  List<Coin> topGainersTab = [];

  List<Category> categories = [];
  List<Coin> selectedCategoryCoins = [];
  String? selectedCategoryName;

  double? marketCap, volume24h, marketCapChange;
  String? trendingCoinSymbol, trendingCoinDominance, trendingCoinImage;

  late TabController _tabController;

  bool _showLoginButton = false;
  double? treasuryValue;

  @override
  void initState() {
    super.initState();
    _log('initState()');
    _scrollController.addListener(_scrollListener);
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _log('TabController listener fired: index=${_tabController.index}');
        _onTabChanged(_tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _log(
        'addPostFrameCallback: fetchInitialData(index=${_tabController.index})',
      );
      fetchInitialData(_tabController.index);
    });
  }

  @override
  void dispose() {
    _log('dispose()');
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!(_selectedTabIndex == 0 || _selectedTabIndex == 1)) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final atBottom = position.pixels >= (position.maxScrollExtent - 100);
    final isAnyLoading =
        _isLoading ||
        (_selectedTabIndex == 0 ? _isLoadingMore : _topCoinsIsLoadingMore);
    final hasMore = _selectedTabIndex == 0 ? _hasMoreData : _topCoinsHasMore;

    _log(
      'scroll: tab=$_selectedTabIndex pixels=${position.pixels.toStringAsFixed(1)} '
      'max=${position.maxScrollExtent.toStringAsFixed(1)} '
      'viewport=${position.viewportDimension.toStringAsFixed(1)} '
      'atBottom=$atBottom isAnyLoading=$isAnyLoading hasMore=$hasMore',
    );

    if (atBottom && !isAnyLoading && hasMore) {
      _log('-> TRIGGER loadMore for active tab');
      _loadMoreCoinsForActiveTab();
    }
  }

  Future<void> fetchTreasuryData() async {
    _log('fetchTreasuryData() start');
    try {
      final url =
          'https://rwa-f1623a22e3ed.herokuapp.com/api/treasuryTokens/get/allTokens';
      final response = await http.get(Uri.parse(url));
      _log('fetchTreasuryData() HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          treasuryValue = (json['totalBalance'] as num?)?.toDouble() ?? 0.0;
        });
        _log('fetchTreasuryData() success totalBalance=$treasuryValue');
      } else {
        _log('fetchTreasuryData() non-200: body=${response.body}');
      }
    } catch (e) {
      _log('❌ fetchTreasuryData() error: $e');
    }
  }

  Future<void> fetchInitialData(int index) async {
    _log(
      'fetchInitialData(index=$index) START '
      '(page0=$_currentPage hasMore0=$_hasMoreData | page1=$_topCoinsPage hasMore1=$_topCoinsHasMore)',
    );
    setState(() => _isLoading = true);

    try {
      // Top strip stats
      final highlight = await _apiService.fetchHighlightData();
      final topTrend = await _apiService.fetchTopTrendingCoin();
      marketCap = (highlight['market_cap'] as num?)?.toDouble();
      volume24h = (highlight['volume_24h'] as num?)?.toDouble();
      marketCapChange =
          (highlight['market_cap_change_24h'] as num?)?.toDouble();
      trendingCoinSymbol = topTrend?['symbol']?.toUpperCase();
      trendingCoinDominance = ((topTrend?['market_cap_change_percentage_24h']
                      as num?)
                  ?.toDouble() ??
              0.0)
          .toStringAsFixed(2);
      trendingCoinImage = topTrend?['image'];
      _log(
        'highlight loaded: marketCap=$marketCap vol24h=$volume24h change=$marketCapChange',
      );

      switch (index) {
        case 0:
          _currentPage = 1;
          _hasMoreData = true;
          _log('Tab0 fetch page=$_currentPage size=$_itemsPerPage');
          allCoinsTab = await _apiService.fetchCoinsPaginated(
            page: _currentPage,
            size: _itemsPerPage,
          );
          _logList('Tab0 page=$_currentPage result', allCoinsTab);
          break;

        case 1:
          _topCoinsPage = 1;
          _topCoinsHasMore = true;
          _log('Tab1 fetch page=$_topCoinsPage size=$_itemsPerPage');
          topCoinsTab = await _apiService.fetchCoinsPaginated(
            page: _topCoinsPage,
            size: _itemsPerPage,
            // sort: 'market_cap_desc',
          );
          _logList('Tab1 page=$_topCoinsPage result', topCoinsTab);
          break;

        case 2:
          final loggedIn = await isUserLoggedIn();
          _showLoginButton = !loggedIn;
          _log('Tab2 watchlist: loggedIn=$loggedIn');
          watchlistTab = loggedIn ? await _apiService.fetchWatchlists() : [];
          _logList('Tab2 watchlist result', watchlistTab);
          break;

        case 3:
          _log('Tab3 trending fetch');
          trendingTab = await _apiService.fetchTrendingCoins();
          _logList('Tab3 trending result', trendingTab);
          break;

        case 4:
          _log('Tab4 topGainers fetch');
          topGainersTab = await _apiService.fetchTopGainers();
          _logList('Tab4 topGainers result', topGainersTab);
          break;

        case 5:
          _isCategoryLoading = true;
          _log('Tab5 categories fetch');
          categories = await _apiService.fetchCategories();
          _isCategoryLoading = false;
          _log('Tab5 categories count=${categories.length}');
          break;
      }
    } catch (e) {
      _log('❌ fetchInitialData error: $e');
    }

    await fetchTreasuryData();

    if (!mounted) return;
    setState(() => _isLoading = false);
    _log('fetchInitialData(index=$index) DONE');
  }

  List<Coin> get currentTabCoins {
    switch (_selectedTabIndex) {
      case 0:
        return allCoinsTab;
      case 1:
        return topCoinsTab;
      case 2:
        return watchlistTab;
      case 3:
        return trendingTab;
      case 4:
        return topGainersTab;
      default:
        return [];
    }
  }

  Future<void> _loadMoreCoinsForActiveTab() async {
    if (_selectedTabIndex == 0) {
      // All Coins
      setState(() => _isLoadingMore = true);
      try {
        final nextPage = _currentPage + 1;
        _log('Tab0 LOAD MORE -> requesting page=$nextPage size=$_itemsPerPage');
        final newCoins = await _apiService.fetchCoinsPaginated(
          page: nextPage,
          size: _itemsPerPage,
        );
        _log('Tab0 page=$nextPage rawLen=${newCoins.length}');
        if (newCoins.isEmpty) {
          _hasMoreData = false;
          _log('Tab0 page=$nextPage returned EMPTY -> hasMore=false');
        } else {
          final existingIds = allCoinsTab.map((e) => e.id).toSet();
          final filtered =
              newCoins.where((c) => !existingIds.contains(c.id)).toList();
          final dups = newCoins.length - filtered.length;
          _log(
            'Tab0 page=$nextPage filteredLen=${filtered.length} (dups=$dups)',
          );
          if (filtered.isEmpty && dups > 0) {
            _log(
              '⚠️ Tab0 page=$nextPage all items were duplicates -> API may be ignoring page param.',
            );
          }
          allCoinsTab.addAll(filtered);
          _currentPage = nextPage;
          _logList('Tab0 after-append (page=$_currentPage)', allCoinsTab);
        }
      } catch (e) {
        _log('❌ Tab0 loadMore error: $e');
      }
      if (mounted) setState(() => _isLoadingMore = false);
    } else if (_selectedTabIndex == 1) {
      // Top Coins
      setState(() => _topCoinsIsLoadingMore = true);
      try {
        final nextPage = _topCoinsPage + 1;
        _log('Tab1 LOAD MORE -> requesting page=$nextPage size=$_itemsPerPage');
        final newCoins = await _apiService.fetchCoinsPaginated(
          page: nextPage,
          size: _itemsPerPage,
          // sort: 'market_cap_desc',
        );
        _log('Tab1 page=$nextPage rawLen=${newCoins.length}');
        if (newCoins.isEmpty) {
          _topCoinsHasMore = false;
          _log('Tab1 page=$nextPage returned EMPTY -> hasMore=false');
        } else {
          final existingIds = topCoinsTab.map((e) => e.id).toSet();
          final filtered =
              newCoins.where((c) => !existingIds.contains(c.id)).toList();
          final dups = newCoins.length - filtered.length;
          _log(
            'Tab1 page=$nextPage filteredLen=${filtered.length} (dups=$dups)',
          );
          if (filtered.isEmpty && dups > 0) {
            _log(
              '⚠️ Tab1 page=$nextPage all items were duplicates -> API may be ignoring page param.',
            );
          }
          topCoinsTab.addAll(filtered);
          _topCoinsPage = nextPage;
          _logList('Tab1 after-append (page=$_topCoinsPage)', topCoinsTab);
        }
      } catch (e) {
        _log('❌ Tab1 loadMore error: $e');
      }
      if (mounted) setState(() => _topCoinsIsLoadingMore = false);
    }
  }

  Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = token != null && token.isNotEmpty;
      _log('isUserLoggedIn() -> $res');
      return res;
    } catch (e) {
      _log('❌ isUserLoggedIn() error: $e');
      return false;
    }
  }

  Future<void> _onTabChanged(int index) async {
    if (_selectedTabIndex == index) return;

    _log('_onTabChanged from=$_selectedTabIndex to=$index');
    setState(() => _selectedTabIndex = index);

    // If leaving Categories detail, reset selection
    if (index != 5 && selectedCategoryName != null) {
      _log('Leaving Tab5 detail -> reset selectedCategory');
      selectedCategoryName = null;
      selectedCategoryCoins = [];
    }

    await fetchInitialData(index);
  }

  String formatNumber(double? value) {
    if (value == null) return '...';
    if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)} T';
    if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)} B';
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)} M';
    if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(2)} K';
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardWidth = (MediaQuery.of(context).size.width - 24 - 6) / 4;

    // Compute start rank per active tab (only for paginated tabs)
    final int startRank =
        (_selectedTabIndex == 0
                ? (_currentPage - 1)
                : _selectedTabIndex == 1
                ? (_topCoinsPage - 1)
                : 0) *
            _itemsPerPage +
        1;

    final bool isBottomLoading =
        _selectedTabIndex == 0
            ? _isLoadingMore
            : _selectedTabIndex == 1
            ? _topCoinsIsLoadingMore
            : false;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: theme.appBarTheme.elevation,
          automaticallyImplyLeading: false,
          toolbarHeight: 60,
          title: Row(
            children: [
              Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/rwapros/logo-white.png'
                    : 'assets/rwapros/logo.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 8),
              Text(
                'RWA PROS',
                style: GoogleFonts.inter(
                  textStyle: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: SvgPicture.asset(
                'assets/search_outline.svg',
                width: 24,
                color: theme.iconTheme.color,
              ),
              onPressed: () {
                _log('Tap search -> CoinSearchScreen');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CoinSearchScreen()),
                );
              },
            ),
            IconButton(
              icon: SvgPicture.asset(
                'assets/profile_outline.svg',
                width: 30,
                color: theme.iconTheme.color,
              ),
              onPressed: () {
                _log('Tap profile -> ProfileScreen');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ],
        ),

        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Market Cap',
                      value: formatNumber(marketCap),
                      change:
                          marketCapChange != null
                              ? '${marketCapChange! >= 0 ? '+' : ''}${marketCapChange!.toStringAsFixed(1)}%'
                              : '',
                      changeColor:
                          marketCapChange == null
                              ? Colors.grey
                              : marketCapChange! >= 0
                              ? const Color.fromARGB(255, 11, 252, 63)
                              : Colors.red,
                      width: cardWidth,
                      isFirst: true,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: StatCard(
                      title: 'Volume',
                      value: formatNumber(volume24h),
                      change: '24H',
                      changeColor:
                          theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                      width: cardWidth,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: StatCard(
                      title: 'Condo Treasury',
                      value: formatNumber(treasuryValue),
                      change: 'View More',
                      changeColor:
                          theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                      width: cardWidth,
                      isLast: true,
                    ),
                  ),
                ],
              ),
            ),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12),
                    child: TabBarSection(
                      onTap: (i) {
                        _log('TabBarSection.onTap($i)');
                        _onTabChanged(i);
                      },
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFEBB411),
                        ),
                      )
                      : // ===== Categories Tab (index 5) =====
                      _selectedTabIndex == 5
                      ? _isCategoryLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFEBB411),
                            ),
                          )
                          : (selectedCategoryName != null)
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _log(
                                        'Category back pressed -> clear selection',
                                      );
                                      setState(() {
                                        selectedCategoryCoins = [];
                                        selectedCategoryName = null;
                                      });
                                    },
                                  ),
                                  Text(
                                    selectedCategoryName ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedCategoryCoins.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'No tokens found in this category.',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: CoinsTable(
                                    coins: selectedCategoryCoins,
                                    scrollController: _scrollController,
                                    onCoinTap: (coin) {
                                      _log(
                                        'Tap coin in category: id=${coin.id} symbol=${coin.symbol}',
                                      );
                                    },
                                    startRank: 1,
                                  ),
                                ),
                            ],
                          )
                          : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final images =
                                  category.topTokenImages.take(3).toList();

                              return GestureDetector(
                                onTap: () async {
                                  _log(
                                    'Category tap -> ${category.name} (${category.id})',
                                  );
                                  setState(() {
                                    _isCategoryLoading = true;
                                    selectedCategoryCoins = [];
                                    selectedCategoryName = category.name;
                                  });

                                  try {
                                    selectedCategoryCoins = await _apiService
                                        .fetchCoinsByCategory(category.id);
                                    _log(
                                      'Category "${category.name}" coins=${selectedCategoryCoins.length}',
                                    );
                                  } catch (e) {
                                    _log('❌ fetchCoinsByCategory error: $e');
                                  }
                                  if (!mounted) return;
                                  setState(() {
                                    _isCategoryLoading = false;
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        children:
                                            images.map((img) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: Image.network(
                                                    img,
                                                    width: 30,
                                                    height: 30,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category.name[0].toUpperCase() +
                                                  category.name.substring(1),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "${category.avg24hPercent.toStringAsFixed(2)}%",
                                              style: TextStyle(
                                                color:
                                                    category.avg24hPercent >= 0
                                                        ? Colors.green
                                                        : Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                      : // ===== Watchlist gate (index 2) =====
                      _selectedTabIndex == 2 && _showLoginButton
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 60,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Login to view your watchlist',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEBB411),
                                ),
                                onPressed: () {
                                  _log('Tap Login -> OnboardingScreen');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const OnboardingScreen(),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Login',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : // Watchlist empty state
                      currentTabCoins.isEmpty && _selectedTabIndex == 2
                      ? Center(
                        child: Text(
                          'No coin yet added',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      )
                      : // ===== Main coins lists (tabs 0/1/3/4/2 when logged in) =====
                      RefreshIndicator(
                        color: const Color(0xFFEBB411),
                        onRefresh: () async {
                          _log(
                            'RefreshIndicator.onRefresh tab=$_selectedTabIndex',
                          );
                          if (_selectedTabIndex == 0) {
                            _currentPage = 1;
                            _hasMoreData = true;
                          } else if (_selectedTabIndex == 1) {
                            _topCoinsPage = 1;
                            _topCoinsHasMore = true;
                          }
                          await fetchInitialData(_selectedTabIndex);
                        },
                        child: CoinsTable(
                          coins: currentTabCoins,
                          scrollController: _scrollController,
                          onCoinTap: (coin) {
                            _log(
                              'Tap coin: id=${coin.id} symbol=${coin.symbol}',
                            );
                          },
                          startRank: startRank,
                          isLoadingMore: isBottomLoading,
                        ),
                      ),
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _log('FAB -> ComingSoonScreen');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComingSoonScreen()),
            );
          },
          backgroundColor: const Color(0xFFEBB411),
          shape: const CircleBorder(),
          child: SvgPicture.asset(
            'assets/bot_light.svg',
            width: 40,
            height: 40,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
