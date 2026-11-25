import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'api.dart';

class PublishPage extends StatefulWidget {
  final String username;
  const PublishPage({super.key, required this.username});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final TextEditingController _titleController = TextEditingController();

  // 选中的视频信息
  String? _videoPath; // 移动端文件路径
  Uint8List? _videoBytes; // Web端文件字节
  String? _videoName;
  int? _videoSizeBytes;

  // 视频预览控制器（仅移动端）
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // 上传状态
  bool _isUploading = false;
  int _uploadProgress = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// 选择视频（全平台兼容）
  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: kIsWeb, // Web端需要读取bytes
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // 移动端：有文件路径，可预览（Web端不访问path，否则抛异常）
      if (!kIsWeb && file.path != null) {
        _videoController?.dispose();
        final controller = VideoPlayerController.file(File(file.path!));
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          return;
        }
        setState(() {
          _videoPath = file.path;
          _videoBytes = null;
          _videoName = file.name;
          _videoSizeBytes = file.size;
          _videoController = controller;
          _isVideoInitialized = true;
        });
        controller.setLooping(true);
        controller.play();
      } else if (file.bytes != null) {
        // Web端：只有bytes，无预览
        setState(() {
          _videoPath = null;
          _videoBytes = file.bytes;
          _videoName = file.name;
          _videoSizeBytes = file.size;
          _videoController = null;
          _isVideoInitialized = false;
        });
      }
    } catch (e) {
      _toast('选择视频失败: $e');
    }
  }

  /// 重新选择
  void _reselectVideo() {
    _videoController?.dispose();
    setState(() {
      _videoPath = null;
      _videoBytes = null;
      _videoName = null;
      _videoSizeBytes = null;
      _videoController = null;
      _isVideoInitialized = false;
    });
    _pickVideo();
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  /// 发布视频
  Future<void> _publish() async {
    if (_videoPath == null && _videoBytes == null) {
      _toast('请先选择视频');
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _toast('请输入视频标题');
      return;
    }
    if (widget.username.isEmpty) {
      _toast('请先登录');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    _videoController?.pause();

    final fileName = _videoName ?? 'video.mp4';
    final result = await uploadVideo(
      filePath: _videoPath,
      fileBytes: _videoBytes,
      fileName: fileName,
      title: title,
      username: widget.username,
      onSendProgress: (sent, total) {
        if (total > 0 && mounted) {
          setState(() => _uploadProgress = (sent / total * 100).round());
        }
      },
    );

    if (!mounted) return;

    setState(() => _isUploading = false);

    if (result['code'] == 0) {
      _toast('发布成功');
      Navigator.of(context).pop(true);
    } else {
      _toast(result['msg'] ?? '上传失败');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: TextButton(
          onPressed:
              _isUploading ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消', style: TextStyle(color: Colors.white)),
        ),
        title: const Text('发布视频',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildVideoArea()),
            _buildTitleInput(),
            _buildPublishButton(),
          ],
        ),
      ),
    );
  }

  /// 视频预览区域
  Widget _buildVideoArea() {
    // 未选择视频
    if (_videoPath == null && _videoBytes == null) {
      return GestureDetector(
        onTap: _pickVideo,
        child: Container(
          color: const Color(0xFF1A1A1A),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.video_call,
                    color: Colors.white54, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('点击选择视频',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('支持 MP4 格式，最大 100MB',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    // Web端：无预览，显示文件信息
    if (kIsWeb || _videoController == null || !_isVideoInitialized) {
      return Container(
        color: const Color(0xFF1A1A1A),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(_videoName ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
                _videoSizeBytes != null
                    ? _formatFileSize(_videoSizeBytes!)
                    : '',
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _isUploading ? null : _reselectVideo,
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              label: const Text('重新选择',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ],
        ),
      );
    }

    // 移动端：视频预览
    final controller = _videoController!;
    final size = controller.value.size;
    final aspectRatio = size.width / size.height;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                ),
                child: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_videoName ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                            _videoSizeBytes != null
                                ? _formatFileSize(_videoSizeBytes!)
                                : '',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isUploading ? null : _reselectVideo,
                    icon: const Icon(Icons.refresh,
                        color: Colors.white70, size: 18),
                    label: const Text('重新选择',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 标题输入框
  Widget _buildTitleInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: TextField(
        controller: _titleController,
        maxLength: 50,
        enabled: !_isUploading,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          hintText: '写个标题吧...',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
          border: InputBorder.none,
          counterStyle: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        cursorColor: Colors.redAccent,
      ),
    );
  }

  /// 发布按钮
  Widget _buildPublishButton() {
    final hasVideo = _videoPath != null || _videoBytes != null;
    final canPublish = hasVideo && !_isUploading;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.black,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: canPublish ? _publish : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canPublish ? Colors.redAccent : Colors.grey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: _isUploading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('上传中 $_uploadProgress%',
                        style: const TextStyle(fontSize: 15)),
                  ],
                )
              : const Text('发布',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
