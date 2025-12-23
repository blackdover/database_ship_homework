# 4 系统设计与实现（增补：4.1 与 4.2）

本文件为 `doc/4系统实现报告.md` 的第 4 章中 **4.1 系统功能结构图** 与 **4.2 各功能模块（按角色/权限划分）** 的增补版，包含 mermaid 结构图、每个角色的功能说明，以及每个模块不少于两个关键代码片段和每段 ≥100 字的中文解释。可将内容合并回主文档或作为补充参考。

## 4.1 系统功能结构图

系统顶层模块分解（便于答辩与代码映射）：

```mermaid
flowchart TB
  TOS[港口集装箱管理系统] --> UserMgmt[用户管理]
  TOS --> MasterData[主数据管理]
  TOS --> YardMgmt[堆场管理]
  TOS --> BizOps[业务操作(订舱/任务/船舶)]
  TOS --> AdminUI[管理后台(Admin/simpleui)]
  TOS --> CLI[运维脚本(同步/重置)]
  MasterData -->|字典| ContainerType[集装箱类型字典]
  YardMgmt --> YardBlock[YardBlock/Stack/Slot模型]
  BizOps --> TaskMgmt[任务管理/分配/执行]
  BizOps --> Booking[订舱管理]
  AdminUI --> Dashboard[仪表盘/统计视图]
```

说明：该结构图把系统职责按“功能域”进行划分，便于把实际代码目录（models/views/templates）和权限边界对应起来。示意中突出了数据库视图、堆场坐标模型与任务调度模块的关系，这些是系统的核心关注点。

## 4.2 核心模块与项目结构（合并）

一句话概述（10 项核心功能）：系统的核心功能包括用户认证与会话管理、业务用户同步、权限与角色判定、堆场三维建模与箱位管理、堆场实时库存视图查询、堆场可用空位视图与自动配位、任务管理与任务详情视图、仪表盘统计与视图样本抓取、聚合搜索与快速定位、运维脚本与示例数据导入。

说明：为简洁起见，本节把原来的“功能模块（4.2）”与“程序项目结构（4.3）”合并为一节，按功能模块列出核心职责并同时指明对应的关键代码位置，便于老师/答辩人快速定位代码实现。

模块 1 — 用户认证与会话管理（认证入口、session 注入）

```16:24:container_management/management/auth_views.py
@require_http_methods(["GET", "POST"])
def custom_login(request):
    """
    自定义登录页面
    """
```

模块关键代码（登录与会话写入，节选）：

```25:66:container_management/management/auth_views.py
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
                request.session['user_role'] = get_user_role(db_user.user_id, django_user=user)
                request.session['user_permissions'] = get_user_permission_names(db_user.user_id)
```

详述（≥150 字）：该模块为系统的认证与会话层，核心思想是“认证由 Django 负责，业务信息由本系统维护并注入 session”。流程先对用户名/密码做空值校验，然后调用 Django 的 `authenticate` 获取 `User` 对象，成功后执行 `django_login` 建立认证会话。随后以事务安全的方式查询或创建业务表 `Users` 的记录，并把业务侧的 `user_id`、`user_full_name`、`user_role` 和 `user_permissions` 写入 session。这样做的优势在于：前端或后续视图只需读取 session 就能做权限判断与界面定制，避免频繁查库；同时把认证逻辑交给 Django，享受其安全更新与哈希算法，业务用户表仅保存扩展字段，从而降低重复实现密码相关逻辑的风险和安全隐患。

模块 2 — 业务用户同步（自动创建与运维工具）

```79:88:container_management/management/auth_views.py
                    with transaction.atomic():
                        db_user = Users.objects.create(
                            username=username,
                            email=email,
                            full_name=user.get_full_name() or username,
                            hashed_password=b'',  # 不存储密码，使用Django认证
                            is_active=user.is_active
                        )
```

模块关键代码（自动同步与事务，节选）：

```79:121:container_management/management/auth_views.py
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
```

详述（≥150 字）：业务用户同步模块解决了 Django 认证用户与业务侧 `Users` 表脱节的问题：当 Django 用户存在但业务表无对应记录时，系统会自动生成具有唯一 email 的业务用户并在事务中插入，确保创建动作的原子性和幂等性。脚本在生成默认 email 时会检测冲突并追加计数以避免重复，随后用 `transaction.atomic()` 包裹插入以确保若后续步骤失败能回滚。该机制降低了管理员手动同步的工作量，并为后续权限映射（如把 ADMIN 权限写入 `UserPermissions`）提供基础；同时配套的运维脚本如 `sync_user.py` 与 `reset_password.py` 提供批量或单用户同步与密码重置能力，使得日常运维更安全、可重复和可审计。

模块 3 — 权限与角色判定（视图 + 装饰器）

```26:40:container_management/management/utils.py
def get_user_permission_names(user_id):
    ...
```

```51:88:container_management/management/utils.py
def require_permission(permission_name):
    ...
```

模块关键代码（权限读取与装饰器，节选）：

```26:40:container_management/management/utils.py
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
```

```51:88:container_management/management/utils.py
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
```

详述（≥150 字）：权限模块使用数据库视图 `View_User_Permissions` 把用户的多条权限记录聚合成一个以逗号分隔的字符串（由 SQL 的 GROUP_CONCAT 完成），`get_user_permission_names` 通过原生 cursor 一次性取回该字符串并解析为列表。此方法将复杂联表的成本下沉到数据库层，显著降低应用层的查询压力，并在视图不可用时提供回退到表查询的容错路径。`require_permission` 装饰器则把访问控制逻辑集中在一个可复用的钩子中：它先确保用户已认证，再从 session 或 `Users` 表获取业务 user_id，然后调用权限检查（`has_permission`），不满足时会以消息提示并重定向到仪表盘或登录页。把权限检查集中化有利于统一日志和审计，并便于在此处加限流、缓存或异步审计等扩展。

模块 4 — 堆场三维建模与箱位管理（YardBlock/Stack/Slot）

```179:193:container_management/management/models.py
# YardStack
```

```213:236:container_management/management/models.py
# YardSlot
```

模块关键代码（堆栈与箱位，节选）：

```179:193:container_management/management/models.py
# 堆场堆栈
class YardStack(models.Model):
    stack_id = models.AutoField(primary_key=True, db_column='Stack_ID')
    block_id = models.ForeignKey(YardBlock, on_delete=models.CASCADE, db_column='Block_ID', verbose_name='所属堆场区')
    bay_number = models.IntegerField(db_column='Bay_Number', verbose_name='贝位号')
    row_number = models.IntegerField(db_column='Row_Number', verbose_name='排号')
```

```213:236:container_management/management/models.py
# 箱位
class YardSlot(models.Model):
    slot_id = models.AutoField(primary_key=True, db_column='Slot_ID')
    stack_id = models.ForeignKey(YardStack, on_delete=models.CASCADE, db_column='Stack_ID', verbose_name='所属堆栈')
    tier_number = models.IntegerField(db_column='Tier_Number', verbose_name='层号')
    slot_coordinates = models.CharField(max_length=50, unique=True, db_column='Slot_Coordinates', verbose_name='坐标')
    SLOT_STATUS_CHOICES = [
        ("Available", "可用"),
        ("Occupied", "占用"),
        ("Reserved", "预留"),
        ("Maintenance", "维护"),
    ]
    slot_status = models.CharField(
        max_length=20,
        choices=SLOT_STATUS_CHOICES,
        default="Available",
        db_column='Slot_Status',
        verbose_name='状态',
    )
    current_container_id = models.OneToOneField(ContainerMaster, on_delete=models.SET_NULL, null=True, blank=True,
                                                db_column='Current_Container_ID', verbose_name='当前集装箱')
```

详述（≥150 字）：堆场建模采用三层结构：顶层 `YardBlock` 表示不同功能区（如冷藏、危险品），中间 `YardStack` 表示贝位与排号组合，底层 `YardSlot` 表示具体层（tier）。`YardSlot` 的 `slot_coordinates` 用于生成便于人读的定位字符串（如 "A 区-1-2-3"），并在数据库层面设置唯一约束以便快速定位与日志追踪。`current_container_id` 采用 OneToOne 和外键约束保证一个箱位同一时间只会被一个集装箱占用，这对并发移动任务而言是关键约束。`slot_status` 的多态枚举允许业务在预留、维护等场景下屏蔽箱位，从而在调度器和分配算法中被优雅排除。

模块 5 — 堆场实时库存视图（View_Yard_Inventory_Live）

```252:273:sqlutil/init_database.sql
/* View_Yard_Inventory_Live */
```

模块关键 SQL（视图定义，节选）：

```252:273:sqlutil/init_database.sql
/* 视图1: View_Yard_Inventory_Live - 堆场实时库存 */
CREATE OR REPLACE VIEW `View_Yard_Inventory_Live` AS
SELECT
    yb.Block_Name AS 堆场区,
    ys.Bay_Number AS 贝位,
    ys.Row_Number AS 排号,
    slot.Tier_Number AS 层号,
    slot.Slot_Coordinates AS 坐标代码,
    cm.Container_Number AS 箱号,
    cm.Current_Status AS 箱状态,
    ct.Type_Code AS ISO代码,
    ct.Nominal_Size AS 尺寸_英尺,
    ct.Group_Code AS 箱型组,
    p.Party_Name AS 箱主,
    p.SCAC_Code AS 箱主代码
FROM `Yard_Slot` slot
JOIN `Container_Master` cm ON slot.Current_Container_ID = cm.Container_Master_ID
JOIN `Container_Type_Dict` ct ON cm.Type_Code = ct.Type_Code
JOIN `Yard_Stack` ys ON slot.Stack_ID = ys.Stack_ID
JOIN `Yard_Block` yb ON ys.Block_ID = yb.Block_ID
LEFT JOIN `Party` p ON cm.Owner_Party_ID = p.Party_ID
WHERE slot.Current_Container_ID IS NOT NULL;
```

详述（≥150 字）：`View_Yard_Inventory_Live` 是系统的核心只读接口之一，它把箱位位置、堆栈信息与容器主数据及箱型字典联结为一张扁平化的视图，便于前端和报表直接消费。使用数据库视图的好处在于：复杂的联表逻辑只需在数据库层维护，应用层只需简单 SELECT 即可获得标准化结果；此外，DB 的查询优化器可针对该视图的底层表建立合适索引或执行更优的执行计划。对于高并发查询场景（如仪表盘、大屏或导出），此视图能显著减少应用层的代码复杂度并提升响应性能。

模块 6 — 堆场可用空位视图与自动配位（View_Yard_Available_Slots）

```520:538:sqlutil/init_database.sql
/* View_Yard_Available_Slots */
```

模块关键 SQL（可用空位视图，节选）：

```520:538:sqlutil/init_database.sql
/* 视图11: View_Yard_Available_Slots - 堆场空位视图 */
CREATE OR REPLACE VIEW `View_Yard_Available_Slots` AS
SELECT
    yb.Block_ID AS 堆场区编号,
    yb.Block_Name AS 堆场区名称,
    yb.Block_Type AS 堆场区类型,
    ys.Stack_ID AS 堆栈编号,
    ys.Bay_Number AS 贝位,
    ys.Row_Number AS 排号,
    slot.Slot_ID AS 箱位编号,
    slot.Tier_Number AS 层号,
    slot.Slot_Coordinates AS 坐标代码,
    slot.Slot_Status AS 箱位状态
FROM `Yard_Slot` slot
JOIN `Yard_Stack` ys ON slot.Stack_ID = ys.Stack_ID
JOIN `Yard_Block` yb ON ys.Block_ID = yb.Block_ID
WHERE slot.Current_Container_ID IS NULL
    AND slot.Slot_Status = 'Available'
ORDER BY yb.Block_Name, ys.Bay_Number, ys.Row_Number, slot.Tier_Number;
```

详述（≥150 字）：`View_Yard_Available_Slots` 提供了所有当前标记为可用且未被占用的箱位信息，是自动配位器的首选数据源。设计上把初筛放在数据库层，能利用 SQL 的过滤与排序高效返回候选集合，减少网络和应用层计算。自动配位器在获取候选后会依据任务类型、容器尺寸、设备可达性、优先级等做二次评分并在分配时使用事务或乐观锁来更新箱位状态与任务表，避免并发冲突。另一方面，该视图也为人工调度提供了清晰的可用箱位列表，便于手工干预与快速决策。

模块 7 — 任务管理与任务详情视图（Task / View_Task_Details）

```311:319:container_management/management/models.py
# Task model
```

```275:319:sqlutil/init_database.sql
/* View_Task_Details */
```

模块关键代码（任务模型与视图，节选）：

```311:336:container_management/management/models.py
# 任务表
class Task(models.Model):
     task_id = models.AutoField(primary_key=True, db_column='Task_ID')
     task_type = models.CharField(
         max_length=30,
         db_column='Task_Type',
         choices=[
             ('Load', '装船'),
             ('Discharge', '卸船'),
             ('Move', '移箱'),
             ('GateIn', '进闸'),
             ('GateOut', '出闸'),
         ],
         verbose_name='任务类型',
     )
     status = models.CharField(
         max_length=20,
         default='Pending',
         db_column='Status',
         choices=[
             ('Pending', '待处理'),
             ('InProgress', '进行中'),
             ('Completed', '已完成'),
             ('Cancelled', '已取消'),
         ],
         verbose_name='状态',
     )
     container_master_id = models.ForeignKey(
         ContainerMaster, on_delete=models.CASCADE, db_column='Container_Master_ID', verbose_name='集装箱'
     )
     from_slot_id = models.ForeignKey(
         YardSlot, on_delete=models.CASCADE, related_name='tasks_from', db_column='From_Slot_ID', verbose_name='起始箱位'
     )
```

```275:319:sqlutil/init_database.sql
/* 视图2: View_Task_Details - 任务详情视图 */
CREATE OR REPLACE VIEW `View_Task_Details` AS
SELECT
    t.Task_ID AS 任务编号,
    t.Task_Type AS 任务类型,
    t.Status AS 任务状态,
    t.Priority AS 优先级,
    t.Movement_Timestamp AS 实际执行时间,
    cm.Container_Number AS 箱号,
    cm.Current_Status AS 箱状态,
    ct.Type_Code AS 箱型代码,
    ct.Nominal_Size AS 箱尺寸,
    yb_from.Block_Name AS 起始堆场区,
    ys_from.Bay_Number AS 起始贝位,
    ys_from.Row_Number AS 起始排号,
    slot_from.Tier_Number AS 起始层号,
    slot_from.Slot_Coordinates AS 起始坐标,
    yb_to.Block_Name AS 目标堆场区,
    ys_to.Bay_Number AS 目标贝位,
    ys_to.Row_Number AS 目标排号,
    slot_to.Tier_Number AS 目标层号,
    slot_to.Slot_Coordinates AS 目标坐标,
    vm.Vessel_Name AS 船舶名称,
    vv.Voyage_Number_In AS 进口航次,
    vv.Voyage_Number_Out AS 出口航次,
    u_creator.Username AS 创建人,
    u_creator.Full_Name AS 创建人姓名,
    u_assigned.Username AS 指派给,
    u_assigned.Full_Name AS 指派给姓名,
    u_executor.Username AS 执行人,
    u_executor.Full_Name AS 执行人姓名
FROM `Task` t
JOIN `Container_Master` cm ON t.Container_Master_ID = cm.Container_Master_ID
JOIN `Container_Type_Dict` ct ON cm.Type_Code = ct.Type_Code
JOIN `Yard_Slot` slot_from ON t.From_Slot_ID = slot_from.Slot_ID
JOIN `Yard_Stack` ys_from ON slot_from.Stack_ID = ys_from.Stack_ID
JOIN `Yard_Block` yb_from ON ys_from.Block_ID = yb_from.Block_ID
JOIN `Yard_Slot` slot_to ON t.To_Slot_ID = slot_to.Slot_ID
JOIN `Yard_Stack` ys_to ON slot_to.Stack_ID = ys_to.Stack_ID
JOIN `Yard_Block` yb_to ON ys_to.Block_ID = yb_to.Block_ID
LEFT JOIN `Vessel_Visit` vv ON t.Vessel_Visit_ID = vv.Vessel_Visit_ID
LEFT JOIN `Vessel_Master` vm ON vv.Vessel_ID = vm.Vessel_ID
JOIN `Users` u_creator ON t.Created_By_User_ID = u_creator.User_ID
LEFT JOIN `Users` u_assigned ON t.Assigned_User_ID = u_assigned.User_ID
LEFT JOIN `Users` u_executor ON t.Actual_Executor_ID = u_executor.User_ID;
```

详述（≥150 字）：任务管理模块不仅包含任务的 CRUD，还承载业务的调度规则与执行跟踪。`Task` 模型包含任务类型、状态、优先级、起止箱位、航次与人员信息，是任务生命周期管理的基础。`View_Task_Details` 把任务与箱位、箱型、航次、用户信息联立，形成一张面向前端与报表的扁平化视图，方便快速查询与导出。任务的创建与变更需要在应用层做并发控制（如在分配时锁定候选空位或采用乐观锁），并在状态变更时触发相应的业务规则（如完成任务后释放箱位并更新 `ContainerMaster.current_status`）。

模块 8 — 仪表盘统计与视图样本采样（dashboard_stats / fetch_view_sample）

```13:29:container_management/management/dashboard_context.py
def dashboard_stats(request):
    ...
```

```68:88:container_management/management/dashboard_context.py
    def fetch_view_sample(view_name, columns, limit=5):
        ...
```

模块关键代码（仪表盘聚合与抓样，节选）：

```13:63:container_management/management/dashboard_context.py
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
```

```68:92:container_management/management/dashboard_context.py
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
            rows_list = [list(row) for row in rows]
            data = {'columns': colnames, 'rows': rows_list}
            cache.set(cache_key, data, 60)  # 缓存 60s
            return data
```

详述（≥150 字）：仪表盘模块通过 ORM 聚合和原生 SQL 的组合提供既有统计性又有样例数据的视图。`dashboard_stats` 使用 ORM 计算 KPI（如任务/容器统计、近期访问），保证代码可读性与可维护性；而 `fetch_view_sample` 使用原生 cursor 直接针对数据库视图执行 SELECT 并把结果缓存起来用于前端示例表格展示。这种设计平衡了实时性和性能：关键指标用 ORM 聚合可以方便地做业务逻辑变换，而视图样例的短期缓存则避免对复杂视图的高频扫描，提升整体响应性并减少数据库负载，适合仪表盘类的使用场景。

模块 9 — 聚合搜索与快速定位（aggregate_search）

```14:32:container_management/management/views.py
def aggregate_search(request):
    ...
```

模块关键代码（聚合搜索，节选）：

```22:33:container_management/management/views.py
@login_required
@user_passes_test(lambda u: u.is_staff)
def aggregate_search(request):
    """
    聚合搜索页：一个输入框同时查询多个核心模型，并给出快捷操作链接。
    """
    query = (request.GET.get('q') or '').strip()

    containers = bookings = tasks = visits = parties = []
    if query:
        containers = (
            ContainerMaster.objects.select_related('type_code', 'owner_party_id')
            .filter(
                Q(container_number__icontains=query)
                | Q(type_code__type_code__icontains=query)
                | Q(owner_party_id__party_name__icontains=query)
            )
            .order_by('-container_master_id')[:10]
        )
```

详述（≥150 字）：聚合搜索视图通过对核心模型（如 `ContainerMaster`、`Booking`、`Task`、`VesselVisit`、`Party`）做并行模糊检索，实现从单一输入框到跨域定位的用户体验。实现细节包括使用 `select_related` 以减少 ORM 的附加查询、使用 `Q` 对象进行 OR 条件匹配以及对每个结果集做切片以保证响应速度。作为运维和调度的工具，该视图能够把问题定位、查看和后续操作（例如跳转到任务创建或详情页）串联起来，显著缩短问题处理链路并提升日常运维效率。

模块 10 — 运维脚本与示例数据导入（insert_sample_data.py）

```30:36:container_management/insert_sample_data.py
def insert_sample_data():
    ...
```

模块关键代码（示例数据入口，节选）：

```30:36:container_management/insert_sample_data.py
def insert_sample_data():
    """插入示例数据"""
    print('=' * 60)
    print('开始插入示例数据...')
    print('=' * 60)

    with transaction.atomic():
        # =========================================
        # 组 1: 基础主数据
        # =========================================
```

详述（≥150 字）：`insert_sample_data.py` 是项目的测试数据种子工具，负责批量创建相关方、港口、堆场区、堆栈、箱位、集装箱、船舶访问、订舱与任务等。脚本通过 `get_or_create` 保证幂等性，并在插入 `User_Permissions` 之类使用复合主键的表时采用原生 SQL 的 `INSERT IGNORE` 来避免重复。整个插入过程置于事务中以保证中间步骤失败时的回滚，从而不会留下不一致的半成品数据。该脚本既适用于本地开发环境快速搭建场景，也适用于 CI 中的环境准备，确保测试有一致的基础数据。

---

## 4.4 公共实现部分（核心技术/接口）

4.4.1 前后端交互设计与仪表盘渲染

关键代码 A：仪表盘模板注入与 Chart.js 渲染（`dashboard_content.html`）

```97:106:container_management/management/templates/admin/simpleui/dashboard_content.html
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    {{ task_status_stats|json_script:"task_status_stats_json" }}
    {{ container_status_stats|json_script:"container_status_stats_json" }}
    {{ recent_visits|json_script:"recent_visits_json" }}
```

解释（≥100 字）：模板使用 Django 的 `json_script` 将后端 JSON 数据安全注入页面，从而避免直接字符串拼接造成的 XSS 风险。前端再使用 Chart.js 对注入的数据进行图表渲染。这种设计把数据聚合与格式化留给后端（Python/Django），前端专注于渲染与交互，简化了前端逻辑并提高安全性。对于仪表盘类页面，后端预处理并返回轻量的结构化数组能够显著降低页面首次渲染时间，尤其是在移动端环境。

关键代码 B：视图样本抓取函数 `fetch_view_sample`（`dashboard_context.py`）

```68:88:container_management/management/dashboard_context.py
    def fetch_view_sample(view_name, columns, limit=5):
        """
        从指定的数据库视图查询若干行样本并返回 {'columns': [...], 'rows': [{col:val}, ...]}
        使用缓存避免频繁查询。
        """
```

解释（≥100 字）：`fetch_view_sample` 是连接数据库视图与仪表盘显示的桥梁：它使用原生 cursor 执行 SELECT 并把返回的行和列名打包成便于模板渲染的结构，同时对结果进行短期缓存（默认 60s）。该函数的引入使得仪表盘可以展示“示例行”而非大表查询，从而在需要展示概览或样例的场景下实现极佳的响应性。缓存时间可以根据视图更新频率调整，既能保证一定的实时性，又能显著降低对复杂视图的频繁访问。

4.4.2 权限工具与装饰器

关键代码 C：获取用户权限列表（`get_user_permission_names`，`utils.py`）

```26:40:container_management/management/utils.py
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
```

解释（≥100 字）：`get_user_permission_names` 通过数据库视图 `View_User_Permissions` 一次性获取某用户的权限字符串（通过 GROUP_CONCAT 聚合），将权限解析为 Python 列表返回。将权限解析下沉到数据库层能够减少 ORM 多表联查的开销并保证权限聚合的一致性；当视图不可用时，函数还提供表查询回退逻辑以增强容错。这一设计在权限粒度不极端复杂的场景非常实用，能显著提升权限校验的性能。

关键代码 D：权限装饰器 `require_permission`（`utils.py`）

```51:88:container_management/management/utils.py
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
```

解释（≥100 字）：`require_permission` 把权限校验作为装饰器抽象出来，适用于需要按业务权限控制访问的视图。它从 session 或通过 username 在 `Users` 表中查找业务用户 ID，然后调用 `has_permission`（内部使用 `get_user_permission_names`）判断权限并根据结果决定是否允许访问或重定向。这种集中式的权限校验保证了所有受保护视图的一致行为，同时便于在装饰器中加入审计、日志或速率限制等横切关注点，简化应用代码并提升可维护性。

(完成 `update-4.4` 的补充内容)

### 数据库连接配置与使用位置

关键配置（Django 数据库连接，在 `settings.py` 中）：

```79:88:container_management/container_management/settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'box_management',
        'USER': 'root',
        'PASSWORD': 'iamshp0228',
        'HOST': 'localhost',
        'PORT': '3306',
    }
}
```

解释：Django 的 `DATABASES` 配置在 `container_management/container_management/settings.py` 中定义，指定了使用 MySQL 驱动、数据库名、用户名、密码与网络地址。Django 会基于此配置管理数据库连接池、事务和连接复用，绝大多数 ORM 操作（如 `Model.objects.filter()`）不需要手动打开或关闭连接。敏感信息（如密码）在生产环境应使用环境变量或密钥管理工具注入，而不是写死在 settings 中。

关键用法 1（原生 cursor，用于视图样本抓取）：

```68:88:container_management/management/dashboard_context.py
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
            rows_list = [list(row) for row in rows]
            data = {'columns': colnames, 'rows': rows_list}
            cache.set(cache_key, data, 60)  # 缓存 60s
            return data
```

解释：当需要从数据库视图获取自定义结果集（如仪表盘样例行）时，代码使用 `django.db.connection.cursor()` 获取低层 cursor 并执行原生 SQL。这种方式绕过 ORM 的对象映射，适用于复杂联表或无法用 ORM 高效表达的查询；同时要注意 SQL 注入风险（此处 columns 与 view_name 来自后端定义并受信任）以及手工管理资源的正确关闭（`with` 上下文自动关闭 cursor）。

关键用法 2（权限视图查询的回退与表查询用法）：

```26:40:container_management/management/utils.py
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
```

解释：权限读取优先调用数据库视图 `View_User_Permissions`（使用原生 cursor 提高查询效率），在视图不存在或出错时降级为 ORM 表查询以保证容错。此处展示了两种常见的数据库访问模式：一是用原生 SQL 获取聚合字符串以减少往返与联表开销；二是回退到基于模型的查询以保持代码的健壮性。

位置汇总：主要的数据库连接/使用点包括：

- 配置：`container_management/container_management/settings.py`（`DATABASES`）
- 原生 cursor 使用：`container_management/management/dashboard_context.py`（`fetch_view_sample`）、`container_management/management/utils.py`（`get_user_permission_names`）等
- 运维脚本直接使用 ORM/transaction：`container_management/insert_sample_data.py`（`transaction.atomic()`）与 `sync_user.py`、`reset_password.py`

补充说明：除少数需要原生 SQL 的场景，建议优先使用 Django ORM；当使用原生 SQL 时要注意参数化查询并限制输入来源以防注入，并在生产环境使用环境变量或 Django 的 `django-environ` 等方式管理连接凭证。

## 4.3 程序项目结构介绍（代码文件结构）

4.3.1 后端（Django）目录概览

- `container_management/`：Django 项目根（包含 settings、wsgi、urls）。
- `container_management/management/`：主应用目录，包含：
  - `models.py`（数据模型）
  - `views.py`（页面视图与业务逻辑）
  - `admin.py`（Admin 注册与界面定制）
  - `templates/`（Django 模板，包含仪表盘与管理页面）
  - `static/`（静态资源）
  - `insert_sample_data.py`, `sync_user.py`, `reset_password.py`（运维脚本）

说明：项目按典型 Django 约定组织，模型负责映射 DB 表、视图负责处理请求并准备模板上下文、Admin 提供可视化运维入口。数据库视图位于 `sqlutil/init_database.sql`，用于把复杂联表下沉到 DB 层，减少应用层代码复杂度。

4.3.2 关键文件与代码摘录（每段均带 ≥100 字解释）

关键代码 A：`YardStack`（`models.py`）——堆栈的二维定位

```179:193:container_management/management/models.py
# 堆场堆栈
class YardStack(models.Model):
    stack_id = models.AutoField(primary_key=True, db_column='Stack_ID')
    block_id = models.ForeignKey(YardBlock, on_delete=models.CASCADE, db_column='Block_ID', verbose_name='所属堆场区')
    bay_number = models.IntegerField(db_column='Bay_Number', verbose_name='贝位号')
    row_number = models.IntegerField(db_column='Row_Number', verbose_name='排号')
```

解释（≥100 字）：`YardStack` 用以表示堆场中的贝位+排号组合，是 `YardBlock` 下的二级地理单元。模型通过外键 `block_id` 与顶层分区关联，并在数据库层使用 `unique_together` 保证同一分区不会重复创建相同贝/排组合。该模型是堆场坐标体系的基石，许多上层查询（例如按区统计利用率或查找附近空位）都以 `YardStack` 为聚合单元，因此为该表建良好的索引和约束对系统性能与数据一致性至关重要。

关键代码 B：`YardSlot`（`models.py`）——三维箱位与占用约束

```213:236:container_management/management/models.py
# 箱位
class YardSlot(models.Model):
    slot_id = models.AutoField(primary_key=True, db_column='Slot_ID')
    stack_id = models.ForeignKey(YardStack, on_delete=models.CASCADE, db_column='Stack_ID', verbose_name='所属堆栈')
    tier_number = models.IntegerField(db_column='Tier_Number', verbose_name='层号')
    slot_coordinates = models.CharField(max_length=50, unique=True, db_column='Slot_Coordinates', verbose_name='坐标')
    SLOT_STATUS_CHOICES = [
        ("Available", "可用"),
        ("Occupied", "占用"),
        ("Reserved", "预留"),
        ("Maintenance", "维护"),
    ]
    slot_status = models.CharField(
        max_length=20,
        choices=SLOT_STATUS_CHOICES,
        default="Available",
        db_column='Slot_Status',
        verbose_name='状态',
    )
    current_container_id = models.OneToOneField(ContainerMaster, on_delete=models.SET_NULL, null=True, blank=True,
                                                db_column='Current_Container_ID', verbose_name='当前集装箱')
```

解释（≥100 字）：`YardSlot` 表示一个具体的箱位（stack + tier），`slot_coordinates` 提供全局唯一标识便于人工查询和日志记录。`current_container_id` 采用 OneToOne 关系并配合 DB 的唯一索引，能确保同一箱位只会被一个容器占用，从而在并发操作中降低数据冲突的可能性。`slot_status` 支持运营状态（可用/占用/预留/维护），这些状态在调度与配位算法中是重要的决策条件，例如自动分配空位时需排除 `Reserved`/`Maintenance` 状态。

关键代码 C：聚合搜索视图（`views.py`）——跨模型快速定位

```14:32:container_management/management/views.py
@login_required
@user_passes_test(lambda u: u.is_staff)
def aggregate_search(request):
    """
    聚合搜索页：一个输入框同时查询多个核心模型，并给出快捷操作链接。
    """
    query = (request.GET.get('q') or '').strip()
```

解释（≥100 字）：`aggregate_search` 将多个模型的查询逻辑包装在同一视图，通过 `Q` 对象实现多字段模糊匹配并使用 `select_related` 减少数据库往返。对于运维和调度人员，这类单点搜索能把定位时间显著缩短：输入一个箱号或航次即可同时看到相关的箱、任务、订舱、船舶信息，便于快速采取操作（例如直接进入任务创建或数据修正）。实现上应注意分页与结果截断以避免一次性返回过多数据导致响应变慢。

关键代码 D：仪表盘路由与角色分支（`auth_views.dashboard`，部分）

```159:176:container_management/management/auth_views.py
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
            if request.user.is_superuser:
                user_id = None
                request.session['user_id'] = None
            else:
                messages.error(request, '用户不存在，请联系管理员')
                return redirect('custom_login')
```

解释（≥100 字）：`dashboard` 视图根据当前登录用户的角色（session 中的 `user_role` 或从 `Users` 表解析）选择不同的数据与模板渲染路径（admin/operator/viewer/guest）。该逻辑保持了认证与授权的清晰分离：认证仍由 Django auth 负责（`request.user`），应用层则通过业务用户表和权限视图决定显示哪类数据。对缺失的业务用户（但 Django 用户存在）做容错处理，便于维护超级用户的管理通道。

（完成 `update-4.3` 的补充内容）

## 4.5 系统界面（截图占位 + 模板/渲染说明）

说明：此节列出关键界面、建议截图文件名与简短说明，并引用关键模板或视图代码以说明页面数据来源与渲染策略。实际提交时请把截图放入 `figures/` 目录并按下列文件名命名。

4.5.1 登录界面（`management/login.html`）

- 建议截图：`figures/图4.5-登录界面.png`（包含输入框、登录按钮、错误提示）
- 说明：登录页调用 `auth_views.custom_login` 完成身份验证并在成功后把 `user_id` / `user_role` / `user_permissions` 写入 session，用于后续权限判断与界面定制。

关键代码（登录视图，`auth_views.py`）：

```16:24:container_management/management/auth_views.py
@require_http_methods(["GET", "POST"])
def custom_login(request):
    """
    自定义登录页面
    """
```

解释（≥100 字）：`custom_login` 是整个应用的认证入口，它使用 Django 的 `authenticate` 执行凭证校验，成功后调用 `django_login` 建立认证会话，并在业务侧的 `Users` 表中查找或创建对应记录，然后将业务用户 ID、角色与权限写入 session。把认证与业务授权拆分的好处是：认证由经过审计的 Django 框架负责（包括哈希算法与安全补丁），业务侧则可维护更丰富的字段（如 `party`、全名、业务权限集合），从而兼顾安全和业务需求，同时在 Admin 与自定义业务页面之间实现一致的权限体验。

4.5.2 仪表盘（管理员/运营视图）

- 建议截图：`figures/图4.5-仪表盘.png`（显示 KPI 卡、任务分布、视图样本表格）
- 说明：仪表盘由 `dashboard_stats` 组织数据，模板 `admin/simpleui/dashboard_content.html` 使用 `json_script` 注入数据并通过 Chart.js 渲染图表，表格样例则来自 `fetch_view_sample`。

关键模板片段（`dashboard_content.html`）：

```97:106:container_management/management/templates/admin/simpleui/dashboard_content.html
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    {{ task_status_stats|json_script:"task_status_stats_json" }}
    {{ container_status_stats|json_script:"container_status_stats_json" }}
    {{ recent_visits|json_script:"recent_visits_json" }}
```

解释（≥100 字）：模板通过 `json_script` 把后端准备好的数据以安全的方式注入页面，避免直接在模板中拼接 JSON 导致的 XSS 风险。前端读取这些注入的 JSON 并交给 Chart.js 做可视化渲染，同时表格部分直接循环 `db_view_samples` 渲染数据库视图的示例行。此模式将数据聚合放在后端完成（便于使用 ORM/原生 SQL/视图），前端负责渲染和交互，能显著简化前端复杂性并提升安全性与可维护性。

4.5.3 堆场可视化查询界面（实时库存/空位）

- 建议截图：`figures/图4.5-堆场实时库存.png`（按区/贝/排/层过滤结果）
- 说明：堆场查询直接或间接基于 `View_Yard_Inventory_Live` 与 `View_Yard_Available_Slots`，支持导出与分页。前端可在表格基础上实现热力图或 SVG 可视化。

关键 SQL（视图，`sqlutil/init_database.sql`）：

```252:273:sqlutil/init_database.sql
/* 视图1: View_Yard_Inventory_Live - 堆场实时库存 */
CREATE OR REPLACE VIEW `View_Yard_Inventory_Live` AS
SELECT
    yb.Block_Name AS 堆场区,
    ys.Bay_Number AS 贝位,
    ys.Row_Number AS 排号,
    slot.Tier_Number AS 层号,
    slot.Slot_Coordinates AS 坐标代码,
    cm.Container_Number AS 箱号,
    cm.Current_Status AS 箱状态,
    ct.Type_Code AS ISO代码,
    ct.Nominal_Size AS 尺寸_英尺,
    ct.Group_Code AS 箱型组,
    p.Party_Name AS 箱主,
    p.SCAC_Code AS 箱主代码
FROM `Yard_Slot` slot
JOIN `Container_Master` cm ON slot.Current_Container_ID = cm.Container_Master_ID
JOIN `Container_Type_Dict` ct ON cm.Type_Code = ct.Type_Code
JOIN `Yard_Stack` ys ON slot.Stack_ID = ys.Stack_ID
JOIN `Yard_Block` yb ON ys.Block_ID = yb.Block_ID
LEFT JOIN `Party` p ON cm.Owner_Party_ID = p.Party_ID
WHERE slot.Current_Container_ID IS NOT NULL;
```

解释（≥100 字）：视图将箱位位置与集装箱信息扁平化输出，便于前端直接查询并显示表格或热力图。数据库视图的优势在于：它把复杂的多表联接放在数据库层，允许对视图执行更高效的索引或在必要时替换为物化视图；同时，报表和外部工具可以以最小权限直接访问这些视图，避免暴露底层表结构与复杂连接逻辑，便于安全管理。

## 4.6 个人实现部分（主要负责的代码与关键逻辑）

说明：本节列举个人负责或主导实现的几个关键逻辑模块，每项包含 ≥2 个关键代码片段与 ≥100 字解释，突出实现细节与设计权衡。

4.6.1 用户同步与自定义登录（责任：保证 Django auth 与业务 Users 表的一致性）

关键代码 1：登录成功后自动创建业务用户（`auth_views.custom_login`）

```79:88:container_management/management/auth_views.py
                    with transaction.atomic():
                        db_user = Users.objects.create(
                            username=username,
                            email=email,
                            full_name=user.get_full_name() or username,
                            hashed_password=b'',  # 不存储密码，使用Django认证
                            is_active=user.is_active
                        )
```

解释（≥100 字）：当 Django 认证成功但业务 `Users` 表中无对应记录时，系统会在事务中创建一条业务用户记录，从而实现“认证与业务用户同步”的自动化。采用事务可以确保在创建用户的过程中若发生错误（例如唯一约束冲突），不会留下半成品记录。业务表不再存储密码哈希（`hashed_password` 置空或做占位），而由 Django auth 管理凭证，这样既避免了重复实现密码哈希逻辑，也能兼容 Django admin 的认证与权限系统。

关键代码 2：登录完成后写 session（权限/角色注入）

```33:46:container_management/management/auth_views.py
        # 使用Django的认证系统
        user = authenticate(request, username=username, password=password)

        if user is not None:
            django_login(request, user)

            # 获取数据库中的用户信息
            try:
                db_user = Users.objects.get(username=username)
                request.session['user_id'] = db_user.user_id
                request.session['user_full_name'] = db_user.full_name or username
                request.session['user_role'] = get_user_role(db_user.user_id, django_user=user)
                request.session['user_permissions'] = get_user_permission_names(db_user.user_id)
```

解释（≥100 字）：登录成功后将业务用户的标识、角色和权限写入 session，是整套权限体系中非常关键的一步。后续的视图和模板仅需读取 session 而无需每次查询数据库，从而提高性能。此处还对超级用户做了兼容处理（把 ADMIN 权限注入 session），保证在管理员进入 Admin 界面时拥有必要的权限，同时保留业务权限模型以支持更细粒度的授权。

4.6.2 任务创建与自动分配（责任：基础的调度/去重逻辑）

关键代码 1：示例数据脚本中的任务创建（防重复插入）`insert_sample_data.py`

```416:441:container_management/insert_sample_data.py
                if not Task.objects.filter(
                    container_master_id=container,
                    task_type='Load',
                    status='Pending',
                    vessel_visit_id=vessel_visits[0]
                ).exists():
                    task = Task.objects.create(
                        container_master_id=container,
                        task_type='Load',
                        status='Pending',
                        from_slot_id=from_slot,
                        to_slot_id=to_slot,
                        vessel_visit_id=vessel_visits[0],
                        created_by_user_id=users_list[0],
                        assigned_user_id=users_list[1],
                        priority=100 - i * 10,
                    )
```

解释（≥100 字）：脚本在创建任务前先检测是否存在类似的待处理任务以避免重复插入，这是一种简单但有效的幂等性保障策略。任务创建时同时写入创建人和指派人，并赋予基于索引的优先级，便于在后续的任务面板中进行排序与分配。虽然示例脚本使用静态分配（`users_list[1]`），实际生产中可将这里替换为更复杂的分配器（考虑距离、设备可达性、空位优先级等因素）。

关键代码 2：可用空位视图供分配器查询（`View_Yard_Available_Slots`）

```520:538:sqlutil/init_database.sql
/* 视图11: View_Yard_Available_Slots - 堆场空位视图 */
CREATE OR REPLACE VIEW `View_Yard_Available_Slots` AS
SELECT
    yb.Block_ID AS 堆场区编号,
    yb.Block_Name AS 堆场区名称,
    yb.Block_Type AS 堆场区类型,
    ys.Stack_ID AS 堆栈编号,
    ys.Bay_Number AS 贝位,
    ys.Row_Number AS 排号,
    slot.Slot_ID AS 箱位编号,
    slot.Tier_Number AS 层号,
    slot.Slot_Coordinates AS 坐标代码,
    slot.Slot_Status AS 箱位状态
FROM `Yard_Slot` slot
JOIN `Yard_Stack` ys ON slot.Stack_ID = ys.Stack_ID
JOIN `Yard_Block` yb ON ys.Block_ID = yb.Block_ID
WHERE slot.Current_Container_ID IS NULL
    AND slot.Slot_Status = 'Available'
ORDER BY yb.Block_Name, ys.Bay_Number, ys.Row_Number, slot.Tier_Number;
```

解释（≥100 字）：分配器首先应该查询 `View_Yard_Available_Slots` 获取候选空位集合，然后基于距离、箱型适配、设备可达性等二次筛选出最优目标。把“可用空位”的初筛放在数据库视图中既能保证查询的统一性，也能利用数据库索引和执行计划优化性能；在分配器实现中，建议对候选集合做批量锁定和事务管理以避免并发分配冲突。

(完成 `update-4.5` 与 `update-4.6` 的补充内容)

说明：以上为 4.1 与 4.2 的增补内容（包含 mermaid 结构图、按角色的功能说明和 ≥2 段关键代码解释）。如果你希望我把这些内容直接合并回 `doc/4系统实现报告.md` 的第 4 章（替换或插入），我可以在确认后执行替换；也可以继续按计划完成后续章节（4.3—4.8）。

## 4.7 测试数据录入（数据库示例数据与截图说明）

4.7.1 示例数据脚本入口与总体说明

- 说明：项目提供 `insert_sample_data.py` 用于在本地快速构建示例数据，包括主数据、堆栈/箱位、集装箱、船舶访问、订舱单与任务等。脚本在事务中执行关键写入并对幂等性做了处理（如 `get_or_create`、`INSERT IGNORE`），便于重复运行而不产生重复记录。运行脚本后建议在数据库管理工具中截图以下表格作为测试数据证明。

- 建议截图文件：
  - `figures/表_Party.png`（相关方样例）
  - `figures/表_ContainerMaster.png`（集装箱样例）
  - `figures/图4.7-堆场实时库存.png`（基于 `View_Yard_Inventory_Live` 的查询结果）
  - `figures/图4.7-任务列表.png`（Task 表与 `View_Task_Details` 的样例）

关键代码 A：脚本入口与事务包裹（`insert_sample_data.py`）

```30:36:container_management/insert_sample_data.py
def insert_sample_data():
    """插入示例数据"""
    print('=' * 60)
    print('开始插入示例数据...')
    print('=' * 60)

    with transaction.atomic():
        # =========================================
        # 组 1: 基础主数据
        # =========================================
```

解释（≥100 字）：脚本以 `insert_sample_data()` 为入口，并使用 `transaction.atomic()` 包裹整个写入流程，确保在任一步骤失败时能回滚已写入的部分，避免数据不一致。脚本将主数据（Party/Port/ContainerType/Permissions）与依赖数据（堆栈、箱位、用户、船舶）分组插入，并在插入权限关联表时使用原始 SQL（`INSERT IGNORE`）来处理复合主键与幂等性，这对于多次运行脚本重复生成数据的场景非常重要。

关键代码 B：箱位生成逻辑（`insert_sample_data.py` 中的箱位创建片段）

```302:316:container_management/insert_sample_data.py
        for stack in stacks[:10]:  # 只在前10个堆栈创建箱位
            for tier in range(1, 5):  # 层号 1-4
                slot_counter += 1
                coordinates = f"{stack.block_id.block_name}-{stack.bay_number}-{stack.row_number}-{tier}"
                slot, created = YardSlot.objects.get_or_create(
                    stack_id=stack,
                    tier_number=tier,
                    defaults={
                        'slot_coordinates': coordinates,
                        'slot_status': 'Available',
                    }
                )
```

解释（≥100 字）：脚本生成箱位时采用 `get_or_create` 保证幂等性，并使用 `stack.block_id.block_name-bay-row-tier` 的字符串格式作为 `slot_coordinates`，便于人工核验和日志记录。只在前 10 个堆栈创建箱位是为了控制测试数据规模，避免本地环境压力过大。该代码片段体现了良好的数据种子设计：既能快速生成可用的测试场景，又能保证多次运行不会重复插入相同的记录。

关键代码 C：任务创建与去重（示例任务创建）

```416:441:container_management/insert_sample_data.py
                if not Task.objects.filter(
                    container_master_id=container,
                    task_type='Load',
                    status='Pending',
                    vessel_visit_id=vessel_visits[0]
                ).exists():
                    task = Task.objects.create(
                        container_master_id=container,
                        task_type='Load',
                        status='Pending',
                        from_slot_id=from_slot,
                        to_slot_id=to_slot,
                        vessel_visit_id=vessel_visits[0],
                        created_by_user_id=users_list[0],
                        assigned_user_id=users_list[1],
                        priority=100 - i * 10,
                    )
```

解释（≥100 字）：在创建任务前先检查是否已存在相同类型和状态的任务以避免重复插入，是脚本提供幂等性的关键部分。任务写入包括 `from_slot_id`、`to_slot_id`、`vessel_visit_id`、`created_by_user_id` 与 `assigned_user_id` 等字段，确保任务在数据库层具备完整的上下文信息。示例脚本中的任务创建逻辑既能为前端和运维提供真实业务场景，也为测试调度与执行逻辑提供真实数据基础。

4.7.2 数据截图与验证建议

- 在运行 `insert_sample_data.py` 后，使用 MySQL 客户端或 Navicat 等工具查看并截图上述建议的表与视图结果；在文档中把截图放入 `figures/` 并在对应位置引用图片，以便答辩时展示真实数据支持。

## 4.8 项目改进空间与下一步工作

下面列出若干可行的改进方向，每条附简要实现建议与优先级（H/M/L）。

1. 自动配位算法优化（优先级：H）

   - 建议：实现基于代价函数的自动配位器，代价可包括距离、设备可达性、箱型匹配和堆场利用率。使用视图 `View_Yard_Available_Slots` 作为候选源，结合近邻搜索与评分机制做最终选择，并在分配时使用事务/乐观锁以防并发冲突。

2. 引入消息队列与异步任务处理（优先级：M）

   - 建议：对于耗时或跨系统操作（如大规模任务下发、外部系统同步），采用 RabbitMQ/Redis+Celery 进行异步处理，减少用户请求等待并提高系统吞吐。

3. 仪表盘与大屏性能优化（优先级：M）

   - 建议：把耗时查询异步化为后台批量聚合或物化视图，并为大图/大屏提供专门的缓存层（如 Redis），在前端采用增量刷新而非全量刷新。

4. 权限系统增强与审计（优先级：H）

   - 建议：拓展为细粒度 RBAC/ABAC，记录权限变更审计日志并将关键操作（任务创建/权限分配）写入审计表，便于事后追溯与合规。

5. 自动化测试与 CI（优先级：H）

   - 建议：为模型、视图、权限装饰器与 SQL 视图编写单元与集成测试，使用 GitHub Actions 或 GitLab CI 在 PR 阶段自动运行测试与示例数据导入检查。

6. 前端重构为 SPA（优先级：L）

   - 建议：将关键交互页面（任务面板、堆场可视化）拆分为 React/Vue 应用，通过 REST/GraphQL 获取数据，提高前端交互性与二次开发效率。

7. 数据库性能与索引优化（优先级：H）

   - 建议：基于慢查询日志和 EXPLAIN 分析 `View_Yard_Inventory_Live`、`View_Task_Details` 等视图底层 SQL，增加必要的复合索引或考虑物化视图来加速常用聚合查询。

8. 多租户或分区支持（优先级：L）
   - 建议：若需要对多个港区或客户进行隔离，考虑在逻辑上或物理上为不同租户分区（schema/DB 或加上 tenant_id 字段），并在权限与数据访问层做隔离。

---

(完成 `update-4.7` 与 `update-4.8` 的补充内容)
