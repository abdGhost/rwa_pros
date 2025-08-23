// new_profile_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rwa_app/screens/edit_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ⬇️ existing: open thread details
import 'package:rwa_app/screens/thread_details_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class NewProfileScreen extends StatefulWidget {
  final String? viewedUserId;
  final bool isFollowingInitial;
  final String? filterForumIdForComments;

  const NewProfileScreen({
    super.key,
    this.viewedUserId,
    this.isFollowingInitial = false,
    this.filterForumIdForComments,
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

  // ====== Follow/Unfollow network state ======
  bool _isFollowBusy = false;
  String? _followError;

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

  // ====== Forums created by target user ======
  bool _isForumsLoading = false;
  String? _forumsError;
  List<Map<String, dynamic>> _createdForums = [];
  int _createdForumsTotal = 0;

  // ====== Forums liked by target user ======
  bool _isLikesLoading = false;
  String? _likesError;
  List<Map<String, dynamic>> _likedForums = [];
  int _likedForumsTotal = 0;

  // ====== Comments by target user ======
  bool _isCommentsLoading = false;
  String? _commentsError;
  List<Map<String, dynamic>> _userComments = [];

  // ====== Followers ======
  bool _isFollowersLoading = false;
  String? _followersError;
  List<Map<String, dynamic>> _followers = [];
  int _followersTotal = 0;
  int _followersPage = 1;
  int _followersSize = 20;
  String _followersFilter = "";

  // ====== Followings ======
  bool _isFollowingLoading = false;
  String? _followingError;
  List<Map<String, dynamic>> _followings = [];
  int _followingsTotal = 0;
  int _followingsPage = 1;
  int _followingsSize = 20;
  String _followingsFilter = "";

  // ⬇️ NEW: shared socket to pass into ThreadDetailScreen
  late IO.Socket _socket;

  // ⬇️ NEW: social links for *my* profile (self)
  List<Map<String, String>> _myLinks = []; // [{platform,url}]

  // --- THEME HELPERS (dark/light aware) ---
  Color _cardBg(ThemeData t) =>
      t.brightness == Brightness.dark ? const Color(0xFF121317) : Colors.white;

  Color _chipBg(ThemeData t) =>
      t.brightness == Brightness.dark
          ? const Color(0xFF1A1C20)
          : const Color.fromARGB(209, 237, 237, 237);

  Color _outline(ThemeData t) {
    return t.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.06)
        : (t.colorScheme.outlineVariant.withOpacity(0.5));
  }

  Color _muted(ThemeData t) => t.colorScheme.onSurface.withOpacity(0.64);
  Color _mutedStrong(ThemeData t) => t.colorScheme.onSurface.withOpacity(0.80);

  MaterialStateProperty<Color?> _inkOverlay(ThemeData t) {
    final base = t.colorScheme.primary;
    return MaterialStateProperty.resolveWith<Color?>((states) {
      if (states.contains(MaterialState.pressed)) {
        return base.withOpacity(t.brightness == Brightness.dark ? 0.12 : 0.08);
      }
      if (states.contains(MaterialState.hovered)) {
        return base.withOpacity(t.brightness == Brightness.dark ? 0.06 : 0.04);
      }
      return Colors.transparent;
    });
  }

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowingInitial;

    // ⬇️ NEW: init socket once for this screen
    _socket = IO.io(
      'https://rwa-f1623a22e3ed.herokuapp.com',
      IO.OptionBuilder().setTransports(['websocket']).build(),
    );
    if (!_socket.connected) _socket.connect();

    _loadFromPrefs();
  }

  @override
  void dispose() {
    try {
      _socket.dispose();
    } catch (_) {}
    super.dispose();
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

    // Determine target user (self or viewed)
    final targetUserId =
        (widget.viewedUserId != null && widget.viewedUserId!.isNotEmpty)
            ? widget.viewedUserId!
            : (_userId ?? "");

    // For viewed profiles, pull full detail + badges
    final futures = <Future>[];
    if (!_isMe && (widget.viewedUserId ?? "").isNotEmpty) {
      futures.add(_fetchViewedUserDetail(widget.viewedUserId!));
      futures.add(_fetchViewedUserBadges(widget.viewedUserId!));
    }

    // ⬇️ NEW: also fetch *my* links so social icons show on my own profile
    if (_isMe && (_userId ?? "").isNotEmpty) {
      futures.add(_fetchMyLinksAndTier(_userId!));
    }

    // Always fetch created + liked forums + comments for the target user
    futures.add(_fetchUserForums(targetUserId, page: 1, size: 20));
    futures.add(_fetchUserLikedForums(targetUserId, page: 1, size: 20));
    futures.add(
      _fetchUserComments(
        targetUserId,
        forumId: widget.filterForumIdForComments,
      ),
    );

    // Also fetch followers/followings (eager)
    futures.add(_fetchFollowers(targetUserId, page: 1, size: 20));
    futures.add(_fetchFollowings(targetUserId, page: 1, size: 20));

    await Future.wait(futures);

    // Debug (optional)
    debugPrint("===== 🔐 Stored User Profile (SharedPreferences) =====");
    debugPrint("Logged-in user ID: $_userId");
    debugPrint("Viewing profile ID : ${widget.viewedUserId ?? '(self)'}");
    debugPrint("Target user for lists: $targetUserId");
    debugPrint(
      "Comments filter forumId: ${widget.filterForumIdForComments ?? '(none)'}",
    );
    debugPrint("======================================================");
  }

  bool get _isMe {
    final viewedId = widget.viewedUserId;
    if (viewedId == null || viewedId.isEmpty) return true;
    return viewedId == (_userId ?? "");
  }

  // ---------- Auth headers ----------
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('token');
    return {
      "Content-Type": "application/json",
      if (jwt != null && jwt.isNotEmpty) "Authorization": "Bearer $jwt",
    };
  }

  // -------- Fetch full detail for viewed user ----------
  Future<void> _fetchViewedUserDetail(String userId) async {
    setState(() {
      _isViewedLoading = true;
      _viewedError = null;
      _vpLinks = [];
    });

    try {
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/users/detail/$userId",
      );

      final res = await http.get(uri, headers: await _authHeaders());

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

  // ⬇️ NEW: fetch *my* links & tier (so my own profile shows social icons)
  Future<void> _fetchMyLinksAndTier(String userId) async {
    try {
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/users/detail/$userId",
      );
      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}");

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["status"] != true || data["userDetail"] == null) {
        throw Exception("Invalid payload");
      }

      final detail = (data["userDetail"] as Map<String, dynamic>);
      final linksDyn = (detail["link"] as List?) ?? [];
      final myLinks =
          linksDyn
              .map<Map<String, String>>(
                (e) => {
                  "platform": (e["platform"] ?? "").toString(),
                  "url": (e["url"] ?? "").toString(),
                },
              )
              .where((m) => m["platform"]!.isNotEmpty && m["url"]!.isNotEmpty)
              .toList();

      // optional tier override from stat if present
      final stat = (data["stat"] as Map<String, dynamic>?);
      final myTier = stat?["tieredProgression"]?.toString();

      setState(() {
        _myLinks = myLinks;
        if ((myTier ?? "").isNotEmpty) _tier = myTier;
      });
    } catch (e) {
      debugPrint("❌ fetchMyLinksAndTier error: $e");
    }
  }

  // -------- Fetch badges for viewed user ----------
  Future<void> _fetchViewedUserBadges(String userId) async {
    setState(() {
      _isBadgesLoading = true;
      _badgesError = null;
      _viewedBadges.updateAll((key, value) => []);
    });

    try {
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/users/badges/$userId",
      );

      final res = await http.get(uri, headers: await _authHeaders());

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

      setState(() {
        _viewedBadges["Tier"] = _asList(userStat["tieredProgression"]);
        _viewedBadges["Reputation"] = _asList(userStat["reputation"]);
        _viewedBadges["Star"] = _asList(userStat["star"]);
        _viewedBadges["Influence"] = _asList(userStat["influence"]);
        _viewedBadges["Quality"] = _asList(userStat["quality"]);
        _viewedBadges["VIP"] = _asList(userStat["vip"]);
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

  // -------- Forums created by user ----------
  Future<void> _fetchUserForums(
    String userId, {
    int page = 1,
    int size = 20,
    String? categoryId,
  }) async {
    setState(() {
      _isForumsLoading = true;
      _forumsError = null;
      _createdForums = [];
      _createdForumsTotal = 0;
    });

    try {
      final String qCategory =
          (categoryId != null && categoryId.isNotEmpty) ? categoryId : "";
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/forum/user/$userId"
        "?categoryId=$qCategory&page=$page&size=$size",
      );

      final res = await http.get(uri, headers: await _authHeaders());

      if (res.statusCode != 200) throw Exception(res.body);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["status"] == true) {
        final forums = (data["forums"] as List?) ?? [];
        setState(() {
          _createdForums =
              forums
                  .map<Map<String, dynamic>>((f) => f as Map<String, dynamic>)
                  .toList();
          _createdForumsTotal = (data["total"] ?? forums.length) as int;
        });
      } else {
        throw Exception("status != true");
      }
    } catch (e) {
      setState(() => _forumsError = "Failed to load threads");
      debugPrint("❌ fetchUserForums error: $e");
    } finally {
      if (mounted) setState(() => _isForumsLoading = false);
    }
  }

  // -------- Forums liked by user ----------
  Future<void> _fetchUserLikedForums(
    String userId, {
    int page = 1,
    int size = 20,
  }) async {
    setState(() {
      _isLikesLoading = true;
      _likesError = null;
      _likedForums = [];
      _likedForumsTotal = 0;
    });

    try {
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/forum/likes/user/$userId"
        "?page=$page&size=$size",
      );

      final res = await http.get(uri, headers: await _authHeaders());

      if (res.statusCode != 200) throw Exception(res.body);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["status"] == true) {
        final likes = (data["likedForum"] as List?) ?? [];
        setState(() {
          _likedForums =
              likes
                  .map<Map<String, dynamic>>((f) => f as Map<String, dynamic>)
                  .toList();
          _likedForumsTotal = (data["total"] ?? likes.length) as int;
        });
      } else {
        throw Exception("status != true");
      }
    } catch (e) {
      setState(() => _likesError = "Failed to load liked forums");
      debugPrint("❌ fetchUserLikedForums error: $e");
    } finally {
      if (mounted) setState(() => _isLikesLoading = false);
    }
  }

  // -------- Comments by user ----------
  Future<void> _fetchUserComments(String userId, {String? forumId}) async {
    setState(() {
      _isCommentsLoading = true;
      _commentsError = null;
      _userComments = [];
    });

    try {
      final qForum =
          (forumId != null && forumId.isNotEmpty) ? "?forumId=$forumId" : "";
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/forum/comment/user/$userId$qForum",
      );

      final res = await http.get(uri, headers: await _authHeaders());

      if (res.statusCode != 200) throw Exception(res.body);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["status"] == true) {
        final list = (data["userComments"] as List?) ?? [];
        setState(() {
          _userComments =
              list
                  .map<Map<String, dynamic>>((c) => c as Map<String, dynamic>)
                  .toList();
        });
      } else {
        throw Exception("status != true");
      }
    } catch (e) {
      setState(() => _commentsError = "Failed to load comments");
      debugPrint("❌ fetchUserComments error: $e");
    } finally {
      if (mounted) setState(() => _isCommentsLoading = false);
    }
  }

  // -------- Followers --------
  Future<void> _fetchFollowers(
    String userId, {
    int? page,
    int? size,
    String? filter,
  }) async {
    setState(() {
      _isFollowersLoading = true;
      _followersError = null;
    });

    try {
      final p = page ?? _followersPage;
      final s = size ?? _followersSize;
      final f = (filter ?? _followersFilter).trim();

      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/follow/allFollower/$userId"
        "?page=$p&size=$s&filter=$f",
      );

      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode != 200) throw Exception(res.body);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list =
          (data["followers"] ??
                  data["items"] ??
                  data["data"] ??
                  data["list"] ??
                  [])
              as List<dynamic>;

      setState(() {
        _followers =
            list
                .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map),
                )
                .toList();
        _followersTotal =
            (data["total"] ?? data["count"] ?? _followers.length) as int;
        _followersPage = p;
        _followersSize = s;
        _followersFilter = f;
      });
    } catch (e) {
      setState(() => _followersError = "Failed to load followers");
    } finally {
      setState(() => _isFollowersLoading = false);
    }
  }

  // -------- Followings --------
  Future<void> _fetchFollowings(
    String userId, {
    int? page,
    int? size,
    String? filter,
  }) async {
    setState(() {
      _isFollowingLoading = true;
      _followingError = null;
    });

    try {
      final p = page ?? _followingsPage;
      final s = size ?? _followingsSize;
      final f = (filter ?? _followingsFilter).trim();

      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/follow/allFollowing/$userId"
        "?page=$p&size=$s&filter=$f",
      );

      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode != 200) throw Exception(res.body);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list =
          (data["followings"] ??
                  data["items"] ??
                  data["data"] ??
                  data["list"] ??
                  [])
              as List<dynamic>;

      setState(() {
        _followings =
            list
                .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map),
                )
                .toList();
        _followingsTotal =
            (data["total"] ?? data["count"] ?? _followings.length) as int;
        _followingsPage = p;
        _followingsSize = s;
        _followingsFilter = f;
      });
    } catch (e) {
      setState(() => _followingError = "Failed to load followings");
    } finally {
      setState(() => _isFollowingLoading = false);
    }
  }

  // -------- Follow / Unfollow --------
  Future<void> _followUser(String targetUserId) async {
    if (_isFollowBusy) return;
    setState(() {
      _isFollowBusy = true;
      _followError = null;
    });

    try {
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/follow/$targetUserId",
      );
      final res = await http.post(uri, headers: await _authHeaders());
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception("HTTP ${res.statusCode}: ${res.body}");
      }
      setState(() {
        _isFollowing = true;
        _vpFollower += 1; // if viewing someone else
        _totalFollower += 1; // if it's me being followed
      });

      final target = widget.viewedUserId ?? "";
      if (target.isNotEmpty) {
        _fetchFollowers(target, page: _followersPage, size: _followersSize);
      }
    } catch (e) {
      setState(() => _followError = "Failed to follow user");
    } finally {
      setState(() => _isFollowBusy = false);
    }
  }

  Future<void> _unfollowUser(String targetUserId) async {
    if (_isFollowBusy) return;
    setState(() {
      _isFollowBusy = true;
      _followError = null;
    });

    try {
      final uri = Uri.parse(
        "https://rwa-f1623a22e3ed.herokuapp.com/api/follow/$targetUserId",
      );
      final res = await http.delete(uri, headers: await _authHeaders());
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception("HTTP ${res.statusCode}: ${res.body}");
      }
      setState(() {
        _isFollowing = false;
        _vpFollower = (_vpFollower - 1).clamp(0, 1 << 31);
        _totalFollower = (_totalFollower - 1).clamp(0, 1 << 31);
      });

      final target = widget.viewedUserId ?? "";
      if (target.isNotEmpty) {
        _fetchFollowers(target, page: _followersPage, size: _followersSize);
      }
    } catch (e) {
      setState(() => _followError = "Failed to unfollow user");
    } finally {
      setState(() => _isFollowBusy = false);
    }
  }

  Future<void> _toggleFollow() async {
    final targetId = widget.viewedUserId ?? "";
    if (targetId.isEmpty) return;
    if (_isFollowing) {
      await _unfollowUser(targetId);
    } else {
      await _followUser(targetId);
    }
  }

  void _onEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditProfileScreen(
              initialName: _userName ?? '',
              initialEmail: '',
              initialProfileImgUrl: _profileImageUrl ?? '',
              initialBannerImgUrl: _bannerImageUrl ?? '',
              initialLinks: _isMe ? [] : [],
            ),
      ),
    );

    if (result == true) {
      await _loadFromPrefs();
      setState(() {});
    }
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

  String _formatAgo(String? iso) {
    if (iso == null || iso.isEmpty) return "recent";
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().toUtc().difference(dt.toUtc());
      if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";
      return "${dt.day.toString().padLeft(2, '0')}/"
          "${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return "recent";
    }
  }

  // helpers to normalize + open a thread map
  String _forumTitleFrom(Map<String, dynamic> f) {
    final raw = (f['title'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;
    return _extractTextFromHtml(f['text'] ?? '');
  }

  String? _stringId(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map && v['_id'] != null) return v['_id'].toString();
    return null;
  }

  void _openThreadFromForumMap(Map<String, dynamic> f) {
    final id = (f['_id'] ?? f['id'] ?? '').toString();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open thread: missing id')),
      );
      return;
    }

    final threadPayload = <String, dynamic>{
      '_id': id,
      'title': _forumTitleFrom(f),
      'text': (f['text'] ?? '').toString(),
      'userId': f['userId'],
      'userName':
          (f['userId'] is Map && f['userId']['userName'] != null)
              ? f['userId']['userName'].toString()
              : (f['userName'] ?? '').toString(),
      'commentsCount':
          (f['commentsCount'] is num) ? (f['commentsCount'] as num).toInt() : 0,
      'categoryId': _stringId(f['categoryId']),
      'subCategoryId':
          _stringId(f['subCategoryId']) ?? _stringId(f['categoryId']),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ThreadDetailScreen(thread: threadPayload, socket: _socket),
      ),
    );
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
    final tComments =
        _userComments.isNotEmpty
            ? _userComments.length
            : (useViewed ? _vpCommentGiven : _totalCommentGiven);
    final likesCount =
        _likedForumsTotal > 0
            ? _likedForumsTotal
            : (useViewed ? _vpLikeReceived : _totalLikeReceived);
    final tLikes = likesCount;
    final tFollowers = useViewed ? _vpFollower : _totalFollower;
    final tFollowing = useViewed ? _vpFollowing : _totalFollowing;

    final List<String> tabs = [
      "Threads ($tThreads)",
      "Comments ($tComments)",
      "Likes ($tLikes)",
      "Followers ($tFollowers)",
      "Following ($tFollowing)",
    ];

    if (!tabs.any((t) => t.startsWith(_selectedTab))) {
      _selectedTab = "Threads";
    }

    // ⬇️ NEW: decide which links to show (self vs viewed)
    final linksToShow = _isMe ? _myLinks : _vpLinks;

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
              color: theme.colorScheme.onSurface,
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
                onPressed: _isFollowBusy ? null : _toggleFollow,
                child:
                    _isFollowBusy
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Text(
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
                  child: CircularProgressIndicator(color: Color(0xFFEBB411)),
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                        color: _muted(theme),
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // ⬇️ Social Links
                    if (linksToShow.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildLinksRow(linksToShow, Theme.of(context)),
                    ],

                    const SizedBox(height: 16),
                    _buildTabs(Theme.of(context), tabs),
                    const SizedBox(height: 8),

                    // ----------------- Tab content -----------------
                    if (_selectedTab == "Threads")
                      _buildThreadsSection()
                    else if (_selectedTab == "Comments")
                      _buildCommentsSection()
                    else if (_selectedTab == "Likes")
                      _buildLikesSection()
                    else if (_selectedTab == "Followers")
                      _buildFollowersSection()
                    else if (_selectedTab == "Following")
                      _buildFollowingsSection(),

                    const SizedBox(height: 8),
                    if (_followError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _followError!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
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

  // ---------- Threads section (created forums) ----------
  Widget _buildThreadsSection() {
    final theme = Theme.of(context);

    if (_isForumsLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFEBB411)),
        ),
      );
    }
    if (_forumsError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _forumsError!,
          style: GoogleFonts.inter(color: Colors.redAccent),
        ),
      );
    }
    if (_createdForums.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "No threads yet",
          style: GoogleFonts.inter(fontSize: 13, color: _muted(theme)),
        ),
      );
    }

    int _countReactions(dynamic r) {
      if (r == null) return 0;
      if (r is Map) {
        try {
          return r.values
              .map((v) => (v is num) ? v.toInt() : 0)
              .fold(0, (a, b) => a + b);
        } catch (_) {
          return 0;
        }
      }
      return 0;
    }

    return Column(
      children:
          _createdForums.map((f) {
            final titleRaw = (f["title"] ?? "").toString();
            final title =
                titleRaw.trim().isEmpty
                    ? _extractTextFromHtml(f["text"] ?? "")
                    : titleRaw.trim();

            final textExcerpt = _extractTextFromHtml(f["text"] ?? "");
            final createdAt = f["createdAt"]?.toString();
            final author = f["userId"]?["userName"]?.toString() ?? "";
            final categoryName = f["categoryId"]?["name"]?.toString() ?? "";
            final commentsCount =
                (f["commentsCount"] is num)
                    ? (f["commentsCount"] as num).toInt()
                    : 0;
            final upvotes =
                (f["upvotes"] is num) ? (f["upvotes"] as num).toInt() : 0;
            final reactionsCount = _countReactions(f["reactions"]);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Card(
                elevation: 0,

                color: _cardBg(theme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: _outline(theme), width: 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openThreadFromForumMap(f),
                  overlayColor: _inkOverlay(theme),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: title + time
                        Row(
                          children: [
                            const Icon(
                              Icons.forum,
                              size: 16,
                              color: Color(0xFFEBB411),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title.isEmpty ? "(untitled)" : title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: _muted(theme),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatAgo(createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _muted(theme),
                              ),
                            ),
                          ],
                        ),

                        // Meta row: author • category
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (author.isNotEmpty)
                              Flexible(
                                child: Text(
                                  "by $author",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _muted(theme),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (author.isNotEmpty && categoryName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  "•",
                                  style: TextStyle(color: _muted(theme)),
                                ),
                              ),
                            if (categoryName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _chipBg(theme),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _outline(theme)),
                                ),
                                child: Text(
                                  categoryName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: _mutedStrong(theme),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Body excerpt (if any text)
                        if (textExcerpt.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            textExcerpt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13.0,
                              height: 1.35,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],

                        // // Footer stats
                        // const SizedBox(height: 10),
                        // Row(
                        //   children: [
                        //     Icon(
                        //       Icons.thumb_up_alt_outlined,
                        //       size: 16,
                        //       color: _muted(theme),
                        //     ),
                        //     const SizedBox(width: 4),
                        //     Text(
                        //       "$upvotes",
                        //       style: GoogleFonts.inter(
                        //         fontSize: 12,
                        //         color: _muted(theme),
                        //       ),
                        //     ),
                        //     const SizedBox(width: 14),
                        //     Icon(
                        //       Icons.emoji_emotions_outlined,
                        //       size: 16,
                        //       color: _muted(theme),
                        //     ),
                        //     const SizedBox(width: 4),
                        //     Text(
                        //       "$reactionsCount",
                        //       style: GoogleFonts.inter(
                        //         fontSize: 12,
                        //         color: _muted(theme),
                        //       ),
                        //     ),
                        //     const SizedBox(width: 14),
                        //     Icon(
                        //       Icons.mode_comment_outlined,
                        //       size: 16,
                        //       color: _muted(theme),
                        //     ),
                        //     const SizedBox(width: 4),
                        //     Text(
                        //       "$commentsCount",
                        //       style: GoogleFonts.inter(
                        //         fontSize: 12,
                        //         color: _muted(theme),
                        //       ),
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  // ---------- Comments section (tap → open parent forum) ----------
  Widget _buildCommentsSection() {
    final theme = Theme.of(context);

    if (_isCommentsLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFEBB411)),
        ),
      );
    }
    if (_commentsError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _commentsError!,
          style: GoogleFonts.inter(color: Colors.redAccent),
        ),
      );
    }
    if (_userComments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "No comments yet",
          style: GoogleFonts.inter(fontSize: 13, color: _muted(theme)),
        ),
      );
    }

    return Column(
      children:
          _userComments.map((c) {
            final text = (c["text"] ?? "").toString();
            final forum = c["forumId"] as Map<String, dynamic>?;
            final forumTitle = forum?["title"]?.toString() ?? "(forum)";
            final createdAt = c["createdAt"]?.toString();
            final quoted = c["quotedCommentedId"] as Map<String, dynamic>?;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Card(
                elevation: 0,
                color: _cardBg(theme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: _outline(theme), width: 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (forum == null ||
                        (forum['_id'] ?? forum['id']) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to open: missing forum'),
                        ),
                      );
                      return;
                    }
                    _openThreadFromForumMap(forum);
                  },
                  overlayColor: _inkOverlay(theme),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: forum title + time
                        Row(
                          children: [
                            const Icon(
                              Icons.forum,
                              size: 16,
                              color: Color(0xFFEBB411),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                forumTitle.trim().isEmpty
                                    ? "(forum)"
                                    : forumTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: _muted(theme),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatAgo(createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _muted(theme),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Quoted comment (if any)
                        if (quoted != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _chipBg(theme),
                              border: Border(
                                left: BorderSide(
                                  color: _outline(theme),
                                  width: 3,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (quoted["username"] != null &&
                                          quoted["username"]
                                              .toString()
                                              .isNotEmpty)
                                      ? "-${quoted["username"]}"
                                      : "Quoted comment",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _mutedStrong(theme),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (quoted["text"] ?? "").toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // User's comment
                        Text(
                          text,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  // ---------- Likes section (liked forums) ----------
  Widget _buildLikesSection() {
    final theme = Theme.of(context);

    if (_isLikesLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFEBB411)),
        ),
      );
    }
    if (_likesError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _likesError!,
          style: GoogleFonts.inter(color: Colors.redAccent),
        ),
      );
    }
    if (_likedForums.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "No likes yet",
          style: GoogleFonts.inter(fontSize: 13, color: _muted(theme)),
        ),
      );
    }

    return Column(
      children:
          _likedForums.map((l) {
            final forum = l["forumId"] as Map<String, dynamic>?;
            final title = (forum?["title"] ?? "").toString().trim();
            final fallbackTitle = _extractTextFromHtml(forum?["text"] ?? "");
            final forumTitle =
                title.isNotEmpty
                    ? title
                    : (fallbackTitle.isNotEmpty ? fallbackTitle : "(untitled)");
            final author = (forum?["userId"]?["userName"] ?? "").toString();
            final createdAt =
                (l["createdAt"] ?? forum?["createdAt"] ?? "").toString();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Card(
                elevation: 0,
                color: _cardBg(theme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: _outline(theme), width: 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    final map = forum ?? {};
                    if (map.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to open: missing forum data'),
                        ),
                      );
                      return;
                    }
                    _openThreadFromForumMap(map);
                  },
                  overlayColor: _inkOverlay(theme),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: liked + time
                        Row(
                          children: [
                            const Icon(
                              Icons.thumb_up_alt_outlined,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                forumTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: _muted(theme),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatAgo(createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _muted(theme),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (author.isNotEmpty)
                          Text(
                            "by $author",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _muted(theme),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  // ---------- Inline follow helpers ----------
  bool _isFollowingUser(String userId) {
    return _followings.any((it) => _pickUserFromItem(it)["id"] == userId);
  }

  Future<void> _toggleFollowUserInline(String userId) async {
    final currentlyFollowing = _isFollowingUser(userId);
    if (currentlyFollowing) {
      await _unfollowUser(userId);
    } else {
      await _followUser(userId);
    }
    final targetUserId =
        (widget.viewedUserId?.isNotEmpty ?? false)
            ? widget.viewedUserId!
            : (_userId ?? "");
    await Future.wait([
      _fetchFollowers(
        targetUserId,
        page: _followersPage,
        size: _followersSize,
        filter: _followersFilter,
      ),
      _fetchFollowings(
        targetUserId,
        page: _followingsPage,
        size: _followingsSize,
        filter: _followingsFilter,
      ),
    ]);
  }

  // ---------- Followers section ----------
  Widget _buildFollowersSection() {
    final theme = Theme.of(context);

    if (_isFollowersLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFEBB411)),
        ),
      );
    }
    if (_followersError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _followersError!,
          style: GoogleFonts.inter(color: Colors.redAccent),
        ),
      );
    }
    if (_followers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "No followers yet",
          style: GoogleFonts.inter(fontSize: 13, color: _muted(theme)),
        ),
      );
    }

    return Column(
      children: [
        ..._followers.map((item) {
          final u = _pickUserFromItem(item);
          final id = u["id"]!;
          final name = u["name"]!;
          final img = u["img"]!;
          final createdAt = (item["createdAt"] ?? "").toString();
          final following = _isFollowingUser(id);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Card(
              elevation: 0,
              color: _cardBg(theme),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _outline(theme), width: 1),
              ),
              // ⬇️ tapping a follower opens their profile
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (id.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => NewProfileScreen(
                            viewedUserId: id,
                            isFollowingInitial: following,
                          ),
                    ),
                  );
                },
                overlayColor: _inkOverlay(theme),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _userAvatar(name, img, radius: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 14,
                                  color: _muted(theme),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Follower",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _muted(theme),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: _muted(theme),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _formatAgo(createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _muted(theme),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!_isMe && id != (_userId ?? ""))
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor:
                                following
                                    ? Colors.grey.shade300
                                    : const Color(0xFFEBB411),
                            foregroundColor:
                                following ? Colors.black87 : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _toggleFollowUserInline(id),
                          child: Text(
                            following ? "Following" : "Follow",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        if (_followersTotal > _followersSize)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed:
                      _followersPage > 1
                          ? () {
                            final targetUserId =
                                (widget.viewedUserId?.isNotEmpty ?? false)
                                    ? widget.viewedUserId!
                                    : (_userId ?? "");
                            _fetchFollowers(
                              targetUserId,
                              page: _followersPage - 1,
                            );
                          }
                          : null,
                  child: const Text("Prev"),
                ),
                const SizedBox(width: 8),
                Text(
                  "Page $_followersPage",
                  style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed:
                      (_followersPage * _followersSize) < _followersTotal
                          ? () {
                            final targetUserId =
                                (widget.viewedUserId?.isNotEmpty ?? false)
                                    ? widget.viewedUserId!
                                    : (_userId ?? "");
                            _fetchFollowers(
                              targetUserId,
                              page: _followersPage + 1,
                            );
                          }
                          : null,
                  child: const Text("Next"),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------- Followings section ----------
  Widget _buildFollowingsSection() {
    final theme = Theme.of(context);

    if (_isFollowingLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFEBB411)),
        ),
      );
    }
    if (_followingError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _followingError!,
          style: GoogleFonts.inter(color: Colors.redAccent),
        ),
      );
    }
    if (_followings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "Not following anyone yet",
          style: GoogleFonts.inter(fontSize: 13, color: _muted(theme)),
        ),
      );
    }

    return Column(
      children: [
        ..._followings.map((item) {
          final u = _pickUserFromItem(item);
          final id = u["id"]!;
          final name = u["name"]!;
          final img = u["img"]!;
          final createdAt = (item["createdAt"] ?? "").toString();
          final following = _isFollowingUser(id); // should be true here

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Card(
              elevation: 0,
              color: _cardBg(theme),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _outline(theme), width: 1),
              ),
              // ⬇️ tapping a following opens their profile
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (id.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => NewProfileScreen(
                            viewedUserId: id,
                            isFollowingInitial: true, // “Following” tab
                          ),
                    ),
                  );
                },
                overlayColor: _inkOverlay(theme),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _userAvatar(name, img, radius: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_add_alt_1,
                                  size: 14,
                                  color: _muted(theme),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Following",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _muted(theme),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: _muted(theme),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _formatAgo(createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _muted(theme),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!_isMe && id != (_userId ?? ""))
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor:
                                following
                                    ? Colors.grey.shade300
                                    : const Color(0xFFEBB411),
                            foregroundColor:
                                following ? Colors.black87 : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _toggleFollowUserInline(id),
                          child: Text(
                            following ? "Following" : "Follow",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        if (_followingsTotal > _followingsSize)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed:
                      _followingsPage > 1
                          ? () {
                            final targetUserId =
                                (widget.viewedUserId?.isNotEmpty ?? false)
                                    ? widget.viewedUserId!
                                    : (_userId ?? "");
                            _fetchFollowings(
                              targetUserId,
                              page: _followingsPage - 1,
                            );
                          }
                          : null,
                  child: const Text("Prev"),
                ),
                const SizedBox(width: 8),
                Text(
                  "Page $_followingsPage",
                  style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed:
                      (_followingsPage * _followingsSize) < _followingsTotal
                          ? () {
                            final targetUserId =
                                (widget.viewedUserId?.isNotEmpty ?? false)
                                    ? widget.viewedUserId!
                                    : (_userId ?? "");
                            _fetchFollowings(
                              targetUserId,
                              page: _followingsPage + 1,
                            );
                          }
                          : null,
                  child: const Text("Next"),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------- Helpers ----------
  Map<String, String> _pickUserFromItem(Map<String, dynamic> it) {
    Map<String, dynamic>? candidate;

    for (final k in [
      "userId",
      "followerId",
      "followingId",
      "target",
      "source",
    ]) {
      if (it[k] is Map<String, dynamic>) {
        candidate = it[k] as Map<String, dynamic>;
        break;
      }
    }
    candidate ??= it;

    final id = (candidate!["_id"] ?? "").toString();
    final name =
        (candidate["userName"] ?? candidate["username"] ?? "User").toString();
    final img = (candidate["profileImg"] ?? "").toString();

    return {"id": id, "name": name, "img": img};
  }

  String _extractTextFromHtml(dynamic htmlLike) {
    final s = (htmlLike ?? "").toString();
    return s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  Widget _userAvatar(String name, String img, {double radius = 18}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final fg = isDark ? Colors.white : Colors.black87;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
      child:
          img.isEmpty
              ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : "U",
                style: GoogleFonts.inter(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              )
              : null,
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
            final key = title.split(' ').first;
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
                                : _outline(theme),
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
                                : theme.colorScheme.onSurface,
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

  // ---------- Social links row ----------
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
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Cannot open $url")));
                  }
                },
                borderRadius: BorderRadius.circular(18),
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
        return FontAwesomeIcons.xTwitter;
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

  // ---------- Badges ----------
  Widget _buildBadgesSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFEBB411),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Loading badges...",
                style: GoogleFonts.inter(fontSize: 12, color: _muted(theme)),
              ),
            ],
          ),
        ),
      );
    }

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
                color: theme.colorScheme.onSurface,
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

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const SizedBox(height: 8), ...rows, const SizedBox(height: 4)],
    );
  }

  Widget _buildBadgeChip(String label, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _chipBg(theme),
        border: Border.all(color: _outline(theme)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
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
}
