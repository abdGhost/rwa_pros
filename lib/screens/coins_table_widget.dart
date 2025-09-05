import 'package:flutter/material.dart';
import 'package:rwa_app/models/coin_model.dart';
import 'package:rwa_app/screens/coin_details_screen.dart';

class CoinsTable extends StatefulWidget {
  final List<Coin> coins;
  final ScrollController? scrollController;
  final void Function(Coin)? onCoinTap;
  final int startRank;
  final bool isLoadingMore;

  const CoinsTable({
    super.key,
    required this.coins,
    this.scrollController,
    this.onCoinTap,
    this.startRank = 1,
    this.isLoadingMore = false,
  });

  @override
  State<CoinsTable> createState() => _CoinsTableState();
}

class _CoinsTableState extends State<CoinsTable> {
  String _sortBy = 'rank';
  bool _isAscending = true;

  void _onSort(String column) {
    setState(() {
      if (_sortBy == column) {
        _isAscending = !_isAscending;
      } else {
        _sortBy = column;
        _isAscending = true;
      }
    });
  }

  List<Coin> _sortedView(List<Coin> input) {
    var list = List<Coin>.from(input);

    int cmp(Coin a, Coin b) {
      switch (_sortBy) {
        case 'price':
          return (a.currentPrice).compareTo(b.currentPrice);
        case 'marketCap':
          return (a.marketCap ?? 0).compareTo(b.marketCap ?? 0);
        case 'name':
          return (a.name).toLowerCase().compareTo((b.name).toLowerCase());
        case 'rank':
        default:
          final ar = (a.marketCapRank ?? a.rank ?? 999999);
          final br = (b.marketCapRank ?? b.rank ?? 999999);
          return ar.compareTo(br);
      }
    }

    list.sort(cmp);
    if (!_isAscending) {
      // FIX: Dart uses `reversed` getter -> Iterable, convert to List
      list = list.reversed.toList();
    }
    return list;
  }

  String formatNumber(num? value) {
    if (value == null) return '...';
    if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)}T';
    if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)}M';
    if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(2)}K';
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowStyle = TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 12,
      color: theme.textTheme.bodyLarge?.color ?? Colors.black,
    );
    final headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: theme.textTheme.bodySmall?.color ?? Colors.grey,
    );

    final sortedCoins = _sortedView(widget.coins);
    final itemCount = sortedCoins.length + (widget.isLoadingMore ? 1 : 0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 24, child: Center(child: Text('#'))),
                  const SizedBox(width: 8),
                  const SizedBox(width: 20),
                  _headerCell('Coin', 'name', headerStyle, flex: 2),
                  _headerCell('Price', 'price', headerStyle, flex: 3),
                  const Expanded(flex: 2, child: Center(child: Text('24H'))),
                  _headerCell('Market Cap', 'marketCap', headerStyle, flex: 4),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.6,
              color: theme.dividerColor.withOpacity(0.4),
            ),
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index >= sortedCoins.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFEBB411),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  final coin = sortedCoins[index];
                  final pct =
                      coin.priceChange24h; // % value if that’s your model
                  final isNegative = (pct ?? 0) < 0;
                  final isPositive = (pct ?? 0) > 0;

                  return InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => CoinDetailScreen(
                                coin: coin.id,
                                coindetils: coin,
                              ),
                        ),
                      );
                      if (result == 'refresh' && widget.onCoinTap != null) {
                        widget.onCoinTap!(coin);
                      }
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Center(
                                  child: Text(
                                    _sortBy == 'rank'
                                        ? '${coin.rank ?? coin.marketCapRank ?? (widget.startRank + index)}'
                                        : '${widget.startRank + index}',
                                    style: rowStyle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildCoinIcon(coin.image),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    coin.symbol.toUpperCase(),
                                    style: rowStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: Text(
                                    '\$${coin.currentPrice.toStringAsFixed(3)}',
                                    style: rowStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    '${(isNegative
                                        ? '-'
                                        : isPositive
                                        ? '+'
                                        : '')}${(pct ?? 0).abs().toStringAsFixed(2)}%',
                                    style: rowStyle.copyWith(
                                      color:
                                          isNegative
                                              ? Colors.red
                                              : isPositive
                                              ? Colors.green
                                              : rowStyle.color,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Center(
                                  child: Text(
                                    formatNumber(coin.marketCap),
                                    style: rowStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 0.6,
                          color: theme.dividerColor.withOpacity(0.3),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(
    String title,
    String key,
    TextStyle style, {
    required int flex,
  }) {
    final isActive = _sortBy == key;
    final icon = _isAscending ? Icons.arrow_upward : Icons.arrow_downward;

    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _onSort(key),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: style.copyWith(
                fontWeight: isActive ? FontWeight.bold : style.fontWeight,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive) Icon(icon, size: 12, color: style.color),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinIcon(String icon) {
    if (icon.startsWith('http')) {
      return Image.network(
        icon,
        width: 20,
        height: 20,
        errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 14),
      );
    }
    return Image.asset(
      icon,
      width: 20,
      height: 20,
      errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 14),
    );
  }
}
