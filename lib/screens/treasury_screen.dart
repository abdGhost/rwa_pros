import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rwa_app/screens/profile_screen.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  List<Map<String, dynamic>> tokenData = [];
  bool isLoading = true;
  double totalBalance = 0.0; // <- Added

  @override
  void initState() {
    super.initState();
    fetchTokenData();
  }

  Future<void> fetchTokenData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://rwa-f1623a22e3ed.herokuapp.com/api/treasuryTokens/get/allTokens',
        ),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          tokenData = List<Map<String, dynamic>>.from(json['treasuryTokens']);
          totalBalance = (json['totalBalance'] as num).toDouble(); // <- Updated
          print(totalBalance);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    );
    return formatter.format(value);
  }

  String formatNumber(String value) {
    try {
      final number = double.parse(value);
      final formatter = NumberFormat('#,##0.00', 'en_US');
      return formatter.format(number);
    } catch (e) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            Image.asset('assets/condo_logo.png', width: 40, height: 40),
            const SizedBox(width: 8),
            Text(
              "Condo Treasury",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 22,
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
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0087E0)),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/bg.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 250,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    top: 0,
                                    child: Image.asset(
                                      'assets/naffan.png',
                                      width:
                                          MediaQuery.of(context).size.width *
                                          0.6,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned(
                                    top: 100,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/cloud.png',
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.7,
                                          fit: BoxFit.contain,
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              "Total Treasury Value",
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              formatCurrency(
                                                totalBalance,
                                              ), // <- Updated
                                              style: GoogleFonts.inter(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children:
                          tokenData.map((token) {
                            return Column(
                              children: [
                                const Divider(
                                  thickness: 0.2,
                                  height: 0,
                                  color: Colors.grey,
                                ),
                                _buildTokenCard(
                                  token['symbol'],
                                  token['tokenName'],
                                  formatCurrency(
                                    double.tryParse(
                                          token['balanceUsd'].toString(),
                                        ) ??
                                        0.0,
                                  ),
                                  formatNumber(
                                    token['tokenBalance'].toString(),
                                  ),
                                  token['tokenImg'],
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
    );
  }

  Widget _buildTokenCard(
    String symbol,
    String name,
    String price,
    String amount,
    String imageUrl,
  ) {
    final theme = Theme.of(context);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                imageUrl,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color ?? Colors.black,
                    fontSize: 14,
                  ),
                ),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyLarge?.color ?? Colors.black,
                  fontSize: 14,
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
