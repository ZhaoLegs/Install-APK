#!/bin/bash

# App: Install APK
# 作者：legs
# 版本：V1.4
# 功能：Install APK 是一个终端工具，可快速安装和更新 Android 应用，同时支持系统更新。
#

# --- 界面颜色定义 ---
if [[ -t 1 ]]; then
  tty_escape() { printf '\033[%sm' "$1"; }
else
  tty_escape() { :; }
fi

tty_red="$(tty_escape '0;31')"
tty_green="$(tty_escape '0;32')"
tty_yellow="$(tty_escape '0;33')"
tty_blue="$(tty_escape '0;34')"
tty_cyan="$(tty_escape '0;36')"
tty_bold="$(tty_escape '1;39')" # 通用粗体
tty_bold_green="$(tty_escape '1;32')" # 用于交互式提示
tty_reset="$(tty_escape 0)"

# --- 全局变量和初始化 ---
LOG_DIR="$HOME/Desktop/apk_install_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date '+%Y-%m-%d_%H-%M-%S').log"
TEMP_DIR="/tmp/apk_install_temp"
mkdir -p "$TEMP_DIR"
SELECTED_DEVICE=""  # 选中的设备序列号

# --- 日志记录函数 ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# --- 箭头菜单选择函数 ---
arrow_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    
    # 显示菜单标题（只显示一次）
    echo ""
    echo "${tty_bold}${tty_green}$title${tty_reset}"
    echo ""
    
    # 隐藏光标以减少闪烁
    printf '\033[?25l'
    
    # 渲染菜单的函数
    render_menu() {
        for i in "${!options[@]}"; do
            printf '\033[2K'  # 清除整行
            if [ $i -eq $selected ]; then
                printf "${tty_bold_green}👉🏻 %s${tty_reset}\n" "${options[$i]}"
            else
                printf "  ${tty_green}%s${tty_reset}\n" "${options[$i]}"
            fi
        done
        echo ""
        printf '\033[2K'  # 清除帮助信息行
        printf "${tty_green}使用 ▲ ▼ 箭头键选择，回车确认${tty_reset}\n"
        echo ""
    }
    
    # 显示初始菜单
    render_menu
    
    while true; do
        # 使用bash内置的read功能读取按键
        local key
        IFS= read -rsn1 key
        
        # 检查是否是ESC序列（箭头键）
        if [[ $key == $'\x1b' ]]; then
            IFS= read -rsn2 key
            case $key in
                '[A') # 上箭头
                    ((selected--))
                    if [ $selected -lt 0 ]; then
                        selected=$((${#options[@]} - 1))
                    fi
                    # 回到菜单开始位置重新渲染
                    printf '\033[%dA' $((${#options[@]} + 3))
                    render_menu
                    ;;
                '[B') # 下箭头
                    ((selected++))
                    if [ $selected -ge ${#options[@]} ]; then
                        selected=0
                    fi
                    # 回到菜单开始位置重新渲染
                    printf '\033[%dA' $((${#options[@]} + 3))
                    render_menu
                    ;;
            esac
        else
            case "$key" in
                $'\x0a'|$'\x0d'|'') # 回车键
                    # 显示光标
                    printf '\033[?25h'
                    echo ""
                    return $selected
                    ;;
                "q"|"Q") # q键退出
                    # 显示光标
                    printf '\033[?25h'
                    echo ""
                    return -1
                    ;;
            esac
        fi
    done
}

# --- 依赖检查与安装 ---
check_and_install_dependencies() {
    echo "${tty_cyan}────────────────────────────────────────────────────────────────────────────────${tty_reset}"
    echo "${tty_cyan}正在检查环境依赖${tty_reset}"
    echo "${tty_cyan}────────────────────────────────────────────────────────────────────────────────${tty_reset}"
    echo ""

    # 1. 检查 Homebrew
    if ! command -v brew &> /dev/null; then
        echo "${tty_yellow}📦 未检测到 Homebrew 包管理器，正在自动安装...${tty_reset}"
        echo "${tty_cyan}ℹ️  Homebrew 是 macOS 上的包管理工具，用于安装 Android 开发工具${tty_reset}"
        /bin/bash "$(dirname "$0")/homebrew_install.sh"
        if [ $? -ne 0 ]; then
            echo "${tty_red}❌ Homebrew 安装失败${tty_reset}"
            echo "${tty_yellow}💡 您可以手动安装：访问 https://brew.sh 获取安装说明${tty_reset}"
            read -p "${tty_bold_green}按回车键退出...${tty_reset}"
            exit 1
        fi
        echo "${tty_green}✅ Homebrew 安装成功${tty_reset}"
    else
        echo "${tty_green}✅ Homebrew 已就绪${tty_reset}"
    fi

    # 初始化 Homebrew 环境
    if [ -x "/opt/homebrew/bin/brew" ]; then
        # Apple Silicon (M1/M2)
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        # Intel
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    # 2. 检查并安装 ADB
    if ! command -v adb &> /dev/null; then
        echo "${tty_yellow}📱 未检测到 ADB 工具，正在安装 Android 平台工具...${tty_reset}"
        echo "${tty_cyan}ℹ️  ADB 是 Android 调试桥，用于与 Android 设备通信${tty_reset}"
        # 强制解决 'already a Binary' 错误
        echo "${tty_yellow}正在清理可能存在的旧版本文件...${tty_reset}"
        rm -f /opt/homebrew/bin/adb
        rm -f /opt/homebrew/bin/fastboot
        
        brew reinstall --cask android-platform-tools
        if [ $? -ne 0 ]; then
            echo "${tty_red}❌ ADB 安装失败${tty_reset}"
            echo "${tty_yellow}💡 请尝试以下解决方案：${tty_reset}"
            echo "${tty_yellow}   1. 运行 'brew update' 更新 Homebrew${tty_reset}"
            echo "${tty_yellow}   2. 检查网络连接是否正常${tty_reset}"
            echo "${tty_yellow}   3. 手动执行：brew reinstall --cask android-platform-tools${tty_reset}"
            read -p "${tty_bold_green}按回车键退出...${tty_reset}"
            exit 1
        fi
        echo "${tty_green}✅ ADB 工具安装成功${tty_reset}"
    else
        echo "${tty_green}✅ ADB 工具已就绪${tty_reset}"
    fi
    
    # 3. 检查并安装 Python3
    if ! command -v python3 &> /dev/null; then
        echo "${tty_yellow}未检测到 Python3，正在通过 Homebrew 安装...${tty_reset}"
        brew install python3
        if [ $? -ne 0 ]; then
            echo "${tty_red}❌ Python3 安装失败。请检查 Homebrew 是否正常工作。${tty_reset}"
            read -p "${tty_bold_green}按回车键退出...${tty_reset}"
            exit 1
        fi
        echo "${tty_green}✅ Python3 安装成功。${tty_reset}"
    else
        echo "${tty_green}✅ Python3 已安装。${tty_reset}"
    fi

    # 4. 检查并安装 aapt 工具
    if ! command -v aapt &> /dev/null; then
        echo "${tty_yellow}未检测到 aapt 工具，正在尝试安装...${tty_reset}"
        
        # 首先检查是否已经有 Android SDK 安装
        local sdk_locations=(
            "$HOME/Library/Android/sdk"
            "$HOME/Android/Sdk"
            "/usr/local/lib/android/sdk"
            "/opt/android-sdk"
        )
        
        local aapt_found=false
        for sdk_path in "${sdk_locations[@]}"; do
            if [ -d "$sdk_path" ]; then
                # 查找 build-tools 目录下最新版本的 aapt
                local build_tools_dir="$sdk_path/build-tools"
                if [ -d "$build_tools_dir" ]; then
                    local latest_version=$(ls -1 "$build_tools_dir" | sort -V | tail -1)
                    if [ -n "$latest_version" ] && [ -f "$build_tools_dir/$latest_version/aapt" ]; then
                        echo "${tty_green}✅ 在 Android SDK 中找到 aapt 工具${tty_reset}"
                        aapt_found=true
                        break
                    fi
                fi
            fi
        done
        
        if ! $aapt_found; then
            echo "${tty_yellow}未找到 Android SDK，尝试通过 Homebrew 安装 android-sdk...${tty_reset}"
            brew install --cask android-sdk
            if [ $? -ne 0 ]; then
                echo "${tty_yellow}无法安装 Android SDK，尝试安装 android-commandlinetools...${tty_reset}"
                brew install --cask android-commandlinetools
                
                if [ $? -ne 0 ]; then
                    echo "${tty_yellow}无法通过 Homebrew 安装 Android 工具，将使用简化模式继续（无 APK 信息提取）...${tty_reset}"
                else
                    # 使用 sdkmanager 安装 build-tools
                    echo "${tty_yellow}安装 Android build-tools...${tty_reset}"
                    yes | sdkmanager "build-tools;33.0.0" > /dev/null
                    
                    # 再次尝试链接 aapt
                    if [ -f "$HOME/Library/Android/sdk/build-tools/33.0.0/aapt" ]; then
                        echo "${tty_green}✅ aapt 工具已安装${tty_reset}"
                        aapt_found=true
                    fi
                fi
            else
                # 安装成功后，使用 sdkmanager 安装 build-tools
                echo "${tty_yellow}安装 Android build-tools...${tty_reset}"
                yes | sdkmanager "build-tools;33.0.0" > /dev/null
                
                # 链接 aapt
                if [ -f "$HOME/Library/Android/sdk/build-tools/33.0.0/aapt" ]; then
                    ln -sf "$HOME/Library/Android/sdk/build-tools/33.0.0/aapt" /usr/local/bin/aapt
                    aapt_found=true
                fi
            fi
        fi
        
        if $aapt_found; then
            echo "${tty_green}✅ aapt 工具安装成功。${tty_reset}"
        else
            echo "${tty_yellow}⚠️ aapt 工具安装失败，将使用简化模式继续（无 APK 信息提取）。${tty_reset}"
        fi
    else
        echo "${tty_green}✅ aapt 工具已安装。${tty_reset}"
    fi

    # 5. 设置 Python 别名
    local shell_config_file
    if [ -n "$ZSH_VERSION" ]; then
        shell_config_file="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_config_file="$HOME/.bash_profile"
    else
        shell_config_file="$HOME/.profile" # 默认情况
    fi

    if ! grep -q "alias python=/usr/bin/python3" "$shell_config_file"; then
        echo "${tty_yellow}正在为 python 命令设置别名指向 python3...${tty_reset}"
        echo -e "\n# 设置 python 命令指向 python3\nalias python=/usr/bin/python3" >> "$shell_config_file"
        echo "${tty_green}✅ 别名已添加到 $shell_config_file。请重启终端以使设置生效。${tty_reset}"
    else
        echo "${tty_green}✅ Python 别名已配置。${tty_reset}"
    fi
    
    # 6. 检查是否有 GNU Parallel 工具
    if ! command -v parallel &> /dev/null; then
        echo "${tty_yellow}未检测到 GNU Parallel 工具，正在通过 Homebrew 安装...${tty_reset}"
        brew install parallel
        if [ $? -ne 0 ]; then
            echo "${tty_yellow}⚠️ GNU Parallel 安装失败，将使用串行模式继续。${tty_reset}"
        else
            echo "${tty_green}✅ GNU Parallel 安装成功。${tty_reset}"
            # 确认已经接受 GNU Parallel 的引用通知
            mkdir -p ~/.parallel
            touch ~/.parallel/will-cite
        fi
    else
        echo "${tty_green}✅ GNU Parallel 已安装。${tty_reset}"
    fi
    
    echo ""
    echo "${tty_cyan}────────────────────────────────────────────────────────────────────────────────${tty_reset}"
    echo "${tty_cyan}环境依赖检查完成${tty_reset}"
    echo "${tty_cyan}────────────────────────────────────────────────────────────────────────────────${tty_reset}"
}


# --- 增强的错误原因解析函数 ---
parse_error_reason() {
    local reason_raw="$1"
    local reason_simplified="未知错误"
    local solution=""

    if [[ $reason_raw == *"INSTALL_FAILED_VERSION_DOWNGRADE"* ]]; then
        reason_simplified="🔄 应用版本问题：您要安装的版本比手机上现有的版本更旧" 
    solution="💡 解决方案：您可以先卸载手机上的应用，或者寻找更新版本的APK文件"
        solution="请使用 -d 参数允许版本降级，或安装更新版本的应用。"
    elif [[ $reason_raw == *"INSTALL_FAILED_ALREADY_EXISTS"* ]]; then
        reason_simplified="应用已存在：但签名或版本不匹配。"
        solution="请先卸载设备上的应用，或使用 -r 参数强制替换。"
    elif [[ $reason_raw == *"INSTALL_FAILED_INSUFFICIENT_STORAGE"* ]]; then
        reason_simplified="存储空间不足：请清理设备存储空间。"
        solution="删除设备上不需要的应用或文件，或尝试将应用安装到外部存储。"
    elif [[ $reason_raw == *"INSTALL_FAILED_USER_RESTRICTED"* ]]; then
        reason_simplified="用户限制：安装被设备系统或用户设置阻止。"
        solution="检查设备设置中的安全选项，确保允许从未知来源安装应用。"
    elif [[ $reason_raw == *"INSTALL_PARSE_FAILED_NO_CERTIFICATES"* ]]; then
        reason_simplified="签名无效：APK文件没有签名或签名无效。"
        solution="重新获取正确签名的APK文件，或检查APK是否已损坏。"
    elif [[ $reason_raw == *"INSTALL_FAILED_MISSING_SHARED_LIBRARY"* ]]; then
        reason_simplified="缺少共享库：设备缺少应用运行所需的库文件。"
        solution="这通常是系统级问题，可能需要更新设备系统或安装相关库。"
    elif [[ $reason_raw == *"INSTALL_FAILED_UPDATE_INCOMPATIBLE"* ]]; then
        reason_simplified="签名不兼容（已安装版本与新版本签名不匹配），请先卸载设备上的应用后再安装新版本。"
        solution=""
    elif [[ $reason_raw == *"INSTALL_FAILED_INVALID_APK"* ]]; then
        reason_simplified="无效的APK文件：文件可能已损坏或格式不正确。"
        solution="重新下载或获取有效的APK文件。"
    elif [[ $reason_raw == *"DELETE_FAILED_INTERNAL_ERROR"* ]]; then
        reason_simplified="系统内部错误：卸载旧版本时出错。"
        solution="重启设备后重试，或尝试手动卸载应用。"
    elif [[ $reason_raw == *"INSTALL_FAILED_DEXOPT"* ]]; then
        reason_simplified="DEX优化失败：应用无法在设备上优化。"
        solution="检查设备存储空间是否足够，或尝试重启设备后重试。"
    elif [[ $reason_raw == *"INSTALL_FAILED_OLDER_SDK"* ]]; then
        reason_simplified="SDK版本过低：应用需要更高版本的Android系统。"
        solution="此应用需要更新的Android版本，无法在当前设备上安装。"
    elif [[ $reason_raw == *"INSTALL_FAILED_NEWER_SDK"* ]]; then
        reason_simplified="SDK版本过高：应用针对更高版本的Android系统开发。"
        solution="此应用针对更新的Android版本开发，可能在当前设备上不稳定。"
    elif [[ $reason_raw == *"INSTALL_FAILED_TEST_ONLY"* ]]; then
        reason_simplified="仅测试应用：此APK仅用于测试，不能直接安装。"
        solution="使用 -t 参数安装测试应用，或获取正式发布版本。"
    elif [[ $reason_raw == *"INSTALL_FAILED_CPU_ABI_INCOMPATIBLE"* ]]; then
        reason_simplified="CPU架构不兼容：APK不支持设备的处理器架构。"
        solution="获取适合当前设备CPU架构的APK版本。"
    elif [[ $reason_raw == *"INSTALL_FAILED_MISSING_FEATURE"* ]]; then
        reason_simplified="缺少必要功能：设备缺少应用所需的硬件或软件功能。"
        solution="此应用需要设备具备特定功能（如NFC、指纹识别等），当前设备不支持。"
    elif [[ $reason_raw == *"INSTALL_FAILED_CONTAINER_ERROR"* ]]; then
        reason_simplified="容器错误：无法复制APK文件到应用容器。"
        solution="检查设备存储空间是否足够，或尝试重启设备后重试。"
    elif [[ $reason_raw == *"INSTALL_FAILED_INVALID_INSTALL_LOCATION"* ]]; then
        reason_simplified="安装位置无效：指定的安装位置无效或不可访问。"
        solution="尝试不指定安装位置，或检查设备存储权限。"
    elif [[ $reason_raw == *"INSTALL_FAILED_MEDIA_UNAVAILABLE"* ]]; then
        reason_simplified="存储介质不可用：指定的存储介质不可用。"
        solution="检查SD卡是否正确插入，或尝试安装到内部存储。"
    elif [[ $reason_raw == *"INSTALL_PARSE_FAILED_UNEXPECTED_EXCEPTION"* ]]; then
        reason_simplified="解析异常：解析APK文件时发生意外异常。"
        solution="APK文件可能已损坏，请重新获取有效的APK文件。"
    elif [[ $reason_raw == *"INSTALL_PARSE_FAILED_BAD_MANIFEST"* ]]; then
        reason_simplified="清单文件错误：APK的AndroidManifest.xml文件有问题。"
        solution="APK文件可能已损坏或格式不正确，请重新获取有效的APK文件。"
    elif [[ $reason_raw == *"INSTALL_PARSE_FAILED_BAD_PACKAGE_NAME"* ]]; then
        reason_simplified="包名错误：APK的包名无效或格式不正确。"
        solution="APK文件可能已损坏，请重新获取有效的APK文件。"
    elif [[ $reason_raw == *"INSTALL_FAILED_VERIFICATION_TIMEOUT"* ]]; then
        reason_simplified="验证超时：APK验证过程超时。"
        solution="检查网络连接，或禁用Google Play保护功能后重试。"
    elif [[ $reason_raw == *"INSTALL_FAILED_VERIFICATION_FAILURE"* ]]; then
        reason_simplified="验证失败：APK未通过验证。"
        solution="APK可能被修改或来源不可信，请从可信来源获取APK。"
    elif [[ $reason_raw == *"INSTALL_FAILED_PACKAGE_CHANGED"* ]]; then
        reason_simplified="包已更改：安装过程中包发生了变化。"
        solution="重新尝试安装，或重启设备后重试。"
    elif [[ $reason_raw == *"INSTALL_FAILED_UID_CHANGED"* ]]; then
        reason_simplified="UID已更改：应用的UID发生了变化。"
        solution="先卸载设备上的应用，再重新安装。"
    elif [[ $reason_raw == *"INSTALL_FAILED_SESSION_INVALID"* ]]; then
        reason_simplified="会话无效：安装会话已失效。"
        solution="重新尝试安装，或重启ADB服务后重试。"
    elif [[ $reason_raw == *"device not found"* || $reason_raw == *"no devices/emulators found"* ]]; then
        reason_simplified="设备未连接：未找到连接的Android设备。"
        solution="检查USB连接，确保设备已正确连接且已启用USB调试模式。"
    elif [[ $reason_raw == *"device offline"* ]]; then
        reason_simplified="设备离线：设备已连接但处于离线状态。"
        solution="重新连接设备，或在设备上重新授权USB调试。"
    elif [[ $reason_raw == *"unauthorized"* ]]; then
        reason_simplified="未授权：设备未授权ADB连接。"
        solution="在设备上确认USB调试授权请求。"
    else
        # 提取关键信息
        reason_simplified=$(echo "$reason_raw" | grep -o 'Failure \[.*\]' | sed 's/Failure \[//;s/\]//')
        if [[ -z "$reason_simplified" ]]; then
            reason_simplified="未能从ADB输出中提取明确原因。"
            solution="请检查ADB连接和设备状态，或尝试重启设备和ADB服务。"
        else
            solution="未知错误类型，请尝试重启设备或ADB服务后重试。"
        fi
    fi
    
    # 返回格式化的错误信息
    echo "$reason_simplified"
    if [ -n "$solution" ]; then
        echo "解决方案: $solution"
    fi
    
    log "原始错误: $reason_raw"
    log "解析后原因: $reason_simplified"
    if [ -n "$solution" ]; then
        log "建议解决方案: $solution"
    fi
}

# --- APK信息提取函数 ---
extract_apk_info() {
    local apk_path="$1"
    local apk_name=$(basename "$apk_path")
    
    # 检查aapt工具是否可用
    if ! command -v aapt &> /dev/null; then
        # 如果不可用，直接返回，不显示错误信息
        return 1
    fi
    
    echo "${tty_cyan}正在提取 APK 信息: $apk_name${tty_reset}"
    
    # 提取包名、版本等基本信息
    local package_info=$(aapt dump badging "$apk_path" 2>/dev/null)
    if [ $? -ne 0 ]; then
        # 如果提取失败，直接返回，不显示错误信息
        return 1
    fi
    
    # 解析信息 - 使用sed替代grep -oP以提高兼容性
    local package_name=$(echo "$package_info" | sed -n "s/.*package: name='\([^']*\)'.*/\1/p")
    local version_name=$(echo "$package_info" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
    local version_code=$(echo "$package_info" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")
    local min_sdk=$(echo "$package_info" | sed -n "s/.*sdkVersion:'\([^']*\)'.*/\1/p")
    local target_sdk=$(echo "$package_info" | sed -n "s/.*targetSdkVersion:'\([^']*\)'.*/\1/p")
    local app_name=$(echo "$package_info" | sed -n "s/.*application-label:'\([^']*\)'.*/\1/p")
    
    # 权限计数
    local permissions=$(aapt dump permissions "$apk_path" 2>/dev/null | grep "uses-permission:" | wc -l)
    
    # 显示信息
    echo "${tty_bold}📱 APK 信息摘要${tty_reset}"
    echo "${tty_green}应用名称: ${tty_reset}${app_name:-未知}"
    echo "${tty_green}包名: ${tty_reset}${package_name:-未知}"
    echo "${tty_green}版本: ${tty_reset}${version_name:-未知} (${version_code:-未知})"
    echo "${tty_green}SDK要求: ${tty_reset}最低 API ${min_sdk:-未知}, 目标 API ${target_sdk:-未知}"
    echo "${tty_green}权限数量: ${tty_reset}${permissions:-未知}"
    
    # 将信息保存到日志
    log "APK信息: $apk_name"
    log "应用名称: ${app_name:-未知}"
    log "包名: ${package_name:-未知}"
    log "版本: ${version_name:-未知} (${version_code:-未知})"
    log "SDK要求: 最低 API ${min_sdk:-未知}, 目标 API ${target_sdk:-未知}"
    log "权限数量: ${permissions:-未知}"
    
    return 0
}

# --- 显示动态进度条函数 ---
show_dynamic_progress() {
    local percent=$1
    local width=20
    local completed=$((width * percent / 100))
    local bar=""
    
    # 构建进度条（长度加倍）
    for ((j=0; j<completed; j++)); do
        bar+="••"  # 每个单位用两个点表示
    done
    for ((j=completed; j<width; j++)); do
        bar+="··"  # 每个空位也用两个点表示
    done
    
    # 显示进度条（不换行，覆盖上一次显示），改为青色
    printf "\r${tty_cyan}安装进度: ${tty_cyan}%s${tty_cyan} %3d%%${tty_reset}" "$bar" "$percent"
}

# --- 获取设备信息函数 ---
get_device_info() {
    local device_id=$1
    local info=""
    
    # 获取设备型号
    local model=$(adb -s "$device_id" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    
    # 获取Android版本
    local android_version=$(adb -s "$device_id" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
    
    # 获取API级别
    local api_level=$(adb -s "$device_id" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
    
    # 获取设备品牌
    local brand=$(adb -s "$device_id" shell getprop ro.product.brand 2>/dev/null | tr -d '\r')
    
    # 获取设备序列号
    local serial=$(adb -s "$device_id" shell getprop ro.serialno 2>/dev/null | tr -d '\r')
    if [ -z "$serial" ]; then
        serial=$device_id
    fi
    
    # 获取设备存储信息
    local storage_info=$(adb -s "$device_id" shell df /data 2>/dev/null | grep "/data" | awk '{print $2, $3, $4}')
    local total_storage=""
    local used_storage=""
    local free_storage=""
    if [ -n "$storage_info" ]; then
        read total_storage used_storage free_storage <<< "$storage_info"
        # 转换为MB
        total_storage=$((total_storage / 1024))
        used_storage=$((used_storage / 1024))
        free_storage=$((free_storage / 1024))
    fi
    
    echo "${tty_bold}设备信息:${tty_reset}"
    echo "${tty_green}型号: ${tty_reset}${model:-未知}"
    echo "${tty_green}品牌: ${tty_reset}${brand:-未知}"
    echo "${tty_green}Android版本: ${tty_reset}${android_version:-未知} (API ${api_level:-未知})"
    echo "${tty_green}序列号: ${tty_reset}${serial:-未知}"
    if [ -n "$total_storage" ]; then
        echo "${tty_green}存储: ${tty_reset}总计 ${total_storage}MB, 已用 ${used_storage}MB, 可用 ${free_storage}MB"
    fi
    
    # 记录设备信息到日志
    log "设备信息:"
    log "型号: ${model:-未知}"
    log "品牌: ${brand:-未知}"
    log "Android版本: ${android_version:-未知} (API ${api_level:-未知})"
    log "序列号: ${serial:-未知}"
    if [ -n "$total_storage" ]; then
        log "存储: 总计 ${total_storage}MB, 已用 ${used_storage}MB, 可用 ${free_storage}MB"
    fi
}

# --- 设备选择函数 ---
select_device() {
    echo "${tty_yellow}💡 温馨提示：正在检查已连接的设备...${tty_reset}"
    
    # 获取设备列表
    local devices_output
    devices_output=$(adb devices | grep -v "List of devices attached" | grep -v "^$")
    
    if [ -z "$devices_output" ]; then
        echo "${tty_red}未检测到任何 Android 设备，请确认手机已通过 USB 连接电脑、已开启"开发者模式"和"USB 调试"，并在手机上允许本电脑调试。${tty_reset}"
        echo ""
        return 1
    fi
    
    # 解析设备ID和状态
    local device_ids=()
    local device_statuses=()
    
    while IFS= read -r line; do
        local id=$(echo "$line" | awk '{print $1}')
        local status=$(echo "$line" | awk '{print $2}')
        device_ids+=("$id")
        device_statuses+=("$status")
    done <<< "$devices_output"
    
    # 过滤出可用设备（状态为device）
    local available_devices=()
    local available_statuses=()
    
    for i in "${!device_ids[@]}"; do
        if [[ "${device_statuses[$i]}" == "device" ]]; then
            available_devices+=("${device_ids[$i]}")
            available_statuses+=("${device_statuses[$i]}")
        fi
    done
    
    # 检查可用设备数量
    if [ ${#available_devices[@]} -eq 0 ]; then
        echo "${tty_red}❌ 错误：所有连接的设备都不可用。${tty_reset}"
        echo "设备状态："
        for i in "${!device_ids[@]}"; do
            echo "  - ${device_ids[$i]}: ${device_statuses[$i]}"
        done
        echo ""
        echo "请确保设备已授权并处于可用状态。"
        return 1
    fi
    
    # 如果只有一个可用设备，直接使用
    if [ ${#available_devices[@]} -eq 1 ]; then
        SELECTED_DEVICE="${available_devices[0]}"
        echo "${tty_green}已自动选择唯一可用设备: $SELECTED_DEVICE${tty_reset}"
        echo ""
        get_device_info "$SELECTED_DEVICE"
        return 0
    fi
    
    # 多个可用设备时，让用户选择
    local device_options=()
    for i in "${!available_devices[@]}"; do
        local device_id="${available_devices[$i]}"
        local device_model=$(adb -s "$device_id" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        if [ -z "$device_model" ]; then
            device_model="未知设备"
        fi
        # 截断过长的设备ID
        local short_id="$device_id"
        if [ ${#device_id} -gt 20 ]; then
            short_id="${device_id:0:17}..."
        fi
        device_options+=("$device_model ($short_id)")
    done
    
    arrow_menu "📱 设备选择菜单" "${device_options[@]}"
    local device_choice=$?
    
    if [ $device_choice -eq -1 ]; then
        return 1
    fi
    
    SELECTED_DEVICE="${available_devices[$device_choice]}"
    
    echo "${tty_green}已选择设备: $SELECTED_DEVICE${tty_reset}"
    echo ""
    get_device_info "$SELECTED_DEVICE"
    return 0
}

# --- 安装单个APK函数 ---
install_single_apk() {
    local apk_path="$1"
    local install_params="$2"
    local current_index="$3"
    local total_count="$4"
    local apk_name=$(basename "$apk_path")
    
    # 提取APK信息（如果可用）
    extract_apk_info "$apk_path" > /dev/null 2>&1
    
    echo "${tty_cyan}正在安装: $apk_name${tty_reset}"
    
    # 初始化进度条
    show_dynamic_progress 0
    
    # 直接执行安装，同时在后台更新进度条
    local progress=0
    (
        while [ $progress -lt 95 ]; do
            progress=$((progress + 2))
            show_dynamic_progress $progress
            sleep 0.1
        done
    ) &
    local progress_pid=$!
    
    # 执行实际安装
    local install_output
    if [ -n "$SELECTED_DEVICE" ]; then
        install_output=$(adb -s "$SELECTED_DEVICE" install $install_params "$apk_path" 2>&1)
    else
        install_output=$(adb install $install_params "$apk_path" 2>&1)
    fi
    local install_status=$?
    
    # 停止进度条更新
    kill $progress_pid 2>/dev/null
    wait $progress_pid 2>/dev/null
    
    # 显示100%完成
    show_dynamic_progress 100
    echo ""  # 换行
    
    if [ $install_status -eq 0 ]; then
        echo "${tty_green}安装成功: $apk_name${tty_reset}"
        return 0
    else
        local reason_output
        reason_output=$(parse_error_reason "$install_output")
        echo "${tty_red}安装失败: $apk_name${tty_reset}"
        # 分别显示原因和解决方案
        while IFS=$'\n' read -r line; do
            if [[ $line == 解决方案:* ]]; then
                echo "${tty_yellow}$line${tty_reset}"
            else
                echo "${tty_yellow}原因: $line${tty_reset}"
            fi
        done <<< "$reason_output"
        return 1
    fi
}

# --- 最终总结显示函数 ---
show_summary() {
    local success_ref_name="$1"
    local failure_ref_name="$2"
    local reasons_ref_name="$3"

    eval "local success_ref=(\"\${$success_ref_name[@]}\")"
    eval "local failure_ref=(\"\${$failure_ref_name[@]}\")"
    eval "local reasons_ref=(\"\${$reasons_ref_name[@]}\")"

    local total_count=$((${#success_ref[@]} + ${#failure_ref[@]}))

    if [ $total_count -eq 0 ]; then
        return
    fi

    echo ""
    
    echo ""
    echo -e "${tty_bold_green}本次安装结果：${tty_reset}\n${tty_bold_green}总计尝试安装：$total_count 个\n安装成功：${#success_ref[@]} 个${tty_reset}"
    if [ ${#failure_ref[@]} -gt 0 ]; then
        echo -e "${tty_red}安装失败：${#failure_ref[@]} 个${tty_reset}"
    fi
    echo ""

    if [ ${#failure_ref[@]} -gt 0 ]; then
        echo "${tty_red}失败详情:${tty_reset}"
        for i in "${!failure_ref[@]}"; do
            echo "  - ${failure_ref[$i]}"
            local parsed_reason=$(parse_error_reason "${reasons_ref[$i]}")
            echo "    ${tty_yellow}原因: $parsed_reason${tty_reset}"
        done
        echo ""
    fi

    if [ ${#failure_ref[@]} -gt 0 ]; then
        echo "${tty_yellow}详细错误日志已保存到: $LOG_FILE${tty_reset}"
    fi
    echo "${tty_cyan}────────────────────────────────────────────────────────────────────────────────${tty_reset}"
}

# --- 并行安装函数（更新为使用选定设备） ---
parallel_install_apks() {
    # 使用简单的参数传递方式，避免复杂的变量引用
    local apks_to_install=("$@")
    local install_params="${apks_to_install[0]}"
    # 移除第一个元素（安装参数）
    apks_to_install=("${apks_to_install[@]:1}")
    
    local total_count=${#apks_to_install[@]}
    local temp_success_file="$TEMP_DIR/success_installs.txt"
    local temp_failure_file="$TEMP_DIR/failure_installs.txt"
    local temp_reasons_file="$TEMP_DIR/failure_reasons.txt"
    
    # 清空临时文件
    > "$temp_success_file"
    > "$temp_failure_file"
    > "$temp_reasons_file"
    
    echo "${tty_cyan}开始安装 $total_count 个 APK 文件${tty_reset}"
    
    # 简化安装过程，不使用GNU Parallel
    local i=1
    for apk_path in "${apks_to_install[@]}"; do
        local apk_name=$(basename "$apk_path")
        echo ""
        echo "${tty_cyan}[ $i / $total_count ] 正在处理: $apk_name${tty_reset}"
        
        # 使用改进的安装函数
        if install_single_apk "$apk_path" "$install_params" "$i" "$total_count"; then
            echo "$apk_name" >> "$temp_success_file"
        else
            echo "$apk_path" >> "$temp_failure_file"
            echo "安装失败" >> "$temp_reasons_file"  # 简化的错误信息
        fi
        
            i=$((i+1))
        done
        
    # 返回结果
    return 0
}

# --- 主逻辑 ---
main() {
    check_and_install_dependencies # 首先检查并安装依赖

    while true; do # 主菜单循环
        local go_to_main_menu=false
        local should_exit_script=false
        local show_return_option=false  # 是否显示返回选项

        # --- 主菜单 ---
        local main_menu_options=(
            "💻 从桌面安装APK"
            "📥 从下载文件夹安装APK"
            "📁 自定义位置安装APK"
            "🔧 刷写系统镜像"
        )
        
        arrow_menu "${tty_bold}${tty_green}Install APK${tty_reset}" "${main_menu_options[@]}"
        local choice=$?
        
        if [ $choice -eq -1 ]; then
            continue
        fi
        
        # 将选择转换为原来的数字格式
        choice=$((choice + 1))

        local APK_DIR=""
        local custom_path=""
        local menu_title=""
        case "$choice" in
            1) 
                APK_DIR="$HOME/Desktop"
                menu_title="${tty_bold}${tty_green}💻 从桌面安装APK${tty_reset}"
                ;;
            2) 
                APK_DIR="$HOME/Downloads"
                menu_title="${tty_bold}${tty_green}📥 从下载文件夹安装APK${tty_reset}"
                ;;
            3) 
                read -p "${tty_green}请输入自定义目录路径（可直接拖入 APK 文件）；直接回车返回上一级菜单： ${tty_reset}" custom_path
                if [[ -z "$custom_path" ]]; then
                    continue
                fi
                # 清理用户可能拖拽进来的路径（去除引号和多余空格）
                custom_path=$(echo "$custom_path" | sed "s/'//g" | xargs)
                menu_title="📁 自定义位置安装APK"
                ;;
            4)
                 echo ""
                 echo "${tty_cyan}设备即将重启进入 Bootloader 模式...${tty_reset}"
                 echo "${tty_yellow}请确保手机已正确连接电脑。${tty_reset}"
                 echo ""
                 # 检查设备连接
                 if ! adb get-state 1>/dev/null 2>&1 && ! fastboot devices 2>&1 | grep -q "fastboot"; then
                     echo -e "${tty_red}⚠️  错误: 未检测到任何设备。请连接您的设备并启用 USB 调试或进入 Bootloader 模式后重试。${tty_reset}"
                     echo "${tty_green}将在 3 秒后自动返回主菜单...${tty_reset}"
                     sleep 3
                     continue
                 fi

                 # 判断设备模式
                 local wait_for_bootloader=false
                 if adb get-state 1>/dev/null 2>&1; then
                     echo "${tty_cyan}检测到设备处于 ADB 模式，正在重启到 Bootloader...${tty_reset}"
                     adb reboot bootloader
                     echo "${tty_yellow}请等待设备重启...${tty_reset}"
                     sleep 5 # 等待设备重启
                     wait_for_bootloader=true
                 elif fastboot devices 2>&1 | grep -q "fastboot"; then
                     echo "${tty_green}✅ 设备已处于 Bootloader 模式。${tty_reset}"
                 fi

                 if [ "$wait_for_bootloader" = true ]; then
                    : # Do nothing and continue to the menu
                 fi
                    echo ""
                while true; do
                    local flash_menu_options=(
                        "💻 桌面"
                        "📥 下载"
                        "返回上一级"
                    )
                    
                    arrow_menu "🔧 刷写系统镜像" "${flash_menu_options[@]}"
                    local flash_choice=$?
                    
                    if [ $flash_choice -eq -1 ] || [ $flash_choice -eq 2 ]; then
                        break
                    fi

                    local target_dir=""
                    if [[ "$flash_choice" == "0" ]]; then
                        target_dir="$HOME/Desktop"
                    elif [[ "$flash_choice" == "1" ]]; then
                        target_dir="$HOME/Downloads"
                    fi

                    if [ -n "$target_dir" ]; then
                        echo ""
                        echo "${tty_cyan}正在扫描 '$target_dir' 中的文件夹...${tty_reset}"
                        
                        # 查找所有名为 "download_images" 的文件夹
                        local dirs=()
                        while IFS= read -r -d $'\0'; do
                            dirs+=("$REPLY")
                        done < <(find "$target_dir" -type d -name "download_images" -print0 | sort -z)

                        if [ ${#dirs[@]} -eq 0 ]; then
                            echo "${tty_yellow}在 '$target_dir' 中未找到任何名为 \"download_images\" 的文件夹。${tty_reset}"
                            echo "${tty_green}将在 3 秒后自动返回主菜单...${tty_reset}"
                            sleep 3
                            continue
                        else
                            local exit_flash_menu=false
                            while true; do
                                local folder_options=()
                                for i in "${!dirs[@]}"; do
                                    local dir_path="${dirs[$i]}"
                                    local parent_dir_name=$(basename "$(dirname "$dir_path")")
                                    folder_options+=("📁 $parent_dir_name")
                                done
                                folder_options+=("返回上一级")
                                
                                arrow_menu "📁 系统镜像文件夹选择" "${folder_options[@]}"
                                local choice=$?
                                
                                if [ $choice -eq -1 ] || [ $choice -eq $((${#folder_options[@]} - 1)) ]; then
                                    break
                                fi

                                if [[ "$choice" -ge 0 ]] && [ "$choice" -lt "${#dirs[@]}" ]; then
                                    selected_dir="${dirs[$choice]}"
                                    clear
                                    echo ""
                                    echo "${tty_green}在新终端窗口中打开文件夹并执行刷机脚本...${tty_reset}"
                                    # Get current terminal window ID before opening new one
                                    current_window_id=$(osascript -e "tell application \"Terminal\" to return id of front window" 2>/dev/null)
                                    # Open new terminal window with flashing script
                                    osascript -e "tell application \"Terminal\" to do script \"cd '$selected_dir' && python3 fastboot-flash.py\"" > /dev/null
                                    # Close the original terminal window (not the new one) without confirmation
                                    if [ -n "$current_window_id" ]; then
                                        osascript -e "tell application \"Terminal\" to close window id $current_window_id saving no" > /dev/null 2>&1
                                    fi
                                    echo ""
                                    exit_flash_menu=true
                                    break
                                fi
                            done
                            if ${exit_flash_menu}; then
                                break
                            fi
                        fi
                    fi
                done
                continue
                 ;;

            *)
                echo "${tty_red}无效的选项。${tty_reset}"
                echo "${tty_green}将在 3 秒后自动返回主菜单...${tty_reset}"
                sleep 3
                continue
                ;;
        esac
        
        local all_apks=()
        # --- 查找 APK 文件 ---
        if [[ "$choice" == "3" ]]; then
            if [ -d "$custom_path" ]; then
                APK_DIR="$custom_path"
                echo "将在 '$APK_DIR' 文件夹中搜索 APK 文件..."
                while IFS= read -r -d $'\0'; do
                    all_apks+=("$REPLY")
                done < <(find "$APK_DIR" -maxdepth 1 -iname "*.apk" -print0 | sort -z)
            elif [ -f "$custom_path" ]; then
                if [[ "$custom_path" == *.apk ]]; then
                    echo "检测到单个APK文件。"
                    all_apks+=("$custom_path")
                else
                    echo "${tty_red}❌ 错误：提供的文件不是一个有效的 .apk 文件。${tty_reset}"
                    read -p "${tty_bold_green}直接回车可返回一级菜单：${tty_reset}"
                    continue
                fi
            else
                echo "${tty_red}❌ 错误：路径 '$custom_path' 不存在或无效。${tty_reset}"
                read -p "${tty_bold_green}安装已完成,直接回车可返回上一级菜单：${tty_reset}"
                continue
            fi
        else
            echo "将在 '$APK_DIR' 文件夹中搜索 APK 文件..."
            while IFS= read -r -d $'\0'; do
                all_apks+=("$REPLY")
            done < <(find "$APK_DIR" -maxdepth 1 -iname "*.apk" -print0 | sort -z)
        fi
        echo ""

        # --- 检查 ADB 和设备 ---
        # 此处的 adb 命令检查可以保留，作为一个双重保障
        if ! command -v adb &> /dev/null; then
            echo "${tty_red}❌ 严重错误：ADB 命令在依赖安装后仍然不可用。${tty_reset}"
            echo "请尝试手动执行 'brew install --cask android-platform-tools' 并重启终端。"
            read -p "${tty_bold_green}按回车键退出...${tty_reset}"
            exit 1
        fi

        # 选择设备
        if ! select_device; then
            echo "${tty_green}将在 3 秒后自动返回主菜单...${tty_reset}"
            sleep 3
            continue
        fi

        if [ ${#all_apks[@]} -eq 0 ]; then
            if [ -d "$APK_DIR" ]; then
                echo ""
                echo "${tty_yellow}⚠️  未在 '$APK_DIR' 中找到任何 .apk 文件。${tty_reset}"
            fi
            echo "${tty_green}将在 3 秒后自动返回主菜单...${tty_reset}"
            sleep 3
            continue
        fi

        echo "${tty_green}共检测到 ${#all_apks[@]} 个 APK 文件。${tty_reset}"
        
        # --- APK 选择 ---
        local apks_to_install=()
        if [ ${#all_apks[@]} -eq 1 ]; then
            apks_to_install=("${all_apks[@]}")
        elif [ ${#all_apks[@]} -gt 1 ]; then
            while true; do
                local apk_options=("安装全部应用")
                for apk_path in "${all_apks[@]}"; do
                    local apk_name
                    apk_name=$(basename "$apk_path")
                    # 截断过长的文件名，保持与分隔线长度一致(80字符)
                    if [ ${#apk_name} -gt 80 ]; then
                        # 截断并保持.apk后缀
                        if [[ $apk_name == *.apk ]]; then
                            apk_name="${apk_name:0:76}...apk"
                        else
                            apk_name="${apk_name:0:77}..."
                        fi
                    fi
                    apk_options+=("$apk_name")
                done
                apk_options+=("返回上一级")
                
                arrow_menu "$menu_title" "${apk_options[@]}"
                local apk_choice=$?
                
                apks_to_install=() # Reset choices
                if [ $apk_choice -eq -1 ] || [ $apk_choice -eq $((${#apk_options[@]} - 1)) ]; then
                    break # Exit selection loop, will then hit the continue below
                fi
                
                if [[ "$apk_choice" == "0" ]]; then
                    apks_to_install=("${all_apks[@]}")
                else
                    # 单选模式 - 选择单个APK
                    apks_to_install=("${all_apks[$((apk_choice-1))]}")
                fi

                if [ ${#apks_to_install[@]} -gt 0 ]; then
                    break # Valid APKs selected, exit loop.
                fi
            done
        fi

        # 如果没有选择任何有效的APK，则返回主菜单
        if [ ${#apks_to_install[@]} -eq 0 ]; then
             continue
        fi
        
        echo ""
        if [ ${#apks_to_install[@]} -eq 1 ]; then
            local apk_name=$(basename "${apks_to_install[0]}")
            echo "${tty_green}已选择安装: $apk_name${tty_reset}"
        else
            echo "${tty_green}已选择 ${#apks_to_install[@]} 个APK文件进行安装。${tty_reset}"
        fi

        # --- 安装选项 ---
        # 使用最佳安装参数，不再询问用户
        local install_params="-t -r -d -g"

        # --- 安装循环 ---
        local successful_installs=()
        local failed_installs_paths=("${apks_to_install[@]}") 
        local failed_install_reasons=()
        
        while [ ${#failed_installs_paths[@]} -gt 0 ] && ! $go_to_main_menu && ! $should_exit_script; do
            local apks_to_try=("${failed_installs_paths[@]}")
            failed_installs_paths=()
            failed_install_reasons=()
            
            local total_to_try=${#apks_to_try[@]}
            
            # 简化并行安装逻辑
            echo "${tty_yellow}💡 开始批量安装 $total_to_try 个APK文件...${tty_reset}"
                echo ""
            
            # 调用安装函数
            parallel_install_apks "$install_params" "${apks_to_try[@]}"
            
            # 读取安装结果
            successful_installs=()
            failed_installs_paths=()
            failed_install_reasons=()
            
            # 读取成功安装的应用
            if [ -f "$TEMP_DIR/success_installs.txt" ]; then
                while IFS= read -r line; do
                    successful_installs+=("$line")
                done < "$TEMP_DIR/success_installs.txt"
            fi
            
            # 读取失败的应用
            if [ -f "$TEMP_DIR/failure_installs.txt" ]; then
                while IFS= read -r line; do
                    failed_installs_paths+=("$line")
                done < "$TEMP_DIR/failure_installs.txt"
            fi
            
            # 读取失败原因
            if [ -f "$TEMP_DIR/failure_reasons.txt" ]; then
                while IFS= read -r line; do
                    failed_install_reasons+=("$line")
                done < "$TEMP_DIR/failure_reasons.txt"
            fi
            
            # 清理临时文件
            rm -f "$TEMP_DIR/success_installs.txt" "$TEMP_DIR/failure_installs.txt" "$TEMP_DIR/failure_reasons.txt"

            if [ ${#failed_installs_paths[@]} -gt 0 ] && ! $go_to_main_menu; then
                while true; do
                    # 先显示统计信息
                    clear
                    echo ""
                    echo "${tty_bold_green}本次安装结果：${tty_reset}"
                    printf "${tty_bold_green}总计尝试安装：%d 个${tty_reset}\n" "${total_to_try}"
                    printf "${tty_bold_green}安装成功：%d 个${tty_reset}\n" "${#successful_installs[@]}"
                    if [ ${#failed_installs_paths[@]} -gt 0 ]; then
                        printf "${tty_red}安装失败：%d 个${tty_reset}\n" "${#failed_installs_paths[@]}"
                    fi
                    echo ""
                    local result_options=("重试失败的安装" "返回主菜单")
                    arrow_menu "继续操作" "${result_options[@]}"
                    local choice=$?
                    
                    case "$choice" in
                        0) 
                            echo "${tty_cyan}1秒后重试...${tty_reset}"
                            sleep 1
                            break # Break prompt loop to retry
                            ;;
                        *)
                            go_to_main_menu=true
                            break # Break prompt loop
                            ;;
                    esac
                done
            fi
        done

        # --- 总结与收尾 ---
        if $go_to_main_menu; then
            continue
        fi
        
        if ! $go_to_main_menu; then
            local final_failed_names=()
            for path in "${failed_installs_paths[@]}"; do
                final_failed_names+=("$(basename "$path")")
            done
            show_summary successful_installs final_failed_names failed_install_reasons
        fi
        
        if $should_exit_script; then
            break # Exit main loop
        fi

        read -p "${tty_bold_green}直接回车键返回主菜单：${tty_reset}"
    done
}

# --- 运行主函数并确保窗口不会立即关闭 ---
main

# 清理临时文件
rm -rf "$TEMP_DIR"

echo ""
echo "感谢使用！脚本执行完毕。"
read -p "${tty_bold_green}按回车键退出终端...${tty_reset}"

exit 0
