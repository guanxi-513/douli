import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'api.dart';

class VideoItem extends StatefulWidget {
  final VideoModel video;
  final bool isPlaying;
  final String username;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final void Function(String videoId, bool liked, int count)? onLikeChanged;
  final void Function(String videoId, int count)? onCommentCountChanged;

  const VideoItem({
    super.key,
    required this.video,
    required this.isPlaying,
    required this.username,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    this.onLikeChanged,
    this.onCommentCountChanged,
  });

  @override
  State<VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;

  void pauseVideo() {
    if (!_isInitialized) return;
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
      if (mounted) setState(() => _isPaused = true);
    }
  }

  void playVideo() {
    if (!_isInitialized) return;
    if (!_videoPlayerController.value.isPlaying) {
      _videoPlayerController.play();
      if (mounted) setState(() => _isPaused = false);
    }
  }

  late bool _isLiked;
  late int _likeCount;
  bool _isLikeProcessing = false;

  bool _isPaused = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  late Animation<Offset> _heartSlide;
  bool _showHeart = false;
  DateTime? _lastDoubleTapTime;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 0.9)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.9, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30),
    ]).animate(_animController);

    _heartController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.3)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 1.3, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(_heartController);
    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_heartController);
    _heartSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.08),
    ).animate(_heartController);

    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeart = false);
      }
    });

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    try {
      await _videoPlayerController.initialize();
      _videoPlayerController.setLooping(true);
      if (mounted) {
        if (widget.isPlaying) {
          await _videoPlayerController.play();
        }
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) setState(() => _isInitialized = true);
    }
  }

  @override
  void didUpdateWidget(covariant VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked != widget.isLiked ||
        oldWidget.likeCount != widget.likeCount) {
      _isLiked = widget.isLiked;
      _likeCount = widget.likeCount;
    }
    if (oldWidget.isPlaying != widget.isPlaying) _handlePlayState();
  }

  void _handlePlayState() {
    if (!_isInitialized) return;
    if (widget.isPlaying) {
      if (!_videoPlayerController.value.isPlaying) {
        _videoPlayerController.play();
        setState(() => _isPaused = false);
      }
    } else {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.pause();
        setState(() => _isPaused = true);
      }
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
      setState(() => _isPaused = true);
    } else {
      _videoPlayerController.play();
      setState(() => _isPaused = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikeProcessing) return;
    _isLikeProcessing = true;

    _animController.forward(from: 0.0);

    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });

    final result = await toggleLike(widget.username, widget.video.id);

    if (result['success'] == true) {
      final liked = result['liked'] as bool? ?? false;
      final count = result['count'] as int? ?? _likeCount;
      setState(() {
        _isLiked = liked;
        _likeCount = count;
      });
      widget.onLikeChanged?.call(widget.video.id, liked, count);
    } else {
      setState(() {
        _isLiked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
    }

    _isLikeProcessing = false;
  }

  void _onDoubleTap() {
    final now = DateTime.now();
    if (_lastDoubleTapTime != null &&
        now.difference(_lastDoubleTapTime!).inMilliseconds < 500) {
      return;
    }
    _lastDoubleTapTime = now;

    setState(() => _showHeart = true);
    _heartController.forward(from: 0.0);

    if (_isLiked) return;

    if (_isLikeProcessing) return;
    _isLikeProcessing = true;

    final wasLiked = _isLiked;
    setState(() {
      _isLiked = true;
      _likeCount += 1;
    });

    _animController.forward(from: 0.0);

    () async {
      final result = await toggleLike(widget.username, widget.video.id);
      if (!mounted) return;
      if (result['success'] == true) {
        final liked = result['liked'] as bool? ?? false;
        final count = result['count'] as int? ?? _likeCount;
        setState(() {
          _isLiked = liked;
          _likeCount = count;
        });
        widget.onLikeChanged?.call(widget.video.id, liked, count);
      } else {
        setState(() {
          _isLiked = wasLiked;
          _likeCount -= 1;
          if (_likeCount < 0) _likeCount = 0;
        });
      }
      _isLikeProcessing = false;
    }();
  }

  void _showCommentDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CommentDrawer(
        videoId: widget.video.id,
        username: widget.username,
        initialCount: widget.commentCount,
        onCountChanged: (count) {
          widget.onCommentCountChanged?.call(widget.video.id, count);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _heartController.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlayPause,
            onDoubleTap: _onDoubleTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: _isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoPlayerController.value.aspectRatio,
                          child: VideoPlayer(_videoPlayerController),
                        )
                      : const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        ),
                ),
                // 暂停图标：暂停时一直显示
                AnimatedOpacity(
                  opacity: (_isInitialized && _isPaused) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showHeart) _buildDoubleTapHeart(),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 80, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('@${widget.video.author}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('关注',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(widget.video.title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
        Positioned(
          right: 12, bottom: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.grey,
                ),
                child: const Icon(Icons.person, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 24),
              _buildLikeButton(),
              const SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.mode_comment_outlined,
                color: Colors.white,
                label: _formatCount(widget.commentCount),
                onTap: _showCommentDrawer,
              ),
              const SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.star_border_rounded,
                color: Colors.white,
                label: '收藏',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.share_outlined,
                color: Colors.white,
                label: _formatCount(widget.video.shares),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoubleTapHeart() {
    return Positioned.fill(
      child: Center(
        child: SlideTransition(
          position: _heartSlide,
          child: ScaleTransition(
            scale: _heartScale,
            child: FadeTransition(
              opacity: _heartOpacity,
              child: const Icon(
                Icons.favorite,
                color: Colors.redAccent,
                size: 100,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton() {
    return GestureDetector(
      onTap: _toggleLike,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.redAccent : Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              _formatCount(_likeCount),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

// ===== 评论抽屉 =====
class _CommentDrawer extends StatefulWidget {
  final String videoId;
  final String username;
  final int initialCount;
  final void Function(int count)? onCountChanged;

  const _CommentDrawer({
    required this.videoId,
    required this.username,
    required this.initialCount,
    this.onCountChanged,
  });

  @override
  State<_CommentDrawer> createState() => _CommentDrawerState();
}

class _CommentDrawerState extends State<_CommentDrawer> {
  final _inputController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  int _count = 0;

  // 头像背景色列表
  static const _avatarColors = [
    Colors.red, Colors.blue, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    _loadComments();
  }

  Future<void> _loadComments() async {
    final result = await getComments(widget.videoId);
    if (mounted) {
      setState(() {
        _comments = (result['data'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _isLoading = false;
        _count = _comments.length;
      });
    }
  }

  Future<void> _sendComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSending = true);
    final result =
        await postComment(widget.username, widget.videoId, content);
    if (mounted) {
      if (result['success'] == true) {
        final newComment = result['data'] as Map<String, dynamic>;
        setState(() {
          _comments.insert(0, newComment);
          _count = _comments.length;
          _inputController.clear();
        });
        widget.onCountChanged?.call(_count);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '评论失败'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      setState(() => _isSending = false);
    }
  }

  Color _getAvatarColor(String name) {
    return _avatarColors[name.hashCode.abs() % _avatarColors.length];
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text('$_count 条评论',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close,
                      color: Colors.white54, size: 22),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 评论列表
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white54, strokeWidth: 2))
                : _comments.isEmpty
                    ? const Center(
                        child: Text('还没有评论，快来抢沙发吧',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 14)))
                    : ListView.builder(
                        itemCount: _comments.length,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          return _buildCommentItem(
                            c['username']?.toString() ?? '匿名',
                            c['content']?.toString() ?? '',
                            c['created_at']?.toString() ?? '',
                          );
                        },
                      ),
          ),

          // 底部输入栏
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(
                  top: BorderSide(color: Colors.white12, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '说点什么...',
                      hintStyle: const TextStyle(
                          color: Colors.white38, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: (_inputController.text.trim().isEmpty ||
                          _isSending)
                      ? null
                      : _sendComment,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white54))
                      : const Icon(Icons.send, size: 22),
                  color: Colors.redAccent,
                  disabledColor: Colors.white24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(String username, String content, String createdAt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文字头像
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getAvatarColor(username),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 用户名、内容、时间
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(content,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4)),
                const SizedBox(height: 4),
                Text(createdAt,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}