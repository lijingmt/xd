/**
 * ========================================================================
 * HTTP API Virtual Connection Management
 * ========================================================================
 *
 * 虚拟连接池管理：BufferConnection类和连接复用机制
 *
 * ========================================================================
 */

// ========================================================================
// 虚拟连接模块 - 此文件通过主文件的 #include 加载
// ========================================================================

#undef CONND
#define CONND ((object)(ROOT + "/pikenv/connd.pike"))

// ========================================================================
// 全局变量
// ========================================================================

/** 虚拟连接池: userid -> ({buffer_conn, last_used_time, player_obj}) */
mapping vconnections = ([ ]);

// ========================================================================
// BufferConnection 类
// ========================================================================

/**
 * 虚拟连接类 - 捕获write()输出
 */
class BufferConnection {
    string buffer = "";
    string output_buffer = "";

    void receive(string str) {
        buffer += str;
        // werror("[BUFFER] Received: %d bytes\n", sizeof(str));
    }

    string get_output() {
        return buffer;
    }

    void clear() {
        buffer = "";
        output_buffer = "";
    }

    int write(string str) {
        buffer += str;
        // werror("[BUFFER] write(): %d bytes\n", sizeof(str));
        return str ? sizeof(str) : 1;
    }

    string filter(string str) {
        return str;
    }

    object query_filter() {
        return 0;
    }

    void close() {
        // 空实现
    }
}

// ========================================================================
// 虚拟连接池管理
// ========================================================================

/**
 * 获取或创建玩家的虚拟连接
 */
mixed get_virtual_connection(string userid)
{
    if(!userid) return 0;
    return vconnections[userid];
}

/**
 * 设置虚拟连接
 */
void set_virtual_connection(string userid, mixed conn_data)
{
    if(!userid) return;
    vconnections[userid] = conn_data;
}

/**
 * 更新连接使用时间
 */
void update_connection_time(string userid)
{
    if(!userid) return;
    mixed vconn = vconnections[userid];
    if(vconn && arrayp(vconn) && sizeof(vconn) >= 2) {
        vconn[1] = time();
    }
}

/**
 * 检查并复用已有的玩家连接
 * @param userid 用户ID
 * @param update_idle_time 是否更新闲置时间（默认1=更新，0=不更新）
 */
object get_player_from_connection(string userid, void|int update_idle_time)
{
    if(!userid) return 0;

    mixed vconn = vconnections[userid];
    if(vconn && arrayp(vconn) && sizeof(vconn) >= 3) {
        object player = vconn[2];
        if(player && functionp(player->query_name)) {
            // 默认更新闲置时间，除非明确传入0
            if(update_idle_time != 0) {
                vconn[1] = time();
            }
            return player;
        }
        vconnections[userid] = 0;
    }
    return 0;
}

/**
 * 清理空闲的虚拟连接并踢出超时用户
 */
void cleanup_idle_connections()
{
    mixed err = catch {
        int timeout = CONN_TIMEOUT;
        int now = time();
        array users = indices(vconnections);
        int kicked_count = 0;

        // 调试：每次cleanup都输出日志
        http_werror("[IDLE_CHECK] Running cleanup, vconnections size=%d, timeout=%d\n", sizeof(vconnections), timeout);

        foreach(users, string userid) {
            mixed vconn = vconnections[userid];
            if(arrayp(vconn) && sizeof(vconn) >= 3) {
                int last_used = vconn[1];
                object player = vconn[2];
                int idle_time = now - last_used;

                // 调试：输出每个连接的状态
                string name = player && functionp(player->query_name) ? player->query_name() : userid;
                http_werror("[IDLE_CHECK] User %s: idle=%d/%d seconds\n", name, idle_time, timeout);

                // 检查是否超时
                if(idle_time > timeout) {
                    // 记录日志
                    string name_cn = player && functionp(player->query_name_cn) ? player->query_name_cn() : name;
                    int level = player && functionp(player->query_level) ? player->query_level() : 0;

                    log_idle_kick(name, name_cn, level, idle_time, "HTTP_API");

                    // 踢出用户
                    if(player && functionp(player->remove)) {
                        player->remove();
                    }

                    // 移除虚拟连接
                    vconnections[userid] = 0;
                    kicked_count++;
                }
            }
        }

        if(kicked_count > 0) {
            http_werror("[IDLE_KICK] Kicked %d idle HTTP_API users\n", kicked_count);
        }
    };

    if(err) {
        http_werror("[IDLE_CHECK] ERROR: %s\n", describe_error(err));
    }

    // 无论是否出错，都继续调度
    call_out(cleanup_idle_connections, 60);
}

/**
 * 记录踢人日志
 */
void log_idle_kick(string name, string name_cn, int level, int idle_seconds, string conn_type)
{
    string now = ctime(time());
    string log_time = now[0..sizeof(now)-2];

    mapping now_time = localtime(time());
    int day = now_time["mday"];
    int mon = now_time["mon"]+1;
    int year = now_time["year"]+1900;

    string mon_str = (mon < 10) ? "0"+mon : (string)mon;
    string day_str = (day < 10) ? "0"+day : (string)day;
    string date_str = year+"-"+mon_str+"-"+day_str;

    string idle_min = (string)(idle_seconds / 60);

    string log_msg = sprintf("[%s] %s(%s) %d级 [%s] 空闲%s分钟 被踢下线\n",
        log_time, name_cn, name, level, conn_type, idle_min);

    Stdio.append_file(ROOT+"/log/idle_kick.log."+date_str, log_msg);
}

/**
 * 获取连接池状态
 */
mapping query_connection_status()
{
    mapping m = ([ ]);
    m["active_connections"] = sizeof(vconnections);
    m["connections"] = ({});

    array users = indices(vconnections);
    foreach(users, string userid) {
        mixed vconn = vconnections[userid];
        if(vconn && arrayp(vconn) && sizeof(vconn) >= 2) {
            m["connections"] += ({([
                "userid": userid,
                "last_used": vconn[1],
                "idle_seconds": time() - vconn[1]
            ])});
        }
    }
    return m;
}

/**
 * 移除虚拟连接（用于被 socket 连接踢掉时）
 */
void remove_virtual_connection(string userid)
{
    if(!userid) return;
    vconnections[userid] = 0;
}

/**
 * 检查用户是否有虚拟连接
 */
int has_virtual_connection(string userid)
{
    if(!userid) return 0;
    mixed vconn = vconnections[userid];
    return vconn != 0 && vconn != UNDEFINED;
}

/**
 * 供安全关服流程取得HTTP/Vue虚拟连接中的真实玩家对象。
 */
array(object) query_all_connected_players()
{
    array(object) players = ({});
    foreach(indices(vconnections),string userid) {
        mixed vconn = vconnections[userid];
        if(vconn && arrayp(vconn) && sizeof(vconn)>=3) {
            object player = vconn[2];
            if(player && functionp(player->query_name) &&
               search(players,player)==-1)
                players += ({player});
        }
    }
    return players;
}
