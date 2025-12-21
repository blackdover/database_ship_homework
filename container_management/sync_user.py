#!/usr/bin/env python
"""
用户同步工具
用于同步Django的auth_user表和数据库的Users表
"""
import os
import sys
import django

# 设置Django环境
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'container_management.settings')
django.setup()

from django.contrib.auth.models import User
from management.models import Users, Party
from django.db import transaction

def sync_user_to_db(django_username):
    """将Django用户同步到数据库Users表"""
    try:
        # 获取Django用户
        django_user = User.objects.get(username=django_username)
        
        # 检查Users表中是否已存在
        if Users.objects.filter(username=django_username).exists():
            db_user = Users.objects.get(username=django_username)
            print(f'✅ 用户 "{django_username}" 在Users表中已存在')
            print(f'   用户ID: {db_user.user_id}')
            print(f'   全名: {db_user.full_name or "未设置"}')
            print(f'   邮箱: {db_user.email}')
            return db_user
        
        # 创建Users表记录
        # 注意：Users表需要email，但email字段是unique的
        # 如果Django用户的email为空，需要生成一个
        email = django_user.email
        if not email:
            email = f'{django_username}@example.com'
            print(f'⚠️  Django用户没有邮箱，使用默认邮箱: {email}')
        
        # 检查email是否已存在
        if Users.objects.filter(email=email).exists():
            # 如果email已存在，添加数字后缀
            counter = 1
            original_email = email
            while Users.objects.filter(email=email).exists():
                email = f'{django_username}{counter}@example.com'
                counter += 1
            print(f'⚠️  邮箱 {original_email} 已存在，使用: {email}')
        
        # 创建Users表记录
        # 注意：Users表的hashed_password是BinaryField，但我们不存储密码
        # 密码验证使用Django的auth_user表
        with transaction.atomic():
            db_user = Users.objects.create(
                username=django_username,
                email=email,
                full_name=django_user.get_full_name() or django_username,
                hashed_password=b'',  # 不存储密码，使用Django认证
                is_active=django_user.is_active
            )
        
        print(f'✅ 成功在Users表中创建用户记录')
        print(f'   用户ID: {db_user.user_id}')
        print(f'   用户名: {db_user.username}')
        print(f'   全名: {db_user.full_name}')
        print(f'   邮箱: {db_user.email}')
        return db_user
        
    except User.DoesNotExist:
        print(f'❌ Django用户 "{django_username}" 不存在！')
        print('\n可用的Django用户列表：')
        users = User.objects.all()
        if users:
            for u in users:
                print(f'   - {u.username} (邮箱: {u.email or "无"}, 超级用户: {"是" if u.is_superuser else "否"})')
        else:
            print('   (无用户)')
        return None
    except Exception as e:
        print(f'❌ 同步用户时出错：{str(e)}')
        import traceback
        traceback.print_exc()
        return None

def sync_all_users():
    """同步所有Django用户到Users表"""
    django_users = User.objects.all()
    if not django_users:
        print('没有Django用户需要同步')
        return
    
    print(f'找到 {django_users.count()} 个Django用户，开始同步...\n')
    
    success_count = 0
    skip_count = 0
    error_count = 0
    
    for django_user in django_users:
        print(f'\n处理用户: {django_user.username}')
        if Users.objects.filter(username=django_user.username).exists():
            print(f'  ⏭️  已存在，跳过')
            skip_count += 1
        else:
            result = sync_user_to_db(django_user.username)
            if result:
                success_count += 1
            else:
                error_count += 1
    
    print(f'\n' + '='*60)
    print(f'同步完成！')
    print(f'  成功: {success_count}')
    print(f'  跳过: {skip_count}')
    print(f'  失败: {error_count}')
    print('='*60)

def create_user_with_sync(username, email, password, full_name=None, is_superuser=False):
    """创建Django用户并同步到Users表"""
    try:
        # 检查Django用户是否已存在
        if User.objects.filter(username=username).exists():
            print(f'⚠️  Django用户 "{username}" 已存在，将同步到Users表')
            django_user = User.objects.get(username=username)
        else:
            # 创建Django用户
            if is_superuser:
                django_user = User.objects.create_superuser(
                    username=username,
                    email=email,
                    password=password
                )
            else:
                django_user = User.objects.create_user(
                    username=username,
                    email=email,
                    password=password
                )
            print(f'✅ Django用户 "{username}" 创建成功')
        
        # 设置全名
        if full_name:
            django_user.first_name = full_name
            django_user.save()
        
        # 同步到Users表
        db_user = sync_user_to_db(username)
        if db_user and full_name:
            db_user.full_name = full_name
            db_user.save()
        
        return django_user, db_user
        
    except Exception as e:
        print(f'❌ 创建用户时出错：{str(e)}')
        import traceback
        traceback.print_exc()
        return None, None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('=' * 60)
        print('用户同步工具')
        print('=' * 60)
        print('\n用法：')
        print('  1. 同步单个用户:')
        print('     python sync_user.py sync <用户名>')
        print('\n  2. 同步所有Django用户:')
        print('     python sync_user.py sync-all')
        print('\n  3. 创建用户并同步（推荐）:')
        print('     python sync_user.py create <用户名> <邮箱> <密码> [全名] [--superuser]')
        print('\n示例：')
        print('  python sync_user.py sync admin')
        print('  python sync_user.py sync-all')
        print('  python sync_user.py create admin admin@example.com password123 "系统管理员" --superuser')
        print('=' * 60)
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    if command == 'sync':
        if len(sys.argv) != 3:
            print('❌ 错误：需要指定用户名')
            print('用法: python sync_user.py sync <用户名>')
            sys.exit(1)
        username = sys.argv[2]
        sync_user_to_db(username)
    
    elif command == 'sync-all':
        sync_all_users()
    
    elif command == 'create':
        if len(sys.argv) < 5:
            print('❌ 错误：创建用户需要用户名、邮箱和密码')
            print('用法: python sync_user.py create <用户名> <邮箱> <密码> [全名] [--superuser]')
            sys.exit(1)
        username = sys.argv[2]
        email = sys.argv[3]
        password = sys.argv[4]
        full_name = sys.argv[5] if len(sys.argv) > 5 and not sys.argv[5].startswith('--') else None
        is_superuser = '--superuser' in sys.argv
        
        create_user_with_sync(username, email, password, full_name, is_superuser)
    
    else:
        print(f'❌ 未知命令: {command}')
        print('可用命令: sync, sync-all, create')
        sys.exit(1)






