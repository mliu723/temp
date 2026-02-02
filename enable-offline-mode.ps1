# OpenCode 离线模式启用脚本 (PowerShell)
# 此脚本用于在 Windows 上设置离线模式环境变量

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "OpenCode 离线模式配置" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "此脚本将设置以下环境变量：" -ForegroundColor Yellow
Write-Host "  OPENCODE_DISABLE_MODELS_FETCH=1" -ForegroundColor White
Write-Host ""
Write-Host "这样 OpenCode 就不会尝试从 models.dev 获取数据" -ForegroundColor White
Write-Host ""

try {
    [System.Environment]::SetEnvironmentVariable('OPENCODE_DISABLE_MODELS_FETCH', '1', 'User')

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "✓ 离线模式已启用！" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "请重新打开 PowerShell 以使更改生效" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "然后运行: opencode auth login" -ForegroundColor Cyan
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "✗ 设置失败" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "错误: $_" -ForegroundColor Red
    Write-Host ""
}
