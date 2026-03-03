# kzo-ios（SwiftUI 原生版）

这是一个按参考图风格实现的 iOS SwiftUI 项目骨架，已经包含：
- 三个核心页面风格：`Home` / `Manga Details` / `Downloads`
- 登录链路：`WKWebView` 登录 + Cookie 提取 + 请求头注入
- 数据层结构：`ViewModel -> Service -> Parser`
- 下载管理状态机骨架：下载中/暂停/完成

当前目录已经补齐了可打开的 Xcode 工程文件：
- `KzoApp.xcodeproj`

---

## 1. 环境要求

- macOS
- Xcode（完整安装版，不是仅 Command Line Tools）
- iOS 16.0+

如果你在终端里看到下面错误：
- `xcodebuild requires Xcode, but active developer directory is CommandLineTools`

说明你当前只指向了命令行工具，需要切到完整 Xcode：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## 2. 如何打开项目

1. 在 Finder 中进入：`/Users/creepnuts/Desktop/swiftDemo/kzo-ios`
2. 双击：`KzoApp.xcodeproj`
3. Xcode 打开后，选择 `KzoApp` Target
4. 在 `Signing & Capabilities` 里选择你的 Team（必做）
5. 选择模拟器（例如 iPhone 15）后直接运行

如果双击还是打不开，可以用终端：

```bash
cd /Users/creepnuts/Desktop/swiftDemo/kzo-ios
xed KzoApp.xcodeproj
```

---

## 3. 项目结构（完整）

```text
kzo-ios/
├── KzoApp.xcodeproj
├── App/
│   ├── KzoApp.swift
│   ├── RootTabView.swift
│   └── Theme/
│       └── AppTheme.swift
├── Core/
│   ├── Auth/
│   │   └── AuthSessionStore.swift
│   ├── DownloadEngine/
│   │   └── DownloadQueueEngine.swift
│   ├── Networking/
│   │   └── NetworkClient.swift
│   ├── Parsing/
│   │   ├── BookshelfParser.swift
│   │   ├── DetailParser.swift
│   │   └── HTMLParsingSupport.swift
│   └── Services/
│       ├── DetailService.swift
│       └── MangaService.swift
├── Features/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── LoginWebView.swift
│   ├── Bookshelf/
│   │   ├── BookshelfView.swift
│   │   └── BookshelfViewModel.swift
│   ├── Detail/
│   │   ├── DetailView.swift
│   │   └── DetailViewModel.swift
│   ├── Downloads/
│   │   ├── DownloadsView.swift
│   │   └── DownloadsViewModel.swift
│   └── Profile/
│       └── ProfileView.swift
└── Shared/
    ├── Components/
    │   ├── CardContainer.swift
    │   ├── MangaGridCard.swift
    │   ├── RemoteCoverImage.swift
    │   └── StatusChip.swift
    └── Models/
        ├── DownloadTask.swift
        └── Manga.swift
```

---

## 4. 已实现功能

### 4.1 UI 与导航

- `TabView` 三个 Tab：`Home / Downloads / Profile`
- 视觉规范对齐参考图：浅灰背景、蓝色主色、圆角卡片、分层阴影
- 书架卡片可跳详情页（带参数）

### 4.2 登录与鉴权

- 书架页点击 `Log In` 打开 `WKWebView`
- 访问 `https://kzo.moe/login.php`
- 登录成功后读取 `WKHTTPCookieStore`
- 会话写入 `AuthSessionStore`
- `NetworkClient` 自动注入 Cookie 请求头

### 4.3 数据链路

- 书架：`BookshelfViewModel -> MangaService -> BookshelfParser`
- 详情：`DetailViewModel -> DetailService -> DetailParser`
- 对 `kzo/koz` 首页优先解析 `disp_divinfo(...)` 脚本数据（书名、作者、封面、更新信息）
- 书架页每次显示都会重新请求首页并重新解析（不依赖登录）
- 搜索使用 `GET /list.php?s=关键词`，返回后复用同一解析器渲染结果
- 解析失败自动回退到本地 Mock，保证 UI 始终可展示

### 4.4 下载模块（骨架）

- `DownloadTask` + `DownloadState`
- `DownloadQueueEngine`（actor）管理任务状态
- 支持暂停/恢复下载项、删除已完成项

---

## 5. 当前限制（你需要知道）

1. 解析器目前是“通用规则”版本（正则抽取），不是最终站点专用选择器。  
2. 下载模块还没接入真实 `URLSessionDownloadTask`。  
3. 封面图为远程加载，若站点防盗链策略变化可能出现加载失败。  
4. 项目已可在 Xcode 打开，但你本机需要先配置完整 Xcode + 签名。  

---

## 6. 下一步建议（开发优先级）

1. 接入 `SwiftSoup`，替换 `BookshelfParser / DetailParser` 为站点精确解析。  
2. 加 `Reader` 页面与章节路由，打通“详情 -> 阅读”。  
3. 接真实下载引擎：后台会话、断点续传、失败重试。  
4. 接 `SwiftData` 保存阅读进度、下载记录、收藏状态。  

---

## 7. 常见问题排查

### Q1: Xcode 提示签名失败
- 打开 Target -> `Signing & Capabilities`
- 选择你的 Team
- 修改 `Bundle Identifier` 为你自己的唯一值

### Q2: 打不开工程或双击无反应
- 确认打开的是 `KzoApp.xcodeproj`，不是文件夹
- 用命令 `xed KzoApp.xcodeproj` 打开

### Q3: 终端里 `xcodebuild` 不能用
- 执行：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
