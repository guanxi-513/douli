import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'video_item.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'publish_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTabIndex = 0;
  final _homeTabKey = GlobalKey<HomeTabState>();

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(key: _homeTabKey),
      const SearchTab(),
      const SizedBox(), // 发布tab占位，实际通过导航跳转
      const MessageTab(),
      ProfilePage(username: AppState.currentUsername),
    ];

    return Scaffold(
      backgroundColor: (_currentTabIndex == 0 || _currentTabIndex == 4) ? Colors.black : null,
      body: IndexedStack(index: _currentTabIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) async {
          if (index == 2) {
            // 发布tab：先暂停首页视频，再跳转到发布页
            _homeTabKey.currentState?.pauseCurrentVideo();
            final username = AppState.currentUsername;
            if (username.isEmpty) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请先登录'), duration: Duration(seconds: 1)),
              );
              return;
            }
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => PublishPage(username: username)),
            );
            // 从发布页返回时：如果当前tab是首页则恢复播放
            if (mounted && _currentTabIndex == 0) {
              _homeTabKey.currentState?.resumeCurrentVideo();
            }
            if (result == true && mounted) {
              _homeTabKey.currentState?.refresh();
            }
          } else {
            // 切换tab：先处理视频播放状态
            final wasHome = _currentTabIndex == 0;
            final isHome = index == 0;
            if (wasHome && !isHome) {
              // 从首页切走：暂停视频
              _homeTabKey.currentState?.pauseCurrentVideo();
            } else if (!wasHome && isHome) {
              // 切回首页：恢复播放
              _homeTabKey.currentState?.resumeCurrentVideo();
            }
            setState(() => _currentTabIndex = index);
          }
        },
        backgroundColor: (_currentTabIndex == 0 || _currentTabIndex == 4) ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
        indicatorColor: Colors.transparent,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: PublishIcon(), label: ''),
          NavigationDestination(icon: Icon(Icons.message_outlined), selectedIcon: Icon(Icons.message), label: '消息'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

class PublishIcon extends StatelessWidget {
  const PublishIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Colors.cyanAccent, Colors.white, Colors.pinkAccent],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
      ),
      child: const Icon(Icons.add, color: Colors.black, size: 22),
    );
  }
}

// ===== 首页视频流 =====
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final PageController _pageController = PageController(initialPage: 0);
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  String _username = '';
  // 点赞状态：{videoId: {count: int, liked: bool}}
  Map<String, Map<String, dynamic>> _likeStatus = {};
  // 评论数：{videoId: count}
  Map<String, int> _commentCounts = {};
  // tab是否处于激活状态（切到其他tab时设为false，暂停当前视频）
  bool _isTabActive = true;

  /// 公开方法：暂停当前正在播放的视频（切tab时调用）
  void pauseCurrentVideo() {
    if (mounted) setState(() => _isTabActive = false);
  }

  /// 公开方法：恢复播放当前视频（切回首页时调用）
  void resumeCurrentVideo() {
    if (mounted) setState(() => _isTabActive = true);
  }

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);

    // 读取登录用户名
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? '';
    AppState.currentUsername = _username;

    final list = await getVideos();

    // 批量获取点赞状态
    if (_username.isNotEmpty && list.isNotEmpty) {
      final ids = list.map((v) => v.id).toList();
      final result = await getLikes(_username, ids);
      if (result['success'] == true) {
        final dataList = result['data'] as List? ?? [];
        final Map<String, Map<String, dynamic>> likeMap = {};
        for (var item in dataList) {
          final id = item['id']?.toString() ?? '';
          likeMap[id] = {
            'count': item['count'] ?? 0,
            'liked': item['liked'] ?? false,
          };
        }
        _likeStatus = likeMap;
      }
    }

    // 批量获取评论数
    if (list.isNotEmpty) {
      final ids = list.map((v) => v.id).toList();
      final cmtResult = await getCommentCount(ids);
      if (cmtResult['success'] == true) {
        final cmtList = cmtResult['data'] as List? ?? [];
        final Map<String, int> cmtMap = {};
        for (var item in cmtList) {
          cmtMap[item['id']?.toString() ?? ''] = item['count'] as int? ?? 0;
        }
        _commentCounts = cmtMap;
      }
    }

    if (mounted) {
      setState(() {
        _videos = list;
        _isLoading = false;
      });
    }
  }

  /// 点赞状态变化时更新UI
  void _onLikeChanged(String videoId, bool liked, int count) {
    setState(() {
      _likeStatus[videoId] = {'count': count, 'liked': liked};
    });
  }

  /// 评论数变化时更新UI
  void _onCommentCountChanged(String videoId, int count) {
    setState(() {
      _commentCounts[videoId] = count;
    });
  }

  /// 公开刷新方法：从外部触发首页刷新
  void refresh() => _refresh();

  /// 下拉刷新：重新获取视频列表和点赞状态
  Future<void> _refresh() async {
    final list = await getVideos();
    if (_username.isNotEmpty && list.isNotEmpty) {
      final ids = list.map((v) => v.id).toList();
      final result = await getLikes(_username, ids);
      if (result['success'] == true) {
        final dataList = result['data'] as List? ?? [];
        final Map<String, Map<String, dynamic>> likeMap = {};
        for (var item in dataList) {
          final id = item['id']?.toString() ?? '';
          likeMap[id] = {'count': item['count'] ?? 0, 'liked': item['liked'] ?? false};
        }
        _likeStatus = likeMap;
      }
    }
    // 批量获取评论数
    if (list.isNotEmpty) {
      final ids = list.map((v) => v.id).toList();
      final cmtResult = await getCommentCount(ids);
      if (cmtResult['success'] == true) {
        final cmtList = cmtResult['data'] as List? ?? [];
        final Map<String, int> cmtMap = {};
        for (var item in cmtList) {
          cmtMap[item['id']?.toString() ?? ''] = item['count'] as int? ?? 0;
        }
        _commentCounts = cmtMap;
      }
    }

    if (mounted) {
      setState(() {
        _videos = list;
        _currentIndex = 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: SizedBox(width: 40, height: 40,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
        ),
      );
    }
    if (_videos.isEmpty) {
      return RefreshIndicator(
        color: Colors.redAccent,
        backgroundColor: Colors.white,
        onRefresh: _refresh,
        child: Container(
          color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('暂无视频', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadVideos, child: const Text('重新加载')),
            ],
          ),
        ),
      ),
      );
    }
    return Stack(
      children: [
        RefreshIndicator(
          color: Colors.redAccent,
          backgroundColor: Colors.white,
          onRefresh: _refresh,
          child: PageView.builder(
            controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _videos.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final video = _videos[index];
            final likeInfo = _likeStatus[video.id] ?? {'count': video.likes, 'liked': false};
            final cmtCount = _commentCounts[video.id] ?? video.comments;
            return VideoItem(
              key: ValueKey(video.id),
              video: video,
              isPlaying: index == _currentIndex && _isTabActive,
              username: _username,
              isLiked: likeInfo['liked'] as bool? ?? false,
              likeCount: likeInfo['count'] as int? ?? video.likes,
              commentCount: cmtCount,
              onLikeChanged: _onLikeChanged,
              onCommentCountChanged: _onCommentCountChanged,
            );
          },
          ),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTopTab('关注', false),
                  Container(width: 1, height: 16, color: Colors.white54, margin: const EdgeInsets.symmetric(horizontal: 12)),
                  _buildTopTab('推荐', true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTab(String label, bool selected) {
    return Text(label,
      style: TextStyle(
        color: Colors.white,
        fontSize: selected ? 18 : 16,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        decoration: selected ? TextDecoration.underline : TextDecoration.none,
        decorationColor: Colors.white,
        decorationThickness: 2,
      ),
    );
  }
}

// ===== 搜索Tab（占位） =====
class SearchTab extends StatelessWidget {
  const SearchTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('搜索功能开发中...'),
          ],
        ),
      ),
    );
  }
}

// ===== 消息Tab（占位） =====
class MessageTab extends StatelessWidget {
  const MessageTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('消息功能开发中...'),
          ],
        ),
      ),
    );
  }
}
