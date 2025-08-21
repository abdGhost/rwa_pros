import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewProfileScreen extends StatefulWidget {
  const NewProfileScreen({super.key});

  @override
  State<NewProfileScreen> createState() => _NewProfileScreenState();
}

class _NewProfileScreenState extends State<NewProfileScreen> {
  String _selectedTab = "Threads";

  // ====== State from SharedPreferences (with sensible defaults) ======
  String? _userName; // name
  String? _userId;
  String? _profileImageUrl; // profileImage
  String? _bannerImageUrl; // bannerImage
  String? _description; // description
  String? _createdAt; // createdAt (ISO)
  String? _tier; // tieredProgression

  int _totalFollower = 0;
  int _totalFollowing = 0;
  int _totalCommentGiven = 0;
  int _totalCommentReceived = 0;
  int _totalLikeReceived = 0;
  int _totalThreadPosted = 0;
  int _totalViewReceived = 0;

  // Demo content (kept as-is)
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

  @override
  void initState() {
    super.initState();
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Read values saved during login flows
    final loadedUserId = prefs.getString('userId');
    final loadedName = prefs.getString('name');
    final loadedProfileImg = prefs.getString('profileImage');
    final loadedBannerImg = prefs.getString('bannerImage');
    final loadedDescription = prefs.getString('description');
    final loadedCreatedAt = prefs.getString('createdAt');
    final loadedTier = prefs.getString('tieredProgression');

    final loadedFollower = prefs.getInt('totalFollower') ?? 0;
    final loadedFollowing = prefs.getInt('totalFollowing') ?? 0;
    final loadedCommentGiven = prefs.getInt('totalCommentGiven') ?? 0;
    final loadedCommentReceived = prefs.getInt('totalCommentReceived') ?? 0;
    final loadedLikeReceived = prefs.getInt('totalLikeReceived') ?? 0;
    final loadedThreadPosted = prefs.getInt('totalThreadPosted') ?? 0;
    final loadedViewReceived = prefs.getInt('totalViewReceived') ?? 0;

    // Assign to state
    setState(() {
      _userId = loadedUserId ?? ""; // ✅ now included
      _userName =
          (loadedName == null || loadedName.isEmpty) ? "John Doe" : loadedName;
      _profileImageUrl = loadedProfileImg ?? "";
      _bannerImageUrl = loadedBannerImg ?? "";
      _description =
          (loadedDescription == null || loadedDescription.isEmpty)
              ? "Condo is the first RWA-focused memetoken powered by a fully transparent on-chain treasury. Combining community culture with real-world assets, Condo bridges meme energy and institutional-grade RWA investments, offering both fun and real value."
              : loadedDescription;
      _createdAt = loadedCreatedAt ?? "";
      _tier = loadedTier ?? "New User";

      _totalFollower = loadedFollower;
      _totalFollowing = loadedFollowing;
      _totalCommentGiven = loadedCommentGiven;
      _totalCommentReceived = loadedCommentReceived;
      _totalLikeReceived = loadedLikeReceived;
      _totalThreadPosted = loadedThreadPosted;
      _totalViewReceived = loadedViewReceived;
    });

    // Debug print (optional)
    debugPrint("===== 🔐 Stored User Profile (SharedPreferences) =====");
    debugPrint("User ID: $_userId");
    debugPrint("Name: $_userName");
    debugPrint("Profile Image: $_profileImageUrl");
    debugPrint("Banner Image: $_bannerImageUrl");
    debugPrint("Tier: $_tier");
    debugPrint("CreatedAt: $_createdAt");
    debugPrint("Followers: $_totalFollower | Following: $_totalFollowing");
    debugPrint(
      "Comments Given: $_totalCommentGiven | Received: $_totalCommentReceived",
    );
    debugPrint(
      "Likes Received: $_totalLikeReceived | Threads: $_totalThreadPosted | Views: $_totalViewReceived",
    );
    debugPrint("======================================================");
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "U";
    final parts = name.trim().split(RegExp(r"\s+"));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatJoinedDate(String? iso) {
    if (iso == null || iso.isEmpty) return "Joined: Unknown";
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      final d = dt.day.toString().padLeft(2, '0');
      final m = months[dt.month - 1];
      final y = dt.year.toString();
      return "Joined: $d $m $y";
    } catch (_) {
      return "Joined: Unknown";
    }
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
                  // Banner
                  SizedBox(
                    height: 130,
                    width: double.infinity,
                    child:
                        _bannerImageUrl != null && _bannerImageUrl!.isNotEmpty
                            ? Image.network(_bannerImageUrl!, fit: BoxFit.cover)
                            : Image.asset(
                              'assets/airdrop.png',
                              fit: BoxFit.cover,
                            ),
                  ),

                  // Avatar
                  Positioned(
                    bottom: -40,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.black : Colors.white,
                        boxShadow: const [
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
                            _profileImageUrl != null &&
                                    _profileImageUrl!.isNotEmpty
                                ? NetworkImage(_profileImageUrl!)
                                : null,
                        child:
                            (_profileImageUrl == null ||
                                    _profileImageUrl!.isEmpty)
                                ? Text(
                                  _getInitials(_userName ?? "John Doe"),
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

            // Name
            Text(
              _userName ?? "John Doe",
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 6),

            // Tier (small text)
            Text(
              _tier ?? "New User",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 10),

            // Badges row (kept as-is)
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: badges.map((b) => _buildBadge(b, isDark)).toList(),
            ),

            const SizedBox(height: 10),

            // Joined date
            Text(
              _formatJoinedDate(_createdAt),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
            ),

            const SizedBox(height: 12),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                (_description == null || _description!.isEmpty)
                    ? "No bio yet"
                    : _description!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            // Simple stats row (optional, non-intrusive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statItem("Followers", _totalFollower),
                  const SizedBox(width: 22),
                  _statItem("Following", _totalFollowing),
                ],
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

  Widget _statItem(String label, int value) {
    return Column(
      children: [
        Text(
          "$value",
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
      ],
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
