/*
 * =========================================
 * 港口集装箱运营系统 (TOS) 统一数据库 (MySQL 格式)
 * * 合并的表创建脚本
 * 顺序已调整以满足外键约束
 * =========================================
 */


/*
 * =========================================
 * 组 1: 基础主数据 (无依赖或自依赖)
 * =========================================
 */

/* * 表: Party * 描述:  系统的“通讯录”, 存储所有公司或个人 */
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
) ENGINE=InnoDB COMMENT='相关方';

/* * 表: Port_Master * 描述:  港口码头的基础信息 */
CREATE TABLE `Port_Master` (
    `Port_ID` INT NOT NULL AUTO_INCREMENT COMMENT '港口编号',
    `Port_Name` VARCHAR(100) NOT NULL COMMENT '名称',
    `Port_Code` CHAR(5) NOT NULL COMMENT '代码',
    `Country` CHAR(2) NOT NULL COMMENT '国家代码',
    PRIMARY KEY (`Port_ID`),
    UNIQUE INDEX `UQ_Port_Code` (`Port_Code`)
) ENGINE=InnoDB COMMENT='港口';

/* * 表: Yard_Block * 描述:  堆场拓扑的顶层, (例如 "冷藏区 R1") */
CREATE TABLE `Yard_Block` (
    `Block_ID` INT NOT NULL AUTO_INCREMENT COMMENT '堆场区编号',
    `Block_Name` VARCHAR(50) NOT NULL COMMENT '名称',
    `Block_Type` VARCHAR(20) NOT NULL DEFAULT 'Standard' COMMENT '类型',
    PRIMARY KEY (`Block_ID`),
    UNIQUE INDEX `UQ_Block_Name` (`Block_Name`)
) ENGINE=InnoDB COMMENT='堆场区';

/* * 表: Users * 描述:  存储用户登录信息 */
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
) ENGINE=InnoDB COMMENT='用户';

/* * 表: Permissions * 描述:  定义系统中的原子操作 */
CREATE TABLE `Permissions` (
    `Permission_ID` INT NOT NULL AUTO_INCREMENT COMMENT '权限编号',
    `Permission_Name` VARCHAR(100) NOT NULL COMMENT '名称',
    `Description` VARCHAR(255) NULL COMMENT '描述',
    PRIMARY KEY (`Permission_ID`),
    UNIQUE INDEX `UQ_Permission_Name` (`Permission_Name`)
) ENGINE=InnoDB COMMENT='权限';

CREATE TABLE `Container_Type_Dict` (
    `Type_Code` VARCHAR(4) NOT NULL COMMENT 'ISO类型代码 (如 22G1)',
    `Nominal_Size` INT NOT NULL COMMENT '名义尺寸 (20/40/45)',
    `Group_Code` VARCHAR(4) NOT NULL COMMENT '组代码 (GP/RF/TK)',
    `Standard_Tare_KG` DECIMAL(8, 2) NULL COMMENT '标准皮重',
    PRIMARY KEY (`Type_Code`)
) ENGINE=InnoDB COMMENT='集装箱类型字典';   

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
) ENGINE=InnoDB COMMENT='泊位基础信息';

/*
 * =========================================
 * 组 2: 依赖于组 1 的主数据
 * =========================================
 */

/* * 表: Vessel_Master * 描述:  船舶的静态信息 */
CREATE TABLE `Vessel_Master` (
    `Vessel_ID` INT NOT NULL AUTO_INCREMENT COMMENT '船舶编号',
    `Vessel_Name` VARCHAR(100) NOT NULL COMMENT '船名',
    `IMO_Number` VARCHAR(7) NOT NULL COMMENT 'IMO编号',
    `Flag_Country` CHAR(2) NULL COMMENT '船旗国',
    `Carrier_Party_ID` INT NULL COMMENT '承运人编号',
    PRIMARY KEY (`Vessel_ID`),
    UNIQUE INDEX `UQ_IMO_Number` (`IMO_Number`),
    CONSTRAINT `FK_Vessel_owned_by_Carrier` FOREIGN KEY (`Carrier_Party_ID`) REFERENCES `Party`(`Party_ID`)
) ENGINE=InnoDB COMMENT='船舶';

/* * 表: Container_Master * 描述:  集装箱的静态属性 */
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
) ENGINE=InnoDB COMMENT='集装箱';

/* * 表: Yard_Stack * 描述:  堆场中的一个物理栈 (贝/排 组合) */
CREATE TABLE `Yard_Stack` (
    `Stack_ID` INT NOT NULL AUTO_INCREMENT COMMENT '堆栈编号',
    `Block_ID` INT NOT NULL COMMENT '所属堆场区编号',
    `Bay_Number` INT NOT NULL COMMENT '贝位号',
    `Row_Number` INT NOT NULL COMMENT '排号',
    PRIMARY KEY (`Stack_ID`),
    UNIQUE INDEX `UQ_Stack_Location` (`Block_ID`, `Bay_Number`, `Row_Number`),
    CONSTRAINT `FK_Stack_in_Block` FOREIGN KEY (`Block_ID`) REFERENCES `Yard_Block`(`Block_ID`)
) ENGINE=InnoDB COMMENT='堆场堆栈';

/* * 表: User_Permissions * 描述:  将权限授予用户 (多对多) */
CREATE TABLE `User_Permissions` (
    `User_ID` INT NOT NULL COMMENT '用户编号',
    `Permission_ID` INT NOT NULL COMMENT '权限编号',
    PRIMARY KEY (`User_ID`, `Permission_ID`),
    CONSTRAINT `FK_UserPerm_maps_User` FOREIGN KEY (`User_ID`) REFERENCES `Users`(`User_ID`),
    CONSTRAINT `FK_UserPerm_maps_Permission` FOREIGN KEY (`Permission_ID`) REFERENCES `Permissions`(`Permission_ID`)
) ENGINE=InnoDB COMMENT='用户权限';


/*
 * =========================================
 * 组 3: 依赖于组 1 & 2 的数据
 * =========================================
 */

/* * 表: Yard_Slot * 描述:  堆场中的单个物理箱位 (3D坐标) */
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
) ENGINE=InnoDB COMMENT='箱位';

/* * 表: Vessel_Visit * 描述:  船舶的单次挂靠, 核心枢纽 */
CREATE TABLE `Vessel_Visit` (
    `Vessel_Visit_ID` INT NOT NULL AUTO_INCREMENT COMMENT '船舶访问编号',
    `Vessel_ID` INT NOT NULL COMMENT '船舶编号',
    `Port_ID` INT NOT NULL COMMENT '挂靠港口编号',
    `Berth_ID` INT NULL COMMENT '泊位编号',
    `Voyage_Number_In` VARCHAR(20) NOT NULL COMMENT '进口航次',
    `Voyage_Number_Out` VARCHAR(20) NOT NULL COMMENT '出口航次',
    `ATA` DATETIME NULL COMMENT '实际到港时间',
    `ATD` DATETIME NULL COMMENT '实际离港时间',
    `Status` VARCHAR(20) NOT NULL DEFAULT 'Approaching' COMMENT '状态',
    PRIMARY KEY (`Vessel_Visit_ID`),
    CONSTRAINT `FK_Visit_is_for_Vessel` FOREIGN KEY (`Vessel_ID`) REFERENCES `Vessel_Master`(`Vessel_ID`),
    CONSTRAINT `FK_Visit_is_at_Port` FOREIGN KEY (`Port_ID`) REFERENCES `Port_Master`(`Port_ID`),
    CONSTRAINT `FK_Visit_at_Berth` FOREIGN KEY (`Berth_ID`) REFERENCES `Berth`(`Berth_ID`),
    CONSTRAINT `CHK_Visit_Time_Logic` CHECK (`ATD` >= `ATA` OR `ATD` IS NULL)
) ENGINE=InnoDB COMMENT='船舶访问';


/*
 * =========================================
 * 组 4: 核心事务表 (Booking & Task)
 * =========================================
 */

/* * 表: Booking * 描述:  商业活动的起点, "订单" */
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
) ENGINE=InnoDB COMMENT='订舱单';

/* * 表: Task * 描述:  合并了“计划”与“执行”的作业任务 */
CREATE TABLE `Task` (
    `Task_ID` INT NOT NULL AUTO_INCREMENT COMMENT '任务编号',
    `Task_Type` VARCHAR(30) NOT NULL COMMENT '任务类型',
    `Status` VARCHAR(20) NOT NULL DEFAULT 'Pending' COMMENT '状态 (Pending, Completed, Cancelled)',
    `Container_Master_ID` INT NOT NULL COMMENT '集装箱编号',
    `From_Slot_ID` INT NOT NULL COMMENT '计划起始箱位编号',
    `To_Slot_ID` INT NOT NULL COMMENT '计划目标箱位编号',
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
) ENGINE=InnoDB COMMENT='作业任务 (计划与执行)';
/*
 * =========================================
 * 组 5: 视图
 * =========================================
 */
--堆场实时库存
CREATE OR REPLACE VIEW `View_Yard_Inventory_Live` AS
SELECT 
    -- 1. 位置信息 (物理坐标)
    yb.Block_Name AS 堆场区,
    ys.Bay_Number AS 贝位,
    ys.Row_Number AS 排号,
    slot.Tier_Number AS 层号,
    slot.Slot_Coordinates AS 坐标代码,
    
    -- 2. 集装箱核心信息
    cm.Container_Number AS 箱号,
    cm.Current_Status AS 箱状态,
    
    -- 3. 箱型详情 (关联字典表)
    ct.Type_Code AS ISO代码,
    ct.Nominal_Size AS 尺寸_英尺,
    ct.Group_Code AS 箱型组, -- GP/RF/TK
    
    -- 4. 权属信息
    p.Party_Name AS 箱主,
    p.SCAC_Code AS 箱主代码

FROM `Yard_Slot` slot
-- 仅查询有箱子的位置
JOIN `Container_Master` cm ON slot.Current_Container_ID = cm.Container_Master_ID
JOIN `Container_Type_Dict` ct ON cm.Type_Code = ct.Type_Code
JOIN `Yard_Stack` ys ON slot.Stack_ID = ys.Stack_ID
JOIN `Yard_Block` yb ON ys.Block_ID = yb.Block_ID
LEFT JOIN `Party` p ON cm.Owner_Party_ID = p.Party_ID
WHERE slot.Current_Container_ID IS NOT NULL;

