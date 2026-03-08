# PerDev Market 
<img src="assets/icon/perdev.png" alt="icon" width="60" style="display: block; margin: auto;">

一个基于Flutter开发的应用商店App，Material design设计，现公开源代码供参考动画和功能实现，前世是PerDev的Flutter重构版。因不可抗力因素已停止运营😭

## 项目信息

- **框架**：Flutter (Dart 3.0+)
- **平台**：Android

## 主要依赖

| 依赖库 | 用途 |
|-------|------|
| HTTP | 网络请求 |
| Flutter Secure Storage | 安全存储 |
| PointyCastle | 数据加密 |
| WebView Flutter | 内置浏览器 |
| Cached Network Image | 图片缓存 |
| SQLite (sqflite) | 本地数据库 |

### 动画与页面
使用Flutter的Hero等流畅动效，Material design设计，虚化效果

## 功能模块
### 服务器认证
启动时根据ID，时间等与服务器进行校验，服务器存储Session
### 应用列表
网格布局等展示应用，支持下拉刷新和上拉加载更多。
### 应用详情
包含应用介绍、下载按钮等，背景虚化。
