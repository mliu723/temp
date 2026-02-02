# OpenCode 打包指南 - Windows 环境

本文档专门针对 Windows 环境下的打包和使用说明。

## 前提条件

### 1. 安装 Bun

在 PowerShell 中运行：
```powershell
irm bun.sh/install.ps1 | iex
```

验证安装：
```powershell
bun --version
```

### 2. 安装 Git

下载并安装 Git for Windows: https://git-scm.com/download/win

验证安装：
```powershell
git --version
```

### 3. 配置 PowerShell 执行策略（如果需要）

如果遇到"无法加载文件，因为在此系统上禁止运行脚本"错误：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Windows 离线打包完整流程

### 步骤 1: 获取 api.json 文件

**在有网络的环境中：**

```powershell
# 方法 1: 直接下载
Invoke-WebRequest -Uri "https://models.dev/api.json" -OutFile "api.json"

# 方法 2: 使用 curl（Windows 10 1803+ 自带）
curl -o api.json https://models.dev/api.json

# 方法 3: 从已有 OpenCode 安装导出
Copy-Item "$env:LOCALAPPDATA\opencode\models.json" -Destination "api.json"
```

### 步骤 2: 克隆或复制项目代码

将整个 OpenCode 项目复制到 Windows 机器上。

### 步骤 3: 运行打包脚本

在项目根目录打开 PowerShell：

```powershell
# 只打包 CLI（推荐，最快）
.\package.ps1 --models-api-json api.json --skip-web --skip-desktop

# 或者打包所有组件
.\package.ps1 --models-api-json api.json
```

### 步骤 4: 获取打包产物

打包完成后，会在项目根目录生成一个 `.tar.gz` 文件，例如：
```
opencode-bundle-1.1.47-20260202-143052.tar.gz
```

## 分发给 Windows 用户

### 方法 1: 直接复制

通过 U 盘、网络共享或内网文件服务器分发 `.tar.gz` 文件。

### 方法 2: 使用 Windows 共享文件夹

```powershell
# 复制到共享文件夹
Copy-Item "opencode-bundle-*.tar.gz" -Destination "\\server\share\"
```

## Windows 用户如何使用

### 解压文件

**使用 PowerShell:**
```powershell
# Windows 10 1803+ 自带 tar
tar -xzf opencode-bundle-*.tar.gz

# 或者使用 7-Zip
# 右键 → 7-Zip → 提取到 "opencode-bundle\"
```

**或手动解压:**
- 右键点击 `.tar.gz` 文件
- 选择"解压缩到新文件夹"

### 安装 CLI 工具

```powershell
# 进入解压后的目录
cd dist-package\cli\opencode-windows-x64\bin

# 测试运行
.\opencode.exe --version

# 添加到 PATH（推荐）
# 1. 创建安装目录，例如 C:\Tools\opencode
New-Item -ItemType Directory -Path "C:\Tools\opencode" -Force
Copy-Item ".\opencode.exe" -Destination "C:\Tools\opencode\"

# 2. 添加到系统 PATH
# - 右键"此电脑" → "属性" → "高级系统设置" → "环境变量"
# - 在"用户变量"中找到 Path，点击"编辑"
# - 点击"新建"，添加 C:\Tools\opencode
# - 确定并保存

# 3. 重新打开 PowerShell，现在可以直接运行
opencode --version
```

### 配置离线模式

创建一个批处理文件 `opencode.bat`:
```batch
@echo off
setlocal
set OPENCODE_DISABLE_MODELS_FETCH=1
opencode.exe %*
endlocal
```

或者设置系统环境变量：
1. 右键"此电脑" → "属性"
2. "高级系统设置" → "环境变量"
3. 新建用户变量：
   - 变量名: `OPENCODE_DISABLE_MODELS_FETCH`
   - 变量值: `1`

### 配置 API Key

**方法 1: 使用命令行（推荐）**
```powershell
opencode auth login
# 按提示选择提供商和输入 API Key
```

**方法 2: 手动创建配置文件**
```powershell
# 配置目录
$configDir = "$env:LOCALAPPDATA\opencode"
New-Item -ItemType Directory -Path $configDir -Force

# 创建 auth.json
@{
    openai = @{
        type = "api"
        key = "sk-your-openai-api-key"
    }
    anthropic = @{
        type = "api"
        key = "sk-ant-your-anthropic-api-key"
    }
} | ConvertTo-Json -Depth 10 | Out-File "$configDir\auth.json" -Encoding utf8
```

**方法 3: 使用环境变量**
```powershell
# 临时设置（当前会话）
$env:OPENAI_API_KEY="sk-your-key"
$env:ANTHROPIC_API_KEY="sk-ant-your-key"

# 永久设置（系统环境变量）
[System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', 'sk-your-key', 'User')
```

### 验证安装

```powershell
# 检查版本
opencode --version

# 查看已配置的凭据
opencode auth list

# 测试运行
opencode
```

## 常见问题 (Windows)

### 1. PowerShell 执行策略错误

**错误**: 无法加载文件 package.ps1，因为在此系统上禁止运行脚本

**解决**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. 找不到 tar 命令

**解决方案**:
- 方案 1: 升级到 Windows 10 1803 或更高版本
- 方案 2: 安装 7-Zip: https://www.7-zip.org/
- 方案 3: 使用 WSL (Windows Subsystem for Linux)

### 3. 中文路径问题

**问题**: 路径包含中文导致构建失败

**解决**:
- 确保项目路径不包含中文字符
- 建议使用: `C:\Projects\opencode` 而不是 `C:\项目\opencode`

### 4. 防火墙/杀毒软件拦截

**解决**:
- 临时禁用杀毒软件
- 或将以下目录添加到白名单：
  - 项目目录
  - Bun 安装目录（通常在 `%LOCALAPPDATA%\bun`）
  - `%LOCALAPPDATA%\opencode`

### 5. Windows Terminal 字符显示问题

**解决**:
```powershell
# 设置 PowerShell UTF-8 编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001
```

## 企业内网部署建议

### 1. 创建安装包

将解压后的文件打包成安装程序：
- 使用 Inno Setup: https://jrsoftware.org/isdl.php
- 或 NSIS: https://nsis.sourceforge.io/

### 2. 部署到共享文件夹

```powershell
# 复制到公司内网共享
$sharePath = "\\company-server\software\opencode"
New-Item -ItemType Directory -Path $sharePath -Force
Copy-Item "dist-package\*" -Destination $sharePath -Recurse
```

### 3. 创建用户配置脚本

`configure-opencode.ps1`:
```powershell
# 设置离线模式
[System.Environment]::SetEnvironmentVariable('OPENCODE_DISABLE_MODELS_FETCH', '1', 'User')

# 添加到 PATH（需要管理员权限）
$installPath = "C:\Tools\opencode"
$existingPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($existingPath -notlike "*$installPath*") {
    [Environment]::SetEnvironmentVariable('Path', "$existingPath;$installPath", 'User')
}

Write-Host "OpenCode 已配置完成！" -ForegroundColor Green
Write-Host "请运行 opencode auth login 配置 API Key"
```

## 技术支持

- 项目主页: https://github.com/anomalyco/opencode
- 文档: https://opencode.ai
- 问题反馈: https://github.com/anomalyco/opencode/issues
