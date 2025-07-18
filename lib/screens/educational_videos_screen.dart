// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:rwa_app/screens/videos_screen.dart';
// import 'package:rwa_app/screens/video_player_modal.dart'; // ✅ Make sure this is imported

// class EducationalVideosScreen extends StatelessWidget {
//   final List<EducationalVideo> videos;

//   const EducationalVideosScreen({super.key, required this.videos});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: theme.scaffoldBackgroundColor,
//         elevation: 0,
//         toolbarHeight: 50,
//         automaticallyImplyLeading: true,
//         iconTheme: theme.iconTheme,
//         title: Text(
//           'Educational Videos',
//           style: GoogleFonts.inter(
//             color: theme.textTheme.titleLarge?.color,
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//           ),
//         ),
//       ),
//       backgroundColor: theme.scaffoldBackgroundColor,
//       body: ListView.builder(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         itemCount: videos.length,
//         itemBuilder: (context, index) {
//           final video = videos[index];
//           return GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder:
//                       (_) => VideoPlayerModal(
//                         videoUrl: video.videoUrl,
//                         title: video.title,
//                       ),
//                 ),
//               );
//             },
//             child: Container(
//               margin: const EdgeInsets.only(bottom: 16),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(8),
//                     child: Stack(
//                       alignment: Alignment.center,
//                       children: [
//                         Image.network(
//                           video.thumbnail,
//                           width: 140,
//                           height: 90,
//                           fit: BoxFit.cover,
//                         ),
//                         Container(
//                           width: 40,
//                           height: 40,
//                           decoration: BoxDecoration(
//                             color: Colors.black.withOpacity(0.5),
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(
//                             Icons.play_arrow,
//                             color: Colors.white,
//                             size: 24,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                               child: Text(
//                                 video.title,
//                                 maxLines: 2,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: theme.textTheme.bodyMedium?.copyWith(
//                                   fontWeight: FontWeight.w600,
//                                   height: 1.1,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 4),
//                             Icon(
//                               Icons.more_vert,
//                               size: 20,
//                               color: theme.iconTheme.color?.withOpacity(0.7),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           video.subtitle,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: theme.textTheme.bodySmall?.copyWith(
//                             fontWeight: FontWeight.w400,
//                             color: theme.hintColor,
//                             height: 1.3,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           video.channel,
//                           style: theme.textTheme.bodySmall?.copyWith(
//                             fontWeight: FontWeight.w600,
//                             color:
//                                 isDark
//                                     ? Colors.grey[400]
//                                     : const Color(0xFF818181),
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Row(
//                           children: [
//                             Text(
//                               "563 Views",
//                               style: theme.textTheme.bodySmall?.copyWith(
//                                 fontSize: 10,
//                                 color: theme.hintColor,
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Text(
//                               "2 days ago",
//                               style: theme.textTheme.bodySmall?.copyWith(
//                                 fontSize: 10,
//                                 color: theme.hintColor,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
