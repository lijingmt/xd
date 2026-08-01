/**
 * ========================================================================
 * HTTP API Rate Limiting Module
 * ========================================================================
 *
 * 速率限制与安全防护：IP限制、登录尝试次数、IP封禁
 *
 * ========================================================================
 */

// ========================================================================
// 速率限制模块 - 此文件通过主文件的 #include 加载
// ========================================================================

// ========================================================================
// 全局变量
// ========================================================================

/** 速率限制数据: IP -> ({login_attempts, register_attempts, last_login_time, last_register_time, failed_logins}) */
mapping rate_limits = ([ ]);

/** IP封禁列表: IP -> unlock_time */
mapping banned_ips = ([ ]);

// ========================================================================
// IP封禁管理
// ========================================================================

/**
 * 检查IP是否被封禁
 */
int is_ip_banned(string ip)
{
    if(!ip) return 0;
    mixed unlock_time = banned_ips[ip];
    if(unlock_time && time() < unlock_time) {
        http_werror(" IP %s is banned until %d\n", ip, unlock_time);
        return 1;
    }
    return 0;
}

/**
 * 封禁IP地址
 */
void ban_ip(string ip, int duration)
{
    if(!ip) return;
    banned_ips[ip] = time() + duration;
    http_werror(" Banned IP %s for %d seconds\n", ip, duration);
}

/**
 * 解封IP地址
 */
void unban_ip(string ip)
{
    if(!ip) return;
    m_delete(banned_ips,ip);
    http_werror(" Unbanned IP %s\n", ip);
}

// ========================================================================
// 登录速率限制
// ========================================================================

/**
 * 检查登录速率限制
 */
int check_login_rate_limit(string ip)
{
    if(!ip) ip = "unknown";
    int now = time();
    int window = RATE_LIMIT_WINDOW;
    int max_attempts = MAX_LOGIN_ATTEMPTS;
    int max_failed = MAX_FAILED_LOGINS;
    int fail_window = PASSWORD_FAIL_WINDOW;
    int lockout_duration = LOCKOUT_DURATION;

    // 检查IP封禁
    if(is_ip_banned(ip)) {
        return 1;
    }

    // 获取或初始化速率限制数据
    mixed data = rate_limits[ip];
    if(!data || !arrayp(data)) {
        rate_limits[ip] = ({0, 0, now - window - 1, now - window - 1, 0});
        data = rate_limits[ip];
    }

    int login_attempts = data[0];
    int last_login = data[2];
    int failed_logins = data[4];

    // 检查连续失败次数
    if(failed_logins >= max_failed) {
        if(now - last_login < fail_window) {
            ban_ip(ip, lockout_duration);
            return 1;
        }
        data[4] = 0;
    }

    // 检查时间窗口内的尝试次数
    if(now - last_login < window) {
        if(login_attempts >= max_attempts) {
            http_werror(" Rate limit exceeded for IP %s: %d attempts\n", ip, login_attempts);
            return 1;
        }
    } else {
        data[0] = 0;
    }

    data[0] = login_attempts + 1;
    data[2] = now;

    return 0;
}

/**
 * 记录登录失败
 */
void record_login_failure(string ip)
{
    if(!ip) ip = "unknown";
    mixed data = rate_limits[ip];
    if(!data || !arrayp(data)) {
        rate_limits[ip] = ({0, 0, time(), time(), 0});
        data = rate_limits[ip];
    }
    data[4] = (data[4] || 0) + 1;
    http_werror(" Recorded login failure for IP %s, total failures: %d\n", ip, data[4]);
}

/**
 * 重置登录失败计数（登录成功时调用）
 */
void reset_login_failures(string ip)
{
    if(!ip) return;
    mixed data = rate_limits[ip];
    if(data && arrayp(data) && sizeof(data) >= 5) {
        data[0] = 0;
        data[4] = 0;
        http_werror(" Reset login failures for IP %s\n", ip);
    }
}

// ========================================================================
// 注册速率限制
// ========================================================================

/**
 * 检查注册速率限制
 */
int check_register_rate_limit(string ip)
{
    if(!ip) ip = "unknown";
    int now = time();
    int window = RATE_LIMIT_WINDOW;
    int max_attempts = MAX_REGISTER_ATTEMPTS;

    if(is_ip_banned(ip)) {
        return 1;
    }

    mixed data = rate_limits[ip];
    if(!data || !arrayp(data)) {
        rate_limits[ip] = ({0, 0, now - window - 1, now - window - 1, 0});
        data = rate_limits[ip];
    }

    int register_attempts = data[1];
    int last_register = data[3];

    if(now - last_register < window) {
        if(register_attempts >= max_attempts) {
            http_werror(" Registration rate limit exceeded for IP %s: %d attempts\n", ip, register_attempts);
            return 1;
        }
    } else {
        data[1] = 0;
    }

    data[1] = register_attempts + 1;
    data[3] = now;

    return 0;
}

// ========================================================================
// 清理过期记录
// ========================================================================

/**
 * 清理过期的速率限制记录
 */
void cleanup_rate_limits()
{
    int now = time();
    int window = RATE_LIMIT_WINDOW;

    array ips = indices(rate_limits);
    foreach(ips, string ip) {
        mixed data = rate_limits[ip];
        if(arrayp(data) && sizeof(data) >= 4) {
            int last_login = data[2];
            int last_register = data[3];

            // 超过5分钟无活动，清理记录
            if(now - last_login > 300 && now - last_register > 300) {
                m_delete(rate_limits,ip);
            }
            // 重置计数器（每分钟）
            else if(now - last_login > window) {
                data[0] = 0;
            }
            if(now - last_register > window) {
                data[1] = 0;
            }
        }
    }

    // 清理过期的IP封禁
    array banned = indices(banned_ips);
    foreach(banned, string ip) {
        if(banned_ips[ip] && banned_ips[ip] < now) {
            http_werror(" Unbanning IP: %s\n", ip);
            m_delete(banned_ips,ip);
        }
    }

    call_out(cleanup_rate_limits, 60);
}

/**
 * 获取速率限制状态
 */
mapping query_rate_limit_status()
{
    mapping m = ([ ]);
    m["tracked_ips"] = sizeof(rate_limits);
    m["banned_ips"] = sizeof(banned_ips);
    m["banned_list"] = indices(banned_ips);
    return m;
}
