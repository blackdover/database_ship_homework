from django.contrib import admin
from django.urls import path, re_path
from django.views.generic import RedirectView

from management.dashboard_views import admin_dashboard
from management.views import aggregate_search
from management.auth_views import custom_login, custom_logout, dashboard

urlpatterns = [
    # 自定义登录页面
    path('login/', custom_login, name='custom_login'),
    # 自定义登出页面
    path('logout/', custom_logout, name='custom_logout'),
    # 用户仪表盘
    path('dashboard/', dashboard, name='dashboard'),
    
    # 覆盖 Django Admin 的登录页面，使用自定义登录页面
    # 必须在 admin.site.urls 之前，这样会优先匹配
    path('admin/login/', custom_login, name='admin:login'),
    
    # 独立仪表盘页（simpleui 框架内）
    path('admin/dashboard/', admin_dashboard, name='admin_dashboard'),
    # 聚合搜索页（simpleui 风格）
    path('admin/search/', aggregate_search, name='aggregate_search'),

    # 默认 Django Admin（已集成 simpleui）
    path('admin/', admin.site.urls),

    # 根路径重定向到登录页面
    re_path(r'^$', RedirectView.as_view(url='/login/', permanent=False)),
]
