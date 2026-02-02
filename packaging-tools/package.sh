#!/usr/bin/env bash
set -e

# OpenCode 项目打包脚本
# 用途：构建并打包项目以便分发

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 配置
PACKAGE_NAME="opencode-bundle"
PACKAGE_DIR="$SCRIPT_DIR/dist-package"
VERSION="${VERSION:-$(grep '"version"' packages/opencode/package.json | head -1 | awk -F: '{print $2}' | tr -d ' ",')}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="$SCRIPT_DIR/${PACKAGE_NAME}-${VERSION}-${TIMESTAMP}.tar.gz"
MODELS_API_JSON=""  # 本地 api.json 文件路径（用于离线打包）

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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
    log_info "检查构建依赖..."

    if ! command -v bun &> /dev/null; then
        log_error "未找到 bun，请先安装 Bun 1.3.5+"
        echo "安装命令: curl -fsSL https://bun.sh/install | bash"
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        log_error "未找到 git"
        exit 1
    fi

    log_info "依赖检查通过 ✓"
}

# 清理旧的构建产物
clean_build() {
    log_info "清理旧构建产物..."
    rm -rf "$PACKAGE_DIR"
    rm -rf packages/opencode/dist
    rm -rf packages/app/dist
    rm -rf packages/desktop/dist
    log_info "清理完成 ✓"
}

# 创建打包目录
create_package_dir() {
    log_info "创建打包目录..."
    mkdir -p "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR/cli"
    mkdir -p "$PACKAGE_DIR/web"
    mkdir -p "$PACKAGE_DIR/desktop"
    mkdir -p "$PACKAGE_DIR/docs"
    log_info "目录创建完成 ✓"
}

# 构建 CLI 工具
build_cli() {
    log_info "构建 CLI 工具（当前平台）..."
    cd "$SCRIPT_DIR/packages/opencode"

    # 设置离线模式环境变量
    if [ -n "$MODELS_API_JSON" ]; then
        if [ ! -f "$MODELS_API_JSON" ]; then
            log_error "指定的 api.json 文件不存在: $MODELS_API_JSON"
            exit 1
        fi
        log_info "使用本地 api.json 文件: $MODELS_API_JSON"
        export MODELS_DEV_API_JSON="$MODELS_API_JSON"
    fi

    # 使用 --single 标志只构建当前平台
    if bun run script/build.ts --single; then
        log_info "CLI 构建成功 ✓"
    else
        log_error "CLI 构建失败"
        exit 1
    fi

    # 清理环境变量
    unset MODELS_DEV_API_JSON

    cd "$SCRIPT_DIR"

    # 复制 CLI 构建产物
    log_info "复制 CLI 构建产物..."
    if [ -d "packages/opencode/dist" ]; then
        cp -r packages/opencode/dist/* "$PACKAGE_DIR/cli/" 2>/dev/null || true
        # 找到当前平台的二进制文件
        for dir in packages/opencode/dist/*/; do
            if [ -d "$dir" ]; then
                name=$(basename "$dir")
                if [ -d "$dir/bin" ]; then
                    mkdir -p "$PACKAGE_DIR/cli/$name"
                    cp -r "$dir/bin" "$PACKAGE_DIR/cli/$name/"
                    cp "$dir/package.json" "$PACKAGE_DIR/cli/$name/" 2>/dev/null || true
                fi
            fi
        done
        log_info "CLI 产物复制完成 ✓"
    else
        log_warn "未找到 CLI 构建产物"
    fi
}

# 构建 Web 应用
build_web() {
    log_info "构建 Web 应用..."

    if [ -d "packages/app" ]; then
        cd "$SCRIPT_DIR/packages/app"

        if bun run build; then
            log_info "Web 应用构建成功 ✓"
        else
            log_warn "Web 应用构建失败（可选组件）"
        fi

        cd "$SCRIPT_DIR"

        # 复制 Web 构建产物
        if [ -d "packages/app/dist" ]; then
            cp -r packages/app/dist/* "$PACKAGE_DIR/web/" 2>/dev/null || true
            log_info "Web 产物复制完成 ✓"
        fi
    else
        log_warn "未找到 packages/app 目录"
    fi
}

# 构建桌面应用
build_desktop() {
    log_info "构建桌面应用..."

    if [ -d "packages/desktop" ]; then
        cd "$SCRIPT_DIR/packages/desktop"

        # 首先构建前端
        log_info "构建桌面应用前端..."
        if bun run build; then
            log_info "前端构建成功 ✓"
        else
            log_warn "前端构建失败"
            cd "$SCRIPT_DIR"
            return
        fi

        # 检查是否安装了 Tauri CLI
        if command -v cargo &> /dev/null; then
            log_info "构建 Tauri 应用..."
            if cargo tauri build --config src-tauri/tauri.conf.json 2>/dev/null; then
                log_info "桌面应用构建成功 ✓"

                # 复制桌面应用构建产物
                cd "$SCRIPT_DIR"
                if [ -d "packages/desktop/src-tauri/target/release/bundle" ]; then
                    cp -r packages/desktop/src-tauri/target/release/bundle/* "$PACKAGE_DIR/desktop/" 2>/dev/null || true
                fi
            else
                log_warn "Tauri 构建失败（可能需要额外的系统依赖）"
            fi
        else
            log_warn "未找到 cargo，跳过 Tauri 构建"
            log_warn "如需构建桌面应用，请安装 Rust: https://rustup.rs/"
        fi

        cd "$SCRIPT_DIR"
    else
        log_warn "未找到 packages/desktop 目录"
    fi
}

# 复制文档和配置
copy_docs() {
    log_info "复制文档和配置文件..."

    # 复制 README
    if [ -f "README.md" ]; then
        cp README.md "$PACKAGE_DIR/docs/"
    fi

    # 复制许可证
    if [ -f "LICENSE" ]; then
        cp LICENSE "$PACKAGE_DIR/docs/"
    fi

    # 复制部署文档（如果存在）
    if [ -f "DEPLOYMENT_GUIDE.md" ]; then
        cp DEPLOYMENT_GUIDE.md "$PACKAGE_DIR/docs/"
    fi

    log_info "文档复制完成 ✓"
}

# 创建安装说明
create_install_guide() {
    log_info "创建安装说明..."

    cat > "$PACKAGE_DIR/INSTALL.md" << 'EOF'
# OpenCode 安装说明

## 包内容

此压缩包包含以下组件：

### 1. CLI 工具 (`cli/`)
命令行界面版本的 OpenCode。

#### 安装方法

**macOS/Linux:**
```bash
# 进入对应平台的目录
cd cli/opencode-<platform>-<arch>/bin

# 将二进制文件添加到 PATH
chmod +x opencode
sudo mv opencode /usr/local/bin/

# 或者直接运行
./opencode
```

**Windows:**
```powershell
# 进入对应平台的目录
cd cli\opencode-windows-x64\bin

# 直接运行
.\opencode.exe
```

### 2. Web 应用 (`web/`)
Web 界面版本，可以部署到任何静态文件服务器。

#### 部署方法

```bash
# 使用任何静态文件服务器
cd web
python -m http.server 8080

# 或使用 nginx
# 将 web 目录内容复制到 nginx 根目录
```

### 3. 桌面应用 (`desktop/`)
原生桌面应用（如果构建成功）。

#### 安装方法

根据你的平台：

- **macOS**: 打开 `.dmg` 文件并拖拽到 Applications
- **Windows**: 运行 `.exe` 安装程序
- **Linux**: 安装 `.deb` 或 `.AppImage` 文件

## 系统要求

- **CLI**:
  - macOS 11+ / Linux (glibc/musl) / Windows 10+
  - 无需额外依赖

- **Web**: 现代浏览器

- **Desktop**:
  - macOS 11+
  - Windows 10+
  - Linux (WebKitGTK 4.0+)

---

## 🔒 离线/受限网络使用指南

本版本已内置完整的模型配置，可在受限网络环境中使用。

### 离线模式配置

如果您的网络环境无法访问外部服务，请设置以下环境变量：

**Linux/macOS:**
```bash
export OPENCODE_DISABLE_MODELS_FETCH=1
```

**Windows (PowerShell):**
```powershell
$env:OPENCODE_DISABLE_MODEMS_FETCH=1
```

**Windows (CMD):**
```cmd
set OPENCODE_DISABLE_MODELS_FETCH=1
```

### 持久化配置

为了每次启动时都自动应用离线模式，您可以：

**Linux/macOS - 添加到 shell 配置文件:**
```bash
# ~/.bashrc 或 ~/.zshrc
export OPENCODE_DISABLE_MODELS_FETCH=1
```

**Windows - 设置系统环境变量:**
1. 右键"此电脑" → "属性"
2. "高级系统设置" → "环境变量"
3. 新建用户变量：`OPENCODE_DISABLE_MODELS_FETCH` = `1`

### 配置您的 API Key

OpenCode 支持多种 LLM 提供商。您需要配置自己的 API Key 才能使用。

#### 方法 1: 使用命令行配置（推荐）

```bash
# 配置 OpenAI
opencode auth login
# 选择 "openai"
# 输入您的 API Key

# 配置 Anthropic (Claude)
opencode auth login
# 选择 "anthropic"
# 输入您的 API Key
```

#### 方法 2: 手动编辑配置文件

配置文件位置：
- Linux/macOS: `~/.local/share/opencode/auth.json`
- Windows: `%LOCALAPPDATA%\opencode\auth.json`

格式示例：
```json
{
  "openai": {
    "type": "api",
    "key": "sk-your-openai-api-key"
  },
  "anthropic": {
    "type": "api",
    "key": "sk-ant-your-anthropic-api-key"
  }
}
```

#### 方法 3: 使用环境变量

```bash
# OpenAI
export OPENAI_API_KEY="sk-your-key"

# Anthropic
export ANTHROPIC_API_KEY="sk-ant-your-key"
```

### 验证配置

```bash
# 查看已配置的凭据
opencode auth list

# 测试运行
opencode --version
```

---

## 获取帮助

- 项目主页: https://github.com/anomalyco/opencode
- 文档: https://opencode.ai
- 问题反馈: https://github.com/anomalyco/opencode/issues

## 版本信息

版本: {{VERSION}}
构建时间: {{TIMESTAMP}}
EOF

    # 替换变量
    sed -i.bak "s/{{VERSION}}/$VERSION/g" "$PACKAGE_DIR/INSTALL.md"
    sed -i.bak "s/{{TIMESTAMP}}/$TIMESTAMP/g" "$PACKAGE_DIR/INSTALL.md"
    rm -f "$PACKAGE_DIR/INSTALL.md.bak"

    log_info "安装说明创建完成 ✓"
}

# 创建元数据
create_metadata() {
    log_info "创建包元数据..."

    cat > "$PACKAGE_DIR/metadata.json" << EOF
{
  "name": "opencode-bundle",
  "version": "$VERSION",
  "buildDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "gitCommit": "$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")",
  "gitBranch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")",
  "offlineMode": $(test -n "$MODELS_API_JSON" && echo "true" || echo "false"),
  "components": {
    "cli": true,
    "web": $(test -d "$PACKAGE_DIR/web" && echo "true" || echo "false"),
    "desktop": $(test -d "$PACKAGE_DIR/desktop" && ls "$PACKAGE_DIR/desktop"/*.* 2>/dev/null >/dev/null && echo "true" || echo "false")
  }
}
EOF

    log_info "元数据创建完成 ✓"
}

# 打包
create_package() {
    log_info "创建分发包..."

    # 创建压缩包
    cd "$SCRIPT_DIR"
    tar -czf "$OUTPUT_FILE" -C "$PACKAGE_DIR" .

    # 获取文件大小
    SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)

    log_info "打包完成 ✓"
    echo ""
    echo "=========================================="
    echo "📦 分发包已创建!"
    echo "=========================================="
    echo "文件: $OUTPUT_FILE"
    echo "大小: $SIZE"
    echo "版本: $VERSION"
    echo "=========================================="
    echo ""
    echo "分发方式："
    echo "  1. 通过文件共享服务发送此文件"
    echo "  2. 上传到云存储分享下载链接"
    echo "  3. 使用 scp/rsync 传输到服务器"
    echo ""
    echo "接收方解压后请阅读 INSTALL.md 了解安装方法"
    echo ""
}

# 主函数
main() {
    echo "=========================================="
    echo "OpenCode 项目打包脚本"
    echo "=========================================="
    echo ""

    # 检查命令行参数
    SKIP_DESKTOP=false
    SKIP_WEB=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-desktop)
                SKIP_DESKTOP=true
                shift
                ;;
            --skip-web)
                SKIP_WEB=true
                shift
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --models-api-json)
                MODELS_API_JSON="$2"
                shift 2
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --skip-desktop        跳过桌面应用构建"
                echo "  --skip-web            跳过 Web 应用构建"
                echo "  --version VER         覆盖版本号"
                echo "  --models-api-json     指定本地 api.json 文件路径（用于离线打包）"
                echo "  --help                显示此帮助信息"
                echo ""
                echo "示例:"
                echo "  $0                                          # 构建所有组件"
                echo "  $0 --skip-web --skip-desktop                # 只构建 CLI"
                echo "  $0 --models-api-json /path/to/api.json      # 使用本地 api.json 离线打包"
                echo "  $0 --version 1.2.3 --models-api-json api.json"
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                echo "使用 --help 查看帮助"
                exit 1
                ;;
        esac
    done

    # 执行构建流程
    check_dependencies
    clean_build
    create_package_dir
    build_cli

    if [ "$SKIP_WEB" = false ]; then
        build_web
    else
        log_warn "跳过 Web 应用构建"
    fi

    if [ "$SKIP_DESKTOP" = false ]; then
        build_desktop
    else
        log_warn "跳过桌面应用构建"
    fi

    copy_docs
    create_install_guide
    create_metadata
    create_package
}

# 运行主函数
main "$@"
