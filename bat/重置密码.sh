#!/bin/bash
# Linux/Mac 密码重置脚本

echo "========================================"
echo "密码重置工具"
echo "========================================"
echo ""

cd "$(dirname "$0")/container_management"

echo "请选择操作："
echo "1. 重置现有用户密码"
echo "2. 列出所有用户"
echo "3. 创建新的超级用户"
echo ""
read -p "请输入选项 (1/2/3): " choice

case $choice in
    1)
        read -p "请输入用户名: " username
        read -sp "请输入新密码: " password
        echo ""
        python reset_password.py reset "$username" "$password"
        ;;
    2)
        python reset_password.py list
        ;;
    3)
        read -p "请输入用户名: " username
        read -p "请输入邮箱: " email
        read -sp "请输入密码: " password
        echo ""
        python reset_password.py create "$username" "$email" "$password"
        ;;
    *)
        echo "无效的选项！"
        ;;
esac






