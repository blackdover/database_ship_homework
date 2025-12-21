/*
 * =========================================
 * 港口集装箱运营系统 (TOS) - 视图脚本
 * 提供多种业务场景的查询视图
 * MySQL 5.7+ / 8.0+
 * =========================================
 */

USE `box_management`;

-- =========================================
-- 视图1：堆场实时库存视图（已存在，保留）
-- =========================================
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

-- =========================================
-- 视图2：任务详情视图
-- =========================================
-- 功能：显示任务的完整信息，包括集装箱、位置、用户、船舶等
CREATE OR REPLACE VIEW `View_Task_Details` AS
SELECT 
    t.Task_ID AS 任务编号,
    t.Task_Type AS 任务类型,
    t.Status AS 任务状态,
    t.Priority AS 优先级,
    t.Movement_Timestamp AS 实际执行时间,
    
    -- 集装箱信息
    cm.Container_Number AS 箱号,
    cm.Current_Status AS 箱状态,
    ct.Type_Code AS 箱型代码,
    ct.Nominal_Size AS 箱尺寸,
    
    -- 起始位置
    yb_from.Block_Name AS 起始堆场区,
    ys_from.Bay_Number AS 起始贝位,
    ys_from.Row_Number AS 起始排号,
    slot_from.Tier_Number AS 起始层号,
    slot_from.Slot_Coordinates AS 起始坐标,
    
    -- 目标位置
    yb_to.Block_Name AS 目标堆场区,
    ys_to.Bay_Number AS 目标贝位,
    ys_to.Row_Number AS 目标排号,
    slot_to.Tier_Number AS 目标层号,
    slot_to.Slot_Coordinates AS 目标坐标,
    
    -- 船舶信息
    vm.Vessel_Name AS 船舶名称,
    vv.Voyage_Number_In AS 进口航次,
    vv.Voyage_Number_Out AS 出口航次,
    
    -- 用户信息
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

-- =========================================
-- 视图3：船舶访问详情视图
-- =========================================
-- 功能：显示船舶访问的完整信息，包括船舶、港口、泊位、统计信息等
CREATE OR REPLACE VIEW `View_Vessel_Visit_Details` AS
SELECT 
    vv.Vessel_Visit_ID AS 访问编号,
    vm.Vessel_Name AS 船舶名称,
    vm.IMO_Number AS IMO编号,
    vm.Flag_Country AS 船旗国,
    carrier.Party_Name AS 承运人,
    
    pm.Port_Name AS 港口名称,
    pm.Port_Code AS 港口代码,
    b.Berth_Name AS 泊位名称,
    
    vv.Voyage_Number_In AS 进口航次,
    vv.Voyage_Number_Out AS 出口航次,
    vv.ATA AS 到港时间,
    vv.ATD AS 离港时间,
    vv.Status AS 访问状态,
    
    -- 统计信息
    COUNT(DISTINCT t.Task_ID) AS 任务总数,
    COUNT(DISTINCT CASE WHEN t.Status = 'Completed' THEN t.Task_ID END) AS 已完成任务数,
    COUNT(DISTINCT t.Container_Master_ID) AS 集装箱总数,
    COUNT(DISTINCT bkg.Booking_ID) AS 订舱单总数
FROM `Vessel_Visit` vv
JOIN `Vessel_Master` vm ON vv.Vessel_ID = vm.Vessel_ID
LEFT JOIN `Party` carrier ON vm.Carrier_Party_ID = carrier.Party_ID
JOIN `Port_Master` pm ON vv.Port_ID = pm.Port_ID
LEFT JOIN `Berth` b ON vv.Berth_ID = b.Berth_ID
LEFT JOIN `Task` t ON vv.Vessel_Visit_ID = t.Vessel_Visit_ID
LEFT JOIN `Booking` bkg ON vv.Vessel_Visit_ID = bkg.Voyage_ID
GROUP BY 
    vv.Vessel_Visit_ID, vm.Vessel_Name, vm.IMO_Number, vm.Flag_Country,
    carrier.Party_Name, pm.Port_Name, pm.Port_Code, b.Berth_Name,
    vv.Voyage_Number_In, vv.Voyage_Number_Out, vv.ATA, vv.ATD, vv.Status;

-- =========================================
-- 视图4：订舱单详情视图
-- =========================================
-- 功能：显示订舱单的完整信息，包括相关方、航次等
CREATE OR REPLACE VIEW `View_Booking_Details` AS
SELECT 
    b.Booking_ID AS 订舱单编号,
    b.Booking_Number AS 订舱号,
    b.Status AS 订舱状态,
    
    -- 相关方信息
    shipper.Party_Name AS 发货人,
    shipper.Contact_Person AS 发货人联系人,
    shipper.Email AS 发货人邮箱,
    consignee.Party_Name AS 收货人,
    consignee.Contact_Person AS 收货人联系人,
    payer.Party_Name AS 付费方,
    
    -- 航次信息
    vv.Vessel_Visit_ID AS 航次编号,
    vm.Vessel_Name AS 船舶名称,
    vv.Voyage_Number_In AS 进口航次,
    vv.Voyage_Number_Out AS 出口航次,
    pm.Port_Name AS 港口名称,
    vv.ATA AS 预计到港时间,
    vv.ATD AS 预计离港时间
FROM `Booking` b
LEFT JOIN `Party` shipper ON b.Shipper_Party_ID = shipper.Party_ID
LEFT JOIN `Party` consignee ON b.Consignee_Party_ID = consignee.Party_ID
LEFT JOIN `Party` payer ON b.Payer_Party_ID = payer.Party_ID
LEFT JOIN `Vessel_Visit` vv ON b.Voyage_ID = vv.Vessel_Visit_ID
LEFT JOIN `Vessel_Master` vm ON vv.Vessel_ID = vm.Vessel_ID
LEFT JOIN `Port_Master` pm ON vv.Port_ID = pm.Port_ID;

-- =========================================
-- 视图5：堆场利用率统计视图
-- =========================================
-- 功能：按堆场区统计箱位利用情况
CREATE OR REPLACE VIEW `View_Yard_Utilization` AS
SELECT 
    yb.Block_ID AS 堆场区编号,
    yb.Block_Name AS 堆场区名称,
    yb.Block_Type AS 堆场区类型,
    
    -- 统计信息
    COUNT(DISTINCT ys.Stack_ID) AS 堆栈总数,
    COUNT(DISTINCT slot.Slot_ID) AS 箱位总数,
    COUNT(DISTINCT CASE WHEN slot.Current_Container_ID IS NOT NULL THEN slot.Slot_ID END) AS 已占用箱位数,
    COUNT(DISTINCT CASE WHEN slot.Current_Container_ID IS NULL THEN slot.Slot_ID END) AS 空闲箱位数,
    
    -- 利用率计算
    ROUND(
        COUNT(DISTINCT CASE WHEN slot.Current_Container_ID IS NOT NULL THEN slot.Slot_ID END) * 100.0 / 
        NULLIF(COUNT(DISTINCT slot.Slot_ID), 0), 
        2
    ) AS 利用率_百分比
FROM `Yard_Block` yb
LEFT JOIN `Yard_Stack` ys ON yb.Block_ID = ys.Block_ID
LEFT JOIN `Yard_Slot` slot ON ys.Stack_ID = slot.Stack_ID
GROUP BY yb.Block_ID, yb.Block_Name, yb.Block_Type;

-- =========================================
-- 视图6：集装箱状态统计视图
-- =========================================
-- 功能：按状态、箱型统计集装箱数量
CREATE OR REPLACE VIEW `View_Container_Status_Summary` AS
SELECT 
    cm.Current_Status AS 集装箱状态,
    ct.Type_Code AS 箱型代码,
    ct.Nominal_Size AS 箱尺寸_英尺,
    ct.Group_Code AS 箱型组,
    COUNT(*) AS 数量,
    
    -- 按箱主统计
    COUNT(DISTINCT cm.Owner_Party_ID) AS 箱主数量
FROM `Container_Master` cm
JOIN `Container_Type_Dict` ct ON cm.Type_Code = ct.Type_Code
WHERE cm.Current_Status IS NOT NULL
GROUP BY cm.Current_Status, ct.Type_Code, ct.Nominal_Size, ct.Group_Code
ORDER BY cm.Current_Status, ct.Nominal_Size DESC, 数量 DESC;

-- =========================================
-- 视图7：用户权限视图
-- =========================================
-- 功能：显示用户及其拥有的权限
CREATE OR REPLACE VIEW `View_User_Permissions` AS
SELECT 
    u.User_ID AS 用户编号,
    u.Username AS 用户名,
    u.Full_Name AS 全名,
    u.Email AS 邮箱,
    u.Is_Active AS 是否激活,
    p.Party_Name AS 关联相关方,
    
    -- 权限信息
    GROUP_CONCAT(perm.Permission_Name ORDER BY perm.Permission_Name SEPARATOR ', ') AS 权限列表,
    COUNT(DISTINCT perm.Permission_ID) AS 权限数量
FROM `Users` u
LEFT JOIN `Party` p ON u.Party_ID = p.Party_ID
LEFT JOIN `User_Permissions` up ON u.User_ID = up.User_ID
LEFT JOIN `Permissions` perm ON up.Permission_ID = perm.Permission_ID
GROUP BY u.User_ID, u.Username, u.Full_Name, u.Email, u.Is_Active, p.Party_Name;

-- =========================================
-- 视图8：任务执行统计视图
-- =========================================
-- 功能：按用户统计任务执行情况
CREATE OR REPLACE VIEW `View_Task_Execution_Stats` AS
SELECT 
    u.User_ID AS 用户编号,
    u.Username AS 用户名,
    u.Full_Name AS 全名,
    
    -- 任务统计
    COUNT(DISTINCT CASE WHEN t.Created_By_User_ID = u.User_ID THEN t.Task_ID END) AS 创建任务数,
    COUNT(DISTINCT CASE WHEN t.Assigned_User_ID = u.User_ID THEN t.Task_ID END) AS 被指派任务数,
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID THEN t.Task_ID END) AS 执行任务数,
    
    -- 完成情况
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID AND t.Status = 'Completed' THEN t.Task_ID END) AS 已完成任务数,
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID AND t.Status = 'Pending' THEN t.Task_ID END) AS 待执行任务数,
    
    -- 任务类型统计
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID AND t.Task_Type = 'Load' THEN t.Task_ID END) AS 装船任务数,
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID AND t.Task_Type = 'Discharge' THEN t.Task_ID END) AS 卸船任务数,
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID AND t.Task_Type = 'GateIn' THEN t.Task_ID END) AS 进闸任务数,
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID AND t.Task_Type = 'GateOut' THEN t.Task_ID END) AS 出闸任务数
FROM `Users` u
LEFT JOIN `Task` t ON (
    u.User_ID = t.Created_By_User_ID OR 
    u.User_ID = t.Assigned_User_ID OR 
    u.User_ID = t.Actual_Executor_ID
)
GROUP BY u.User_ID, u.Username, u.Full_Name;

-- =========================================
-- 视图9：集装箱位置追踪视图
-- =========================================
-- 功能：显示所有集装箱的当前位置和状态
CREATE OR REPLACE VIEW `View_Container_Location_Tracking` AS
SELECT 
    cm.Container_Master_ID AS 集装箱编号,
    cm.Container_Number AS 箱号,
    cm.Current_Status AS 当前状态,
    
    -- 箱型信息
    ct.Type_Code AS 箱型代码,
    ct.Nominal_Size AS 箱尺寸,
    ct.Group_Code AS 箱型组,
    
    -- 箱主信息
    p.Party_Name AS 箱主,
    p.SCAC_Code AS 箱主代码,
    
    -- 当前位置
    CASE 
        WHEN cm.Current_Status = 'InYard' THEN 
            CONCAT(
                yb.Block_Name, '-',
                ys.Bay_Number, '-',
                ys.Row_Number, '-',
                slot.Tier_Number
            )
        WHEN cm.Current_Status = 'OnVessel' THEN 
            CONCAT('船舶: ', vm.Vessel_Name)
        WHEN cm.Current_Status = 'GateOut' THEN '已出闸'
        ELSE '未知位置'
    END AS 当前位置,
    
    -- 堆场位置详情（如果在堆场）
    yb.Block_Name AS 堆场区,
    ys.Bay_Number AS 贝位,
    ys.Row_Number AS 排号,
    slot.Tier_Number AS 层号,
    slot.Slot_Coordinates AS 坐标代码,
    
    -- 船舶信息（如果在船上）
    vm.Vessel_Name AS 所在船舶,
    vv.Voyage_Number_Out AS 航次
FROM `Container_Master` cm
JOIN `Container_Type_Dict` ct ON cm.Type_Code = ct.Type_Code
LEFT JOIN `Party` p ON cm.Owner_Party_ID = p.Party_ID
LEFT JOIN `Yard_Slot` slot ON slot.Current_Container_ID = cm.Container_Master_ID
LEFT JOIN `Yard_Stack` ys ON slot.Stack_ID = ys.Stack_ID
LEFT JOIN `Yard_Block` yb ON ys.Block_ID = yb.Block_ID
LEFT JOIN `Task` t ON t.Container_Master_ID = cm.Container_Master_ID 
    AND t.Status = 'Completed' 
    AND t.Task_Type = 'Load'
LEFT JOIN `Vessel_Visit` vv ON t.Vessel_Visit_ID = vv.Vessel_Visit_ID
LEFT JOIN `Vessel_Master` vm ON vv.Vessel_ID = vm.Vessel_ID;

-- =========================================
-- 视图10：船舶访问统计视图
-- =========================================
-- 功能：按船舶统计访问次数和集装箱数量
CREATE OR REPLACE VIEW `View_Vessel_Visit_Statistics` AS
SELECT 
    vm.Vessel_ID AS 船舶编号,
    vm.Vessel_Name AS 船舶名称,
    vm.IMO_Number AS IMO编号,
    carrier.Party_Name AS 承运人,
    
    -- 访问统计
    COUNT(DISTINCT vv.Vessel_Visit_ID) AS 访问次数,
    COUNT(DISTINCT CASE WHEN vv.Status = 'Completed' THEN vv.Vessel_Visit_ID END) AS 已完成访问次数,
    COUNT(DISTINCT CASE WHEN vv.Status = 'Approaching' THEN vv.Vessel_Visit_ID END) AS 即将到港次数,
    
    -- 集装箱统计
    COUNT(DISTINCT t.Container_Master_ID) AS 处理集装箱总数,
    COUNT(DISTINCT CASE WHEN t.Task_Type = 'Load' THEN t.Container_Master_ID END) AS 装船集装箱数,
    COUNT(DISTINCT CASE WHEN t.Task_Type = 'Discharge' THEN t.Container_Master_ID END) AS 卸船集装箱数,
    
    -- 任务统计
    COUNT(DISTINCT t.Task_ID) AS 任务总数,
    COUNT(DISTINCT CASE WHEN t.Status = 'Completed' THEN t.Task_ID END) AS 已完成任务数
FROM `Vessel_Master` vm
LEFT JOIN `Party` carrier ON vm.Carrier_Party_ID = carrier.Party_ID
LEFT JOIN `Vessel_Visit` vv ON vm.Vessel_ID = vv.Vessel_ID
LEFT JOIN `Task` t ON vv.Vessel_Visit_ID = t.Vessel_Visit_ID
GROUP BY vm.Vessel_ID, vm.Vessel_Name, vm.IMO_Number, carrier.Party_Name
ORDER BY 访问次数 DESC, 处理集装箱总数 DESC;

-- =========================================
-- 视图11：堆场空位视图
-- =========================================
-- 功能：显示所有可用的堆场空位
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

-- =========================================
-- 视图12：待执行任务视图
-- =========================================
-- 功能：显示所有待执行的任务
CREATE OR REPLACE VIEW `View_Pending_Tasks` AS
SELECT 
    t.Task_ID AS 任务编号,
    t.Task_Type AS 任务类型,
    t.Priority AS 优先级,
    cm.Container_Number AS 箱号,
    ct.Nominal_Size AS 箱尺寸,
    
    -- 起始位置
    CONCAT(yb_from.Block_Name, '-', ys_from.Bay_Number, '-', ys_from.Row_Number, '-', slot_from.Tier_Number) AS 起始位置,
    
    -- 目标位置
    CONCAT(yb_to.Block_Name, '-', ys_to.Bay_Number, '-', ys_to.Row_Number, '-', slot_to.Tier_Number) AS 目标位置,
    
    -- 船舶信息
    vm.Vessel_Name AS 船舶名称,
    vv.Voyage_Number_Out AS 航次,
    
    -- 用户信息
    u_creator.Username AS 创建人,
    u_assigned.Username AS 指派给,
    u_assigned.Full_Name AS 指派给姓名
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
WHERE t.Status = 'Pending'
ORDER BY t.Priority ASC, t.Task_ID ASC;

-- =========================================
-- 完成提示
-- =========================================
SELECT '所有视图创建成功！' AS 提示信息;
SELECT COUNT(*) AS 视图总数 FROM information_schema.views WHERE table_schema = 'box_management';

