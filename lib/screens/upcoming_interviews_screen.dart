// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:rwa_app/screens/videos_screen.dart';
// import 'package:rwa_app/theme/theme.dart';

// class UpcomingInterviewsScreen extends StatelessWidget {
//   final List<Interview> interviews;

//   const UpcomingInterviewsScreen({super.key, required this.interviews});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: theme.scaffoldBackgroundColor,
//         elevation: 0,
//         toolbarHeight: 50,
//         iconTheme: theme.iconTheme,
//         title: Text(
//           'Upcoming Interviews',
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
//         itemCount: interviews.length,
//         itemBuilder: (context, index) {
//           final i = interviews[index];
//           return Container(
//             margin: const EdgeInsets.only(bottom: 16),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     ClipOval(
//                       child: Image.network(
//                         i.founderImg,
//                         width: 80,
//                         height: 80,
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     SizedBox(
//                       width: 80,
//                       child: Column(
//                         children: [
//                           Text(
//                             i.founderName,
//                             textAlign: TextAlign.center,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w600,
//                               color: theme.textTheme.bodyMedium?.color,
//                             ),
//                           ),
//                           Text(
//                             i.designation,
//                             textAlign: TextAlign.center,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               fontSize: 10,
//                               fontWeight: FontWeight.w400,
//                               color: theme.hintColor,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: SizedBox(
//                     height: 100,
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           i.topicTitle,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: theme.textTheme.bodyLarge?.copyWith(
//                             fontWeight: FontWeight.w600,
//                             height: 1.3,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           i.topicDescription,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: theme.textTheme.bodySmall?.copyWith(
//                             height: 1.2,
//                             color: theme.hintColor,
//                             fontSize: 12,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           i.videoDate.split('T')[0],
//                           style: theme.textTheme.bodySmall?.copyWith(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w500,
//                             color: AppColors.primaryDark,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
