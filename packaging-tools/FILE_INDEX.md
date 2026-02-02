# 文件清单

## 📋 packaging-tools 文件夹内容

### 🚀 打包脚本（核心文件）

| 文件名 | 平台 | 说明 | 使用方法 |
|--------|------|------|----------|
| `package.sh` | Linux/macOS | Bash 打包脚本 | `./package.sh --models-api-json api.json` |
| `package.ps1` | Windows | PowerShell 打包脚本 | `.\package.ps1 --models-api-json api.json` |

### 📖 文档

| 文件名 | 说明 | 适合人群 |
|--------|------|----------|
| `README.md` | 主文档，包含所有信息 | 所有用户 |
| `QUICKSTART.md` | 快速入门指南 | 新用户 |
| `PACKAGING_README.md` | 详细打包指南（跨平台） | 需要详细了解的用户 |
| `PACKAGING_WINDOWS.md` | Windows 环境详细指南 | Windows 用户 |
| `FILE_INDEX.md` | 本文件，文件清单 | 查看文件用途 |

### 🔧 辅助工具

| 文件名 | 平台 | 说明 | 使用方法 |
|--------|------|------|----------|
| `enable-offline-mode.bat` | Windows | 批处理脚本，设置离线模式 | 双击运行或 `enable-offline-mode.bat` |
| `enable-offline-mode.ps1` | Windows | PowerShell 脚本，设置离线模式 | `.\enable-offline-mode.ps1` |
| `enable-offline-mode.sh` | Linux/macOS | Shell 脚本，设置离线模式 | `./enable-offline-mode.sh` |

---

## 🎯 使用流程

### 第一步：准备 api.json

**在有网络的环境中：**
```bash
# Linux/macOS
curl -O https://models.dev/api.json

# Windows PowerShell
Invoke-WebRequest -Uri "https://models.dev/api.json" -OutFile "api.json"
```

### 第二步：打包

**将 `packaging-tools` 文件夹和 `api.json` 复制到目标环境，然后：**

**Windows:**
```powershell
cd packaging-tools
.\package.ps1 --models-api-json ..\api.json --skip-web --skip-desktop
```

**Linux/macOS:**
```bash
cd packaging-tools
./package.sh --models-api-json ../api.json --skip-web --skip-desktop
```

### 第三步：用户配置

打包产物分发后，用户运行对应的 `enable-offline-mode` 脚本即可启用离线模式。

---

## 📌 文件大小参考

```
package.sh                    ~13 KB  (Linux/macOS 打包脚本)
package.ps1                   ~16 KB  (Windows 打包脚本)
PACKAGING_README.md           ~9 KB   (通用文档)
PACKAGING_WINDOWS.md          ~6 KB   (Windows 文档)
README.md                     ~3 KB   (主文档)
QUICKSTART.md                 ~2 KB   (快速入门)
enable-offline-mode.*         ~1 KB   (辅助脚本)
```

---

## ⚠️ 重要提示

1. **api.json 文件** 不包含在此文件夹中，需要单独下载
2. **打包脚本** 需要和 `api.json` 在同一环境使用
3. **辅助脚本** 可以分发给最终用户，帮助他们快速配置离线模式

---

## 🚀 快速查找

- **我是新用户** → 查看 `QUICKSTART.md`
- **我在 Windows 上** → 查看 `PACKAGING_WINDOWS.md`
- **我想了解详细信息** → 查看 `README.md` 或 `PACKAGING_README.md`
- **我想给用户配置工具** → 使用 `enable-offline-mode.*` 脚本
- **我要打包项目** → 使用 `package.sh` 或 `package.ps1`
