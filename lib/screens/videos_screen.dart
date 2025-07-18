// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:rwa_app/screens/chat_screen.dart';
// import 'package:rwa_app/screens/educational_videos_screen.dart';
// import 'package:rwa_app/screens/profile_screen.dart';
// import 'package:rwa_app/screens/upcoming_interviews_screen.dart';
// import 'package:rwa_app/screens/recorded_interviews_screen.dart';
// import 'package:rwa_app/screens/video_player_modal.dart';

// class EducationalVideo {
//   final String title;
//   final String thumbnail;
//   final String subtitle;
//   final String channel;
//   final String videoUrl;
//   final String date;

//   EducationalVideo({
//     required this.title,
//     required this.thumbnail,
//     required this.subtitle,
//     required this.channel,
//     required this.videoUrl,
//     required this.date,
//   });

//   factory EducationalVideo.fromJson(Map<String, dynamic> json) {
//     return EducationalVideo(
//       title: json['videoTitle'],
//       thumbnail: json['videoThumbImg'],
//       subtitle: json['videoSubTitle'],
//       channel: json['channelName'],
//       videoUrl: json['videoLink'],
//       date: json['videoDate'],
//     );
//   }
// }

// class Interview {
//   final String founderName;
//   final String founderImg;
//   final String designation;
//   final String topicTitle;
//   final String topicDescription;
//   final String? videoLinkUrl;
//   final String? videoThumbnail;
//   final String videoDate;

//   Interview({
//     required this.founderName,
//     required this.founderImg,
//     required this.designation,
//     required this.topicTitle,
//     required this.topicDescription,
//     required this.videoDate,
//     this.videoLinkUrl,
//     this.videoThumbnail,
//   });

//   factory Interview.fromJson(Map<String, dynamic> json) {
//     return Interview(
//       founderName: json['founderName'],
//       founderImg: json['founderImg'],
//       designation: json['foundersDesignation'],
//       topicTitle: json['topicTitle'],
//       topicDescription: json['topicDescription'],
//       videoLinkUrl: json['videoLinkUrl'],
//       videoThumbnail: json['videoThumbnail'],
//       videoDate: json['videoDate'],
//     );
//   }
// }

// Future<List<EducationalVideo>> fetchEducationalVideos() async {
//   const url =
//       'https://airdrop-production-61b7.up.railway.app/api/get/allEducationalVideo';
//   final response = await http.get(Uri.parse(url));
//   if (response.statusCode == 200) {
//     final data = jsonDecode(response.body);
//     return (data['data'] as List)
//         .map((video) => EducationalVideo.fromJson(video))
//         .toList();
//   } else {
//     throw Exception('Failed to load videos');
//   }
// }

// Future<List<Interview>> fetchInterviews() async {
//   const url =
//       'https://airdrop-production-61b7.up.railway.app/api/get/allInterviews';
//   final response = await http.get(Uri.parse(url));
//   if (response.statusCode == 200) {
//     final data = jsonDecode(response.body);
//     return (data['data'] as List)
//         .map((item) => Interview.fromJson(item))
//         .toList();
//   } else {
//     throw Exception('Failed to load interviews');
//   }
// }

// class VideosScreen extends StatelessWidget {
//   const VideosScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;
//     final screenWidth = MediaQuery.of(context).size.width;
//     final cardWidth = screenWidth * 0.4;

//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: AppBar(
//         backgroundColor: isDark ? Colors.black : theme.scaffoldBackgroundColor,
//         elevation: 1,
//         automaticallyImplyLeading: false,
//         toolbarHeight: 40,
//         title: Row(
//           children: [
//             Text(
//               'Explore',
//               style: GoogleFonts.inter(
//                 color: theme.textTheme.titleLarge?.color ?? Colors.black,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18,
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           InkWell(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const ProfileScreen()),
//               );
//             },
//             child: Padding(
//               padding: const EdgeInsets.only(right: 12),
//               child: SvgPicture.asset(
//                 'assets/profile_outline.svg',
//                 width: 30,
//                 height: 30,
//                 colorFilter: ColorFilter.mode(
//                   theme.iconTheme.color ?? Colors.black,
//                   BlendMode.srcIn,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: SizedBox(
//         width: 56,
//         height: 56,
//         child: FloatingActionButton(
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => const ChatScreen()),
//             );
//           },
//           backgroundColor: const Color(0xFF348F6C),
//           shape: const CircleBorder(),
//           child: SvgPicture.asset(
//             'assets/bot_light.svg',
//             width: 40,
//             height: 40,
//             fit: BoxFit.contain,
//             colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
//           ),
//         ),
//       ),

//       body: SafeArea(
//         child: FutureBuilder(
//           future: Future.wait([fetchEducationalVideos(), fetchInterviews()]),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF0087E0)),
//               );
//             } else if (snapshot.hasError) {
//               return Center(child: Text("Error: ${snapshot.error}"));
//             }
//             final videos = snapshot.data![0] as List<EducationalVideo>;
//             final interviews = snapshot.data![1] as List<Interview>;

//             final upcoming =
//                 interviews.where((i) => i.videoLinkUrl == null).toList();
//             final recorded =
//                 interviews.where((i) => i.videoLinkUrl != null).toList();

//             return SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _sectionTitle(context, "Educational Videos", () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => EducationalVideosScreen(videos: videos),
//                       ),
//                     );
//                   }),
//                   const SizedBox(height: 8),
//                   videos.isEmpty
//                       ? Center(
//                         child: Text(
//                           "No educational videos available.",
//                           style: Theme.of(context).textTheme.bodySmall,
//                         ),
//                       )
//                       : _videoSliderFromApi(context, cardWidth, videos),
//                   const SizedBox(height: 20),

//                   _sectionTitle(context, "Upcoming Interviews", () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder:
//                             (_) =>
//                                 UpcomingInterviewsScreen(interviews: upcoming),
//                       ),
//                     );
//                   }),
//                   const SizedBox(height: 6),
//                   upcoming.isEmpty
//                       ? Center(
//                         child: Text(
//                           "No upcoming interviews.",
//                           style: Theme.of(context).textTheme.bodySmall,
//                         ),
//                       )
//                       : Column(
//                         children:
//                             upcoming
//                                 .map((i) => _interviewTileFromApi(context, i))
//                                 .toList(),
//                       ),
//                   const SizedBox(height: 12),

//                   _sectionTitle(context, "Recorded Interviews", () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder:
//                             (_) =>
//                                 RecordedInterviewsScreen(interviews: recorded),
//                       ),
//                     );
//                   }),
//                   const SizedBox(height: 6),
//                   recorded.isEmpty
//                       ? Center(
//                         child: Text(
//                           "No recorded interviews.",
//                           style: Theme.of(context).textTheme.bodySmall,
//                         ),
//                       )
//                       : Column(
//                         children:
//                             recorded
//                                 .map(
//                                   (i) =>
//                                       _recordedInterviewCardFromApi(context, i),
//                                 )
//                                 .toList(),
//                       ),
//                 ],
//               ),
//             );

//             // return SingleChildScrollView(
//             //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//             //   child: Column(
//             //     crossAxisAlignment: CrossAxisAlignment.start,
//             //     children: [
//             //       _sectionTitle(context, "Educational Videos", () {
//             //         Navigator.push(
//             //           context,
//             //           MaterialPageRoute(
//             //             builder: (_) => EducationalVideosScreen(videos: videos),
//             //           ),
//             //         );
//             //       }),
//             //       const SizedBox(height: 8),
//             //       _videoSliderFromApi(context, cardWidth, videos),
//             //       const SizedBox(height: 12),
//             //       _sectionTitle(context, "Upcoming Interviews", () {
//             //         Navigator.push(
//             //           context,
//             //           MaterialPageRoute(
//             //             builder:
//             //                 (_) =>
//             //                     UpcomingInterviewsScreen(interviews: upcoming),
//             //           ),
//             //         );
//             //       }),

//             //       const SizedBox(height: 6),
//             //       ...upcoming.map((i) => _interviewTileFromApi(context, i)),
//             //       const SizedBox(height: 12),
//             //       _sectionTitle(context, "Recorded Interviews", () {
//             //         Navigator.push(
//             //           context,
//             //           MaterialPageRoute(
//             //             builder:
//             //                 (_) =>
//             //                     RecordedInterviewsScreen(interviews: recorded),
//             //           ),
//             //         );
//             //       }),
//             //       const SizedBox(height: 6),
//             //       ...recorded.map(
//             //         (i) => _recordedInterviewCardFromApi(context, i),
//             //       ),
//             //     ],
//             //   ),
//             // );
//           },
//         ),
//       ),
//     );
//   }

//   Widget _sectionTitle(
//     BuildContext context,
//     String title,
//     VoidCallback onSeeAll,
//   ) {
//     final theme = Theme.of(context);
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Flexible(
//           child: Text(
//             title,
//             style: theme.textTheme.titleSmall?.copyWith(
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//         GestureDetector(
//           onTap: onSeeAll,
//           child: const Text(
//             "See all",
//             style: TextStyle(color: Colors.blue, fontSize: 12),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _videoSliderFromApi(
//     BuildContext context,
//     double cardWidth,
//     List<EducationalVideo> videos,
//   ) {
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Row(
//         children:
//             videos.map((video) {
//               print(video.videoUrl);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 6),
//                 child: GestureDetector(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder:
//                             (_) => VideoPlayerModal(
//                               videoUrl: video.videoUrl,
//                               title: video.title,
//                             ),
//                       ),
//                     );
//                   },
//                   child: SizedBox(
//                     width: cardWidth,
//                     child: _videoCard(
//                       context,
//                       video.thumbnail,
//                       video.title,
//                       "8:20",
//                       subtitle: video.subtitle,
//                     ),
//                   ),
//                 ),
//               );
//             }).toList(),
//       ),
//     );
//   }

//   Widget _videoCard(
//     BuildContext context,
//     String imageUrl,
//     String title,
//     String duration, {
//     String subtitle = "Subtitle",
//   }) {
//     final theme = Theme.of(context);
//     return Container(
//       decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Stack(
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(8),
//                 child: Image.network(
//                   imageUrl,
//                   width: double.infinity,
//                   height: 100,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//               Positioned(
//                 bottom: 4,
//                 right: 4,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 6,
//                     vertical: 2,
//                   ),
//                   color: Colors.black87,
//                   child: Text(
//                     duration,
//                     style: const TextStyle(color: Colors.white, fontSize: 10),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             title,
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//             style: theme.textTheme.bodySmall?.copyWith(
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             subtitle,
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//             style: theme.textTheme.bodySmall?.copyWith(
//               fontSize: 10,
//               fontWeight: FontWeight.w400,
//               color: theme.hintColor,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _interviewTileFromApi(BuildContext context, Interview i) {
//     final theme = Theme.of(context);
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           CircleAvatar(radius: 26, backgroundImage: NetworkImage(i.founderImg)),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   i.topicTitle,
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 12,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   i.videoDate.split('T')[0],
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontWeight: FontWeight.w400,
//                     fontSize: 10,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             margin: const EdgeInsets.only(left: 8),
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: Colors.orange,
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: const Text(
//               "Scheduled",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 10,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _recordedInterviewCardFromApi(BuildContext context, Interview i) {
//     final theme = Theme.of(context);
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(8),
//         color: theme.cardColor,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.02),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: IntrinsicHeight(
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             ClipRRect(
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(8),
//                 bottomLeft: Radius.circular(8),
//               ),
//               child:
//                   i.videoThumbnail != null
//                       ? Image.network(
//                         i.videoThumbnail!,
//                         width: 120,
//                         fit: BoxFit.cover,
//                       )
//                       : Container(width: 120, color: Colors.grey),
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       i.topicTitle,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: theme.textTheme.bodyMedium?.copyWith(
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       i.founderName,
//                       style: const TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w500,
//                         color: Color(0xFF348f6c),
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       i.topicDescription,
//                       maxLines: 3,
//                       overflow: TextOverflow.ellipsis,
//                       style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
