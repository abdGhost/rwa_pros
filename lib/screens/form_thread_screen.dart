import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:readmore/readmore.dart';
import 'package:rwa_app/screens/profile/new_profile.dart';
import 'package:rwa_app/widgets/html_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:rwa_app/screens/add_thread_screen.dart';
import 'package:rwa_app/screens/thread_details_screen.dart';
import 'dart:math'; // place at top of your file

class ForumThreadScreen extends StatefulWidget {
  final Map<String, dynamic> forumData;

  const ForumThreadScreen({super.key, required this.forumData});

  @override
  State<ForumThreadScreen> createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends State<ForumThreadScreen> {
  List<Map<String, dynamic>> threads = [];
  List<bool> likedList = [];
  List<bool> dislikedList = []; // For each thread, tracks if user disliked
  bool isLoading = true;
  String token = '';
  String userId = '';

  late IO.Socket socket;
  bool isExpanded = false;
  List<bool> expandedList = [];

  Set<int> lockedIndexes = {};

  // Track operations started from THIS device
  final Set<String> inflightLike = {};
  final Set<String> inflightDislike = {};

  @override
  void initState() {
    super.initState();
    _initialize();
    print('hereeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee------------------------');
  }

  Future<void> _initialize() async {
    await _loadTokenAndFetch(); // ensures token/userId loaded
    _initSocket(); // socket now connects with correct userId
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> _loadTokenAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? '';
    userId = prefs.getString('userId') ?? '';
    fetchThreads();
  }

  void _initSocket() {
    socket = IO.io(
      'https://rwa-f1623a22e3ed.herokuapp.com',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': token})
          // .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('Socket connected ✅ ✅ ✅ ✅');

      socket.emit('joinCategory', {
        'categoryId': widget.forumData['categoryId'],
      });
      socket.emit('joinSubCategory', {
        'subCategoryId': widget.forumData['subCategoryId'],
      });
    });

    socket.onDisconnect((_) {
      print('Socket disconnected ❌');
    });

    // ✅ Listen for newly added threads in this category
    socket.on('forumAdded', (data) {
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
    });

    socket.on('reactToForum', (data) {
      final threadId = data['forumId'];
      final reactorUserId = data['userId'];
      final action = data['action']; // 'Added' | 'Remove' | 'Updated'

      final index = threads.indexWhere((t) => t['_id'] == threadId);
      if (index == -1) return;

      final fromMe = reactorUserId == userId;
      final startedHere =
          inflightLike.contains(threadId) || inflightDislike.contains(threadId);

      // If it's my own echo for an action I started on THIS device, skip (optimistic already applied).
      if (fromMe && startedHere) return;

      setState(() {
        final currLikes = (threads[index]['likes'] ?? 0) as int;
        final currDislikes = (threads[index]['dislikes'] ?? 0) as int;

        if (action == 'Added') {
          threads[index]['likes'] = currLikes + 1;
          if (fromMe && !startedHere) {
            // came from my OTHER device → sync my toggle/color locally
            likedList[index] = true;
          }
        } else if (action == 'Remove') {
          threads[index]['likes'] = (currLikes - 1).clamp(0, currLikes);
          if (fromMe && !startedHere) {
            likedList[index] = false;
          }
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
    });

    socket.on('reactToForumDislike', (data) {
      final threadId = data['forumId'];
      final reactorUserId = data['userId'];
      final action = data['action'];

      final index = threads.indexWhere((t) => t['_id'] == threadId);
      if (index == -1) return;

      final fromMe = reactorUserId == userId;
      final startedHere =
          inflightLike.contains(threadId) || inflightDislike.contains(threadId);

      if (fromMe && startedHere) return; // same-device echo

      setState(() {
        final currDislikes = (threads[index]['dislikes'] ?? 0) as int;
        final currLikes = (threads[index]['likes'] ?? 0) as int;

        if (action == 'Added') {
          threads[index]['dislikes'] = currDislikes + 1;
          if (fromMe && !startedHere) {
            dislikedList[index] = true;
          }
        } else if (action == 'Remove') {
          threads[index]['dislikes'] = (currDislikes - 1).clamp(
            0,
            currDislikes,
          );
          if (fromMe && !startedHere) {
            dislikedList[index] = false;
          }
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
    });

    socket.on('commentAdded', (data) {
      print('New Comment Added: $data');

      final forumId = data['forumId'];

      final index = threads.indexWhere((t) => t['_id'] == forumId);

      if (index != -1) {
        setState(() {
          threads[index]['replies'] = (threads[index]['replies'] ?? 0) + 1;
        });
        print('✅ Updated comments count for thread $forumId');
      } else {
        print('⚠️ Thread not found for id $forumId');
      }
    });
  }

  Future<void> fetchThreads() async {
    print(widget.forumData);
    setState(() {
      isLoading = true;
    });

    try {
      final headers = {'Content-Type': 'application/json'};

      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse(
          'https://rwa-f1623a22e3ed.herokuapp.com/api/forum?categoryId=${widget.forumData['subCategoryId']}',
        ),
        headers: headers,
      );

      print(
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum?categoryId=${widget.forumData['subCategoryId']}',
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['forums'] ?? [];
        print('Data from Thread');
        print(data);

        threads =
            data.map<Map<String, dynamic>>((item) {
              final reactions =
                  item['reactions'] as Map<String, dynamic>? ?? {};

              final likeCount = (item['upvotes'] ?? 0) + (reactions['👍'] ?? 0);

              final dislikeCount = reactions['👎'] ?? 0;

              final userObj = item['userId'] as Map<String, dynamic>?; // 👈

              return {
                '_id': item['_id'] ?? '',
                'title': item['title'] ?? '',
                'description': item['text'] ?? '',
                'author': item['userId']?['userName'] ?? 'Unknown',
                'userId': userObj?['_id'] ?? '', // ✅ add this
                'profileImage': userObj?['profileImage'] ?? '', // ✅ optional
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

        expandedList = List<bool>.filled(threads.length, false);
      } else {
        throw Exception('Failed to load threads');
      }
    } catch (e) {
      print('Error fetching threads: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<int, DateTime> tapTimestamps = {};

  bool canTap(int index) {
    final now = DateTime.now();
    final lastTap = tapTimestamps[index];

    if (lastTap != null && now.difference(lastTap) < Duration(seconds: 1)) {
      return false;
    }

    tapTimestamps[index] = now;
    return true;
  }

  Future<void> reactToThread(String forumId, int index) async {
    if (!canTap(index)) return;

    lockedIndexes.add(index);
    inflightLike.add(forumId); // 👈 mark started here

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

    try {
      final res = await http.post(
        Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "forumId": forumId,
          "categoryId": widget.forumData['id'],
          "subCategoryId": widget.forumData['subCategoryId'],
          "emoji": "",
        }),
      );
      if (res.statusCode != 200 && res.statusCode != 201)
        revertLikeState(index, wasLiked);
    } catch (_) {
      revertLikeState(index, wasLiked);
    } finally {
      inflightLike.remove(forumId); // 👈 clear
      lockedIndexes.remove(index);
    }
  }

  void revertLikeState(int index, bool wasLiked) {
    setState(() {
      likedList[index] = wasLiked;

      final currentLikes = (threads[index]['likes'] ?? 0) as int;
      threads[index]['likes'] =
          wasLiked
              ? currentLikes +
                  1 // we had decremented on optimistic toggle
              : (currentLikes - 1).clamp(0, currentLikes);
    });
  }

  Future<void> dislikeToThread(String forumId, int index) async {
    if (!canTap(index)) return;

    lockedIndexes.add(index);
    inflightDislike.add(forumId); // 👈 mark started here

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
          "categoryId": widget.forumData['id'],
          "subCategoryId": widget.forumData['subCategoryId'],
          "emoji": "👎",
        }),
      );
      if (res.statusCode != 200 && res.statusCode != 201)
        revertDislikeState(index, wasDisliked);
    } catch (_) {
      revertDislikeState(index, wasDisliked);
    } finally {
      inflightDislike.remove(forumId); // 👈 clear
      lockedIndexes.remove(index);
    }
  }

  void revertDislikeState(int index, bool wasDisliked) {
    setState(() {
      dislikedList[index] = wasDisliked;

      final currentDislikes = (threads[index]['dislikes'] ?? 0) as int;
      threads[index]['dislikes'] =
          wasDisliked
              ? currentDislikes +
                  1 // we had decremented on optimistic toggle
              : (currentDislikes - 1).clamp(0, currentDislikes);
    });
  }

  String removeEmptyBrParagraphAfterLists(String html) {
    // Remove <p><br/></p> immediately after </ol> or </ul>
    return html.replaceAllMapped(
      RegExp(r'(</(ol|ul)>)\s*<p>\s*<br\s*/?>\s*</p>', caseSensitive: false),
      (match) => match.group(1) ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        socket.disconnect();
        socket.dispose();
        Navigator.pop(context, true); // signal parent to reconnect
        return false;
      },
      child: Scaffold(
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
                ? ListView.builder(
                  itemCount: 5,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                  ), // ✅ No horizontal padding
                  itemBuilder: (context, index) {
                    return Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: double.infinity, // ✅ Full width container
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Card(
                          margin:
                              EdgeInsets.zero, // ✅ Prevent card internal margin
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title skeleton
                              Container(
                                width: double.infinity,
                                height: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 6),

                              // Description skeleton (2 lines)
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

                              // Author skeleton
                              Container(
                                width: 80,
                                height: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 12),

                              // Reaction icons row skeleton
                              Row(
                                children: [
                                  // Like icon + count
                                  Container(
                                    width: 50,
                                    height: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 20),

                                  // Dislike icon + count
                                  Container(
                                    width: 50,
                                    height: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 20),

                                  // Comment icon + count
                                  Container(
                                    width: 50,
                                    height: 12,
                                    color: Colors.white,
                                  ),
                                  const Spacer(),

                                  // Time ago skeleton
                                  Container(
                                    width: 40,
                                    height: 12,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
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
                  color: Color(0xFFEBB411),
                  onRefresh: fetchThreads,
                  child: ListView.builder(
                    itemCount: threads.length,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      // horizontal: 12,
                    ),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      print('Threadddddddddddddddddd ${thread}');
                      final isLiked = likedList[index];
                      final isDisliked = dislikedList[index];
                      final dislikeCount = thread['dislikes'] ?? 0;

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ThreadDetailScreen(
                                    thread: {
                                      ...thread,
                                      'categoryId':
                                          widget
                                              .forumData['categoryId'], // ✅ real categoryId
                                      'subCategoryId':
                                          widget
                                              .forumData['subCategoryId'], // ✅ subcategoryId
                                    },
                                    socket: socket,
                                  ),
                            ),
                          ).then((result) {
                            if (result != null) {
                              final index = threads.indexWhere(
                                (t) => t['_id'] == result['_id'],
                              );
                              if (index != -1) {
                                setState(() {
                                  threads[index]['isReact'] = result['isReact'];
                                  threads[index]['likes'] = result['likes'];
                                  threads[index]['replies'] =
                                      result['commentsCount'];

                                  // ✅ Add dislike state and count update
                                  threads[index]['isDislike'] =
                                      result['isDislike'];
                                  threads[index]['dislikes'] =
                                      result['dislikes'];

                                  likedList[index] = result['isReact'];
                                  dislikedList[index] =
                                      result['isDislike']; // 🔴 Add this line
                                });
                              }
                            }
                          });
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
                                    // Profile image or initial
                                    if (thread['profileImage'] != null &&
                                        thread['profileImage']
                                            .toString()
                                            .isNotEmpty)
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => NewProfileScreen(
                                                    viewedUserId:
                                                        thread['userId'],
                                                  ),
                                            ),
                                          );
                                        },
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundImage: NetworkImage(
                                            thread['profileImage'],
                                          ),
                                        ),
                                      )
                                    else
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => NewProfileScreen(
                                                    viewedUserId:
                                                        thread['userId'],
                                                  ),
                                            ),
                                          );
                                        },
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(
                                            0xFFEBB411,
                                          ),
                                          child: Text(
                                            thread['author']
                                                    .toString()
                                                    .isNotEmpty
                                                ? thread['author'][0]
                                                    .toUpperCase()
                                                : '?',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 10),

                                    // Right side: title, author, and actions
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            thread['title']
                                                    .toString()
                                                    .isNotEmpty
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
                                                    () => reactToThread(
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
                                                              : Colors
                                                                  .grey[600],
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
                                                    () => dislikeToThread(
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
                                                              : Colors
                                                                  .grey[600],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$dislikeCount',
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
                                                      fontWeight:
                                                          FontWeight.w400,
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
                                                timeAgo(thread['createdAt']),
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
              fetchThreads();
            }
          },
          child: Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
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
}
