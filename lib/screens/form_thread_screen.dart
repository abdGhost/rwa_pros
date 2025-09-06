import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:rwa_app/screens/add_thread_screen.dart';
import 'package:rwa_app/screens/profile/new_profile.dart';
import 'package:rwa_app/screens/thread_details_screen.dart';

class ForumThreadScreen extends StatefulWidget {
  final Map<String, dynamic> forumData;

  const ForumThreadScreen({super.key, required this.forumData});

  @override
  State<ForumThreadScreen> createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends State<ForumThreadScreen>
    with WidgetsBindingObserver {
  // --- state ---
  List<Map<String, dynamic>> threads = [];
  List<bool> likedList = [];
  List<bool> dislikedList = [];
  bool isLoading = true;

  String token = '';
  String userId = '';

  late IO.Socket socket;

  // exact handlers (so we can detach precisely ours)
  void Function(dynamic)? _hForumAdded;
  void Function(dynamic)? _hReactToForum;
  void Function(dynamic)? _hReactToForumDislike;
  void Function(dynamic)? _hCommentAdded;

  // optimistic control/click throttle
  final Set<String> inflightLike = {};
  final Set<String> inflightDislike = {};
  final Map<int, DateTime> _tapTimestamps = {};

  // details / echo control
  bool _inDetails = false;
  final Map<String, DateTime> _selfEchoMuteUntil = {};

  // --- logging helper ---
  void _log(String msg) {
    debugPrint('[ForumThread] ${DateTime.now().toIso8601String()} | $msg');
  }

  bool _shouldMuteSelf(String threadId) {
    final until = _selfEchoMuteUntil[threadId];
    return until != null && DateTime.now().isBefore(until);
  }

  void _muteSelfEchoFor(String threadId, {int ms = 1500}) {
    _selfEchoMuteUntil[threadId] = DateTime.now().add(
      Duration(milliseconds: ms),
    );
  }

  bool _canTap(int index) {
    final now = DateTime.now();
    final last = _tapTimestamps[index];
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 800)) {
      return false;
    }
    _tapTimestamps[index] = now;
    return true;
  }

  // --- lifecycle ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachSocketListeners();
    try {
      socket.disconnect();
      socket.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _log('APP RESUMED');
      // Recreate to be bulletproof if backgrounded and other views touched listeners
      _forceRecreateSocket();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? '';
    userId = prefs.getString('userId') ?? '';
    _log(
      'Loaded token=${token.isNotEmpty ? "eyJ***" : "<empty>"} userId=${userId.isNotEmpty ? userId.substring(0, 3) + "***" : "<empty>"}',
    );

    await _fetchThreads();
    _initSocket();
  }

  // --- socket setup ---
  void _initSocket() {
    final cat = widget.forumData['categoryId'];
    final sub = widget.forumData['subCategoryId'];
    _log(
      'INIT SOCKET -> https://rwa-f1623a22e3ed.herokuapp.com (cat=$cat sub=$sub)',
    );

    final opts = <String, dynamic>{
      'transports': ['websocket'],
      'query': {'token': token},
      'reconnection': true,
      'reconnectionAttempts': 15,
      'reconnectionDelay': 500,
      'reconnectionDelayMax': 4000,
      'autoConnect': true,
    };

    socket = IO.io('https://rwa-f1623a22e3ed.herokuapp.com', opts);

    socket.onConnect((_) {
      _log('CONNECT: id=${socket.id} connected=${socket.connected}');
      _log('onConnect -> join rooms & bind listeners');
      _joinRooms();
      _detachSocketListeners();
      _attachSocketListeners();
    });

    socket.onReconnect((_) {
      _log('RECONNECT: id=${socket.id} connected=${socket.connected}');
      _joinRooms();
      _detachSocketListeners();
      _attachSocketListeners();
    });

    socket.onDisconnect((reason) {
      _log('DISCONNECT: reason=$reason');
    });

    socket.onConnectError((err) {
      _log('CONNECT_ERROR: $err');
    });

    socket.onError((err) {
      _log('ERROR: $err');
    });

    // Attempt cycles
    socket.on('reconnect_attempt', (_) => _log('RECONNECT_ATTEMPT'));
    socket.on('reconnect_error', (e) => _log('RECONNECT_ERROR: $e'));
    socket.on('reconnect_failed', (_) => _log('RECONNECT_FAILED'));

    if (!socket.connected) {
      _log('connect() called (connected=${socket.connected})');
      socket.connect();
    }
  }

  // ALWAYS rebuild a fresh socket (defensive against other screens calling off())
  void _forceRecreateSocket() {
    _log('forceRecreateSocket()');
    try {
      _detachSocketListeners();
      socket.disconnect();
      socket.dispose();
    } catch (_) {}
    _initSocket();
  }

  // emitWithAck if available; fallback to emit
  void _emitWithAckOrEmit(String event, Map data) {
    try {
      // ignore: invalid_use_of_visible_for_testing_member
      socket.emitWithAck(
        event,
        data,
        ack: (ackData) {
          _log('ACK $event: $ackData');
        },
      );
      _log('emitWithAck $event: $data');
    } catch (_) {
      socket.emit(event, data);
      _log('emit $event: $data');
    }
  }

  void _joinRooms() {
    _emitWithAckOrEmit('joinCategory', {
      'categoryId': widget.forumData['categoryId'],
    });
    _emitWithAckOrEmit('joinSubCategory', {
      'subCategoryId': widget.forumData['subCategoryId'],
    });
  }

  void _attachSocketListeners() {
    _log('Listeners ATTACHED');

    _hForumAdded = (data) {
      final reactions =
          (data['reactions'] as Map?)?.cast<String, dynamic>() ?? const {};
      final userObj =
          (data['userId'] is Map)
              ? (data['userId'] as Map).cast<String, dynamic>()
              : null;

      setState(() {
        threads.insert(0, {
          '_id': data['_id'] ?? '',
          'title': data['title'] ?? '',
          'description': data['text'] ?? '',
          'author': userObj?['userName'] ?? 'Unknown',
          'userId': userObj?['_id'] ?? '',
          'profileImage': userObj?['profileImage'] ?? '',
          'replies': data['commentsCount'] ?? 0,
          'likes': (data['upvotes'] ?? 0) + (reactions['👍'] ?? 0),
          'dislikes': (reactions['👎'] ?? 0),
          'createdAt': data['createdAt'] ?? '',
          'isReact': data['isReact'] ?? false,
          'isDislike': data['isDislike'] ?? false,
        });
        likedList.insert(0, data['isReact'] ?? false);
        dislikedList.insert(0, data['isDislike'] ?? false);
      });
    };
    socket.on('forumAdded', _hForumAdded!);

    _hReactToForum = (data) {
      final threadId = data['forumId'];
      final reactorUserId = data['userId'];
      final action = data['action']; // Added | Remove | Updated

      final index = threads.indexWhere((t) => t['_id'] == threadId);
      if (index == -1) return;

      final fromMe = reactorUserId == userId;
      final startedHere =
          inflightLike.contains(threadId) || inflightDislike.contains(threadId);

      if (fromMe && (_inDetails || startedHere || _shouldMuteSelf(threadId))) {
        _log('reactToForum (skip self-echo) action=$action thread=$threadId');
        return;
      }

      setState(() {
        final currLikes = (threads[index]['likes'] ?? 0) as int;
        final currDislikes = (threads[index]['dislikes'] ?? 0) as int;

        if (action == 'Added') {
          threads[index]['likes'] = currLikes + 1;
          if (fromMe && !startedHere) likedList[index] = true;
        } else if (action == 'Remove') {
          threads[index]['likes'] = max(0, currLikes - 1);
          if (fromMe && !startedHere) likedList[index] = false;
        } else if (action == 'Updated') {
          // dislike → like
          threads[index]['likes'] = currLikes + 1;
          if (currDislikes > 0) threads[index]['dislikes'] = currDislikes - 1;
          if (fromMe && !startedHere) {
            likedList[index] = true;
            dislikedList[index] = false;
          }
        }
      });
    };
    socket.on('reactToForum', _hReactToForum!);

    _hReactToForumDislike = (data) {
      final threadId = data['forumId'];
      final reactorUserId = data['userId'];
      final action = data['action'];

      final index = threads.indexWhere((t) => t['_id'] == threadId);
      if (index == -1) return;

      final fromMe = reactorUserId == userId;
      final startedHere =
          inflightLike.contains(threadId) || inflightDislike.contains(threadId);

      if (fromMe && (_inDetails || startedHere || _shouldMuteSelf(threadId))) {
        _log(
          'reactToForumDislike (skip self-echo) action=$action thread=$threadId',
        );
        return;
      }

      setState(() {
        final currDislikes = (threads[index]['dislikes'] ?? 0) as int;
        final currLikes = (threads[index]['likes'] ?? 0) as int;

        if (action == 'Added') {
          threads[index]['dislikes'] = currDislikes + 1;
          if (fromMe && !startedHere) dislikedList[index] = true;
        } else if (action == 'Remove') {
          threads[index]['dislikes'] = max(0, currDislikes - 1);
          if (fromMe && !startedHere) dislikedList[index] = false;
        } else if (action == 'Updated') {
          // like → dislike
          threads[index]['dislikes'] = currDislikes + 1;
          if (currLikes > 0) threads[index]['likes'] = currLikes - 1;
          if (fromMe && !startedHere) {
            dislikedList[index] = true;
            likedList[index] = false;
          }
        }
      });
    };
    socket.on('reactToForumDislike', _hReactToForumDislike!);

    _hCommentAdded = (data) {
      final forumId = data['forumId'];
      final index = threads.indexWhere((t) => t['_id'] == forumId);
      if (index != -1) {
        setState(() {
          threads[index]['replies'] = (threads[index]['replies'] ?? 0) + 1;
        });
      }
    };
    socket.on('commentAdded', _hCommentAdded!);
  }

  void _detachSocketListeners() {
    _log('Listeners DETACHED');
    if (_hForumAdded != null) socket.off('forumAdded', _hForumAdded);
    if (_hReactToForum != null) socket.off('reactToForum', _hReactToForum);
    if (_hReactToForumDislike != null) {
      socket.off('reactToForumDislike', _hReactToForumDislike);
    }
    if (_hCommentAdded != null) socket.off('commentAdded', _hCommentAdded);
  }

  // --- data ---
  Future<void> _fetchThreads() async {
    setState(() => isLoading = true);

    final subId = widget.forumData['subCategoryId'];
    final url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum?categoryId=$subId';
    _log('GET threads: $url');

    try {
      final headers = {'Content-Type': 'application/json'};
      if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['forums'] ?? [];

        threads =
            data.map<Map<String, dynamic>>((item) {
              final reactions =
                  item['reactions'] as Map<String, dynamic>? ?? {};
              final likeCount = (item['upvotes'] ?? 0) + (reactions['👍'] ?? 0);
              final dislikeCount = reactions['👎'] ?? 0;
              final userObj = item['userId'] as Map<String, dynamic>?;

              return {
                '_id': item['_id'] ?? '',
                'title': item['title'] ?? '',
                'description': item['text'] ?? '',
                'author': item['userId']?['userName'] ?? 'Unknown',
                'userId': userObj?['_id'] ?? '',
                'profileImage':
                    userObj?['_id'] == null
                        ? ''
                        : (userObj?['profileImage'] ?? ''),
                'replies': item['commentsCount'] ?? 0,
                'likes': likeCount,
                'dislikes': dislikeCount,
                'createdAt': item['createdAt'] ?? '',
                'isReact': item['isReact'] ?? false,
                'isDislike': item['isDislike'] ?? false,
              };
            }).toList();

        likedList = threads.map<bool>((t) => t['isReact'] as bool).toList();
        dislikedList =
            threads.map<bool>((t) => t['isDislike'] as bool).toList();
      } else {
        throw Exception('Failed to load threads ${response.statusCode}');
      }
    } catch (e) {
      _log('Error fetching threads: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // canonical refresh for a single thread
  Future<void> _refreshSingleThread(String threadId) async {
    final url = 'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/$threadId';
    _log('GET thread snapshot: $url');
    try {
      final headers = {'Content-Type': 'application/json'};
      if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      final res = await http.get(Uri.parse(url), headers: headers);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final forum = body['forum'] as Map<String, dynamic>?;
        if (forum == null) return;

        int likeReactions = 0;
        int dislikeReactions = 0;
        if (forum['reactions'] != null) {
          final rx = forum['reactions'] as Map<String, dynamic>;
          likeReactions = (rx['👍'] ?? 0) as int;
          dislikeReactions = (rx['👎'] ?? 0) as int;
        }
        final upvotes = (forum['upvotes'] ?? 0) as int;
        final likesCanonical = upvotes + likeReactions;
        final dislikesCanonical = dislikeReactions;
        final commentsCanonical = (forum['commentsCount'] ?? 0) as int;
        final isReact = forum['isReact'] == true;
        final isDislike = forum['isDislike'] == true;

        final idx = threads.indexWhere((t) => t['_id'] == threadId);
        if (idx != -1 && mounted) {
          setState(() {
            threads[idx]['likes'] = likesCanonical;
            threads[idx]['dislikes'] = dislikesCanonical;
            threads[idx]['replies'] = commentsCanonical;
            likedList[idx] = isReact;
            dislikedList[idx] = isDislike;
          });
          _log(
            'Snapshot applied for $threadId '
            'likes=${threads[idx]['likes']} dislikes=${threads[idx]['dislikes']} '
            'replies=${threads[idx]['replies']} isReact=${likedList[idx]} isDislike=${dislikedList[idx]}',
          );
        }
      }
    } catch (e) {
      _log('Error snapshot $threadId: $e');
    }
  }

  // --- reactions (optimistic on list) ---
  Future<void> _reactToThread(String forumId, int index) async {
    if (!_canTap(index)) return;

    final wasLiked = likedList[index];

    setState(() {
      likedList[index] = !wasLiked;
      threads[index]['likes'] = max(
        0,
        (threads[index]['likes'] ?? 0) + (!wasLiked ? 1 : -1),
      );
      if (!wasLiked && dislikedList[index]) {
        dislikedList[index] = false;
        threads[index]['dislikes'] = max(
          0,
          (threads[index]['dislikes'] ?? 1) - 1,
        );
      }
    });

    inflightLike.add(forumId);
    try {
      final res = await http.post(
        Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "forumId": forumId,
          "categoryId": widget.forumData['categoryId'],
          "subCategoryId": widget.forumData['subCategoryId'],
          "emoji": "",
        }),
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        _revertLikeState(index, wasLiked);
      }
    } catch (_) {
      _revertLikeState(index, wasLiked);
    } finally {
      inflightLike.remove(forumId);
    }
  }

  void _revertLikeState(int index, bool wasLiked) {
    setState(() {
      likedList[index] = wasLiked;
      final currentLikes = (threads[index]['likes'] ?? 0) as int;
      threads[index]['likes'] =
          wasLiked ? currentLikes + 1 : max(0, currentLikes - 1);
    });
  }

  Future<void> _dislikeToThread(String forumId, int index) async {
    if (!_canTap(index)) return;

    final wasDisliked = dislikedList[index];

    setState(() {
      dislikedList[index] = !wasDisliked;
      threads[index]['dislikes'] = max(
        0,
        (threads[index]['dislikes'] ?? 0) + (!wasDisliked ? 1 : -1),
      );
      if (!wasDisliked && likedList[index]) {
        likedList[index] = false;
        threads[index]['likes'] = max(0, (threads[index]['likes'] ?? 1) - 1);
      }
    });

    inflightDislike.add(forumId);
    try {
      final res = await http.post(
        Uri.parse(
          'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react/dislike',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "forumId": forumId,
          "categoryId": widget.forumData['categoryId'],
          "subCategoryId": widget.forumData['subCategoryId'],
          "emoji": "👎",
        }),
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        _revertDislikeState(index, wasDisliked);
      }
    } catch (_) {
      _revertDislikeState(index, wasDisliked);
    } finally {
      inflightDislike.remove(forumId);
    }
  }

  void _revertDislikeState(int index, bool wasDisliked) {
    setState(() {
      dislikedList[index] = wasDisliked;
      final currentDislikes = (threads[index]['dislikes'] ?? 0) as int;
      threads[index]['dislikes'] =
          wasDisliked ? currentDislikes + 1 : max(0, currentDislikes - 1);
    });
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.forumData['subCategoryName']?.toString() ?? 'Forum',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
      ),
      body:
          isLoading
              ? _buildShimmer(theme)
              : threads.isEmpty
              ? Center(
                child: Text(
                  'No threads yet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              )
              : RefreshIndicator(
                backgroundColor: Colors.white,
                color: const Color(0xFFEBB411),
                onRefresh: _fetchThreads,
                child: ListView.builder(
                  itemCount: threads.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final isLiked = likedList[index];
                    final isDisliked = dislikedList[index];

                    return InkWell(
                      onTap: () async {
                        _inDetails = true;
                        _log('NAV -> details for thread=${thread['_id']}');

                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ThreadDetailScreen(
                                  thread: {
                                    ...thread,
                                    'categoryId':
                                        widget.forumData['categoryId'],
                                    'subCategoryId':
                                        widget.forumData['subCategoryId'],
                                  },
                                  socket: socket, // still using parent socket
                                ),
                          ),
                        );

                        _inDetails = false;

                        _log(
                          'NAV <- back; socket.connected=${socket.connected} id=${socket.id}',
                        );

                        // ✅ Always recreate socket on return to avoid wiped listeners
                        _forceRecreateSocket();

                        final openedId = thread['_id'] as String;
                        _muteSelfEchoFor(openedId, ms: 1500);

                        await Future.delayed(const Duration(milliseconds: 150));

                        if (result is Map<String, dynamic> &&
                            (result['_id'] ?? result['id']) == openedId) {
                          _log(
                            'details returned snapshot for $openedId -> applying',
                          );
                          final idx = threads.indexWhere(
                            (t) => t['_id'] == openedId,
                          );
                          if (idx != -1 && mounted) {
                            setState(() {
                              if (result['likes'] != null) {
                                threads[idx]['likes'] = result['likes'];
                              }
                              if (result['dislikes'] != null) {
                                threads[idx]['dislikes'] = result['dislikes'];
                              }
                              if (result['commentsCount'] != null) {
                                threads[idx]['replies'] =
                                    result['commentsCount'];
                              }
                              if (result.containsKey('isReact')) {
                                likedList[idx] = result['isReact'] == true;
                              }
                              if (result.containsKey('isDislike')) {
                                dislikedList[idx] = result['isDislike'] == true;
                              }
                            });
                          }
                        }

                        // final snap from server to fix any drift
                        await _refreshSingleThread(openedId);
                      },
                      child: Card(
                        color: theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                        elevation: 0.04,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _avatar(thread),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          thread['title'].toString().isNotEmpty
                                              ? '${thread['title'][0].toUpperCase()}${thread['title'].substring(1)}'
                                              : '',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color:
                                                theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '- ${thread['author']}',
                                          style: GoogleFonts.inter(
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            color: theme
                                                .textTheme
                                                .bodySmall
                                                ?.color
                                                ?.withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap:
                                                  () => _reactToThread(
                                                    thread['_id'],
                                                    index,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isLiked
                                                        ? Icons
                                                            .thumb_up_outlined
                                                        : Icons
                                                            .thumb_up_alt_outlined,
                                                    size: 18,
                                                    color:
                                                        isLiked
                                                            ? const Color(
                                                              0xFFEBB411,
                                                            )
                                                            : Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${thread['likes']}',
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      fontSize: 12,
                                                      color:
                                                          isLiked
                                                              ? const Color(
                                                                0xFFEBB411,
                                                              )
                                                              : theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.color
                                                                  ?.withOpacity(
                                                                    0.85,
                                                                  ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            InkWell(
                                              onTap:
                                                  () => _dislikeToThread(
                                                    thread['_id'],
                                                    index,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isDisliked
                                                        ? Icons
                                                            .thumb_down_outlined
                                                        : Icons
                                                            .thumb_down_alt_outlined,
                                                    size: 18,
                                                    color:
                                                        isDisliked
                                                            ? Colors.red
                                                            : Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${thread['dislikes'] ?? 0}',
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      fontSize: 12,
                                                      color:
                                                          isDisliked
                                                              ? Colors.red
                                                              : Colors
                                                                  .grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.mode_comment_outlined,
                                                  size: 18,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${thread['replies']}',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 12,
                                                    color: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color
                                                        ?.withOpacity(0.85),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            Text(
                                              _timestampLabelNoTZ(
                                                thread['createdAt'],
                                              ),
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w400,
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: theme.primaryColor,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddThreadScreen(forumData: widget.forumData),
            ),
          );
          if (result == true) {
            await _fetchThreads();
          }
        },
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> thread) {
    final profileImage = (thread['profileImage'] ?? '').toString();
    if (profileImage.isNotEmpty) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewProfileScreen(viewedUserId: thread['userId']),
            ),
          );
        },
        child: CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(profileImage),
        ),
      );
    }
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewProfileScreen(viewedUserId: thread['userId']),
          ),
        );
      },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFEBB411),
        child: Text(
          thread['author'].toString().isNotEmpty
              ? thread['author'][0].toUpperCase()
              : '?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer(ThemeData theme) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(width: 80, height: 12, color: Colors.white),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(width: 50, height: 12, color: Colors.white),
                      const SizedBox(width: 20),
                      Container(width: 50, height: 12, color: Colors.white),
                      const SizedBox(width: 20),
                      Container(width: 50, height: 12, color: Colors.white),
                      const Spacer(),
                      Container(width: 40, height: 12, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String timeAgo(String dateString) {
    final date = DateTime.parse(dateString).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 8) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _absoluteLocalNoTZ(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final date = DateFormat('MMM d, yyyy').format(dt);
      final time = DateFormat('h:mm a').format(dt);
      return '$date • $time';
    } catch (_) {
      return '';
    }
  }

  String _timestampLabelNoTZ(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final ago = timeAgo(iso);
    final looksLikeDate =
        ago.contains('/') || ago.contains(',') || ago.contains('20');
    if (looksLikeDate) return _absoluteLocalNoTZ(iso);

    try {
      final dt = DateTime.parse(iso).toLocal();
      final tm = DateFormat('h:mm a').format(dt);
      return '$ago • $tm';
    } catch (_) {
      return _absoluteLocalNoTZ(iso);
    }
  }
}
