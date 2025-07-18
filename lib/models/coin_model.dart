class Coin {
  final String id;
  final String symbol;
  final String name;
  final String image;
  final double currentPrice;
  final double marketCap;
  final int? marketCapRank;
  final int? rank;
  final double priceChange24h;
  final List<double> sparkline;

  final double? totalVolume;
  final double? high24h;
  final double? low24h;
  final double? marketCapChange24h;
  final double? ath;
  final double? atl;
  final double? athChangePercentage;
  final double? atlChangePercentage;

  Coin({
    required this.id,
    required this.symbol,
    required this.name,
    required this.image,
    required this.currentPrice,
    required this.marketCap,
    required this.marketCapRank,
    required this.rank,
    required this.priceChange24h,
    required this.sparkline,
    this.totalVolume,
    this.high24h,
    this.low24h,
    this.marketCapChange24h,
    this.ath,
    this.atl,
    this.athChangePercentage,
    this.atlChangePercentage,
  });

  factory Coin.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Coin(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      currentPrice: toDouble(json['current_price']) ?? 0.0,
      marketCap: toDouble(json['market_cap']) ?? 0.0,
      rank: json['rank'],
      marketCapRank: json['market_cap_rank'],
      priceChange24h:
          toDouble(json['price_change_percentage_24h_in_currency']) ?? 0.0,
      sparkline:
          (json['sparkline_in_7d']?['price'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      totalVolume: toDouble(json['total_volume']),
      high24h: toDouble(json['high_24h']),
      low24h: toDouble(json['low_24h']),
      marketCapChange24h: toDouble(json['market_cap_change_24h']),
      ath: toDouble(json['ath']),
      atl: toDouble(json['atl']),
      athChangePercentage: toDouble(json['ath_change_percentage']),
      atlChangePercentage: toDouble(json['atl_change_percentage']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'image': image,
      'current_price': currentPrice,
      'market_cap': marketCap,
      'market_cap_rank': marketCapRank,
      'rank': rank,
      'price_change_percentage_24h_in_currency': priceChange24h,
      'sparkline_in_7d': {'price': sparkline},
      'total_volume': totalVolume,
      'high_24h': high24h,
      'low_24h': low24h,
      'market_cap_change_24h': marketCapChange24h,
      'ath': ath,
      'atl': atl,
      'ath_change_percentage': athChangePercentage,
      'atl_change_percentage': atlChangePercentage,
    };
  }
}

class CurrenciesResponse {
  final bool status;
  final List<Coin> currencies;

  CurrenciesResponse({required this.status, required this.currencies});

  factory CurrenciesResponse.fromJson(Map<String, dynamic> json) {
    return CurrenciesResponse(
      status: json['status'] ?? false,
      currencies:
          (json['currency'] as List<dynamic>)
              .map((item) => Coin.fromJson(item))
              .toList(),
    );
  }
}
