import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:readmore/readmore.dart';
import 'package:rwa_app/widgets/html_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ThreadDetailScreen extends StatefulWidget {
  final Map<String, dynamic> thread;
  final IO.Socket socket;

  const ThreadDetailScreen({
    super.key,
    required this.thread,
    required this.socket,
  });

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  late IO.Socket socket;
  final uuid = Uuid();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> replyKeys = {};
  bool isLiked = false;
  bool isDisliked = false;
  int likeCount = 0;
  int commentsCount = 0;
  String author = "";
  String description = "";
  String lastUpdated = "";
  List<Map<String, dynamic>> replies = [];
  bool isLoading = true;

  String? selectedCommentId;
  String? selectedCommentUsername;
  int dislikeCount = 0;
  String currentUserId = '';

  bool isSending = false;
  bool _isDescriptionExpanded = false;
  bool isMainReactionProcessing = false;

  @override
  void initState() {
    super.initState();
    print(const JsonEncoder.withIndent('  ').convert(widget.thread));

    socket = widget.socket;

    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        currentUserId = prefs.getString('id') ?? '';
      });
    });

    // Join forum room
    if (socket.connected) {
      socket.emit('joinForum', {'forumId': widget.thread['_id']});
      socket.emit('checkRooms');
    } else {
      socket.once('connect', (_) {
        socket.emit('joinForum', {'forumId': widget.thread['_id']});
        socket.emit('checkRooms');
      });
    }

    socket.on('commentAddToForum', (data) {
      if (!mounted) return;

      print("🆕Comment Added In Forum : $data");
      final comment = data['comment'];
      if (comment == null) return;

      Map<String, dynamic>? quotedParsed;
      final quoted = comment['quotedCommentedId'];
      if (quoted != null && quoted is Map && quoted.containsKey('username')) {
        quotedParsed = {
          "id": quoted['_id'] ?? '',
          "text": quoted['text'] ?? '',
          "username": quoted['username'] ?? 'Unknown',
          "createdAt": quoted['createdAt'] ?? '',
        };
      }

      setState(() {
        replies.insert(0, {
          "id": comment['_id'],
          "parentId": quotedParsed?['id'] ?? (quoted is String ? quoted : null),
          "quotedCommentedId": quotedParsed,
          "name": comment['username'] ?? 'Unknown',
          "time": timeAgo(comment['createdAt']),
          "text": comment['text'] ?? '',
          "isLiked": false,
          "likes": 0,
        });
        commentsCount += 1;
      });
    });

    socket.on('reactToForum', (data) async {
      if (!mounted) return;

      print('🔔 reactToForum received: $data');

      final updatedThreadId = data['forumId'];
      final reactorUserId = data['userId'];
      final action = data['action'];

      if (updatedThreadId != widget.thread['_id']) {
        print('⚠️ Reaction is for a different thread, ignoring');
        return;
      }

      if (reactorUserId == currentUserId) {
        print('👤 Reaction is from my user, skipping duplicate UI update.');
        return;
      }

      setState(() {
        if (action == 'Added') {
          likeCount += 1;

          if (dislikeCount > 0) {
            dislikeCount -= 1;
            print('✅ Removed dislike due to like switch from other user');
          }
        } else if (action == 'Remove') {
          likeCount = (likeCount - 1).clamp(0, double.infinity).toInt();
        } else if (action == 'Updated') {
          likeCount += 1;

          if (dislikeCount > 0) {
            dislikeCount -= 1;
            print(
              '✅ Removed dislike due to like switch from other user (Updated)',
            );
          }

          print('✅ Reaction updated from dislike to like');
        } else {
          print('⚠️ Unknown action: $action');
        }
        print('✅ Updated likes count to $likeCount for another user');
      });
    });

    socket.on('reactToForumDislike', (data) {
      if (!mounted) return;

      print('🔔 reactToForumDislike received: $data');

      final updatedThreadId = data['forumId'];
      final reactorUserId = data['userId'];
      final action = data['action'];

      if (updatedThreadId != widget.thread['_id']) return;

      setState(() {
        if (action == 'Added') {
          dislikeCount += 1;

          if (likeCount > 0) {
            likeCount -= 1;
            print('✅ Removed like due to dislike switch from other user');
          }

          if (reactorUserId == currentUserId) {
            isDisliked = true;

            if (isLiked) {
              isLiked = false;
              likeCount = (likeCount - 1).clamp(0, double.infinity).toInt();
            }
          }
        } else if (action == 'Remove') {
          dislikeCount = (dislikeCount - 1).clamp(0, double.infinity).toInt();

          if (reactorUserId == currentUserId) {
            isDisliked = false;
          }
        } else if (action == 'Updated') {
          dislikeCount += 1;

          if (likeCount > 0) {
            likeCount -= 1;
            print(
              '✅ Removed like due to dislike switch from other user (Updated)',
            );
          }

          print('✅ Reaction updated from like to dislike');
        } else {
          print('⚠️ Unknown action: $action');
        }
      });
    });

    socket.on('reactToComment', (data) async {
      if (!mounted) return;

      print('React Comment Like Socket $data');

      final commentId = data['commentId'];
      final reactorUserId = data['userId'];
      final action = data['action'];

      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId') ?? '';

      final index = replies.indexWhere((c) => c['id'] == commentId);
      if (index != -1) {
        setState(() {
          if (action == 'Added') {
            replies[index]['likes'] += 1;

            if (reactorUserId == currentUserId) {
              replies[index]['isLiked'] = true;

              // ✅ Remove dislike if previously disliked
              if (replies[index]['isDisliked']) {
                replies[index]['isDisliked'] = false;
                replies[index]['dislikes'] =
                    (replies[index]['dislikes'] - 1)
                        .clamp(0, double.infinity)
                        .toInt();
              }
            }
          } else if (action == 'Remove') {
            replies[index]['likes'] =
                (replies[index]['likes'] - 1).clamp(0, double.infinity).toInt();

            if (reactorUserId == currentUserId) {
              replies[index]['isLiked'] = false;
            }
          } else if (action == 'Updated') {
            replies[index]['likes'] += 1;

            // ✅ Always reduce dislike count since user switched from dislike to like
            replies[index]['dislikes'] =
                (replies[index]['dislikes'] - 1)
                    .clamp(0, double.infinity)
                    .toInt();

            if (reactorUserId == currentUserId) {
              replies[index]['isLiked'] = true;
              replies[index]['isDisliked'] = false;
            }
          }
        });
      }
    });

    socket.on('reactToCommentDislike', (data) async {
      if (!mounted) return;

      print('React Comment Dislike Socket $data');

      final commentId = data['commentId'];
      final reactorUserId = data['userId'];
      final action = data['action'];

      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId') ?? '';

      final index = replies.indexWhere((c) => c['id'] == commentId);
      if (index != -1) {
        setState(() {
          if (action == 'Added') {
            replies[index]['dislikes'] += 1;

            if (reactorUserId == currentUserId) {
              replies[index]['isDisliked'] = true;

              // ✅ Remove like if previously liked
              if (replies[index]['isLiked']) {
                replies[index]['isLiked'] = false;
                replies[index]['likes'] =
                    (replies[index]['likes'] - 1)
                        .clamp(0, double.infinity)
                        .toInt();
              }
            }
          } else if (action == 'Remove') {
            replies[index]['dislikes'] =
                (replies[index]['dislikes'] - 1)
                    .clamp(0, double.infinity)
                    .toInt();

            if (reactorUserId == currentUserId) {
              replies[index]['isDisliked'] = false;
            }
          } else if (action == 'Updated') {
            replies[index]['dislikes'] += 1;

            // ✅ Always reduce like count since user switched from like to dislike
            replies[index]['likes'] =
                (replies[index]['likes'] - 1).clamp(0, double.infinity).toInt();

            if (reactorUserId == currentUserId) {
              replies[index]['isDisliked'] = true;
              replies[index]['isLiked'] = false;
            }
          }
        });
      }
    });

    loadData();
  }

  @override
  void dispose() {
    socket.off('commentAddToForum');
    socket.off('reactToForum');
    socket.off('reactToForumDislike'); // ✅ Clean up dislike listener
    socket.off('reactToComment');

    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    await Future.wait([fetchThreadData(), fetchComments()]);
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchThreadData() async {
    final id = widget.thread['_id'];
    if (id == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = 'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/$id';

    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final forum = jsonResponse['forum'];
        print('🔎 Parsed Forum Data: $forum');

        int likeReactions = 0;
        int dislikeReactions = 0;

        if (forum['reactions'] != null) {
          final reactionsMap = forum['reactions'] as Map<String, dynamic>;
          likeReactions = reactionsMap['👍'] ?? 0;
          dislikeReactions = reactionsMap['👎'] ?? 0;
        }

        setState(() {
          isLiked = forum['isReact'] ?? false;
          isDisliked = forum['isDislike'] ?? false;
          likeCount = (forum['upvotes'] ?? 0) + likeReactions;
          dislikeCount = dislikeReactions;
          commentsCount = forum['commentsCount'] ?? 0;
          author = forum['userId']?['userName'] ?? 'Unknown';
          description = forum['text'] ?? '';
          lastUpdated = forum['createdAt'] ?? '';
        });
      } else {
        print(
          "❌ Failed to fetch thread: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      print("❌ Error fetching thread: $e");
    }
  }

  Future<void> fetchComments() async {
    final id = widget.thread['_id'];
    if (id == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/comment/forum/$id?page=&size=';

    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(Uri.parse(url), headers: headers);
      print("🔎 Full comments API response: ${response.body}");

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> comments = jsonResponse['comments'];

        setState(() {
          replies =
              comments.map((item) {
                final quoted = item['quotedCommentedId'];
                Map<String, dynamic>? quotedParsed;
                if (quoted != null &&
                    quoted is Map &&
                    quoted.containsKey('username')) {
                  quotedParsed = {
                    "id": quoted['_id'] ?? '',
                    "text": quoted['text'] ?? '',
                    "username": quoted['username'] ?? 'Unknown',
                    "createdAt": quoted['createdAt'] ?? '',
                  };
                }

                final reactions =
                    item['reactions'] as Map<String, dynamic>? ?? {};
                final likes = reactions['👍'] ?? 0;
                final dislikes = reactions['👎'] ?? 0;

                return {
                  "id": item['_id'],
                  "parentId": quotedParsed?['id'],
                  "quotedCommentedId": quotedParsed,
                  "name": item['username'] ?? 'Unknown',
                  "time": timeAgo(item['createdAt']),
                  "text": item['text'] ?? '',
                  "isLiked": item['isReact'] ?? false,
                  "likes": likes,
                  "isDisliked": item['isDislike'] ?? false,
                  "dislikes": dislikes,
                };
              }).toList();
        });
      } else {
        print("❌ Failed to fetch comments: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetching comments: $e");
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() {
      isSending = true; // show loading
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final username = prefs.getString('name') ?? '';

    final url = 'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/comment/add';
    final payload = {
      "forumId": widget.thread['_id'],
      "text": _replyController.text.trim(),
      "username": username,
      "quotedCommentId": selectedCommentId ?? "",
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        await fetchComments();
        setState(() {
          _replyController.clear(); // clear text
          selectedCommentId = null;
          selectedCommentUsername = null;
          FocusScope.of(context).unfocus(); // close keyboard
        });
      } else {
        print("❌ Failed to add comment: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send reply. Please try again.")),
        );
      }
    } catch (e) {
      print("❌ Error adding comment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending reply. Please try again.")),
      );
    } finally {
      setState(() {
        isSending = false; // hide loading
      });
    }
  }

  Future<bool> _ensureLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to use this feature.")),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.thread['title'] ?? 'Thread';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, {
          '_id': widget.thread['_id'],
          'isReact': isLiked,
          'likes': likeCount,
          'commentsCount': commentsCount,
          'isDislike': isDisliked, // ✅ added
          'dislikes': dislikeCount, // ✅ added
        });

        return false; // prevent default pop because we manually did it
      },

      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text(title)),
        body:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildMainPost(theme),
                          const SizedBox(height: 16),
                          Text(
                            "Discussions",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (replies.isEmpty)
                            SizedBox(
                              height:
                                  MediaQuery.of(context).size.height *
                                  0.45, // adjust as needed
                              child: Center(
                                child: Text(
                                  'No discussions yet.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            )
                          else
                            ...replies.asMap().entries.map((entry) {
                              final index = entry.key;
                              final reply = entry.value;
                              return GestureDetector(
                                onLongPress: () {
                                  setState(() {
                                    selectedCommentId = reply['id'];
                                    selectedCommentUsername = reply['name'];
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        selectedCommentId == reply['id']
                                            ? theme.primaryColor.withOpacity(
                                              0.2,
                                            )
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: _buildReplyCard(reply, theme, index),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                    if (selectedCommentUsername != null)
                      Container(
                        color: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Replying to $selectedCommentUsername',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setState(() {
                                  selectedCommentId = null;
                                  selectedCommentUsername = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    _buildReplyInput(theme),
                  ],
                ),
      ),
    );
  }

  Widget _buildMainPost(ThemeData theme) {
    return Card(
      elevation: 0.02,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.thread['title'] ?? '',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 6),
            HtmlPreviewWithToggle(
              html: description,
              isExpanded: _isDescriptionExpanded,
              onToggle: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
            ),

            const SizedBox(height: 8),
            Text(
              "- $author",
              style: GoogleFonts.inter(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // LIKE BUTTON
                InkWell(
                  onTap: () async {
                    if (await _ensureLoggedIn()) _toggleMainPostLike();
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.thumb_up,
                        size: 18,
                        color: isLiked ? Colors.blue : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$likeCount',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isLiked ? Colors.blue : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // DISLIKE BUTTON
                InkWell(
                  onTap: () async {
                    if (await _ensureLoggedIn()) _toggleMainPostDislike();
                  },

                  child: Row(
                    children: [
                      Icon(
                        Icons.thumb_down,
                        size: 18,
                        color: isDisliked ? Colors.red : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$dislikeCount',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDisliked ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Comments
                Icon(
                  Icons.mode_comment_outlined,
                  size: 18,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 4),
                Text(
                  '$commentsCount',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Text(
                  timeAgo(lastUpdated),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyCard(
    Map<String, dynamic> reply,
    ThemeData theme,
    int index,
  ) {
    final likes = reply['likes'] as int;
    final dislikes = reply['dislikes'] as int? ?? 0; // ✅ Added dislikes
    final quoted = reply['quotedCommentedId'];

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final currentUsername = snapshot.data!.getString('name') ?? '';

        return Card(
          elevation: 0.02,
          key: replyKeys[reply['id']],
          color: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (quoted != null) ...[
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: theme.primaryColor,
                                    width: 3,
                                  ),
                                ),
                                color: theme.cardColor.withOpacity(0.05),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quoted['text'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    quoted['createdAt'] != null &&
                                            quoted['createdAt']
                                                .toString()
                                                .isNotEmpty
                                        ? "- ${quoted['username']} • ${timeAgo(quoted['createdAt'])}"
                                        : "- ${quoted['username']}",
                                    style: GoogleFonts.inter(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 11,
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            reply['text'],
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '- ${reply['name']}',
                            style: GoogleFonts.inter(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        if (await _ensureLoggedIn()) _toggleReplyLike(index);
                      },

                      child: Row(
                        children: [
                          Icon(
                            reply['isLiked']
                                ? Icons.thumb_up
                                : Icons.thumb_up_alt_outlined,
                            size: 18,
                            color:
                                reply['isLiked']
                                    ? Colors.blue
                                    : Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reply['likes']}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  reply['isLiked']
                                      ? Colors.blue
                                      : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    InkWell(
                      onTap: () async {
                        if (await _ensureLoggedIn()) _toggleReplyDislike(index);
                      },

                      child: Row(
                        children: [
                          Icon(
                            reply['isDisliked'] == true
                                ? Icons.thumb_down
                                : Icons.thumb_down_alt_outlined,
                            size: 18,
                            color:
                                reply['isDisliked'] == true
                                    ? Colors.red
                                    : Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$dislikes',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  reply['isDisliked'] == true
                                      ? Colors.red
                                      : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      reply['time'],
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _replyController,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                decoration: InputDecoration(
                  hintText: "Write a reply...",
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.hintColor,
                  ),
                  border: InputBorder.none,
                ),
                minLines: 1,
                maxLines: 10, // ✅ allows expansion up to 5 lines
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: isSending ? Colors.grey : theme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon:
                  isSending
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                      : Icon(Icons.send, color: theme.colorScheme.onPrimary),
              onPressed:
                  isSending
                      ? null
                      : () async {
                        if (await _ensureLoggedIn()) _sendReply();
                      },
            ),
          ),
        ],
      ),
    );
  }

  String timeAgo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "Unknown";
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 8) return '${date.day}/${date.month}/${date.year}';
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      print("Invalid date format: $dateString");
      return "Unknown";
    }
  }

  Future<void> _toggleReplyLike(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final commentId = replies[index]['id'];

    final categoryIdRaw = widget.thread['categoryId'];
    final categoryId =
        categoryIdRaw is String
            ? categoryIdRaw
            : (categoryIdRaw is Map ? categoryIdRaw['_id'] : null);

    final url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/comment/react';
    final payload = {
      "commentId": commentId,
      "categoryId": categoryId,
      "emoji": "",
    };

    print(payload);

    // Optimistic UI update with mutual exclusivity
    setState(() {
      if (replies[index]['isLiked']) {
        replies[index]['isLiked'] = false;
        replies[index]['likes'] -= 1;
      } else {
        replies[index]['isLiked'] = true;
        replies[index]['likes'] += 1;

        // ✅ If previously disliked, remove dislike
        if (replies[index]['isDisliked']) {
          replies[index]['isDisliked'] = false;
          replies[index]['dislikes'] =
              (replies[index]['dislikes'] - 1)
                  .clamp(0, double.infinity)
                  .toInt();
        }
      }
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        print("✅ Reaction added");
      } else if (response.statusCode == 200) {
        print("✅ Reaction removed");
      } else {
        print("❌ Failed to react to comment: ${response.body}");
        // Revert optimistic UI on failure
        setState(() {
          if (replies[index]['isLiked']) {
            replies[index]['isLiked'] = false;
            replies[index]['likes'] -= 1;
          } else {
            replies[index]['isLiked'] = true;
            replies[index]['likes'] += 1;
          }
        });
      }
    } catch (e) {
      print("❌ Error reacting to comment: $e");
      // Revert optimistic UI on error
      setState(() {
        if (replies[index]['isLiked']) {
          replies[index]['isLiked'] = false;
          replies[index]['likes'] -= 1;
        } else {
          replies[index]['isLiked'] = true;
          replies[index]['likes'] += 1;
        }
      });
    }
  }

  Future<void> _toggleReplyDislike(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final commentId = replies[index]['id'];

    final categoryIdRaw = widget.thread['categoryId'];
    final categoryId =
        categoryIdRaw is String
            ? categoryIdRaw
            : (categoryIdRaw is Map ? categoryIdRaw['_id'] : null);

    final url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/comment/react/dislike';
    final payload = {
      "commentId": commentId,
      "categoryId": categoryId,
      "emoji": "👎",
    };

    print(payload);

    // Optimistic UI update with mutual exclusivity
    setState(() {
      if (replies[index]['isDisliked']) {
        replies[index]['isDisliked'] = false;
        replies[index]['dislikes'] =
            (replies[index]['dislikes'] - 1).clamp(0, double.infinity).toInt();
      } else {
        replies[index]['isDisliked'] = true;
        replies[index]['dislikes'] += 1;

        // ✅ If previously liked, remove like
        if (replies[index]['isLiked']) {
          replies[index]['isLiked'] = false;
          replies[index]['likes'] =
              (replies[index]['likes'] - 1).clamp(0, double.infinity).toInt();
        }
      }
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Comment dislike toggled");
      } else {
        print("❌ Failed to dislike comment: ${response.body}");
        // Revert optimistic UI on failure
        setState(() {
          if (replies[index]['isDisliked']) {
            replies[index]['isDisliked'] = false;
            replies[index]['dislikes'] =
                (replies[index]['dislikes'] - 1)
                    .clamp(0, double.infinity)
                    .toInt();
          } else {
            replies[index]['isDisliked'] = true;
            replies[index]['dislikes'] += 1;
          }
        });
      }
    } catch (e) {
      print("❌ Error disliking comment: $e");
      // Revert optimistic UI on error
      setState(() {
        if (replies[index]['isDisliked']) {
          replies[index]['isDisliked'] = false;
          replies[index]['dislikes'] =
              (replies[index]['dislikes'] - 1)
                  .clamp(0, double.infinity)
                  .toInt();
        } else {
          replies[index]['isDisliked'] = true;
          replies[index]['dislikes'] += 1;
        }
      });
    }
  }

  Future<void> _toggleMainPostLike() async {
    if (isMainReactionProcessing) return; // prevent multiple taps
    isMainReactionProcessing = true;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final forumId = widget.thread['_id'];

    final url = 'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react';
    final payload = {"forumId": forumId, "emoji": ""};

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        setState(() {
          isLiked = true;
          likeCount = 1; // max 1
          if (isDisliked) {
            isDisliked = false;
            dislikeCount = 0;
          }
        });
      } else if (response.statusCode == 200) {
        setState(() {
          isLiked = false;
          likeCount = 0;
        });
      } else {
        print("❌ Failed to react to forum: ${response.body}");
      }
    } catch (e) {
      print("❌ Error reacting to forum: $e");
    } finally {
      isMainReactionProcessing = false;
    }
  }

  Future<void> _toggleMainPostDislike() async {
    if (isMainReactionProcessing) return;
    isMainReactionProcessing = true;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final forumId = widget.thread['_id'];

    final url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react/dislike';
    final payload = {"forumId": forumId, "emoji": "👎"};

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        setState(() {
          isDisliked = true;
          dislikeCount = 1;
          if (isLiked) {
            isLiked = false;
            likeCount = 0;
          }
        });
      } else if (response.statusCode == 200) {
        setState(() {
          isDisliked = false;
          dislikeCount = 0;
        });
      } else {
        print("❌ Failed to dislike forum: ${response.body}");
      }
    } catch (e) {
      print("❌ Error disliking forum: $e");
    } finally {
      isMainReactionProcessing = false;
    }
  }
}
