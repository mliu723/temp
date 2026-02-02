@echo off
REM OpenCode 离线模式启用脚本
REM 此脚本用于在 Windows 上设置离线模式环境变量

echo ============================================
echo OpenCode 离线模式配置
echo ============================================
echo.
echo 此脚本将设置以下环境变量：
echo   OPENCODE_DISABLE_MODELS_FETCH=1
echo.
echo 这样 OpenCode 就不会尝试从 models.dev 获取数据
echo.

setx OPENCODE_DISABLE_MODELS_FETCH "1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================
    echo ✓ 离线模式已启用！
    echo ============================================
    echo.
    echo 请重新打开命令提示符或 PowerShell 以使更改生效
    echo.
    echo 然后运行: opencode auth login
    echo.
) else (
    echo.
    echo ============================================
    echo ✗ 设置失败
    echo ============================================
    echo.
    echo 请尝试以管理员身份运行此脚本
    echo.
)

pause
