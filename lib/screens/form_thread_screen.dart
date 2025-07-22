import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:readmore/readmore.dart';
import 'package:rwa_app/widgets/html_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:rwa_app/screens/add_thread_screen.dart';
import 'package:rwa_app/screens/thread_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadTokenAndFetch(); // ensures token/userId loaded
    _initSocket(); // socket now connects with correct userId
  }

  @override
  void dispose() {
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
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('Socket connected ✅');

      // ✅ Join specific category room immediately after connect
      socket.emit('joinCategory', {'categoryId': widget.forumData['id']});
    });

    socket.onDisconnect((_) {
      print('Socket disconnected ❌');
    });

    // ✅ Listen for newly added threads in this category
    socket.on('forumAdded', (data) {
      print('New thread added to category: $data');

      setState(() {
        threads.insert(0, {
          '_id': data['_id'] ?? '',
          'title': data['title'] ?? '',
          'description': data['text'] ?? '',
          'author':
              (data['userId'] is Map)
                  ? (data['userId']?['userName'] ?? 'Unknown')
                  : 'Unknown',
          'replies': data['commentsCount'] ?? 0,
          'likes':
              (data['upvotes'] ?? 0) +
              ((data['reactions'] as Map<String, dynamic>?)?.values.fold(
                    0,
                    (sum, value) => sum + (value as int),
                  ) ??
                  0),
          'createdAt': data['createdAt'] ?? '',
          'isReact': data['isReact'] ?? false,
        });

        likedList.insert(0, data['isReact'] ?? false);
      });
    });

    socket.on('reactToForum', (data) {
      final updatedThreadId = data['forumId'];
      final reactorUserId = data['userId'];
      final action = data['action'];

      print('🔔 reactToForum received: $data');

      final index = threads.indexWhere((t) => t['_id'] == updatedThreadId);

      if (index != -1) {
        if (reactorUserId == userId) {
          print('👤 Reaction is from my user, skipping duplicate UI update.');
          return;
        }

        setState(() {
          int currentLikes = threads[index]['likes'] ?? 0;
          int updatedLikes = currentLikes;

          if (action == 'Added') {
            updatedLikes = currentLikes + 1;

            int currentDislikes = threads[index]['dislikes'] ?? 0;
            if (currentDislikes > 0) {
              threads[index]['dislikes'] = currentDislikes - 1;
              print(
                '✅ Decremented dislikes count due to new like from another user',
              );
            }
          } else if (action == 'Remove') {
            updatedLikes = (currentLikes - 1).clamp(0, double.infinity).toInt();
          } else if (action == 'Updated') {
            updatedLikes = currentLikes + 1;

            int currentDislikes = threads[index]['dislikes'] ?? 0;
            if (currentDislikes > 0) {
              threads[index]['dislikes'] = currentDislikes - 1;
              print('✅ Decremented dislikes count due to Updated like switch');
            }

            print('✅ Reaction updated from dislike to like');
          } else {
            print('⚠️ Unknown action: $action');
          }

          threads[index]['likes'] = updatedLikes;
          print('✅ Updated likes count to $updatedLikes for another user');
        });
      } else {
        print('⚠️ Thread not found for id $updatedThreadId');
      }
    });

    socket.on('reactToForumDislike', (data) {
      print('🔔 reactToForumDislike received: $data');

      final updatedThreadId = data['forumId'];
      final reactorUserId = data['userId'];
      final action = data['action'];

      final index = threads.indexWhere((t) => t['_id'] == updatedThreadId);

      if (index != -1) {
        if (reactorUserId == userId) {
          print(
            '👤 Dislike reaction is from my user, skipping duplicate UI update.',
          );
          return;
        }

        setState(() {
          int currentDislikes = threads[index]['dislikes'] ?? 0;
          int updatedDislikes = currentDislikes;

          if (action == 'Added') {
            updatedDislikes = currentDislikes + 1;
          } else if (action == 'Remove') {
            updatedDislikes =
                (currentDislikes - 1).clamp(0, double.infinity).toInt();
          } else if (action == 'Updated') {
            updatedDislikes = currentDislikes + 1;

            int currentLikes = threads[index]['likes'] ?? 0;
            if (currentLikes > 0) {
              threads[index]['likes'] = currentLikes - 1;
              print('✅ Decremented likes count due to Updated dislike switch');
            }

            print('✅ Reaction updated from like to dislike');
          } else {
            print('⚠️ Unknown dislike action: $action');
          }

          threads[index]['dislikes'] = updatedDislikes;
          print(
            '✅ Updated dislikes count to $updatedDislikes for another user',
          );
        });
      } else {
        print('⚠️ Thread not found for id $updatedThreadId');
      }
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
          'https://rwa-f1623a22e3ed.herokuapp.com/api/forum?categoryId=${widget.forumData['id']}',
        ),
        headers: headers,
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

              return {
                '_id': item['_id'] ?? '',
                'title': item['title'] ?? '',
                'description': item['text'] ?? '',
                'author': item['userId']?['userName'] ?? 'Unknown',
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

  Future<void> reactToThread(String forumId, int index) async {
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to use this feature.")),
      );
      return;
    }

    final isLiked = likedList[index];

    setState(() {
      likedList[index] = !isLiked;
      threads[index]['likes'] =
          (threads[index]['likes'] ?? 0) + (!isLiked ? 1 : -1);

      if (!isLiked && dislikedList[index]) {
        dislikedList[index] = false;
        threads[index]['dislikes'] = (threads[index]['dislikes'] ?? 1) - 1;
      }
    });

    final url = 'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react';
    print(!isLiked);
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },

        body: jsonEncode({
          "forumId": forumId,
          "categoryId": widget.forumData['id'],
          "emoji": "",
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        socket.emit('reactThread', {"forumId": forumId});
      } else {
        // ❌ Revert optimistic update on failure
        setState(() {
          likedList[index] = isLiked;
          threads[index]['likes'] =
              (threads[index]['likes'] ?? 0) + (isLiked ? 1 : -1);
        });
        print('Failed to react: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to like. Please try again.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error reacting: $e');
      // ❌ Revert optimistic update on exception
      setState(() {
        likedList[index] = isLiked;
        threads[index]['likes'] =
            (threads[index]['likes'] ?? 0) + (isLiked ? 1 : -1);

        // If dislike was removed on optimistic like, re-add it on revert
        if (!isLiked && dislikedList[index]) {
          dislikedList[index] = true;
          threads[index]['dislikes'] = (threads[index]['dislikes'] ?? 0) + 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error. Please try again.',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> dislikeToThread(String forumId, int index) async {
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to use this feature.")),
      );
      return;
    }

    final isDisliked = dislikedList[index];

    setState(() {
      dislikedList[index] = !isDisliked;
      threads[index]['dislikes'] =
          (threads[index]['dislikes'] ?? 0) + (!isDisliked ? 1 : -1);

      if (!isDisliked && likedList[index]) {
        likedList[index] = false;
        threads[index]['likes'] = (threads[index]['likes'] ?? 1) - 1;
      }
    });

    final url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/react/dislike';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "forumId": forumId,
          "categoryId": widget.forumData['id'],
          "emoji": "👎",
        }),
      );

      print('Dislike API');
      print(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        socket.emit('reactThread', {"forumId": forumId});
      } else {
        // revert on failure
        setState(() {
          dislikedList[index] = isDisliked;
          threads[index]['dislikes'] =
              (threads[index]['dislikes'] ?? 0) + (isDisliked ? 1 : -1);
        });

        print('Failed to dislike: ${response.body}');
      }
    } catch (e) {
      print('Error disliking: $e');
      setState(() {
        dislikedList[index] = isDisliked;
      });
    }
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.forumData['name'],
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
                  vertical: 8,
                  horizontal: 12,
                ),
                itemBuilder: (context, index) {
                  return Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                  'No threads yet in ${widget.forumData['name']}.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              )
              : RefreshIndicator(
                backgroundColor: Colors.white,
                color: Color(0xFF0087E0),
                onRefresh: fetchThreads,
                child: ListView.builder(
                  itemCount: threads.length,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
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
                                            .forumData['id'], // ✅ Include categoryId here
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
                                threads[index]['dislikes'] = result['dislikes'];

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
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0.04,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Profile image or initial
                                  if (thread['profileImage'] != null &&
                                      thread['profileImage']
                                          .toString()
                                          .isNotEmpty)
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(
                                        thread['profileImage'],
                                      ),
                                    )
                                  else
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.yellow,
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
                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: Text(
                                      thread['title'].toString().isNotEmpty
                                          ? '${thread['title'][0].toUpperCase()}${thread['title'].substring(1)}'
                                          : '',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                        color:
                                            theme.textTheme.titleMedium?.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),
                              Text(
                                '- ${thread['author']}',
                                style: GoogleFonts.inter(
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      reactToThread(thread['_id'], index);
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLiked
                                              ? Icons.thumb_up
                                              : Icons.thumb_up_alt_outlined,
                                          size: 18,
                                          color:
                                              isLiked
                                                  ? Colors.blue
                                                  : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          // '${thread['likes']} likes',
                                          '${thread['likes']}',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            color:
                                                isLiked
                                                    ? Colors.blue
                                                    : theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color
                                                        ?.withOpacity(0.85),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),

                                  InkWell(
                                    onTap: () {
                                      dislikeToThread(thread['_id'], index);
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDisliked
                                              ? Icons.thumb_down
                                              : Icons.thumb_down_alt_outlined,
                                          size: 18,
                                          color:
                                              isDisliked
                                                  ? Colors.red
                                                  : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$dislikeCount',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            color:
                                                isDisliked
                                                    ? Colors.red
                                                    : Colors.grey[600],
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
                                        // '${thread['replies']} discussions',
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

                                  SizedBox(width: 20),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.remove_red_eye_outlined,
                                        size: 18,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '20',
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
        child: Icon(Icons.add, size: 32, color: theme.colorScheme.onPrimary),
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
