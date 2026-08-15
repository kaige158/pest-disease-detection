Set-Location "F:\lao-cn-APP\flutter_app"
Write-Host "正在编译蔬菜版，请稍候..." -ForegroundColor Green
Write-Host "编译完成后访问: http://localhost:8081" -ForegroundColor Cyan
& "C:\Users\30256\flutter_sdk\bin\flutter.bat" run -d web-server --web-port 8081 --web-renderer html -t lib/main_vegetable.dart
Write-Host "服务已停止，按任意键关闭" -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
