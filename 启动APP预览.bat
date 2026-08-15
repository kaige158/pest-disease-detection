@echo off
chcp 65001 >nul
title 老挝农业APP — 开发预览启动器

echo.
echo ╔══════════════════════════════════════╗
echo ║   老挝智能农果APP — 开发预览启动器     ║
echo ╚══════════════════════════════════════╝
echo.
echo 请选择启动版本:
echo   [1] 蔬菜版 (端口 8081)
echo   [2] 果树版 (端口 8082)
echo   [3] 两个版本同时启动
echo.
set /p choice=输入选项 (1/2/3):

if "%choice%"=="1" goto veg
if "%choice%"=="2" goto fruit
if "%choice%"=="3" goto both
goto veg

:veg
echo.
echo 正在启动蔬菜版...
start "蔬菜版-Flutter服务" cmd /k "cd /d F:\lao-cn-APP\flutter_app && flutter run -d web-server --web-port 8081 --web-renderer html -t lib/main_vegetable.dart"
timeout /t 8 /nobreak >nul
start "" "http://localhost:8081"
echo 蔬菜版已在浏览器打开: http://localhost:8081
goto done

:fruit
echo.
echo 正在启动果树版...
start "果树版-Flutter服务" cmd /k "cd /d F:\lao-cn-APP\flutter_app && flutter run -d web-server --web-port 8082 --web-renderer html -t lib/main_fruit.dart"
timeout /t 8 /nobreak >nul
start "" "http://localhost:8082"
echo 果树版已在浏览器打开: http://localhost:8082
goto done

:both
echo.
start "蔬菜版-Flutter服务" cmd /k "cd /d F:\lao-cn-APP\flutter_app && flutter run -d web-server --web-port 8081 --web-renderer html -t lib/main_vegetable.dart"
echo 蔬菜版启动中(端口8081)...
timeout /t 12 /nobreak >nul
start "果树版-Flutter服务" cmd /k "cd /d F:\lao-cn-APP\flutter_app && flutter run -d web-server --web-port 8082 --web-renderer html -t lib/main_fruit.dart"
echo 果树版启动中(端口8082)...
timeout /t 12 /nobreak >nul
start "" "http://localhost:8081"
timeout /t 2 /nobreak >nul
start "" "http://localhost:8082"
goto done

:done
echo.
echo ✓ 启动完成！
echo   热重载: 在Flutter服务窗口按 r
echo   热重启: 在Flutter服务窗口按 R
echo   退出:   在Flutter服务窗口按 q
echo.
pause
