/*
 * =========================================
 * 港口集装箱运营系统 (TOS) 业务表初始化脚本
 * 仅创建业务表，不删除数据库
 * MySQL 5.7+ / 8.0+
 * =========================================
 * 
 * ✅ 此脚本不会删除数据库，只会创建或重建业务表
 * 适用于：数据库已存在且包含 Django 系统表的情况
 * 
 * 使用步骤：
 * 1. 确保数据库 box_management 已存在
 * 2. 如果使用 Django，先运行: python manage.py migrate
 * 3. 然后运行此脚本创建业务表
 */

USE `box_management`;

-- =========================================
-- 删除已存在的业务表和视图（如果存在）
-- 注意：只删除业务表，不删除 Django 系统表
-- =========================================

-- 删除视图（必须先删除，因为有依赖关系）
DROP VIEW IF EXISTS `View_Pending_Tasks`;
DROP VIEW IF EXISTS `View_Yard_Available_Slots`;
DROP VIEW IF EXISTS `View_Vessel_Visit_Statistics`;
DROP VIEW IF EXISTS `View_Container_Location_Tracking`;
DROP VIEW IF EXISTS `View_Task_Execution_Stats`;
DROP VIEW IF EXISTS `View_User_Permissions`;
DROP VIEW IF EXISTS `View_Container_Status_Summary`;
DROP VIEW IF EXISTS `View_Yard_Utilization`;
DROP VIEW IF EXISTS `View_Booking_Details`;
DROP VIEW IF EXISTS `View_Vessel_Visit_Details`;
DROP VIEW IF EXISTS `View_Task_Details`;
DROP VIEW IF EXISTS `View_Yard_Inventory_Live`;

-- 删除业务表（按依赖关系逆序删除）
DROP TABLE IF EXISTS `Task`;
DROP TABLE IF EXISTS `Booking`;
DROP TABLE IF EXISTS `Vessel_Visit`;
DROP TABLE IF EXISTS `Yard_Slot`;
DROP TABLE IF EXISTS `User_Permissions`;
DROP TABLE IF EXISTS `Yard_Stack`;
DROP TABLE IF EXISTS `Container_Master`;
DROP TABLE IF EXISTS `Vessel_Master`;
DROP TABLE IF EXISTS `Berth`;
DROP TABLE IF EXISTS `Container_Type_Dict`;
DROP TABLE IF EXISTS `Permissions`;
DROP TABLE IF EXISTS `Users`;
DROP TABLE IF EXISTS `Yard_Block`;
DROP TABLE IF EXISTS `Port_Master`;
DROP TABLE IF EXISTS `Party`;

-- =========================================
-- 创建业务表
-- 组 1: 基础主数据 (无依赖或自依赖)
-- =========================================

/* 表: Party - 系统的"通讯录", 存储所有公司或个人 */
CREATE TABLE `Party` (
    `Party_ID` INT NOT NULL AUTO_INCREMENT COMMENT '相关方编号',
    `Party_Name` VARCHAR(255) NOT NULL COMMENT '名称',
    `Party_Type` VARCHAR(20) NOT NULL COMMENT '类型',
    `Address_Line_1` VARCHAR(255) NULL COMMENT '地址',
    `City` VARCHAR(100) NULL COMMENT '城市',
    `Country` CHAR(2) NULL COMMENT '国家代码',
    `Contact_Person` VARCHAR(100) NULL COMMENT '联系人',
    `Email` VARCHAR(255) NULL COMMENT '电子邮件',
    `Phone` VARCHAR(50) NULL COMMENT '电话',
    `SCAC_Code` VARCHAR(10) NULL COMMENT '承运人代码',
    PRIMARY KEY (`Party_ID`),
    UNIQUE INDEX `UQ_Party_Name` (`Party_Name`),
    CONSTRAINT `CHK_Party_Type` CHECK (`Party_Type` IN ('COMPANY', 'PERSON'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='相关方';

/* 表: Port_Master - 港口码头的基础信息 */
CREATE TABLE `Port_Master` (
    `Port_ID` INT NOT NULL AUTO_INCREMENT COMMENT '港口编号',
    `Port_Name` VARCHAR(100) NOT NULL COMMENT '名称',
    `Port_Code` CHAR(5) NOT NULL COMMENT '代码',
    `Country` CHAR(2) NOT NULL COMMENT '国家代码',
    PRIMARY KEY (`Port_ID`),
    UNIQUE INDEX `UQ_Port_Code` (`Port_Code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='港口';

/* 表: Yard_Block - 堆场拓扑的顶层, (例如 "冷藏区 R1") */
CREATE TABLE `Yard_Block` (
    `Block_ID` INT NOT NULL AUTO_INCREMENT COMMENT '堆场区编号',
    `Block_Name` VARCHAR(50) NOT NULL COMMENT '名称',
    `Block_Type` VARCHAR(20) NOT NULL DEFAULT 'Standard' COMMENT '类型',
    PRIMARY KEY (`Block_ID`),
    UNIQUE INDEX `UQ_Block_Name` (`Block_Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='堆场区';

/* 表: Users - 存储用户登录信息 */
CREATE TABLE `Users` (
    `User_ID` INT NOT NULL AUTO_INCREMENT COMMENT '用户编号',
    `Username` VARCHAR(100) NOT NULL COMMENT '用户名',
    `Hashed_Password` VARBINARY(256) NOT NULL COMMENT '密码',
    `Full_Name` VARCHAR(100) NULL COMMENT '全名',
    `Email` VARCHAR(255) NOT NULL COMMENT '电子邮件',
    `Party_ID` INT NULL COMMENT '关联的相关方编号',
    `Is_Active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否激活',
    PRIMARY KEY (`User_ID`),
    UNIQUE INDEX `UQ_Username` (`Username`),
    UNIQUE INDEX `UQ_User_Email` (`Email`),
    CONSTRAINT `FK_User_links_to_Party` FOREIGN KEY (`Party_ID`) REFERENCES `Party`(`Party_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户';

/* 表: Permissions - 定义系统中的原子操作 */
CREATE TABLE `Permissions` (
    `Permission_ID` INT NOT NULL AUTO_INCREMENT COMMENT '权限编号',
    `Permission_Name` VARCHAR(100) NOT NULL COMMENT '名称',
    `Description` VARCHAR(255) NULL COMMENT '描述',
    PRIMARY KEY (`Permission_ID`),
    UNIQUE INDEX `UQ_Permission_Name` (`Permission_Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='权限';

/* 表: Container_Type_Dict - 集装箱类型字典 */
CREATE TABLE `Container_Type_Dict` (
    `Type_Code` VARCHAR(4) NOT NULL COMMENT 'ISO类型代码 (如 22G1)',
    `Nominal_Size` INT NOT NULL COMMENT '名义尺寸 (20/40/45)',
    `Group_Code` VARCHAR(4) NOT NULL COMMENT '组代码 (GP/RF/TK)',
    `Standard_Tare_KG` DECIMAL(8, 2) NULL COMMENT '标准皮重',
    PRIMARY KEY (`Type_Code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='集装箱类型字典';

/* 表: Berth - 泊位基础信息 */
CREATE TABLE `Berth` (
    `Berth_ID` INT NOT NULL AUTO_INCREMENT COMMENT '泊位编号',
    `Port_ID` INT NOT NULL COMMENT '所属港口',
    `Berth_Name` VARCHAR(50) NOT NULL COMMENT '泊位名称 (如 N1, S2)',
    `Length_Meters` DECIMAL(6, 2) NULL COMMENT '泊位长度(米)',
    `Depth_Meters` DECIMAL(5, 2) NULL COMMENT '泊位水深(米)',
    `Max_Vessel_LOA` DECIMAL(6, 2) NULL COMMENT '最大容纳船长',
    PRIMARY KEY (`Berth_ID`),
    UNIQUE INDEX `UQ_Port_Berth_Name` (`Port_ID`, `Berth_Name`),
    CONSTRAINT `FK_Berth_belongs_to_Port` FOREIGN KEY (`Port_ID`) REFERENCES `Port_Master`(`Port_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='泊位基础信息';

-- =========================================
-- 组 2: 依赖于组 1 的主数据
-- =========================================

/* 表: Vessel_Master - 船舶的静态信息 */
CREATE TABLE `Vessel_Master` (
    `Vessel_ID` INT NOT NULL AUTO_INCREMENT COMMENT '船舶编号',
    `Vessel_Name` VARCHAR(100) NOT NULL COMMENT '船名',
    `IMO_Number` VARCHAR(7) NOT NULL COMMENT 'IMO编号',
    `Flag_Country` CHAR(2) NULL COMMENT '船旗国',
    `Carrier_Party_ID` INT NULL COMMENT '承运人编号',
    PRIMARY KEY (`Vessel_ID`),
    UNIQUE INDEX `UQ_IMO_Number` (`IMO_Number`),
    CONSTRAINT `FK_Vessel_owned_by_Carrier` FOREIGN KEY (`Carrier_Party_ID`) REFERENCES `Party`(`Party_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='船舶';

/* 表: Container_Master - 集装箱的静态属性 */
CREATE TABLE `Container_Master` (
    `Container_Master_ID` INT NOT NULL AUTO_INCREMENT COMMENT '集装箱编号',
    `Container_Number` VARCHAR(11) NOT NULL COMMENT '箱号',
    `Owner_Party_ID` INT NULL COMMENT '箱主编号',
    `Type_Code` VARCHAR(4) NOT NULL COMMENT '类型代码 FK', 
    `Current_Status` VARCHAR(20) NULL COMMENT '当前状态 (InYard, OnVessel, GateOut)',
    PRIMARY KEY (`Container_Master_ID`),
    UNIQUE INDEX `UQ_Container_Number` (`Container_Number`),
    CONSTRAINT `FK_Container_owned_by_Party` FOREIGN KEY (`Owner_Party_ID`) REFERENCES `Party`(`Party_ID`),
    CONSTRAINT `FK_Container_ref_Type` FOREIGN KEY (`Type_Code`) REFERENCES `Container_Type_Dict`(`Type_Code`),
    CONSTRAINT `CHK_Container_Number_Format` CHECK (`Container_Number` REGEXP '^[A-Z]{4}[0-9]{7}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='集装箱';

/* 表: Yard_Stack - 堆场中的一个物理栈 (贝/排 组合) */
CREATE TABLE `Yard_Stack` (
    `Stack_ID` INT NOT NULL AUTO_INCREMENT COMMENT '堆栈编号',
    `Block_ID` INT NOT NULL COMMENT '所属堆场区编号',
    `Bay_Number` INT NOT NULL COMMENT '贝位号',
    `Row_Number` INT NOT NULL COMMENT '排号',
    PRIMARY KEY (`Stack_ID`),
    UNIQUE INDEX `UQ_Stack_Location` (`Block_ID`, `Bay_Number`, `Row_Number`),
    CONSTRAINT `FK_Stack_in_Block` FOREIGN KEY (`Block_ID`) REFERENCES `Yard_Block`(`Block_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='堆场堆栈';

/* 表: User_Permissions - 将权限授予用户 (多对多) */
CREATE TABLE `User_Permissions` (
    `User_ID` INT NOT NULL COMMENT '用户编号',
    `Permission_ID` INT NOT NULL COMMENT '权限编号',
    PRIMARY KEY (`User_ID`, `Permission_ID`),
    CONSTRAINT `FK_UserPerm_maps_User` FOREIGN KEY (`User_ID`) REFERENCES `Users`(`User_ID`),
    CONSTRAINT `FK_UserPerm_maps_Permission` FOREIGN KEY (`Permission_ID`) REFERENCES `Permissions`(`Permission_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户权限';

-- =========================================
-- 组 3: 依赖于组 1 & 2 的数据
-- =========================================

/* 表: Yard_Slot - 堆场中的单个物理箱位 (3D坐标) */
CREATE TABLE `Yard_Slot` (
    `Slot_ID` INT NOT NULL AUTO_INCREMENT COMMENT '箱位编号',
    `Stack_ID` INT NOT NULL COMMENT '所属堆栈编号',
    `Tier_Number` INT NOT NULL COMMENT '层号',
    `Slot_Coordinates` VARCHAR(50) NOT NULL COMMENT '坐标',
    `Slot_Status` VARCHAR(20) NOT NULL DEFAULT 'Available' COMMENT '状态',
    `Current_Container_ID` INT NULL COMMENT '当前集装箱编号',
    PRIMARY KEY (`Slot_ID`),
    UNIQUE INDEX `UQ_Slot_Coordinates` (`Slot_Coordinates`),
    UNIQUE INDEX `UQ_Stack_Tier` (`Stack_ID`, `Tier_Number`),
    UNIQUE INDEX `UQ_Slot_Container` (`Current_Container_ID`),
    CONSTRAINT `FK_Slot_belongs_to_Stack` FOREIGN KEY (`Stack_ID`) REFERENCES `Yard_Stack`(`Stack_ID`),
    CONSTRAINT `FK_Slot_occupied_by_Container` FOREIGN KEY (`Current_Container_ID`) REFERENCES `Container_Master`(`Container_Master_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='箱位';

/* 表: Vessel_Visit - 船舶的单次挂靠, 核心枢纽 */
CREATE TABLE `Vessel_Visit` (
    `Vessel_Visit_ID` INT NOT NULL AUTO_INCREMENT COMMENT '船舶访问编号',
    `Vessel_ID` INT NOT NULL COMMENT '船舶编号',
    `Port_ID` INT NOT NULL COMMENT '挂靠港口编号',
    `Berth_ID` INT NULL COMMENT '泊位编号',
    `Voyage_Number_In` VARCHAR(20) NOT NULL COMMENT '进口航次',
    `Voyage_Number_Out` VARCHAR(20) NULL COMMENT '出口航次',
    `ATA` DATETIME NULL COMMENT '实际到港时间',
    `ATD` DATETIME NULL COMMENT '实际离港时间',
    `Status` VARCHAR(20) NOT NULL DEFAULT 'Approaching' COMMENT '状态',
    PRIMARY KEY (`Vessel_Visit_ID`),
    CONSTRAINT `FK_Visit_is_for_Vessel` FOREIGN KEY (`Vessel_ID`) REFERENCES `Vessel_Master`(`Vessel_ID`),
    CONSTRAINT `FK_Visit_is_at_Port` FOREIGN KEY (`Port_ID`) REFERENCES `Port_Master`(`Port_ID`),
    CONSTRAINT `FK_Visit_at_Berth` FOREIGN KEY (`Berth_ID`) REFERENCES `Berth`(`Berth_ID`),
    CONSTRAINT `CHK_Visit_Time_Logic` CHECK (`ATD` >= `ATA` OR `ATD` IS NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='船舶访问';

-- =========================================
-- 组 4: 核心事务表 (Booking & Task)
-- =========================================

/* 表: Booking - 商业活动的起点, "订单" */
CREATE TABLE `Booking` (
    `Booking_ID` INT NOT NULL AUTO_INCREMENT COMMENT '订舱单编号',
    `Booking_Number` VARCHAR(50) NOT NULL COMMENT '订舱号',
    `Status` VARCHAR(20) NOT NULL DEFAULT 'Draft' COMMENT '状态',
    `Shipper_Party_ID` INT NULL COMMENT '发货人编号',
    `Consignee_Party_ID` INT NULL COMMENT '收货人编号',
    `Payer_Party_ID` INT NULL COMMENT '付费方编号',
    `Voyage_ID` INT NULL COMMENT '航次编号',
    PRIMARY KEY (`Booking_ID`),
    UNIQUE INDEX `UQ_Booking_Number` (`Booking_Number`),
    CONSTRAINT `FK_Booking_has_Shipper` FOREIGN KEY (`Shipper_Party_ID`) REFERENCES `Party`(`Party_ID`),
    CONSTRAINT `FK_Booking_has_Consignee` FOREIGN KEY (`Consignee_Party_ID`) REFERENCES `Party`(`Party_ID`),
    CONSTRAINT `FK_Booking_has_Payer` FOREIGN KEY (`Payer_Party_ID`) REFERENCES `Party`(`Party_ID`),
    CONSTRAINT `FK_Booking_is_for_Voyage` FOREIGN KEY (`Voyage_ID`) REFERENCES `Vessel_Visit`(`Vessel_Visit_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订舱单';

/* 表: Task - 合并了"计划"与"执行"的作业任务 */
CREATE TABLE `Task` (
    `Task_ID` INT NOT NULL AUTO_INCREMENT COMMENT '任务编号',
    `Task_Type` VARCHAR(30) NOT NULL COMMENT '任务类型',
    `Status` VARCHAR(20) NOT NULL DEFAULT 'Pending' COMMENT '状态 (Pending, Completed, Cancelled)',
    `Container_Master_ID` INT NOT NULL COMMENT '集装箱编号',
    `From_Slot_ID` INT NULL COMMENT '计划起始箱位编号',
    `To_Slot_ID` INT NULL COMMENT '计划目标箱位编号',
    `Vessel_Visit_ID` INT NULL COMMENT '关联的船舶访问编号',
    `Created_By_User_ID` INT NOT NULL COMMENT '创建任务的用户编号',
    `Assigned_User_ID` INT NULL COMMENT '指派给的用户编号',
    `Actual_Executor_ID` INT NULL COMMENT '实际执行的用户编号',
    `Priority` INT NOT NULL DEFAULT 100 COMMENT '优先级',
    `Movement_Timestamp` DATETIME(6) NULL COMMENT '实际移动时间戳',
    PRIMARY KEY (`Task_ID`),
    CONSTRAINT `FK_Task_is_for_Container` FOREIGN KEY (`Container_Master_ID`) REFERENCES `Container_Master`(`Container_Master_ID`),
    CONSTRAINT `FK_Task_from_Slot` FOREIGN KEY (`From_Slot_ID`) REFERENCES `Yard_Slot`(`Slot_ID`),
    CONSTRAINT `FK_Task_to_Slot` FOREIGN KEY (`To_Slot_ID`) REFERENCES `Yard_Slot`(`Slot_ID`),
    CONSTRAINT `FK_Task_related_to_Visit` FOREIGN KEY (`Vessel_Visit_ID`) REFERENCES `Vessel_Visit`(`Vessel_Visit_ID`),
    CONSTRAINT `FK_Task_created_by_User` FOREIGN KEY (`Created_By_User_ID`) REFERENCES `Users`(`User_ID`),
    CONSTRAINT `FK_Task_assigned_to_User` FOREIGN KEY (`Assigned_User_ID`) REFERENCES `Users`(`User_ID`),
    CONSTRAINT `FK_Task_executed_by_User` FOREIGN KEY (`Actual_Executor_ID`) REFERENCES `Users`(`User_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='作业任务 (计划与执行)';

-- =========================================
-- 组 5: 视图
-- =========================================

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

/* 视图3: View_Vessel_Visit_Details - 船舶访问详情视图 */
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

/* 视图4: View_Booking_Details - 订舱单详情视图 */
CREATE OR REPLACE VIEW `View_Booking_Details` AS
SELECT 
    b.Booking_ID AS 订舱单编号,
    b.Booking_Number AS 订舱号,
    b.Status AS 订舱状态,
    shipper.Party_Name AS 发货人,
    shipper.Contact_Person AS 发货人联系人,
    shipper.Email AS 发货人邮箱,
    consignee.Party_Name AS 收货人,
    consignee.Contact_Person AS 收货人联系人,
    payer.Party_Name AS 付费方,
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

/* 视图5: View_Yard_Utilization - 堆场利用率统计视图 */
CREATE OR REPLACE VIEW `View_Yard_Utilization` AS
SELECT 
    yb.Block_ID AS 堆场区编号,
    yb.Block_Name AS 堆场区名称,
    yb.Block_Type AS 堆场区类型,
    COUNT(DISTINCT ys.Stack_ID) AS 堆栈总数,
    COUNT(DISTINCT slot.Slot_ID) AS 箱位总数,
    COUNT(DISTINCT CASE WHEN slot.Current_Container_ID IS NOT NULL THEN slot.Slot_ID END) AS 已占用箱位数,
    COUNT(DISTINCT CASE WHEN slot.Current_Container_ID IS NULL THEN slot.Slot_ID END) AS 空闲箱位数,
    ROUND(
        COUNT(DISTINCT CASE WHEN slot.Current_Container_ID IS NOT NULL THEN slot.Slot_ID END) * 100.0 / 
        NULLIF(COUNT(DISTINCT slot.Slot_ID), 0), 
        2
    ) AS 利用率_百分比
FROM `Yard_Block` yb
LEFT JOIN `Yard_Stack` ys ON yb.Block_ID = ys.Block_ID
LEFT JOIN `Yard_Slot` slot ON ys.Stack_ID = slot.Stack_ID
GROUP BY yb.Block_ID, yb.Block_Name, yb.Block_Type;

/* 视图6: View_Container_Status_Summary - 集装箱状态统计视图 */
CREATE OR REPLACE VIEW `View_Container_Status_Summary` AS
SELECT 
    cm.Current_Status AS 集装箱状态,
    ct.Type_Code AS 箱型代码,
    ct.Nominal_Size AS 箱尺寸_英尺,
    ct.Group_Code AS 箱型组,
    COUNT(*) AS 数量,
    COUNT(DISTINCT cm.Owner_Party_ID) AS 箱主数量
FROM `Container_Master` cm
JOIN `Container_Type_Dict` ct ON cm.Type_Code = ct.Type_Code
WHERE cm.Current_Status IS NOT NULL
GROUP BY cm.Current_Status, ct.Type_Code, ct.Nominal_Size, ct.Group_Code
ORDER BY cm.Current_Status, ct.Nominal_Size DESC, 数量 DESC;

/* 视图7: View_User_Permissions - 用户权限视图 */
CREATE OR REPLACE VIEW `View_User_Permissions` AS
SELECT 
    u.User_ID AS 用户编号,
    u.Username AS 用户名,
    u.Full_Name AS 全名,
    u.Email AS 邮箱,
    u.Is_Active AS 是否激活,
    p.Party_Name AS 关联相关方,
    GROUP_CONCAT(perm.Permission_Name ORDER BY perm.Permission_Name SEPARATOR ', ') AS 权限列表,
    COUNT(DISTINCT perm.Permission_ID) AS 权限数量
FROM `Users` u
LEFT JOIN `Party` p ON u.Party_ID = p.Party_ID
LEFT JOIN `User_Permissions` up ON u.User_ID = up.User_ID
LEFT JOIN `Permissions` perm ON up.Permission_ID = perm.Permission_ID
GROUP BY u.User_ID, u.Username, u.Full_Name, u.Email, u.Is_Active, p.Party_Name;

/* 视图8: View_Task_Execution_Stats - 任务执行统计视图 */
CREATE OR REPLACE VIEW `View_Task_Execution_Stats` AS
SELECT 
    u.User_ID AS 用户编号,
    u.Username AS 用户名,
    u.Full_Name AS 全名,
    COUNT(DISTINCT CASE WHEN t.Created_By_User_ID = u.User_ID THEN t.Task_ID END) AS 创建任务数,
    COUNT(DISTINCT CASE WHEN t.Assigned_User_ID = u.User_ID THEN t.Task_ID END) AS 被指派任务数,
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID THEN t.Task_ID END) AS 执行任务数,
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID AND t.Status = 'Completed' THEN t.Task_ID END) AS 已完成任务数,
    COUNT(DISTINCT CASE WHEN t.Actual_Executor_ID = u.User_ID AND t.Status = 'Pending' THEN t.Task_ID END) AS 待执行任务数,
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

/* 视图9: View_Container_Location_Tracking - 集装箱位置追踪视图 */
CREATE OR REPLACE VIEW `View_Container_Location_Tracking` AS
SELECT 
    cm.Container_Master_ID AS 集装箱编号,
    cm.Container_Number AS 箱号,
    cm.Current_Status AS 当前状态,
    ct.Type_Code AS 箱型代码,
    ct.Nominal_Size AS 箱尺寸,
    ct.Group_Code AS 箱型组,
    p.Party_Name AS 箱主,
    p.SCAC_Code AS 箱主代码,
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
    yb.Block_Name AS 堆场区,
    ys.Bay_Number AS 贝位,
    ys.Row_Number AS 排号,
    slot.Tier_Number AS 层号,
    slot.Slot_Coordinates AS 坐标代码,
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

/* 视图10: View_Vessel_Visit_Statistics - 船舶访问统计视图 */
CREATE OR REPLACE VIEW `View_Vessel_Visit_Statistics` AS
SELECT 
    vm.Vessel_ID AS 船舶编号,
    vm.Vessel_Name AS 船舶名称,
    vm.IMO_Number AS IMO编号,
    carrier.Party_Name AS 承运人,
    COUNT(DISTINCT vv.Vessel_Visit_ID) AS 访问次数,
    COUNT(DISTINCT CASE WHEN vv.Status = 'Completed' THEN vv.Vessel_Visit_ID END) AS 已完成访问次数,
    COUNT(DISTINCT CASE WHEN vv.Status = 'Approaching' THEN vv.Vessel_Visit_ID END) AS 即将到港次数,
    COUNT(DISTINCT t.Container_Master_ID) AS 处理集装箱总数,
    COUNT(DISTINCT CASE WHEN t.Task_Type = 'Load' THEN t.Container_Master_ID END) AS 装船集装箱数,
    COUNT(DISTINCT CASE WHEN t.Task_Type = 'Discharge' THEN t.Container_Master_ID END) AS 卸船集装箱数,
    COUNT(DISTINCT t.Task_ID) AS 任务总数,
    COUNT(DISTINCT CASE WHEN t.Status = 'Completed' THEN t.Task_ID END) AS 已完成任务数
FROM `Vessel_Master` vm
LEFT JOIN `Party` carrier ON vm.Carrier_Party_ID = carrier.Party_ID
LEFT JOIN `Vessel_Visit` vv ON vm.Vessel_ID = vv.Vessel_ID
LEFT JOIN `Task` t ON vv.Vessel_Visit_ID = t.Vessel_Visit_ID
GROUP BY vm.Vessel_ID, vm.Vessel_Name, vm.IMO_Number, carrier.Party_Name
ORDER BY 访问次数 DESC, 处理集装箱总数 DESC;

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

/* 视图12: View_Pending_Tasks - 待执行任务视图 */
CREATE OR REPLACE VIEW `View_Pending_Tasks` AS
SELECT 
    t.Task_ID AS 任务编号,
    t.Task_Type AS 任务类型,
    t.Priority AS 优先级,
    cm.Container_Number AS 箱号,
    ct.Nominal_Size AS 箱尺寸,
    CONCAT(yb_from.Block_Name, '-', ys_from.Bay_Number, '-', ys_from.Row_Number, '-', slot_from.Tier_Number) AS 起始位置,
    CONCAT(yb_to.Block_Name, '-', ys_to.Bay_Number, '-', ys_to.Row_Number, '-', slot_to.Tier_Number) AS 目标位置,
    vm.Vessel_Name AS 船舶名称,
    vv.Voyage_Number_Out AS 航次,
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
SELECT '业务表创建成功！' AS 提示信息;
SELECT '所有业务表已创建完成！' AS 提示信息;
SELECT '所有视图已创建完成！共12个视图' AS 提示信息;
SELECT '注意：Django 系统表（如 auth_user, django_migrations）未被删除' AS 提示信息;







