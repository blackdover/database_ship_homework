#!/usr/bin/env python
"""
示例数据插入脚本
用于向数据库插入示例数据，方便测试和演示
"""
import os
import sys
import django
from datetime import datetime, timedelta
import hashlib

# 设置Django环境
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'container_management.settings')
django.setup()

from django.db import transaction, connection
from management.models import (
    Party, PortMaster, YardBlock, ContainerTypeDict, Permissions,
    Berth, VesselMaster, ContainerMaster, YardStack, Users,
    YardSlot, VesselVisit, UserPermissions, Booking, Task
)


def hash_password(password):
    """简单的密码哈希（实际项目中应使用Django的密码哈希）"""
    return hashlib.sha256(password.encode()).digest()


def insert_sample_data():
    """插入示例数据"""
    print('=' * 60)
    print('开始插入示例数据...')
    print('=' * 60)
    
    with transaction.atomic():
        # =========================================
        # 组 1: 基础主数据
        # =========================================
        print('\n[1/4] 插入基础主数据...')
        
        # 1.1 相关方 (Party)
        parties = []
        party_data = [
            ('中远海运', 'COMPANY', '上海市浦东新区', '上海', 'CN', '张经理', 'zhang@cosco.com', '021-12345678', 'COSC'),
            ('马士基航运', 'COMPANY', '丹麦哥本哈根', '哥本哈根', 'DK', 'John Smith', 'john@maersk.com', '+45-12345678', 'MAEU'),
            ('地中海航运', 'COMPANY', '瑞士日内瓦', '日内瓦', 'CH', 'Maria Rossi', 'maria@msc.com', '+41-12345678', 'MSCU'),
            ('达飞轮船', 'COMPANY', '法国马赛', '马赛', 'FR', 'Pierre Dubois', 'pierre@cma-cgm.com', '+33-12345678', 'CMAU'),
            ('长荣海运', 'COMPANY', '台湾台北', '台北', 'TW', '陈先生', 'chen@evergreen.com', '02-12345678', 'EGLV'),
            ('上海港务集团', 'COMPANY', '上海市黄浦区', '上海', 'CN', '李经理', 'li@shanghaiport.com', '021-87654321', None),
            ('青岛港务集团', 'COMPANY', '山东省青岛市', '青岛', 'CN', '王经理', 'wang@qingdaoport.com', '0532-12345678', None),
            ('深圳港务集团', 'COMPANY', '广东省深圳市', '深圳', 'CN', '刘经理', 'liu@shenzhenport.com', '0755-12345678', None),
            ('华为技术有限公司', 'COMPANY', '广东省深圳市', '深圳', 'CN', '任总', 'ren@huawei.com', '0755-87654321', None),
            ('阿里巴巴集团', 'COMPANY', '浙江省杭州市', '杭州', 'CN', '马总', 'ma@alibaba.com', '0571-12345678', None),
        ]
        
        for data in party_data:
            party, created = Party.objects.get_or_create(
                party_name=data[0],
                defaults={
                    'party_type': data[1],
                    'address_line_1': data[2],
                    'city': data[3],
                    'country': data[4],
                    'contact_person': data[5],
                    'email': data[6],
                    'phone': data[7],
                    'scac_code': data[8],
                }
            )
            parties.append(party)
            if created:
                print(f'  ✓ 创建相关方: {party.party_name}')
        
        # 1.2 港口 (Port_Master)
        ports = []
        port_data = [
            ('上海港', 'CNSHA', 'CN'),
            ('青岛港', 'CNTAO', 'CN'),
            ('深圳港', 'CNSZN', 'CN'),
            ('宁波港', 'CNNGB', 'CN'),
            ('天津港', 'CNTXG', 'CN'),
            ('新加坡港', 'SGSIN', 'SG'),
            ('香港港', 'HKHKG', 'HK'),
            ('洛杉矶港', 'USLAX', 'US'),
        ]
        
        for data in port_data:
            port, created = PortMaster.objects.get_or_create(
                port_code=data[1],
                defaults={
                    'port_name': data[0],
                    'country': data[2],
                }
            )
            ports.append(port)
            if created:
                print(f'  ✓ 创建港口: {port.port_name} ({port.port_code})')
        
        # 1.3 堆场区 (Yard_Block)
        blocks = []
        block_data = [
            ('A区', 'Standard'),
            ('B区', 'Standard'),
            ('C区', 'Standard'),
            ('冷藏区R1', 'Reefer'),
            ('冷藏区R2', 'Reefer'),
            ('危险品区D1', 'Dangerous'),
        ]
        
        for data in block_data:
            block, created = YardBlock.objects.get_or_create(
                block_name=data[0],
                defaults={'block_type': data[1]}
            )
            blocks.append(block)
            if created:
                print(f'  ✓ 创建堆场区: {block.block_name}')
        
        # 1.4 集装箱类型字典 (Container_Type_Dict)
        container_types = []
        type_data = [
            ('22G1', 20, 'GP', 2200.00),  # 20英尺通用集装箱
            ('42G1', 40, 'GP', 3800.00),  # 40英尺通用集装箱
            ('45G1', 45, 'GP', 4200.00),  # 45英尺通用集装箱
            ('22R1', 20, 'RF', 2800.00),  # 20英尺冷藏集装箱
            ('42R1', 40, 'RF', 4500.00),  # 40英尺冷藏集装箱
            ('22T1', 20, 'TK', 2500.00),  # 20英尺罐式集装箱
        ]
        
        for data in type_data:
            ct, created = ContainerTypeDict.objects.get_or_create(
                type_code=data[0],
                defaults={
                    'nominal_size': data[1],
                    'group_code': data[2],
                    'standard_tare_kg': data[3],
                }
            )
            container_types.append(ct)
            if created:
                print(f'  ✓ 创建集装箱类型: {ct.type_code} ({ct.nominal_size}ft)')
        
        # 1.5 权限 (Permissions)
        permissions = []
        perm_data = [
            ('view_dashboard', '查看仪表板'),
            ('view_yard_inventory', '查看堆场库存'),
            ('view_vessel_visit', '查看船舶访问'),
            ('view_task', '查看任务'),
            ('create_task', '创建任务'),
            ('edit_task', '编辑任务'),
            ('execute_task', '执行任务'),
            ('view_booking', '查看订舱单'),
            ('create_booking', '创建订舱单'),
            ('edit_booking', '编辑订舱单'),
            ('admin_access', '管理员权限'),
        ]
        
        for data in perm_data:
            perm, created = Permissions.objects.get_or_create(
                permission_name=data[0],
                defaults={'description': data[1]}
            )
            permissions.append(perm)
            if created:
                print(f'  ✓ 创建权限: {perm.permission_name}')
        
        # =========================================
        # 组 2: 依赖于组 1 的主数据
        # =========================================
        print('\n[2/4] 插入依赖主数据...')
        
        # 2.1 泊位 (Berth)
        berths = []
        berth_data = [
            (ports[0], 'N1', 350.00, 15.00, 400.00),  # 上海港 N1泊位
            (ports[0], 'N2', 350.00, 15.00, 400.00),  # 上海港 N2泊位
            (ports[0], 'S1', 300.00, 14.00, 350.00),  # 上海港 S1泊位
            (ports[1], '1号泊位', 320.00, 16.00, 380.00),  # 青岛港
            (ports[2], '东泊位', 280.00, 13.00, 320.00),  # 深圳港
        ]
        
        for data in berth_data:
            berth, created = Berth.objects.get_or_create(
                port_id=data[0],
                berth_name=data[1],
                defaults={
                    'length_meters': data[2],
                    'depth_meters': data[3],
                    'max_vessel_loa': data[4],
                }
            )
            berths.append(berth)
            if created:
                print(f'  ✓ 创建泊位: {berth.port_id.port_name} - {berth.berth_name}')
        
        # 2.2 船舶 (Vessel_Master)
        vessels = []
        vessel_data = [
            ('中远海运天秤座', '9876543', 'CN', parties[0]),  # 中远海运
            ('马士基马德里', '1234567', 'DK', parties[1]),  # 马士基
            ('地中海米兰', '2345678', 'CH', parties[2]),  # 地中海
            ('达飞巴黎', '3456789', 'FR', parties[3]),  # 达飞
            ('长荣台北', '4567890', 'TW', parties[4]),  # 长荣
        ]
        
        for data in vessel_data:
            vessel, created = VesselMaster.objects.get_or_create(
                imo_number=data[1],
                defaults={
                    'vessel_name': data[0],
                    'flag_country': data[2],
                    'carrier_party_id': data[3],
                }
            )
            vessels.append(vessel)
            if created:
                print(f'  ✓ 创建船舶: {vessel.vessel_name} (IMO: {vessel.imo_number})')
        
        # 2.3 堆场堆栈 (Yard_Stack)
        stacks = []
        for block in blocks[:3]:  # 只在前3个区创建堆栈
            for bay in range(1, 6):  # 贝位 1-5
                for row in range(1, 4):  # 排号 1-3
                    stack, created = YardStack.objects.get_or_create(
                        block_id=block,
                        bay_number=bay,
                        row_number=row,
                    )
                    stacks.append(stack)
                    if created:
                        print(f'  ✓ 创建堆栈: {block.block_name} - 贝{bay}排{row}')
        
        # 2.4 用户 (Users) - 需要先有Party
        users_list = []
        user_data = [
            ('admin', 'admin@example.com', '管理员', parties[5], True),  # 上海港务集团
            ('operator1', 'operator1@example.com', '操作员1', parties[5], True),
            ('operator2', 'operator2@example.com', '操作员2', parties[5], True),
            ('viewer1', 'viewer1@example.com', '查看员1', parties[6], True),
            ('viewer2', 'viewer2@example.com', '查看员2', parties[7], True),
        ]
        
        for data in user_data:
            user, created = Users.objects.get_or_create(
                username=data[0],
                defaults={
                    'email': data[1],
                    'full_name': data[2],
                    'party_id': data[3],
                    'is_active': data[4],
                    'hashed_password': hash_password('password123'),
                }
            )
            users_list.append(user)
            if created:
                print(f'  ✓ 创建用户: {user.username} ({user.full_name})')
        
        # 2.5 用户权限 (User_Permissions)
        # 注意：User_Permissions 表使用复合主键，没有 id 字段，需要使用原始 SQL
        cursor = connection.cursor()
        
        # 给admin所有权限
        for perm in permissions:
            cursor.execute(
                "INSERT IGNORE INTO User_Permissions (User_ID, Permission_ID) VALUES (%s, %s)",
                [users_list[0].user_id, perm.permission_id]
            )
        
        # 给操作员创建和执行任务权限
        task_perms = [p for p in permissions if 'task' in p.permission_name]
        for perm in task_perms:
            cursor.execute(
                "INSERT IGNORE INTO User_Permissions (User_ID, Permission_ID) VALUES (%s, %s)",
                [users_list[1].user_id, perm.permission_id]
            )
            cursor.execute(
                "INSERT IGNORE INTO User_Permissions (User_ID, Permission_ID) VALUES (%s, %s)",
                [users_list[2].user_id, perm.permission_id]
            )
        
        # 给查看员查看权限
        view_perms = [p for p in permissions if 'view' in p.permission_name]
        for perm in view_perms:
            cursor.execute(
                "INSERT IGNORE INTO User_Permissions (User_ID, Permission_ID) VALUES (%s, %s)",
                [users_list[3].user_id, perm.permission_id]
            )
            cursor.execute(
                "INSERT IGNORE INTO User_Permissions (User_ID, Permission_ID) VALUES (%s, %s)",
                [users_list[4].user_id, perm.permission_id]
            )
        
        print(f'  ✓ 分配用户权限完成')
        
        # =========================================
        # 组 3: 依赖于组 1 & 2 的数据
        # =========================================
        print('\n[3/4] 插入业务数据...')
        
        # 3.1 箱位 (Yard_Slot)
        slots = []
        slot_counter = 0
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
                slots.append(slot)
                if created and slot_counter <= 5:  # 只打印前5个
                    print(f'  ✓ 创建箱位: {slot.slot_coordinates}')
        if slot_counter > 5:
            print(f'  ✓ 创建箱位: 共 {slot_counter} 个')
        
        # 3.2 集装箱 (Container_Master)
        containers = []
        # 生成符合格式的箱号: 4个字母 + 7个数字
        container_numbers = [
            'ABCD1234567', 'EFGH2345678', 'IJKL3456789', 'MNOP4567890',
            'QRST5678901', 'UVWX6789012', 'YZAB7890123', 'CDEF8901234',
            'GHIJ9012345', 'KLMN0123456', 'OPQR1234567', 'STUV2345678',
            'WXYZ3456789', 'ABCD4567890', 'EFGH5678901', 'IJKL6789012',
        ]
        
        for i, cn in enumerate(container_numbers):
            container, created = ContainerMaster.objects.get_or_create(
                container_number=cn,
                defaults={
                    'owner_party_id': parties[i % len(parties[:5])],  # 轮换使用前5个相关方
                    'type_code': container_types[i % len(container_types)],
                    'current_status': 'InYard' if i < 12 else 'OnVessel',
                }
            )
            containers.append(container)
            if created:
                print(f'  ✓ 创建集装箱: {container.container_number}')
        
        # 3.3 将部分集装箱放入箱位
        for i, container in enumerate(containers[:12]):  # 前12个集装箱放入堆场
            if i < len(slots):
                slot = slots[i]
                slot.current_container_id = container
                slot.slot_status = 'Occupied'
                slot.save()
                container.current_status = 'InYard'
                container.save()
        print(f'  ✓ 将 {min(12, len(slots))} 个集装箱放入堆场')
        
        # 3.4 船舶访问 (Vessel_Visit)
        vessel_visits = []
        now = datetime.now()
        visit_data = [
            (vessels[0], ports[0], berths[0], 'V001E', 'V001W', now - timedelta(days=2), None, 'AtBerth'),
            (vessels[1], ports[0], berths[1], 'V002E', 'V002W', now - timedelta(days=1), None, 'AtBerth'),
            (vessels[2], ports[1], berths[3], 'V003E', 'V003W', now + timedelta(days=1), None, 'Approaching'),
            (vessels[0], ports[0], berths[0], 'V004E', 'V004W', now - timedelta(days=10), now - timedelta(days=8), 'Completed'),
        ]
        
        for data in visit_data:
            visit, created = VesselVisit.objects.get_or_create(
                vessel_id=data[0],
                voyage_number_in=data[3],
                defaults={
                    'port_id': data[1],
                    'berth_id': data[2],
                    'voyage_number_out': data[4],
                    'ata': data[5],
                    'atd': data[6],
                    'status': data[7],
                }
            )
            vessel_visits.append(visit)
            if created:
                print(f'  ✓ 创建船舶访问: {visit.vessel_id.vessel_name} - {visit.voyage_number_in}')
        
        # =========================================
        # 组 4: 核心事务表
        # =========================================
        print('\n[4/4] 插入事务数据...')
        
        # 4.1 订舱单 (Booking)
        bookings = []
        booking_data = [
            ('BK001', 'Confirmed', parties[8], parties[9], parties[8], vessel_visits[0]),  # 华为 -> 阿里巴巴
            ('BK002', 'Confirmed', parties[9], parties[8], parties[9], vessel_visits[1]),  # 阿里巴巴 -> 华为
            ('BK003', 'Draft', parties[8], parties[9], parties[8], vessel_visits[2]),  # 华为 -> 阿里巴巴
        ]
        
        for data in booking_data:
            booking, created = Booking.objects.get_or_create(
                booking_number=data[0],
                defaults={
                    'status': data[1],
                    'shipper_party_id': data[2],
                    'consignee_party_id': data[3],
                    'payer_party_id': data[4],
                    'voyage_id': data[5],
                }
            )
            bookings.append(booking)
            if created:
                print(f'  ✓ 创建订舱单: {booking.booking_number}')
        
        # 4.2 任务 (Task)
        tasks = []
        # 创建一些装船任务
        for i in range(3):
            if i < len(containers) and i < len(slots) and i < len(vessel_visits):
                container = containers[i + 12] if i + 12 < len(containers) else containers[i]
                from_slot = slots[i] if i < len(slots) else slots[0]
                # 找一个空箱位作为目标
                to_slot = next((s for s in slots if s.current_container_id is None), slots[0])
                
                # 检查是否已存在类似任务
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
                    tasks.append(task)
                    print(f'  ✓ 创建任务: {task.task_type} - {task.container_master_id.container_number}')
        
        # 创建一些卸船任务
        for i in range(2):
            if i < len(containers) and i < len(slots) and i < len(vessel_visits):
                container = containers[i]
                # 找一个空箱位作为目标
                to_slot = next((s for s in slots if s.current_container_id is None), None)
                if to_slot:
                    from_slot = slots[0]  # 假设从船上卸下
                    
                    # 检查是否已存在类似任务
                    if not Task.objects.filter(
                        container_master_id=container,
                        task_type='Discharge',
                        vessel_visit_id=vessel_visits[1]
                    ).exists():
                        task = Task.objects.create(
                            container_master_id=container,
                            task_type='Discharge',
                            status='InProgress',
                            from_slot_id=from_slot,
                            to_slot_id=to_slot,
                            vessel_visit_id=vessel_visits[1],
                            created_by_user_id=users_list[0],
                            assigned_user_id=users_list[2],
                            actual_executor_id=users_list[2],
                            priority=90 - i * 10,
                            movement_timestamp=now - timedelta(hours=i),
                        )
                        tasks.append(task)
                        print(f'  ✓ 创建任务: {task.task_type} - {task.container_master_id.container_number}')
        
        # 创建一些移箱任务
        for i in range(2):
            if i + 1 < len(slots):
                container = containers[i + 2] if i + 2 < len(containers) else containers[0]
                from_slot = slots[i]
                to_slot = slots[i + 1]
                
                # 检查是否已存在类似任务
                if not Task.objects.filter(
                    container_master_id=container,
                    task_type='Move',
                    from_slot_id=from_slot,
                    to_slot_id=to_slot,
                    status='Completed'
                ).exists():
                    task = Task.objects.create(
                        container_master_id=container,
                        task_type='Move',
                        status='Completed',
                        from_slot_id=from_slot,
                        to_slot_id=to_slot,
                        created_by_user_id=users_list[0],
                        assigned_user_id=users_list[1],
                        actual_executor_id=users_list[1],
                        priority=80,
                        movement_timestamp=now - timedelta(hours=i + 5),
                    )
                    tasks.append(task)
                    print(f'  ✓ 创建任务: {task.task_type} - {task.container_master_id.container_number}')
    
    print('\n' + '=' * 60)
    print('示例数据插入完成！')
    print('=' * 60)
    print(f'\n数据统计:')
    print(f'  - 相关方: {Party.objects.count()} 个')
    print(f'  - 港口: {PortMaster.objects.count()} 个')
    print(f'  - 堆场区: {YardBlock.objects.count()} 个')
    print(f'  - 集装箱类型: {ContainerTypeDict.objects.count()} 个')
    print(f'  - 权限: {Permissions.objects.count()} 个')
    print(f'  - 泊位: {Berth.objects.count()} 个')
    print(f'  - 船舶: {VesselMaster.objects.count()} 个')
    print(f'  - 堆栈: {YardStack.objects.count()} 个')
    print(f'  - 用户: {Users.objects.count()} 个')
    print(f'  - 箱位: {YardSlot.objects.count()} 个')
    print(f'  - 集装箱: {ContainerMaster.objects.count()} 个')
    print(f'  - 船舶访问: {VesselVisit.objects.count()} 个')
    print(f'  - 订舱单: {Booking.objects.count()} 个')
    print(f'  - 任务: {Task.objects.count()} 个')
    print('=' * 60)


if __name__ == '__main__':
    try:
        insert_sample_data()
    except Exception as e:
        print(f'\n❌ 插入数据时出错: {str(e)}')
        import traceback
        traceback.print_exc()
        sys.exit(1)

