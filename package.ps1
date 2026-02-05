#!/usr/bin/env pwsh
# OpenCode CLI 打包脚本 (使用本地 api.json)
# 无需从 models.dev 下载

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$Version = (Get-Content "$ScriptDir\packages\opencode\package.json" | ConvertFrom-Json).version
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputFile = "$ScriptDir\opencode-cli-$Version-$Timestamp.tar.gz"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OpenCode CLI 打包 (离线模式)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 api.json 是否存在
$apiJsonPath = "C:\api.json"

if (Test-Path $apiJsonPath) {
    $item = Get-Item $apiJsonPath
    if ($item.PSIsContainer) {
        Write-Host "错误: C:\api.json 是一个目录，不是文件" -ForegroundColor Red
        Write-Host ""
        Write-Host "请删除该目录或重命名，然后创建一个文件: C:\api.json"
        exit 1
    }

    $fileSize = [math]::Round($item.Length / 1MB, 2)
    Write-Host "找到 api.json: $fileSize MB" -ForegroundColor Green
} else {
    Write-Host "错误: 找不到 C:\api.json 文件" -ForegroundColor Red
    Write-Host ""
    Write-Host "请按以下步骤操作：" -ForegroundColor Yellow
    Write-Host "1. 将 api.json 文件复制到 C 盘根目录"
    Write-Host "2. 确保文件名为: C:\api.json (不是目录)"
    Write-Host "3. 重新运行此脚本"
    Write-Host ""
    Write-Host "或者，将 api.json 放在其他位置，然后修改脚本中的路径"
    exit 1
}

Write-Host ""

# 验证 JSON 是否有效
Write-Host "验证 JSON 文件..." -ForegroundColor Cyan
try {
    $null = Get-Content $apiJsonPath -Raw | ConvertFrom-Json
    Write-Host "JSON 文件验证通过" -ForegroundColor Green
} catch {
    Write-Host "错误: api.json 文件格式无效" -ForegroundColor Red
    Write-Host "请确保文件是完整的 JSON 格式"
    exit 1
}

Write-Host ""

# 将 api.json 复制到项目根目录，避免路径问题
Write-Host "准备构建文件..." -ForegroundColor Cyan
$localApiJson = "$ScriptDir\api.json"
Copy-Item $apiJsonPath -Destination $localApiJson -Force
Write-Host "已复制 api.json 到: $localApiJson" -ForegroundColor Green
Write-Host ""

Write-Host "开始构建..." -ForegroundColor Cyan
Push-Location "$ScriptDir\packages\opencode"

# 使用绝对路径的 MODELS_DEV_API_JSON
$env:MODELS_DEV_API_JSON = $localApiJson
$env:OPENCODE_DISABLE_MODELS_FETCH = "1"

Write-Host "环境变量 MODELS_DEV_API_JSON = $env:MODELS_DEV_API_JSON" -ForegroundColor DarkGray
bun run script/build.ts --single

if ($LASTEXITCODE -ne 0) {
    Write-Host "构建失败" -ForegroundColor Red
    Pop-Location
    Remove-Item $localApiJson -Force -ErrorAction SilentlyContinue
    exit 1
}

Pop-Location

# 清理
Remove-Item $localApiJson -Force -ErrorAction SilentlyContinue
Remove-Item Env:MODELS_DEV_API_JSON -ErrorAction SilentlyContinue
Remove-Item Env:OPENCODE_DISABLE_MODELS_FETCH -ErrorAction SilentlyContinue

Write-Host "构建成功!" -ForegroundColor Green
Write-Host ""

# 打包
Write-Host "打包中..." -ForegroundColor Cyan
$tempDir = "$ScriptDir\dist-package-temp"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path "$tempDir\cli" -Force | Out-Null

# 复制构建产物（只复制必要的文件）
$distPath = "$ScriptDir\packages\opencode\dist"
if (Test-Path $distPath) {
    # 只复制 Windows 平台文件夹（opencode-windows-x64）
    $windowsDirs = Get-ChildItem -Path $distPath -Directory | Where-Object { $_.Name -like "*windows*" }

    if ($windowsDirs) {
        foreach ($dir in $windowsDirs) {
            $targetDir = "$tempDir\cli\$($dir.Name)"
            Write-Host "  复制: $($dir.Name)" -ForegroundColor DarkGray
            Copy-Item -Path "$($dir.FullName)\*" -Destination "$targetDir\" -Recurse -Force

            # 删除不需要的文件
            $unwantedFiles = @(
                "package.json",
                "*.ts",
                "*.map",
                "README.md",
                "LICENSE",
                ".gitkeep"
            )

            foreach ($pattern in $unwantedFiles) {
                Remove-Item -Path "$targetDir\$pattern" -Recurse -Force -ErrorAction SilentlyContinue
            }

            # 递归删除 node_modules 中的文档文件
            Get-ChildItem -Path $targetDir -Recurse -Filter "README.md" | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path $targetDir -Recurse -Filter "LICENSE" | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        Write-Host "  已清理不必要的文件" -ForegroundColor Green
    } else {
        Write-Host "  警告: 未找到 Windows 平台的构建产物" -ForegroundColor Yellow
    }
}

# 创建便捷启动脚本
$launcherBat = @"
@echo off
setlocal EnableDelayedExpansion

REM 配置文件路径
set "CONFIG_DIR=%USERPROFILE%\.config\opencode"
set "CONFIG_FILE=!CONFIG_DIR!\opencode.json"

REM 自动创建配置文件（如果不存在）
if not exist "!CONFIG_FILE!" (
    echo 正在创建配置文件: !CONFIG_FILE!
    if not exist "!CONFIG_DIR!" mkdir "!CONFIG_DIR!"
    (
        echo {
        echo   "$schema": "https://opencode.ai/config.json",
        echo   "provider": {
        echo     "anthropic": {
        echo       "options": {
        echo         "apiKey": "你的-API-Key"
        echo       }
        echo     }
        echo   },
        echo   "model": "anthropic/claude-sonnet-4-5-20250929"
        echo }
    ) > "!CONFIG_FILE!"
    echo.
    echo 配置文件已创建！
    echo.
    echo 请按以下步骤操作：
    echo 1. 用记事本打开配置文件
    echo 2. 将 "你的-API-Key" 替换为真实的 API Key
    echo 3. 保存并关闭文件
    echo.
    choice /c YN /n /m "现在打开配置文件？(Y/N): "
    if errorlevel 2 goto :run
    start "" "!CONFIG_FILE!"
    echo.
    echo 修改完成后按任意键继续...
    pause >nul
)

:run
echo 启动 OpenCode...
opencode.exe
pause
"@

# 将启动脚本放到 bin 目录
$binDir = "$tempDir\cli\opencode-windows-x64\bin"
if (Test-Path $binDir) {
    $launcherBat | Out-File -FilePath "$binDir\opencode.bat" -Encoding default
}

# 创建 README
@"
# OpenCode CLI

## 快速开始

1. 进入 `cli\opencode-windows-x64\bin` 目录
2. **双击 `opencode.bat`**
3. 首次运行会自动创建配置文件 `C:\Users\你的用户名\.config\opencode\opencode.json`
4. 编辑配置文件，将 `你的-API-Key` 替换为真实的 API Key
5. 再次双击 `opencode.bat` 启动

## 配置文件位置

`C:\Users\你的用户名\.config\opencode\opencode.json`

## 获取 API Key

- Anthropic: https://opencode.ai/auth
- OpenAI: https://platform.openai.com/api-keys
- Google: https://makersuite.google.com/app/apikey

## 文档

https://opencode.ai/docs

---

版本: $Version
构建时间: $Timestamp
"@ | Out-File -FilePath "$tempDir\README.md" -Encoding UTF8

# 创建压缩包
Push-Location $ScriptDir
tar -czf $OutputFile -C $tempDir .
Pop-Location

# 清理
Remove-Item -Path $tempDir -Recurse -Force

# 显示结果
$resultSize = [math]::Round((Get-Item $OutputFile).Length / 1MB, 2)

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "打包完成!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "文件: $OutputFile"
Write-Host "大小: $resultSize MB"
Write-Host ""
Write-Host "已排除不必要的文件:" -ForegroundColor DarkGray
Write-Host "  - package.json（开发文件，运行时不需要）" -ForegroundColor DarkGray
Write-Host "  - TypeScript 源码（*.ts, *.map）" -ForegroundColor DarkGray
Write-Host "  - README.md, LICENSE（重复文档）" -ForegroundColor DarkGray
Write-Host "  - 非 Windows 平台文件" -ForegroundColor DarkGray
Write-Host "==========================================" -ForegroundColor Cyan
