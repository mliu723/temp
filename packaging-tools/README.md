# OpenCode 打包工具集

这个文件夹包含了在离线/受限网络环境下打包 OpenCode 项目所需的所有脚本和文档。

## 📁 文件说明

### 打包脚本

| 文件 | 平台 | 说明 |
|------|------|------|
| `package.sh` | Linux/macOS | Bash 打包脚本 |
| `package.ps1` | Windows | PowerShell 打包脚本 |

### 文档

| 文件 | 说明 |
|------|------|
| `PACKAGING_README.md` | 通用打包指南（跨平台） |
| `PACKAGING_WINDOWS.md` | Windows 环境详细指南 |

## 🚀 快速开始

### 前提条件

1. **在有网络的环境中下载 api.json**:
   ```bash
   # Linux/macOS
   curl -O https://models.dev/api.json

   # Windows PowerShell
   Invoke-WebRequest -Uri "https://models.dev/api.json" -OutFile "api.json"
   ```

2. **将此文件夹和 api.json 复制到目标环境**

### Windows 环境（推荐）

```powershell
# 只打包 CLI（最快，推荐）
.\package.ps1 --models-api-json api.json --skip-web --skip-desktop

# 打包所有组件
.\package.ps1 --models-api-json api.json
```

### Linux/macOS 环境

```bash
# 只打包 CLI（最快，推荐）
./package.sh --models-api-json api.json --skip-web --skip-desktop

# 打包所有组件
./package.sh --models-api-json api.json
```

## 📦 使用场景

### 场景 1: 公司内网打包

适用于无法访问 models.dev 的企业内网环境。

**步骤**:
1. 在外部网络下载 api.json
2. 将打包工具和 api.json 复制到内网机器
3. 运行打包脚本

### 场景 2: 分发给内网用户

打包后的产物可以在完全离线的环境中使用。

**用户只需**:
1. 解压分发包
2. 设置环境变量 `OPENCODE_DISABLE_MODELS_FETCH=1`
3. 配置自己的 API Key

## 📖 详细文档

- **通用指南**: 查看 [PACKAGING_README.md](PACKAGING_README.md)
- **Windows 用户**: 查看 [PACKAGING_WINDOWS.md](PACKAGING_WINDOWS.md)

## 🔧 系统要求

### Windows
- Windows 10 1803 或更高版本
- PowerShell 5.1+
- Bun 1.3.5+
- Git

### Linux/macOS
- 任何主流 Linux 发行版或 macOS 11+
- Bash
- Bun 1.3.5+
- Git

## ⚠️ 重要提示

1. **api.json 文件**: 必须在有网络的环境中提前下载
2. **路径要求**: 脚本和 api.json 应在同一目录，或使用绝对路径
3. **权限要求**:
   - Windows: 可能需要设置 PowerShell 执行策略
   - Linux/macOS: 脚本需要执行权限 (`chmod +x package.sh`)

## 🆘 遇到问题？

### Windows
```powershell
# 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Linux/macOS
```bash
# 添加执行权限
chmod +x package.sh
```

查看详细文档获取更多帮助。

## 📋 输出说明

打包成功后会生成：
```
opencode-bundle-{version}-{timestamp}.tar.gz
```

包含：
- CLI 工具（可直接运行）
- 完整的安装说明（INSTALL.md）
- 离线模式配置指南

## 🔗 相关链接

- OpenCode 项目: https://github.com/anomalyco/opencode
- 官方文档: https://opencode.ai
- 问题反馈: https://github.com/anomalyco/opencode/issues

---

**版本**: 1.0
**更新日期**: 2025-02-02
**支持平台**: Windows 10+, Linux, macOS 11+
