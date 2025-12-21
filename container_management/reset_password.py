#!/usr/bin/env python
"""
密码重置工具
用法: python reset_password.py <用户名> <新密码>
"""
import os
import sys
import django

# 设置Django环境
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'container_management.settings')
django.setup()

from django.contrib.auth.models import User

def reset_password(username, new_password):
    """重置用户密码"""
    try:
        user = User.objects.get(username=username)
        user.set_password(new_password)
        user.save()
        print(f'✅ 用户 "{username}" 的密码已成功重置！')
        print(f'   新密码: {new_password}')
        return True
    except User.DoesNotExist:
        print(f'❌ 用户 "{username}" 不存在！')
        print('\n可用的用户列表：')
        users = User.objects.all()
        if users:
            for u in users:
                print(f'   - {u.username} (邮箱: {u.email or "无"}, 超级用户: {"是" if u.is_superuser else "否"})')
        else:
            print('   (无用户)')
        return False
    except Exception as e:
        print(f'❌ 重置密码时出错：{str(e)}')
        return False

def list_users():
    """列出所有用户"""
    users = User.objects.all()
    if not users:
        print('系统中没有用户。')
        return
    
    print('系统中的用户列表：')
    print('-' * 60)
    print(f'{"用户名":<20} {"邮箱":<25} {"超级用户":<10} {"激活":<10}')
    print('-' * 60)
    for user in users:
        email = user.email or '无'
        superuser = '是' if user.is_superuser else '否'
        active = '是' if user.is_active else '否'
        print(f'{user.username:<20} {email:<25} {superuser:<10} {active:<10}')
    print('-' * 60)

def create_superuser(username, email, password):
    """创建超级用户并同步到Users表"""
    try:
        if User.objects.filter(username=username).exists():
            print(f'⚠️  Django用户 "{username}" 已存在，将同步到Users表')
            django_user = User.objects.get(username=username)
        else:
            django_user = User.objects.create_superuser(
                username=username,
                email=email,
                password=password
            )
            print(f'✅ Django超级用户 "{username}" 创建成功！')
        
        # 同步到Users表
        try:
            from management.models import Users
            from django.db import transaction
            
            if Users.objects.filter(username=username).exists():
                print(f'✅ 用户 "{username}" 在Users表中已存在')
            else:
                # 处理邮箱冲突
                user_email = email
                if Users.objects.filter(email=user_email).exists():
                    counter = 1
                    while Users.objects.filter(email=user_email).exists():
                        user_email = f'{username}{counter}@example.com'
                        counter += 1
                    print(f'⚠️  邮箱 {email} 已存在，使用: {user_email}')
                
                with transaction.atomic():
                    Users.objects.create(
                        username=username,
                        email=user_email,
                        full_name=username,
                        hashed_password=b'',
                        is_active=True
                    )
                print(f'✅ 用户 "{username}" 已同步到Users表')
        except Exception as sync_error:
            print(f'⚠️  同步到Users表时出错：{str(sync_error)}')
            print('   您可以稍后使用 sync_user.py 工具手动同步')
        
        return True
    except Exception as e:
        print(f'❌ 创建用户时出错：{str(e)}')
        return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('=' * 60)
        print('密码重置工具')
        print('=' * 60)
        print('\n用法：')
        print('  1. 重置密码:')
        print('     python reset_password.py reset <用户名> <新密码>')
        print('\n  2. 列出所有用户:')
        print('     python reset_password.py list')
        print('\n  3. 创建超级用户:')
        print('     python reset_password.py create <用户名> <邮箱> <密码>')
        print('\n示例：')
        print('  python reset_password.py reset admin newpassword123')
        print('  python reset_password.py list')
        print('  python reset_password.py create admin admin@example.com password123')
        print('=' * 60)
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    if command == 'reset':
        if len(sys.argv) != 4:
            print('❌ 错误：重置密码需要用户名和新密码')
            print('用法: python reset_password.py reset <用户名> <新密码>')
            sys.exit(1)
        username = sys.argv[2]
        new_password = sys.argv[3]
        reset_password(username, new_password)
    
    elif command == 'list':
        list_users()
    
    elif command == 'create':
        if len(sys.argv) != 5:
            print('❌ 错误：创建用户需要用户名、邮箱和密码')
            print('用法: python reset_password.py create <用户名> <邮箱> <密码>')
            sys.exit(1)
        username = sys.argv[2]
        email = sys.argv[3]
        password = sys.argv[4]
        create_superuser(username, email, password)
    
    else:
        print(f'❌ 未知命令: {command}')
        print('可用命令: reset, list, create')
        sys.exit(1)

