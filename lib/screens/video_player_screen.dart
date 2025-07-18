// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';

// class VideoPlayerScreen extends StatefulWidget {
//   final String videoUrl;

//   const VideoPlayerScreen({super.key, required this.videoUrl});

//   @override
//   State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
//   late VideoPlayerController _controller;
//   bool _initialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
//       ..initialize().then((_) {
//         setState(() => _initialized = true);
//         _controller.play();
//       });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Playing Interview")),
//       body: Center(
//         child:
//             _initialized
//                 ? AspectRatio(
//                   aspectRatio: _controller.value.aspectRatio,
//                   child: VideoPlayer(_controller),
//                 )
//                 : const CircularProgressIndicator(),
//       ),
//       floatingActionButton:
//           _initialized
//               ? FloatingActionButton(
//                 onPressed: () {
//                   setState(() {
//                     _controller.value.isPlaying
//                         ? _controller.pause()
//                         : _controller.play();
//                   });
//                 },
//                 child: Icon(
//                   _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
//                 ),
//               )
//               : null,
//     );
//   }
// }
