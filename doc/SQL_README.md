# SQL 脚本使用说明

## 📁 文件说明

### 1. `init_database.sql` - 完整数据库初始化脚本（推荐）

**功能：**
- ✅ 自动创建数据库 `box_management`
- ✅ 创建所有15+个数据表
- ✅ 创建视图 `View_Yard_Inventory_Live`
- ✅ 包含所有外键约束和索引
- ✅ 使用 UTF8MB4 字符集，支持中文

**使用方法：**
```bash
# 方式1：直接执行（推荐）
mysql -u root -p < init_database.sql

# 方式2：在MySQL命令行中执行
mysql -u root -p
source init_database.sql;
```

**注意事项：**
- ⚠️ 脚本会先删除已存在的 `box_management` 数据库（如果存在）
- ⚠️ 确保有足够的数据库权限
- ✅ 脚本会自动设置字符集为 `utf8mb4`，支持中文存储

### 2. `createtable.sql` - 仅创建表的脚本

**功能：**
- ✅ 仅创建数据表（不创建数据库）
- ✅ 适用于数据库已存在的情况

**使用方法：**
```bash
# 先创建数据库
mysql -u root -p
CREATE DATABASE box_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE box_management;

# 然后执行表创建脚本
SOURCE createtable.sql;
```

或者：
```bash
mysql -u root -p box_management < createtable.sql
```

## 🗄️ 数据库结构

### 表分类

#### 组 1: 基础主数据（无依赖）
- `Party` - 相关方（公司/个人）
- `Port_Master` - 港口信息
- `Yard_Block` - 堆场区
- `Users` - 用户信息
- `Permissions` - 权限定义
- `Container_Type_Dict` - 集装箱类型字典
- `Berth` - 泊位信息

#### 组 2: 依赖组1的主数据
- `Vessel_Master` - 船舶信息
- `Container_Master` - 集装箱信息
- `Yard_Stack` - 堆场堆栈
- `User_Permissions` - 用户权限关联

#### 组 3: 依赖组1和组2的数据
- `Yard_Slot` - 箱位（3D坐标）
- `Vessel_Visit` - 船舶访问记录

#### 组 4: 核心事务表
- `Booking` - 订舱单
- `Task` - 作业任务

### 视图

- `View_Yard_Inventory_Live` - 堆场实时库存视图

## 🔧 SQL 语句说明

### 建库语句
```sql
DROP DATABASE IF EXISTS `box_management`;
CREATE DATABASE `box_management` 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci
    COMMENT '港口集装箱运营系统数据库';
```

### 建表示例
```sql
CREATE TABLE `Party` (
    `Party_ID` INT NOT NULL AUTO_INCREMENT COMMENT '相关方编号',
    `Party_Name` VARCHAR(255) NOT NULL COMMENT '名称',
    -- ... 其他字段
    PRIMARY KEY (`Party_ID`),
    UNIQUE INDEX `UQ_Party_Name` (`Party_Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='相关方';
```

### 外键约束示例
```sql
CONSTRAINT `FK_User_links_to_Party` 
    FOREIGN KEY (`Party_ID`) 
    REFERENCES `Party`(`Party_ID`)
```

## ✅ 验证安装

执行脚本后，可以验证数据库是否创建成功：

```sql
-- 查看数据库
SHOW DATABASES LIKE 'box_management';

-- 使用数据库
USE box_management;

-- 查看所有表
SHOW TABLES;

-- 查看表结构
DESCRIBE Party;

-- 查看视图
SHOW FULL TABLES WHERE Table_type = 'VIEW';
```

## 🐛 常见问题

### Q1: 执行脚本时提示权限不足
**A:** 确保使用的MySQL用户有 `CREATE`、`DROP`、`ALTER` 权限：
```sql
GRANT ALL PRIVILEGES ON *.* TO 'your_user'@'localhost';
FLUSH PRIVILEGES;
```

### Q2: 中文显示乱码
**A:** 确保数据库和表都使用 `utf8mb4` 字符集。`init_database.sql` 已自动设置。

### Q3: 外键约束错误
**A:** 确保按照正确的顺序创建表。`init_database.sql` 已按依赖关系排序。

### Q4: CHECK 约束不生效（MySQL 5.7）
**A:** MySQL 5.7 默认不启用 CHECK 约束。可以升级到 MySQL 8.0，或使用触发器实现约束。

### Q5: 视图创建失败
**A:** 确保所有依赖的表都已创建。视图依赖于多个表的 JOIN。

## 📊 表统计

- **总表数：** 15个
- **视图数：** 1个
- **外键约束：** 20+个
- **唯一索引：** 15+个
- **字符集：** UTF8MB4（支持中文和emoji）

## 🚀 快速开始

最简单的使用方式：

```bash
# 1. 执行完整初始化脚本
mysql -u root -p < init_database.sql

# 2. 验证
mysql -u root -p -e "USE box_management; SHOW TABLES;"
```

完成！数据库已创建，可以开始使用Django应用了。

