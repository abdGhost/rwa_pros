class PortfolioToken {
  final String tokenId;
  final double amount;
  final double quantity;
  final double perUnit;
  final double currentPrice;
  final double returnPercentage;
  final double returns;
  final String symbol;
  final String name;
  final String image;
  final double change24h;
  final double change1h;
  final double change7d;

  PortfolioToken({
    required this.tokenId,
    required this.amount,
    required this.quantity,
    required this.perUnit,
    required this.currentPrice,
    required this.returnPercentage,
    required this.returns,
    required this.symbol,
    required this.name,
    required this.image,
    required this.change24h,
    required this.change1h,
    required this.change7d,
  });

  factory PortfolioToken.fromJson(Map<String, dynamic> json) {
    return PortfolioToken(
      tokenId: json['tokenId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      quantity: (json['quantity'] ?? 0).toDouble(),
      perUnit: (json['perUnit'] ?? 0).toDouble(),
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      returnPercentage: (json['returnPercentage'] ?? 0).toDouble(),
      returns: (json['return'] ?? 0).toDouble(),
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      change24h:
          (json['price_change_percentage_24h_in_currency'] ?? 0).toDouble(),
      change1h:
          (json['price_change_percentage_1h_in_currency'] ?? 0).toDouble(),
      change7d:
          (json['price_change_percentage_7d_in_currency'] ?? 0).toDouble(),
    );
  }
}
