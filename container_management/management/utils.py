"""
权限检查工具函数
"""
from functools import wraps
from django.shortcuts import redirect
from django.contrib import messages
from django.db import connection
from .models import Users, Permissions, UserPermissions


def get_user_permissions(user_id):
    """
    获取用户的所有权限名称列表（已废弃，使用get_user_permission_names）
    """
    return get_user_permission_names(user_id)


def has_permission(user_id, permission_name):
    """
    检查用户是否拥有指定权限
    """
    permissions = get_user_permission_names(user_id)
    return permission_name in permissions


def get_user_permission_names(user_id):
    """
    获取用户权限名称列表（优化版本，使用视图）
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 权限列表
                FROM View_User_Permissions
                WHERE 用户编号 = %s
            """, [user_id])
            row = cursor.fetchone()
            if row and row[0]:
                return [p.strip() for p in row[0].split(',')]
            return []
    except Exception:
        # 如果视图不存在，使用表查询
        try:
            user = Users.objects.get(user_id=user_id)
            permissions = UserPermissions.objects.filter(user_id=user)
            return [up.permission_id.permission_name for up in permissions]
        except Exception:
            return []


def require_permission(permission_name):
    """
    装饰器：要求用户拥有指定权限才能访问视图
    """
    def decorator(view_func):
        @wraps(view_func)
        def wrapper(request, *args, **kwargs):
            if not request.user.is_authenticated:
                messages.error(request, '请先登录')
                return redirect('custom_login')
            
            # 获取用户ID（假设使用Django的User系统，需要映射到Users表）
            try:
                # 尝试从session或request中获取用户ID
                user_id = request.session.get('user_id')
                if not user_id:
                    # 尝试通过用户名查找
                    username = request.user.username
                    try:
                        db_user = Users.objects.get(username=username)
                        user_id = db_user.user_id
                        request.session['user_id'] = user_id
                    except Users.DoesNotExist:
                        messages.error(request, '用户不存在')
                        return redirect('custom_login')
                
                # 检查权限
                if not has_permission(user_id, permission_name):
                    messages.error(request, f'您没有权限访问此页面（需要权限：{permission_name}）')
                    return redirect('dashboard')
                
                return view_func(request, *args, **kwargs)
            except Exception as e:
                messages.error(request, f'权限检查失败：{str(e)}')
                return redirect('dashboard')
        
        return wrapper
    return decorator


def get_user_role(user_id, django_user=None):
    """
    根据用户权限判断用户角色
    返回：'admin', 'operator', 'viewer', 'guest'
    
    参数:
        user_id: Users表的用户ID
        django_user: Django的User对象（可选，用于检查is_superuser）
    """
    # 如果提供了Django用户且是超级用户，直接返回admin
    if django_user and django_user.is_superuser:
        return 'admin'
    
    if not user_id:
        return 'guest'
    
    permissions = get_user_permission_names(user_id)
    
    if 'ADMIN' in permissions:
        return 'admin'
    elif 'CREATE_TASK' in permissions or 'UPDATE_TASK' in permissions:
        return 'operator'
    elif 'VIEW_INVENTORY' in permissions or 'VIEW_STATISTICS' in permissions:
        return 'viewer'
    else:
        return 'guest'

