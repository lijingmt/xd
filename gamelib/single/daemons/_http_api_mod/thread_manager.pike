/**
 * ========================================================================
 * HTTP API 线程管理器 - Phase 3: 真正多核并行
 * ========================================================================
 *
 * 架构:
 * - 核心命令: 主线程直接执行（带锁，保证因果一致性）
 * - 非核心命令: 独立线程执行（并行，利用多核）
 *
 * 执行模型:
 * ┌─────────┐  ┌─────────┐  ┌─────────┐
 * │ 请求A   │  │ 请求B   │  │ 请求C   │
 * │ 非核心  │  │ 非核心  │  │ 核心    │
 * │   ↓     │  │   ↓     │  │   ↓     │
 * │ 新线程  │  │ 新线程  │  │ 主线程  │
 * │ (并行)  │  │ (并行)  │  │ (串行)  │
 * └─────────┘  └─────────┘  └─────────┘
 *
 * ========================================================================
 */

// ========================================================================
// 常量定义
// ========================================================================

/** 核心命令列表 - 需要因果一致性，主线程执行（多人交互类） */
constant CORE_COMMANDS = ({
    // ========== 登录相关 ==========
    "gamelib", "register", "init", "check_login", "check_login_new",
    // "login" 已移除 - 使用线程执行，避免阻塞其他玩家

    // ========== 战斗相关（多人交互）==========
    "attack", "kill", "hit", "fight", "strike",
    "flee", "escape", "run", "surrender",
    "zhaohuan", "zhaohuan_cfm", "summon",  // 召唤（涉及NPC和共享状态）
    "growth_task", "task_guide",  // 职业历练与任务引导传送
    "autofight", "autofightclose",  // 自动战斗
    "feedback", "mgr_feedback",  // 反馈提交、审核及玉石奖励

    // ========== 移动相关（可能触发战斗/NPC交互）==========
    "go", "goto", "go_back", "fly",
    "north", "south", "east", "west", "up", "down", "enter", "exit",

    // ========== 商店/交易（涉及金币/物品转移）==========
    "buy", "buy_items", "sell", "list", "value",
    "trade",  // 玩家间交易
    "sell_new", "sell_zb_all",  // 拍卖售卖
    "cancel_sell",  // 取消拍卖（物品返回）
    // 拍卖系统
    "vendue", "vendue_end", "vendue_end2",
    "vendue_ykj", "vendue_ykj2",
    "vendue_dj", "vendue_dj2",
    "vendue_qrqp", "vendue_qrqp2",
    "vie_buy", "vie_buy2",  // 竞价购买
    // 特卖系统
    "temai_shop", "temai_list", "temai_other_buy", "temai_yao", "temai_yao_buy",
    "temai_buy", "temai_buymenpai", "temai_buymenpai_ask",
    "temai_daoju", "temai_daoju_buyluyin", "temai_daoju_buyluyin_yanmen",
    "temai_daoju_choicepaimen", "temai_fix_buy",
    "temai_temaichang", "temai_temaichang_buy", "temai_checkfee",
    // 其他出售
    "dsd_sell", "dsd_sell_confirm",
    "sdlihe_sell", "sdlihe_sell_confirm",
    "ydlihe_sell", "ydlihe_sell_confirm",
    "zlj_sell", "zlj_sell_confirm",

    // ========== 物品转移（多人交互风险）==========
    "get", "take",  // 从地上拾取（可能有竞争）
    "drop", "put",  // 丢弃/放置（可能被他人拾取）
    "give", "offer",  // 给予他人
    "duanwu_throw", "duanwu_throw_cof",  // 投放粽子（他人可捡）

    // ========== 仓库（物品存取）==========
    "deposit", "withdraw", "store", "retrieve",
    "storage", "storage_list", "restorage", "restorage_list",
    "expand_storage", "expand_storage_list", "expand_storage_replace",

    // ========== 组队（多人交互）==========
    "team", "follow", "lead", "dismiss", "recruit",
    "my_term", "term_assist", "term_ok", "term_refuse",
    "term_changeleader", "term_kick", "term_leave", "term_release",
    "term_chat", "fb_entry", "fb_leave", "fb_term_cangku",
    "fb_items_assign", "fb_assign_confirm",

    // ========== 帮派（多人交互）==========
    "set_bang", "set_bang_ask", "leavebang", "betray", "betray2",
    "delbanguser", "delbanguser_ask", "delmaster",
    "changebanglevel", "changebangmaster", "changebangmasterok",

    // ========== 师徒（多人交互）==========
    "baishi", "apply_baishi",
    "master_del",

    // ========== 社交（多人交互）==========
    "married", "marry_divorce",
    "do_marrage", "do_marriage_yes",
    "relation",

    // ========== 其他 ==========
    "quit", "save"
});

/** 共享系统命令前缀 - 新增子命令也必须进入全局核心锁 */
constant CORE_COMMAND_PREFIXES = ({
    "vendue_", "temai_", "term_", "fb_", "viceskill_"
});

// ========================================================================
// 全局变量
// ========================================================================

/** 核心命令锁 - 保证因果一致性 */
Thread.Mutex core_lock = Thread.Mutex();

/** 同一账号命令锁 - 保护人物状态和虚拟输出连接 */
mapping(string:object) user_command_locks = ([]);
Thread.Mutex user_command_lock_table_lock = Thread.Mutex();

/** 结果容器类（每个请求独立） */
class ResultContainer {
    Thread.Condition cond = Thread.Condition();
    Thread.Mutex mutex = Thread.Mutex();
    string result = "";
    int done = 0;
}

// ========================================================================
// 工具函数
// ========================================================================

/**
 * 判断是否为核心命令
 */
int is_core_command(string cmd)
{
    array(string) prefixes;
    if(!cmd) return 1;  // 默认核心

    string first_word = cmd;
    int space_pos = search(cmd, " ");
    if(space_pos > 0) {
        first_word = cmd[0..space_pos-1];
    }

    first_word = lower_case(first_word);

    if(has_value(CORE_COMMANDS, first_word))
        return 1;
    prefixes = CORE_COMMAND_PREFIXES;
    foreach(prefixes,string prefix){
        if(has_prefix(first_word,prefix))
            return 1;
    }
    return 0;
}

/**
 * 获取指定账号稳定复用的命令锁。
 */
object query_user_command_mutex(string userid)
{
    object table_key;
    object mutex;

    userid = lower_case(String.trim_all_whites(userid || ""));
    if(userid == "")
        userid = "_anonymous";
    table_key = user_command_lock_table_lock->lock();
    if(!objectp(user_command_locks[userid]))
        user_command_locks[userid] = Thread.Mutex();
    mutex = user_command_locks[userid];
    destruct(table_key);
    return mutex;
}

int query_user_command_lock_count()
{
    object table_key;
    int count;

    table_key = user_command_lock_table_lock->lock();
    count = sizeof(user_command_locks);
    destruct(table_key);
    return count;
}

// ========================================================================
// 命令执行
// ========================================================================

/**
 * 线程执行函数（用于非核心命令）
 */
void _execute_in_thread(string userid, string password, string cmd, object result_container)
{
    object user_mutex;
    object user_key;
    string result = "";

    user_mutex = query_user_command_mutex(userid);
    user_key = user_mutex->lock();
    mixed err = catch {
        object main_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
        if(main_daemon && functionp(main_daemon->execute_command_sync)) {
            result = main_daemon->execute_command_sync(userid, password, cmd);
        } else {
            result = "错误: 无法找到主执行器";
        }
    };
    destruct(user_key);

    if(err) {
        result = "错误: " + describe_error(err);
    }

    // 存储结果并发送信号
    object key = result_container->mutex->lock();
    result_container->result = result;
    result_container->done = 1;
    destruct(key);
    result_container->cond->signal();
}

/**
 * 执行核心命令（主线程，带锁）
 */
string execute_core_command(string userid, string password, string cmd)
{
    object user_mutex = query_user_command_mutex(userid);
    object user_key = user_mutex->lock();
    object core_key = core_lock->lock();
    string result = "错误: 无法找到主执行器";

    mixed err = catch {
        object main_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
        if(main_daemon && functionp(main_daemon->execute_command_sync)) {
            result = main_daemon->execute_command_sync(userid, password, cmd);
        }
    };

    destruct(core_key);
    destruct(user_key);

    if(err) {
        return "错误: " + describe_error(err);
    }

    return result;
}

/**
 * 执行非核心命令（独立线程，并行）
 */
string execute_parallel_command(string userid, string password, string cmd)
{
    int deadline;
    int remaining;
    int timed_out;
    string result;
    // 创建独立的结果容器
    object result_container = ResultContainer();

    // 启动线程执行命令
    Thread.Thread t = Thread.Thread(_execute_in_thread, userid, password, cmd, result_container);

    // 等待结果（最多30秒）
    object key = result_container->mutex->lock();
    deadline = time()+HTTP_COMMAND_TIMEOUT;
    remaining = HTTP_COMMAND_TIMEOUT;
    while(result_container->done == 0 && remaining > 0) {
        result_container->cond->wait(key, remaining);
        remaining = deadline-time();
    }
    timed_out = result_container->done == 0;
    result = result_container->result;
    destruct(key);

    if(timed_out)
        return "错误: 命令执行超时";
    return result;
}

// ========================================================================
// 路由入口 (供 http_api.pike 调用)
// ========================================================================

/**
 * 路由并执行命令（无等待，直接执行）
 *
 * @param userid 用户ID
 * @param password 密码
 * @param cmd 命令
 * @return 执行结果
 */
string route_and_execute(string userid, string password, string cmd)
{
    string result = "";
    mixed err;
    if(!userid || !cmd) return "错误: 参数无效";

    err = catch {
        if(is_core_command(cmd)) {
            // 核心命令: 同账号锁内再获取全局核心锁。
            result = execute_core_command(userid, password, cmd);
        } else {
            // 普通命令: 执行线程持有账号锁，超时返回也不会提前释放。
            result = execute_parallel_command(userid, password, cmd);
        }
    };

    if(err)
        return "错误: "+describe_error(err);
    return result;
}

// ========================================================================
// 状态查询
// ========================================================================

/**
 * 获取线程状态（Phase 3 简化版）
 */
mapping query_thread_status()
{
    mapping m = ([ ]);

    m["mode"] = "parallel";
    m["description"] = "HTTP requests execute in parallel, core commands use mutex lock";
    m["core_commands"] = sizeof(CORE_COMMANDS);
    m["core_prefixes"] = sizeof(CORE_COMMAND_PREFIXES);
    m["user_command_locks"] = query_user_command_lock_count();
    m["same_user_policy"] = "serialized";
    m["cross_user_policy"] = "parallel_except_core";

    return m;
}
