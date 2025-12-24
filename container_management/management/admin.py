from django.contrib import admin
from django.db import connection
from django.db.models import Q, F
from django import forms
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
    # UserPermissions
    YardSlot,
    VesselVisit,
    Booking,
    Task,
)


class ExplicitSaveAdmin(admin.ModelAdmin):
    # 管理后台基类：在保存模型时显式调用 obj.save()
    def save_model(self, request, obj, form, change):
        # 在保存时再次校验权限：如果当前角色为 viewer，阻止写操作并在表单层抛出错误
        role = request.session.get('user_role')
        if role == 'viewer':
            # 抛出 forms.ValidationError，使 Admin 表单以红字显示错误
            raise forms.ValidationError({'__all__': '无操作权限：您没有执行该操作的权限。'})
        obj.save()

    def get_form(self, request, obj=None, **kwargs):
        """
        为 viewer 动态替换表单，使其在 clean 时抛出表单级错误（前端红字显示）。
        这样即使通过直接 URL 访问编辑页面，提交时也会给出友好表单错误。
        """
        base_form = super().get_form(request, obj, **kwargs)
        role = request.session.get('user_role')
        if role == 'viewer':
            class ViewerBlockedForm(base_form):
                def clean(self_inner):
                    cleaned = super().clean()
                    raise forms.ValidationError({'__all__': '无操作权限：您没有执行该操作的权限。'})
            return ViewerBlockedForm
        return base_form

    def has_add_permission(self, request, obj=None):
        role = request.session.get('user_role')
        if role == 'viewer':
            return False
        # Django 的 has_add_permission 在某些版本仅接受 (request)
        try:
            return super().has_add_permission(request, obj)
        except TypeError:
            return super().has_add_permission(request)

    def has_change_permission(self, request, obj=None):
        role = request.session.get('user_role')
        if role == 'viewer':
            return False
        return super().has_change_permission(request, obj)

    def has_delete_permission(self, request, obj=None):
        role = request.session.get('user_role')
        if role == 'viewer':
            return False
        return super().has_delete_permission(request, obj)


# 管理站点标题
admin.site.site_header = "港口集装箱运营管理系统"
admin.site.site_title = "港口集装箱运营管理系统"
# admin.site.index_title = "港口集装箱运营管理系统"

# 模型：Party（当事方）在后台的显示配置
@admin.register(Party)
class PartyAdmin(ExplicitSaveAdmin):
    # 列表显示字段、筛选、搜索与分页配置
    list_display = ['party_id', 'party_name', 'party_type', 'city', 'country', 'contact_person', 'phone']
    list_filter = ['party_type', 'country']
    search_fields = ['party_name', 'contact_person', 'email']
    list_per_page = 20


@admin.register(PortMaster)
class PortMasterAdmin(ExplicitSaveAdmin):
    # 模型：PortMaster（港口主表）后台显示配置
    list_display = ['port_id', 'port_name', 'port_code', 'country']
    search_fields = ['port_name', 'port_code']
    list_per_page = 20


@admin.register(YardBlock)
class YardBlockAdmin(ExplicitSaveAdmin):
    # 模型：YardBlock（堆场分区）后台显示配置
    list_display = ['block_id', 'block_name', 'block_type']
    search_fields = ['block_name']
    list_per_page = 20


@admin.register(Users)
class UsersAdmin(ExplicitSaveAdmin):
    # 模型：Users（用户）后台显示配置
    list_display = ['user_id', 'username', 'full_name', 'email', 'party_id', 'is_active']
    list_filter = ['is_active']
    search_fields = ['username', 'full_name', 'email']
    list_per_page = 20
    # 针对 operator 角色隐藏该模型（在界面上不显示）
    hide_for_operator = True
    def has_module_permission(self, request):
        # 若当前会话角色为 operator 且配置为隐藏，则禁止该模块显示
        role = request.session.get('user_role')
        if role == 'operator' and getattr(self, 'hide_for_operator', False):
            return False
        return super().has_module_permission(request)
    def get_model_perms(self, request):
        """
        针对 operator 返回空权限，避免 Django 的应用列表/菜单生成中包含此模型。
        """
        role = request.session.get('user_role')
        if role == 'operator' and getattr(self, 'hide_for_operator', False):
            return {}
        return super().get_model_perms(request)


@admin.register(Permissions)
class PermissionsAdmin(ExplicitSaveAdmin):
    # 管理界面：Permissions（权限定义表）显示配置
    list_display = ['permission_id', 'permission_name', 'description']
    search_fields = ['permission_name', 'description']
    list_per_page = 50
    # 同样对 operator 隐藏权限表显示
    hide_for_operator = True
    def has_module_permission(self, request):
        role = request.session.get('user_role')
        if role == 'operator' and getattr(self, 'hide_for_operator', False):
            return False
        return super().has_module_permission(request)
    def get_model_perms(self, request):
        role = request.session.get('user_role')
        if role == 'operator' and getattr(self, 'hide_for_operator', False):
            return {}
        return super().get_model_perms(request)


# UserPermissions admin registration removed to hide permission assignments from admin UI.
# If you need to re-enable it later, restore the registration and import above.


@admin.register(ContainerTypeDict)
class ContainerTypeDictAdmin(ExplicitSaveAdmin):
    # 模型：ContainerTypeDict（箱型字典）后台显示配置
    list_display = ['type_code', 'nominal_size', 'group_code', 'standard_tare_kg']
    list_filter = ['nominal_size', 'group_code']
    search_fields = ['type_code']
    list_per_page = 20


@admin.register(Berth)
class BerthAdmin(ExplicitSaveAdmin):
    # 模型：Berth（泊位）后台显示配置
    list_display = ['berth_id', 'port_id', 'berth_name', 'length_meters', 'depth_meters']
    list_filter = ['port_id']
    search_fields = ['berth_name']
    list_per_page = 20


@admin.register(VesselMaster)
class VesselMasterAdmin(ExplicitSaveAdmin):
    # 模型：VesselMaster（船舶主表）后台显示配置
    list_display = ['vessel_id', 'vessel_name', 'imo_number', 'flag_country', 'carrier_party_id']
    search_fields = ['vessel_name', 'imo_number']
    list_per_page = 20


@admin.register(ContainerMaster)
class ContainerMasterAdmin(ExplicitSaveAdmin):
    # 模型：ContainerMaster（集装箱主表）后台显示配置
    list_display = ['container_master_id', 'container_number', 'type_code', 'owner_party_id', 'current_status']
    list_filter = ['current_status', 'type_code']
    search_fields = ['container_number']
    list_per_page = 20


@admin.register(YardStack)
class YardStackAdmin(ExplicitSaveAdmin):
    # 模型：YardStack（堆位栈）后台显示配置
    list_display = ['stack_id', 'block_id', 'bay_number', 'row_number']
    list_filter = ['block_id']
    list_per_page = 20


@admin.register(YardSlot)
class YardSlotAdmin(ExplicitSaveAdmin):
    # 模型：YardSlot（具体格位）后台显示配置
    list_display = ['slot_id', 'stack_id', 'tier_number', 'slot_coordinates', 'slot_status', 'current_container_id']
    list_filter = ['slot_status', 'stack_id__block_id']
    search_fields = ['slot_coordinates']
    list_per_page = 20


@admin.register(VesselVisit)
class VesselVisitAdmin(ExplicitSaveAdmin):
    # 模型：VesselVisit（船舶到港记录）后台显示配置
    list_display = ['vessel_visit_id', 'vessel_id', 'port_id', 'berth_id', 'voyage_number_in', 'voyage_number_out', 'ata', 'atd', 'status']
    list_filter = ['status', 'port_id']
    search_fields = ['voyage_number_in', 'voyage_number_out']
    list_per_page = 20
    # 本地数据库无时区表时，date_hierarchy 会触发 CONVERT_TZ 报错，先停用
    # date_hierarchy = 'ata'
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        # 保留 berth 为 NULL 或者 berth.port_id 与 vessel_visit.port_id 相同的记录
        return qs.filter(Q(berth_id__isnull=True) | Q(berth_id__port_id=F('port_id')))


@admin.register(Booking)
class BookingAdmin(ExplicitSaveAdmin):
    # 模型：Booking（订舱）后台显示配置
    list_display = ['booking_id', 'booking_number', 'status', 'shipper_party_id', 'consignee_party_id', 'voyage_id']
    list_filter = ['status']
    search_fields = ['booking_number']
    list_per_page = 20
    


class BookingForm(forms.ModelForm):
    class Meta:
        model = Booking
        fields = '__all__'

    def clean(self):
        cleaned = super().clean()
        status = cleaned.get('status')
        voyage = cleaned.get('voyage_id')
        # 当前业务规则：确认订舱（Confirmed）必须先关联航次
        if status == 'Confirmed' and not voyage:
            # 将错误绑定到 status 字段，Admin 页面会以红字显示
            raise forms.ValidationError({'status': '订舱单确认时必须关联付费方及航次！'})
        return cleaned

# 将 BookingForm 应用到 BookingAdmin（放在类定义后避免引用顺序问题）
BookingAdmin.form = BookingForm


@admin.register(Task)
class TaskAdmin(ExplicitSaveAdmin):
    # 模型：Task（任务）后台显示配置
    list_display = ['task_id', 'task_type', 'status', 'container_master_id', 'priority', 'created_by_user_id', 'assigned_user_id']
    list_filter = ['task_type', 'status']
    search_fields = ['container_master_id__container_number']
    list_per_page = 20
    # 留空日期层级避免本地数据库缺少时区表时触发 CONVERT_TZ 错误
    # date_hierarchy = 'movement_timestamp'
