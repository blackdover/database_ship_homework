/*
 * =========================================
 * 港口集装箱运营系统 (TOS) - 触发器脚本
 * 实现表之间的自动联动和数据一致性保证
 * MySQL 5.7+ / 8.0+
 * =========================================
 */

USE `box_management`;

-- =========================================
-- 触发器1：任务完成时自动更新集装箱状态
-- =========================================
-- 功能：当任务状态更新为"已完成"时，根据任务类型自动更新集装箱的当前状态
-- 联动：Task 表 → Container_Master 表

DELIMITER $$

DROP TRIGGER IF EXISTS `TRG_Task_Complete_Update_Container`$$

CREATE TRIGGER `TRG_Task_Complete_Update_Container`
AFTER UPDATE ON `Task`
FOR EACH ROW
BEGIN
    -- 只有当状态从非"已完成"变为"已完成"时才执行
    IF NEW.Status = 'Completed' AND OLD.Status != 'Completed' THEN
        -- 装船任务：集装箱状态更新为"在船上"
        IF NEW.Task_Type = 'Load' THEN
            UPDATE Container_Master 
            SET Current_Status = 'OnVessel'
            WHERE Container_Master_ID = NEW.Container_Master_ID;
        
        -- 卸船任务：集装箱状态更新为"在堆场"
        ELSEIF NEW.Task_Type = 'Discharge' THEN
            UPDATE Container_Master 
            SET Current_Status = 'InYard'
            WHERE Container_Master_ID = NEW.Container_Master_ID;
        
        -- 出闸任务：集装箱状态更新为"已出闸"
        ELSEIF NEW.Task_Type = 'GateOut' THEN
            UPDATE Container_Master 
            SET Current_Status = 'GateOut'
            WHERE Container_Master_ID = NEW.Container_Master_ID;
        
        -- 进闸任务：集装箱状态更新为"在堆场"
        ELSEIF NEW.Task_Type = 'GateIn' THEN
            UPDATE Container_Master 
            SET Current_Status = 'InYard'
            WHERE Container_Master_ID = NEW.Container_Master_ID;
        END IF;
    END IF;
END$$

DELIMITER ;

-- =========================================
-- 触发器2：任务完成时自动更新箱位状态
-- =========================================
-- 功能：当任务完成时，自动更新起始箱位和目标箱位的状态
-- 联动：Task 表 → Yard_Slot 表

DELIMITER $$

DROP TRIGGER IF EXISTS `TRG_Task_Complete_Update_Slot`$$

CREATE TRIGGER `TRG_Task_Complete_Update_Slot`
AFTER UPDATE ON `Task`
FOR EACH ROW
BEGIN
    -- 只有当状态从非"已完成"变为"已完成"时才执行
    IF NEW.Status = 'Completed' AND OLD.Status != 'Completed' THEN
        -- 清空起始箱位的集装箱，设置为可用状态
        UPDATE Yard_Slot 
        SET Current_Container_ID = NULL,
            Slot_Status = 'Available'
        WHERE Slot_ID = NEW.From_Slot_ID;
        
        -- 更新目标箱位：放置集装箱，设置为占用状态
        UPDATE Yard_Slot 
        SET Current_Container_ID = NEW.Container_Master_ID,
            Slot_Status = 'Occupied'
        WHERE Slot_ID = NEW.To_Slot_ID;
    END IF;
END$$

DELIMITER ;

-- =========================================
-- 触发器3：集装箱插入时自动验证格式
-- =========================================
-- 功能：在插入集装箱记录前，验证箱号格式是否符合ISO标准
-- 联动：Container_Master 表（自验证）

DELIMITER $$

DROP TRIGGER IF EXISTS `TRG_Container_Validate_Format`$$

CREATE TRIGGER `TRG_Container_Validate_Format`
BEFORE INSERT ON `Container_Master`
FOR EACH ROW
BEGIN
    -- 验证集装箱编号格式：4个大写字母 + 7位数字
    IF NEW.Container_Number NOT REGEXP '^[A-Z]{4}[0-9]{7}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '集装箱编号格式错误！必须为4个大写字母+7位数字（如：ABCD1234567）';
    END IF;
END$$

DELIMITER ;

-- =========================================
-- 触发器4：船舶访问完成时自动更新状态
-- =========================================
-- 功能：当船舶访问的离港时间（ATD）被设置时，自动将状态更新为"已完成"
-- 联动：Vessel_Visit 表（自更新）

DELIMITER $$

DROP TRIGGER IF EXISTS `TRG_Vessel_Visit_Auto_Complete`$$

CREATE TRIGGER `TRG_Vessel_Visit_Auto_Complete`
BEFORE UPDATE ON `Vessel_Visit`
FOR EACH ROW
BEGIN
    -- 如果设置了离港时间且之前没有，自动将状态更新为"已完成"
    IF NEW.ATD IS NOT NULL AND OLD.ATD IS NULL THEN
        SET NEW.Status = 'Completed';
    END IF;
END$$

DELIMITER ;

-- =========================================
-- 触发器5：任务创建时自动设置创建时间
-- =========================================
-- 功能：创建任务时，如果没有指定优先级，自动设置为默认值
-- 联动：Task 表（自更新）

DELIMITER $$

DROP TRIGGER IF EXISTS `TRG_Task_Set_Default_Priority`$$

CREATE TRIGGER `TRG_Task_Set_Default_Priority`
BEFORE INSERT ON `Task`
FOR EACH ROW
BEGIN
    -- 如果优先级未设置，设置为默认值100
    IF NEW.Priority IS NULL OR NEW.Priority = 0 THEN
        SET NEW.Priority = 100;
    END IF;
END$$

DELIMITER ;

-- =========================================
-- 触发器6：订舱单确认时自动关联航次
-- =========================================
-- 功能：当订舱单状态更新为"已确认"时，验证是否已关联航次
-- 联动：Booking 表（数据验证）

DELIMITER $$

DROP TRIGGER IF EXISTS `TRG_Booking_Validate_Voyage`$$

CREATE TRIGGER `TRG_Booking_Validate_Voyage`
BEFORE UPDATE ON `Booking`
FOR EACH ROW
BEGIN
    -- 如果状态更新为"已确认"，但未关联航次，则报错
    IF NEW.Status = 'Confirmed' AND NEW.Voyage_ID IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '订舱单确认时必须关联航次！';
    END IF;
END$$

DELIMITER ;

-- =========================================
-- 验证触发器创建成功
-- =========================================
SELECT '所有触发器创建成功！' AS 提示信息;

-- 查看所有触发器
SHOW TRIGGERS;

