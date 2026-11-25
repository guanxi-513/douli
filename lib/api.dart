import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

// 基础URL配置
// 本地测试说明：
// - Android模拟器访问本机: http://10.0.2.2:3000
// - 真机USB调试: http://电脑IP:3000 (如 http://192.168.1.100:3000)
// - Flutter Web/Windows: http://localhost:3000
const String baseUrl = 'http://localhost:3000';

// 登录接口
Future<Map<String, dynamic>> login(String username, String password) async {
  final url = Uri.parse('$baseUrl/api/login');
  try {
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {'success': false, 'message': '请求失败: ${response.statusCode}'};
    }
  } catch (e) {
    return {'success': false, 'message': '网络错误: $e'};
  }
}

// 注册接口
Future<Map<String, dynamic>> register(String username, String password) async {
  final url = Uri.parse('$baseUrl/api/register');
  try {
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {'success': false, 'message': '请求失败: ${response.statusCode}'};
    }
  } catch (e) {
    return {'success': false, 'message': '网络错误: $e'};
  }
}

// 视频列表模型
class VideoModel {
  final String id;
  final String title;
  final String author;
  final String avatar;
  final String videoUrl;
  final int likes;
  final int comments;
  final int shares;

  VideoModel({
    required this.id,
    required this.title,
    required this.author,
    required this.avatar,
    required this.videoUrl,
    required this.likes,
    required this.comments,
    required this.shares,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
    );
  }
}

// 获取视频列表接口
Future<List<VideoModel>> getVideos() async {
  final url = Uri.parse('$baseUrl/api/videos');
  try {
    final response = await http
        .get(url, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['data'] ?? data['videos'] ?? [];
      return list.map((item) => VideoModel.fromJson(item)).toList();
    } else {
      return _getMockVideos();
    }
  } catch (e) {
    // 请求失败时返回模拟数据，方便前端调试
    return _getMockVideos();
  }
}

// 模拟视频数据（后端未启动时使用）
List<VideoModel> _getMockVideos() {
  return [
    VideoModel(
      id: '1',
      title: '这是一个测试视频标题，欢迎来到斗立短视频平台！',
      author: '斗立官方',
      avatar: '',
      videoUrl: 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
      likes: 1234,
      comments: 88,
      shares: 23,
    ),
    VideoModel(
      id: '2',
      title: '生活不止眼前的苟且，还有诗和远方',
      author: '旅行者小明',
      avatar: '',
      videoUrl: 'https://www.w3schools.com/html/mov_bbb.mp4',
      likes: 5678,
      comments: 234,
      shares: 156,
    ),
    VideoModel(
      id: '3',
      title: '美食探店，今天带你吃遍这条街！',
      author: '吃货大V',
      avatar: '',
      videoUrl: 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
      likes: 9999,
      comments: 666,
      shares: 333,
    ),
  ];
}



// 点赞/取消点赞
Future<Map<String, dynamic>> toggleLike(String username, String videoId) async {
  final url = Uri.parse('$baseUrl/api/like');
  try {
    final response = await http
        .post(url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'videoId': videoId}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false, 'message': '请求失败'};
  } catch (e) {
    return {'success': false, 'message': '网络错误: $e'};
  }
}

// 批量查询点赞状态
Future<Map<String, dynamic>> getLikes(String username, List<String> ids) async {
  final url = Uri.parse('$baseUrl/api/likes?username=$username&ids=${ids.join(',')}');
  try {
    final response = await http
        .get(url, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false, 'data': []};
  } catch (e) {
    return {'success': false, 'data': []};
  }
}


// 获取评论列表
Future<Map<String, dynamic>> getComments(String videoId) async {
  final url = Uri.parse('$baseUrl/api/comments?videoId=$videoId');
  try {
    final response = await http
        .get(url, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false, 'data': []};
  } catch (e) {
    return {'success': false, 'data': []};
  }
}

// 发表评论
Future<Map<String, dynamic>> postComment(
    String username, String videoId, String content) async {
  final url = Uri.parse('$baseUrl/api/comment');
  try {
    final response = await http
        .post(url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'videoId': videoId,
              'content': content,
            }))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false, 'message': '请求失败'};
  } catch (e) {
    return {'success': false, 'message': '网络错误: $e'};
  }
}

// 批量获取评论数
Future<Map<String, dynamic>> getCommentCount(List<String> ids) async {
  final url = Uri.parse('$baseUrl/api/commentCount?ids=${ids.join(',')}');
  try {
    final response = await http
        .get(url, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false, 'data': []};
  } catch (e) {
    return {'success': false, 'data': []};
  }
}


// 获取用户个人信息
Future<Map<String, dynamic>> getUserProfile(String username) async {
  final url = Uri.parse('$baseUrl/api/user/profile?username=$username');
  try {
    final response = await http
        .get(url, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false, 'message': '请求失败'};
  } catch (e) {
    return {'success': false, 'message': '网络错误: $e'};
  }
}

// 获取用户作品列表
Future<List<VideoModel>> getUserVideos(String username) async {
  final url = Uri.parse('$baseUrl/api/user/videos?username=$username');
  try {
    final response = await http
        .get(url, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['code'] == 0) {
        final data = result['data'] as List? ?? [];
        return data.map((item) {
          final mapped = Map<String, dynamic>.from(item);
          mapped['videoUrl'] = mapped['url'] ?? '';
          return VideoModel.fromJson(mapped);
        }).toList();
      }
    }
    return [];
  } catch (e) {
    return [];
  }
}

// 上传视频（使用dio带进度）
// filePath: 视频文件本地路径（移动端）
// fileBytes: 视频文件字节（Web端）
// fileName: 视频文件名
// title: 视频标题
// username: 上传者用户名
// onSendProgress: (已发送字节, 总字节) 回调
Future<Map<String, dynamic>> uploadVideo({
  String? filePath,
  Uint8List? fileBytes,
  required String fileName,
  required String title,
  required String username,
  void Function(int sent, int total)? onSendProgress,
}) async {
  try {
    final dio = Dio();
    MultipartFile videoFile;
    if (filePath != null) {
      videoFile = MultipartFile.fromFileSync(filePath, filename: fileName);
    } else if (fileBytes != null) {
      videoFile = MultipartFile.fromBytes(fileBytes, filename: fileName);
    } else {
      return {'code': 1, 'msg': '没有视频文件'};
    }
    final formData = FormData.fromMap({
      'video': videoFile,
      'title': title,
      'username': username,
    });
    final response = await dio.post(
      '$baseUrl/api/upload',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data);
    }
    return {'code': 1, 'msg': '请求失败: ${response.statusCode}'};
  } catch (e) {
    return {'code': 1, 'msg': '网络错误: $e'};
  }
}
