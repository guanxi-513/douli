const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');

const app = express();
const PORT = 3000;
const HOST = '0.0.0.0';

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ===== 视频文件夹（上传视频存放） =====
const videoDir = path.join(__dirname, 'video');
if (!fs.existsSync(videoDir)) fs.mkdirSync(videoDir, { recursive: true });
app.use('/video', express.static(videoDir));

// ===== SQLite数据库初始化 =====
const db = new Database(path.join(__dirname, 'douli.db'));
db.pragma('journal_mode = WAL');

// 建表（IF NOT EXISTS）
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS likes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    video_id INTEGER,
    created_at TEXT,
    UNIQUE(username, video_id)
  );
  CREATE TABLE IF NOT EXISTS comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    video_id INTEGER,
    content TEXT,
    likes INTEGER DEFAULT 0,
    created_at TEXT
  );
  CREATE TABLE IF NOT EXISTS videos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT,
    title TEXT,
    author TEXT,
    created_at TEXT
  );
`);
console.log('数据库初始化完成');

// ===== 视频数据（内存，保持原有逻辑） =====
const videos = [];
function initMockVideos() {
  if (videos.length > 0) return;
  const sampleVideos = [
    { title: '这是一个测试视频标题，欢迎来到斗立短视频平台！', author: '斗立官方',
      videoUrl: 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4' },
    { title: '生活不止眼前的苟且，还有诗和远方', author: '旅行者小明',
      videoUrl: 'https://www.w3schools.com/html/mov_bbb.mp4' },
    { title: '美食探店，今天带你吃遍这条街！', author: '吃货大V',
      videoUrl: 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4' },
  ];
  sampleVideos.forEach((v, i) => {
    videos.push({
      id: String(Date.now() + i), title: v.title, author: v.author, avatar: '',
      videoUrl: v.videoUrl,
      likes: Math.floor(Math.random() * 10000),
      comments: Math.floor(Math.random() * 1000),
      shares: Math.floor(Math.random() * 500),
      createdAt: new Date().toISOString(),
    });
  });
}
initMockVideos();

// ===== 文件上传配置（保持不变） =====
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    let folder = 'uploads/videos';
    if (file.fieldname === 'avatar') folder = 'uploads/avatars';
    const dest = path.join(__dirname, folder);
    if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
    cb(null, dest);
  },
  filename: function (req, file, cb) {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, Date.now() + '_' + Math.round(Math.random() * 1e6) + ext);
  },
});

function fileFilter(req, file, cb) {
  const videoExts = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'];
  const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  const ext = path.extname(file.originalname).toLowerCase();
  if (file.fieldname === 'video') {
    if (videoExts.includes(ext)) return cb(null, true);
    return cb(new Error('只支持 MP4, MOV, AVI, MKV, WEBM, M4V 视频格式'), false);
  }
  if (file.fieldname === 'avatar') {
    if (imageExts.includes(ext)) return cb(null, true);
    return cb(new Error('只支持 JPG, PNG, GIF, WEBP 图片格式'), false);
  }
  cb(new Error('未知的文件类型'), false);
}

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: { fileSize: 500 * 1024 * 1024 },
});

// ===== 视频上传multer配置（/api/upload专用） =====
const uploadVideo = multer({
  storage: multer.diskStorage({
    destination: function (req, file, cb) {
      if (!fs.existsSync(videoDir)) fs.mkdirSync(videoDir, { recursive: true });
      cb(null, videoDir);
    },
    filename: function (req, file, cb) {
      cb(null, Date.now() + '_' + Math.round(Math.random() * 1e6) + '.mp4');
    },
  }),
  fileFilter: function (req, file, cb) {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === '.mp4') return cb(null, true);
    cb(new Error('只支持 MP4 格式'), false);
  },
  limits: { fileSize: 3 * 1024 * 1024 * 1024 }, // 3GB
});

function getBaseUrl(req) {
  return req.protocol + '://' + req.get('host');
}

function formatDateTime() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`;
}

// ===== 健康检查 =====
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// ===== 登录 =====
app.post('/api/login', (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) return res.json({ success: false, message: '账号和密码不能为空' });
    const row = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
    if (!row) return res.json({ success: false, message: '用户不存在，请先注册' });
    if (row.password !== password) return res.json({ success: false, message: '密码错误' });
    res.json({ success: true, message: '登录成功', data: { username: username } });
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message });
  }
});

// ===== 注册 =====
app.post('/api/register', (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) return res.json({ success: false, message: '账号和密码不能为空' });
    if (String(username).length < 3) return res.json({ success: false, message: '账号至少3位' });
    if (String(password).length < 6) return res.json({ success: false, message: '密码至少6位' });
    try {
      db.prepare('INSERT INTO users (username, password, created_at) VALUES (?, ?, ?)')
        .run(username, password, new Date().toISOString());
      res.json({ success: true, message: '注册成功', data: { username: username } });
    } catch (e) {
      if (e.message.includes('UNIQUE') || e.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return res.json({ success: false, message: '该账号已被注册' });
      }
      throw e;
    }
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message });
  }
});

// ===== 上传视频（新接口，存数据库） =====
app.post('/api/upload', (req, res, next) => {
  uploadVideo.single('video')(req, res, (err) => {
    if (err) {
      return res.json({ code: 1, msg: err.message || '上传错误' });
    }
    next();
  });
}, (req, res) => {
  try {
    const base = getBaseUrl(req);
    const title = String(req.body.title || '').trim();
    const username = String(req.body.username || '').trim();
    if (!req.file) {
      return res.json({ code: 1, msg: '请选择要上传的视频文件' });
    }
    if (!title) {
      return res.json({ code: 1, msg: '请输入视频标题' });
    }
    if (!username) {
      return res.json({ code: 1, msg: 'username不能为空' });
    }
    const filename = req.file.filename;
    const createdAt = new Date().toISOString();
    const info = db.prepare('INSERT INTO videos (filename, title, author, created_at) VALUES (?, ?, ?, ?)')
      .run(filename, title, username, createdAt);
    const id = info.lastInsertRowid;
    const url = base + '/video/' + filename;
    res.json({
      code: 0,
      msg: '上传成功',
      data: { id: id, url: url, title: title, author: username }
    });
  } catch (e) {
    res.json({ code: 1, msg: '上传失败: ' + e.message });
  }
});

// ===== 视频列表（从数据库查询） =====
app.get('/api/videos', (req, res) => {
  try {
    const base = getBaseUrl(req);
    const page = parseInt(req.query.page) || 1;
    const pageSize = parseInt(req.query.pageSize) || 20;

    // 1. 优先从 videos 表查询，按 id 倒序
    const rows = db.prepare('SELECT * FROM videos ORDER BY id DESC').all();
    let list = [];
    if (rows.length > 0) {
      list = rows.map(r => ({
        id: String(r.id),
        title: r.title,
        author: r.author,
        avatar: '',
        videoUrl: base + '/video/' + r.filename,
        likes: 0,
        comments: 0,
        shares: 0,
        createdAt: r.created_at,
      }));
    } else {
      // 2. 回退到本地 video 文件夹的 mp4 文件
      const files = fs.existsSync(videoDir)
        ? fs.readdirSync(videoDir).filter(f => f.toLowerCase().endsWith('.mp4'))
        : [];
      if (files.length > 0) {
        list = files.map((f, i) => ({
          id: String(i + 1),
          title: f.replace(/\.mp4$/i, ''),
          author: '本地视频',
          avatar: '',
          videoUrl: base + '/video/' + f,
          likes: 0,
          comments: 0,
          shares: 0,
          createdAt: new Date().toISOString(),
        }));
      } else {
        // 3. 最终回退到 mock 数据
        list = videos.slice().sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
      }
    }

    const start = (page - 1) * pageSize;
    const paged = list.slice(start, start + pageSize);
    res.json({ success: true, data: paged, total: list.length, page: page, pageSize: pageSize });
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message, data: [] });
  }
});

// ===== 上传视频（保持不变） =====
app.post('/api/videos/upload',
  upload.fields([{ name: 'video', maxCount: 1 }, { name: 'avatar', maxCount: 1 }]),
  (req, res) => {
    try {
      const base = getBaseUrl(req);
      const title = String(req.body.title || '').trim();
      const author = String(req.body.author || '匿名用户').trim();
      if (!req.files || !req.files['video'] || req.files['video'].length === 0) {
        return res.json({ success: false, message: '请选择要上传的视频文件' });
      }
      if (!title) return res.json({ success: false, message: '请输入视频标题' });
      const videoFile = req.files['video'][0];
      const videoUrl = base + '/uploads/videos/' + videoFile.filename;
      let avatarUrl = '';
      if (req.files && req.files['avatar'] && req.files['avatar'].length > 0) {
        avatarUrl = base + '/uploads/avatars/' + req.files['avatar'][0].filename;
      }
      const newVideo = {
        id: String(Date.now()), title: title, author: author, avatar: avatarUrl,
        videoUrl: videoUrl, likes: 0, comments: 0, shares: 0,
        createdAt: new Date().toISOString(),
      };
      videos.unshift(newVideo);
      res.json({ success: true, message: '上传成功', data: newVideo });
    } catch (e) {
      res.json({ success: false, message: '上传失败: ' + e.message });
    }
  }
);

// ===== 错误处理 =====
app.use((err, req, res, next) => {
  if (err) return res.json({ success: false, message: err.message || '上传错误' });
  next();
});

// ===== 旧版点赞（仅+1，保持兼容） =====
app.post('/api/videos/:id/like', (req, res) => {
  try {
    const v = videos.find((x) => x.id === req.params.id);
    if (!v) return res.json({ success: false, message: '视频不存在' });
    v.likes = (v.likes || 0) + 1;
    res.json({ success: true, data: { id: v.id, likes: v.likes } });
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message });
  }
});

// ===== 点赞/取消点赞 =====
app.post('/api/like', (req, res) => {
  try {
    const { username, videoId } = req.body || {};
    if (!username || !videoId) {
      return res.json({ success: false, message: 'username 和 videoId 不能为空' });
    }
    const vId = Number(videoId);
    const existing = db.prepare('SELECT id FROM likes WHERE username = ? AND video_id = ?').get(username, vId);
    if (existing) {
      db.prepare('DELETE FROM likes WHERE username = ? AND video_id = ?').run(username, vId);
      const countRow = db.prepare('SELECT COUNT(*) as count FROM likes WHERE video_id = ?').get(vId);
      res.json({ success: true, liked: false, count: countRow.count });
    } else {
      db.prepare('INSERT INTO likes (username, video_id, created_at) VALUES (?, ?, ?)')
        .run(username, vId, new Date().toISOString());
      const countRow = db.prepare('SELECT COUNT(*) as count FROM likes WHERE video_id = ?').get(vId);
      res.json({ success: true, liked: true, count: countRow.count });
    }
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message });
  }
});

// ===== 批量查询点赞状态 =====
app.get('/api/likes', (req, res) => {
  try {
    const username = req.query.username || '';
    const idsRaw = req.query.ids || '';
    const ids = idsRaw ? idsRaw.split(',').map(s => s.trim()).filter(Boolean) : [];
    const result = ids.map(id => {
      const vId = Number(id);
      const countRow = db.prepare('SELECT COUNT(*) as count FROM likes WHERE video_id = ?').get(vId);
      let liked = false;
      if (username) {
        const likeRow = db.prepare('SELECT id FROM likes WHERE username = ? AND video_id = ?').get(username, vId);
        liked = !!likeRow;
      }
      return { id: id, count: countRow.count, liked: liked };
    });
    res.json({ success: true, data: result });
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message, data: [] });
  }
});

// ===== 发表评论 =====
app.post('/api/comment', (req, res) => {
  try {
    const { username, videoId, content } = req.body || {};
    if (!username || !videoId || !content) {
      return res.json({ success: false, message: 'username, videoId, content 不能为空' });
    }
    if (String(content).trim().length === 0) {
      return res.json({ success: false, message: '评论内容不能为空' });
    }
    if (String(content).length > 200) {
      return res.json({ success: false, message: '评论内容不能超过200字' });
    }
    const vId = Number(videoId);
    const createdAt = formatDateTime();
    const info = db.prepare('INSERT INTO comments (username, video_id, content, likes, created_at) VALUES (?, ?, ?, 0, ?)')
      .run(username, vId, String(content), createdAt);
    const comment = db.prepare('SELECT * FROM comments WHERE id = ?').get(info.lastInsertRowid);
    res.json({ success: true, message: '评论成功', data: comment });
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message });
  }
});

// ===== 评论列表 =====
app.get('/api/comments', (req, res) => {
  try {
    const videoId = req.query.videoId;
    if (!videoId) return res.json({ success: false, message: 'videoId 不能为空', data: [] });
    const vId = Number(videoId);
    const comments = db.prepare('SELECT * FROM comments WHERE video_id = ? ORDER BY id DESC').all(vId);
    res.json({ success: true, data: comments });
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message, data: [] });
  }
});

// ===== 批量查询评论数 =====
app.get('/api/commentCount', (req, res) => {
  try {
    const idsRaw = req.query.ids || '';
    const ids = idsRaw ? idsRaw.split(',').map(s => s.trim()).filter(Boolean) : [];
    const result = ids.map(id => {
      const vId = Number(id);
      const countRow = db.prepare('SELECT COUNT(*) as count FROM comments WHERE video_id = ?').get(vId);
      return { id: id, count: countRow.count };
    });
    res.json({ success: true, data: result });
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message, data: [] });
  }
});

// ===== 用户个人信息统计 =====
app.get('/api/user/profile', (req, res) => {
  try {
    const username = req.query.username || '';
    if (!username) {
      return res.json({ success: false, message: 'username 不能为空' });
    }
    // 喜欢数：该用户点赞过的视频数量
    const favRow = db.prepare('SELECT COUNT(*) as count FROM likes WHERE username = ?').get(username);
    // 作品数：该用户上传的视频数量
    const worksRow = db.prepare('SELECT COUNT(*) as count FROM videos WHERE author = ?').get(username);
    // 获赞总数：该用户所有视频获得的点赞数（通过 video_id 关联 videos 表的 author）
    const likesRow = db.prepare(`
      SELECT COUNT(*) as count FROM likes
      WHERE video_id IN (SELECT id FROM videos WHERE author = ?)
    `).get(username);
    res.json({
      success: true,
      data: {
        username: username,
        likes: likesRow.count,    // 获赞总数
        following: 0,             // 关注数（后续做关注功能再改）
        followers: 0,             // 粉丝数（后续做关注功能再改）
        works: worksRow.count,    // 作品数
        favorite: favRow.count     // 喜欢数
      }
    });
  } catch (e) {
    res.json({ success: false, message: '服务器错误: ' + e.message });
  }
});

// ===== 用户作品列表 =====
app.get('/api/user/videos', (req, res) => {
  try {
    const base = getBaseUrl(req);
    const username = req.query.username || '';
    if (!username) {
      return res.json({ code: 1, msg: 'username 不能为空' });
    }
    const rows = db.prepare('SELECT * FROM videos WHERE author = ? ORDER BY id DESC').all(username);
    const data = rows.map(r => ({
      id: String(r.id),
      url: base + '/video/' + r.filename,
      title: r.title,
      author: r.author,
      created_at: r.created_at,
    }));
    res.json({ code: 0, data: data });
  } catch (e) {
    res.json({ code: 1, msg: '服务器错误: ' + e.message });
  }
});

// ===== 启动服务 =====
app.listen(PORT, HOST, () => {
  console.log('========================================');
  console.log('   斗立后端服务已启动 (SQLite持久化)');
  console.log('========================================');
  console.log('本地访问:   http://localhost:' + PORT);
  console.log('健康检查:   http://localhost:' + PORT + '/health');
  console.log('视频上传功能已就绪');
  console.log('接口列表:');
  console.log('  POST /api/login           登录');
  console.log('  POST /api/register        注册');
  console.log('  GET  /api/videos          视频列表');
  console.log('  POST /api/upload          视频上传(新)');
  console.log('  POST /api/videos/upload   视频上传(旧)');
  console.log('  POST /api/like            点赞/取消点赞');
  console.log('  GET  /api/likes            批量查询点赞状态');
  console.log('  POST /api/comment         发表评论');
  console.log('  GET  /api/comments        评论列表');
  console.log('  GET  /api/commentCount    批量查询评论数');
  console.log('  GET  /api/user/profile    用户个人信息统计');
  console.log('  GET  /api/user/videos     用户作品列表');
  console.log('========================================');
});