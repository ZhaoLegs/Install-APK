#!/bin/bash

# 此脚本用于安装当前目录下的所有APK文件。
#
# 使用方法：
# 1. 将此脚本与需要安装的APK文件放置在同一目录下。
# 2. 打开终端，进入此目录。
# 3. 授予脚本执行权限：chmod +x install_apks.command
# 4. 运行脚本：./install_apks.command
#
# 脚本会自动查找并安装目录中所有的.apk文件。

# This script is designed to be run by double-clicking on macOS.
# It keeps the terminal window open until the user presses Enter.

# --- Function to display a final summary ---
show_summary() {
    # Use namerefs to get the arrays passed by reference
    local -n success_ref=$1
    local -n failure_ref=$2
    local -n reasons_ref=$3

    echo ""
    echo "========================================"
    echo "          安装最终总结"
    echo "========================================"

    if [ ${#success_ref[@]} -gt 0 ]; then
        echo "✅ 安装成功列表:"
        for item in "${success_ref[@]}"; do
            echo "  - $item"
        done
    else
        echo "✅ 没有应用安装成功。"
    fi

    echo "" # Add a blank line for spacing

    if [ ${#failure_ref[@]} -gt 0 ]; then
        echo "❌ 安装失败列表:"
        for i in "${!failure_ref[@]}"; do
            echo "  - ${failure_ref[$i]}"
            echo "    原因: ${reasons_ref[$i]}"
        done
    else
        echo "🎉 太棒了！所有应用都已成功安装。"
    fi
    echo "========================================"
}

# --- Main Logic ---
main() {
    # --- Choose Directory ---
    echo "请选择要从哪个文件夹安装 APK 文件："
    echo "1. 桌面 ($HOME/Desktop)"
    echo "2. 下载文件夹 ($HOME/Downloads)"
    read -p "请输入选项 ( 1 或 2 ) 后请回车继续: " choice

    local APK_DIR=""
    case "$choice" in
        1)
            APK_DIR="$HOME/Desktop"
            ;;
        2)
            APK_DIR="$HOME/Downloads"
            ;;
        *)
            echo "无效的选项。退出脚本。"
            read
            exit 1
            ;;
    esac
    echo "将在 '$APK_DIR' 文件夹中搜索 APK 文件..."
    echo ""

    # Check if adb is available first
    if ! command -v adb &> /dev/null; then
        echo "错误：找不到 adb 命令。"
        echo "请确保 Android SDK Platform-Tools 已安装并配置在系统路径中。"
        read
        exit 1
    fi

    local all_apks=()
    # Use find to correctly handle filenames with spaces
    while IFS= read -r -d $'\0'; do
        all_apks+=("$REPLY")
    done < <(find "$APK_DIR" -maxdepth 1 -iname "*.apk" -print0)

    if [ ${#all_apks[@]} -eq 0 ]; then
        echo "在 '$APK_DIR' 文件夹中未找到任何 .apk 文件。"
        read
        exit 1
    fi

    local successful_installs=()
    # Start with all APKs in the 'failed' list. We'll move them out as they succeed.
    local failed_installs_paths=("${all_apks[@]}") 
    local failed_install_reasons=()
    
    # Loop as long as there are failed items and the user wants to retry
    while [ ${#failed_installs_paths[@]} -gt 0 ]; do
        local current_round_failures=()
        local apks_to_try=("${failed_installs_paths[@]}")
        failed_installs_paths=() # Clear the list for this round's attempts
        failed_install_reasons=() # Clear reasons for this round

        for apk_path in "${apks_to_try[@]}"; do
            local apk_name
            apk_name=$(basename "$apk_path")
            echo ""
            echo "--- 正在安装: $apk_name ---"
            
            # Execute the adb install command and capture all output
            install_output=$(adb install -t -r -d "$apk_path" 2>&1)
            
            if [ $? -eq 0 ]; then
                echo "✅ 安装成功: $apk_name"
                successful_installs+=("$apk_name")
            else
                echo "❌ 安装失败: $apk_name"
                echo "    原因: $install_output"
                # If it fails, add its full path back to the list for the next potential retry
                failed_installs_paths+=("$apk_path")
                failed_install_reasons+=("$install_output")
                current_round_failures+=("$apk_name")
            fi
        done

        # After a full round, if there are still failures, ask the user to retry
        if [ ${#failed_installs_paths[@]} -gt 0 ]; then
            local should_break_main_loop=false
            while true; do # Prompt loop
                echo ""
                echo "----------------------------------------"
                echo "本轮有 ${#failed_installs_paths[@]} 个应用安装失败。"
                echo "----------------------------------------"
                
                read -p "输入 1 重试, 输入 2 可输入自定义命令行, 如已安装完毕可直接关闭退出终端; " choice
                if [[ "$choice" == "1" ]]; then
                    # Break prompt loop and continue main loop to retry.
                    break
                elif [[ "$choice" == "2" ]]; then
                    # Enter custom command mode.
                    while true; do
                        read -p "请输入自定义命令 (或输入 '0' 回车返回上层): " custom_command
                        if [[ "$custom_command" == "0" ]]; then
                            break # Break custom command loop to return to prompt loop.
                        fi
                        echo "--- 执行自定义命令 ---"
                        # Execute the command and show output
                        eval "$custom_command"
                        echo "--- 命令执行完毕 ---"
                        echo ""
                    done
                    # After custom command loop, continue prompt loop to show prompt again.
                    continue
                else
                    # Exit everything.
                    echo "好的，将不再重试。"
                    should_break_main_loop=true
                    break # Break prompt loop.
                fi
            done
            
            if $should_break_main_loop; then
                break # Break main loop.
            fi
        fi
    done

    # --- Final Summary ---
    local final_failed_names=()
    for path in "${failed_installs_paths[@]}"; do
        final_failed_names+=("$(basename "$path")")
    done
    
    show_summary successful_installs final_failed_names failed_install_reasons

    echo ""
    read
}

# --- Run the main function ---
main

exit 0