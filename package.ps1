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
$launcherContent = @"
@echo off
REM OpenCode 配置和启动脚本
REM 双击此文件开始配置或启动 OpenCode

setlocal EnableDelayedExpansion

echo ==========================================
echo OpenCode CLI - 配置和启动
echo ==========================================
echo.

REM 检查并创建配置文件
set "CONFIG_DIR=%USERPROFILE%\.config\opencode"
set "CONFIG_FILE=!CONFIG_DIR!\opencode.json"

if not exist "!CONFIG_FILE!" (
    echo [初始化] 正在创建配置文件...
    echo.

    REM 创建配置目录
    if not exist "!CONFIG_DIR!" (
        mkdir "!CONFIG_DIR!"
    )

    REM 写入默认配置文件
    (
        echo {
        echo   "\`$schema": "https://opencode.ai/config.json",
        echo   "provider": {
        echo     "anthropic": {
        echo       "options": {
        echo         "apiKey": "你的-API-Key"
        echo       }
        echo     }
        echo   },
        echo   "model": "anthropic/claude-sonnet-4-5-20250929",
        echo   "// 只启用指定的 providers（可选）": "",
        echo   "// 如果只想使用自定义的 API，取消下面这行的注释，并添加你的 provider ID": "",
        echo   "// \"enabled_providers\": [\"your-custom-provider\"],": "",
        echo   "// 或者禁用默认 providers（可选）": "",
        echo   "// \"disabled_providers\": [\"anthropic\", \"openai\", \"google\"],": "",
        echo   "// 其他配置选项请参考: https://opencode.ai/config.json": ""
    echo }
    ) > "!CONFIG_FILE!"

    echo [成功] 配置文件已创建: !CONFIG_FILE!
    echo.
    echo 注意: 配置文件中的 apiKey 只是示例
    echo 你需要运行 'opencode auth login' 来配置真实的 API Key
    echo 或者手动编辑配置文件替换 API Key
    echo.
    pause
    cls
)

REM 检查是否已配置凭证
opencode auth list >nul 2>&1
if errorlevel 1 (
    echo [1] 首次使用 - 需要配置 API Key
    echo.
    echo 即将启动配置向导...
    echo.
    pause
    echo.
    opencode auth login
    echo.
    echo 配置完成！按任意键启动 OpenCode...
    pause >nul
    opencode
) else (
    echo [2] 已配置 - 启动选项
    echo.
    echo   1. 启动 OpenCode TUI
    echo   2. 重新配置 API Key
    echo   3. 查看当前配置
    echo   4. 打开配置文件
    echo   5. 退出
    echo.
    choice /c 12345 /n /m "请选择 (1-5): "

    if errorlevel 5 goto :eof
    if errorlevel 4 (
        echo.
        echo 正在打开配置文件...
        start "" "!CONFIG_FILE!"
        echo.
        pause
        goto :start
    )
    if errorlevel 3 (
        cls
        opencode auth list
        echo.
        pause
        goto :start
    )
    if errorlevel 2 (
        cls
        opencode auth login
        echo.
        echo 配置完成！按任意键启动 OpenCode...
        pause >nul
        opencode
        goto :eof
    )
    if errorlevel 1 (
        opencode
        goto :eof
    )
)

:start
"@

# 将启动脚本放到 bin 目录
$binDir = "$tempDir\cli\opencode-windows-x64\bin"
if (Test-Path $binDir) {
    $launcherContent | Out-File -FilePath "$binDir\启动opencode.bat" -Encoding default
    $launcherContent | Out-File -FilePath "$binDir\opencode-launcher.bat" -Encoding default
}

# 创建配置文件示例到根目录（供用户参考）
@"
# OpenCode 配置文件示例
#
# 使用方法：
# 1. 将此文件复制到: %USERPROFILE%\.config\opencode\opencode.json
# 2. 或者运行"启动opencode.bat"，会自动创建基础配置文件
# 3. 修改 apiKey 为你的实际 API Key
#
# 配置文档: https://opencode.ai/config.json

{
  "\`$schema": "https://opencode.ai/config.json",

  // ========== AI Provider 配置 ==========
  "provider": {
    // Anthropic Claude (推荐)
    "anthropic": {
      "options": {
        "apiKey": "sk-ant-your-api-key-here"
      }
    },

    // OpenAI GPT
    // "openai": {
    //   "options": {
    //     "apiKey": "sk-your-openai-key-here"
    //   }
    // },

    // Google Gemini
    // "google": {
    //   "options": {
    //     "apiKey": "your-google-api-key-here"
    //   }
    // }
  },

  // 默认使用的模型
  "model": "anthropic/claude-sonnet-4-5-20250929",

  // 小模型（用于标题生成等简单任务）
  "small_model": "anthropic/claude-haiku-4-5-20250108",

  // ========== Provider 过滤配置 ==========

  // 只启用指定的 providers（忽略所有默认的）
  // 取消注释并添加你想要的 provider IDs
  // "enabled_providers": ["anthropic", "my-custom-api"],

  // 禁用指定的 providers
  // "disabled_providers": ["openai", "google", "copilot"],

  // ========== 其他可选配置 ==========

  // 用户名（显示在对话中）
  // "username": "YourName",

  // 主题
  // "theme": "dark",

  // 日志级别
  // "logLevel": "info",

  // 自动分享会话
  // "share": "manual",

  // Agent 配置
  // "agent": {
  //   "build": {
  //     "description": "用于编写和修改代码",
  //     "model": "anthropic/claude-sonnet-4-5-20250929"
  //   },
  //   "plan": {
  //     "description": "用于规划和设计",
  //     "model": "anthropic/claude-sonnet-4-5-20250929"
  //   }
  // }
}
"@ | Out-File -FilePath "$tempDir\opencode.json.example" -Encoding UTF8


# 创建根目录 README
@"
# OpenCode CLI

欢迎使用 OpenCode - AI 驱动的开发助手！

## 快速开始

### 🚀 最简单的方式（推荐）

1. 双击 `cli\opencode-windows-x64\bin\启动opencode.bat`
2. 首次运行会自动创建配置文件
3. 按提示配置你的 API Key
4. 开始使用！

### 📝 配置说明

- 配置文件位置: `C:\Users\你的用户名\.config\opencode\opencode.json`
- 首次运行启动脚本会自动创建基础配置文件
- 也可以参考根目录的 `opencode.json.example` 文件

### 📖 详细说明

请查看 `INSTALL.md` 获取完整的安装和配置说明。

## 文件说明

- `cli/` - OpenCode CLI 可执行文件
  - `opencode-windows-x64/bin/` - 可执行文件目录
    - `opencode.exe` - 主程序
    - `启动opencode.bat` - 快速启动脚本（推荐，自动创建配置）
    - `opencode-launcher.bat` - 英文版启动脚本
- `opencode.json.example` - 配置文件示例（供参考）
- `INSTALL.md` - 详细安装和使用说明

## 系统要求

- Windows 10 或更高版本
- 需要配置 AI Provider 的 API Key

## 支持的 AI Provider

- ✅ Anthropic Claude (推荐)
- ✅ OpenAI GPT-4/GPT-3.5
- ✅ Google Gemini
- ✅ 50+ 其他 Provider

## 获取 API Key

- **Anthropic**: https://opencode.ai/auth
- **OpenAI**: https://platform.openai.com/api-keys
- **Google**: https://makersuite.google.com/app/apikey

## 需要帮助？

- 📖 查看详细说明: `INSTALL.md`
- 🌐 官方文档: https://opencode.ai/docs
- 💻 GitHub: https://github.com/anomalyco/opencode

---

版本: $Version
构建时间: $Timestamp
"@ | Out-File -FilePath "$tempDir\README.md" -Encoding UTF8

# 创建安装说明
@"
# OpenCode CLI 安装说明 (Windows)

## 快速开始

### 方法1: 双击启动脚本（最简单）

1. 解压此文件
2. 进入 `cli\opencode-windows-x64\bin` 目录
3. **双击 `启动opencode.bat`**
4. **首次运行会自动创建配置文件** `C:\Users\你的用户名\.config\opencode\opencode.json`
5. 按提示配置 API Key
6. 配置完成后自动启动 OpenCode

这是最简单的方式，适合初学者！配置文件会自动创建，无需手动操作。

### 方法2: 使用命令行（推荐）

1. 解压此文件到任意目录，例如 `C:\Tools\opencode`
2. 打开命令提示符或 PowerShell，进入 `cli\opencode-windows-x64\bin` 目录
3. **配置 API Key**:

   \`\`\`powershell
   # 运行配置命令（推荐）
   .\opencode.exe auth login

   # 选择你的 Provider 并输入 API Key
   # 支持的 Provider:
   #   - anthropic (Claude)
   #   - openai (ChatGPT)
   #   - google (Gemini)
   #   - 或其他自定义 Provider
   \`\`\`

   凭证会自动保存到: \`C:\Users\你的用户名\\.local\\share\\opencode\\data\\auth.json\`

4. **启动 OpenCode**:

   \`\`\`powershell
   .\opencode.exe
   \`\`\`

### 方法3: 添加到系统 PATH（高级用户）

1. 创建目录: \`C:\Tools\\opencode\`
2. 复制整个 \`cli\\opencode-windows-x64\` 文件夹到该目录
3. 将 \`C:\Tools\\opencode\\opencode-windows-x64\\bin\` 添加到系统 PATH:
   - 右键"此电脑" → 属性 → 高级系统设置 → 环境变量
   - 在"用户变量"中找到"Path"，点击"编辑"
   - 添加新条目: \`C:\Tools\\opencode\\opencode-windows-x64\\bin\`
4. **重新打开命令提示符**（必须！），即可在任何目录运行:

   \`\`\`powershell
   # 配置 API Key
   opencode auth login

   # 启动 OpenCode
   opencode
   \`\`\`

## 配置说明

### 使用 opencode auth login

交互式配置命令，支持多种 Provider:

\`\`\`powershell
opencode auth login
\`\`\`

按提示选择:
- **anthropic**: Claude 系列（推荐）
- **openai**: GPT-4, GPT-3.5
- **google**: Gemini Pro
- **Other**: 自定义兼容 OpenAI API 的服务

### 配置文件说明

OpenCode 使用两种配置方式：

#### 方式1: 使用 auth 命令（推荐，自动管理）

运行 `opencode auth login` 后，凭证会自动保存到:
\`\`\`
C:\Users\你的用户名\.local\share\opencode\data\auth.json
\`\`\`

无需手动创建文件，最简单方便！

#### 方式2: 使用配置文件（高级用户）

配置文件位置（首次运行启动脚本会自动创建）:
\`\`\`
C:\Users\你的用户名\.config\opencode\opencode.json
\`\`\`

或者参考本目录的 \`opencode.json.example\` 文件，创建完整的配置文件：

\`\`\`json
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "sk-ant-your-api-key-here"
      }
    }
  },
  "model": "anthropic/claude-sonnet-4-5-20250929"
}
\`\`\`

### 自定义 Provider（高级）

如果你想**只使用自己的 API，禁用所有默认 providers**，可以使用以下配置：

\`\`\`json
{
  "\$schema": "https://opencode.ai/config.json",
  "enabled_providers": ["my-custom-api"],
  "provider": {
    "my-custom-api": {
      "name": "My Custom API",
      "api": "https://my-api.com/v1",
      "options": {
        "apiKey": "your-api-key"
      },
      "models": {
        "my-model": {
          "id": "my-model",
          "name": "My Custom Model",
          "release_date": "2024-01-01",
          "attachment": true,
          "tool_call": true,
          "temperature": true,
          "limit": {
            "context": 200000,
            "output": 8192
          }
        }
      }
    }
  },
  "model": "my-custom-api/my-model"
}
\`\`\`

或者只禁用特定的默认 providers：

\`\`\`json
{
  "disabled_providers": ["openai", "google", "copilot"]
}
\`\`\`

更多详情请参考: https://opencode.ai/docs/providers

或使用环境变量:

\`\`\`powershell
# 设置环境变量（当前会话）
\`$env:ANTHROPIC_API_KEY = \"sk-ant-your-key\"

# 永久设置
setx ANTHROPIC_API_KEY \"sk-ant-your-key\"
\`\`\`

## 常见问题

### Q: 直接双击 opencode.exe 没反应？
A: OpenCode 是命令行工具，需要通过命令行运行。请打开 PowerShell 或命令提示符。

### Q: 提示"没有可用的凭证"？
A: 需要先运行 \`opencode auth login\` 配置 API Key。

### Q: 配置文件在哪里？
A:
- **配置文件** (可选): \`C:\Users\你的用户名\\.config\\opencode\\opencode.json\`
- **凭证文件** (必需): \`C:\Users\你的用户名\\.local\\share\\opencode\\data\\auth.json\`

首次运行启动脚本会自动创建基础配置文件，或参考根目录的 \`opencode.json.example\`。

### Q: 如何修改配置？
A: 有三种方式:
1. 运行 \`启动opencode.bat\`，选择"打开配置文件"
2. 手动编辑 \`C:\Users\你的用户名\\.config\\opencode\\opencode.json\`
3. 使用环境变量 (临时): \`setx ANTHROPIC_API_KEY "your-key"\`

### Q: 支持哪些模型？
A: 本版本内置了完整的模型配置，支持:
- Claude (Sonnet 4.5, Opus 4.5, Haiku 4.5 等)
- GPT-4/GPT-3.5
- Gemini Pro
- 以及其他 50+ Provider

### Q: 如何查看当前配置？
A: 运行 \`opencode auth list\` 查看已配置的凭证。

### Q: 如何切换模型？
A:
1. 运行 \`opencode auth list\` 查看可用模型
2. 在 TUI 中按 \`F2\` 切换最近使用的模型
3. 或在配置文件中设置默认模型

## 离线使用

本版本已内置完整的模型配置（api.json），可在受限网络中使用。

**注意事项**:
- ✅ 内置模型列表，无需访问 models.dev
- ❌ 仍需要配置自己的 API Key 才能使用
- ✅ 支持 OpenAI 兼容的自定义 API

## 版本信息

版本: $Version
构建时间: $Timestamp
构建模式: 离线/内网版本

## 技术支持

- 文档: https://opencode.ai/docs
- GitHub: https://github.com/anomalyco/opencode
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
Write-Host ""
Write-Host "已排除不必要的文件:" -ForegroundColor DarkGray
Write-Host "  - package.json（开发文件，运行时不需要）" -ForegroundColor DarkGray
Write-Host "  - TypeScript 源码（*.ts, *.map）" -ForegroundColor DarkGray
Write-Host "  - README.md, LICENSE（重复文档）" -ForegroundColor DarkGray
Write-Host "  - 非 Windows 平台文件" -ForegroundColor DarkGray
Write-Host "==========================================" -ForegroundColor Cyan
