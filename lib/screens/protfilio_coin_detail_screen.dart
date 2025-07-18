import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilioCoinDetailScreen extends StatefulWidget {
  final Map<String, dynamic> coin;
  final List<double> trend;

  const ProfilioCoinDetailScreen({
    super.key,
    required this.coin,
    required this.trend,
  });

  @override
  State<ProfilioCoinDetailScreen> createState() =>
      _ProfilioCoinDetailScreenState();
}

class _ProfilioCoinDetailScreenState extends State<ProfilioCoinDetailScreen> {
  int selectedIndex = 1;
  final List<String> filters = ["1H", "24H", "7D", "1M", "1Y", "All"];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool isProfit = (widget.coin['returnPercentage'] ?? 0) >= 0;
    final Color changeColor =
        isProfit ? const Color(0xFF16C784) : const Color(0xFFFF3B30);
    final IconData changeIcon =
        isProfit ? Icons.arrow_drop_up : Icons.arrow_drop_down;

    final List<FlSpot> chartData = List.generate(
      widget.trend.length,
      (i) => FlSpot(i.toDouble(), widget.trend[i]),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 1,
        iconTheme: theme.iconTheme,
        titleSpacing: 0,
        title: Row(
          children: [
            Image.network(
              widget.coin['image'] ?? '',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.image),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "${widget.coin['name']} / ${widget.coin['symbol']}"
                    .toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: theme.textTheme.titleSmall?.color,
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  "\$${(widget.coin['currentPrice'] ?? 0).toStringAsFixed(2)}",
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(changeIcon, color: changeColor, size: 20),
                Text(
                  "${(widget.coin['returnPercentage'] ?? 0).abs().toStringAsFixed(2)}%",
                  style: GoogleFonts.inter(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _buildChart(theme, chartData, changeColor),
          const SizedBox(height: 10),
          _buildFilterButtons(theme, isDark),
          const SizedBox(height: 20),
          _buildStatsSection(context),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildChart(ThemeData theme, List<FlSpot> chartData, Color color) {
    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(show: false),
            minY: widget.trend.reduce((a, b) => a < b ? a : b) - 1,
            maxY: widget.trend.reduce((a, b) => a > b ? a : b) + 1,
            lineBarsData: [
              LineChartBarData(
                spots: chartData,
                isCurved: true,
                color: color,
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButtons(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : const Color(0xFFEFF2F5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              filters.asMap().entries.map((entry) {
                final isSelected = selectedIndex == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedIndex = entry.key;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? theme.scaffoldBackgroundColor
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.value,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            isSelected
                                ? theme.textTheme.bodyLarge?.color
                                : Colors.grey,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _buildSummaryCard(
              context,
              "Total Invested",
              "\$${(widget.coin['amount'] ?? 0).toStringAsFixed(2)}",
            ),
            _buildSummaryCard(
              context,
              "Avg Buy Price",
              "\$${(widget.coin['perUnit'] ?? 0).toStringAsFixed(2)}",
            ),
            _buildSummaryCard(
              context,
              "Current Holdings",
              "${(widget.coin['quantity'] ?? 0)} ${widget.coin['symbol']}"
                  .toUpperCase(),
              sub:
                  "\$${((widget.coin['quantity'] ?? 0) * (widget.coin['currentPrice'] ?? 0)).toStringAsFixed(2)}",
            ),
            _buildSummaryCard(
              context,
              "All-time P/L",
              "\$${(widget.coin['return'] ?? 0).toStringAsFixed(2)}",
              sub:
                  "${(widget.coin['returnPercentage'] ?? 0).toStringAsFixed(2)}%",
              subColor:
                  (widget.coin['returnPercentage'] ?? 0) >= 0
                      ? Colors.green
                      : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value, {
    String? sub,
    Color? subColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          if (sub != null)
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: subColor ?? Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
