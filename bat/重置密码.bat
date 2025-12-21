@echo off
REM Windows批处理脚本：快速重置密码
REM 使用方法：双击此文件，然后按提示操作

echo ========================================
echo 密码重置工具
echo ========================================
echo.

cd /d %~dp0container_management

echo 请选择操作：
echo 1. 重置现有用户密码
echo 2. 列出所有用户
echo 3. 创建新的超级用户
echo.
set /p choice=请输入选项 (1/2/3): 

if "%choice%"=="1" (
    set /p username=请输入用户名: 
    set /p password=请输入新密码: 
    python reset_password.py reset %username% %password%
) else if "%choice%"=="2" (
    python reset_password.py list
) else if "%choice%"=="3" (
    set /p username=请输入用户名: 
    set /p email=请输入邮箱: 
    set /p password=请输入密码: 
    python reset_password.py create %username% %email% %password%
) else (
    echo 无效的选项！
)

echo.
pause






