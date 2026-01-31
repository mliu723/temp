@echo off
setlocal enabledelayedexpansion

REM 配置
set VERSION=1.0.0
set API_URL=https://models.dev/api.json
set API_FILE=api.json
set RELEASE_DIR=release
set ZIP_FILE=opencode-internal-v%VERSION%.zip

echo ====================
echo   OpenCode 内网版构建 v%VERSION%
echo ====================
echo.

REM 检查 api.json
echo [1/5] 准备模型数据...
if not exist "%API_FILE%" (
    echo   下载 api.json...
    powershell -Command "Invoke-WebRequest -Uri '%API_URL%' -OutFile '%API_FILE%' -UseBasicParsing"
    if errorlevel 1 (
        echo   错误: 下载失败
        pause
        exit /b 1
    )
) else (
    echo   使用已有 api.json
)

REM 检查 Bun
echo [2/5] 检查 Bun...
bun --version >nul 2>&1
if errorlevel 1 (
    echo   错误: 未找到 Bun
    pause
    exit /b 1
)
echo   Bun 已安装

REM 设置环境变量
echo [3/5] 设置环境变量...
for /f "delims=" %%i in ('powershell -Command "(Resolve-Path '%API_FILE%').Path"') do set API_JSON_PATH=%%i
set MODELS_DEV_API_JSON=%API_JSON_PATH%
set OPENCODE_DISABLE_MODELS_FETCH=1

REM 清理旧版本
echo [4/5] 清理旧版本...
if exist "%RELEASE_DIR%" rmdir /s /q "%RELEASE_DIR%"
if exist "%ZIP_FILE%" del "%ZIP_FILE%"
mkdir "%RELEASE_DIR%"

REM 构建
echo [5/5] 构建中（可能需要几分钟）...
call bun packages\opencode\script\build.ts --single
if errorlevel 1 (
    echo   错误: 构建失败
    pause
    exit /b 1
)

REM 打包
echo 打包发布文件...
xcopy /e /i /q packages\opencode\dist\opencode-windows-x64\* "%RELEASE_DIR%\"
copy "%API_FILE%" "%RELEASE_DIR%\models.json"

REM 创建 README
echo # OpenCode 内网版 v%VERSION%> "%RELEASE_DIR%\README.md"
echo.>> "%RELEASE_DIR%\README.md"
echo ## 快速开始>> "%RELEASE_DIR%\README.md"
echo.>> "%RELEASE_DIR%\README.md"
echo ```powershell>> "%RELEASE_DIR%\README.md"
echo .\bin\opencode.exe>> "%RELEASE_DIR%\README.md"
echo ```>> "%RELEASE_DIR%\README.md"
echo.>> "%RELEASE_DIR%\README.md"
echo ## 配置 API Key>> "%RELEASE_DIR%\README.md"
echo.>> "%RELEASE_DIR%\README.md"
echo 创建 opencode.json>> "%RELEASE_DIR%\README.md"
echo.>> "%RELEASE_DIR%\README.md"

REM 压缩
echo 创建压缩包...
powershell -Command "Compress-Archive -Path '%RELEASE_DIR%\*' -DestinationPath '%ZIP_FILE%'"

REM 完成
echo.
echo ====================
echo   构建完成！
echo ====================
echo.
echo 输出文件: %ZIP_FILE%
echo.

for /f "delims=" %%i in ('powershell -Command "[Math]::Round((Get-Item '%ZIP_FILE%').Length / 1MB, 2)"') do set SIZE=%%i
echo 文件大小: %SIZE% MB
echo.

pause
