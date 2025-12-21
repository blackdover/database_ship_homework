/*
 * 初始化示例数据 - 港口集装箱运营系统 (TOS)
 * 说明：按 init_database.sql 中的表结构顺序插入示例数据（尽可能真实）。
 * 在实际环境运行前请备份数据库，脚本假设当前数据库为 `box_management`。
 */

USE `box_management`;

START TRANSACTION;

-- ===== 插入相关方（Party） =====
INSERT INTO `Party` (`Party_ID`,`Party_Name`,`Party_Type`,`Address_Line_1`,`City`,`Country`,`Contact_Person`,`Email`,`Phone`,`SCAC_Code`) VALUES
 (1, '中远海运集运有限公司', 'COMPANY', '上海市浦东新区海运路12号', '上海', 'CN', '张伟', 'sales@cosco.cn', '+86-21-88880001', 'COSC'),
 (2, '深圳港务集团', 'COMPANY', '深圳市盐田港大道3号', '深圳', 'CN', '李娜', 'ops@szhg.cn', '+86-755-66660002', 'SZPG'),
 (3, '万海航运', 'COMPANY', '台湾高雄市港口路8号', 'Kaohsiung', 'TW', '王强', 'info@wanhai.tw', '+886-7-1234567', 'WANH'),
 (4, '李四（个人）', 'PERSON', '广州市天河区林和路5号', '广州', 'CN', '李四', 'lisi@example.com', '+86-20-11112222', NULL),
 (5, '马士基物流', 'COMPANY', '丹麦哥本哈根港口区', 'Copenhagen', 'DK', 'Anders Hansen', 'no-reply@maersk.com', '+45-33-444400', 'MAEU'),
 (6, '示例承运人 A', 'COMPANY', '香港九龙码头1号', 'Hong Kong', 'HK', 'Chan Tai', 'carrierA@hk.com', '+852-23456789', 'HKCA');
ON DUPLICATE KEY UPDATE `Party_Name` = `Party_Name`;

-- ===== 插入港口（Port_Master） =====
INSERT INTO `Port_Master` (`Port_ID`,`Port_Name`,`Port_Code`,`Country`) VALUES
 (1, '上海洋山港', 'CNSHA', 'CN'),
 (2, '深圳盐田港', 'CNSZX', 'CN'),
 (3, '宁波舟山港', 'CNNGB', 'CN'),
 (4, '新加坡港', 'SGSIN', 'SG');
ON DUPLICATE KEY UPDATE `Port_Code` = `Port_Code`;

-- ===== 插入堆场区（Yard_Block） =====
INSERT INTO `Yard_Block` (`Block_ID`,`Block_Name`,`Block_Type`) VALUES
 (1, '北堆场A区', 'Standard'),
 (2, '南堆场冷藏区', 'Reefer'),
 (3, '西堆场临时区', 'Temporary');
ON DUPLICATE KEY UPDATE `Block_Name` = `Block_Name`;

-- ===== 插入集装箱类型字典（Container_Type_Dict） =====
INSERT INTO `Container_Type_Dict` (`Type_Code`,`Nominal_Size`,`Group_Code`,`Standard_Tare_KG`) VALUES
 ('22G1', 20, 'GP', 2200.00),
 ('45G1', 40, 'GP', 4200.00),
 ('45R1', 40, 'RF', 4800.00);
ON DUPLICATE KEY UPDATE `Type_Code` = `Type_Code`;

-- ===== 插入用户（Users） =====
-- Hashed_Password 这里使用占位二进制（实际使用 Django 认证，不直接使用该字段）
INSERT INTO `Users` (`User_ID`,`Username`,`Hashed_Password`,`Full_Name`,`Email`,`Party_ID`,`Is_Active`) VALUES
 (1, 'admin', 0x01, '系统管理员', 'admin@example.com', NULL, 1),
 (2, 'ops_user', 0x01, '操作员 张三', 'zhangsan@example.com', 2, 1),
 (3, 'viewer', 0x01, '只读用户', 'viewer@example.com', NULL, 1),
 (4, 'li_si', 0x01, '李四', 'lisi@example.com', 4, 1);
ON DUPLICATE KEY UPDATE `Username` = `Username`;

-- ===== 插入权限（Permissions） & 用户权限映射（User_Permissions） =====
INSERT INTO `Permissions` (`Permission_ID`,`Permission_Name`,`Description`) VALUES
 (1, 'VIEW_INVENTORY', 'View Yard Inventory'),
 (2, 'VIEW_VESSEL', 'View Vessel Visit Information'),
 (3, 'VIEW_TASK', 'View Task Information'),
 (4, 'VIEW_STATISTICS', 'View Statistics Reports'),
 (5, 'CREATE_TASK', 'Create Task'),
 (6, 'ADMIN', 'Administrator');
ON DUPLICATE KEY UPDATE `Permission_Name` = `Permission_Name`;

INSERT INTO `User_Permissions` (`User_ID`,`Permission_ID`) VALUES
 (1, 6), -- admin
 (1, 1),
 (1, 2),
 (1, 3),
 (1, 4),
 (2, 1),
 (2, 3),
 (3, 1);
ON DUPLICATE KEY UPDATE `User_ID` = `User_ID`;

-- ===== 插入船舶主数据（Vessel_Master） =====
INSERT INTO `Vessel_Master` (`Vessel_ID`,`Vessel_Name`,`IMO_Number`,`Flag_Country`,`Carrier_Party_ID`) VALUES
 (1, 'COSCO SHIPPING VENUS', '9812345', 'CN', 1),
 (2, 'WAN HAI 107', '9787654', 'TW', 3),
 (3, 'MAERSK HAMBURG', '9604321', 'DK', 5);
ON DUPLICATE KEY UPDATE `IMO_Number` = `IMO_Number`;

-- ===== 插入堆栈（Yard_Stack） =====
INSERT INTO `Yard_Stack` (`Stack_ID`,`Block_ID`,`Bay_Number`,`Row_Number`) VALUES
 (1, 1, 1, 1),
 (2, 1, 1, 2),
 (3, 2, 2, 1),
 (4, 3, 3, 1);
ON DUPLICATE KEY UPDATE `Stack_ID` = `Stack_ID`;

-- ===== 插入箱位（Yard_Slot） =====
INSERT INTO `Yard_Slot` (`Slot_ID`,`Stack_ID`,`Tier_Number`,`Slot_Coordinates`,`Slot_Status`,`Current_Container_ID`) VALUES
 (1, 1, 1, 'A1-1-1', 'Occupied', NULL),
 (2, 1, 2, 'A1-1-2', 'Available', NULL),
 (3, 2, 1, 'A1-2-1', 'Occupied', NULL),
 (4, 2, 2, 'A1-2-2', 'Available', NULL),
 (5, 3, 1, 'R2-2-1', 'Available', NULL),
 (6, 4, 1, 'T3-3-1', 'Available', NULL);
ON DUPLICATE KEY UPDATE `Slot_Coordinates` = `Slot_Coordinates`;

-- ===== 插入集装箱（Container_Master） =====
INSERT INTO `Container_Master` (`Container_Master_ID`,`Container_Number`,`Owner_Party_ID`,`Type_Code`,`Current_Status`) VALUES
 (1, 'MSCU1234567', 1, '22G1', 'InYard'),
 (2, 'COSU7654321', 2, '45G1', 'OnVessel'),
 (3, 'WANH0000001', 3, '45R1', 'InYard'),
 (4, 'MAEU1112223', 5, '45G1', 'GateOut'),
 (5, 'TEST0000001', 4, '22G1', 'InYard');
ON DUPLICATE KEY UPDATE `Container_Number` = `Container_Number`;

-- 把一些容器放到箱位上（更新 Current_Container_ID）
UPDATE `Yard_Slot` SET `Current_Container_ID` = 1, `Slot_Status`='Occupied' WHERE `Slot_ID` = 1;
UPDATE `Yard_Slot` SET `Current_Container_ID` = 3, `Slot_Status`='Occupied' WHERE `Slot_ID` = 3;

-- ===== 插入船舶访问（Vessel_Visit） =====
INSERT INTO `Vessel_Visit` (`Vessel_Visit_ID`,`Vessel_ID`,`Port_ID`,`Berth_ID`,`Voyage_Number_In`,`Voyage_Number_Out`,`ATA`,`ATD`,`Status`) VALUES
 (1, 1, 1, NULL, 'VN001', 'VN002', '2025-12-10 02:00:00', NULL, 'Approaching'),
 (2, 2, 2, NULL, 'WH107A', NULL, '2025-11-25 08:30:00', '2025-11-26 17:00:00', 'Completed'),
 (3, 3, 4, NULL, 'MAH01', 'MAH02', '2025-12-01 12:00:00', NULL, 'AtBerth');
ON DUPLICATE KEY UPDATE `Vessel_Visit_ID` = `Vessel_Visit_ID`;

-- ===== 插入订舱单（Booking） =====
INSERT INTO `Booking` (`Booking_ID`,`Booking_Number`,`Status`,`Shipper_Party_ID`,`Consignee_Party_ID`,`Payer_Party_ID`,`Voyage_ID`) VALUES
 (1, 'BKG202512001', 'Confirmed', 1, 2, 1, 1),
 (2, 'BKG202511015', 'Draft', 3, 5, 3, NULL);
ON DUPLICATE KEY UPDATE `Booking_Number` = `Booking_Number`;

-- ===== 插入任务（Task） =====
INSERT INTO `Task` (`Task_ID`,`Task_Type`,`Status`,`Container_Master_ID`,`From_Slot_ID`,`To_Slot_ID`,`Vessel_Visit_ID`,`Created_By_User_ID`,`Assigned_User_ID`,`Actual_Executor_ID`,`Priority`,`Movement_Timestamp`) VALUES
 (1, 'Load', 'Pending', 1, 1, 2, 1, 2, 2, NULL, 100, NULL),
 (2, 'Discharge', 'Completed', 2, NULL, 3, 2, 2, 2, 2, 90, '2025-11-26 17:00:00'),
 (3, 'Move', 'Pending', 3, 3, 5, NULL, 2, NULL, NULL, 120, NULL);
ON DUPLICATE KEY UPDATE `Task_ID` = `Task_ID`;

-- ===== 追加示例数据（扩充，保持引用完整） =====
-- 追加相关方（Party）7-12
INSERT INTO `Party` (`Party_ID`,`Party_Name`,`Party_Type`,`Address_Line_1`,`City`,`Country`,`Contact_Person`,`Email`,`Phone`,`SCAC_Code`) VALUES
 (7, '青岛港集团', 'COMPANY', '青岛市港城路2号', '青岛', 'CN', '赵鹏', 'qdport@example.cn', '+86-532-7777007', 'QDG'),
 (8, '天津港股份', 'COMPANY', '天津市港口大道5号', '天津', 'CN', '王芳', 'tjport@example.cn', '+86-22-5555005', 'TJP'),
 (9, '广州港集团', 'COMPANY', '广州市南沙港区', '广州', 'CN', '陈雷', 'gzport@example.cn', '+86-20-66668888', 'GZP'),
 (10, '香港港务集团', 'COMPANY', '香港中环港口大道', 'Hong Kong', 'HK', 'Lee Ming', 'hkport@example.hk', '+852-99998888', 'HKP'),
 (11, '达飞轮船', 'COMPANY', '法国马赛港区', 'Marseille', 'FR', 'Pierre Martin', 'cds@cma-cgm.com', '+33-4-91919191', 'CMDU'),
 (12, '示例承运人 B', 'COMPANY', '上海外高桥港区', '上海', 'CN', '周洁', 'carrierB@sh.com', '+86-21-33334444', 'SHCB');
ON DUPLICATE KEY UPDATE `Party_Name` = `Party_Name`;

-- 追加港口（Port_Master）5-8
INSERT INTO `Port_Master` (`Port_ID`,`Port_Name`,`Port_Code`,`Country`) VALUES
 (5, '广州港', 'CNGUA', 'CN'),
 (6, '天津港', 'CNTJN', 'CN'),
 (7, '青岛港', 'CNQDG', 'CN'),
 (8, '香港港', 'HKHKG', 'HK');
ON DUPLICATE KEY UPDATE `Port_Code` = `Port_Code`;

-- 追加堆场区（Yard_Block）4-6
INSERT INTO `Yard_Block` (`Block_ID`,`Block_Name`,`Block_Type`) VALUES
 (4, '东堆场重载区', 'Heavy'),
 (5, '中转堆场B区', 'Standard'),
 (6, '南部散货区', 'Bulk');
ON DUPLICATE KEY UPDATE `Block_Name` = `Block_Name`;

-- 追加箱型字典（Container_Type_Dict）4-6
INSERT INTO `Container_Type_Dict` (`Type_Code`,`Nominal_Size`,`Group_Code`,`Standard_Tare_KG`) VALUES
 ('20R1', 20, 'RF', 2300.00),
 ('40HC', 40, 'HC', 4100.00),
 ('20OT', 20, 'OT', 2500.00);
ON DUPLICATE KEY UPDATE `Type_Code` = `Type_Code`;

-- 追加用户（Users）5-8
INSERT INTO `Users` (`User_ID`,`Username`,`Hashed_Password`,`Full_Name`,`Email`,`Party_ID`,`Is_Active`) VALUES
 (5, 'qa_user', 0x01, '质检 王五', 'wangwu@example.com', 7, 1),
 (6, 'scheduler', 0x01, '排班 小王', 'schedule@example.com', 2, 1),
 (7, 'ops_b', 0x01, '操作员 B', 'opsb@example.com', 9, 1),
 (8, 'auditor', 0x01, '审计员', 'audit@example.com', NULL, 1);
ON DUPLICATE KEY UPDATE `Username` = `Username`;

-- 追加用户权限映射
INSERT INTO `User_Permissions` (`User_ID`,`Permission_ID`) VALUES
 (5, 1),
 (6, 3),
 (7, 1),
 (8, 4);
ON DUPLICATE KEY UPDATE `User_ID` = `User_ID`;

-- 追加船舶（Vessel_Master）4-6
INSERT INTO `Vessel_Master` (`Vessel_ID`,`Vessel_Name`,`IMO_Number`,`Flag_Country`,`Carrier_Party_ID`) VALUES
 (4, 'CMA CGM JUPITER', '9712345', 'FR', 11),
 (5, 'EVERGREEN AURORA', '9654321', 'TW', 3),
 (6, 'HAPAG-LLOYD OSAKA', '9623344', 'DE', 12);
ON DUPLICATE KEY UPDATE `IMO_Number` = `IMO_Number`;

-- 追加堆栈（Yard_Stack）5-8
INSERT INTO `Yard_Stack` (`Stack_ID`,`Block_ID`,`Bay_Number`,`Row_Number`) VALUES
 (5, 4, 1, 1),
 (6, 5, 2, 2),
 (7, 2, 3, 1),
 (8, 6, 1, 1);
ON DUPLICATE KEY UPDATE `Stack_ID` = `Stack_ID`;

-- 追加箱位（Yard_Slot）7-12
INSERT INTO `Yard_Slot` (`Slot_ID`,`Stack_ID`,`Tier_Number`,`Slot_Coordinates`,`Slot_Status`,`Current_Container_ID`) VALUES
 (7, 5, 1, 'E4-1-1', 'Available', NULL),
 (8, 5, 2, 'E4-1-2', 'Available', NULL),
 (9, 6, 1, 'B5-2-1', 'Available', NULL),
 (10, 7, 1, 'C2-3-1', 'Available', NULL),
 (11, 8, 1, 'D6-1-1', 'Available', NULL),
 (12, 3, 2, 'R2-2-2', 'Available', NULL);
ON DUPLICATE KEY UPDATE `Slot_Coordinates` = `Slot_Coordinates`;

-- 追加集装箱（Container_Master）6-10
INSERT INTO `Container_Master` (`Container_Master_ID`,`Container_Number`,`Owner_Party_ID`,`Type_Code`,`Current_Status`) VALUES
 (6, 'QDGX2223334', 7, '20R1', 'InYard'),
 (7, 'TJN000777888', 8, '40HC', 'InYard'),
 (8, 'GZP555666777', 9, '45G1', 'OnVessel'),
 (9, 'HKP999000111', 10, '20OT', 'InYard'),
 (10,'CMDU444555666',11, '45G1', 'InYard');
ON DUPLICATE KEY UPDATE `Container_Number` = `Container_Number`;

-- 把新增容器放到箱位上
UPDATE `Yard_Slot` SET `Current_Container_ID` = 6, `Slot_Status`='Occupied' WHERE `Slot_ID` = 7;
UPDATE `Yard_Slot` SET `Current_Container_ID` = 9, `Slot_Status`='Occupied' WHERE `Slot_ID` = 11;

-- 追加船舶访问（Vessel_Visit）4-6
INSERT INTO `Vessel_Visit` (`Vessel_Visit_ID`,`Vessel_ID`,`Port_ID`,`Berth_ID`,`Voyage_Number_In`,`Voyage_Number_Out`,`ATA`,`ATD`,`Status`) VALUES
 (4, 4, 4, NULL, 'CGM100', 'CGM101', '2025-10-12 06:00:00', '2025-10-13 18:00:00', 'Completed'),
 (5, 5, 5, NULL, 'EGR200', 'EGR201', '2025-12-05 10:00:00', NULL, 'AtBerth'),
 (6, 6, 8, NULL, 'HLO300', 'HLO301', '2025-11-20 09:00:00', '2025-11-21 20:00:00', 'Completed');
ON DUPLICATE KEY UPDATE `Vessel_Visit_ID` = `Vessel_Visit_ID`;

-- 追加订舱单（Booking）3-4
INSERT INTO `Booking` (`Booking_ID`,`Booking_Number`,`Status`,`Shipper_Party_ID`,`Consignee_Party_ID`,`Payer_Party_ID`,`Voyage_ID`) VALUES
 (3, 'BKG202510500', 'Confirmed', 7, 9, 7, 5),
 (4, 'BKG202509888', 'Confirmed', 11, 2, 11, 4);
ON DUPLICATE KEY UPDATE `Booking_Number` = `Booking_Number`;

-- 追加任务（Task）4-6
INSERT INTO `Task` (`Task_ID`,`Task_Type`,`Status`,`Container_Master_ID`,`From_Slot_ID`,`To_Slot_ID`,`Vessel_Visit_ID`,`Created_By_User_ID`,`Assigned_User_ID`,`Actual_Executor_ID`,`Priority`,`Movement_Timestamp`) VALUES
 (4, 'GateOut', 'Pending', 5, 5, NULL, NULL, 6, 6, NULL, 80, NULL),
 (5, 'Load', 'Completed', 8, NULL, NULL, 5, 2, 7, 7, 110, '2025-12-05 15:30:00'),
 (6, 'Move', 'Pending', 10, 9, 11, NULL, 6, 6, NULL, 95, NULL);
ON DUPLICATE KEY UPDATE `Task_ID` = `Task_ID`;

COMMIT;

/* End of sample data */


