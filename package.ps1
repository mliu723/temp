#!/usr/bin/env pwsh
# OpenCode CLI 打包脚本 (直接使用 snapshot)
# 从现有 snapshot 提取 JSON，无需 api.json

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$Version = (Get-Content "$ScriptDir\packages\opencode\package.json" | ConvertFrom-Json).version
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputFile = "$ScriptDir\opencode-cli-$Version-$Timestamp.tar.gz"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OpenCode CLI 打包 (使用现有 snapshot)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$snapshotPath = "$ScriptDir\packages\opencode\src\provider\models-snapshot.ts"
if (-not (Test-Path $snapshotPath)) {
    Write-Host "错误: 找不到 models-snapshot.ts" -ForegroundColor Red
    exit 1
}

$fileSize = [math]::Round((Get-Item $snapshotPath).Length / 1KB, 2)
Write-Host "找到 snapshot 文件: $fileSize KB" -ForegroundColor Green
Write-Host ""

# 从 snapshot 文件中提取 JSON 数据
$snapshotContent = Get-Content $snapshotPath -Raw
if ($snapshotContent -match 'export const snapshot = ({.+}) as const') {
    $jsonData = $matches[1]

    # 创建临时 api.json 文件
    $tempApiJson = "$ScriptDir\temp-api.json"
    $jsonData | Out-File -FilePath $tempApiJson -Encoding UTF8

    Write-Host "从 snapshot 提取 JSON 数据" -ForegroundColor Green
    Write-Host ""

    # 设置环境变量
    $env:MODELS_DEV_API_JSON = $tempApiJson

    Write-Host "开始构建..." -ForegroundColor Cyan
    Push-Location "$ScriptDir\packages\opencode"

    bun run script/build.ts --single

    if ($LASTEXITCODE -ne 0) {
        Write-Host "构建失败" -ForegroundColor Red
        Pop-Location
        Remove-Item $tempApiJson -Force -ErrorAction SilentlyContinue
        Remove-Item Env:MODELS_DEV_API_JSON
        exit 1
    }

    Pop-Location

    # 清理
    Remove-Item $tempApiJson -Force -ErrorAction SilentlyContinue
    Remove-Item Env:MODELS_DEV_API_JSON

} else {
    Write-Host "错误: 无法从 snapshot 文件提取 JSON 数据" -ForegroundColor Red
    exit 1
}

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
