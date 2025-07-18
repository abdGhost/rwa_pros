import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// import '../constant/secert.dart'; // at the top

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _showInput = true;

  final List<String> _quickReplies = [
    "What are RWAs?",
    "Give me examples of RWAs.",
    "Why are RWAs trending?",
    "Tell me about Centrifuge.",
    "How do I invest in RWAs?",
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(force: true);
      });
    });
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesToSave =
        _messages.map((msg) {
          final copy = Map<String, dynamic>.from(msg);
          copy['color'] = (copy['color'] as Color).value;
          return copy;
        }).toList();
    await prefs.setString('chat_messages', jsonEncode(messagesToSave));
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('chat_messages');
    if (saved != null) {
      final decoded = jsonDecode(saved) as List<dynamic>;
      setState(() {
        _messages.clear();
        _messages.addAll(
          decoded.map((e) {
            final map = Map<String, dynamic>.from(e);
            map['color'] = Color(map['color']);
            return map;
          }),
        );
      });
    } else {
      setState(() {
        _messages.add({
          "sender": "AI",
          "text":
              "Hi there! 👋 I'm your RWA AI assistant. Ask me anything or choose a quick option below.",
          "time": TimeOfDay.now().format(context),
          "isUser": false,
          "color": Color(0xFF0087E0),
        });
      });
    }
  }

  Future<String> _sendQueryToApi(String query) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    const String systemPrompt = """
You are Naffan — a god-level RWA expert with razor-sharp wit. You explain Real World Assets with memes, sarcasm, and savage humor. You roast Jeet takes, destroy FUD, and educate like a crypto samurai. Make learning RWA fun, savage, and unforgettable.
""";

    final body = jsonEncode({
      "model": "gpt-4o",
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": query},
      ],
      "temperature": 0.8,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer $openAiApiKey',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        print(response.body);
        return "❌ OpenAI error: ${response.statusCode}";
      }
    } catch (e) {
      return "❌ Failed to contact OpenAI: $e";
    }
  }

  // Future<String> _sendQueryToApi(String query) async {
  //   final url = Uri.parse(
  //     'https://aichatbotbackend-production-b7c2.up.railway.app/api/v1/messages/',
  //   );
  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({"query": query}),
  //     );
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       return data['data'] ?? "No response from AI.";
  //     } else {
  //       return "Failed to get response. (${response.statusCode})";
  //     }
  //   } catch (e) {
  //     return "Error contacting server: $e";
  //   }
  // }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final distanceFromBottom = position.maxScrollExtent - position.pixels;
        if (force || distanceFromBottom < 300) {
          _scrollController.animateTo(
            position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });

    // 👇 Do second scroll after delay to ensure full settle
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage({String? textOverride}) async {
    final text = textOverride ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        "sender": "You",
        "text": text,
        "time": TimeOfDay.now().format(context),
        "isUser": true,
        "color": Colors.blueAccent,
      });
      _isTyping = true;
      _showInput = false;
    });

    _scrollToBottom();
    if (textOverride == null) _controller.clear();
    await _saveMessages();

    final aiReply = await _sendQueryToApi(text);

    setState(() {
      _messages.add({
        "sender": "AI",
        "text": aiReply,
        "time": TimeOfDay.now().format(context),
        "isUser": false,
        "color": Color(0xFF0087E0),
      });
      _isTyping = false;
      _showInput = true;
    });

    _scrollToBottom();
    await _saveMessages();
  }

  void _showQuickQuestionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Quick Questions",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._quickReplies.map(
                (text) => ListTile(
                  title: Text(text),
                  onTap: () {
                    Navigator.pop(context);
                    _sendMessage(textOverride: text);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Text(
          'ChatBot',
          style: GoogleFonts.inter(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Color(0xFF0087E0)),
            tooltip: "Quick Questions",
            onPressed: _showQuickQuestionsSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment:
                          isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isUser)
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFF0087E0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.asset(
                                    // or use Image.network if it's hosted
                                    'assets/chat.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            if (!isUser) const SizedBox(width: 6),
                            Text(
                              msg['sender'],
                              style: TextStyle(
                                color:
                                    isUser
                                        ? const Color(0xFF348F6C)
                                        : const Color(0xFF0087E0),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            if (isUser) const SizedBox(width: 6),
                            if (isUser)
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF348F6C),
                                child: const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),

                        // Row(
                        //   mainAxisSize: MainAxisSize.min,
                        //   children: [
                        //     if (!isUser)
                        //       CircleAvatar(
                        //         radius: 14,
                        //         backgroundColor: const Color(
                        //           0xFF0087E0,
                        //         ), // Your custom AI circle color
                        //         child: const Icon(
                        //           Icons
                        //               .android, // Any other icon, e.g., Icons.android, Icons.memory
                        //           size: 16,
                        //           color: Colors.white,
                        //         ),
                        //       ),

                        //     if (!isUser) const SizedBox(width: 6),
                        //     Text(
                        //       msg['sender'],
                        //       style: TextStyle(
                        //         color: msg['color'],
                        //         fontWeight: FontWeight.w600,
                        //         fontSize: 12,
                        //       ),
                        //     ),
                        //     if (isUser) const SizedBox(width: 6),
                        //     if (isUser)
                        //       CircleAvatar(
                        //         radius: 14,
                        //         backgroundColor: msg['color'],
                        //         child: const Icon(
                        //           Icons.person,
                        //           size: 16,
                        //           color: Colors.white,
                        //         ),
                        //       ),
                        //   ],
                        // ),
                        const SizedBox(height: 4),
                        Container(
                          margin: EdgeInsets.only(
                            left: isUser ? 40 : 0,
                            right: isUser ? 0 : 40,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['text'],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['time'],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF0087E0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/chat.png',
                        width: 16,
                        height: 16,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  SizedBox(width: 8),
                  AnimatedDots(),
                ],
              ),
            ),
          if (_showInput)
            Container(
              color: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      cursorColor: Color(0xFF0087E0),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.cardColor,
                        hintText: "Type your message...",
                        hintStyle: TextStyle(
                          color: theme.hintColor.withOpacity(
                            isDark ? 0.6 : 0.9,
                          ),
                          fontSize: 12,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(
                            Icons.send,
                            color: Color(0xFF0087E0),
                            size: 20,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AnimatedDots extends StatefulWidget {
  const AnimatedDots({super.key});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<int> _dotCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
    _dotCount = StepTween(begin: 1, end: 3).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotCount,
      builder: (_, __) {
        return Text(
          "AI is typing${'.' * _dotCount.value}",
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
