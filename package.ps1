#!/usr/bin/env pwsh
# OpenCode CLI 打包脚本 (Windows 精简版)
# 用途：只打包 CLI 工具

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$Version = (Get-Content "$ScriptDir\packages\opencode\package.json" | ConvertFrom-Json).version
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputFile = "$ScriptDir\opencode-cli-$Version-$Timestamp.tar.gz"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OpenCode CLI 打包脚本 (Windows)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 检查参数
if ($args.Count -eq 0 -or $args[0] -eq "--help") {
    Write-Host "用法: .\package.ps1 <api.json路径>"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\package.ps1 api.json"
    exit 0
}

$apiJsonPath = $args[0]

if (-not (Test-Path $apiJsonPath)) {
    Write-Host "错误: 找不到 api.json 文件: $apiJsonPath" -ForegroundColor Red
    exit 1
}

Write-Host "使用 api.json: $apiJsonPath" -ForegroundColor Green
Write-Host ""

# 设置环境变量
$env:MODELS_DEV_API_JSON = $apiJsonPath

# 构建
Write-Host "开始构建..." -ForegroundColor Cyan
Push-Location "$ScriptDir\packages\opencode"

bun run script/build.ts --single

if ($LASTEXITCODE -ne 0) {
    Write-Host "构建失败" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

# 清理环境变量
Remove-Item Env:MODELS_DEV_API_JSON

Write-Host "构建成功!" -ForegroundColor Green
Write-Host ""

# 打包
Write-Host "打包中..." -ForegroundColor Cyan
$tempDir = "$ScriptDir\dist-package-temp"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path "$tempDir\cli" -Force | Out-Null

# 复制构建产物
$distPath = "$ScriptDir\packages\opencode\dist"
if (Test-Path $distPath) {
    Copy-Item -Path "$distPath\*" -Destination "$tempDir\cli\" -Recurse -Force
}

# 创建简化的安装说明
@"
# OpenCode CLI 安装说明 (Windows)

## 快速安装

1. 解压此文件
2. 进入对应平台的 bin 目录
3. 运行 opencode.exe

## 添加到 PATH

1. 复制 opencode.exe 到 C:\Tools\opencode\
2. 将 C:\Tools\opencode 添加到系统 PATH
3. 重新打开命令提示符

## 离线模式

设置环境变量:
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

# 清理临时目录
Remove-Item -Path $tempDir -Recurse -Force

# 显示结果
$fileSize = [math]::Round((Get-Item $OutputFile).Length / 1MB, 2)

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "打包完成!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "文件: $OutputFile"
Write-Host "大小: $fileSize MB"
Write-Host "==========================================" -ForegroundColor Cyan
