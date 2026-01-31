#!/usr/bin/env pwsh
<#
.SYNOPSIS
    OpenCode 内网版构建脚本
.DESCRIPTION
    构建内网版本的 OpenCode，内置模型列表，无需联网即可使用
.PARAMETER ApiJsonPath
    api.json 文件路径（默认使用当前目录的 api.json）
.PARAMETER Version
    版本号（默认：1.0.0）
.PARAMETER OutputDir
    输出目录（默认：release）
.PARAMETER SkipDownload
    跳过下载 api.json（如果已有文件）
.PARAMETER Clean
    清理构建缓存
.EXAMPLE
    .\build-internal.ps1
.EXAMPLE
    .\build-internal.ps1 -Version "2.0.0" -Clean
#>

param(
    [string]$ApiJsonPath = "api.json",
    [string]$Version = "1.0.0",
    [string]$OutputDir = "release",
    [switch]$SkipDownload = $false,
    [switch]$Clean = $false
)

# ========== 配置 ==========
$PROJECT_ROOT = $PSScriptRoot
$API_URL = "https://models.dev/api.json"
$MODELS_DEV_API_JSON = Join-Path $PROJECT_ROOT "api.json"
$BUILD_SCRIPT = Join-Path $PROJECT_ROOT "packages\opencode\script\build.ts"
$DIST_DIR = Join-Path $PROJECT_ROOT "packages\opencode\dist\opencode-windows-x64"
$RELEASE_DIR = Join-Path $PROJECT_ROOT $OutputDir
$ZIP_FILE = Join-Path $PROJECT_ROOT "opencode-internal-v$Version.zip"

# ========== 颜色输出函数 ==========
function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Write-Step {
    param([string]$Message, [int]$Step, [int]$Total)
    Write-Host "[$Step/$Total] $Message" -ForegroundColor Yellow
}

# ========== 工具函数 ==========
function Get-FileSize {
    param([string]$Path)
    if (Test-Path $Path) {
        $size = (Get-Item $Path).Length
        if ($size -gt 1GB) {
            return "{0:N2} GB" -f ($size / 1GB)
        } elseif ($size -gt 1MB) {
            return "{0:N2} MB" -f ($size / 1MB)
        } elseif ($size -gt 1KB) {
            return "{0:N2} KB" -f ($size / 1KB)
        } else {
            return "$size bytes"
        }
    }
    return "0 bytes"
}

function Test-Command {
    param([string]$Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# ========== 主程序 ==========
function Main {
    Write-Info "===================================="
    Write-Info "  OpenCode 内网版构建脚本 v$Version"
    Write-Info "===================================="
    Write-Host ""

    $totalSteps = 6
    $currentStep = 0

    # ========== 步骤 1: 环境检查 ==========
    $currentStep++
    Write-Step "检查构建环境..." $currentStep $totalSteps

    # 检查 Bun
    if (-not (Test-Command "bun")) {
        Write-Error "错误：未找到 Bun"
        Write-Warning "请先安装 Bun：https://bun.sh/"
        exit 1
    }
    Write-Success "  ✓ Bun 已安装: $(bun --version)"

    # 检查构建脚本
    if (-not (Test-Path $BUILD_SCRIPT)) {
        Write-Error "错误：找不到构建脚本 $BUILD_SCRIPT"
        Write-Warning "请确保在项目根目录运行此脚本"
        exit 1
    }
    Write-Success "  ✓ 构建脚本存在"

    # 检查项目结构
    $packageJson = Join-Path $PROJECT_ROOT "package.json"
    if (-not (Test-Path $packageJson)) {
        Write-Error "错误：不是有效的 OpenCode 项目目录"
        exit 1
    }
    Write-Success "  ✓ 项目结构验证通过"
    Write-Host ""

    # ========== 步骤 2: 准备 api.json ==========
    $currentStep++
    Write-Step "准备模型数据..." $currentStep $totalSteps

    if ($Clean -and (Test-Path $MODELS_DEV_API_JSON)) {
        Write-Warning "  删除旧的 api.json"
        Remove-Item $MODELS_DEV_API_JSON -Force
    }

    if (-not (Test-Path $MODELS_DEV_API_JSON)) {
        if ($SkipDownload) {
            Write-Error "错误：找不到 $MODELS_DEV_API_JSON"
            Write-Warning "请先下载 api.json 或移除 -SkipDownload 参数"
            exit 1
        }

        Write-Warning "  正在下载 api.json 从 $API_URL ..."
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $API_URL -OutFile $MODELS_DEV_API_JSON -UseBasicParsing
            $ProgressPreference = 'Continue'
            Write-Success "  ✓ 下载成功: $(Get-FileSize $MODELS_DEV_API_JSON)"
        } catch {
            Write-Error "  下载失败: $_"
            Write-Warning "提示：可以从能访问外网的机器下载后复制过来"
            exit 1
        }
    } else {
        Write-Success "  ✓ api.json 已存在: $(Get-FileSize $MODELS_DEV_API_JSON)"
    }

    # 验证 api.json 格式
    try {
        $json = Get-Content $MODELS_DEV_API_JSON -Raw | ConvertFrom-Json
        $providerCount = ($json | Get-Member -MemberType NoteProperty | Measure-Object).Count
        Write-Success "  ✓ api.json 格式正确 (包含 $providerCount 个提供商)"
    } catch {
        Write-Error "  api.json 格式错误: $_"
        exit 1
    }
    Write-Host ""

    # ========== 步骤 3: 清理旧版本 ==========
    $currentStep++
    Write-Step "清理旧的构建产物..." $currentStep $totalSteps

    if (Test-Path $RELEASE_DIR) {
        Write-Warning "  删除目录: $RELEASE_DIR"
        Remove-Item -Recurse -Force $RELEASE_DIR
    }
    New-Item -ItemType Directory -Path $RELEASE_DIR -Force | Out-Null
    Write-Success "  ✓ 输出目录已创建"

    if (Test-Path $ZIP_FILE) {
        Write-Warning "  删除旧的压缩包: $ZIP_FILE"
        Remove-Item $ZIP_FILE -Force
    }
    Write-Success "  ✓ 清理完成"
    Write-Host ""

    # ========== 步骤 4: 构建 ==========
    $currentStep++
    Write-Step "构建 OpenCode..." $currentStep $totalSteps

    # 设置环境变量
    $env:MODELS_DEV_API_JSON = (Resolve-Path $MODELS_DEV_API_JSON).Path
    $env:OPENCODE_DISABLE_MODELS_FETCH = "1"

    Write-Warning "  构建参数："
    Write-Host "    - MODELS_DEV_API_JSON = $env:MODELS_DEV_API_JSON" -ForegroundColor Gray
    Write-Host "    - OPENCODE_DISABLE_MODELS_FETCH = 1" -ForegroundColor Gray
    Write-Host ""

    $buildStartTime = Get-Date
    Write-Warning "  正在构建（可能需要几分钟）..."

    try {
        Push-Location $PROJECT_ROOT
        bun $BUILD_SCRIPT --single 2>&1 | Tee-Object -Variable buildOutput
        $buildExitCode = $LASTEXITCODE
        Pop-Location

        if ($buildExitCode -ne 0) {
            Write-Error "  构建失败，退出码: $buildExitCode"
            Write-Warning "查看上方错误信息"
            exit 1
        }

        $buildDuration = ((Get-Date) - $buildStartTime).TotalSeconds
        Write-Success "  ✓ 构建成功 (用时: $([math]::Round($buildDuration, 1)) 秒)"
    } catch {
        Write-Error "  构建异常: $_"
        exit 1
    }
    Write-Host ""

    # ========== 步骤 5: 打包 ==========
    $currentStep++
    Write-Step "打包发布文件..." $currentStep $totalSteps

    # 检查构建产物
    if (-not (Test-Path $DIST_DIR)) {
        Write-Error "错误：找不到构建产物 $DIST_DIR"
        exit 1
    }

    Write-Warning "  复制文件到发布目录..."
    Copy-Item -Recurse -Force "$DIST_DIR\*" "$RELEASE_DIR\"
    Write-Success "  ✓ 文件已复制"

    # 复制 api.json（用于用户更新）
    Write-Warning "  添加模型数据文件..."
    Copy-Item $MODELS_DEV_API_JSON "$RELEASE_DIR\models.json"
    Write-Success "  ✓ models.json 已添加"

    # 创建 README
    Write-Warning "  生成 README.md..."
    $readmeContent = @"
# OpenCode - 内网版 v$Version

## 🚀 快速开始

\`\`\`powershell
# 直接运行，无需配置环境变量
.\bin\opencode.exe

# TUI 模式（交互式界面）
.\bin\opencode.exe .

# CLI 模式（一次性任务）
.\bin\opencode.exe run "帮我写一个排序函数"
\`\`\`

## ⚙️ 配置 API Key

在当前目录创建 \`opencode.json\` 文件：

\`\`\`json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "your-provider/your-model-name",
  "provider": {
    "your-provider": {
      "options": {
        "apiKey": "你的API-Key",
        "baseURL": "https://your-api.com/v1"
      }
    }
  }
}
\`\`\`

### 常用提供商配置示例

**公司内部 API：**
\`\`\`json
{
  "model": "company/model-name",
  "provider": {
    "company": {
      "options": {
        "apiKey": "sk-xxx",
        "baseURL": "https://api.company.com/v1"
      }
    }
  }
}
\`\`\`

**OpenAI 兼容：**
\`\`\`json
{
  "model": "openai/gpt-4o",
  "provider": {
    "openai": {
      "options": {
        "apiKey": "sk-xxx",
        "baseURL": "https://api.openai.com/v1"
      }
    }
  }
}
\`\`\`

## ✨ 特性

- ✅ 已内置模型列表（无需联网访问 models.dev）
- ✅ 开箱即用，无需配置环境变量
- ✅ 支持 75+ LLM 提供商
- ✅ 支持自定义提供商和模型

## 📚 常用命令

\`\`\`powershell
# 查看帮助
.\bin\opencode.exe --help

# 查看版本
.\bin\opencode.exe --version

# 查看模型列表
.\bin\opencode.exe models

# 启动 API 服务器
.\bin\opencode.exe serve

# 启动 Web 界面
.\bin\opencode.exe web

# 连接到远程服务器
.\bin\opencode.exe attach http://localhost:4096
\`\`\`

## 🔄 更新模型列表

本版本已预置模型列表（基于 models.dev）。如需更新：

1. 从外网下载最新的 \`api.json\`
2. 替换当前目录的 \`models.json\` 文件
3. 重启 OpenCode

或者从以下地址下载：
- https://models.dev/api.json

## 📖 使用技巧

### TUI 模式快捷键

- \`Ctrl+M\` - 打开模型列表
- \`Ctrl+P\` - 打开命令列表
- \`Ctrl+A\` - 打开提供商列表
- \`Tab\` - 切换 Agent
- \`Ctrl+C\` - 退出

### CLI 模式

\`\`\`powershell
# 基本用法
.\bin\opencode.exe run "你的任务"

# 指定模型
.\bin\opencode.exe run "任务" -m provider/model

# 继续上一次会话
.\bin\opencode.exe run "继续" -c

# 使用命令
.\bin\opencode.exe run --command commit "提交代码"
\`\`\`

## ❓ 常见问题

**Q: 提示找不到模型？**
A: 检查 \`opencode.json\` 中的 \`model\` 字段是否正确。

**Q: API 请求失败？**
A: 检查网络连接和 API Key 是否正确。

**Q: 如何查看详细日志？**
A: 添加 \`--print-logs\` 参数：\`.\bin\opencode.exe --print-logs\`

## 📞 技术支持

遇到问题请联系：your-email@company.com

---

**版本：** v$Version
**构建日期：** $(Get-Date -Format "yyyy-MM-dd")
**内网专用版本**
"@

    $readmeContent | Out-File -FilePath "$RELEASE_DIR\README.md" -Encoding UTF8
    Write-Success "  ✓ README.md 已生成"
    Write-Host ""

    # ========== 步骤 6: 压缩打包 ==========
    $currentStep++
    Write-Step "创建压缩包..." $currentStep $totalSteps

    Write-Warning "  正在压缩（可能需要几分钟）..."
    try {
        Compress-Archive -Path "$RELEASE_DIR\*" -DestinationPath $ZIP_FILE -CompressionLevel Optimal
        Write-Success "  ✓ 压缩完成"
    } catch {
        Write-Error "  压缩失败: $_"
        exit 1
    }

    $zipSize = Get-FileSize $ZIP_FILE
    Write-Host ""
    Write-Success "===================================="
    Write-Success "  构建完成！"
    Write-Success "===================================="
    Write-Host ""
    Write-Info "输出文件："
    Write-Host "  📦 $ZIP_FILE ($zipSize)" -ForegroundColor White
    Write-Host "  📁 $RELEASE_DIR" -ForegroundColor White
    Write-Host ""
    Write-Info "版本信息："
    Write-Host "  版本: v$Version" -ForegroundColor White
    Write-Host "  日期: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "  模型数据: 已内置 $(Get-FileSize $MODELS_DEV_API_JSON)" -ForegroundColor White
    Write-Host ""
    Write-Success "✅ 特点："
    Write-Host "  - 已内置模型列表（models.dev）" -ForegroundColor Green
    Write-Host "  - 无需配置环境变量" -ForegroundColor Green
    Write-Host "  - 开箱即用" -ForegroundColor Green
    Write-Host "  - 适合内网环境" -ForegroundColor Green
    Write-Host ""

    # ========== 验证提示 ==========
    Write-Info "💡 提示："
    Write-Host "  1. 测试运行：" -ForegroundColor Cyan
    Write-Host "     cd $RELEASE_DIR\bin" -ForegroundColor Gray
    Write-Host "     .\opencode.exe --version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. 查看模型列表：" -ForegroundColor Cyan
    Write-Host "     .\opencode.exe models" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. 分发给用户：" -ForegroundColor Cyan
    Write-Host "     上传 $ZIP_FILE 到内部平台" -ForegroundColor Gray
    Write-Host ""
}

# ========== 执行主程序 ==========
try {
    Main
    exit 0
} catch {
        Write-Error "构建失败: $_"
        Write-Error $_.ScriptStackTrace
        exit 1
}
