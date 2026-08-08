# MySQL 配置说明文档

本文档详细说明如何在 xiand Docker 容器中配置 MySQL 连接。

## 目录

1. [背景说明](#背景说明)
2. [架构原理](#架构原理)
3. [首次配置](#首次配置)
4. [Socat 转发](#socat-转发)
5. [连接测试](#连接测试)
6. [故障排查](#故障排查)
7. [生产环境配置](#生产环境配置)

---

## 背景说明

### 为什么需要特殊配置？

xiand MUD 使用 Pike 语言开发，Pike 的 MySQL 模块默认使用 **Unix socket** 方式连接本地 MySQL：

```pike
// Pike 默认使用 Unix socket
object db = Sql.sql("mysql://root:password@database_name");
```

但在 Docker 环境中：
- **MUD 程序运行在容器内**
- **MySQL 运行在宿主机上**

容器内没有 MySQL 服务，因此 Unix socket 文件不存在，导致连接失败。

### 解决方案：Socat 转发

使用 `socat` 工具将容器内的 Unix socket 请求转发到宿主机的 TCP 端口：

```
容器内 Pike               Socat                    宿主机
    ↓                      ↓                        ↓
Unix socket           转发请求                  TCP 3306
/tmp/.mysql_sock  →  172.17.0.1:3306    →   MySQL Server
```

---

## 架构原理

### 网络架构

```
┌─────────────────────────────────────────────────────────────┐
│                        宿主机 (203)                         │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Docker 容器 (xiand-xd01)                           │   │
│  │                                                      │   │
│  │  ┌──────────────┐      ┌──────────────┐            │   │
│  │  │ Pike MUD     │─────│  Socat       │            │   │
│  │  │              │      │  (转发器)    │            │   │
│  │  └──────────────┘      └──────────────┘            │   │
│  │         │                       │                   │   │
│  │         │ Unix socket          │ TCP               │   │
│  │         ↓                       ↓                   │   │
│  │    /tmp/.mysql_sock      172.17.0.1:3306 ──────┐   │   │
│  │                                            │   │   │
│  └────────────────────────────────────────────┼───┘   │
│                                                 │       │
│  ┌────────────────────────────────────────────┼───────┘│
│  │  MySQL/MariaDB (宿主机)                     │        │
│  │                                             │        │
│  │  监听: 127.0.0.1:3306                       │        │
│  │        172.17.0.1:3306 (Docker 网关)         │        │
│  │                                             │        │
│  └─────────────────────────────────────────────┘        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 数据流向

1. **Pike 程序** 发起 MySQL 连接请求
2. **Socat** 监听 `/tmp/.mysql_sock`，接收请求
3. **Socat** 将请求转发到 `172.17.0.1:3306`
4. **MySQL** 接收请求并返回数据
5. **Socat** 将返回数据转发回 Pike 程序

---

## 首次配置

### 步骤 1：配置 MySQL 远程访问权限

在宿主机上执行设置脚本：

```bash
cd /usr/local/games/xiand
./scripts/setup-mysql-docker-access.sh
```

脚本会自动：
1. 检查 MySQL 是否运行
2. 创建 Docker 网络用户
3. 授予访问权限

**输出示例：**

```
======================================
MySQL Docker 网络访问权限配置
======================================

✓ 已连接到 MySQL/MariaDB

正在配置权限...
======================================
✅ MySQL 权限配置完成
======================================

Docker 容器现在可以使用以下凭证连接 MySQL:
  • 主机: 172.17.0.1 (Docker 网关)
  • 用户: root
  • 密码: 通过 `MYSQL_PASSWORD` 环境变量提供
```

### 步骤 2：手动配置（可选）

如果脚本无法运行，可以手动配置：

```bash
# 登录 MySQL
mysql -u root -p
```

```sql
-- 为 Docker 网关创建用户
CREATE USER IF NOT EXISTS 'root'@'172.17.0.1' IDENTIFIED BY '<set-a-strong-secret>';

-- 授予所有权限
GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.17.0.1' WITH GRANT OPTION;

-- 为 Docker 桥接网络创建用户
CREATE USER IF NOT EXISTS 'root'@'172.18.%' IDENTIFIED BY '<set-a-strong-secret>';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.18.%' WITH GRANT OPTION;

-- 刷新权限
FLUSH PRIVILEGES;

-- 验证
SELECT user, host FROM mysql.user WHERE user='root';
```

### 步骤 3：验证配置

```bash
# 测试 MySQL 连接
mysql -h 172.17.0.1 -u root -p -e "SHOW DATABASES;"
```

---

## Socat 转发

### 自动启动

Socat 转发由容器启动脚本自动启动，无需手动配置。

启动流程（在 `docker/Dockerfile.all` 中）：

```bash
# 1. 删除旧的 socket 文件
rm -f /tmp/.mysql_sock /var/lib/mysql/mysql.sock /run/mysqld/mysqld.sock

# 2. 创建 socket 目录
mkdir -p /run/mysqld

# 3. 启动 socat 转发
socat UNIX-LISTEN:/tmp/.mysql_sock,fork,reuseaddr,mode=666 \
      TCP:172.17.0.1:3306 > /tmp/socat.log 2>&1 &

# 4. 创建符号链接
ln -sf /tmp/.mysql_sock /var/lib/mysql/mysql.sock
ln -sf /tmp/.mysql_sock /run/mysqld/mysqld.sock
```

### 手动测试

进入容器手动启动 socat：

```bash
# 进入容器
docker exec -it xiand-xd01 bash

# 运行 socat 启动脚本
/app/xiand/start_mysql_socat.sh

# 或手动启动
rm -f /tmp/.mysql_sock
socat UNIX-LISTEN:/tmp/.mysql_sock,fork,reuseaddr,mode=666 \
      TCP:172.17.0.1:3306 &
```

### 验证 Socat

```bash
# 检查 socat 进程
ps aux | grep socat

# 检查 socket 文件
ls -la /tmp/.mysql_sock

# 检查符号链接
ls -la /var/lib/mysql/mysql.sock
ls -la /run/mysqld/mysqld.sock
```

---

## 连接测试

### 测试 1：Socat 转发测试

```bash
# 进入容器
docker exec -it xiand-xd01 bash

# 通过 socket 连接 MySQL
mysql -S /tmp/.mysql_sock -u root -p -e "SHOW DATABASES;"
```

**成功输出：**

```
+--------------------+
| Database           |
+--------------------+
| information_schema |
| xd01               |
| mysql              |
+--------------------+
```

### 测试 2：TCP 直接连接测试

```bash
# 进入容器
docker exec -it xiand-xd01 bash

# 通过 TCP 连接 MySQL
mysql -h 172.17.0.1 -u root -p -e "SHOW DATABASES;"
```

### 测试 3：Pike 程序测试

```bash
# 进入容器
docker exec -it xiand-xd01 bash

# 使用 Pike 测试 MySQL 连接
pike -e "
object db = Sql.sql('mysql://root:<password-from-environment>@xd01');
write('MySQL 连接成功！\\n');
array tables = db->list_tables('xd01');
write('数据库表数量: ' + sizeof(tables) + '\\n');
"
```

### 测试 4：完整 MUD 测试

```bash
# 检查 MUD 日志
docker logs -f xiand-xd01

# 查看 MUD 进程
docker exec xiand-xd01 ps aux | grep pike

# 连接 MUD 测试
telnet 127.0.0.1 13800
```

---

## 故障排查

### 问题 1：socat 未安装

**症状：**

```
socat: command not found
```

**解决方案：**

```bash
# 进入容器
docker exec -it xiand-xd01 bash

# 安装 socat
dnf install -y socat

# 或重新构建镜像（在 Dockerfile 中添加）
# RUN dnf install -y socat
```

### 问题 2：MySQL 连接被拒绝

**症状：**

```
ERROR 1130 (HY000): Host '172.17.0.1' is not allowed to connect
```

**解决方案：**

```bash
# 在宿主机上重新配置权限
cd /usr/local/games/xiand
./scripts/setup-mysql-docker-access.sh
```

### 问题 3：Socket 文件不存在

**症状：**

```
Can't connect to local MySQL server through socket '/tmp/.mysql_sock'
```

**排查步骤：**

```bash
# 1. 检查 socat 进程
docker exec xiand-xd01 ps aux | grep socat

# 2. 检查 socket 文件
docker exec xiand-xd01 ls -la /tmp/.mysql_sock

# 3. 检查 socat 日志
docker exec xiand-xd01 cat /tmp/socat.log

# 4. 重启 socat
docker exec xiand-xd01 bash -c "
    pkill socat
    rm -f /tmp/.mysql_sock
    socat UNIX-LISTEN:/tmp/.mysql_sock,fork,reuseaddr,mode=666 TCP:172.17.0.1:3306 &
"
```

### 问题 4：权限被拒绝

**症状：**

```
Permission denied /tmp/.mysql_sock
```

**解决方案：**

```bash
# 修改 socket 权限
docker exec xiand-xd01 chmod 666 /tmp/.mysql_sock

# 或重新启动 socat 并指定 mode
docker exec xiand-xd01 bash -c "
    pkill socat
    socat UNIX-LISTEN:/tmp/.mysql_sock,fork,reuseaddr,mode=666 TCP:172.17.0.1:3306 &
"
```

### 问题 5：MySQL 监听地址问题

**症状：**

从容器无法连接到宿主机 MySQL

**解决方案：**

```bash
# 检查 MySQL 监听地址
sudo netstat -tlnp | grep 3306

# 如果只监听 127.0.0.1，需要修改配置
sudo vi /etc/my.cnf.d/mariadb-server.cnf

# 修改或添加：
[mysqld]
bind-address = 0.0.0.0

# 重启 MySQL
sudo systemctl restart mariadb
```

---

## 生产环境配置

### 安全建议

1. **使用专用 MySQL 用户**

```sql
-- 创建专用用户
CREATE USER 'xiand'@'172.17.0.1' IDENTIFIED BY 'strong_password';

-- 只授予必要权限
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP
ON xiand.* TO 'xiand'@'172.17.0.1';

FLUSH PRIVILEGES;
```

2. **限制访问 IP**

```sql
-- 只允许特定容器访问
CREATE USER 'xiand'@'172.17.0.2' IDENTIFIED BY 'strong_password';
GRANT ALL PRIVILEGES ON xiand.* TO 'xiand'@'172.17.0.2';
```

3. **使用 SSL 连接**

```bash
# 在容器内配置 SSL
mysql -h 172.17.0.1 -u xiand -p --ssl-ca=/path/to/ca.pem
```

### 性能优化

1. **调整 MySQL 参数**

```ini
[mysqld]
max_connections = 500
innodb_buffer_pool_size = 2G
query_cache_size = 128M
```

2. **使用连接池**

Pike 程序中使用连接池复用连接。

3. **监控 Socat 性能**

```bash
# 查看 socat 转发统计
docker exec xiand-xd01 bash -c "
    ss -a | grep mysql_sock
    lsof | grep mysql_sock
"
```

---

## 快速参考

### 常用命令

```bash
# 配置 MySQL 权限
./scripts/setup-mysql-docker-access.sh

# 启动容器
./restart-docker.sh xd01 9001 8888

# 查看 socat 状态
docker exec xiand-xd01 ps aux | grep socat

# 测试 MySQL 连接（容器内）
docker exec -it xiand-xd01 mysql -S /tmp/.mysql_sock -u root -p -e "SHOW DATABASES;"

# 测试 MySQL 连接（宿主机）
mysql -h 172.17.0.1 -u root -p -e "SHOW DATABASES;"

# 查看 socat 日志
docker exec xiand-xd01 cat /tmp/socat.log

# 重启 socat
docker exec xiand-xd01 bash -c "pkill socat && sleep 1 && /app/xiand/start_mysql_socat.sh"
```

### 文件位置

| 文件 | 路径 |
|------|------|
| MySQL 权限设置脚本 | `/usr/local/games/xiand/scripts/setup-mysql-docker-access.sh` |
| Socat 启动脚本 | `/usr/local/games/xiand/start_mysql_socat.sh` |
| MySQL 说明文档 | `/usr/local/games/xiand/gamelib/howtomysql.txt` |
| Docker 启动脚本 | `/usr/local/games/xiand/docker/Dockerfile.all` |
| Socat 日志（容器内） | `/tmp/socat.log` |
| Socket 文件（容器内） | `/tmp/.mysql_sock` |

### 网络配置

| 项目 | 值 |
|------|-----|
| Docker 网关 | 172.17.0.1 |
| MySQL 端口 | 3306 |
| Socket 路径 | /tmp/.mysql_sock |
| 默认用户 | root |
| 默认密码 | 无；必须通过环境变量提供 |
