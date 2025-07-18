import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/api/api_service.dart';
import 'package:rwa_app/models/category_model.dart';
import 'package:rwa_app/models/coin_model.dart';
import 'package:rwa_app/screens/chat_screen.dart';
import 'package:rwa_app/screens/coin_search_screen.dart';
import 'package:rwa_app/screens/coins_table_widget.dart';
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
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _isCategoryLoading = false;

  int _currentPage = 1;
  int _selectedTabIndex = 0;
  final int _itemsPerPage = 25;

  List<Coin> allCoins = [];
  List<Coin> displayedCoins = [];
  List<Coin> favCoin = [];
  List<Category> categories = [];
  List<Coin> selectedCategoryCoins = [];
  String? selectedCategoryName;

  double? marketCap, volume24h, marketCapChange;
  String? trendingCoinSymbol, trendingCoinDominance, trendingCoinImage;

  late TabController _tabController;

  bool _showLoginButton = false;
  bool _isWatchlistLoading = false;
  double? treasuryValue;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _onTabChanged(_tabController.index);
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => fetchInitialData(_tabController.index),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final isInfiniteTab = _selectedTabIndex == 0 || _selectedTabIndex == 1;

    final canLoadMore =
        isInfiniteTab &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMoreData;

    if (canLoadMore) _loadMoreCoins();
  }

  Future<void> fetchTreasuryData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://rwa-f1623a22e3ed.herokuapp.com/api/treasuryTokens/get/allTokens',
        ),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          treasuryValue = (json['totalBalance'] as num?)?.toDouble() ?? 0.0;
        });
      } else {
        print("❌ Failed to fetch treasury data: ${response.statusCode}");
      }
    } catch (e) {
      // print("❌ fetchTreasuryData error: $e");
    }
  }

  Future<void> fetchInitialData(int index) async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMoreData = true;
      allCoins = [];
      displayedCoins = [];
    });

    try {
      final highlight = await _apiService.fetchHighlightData();
      final topTrend = await _apiService.fetchTopTrendingCoin();

      await fetchTreasuryData();

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

      if (index == 2) {
        final loggedIn = await isUserLoggedIn();
        _showLoginButton = !loggedIn;

        if (!loggedIn) {
          favCoin = [];
        } else {
          _isWatchlistLoading = true;
          setState(() {});
          favCoin = await _apiService.fetchWatchlists();
          _isWatchlistLoading = false;
        }
        setState(() => _isLoading = false);
        return;
      }

      if (index == 3) {
        displayedCoins = await _apiService.fetchTrendingCoins();
      } else if (index == 5) {
        _isCategoryLoading = true;
        categories = await _apiService.fetchCategories();
        _isCategoryLoading = false;
      } else {
        allCoins = await _apiService.fetchCoinsPaginated(
          page: _currentPage,
          size: _itemsPerPage,
        );
        displayedCoins = List.from(allCoins);
      }
    } catch (e) {
      print("❌ fetchInitialData Error: $e");
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreCoins() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final newCoins = await _apiService.fetchCoinsPaginated(
        page: nextPage,
        size: _itemsPerPage,
      );

      if (newCoins.isEmpty) {
        _hasMoreData = false;
      } else {
        final existingIds = allCoins.map((e) => e.id).toSet();
        final filtered =
            newCoins.where((coin) => !existingIds.contains(coin.id)).toList();
        allCoins.addAll(filtered);
        if (_selectedTabIndex != 2) displayedCoins = List.from(allCoins);
        _currentPage = nextPage;
      }
    } catch (e) {
      print("❌ _loadMoreCoins Error: $e");
    }
    setState(() => _isLoadingMore = false);
  }

  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  Future<void> _onTabChanged(int index) async {
    if (_selectedTabIndex == index) return;

    setState(() {
      _selectedTabIndex = index;
      _isLoading = true;
      _showLoginButton = false;
      selectedCategoryCoins = [];
      selectedCategoryName = null;
    });

    try {
      switch (index) {
        case 0:
          _currentPage = 1;
          _hasMoreData = true;
          allCoins = await _apiService.fetchCoinsPaginated(
            page: _currentPage,
            size: _itemsPerPage,
          );
          displayedCoins = List.from(allCoins);
          break;
        case 1:
          displayedCoins = await _apiService.fetchCoinsPaginated();
          break;
        case 2:
          final loggedIn = await isUserLoggedIn();
          _showLoginButton = !loggedIn;
          favCoin = loggedIn ? await _apiService.fetchWatchlists() : [];
          break;
        case 3:
          displayedCoins = await _apiService.fetchTrendingCoins();
          break;
        case 4:
          displayedCoins = await _apiService.fetchTopGainers();
          break;
        case 5:
          _isCategoryLoading = true;
          setState(() {});
          categories = await _apiService.fetchCategories();
          _isCategoryLoading = false;
          break;
      }
    } catch (e) {
      print("❌ _onTabChanged Error: $e");
    }

    setState(() => _isLoading = false);
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
              Image.asset('assets/rwapros/logo.png', width: 40, height: 40),
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
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CoinSearchScreen()),
                  ),
            ),
            IconButton(
              icon: SvgPicture.asset(
                'assets/profile_outline.svg',
                width: 30,
                color: theme.iconTheme.color,
              ),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
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
                      changeColor: Colors.white,
                      width: cardWidth,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: StatCard(
                      title: 'Condo Treasury',
                      value: formatNumber(treasuryValue),
                      change: 'View More',
                      changeColor: Colors.white,
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
                    child: TabBarSection(onTap: _onTabChanged),
                  ),
                ),
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0087E0),
                        ),
                      )
                      : _selectedTabIndex == 5
                      ? _isCategoryLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF0087E0),
                            ),
                          )
                          : selectedCategoryCoins.isNotEmpty
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
                              Expanded(
                                child: CoinsTable(
                                  coins: selectedCategoryCoins,
                                  scrollController: _scrollController,
                                  onCoinTap: (coin) {},
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
                                  setState(() {
                                    _isCategoryLoading = true;
                                    selectedCategoryCoins = [];
                                    selectedCategoryName = category.name;
                                  });

                                  try {
                                    selectedCategoryCoins = await _apiService
                                        .fetchCoinsByCategory(category.id);
                                  } catch (e) {
                                    print("❌ fetchCoinsByCategory Error: $e");
                                  }
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
                                      // 3 images side by side
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
                                      // Title and 24h change below
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
                      : CoinsTable(
                        coins: displayedCoins,
                        scrollController: _scrollController,
                        onCoinTap: (coin) {},
                      ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
          backgroundColor: const Color(0xFF0087E0),
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
