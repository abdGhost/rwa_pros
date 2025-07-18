import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class PodcastPlayerScreen extends StatefulWidget {
  final String youtubeUrl;

  const PodcastPlayerScreen({super.key, required this.youtubeUrl});

  @override
  State<PodcastPlayerScreen> createState() => _PodcastPlayerScreenState();
}

class _PodcastPlayerScreenState extends State<PodcastPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    // Force landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final videoId =
        YoutubePlayerController.convertUrlToId(widget.youtubeUrl) ?? '';

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false, // ✅ Hide fullscreen button
        enableCaption: false,
        playsInline: false,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    // Restore portrait mode on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controller.close();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    Navigator.of(context).pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            YoutubePlayerScaffold(
              controller: _controller,
              builder: (context, player) {
                return Center(
                  child: AspectRatio(aspectRatio: 16 / 9, child: player),
                );
              },
            ),
            Positioned(
              top: 24,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _handleBack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
