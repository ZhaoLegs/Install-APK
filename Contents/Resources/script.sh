#!/bin/bash

# 作者：legs
# 版本：v1.4 (2024.07)
# 功能：批量安装 APK，支持自定义目录、失败重试、错误原因解析与日志记录
#
# 此脚本旨在提供一个用户友好的界面，用于从指定文件夹批量安装APK文件。
# 它包含了对常见安装错误的解析、安装进度提示以及日志记录功能。

# --- 全局变量和初始化 ---
LOG_DIR="$HOME/Desktop/apk_install_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date '+%Y-%m-%d_%H-%M-%S').log"

# --- 日志记录函数 ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# --- 增强的错误原因解析函数 ---
parse_error_reason() {
    local reason_raw="$1"
    local reason_simplified="未知错误"

    if [[ $reason_raw == *"INSTALL_FAILED_VERSION_DOWNGRADE"* ]]; then
        reason_simplified="版本降级：设备上的应用版本比安装的要新。"
    elif [[ $reason_raw == *"INSTALL_FAILED_ALREADY_EXISTS"* ]]; then
        reason_simplified="应用已存在：但签名或版本不匹配。"
    elif [[ $reason_raw == *"INSTALL_FAILED_INSUFFICIENT_STORAGE"* ]]; then
        reason_simplified="存储空间不足：请清理设备存储空间。"
    elif [[ $reason_raw == *"INSTALL_FAILED_USER_RESTRICTED"* ]]; then
        reason_simplified="用户限制：安装被设备系统或用户设置阻止。"
    elif [[ $reason_raw == *"INSTALL_PARSE_FAILED_NO_CERTIFICATES"* ]]; then
        reason_simplified="签名无效：APK文件没有签名或签名无效。"
    elif [[ $reason_raw == *"INSTALL_FAILED_MISSING_SHARED_LIBRARY"* ]]; then
        reason_simplified="缺少共享库：设备缺少应用运行所需的库文件。"
    elif [[ $reason_raw == *"INSTALL_FAILED_UPDATE_INCOMPATIBLE"* ]]; then
        reason_simplified="签名不兼容：已安装版本的签名与新版本不匹配。"
    elif [[ $reason_raw == *"INSTALL_FAILED_INVALID_APK"* ]]; then
        reason_simplified="无效的APK文件：文件可能已损坏或格式不正确。"
    elif [[ $reason_raw == *"DELETE_FAILED_INTERNAL_ERROR"* ]]; then
        reason_simplified="系统内部错误：卸载旧版本时出错。"
    else
        # 提取关键信息
        reason_simplified=$(echo "$reason_raw" | grep -o 'Failure \[.*\]' | sed 's/Failure \[//;s/\]//')
        if [[ -z "$reason_simplified" ]]; then
            reason_simplified="未能从ADB输出中提取明确原因。"
        fi
    fi
    echo "$reason_simplified"
    log "原始错误: $reason_raw"
    log "解析后原因: $reason_simplified"
}


# --- 最终总结显示函数 ---
show_summary() {
    local -n success_ref=$1
    local -n failure_ref=$2
    local -n reasons_ref=$3

    echo ""
    echo "========================================"
    echo "          安装最终总结"
    echo "========================================"

    local total_count=$((${#success_ref[@]} + ${#failure_ref[@]}))
    
    if [ $total_count -eq 0 ]; then
        echo "⚠️  没有进行任何安装操作"
        echo "========================================"
        return
    fi

    echo "📊 总共尝试安装: $total_count 个应用"
    echo ""

    if [ ${#success_ref[@]} -gt 0 ]; then
        echo "✅ 安装成功 (${#success_ref[@]} 个):"
        for item in "${success_ref[@]}"; do
            echo "  - $item"
        done
    fi

    if [ ${#failure_ref[@]} -gt 0 ]; then
        if [ ${#success_ref[@]} -gt 0 ]; then
            echo ""
        fi
        echo "❌ 安装失败 (${#failure_ref[@]} 个):"
        for i in "${!failure_ref[@]}"; do
            echo "  - ${failure_ref[$i]}"
            local parsed_reason=$(parse_error_reason "${reasons_ref[$i]}")
            echo "    原因: $parsed_reason"
        done
    fi

    echo ""
    echo "🎉 安装流程完成！"
    echo ""
    echo "✅ 成功: ${#success_ref[@]} 个"
    echo "❌ 失败: ${#failure_ref[@]} 个"
    echo ""
    if [ ${#failure_ref[@]} -gt 0 ]; then
        echo "详细错误日志已保存到: $LOG_FILE"
    fi
    echo "========================================"
}

# --- 主逻辑 ---
main() {
    while true; do # 主菜单循环
        local go_to_main_menu=false
        local should_exit_script=false

        # --- 目录选择 ---
        echo "请选择要从哪个文件夹安装 APK 文件："
        echo "1. 桌面 ($HOME/Desktop)"
        echo "2. 下载文件夹 ($HOME/Downloads)"
        echo "3. 自定义目录"
        read -p "请输入选项 (1, 2, 或 3)，然后回车: " choice

        local APK_DIR=""
        local custom_path=""
        case "$choice" in
            1) APK_DIR="$HOME/Desktop" ;;
            2) APK_DIR="$HOME/Downloads" ;;
            3) 
                read -p "请输入自定义目录的完整路径 (可将文件夹或APK文件拖拽到此窗口): " custom_path
                # 清理用户可能拖拽进来的路径（去除引号和多余空格）
                custom_path=$(echo "$custom_path" | sed "s/'//g" | xargs)
                ;;
            *)
                echo "无效的选项。退出脚本。"
                read -p "按回车键退出..."
                exit 1
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
                done < <(find "$APK_DIR" -maxdepth 1 -iname "*.apk" -print0)
            elif [ -f "$custom_path" ]; then
                if [[ "$custom_path" == *.apk ]]; then
                    echo "检测到单个APK文件。"
                    all_apks+=("$custom_path")
                else
                    echo "❌ 错误：提供的文件不是一个有效的 .apk 文件。"
                    read -p "按回车键返回主菜单..."
                    continue
                fi
            else
                echo "❌ 错误：路径 '$custom_path' 不存在或无效。"
                read -p "按回车键返回主菜单..."
                continue
            fi
        else
            APK_DIR="$choice" # This will be Desktop or Downloads path
            echo "将在 '$APK_DIR' 文件夹中搜索 APK 文件..."
            while IFS= read -r -d $'\0'; do
                all_apks+=("$REPLY")
            done < <(find "$APK_DIR" -maxdepth 1 -iname "*.apk" -print0)
        fi
        echo ""

        # --- 检查 ADB 和设备 ---
        if ! command -v adb &> /dev/null; then
            echo "❌ 错误：找不到 adb 命令。"
            echo "请确保 Android SDK Platform-Tools 已安装并配置在系统路径中。"
            read -p "按回车键退出..."
            exit 1
        fi

        echo "正在检查连接的设备..."
        local devices_output
        devices_output=$(adb devices | grep -v "List of devices attached" | grep -v "^$")
        if [ -z "$devices_output" ]; then
            echo ""
            echo "❌ 错误：未检测到任何Android设备。"
            echo "请确保："
            echo "  1. Android设备已通过USB连接到电脑"
            echo "  2. 设备已开启USB调试模式"
            echo "  3. 已在设备上授权此计算机进行调试"
            echo ""
            read -p "输入 0 回到主菜单, 或按回车键退出... " no_device_choice
            if [[ "$no_device_choice" == "0" ]]; then
                continue
            else
                exit 1
            fi
        fi
        echo "🔌 已连接设备列表："
        echo "$devices_output"
        echo ""

        if [ ${#all_apks[@]} -eq 0 ]; then
            if [ -d "$APK_DIR" ]; then
                echo "⚠️  未在 '$APK_DIR' 中找到任何 .apk 文件。"
            fi
            read -p "按回车键返回主菜单..."
            continue
        fi

        echo "找到 ${#all_apks[@]} 个APK文件。"
        
        # --- 安装选项 ---
        local install_params="-t -r"
        read -p "是否允许版本降级安装 (覆盖已有的新版本)？(y/n，默认为n): " allow_downgrade
        if [[ "$allow_downgrade" == "y" || "$allow_downgrade" == "Y" ]]; then
            install_params+=" -d"
            echo "ℹ️  已启用版本降级安装。"
        else
            echo "ℹ️  未启用版本降级安装。"
        fi
        echo ""


        # --- 安装循环 ---
        local successful_installs=()
        local failed_installs_paths=("${all_apks[@]}") 
        local failed_install_reasons=()
        
        while [ ${#failed_installs_paths[@]} -gt 0 ] && ! $go_to_main_menu && ! $should_exit_script; do
            local apks_to_try=("${failed_installs_paths[@]}")
            failed_installs_paths=()
            failed_install_reasons=()
            
            local total_to_try=${#apks_to_try[@]}
            local i=0

            for apk_path in "${apks_to_try[@]}"; do
                i=$((i+1))
                local apk_name
                apk_name=$(basename "$apk_path")
                echo ""
                echo "--- [ $i / $total_to_try ] 正在安装: $apk_name ---"
                
                local install_output
                install_output=$(adb install $install_params "$apk_path" 2>&1)
                
                if [ $? -eq 0 ]; then
                    echo "✅ 安装成功: $apk_name"
                    successful_installs+=("$apk_name")
                    log "成功: $apk_name"
                else
                    local reason
                    reason=$(parse_error_reason "$install_output")
                    echo "❌ 安装失败: $apk_name"
                    echo "   原因: $reason"
                    failed_installs_paths+=("$apk_path")
                    failed_install_reasons+=("$install_output") # Store original output for detailed summary
                    log "失败: $apk_name"
                fi
            done

            if [ ${#failed_installs_paths[@]} -gt 0 ] && ! $go_to_main_menu; then
                while true; do
                    echo ""
                    echo "----------------------------------------"
                    echo "本轮有 ${#failed_installs_paths[@]} 个应用安装失败。"
                    echo "----------------------------------------"
                    
                    read -p "输入 1 重试, 输入 2 进入自定义命令模式, 或按其他任意键退出: " choice
                    case "$choice" in
                        1) 
                            echo "1秒后重试..."
                            sleep 1
                            break # Break prompt loop to retry
                            ;;
                        2)
                            while true; do
                                read -p "请输入自定义命令 (输入 'exit' 返回): " cmd
                                if [[ "$cmd" == "exit" ]]; then
                                    break
                                fi
                                echo "--- 执行: $cmd ---"
                                # Use timeout to prevent hanging, requires coreutils (brew install coreutils)
                                # For now, we execute directly. Add a warning.
                                echo "警告：长时间运行的命令会卡住脚本。按 Ctrl+C 可强制中止。"
                                eval "$cmd"
                                echo "--- 执行完毕 ---"
                            done
                            continue # Continue prompt loop
                            ;;
                        *)
                            echo "好的，将不再重试。"
                            should_exit_script=true
                            break # Break prompt loop
                            ;;
                    esac
                done
            fi
        done

        # --- 总结与收尾 ---
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

        read -p "是否返回主菜单以选择其他文件夹？(y/n，默认为n): " continue_choice
        if [[ "$continue_choice" != "y" && "$continue_choice" != "Y" ]]; then
            break
        fi
    done
}

# --- 运行主函数并确保窗口不会立即关闭 ---
main

echo ""
echo "感谢使用！脚本执行完毕。"
read -p "按回车键退出终端..."

exit 0
