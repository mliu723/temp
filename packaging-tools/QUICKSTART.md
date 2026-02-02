# OpenCode 打包快速入门

## 🎯 你需要做什么

### 步骤 1: 下载 api.json（在有网络的环境中）

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -Uri "https://models.dev/api.json" -OutFile "api.json"
```

**Linux/macOS:**
```bash
curl -O https://models.dev/api.json
```

### 步骤 2: 将文件复制到目标环境

将以下文件复制到目标机器（公司内网）：
- ✅ 整个 `packaging-tools` 文件夹
- ✅ `api.json` 文件

### 步骤 3: 运行打包脚本

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

### 步骤 4: 获取打包产物

打包完成后，会在上级目录生成：
```
opencode-bundle-{version}-{timestamp}.tar.gz
```

这个文件就可以分发给用户了！

---

## 📤 分发给用户

用户解压后需要：

1. **设置离线模式**
   ```powershell
   # Windows
   [System.Environment]::SetEnvironmentVariable('OPENCODE_DISABLE_MODELS_FETCH', '1', 'User')
   ```

   ```bash
   # Linux/macOS
   export OPENCODE_DISABLE_MODELS_FETCH=1
   ```

2. **配置 API Key**
   ```bash
   opencode auth login
   ```

3. **开始使用**
   ```bash
   opencode
   ```

---

## ❓ 常见问题

### Q: 为什么需要 api.json？
A: 因为公司网络无法访问 models.dev，所以需要提前下载模型配置文件。

### Q: 打包后的文件能在离线环境使用吗？
A: 可以！打包后的二进制文件已经内置了完整的模型配置，用户只需设置环境变量 `OPENCODE_DISABLE_MODELS_FETCH=1`。

### Q: Windows 提示无法运行脚本？
A: 运行以下命令：
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### Q: Linux 提示权限不足？
A: 运行以下命令：
   ```bash
   chmod +x packaging-tools/package.sh
   ```

---

## 📚 更多信息

- **完整文档**: 查看 [README.md](README.md)
- **Windows 用户**: 查看 [PACKAGING_WINDOWS.md](PACKAGING_WINDOWS.md)
- **通用指南**: 查看 [PACKAGING_README.md](PACKAGING_README.md)
