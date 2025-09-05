import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/models/coin_model.dart';
import 'package:rwa_app/screens/coin_detail_widget/build_appbar_widget.dart';
import 'package:rwa_app/screens/coin_detail_widget/build_skeleton_appbar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rwa_app/screens/coin_detail_widget/watchlist_mixin.dart';
import 'package:flutter_html/flutter_html.dart';

// NEW: navigate to reviewer profile
import 'package:rwa_app/screens/profile/new_profile.dart';

/// READ-ONLY star row that rounds to nearest 0.5 and shows half stars accurately.
class StarDisplay extends StatelessWidget {
  final double rating; // e.g., 3.5
  final double size;
  const StarDisplay({super.key, required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final halfSteps = (rating * 2).round();
    final full = halfSteps ~/ 2;
    final hasHalf = halfSteps % 2 == 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full)
          return Icon(Icons.star, size: size, color: const Color(0xFFEBB411));
        if (i == full && hasHalf)
          return Icon(
            Icons.star_half,
            size: size,
            color: const Color(0xFFEBB411),
          );
        return Icon(
          Icons.star_border,
          size: size,
          color: const Color(0xFFEBB411),
        );
      }),
    );
  }
}

/// INTERACTIVE half-star selector: tap left half = .5, right half = full.
class HalfStarSelector extends StatelessWidget {
  final double value; // current value, supports halves
  final ValueChanged<double> onChanged;
  final double size;
  const HalfStarSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final halfSteps = (value * 2).round();
    final full = halfSteps ~/ 2;
    final hasHalf = halfSteps % 2 == 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final icon = () {
          if (index < full) return Icons.star;
          if (index == full && hasHalf) return Icons.star_half;
          return Icons.star_border;
        }();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final isLeftHalf = details.localPosition.dx <= (size / 2);
            final picked = index + (isLeftHalf ? 0.5 : 1.0);
            onChanged(picked.clamp(0.5, 5.0));
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size, color: const Color(0xFFEBB411)),
          ),
        );
      }),
    );
  }
}

class CoinDetailScreen extends StatefulWidget {
  final Coin coindetils;
  final String coin;

  const CoinDetailScreen({
    super.key,
    required this.coin,
    required this.coindetils,
  });

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen>
    with WatchlistMixin<CoinDetailScreen> {
  bool isLoading = true;
  Map<String, dynamic>? coin;
  List<double> trend = [];

  bool _watchlistChanged = false;

  double _currentRating = 0;
  double? averageRating;
  bool _isModalSubmitting = false;

  List<dynamic> expertReviews = [];

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _expertKey = GlobalKey();
  final GlobalKey _linksKey = GlobalKey();
  final GlobalKey _descriptionKey = GlobalKey();

  bool _isExpanded = false;

  int _selectedTab = 0; // For tab highlight
  int totalRating = 0;
  int? rank;

  bool _isHtmlExpanded = false;
  String _truncatedHtml = '';
  String _fullHtml = '';

  // NEW: persist/show user's own rating locally (prevents "disappearing")
  double? _myRating;

  @override
  void initState() {
    super.initState();
    _fetchCoinDetails();
    _loadMyRatingLocal(); // load user's existing rating if any
    checkIfFavorite(widget.coin, (fav, loading) {
      setState(() {
        isFavorite = fav;
        isFavoriteLoading = loading;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ======== Local cache for user's rating ========
  Future<void> _saveMyRatingLocal(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final mapStr = prefs.getString('my_ratings');
    final Map<String, dynamic> map =
        mapStr != null ? Map<String, dynamic>.from(jsonDecode(mapStr)) : {};
    map[widget.coindetils.id] = value;
    await prefs.setString('my_ratings', jsonEncode(map));
  }

  Future<void> _loadMyRatingLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final mapStr = prefs.getString('my_ratings');
    if (mapStr == null) return;
    final map = Map<String, dynamic>.from(jsonDecode(mapStr));
    final val = map[widget.coindetils.id];
    if (val is num) {
      setState(() {
        _myRating = val.toDouble();
        _currentRating = _myRating!;
      });
    }
  }
  // ==============================================

  Widget _buildTabBar(ThemeData theme) {
    final List<String> labels = ["About", "Links", "Description", "Reviews"];

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            color: theme.dividerColor.withOpacity(0.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(labels.length, (index) {
              final isSelected = _selectedTab == index;
              return GestureDetector(
                onTap: () => _onTabPressed(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[index],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color:
                            isSelected
                                ? const Color(0xFFEBB411)
                                : theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: 24,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFFEBB411)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  void _onTabPressed(int index) {
    if (isLoading) return;

    setState(() {
      _selectedTab = index;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(index);
      });
    });
  }

  void _scrollToSection(int index, [int retry = 0]) {
    final keys = [_aboutKey, _linksKey, _descriptionKey, _expertKey];

    if (index < 0 || index >= keys.length) return;

    final targetKey = keys[index];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = targetKey.currentContext;

      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0,
        );
      } else if (retry < 10) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _scrollToSection(index, retry + 1);
        });
      }
    });
  }

  String _truncateHtmlRaw(String html, int maxChars) {
    if (html.length <= maxChars) return html;
    return html.substring(0, maxChars).trim() + '...';
  }

  Future<void> _fetchCoinDetails() async {
    final detailUrl = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/currencies/rwa/coin/${widget.coin}',
    );

    final chartUrl = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/currencies/rwa/graph/coinOHLC/${widget.coin}',
    );

    try {
      final detailRes = await http.get(detailUrl);
      final chartRes = await http.get(chartUrl);

      if (detailRes.statusCode == 200 && chartRes.statusCode == 200) {
        final detailJson = json.decode(detailRes.body);
        final chartJson = json.decode(chartRes.body);

        final coinData = detailJson['detail'];
        final averageRatingRaw = detailJson['rating'];
        rank = detailJson['rank'];
        final average =
            (averageRatingRaw is num)
                ? averageRatingRaw.toDouble()
                : double.tryParse(averageRatingRaw.toString()) ?? 0;

        final List<dynamic> chartRaw = chartJson['graphData'];
        final List<double> closePrices =
            chartRaw.map((e) => (e[4] as num).toDouble()).toList();

        setState(() {
          coin = coinData;
          trend = closePrices;
          averageRating = average;
          expertReviews = detailJson['expertReview'] ?? [];
          totalRating = detailJson['totalRating'] ?? 0;
          rank = detailJson['rank'];
          isLoading = false;
        });

        _fullHtml = coinData['description']?['en'] ?? '';
        _truncatedHtml = _truncateHtmlRaw(_fullHtml, 300);
      } else {
        // ignore: avoid_print
        print('❌ Failed to fetch details or chart');
        setState(() => isLoading = false);
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Exception in _fetchCoinDetails: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _shareCoin() async {
    if (coin == null) return;
    final id = coin?['id'];

    final name = coin?['name'];
    final symbol = coin?['symbol']?.toUpperCase();
    final price = coin?['market_data']['current_price']['usd'];
    final website = 'https://rwapros.com/tokendetails/$id';

    final message =
        'Check out $name ($symbol)!\n'
        'Price: \$$price\n'
        'Learn more: $website';

    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEverythingLoading = isLoading || isFavoriteLoading;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child:
            isEverythingLoading
                ? Column(
                  children: [
                    SkeletonAppBarWidget(theme: theme),
                    const SizedBox(height: 8),
                    Expanded(child: _buildSkeletonBody(theme)),
                  ],
                )
                : Column(
                  children: [
                    buildAppBar(
                      theme: theme,
                      context: context,
                      onBack:
                          () => Navigator.pop(
                            context,
                            _watchlistChanged ? 'refresh' : null,
                          ),
                      onShare: _shareCoin,
                      onToggleFavorite: () {
                        toggleFavorite(widget.coin, context, (fav, changed) {
                          setState(() {
                            isFavorite = fav;
                            _watchlistChanged = changed;
                          });
                        });
                      },
                      isFavorite: isFavorite,
                      isFavoriteLoading: isFavoriteLoading,
                      watchlistChanged: _watchlistChanged,
                      imageUrl: widget.coindetils.image,
                      symbol: widget.coindetils.symbol,
                      name: widget.coindetils.name,
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _buildBody(theme)),
                  ],
                ),
      ),
    );
  }

  Widget _buildSkeletonBody(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[500]! : Colors.grey[100]!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(6, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: index == 1 ? 200 : 80,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final chartData = List.generate(
      trend.length,
      (i) => FlSpot(i.toDouble(), trend[i]),
    );
    final double minPrice =
        trend.isEmpty ? 0 : trend.reduce((a, b) => a < b ? a : b).toDouble();
    final double maxPrice =
        trend.isEmpty ? 0 : trend.reduce((a, b) => a > b ? a : b).toDouble();

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPriceSection(theme),
          const SizedBox(height: 12),
          _buildChartSection(theme, chartData, minPrice, maxPrice),
          const SizedBox(height: 16),
          _buildTabBar(theme),
          const SizedBox(height: 16),

          // [0] About
          Container(
            key: _aboutKey,
            child: Builder(builder: (context) => _buildOverviewSection(theme)),
          ),
          const SizedBox(height: 24),

          // [1] Links
          Container(
            key: _linksKey,
            child: Builder(builder: (context) => _buildLinksSection(theme)),
          ),
          const SizedBox(height: 24),

          // [2] Description
          Container(
            key: _descriptionKey,
            child: Builder(builder: (context) => _buildDescSection(theme)),
          ),
          const SizedBox(height: 24),

          // [3] Reviews
          Container(
            key: _expertKey,
            child: Builder(
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:
                      expertReviews.isNotEmpty
                          ? _buildExpertSection(theme)
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Expert's Advice",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No expert reviews yet.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPriceSection(ThemeData theme) {
    final price = (coin?['market_data']['current_price']['usd'] ?? 0) as num;
    final change =
        (coin?['market_data']['price_change_percentage_24h'] ?? 0) as num;
    final isUp = change >= 0;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price and Change
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${price.toStringAsFixed(4)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: isUp ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    Text(
                      '${change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: isUp ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Rating Section + tooltip + (NEW) show "Your rating"
          GestureDetector(
            onTap: () {
              _showRatingDialog(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      averageRating != null
                          ? averageRating!.toStringAsFixed(1)
                          : '--',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.star, color: Color(0xFFEBB411), size: 18),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalRating review${totalRating == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Colors.grey[400] : const Color(0xFF6B6B6B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Tap to rate this coin',
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatYAxisValue(double value) {
    if (value >= 1e12) return '${(value / 1e12).toStringAsFixed(2)}T';
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(2)}K';
    return value.toStringAsFixed(2);
  }

  void _showRatingDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to rate this coin.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Reset draft rating to user's saved rating (or 0 if first-time)
    setState(() => _currentRating = _myRating ?? 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => StatefulBuilder(
            builder: (context, setModalState) {
              final double display = _currentRating; // 0 => empty stars

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rate ${widget.coindetils.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _isModalSubmitting
                        ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (_) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.star_border,
                                  size: 36,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        )
                        : Column(
                          children: [
                            HalfStarSelector(
                              value: display, // <-- no default 2.5
                              onChanged: (v) {
                                setState(() => _currentRating = v);
                                setModalState(() {});
                              },
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              display == 0
                                  ? 'Tap stars to rate'
                                  : 'Your rating: ${display.toStringAsFixed(1)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),

                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed:
                          _isModalSubmitting
                              ? null
                              : () {
                                setState(() => _isModalSubmitting = true);
                                setModalState(() {});
                                _submitRating(context).then((_) {
                                  setState(() => _isModalSubmitting = false);
                                });
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEBB411),
                        minimumSize: const Size.fromHeight(45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isModalSubmitting
                              ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2.5,
                                ),
                              )
                              : const Text(
                                'Submit Rating',
                                style: TextStyle(color: Colors.white),
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Future<void> _submitRating(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to submit a rating.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      Navigator.pop(context); // Close modal if not logged in
      return;
    }

    // If unchanged, don't resubmit
    if (_myRating != null &&
        (_currentRating.toStringAsFixed(1) == _myRating!.toStringAsFixed(1))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your rating is already saved.')),
        );
      }
      Navigator.pop(context);
      return;
    }

    final coinId = widget.coindetils.id;
    final url = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/user/token/add/rating/$coinId',
    );

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'value': _currentRating}); // supports halves

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? 'Thanks for rating!'
                  : 'Failed to submit rating',
            ),
          ),
        );
      }

      // Cache locally so it shows on reopen
      await _saveMyRatingLocal(_currentRating);
      setState(() => _myRating = _currentRating);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Exception during rating: $e');
    } finally {
      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchCoinDetails();
        Navigator.pop(context);
      }
    }
  }

  Widget _buildChartSection(
    ThemeData theme,
    List<FlSpot> chartData,
    double minPrice,
    double maxPrice,
  ) {
    // NEW: color reflects trend (green up, red down)
    final bool isUp =
        chartData.length >= 2 ? (chartData.last.y >= chartData.first.y) : true;
    final Color up = const Color(0xFF16C784);
    final Color down = const Color(0xFFE53935);
    final Color lineColor = isUp ? up : down;

    return SizedBox(
      height: 250,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: true),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _formatYAxisValue(value),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 8,
                  getTitlesWidget: (value, meta) {
                    if (value < 0 || value.toInt() >= trend.length) {
                      return const SizedBox.shrink();
                    }
                    final time = DateTime.now().subtract(
                      Duration(minutes: (trend.length - value.toInt()) * 30),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            minY: minPrice * 0.98,
            maxY: maxPrice * 1.02,
            lineBarsData: [
              LineChartBarData(
                spots: chartData,
                isCurved: true,
                // single-color gradient based on trend
                gradient: LinearGradient(
                  colors: [lineColor, lineColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [lineColor.withOpacity(0.20), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection(ThemeData theme) {
    if (coin == null || coin?['market_data'] == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            _buildOverviewRow('Rank', rank != null ? "No. $rank" : '--'),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'Market Cap',
              '\$${_formatValue(coin?['market_data']['market_cap']?['usd'])}',
            ),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'Market Dominance',
              _formatValue(
                coin?['market_data']?['market_cap_percentage']?['usd'],
              ),
            ),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'Circulating Supply',
              _formatValue(coin?['market_data']?['circulating_supply']),
            ),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'Max Supply',
              _formatValue(coin?['market_data']?['max_supply']),
            ),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'Total Supply',
              _formatValue(coin?['market_data']?['total_supply']),
            ),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'Total Volume',
              '\$${_formatValue(coin?['market_data']?['total_volume']?['usd'])}',
            ),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'Genesis Date',
              coin?['genesis_date']?.toString() ?? '--',
            ),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'All Time High',
              '\$${_formatValue(coin?['market_data']?['ath']?['usd'])}',
            ),
            const SizedBox(height: 10),
            _buildOverviewRow(
              'All Time Low',
              '\$${_formatValue(coin?['market_data']?['atl']?['usd'])}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewRow(String title1, String value1) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title1,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescSection(ThemeData theme) {
    if (_fullHtml.isEmpty) return const SizedBox.shrink();

    final htmlToRender = _isHtmlExpanded ? _fullHtml : _truncatedHtml;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Html(
            data: htmlToRender,
            style: {
              "body": Style(
                fontSize: FontSize(12),
                color:
                    theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                lineHeight: LineHeight(1.5),
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
            },
          ),
          GestureDetector(
            onTap: () {
              setState(() => _isHtmlExpanded = !_isHtmlExpanded);
            },
            child: const Text(
              'Read more',
              style: TextStyle(
                color: Color(0xFFEBB411),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertSection(ThemeData theme) {
    if (expertReviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Expert Reviews",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children:
                expertReviews.map((review) {
                  final ratingRaw = review['rating'] ?? 0;
                  final double rating =
                      (ratingRaw is num)
                          ? ratingRaw.toDouble()
                          : double.tryParse('$ratingRaw') ?? 0.0;
                  final value = review['value'] ?? '';
                  final username = review['userId']?['username'] ?? 'Unknown';
                  final userId = review['userId']?['_id'];
                  final date = DateTime.tryParse(review['createdAt'] ?? '');
                  final dateStr =
                      date != null
                          ? "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"
                          : "";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD5D5D5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Half-star accurate display
                        StarDisplay(rating: rating, size: 18),
                        const SizedBox(height: 8),
                        Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            if (userId != null) {
                              _showReviewerProfileSheet(userId, username);
                            }
                          },

                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[200],
                                child: Text(
                                  username.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFEBB411),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      dateStr,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLinksSection(ThemeData theme) {
    final homepage = _safeFirst(coin?['links']?['homepage']);
    final whitepaper = coin?['links']?['whitepaper'] ?? '';
    final twitter = coin?['links']?['twitter_screen_name'] ?? '';
    final explorer = _safeFirst(coin?['links']?['blockchain_site']);

    final links = [
      {'label': 'Website', 'url': homepage, 'icon': 'assets/website.png'},
      {
        'label': 'Whitepaper',
        'url': whitepaper,
        'icon': 'assets/whitepaper.png',
      },
      {'label': 'Explorer', 'url': explorer, 'icon': 'assets/explorer.png'},
      {
        'label': 'Twitter',
        'url': twitter.isNotEmpty ? 'https://twitter.com/$twitter' : '',
        'icon': 'assets/twitter.png',
      },
    ];

    final visibleLinks =
        links.where((link) => link['url']!.isNotEmpty).toList();

    if (visibleLinks.isEmpty) return const SizedBox.shrink();

    // 👉 Width for 3 buttons per row (with spacing ~12px)
    final double maxButtonWidth =
        (MediaQuery.of(context).size.width - 16 * 2 - 24) / 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Links',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                visibleLinks.map((link) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxButtonWidth),
                    child: GestureDetector(
                      onTap: () async {
                        final url = Uri.tryParse(link['url']!);
                        if (url != null) {
                          await launchUrl(url, mode: LaunchMode.inAppWebView);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not open ${link['url']}'),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              link['icon']!,
                              width: 18,
                              height: 18,
                              color: const Color(0xFFEBB411),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                link['label']!,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEBB411),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  String _safeFirst(dynamic listData) {
    if (listData is List && listData.isNotEmpty) {
      final first = listData.first;
      if (first is String &&
          first.trim().isNotEmpty &&
          first.startsWith('http')) {
        return first.trim();
      }
    }
    return '';
  }

  // --- Reviewer profile: fetch + cache (handles 200 and 304) ---
  Future<Map<String, dynamic>?> _fetchReviewerProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // optional; sent if present
      final url = Uri.parse(
        'https://rwa-f1623a22e3ed.herokuapp.com/api/admin/profile/$userId',
      );

      final res = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      // 200 => parse & cache
      if (res.statusCode == 200) {
        if (res.body.isNotEmpty) {
          final obj = jsonDecode(res.body);
          if (obj is Map &&
              obj['status'] == true &&
              obj['userProfile'] != null) {
            await prefs.setString(
              'reviewer_profile_$userId',
              jsonEncode(obj['userProfile']),
            );
            return Map<String, dynamic>.from(obj['userProfile']);
          }
        }
        return null;
      }

      // 304 => try cached body (some proxies return 304 without a body)
      if (res.statusCode == 304) {
        final cached = prefs.getString('reviewer_profile_$userId');
        if (cached != null) {
          return Map<String, dynamic>.from(jsonDecode(cached));
        }
      }

      // If server (unusually) returns JSON with 304, try parsing
      if (res.statusCode == 304 && res.body.isNotEmpty) {
        final obj = jsonDecode(res.body);
        if (obj is Map && obj['status'] == true && obj['userProfile'] != null) {
          await prefs.setString(
            'reviewer_profile_$userId',
            jsonEncode(obj['userProfile']),
          );
          return Map<String, dynamic>.from(obj['userProfile']);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ _fetchReviewerProfile error: $e');
    }
    return null;
  }

  // --- Open profile sheet ---
  void _showReviewerProfileSheet(String userId, String fallbackName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _fetchReviewerProfile(userId),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  // Shimmer skeleton while loading
                  return Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 6,
                          width: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(height: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(height: 14, color: Colors.grey),
                        const SizedBox(height: 8),
                        Container(height: 14, color: Colors.grey),
                      ],
                    ),
                  );
                }

                final p = snap.data;
                if (p == null) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 6,
                          width: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Reviewer profile',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Unable to load the reviewer profile right now. Please try again.',
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  );
                }

                final username = (p['username'] ?? fallbackName) as String;
                final email = (p['email'] ?? '') as String;
                final description = (p['description'] ?? '') as String;
                final links =
                    (p['link'] is List)
                        ? List<String>.from(p['link'])
                        : <String>[];
                final img = (p['profileImg'] ?? '') as String;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          height: 6,
                          width: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey[200],
                            backgroundImage:
                                img.isNotEmpty ? NetworkImage(img) : null,
                            child:
                                img.isEmpty
                                    ? Text(
                                      (username.isNotEmpty ? username[0] : '?')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFFEBB411),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  InkWell(
                                    onTap:
                                        () => launchUrl(
                                          Uri.parse('mailto:$email'),
                                        ),
                                    child: Text(
                                      email,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            decoration:
                                                TextDecoration.underline,
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (description.isNotEmpty) ...[
                        Text(
                          'About',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(description, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 12),
                      ],
                      if (links.isNotEmpty) ...[
                        Text(
                          'Links',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              links.map((u) {
                                return ActionChip(
                                  label: Text(
                                    Uri.tryParse(u)?.host ?? 'Open',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: () async {
                                    final uri = Uri.tryParse(u);
                                    if (uri != null) {
                                      final ok = await launchUrl(
                                        uri,
                                        mode: LaunchMode.inAppWebView,
                                      );
                                      if (!ok && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Could not open $u'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

String _formatValue(dynamic numVal) {
  if (numVal == null) return "--";
  final num number =
      (numVal is num) ? numVal : double.tryParse(numVal.toString()) ?? 0;
  if (number >= 1e12) return '${(number / 1e12).toStringAsFixed(2)}T';
  if (number >= 1e9) return '${(number / 1e9).toStringAsFixed(2)}B';
  if (number >= 1e6) return '${(number / 1e6).toStringAsFixed(2)}M';
  if (number >= 1e3) return '${(number / 1e3).toStringAsFixed(2)}K';
  return number.toStringAsFixed(2);
}
