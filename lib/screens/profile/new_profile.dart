import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';

class NewProfileScreen extends StatefulWidget {
  const NewProfileScreen({super.key});

  @override
  State<NewProfileScreen> createState() => _NewProfileScreenState();
}

class _NewProfileScreenState extends State<NewProfileScreen> {
  String _selectedTab = "Threads";
  final String userName = "John Doe";
  final String? profileImageUrl = null;

  final List<Map<String, String>> threads = [
    {"title": "RWAs You Personally Hold?", "author": "Michael"},
    {"title": "Which Blockchain Will Win the RWA Race?", "author": "Michael"},
    {"title": "Beginner’s Guide: Explain RWAs Like I’m 5", "author": "Michael"},
  ];

  final List<Map<String, String>> comments = [
    {
      "comment": "This guide helped me understand RWAs, thank you!",
      "thread": "Beginner’s Guide: RWAs",
    },
    {
      "comment": "I think Ethereum still leads the race!",
      "thread": "Which Blockchain Will Win?",
    },
  ];

  final List<Map<String, String>> likes = [
    {"liked": "RWAs You Personally Hold?"},
    {"liked": "Explain RWAs Like I’m 5"},
  ];

  final List<String> badges = ["Explorer", "Contributor", "Veteran", "Pro"];

  String _getInitials(String name) {
    final parts = name.trim().split(" ");
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        toolbarHeight: 60,
        title: Text(
          'My Account',
          style: GoogleFonts.inter(
            textStyle: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, size: 26, color: theme.iconTheme.color),
            onPressed: () {
              // Navigate or perform edit action
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner & Profile Image
            Container(
              margin: const EdgeInsets.only(bottom: 40),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    'assets/airdrop.png',
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: -40,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.black : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage:
                            profileImageUrl != null &&
                                    profileImageUrl!.isNotEmpty
                                ? NetworkImage(profileImageUrl!)
                                : null,
                        child:
                            (profileImageUrl == null ||
                                    profileImageUrl!.isEmpty)
                                ? Text(
                                  _getInitials(userName),
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                )
                                : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Text(
              userName,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: badges.map((b) => _buildBadge(b, isDark)).toList(),
            ),

            const SizedBox(height: 10),
            Text(
              "Joined: 14 March 2025",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Condo is the first RWA-focused memetoken powered by a fully transparent on-chain treasury. Combining community culture with real-world assets, Condo bridges meme energy and institutional-grade RWA investments, offering both fun and real value.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),
            _buildTabs(theme),
            const SizedBox(height: 8),

            if (_selectedTab == "Threads")
              ...threads.map(
                (t) => _buildThreadCard(t['title']!, t['author']!),
              ),
            if (_selectedTab == "Comments")
              ...comments.map(
                (c) => _buildCommentCard(c['comment']!, c['thread']!),
              ),
            if (_selectedTab == "Likes")
              ...likes.map((l) => _buildLikeCard(l['liked']!)),
            if (_selectedTab == "Badges") _buildBadgesList(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, bool isDark) {
    final Map<String, Color> colorMap = {
      "Explorer": Colors.grey,
      "Contributor": Colors.blue,
      "Veteran": Colors.green,
      "Pro": const Color(0xFFEBB411),
    };

    final color = colorMap[label] ?? Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey),
        // borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTabs(ThemeData theme) {
    List<String> tabs = [
      "Threads",
      "Comments",
      "Likes",
      "Followers",
      "Following",
      "Badges",
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            return Row(
              children: [
                _tabItem(tabs[index]),
                if (index != tabs.length - 1) const SizedBox(width: 8),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _tabItem(String title) {
    final isSelected = _selectedTab == title;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: isSelected ? const Color(0xFFEBB411) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFFEBB411) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                isSelected
                    ? Colors.white
                    : isDark
                    ? Colors.white
                    : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildThreadCard(String title, String author) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.forum, color: Color(0xFFEBB411)),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Text(
            "by $author",
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.access_time, size: 14, color: Colors.grey),
          Text(
            " 4 hours ago",
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      onTap: () {},
    );
  }

  Widget _buildCommentCard(String comment, String threadTitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.comment, color: Colors.blue),
      title: Text(comment, style: GoogleFonts.inter(fontSize: 14)),
      subtitle: Text(
        "on \"$threadTitle\"",
        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
      ),
    );
  }

  Widget _buildLikeCard(String likedThread) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.thumb_up, color: Colors.green),
      title: Text(
        "Liked \"$likedThread\"",
        style: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }

  Widget _buildBadgesList() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        children:
            badges
                .map(
                  (b) => ListTile(
                    leading: const Icon(Icons.verified, color: Colors.orange),
                    title: Text(
                      b,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}
