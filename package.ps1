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
if (-not (Test-Path $apiJsonPath)) {
    Write-Host "错误: 找不到 C:\api.json 文件" -ForegroundColor Red
    Write-Host ""
    Write-Host "请按以下步骤操作："
    Write-Host "1. 将 api.json 文件复制到 C 盘根目录"
    Write-Host "2. 确保文件名为: C:\api.json"
    Write-Host "3. 重新运行此脚本"
    exit 1
}

$fileSize = [math]::Round((Get-Item $apiJsonPath).Length / 1MB, 2)
Write-Host "找到 api.json: $fileSize MB" -ForegroundColor Green
Write-Host ""

# 验证 JSON 是否有效
try {
    $null = Get-Content $apiJsonPath | ConvertFrom-Json
    Write-Host "JSON 文件验证通过" -ForegroundColor Green
} catch {
    Write-Host "错误: api.json 文件格式无效" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 设置环境变量，使用本地 file:// URL
$env:OPENCODE_MODELS_URL = "file:///C:/"

Write-Host "开始构建..." -ForegroundColor Cyan
Push-Location "$ScriptDir\packages\opencode"

bun run script/build.ts --single

if ($LASTEXITCODE -ne 0) {
    Write-Host "构建失败" -ForegroundColor Red
    Pop-Location
    Remove-Item Env:OPENCODE_MODELS_URL
    exit 1
}

Pop-Location

# 清理环境变量
Remove-Item Env:OPENCODE_MODELS_URL

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

# 复制构建产物
$distPath = "$ScriptDir\packages\opencode\dist"
if (Test-Path $distPath) {
    Copy-Item -Path "$distPath\*" -Destination "$tempDir\cli\" -Recurse -Force
}

# 创建安装说明
@"
# OpenCode CLI 安装说明 (Windows)

## 快速安装

1. 解压此文件
2. 进入 cli\opencode-windows-x64\bin 目录
3. 运行 opencode.exe

## 添加到 PATH (推荐)

1. 创建目录: C:\Tools\opencode
2. 复制 opencode.exe 到该目录
3. 将 C:\Tools\opencode 添加到系统 PATH
4. 重新打开命令提示符

## 离线使用

本版本已内置完整的模型配置，可在受限网络中使用。

如需禁用网络请求，设置环境变量:
`$env:OPENCODE_DISABLE_MODELS_FETCH=1

## 配置 API Key

运行: opencode auth login

版本: $Version
构建时间: $Timestamp
"@ | Out-File -FilePath "$tempDir\INSTALL.md" -Encoding UTF8

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
Write-Host "==========================================" -ForegroundColor Cyan
