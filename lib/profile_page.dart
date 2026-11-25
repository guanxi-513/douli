import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'login_page.dart';
import 'full_video_player.dart';

class ProfilePage extends StatefulWidget {
  final String username;
  const ProfilePage({super.key, required this.username});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _username = '';

  Map<String, dynamic> _profile = {};
  bool _isLoadingProfile = true;

  List<VideoModel> _userVideos = [];
  bool _isLoadingVideos = true;

  List<VideoModel> _likedVideos = [];
  bool _isLoadingLiked = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    _username = widget.username;
    if (_username.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _username = prefs.getString('username') ?? '';
      AppState.currentUsername = _username;
    }
    if (mounted) setState(() {});
    _loadProfile();
    _loadUserVideos();
    _loadLikedVideos();
  }

  Future<void> _loadUserVideos() async {
    if (_username.isEmpty) {
      if (mounted) setState(() => _isLoadingVideos = false);
      return;
    }
    final videos = await getUserVideos(_username);
    if (mounted) {
      setState(() {
        _userVideos = videos;
        _isLoadingVideos = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    if (_username.isEmpty) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }
    final result = await getUserProfile(_username);
    if (mounted) {
      setState(() {
        _isLoadingProfile = false;
        if (result['success'] == true) {
          _profile = result['data'] ?? {};
        }
      });
    }
  }

  Future<void> _loadLikedVideos() async {
    final videos = await getVideos();
    if (_username.isNotEmpty && videos.isNotEmpty) {
      final ids = videos.map((v) => v.id).toList();
      final result = await getLikes(_username, ids);
      if (result['success'] == true) {
        final dataList = result['data'] as List? ?? [];
        final likedIds = <String>{};
        for (var item in dataList) {
          if (item['liked'] == true) {
            likedIds.add(item['id']?.toString() ?? '');
          }
        }
        _likedVideos = videos.where((v) => likedIds.contains(v.id)).toList();
      }
    }
    if (mounted) setState(() => _isLoadingLiked = false);
  }

  String _getInitial(String name) {
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _refreshAll() async {
    setState(() {
      _isLoadingProfile = true;
      _isLoadingVideos = true;
      _isLoadingLiked = true;
    });
    await Future.wait([
      _loadProfile(),
      _loadUserVideos(),
      _loadLikedVideos(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: Colors.redAccent,
        onRefresh: _refreshAll,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: Colors.black,
              pinned: false,
              stretch: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A1A2E), Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout,
                      color: Colors.white70, size: 22),
                  tooltip: '退出登录',
                  onPressed: () async {
                    await AppState.clearUsername();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                  onPressed: () => _toast('设置'),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _buildUserInfo()),
            SliverToBoxAdapter(child: _buildStats()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on, size: 20), text: '作品'),
                    Tab(icon: Icon(Icons.favorite_border, size: 20), text: '喜欢'),
                    Tab(icon: Icon(Icons.bookmark_border, size: 20), text: '收藏'),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.white,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildWorksTab(),
            _buildLikesTab(),
            _buildEmptyState('还没有收藏'),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildWorksTab() {
    if (_isLoadingVideos) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
    }
    if (_userVideos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.videocam_outlined, color: Colors.white24, size: 64),
          SizedBox(height: 12),
          Text('还没有作品，快去发布第一个吧',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3 / 4, // 更紧凑比例，9:16屏幕可显示3行+
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _userVideos.length,
      itemBuilder: (context, index) =>
          _buildWorkGridItem(_userVideos[index]),
    );
  }

  Widget _buildWorkGridItem(VideoModel video) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullVideoPlayer(
              videoUrl: video.videoUrl,
              title: video.title,
              author: video.author,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 占位封面：深色渐变背景
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade800, Colors.grey.shade900],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white, size: 40),
              ),
            ),
            // 底部视频标题（最多一行，溢出省略）
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Text(
                video.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final display = _username.isEmpty ? '游客' : _username;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black,
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.pinkAccent, Colors.deepPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _getInitial(display),
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('抖音号：douli_$display',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _toast('编辑资料'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    minimumSize: const Size(90, 30),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('编辑资料',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final likes = (_profile['likes'] ?? 0) as num;
    final following = (_profile['following'] ?? 0) as num;
    final followers = (_profile['followers'] ?? 0) as num;
    final likeStr = _isLoadingProfile ? '-' : likes.toString();
    final followStr = _isLoadingProfile ? '-' : following.toString();
    final followerStr = _isLoadingProfile ? '-' : followers.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(followStr, '关注'),
          _buildDivider(),
          _buildStatItem(followerStr, '粉丝'),
          _buildDivider(),
          _buildStatItem(likeStr, '获赞'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
        width: 1,
        height: 24,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 20));
  }

  Widget _buildLikesTab() {
    if (_isLoadingLiked) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
    }
    if (_likedVideos.isEmpty) {
      return _buildEmptyState('还没有喜欢');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _likedVideos.length,
      itemBuilder: (context, index) =>
          _buildVideoGridItem(_likedVideos[index]),
    );
  }

  Widget _buildVideoGridItem(VideoModel video) {
    return GestureDetector(
      onTap: () => _toast('视频ID: ${video.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade800, Colors.grey.shade900],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white38, size: 40),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                  const SizedBox(width: 2),
                  Text('${video.likes}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.inbox_outlined, color: Colors.white24, size: 64),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 14)),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.black, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
