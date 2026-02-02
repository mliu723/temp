#!/usr/bin/env pwsh
# OpenCode 项目打包脚本 (Windows 版本)
# 用途：在 Windows 环境中构建并打包项目以便分发

$ErrorActionPreference = "Stop"

# 配置
$ScriptDir = $PSScriptRoot
$PackageName = "opencode-bundle"
$PackageDir = Join-Path $ScriptDir "dist-package"
$Version = if ($env:VERSION) { $env:VERSION } else {
    (Get-Content (Join-Path $ScriptDir "packages\opencode\package.json") | ConvertFrom-Json).version
}
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputFile = Join-Path $ScriptDir "${PackageName}-${Version}-${Timestamp}.tar.gz"
$ModelsApiJson = ""  # 本地 api.json 文件路径（用于离线打包）

# 颜色输出函数
function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Log-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# 检查依赖
function Test-Dependencies {
    Log-Info "检查构建依赖..."

    try {
        $null = Get-Command bun -ErrorAction Stop
    } catch {
        Log-Error "未找到 bun，请先安装 Bun 1.3.5+"
        Write-Host "安装命令: irm bun.sh/install.ps1 | iex"
        exit 1
    }

    try {
        $null = Get-Command git -ErrorAction Stop
    } catch {
        Log-Error "未找到 git"
        exit 1
    }

    # 检查是否安装了 tar（Windows 10 1803+ 自带）
    try {
        $null = Get-Command tar -ErrorAction Stop
    } catch {
        Log-Error "未找到 tar 命令（Windows 10 1803+ 自带）"
        Log-Error "或者安装 7-Zip: https://www.7-zip.org/"
        exit 1
    }

    Log-Info "依赖检查通过 ✓"
}

# 清理旧的构建产物
function Remove-BuildArtifacts {
    Log-Info "清理旧构建产物..."

    if (Test-Path $PackageDir) {
        Remove-Item -Path $PackageDir -Recurse -Force
    }

    $distPath = Join-Path $ScriptDir "packages\opencode\dist"
    if (Test-Path $distPath) {
        Remove-Item -Path $distPath -Recurse -Force
    }

    $appDistPath = Join-Path $ScriptDir "packages\app\dist"
    if (Test-Path $appDistPath) {
        Remove-Item -Path $appDistPath -Recurse -Force
    }

    $desktopDistPath = Join-Path $ScriptDir "packages\desktop\dist"
    if (Test-Path $desktopDistPath) {
        Remove-Item -Path $desktopDistPath -Recurse -Force
    }

    Log-Info "清理完成 ✓"
}

# 创建打包目录
function New-PackageDirectory {
    Log-Info "创建打包目录..."

    $null = New-Item -Path (Join-Path $PackageDir "cli") -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $PackageDir "web") -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $PackageDir "desktop") -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $PackageDir "docs") -ItemType Directory -Force

    Log-Info "目录创建完成 ✓"
}

# 构建 CLI 工具
function Build-Cli {
    Log-Info "构建 CLI 工具（当前平台）..."
    Push-Location (Join-Path $ScriptDir "packages\opencode")

    try {
        # 设置离线模式环境变量
        if ($ModelsApiJson) {
            if (-not (Test-Path $ModelsApiJson)) {
                Log-Error "指定的 api.json 文件不存在: $ModelsApiJson"
                exit 1
            }
            $env:MODELS_DEV_API_JSON = $ModelsApiJson
            Log-Info "使用本地 api.json 文件: $ModelsApiJson"
        }

        # 使用 --single 标志只构建当前平台
        $result = bun run script/build.ts --single 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log-Info "CLI 构建成功 ✓"
        } else {
            Log-Error "CLI 构建失败"
            Write-Host $result
            exit 1
        }
    } finally {
        # 清理环境变量
        if ($env:MODELS_DEV_API_JSON) {
            Remove-Item Env:MODELS_DEV_API_JSON
        }
        Pop-Location
    }

    # 复制 CLI 构建产物
    Log-Info "复制 CLI 构建产物..."
    $distPath = Join-Path $ScriptDir "packages\opencode\dist"

    if (Test-Path $distPath) {
        $dirs = Get-ChildItem -Path $distPath -Directory
        foreach ($dir in $dirs) {
            $name = $dir.Name
            $binPath = Join-Path $dir.FullName "bin"

            if (Test-Path $binPath) {
                $targetPath = Join-Path $PackageDir "cli\$name"
                $null = New-Item -Path $targetPath -ItemType Directory -Force
                Copy-Item -Path "$binPath\*" -Destination $targetPath -Recurse -Force

                $pkgJsonPath = Join-Path $dir.FullName "package.json"
                if (Test-Path $pkgJsonPath) {
                    Copy-Item -Path $pkgJsonPath -Destination $targetPath -Force
                }
            }
        }
        Log-Info "CLI 产物复制完成 ✓"
    } else {
        Log-Warn "未找到 CLI 构建产物"
    }
}

# 构建 Web 应用
function Build-Web {
    Log-Info "构建 Web 应用..."

    $appPath = Join-Path $ScriptDir "packages\app"
    if (Test-Path $appPath) {
        Push-Location $appPath

        $result = bun run build 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log-Info "Web 应用构建成功 ✓"
        } else {
            Log-Warn "Web 应用构建失败（可选组件）"
            Pop-Location
            return
        }

        Pop-Location

        # 复制 Web 构建产物
        $appDistPath = Join-Path $appPath "dist"
        if (Test-Path $appDistPath) {
            $targetPath = Join-Path $PackageDir "web"
            Copy-Item -Path "$appDistPath\*" -Destination $targetPath -Recurse -Force
            Log-Info "Web 产物复制完成 ✓"
        }
    } else {
        Log-Warn "未找到 packages\app 目录"
    }
}

# 构建桌面应用
function Build-Desktop {
    Log-Info "构建桌面应用..."

    $desktopPath = Join-Path $ScriptDir "packages\desktop"
    if (Test-Path $desktopPath) {
        Push-Location $desktopPath

        # 首先构建前端
        Log-Info "构建桌面应用前端..."
        $result = bun run build 2>&1
        if ($LASTEXITCODE -ne 0) {
            Log-Warn "前端构建失败"
            Pop-Location
            return
        }
        Log-Info "前端构建成功 ✓"

        # 检查是否安装了 Rust/cargo
        try {
            $null = Get-Command cargo -ErrorAction Stop
            Log-Info "构建 Tauri 应用..."
            $result = cargo tauri build --config src-tauri\tauri.conf.json 2>&1
            if ($LASTEXITCODE -eq 0) {
                Log-Info "桌面应用构建成功 ✓"

                # 复制桌面应用构建产物
                $bundlePath = Join-Path $desktopPath "src-tauri\target\release\bundle"
                if (Test-Path $bundlePath) {
                    $targetPath = Join-Path $PackageDir "desktop"
                    Copy-Item -Path "$bundlePath\*" -Destination $targetPath -Recurse -Force
                }
            } else {
                Log-Warn "Tauri 构建失败（可能需要额外的系统依赖）"
            }
        } catch {
            Log-Warn "未找到 cargo，跳过 Tauri 构建"
            Log-Warn "如需构建桌面应用，请安装 Rust: https://rustup.rs/"
        }

        Pop-Location
    } else {
        Log-Warn "未找到 packages\desktop 目录"
    }
}

# 复制文档和配置
function Copy-Documents {
    Log-Info "复制文档和配置文件..."

    $readmePath = Join-Path $ScriptDir "README.md"
    if (Test-Path $readmePath) {
        Copy-Item -Path $readmePath -Destination (Join-Path $PackageDir "docs\") -Force
    }

    $licensePath = Join-Path $ScriptDir "LICENSE"
    if (Test-Path $licensePath) {
        Copy-Item -Path $licensePath -Destination (Join-Path $PackageDir "docs\") -Force
    }

    $deployGuidePath = Join-Path $ScriptDir "DEPLOYMENT_GUIDE.md"
    if (Test-Path $deployGuidePath) {
        Copy-Item -Path $deployGuidePath -Destination (Join-Path $PackageDir "docs\") -Force
    }

    Log-Info "文档复制完成 ✓"
}

# 创建安装说明
function New-InstallGuide {
    Log-Info "创建安装说明..."

    $installContent = @"
# OpenCode 安装说明 (Windows)

## 包内容

此压缩包包含以下组件：

### 1. CLI 工具 (`cli/`)
命令行界面版本的 OpenCode。

#### 安装方法

```powershell
# 进入对应平台的目录
cd cli\opencode-windows-x64\bin

# 直接运行
.\opencode.exe

# 或者添加到 PATH（推荐）
# 1. 复制 opencode.exe 到你想安装的目录，比如 C:\Tools
# 2. 将该目录添加到系统 PATH
#    - 右键"此电脑" → "属性" → "高级系统设置" → "环境变量"
#    - 在"系统变量"中找到 Path，点击"编辑"
#    - 点击"新建"，添加 C:\Tools
# 3. 重新打开命令提示符或 PowerShell，就可以直接运行 opencode
```

### 2. Web 应用 (`web/`)
Web 界面版本，可以部署到任何静态文件服务器。

#### 部署方法

```powershell
# 使用 Python（如果已安装）
cd web
python -m http.server 8080

# 或使用 IIS、nginx 等 Web 服务器
```

### 3. 桌面应用 (`desktop/`)
原生桌面应用（如果构建成功）。

#### 安装方法

运行 `.exe` 安装程序即可完成安装。

---

## 🔒 离线/受限网络使用指南

本版本已内置完整的模型配置，可在受限网络环境中使用。

### 离线模式配置

如果您的网络环境无法访问外部服务，请设置以下环境变量：

**PowerShell:**
```powershell
`$env:OPENCODE_DISABLE_MODELS_FETCH=1
```

**CMD:**
```cmd
set OPENCODE_DISABLE_MODELS_FETCH=1
```

### 持久化配置

为了每次启动时都自动应用离线模式，您可以：

**方法 1: 设置系统环境变量**
1. 右键"此电脑" → "属性"
2. "高级系统设置" → "环境变量"
3. 新建用户变量：`OPENCODE_DISABLE_MODELS_FETCH` = `1`

**方法 2: PowerShell 配置文件**
```powershell
# 添加到 PowerShell 配置文件（`$PROFILE`）
[System.Environment]::SetEnvironmentVariable('OPENCODE_DISABLE_MODELS_FETCH', '1', 'User')
```

### 配置您的 API Key

OpenCode 支持多种 LLM 提供商。您需要配置自己的 API Key 才能使用。

#### 方法 1: 使用命令行配置（推荐）

```powershell
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

```powershell
# OpenAI
`$env:OPENAI_API_KEY="sk-your-key"

# Anthropic
`$env:ANTHROPIC_API_KEY="sk-ant-your-key"
```

### 验证配置

```powershell
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

版本: $Version
构建时间: $Timestamp
"@

    $installContent | Out-File -FilePath (Join-Path $PackageDir "INSTALL.md") -Encoding UTF8

    Log-Info "安装说明创建完成 ✓"
}

# 创建元数据
function New-Metadata {
    Log-Info "创建包元数据..."

    $webExists = Test-Path (Join-Path $PackageDir "web\*")
    $desktopExists = Test-Path (Join-Path $PackageDir "desktop\*.*")
    $offlineMode = if ($ModelsApiJson) { "true" } else { "false" }

    $gitCommit = git rev-parse --short HEAD 2>$null
    if (-not $gitCommit) { $gitCommit = "unknown" }

    $gitBranch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $gitBranch) { $gitBranch = "unknown" }

    $metadata = @{
        name = "opencode-bundle"
        version = $Version
        buildDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        gitCommit = $gitCommit
        gitBranch = $gitBranch
        offlineMode = [bool]::Parse($offlineMode)
        components = @{
            cli = $true
            web = $webExists
            desktop = $desktopExists
        }
    }

    $metadata | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $PackageDir "metadata.json") -Encoding UTF8

    Log-Info "元数据创建完成 ✓"
}

# 创建打包
function New-Package {
    Log-Info "创建分发包..."

    # 切换到脚本目录
    Push-Location $ScriptDir

    # 使用 tar 创建压缩包（Windows 10 1803+ 自带 tar）
    tar -czf $OutputFile -C $PackageDir .

    Pop-Location

    # 获取文件大小
    $sizeInfo = Get-Item $OutputFile | Select-Object Name, @{Name="Size";Expression={$_.Length / 1MB}}, @{Name="SizeMB";Expression={"{0:N2} MB" -f ($_.Length / 1MB)}}

    Log-Info "打包完成 ✓"
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "📦 分发包已创建!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "文件: $($sizeInfo.Name)"
    Write-Host "大小: $($sizeInfo.SizeMB)"
    Write-Host "版本: $Version"
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "分发方式："
    Write-Host "  1. 通过文件共享服务发送此文件"
    Write-Host "  2. 上传到云存储分享下载链接"
    Write-Host "  3. 复制到公司内网文件服务器"
    Write-Host ""
    Write-Host "接收方解压后请阅读 INSTALL.md 了解安装方法"
    Write-Host ""
}

# 主函数
function Main {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "OpenCode 项目打包脚本 (Windows)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    # 解析命令行参数
    $skipDesktop = $false
    $skipWeb = $false

    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "--skip-desktop" {
                $skipDesktop = $true
            }
            "--skip-web" {
                $skipWeb = $true
            }
            "--version" {
                $Version = $args[++$i]
            }
            "--models-api-json" {
                $ModelsApiJson = $args[++$i]
            }
            "--help" {
                Write-Host "用法: .\package.ps1 [选项]"
                Write-Host ""
                Write-Host "选项:"
                Write-Host "  --skip-desktop        跳过桌面应用构建"
                Write-Host "  --skip-web            跳过 Web 应用构建"
                Write-Host "  --version VER         覆盖版本号"
                Write-Host "  --models-api-json     指定本地 api.json 文件路径（用于离线打包）"
                Write-Host "  --help                显示此帮助信息"
                Write-Host ""
                Write-Host "示例:"
                Write-Host "  .\package.ps1                                          # 构建所有组件"
                Write-Host "  .\package.ps1 --skip-web --skip-desktop                # 只构建 CLI"
                Write-Host "  .\package.ps1 --models-api-json C:\path\to\api.json    # 使用本地 api.json 离线打包"
                Write-Host "  .\package.ps1 --version 1.2.3 --models-api-json api.json"
                exit 0
            }
            default {
                Log-Error "未知选项: $($args[$i])"
                Write-Host "使用 --help 查看帮助"
                exit 1
            }
        }
    }

    # 执行构建流程
    Test-Dependencies
    Remove-BuildArtifacts
    New-PackageDirectory
    Build-Cli

    if (-not $skipWeb) {
        Build-Web
    } else {
        Log-Warn "跳过 Web 应用构建"
    }

    if (-not $skipDesktop) {
        Build-Desktop
    } else {
        Log-Warn "跳过桌面应用构建"
    }

    Copy-Documents
    New-InstallGuide
    New-Metadata
    New-Package
}

# 运行主函数
Main $args
