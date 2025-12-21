from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import render

from .dashboard_context import dashboard_stats


@login_required
@user_passes_test(lambda u: u.is_staff)
def admin_dashboard(request):
    """
    独立的后台仪表盘页 (/admin/dashboard)，复用 simpleui 外观。
    """
    context = dashboard_stats(request)
    return render(request, 'admin/simpleui/dashboard.html', context)
