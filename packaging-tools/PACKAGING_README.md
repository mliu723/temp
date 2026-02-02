# OpenCode 打包脚本使用指南

## 概述

本项目提供跨平台的打包脚本：
- **Linux/macOS**: `package.sh` (Bash 脚本)
- **Windows**: `package.ps1` (PowerShell 脚本)

用于构建 OpenCode 项目并创建可在受限网络环境中使用的分发包。

## 快速开始

### Linux/macOS

```bash
# 构建所有组件（CLI + Web + Desktop）
./package.sh

# 只构建 CLI（推荐，最快）
./package.sh --skip-web --skip-desktop
```

### Windows

```powershell
# 构建所有组件
.\package.ps1

# 只构建 CLI（推荐，最快）
.\package.ps1 --skip-web --skip-desktop
```

### 跳过某些组件

```bash
# 只构建 CLI，跳过其他组件
./package.sh --skip-web --skip-desktop

# 构建 CLI 和 Web，跳过桌面应用
./package.sh --skip-desktop
```

### 指定版本号

```bash
# 使用自定义版本号
./package.sh --version 1.2.3
```

## 离线/受限网络打包

如果你的网络环境无法访问 `models.dev`（比如公司内网），可以使用本地 `api.json` 文件进行离线打包。

### 获取 api.json 文件

在有网络访问的环境中下载 `api.json`：

**Linux/macOS:**
```bash
# 从 models.dev 下载
curl -o api.json https://models.dev/api.json

# 或者从已有的 OpenCode 安装中导出
cp ~/.local/share/opencode/models.json api.json
```

**Windows (PowerShell):**
```powershell
# 从 models.dev 下载
Invoke-WebRequest -Uri "https://models.dev/api.json" -OutFile "api.json"

# 或者从已有的 OpenCode 安装中导出
Copy-Item "$env:LOCALAPPDATA\opencode\models.json" -Destination "api.json"
```

**Windows (CMD):**
```cmd
REM 从 models.dev 下载
curl -o api.json https://models.dev/api.json

REM 或者从已有的 OpenCode 安装中导出
copy %LOCALAPPDATA%\opencode\models.json api.json
```

### 使用本地 api.json 打包

**Linux/macOS:**
```bash
# 使用本地 api.json 文件打包
./package.sh --models-api-json /path/to/api.json

# 只打包 CLI（最快，推荐）
./package.sh --models-api-json api.json --skip-web --skip-desktop

# 指定版本号
./package.sh --models-api-json api.json --version 1.2.3
```

**Windows:**
```powershell
# 使用本地 api.json 文件打包
.\package.ps1 --models-api-json C:\path\to\api.json

# 只打包 CLI（最快，推荐）
.\package.ps1 --models-api-json api.json --skip-web --skip-desktop

# 指定版本号
.\package.ps1 --models-api-json api.json --version 1.2.3
```

### 离线模式的优势

使用 `--models-api-json` 参数打包的产物具有以下特点：

1. ✅ **完全离线运行** - 打包后的二进制文件已内置完整的模型配置
2. ✅ **无需网络访问** - 用户在受限网络中可以直接使用
3. ✅ **静态模型列表** - 使用打包时的模型配置，不会尝试更新
4. ✅ **适用于内网环境** - 适合企业内部部署

### 用户使用离线包

打包完成后，分发包内的 `INSTALL.md` 会包含详细的离线配置说明。用户只需：

1. 解压分发包
2. 设置环境变量 `OPENCODE_DISABLE_MODELS_FETCH=1`
3. 使用 `opencode auth login` 配置自己的 API Key
4. 正常使用

详细说明见分发包中的 `INSTALL.md` 文件。

## 前置要求

### 必需

- **Bun 1.3.5+**
  - Linux/macOS:
    ```bash
    curl -fsSL https://bun.sh/install | bash
    ```
  - Windows PowerShell:
    ```powershell
    irm bun.sh/install.ps1 | iex
    ```

- **Git**
  - macOS: `brew install git`
  - Ubuntu: `sudo apt install git`
  - Windows: https://git-scm.com/download/win

### 可选（用于构建桌面应用）

- **Rust 工具链**
  - Linux/macOS:
    ```bash
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    ```
  - Windows: https://rustup.rs/

- **系统依赖**
  - Ubuntu/Debian:
    ```bash
    sudo apt install libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev patchelf
    ```
  - macOS: 无需额外依赖
  - Windows: 无需额外依赖

### Windows 额外要求

- **PowerShell 5.1+** (Windows 10 自带)
- **tar 命令** (Windows 10 1803+ 自带，或安装 7-Zip)
- **执行策略**（首次运行可能需要）:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```
  ```

- **系统依赖**
  - Ubuntu/Debian:
    ```bash
    sudo apt install libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev patchelf
    ```
  - macOS: 无需额外依赖
  - Windows: 无需额外依赖

## 输出结构

脚本执行后会生成一个 `.tar.gz` 压缩包，包含以下内容：

```
opencode-bundle-{version}-{timestamp}.tar.gz
├── cli/                    # CLI 工具
│   └── opencode-{os}-{arch}/
│       ├── bin/
│       │   └── opencode   # 可执行文件
│       └── package.json
├── web/                    # Web 应用（如果构建）
│   ├── assets/
│   └── index.html
├── desktop/                # 桌面应用（如果构建）
│   ├── dmg/               # macOS 安装包
│   ├── nsis/              # Windows 安装包
│   └── appimage/          # Linux AppImage
├── docs/                   # 文档
│   ├── README.md
│   └── LICENSE
├── INSTALL.md              # 安装说明
└── metadata.json           # 包元数据
```

## 分发方式

### 1. 直接分享文件

```bash
# 发送给其他人
scp opencode-bundle-*.tar.gz user@server:/path/
```

### 2. 上传到云存储

- Google Drive
- Dropbox
- OneDrive
- AWS S3
- 阿里云 OSS

### 3. 通过内部文件服务器

```bash
# 上传到公司内网文件服务器
curl -F "file=@opencode-bundle-*.tar.gz" http://your-server/upload
```

## 接收方使用方法

### 解压

```bash
tar -xzf opencode-bundle-*.tar.gz
cd dist-package
```

### 安装

详细安装说明请查看解压后的 `INSTALL.md` 文件。

#### 快速安装 CLI

```bash
# macOS/Linux
cd cli/opencode-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)/bin
chmod +x opencode
sudo mv opencode /usr/local/bin/
opencode --version
```

```powershell
# Windows
cd cli\opencode-windows-x64\bin
.\opencode.exe --version
```

## 常见问题

### 1. 构建失败

**问题**: CLI 构建失败

**解决**:
```bash
# 清理缓存并重试
rm -rf node_modules bun.lockb
bun install
./package.sh
```

### 2. 桌面应用构建失败

**问题**: Tauri 构建失败

**解决**:
```bash
# 跳过桌面应用构建
./package.sh --skip-desktop
```

或者安装 Rust 和系统依赖后重试。

### 3. 权限错误

**问题**: 无法执行脚本

**解决**:
```bash
chmod +x package.sh
./package.sh
```

### 4. Bun 版本不兼容

**问题**: Bun 版本过低

**解决**:
```bash
# Linux/macOS - 更新 Bun
bun upgrade
# 或重新安装
curl -fsSL https://bun.sh/install | bash
```

```powershell
# Windows - 更新 Bun
bun upgrade
# 或重新安装
irm bun.sh/install.ps1 | iex
```

### 5. Windows PowerShell 执行策略错误

**问题**: 无法运行 .ps1 脚本

**解决**:
```powershell
# 查看当前执行策略
Get-ExecutionPolicy -List

# 为当前用户设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 然后重新运行脚本
.\package.ps1
```

### 6. Windows 缺少 tar 命令

**问题**: 打包时提示找不到 tar 命令

**解决**:
- 升级到 Windows 10 1803 或更高版本（自带 tar）
- 或者安装 7-Zip: https://www.7-zip.org/
- 或者使用 WSL (Windows Subsystem for Linux)

### 5. 离线环境无法访问 models.dev

**问题**: 构建时无法访问 `models.dev/api.json`

**解决**:
```bash
# 在有网络的环境下载 api.json
curl -o api.json https://models.dev/api.json

# 使用本地文件打包
./package.sh --models-api-json api.json
```

### 6. 用户在受限网络中使用

**问题**: 分发的用户无法访问外网

**解决**: 使用离线打包方式：
```bash
# 打包时使用 --models-api.json 参数
./package.sh --models-api-json api.json

# 这样打包的产物内置了完整的模型配置
# 用户只需设置 OPENCODE_DISABLE_MODELS_FETCH=1 即可离线使用
```

## 高级用法

### 自定义构建

如果你想只构建特定平台的 CLI：

```bash
cd packages/opencode
bun run script/build.ts --single --baseline
```

### 只构建 Web 应用

```bash
cd packages/app
bun run build
```

### 只构建桌面应用

```bash
cd packages/desktop
bun run build
cargo tauri build
```

## CI/CD 集成

### GitHub Actions

```yaml
name: Package

on:
  push:
    tags:
      - 'v*'

jobs:
  package:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: oven-sh/setup-bun@v1
        with:
          bun-version: 1.3.5

      - name: Build and package
        run: ./package.sh --skip-desktop

      - uses: actions/upload-artifact@v4
        with:
          name: opencode-bundle
          path: opencode-bundle-*.tar.gz
```

## 技术支持

如遇问题，请：

1. 查看 [INSTALL.md](INSTALL.md) 获取详细安装说明
2. 查看 [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) 获取部署指南
3. 提交 Issue: https://github.com/anomalyco/opencode/issues
