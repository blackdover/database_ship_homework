import json

from django.db.models import Count

from .models import ContainerMaster, Task, VesselVisit


def dashboard_stats(request):
    """
    为 simpleui 首页提供基础统计数据：
    - 任务按状态分布
    - 集装箱按当前状态分布
    - 关键指标数字
    - 最近船舶访问
    """
    # 任务状态统计
    task_stats_qs = (
        Task.objects.values('status')
        .annotate(total=Count('task_id'))
        .order_by('status')
    )
    task_status_stats = [
        {'name': item['status'], 'value': item['total']} for item in task_stats_qs
    ]

    # 集装箱当前状态统计
    container_stats_qs = (
        ContainerMaster.objects.values('current_status')
        .annotate(total=Count('container_master_id'))
        .order_by('current_status')
    )
    container_status_stats = [
        {'name': item['current_status'] or '未设置', 'value': item['total']}
        for item in container_stats_qs
    ]

    # 关键指标
    total_containers = ContainerMaster.objects.count()
    in_yard = ContainerMaster.objects.filter(current_status='InYard').count()
    total_tasks = Task.objects.count()
    pending_tasks = Task.objects.filter(status='Pending').count()
    total_visits = VesselVisit.objects.count()
    at_berth = VesselVisit.objects.filter(status='AtBerth').count()

    # 最近船舶访问
    recent_visits = list(
        VesselVisit.objects.select_related('vessel_id', 'port_id')
        .order_by('-ata')[:6]
        .values('vessel_id__vessel_name', 'port_id__port_name', 'ata', 'status')
    )

    return {
        # 图表/列表数据
        'task_status_stats': task_status_stats,
        'container_status_stats': container_status_stats,
        # 关键指标
        'kpi_total_containers': total_containers,
        'kpi_in_yard': in_yard,
        'kpi_total_tasks': total_tasks,
        'kpi_pending_tasks': pending_tasks,
        'kpi_total_visits': total_visits,
        'kpi_at_berth': at_berth,
        # 列表
        'recent_visits': recent_visits,
    }


