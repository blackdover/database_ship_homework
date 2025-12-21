# PowerShell脚本：执行权限初始化
# 使用方法：在PowerShell中运行此脚本

Write-Host "正在初始化权限系统..." -ForegroundColor Green

# 读取MySQL密码（安全方式）
$password = Read-Host "请输入MySQL root密码" -AsSecureString
$passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
)

# 执行SQL文件
$sqlFile = Join-Path $PSScriptRoot "init_permissions.sql"
$sqlContent = Get-Content $sqlFile -Raw -Encoding UTF8

# 使用mysql命令执行
$command = "mysql -u root -p$passwordPlain box_management"
$sqlContent | & $command

if ($LASTEXITCODE -eq 0) {
    Write-Host "权限初始化成功！" -ForegroundColor Green
} else {
    Write-Host "权限初始化失败，请检查错误信息" -ForegroundColor Red
}

# 清理密码变量
$passwordPlain = $null
$password = $null

