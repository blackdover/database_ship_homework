@echo off
REM Windows批处理脚本：执行权限初始化
REM 使用方法：双击此文件或在命令行中运行

echo 正在初始化权限系统...
echo.

REM 获取脚本所在目录
set SCRIPT_DIR=%~dp0
cd /d %SCRIPT_DIR

REM 执行SQL文件（使用UTF-8编码）
chcp 65001 >nul
mysql -u root -p --default-character-set=utf8mb4 box_management < init_permissions_utf8.sql

if %ERRORLEVEL% EQU 0 (
    echo.
    echo 权限初始化成功！
) else (
    echo.
    echo 权限初始化失败，请检查错误信息
)

pause

