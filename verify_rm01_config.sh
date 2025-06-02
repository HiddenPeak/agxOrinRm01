#!/bin/bash

# RM01 载板配置验证脚本
# 用于在flash之前验证所有必要文件和配置

echo "=== RM01 载板配置验证 ==="
echo ""

# 检查工作目录
EXPECTED_DIR="/home/rm01/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra"
if [ "$(pwd)" != "$EXPECTED_DIR" ]; then
    echo "❌ 错误：请在正确的目录下运行此脚本"
    echo "   当前目录: $(pwd)"
    echo "   期望目录: $EXPECTED_DIR"
    exit 1
fi

echo "✅ 工作目录正确"

# 检查配置文件
CONFIG_FILE="jetson-agx-orin-rm01.conf"
if [ -f "$CONFIG_FILE" ]; then
    echo "✅ 配置文件存在: $CONFIG_FILE"
    # 检查关键配置项
    if grep -q "tegra234-rm01+p3701-0005.dtb" "$CONFIG_FILE"; then
        echo "✅ DTB文件引用正确"
    else
        echo "❌ DTB文件引用错误"
        exit 1
    fi
else
    echo "❌ 配置文件缺失: $CONFIG_FILE"
    exit 1
fi

# 检查设备树文件
DTB_FILE="kernel/dtb/tegra234-rm01+p3701-0005.dtb"
DTS_FILE="kernel/tegra234-rm01+p3701-0005.dts"

if [ -f "$DTB_FILE" ]; then
    echo "✅ DTB文件存在: $DTB_FILE"
    
    # 检查DTB文件大小
    DTB_SIZE=$(stat -c%s "$DTB_FILE")
    if [ "$DTB_SIZE" -gt 100000 ]; then
        echo "✅ DTB文件大小合理: ${DTB_SIZE} bytes"
    else
        echo "❌ DTB文件大小异常: ${DTB_SIZE} bytes"
        exit 1
    fi
else
    echo "❌ DTB文件缺失: $DTB_FILE"
    exit 1
fi

if [ -f "$DTS_FILE" ]; then
    echo "✅ DTS源文件存在: $DTS_FILE"
else
    echo "⚠️  DTS源文件缺失: $DTS_FILE (可选)"
fi

# 验证DTB完整性
echo ""
echo "=== 验证DTB文件完整性 ==="
if dtc -I dtb -O dts "$DTB_FILE" > /dev/null 2>&1; then
    echo "✅ DTB文件格式正确"
else
    echo "❌ DTB文件格式错误"
    exit 1
fi

# 检查关键配置项
echo ""
echo "=== 验证设备树配置 ==="
DTB_CONTENT=$(dtc -I dtb -O dts "$DTB_FILE" 2>/dev/null)

# 检查compatible字符串
if echo "$DTB_CONTENT" | grep -q "rm01,rm01+p3701-0005"; then
    echo "✅ RM01载板compatible字符串正确"
else
    echo "❌ RM01载板compatible字符串错误"
    exit 1
fi

# 检查模型名称
if echo "$DTB_CONTENT" | grep -q "RM01 Carrier Board with P3701-0005 Module"; then
    echo "✅ 模型名称正确"
else
    echo "❌ 模型名称错误"
    exit 1
fi

# 检查PCIe C1配置（以太网）
if echo "$DTB_CONTENT" | awk '/pcie@14100000 {/,/^[ \t]*}[ \t]*$/ {print}' | grep -q 'status = "okay"'; then
    echo "✅ PCIe C1 (以太网) 已启用"
else
    echo "❌ PCIe C1 (以太网) 配置错误"
    exit 1
fi

# 检查PCIe C5配置（NVMe）
if echo "$DTB_CONTENT" | awk '/pcie@141a0000 {/,/^[ \t]*}[ \t]*$/ {print}' | grep -q 'status = "okay"'; then
    echo "✅ PCIe C5 (NVMe) 已启用"
else
    echo "❌ PCIe C5 (NVMe) 配置错误"
    exit 1
fi

# 检查GPIO17配置
if echo "$DTB_CONTENT" | grep -q "nvme-detect"; then
    echo "✅ GPIO17 NVMe检测配置存在"
else
    echo "❌ GPIO17 NVMe检测配置缺失"
    exit 1
fi

# 检查音频子系统禁用
if echo "$DTB_CONTENT" | grep -A5 "aconnect@2900000" | grep -q 'status = "disabled"'; then
    echo "✅ 音频子系统已禁用"
else
    echo "⚠️  音频子系统状态检查失败"
fi

# 检查flash.sh脚本
if [ -x "flash.sh" ]; then
    echo "✅ flash.sh脚本存在且可执行"
else
    echo "❌ flash.sh脚本缺失或不可执行"
    exit 1
fi

# 检查必要的依赖工具
echo ""
echo "=== 检查系统依赖 ==="
if command -v dtc >/dev/null 2>&1; then
    echo "✅ dtc (设备树编译器) 可用"
else
    echo "❌ dtc (设备树编译器) 缺失"
    exit 1
fi

if command -v lsusb >/dev/null 2>&1; then
    echo "✅ lsusb 工具可用"
else
    echo "❌ lsusb 工具缺失"
    exit 1
fi

echo ""
echo "=== 验证完成 ==="
echo "✅ 所有检查都通过！RM01载板配置已准备就绪。"
echo ""
echo "接下来的步骤："
echo "1. 将Jetson AGX Orin设置为Recovery模式"
echo "2. 使用USB连接至主机"
echo "3. 运行: sudo ./flash.sh jetson-agx-orin-rm01 internal"
echo ""
echo "如需更多信息，请参考: RM01_FLASH_GUIDE.md"
