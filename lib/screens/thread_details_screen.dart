import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:readmore/readmore.dart';
import 'package:rwa_app/widgets/html_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

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
  Map<String, DateTime> tapTimestamps = {};
  // Track ops started from THIS device so we don't double-apply our own echo
  final Set<String> inflightForumLike = {};
  final Set<String> inflightForumDislike = {};
  Timer? _countsDebounce;

  bool _loaded = false; // becomes true after initial load
  bool _dirty = false; // becomes true if anything changed here

  @override
  void dispose() {
    _countsDebounce?.cancel(); // 👈 add this
    socket.off('commentAddToForum');
    socket.off('reactToForum');
    socket.off('reactToForumDislike');
    socket.off('reactToComment');
    socket.off('reactToCommentDislike');
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleCountsRefresh() {
    _countsDebounce?.cancel();
    _countsDebounce = Timer(const Duration(milliseconds: 150), () async {
      // Reuse your existing loader; it sets isLiked/isDisliked/likeCount/dislikeCount from server.
      await fetchThreadData();
      if (mounted) {
        setState(() {}); // ensure rebuild with canonical values
      }
    });
  }

  @override
  void initState() {
    super.initState();
    print(const JsonEncoder.withIndent('  ').convert(widget.thread));

    socket = widget.socket;

    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        currentUserId = prefs.getString('userId') ?? ''; // ✅ Correct key
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
          "createdAt":
              comment['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
          "text": comment['text'] ?? '',
          "isLiked": false,
          "likes": 0,
        });
        commentsCount += 1;
        _dirty = true;
      });
    });

    // 👍 LIKE
    socket.on('reactToForum', (data) async {
      if (!mounted) return;
      final threadId = data['forumId'];
      if (threadId != widget.thread['_id']) return;

      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('userId') ?? '';
      final fromMe = (data['userId'] == myId);

      // Did this reaction start on THIS device?
      final startedHere =
          inflightForumLike.contains(threadId) ||
          inflightForumDislike.contains(threadId);

      final reactions =
          (data['reactions'] as Map?)?.cast<String, dynamic>() ?? const {};
      final upvotes = (data['upvotes'] as int?) ?? 0;
      final action = data['action'] as String?;

      setState(() {
        if (reactions.isNotEmpty) {
          // Canonical snapshot → snap counts deterministically
          likeCount =
              (upvotes + (reactions['👍'] ?? 0))
                  .clamp(0, double.infinity)
                  .toInt();
          dislikeCount =
              ((reactions['👎'] ?? 0)).clamp(0, double.infinity).toInt();

          // Keep toggles consistent if it was my action from another device
          if (fromMe && !startedHere) {
            isLiked = true;
            isDisliked = false;
          }
          _dirty = true;
        } else {
          // No snapshot in event → don’t guess counts (avoid double math)
          // We already toggled color locally in the tap handler.
          _scheduleCountsRefresh();
        }
      });
    });

    // 👎 DISLIKE
    socket.on('reactToForumDislike', (data) async {
      if (!mounted) return;
      final threadId = data['forumId'];
      if (threadId != widget.thread['_id']) return;

      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('userId') ?? '';
      final fromMe = (data['userId'] == myId);

      final startedHere =
          inflightForumLike.contains(threadId) ||
          inflightForumDislike.contains(threadId);

      final reactions =
          (data['reactions'] as Map?)?.cast<String, dynamic>() ?? const {};
      final upvotes = (data['upvotes'] as int?) ?? 0;
      final action = data['action'] as String?;

      setState(() {
        if (reactions.isNotEmpty) {
          likeCount =
              (upvotes + (reactions['👍'] ?? 0))
                  .clamp(0, double.infinity)
                  .toInt();
          dislikeCount =
              ((reactions['👎'] ?? 0)).clamp(0, double.infinity).toInt();
          if (fromMe && !startedHere) {
            isDisliked = true;
            isLiked = false;
          }
          _dirty = true;
        } else {
          _scheduleCountsRefresh();
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
      final isMyAction = reactorUserId == currentUserId;

      final index = replies.indexWhere((c) => c['id'] == commentId);
      if (index != -1) {
        setState(() {
          if (action == 'Added') {
            replies[index]['likes'] += 1;
            if (isMyAction) {
              replies[index]['isLiked'] = true;

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
            if (isMyAction) {
              replies[index]['isLiked'] = false;
            }
          } else if (action == 'Updated') {
            replies[index]['likes'] += 1;
            replies[index]['dislikes'] =
                (replies[index]['dislikes'] - 1)
                    .clamp(0, double.infinity)
                    .toInt();
            if (isMyAction) {
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
      final isMyAction = reactorUserId == currentUserId;

      final index = replies.indexWhere((c) => c['id'] == commentId);
      if (index != -1) {
        setState(() {
          if (action == 'Added') {
            replies[index]['dislikes'] += 1;
            if (isMyAction) {
              replies[index]['isDisliked'] = true;

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
            if (isMyAction) {
              replies[index]['isDisliked'] = false;
            }
          } else if (action == 'Updated') {
            replies[index]['dislikes'] += 1;
            replies[index]['likes'] =
                (replies[index]['likes'] - 1).clamp(0, double.infinity).toInt();
            if (isMyAction) {
              replies[index]['isDisliked'] = true;
              replies[index]['isLiked'] = false;
            }
          }
        });
      }
    });

    loadData();
  }

  Future<void> loadData() async {
    await Future.wait([fetchThreadData(), fetchComments()]);
    setState(() {
      isLoading = false;
      _loaded = true;
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
                  "createdAt": item['createdAt'],
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
      "subCategoryId": widget.thread['subCategoryId'],
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

  bool canTap(String key) {
    final now = DateTime.now();
    final lastTap = tapTimestamps[key];

    if (lastTap != null && now.difference(lastTap) < Duration(seconds: 1)) {
      return false;
    }

    tapTimestamps[key] = now;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.thread['title'] ?? 'Thread';
    print(
      '🔢 UI Rebuilding with likeCount = $likeCount and isLiked = $isLiked',
    );

    return WillPopScope(
      onWillPop: () async {
        if (_loaded && _dirty) {
          Navigator.pop(context, {
            '_id': widget.thread['_id'],
            'isReact': isLiked,
            'likes': likeCount,
            'commentsCount': commentsCount,
            'isDislike': isDisliked,
            'dislikes': dislikeCount,
          });
        } else {
          Navigator.pop(context, null);
        }
        return false;
      },

      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text(title)),
        body:
            isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFEBB411)),
                )
                : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        // padding: const EdgeInsets.all(12),
                        children: [
                          _buildMainPost(theme),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              "Discussions",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onBackground,
                              ),
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
                                            ? const Color(
                                              0xFFEBB411,
                                            ).withOpacity(
                                              0.1,
                                            ) // Optional background highlight
                                            : Colors.transparent,
                                    border: Border.all(
                                      color:
                                          selectedCommentId == reply['id']
                                              ? const Color(0xFFEBB411)
                                              : Colors.transparent,
                                      width:
                                          selectedCommentId == reply['id']
                                              ? .4
                                              : 0.0, // Change width here
                                    ),
                                  ),
                                  child: _buildReplyCard(reply, theme, index),
                                ),

                                // child: Container(
                                //   decoration: BoxDecoration(
                                //     color:
                                //         selectedCommentId == reply['id']
                                //             ? Color(0xFFEBB411)
                                //             : Colors.transparent,
                                //     // borderRadius: BorderRadius.circular(4),
                                //   ),
                                //   child: _buildReplyCard(reply, theme, index),
                                // ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                    if (selectedCommentUsername != null)
                      Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Replying to $selectedCommentUsername',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: Theme.of(context).iconTheme.color,
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
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFEBB411), width: .4),
          bottom: BorderSide(color: Color(0xFFEBB411), width: .4),
        ),
      ),
      child: Card(
        elevation: 0.02,
        color: theme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  widget.thread['title'] ?? '',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Description (collapsible)
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

              // Author
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  "- $author",
                  style: GoogleFonts.inter(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Reactions + meta
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    // LIKE
                    InkWell(
                      onTap: () async {
                        if (isMainReactionProcessing) return;
                        if (await _ensureLoggedIn()) _toggleMainPostLike();
                      },
                      child: Row(
                        children: [
                          Icon(
                            isLiked
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined, // filled when active
                            size: 18,
                            color:
                                isLiked
                                    ? const Color(0xFFEBB411)
                                    : Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likeCount',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  isLiked
                                      ? const Color(0xFFEBB411)
                                      : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // DISLIKE
                    InkWell(
                      onTap: () async {
                        if (isMainReactionProcessing) return;
                        if (await _ensureLoggedIn()) _toggleMainPostDislike();
                      },
                      child: Row(
                        children: [
                          Icon(
                            isDisliked
                                ? Icons.thumb_down
                                : Icons
                                    .thumb_down_outlined, // filled when active
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

                    // COMMENTS
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

                    // Time
                    Text(
                      _timestampLabelNoTZ(
                        lastUpdated,
                      ), // was: timeAgo(lastUpdated)
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 12,
              bottom: 12,
              top: 12,
            ),
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
                                ? Icons.thumb_up_outlined
                                : Icons.thumb_up_alt_outlined,
                            size: 18,
                            color:
                                reply['isLiked']
                                    ? Color(0xFFEBB411)
                                    : Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reply['likes']}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  reply['isLiked']
                                      ? Color(0xFFEBB411)
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
                                ? Icons.thumb_down_outlined
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
                      _timestampLabelNoTZ(reply['createdAt']),

                      // _timestampLabel(reply['createdAt']), // was: reply['time']
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
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Icon(Icons.send, color: Colors.white),
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
    if (!canTap('replyLike_$index')) return;

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
      "subCategoryId": widget.thread['subCategoryId'],
    };

    print(payload);

    // Optimistic UI update
    setState(() {
      if (replies[index]['isLiked'] == true) {
        replies[index]['isLiked'] = false;
        replies[index]['likes'] = (replies[index]['likes'] ?? 1) - 1;
      } else {
        replies[index]['isLiked'] = true;
        replies[index]['likes'] = (replies[index]['likes'] ?? 0) + 1;

        if (replies[index]['isDisliked'] == true) {
          replies[index]['isDisliked'] = false;
          replies[index]['dislikes'] =
              ((replies[index]['dislikes'] ?? 1) - 1)
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
        print("❌ Failed to react: ${response.body}");
        _revertLikeState(index);
      }
    } catch (e) {
      print("❌ Error reacting: $e");
      _revertLikeState(index);
    }
  }

  void _revertLikeState(int index) {
    setState(() {
      if (replies[index]['isLiked'] == true) {
        replies[index]['isLiked'] = false;
        replies[index]['likes'] = (replies[index]['likes'] ?? 1) - 1;
      } else {
        replies[index]['isLiked'] = true;
        replies[index]['likes'] = (replies[index]['likes'] ?? 0) + 1;
      }
    });
  }

  Future<void> _toggleReplyDislike(int index) async {
    if (!canTap('replyDislike_$index')) return;

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
      "subCategoryId": widget.thread['subCategoryId'],
    };

    print(payload);

    // Optimistic UI update
    setState(() {
      if (replies[index]['isDisliked'] == true) {
        replies[index]['isDisliked'] = false;
        replies[index]['dislikes'] =
            ((replies[index]['dislikes'] ?? 1) - 1)
                .clamp(0, double.infinity)
                .toInt();
      } else {
        replies[index]['isDisliked'] = true;
        replies[index]['dislikes'] = (replies[index]['dislikes'] ?? 0) + 1;

        if (replies[index]['isLiked'] == true) {
          replies[index]['isLiked'] = false;
          replies[index]['likes'] =
              ((replies[index]['likes'] ?? 1) - 1)
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

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Comment dislike toggled");
      } else {
        print("❌ Failed to dislike: ${response.body}");
        _revertDislikeState(index);
      }
    } catch (e) {
      print("❌ Error disliking: $e");
      _revertDislikeState(index);
    }
  }

  void _revertDislikeState(int index) {
    setState(() {
      if (replies[index]['isDisliked'] == true) {
        replies[index]['isDisliked'] = false;
        replies[index]['dislikes'] =
            ((replies[index]['dislikes'] ?? 1) - 1)
                .clamp(0, double.infinity)
                .toInt();
      } else {
        replies[index]['isDisliked'] = true;
        replies[index]['dislikes'] = (replies[index]['dislikes'] ?? 0) + 1;
      }
    });
  }

  Future<void> _toggleMainPostLike() async {
    if (isMainReactionProcessing || !canTap('mainLike')) return;
    isMainReactionProcessing = true;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final forumId = widget.thread['_id'];

    final catRaw = widget.thread['categoryId'];
    final categoryId =
        catRaw is String ? catRaw : (catRaw is Map ? catRaw['_id'] : null);

    final url = 'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react';
    final payload = {
      "forumId": forumId,
      "emoji": "",
      "subCategoryId": widget.thread['subCategoryId'],
      "categoryId": categoryId,
    };

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      // no local UI changes here! (color stays as-is)
      // Optional fallback if socket is slow: fetch snapshot once to update both together
      if (res.statusCode == 200 || res.statusCode == 201) {
        // await fetchThreadData(); // <-- enable if you want an HTTP fallback
      }
    } catch (_) {
      // no-op; keep UI unchanged
    } finally {
      isMainReactionProcessing = false;
      if (mounted) setState(() {}); // re-enable taps
    }
  }

  Future<void> _toggleMainPostDislike() async {
    if (isMainReactionProcessing || !canTap('mainDislike')) return;
    isMainReactionProcessing = true;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final forumId = widget.thread['_id'];

    final catRaw = widget.thread['categoryId'];
    final categoryId =
        catRaw is String ? catRaw : (catRaw is Map ? catRaw['_id'] : null);

    final url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react/dislike';
    final payload = {
      "forumId": forumId,
      "emoji": "👎",
      "subCategoryId": widget.thread['subCategoryId'],
      "categoryId": categoryId,
    };

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      // no local UI changes here
      // Optional fallback:
      if (res.statusCode == 200 || res.statusCode == 201) {
        // await fetchThreadData(); // <-- enable if you want an HTTP fallback
      }
    } catch (_) {
      // no-op
    } finally {
      isMainReactionProcessing = false;
      if (mounted) setState(() {});
    }
  }

  String _tzOffsetLabel(Duration off) {
    final sign = off.isNegative ? '-' : '+';
    final abs = off.abs();
    final hh = abs.inHours.toString().padLeft(2, '0');
    final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hh:$mm';
  }

  /// Absolute local timestamp like: "Sep 5, 2025 • 12:40 PM UTC+05:30"
  String _absoluteLocal(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final date = DateFormat('MMM d, yyyy').format(dt);
      final time = DateFormat('h:mm a').format(dt);
      final tz = _tzOffsetLabel(dt.timeZoneOffset);
      return '$date • $time $tz';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Final label to render under comments:
  /// - For recent: "12m ago • 12:28 PM"
  /// - For older:  "Aug 12, 2025 • 4:03 PM UTC+05:30" (timeAgo returns a date, we still add exact clock)
  String _timestampLabel(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    final ago = timeAgo(iso); // your existing relative formatter
    final abs = _absoluteLocal(iso);

    // If "ago" is already a date (for > 8 days in your current logic),
    // just use the absolute label to avoid repeating date twice.
    final looksLikeDate =
        ago.contains('/') || ago.contains(',') || ago.contains('20');
    if (looksLikeDate) return abs;

    // Otherwise show both relative and exact time (compact).
    // Example: "2h ago • 3:14 PM"
    try {
      final dt = DateTime.parse(iso).toLocal();
      final tm = DateFormat('h:mm a').format(dt);
      return '$ago • $tm';
    } catch (_) {
      return abs;
    }
  }

  String _absoluteLocalNoTZ(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final date = DateFormat('MMM d, yyyy').format(dt);
      final time = DateFormat('h:mm a').format(dt);
      return '$date • $time'; // <- no timezone
    } catch (_) {
      return 'Unknown';
    }
  }

  String _timestampLabelNoTZ(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    final ago = timeAgo(iso);

    // In your logic, timeAgo returns a date string (like 5/9/2025) for > 8 days.
    final looksLikeDate =
        ago.contains('/') || ago.contains(',') || ago.contains('20');

    if (looksLikeDate) {
      // Older → absolute date + time (no TZ)
      return _absoluteLocalNoTZ(iso);
    }

    // Recent → "2h ago • 3:14 PM" (no TZ)
    try {
      final dt = DateTime.parse(iso).toLocal();
      final tm = DateFormat('h:mm a').format(dt);
      return '$ago • $tm';
    } catch (_) {
      return _absoluteLocalNoTZ(iso);
    }
  }
}
