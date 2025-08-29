# Install APK v1.6

一个用于在 macOS 上安装和管理 APK 文件的工具。

## 🚀 功能特点

- 简单易用的 macOS 应用程序
- 专业的 DMG 安装包
- 优化的用户界面布局
- 自动化打包脚本

## 📦 下载安装

### 下载方式
1. 从 [Releases](https://github.com/YOUR_USERNAME/install-apk-macos/releases) 页面下载最新版本的 DMG 文件
2. 双击 DMG 文件打开安装界面
3. 将 Install APK.app 拖拽到 Applications 文件夹

### 系统要求
- macOS 10.12 或更高版本
- 64位处理器

## 🛠️ 开发者信息

### 项目结构
```
├── Install APK.app/          # 主应用程序
├── create_dmg.sh            # DMG 打包脚本
├── create_custom_background.py # 自定义背景生成脚本
├── DMG_Background_Guide.md  # DMG 背景设置指南
└── 历史备份/                # 历史版本备份
```

### 打包说明
本项目使用自定义的 DMG 打包脚本，具有以下特点：
- 窗口尺寸：600x400 像素
- 左侧显示应用图标，右侧显示 Applications 文件夹
- 图标完美居中对齐
- 专业的安装界面

### 构建 DMG
```bash
# 运行打包脚本
./create_dmg.sh
```

## 📝 更新日志

### v1.6.0
- 优化 DMG 窗口布局
- 更新窗口尺寸为 600x400 像素
- 改进图标位置算法
- 增强打包脚本稳定性

## 📄 许可证

[在此添加您的许可证信息]

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 联系方式

如有问题，请通过以下方式联系：
- GitHub Issues: [项目 Issues 页面]
- Email: [您的邮箱]