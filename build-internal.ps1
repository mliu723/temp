<#
.SYNOPSIS
    OpenCode 内网版构建脚本
.DESCRIPTION
    构建内网版本，内置模型列表，无需联网
.PARAMETER Version
    版本号（默认：1.0.0）
.PARAMETER SkipDownload
    跳过下载 api.json（如果已有文件）
.EXAMPLE
    .\build-internal.ps1
.EXAMPLE
    .\build-internal.ps1 -Version "2.0.0" -SkipDownload
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Version = "1.0.0",

    [Parameter(Mandatory = $false)]
    [switch]$SkipDownload = $false
)

# 错误时停止
$ErrorActionPreference = "Stop"

# 配置
$API_URL = "https://models.dev/api.json"
$API_FILE = "api.json"
$RELEASE_DIR = "release"
$ZIP_FILE = "opencode-internal-v$Version.zip"

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  OpenCode 内网版构建 v$Version" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# ========== 准备 api.json ==========
Write-Host "[1/5] 准备模型数据..." -ForegroundColor Yellow

if (-not (Test-Path $API_FILE)) {
    if ($SkipDownload) {
        Write-Host "  错误: 找不到 $API_FILE" -ForegroundColor Red
        exit 1
    }
    Write-Host "  下载 api.json..." -ForegroundColor Gray
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $API_URL -OutFile $API_FILE -UseBasicParsing
        $ProgressPreference = 'Continue'
        Write-Host "  下载完成" -ForegroundColor Green
    } catch {
        Write-Host "  下载失败: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  使用已有 api.json" -ForegroundColor Green
}

# ========== 检查 Bun ==========
Write-Host "[2/5] 检查构建环境..." -ForegroundColor Yellow
try {
    $bunVersion = bun --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Bun: $bunVersion" -ForegroundColor Green
    } else {
        throw "Bun 未安装"
    }
} catch {
    Write-Host "  错误: 未找到 Bun，请先安装" -ForegroundColor Red
    Write-Host "  安装方法: powershell -c `"irm bun.sh/install.ps1|iex`"" -ForegroundColor Gray
    exit 1
}

# ========== 设置环境变量 ==========
Write-Host "[3/5] 设置环境变量..." -ForegroundColor Yellow
$apiJsonPath = (Resolve-Path $API_FILE).Path
$env:MODELS_DEV_API_JSON = $apiJsonPath
$env:OPENCODE_DISABLE_MODELS_FETCH = "1"
Write-Host "  MODELS_DEV_API_JSON = $apiJsonPath" -ForegroundColor Gray

# ========== 清理旧版本 ==========
Write-Host "[4/5] 清理旧版本..." -ForegroundColor Yellow
if (Test-Path $RELEASE_DIR) {
    Remove-Item -Recurse -Force $RELEASE_DIR
    Write-Host "  已删除旧目录" -ForegroundColor Green
}
if (Test-Path $ZIP_FILE) {
    Remove-Item $ZIP_FILE
}
New-Item -ItemType Directory -Path $RELEASE_DIR -Force | Out-Null

# ========== 构建 ==========
Write-Host "[5/5] 构建中（可能需要几分钟）..." -ForegroundColor Yellow
$buildScript = "packages\opencode\script\build.ts"

if (-not (Test-Path $buildScript)) {
    Write-Host "  错误: 找不到 $buildScript" -ForegroundColor Red
    Write-Host "  请确保在项目根目录运行此脚本" -ForegroundColor Gray
    exit 1
}

bun $buildScript --single 2>&1 | Tee-Object -Variable buildOutput
if ($LASTEXITCODE -ne 0) {
    Write-Host "  构建失败" -ForegroundColor Red
    exit 1
}
Write-Host "  构建成功" -ForegroundColor Green

# ========== 打包 ==========
Write-Host "打包发布文件..." -ForegroundColor Yellow

# 检查构建产物
$distDir = "packages\opencode\dist\opencode-windows-x64"
if (-not (Test-Path $distDir)) {
    Write-Host "  错误: 找不到构建产物 $distDir" -ForegroundColor Red
    exit 1
}

# 复制文件
Copy-Item -Recurse -Force "$distDir\*" "$RELEASE_DIR\"
Write-Host "  已复制可执行文件" -ForegroundColor Green

# 复制模型数据
Copy-Item $API_FILE "$RELEASE_DIR\models.json"
Write-Host "  已添加 models.json" -ForegroundColor Green

# 创建 README
$readmeContent = @"
# OpenCode 内网版 v$Version

## 快速开始

```powershell
.\bin\opencode.exe
```

## 配置 API Key

在当前目录创建 `opencode.json`：

```json
{
  "model": "your-provider/your-model",
  "provider": {
    "your-provider": {
      "options": {
        "apiKey": "your-key",
        "baseURL": "https://your-api.com/v1"
      }
    }
  }
}
```

## 常用命令

```powershell
.\bin\opencode.exe --help
.\bin\opencode.exe models
.\bin\opencode.exe serve
```

## 更新模型列表

本版本已预置模型列表。如需更新：

1. 从外网下载最新的 `api.json`
2. 替换当前目录的 `models.json`
3. 重启 OpenCode
"@

$readmeContent | Out-File "$RELEASE_DIR\README.md" -Encoding UTF8
Write-Host "  已生成 README.md" -ForegroundColor Green

# 压缩
Write-Host "创建压缩包..." -ForegroundColor Yellow
Compress-Archive -Path "$RELEASE_DIR\*" -DestinationPath $ZIP_FILE

# ========== 完成 ==========
Write-Host ""
Write-Host "====================================" -ForegroundColor Green
Write-Host "  构建完成！" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""
Write-Host "输出文件:" -ForegroundColor Cyan
Write-Host "  $ZIP_FILE" -ForegroundColor White

$size = [math]::Round((Get-Item $ZIP_FILE).Length / 1MB, 2)
Write-Host ""
Write-Host "文件大小: $size MB" -ForegroundColor Gray
Write-Host ""
Write-Host "测试运行:" -ForegroundColor Cyan
Write-Host "  cd $RELEASE_DIR\bin" -ForegroundColor Gray
Write-Host "  .\opencode.exe --version" -ForegroundColor Gray
Write-Host ""
