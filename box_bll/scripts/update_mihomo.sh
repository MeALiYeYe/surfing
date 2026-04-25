#!/bin/bash

# Mihomo 更新脚本 - 包含 Model.bin LightGBM 模型更新
# 用途: 自动下载最新的 Mihomo 核心和 LightGBM 模型

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN_DIR="$REPO_ROOT/box_bll/bin"
CLASH_DIR="$REPO_ROOT/box_bll/clash"
BACKUP_DIR="$BIN_DIR/backup"
SCRIPT_DIR="$REPO_ROOT/box_bll/scripts"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "gunzip")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "缺少依赖: $cmd"
            exit 1
        fi
    done
}

# 获取最新的 Mihomo Alpha 版本 (android-arm64-v8)
download_mihomo() {
    log_info "获取最新 Mihomo Alpha 版本信息..."
    
    # 获取发布信息 JSON
    local release_json=$(curl -s "https://api.github.com/repos/vernesong/mihomo/releases/tags/Prerelease-Alpha")
    
    # 提取 android-arm64-v8 的下载链接
    local download_url=$(echo "$release_json" | grep -o '"browser_download_url":"[^"]*android-arm64-v8[^"]*"' | grep -o 'https://[^"]*' | head -1)
    
    if [ -z "$download_url" ]; then
        log_error "无法获取 Mihomo Android ARM64-v8 下载链接"
        return 1
    fi
    
    log_info "下载地址: $download_url"
    
    local temp_file=$(mktemp)
    local filename=$(basename "$download_url" .gz)
    
    log_info "正在下载 Mihomo 核心..."
    if curl -L -o "$temp_file" "$download_url"; then
        log_info "下载完成，解压中..."
        
        # 创建备份目录
        mkdir -p "$BACKUP_DIR"
        
        # 备份旧的 clash 文件
        if [ -f "$BIN_DIR/clash" ]; then
            cp "$BIN_DIR/clash" "$BACKUP_DIR/clash.backup.$(date +%s)"
            log_info "已备份旧的 clash 文件"
        fi
        
        # 解压并移动文件
        gunzip -c "$temp_file" > "$BIN_DIR/clash"
        chmod +x "$BIN_DIR/clash"
        
        log_info "✅ Mihomo 核心已更新到 $BIN_DIR/clash"
        
        # 验证文件
        if [ -f "$BIN_DIR/clash" ] && "$BIN_DIR/clash" --version &>/dev/null; then
            log_info "✅ Mihomo 核心验证成功"
        else
            log_warn "⚠️  无法验证 Mihomo 核心，但文件已创建"
        fi
        
        rm -f "$temp_file"
        return 0
    else
        log_error "下载 Mihomo 失败"
        rm -f "$temp_file"
        return 1
    fi
}

# 获取最新的 LightGBM Model.bin
download_model() {
    log_info "获取最新 LightGBM Model.bin..."
    
    # 获取发布信息 JSON
    local release_json=$(curl -s "https://api.github.com/repos/vernesong/mihomo/releases/tags/LightGBM-Model")
    
    # 提取 Model.bin 的下载链接
    local download_url=$(echo "$release_json" | grep -o '"browser_download_url":"[^"]*Model\.bin"' | grep -o 'https://[^"]*' | head -1)
    
    if [ -z "$download_url" ]; then
        log_error "无法获取 Model.bin 下载链接"
        return 1
    fi
    
    log_info "下载地址: $download_url"
    
    local output_file="$CLASH_DIR/Model.bin"
    
    log_info "正在下载 LightGBM Model.bin..."
    if curl -L -o "$output_file" "$download_url"; then
        chmod 644 "$output_file"
        
        local file_size=$(du -h "$output_file" | cut -f1)
        log_info "✅ Model.bin 已更新到 $CLASH_DIR/Model.bin (大小: $file_size)"
        
        return 0
    else
        log_error "下载 Model.bin 失败"
        return 1
    fi
}

# 主函数
main() {
    log_info "========================================="
    log_info "Mihomo 更新脚本 (包含 LightGBM 模型)"
    log_info "========================================="
    
    check_dependencies
    
    # 创建必要的目录
    mkdir -p "$BIN_DIR" "$CLASH_DIR" "$BACKUP_DIR"
    
    # 下载 Mihomo 核心
    if download_mihomo; then
        log_info "Mihomo 核心下载成功"
    else
        log_error "Mihomo 核心下载失败"
        exit 1
    fi
    
    # 下载 Model.bin
    if download_model; then
        log_info "Model.bin 下载成功"
    else
        log_warn "Model.bin 下载失败，但 Mihomo 核心已更新"
    fi
    
    log_info "========================================="
    log_info "✅ 更新完成！"
    log_info "========================================="
    log_info ""
    log_info "Mihomo 核心位置: $BIN_DIR/clash"
    log_info "LightGBM 模型位置: $CLASH_DIR/Model.bin"
    log_info "配置文件位置: $CLASH_DIR/config.yaml"
    log_info ""
    log_info "下一步:"
    log_info "  1. 检查配置文件: $CLASH_DIR/config.yaml"
    log_info "  2. 启动 Mihomo: $BIN_DIR/clash -d $CLASH_DIR"
}

main "$@"
