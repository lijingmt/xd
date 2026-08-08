#!/bin/bash

##############################################################################
# MySQL Docker 网络访问权限设置脚本
# 用途：为 Docker 容器网络配置 MySQL 远程访问权限
# 执行频率：仅需执行一次，或在 MySQL 重新安装时执行
##############################################################################

# 配置
MYSQL_USER="root"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
DOCKER_NETWORK="172.17.0.1"
MYSQL_HOST="localhost"

if [ -z "$MYSQL_PASSWORD" ]; then
    echo "错误：请通过 MYSQL_PASSWORD 环境变量提供数据库密码" >&2
    exit 1
fi

echo "======================================"
echo "MySQL Docker 网络访问权限配置"
echo "======================================"
echo ""

# 检查 MySQL 是否运行
if ! MYSQL_PWD="$MYSQL_PASSWORD" mysqladmin -u "$MYSQL_USER" ping -h "$MYSQL_HOST" &>/dev/null; then
    # 尝试使用 mariadb-admin
    if ! command -v mariadb-admin &>/dev/null || ! MYSQL_PWD="$MYSQL_PASSWORD" mariadb-admin -u "$MYSQL_USER" ping -h "$MYSQL_HOST" &>/dev/null; then
        echo "❌ 错误：无法连接到 MySQL/MariaDB"
        echo "   请确保 MySQL/MariaDB 正在运行且用户名/密码正确"
        echo ""
        echo "检查命令："
        echo "  systemctl status mariadb"
        echo "  systemctl status mysqld"
        exit 1
    fi
fi

echo "✓ 已连接到 MySQL/MariaDB"
echo ""

# 确定使用 mysql 还是 mariadb 命令
if command -v mariadb &>/dev/null; then
    MYSQL_CMD="mariadb"
else
    MYSQL_CMD="mysql"
fi

# 执行授权
echo "正在配置权限..."
MYSQL_PWD="$MYSQL_PASSWORD" $MYSQL_CMD -u "$MYSQL_USER" -h "$MYSQL_HOST" << EOF
-- 为 Docker 容器创建或更新 root 用户
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'$DOCKER_NETWORK' IDENTIFIED BY '$MYSQL_PASSWORD';

-- 授予所有权限
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'$DOCKER_NETWORK' WITH GRANT OPTION;

-- 为所有 Docker 网络创建用户（可选）
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'172.18.%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'172.18.%' WITH GRANT OPTION;

-- 刷新权限
FLUSH PRIVILEGES;

-- 显示授权结果
SELECT 'MySQL 权限配置成功:' as 信息;
SELECT user, host FROM mysql.user WHERE user='$MYSQL_USER';
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "✅ MySQL 权限配置完成"
    echo "======================================"
    echo ""
echo "Docker 容器现在可以使用已配置的凭证连接 MySQL:"
    echo "  • 主机: 172.17.0.1 (Docker 网关)"
    echo "  • 用户: $MYSQL_USER"
    echo ""
    echo "测试连接："
    echo "  docker exec -it xiand-xd01 bash"
    echo "  mysql -h 172.17.0.1 -u $MYSQL_USER -p -e \"SHOW DATABASES;\""
    echo ""
else
    echo ""
    echo "======================================"
    echo "❌ 权限配置失败"
    echo "======================================"
    exit 1
fi
