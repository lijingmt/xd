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
 */
object get_player_from_connection(string userid, void|int update_idle_time)
{
    if(!userid) return 0;

    mixed vconn = vconnections[userid];
    if(vconn && arrayp(vconn) && sizeof(vconn) >= 3) {
        object player = vconn[2];
        if(player && functionp(player->query_name)) {
            if(update_idle_time != 0) {
                vconn[1] = time();
            }
            return player;
        }
        m_delete(vconnections,userid);
    }
    return 0;
}

/**
 * 清理空闲的虚拟连接
 */
void cleanup_idle_connections()
{
    int timeout = CONN_TIMEOUT;
    int now = time();
    array users = indices(vconnections);
    foreach(users, string userid) {
        mixed vconn = vconnections[userid];
        if(arrayp(vconn) && sizeof(vconn) >= 2) {
            int last_used = vconn[1];
            if(now - last_used > timeout) {
                m_delete(vconnections,userid);
            }
        }
    }
    call_out(cleanup_idle_connections, 60);
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
    m_delete(vconnections,userid);
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
