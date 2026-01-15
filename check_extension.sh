#!/bin/bash

echo "🔍 检查 Top Shelf Extension 嵌入状态"
echo "======================================"

# 查找最新的 build 产物
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/MoviePilot-ATV-*/Build/Products/Debug-appletvsimulator"

if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ 找不到构建目录，请先运行 app"
    exit 1
fi

APP_PATH=$(find "$BUILD_DIR" -name "MoviePilotTV.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ 找不到 MoviePilotTV.app"
    exit 1
fi

echo "✅ 找到 App: $APP_PATH"
echo ""

# 检查 PlugIns 目录
PLUGINS_DIR="$APP_PATH/PlugIns"
if [ -d "$PLUGINS_DIR" ]; then
    echo "✅ PlugIns 目录存在"
    ls -la "$PLUGINS_DIR"
    echo ""
else
    echo "❌ PlugIns 目录不存在！Extension 未嵌入！"
    echo ""
    echo "修复步骤："
    echo "1. 在 Xcode 中选择 MoviePilotTV target"
    echo "2. 进入 Build Phases 标签"
    echo "3. 查找 'Embed App Extensions' 或 'Embed Foundation Extensions'"
    echo "4. 确认 MoviePilotTVTopShelf.appex 在列表中"
    echo "5. 如果没有，点击 + 添加它"
    exit 1
fi

# 检查 Extension
EXTENSION_PATH="$PLUGINS_DIR/MoviePilotTVTopShelf.appex"
if [ -d "$EXTENSION_PATH" ]; then
    echo "✅ Extension 已嵌入: MoviePilotTVTopShelf.appex"
    echo ""
    
    # 检查 Info.plist
    EXTENSION_PLIST="$EXTENSION_PATH/Info.plist"
    if [ -f "$EXTENSION_PLIST" ]; then
        echo "📋 Extension Info.plist 配置:"
        /usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPointIdentifier" "$EXTENSION_PLIST" 2>/dev/null
        /usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPrincipalClass" "$EXTENSION_PLIST" 2>/dev/null
        echo ""
    fi
    
    # 检查 entitlements
    EXTENSION_ENTITLEMENTS="$EXTENSION_PATH/archived-expanded-entitlements.xcent"
    if [ -f "$EXTENSION_ENTITLEMENTS" ]; then
        echo "🔐 Extension App Groups:"
        /usr/libexec/PlistBuddy -c "Print :com.apple.security.application-groups" "$EXTENSION_ENTITLEMENTS" 2>/dev/null
        echo ""
    fi
    
    echo "✅ Extension 配置正确！"
    echo ""
    echo "📝 调试建议："
    echo "1. 完全退出模拟器（Cmd+Q）"
    echo "2. 清理构建：Cmd+Shift+K"
    echo "3. 重新运行 app"
    echo "4. 退出 app 到主屏幕"
    echo "5. 等待 5-10 秒让系统加载 Extension"
    echo "6. 查看 Xcode 控制台是否有 [TopShelf] 日志"
    
else
    echo "❌ Extension 文件不存在: MoviePilotTVTopShelf.appex"
    echo ""
    echo "可能的原因："
    echo "1. Extension target 没有构建成功"
    echo "2. Embed App Extensions 阶段配置错误"
    echo ""
    echo "修复步骤："
    echo "1. 选择 MoviePilotTVTopShelf scheme 并构建它"
    echo "2. 然后选择 MoviePilotTV scheme"
    echo "3. Product > Clean Build Folder"
    echo "4. 重新构建并运行"
fi
