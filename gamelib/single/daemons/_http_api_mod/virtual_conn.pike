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
Thread.Mutex vconnections_lock = Thread.Mutex();

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
    object key = vconnections_lock->lock();
    mixed result = vconnections[userid];
    if(arrayp(result))
        result = result + ({});
    destruct(key);
    return result;
}

/**
 * 设置虚拟连接
 */
void set_virtual_connection(string userid, mixed conn_data)
{
    if(!userid) return;
    object key = vconnections_lock->lock();
    vconnections[userid] = conn_data;
    destruct(key);
}

/**
 * 更新连接使用时间
 */
void update_connection_time(string userid)
{
    if(!userid) return;
    object|zero player = 0;
    object key = vconnections_lock->lock();
    mixed vconn = vconnections[userid];
    if(vconn && arrayp(vconn) && sizeof(vconn) >= 2) {
        vconn[1] = time();
        if(sizeof(vconn)>=3)
            player = vconn[2];
    }
    destruct(key);
    if(player && functionp(player->mark_user_activity))
        player->mark_user_activity();
}

/**
 * 检查并复用已有的玩家连接
 * @param userid 用户ID
 * @param update_idle_time 是否更新闲置时间（显式1=更新，省略或0=不更新）
 */
object get_player_from_connection(string userid, void|int update_idle_time)
{
    if(!userid) return 0;

    object key = vconnections_lock->lock();
    mixed vconn = vconnections[userid];
    if(vconn && arrayp(vconn) && sizeof(vconn) >= 3) {
        object player = vconn[2];
        if(player && functionp(player->query_name)) {
            // 只有用户主动操作的调用点才显式传1；只读轮询必须传0。
            if(update_idle_time != 0) {
                vconn[1] = time();
            }
            destruct(key);
            if(update_idle_time != 0 &&
               functionp(player->mark_user_activity))
                player->mark_user_activity();
            return player;
        }
        m_delete(vconnections,userid);
    }
    destruct(key);
    return 0;
}

/** 仅当快照仍未被请求刷新时认领超时连接。 */
private int claim_idle_connection(string userid,int expected_last_used,
    int now,int timeout)
{
    int claimed = 0;
    object key = vconnections_lock->lock();
    mixed current = vconnections[userid];
    if(arrayp(current) && sizeof(current)>=3 &&
       (int)current[1]==expected_last_used &&
       now-(int)current[1]>=timeout){
        m_delete(vconnections,userid);
        claimed = 1;
    }
    destruct(key);
    return claimed;
}

/**
 * 清理空闲的虚拟连接并踢出超时用户
 */
void cleanup_idle_connections()
{
    mixed err = catch {
        int now = time();
        mapping snapshot = ([]);
        object snapshot_key = vconnections_lock->lock();
        foreach(indices(vconnections),string snapshot_userid){
            mixed snapshot_conn = vconnections[snapshot_userid];
            if(arrayp(snapshot_conn))
                snapshot[snapshot_userid] = snapshot_conn + ({});
        }
        destruct(snapshot_key);
        array users = indices(snapshot);
        int kicked_count = 0;

        foreach(users, string userid) {
            mixed vconn = snapshot[userid];
            if(arrayp(vconn) && sizeof(vconn) >= 3) {
                int last_used = vconn[1];
                object player = vconn[2];
                int idle_time = now - last_used;
                int timeout = player ?
                    IDLE_KICKD->query_timeout_for(player) : CONN_TIMEOUT;

                string name = player && functionp(player->query_name) ? player->query_name() : userid;

                // 检查是否超时
                if(idle_time >= timeout &&
                   claim_idle_connection(userid,last_used,now,timeout)) {
                    // 记录日志
                    string name_cn = player && functionp(player->query_name_cn) ? player->query_name_cn() : name;
                    int level = player && functionp(player->query_level) ? player->query_level() : 0;
                    int vip_level = player ?
                        IDLE_KICKD->query_active_vip_level(player) : 0;

                    log_idle_kick(name, name_cn, level, idle_time,
                        "HTTP_API",vip_level);

                    // 踢出用户
                    if(player && functionp(player->remove)) {
                        player->remove();
                    }

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
void log_idle_kick(string name, string name_cn, int level,
    int idle_seconds, string conn_type,int|void vip_level)
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

    string vip_str = vip_level>0 ? "VIP"+vip_level+" " : "";
    string log_msg = sprintf("[%s] %s(%s) %d级 %s[%s] 空闲%s分钟 被踢下线\n",
        log_time, name_cn, name, level, vip_str, conn_type, idle_min);

    Stdio.append_file(ROOT+"/log/idle_kick.log."+date_str, log_msg);
}

/**
 * 获取连接池状态
 */
mapping query_connection_status()
{
    mapping m = ([ ]);
    mapping snapshot = ([]);
    object key = vconnections_lock->lock();
    foreach(indices(vconnections),string snapshot_userid){
        mixed snapshot_conn = vconnections[snapshot_userid];
        if(arrayp(snapshot_conn))
            snapshot[snapshot_userid] = snapshot_conn + ({});
    }
    destruct(key);
    m["active_connections"] = sizeof(snapshot);
    m["connections"] = ({});

    array users = indices(snapshot);
    foreach(users, string userid) {
        mixed vconn = snapshot[userid];
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
    object key = vconnections_lock->lock();
    m_delete(vconnections,userid);
    destruct(key);
}

/**
 * 检查用户是否有虚拟连接
 */
int has_virtual_connection(string userid)
{
    if(!userid) return 0;
    object key = vconnections_lock->lock();
    mixed vconn = vconnections[userid];
    int result = vconn != 0 && vconn != UNDEFINED;
    destruct(key);
    return result;
}

/**
 * 供安全关服流程取得HTTP/Vue虚拟连接中的真实玩家对象。
 */
array(object) query_all_connected_players()
{
    array(object) players = ({});
    object key = vconnections_lock->lock();
    foreach(indices(vconnections),string userid) {
        mixed vconn = vconnections[userid];
        if(vconn && arrayp(vconn) && sizeof(vconn)>=3) {
            object player = vconn[2];
            if(player && functionp(player->query_name) &&
               search(players,player)==-1)
                players += ({player});
        }
    }
    destruct(key);
    return players;
}
