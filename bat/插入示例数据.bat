@echo off
chcp 65001 >nul
echo ========================================
echo 插入示例数据脚本
echo ========================================
echo.

cd /d "%~dp0\container_management"
python insert_sample_data.py

if %errorlevel% == 0 (
    echo.
    echo ========================================
    echo 数据插入成功！
    echo ========================================
) else (
    echo.
    echo ========================================
    echo 数据插入失败，请检查错误信息
    echo ========================================
)

pause

