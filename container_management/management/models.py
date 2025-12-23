from django.db import models
from django.core.exceptions import ValidationError

# 堆场区类型枚举（用于模型字段 choices）
BLOCK_TYPE_CHOICES = [
    ("Standard", "标准"),
    ("Reefer", "冷藏"),
    ("Temporary", "临时"),
    ("Heavy", "重载"),
    ("Bulk", "散货"),
]


# 相关方表
class Party(models.Model):
    party_id = models.AutoField(primary_key=True, db_column="Party_ID")
    party_name = models.CharField(max_length=255, unique=True, db_column="Party_Name", verbose_name="名称")
    party_type = models.CharField(
        max_length=20,
        db_column="Party_Type",
        choices=[("COMPANY", "公司"), ("PERSON", "个人")],
        verbose_name="类型",
    )
    address_line_1 = models.CharField(max_length=255, null=True, blank=True, db_column="Address_Line_1", verbose_name="地址")
    city = models.CharField(max_length=100, null=True, blank=True, db_column="City", verbose_name="城市")
    country = models.CharField(max_length=2, null=True, blank=True, db_column="Country", verbose_name="国家代码")
    contact_person = models.CharField(max_length=100, null=True, blank=True, db_column="Contact_Person", verbose_name="联系人")
    email = models.EmailField(max_length=255, null=True, blank=True, db_column="Email", verbose_name="电子邮件")
    phone = models.CharField(max_length=50, null=True, blank=True, db_column="Phone", verbose_name="电话")
    scac_code = models.CharField(max_length=10, null=True, blank=True, db_column="SCAC_Code", verbose_name="承运人代码")

    class Meta:
        db_table = "Party"
        verbose_name = "相关方"
        verbose_name_plural = "相关方"

    def __str__(self):
        return self.party_name


# 港口主数据
class PortMaster(models.Model):
    port_id = models.AutoField(primary_key=True, db_column="Port_ID")
    port_name = models.CharField(max_length=100, db_column="Port_Name", verbose_name="名称")
    port_code = models.CharField(max_length=5, unique=True, db_column="Port_Code", verbose_name="代码")
    country = models.CharField(max_length=2, db_column="Country", verbose_name="国家代码")

    class Meta:
        db_table = "Port_Master"
        verbose_name = "港口"
        verbose_name_plural = "港口"

    def __str__(self):
        return f"{self.port_name} ({self.port_code})"


# 堆场区
class YardBlock(models.Model):
    block_id = models.AutoField(primary_key=True, db_column="Block_ID")
    block_name = models.CharField(max_length=50, unique=True, db_column="Block_Name", verbose_name="名称")
    block_type = models.CharField(
        max_length=20,
        choices=BLOCK_TYPE_CHOICES,
        default="Standard",
        db_column="Block_Type",
        verbose_name="类型",
    )

    class Meta:
        db_table = "Yard_Block"
        verbose_name = "堆场区"
        verbose_name_plural = "堆场区"

    def __str__(self):
        return self.block_name


# 用户表
class Users(models.Model):
    user_id = models.AutoField(primary_key=True, db_column="User_ID")
    username = models.CharField(max_length=100, unique=True, db_column="Username", verbose_name="用户名")
    hashed_password = models.BinaryField(max_length=256, db_column="Hashed_Password", verbose_name="密码")
    full_name = models.CharField(max_length=100, null=True, blank=True, db_column="Full_Name", verbose_name="全名")
    email = models.EmailField(max_length=255, unique=True, db_column="Email", verbose_name="电子邮件")
    party_id = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True, db_column="Party_ID", verbose_name="关联相关方")
    is_active = models.BooleanField(default=True, db_column="Is_Active", verbose_name="是否激活")

    class Meta:
        db_table = "Users"
        verbose_name = "用户"
        verbose_name_plural = "用户"

    def __str__(self):
        return self.username


# 权限表
class Permissions(models.Model):
    permission_id = models.AutoField(primary_key=True, db_column="Permission_ID")
    permission_name = models.CharField(max_length=100, unique=True, db_column="Permission_Name", verbose_name="名称")
    description = models.CharField(max_length=255, null=True, blank=True, db_column="Description", verbose_name="描述")

    class Meta:
        db_table = "Permissions"
        verbose_name = "权限"
        verbose_name_plural = "权限"

    def __str__(self):
        return self.permission_name


# 集装箱类型字典
class ContainerTypeDict(models.Model):
    type_code = models.CharField(max_length=4, primary_key=True, db_column="Type_Code", verbose_name="ISO类型代码")
    nominal_size = models.IntegerField(db_column="Nominal_Size", verbose_name="名义尺寸")
    group_code = models.CharField(max_length=4, db_column="Group_Code", verbose_name="组代码")
    standard_tare_kg = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True, db_column="Standard_Tare_KG", verbose_name="标准皮重")

    class Meta:
        db_table = "Container_Type_Dict"
        verbose_name = "集装箱类型字典"
        verbose_name_plural = "集装箱类型字典"

    def __str__(self):
        return f"{self.type_code} ({self.nominal_size}ft)"


# 泊位
class Berth(models.Model):
    berth_id = models.AutoField(primary_key=True, db_column="Berth_ID")
    port_id = models.ForeignKey(PortMaster, on_delete=models.CASCADE, db_column="Port_ID", verbose_name="所属港口")
    berth_name = models.CharField(max_length=50, db_column="Berth_Name", verbose_name="泊位名称")
    length_meters = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True, db_column="Length_Meters", verbose_name="泊位长度(米)")
    depth_meters = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True, db_column="Depth_Meters", verbose_name="泊位水深(米)")
    max_vessel_loa = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True, db_column="Max_Vessel_LOA", verbose_name="最大容纳船长")

    class Meta:
        db_table = "Berth"
        verbose_name = "泊位"
        verbose_name_plural = "泊位"
        unique_together = [["port_id", "berth_name"]]

    def __str__(self):
        return f"{self.port_id.port_name} - {self.berth_name}"


# 船舶主数据
class VesselMaster(models.Model):
    vessel_id = models.AutoField(primary_key=True, db_column="Vessel_ID")
    vessel_name = models.CharField(max_length=100, db_column="Vessel_Name", verbose_name="船名")
    imo_number = models.CharField(max_length=7, unique=True, db_column="IMO_Number", verbose_name="IMO编号")
    flag_country = models.CharField(max_length=2, null=True, blank=True, db_column="Flag_Country", verbose_name="船旗国")
    carrier_party_id = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True, db_column="Carrier_Party_ID", verbose_name="承运人")

    class Meta:
        db_table = "Vessel_Master"
        verbose_name = "船舶"
        verbose_name_plural = "船舶"

    def __str__(self):
        return self.vessel_name


# 集装箱主数据
class ContainerMaster(models.Model):
    container_master_id = models.AutoField(primary_key=True, db_column="Container_Master_ID")
    container_number = models.CharField(max_length=11, unique=True, db_column="Container_Number", verbose_name="箱号")
    owner_party_id = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True, db_column="Owner_Party_ID", verbose_name="箱主")
    type_code = models.ForeignKey(ContainerTypeDict, on_delete=models.PROTECT, db_column="Type_Code", verbose_name="类型代码")
    current_status = models.CharField(
        max_length=20,
        null=True,
        blank=True,
        db_column="Current_Status",
        choices=[("InYard", "在堆场"), ("OnVessel", "在船上"), ("GateOut", "已出闸")],
        verbose_name="当前状态",
    )

    class Meta:
        db_table = "Container_Master"
        verbose_name = "集装箱"
        verbose_name_plural = "集装箱"

    def __str__(self):
        return self.container_number


# 堆场堆栈
class YardStack(models.Model):
    stack_id = models.AutoField(primary_key=True, db_column="Stack_ID")
    block_id = models.ForeignKey(YardBlock, on_delete=models.CASCADE, db_column="Block_ID", verbose_name="所属堆场区")
    bay_number = models.IntegerField(db_column="Bay_Number", verbose_name="贝位号")
    row_number = models.IntegerField(db_column="Row_Number", verbose_name="排号")

    class Meta:
        db_table = "Yard_Stack"
        verbose_name = "堆场堆栈"
        verbose_name_plural = "堆场堆栈"
        unique_together = [["block_id", "bay_number", "row_number"]]

    def __str__(self):
        return f"{self.block_id.block_name} - 贝{self.bay_number}排{self.row_number}"


# 用户权限关联表
class UserPermissions(models.Model):
    user_id = models.ForeignKey(Users, on_delete=models.CASCADE, db_column="User_ID", verbose_name="用户")
    permission_id = models.ForeignKey(Permissions, on_delete=models.CASCADE, db_column="Permission_ID", verbose_name="权限")

    class Meta:
        db_table = "User_Permissions"
        verbose_name = "用户权限"
        verbose_name_plural = "用户权限"
        unique_together = [["user_id", "permission_id"]]
        # 注意：数据库表使用复合主键 (User_ID, Permission_ID)，没有单独的 id 字段
        # Django 不支持复合主键，所以需要通过原始 SQL 操作此表

    def __str__(self):
        return f"{self.user_id.username} - {self.permission_id.permission_name}"


# 箱位
class YardSlot(models.Model):
    slot_id = models.AutoField(primary_key=True, db_column="Slot_ID")
    stack_id = models.ForeignKey(YardStack, on_delete=models.CASCADE, db_column="Stack_ID", verbose_name="所属堆栈")
    tier_number = models.IntegerField(db_column="Tier_Number", verbose_name="层号")
    slot_coordinates = models.CharField(max_length=50, unique=True, db_column="Slot_Coordinates", verbose_name="坐标")
    # 箱位状态枚举
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
        db_column="Slot_Status",
        verbose_name="状态",
    )
    current_container_id = models.OneToOneField(
        ContainerMaster, on_delete=models.SET_NULL, null=True, blank=True, db_column="Current_Container_ID", verbose_name="当前集装箱"
    )

    class Meta:
        db_table = "Yard_Slot"
        verbose_name = "箱位"
        verbose_name_plural = "箱位"
        unique_together = [["stack_id", "tier_number"]]

    def __str__(self):
        return self.slot_coordinates


# 船舶访问
class VesselVisit(models.Model):
    vessel_visit_id = models.AutoField(primary_key=True, db_column="Vessel_Visit_ID")
    vessel_id = models.ForeignKey(VesselMaster, on_delete=models.CASCADE, db_column="Vessel_ID", verbose_name="船舶")
    port_id = models.ForeignKey(PortMaster, on_delete=models.CASCADE, db_column="Port_ID", verbose_name="挂靠港口")
    berth_id = models.ForeignKey(Berth, on_delete=models.SET_NULL, null=True, blank=True, db_column="Berth_ID", verbose_name="泊位")
    voyage_number_in = models.CharField(max_length=20, db_column="Voyage_Number_In", verbose_name="进口航次")
    voyage_number_out = models.CharField(max_length=20, db_column="Voyage_Number_Out", verbose_name="出口航次")
    ata = models.DateTimeField(null=True, blank=True, db_column="ATA", verbose_name="实际到港时间")
    atd = models.DateTimeField(null=True, blank=True, db_column="ATD", verbose_name="实际离港时间")
    status = models.CharField(
        max_length=20,
        default="Approaching",
        db_column="Status",
        choices=[("Approaching", "接近中"), ("AtBerth", "靠泊"), ("Departing", "离港中"), ("Completed", "已完成")],
        verbose_name="状态",
    )

    class Meta:
        db_table = "Vessel_Visit"
        verbose_name = "船舶访问"
        verbose_name_plural = "船舶访问"

    def __str__(self):
        return f"{self.vessel_id.vessel_name} - {self.voyage_number_in}"

    def clean(self):
        """
        Ensure that if a berth is set, it belongs to the same port as port_id.
        Prevent inconsistent data like port = Guangzhou but berth belongs to Yangshan.
        """
        if self.berth_id and self.port_id:
            # berth_id is a Berth instance; its port FK field is `port_id`
            if getattr(self.berth_id, "port_id_id", None) is not None:
                if self.berth_id.port_id_id != self.port_id_id:
                    raise ValidationError({"berth_id": "所选泊位不属于所选挂靠港口，请选择同一港口下的泊位。"})

    def save(self, *args, **kwargs):
        # 在程序化保存时也运行验证
        self.full_clean()
        super().save(*args, **kwargs)


# 订舱单
class Booking(models.Model):
    booking_id = models.AutoField(primary_key=True, db_column="Booking_ID")
    booking_number = models.CharField(max_length=50, unique=True, db_column="Booking_Number", verbose_name="订舱号")
    status = models.CharField(
        max_length=20,
        default="Draft",
        db_column="Status",
        choices=[("Draft", "草稿"), ("Confirmed", "已确认"), ("Cancelled", "已取消")],
        verbose_name="状态",
    )
    shipper_party_id = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True, related_name="shipper_bookings", db_column="Shipper_Party_ID", verbose_name="发货人")
    consignee_party_id = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True, related_name="consignee_bookings", db_column="Consignee_Party_ID", verbose_name="收货人")
    payer_party_id = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True, related_name="payer_bookings", db_column="Payer_Party_ID", verbose_name="付费方")
    voyage_id = models.ForeignKey(VesselVisit, on_delete=models.SET_NULL, null=True, blank=True, db_column="Voyage_ID", verbose_name="航次")

    class Meta:
        db_table = "Booking"
        verbose_name = "订舱单"
        verbose_name_plural = "订舱单"

    def __str__(self):
        return self.booking_number


# 任务表
class Task(models.Model):
    task_id = models.AutoField(primary_key=True, db_column="Task_ID")
    task_type = models.CharField(
        max_length=30,
        db_column="Task_Type",
        choices=[("Load", "装船"), ("Discharge", "卸船"), ("Move", "移箱"), ("GateIn", "进闸"), ("GateOut", "出闸")],
        verbose_name="任务类型",
    )
    status = models.CharField(
        max_length=20,
        default="Pending",
        db_column="Status",
        choices=[("Pending", "待处理"), ("InProgress", "进行中"), ("Completed", "已完成"), ("Cancelled", "已取消")],
        verbose_name="状态",
    )
    container_master_id = models.ForeignKey(ContainerMaster, on_delete=models.CASCADE, db_column="Container_Master_ID", verbose_name="集装箱")
    from_slot_id = models.ForeignKey(YardSlot, on_delete=models.CASCADE, related_name="tasks_from", db_column="From_Slot_ID", verbose_name="起始箱位")
    to_slot_id = models.ForeignKey(YardSlot, on_delete=models.CASCADE, related_name="tasks_to", db_column="To_Slot_ID", verbose_name="目标箱位")
    vessel_visit_id = models.ForeignKey(VesselVisit, on_delete=models.SET_NULL, null=True, blank=True, db_column="Vessel_Visit_ID", verbose_name="船舶访问")
    created_by_user_id = models.ForeignKey(Users, on_delete=models.CASCADE, related_name="created_tasks", db_column="Created_By_User_ID", verbose_name="创建人")
    assigned_user_id = models.ForeignKey(Users, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_tasks", db_column="Assigned_User_ID", verbose_name="指派给")
    actual_executor_id = models.ForeignKey(Users, on_delete=models.SET_NULL, null=True, blank=True, related_name="executed_tasks", db_column="Actual_Executor_ID", verbose_name="实际执行人")
    priority = models.IntegerField(default=100, db_column="Priority", verbose_name="优先级")
    movement_timestamp = models.DateTimeField(null=True, blank=True, db_column="Movement_Timestamp", verbose_name="实际移动时间戳")

    class Meta:
        db_table = "Task"
        verbose_name = "作业任务"
        verbose_name_plural = "作业任务"

    def __str__(self):
        return f"{self.task_type} - {self.container_master_id.container_number}"