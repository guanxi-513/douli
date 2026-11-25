# 斗立 (douli)

仿抖音风格的短视频社区 App，Flutter 客户端 + Node.js 后端，纯学习项目。

| 登录 | 视频流 |
| --- | --- |
| ![登录页](docs/screenshots/login.png) | ![视频流](docs/screenshots/home_feed.png) |

## 功能

- 登录 / 注册（账号 + 密码）
- 上下滑动视频流（关注 / 推荐 tab）
- 点赞、评论、收藏、分享计数
- 发布页上传视频（手机拍摄或本地文件）
- 个人主页（头像、昵称、作品列表）
- 深色 / 浅色主题跟随系统，抖音红 (`#FE2C55`) 主题色

## 技术栈

- **客户端**：Flutter（Material 3），`video_player`、`image_picker`、`file_picker`、`dio`、`shared_preferences`
- **后端**：Node.js + Express + better-sqlite3（SQLite WAL）+ multer（视频上传）

## 目录结构

```
douli/
├── lib/                  # Flutter 客户端
│   ├── main.dart         # 入口、主题、路由
│   ├── api.dart          # 后端接口封装
│   ├── login_page.dart   # 登录/注册
│   ├── home_page.dart    # 首页视频流 + 底部导航
│   ├── video_item.dart   # 单个视频项（播放器、点赞、评论）
│   ├── publish_page.dart # 发布上传
│   ├── profile_page.dart # 个人主页
│   └── full_video_player.dart
├── backend/              # Node.js 服务
│   ├── server.js         # 全部 API
│   ├── douli.db          # SQLite 数据库（运行时生成）
│   ├── video/            # 上传的视频（运行时生成）
│   └── uploads/          # 上传的图片（运行时生成）
├── android/ ios/ web/ windows/ linux/ macos/   # 各平台壳工程
└── docs/screenshots/     # 界面截图
```

## 运行

### 1. 启动后端（需要 Node.js 20+）

```bash
cd backend
npm install
node server.js   # 监听 http://0.0.0.0:3000
```

### 2. 启动客户端

```bash
flutter pub get
flutter run
```

API 地址在 `lib/api.dart` 的 `baseUrl` 中配置：

- Android 模拟器：`http://10.0.2.2:3000`
- 真机 USB 调试：`http://电脑局域网IP:3000`
- Flutter Web / Windows：`http://localhost:3000`

## API 一览

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/health` | 健康检查 |
| POST | `/api/register` | 注册 |
| POST | `/api/login` | 登录 |
| POST | `/api/upload` | 上传图片 |
| POST | `/api/videos/upload` | 上传视频 |
| GET | `/api/videos` | 视频列表 |
| POST | `/api/videos/:id/like` | 点赞/取消点赞 |
| GET | `/api/likes` | 批量查询点赞状态 |
| POST | `/api/comment` | 发表评论 |
| GET | `/api/comments` | 评论列表 |
| GET | `/api/commentCount` | 批量查询评论数 |
| GET | `/api/user/profile` | 用户信息 |
| GET | `/api/user/videos` | 用户作品列表 |

## 备注

- 仅用于学习交流，界面布局参考抖音，素材均来自测试上传。
- 数据库、上传的视频、日志均为运行时产物，不纳入版本控制。
