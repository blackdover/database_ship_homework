@echo off
REM Windows批处理脚本：同步用户
REM 使用方法：双击此文件，然后按提示操作

echo ========================================
echo 用户同步工具
echo ========================================
echo.

cd /d %~dp0container_management

echo 请选择操作：
echo 1. 同步单个用户到Users表
echo 2. 同步所有Django用户到Users表
echo 3. 创建新用户并同步（推荐）
echo.
set /p choice=请输入选项 (1/2/3): 

if "%choice%"=="1" (
    set /p username=请输入Django用户名: 
    python sync_user.py sync %username%
) else if "%choice%"=="2" (
    python sync_user.py sync-all
) else if "%choice%"=="3" (
    set /p username=请输入用户名: 
    set /p email=请输入邮箱: 
    set /p password=请输入密码: 
    set /p fullname=请输入全名（可选，直接回车跳过）: 
    set /p issuper=是否创建为超级用户？(y/n): 
    if /i "%issuper%"=="y" (
        if "%fullname%"=="" (
            python sync_user.py create %username% %email% %password% --superuser
        ) else (
            python sync_user.py create %username% %email% %password% "%fullname%" --superuser
        )
    ) else (
        if "%fullname%"=="" (
            python sync_user.py create %username% %email% %password%
        ) else (
            python sync_user.py create %username% %email% %password% "%fullname%"
        )
    )
) else (
    echo 无效的选项！
)

echo.
pause






