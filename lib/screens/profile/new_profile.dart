import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class NewProfileScreen extends StatefulWidget {
  /// If null or equal to the logged-in user's id (from SharedPreferences),
  /// we treat it as "my profile". Otherwise it's "someone else's profile".
  final String? viewedUserId;

  /// Optional initial follow state when viewing someone else.
  final bool isFollowingInitial;

  const NewProfileScreen({
    super.key,
    this.viewedUserId,
    this.isFollowingInitial = false,
  });

  @override
  State<NewProfileScreen> createState() => _NewProfileScreenState();
}

class _NewProfileScreenState extends State<NewProfileScreen> {
  String _selectedTab = "Threads";

  // ====== LOGGED-IN (from SharedPreferences) ======
  String? _userName; // me
  String? _userId; // me
  String? _profileImageUrl; // me
  String? _bannerImageUrl; // me
  String? _description; // me
  String? _createdAt; // me
  String? _tier; // me

  int _totalFollower = 0;
  int _totalFollowing = 0;
  int _totalCommentGiven = 0;
  int _totalCommentReceived = 0;
  int _totalLikeReceived = 0;
  int _totalThreadPosted = 0;
  int _totalViewReceived = 0;

  // ====== VIEWED PROFILE (from /users/detail/{id}) ======
  bool _isViewedLoading = false;
  String? _viewedError;

  String? _vpName;
  String? _vpProfileImg;
  String? _vpBannerImg;
  String? _vpDescription;
  String? _vpCreatedAt;
  String? _vpTier; // from stat.tieredProgression
  List<Map<String, String>> _vpLinks = []; // [{platform,url}]

  int _vpFollower = 0;
  int _vpFollowing = 0;
  int _vpCommentGiven = 0;
  int _vpCommentReceived = 0;
  int _vpLikeReceived = 0;
  int _vpThreadPosted = 0;
  int _vpViewReceived = 0;

  // Follow state when viewing someone else
  bool _isFollowing = false;

  // ====== Badges for viewed profile ======
  bool _isBadgesLoading = false;
  String? _badgesError;
  final Map<String, List<String>> _viewedBadges = {
    "Tier": [],
    "Reputation": [],
    "Star": [],
    "Influence": [],
    "Quality": [],
    "VIP": [],
  };

  // Demo content (keep your preview lists)
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

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowingInitial;
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    debugPrint('🔎 viewedUserId → ${widget.viewedUserId}');
    final prefs = await SharedPreferences.getInstance();

    // Logged-in values
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

    setState(() {
      _userId = loadedUserId ?? "";
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

    // If viewing someone else, fetch their details + badges
    if (!_isMe && (widget.viewedUserId ?? "").isNotEmpty) {
      await Future.wait([
        _fetchViewedUserDetail(widget.viewedUserId!),
        _fetchViewedUserBadges(widget.viewedUserId!),
      ]);
    }

    // Debug (optional)
    debugPrint("===== 🔐 Stored User Profile (SharedPreferences) =====");
    debugPrint("Logged-in user ID: $_userId");
    debugPrint("Viewing profile ID : ${widget.viewedUserId ?? '(self)'}");
    debugPrint("======================================================");
  }

  bool get _isMe {
    // If no viewedUserId provided, treat as my profile
    final viewedId = widget.viewedUserId;
    if (viewedId == null || viewedId.isEmpty) return true;
    // Compare with logged-in id from prefs
    return viewedId == (_userId ?? "");
  }

  // -------- Fetch full detail for viewed user ----------
  Future<void> _fetchViewedUserDetail(String userId) async {
    setState(() {
      _isViewedLoading = true;
      _viewedError = null;
      _vpLinks = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('token'); // optional

      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/users/detail/$userId",
      );

      final res = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          if (jwt != null && jwt.isNotEmpty) "Authorization": "Bearer $jwt",
        },
      );

      if (res.statusCode != 200) {
        throw Exception("HTTP ${res.statusCode}: ${res.body}");
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["status"] != true ||
          data["userDetail"] == null ||
          data["stat"] == null) {
        throw Exception("Invalid payload");
      }

      final detail = (data["userDetail"] as Map<String, dynamic>);
      final stat = (data["stat"] as Map<String, dynamic>);

      // detail
      _vpName = (detail["userName"] ?? "").toString();
      _vpProfileImg = (detail["profileImg"] ?? "").toString();
      _vpBannerImg = (detail["bannerImg"] ?? "").toString();
      _vpDescription = (detail["description"] ?? "").toString();
      _vpCreatedAt = (detail["createdAt"] ?? "").toString();

      final linksDyn = (detail["link"] as List?) ?? [];
      _vpLinks =
          linksDyn
              .map<Map<String, String>>(
                (e) => {
                  "platform": (e["platform"] ?? "").toString(),
                  "url": (e["url"] ?? "").toString(),
                },
              )
              .where((m) => m["platform"]!.isNotEmpty && m["url"]!.isNotEmpty)
              .toList();

      // stat
      _vpFollower = (stat["totalFollower"] ?? 0) as int;
      _vpFollowing = (stat["totalFollowing"] ?? 0) as int;
      _vpCommentGiven = (stat["totalCommentGiven"] ?? 0) as int;
      _vpCommentReceived = (stat["totalCommentReceived"] ?? 0) as int;
      _vpLikeReceived = (stat["totalLikeReceived"] ?? 0) as int;
      _vpThreadPosted = (stat["totalThreadPosted"] ?? 0) as int;
      _vpViewReceived = (stat["totalViewReceived"] ?? 0) as int;
      _vpTier = (stat["tieredProgression"] ?? "").toString();
    } catch (e) {
      _viewedError = "Failed to load profile";
      debugPrint("❌ Viewed profile error: $e");
    } finally {
      if (mounted) setState(() => _isViewedLoading = false);
    }
  }

  // -------- Fetch badges for viewed user ----------
  Future<void> _fetchViewedUserBadges(String userId) async {
    setState(() {
      _isBadgesLoading = true;
      _badgesError = null;
      // clear previous
      _viewedBadges.updateAll((key, value) => []);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('token'); // optional auth

      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/users/badges/$userId",
      );

      final res = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          if (jwt != null && jwt.isNotEmpty) "Authorization": "Bearer $jwt",
        },
      );

      if (res.statusCode != 200) {
        throw Exception("HTTP ${res.statusCode}: ${res.body}");
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["status"] != true || data["userStat"] == null) {
        throw Exception("Invalid payload");
      }

      final userStat = data["userStat"] as Map<String, dynamic>;

      List<String> _asList(dynamic v) {
        if (v == null) return [];
        if (v is List) {
          return v
              .map((e) => (e ?? "").toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        final s = v.toString().trim();
        return s.isEmpty ? [] : [s];
      }

      final tier = _asList(userStat["tieredProgression"]);
      final reput = _asList(userStat["reputation"]);
      final star = _asList(userStat["star"]);
      final infl = _asList(userStat["influence"]);
      final qual = _asList(userStat["quality"]);
      final vip = _asList(userStat["vip"]);

      setState(() {
        _viewedBadges["Tier"] = tier;
        _viewedBadges["Reputation"] = reput;
        _viewedBadges["Star"] = star;
        _viewedBadges["Influence"] = infl;
        _viewedBadges["Quality"] = qual;
        _viewedBadges["VIP"] = vip;
      });
    } catch (e) {
      setState(() {
        _badgesError = "Failed to load badges";
      });
      debugPrint("❌ Badges fetch error: $e");
    } finally {
      if (mounted) {
        setState(() => _isBadgesLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    // TODO: call your follow/unfollow API here.
    // Example:
    // final token = (await SharedPreferences.getInstance()).getString('token');
    // await http.post(Uri.parse(".../follow"),
    //   headers: {"Authorization":"Bearer $token"},
    //   body: {"targetId": widget.viewedUserId});
    setState(() => _isFollowing = !_isFollowing);
    debugPrint(_isFollowing ? "✅ Now following" : "❌ Unfollowed");
  }

  void _onEditProfile() {
    // TODO: Navigate to your edit profile screen
    debugPrint("📝 Edit profile tapped");
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

    final bool useViewed = !_isMe;

    // Top fields
    final displayName =
        useViewed ? (_vpName ?? "User") : (_userName ?? "John Doe");
    final displayProfileImg =
        useViewed ? (_vpProfileImg ?? "") : (_profileImageUrl ?? "");
    final displayBannerImg =
        useViewed ? (_vpBannerImg ?? "") : (_bannerImageUrl ?? "");
    final displayDesc =
        useViewed ? (_vpDescription ?? "") : (_description ?? "");
    final displayCreatedAt =
        useViewed ? (_vpCreatedAt ?? "") : (_createdAt ?? "");
    final displayTier = useViewed ? (_vpTier ?? "") : (_tier ?? "");

    // Stats for tabs
    final tThreads = useViewed ? _vpThreadPosted : _totalThreadPosted;
    final tComments = useViewed ? _vpCommentGiven : _totalCommentGiven;
    final tLikes = useViewed ? _vpLikeReceived : _totalLikeReceived;
    final tFollowers = useViewed ? _vpFollower : _totalFollower;
    final tFollowing = useViewed ? _vpFollowing : _totalFollowing;

    final List<String> tabs = [
      "Threads ($tThreads)",
      "Comments ($tComments)",
      "Likes ($tLikes)",
      "Followers ($tFollowers)",
      "Following ($tFollowing)",
    ];

    // Normalize selection if a label changed due to counts
    if (!tabs.any((t) => t.startsWith(_selectedTab))) {
      _selectedTab = "Threads";
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        toolbarHeight: 60,
        title: Text(
          _isMe ? 'My Account' : 'Profile',
          style: GoogleFonts.inter(
            textStyle: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        actions: [
          if (_isMe)
            IconButton(
              icon: Icon(Icons.edit, size: 26, color: theme.iconTheme.color),
              onPressed: _onEditProfile,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor:
                      _isFollowing
                          ? Colors.grey.shade300
                          : const Color(0xFFEBB411),
                  foregroundColor: _isFollowing ? Colors.black87 : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _toggleFollow,
                child: Text(
                  _isFollowing ? "Following" : "Follow",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body:
          useViewed && _isViewedLoading
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 24.0),
                  child: CircularProgressIndicator(),
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Banner & Avatar
                    Container(
                      margin: const EdgeInsets.only(bottom: 40),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            height: 130,
                            width: double.infinity,
                            child:
                                (displayBannerImg.isNotEmpty)
                                    ? Image.network(
                                      displayBannerImg,
                                      fit: BoxFit.cover,
                                    )
                                    : Image.asset(
                                      'assets/airdrop.png',
                                      fit: BoxFit.cover,
                                    ),
                          ),
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
                                    (displayProfileImg.isNotEmpty)
                                        ? NetworkImage(displayProfileImg)
                                        : null,
                                child:
                                    (displayProfileImg.isEmpty)
                                        ? Text(
                                          _getInitials(displayName),
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
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Tier
                    if ((displayTier).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _buildTierChip(displayTier, isDark),
                      ),

                    const SizedBox(height: 10),

                    // Joined date
                    Text(
                      _formatJoinedDate(displayCreatedAt),
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
                        displayDesc.isEmpty ? "No bio yet" : displayDesc,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Social Links (only when viewing others & links exist)
                    if (!_isMe && _vpLinks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildLinksRow(_vpLinks, Theme.of(context)),
                    ],

                    // // Badges (viewing others)
                    // if (!_isMe) _buildBadgesSection(Theme.of(context)),
                    const SizedBox(height: 16),
                    _buildTabs(Theme.of(context), tabs),
                    const SizedBox(height: 8),

                    // Tab content (demo)
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
                    if (_selectedTab == "Followers")
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "Followers: ${useViewed ? _vpFollower : _totalFollower}",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (_selectedTab == "Following")
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "Following: ${useViewed ? _vpFollowing : _totalFollowing}",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    if (useViewed && _viewedError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _viewedError!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  // ---------- Badges section ----------
  Widget _buildBadgesSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    // If still loading
    if (_isBadgesLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                "Loading badges...",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If error
    if (_badgesError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          _badgesError!,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Build rows per category if any items exist
    final List<Widget> rows = [];
    _viewedBadges.forEach((category, items) {
      if (items.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              category,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((b) => _buildBadgeChip(b, isDark)).toList(),
          ),
        ),
      );
    });

    if (rows.isEmpty) {
      // No badges present
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const SizedBox(height: 8), ...rows, const SizedBox(height: 4)],
    );
  }

  Widget _buildBadgeChip(String label, bool isDark) {
    // you can tune colors per label or by category if you want
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTierChip(String label, bool isDark) {
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

  Widget _buildTabs(ThemeData theme, List<String> tabs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final title = tabs[index];
            final key = title.split(' ').first; // "Threads", "Comments", etc.
            final isSelected = _selectedTab == key;

            return Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedTab = key),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color:
                          isSelected
                              ? const Color(0xFFEBB411)
                              : Colors.transparent,
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFFEBB411)
                                : Colors.grey.shade300,
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
                                : (theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black),
                      ),
                    ),
                  ),
                ),
                if (index != tabs.length - 1) const SizedBox(width: 8),
              ],
            );
          }),
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
        'on "$threadTitle"',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
      ),
    );
  }

  Widget _buildLikeCard(String likedThread) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.thumb_up, color: Colors.green),
      title: Text(
        'Liked "$likedThread"',
        style: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }

  // ---------- Social links row ----------
  // Widget _buildLinksRow(List<Map<String, String>> links, ThemeData theme) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16),
  //     child: Wrap(
  //       spacing: 8,
  //       runSpacing: 8,
  //       children:
  //           links.map((m) {
  //             final platform = m["platform"]!;
  //             String url = m["url"]!;
  //             // prepend scheme if missing
  //             if (!url.startsWith("http://") && !url.startsWith("https://")) {
  //               url = "https://$url";
  //             }
  //             final icon = _iconForPlatform(platform);
  //             return InkWell(
  //               onTap: () async {
  //                 final uri = Uri.parse(url);
  //                 if (await canLaunchUrl(uri)) {
  //                   await launchUrl(uri, mode: LaunchMode.externalApplication);
  //                 } else {
  //                   ScaffoldMessenger.of(
  //                     context,
  //                   ).showSnackBar(SnackBar(content: Text("Cannot open $url")));
  //                 }
  //               },
  //               child: Container(
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 10,
  //                   vertical: 6,
  //                 ),
  //                 decoration: BoxDecoration(
  //                   color:
  //                       theme.brightness == Brightness.dark
  //                           ? Colors.grey.shade800
  //                           : Colors.grey.shade200,
  //                   borderRadius: BorderRadius.circular(6),
  //                   border: Border.all(
  //                     color:
  //                         theme.brightness == Brightness.dark
  //                             ? Colors.grey.shade700
  //                             : Colors.grey.shade300,
  //                   ),
  //                 ),
  //                 child: Row(
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     Icon(icon, size: 14),
  //                     const SizedBox(width: 6),
  //                     Text(
  //                       platform,
  //                       style: GoogleFonts.inter(
  //                         fontSize: 12,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             );
  //           }).toList(),
  //     ),
  //   );
  // }

  Widget _buildLinksRow(List<Map<String, String>> links, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        children:
            links.map((m) {
              final platform = m["platform"]!;
              String url = m["url"]!;
              // prepend scheme if missing
              if (!url.startsWith("http://") && !url.startsWith("https://")) {
                url = "https://$url";
              }
              final icon = _iconForPlatform(platform);

              return InkWell(
                onTap: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Cannot open $url")));
                  }
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  child: Icon(
                    icon,
                    size: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  IconData _iconForPlatform(String p) {
    switch (p.toLowerCase()) {
      case "twitter":
      case "x":
        return FontAwesomeIcons.xTwitter; // better icon for X/Twitter
      case "telegram":
        return FontAwesomeIcons.telegram;
      case "linkedin":
        return FontAwesomeIcons.linkedin;
      case "youtube":
        return FontAwesomeIcons.youtube;
      case "medium":
        return FontAwesomeIcons.medium;
      default:
        return FontAwesomeIcons.link;
    }
  }
}
