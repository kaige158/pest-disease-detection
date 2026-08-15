@echo off
chcp 65001 >nul
title 果树版APP — Flutter服务
cd /d "F:\lao-cn-APP\flutter_app"
echo 正在编译果树版，请稍候（首次约30-60秒）...
echo 编译完成后请访问: http://localhost:8082
echo.
"C:\Users\30256\flutter_sdk\bin\flutter.bat" run -d web-server --web-port 8082 --web-renderer html -t lib/main_fruit.dart
echo.
echo 服务已停止。按任意键关闭窗口。
pause
