import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoPlayerModal extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerModal({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<VideoPlayerModal> {
  late YoutubePlayerController _controller;
  bool _isValid = true;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();

    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    if (videoId == null) {
      _isValid = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid YouTube video URL')),
        );
      });
      return;
    }

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        controlsVisibleAtStart: true,
        hideControls: false,
        disableDragSeek: false,
      ),
    )..addListener(() {
      if (!_isPlayerReady && _controller.value.isReady) {
        setState(() => _isPlayerReady = true);
      }
    });
  }

  @override
  void dispose() {
    if (_isValid) {
      _controller.pause();
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValid) return const SizedBox();

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: false,
        progressColors: ProgressBarColors(
          playedColor: const Color(0xFF348F6C),
          handleColor: const Color(0xFF348F6C),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.grey,
        ),
        bottomActions: [
          CurrentPosition(),
          ProgressBar(isExpanded: true),
          RemainingDuration(),
          const PlaybackSpeedButton(),
          FullScreenButton(), // ✅ Add fullscreen toggle button
        ],
        topActions: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
      builder:
          (context, player) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              elevation: 0,
            ),
            body: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: _isPlayerReady ? 1 : 0, child: player),
                if (!_isPlayerReady)
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0087E0),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
