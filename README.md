# UnzipLite - 解压助手

基于 Jieyas.ipa (Unzip v5.13) 基础功能复刻的 iOS 文件管理应用。

## 核心功能

### 1. 文件页 - 正常访问系统目录
- 浏览应用沙盒内的文件和目录
- 支持多级目录导航
- 从系统「文件」应用导入文件（支持多选）
- 新建文件夹、删除、重命名、分享
- 文件类型图标识别（压缩包、图片、视频、音频、文档、电子书）
- 支持图片缩放预览、文本预览、QuickLook 预览（PDF/Office 等）
- 左滑操作：删除 / 重命名 / 分享

### 2. 设置页 - 在「文件」应用中隐藏文件
- **核心开关**：「在文件应用中隐藏文件」
- 开启后，所有文件从 iOS 系统「文件」(Files) 应用中消失
- 应用内仍可正常访问和管理所有文件
- 关闭后，文件恢复到「文件」应用中可见

## 隐藏文件实现原理

iOS 的「文件」应用通过 `UIFileSharingEnabled` 显示应用的 `Documents/` 目录。

```
关闭隐藏（默认）:
  Documents/          ← 在 Files 应用中可见
    ├── 文件1.zip
    ├── 照片.jpg
    └── ...

开启隐藏:
  Documents/          ← 空，Files 应用中看不到文件
  Library/HiddenFiles/ ← Files 应用不可见
    ├── 文件1.zip
    ├── 照片.jpg
    └── ...
```

应用内文件浏览器始终读取当前活动目录（`FileHideManager.currentRootURL`），因此无论隐藏状态如何，用户在应用内都能看到所有文件。

## 项目结构

```
UnzipLite/
├── UnzipLite/
│   ├── AppDelegate.swift              # 应用入口
│   ├── SceneDelegate.swift            # 场景管理
│   ├── Info.plist                     # 应用配置
│   ├── Base.lproj/
│   │   └── LaunchScreen.storyboard    # 启动屏
│   ├── Assets.xcassets/               # 资源目录
│   ├── ViewControllers/
│   │   ├── MainTabBarController.swift    # 主标签栏（文件+设置）
│   │   ├── FileBrowserViewController.swift  # 文件浏览器
│   │   ├── FilePreviewViewController.swift  # 文件预览
│   │   └── SettingsViewController.swift     # 设置页（含隐藏开关）
│   ├── Models/
│   │   ├── FileItem.swift             # 文件项模型
│   │   └── FileHideManager.swift      # 文件隐藏管理器（核心）
│   └── Views/
│       └── FileCell.swift             # 文件列表单元格
└── UnzipLite.xcodeproj/
    └── project.pbxproj                # Xcode 项目配置
```

## 编译要求

- macOS 13+ (Ventura 或更新)
- Xcode 14.0+
- iOS 13.0+ 部署目标
- Swift 5.0+

## 编译步骤

1. **打开项目**
   ```bash
   open UnzipLite.xcodeproj
   ```

2. **配置签名**
   - 在 Xcode 中选中项目 → Signing & Capabilities
   - 选择你的开发团队 (Team)
   - 修改 Bundle Identifier 为唯一值（默认 `com.example.unziplite`）

3. **编译运行**
   - 选择目标设备或模拟器
   - 按 `Cmd + R` 运行

4. **导出 IPA**
   - Product → Archive
   - Distribute App → 选择分发方式
   - 导出 `.ipa` 文件

## 关键类说明

### FileHideManager（单例）

核心文件隐藏管理器，负责：
- `isHidingInFilesApp` — 当前隐藏状态（持久化到 UserDefaults）
- `enableHiding()` — 将 Documents 文件移到 Library/HiddenFiles
- `disableHiding()` — 将文件移回 Documents
- `currentRootURL` — 应用内应使用的根目录
- `contentsOfDirectory(at:)` — 列出目录内容
- `importFile(from:)` — 导入外部文件
- `createFolder/deleteItem/renameItem` — 文件操作

### SettingsViewController

设置页面，包含：
- 文件可见性 section：隐藏开关（核心功能）
- 通用 section：默认目录显示、清理缓存
- 关于 section：版本信息、隐私政策

### FileBrowserViewController

文件浏览器，支持：
- 目录导航（push 子目录）
- 文件导入（UIDocumentPickerViewController）
- 新建文件夹
- 左滑删除/重命名/分享
- 文件预览（图片缩放、文本、QuickLook）

## 与原应用 (Unzip v5.13) 的对应关系

| 原应用功能 | 本项目实现 |
|-----------|-----------|
| 文件浏览 | FileBrowserViewController |
| 系统目录访问 | UIDocumentPicker + 沙盒目录 |
| 在 Files 中隐藏 | FileHideManager + 设置开关 |
| 文件类型识别 | FileItem.FileType 枚举 |
| 压缩包图标 | SF Symbols (archivebox.fill) |
| 专业版订阅 | 未实现（本项目为基础功能版） |
| 广告 SDK | 未集成（纯净版） |
| 云存储集成 | 未实现（可扩展） |

## 扩展方向

- 集成压缩/解压功能（使用 PLzmaSDK 或 SSZipArchive）
- 添加 WiFi 文件传输（GCDWebUploader）
- 集成密码锁（LTHPasscodeViewController）
- 添加云存储（Google Drive / Dropbox / OneDrive）
- 支持更多文件格式预览
