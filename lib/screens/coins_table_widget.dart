import 'package:flutter/material.dart';
import 'package:rwa_app/models/coin_model.dart';
import 'package:rwa_app/screens/coin_details_screen.dart';

class CoinsTable extends StatefulWidget {
  final List<Coin> coins;
  final ScrollController? scrollController;
  final void Function(Coin)? onCoinTap;

  const CoinsTable({
    super.key,
    required this.coins,
    this.scrollController,
    this.onCoinTap,
  });

  @override
  State<CoinsTable> createState() => _CoinsTableState();
}

class _CoinsTableState extends State<CoinsTable> {
  late List<Coin> _sortedCoins;
  String _sortBy = 'rank';
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _sortedCoins = List.from(widget.coins);
  }

  @override
  void didUpdateWidget(covariant CoinsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coins != widget.coins) {
      _sortedCoins = List.from(widget.coins);
      _sortCoins();
    }
  }

  void _onSort(String column) {
    setState(() {
      if (_sortBy == column) {
        _isAscending = !_isAscending;
      } else {
        _sortBy = column;
        _isAscending = true;
      }
      _sortCoins();
    });
  }

  void _sortCoins() {
    _sortedCoins.sort((a, b) {
      int compare;
      switch (_sortBy) {
        case 'price':
          compare = a.currentPrice.compareTo(b.currentPrice);
          break;
        case 'marketCap':
          compare = a.marketCap.compareTo(b.marketCap);
          break;
        case 'name':
          compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        default:
          compare = (a.marketCapRank ?? 999999).compareTo(
            b.marketCapRank ?? 999999,
          );
      }
      return _isAscending ? compare : -compare;
    });
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
                  const SizedBox(width: 20), // for icon
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
                itemCount: _sortedCoins.length,
                itemBuilder: (context, index) {
                  final coin = _sortedCoins[index];
                  final isNegative = coin.priceChange24h < 0;
                  final isPositive = coin.priceChange24h > 0;

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
                                  child: Text('${coin.rank}', style: rowStyle),
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
                                    '${isNegative
                                        ? '-'
                                        : isPositive
                                        ? '+'
                                        : ''}${coin.priceChange24h.abs().toStringAsFixed(2)}%',
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
