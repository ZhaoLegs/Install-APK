#!/usr/bin/env python3
"""
创建自定义 DMG 背景图片的示例脚本
你可以修改这个脚本来创建你想要的背景样式
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import sys

def create_custom_background(output_path):
    # DMG 标准尺寸
    width, height = 520, 320
    
    # 创建基础图片 (浅色主题，便于文字显示)
    image = Image.new('RGB', (width, height), color='#f5f7fa')
    draw = ImageDraw.Draw(image)
    
    # 绘制渐变背景 (浅色主题)
    for i in range(height):
        # 从浅灰到浅蓝的渐变
        r = int(245 + (230-245) * i / height)  # f5 -> e6
        g = int(247 + (240-247) * i / height)  # f7 -> f0  
        b = int(250 + (255-250) * i / height)  # fa -> ff
        draw.line([(0, i), (width, i)], fill=(r, g, b))
    
    # 添加一些装饰元素 - 圆形光点 (适配浅色背景)
    for i in range(6):
        x = 60 + i * 70
        y = 40 + (i % 2) * 25
        # 创建半透明的装饰点
        circle_size = 15
        overlay = Image.new('RGBA', (width, height), (255, 255, 255, 0))
        circle_draw = ImageDraw.Draw(overlay)
        circle_draw.ellipse([x-circle_size, y-circle_size, x+circle_size, y+circle_size], 
                           fill=(52, 152, 219, 25))  # 蓝色半透明，适合浅色背景
        image = Image.alpha_composite(image.convert('RGBA'), overlay).convert('RGB')
    
    # 重新获取绘制对象
    draw = ImageDraw.Draw(image)
    
    # 设置字体
    try:
        font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
        font_medium = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
        font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
    except:
        font_large = ImageFont.load_default()
        font_medium = ImageFont.load_default() 
        font_small = ImageFont.load_default()
    
    # 绘制标题
    title_text = "Install APK"
    version_text = "v1.6.0"
    subtitle_text = "拖拽应用到 Applications 文件夹完成安装"
    
    # 计算标题位置（居中）
    title_bbox = draw.textbbox((0, 0), title_text, font=font_large)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (width - title_width) // 2
    
    version_bbox = draw.textbbox((0, 0), version_text, font=font_medium)
    version_width = version_bbox[2] - version_bbox[0]
    version_x = (width - version_width) // 2
    
    subtitle_bbox = draw.textbbox((0, 0), subtitle_text, font=font_small)
    subtitle_width = subtitle_bbox[2] - subtitle_bbox[0] 
    subtitle_x = (width - subtitle_width) // 2
    
    # 绘制文本（深色文字，适合浅色背景）
    # 标题
    draw.text((title_x+1, 31), title_text, fill='#ecf0f1', font=font_large)  # 浅色阴影
    draw.text((title_x, 30), title_text, fill='#2c3e50', font=font_large)    # 深色主文字
    
    # 版本号
    draw.text((version_x+1, 61), version_text, fill='#ecf0f1', font=font_medium)
    draw.text((version_x, 60), version_text, fill='#3498db', font=font_medium)
    
    # 说明文字
    draw.text((subtitle_x+1, 291), subtitle_text, fill='#ecf0f1', font=font_small)
    draw.text((subtitle_x, 290), subtitle_text, fill='#5d6d7e', font=font_small)
    
    # 绘制安装箭头（更漂亮的箭头）- 调整位置以匹配新的图标布局
    arrow_y = 160
    arrow_start_x = 190
    arrow_end_x = 330
    
    # 箭头主体 (适配浅色背景)
    draw.line([(arrow_start_x, arrow_y), (arrow_end_x-15, arrow_y)], fill='#3498db', width=4)
    
    # 箭头头部
    points = [
        (arrow_end_x, arrow_y),      # 箭头尖端
        (arrow_end_x-15, arrow_y-8), # 上方
        (arrow_end_x-10, arrow_y),   # 中间
        (arrow_end_x-15, arrow_y+8), # 下方
    ]
    draw.polygon(points, fill='#3498db')
    
    # 添加一些装饰线条 (浅色背景适配)
    for i in range(3):
        y_pos = 110 + i * 35
        draw.line([(25, y_pos), (50, y_pos)], fill='#3498db', width=2)
        draw.line([(width-50, y_pos), (width-25, y_pos)], fill='#3498db', width=2)
    
    # 保存图片
    image.save(output_path, 'PNG', quality=95)
    print(f"自定义背景图片已创建: {output_path}")
    print("提示: 这个背景使用了深色主题，你可以修改脚本来创建不同的样式")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        output_path = sys.argv[1]
    else:
        output_path = "dmg_background.png"
    
    create_custom_background(output_path)