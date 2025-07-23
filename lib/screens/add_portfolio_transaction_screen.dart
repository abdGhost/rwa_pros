import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class AddPortfolioTransactionScreen extends StatefulWidget {
  final Map<String, dynamic> coin;

  const AddPortfolioTransactionScreen({super.key, required this.coin});

  @override
  State<AddPortfolioTransactionScreen> createState() =>
      _AddPortfolioTransactionScreenState();
}

class _AddPortfolioTransactionScreenState
    extends State<AddPortfolioTransactionScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updatePricePerToken);
    _quantityController.addListener(_updatePricePerToken);
  }

  void _updatePricePerToken() {
    final amount = double.tryParse(_amountController.text);
    final quantity = double.tryParse(_quantityController.text);

    if (amount != null && quantity != null && quantity > 0) {
      final price = amount / quantity;
      _priceController.text = price.toStringAsFixed(4);
    } else {
      _priceController.text = '';
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_updatePricePerToken);
    _quantityController.removeListener(_updatePricePerToken);
    _amountController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(
                context,
              ).colorScheme.copyWith(primary: const Color(0xFFEBB411)),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitTransaction() async {
    setState(() => isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final id = widget.coin["tokenId"] ?? widget.coin["id"];

    final response = await http.post(
      Uri.parse(
        'https://rwa-f1623a22e3ed.herokuapp.com/api/user/token/portfolio/$id',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "id": id,
        "amount": _amountController.text,
        "quantity": _quantityController.text,
      }),
    );

    setState(() => isSubmitting = false);

    if (response.statusCode == 200) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transaction added successfully!',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add transaction.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coin = widget.coin;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Transaction',
          style: GoogleFonts.inter(textStyle: theme.textTheme.titleMedium),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label("Selected Coin", theme),
            const SizedBox(height: 4),
            Text(
              "${coin["name"]} / ${coin["symbol"].toString().toUpperCase()}",
              style: GoogleFonts.inter(
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _label("Total Spent", theme),
            const SizedBox(height: 6),
            _inputField(theme, _amountController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label("Quantity", theme),
                      const SizedBox(height: 6),
                      _inputField(theme, _quantityController),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label("Price per Token", theme),
                      const SizedBox(height: 6),
                      _inputField(theme, _priceController, readOnly: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _label("Date", theme),
            const SizedBox(height: 6),
            TextField(
              controller: _dateController,
              readOnly: true,
              onTap: () => _pickDate(context),
              style: GoogleFonts.inter(textStyle: theme.textTheme.bodyMedium),
              cursorColor: theme.primaryColor,
              decoration: _inputDecoration(theme).copyWith(
                hintText: "dd/mm/yyyy",
                hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                suffixIcon: Icon(
                  Icons.calendar_today,
                  color: theme.iconTheme.color,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEBB411),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: isSubmitting ? null : _submitTransaction,
                child:
                    isSubmitting
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          "Add Transaction",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, ThemeData theme) {
    return Text(
      text,
      style: GoogleFonts.inter(
        textStyle: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  TextField _inputField(
    ThemeData theme,
    TextEditingController controller, {
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: TextInputType.number,
      style: GoogleFonts.inter(textStyle: theme.textTheme.bodyMedium),
      cursorColor: theme.primaryColor,
      decoration: _inputDecoration(theme),
    );
  }

  InputDecoration _inputDecoration(ThemeData theme) {
    return InputDecoration(
      filled: true,
      fillColor: theme.cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 0.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 0.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade600, width: 0.6),
      ),
    );
  }
}
