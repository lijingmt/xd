/**
 * ========================================================================
 * HTTP API Configuration
 * ========================================================================
 *
 * 集中管理HTTP API服务器的所有配置常量
 *
 * ========================================================================
 */

#ifndef HTTP_API_CONFIG_PIKE
#define HTTP_API_CONFIG_PIKE

// Log when config is loaded
#ifdef HTTP_API_CONFIG_LOADED
#warning "HTTP_API config already loaded!"
#else
#define HTTP_API_CONFIG_LOADED
#endif

// ========================================================================
// 服务器配置
// ========================================================================

/** HTTP服务端口 */
constant HTTP_PORT = 8888;

/** 缺少玩家对象时的HTTP空闲兜底；正常连接由IDLE_KICKD统一判定。 */
constant CONN_TIMEOUT = 3600;

// ========================================================================
// 命令隐藏系统配置
// ========================================================================

/** 每个用户最多存储的命令数量 */
constant HIDDEN_SIZE = 9999;

// ========================================================================
// 请求队列配置
// ========================================================================

/** 每个用户最大队列长度 */
constant MAX_QUEUE_SIZE = 10;

/** 结果缓存时间 (毫秒) */
constant RESULT_CACHE_TIME = 5000;

/** 结果缓存清理间隔 (秒) */
constant RESULT_CLEANUP_INTERVAL = 60;

/** 队列成功路径调试日志 */
constant HTTP_API_QUEUE_DEBUG = 0;

/** HTTP命令同步等待上限 (秒) */
constant HTTP_COMMAND_TIMEOUT = 30;

/** 慢请求阈值 (毫秒) */
constant HTTP_SLOW_REQUEST_MS = 2000;

/** 单个请求的解析边界，避免超大查询串或正文拖垮事件线程。 */
constant MAX_HTTP_QUERY_SIZE = 8192;
constant MAX_HTTP_BODY_SIZE = 65536;

// ========================================================================
// 速率限制配置
// ========================================================================

/** 时间窗口 (秒) */
constant RATE_LIMIT_WINDOW = 60;

/** 每分钟最多登录尝试次数 */
constant MAX_LOGIN_ATTEMPTS = 20;

/** 每分钟最多注册尝试次数 */
constant MAX_REGISTER_ATTEMPTS = 5;

/** 连续失败多少次后锁定 */
constant MAX_FAILED_LOGINS = 15;

/** 锁定时长 (秒) */
constant LOCKOUT_DURATION = 120;

/** 密码失败追踪窗口 (秒) */
constant PASSWORD_FAIL_WINDOW = 300;

// ========================================================================
// 经验加成配置
// ========================================================================

/** HTTP API 用户经验加成开关 (1=开启 50%加成, 0=关闭) */
constant HTTP_API_EXP_BONUS_ENABLED = 1;

/** HTTP API 用户经验加成倍率 (100 = 原始, 300 = 3倍) */
constant HTTP_API_EXP_BONUS_RATE = 300;

#endif
