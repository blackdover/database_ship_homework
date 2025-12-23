"""
自定义认证视图
"""
from django.shortcuts import render, redirect
from django.contrib import messages
from django.contrib.auth import authenticate, login as django_login, logout as django_logout
from django.db import connection
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .models import Users
from .utils import get_user_permission_names, get_user_role
from .dashboard_context import dashboard_stats
from django.template import TemplateDoesNotExist


@require_http_methods(["GET", "POST"])
def custom_login(request):
    """
    自定义登录页面
    """
    # 获取重定向目标（Django Admin 会传递 next 参数）
    # 先不设置默认，登录成功后根据用户角色决定跳转（admin -> /admin/，非 admin -> /dashboard/）
    next_url = request.GET.get('next') or request.POST.get('next') or None
    
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        if not username or not password:
            messages.error(request, '请输入用户名和密码')
            return render(request, 'management/login.html', {'next': next_url})
        
        # 使用Django的认证系统
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            django_login(request, user)
            
            # 获取数据库中的用户信息
            try:
                db_user = Users.objects.get(username=username)
                request.session['user_id'] = db_user.user_id
                request.session['user_full_name'] = db_user.full_name or username
                # 传递Django用户对象以检查is_superuser
                request.session['user_role'] = get_user_role(db_user.user_id, django_user=user)
                request.session['user_permissions'] = get_user_permission_names(db_user.user_id)
                
                # 如果Django用户是超级用户，自动添加ADMIN权限到session
                if user.is_superuser:
                    if 'ADMIN' not in request.session['user_permissions']:
                        request.session['user_permissions'].append('ADMIN')
                    request.session['user_role'] = 'admin'
                
                messages.success(request, f'欢迎回来，{db_user.full_name or username}！')
                # 根据用户角色决定最终跳转目标：admin/staff 优先跳转到 admin，否则跳 dashboard
                try:
                    is_staff_user = user.is_superuser or getattr(user, 'is_staff', False)
                    # 如果 next 指向 admin 且当前不是 admin/staff，则忽略 next，强制去 dashboard
                    if next_url and next_url.startswith('/admin') and not is_staff_user:
                        target = '/dashboard/'
                    else:
                        target = next_url or ('/admin/' if is_staff_user else '/dashboard/')
                except Exception:
                    target = next_url or '/dashboard/'
                return redirect(target)
            except Users.DoesNotExist:
                # 如果Django用户存在但数据库用户不存在，尝试自动创建
                try:
                    from django.db import transaction
                    # 生成默认邮箱
                    email = user.email or f'{username}@example.com'
                    # 检查email是否已存在
                    if Users.objects.filter(email=email).exists():
                        counter = 1
                        while Users.objects.filter(email=email).exists():
                            email = f'{username}{counter}@example.com'
                            counter += 1
                    
                    # 自动创建Users表记录
                    with transaction.atomic():
                        db_user = Users.objects.create(
                            username=username,
                            email=email,
                            full_name=user.get_full_name() or username,
                            hashed_password=b'',  # 不存储密码，使用Django认证
                            is_active=user.is_active
                        )
                    
                    # 设置session信息
                    request.session['user_id'] = db_user.user_id
                    request.session['user_full_name'] = db_user.full_name or username
                    # 传递Django用户对象以检查is_superuser
                    request.session['user_role'] = get_user_role(db_user.user_id, django_user=user)
                    request.session['user_permissions'] = get_user_permission_names(db_user.user_id)
                    
                    # 如果Django用户是超级用户，自动添加ADMIN权限到session
                    if user.is_superuser:
                        if 'ADMIN' not in request.session['user_permissions']:
                            request.session['user_permissions'].append('ADMIN')
                        request.session['user_role'] = 'admin'
                        # 自动分配ADMIN权限到数据库
                        try:
                            from .models import Permissions, UserPermissions
                            admin_permission = Permissions.objects.get(permission_name='ADMIN')
                            UserPermissions.objects.get_or_create(
                                user_id=db_user,
                                permission_id=admin_permission
                            )
                        except Exception:
                            pass  # 如果权限表未初始化，忽略
                    
                    messages.success(request, f'欢迎回来，{db_user.full_name or username}！用户信息已自动同步。')
                    try:
                        is_staff_user = user.is_superuser or getattr(user, 'is_staff', False)
                        if next_url and next_url.startswith('/admin') and not is_staff_user:
                            target = '/dashboard/'
                        else:
                            target = next_url or ('/admin/' if is_staff_user else '/dashboard/')
                    except Exception:
                        target = next_url or '/dashboard/'
                    return redirect(target)
                except Exception as e:
                    # 如果自动创建失败，检查是否是超级用户
                    if user.is_superuser:
                        # 超级用户即使Users表不存在，也允许登录并标记为管理员
                        request.session['user_id'] = None
                        request.session['user_full_name'] = username
                        request.session['user_role'] = 'admin'
                        request.session['user_permissions'] = ['ADMIN']
                        messages.warning(request, f'超级用户登录成功，但Users表记录未创建。建议使用 sync_user.py 工具同步用户信息。')
                    else:
                        # 普通用户标记为访客
                        request.session['user_id'] = None
                        request.session['user_full_name'] = username
                        request.session['user_role'] = 'guest'
                        request.session['user_permissions'] = []
                        messages.warning(request, f'用户信息不完整，已自动创建但可能不完整。如遇问题，请使用 sync_user.py 工具同步用户。')
                    return redirect(next_url)
        else:
            messages.error(request, '用户名或密码错误')
    
    return render(request, 'management/login.html', {'next': next_url})
    # GET 请求时给未登录用户一个欢迎提示（确保登出后也能看到欢迎提示）
    if request.method == 'GET' and not request.user.is_authenticated:
        messages.info(request, '欢迎回来，访客！')
    return render(request, 'management/login.html', {'next': next_url})


def custom_logout(request):
    """
    自定义登出
    """
    django_logout(request)
    request.session.flush()
    messages.success(request, '您已成功登出')
    return redirect('custom_login')


def dashboard(request):
    """
    用户仪表板 - 根据权限显示不同内容
    """
    if not request.user.is_authenticated:
        return redirect('custom_login')
    
    user_id = request.session.get('user_id')
    if not user_id:
        try:
            db_user = Users.objects.get(username=request.user.username)
            user_id = db_user.user_id
            request.session['user_id'] = user_id
        except Users.DoesNotExist:
            # 如果Users表不存在但Django用户是超级用户，允许访问
            if request.user.is_superuser:
                user_id = None
                request.session['user_id'] = None
            else:
                messages.error(request, '用户不存在，请联系管理员')
                return redirect('custom_login')
    
    # 获取用户信息和权限
    # 如果Django用户是超级用户，自动设置为管理员
    if request.user.is_superuser:
        user_role = 'admin'
        permissions = request.session.get('user_permissions') or get_user_permission_names(user_id)
        if 'ADMIN' not in permissions:
            permissions.append('ADMIN')
        # 更新session
        request.session['user_role'] = 'admin'
        request.session['user_permissions'] = permissions
    else:
        user_role = request.session.get('user_role') or get_user_role(user_id, django_user=request.user)
        permissions = request.session.get('user_permissions') or get_user_permission_names(user_id)
        # 更新session
        request.session['user_role'] = user_role
        request.session['user_permissions'] = permissions
    
    # 确保user_full_name在session中
    if 'user_full_name' not in request.session:
        request.session['user_full_name'] = request.user.username
    
    # 左侧标签状态与可选的 admin 嵌入 URL
    active_tab = request.GET.get('tab', 'dashboard')
    embed_url = request.GET.get('embed')
    if embed_url:
        embed_url = embed_url.strip()
        if not embed_url.startswith('/'):
            embed_url = '/' + embed_url
    
    # 根据角色获取不同的数据
    context = {
        'user_role': user_role,
        'permissions': permissions,
        'user_full_name': request.session.get('user_full_name', request.user.username),
        'active_tab': active_tab,
        'embed_url': embed_url,
    }
    
    # 根据角色加载不同的数据
    if user_role == 'admin':
        # 管理员：显示所有统计信息
        context.update(get_admin_dashboard_data())
    elif user_role == 'operator':
        # 操作员：显示任务相关数据
        context.update(get_operator_dashboard_data(user_id))
    elif user_role == 'viewer':
        # 查看者：显示只读统计
        context.update(get_viewer_dashboard_data())
    else:
        # 访客：显示基本信息
        context.update(get_guest_dashboard_data())
    # 合并 dashboard_stats（包含仪表盘通用数据和视图样本）
    try:
        context.update(dashboard_stats(request))
    except Exception:
        # 若 dashboard_stats 抛错，仍返回已有 context
        pass

    # 尝试渲染角色对应的模板；若模板不存在则回退到合理的默认页面
    try:
        return render(request, f'management/dashboard_{user_role}.html', context)
    except TemplateDoesNotExist:
        # 管理员使用 simpleui 的 admin 仪表盘
        if user_role == 'admin':
            return render(request, 'admin/simpleui/dashboard.html', context)
        # 其他角色回退到极简访客仪表盘（只读）
        return render(request, 'management/dashboard_guest_minimal.html', context)


def get_admin_dashboard_data():
    """管理员仪表板数据"""
    stats = {}
    try:
        with connection.cursor() as cursor:
            # 集装箱状态统计
            try:
                cursor.execute("""
                    SELECT 集装箱状态 AS 状态, SUM(数量) AS 数量
                    FROM View_Container_Status_Summary
                    GROUP BY 集装箱状态
                    ORDER BY 数量 DESC
                """)
                stats['container_status'] = [dict(zip(['状态', '数量'], row)) for row in cursor.fetchall()]
            except Exception:
                stats['container_status'] = []
            
            # 任务统计
            try:
                cursor.execute("""
                    SELECT 任务状态 AS 状态, COUNT(*) AS 数量
                    FROM View_Task_Details
                    GROUP BY 任务状态
                """)
                stats['task_status'] = [dict(zip(['状态', '数量'], row)) for row in cursor.fetchall()]
            except Exception:
                stats['task_status'] = []
            
            # 堆场利用率
            try:
                cursor.execute("""
                    SELECT SUM(箱位总数) AS 总箱位数,
                           SUM(已占用箱位数) AS 已占用,
                           ROUND(AVG(利用率_百分比), 2) AS 利用率
                    FROM View_Yard_Utilization
                """)
                result = cursor.fetchone()
                if result:
                    stats['yard_utilization'] = {
                        '总箱位数': result[0] or 0,
                        '已占用': result[1] or 0,
                        '利用率': result[2] or 0
                    }
                else:
                    stats['yard_utilization'] = {'总箱位数': 0, '已占用': 0, '利用率': 0}
            except Exception:
                stats['yard_utilization'] = {'总箱位数': 0, '已占用': 0, '利用率': 0}
            
            # 船舶访问统计
            try:
                cursor.execute("""
                    SELECT 访问状态 AS 状态, COUNT(*) AS 数量
                    FROM View_Vessel_Visit_Details
                    GROUP BY 访问状态
                """)
                stats['vessel_visit'] = [dict(zip(['状态', '数量'], row)) for row in cursor.fetchall()]
            except Exception:
                stats['vessel_visit'] = []
    except Exception:
        stats = {
            'container_status': [],
            'task_status': [],
            'yard_utilization': {'总箱位数': 0, '已占用': 0, '利用率': 0},
            'vessel_visit': []
        }
    
    return {'stats': stats}


def get_operator_dashboard_data(user_id):
    """操作员仪表板数据"""
    data = {}
    with connection.cursor() as cursor:
        # 我的待执行任务
        cursor.execute("""
            SELECT COUNT(*) AS 数量
            FROM View_Pending_Tasks
            WHERE 指派给 = (SELECT Username FROM Users WHERE User_ID = %s)
        """, [user_id])
        row = cursor.fetchone()
        data['my_pending_tasks'] = row[0] if row else 0
        
        # 我的已完成任务
        cursor.execute("""
            SELECT COUNT(*) AS 数量
            FROM View_Task_Details
            WHERE 执行人 = (SELECT Username FROM Users WHERE User_ID = %s)
            AND 任务状态 = 'Completed'
        """, [user_id])
        row = cursor.fetchone()
        data['my_completed_tasks'] = row[0] if row else 0
    
    return data


def get_viewer_dashboard_data():
    """查看者仪表板数据"""
    return get_admin_dashboard_data()  # 查看者可以看到统计，但不能操作


def get_guest_dashboard_data():
    """访客仪表板数据 - 显示只读统计信息"""
    stats = {}
    try:
        with connection.cursor() as cursor:
            # 堆场利用率（只读）
            try:
                cursor.execute("""
                    SELECT SUM(箱位总数) AS 总箱位数,
                           SUM(已占用箱位数) AS 已占用,
                           ROUND(AVG(利用率_百分比), 2) AS 利用率
                    FROM View_Yard_Utilization
                """)
                result = cursor.fetchone()
                if result:
                    stats['yard_utilization'] = {
                        '总箱位数': result[0] or 0,
                        '已占用': result[1] or 0,
                        '利用率': result[2] or 0
                    }
                else:
                    stats['yard_utilization'] = {'总箱位数': 0, '已占用': 0, '利用率': 0}
            except Exception:
                stats['yard_utilization'] = {'总箱位数': 0, '已占用': 0, '利用率': 0}
            
            # 集装箱状态统计（只读）
            try:
                cursor.execute("""
                    SELECT 集装箱状态 AS 状态, SUM(数量) AS 数量
                    FROM View_Container_Status_Summary
                    GROUP BY 集装箱状态
                    ORDER BY 数量 DESC
                    LIMIT 5
                """)
                stats['container_status'] = [dict(zip(['状态', '数量'], row)) for row in cursor.fetchall()]
            except Exception:
                stats['container_status'] = []
            
            # 任务统计（只读）
            try:
                cursor.execute("""
                    SELECT 任务状态 AS 状态, COUNT(*) AS 数量
                    FROM View_Task_Details
                    GROUP BY 任务状态
                """)
                stats['task_status'] = [dict(zip(['状态', '数量'], row)) for row in cursor.fetchall()]
            except Exception:
                stats['task_status'] = []
    except Exception:
        stats = {
            'yard_utilization': {'总箱位数': 0, '已占用': 0, '利用率': 0},
            'container_status': [],
            'task_status': []
        }
    
    return {'stats': stats}
