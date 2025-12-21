/*
 * =========================================
 * TOS - Permission Initialization Script
 * Create system permissions and default roles
 * MySQL 5.7+ / 8.0+
 * UTF-8 Encoding
 * =========================================
 */

USE `box_management`;

-- Set character set to UTF-8
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- =========================================
-- Insert System Permissions
-- =========================================

-- Delete existing permissions if exist
DELETE FROM `User_Permissions` WHERE Permission_ID IN (
    SELECT Permission_ID FROM (SELECT Permission_ID FROM Permissions) AS temp
);
DELETE FROM `Permissions`;

-- Insert permission definitions
INSERT INTO `Permissions` (`Permission_Name`, `Description`) VALUES
('VIEW_INVENTORY', 'View Yard Inventory'),
('VIEW_VESSEL', 'View Vessel Visit Information'),
('VIEW_TASK', 'View Task Information'),
('VIEW_STATISTICS', 'View Statistics Reports'),
('CREATE_TASK', 'Create Tasks'),
('UPDATE_TASK', 'Update Task Status'),
('DELETE_TASK', 'Delete Tasks'),
('MANAGE_BOOKING', 'Manage Bookings'),
('MANAGE_CONTAINER', 'Manage Containers'),
('MANAGE_VESSEL', 'Manage Vessel Information'),
('MANAGE_YARD', 'Manage Yard Information'),
('MANAGE_USER', 'Manage Users'),
('MANAGE_PERMISSION', 'Manage Permissions'),
('ADMIN', 'System Administrator - All Permissions');

-- =========================================
-- Create Default Roles (Optional)
-- =========================================

-- Note: Users are not created automatically, need to assign permissions manually
-- Example: Assign permissions to a user
-- INSERT INTO User_Permissions (User_ID, Permission_ID) 
-- SELECT 1, Permission_ID FROM Permissions WHERE Permission_Name IN ('VIEW_INVENTORY', 'VIEW_STATISTICS');

-- =========================================
-- Permission Role Examples
-- =========================================

-- Admin Role: Has all permissions
-- INSERT INTO User_Permissions (User_ID, Permission_ID)
-- SELECT 1, Permission_ID FROM Permissions;

-- Operator Role: Can view and create tasks
-- INSERT INTO User_Permissions (User_ID, Permission_ID)
-- SELECT 2, Permission_ID FROM Permissions 
-- WHERE Permission_Name IN ('VIEW_INVENTORY', 'VIEW_VESSEL', 'VIEW_TASK', 'CREATE_TASK', 'UPDATE_TASK');

-- Viewer Role: Can only view information
-- INSERT INTO User_Permissions (User_ID, Permission_ID)
-- SELECT 3, Permission_ID FROM Permissions 
-- WHERE Permission_Name IN ('VIEW_INVENTORY', 'VIEW_VESSEL', 'VIEW_TASK', 'VIEW_STATISTICS');

-- =========================================
-- Completion Message
-- =========================================
SELECT 'Permission initialization completed!' AS Message;
SELECT COUNT(*) AS Total_Permissions FROM Permissions;

