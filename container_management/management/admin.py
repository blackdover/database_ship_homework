from django.contrib import admin
from django.db.models import Q, F
from .models import (
    Party,
    PortMaster,
    YardBlock,
    Users,
    Permissions,
    ContainerTypeDict,
    Berth,
    VesselMaster,
    ContainerMaster,
    YardStack,
    UserPermissions,
    YardSlot,
    VesselVisit,
    Booking,
    Task,
)
admin.site.site_header = "港口集装箱运营管理系统"
admin.site.site_title = "港口集装箱运营管理系统"
# admin.site.index_title = "港口集装箱运营管理系统"

# 使用默认的 Django Admin（配合 simpleui），仅保留模型注册和字段配置
@admin.register(Party)
class PartyAdmin(admin.ModelAdmin):
    list_display = ['party_id', 'party_name', 'party_type', 'city', 'country', 'contact_person', 'phone']
    list_filter = ['party_type', 'country']
    search_fields = ['party_name', 'contact_person', 'email']
    list_per_page = 20


@admin.register(PortMaster)
class PortMasterAdmin(admin.ModelAdmin):
    list_display = ['port_id', 'port_name', 'port_code', 'country']
    search_fields = ['port_name', 'port_code']
    list_per_page = 20


@admin.register(YardBlock)
class YardBlockAdmin(admin.ModelAdmin):
    list_display = ['block_id', 'block_name', 'block_type']
    search_fields = ['block_name']
    list_per_page = 20


@admin.register(Users)
class UsersAdmin(admin.ModelAdmin):
    list_display = ['user_id', 'username', 'full_name', 'email', 'party_id', 'is_active']
    list_filter = ['is_active']
    search_fields = ['username', 'full_name', 'email']
    list_per_page = 20


@admin.register(ContainerTypeDict)
class ContainerTypeDictAdmin(admin.ModelAdmin):
    list_display = ['type_code', 'nominal_size', 'group_code', 'standard_tare_kg']
    list_filter = ['nominal_size', 'group_code']
    search_fields = ['type_code']
    list_per_page = 20


@admin.register(Berth)
class BerthAdmin(admin.ModelAdmin):
    list_display = ['berth_id', 'port_id', 'berth_name', 'length_meters', 'depth_meters']
    list_filter = ['port_id']
    search_fields = ['berth_name']
    list_per_page = 20


@admin.register(VesselMaster)
class VesselMasterAdmin(admin.ModelAdmin):
    list_display = ['vessel_id', 'vessel_name', 'imo_number', 'flag_country', 'carrier_party_id']
    search_fields = ['vessel_name', 'imo_number']
    list_per_page = 20


@admin.register(ContainerMaster)
class ContainerMasterAdmin(admin.ModelAdmin):
    list_display = ['container_master_id', 'container_number', 'type_code', 'owner_party_id', 'current_status']
    list_filter = ['current_status', 'type_code']
    search_fields = ['container_number']
    list_per_page = 20


@admin.register(YardStack)
class YardStackAdmin(admin.ModelAdmin):
    list_display = ['stack_id', 'block_id', 'bay_number', 'row_number']
    list_filter = ['block_id']
    list_per_page = 20


@admin.register(YardSlot)
class YardSlotAdmin(admin.ModelAdmin):
    list_display = ['slot_id', 'stack_id', 'tier_number', 'slot_coordinates', 'slot_status', 'current_container_id']
    list_filter = ['slot_status', 'stack_id__block_id']
    search_fields = ['slot_coordinates']
    list_per_page = 20


@admin.register(VesselVisit)
class VesselVisitAdmin(admin.ModelAdmin):
    list_display = ['vessel_visit_id', 'vessel_id', 'port_id', 'berth_id', 'voyage_number_in', 'voyage_number_out', 'ata', 'atd', 'status']
    list_filter = ['status', 'port_id']
    search_fields = ['voyage_number_in', 'voyage_number_out']
    list_per_page = 20
    # 本地数据库无时区表时，date_hierarchy 会触发 CONVERT_TZ 报错，先停用
    # date_hierarchy = 'ata'
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        # Keep rows where berth is NULL OR berth.port_id == port_id
        return qs.filter(Q(berth_id__isnull=True) | Q(berth_id__port_id=F('port_id')))


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ['booking_id', 'booking_number', 'status', 'shipper_party_id', 'consignee_party_id', 'voyage_id']
    list_filter = ['status']
    search_fields = ['booking_number']
    list_per_page = 20


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ['task_id', 'task_type', 'status', 'container_master_id', 'priority', 'created_by_user_id', 'assigned_user_id']
    list_filter = ['task_type', 'status']
    search_fields = ['container_master_id__container_number']
    list_per_page = 20
    # 留空日期层级避免本地数据库缺少时区表时触发 CONVERT_TZ 错误
    # date_hierarchy = 'movement_timestamp'
