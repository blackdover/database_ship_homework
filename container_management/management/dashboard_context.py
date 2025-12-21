import json

from django.db.models import Count
from django.db import connection
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)

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

    # --------- 新增：从数据库视图抓取样本数据（每个视图 5 行示例） ---------
    def fetch_view_sample(view_name, columns, limit=5):
        """
        从指定的数据库视图查询若干行样本并返回 {'columns': [...], 'rows': [{col:val}, ...]}
        使用缓存避免频繁查询。
        """
        cache_key = f'dashboard_view_sample:{view_name}'
        cached = cache.get(cache_key)
        if cached is not None:
            return cached

        cols_sql = ', '.join([f'`{c}`' for c in columns])
        sql = f"SELECT {cols_sql} FROM `{view_name}` LIMIT {limit}"
        try:
            with connection.cursor() as cur:
                cur.execute(sql)
                rows = cur.fetchall()
                colnames = [d[0] for d in cur.description] if cur.description else []
            # 将每行转为按列顺序的列表，便于模板按顺序渲染
            rows_list = [list(row) for row in rows]
            data = {'columns': colnames, 'rows': rows_list}
            cache.set(cache_key, data, 60)  # 缓存 60s
            return data
        except Exception as e:
            logger.exception("fetch_view_sample failed for %s", view_name)
            return {'columns': columns, 'rows': []}

    # 预定义每个视图在仪表盘需要展示的列（按 plan）
    view_columns = {
        "View_Yard_Inventory_Live": ["堆场区", "贝位", "排号", "层号", "坐标代码", "箱号", "箱状态", "ISO代码", "尺寸_英尺"],
        "View_Task_Details": ["任务编号", "任务类型", "任务状态", "优先级", "箱号", "起始堆场区", "起始贝位", "目标堆场区", "目标贝位", "创建人"],
        "View_Vessel_Visit_Details": ["访问编号", "船舶名称", "IMO编号", "承运人", "港口名称", "泊位名称", "进口航次", "到港时间", "离港时间", "任务总数"],
        "View_Booking_Details": ["订舱单编号", "订舱号", "订舱状态", "发货人", "收货人", "航次编号", "船舶名称", "预计到港时间"],
        "View_Yard_Utilization": ["堆场区编号", "堆场区名称", "堆栈总数", "箱位总数", "已占用箱位数", "空闲箱位数", "利用率_百分比"],
        "View_Container_Status_Summary": ["集装箱状态", "箱型代码", "箱尺寸_英尺", "箱型组", "数量"],
        "View_User_Permissions": ["用户编号", "用户名", "全名", "邮箱", "是否激活", "权限列表"],
        "View_Task_Execution_Stats": ["用户编号", "用户名", "创建任务数", "被指派任务数", "执行任务数", "已完成任务数"],
        "View_Container_Location_Tracking": ["集装箱编号", "箱号", "当前状态", "当前位置", "堆场区", "贝位", "层号"],
        "View_Vessel_Visit_Statistics": ["船舶编号", "船舶名称", "访问次数", "处理集装箱总数", "任务总数"],
        "View_Yard_Available_Slots": ["堆场区编号", "堆场区名称", "堆栈编号", "贝位", "排号", "箱位编号", "层号", "箱位状态"],
        "View_Pending_Tasks": ["任务编号", "任务类型", "优先级", "箱号", "起始位置", "目标位置", "船舶名称", "创建人", "指派给"],
    }

    db_view_samples = {}
    for vname, cols in view_columns.items():
        db_view_samples[vname] = fetch_view_sample(vname, cols, limit=5)

    # 显示名称映射（可修改为更友好的中文标题）
    display_names = {
        "View_Yard_Inventory_Live": "堆场实时库存",
        "View_Task_Details": "任务详情",
        "View_Vessel_Visit_Details": "船舶访问详情",
        "View_Booking_Details": "订舱单详情",
        "View_Yard_Utilization": "堆场利用率",
        "View_Container_Status_Summary": "集装箱状态统计",
        "View_User_Permissions": "用户权限",
        "View_Task_Execution_Stats": "任务执行统计",
        "View_Container_Location_Tracking": "集装箱位置追踪",
        "View_Vessel_Visit_Statistics": "船舶访问统计",
        "View_Yard_Available_Slots": "堆场可用空位",
        "View_Pending_Tasks": "待执行任务",
    }
    # 把 display_name 嵌入 sample 以便模板直接使用
    for vname, sample in db_view_samples.items():
        sample['display_name'] = display_names.get(vname, vname)

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
        # 新增：各数据库视图的样本数据，用于仪表盘渲染
        'db_view_samples': db_view_samples,
    }


