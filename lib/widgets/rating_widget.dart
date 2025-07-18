 // Widget _buildRatingSection(ThemeData theme) {
  //   final isDark = theme.brightness == Brightness.dark;

  //   return FutureBuilder<SharedPreferences>(
  //     future: SharedPreferences.getInstance(),
  //     builder: (context, snapshot) {
  //       if (!snapshot.hasData) return const SizedBox.shrink();

  //       final token = snapshot.data!.getString('token');
  //       final isLoggedIn = token != null;

  //       final baseColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
  //       final highlightColor = isDark ? Colors.grey[500]! : Colors.grey[100]!;

  //       return Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 16),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               'Rate this Coin',
  //               style: theme.textTheme.titleMedium?.copyWith(
  //                 fontWeight: FontWeight.bold,
  //                 fontSize: 14,
  //                 color: isDark ? Colors.white : Colors.black,
  //               ),
  //             ),
  //             const SizedBox(height: 6),
  //             _isSubmittingRating
  //                 ? Shimmer.fromColors(
  //                   baseColor: baseColor,
  //                   highlightColor: highlightColor,
  //                   child: Row(
  //                     mainAxisSize: MainAxisSize.min,
  //                     children: List.generate(5, (index) {
  //                       return Padding(
  //                         padding: const EdgeInsets.only(right: 4),
  //                         child: Icon(
  //                           Icons.star_border,
  //                           color: const Color(0xFF0087E0),
  //                           size: 32,
  //                         ),
  //                       );
  //                     }),
  //                   ),
  //                 )
  //                 : Row(
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: List.generate(5, (index) {
  //                     final isSelected = index < _currentRating;

  //                     return GestureDetector(
  //                       onTap: () async {
  //                         if (_isSubmittingRating) return;

  //                         if (!isLoggedIn) {
  //                           ScaffoldMessenger.of(context).showSnackBar(
  //                             const SnackBar(
  //                               content: Text('Please log in to rate.'),
  //                               duration: Duration(seconds: 2),
  //                             ),
  //                           );
  //                           return;
  //                         }

  //                         setState(() {
  //                           _currentRating = index + 1;
  //                           _isSubmittingRating = true;
  //                         });

  //                         final coinId = widget.coindetils.id;
  //                         final url = Uri.parse(
  //                           // http://192.168.1.43:5001/api/user/token/add/rating/chainlink
  //                           'https://rwa-f1623a22e3ed.herokuapp.com/api/user/token/add/rating/$coinId',
  //                         );

  //                         final headers = {
  //                           'Authorization': 'Bearer $token',
  //                           'Content-Type': 'application/json',
  //                         };
  //                         final body = jsonEncode({'value': _currentRating});

  //                         print('📡 Sending Rating Request...');
  //                         print('🔗 URL: $url');
  //                         print('🪪 Token: $token');
  //                         print('🧾 Headers: $headers');
  //                         print('📦 Body: $body');

  //                         try {
  //                           final response = await http.post(
  //                             url,
  //                             headers: headers,
  //                             body: body,
  //                           );

  //                           print('📬 Status Code: ${response.statusCode}');
  //                           print('📄 Response Body: ${response.body}');

  //                           if (context.mounted) {
  //                             ScaffoldMessenger.of(context).showSnackBar(
  //                               SnackBar(
  //                                 content: Text(
  //                                   response.statusCode == 200
  //                                       ? 'Thanks for rating!'
  //                                       : 'Failed to submit rating',
  //                                 ),
  //                               ),
  //                             );
  //                           }
  //                         } catch (e) {
  //                           print('❌ Exception during rating: $e');
  //                         } finally {
  //                           if (mounted) {
  //                             setState(() {
  //                               _isSubmittingRating = false;
  //                             });
  //                           }
  //                         }
  //                       },

  //                       child: Padding(
  //                         padding: const EdgeInsets.only(right: 4),
  //                         child: Icon(
  //                           isSelected ? Icons.star : Icons.star_border,
  //                           color:
  //                               isSelected
  //                                   ? const Color(0xFF0087E0)
  //                                   : isDark
  //                                   ? Colors.grey[600]
  //                                   : Colors.grey[500],
  //                           size: 32,
  //                         ),
  //                       ),
  //                     );
  //                   }),
  //                 ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }