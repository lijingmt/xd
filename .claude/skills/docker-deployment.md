# Docker 部署 Skill

当用户需要在 203 服务器上部署 xiand Docker 容器时，使用此技能。

## 目录

1. [环境信息](#环境信息)
2. [目录结构](#目录结构)
3. [目录映射](#目录映射)
4. [部署步骤](#部署步骤)
5. [环境变量](#环境变量)
6. [端口说明](#端口说明)
7. [数据库自动初始化](#数据库自动初始化)
8. [Vue 前端配置](#vue-前端配置)
9. [常见问题](#常见问题)
10. [容器管理](#容器管理)
11. [镜像管理](#镜像管理)
12. [调试命令](#调试命令)
13. [重启流程](#重启流程)
14. [多区部署](#多区部署)
15. [合服部署](#合服部署)
16. [高级配置](#高级配置)

---

## 环境信息

| 项目 | 值 |
|------|-----|
| 服务器 | 203 (CentOS Stream 10) |
| 项目名称 | xiand (仙道 MUD) |
| 镜像名称 | lijingmt/xiand-all:latest |
| Pike 版本 | 9.0.11 |
| Tomcat 版本 | 11.0.2 |
| Java 版本 | 21 |
| 数据库 | MariaDB (宿主机) |

---

## 目录结构

### 项目目录

```
/usr/local/games/xiand/          # 项目根目录
├── docker/
│   ├── Dockerfile.all           # 一体化镜像（Pike + Tomcat）
│   └── docker-compose.yml       # Docker Compose 配置
├── .claude/
│   └── skills/
│       └── docker-deployment.md # 本部署文档
├── .dockerignore                 # Docker 忽略文件
├── rebuild-image.sh              # 构建并推送镜像脚本
├── restart-docker.sh             # 启动容器脚本
├── xd.sql                        # 数据库初始化文件
├── lowlib/
│   └── driver.pike              # MUD 驱动程序
├── gamelib/                      # 游戏库
│   └── clone/
│       └── item/                # 物品定义（共享）
├── web/                          # JSP 前端
├── vue_source/                   # Vue 前端源码
│   └── build.js                 # Vue 构建脚本
└── data_xiand/                   # 游戏数据（gitignore）
```

### 数据目录

```
/usr/local/games/allxd/          # 数据根目录
├── xd01/                         # 1区数据
│   ├── data_xiand/              # 游戏运行数据
│   │   ├── users/              # 玩家数据
│   │   ├── bang/               # 帮派数据
│   │   └── ...                 # 其他游戏数据
│   └── item/                    # 物品数据（软链接或复制）
├── xd02/                         # 2区数据
│   ├── data_xiand/
│   └── item/
├── xd03/                         # 3区数据
├── xd04/                         # 4区数据
├── xd05/                         # 5区数据
├── log/                          # 日志目录
│   ├── xd01/                    # 1区日志
│   │   ├── pike.log            # MUD 主日志
│   │   ├── error.log           # 错误日志
│   │   └── ...                 # 其他日志
│   ├── xd02/
│   └── ...
```

---

## 目录映射

### 容器内与宿主机映射关系

| 容器内路径 | 宿主机路径 | 说明 | 用途 |
|-----------|-----------|------|------|
| `/app/xiand/data_xiand` | `/usr/local/games/allxd/{GAME_AREA}/data_xiand` | 游戏数据 | 玩家、帮派等运行时数据 |
| `/app/xiand/gamelib/clone/item` | `/usr/local/games/allxd/{GAME_AREA}/item` | 物品数据 | 装备、物品定义（可共享） |
| `/app/xiand/log` | `/usr/local/games/allxd/log/{GAME_AREA}/` | 日志文件 | MUD 运行日志 |

### 数据库

- 数据库运行在宿主机（172.17.0.1:3306）
- 容器通过 `socat` 将 Unix socket 转发到 TCP
- 数据库名称 = 区号（如 xd01, xd02）

---

## 部署步骤

### 1. 拉取代码

```bash
cd /usr/local/games/xiand
git pull origin vue-http-api
```

### 2. 构建 Vue 前端

```bash
cd /usr/local/games/xiand/vue_source
node build.js
cd ..
```

构建成功后会显示：
```
✓ Vue 前端构建成功！
```

### 3. 构建 Docker 镜像（可选）

#### 方式一：仅构建本地镜像

```bash
SKIP_PUSH=1 ./rebuild-image.sh
```

#### 方式二：构建并推送到 Docker Hub

```bash
DOCKER_TOKEN=your_token ./rebuild-image.sh
```

#### 方式三：推送到公开仓库

```bash
DOCKER_TOKEN=your_token IS_PRIVATE_REPO=false ./rebuild-image.sh
```

### 4. 启动容器

#### 基本语法

```bash
./restart-docker.sh [GAME_AREA] [TOMCAT_PORT] [API_PORT] [IMAGE_TAG]
```

#### 参数说明

| 参数 | 默认值 | 说明 | 示例 |
|------|--------|------|------|
| `GAME_AREA` | xd01 | 游戏区号 | xd01, xd02, xd01-05 |
| `TOMCAT_PORT` | 9001 | Tomcat HTTP 端口 | 9001, 9002, 9003 |
| `API_PORT` | 8888 | HTTP API 端口 | 8888, 8889, 8890 |
| `IMAGE_TAG` | latest | Docker 镜像标签 | latest, 2025-12-20 |

#### 启动示例

```bash
# 使用全部默认值（xd01, 9001, 8888, latest）
./restart-docker.sh

# 指定区号
./restart-docker.sh xd01

# 指定区号和端口
./restart-docker.sh xd01 9001

# 指定区号、端口和 API 端口
./restart-docker.sh xd01 9001 8888

# 完整参数
./restart-docker.sh xd01 9001 8888 latest

# 启动 xd02 区
./restart-docker.sh xd02 9002 8889

# 启动 xd03 区
./restart-docker.sh xd03 9003 8890

# 启动 xd04 区
./restart-docker.sh xd04 9004 8891

# 启动 xd05 区
./restart-docker.sh xd05 9005 8892

# 启动合服区 xd01-05
./restart-docker.sh xd01-05 9005 8890
```

### 5. 查看日志

```bash
# 查看容器日志
docker logs -f xiand-xd01

# 查看 MUD 日志
tail -f /usr/local/games/allxd/log/xd01/pike.log

# 查看错误日志
tail -f /usr/local/games/allxd/log/xd01/error.log
```

---

## 环境变量

### 脚本环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `GAME_AREA` | xd01 | 游戏区号 |
| `GAME_AREAS` | xd01,xd02,xd03,xd04,xd05 | Vue 前端分区列表（逗号分隔） |
| `TOMCAT_HTTP_PORT` | 9001 | Tomcat HTTP 端口 |
| `HTTP_API_PORT` | 8888 | HTTP API 端口 |
| `DOCKER_IMAGE_TAG` | latest | Docker 镜像标签 |

### 容器环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TZ` | Asia/Shanghai | 时区 |
| `MYSQL_HOST` | 172.17.0.1 | MySQL 主机 |
| `MYSQL_PORT` | 3306 | MySQL 端口 |
| `MYSQL_USER` | root | MySQL 用户 |
| `MYSQL_PASSWORD` | 无（必填） | MySQL 密码；通过受限权限的 `.env` 或环境变量提供 |
| `MYSQL_DATABASE` | {GAME_AREA} | MySQL 数据库名 |
| `MUD_PORT` | 13800 | MUD 服务端口 |
| `DEBUG` | 0 | 调试模式 |

### 环境变量使用示例

```bash
# 自定义分区列表
GAME_AREAS="xd01,xd02,xd03" ./restart-docker.sh xd01 9001 8888

# 使用自定义镜像版本
DOCKER_IMAGE_TAG=2025-12-20 ./restart-docker.sh xd01 9001 8888

# 组合使用
GAME_AREAS="xd01,xd02" DOCKER_IMAGE_TAG=2025-12-20 ./restart-docker.sh xd01 9001 8888
```

---

## 端口说明

### 服务端口

| 端口 | 类型 | 默认值 | 说明 | 可配置 |
|------|------|--------|------|--------|
| 13800 | TCP | 13800 | MUD 服务端口 | 否 |
| 8888 | TCP | 8888 | HTTP API 端口 | 是 |
| 9001+ | TCP | 9001 | Tomcat HTTP 端口 | 是 |
| 8443 | TCP | 8443 | Tomcat HTTPS 端口 | 是 |

### 端口规划建议

```
xd01: 9001 (HTTP) / 8888 (API)
xd02: 9002 (HTTP) / 8889 (API)
xd03: 9003 (HTTP) / 8890 (API)
xd04: 9004 (HTTP) / 8891 (API)
xd05: 9005 (HTTP) / 8892 (API)
```

### 防火墙配置

```bash
# 检查防火墙状态
sudo firewall-cmd --list-all

# 开放端口
sudo firewall-cmd --permanent --add-port=9001/tcp
sudo firewall-cmd --permanent --add-port=8888/tcp
sudo firewall-cmd --reload

# 批量开放端口
for port in 9001 9002 9003 9004 9005 8888 8889 8890 8891 8892; do
    sudo firewall-cmd --permanent --add-port=$port/tcp
done
sudo firewall-cmd --reload
```

---

## 数据库自动初始化

### 初始化流程

```
容器启动
    ↓
检查数据库是否存在
    ├─ 不存在 → 创建数据库
    └─ 存在 → 继续
    ↓
检查数据库是否为空（无表）
    ├─ 为空 → 导入 xd.sql
    └─ 有数据 → 跳过导入
    ↓
启动 Pike MUD
    ↓
启动 Tomcat
```

### 数据库命名规则

| 区号 | 数据库名 |
|------|----------|
| xd01 | xd01 |
| xd02 | xd02 |
| xd03 | xd03 |
| xd04 | xd04 |
| xd05 | xd05 |
| xd01-05 | xd01-05 |

### 手动初始化（如需要）

```bash
# 从受限权限的环境文件加载，不要把口令写入命令历史
set -a
source /usr/local/games/xiand/.env
set +a

# 创建数据库
MYSQL_PWD="$MYSQL_PASSWORD" mysql -u root -e "CREATE DATABASE IF NOT EXISTS xd01 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

# 导入 SQL
MYSQL_PWD="$MYSQL_PASSWORD" mysql -u root xd01 < /usr/local/games/xiand/xd.sql

# 验证
MYSQL_PWD="$MYSQL_PASSWORD" mysql -u root -e "USE xd01; SHOW TABLES;"
```

---

## Vue 前端配置

### 分区列表自动配置

容器启动时会自动更新 Vue 前端的分区配置：

```javascript
// 默认分区列表（在 app.js 中）
const defaultPartitions = [
    { value: 'xd01', label: '1区' },
    { value: 'xd02', label: '2区' },
    { value: 'xd03', label: '3区' },
    { value: 'xd04', label: '4区' },
    { value: 'xd05', label: '5区' }
];
```

### 自定义分区列表

```bash
# 只显示部分分区
GAME_AREAS="xd01,xd02,xd03" ./restart-docker.sh xd01 9001 8888

# 单分区
GAME_AREAS="xd01" ./restart-docker.sh xd01 9001 8888
```

### API 端口自动更新

容器启动时会自动更新 Vue 前端的 API 端口配置：

```bash
# API 端口会自动更新为 8889
./restart-docker.sh xd01 9001 8889
```

### 手动更新 Vue 配置

```bash
# 进入容器
docker exec -it xiand-xd01 bash

# 编辑配置
vi /usr/local/tomcat/webapps/ROOT/web_vue/js/app.js

# 重启 Tomcat
docker restart xiand-xd01
```

---

## 常见问题

### 容器无法启动

#### 症状

```bash
docker ps -a
# CONTAINER ID   IMAGE   STATUS
# abc123         xxx     Exited (1) 5 seconds ago
```

#### 排查步骤

```bash
# 1. 查看容器日志
docker logs xiand-xd01

# 2. 查看详细日志
docker logs --tail 100 xiand-xd01

# 3. 检查目录权限
ls -la /usr/local/games/allxd/xd01/

# 4. 检查端口占用
netstat -tlnp | grep 9001
netstat -tlnp | grep 13800

# 5. 检查 Docker 日志
journalctl -u docker -n 50
```

#### 常见原因

| 问题 | 解决方案 |
|------|----------|
| 端口被占用 | 停止占用端口的进程或更换端口 |
| 目录权限不足 | `chmod -R 777 /usr/local/games/allxd/xd01/` |
| 镜像不存在 | 运行 `docker pull lijingmt/xiand-all:latest` |
| 内存不足 | 调整 Docker 内存限制或关闭其他容器 |

### 数据库连接失败

#### 症状

```
✗ 数据库导入失败
Can't connect to MySQL server
```

#### 排查步骤

```bash
# 1. 检查 MySQL 是否运行
systemctl status mariadb
# 或
systemctl status mysqld

# 2. 测试连接
MYSQL_PWD="$MYSQL_PASSWORD" mysql -u root -e "SHOW DATABASES;"

# 3. 检查防火墙
sudo firewall-cmd --list-all

# 4. 检查 MySQL 监听地址
sudo netstat -tlnp | grep 3306

# 5. 检查容器网络
docker exec -it xiand-xd01 bash
ping 172.17.0.1
telnet 172.17.0.1 3306
```

#### 解决方案

```bash
# 确保 MySQL 监听所有地址
sudo vi /etc/my.cnf.d/mariadb-server.cnf
# 添加或修改：
# bind-address = 0.0.0.0

sudo systemctl restart mariadb

# 或者修改容器使用 host 网络模式
docker run --network host ...
```

### 目录权限问题

#### 症状

```
Permission denied
Cannot write to /app/xiand/data_xiand
```

#### 解决方案

```bash
# 修复数据目录权限
chmod -R 777 /usr/local/games/allxd/xd01/
chmod -R 777 /usr/local/games/allxd/xd01/data_xiand
chmod -R 777 /usr/local/games/allxd/xd01/item

# 修复日志目录权限
chmod -R 777 /usr/local/games/allxd/log/xd01/

# 修复所有区
chmod -R 777 /usr/local/games/allxd/
```

### Vue 前端无法访问

#### 症状

浏览器打开 `http://服务器IP:9001/` 显示 404 或空白

#### 排查步骤

```bash
# 1. 检查容器状态
docker ps | grep xiand-xd01

# 2. 检查 Tomcat 日志
docker exec xiand-xd01 cat /usr/local/tomcat/logs/catalina.out

# 3. 检查文件是否存在
docker exec xiand-xd01 ls -la /usr/local/tomcat/webapps/ROOT/

# 4. 检查端口映射
docker port xiand-xd01
```

#### 解决方案

```bash
# 重新构建 Vue 前端
cd /usr/local/games/xiand/vue_source
node build.js

# 重启容器
docker restart xiand-xd01
```

### MUD 无法连接

#### 症状

telnet 连接 13800 端口失败

#### 排查步骤

```bash
# 1. 检查 MUD 进程
docker exec xiand-xd01 ps aux | grep pike

# 2. 检查 MUD 日志
docker exec xiand-xd01 tail -f /app/xiand/log/pike.log

# 3. 测试内部连接
docker exec xiand-xd01 telnet 127.0.0.1 13800

# 4. 检查端口映射
docker port xiand-xd01 | grep 13800
```

---

## 容器管理

### 基本操作

```bash
# 启动容器
docker start xiand-xd01

# 停止容器
docker stop xiand-xd01

# 重启容器
docker restart xiand-xd01

# 删除容器
docker rm -f xiand-xd01

# 暂停容器
docker pause xiand-xd01

# 恢复容器
docker unpause xiand-xd01
```

### 查看信息

```bash
# 查看运行中的容器
docker ps

# 查看所有容器
docker ps -a

# 查看容器详情
docker inspect xiand-xd01

# 查看容器资源使用
docker stats xiand-xd01

# 查看容器日志
docker logs xiand-xd01

# 实时查看日志
docker logs -f xiand-xd01

# 查看最近 100 行日志
docker logs --tail 100 xiand-xd01
```

### 进入容器

```bash
# 进入容器 bash
docker exec -it xiand-xd01 bash

# 以 root 用户进入
docker exec -it -u root xiand-xd01 bash

# 执行单条命令
docker exec xiand-xd01 ls -la /app/xiand/

# 在容器中启动交互式程序
docker exec -it xiand-xd01 /bin/sh
```

### 容器文件操作

```bash
# 从容器复制文件到宿主机
docker cp xiand-xd01:/app/xiand/log/pike.log ./

# 从宿主机复制文件到容器
docker cp ./config.txt xiand-xd01:/app/xiand/

# 查看容器内文件
docker exec xiand-xd01 cat /app/xiand/log/pike.log
```

---

## 镜像管理

### 查看镜像

```bash
# 查看本地镜像
docker images | grep xiand

# 查看镜像详情
docker inspect lijingmt/xiand-all:latest

# 查看镜像历史
docker history lijingmt/xiand-all:latest
```

### 拉取镜像

```bash
# 拉取最新镜像
docker pull lijingmt/xiand-all:latest

# 拉取指定版本
docker pull lijingmt/xiand-all:2025-12-20

# 拉取所有标签
docker pull -a lijingmt/xiand-all
```

### 删除镜像

```bash
# 删除指定镜像
docker rmi lijingmt/xiand-all:old-tag

# 强制删除
docker rmi -f lijingmt/xiand-all:old-tag

# 删除所有未使用的镜像
docker image prune

# 删除所有悬空镜像
docker image prune -a
```

### 镜像标签管理

```bash
# 添加标签
docker tag lijingmt/xiand-all:latest xiand:backup

# 推送标签
docker push lijingmt/xiand-all:latest
```

---

## 调试命令

### Pike 调试

```bash
# 进入容器
docker exec -it xiand-xd01 bash

# 检查 Pike 版本
pike -v

# 检查 Pike 路径
which pike

# 检查 Pike 模块
pike -e "write(sprintf(\"Pike version: %s\\n\", __VERSION__));"

# 测试 MySQL 连接
pike -e "
string password = getenv(\"MYSQL_PASSWORD\");
if (!password || !sizeof(password)) error(\"MYSQL_PASSWORD is required\\n\");
object sql = Sql.sql(sprintf(\"mysql://root:%s@172.17.0.1/xd01\", password));
write(\"MySQL connected\\n\");
"
```

### Tomcat 调试

```bash
# 检查 Tomcat 目录
docker exec xiand-xd01 ls -la /usr/local/tomcat/

# 检查 Tomcat 日志
docker exec xiand-xd01 ls -la /usr/local/tomcat/logs/

# 查看 catalina 日志
docker exec xiand-xd01 tail -f /usr/local/tomcat/logs/catalina.out

# 检查 webapps
docker exec xiand-xd01 ls -la /usr/local/tomcat/webapps/

# 检查 ROOT 应用
docker exec xiand-xd01 ls -la /usr/local/tomcat/webapps/ROOT/
```

### MUD 调试

```bash
# 检查 MUD 进程
docker exec xiand-xd01 ps aux | grep pike

# 检查 MUD 日志
docker exec xiand-xd01 tail -f /app/xiand/log/pike.log

# 测试 MUD 连接（容器内）
docker exec xiand-xd01 telnet 127.0.0.1 13800

# 测试 MUD 连接（宿主机）
telnet 127.0.0.1 13800

# 检查 MUD 端口监听
docker exec xiand-xd01 netstat -tlnp | grep 13800
```

### 网络调试

```bash
# 检查容器网络
docker exec xiand-xd01 ip addr

# 检查容器路由
docker exec xiand-xd01 ip route

# 测试 DNS
docker exec xiand-xd01 nslookup google.com

# 测试外部连接
docker exec xiand-xd01 curl -I https://www.google.com

# 检查端口映射
docker port xiand-xd01
```

---

## 重启流程

### 完整重启流程

```bash
# 1. 停止并删除旧容器
docker stop xiand-xd01
docker rm xiand-xd01

# 2. （可选）拉取最新镜像
docker pull lijingmt/xiand-all:latest

# 3. 重新构建 Vue 前端
cd /usr/local/games/xiand/vue_source
node build.js
cd ..

# 4. 启动新容器
./restart-docker.sh xd01 9001 8888

# 5. 等待容器启动
sleep 30

# 6. 查看日志
docker logs -f xiand-xd01

# 7. 测试连接
telnet 127.0.0.1 13800
curl http://127.0.0.1:9001/
```

### 快速重启

```bash
# 使用 restart-docker.sh 自动处理
./restart-docker.sh xd01 9001 8888
```

---

## 多区部署

### 端口规划

```
区号   HTTP端口  API端口  MUD端口  容器名
xd01   9001      8888     13800    xiand-xd01
xd02   9002      8889     13800    xiand-xd02
xd03   9003      8890     13800    xiand-xd03
xd04   9004      8891     13800    xiand-xd04
xd05   9005      8892     13800    xiand-xd05
```

### 批量启动

```bash
# 启动所有 5 个区
./restart-docker.sh xd01 9001 8888
./restart-docker.sh xd02 9002 8889
./restart-docker.sh xd03 9003 8890
./restart-docker.sh xd04 9004 8891
./restart-docker.sh xd05 9005 8892
```

### 使用循环批量启动

```bash
# 使用循环批量启动（在 bash 中）
for i in {1..5}; do
    area=$(printf "xd%02d" $i)
    http_port=$((9000 + $i))
    api_port=$((8887 + $i))
    ./restart-docker.sh $area $http_port $api_port
done
```

### 查看所有区状态

```bash
# 查看所有 xiand 容器
docker ps | grep xiand

# 查看所有容器资源
docker stats | grep xiand
```

### 停止所有区

```bash
# 停止所有 xiand 容器
docker stop $(docker ps -q -f name=xiand)

# 或逐个停止
for i in {1..5}; do
    docker stop xiand-xd$(printf "%02d" $i)
done
```

---

## 合服部署

### 合服说明

合服是指将多个区的数据合并到一个服务器上运行。

### 启动合服区

```bash
# 启动合服区 xd01-05
GAME_AREAS="xd01,xd02,xd03,xd04,xd05" ./restart-docker.sh xd01-05 9001 8888
```

### 数据迁移

```bash
# 1. 停止单区容器
docker stop xiand-xd01 xiand-xd02 xiand-xd03 xiand-xd04 xiand-xd05

# 2. 合并数据（需要手动处理）
# 根据具体业务逻辑合并 data_xiand 目录

# 3. 启动合服区
./restart-docker.sh xd01-05 9001 8888
```

### 合服注意事项

1. **玩家数据冲突**：需要处理相同玩家 ID 的情况
2. **帮派数据**：需要合并帮派数据
3. **装备数据**：确保装备唯一性
4. **数据库合并**：可能需要手动合并数据库

---

## 高级配置

### 自定义 MySQL 配置

```bash
# 修改启动脚本中的 MySQL 连接参数
docker run -d \
    -e MYSQL_HOST=192.168.1.100 \
    -e MYSQL_PORT=3307 \
    -e MYSQL_USER=xiand_user \
    -e MYSQL_PASSWORD=custom_password \
    ...
```

### 使用外部 Tomcat

如果需要使用外部 Tomcat 而不是容器内的：

```bash
# 1. 复制 web 文件到外部 Tomcat
cp -r /usr/local/games/xiand/web/* /var/lib/tomcat/webapps/ROOT/

# 2. 容器只运行 MUD
# 需要修改 Dockerfile 和启动脚本
```

### 持久化配置

```bash
# 添加更多持久化目录
docker run -d \
    -v /usr/local/games/allxd/xd01/custom_config:/app/xiand/custom_config \
    ...
```

### 资源限制

```bash
# 限制内存和 CPU
docker run -d \
    --memory=4g \
    --memory-swap=8g \
    --cpus=2.0 \
    ...
```

### 日志轮转

```bash
# 配置容器日志轮转
docker run -d \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    ...
```

### 网络配置

```bash
# 使用 host 网络模式（性能更好，但端口可能冲突）
docker run -d \
    --network host \
    ...

# 使用自定义网络
docker network create xiand-network
docker run -d \
    --network xiand-network \
    ...
```

### 备份策略

```bash
# 备份数据目录
tar -czf xiand-xd01-backup-$(date +%Y%m%d).tar.gz /usr/local/games/allxd/xd01/

# 备份数据库
MYSQL_PWD="$MYSQL_PASSWORD" mysqldump -u root xd01 > xiand-xd01-db-$(date +%Y%m%d).sql

# 自动备份脚本
cat > /usr/local/games/xiand/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/usr/local/games/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
test -n "$MYSQL_PASSWORD" || { echo "MYSQL_PASSWORD is required" >&2; exit 1; }
tar -czf $BACKUP_DIR/xiand-xd01-$DATE.tar.gz /usr/local/games/allxd/xd01/
MYSQL_PWD="$MYSQL_PASSWORD" mysqldump -u root xd01 > $BACKUP_DIR/xiand-xd01-db-$DATE.sql
# 保留最近 7 天的备份
find $BACKUP_DIR -name "xiand-xd01-*" -mtime +7 -delete
EOF
chmod +x /usr/local/games/xiand/backup.sh

# 添加到 crontab（每天凌晨 2 点备份）
crontab -e
# 添加: 0 2 * * * /usr/local/games/xiand/backup.sh
```

---

## 快速参考

### 常用命令速查

```bash
# 启动容器
./restart-docker.sh xd01 9001 8888

# 查看日志
docker logs -f xiand-xd01

# 进入容器
docker exec -it xiand-xd01 bash

# 重启容器
docker restart xiand-xd01

# 停止容器
docker stop xiand-xd01

# 删除容器
docker rm -f xiand-xd01

# 查看状态
docker ps | grep xiand

# 查看资源
docker stats xiand-xd01
```

### 故障排查清单

- [ ] 检查容器状态：`docker ps -a`
- [ ] 查看容器日志：`docker logs xiand-xd01`
- [ ] 检查目录权限：`ls -la /usr/local/games/allxd/xd01/`
- [ ] 检查端口占用：`netstat -tlnp | grep 9001`
- [ ] 测试数据库连接：`MYSQL_PWD="$MYSQL_PASSWORD" mysql -u root -e "SHOW DATABASES;"`
- [ ] 检查防火墙：`sudo firewall-cmd --list-all`
- [ ] 检查磁盘空间：`df -h`
- [ ] 检查内存使用：`free -h`
