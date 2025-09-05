import 'dart:convert';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rwa_app/screens/add_portfolio_transaction_screen.dart';
import 'package:rwa_app/screens/coming_soon.dart';
import 'package:rwa_app/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/screens/add_coin_to_portfolio.dart';
import 'package:rwa_app/screens/chat_screen.dart';
import 'package:rwa_app/screens/profile_screen.dart';
import 'package:rwa_app/screens/protfilio_coin_detail_screen.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  // ===== Logging =====
  static const bool kLog = true; // toggle logs on/off here
  void _log(String tag, Object msg) {
    if (!kLog) return;
    debugPrint('[Portfolio][$tag][${DateTime.now().toIso8601String()}] $msg');
  }

  String _short(Object? s, {int max = 400}) {
    final str = s?.toString() ?? '';
    return str.length > max ? '${str.substring(0, max)}…(${str.length})' : str;
  }

  // ===== State =====
  bool _isLoading = true;
  List<dynamic> _coins = [];
  double _totalAmount = 0.0;
  double _totalReturn = 0.0;
  double _totalPercentage = 0.0;
  String? _userName;

  // ---- helpers ----
  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0.0;
  }

  String _asString(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    return v.toString();
  }

  String? _coinId(Map<String, dynamic> coin) {
    final id = coin['_id'] ?? coin['id'] ?? coin['tokenId'];
    return id?.toString();
  }

  String _coinKey(Map<String, dynamic> coin) {
    return _coinId(coin) ??
        '${coin['symbol'] ?? ''}|${coin['name'] ?? ''}|${coin['image'] ?? ''}';
  }

  @override
  void initState() {
    super.initState();
    _log('initState', 'enter');
    fetchPortfolio();
  }

  // ⚠️ removed to avoid racing re-fetches
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   fetchPortfolio();
  // }

  Future<void> fetchPortfolio() async {
    _log('fetchPortfolio', 'start');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final userName = prefs.getString('name');
      _log(
        'fetchPortfolio',
        'token.isEmpty=${token.isEmpty} userName=$userName',
      );

      if (token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _coins = [];
          _totalAmount = 0.0;
          _totalReturn = 0.0;
          _totalPercentage = 0.0;
          _userName = userName;
          _isLoading = false;
        });
        _log('fetchPortfolio', 'no token -> show empty/login state');
        return;
      }

      final uri = Uri.parse(
        'https://rwa-f1623a22e3ed.herokuapp.com/api/user/token/portfolio',
      );
      _log('fetchPortfolio', 'GET $uri');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      _log('fetchPortfolio', 'status=${response.statusCode}');
      _log('fetchPortfolio', 'body=${_short(response.body)}');

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final coinsRaw =
            data['portfolioToken'] ?? data['portfolioTokens'] ?? [];
        final List<dynamic> coins = (coinsRaw is List) ? coinsRaw : [];
        _log('fetchPortfolio', 'coins.length=${coins.length}');
        _log(
          'fetchPortfolio',
          'totals raw: amount=${data['totalAmount']}(${data['totalAmount']?.runtimeType}), '
              'return=${data['totalReturn']}(${data['totalReturn']?.runtimeType}), '
              'perc=${data['totalPercentage']}(${data['totalPercentage']?.runtimeType})',
        );

        if (!mounted) return;
        setState(() {
          _coins = coins;
          _totalAmount = _asDouble(data['totalAmount']);
          _totalReturn = _asDouble(data['totalReturn']);
          _totalPercentage = _asDouble(data['totalPercentage']);
          _userName = userName;
          _isLoading = false;
        });
        _log(
          'fetchPortfolio',
          'setState done: coins=${_coins.length} amount=$_totalAmount return=$_totalReturn perc=$_totalPercentage',
        );
      } else {
        if (!mounted) return;
        setState(() {
          _coins = [];
          _userName = userName;
          _isLoading = false;
        });
        _log('fetchPortfolio', 'non-200 -> show empty state');
      }
    } catch (e, st) {
      _log('fetchPortfolio', 'ERROR: $e\n$st');
      if (!mounted) return;
      setState(() {
        _coins = [];
        _userName = null;
        _isLoading = false;
      });
    }
  }

  /// Return true on success, false otherwise.
  Future<bool> deleteCoinFromPortfolio(String coinId) async {
    _log('deleteCoin', 'start coinId=$coinId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final uri = Uri.parse(
        'https://rwa-f1623a22e3ed.herokuapp.com/api/user/token/remove/portfolio/$coinId',
      );
      _log('deleteCoin', 'DELETE $uri');
      final response = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      _log(
        'deleteCoin',
        'status=${response.statusCode} body=${_short(response.body)}',
      );

      if (response.statusCode == 200) {
        _log('deleteCoin', 'server OK');
        return true;
      } else {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete coin.', style: GoogleFonts.inter()),
          ),
        );
        return false;
      }
    } catch (e, st) {
      _log('deleteCoin', 'ERROR: $e\n$st');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting coin: $e', style: GoogleFonts.inter()),
        ),
      );
      return false;
    }
  }

  Future<bool> _confirmDeleteDialog(String symbol) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Remove from Portfolio'),
                content: Text(
                  'Are you sure you want to remove $symbol from your portfolio?',
                  style: GoogleFonts.inter(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<bool> _handleDeleteFlow(Map<String, dynamic> coin) async {
    final id = _coinId(coin);
    final symbol = _asString(coin['symbol']).toUpperCase();
    if (id == null) {
      _log('deleteFlow', 'NO ID for coin=$symbol');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not determine coin id.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      return false;
    }

    final confirm = await _confirmDeleteDialog(symbol);
    if (!confirm) {
      _log('deleteFlow', 'user canceled');
      return false;
    }

    final ok = await deleteCoinFromPortfolio(id);
    if (ok) {
      _log('deleteFlow', 'delete success -> refreshing portfolio');
      if (!mounted) return true;
      setState(() => _isLoading = true);
      await fetchPortfolio();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$symbol removed.', style: GoogleFonts.inter())),
      );
      return true;
    } else {
      _log('deleteFlow', 'delete failed');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _log(
      'build',
      'isLoading=$_isLoading coins=${_coins.length} userName=$_userName',
    );
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        toolbarHeight: 50,
        titleSpacing: 16,
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
              (_userName != null && _userName!.isNotEmpty)
                  ? "Hi, ${_userName!.split(' ').first}"
                  : "Portfolio",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/profile_outline.svg',
              width: 30,
              color: theme.iconTheme.color,
            ),
            onPressed: () {
              _log('nav', 'to ProfileScreen');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFEBB411)),
              )
              : _coins.isEmpty
              ? _buildEmptyState(theme)
              : _buildPortfolioContent(context, theme),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFEBB411),
        shape: const CircleBorder(),
        onPressed: () {
          _log('fab', 'ComingSoon tapped');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ComingSoonScreen()),
          );
        },
        child: SvgPicture.asset(
          'assets/bot_light.svg',
          width: 40,
          height: 40,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    _log('ui', 'render _buildEmptyState');
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final isLoggedIn =
            snapshot.hasData &&
            (snapshot.data?.getString('token')?.isNotEmpty ?? false);

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/rwapros/logo.png', height: 260),
              const SizedBox(height: 20),
              Text(
                isLoggedIn
                    ? "Almost there!\nJust a few steps left"
                    : "Welcome!\nPlease log in to track your portfolio",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  isLoggedIn
                      ? "Add your first coin to start tracking your assets."
                      : "Sign in to add, manage, and track your crypto portfolio easily.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: theme.hintColor,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (isLoggedIn) {
                        _log(
                          'nav',
                          'to AddCoinToPortfolioScreen (empty state button)',
                        );
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddCoinToPortfolioScreen(),
                          ),
                        ).then((result) async {
                          _log(
                            'nav',
                            'returned from Add screen, result=$result',
                          );
                          if (!mounted) return;
                          setState(() => _isLoading = true);
                          await fetchPortfolio();
                        });
                      } else {
                        _log('nav', 'to OnboardingScreen');
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OnboardingScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEBB411),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isLoggedIn ? "Add Coin" : "Login",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortfolioContent(BuildContext context, ThemeData theme) {
    _log('ui', 'render _buildPortfolioContent coins=${_coins.length}');
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _buildWalletSummaryCard(theme),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "My Portfolio",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                ),
              ),
              InkWell(
                onTap: () async {
                  _log('nav', 'to AddCoinToPortfolioScreen (header +Add Coin)');
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddCoinToPortfolioScreen(),
                    ),
                  );
                  _log('nav', 'returned from Add screen, result=$result');
                  if (result == true) {
                    if (!mounted) return;
                    setState(() => _isLoading = true);
                    await fetchPortfolio();
                  }
                },
                child: Text(
                  "+Add Coin",
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEBB411),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._coins
            .map(
              (coin) =>
                  _buildCoinRowWithDelete(context, Theme.of(context), coin),
            )
            .toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  // Dismissible + tile + delete/add overlays
  Widget _buildCoinRowWithDelete(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> coin,
  ) {
    final key = ValueKey(_coinKey(coin));
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart, // swipe right -> left to delete
      background: _buildDeleteBackground(context),
      confirmDismiss: (_) async {
        return await _handleDeleteFlow(coin);
      },
      child: _buildCoinTile(context, theme, coin),
    );
  }

  Widget _buildDeleteBackground(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.delete_outline, color: Colors.white),
          const SizedBox(width: 6),
          Text('Remove', style: GoogleFonts.inter(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildWalletSummaryCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      height: 146,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
          width: 0.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total Wallet Balance",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 6),
          Text(
            "\$${_totalAmount.toStringAsFixed(2)}",
            style: GoogleFonts.inter(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                "Profit/Loss",
                style: GoogleFonts.inter(fontSize: 12, color: theme.hintColor),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    "\$${_totalReturn.toStringAsFixed(2)}",
                    style: GoogleFonts.inter(
                      color: _totalReturn >= 0 ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _totalReturn >= 0
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: _totalReturn >= 0 ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  Text(
                    "${_totalPercentage.abs().toStringAsFixed(2)}%",
                    style: GoogleFonts.inter(
                      color: _totalReturn >= 0 ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinTile(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> coin,
  ) {
    final double change = _asDouble(coin['price_change_percentage_24h']);
    final Color changeColor = change >= 0 ? Colors.green : Colors.red;
    final IconData changeIcon =
        change >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down;

    final String symbol = _asString(coin['symbol']).toUpperCase();
    final String name = _asString(coin['name']);
    final String image = _asString(coin['image']);
    final double currentPrice = _asDouble(coin['currentPrice']);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onLongPress: () async {
            // Long-press also opens delete flow
            await _handleDeleteFlow(coin);
          },
          onTap: () {
            _log('nav', 'to ProfilioCoinDetailScreen coin=$symbol');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ProfilioCoinDetailScreen(
                      coin: coin,
                      trend: const [12.1, 12.3, 12.6, 12.5, 12.8, 13.2, 13.57],
                    ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Image.network(
                  image,
                  width: 36,
                  height: 36,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "\$${currentPrice.toStringAsFixed(2)}",
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      symbol,
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(changeIcon, color: changeColor, size: 18),
                        const SizedBox(width: 2),
                        Text(
                          "${change.abs().toStringAsFixed(2)}%",
                          style: GoogleFonts.inter(
                            color: changeColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Add transaction floating button (existing)
        Positioned(
          top: -10,
          right: 26,
          child: GestureDetector(
            onTap: () async {
              _log('nav', 'to AddPortfolioTransactionScreen coin=$symbol');
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPortfolioTransactionScreen(coin: coin),
                ),
              );
              _log('nav', 'returned from AddTransaction, result=$result');
              if (result == true) {
                await fetchPortfolio();
              }
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFEBB411),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ),

        // NEW: quick delete floating button (trash)
        Positioned(
          top: -10,
          left: 26,
          child: GestureDetector(
            onTap: () async {
              await _handleDeleteFlow(coin);
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
