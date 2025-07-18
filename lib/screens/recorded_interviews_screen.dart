// import 'package:flutter/material.dart';
// import 'package:rwa_app/screens/video_player_modal.dart';
// import 'package:rwa_app/widgets/video_widegt.dart'; // Assumes this contains recordedInterviewCard()
// import 'package:rwa_app/screens/videos_screen.dart'; // For Interview class

// class RecordedInterviewsScreen extends StatelessWidget {
//   final List<Interview> interviews;

//   const RecordedInterviewsScreen({super.key, required this.interviews});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("All Recorded Interviews"),
//         backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
//         foregroundColor: theme.textTheme.titleLarge?.color,
//         elevation: 1,
//       ),
//       backgroundColor: theme.scaffoldBackgroundColor,
//       body:
//           interviews.isEmpty
//               ? Center(
//                 child: Text(
//                   "No recorded interviews available.",
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     color: theme.hintColor,
//                     fontSize: 14,
//                   ),
//                 ),
//               )
//               : ListView.builder(
//                 padding: const EdgeInsets.all(16),
//                 itemCount: interviews.length,
//                 itemBuilder: (context, index) {
//                   final i = interviews[index];
//                   return GestureDetector(
//                     onTap: () {
//                       if (i.videoLinkUrl != null &&
//                           i.videoLinkUrl!.isNotEmpty) {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder:
//                                 (_) => VideoPlayerModal(
//                                   videoUrl: i.videoLinkUrl!,
//                                   title: i.topicTitle,
//                                 ),
//                           ),
//                         );
//                       }
//                     },
//                     child: recordedInterviewCard(
//                       i.topicTitle,
//                       "Guest: ${i.founderName}, ${i.designation}",
//                       i.videoThumbnail ?? '',
//                       subtitle: i.topicDescription,
//                       isAsset: false,
//                     ),
//                   );
//                 },
//               ),
//     );
//   }
// }
