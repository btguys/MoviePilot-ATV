#!/bin/bash

echo "🧪 Top Shelf Extension 诊断测试"
echo "================================"
echo ""

APP_PATH="/Users/ykyau/Library/Developer/Xcode/DerivedData/MoviePilot-ATV-aluengilzikkhsggirigqflohjqu/Build/Products/Debug-appletvsimulator/MoviePilotTV.app"
EXTENSION_PATH="$APP_PATH/PlugIns/MoviePilotTVTopShelf.appex"

# 1. 检查 Extension 存在
if [ -d "$EXTENSION_PATH" ]; then
    echo "✅ Extension 已嵌入"
else
    echo "❌ Extension 不存在"
    exit 1
fi

# 2. 检查 Extension 配置
echo ""
echo "📋 Extension 配置:"
echo "Extension Point: $(/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPointIdentifier" "$EXTENSION_PATH/Info.plist" 2>/dev/null)"
echo "Principal Class: $(/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPrincipalClass" "$EXTENSION_PATH/Info.plist" 2>/dev/null)"
echo "Bundle ID: $(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$EXTENSION_PATH/Info.plist" 2>/dev/null)"

# 3. 检查 Swift 模块
echo ""
echo "🔍 检查编译的类文件:"
if [ -d "$EXTENSION_PATH/Frameworks" ]; then
    echo "   Frameworks 目录存在"
    ls -la "$EXTENSION_PATH/Frameworks" 2>/dev/null
fi

# 4. 检查可执行文件
EXECUTABLE="$EXTENSION_PATH/MoviePilotTVTopShelf"
if [ -f "$EXECUTABLE" ]; then
    echo ""
    echo "✅ Extension 可执行文件存在"
    file "$EXECUTABLE"
    echo ""
    echo "📦 可执行文件包含的类:"
    nm "$EXECUTABLE" 2>/dev/null | grep -i "ContentProvider" | head -5
else
    echo "❌ Extension 可执行文件不存在"
fi

echo ""
echo "💡 建议的测试步骤:"
echo "1. 在 Xcode 中完全清理项目: Product > Clean Build Folder (Cmd+Shift+K)"
echo "2. 退出模拟器"
echo "3. 删除模拟器中的 app: xcrun simctl uninstall booted com.hvg.moviepilot-atv"
echo "4. 重新构建并运行"
echo "5. 登录并加载首页"
echo "6. 按 Home 键退出"
echo "7. 等待 10-15 秒"
echo "8. 查看 Xcode 控制台是否有 [TopShelf] 日志"
echo ""
echo "🔧 如果仍然不工作，尝试:"
echo "   xcrun simctl shutdown all"
echo "   rm -rf ~/Library/Developer/CoreSimulator/Caches/*"
echo "   重启 Xcode"
