// import 'package:flutter/material.dart';

// /// Displays a video card (e.g., for educational videos or recorded interviews)
// Widget videoCard(
//   String imageUrl,
//   String title,
//   String duration, {
//   String subtitle = "Subtitle here",
//   bool isAsset = false,
// }) {
//   return Builder(
//     builder: (context) {
//       final theme = Theme.of(context);

//       return Container(
//         decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Stack(
//               children: [
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child:
//                       isAsset
//                           ? Image.asset(
//                             imageUrl,
//                             width: double.infinity,
//                             height: 100,
//                             fit: BoxFit.cover,
//                           )
//                           : Image.network(
//                             imageUrl,
//                             width: double.infinity,
//                             height: 100,
//                             fit: BoxFit.cover,
//                             errorBuilder:
//                                 (_, __, ___) => Container(
//                                   width: double.infinity,
//                                   height: 100,
//                                   color: Colors.grey.shade300,
//                                   alignment: Alignment.center,
//                                   child: const Icon(
//                                     Icons.broken_image,
//                                     size: 32,
//                                   ),
//                                 ),
//                           ),
//                 ),
//                 Positioned(
//                   bottom: 4,
//                   right: 4,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 6,
//                       vertical: 2,
//                     ),
//                     color: Colors.black87,
//                     child: Text(
//                       duration,
//                       style: const TextStyle(color: Colors.white, fontSize: 10),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 6),
//             Text(
//               title,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: theme.textTheme.bodyMedium?.copyWith(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//                 height: 1.2,
//               ),
//             ),
//             const SizedBox(height: 2),
//             Text(
//               subtitle,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: theme.textTheme.bodySmall?.copyWith(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w400,
//                 color: theme.hintColor,
//                 height: 1.2,
//               ),
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }

// /// Displays a circular avatar interview tile with title and badge
// Widget interviewTile(String title, String time, String badge) {
//   return Builder(
//     builder: (context) {
//       final theme = Theme.of(context);

//       return Padding(
//         padding: const EdgeInsets.only(top: 10, bottom: 2),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             const CircleAvatar(
//               radius: 26,
//               backgroundImage: AssetImage("assets/interview1.png"),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       fontWeight: FontWeight.w600,
//                       fontSize: 14,
//                       height: 1.2,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     time,
//                     style: theme.textTheme.bodySmall?.copyWith(
//                       fontSize: 12,
//                       height: 1.2,
//                       color: theme.hintColor,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Container(
//               margin: const EdgeInsets.only(left: 8),
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color:
//                     badge.toUpperCase() == "LIVE"
//                         ? Colors.red
//                         : theme.hintColor,
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               child: Text(
//                 badge,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 10,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }

// /// Displays a recorded interview card with guest, title, subtitle and thumbnail
// Widget recordedInterviewCard(
//   String title,
//   String guest,
//   String imageUrl, {
//   String subtitle =
//       "Exclusive discussion on unlocking credit for emerging markets through real-world lending protocols.",
//   bool isAsset = false,
// }) {
//   return Builder(
//     builder: (context) {
//       final theme = Theme.of(context);
//       return Container(
//         margin: const EdgeInsets.only(bottom: 8, top: 6),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(8),
//           color: theme.cardColor,
//           boxShadow: [
//             BoxShadow(
//               color: theme.shadowColor.withOpacity(0.05),
//               blurRadius: 4,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: IntrinsicHeight(
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               SizedBox(
//                 width: 120,
//                 height: 100,
//                 child: ClipRRect(
//                   borderRadius: const BorderRadius.only(
//                     topLeft: Radius.circular(8),
//                     bottomLeft: Radius.circular(8),
//                   ),
//                   child: Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       isAsset
//                           ? Image.asset(
//                             imageUrl,
//                             width: 120,
//                             height: 100,
//                             fit: BoxFit.cover,
//                           )
//                           : Image.network(
//                             imageUrl,
//                             width: 120,
//                             height: 100,
//                             fit: BoxFit.cover,
//                             errorBuilder:
//                                 (_, __, ___) => Container(
//                                   width: 120,
//                                   height: 100,
//                                   color: Colors.grey.shade300,
//                                   alignment: Alignment.center,
//                                   child: const Icon(
//                                     Icons.broken_image,
//                                     size: 32,
//                                   ),
//                                 ),
//                           ),
//                       Container(
//                         decoration: const BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: Colors.black45,
//                         ),
//                         child: const Icon(
//                           Icons.play_circle_fill,
//                           size: 36,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 8),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         title,
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: theme.textTheme.bodyMedium?.copyWith(
//                           fontWeight: FontWeight.w600,
//                           fontSize: 14,
//                           height: 1.3,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         guest,
//                         style: theme.textTheme.bodySmall?.copyWith(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w500,
//                           color: const Color(0xFF348F6C),
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         subtitle,
//                         maxLines: 3,
//                         overflow: TextOverflow.ellipsis,
//                         style: theme.textTheme.bodySmall?.copyWith(
//                           fontSize: 10,
//                           color: theme.hintColor,
//                           height: 1.3,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     },
//   );
// }
