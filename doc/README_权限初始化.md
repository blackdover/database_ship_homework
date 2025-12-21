# 权限初始化执行指南

## ⚠️ PowerShell 执行 SQL 文件的方法

在 Windows PowerShell 中，`<` 重定向操作符不被支持。请使用以下方法之一：

---

## 方法一：使用批处理文件（推荐）

1. **双击运行** `执行权限初始化.bat`
2. 输入 MySQL root 密码
3. 等待执行完成

**注意**：已修复编码问题，现在使用 `init_permissions_utf8.sql` 文件

---

## 方法二：PowerShell 命令

### 方式 A：使用 Get-Content 管道

```powershell
# 在项目根目录执行
Get-Content init_permissions.sql | mysql -u root -p box_management
```

### 方式 B：使用 cmd.exe 执行

```powershell
# 在项目根目录执行
cmd /c "mysql -u root -p box_management < init_permissions.sql"
```

### 方式 C：直接指定文件内容

```powershell
# 在项目根目录执行
$sql = Get-Content init_permissions.sql -Raw
$sql | mysql -u root -p box_management
```

---

## 方法三：在 MySQL 命令行中执行

```powershell
# 1. 登录MySQL
mysql -u root -p

# 2. 选择数据库
USE box_management;

# 3. 执行SQL文件
SOURCE E:/code/homework/database_simple/init_permissions.sql;

# 或者使用绝对路径
SOURCE init_permissions.sql;
```

---

## 方法四：使用 PowerShell 脚本

```powershell
# 运行提供的PowerShell脚本
.\执行权限初始化.ps1
```

---

## 方法五：在 MySQL Workbench 或其他工具中执行

1. 打开 MySQL Workbench 或其他 MySQL 客户端
2. 连接到数据库 `box_management`
3. 打开 `init_permissions.sql` 文件
4. 执行整个脚本

---

## 验证权限是否初始化成功

执行以下 SQL 查询验证：

```sql
USE box_management;

-- 查看所有权限
SELECT * FROM Permissions;

-- 应该看到14条权限记录
SELECT COUNT(*) AS 权限总数 FROM Permissions;
```

---

## 常见问题

### Q: PowerShell 提示"< 运算符是为将来使用而保留的"

**A:** 这是正常的，PowerShell 不支持 `<` 重定向。请使用上述方法之一。

### Q: 提示找不到 mysql 命令

**A:** 需要将 MySQL 的 bin 目录添加到系统 PATH 环境变量中，或者使用完整路径：

```powershell
# 使用完整路径（根据你的MySQL安装路径调整）
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p box_management < init_permissions.sql
```

### Q: 提示"Access denied"

**A:** 检查：

1. MySQL root 密码是否正确
2. MySQL 服务是否正在运行
3. 用户是否有执行权限

---

## 快速命令（复制粘贴）

### PowerShell（推荐）

```powershell
Get-Content init_permissions.sql | mysql -u root -p box_management
```

### CMD

```cmd
mysql -u root -p box_management < init_permissions.sql
```

---

**注意**：执行前请确保：

- ✅ MySQL 服务正在运行
- ✅ 数据库 `box_management` 已创建
- ✅ 有 root 用户权限
