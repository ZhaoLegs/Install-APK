# Install APK (macOS)

**作者：** legs
**版本：** 1.3

## 简介

`Install APK` 是一个为 macOS 设计的终端工具，旨在简化 Android 应用的安装与更新流程，并提供系统更新支持。

## 主要功能

*   **🚀 快速安装与更新**: 轻松拖拽 APK/OTA 文件即可完成安装或系统更新。
*   **⚙️ 环境自动配置**: 首次运行时，自动检测并安装所需的依赖环境 (Homebrew, ADB)。
*   **🔧 高级工具箱**: 内置常用 ADB 命令，方便进行高级调试操作。

## 使用方法

1.  **下载**: 从以下地址下载 `InstallAPK.zip` 文件。
    *   [https://github.com/ZhaoLegs/Install-APK/releases](https://github.com/ZhaoLegs/Install-APK/releases)
2.  **解压**: 双击解压 `InstallAPK.zip`，得到 `Install APK.app`。
3.  **运行**: 双击 `Install APK.app` 启动工具。

## 常见问题排查 (Troubleshooting)

**问题：打开时提示“文件已损坏”或“无法打开，因为来自未经验证的开发者”。**

这是 macOS 的安全机制 (Gatekeeper) 导致的。您有两种方式可以解决：

**方法一：通过终端命令 (推荐)**

1.  打开“终端” (Terminal) 应用。
2.  输入以下命令，注意命令和路径之间的空格：
    ```bash
    sudo xattr -r -d com.apple.quarantine 
    ```
3.  将 `Install APK.app` 文件拖入终端窗口，会自动填充其完整路径。
4.  按下回车，输入您的电脑密码 (输入时不可见)，再次回车即可。

**方法二：通过系统设置**

1.  首次尝试打开应用失败后，进入“系统设置”。
2.  前往“隐私与安全性”面板。
3.  向下滚动，您会看到一条关于“Install APK.app”被阻止的提示。
4.  点击“仍要打开”按钮，并根据提示输入密码。

---
感谢使用！
