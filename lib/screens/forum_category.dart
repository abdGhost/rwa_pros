import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rwa_app/screens/profile_screen.dart';

class ForumCategory extends StatelessWidget {
  const ForumCategory({super.key});

  Widget buildSubcategory({
    required IconData icon,
    required String title,
    required String contentTitle,
    required String timeAgo,
    required String author,
    bool highlightTitle = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: const Color(0xFFEBB411), size: 26),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                contentTitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(
                '$timeAgo · $author',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, thickness: 0.4),
      ],
    );
  }

  Widget buildHottestTodayCard() {
    return Container(
      color: Colors.white,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0.02,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    "Hottest today",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Colors.black,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Thread 1
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.green,
                    child: Icon(
                      Icons.arrow_drop_up,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sim.ai Sold For \$220,000",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "8 replies · silentg",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Thread 2
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(
                      "https://i.pravatar.cc/150?img=65",
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "I missed first 1000000USD in my domain career!",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "11 replies · domainnews",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        toolbarHeight: 50,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/rwapros/logo-white.png'
                  : 'assets/rwapros/logo.png',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 8),
            Text(
              "Forum",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/profile_outline.svg',
              width: 30,
              color: theme.iconTheme.color,
            ),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Section title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text(
                "The Pulse",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Forum thread list card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0.02,
                color: Colors.white,
                child: Column(
                  children: [
                    buildSubcategory(
                      icon: Icons.layers,
                      title: "Recent Posts",
                      contentTitle: "4DUE.com",
                      timeAgo: "5 minutes ago",
                      author: "Hesham Salem",
                    ),
                    buildSubcategory(
                      icon: Icons.forum,
                      title: "All Domain Discussions",
                      contentTitle: "I missed first 1000000USD in my domai...",
                      timeAgo: "13 minutes ago",
                      author: "Leo2k",
                    ),
                    buildSubcategory(
                      icon: Icons.public,
                      title: "All Domain News",
                      contentTitle: "Domain Names Continue to Def...",
                      timeAgo: "Today at 3:08 AM",
                      author: "Ron Jackson",
                    ),
                    buildSubcategory(
                      icon: Icons.star_border,
                      title: "NamePros Blog",
                      contentTitle: "What Makes A Word Memorable...",
                      timeAgo: "27 minutes ago",
                      author: "ojustin",
                      highlightTitle: true,
                    ),
                    buildSubcategory(
                      icon: Icons.shopping_cart,
                      title: "Buy Domain Names",
                      contentTitle: "SABOTAGE.CO , ATOMY.IO , UNT.IO ...",
                      timeAgo: "38 minutes ago",
                      author: "Olglaer",
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Hottest today section
            buildHottestTodayCard(),
            const SizedBox(height: 8),

            // Favorites Today
            buildHottestTodayCard(),
            const SizedBox(height: 8),

            // Favvorites this week
            buildHottestTodayCard(),
            const SizedBox(height: 8),

            // Hottest this week
            buildHottestTodayCard(),
            const SizedBox(height: 8),

            // Hottest this month
            buildHottestTodayCard(),
            const SizedBox(height: 10),

            // Discussion Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text(
                "The Pulse",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Forum thread list card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0.02,
                color: Colors.white,
                child: Column(
                  children: [
                    buildSubcategory(
                      icon: Icons.layers,
                      title: "Recent Posts",
                      contentTitle: "4DUE.com",
                      timeAgo: "5 minutes ago",
                      author: "Hesham Salem",
                    ),
                    buildSubcategory(
                      icon: Icons.forum,
                      title: "All Domain Discussions",
                      contentTitle: "I missed first 1000000USD in my domai...",
                      timeAgo: "13 minutes ago",
                      author: "Leo2k",
                    ),
                    buildSubcategory(
                      icon: Icons.public,
                      title: "All Domain News",
                      contentTitle: "Domain Names Continue to Def...",
                      timeAgo: "Today at 3:08 AM",
                      author: "Ron Jackson",
                    ),
                    buildSubcategory(
                      icon: Icons.star_border,
                      title: "NamePros Blog",
                      contentTitle: "What Makes A Word Memorable...",
                      timeAgo: "27 minutes ago",
                      author: "ojustin",
                      highlightTitle: true,
                    ),
                    buildSubcategory(
                      icon: Icons.shopping_cart,
                      title: "Buy Domain Names",
                      contentTitle: "SABOTAGE.CO , ATOMY.IO , UNT.IO ...",
                      timeAgo: "38 minutes ago",
                      author: "Olglaer",
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Discussion Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text(
                "The Pulse",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Forum thread list card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0.02,
                color: Colors.white,
                child: Column(
                  children: [
                    buildSubcategory(
                      icon: Icons.layers,
                      title: "Recent Posts",
                      contentTitle: "4DUE.com",
                      timeAgo: "5 minutes ago",
                      author: "Hesham Salem",
                    ),
                    buildSubcategory(
                      icon: Icons.forum,
                      title: "All Domain Discussions",
                      contentTitle: "I missed first 1000000USD in my domai...",
                      timeAgo: "13 minutes ago",
                      author: "Leo2k",
                    ),
                    buildSubcategory(
                      icon: Icons.public,
                      title: "All Domain News",
                      contentTitle: "Domain Names Continue to Def...",
                      timeAgo: "Today at 3:08 AM",
                      author: "Ron Jackson",
                    ),
                    buildSubcategory(
                      icon: Icons.star_border,
                      title: "NamePros Blog",
                      contentTitle: "What Makes A Word Memorable...",
                      timeAgo: "27 minutes ago",
                      author: "ojustin",
                      highlightTitle: true,
                    ),
                    buildSubcategory(
                      icon: Icons.shopping_cart,
                      title: "Buy Domain Names",
                      contentTitle: "SABOTAGE.CO , ATOMY.IO , UNT.IO ...",
                      timeAgo: "38 minutes ago",
                      author: "Olglaer",
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
