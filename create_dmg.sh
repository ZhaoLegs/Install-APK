#!/bin/bash

# 创建 DMG 打包脚本
# App: Install APK V1.6.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=====================================${NC}"
echo -e "${CYAN}    Install APK V1.6.0 DMG 打包工具${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

# 设置变量
APP_NAME="Install APK"
APP_VERSION="1.6"
DMG_NAME="Install_APK_v${APP_VERSION}"
SOURCE_APP="Install APK.app"
BUILD_DIR="build_dmg"
DMG_DIR="${BUILD_DIR}/dmg_root"

# 检查应用是否存在
if [ ! -d "$SOURCE_APP" ]; then
    echo -e "${RED}❌ 错误: 未找到应用程序 '$SOURCE_APP'${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 准备打包环境...${NC}"

# 清理并创建构建目录
rm -rf "$BUILD_DIR"
mkdir -p "$DMG_DIR"

echo -e "${YELLOW}📋 复制应用程序...${NC}"

# 复制应用程序到DMG目录
cp -R "$SOURCE_APP" "$DMG_DIR/"

# 创建应用程序快捷方式到Applications
ln -sf /Applications "$DMG_DIR/Applications"

# 创建DS_Store文件以设置DMG外观
echo -e "${YELLOW}🎨 配置DMG外观...${NC}"

# 创建临时的AppleScript来设置DMG样式
cat > "${BUILD_DIR}/dmg_style.applescript" << 'EOF'
tell application "Finder"
    delay 3
    set dmgName to ""
    
    -- 尝试找到正确的DMG卷
    set dmgList to {"Install APK", "Install", "Install APK 1", "Install APK 2"}
    repeat with dmgVol in dmgList
        try
            if exists disk dmgVol then
                set dmgName to dmgVol
                exit repeat
            end if
        end try
    end repeat
    
    if dmgName is not "" then
        try
            tell disk dmgName
                open
                delay 2
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                -- 设置窗口大小为 600x400 像素
                set the bounds of container window to {360, 160, 960, 560}
                
                set viewOptions to the icon view options of container window
                set arrangement of viewOptions to not arranged
                set icon size of viewOptions to 80
                set text size of viewOptions to 13
                set shows item info of viewOptions to false
                set shows icon preview of viewOptions to true
                
                delay 3
                
                -- 设置图标位置：左侧Install APK，右侧Applications
                -- 窗口宽度600px：左侧 x=125, 右侧 x=425, 垂直居中 y=160
                set position of item "Install APK.app" of container window to {125, 160}
                set position of item "Applications" of container window to {425, 160}
                
                -- 设置标签颜色
                set label index of item "Install APK.app" of container window to 0
                set label index of item "Applications" of container window to 0
                
                delay 2
                
                -- 关闭并重新打开以保存设置
                close
                delay 1
                open
                delay 2
                
                -- 确保位置被正确设置
                set position of item "Install APK.app" of container window to {125, 160}
                set position of item "Applications" of container window to {425, 160}
                
                delay 1
                close
            end tell
        on error errMsg
            -- 忽略错误，继续执行
        end try
    end if
end tell
EOF

echo -e "${YELLOW}🖼️ 设置背景图片...${NC}"

# 使用系统默认样式，不设置背景图片
echo -e "${BLUE}📁 使用系统默认DMG样式${NC}"

echo -e "${YELLOW}💿 创建DMG文件...${NC}"

# 创建临时DMG
TEMP_DMG="${BUILD_DIR}/${DMG_NAME}_temp.dmg"
FINAL_DMG="${DMG_NAME}.dmg"

# 计算DMG大小 (应用大小 + 50MB 缓冲)
APP_SIZE=$(du -sm "$SOURCE_APP" | cut -f1)
DMG_SIZE=$((APP_SIZE + 50))

echo -e "${BLUE}应用大小: ${APP_SIZE}MB, DMG大小: ${DMG_SIZE}MB${NC}"

# 创建DMG
hdiutil create -srcfolder "$DMG_DIR" -volname "Install APK" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DMG_SIZE}M "$TEMP_DMG"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 创建临时DMG失败${NC}"
    exit 1
fi

echo -e "${YELLOW}🎨 设置DMG外观...${NC}"

# 优先确保没有已挂载的Install APK卷
for vol in "/Volumes/Install APK"*; do
    if [ -d "$vol" ]; then
        echo -e "${BLUE}📁 正在卸载已存在的卷: $vol${NC}"
        hdiutil detach "$vol" 2>/dev/null || true
    fi
done

# 等待一下再挂载
sleep 1

# 挂载临时DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | grep -E '^/dev/' | sed 1q | awk '{print $1}')

if [ -z "$DEVICE" ]; then
    echo -e "${RED}❌ 挂载DMG失败${NC}"
    exit 1
fi

echo -e "${BLUE}DMG已挂载到: $DEVICE${NC}"

# 等待挂载完成
sleep 3

# 查找实际的挂载点
MOUNT_POINT=$(df | grep "$DEVICE" | awk '{print $NF}')
echo -e "${BLUE}实际挂载点: $MOUNT_POINT${NC}"

# 应用样式脚本
if [ -f "${BUILD_DIR}/dmg_style.applescript" ]; then
    echo -e "${YELLOW}🎨 正在应用DMG样式...${NC}"
    osascript "${BUILD_DIR}/dmg_style.applescript" 2>&1 || echo -e "${YELLOW}⚠️  样式应用可能不完整${NC}"
    
    # 等待一下让系统保存DS_Store文件
    sleep 3
fi

# 设置权限
if [ -n "$MOUNT_POINT" ]; then
    chmod -Rf go-w "$MOUNT_POINT" 2>/dev/null
fi

# 同步并卸载
sync
hdiutil detach "$DEVICE"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 卸载DMG失败${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 压缩DMG文件...${NC}"

# 转换为只读压缩DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 压缩DMG失败${NC}"
    exit 1
fi

# 清理临时文件
rm -rf "$BUILD_DIR"

# 获取最终文件信息
FINAL_SIZE=$(du -h "$FINAL_DMG" | cut -f1)

echo ""
echo -e "${GREEN}✅ DMG打包完成！${NC}"
echo -e "${GREEN}📁 文件名: ${FINAL_DMG}${NC}"
echo -e "${GREEN}📏 文件大小: ${FINAL_SIZE}${NC}"
echo -e "${GREEN}📍 位置: $(pwd)/${FINAL_DMG}${NC}"
echo ""
echo -e "${CYAN}🚀 现在你可以分发这个DMG文件了！${NC}"
echo -e "${YELLOW}💡 用户只需双击DMG文件，然后拖拽应用到Applications文件夹即可安装。${NC}"
echo ""