/**
 * ========================================================================
 * HTTP API 线程管理器 - 单进程、单世界写入模型
 * ========================================================================
 *
 * 所有会访问人物、房间、怪物、掉落和存档的命令都经过同一世界锁。
 * 不再为普通命令临时创建 Thread.Thread；可隔离的文件 I/O 统一交给
 * async_iod 的 Pike 9 Thread.Farm。
 *
 * ========================================================================
 */

// ========================================================================
// 常量定义
// ========================================================================

/** 核心命令列表 - 用于运行指标分类（所有游戏命令均在 Backend 单写） */
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
	"profession_assistant",  // 职业助手会改写配置、召唤物与仙玉
    "flushview", "use_perform",  // 挂机循环与技能会改写敌人/队友共享状态
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
	"tell", "game_deal", "txadd", "quit", "save"
});

/** 共享系统命令前缀 - 新增子命令也必须进入全局核心锁 */
constant CORE_COMMAND_PREFIXES = ({
	"vendue_", "temai_", "term_", "fb_", "viceskill_",
	// 跨玩家/跨档案写入必须与核心世界状态串行，不能只依赖单账号锁。
	"bang_", "mail_", "mailbox_", "present_", "sendother",
	"home_", "trade_", "follow_", "spy_", "spec_", "mgr_", "wiz_"
});

constant HTTP_SLOW_COMMAND_MS = 500;

// ========================================================================
// 全局变量
// ========================================================================

/** 核心命令锁 - 保证因果一致性 */
Thread.Mutex core_lock = Thread.Mutex();

/** 同一账号命令锁 - 保护人物状态和虚拟输出连接。 */
mapping(string:object) user_command_locks =
    set_weak_flag(([]),Pike.WEAK_VALUES);
Thread.Mutex user_command_lock_table_lock = Thread.Mutex();

/** 世界命令队列/耗时指标；只统计等待者，不复制游戏对象。 */
Thread.Mutex command_status_lock = Thread.Mutex();
int world_commands_waiting = 0;
int world_commands_active = 0;
int world_command_queue_peak = 0;
int world_command_count = 0;
int world_core_command_count = 0;
int world_regular_command_count = 0;
int world_slow_command_count = 0;
int world_max_command_ms = 0;
int world_last_slow_time = 0;
string world_last_slow_command = "";
int world_non_backend_rejected = 0;

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

private void record_world_command_start()
{
    object key = command_status_lock->lock();
    world_commands_waiting++;
    if(world_commands_waiting > world_command_queue_peak)
        world_command_queue_peak = world_commands_waiting;
    destruct(key);
}

private void record_world_command_acquired()
{
    object key = command_status_lock->lock();
    if(world_commands_waiting > 0)
        world_commands_waiting--;
    world_commands_active = 1;
    destruct(key);
}

private void record_world_command_finish(string cmd,int is_core,
    int started_at,int acquired)
{
    int elapsed_ms = (gethrtime()-started_at)/1000;
    object key = command_status_lock->lock();
    if(acquired)
        world_commands_active = 0;
    else if(world_commands_waiting > 0)
        world_commands_waiting--;
    world_command_count++;
    if(is_core)
        world_core_command_count++;
    else
        world_regular_command_count++;
    if(elapsed_ms > world_max_command_ms)
        world_max_command_ms = elapsed_ms;
    if(elapsed_ms >= HTTP_SLOW_COMMAND_MS){
        world_slow_command_count++;
        world_last_slow_time = time();
        world_last_slow_command = (cmd/" ")[0];
    }
    destruct(key);
    if(elapsed_ms >= HTTP_SLOW_COMMAND_MS)
        werror("[HTTP_API][SLOW_COMMAND] %s took %d ms\n",
            (cmd/" ")[0],elapsed_ms);
}

/**
 * 游戏命令统一在主 Backend 单写执行；锁顺序固定为“账号锁 ->
 * 世界锁”，避免人物连接与共享世界状态交叉写入。
 */
string execute_world_command(string userid,string password,string cmd)
{
    object|zero user_mutex = 0;
    object|zero user_key = 0;
    object|zero core_key = 0;
    object|zero main_daemon = 0;
    string result = "错误: 无法找到主执行器";
    int started_at = gethrtime();
    int core_command = is_core_command(cmd);
    int acquired = 0;

    // 心跳、call_out 与 HTTP 世界命令必须由同一个 Backend 线程写入。
    // 世界锁只能串行 HTTP 请求，不能保护不持锁的心跳，因此来自任何
    // 工作线程的游戏命令都必须拒绝，绝不能在该线程里直接执行。
    if(master()->backend_thread()!=this_thread()){
        object status_key = command_status_lock->lock();
        world_non_backend_rejected++;
        destruct(status_key);
        return "错误: 游戏命令必须由主事件线程执行";
    }

    record_world_command_start();
    mixed err = catch {
        user_mutex = query_user_command_mutex(userid);
        user_key = user_mutex->lock();
        core_key = core_lock->lock();
        record_world_command_acquired();
        acquired = 1;
        main_daemon = find_object(ROOT+
            "/gamelib/single/daemons/http_api_daemon.pike");
        if(main_daemon && functionp(main_daemon->execute_command_sync))
            result = main_daemon->execute_command_sync(userid,password,cmd);
    };
    if(core_key)
        destruct(core_key);
    if(user_key)
        destruct(user_key);
    record_world_command_finish(cmd,core_command,started_at,acquired);
    if(err)
        return "错误: "+describe_error(err);
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
    if(sizeof(userid) > 64 || sizeof(password || "") > 128 ||
       sizeof(cmd) > 2048)
        return "错误: 请求参数过长";

    err = catch {
        result = execute_world_command(userid,password,cmd);
    };

    if(err)
        return "错误: "+describe_error(err);
    return result;
}

// ========================================================================
// 状态查询
// ========================================================================

/**
 * 获取单进程线程与世界写入状态。
 */
mapping query_thread_status()
{
    mapping m = ([ ]);
    object key;

    m["mode"] = "single_writer_with_safe_thread_farm";
    m["process_model"] = "single_process";
    m["description"] = "game world commands are serialized; isolated I/O uses Thread.Farm";
    m["core_commands"] = sizeof(CORE_COMMANDS);
    m["core_prefixes"] = sizeof(CORE_COMMAND_PREFIXES);
    m["user_command_locks"] = query_user_command_lock_count();
    m["same_user_policy"] = "serialized";
    m["cross_user_policy"] = "serialized_world_writes";
    key = command_status_lock->lock();
    m["world_commands_waiting"] = world_commands_waiting;
    m["world_commands_active"] = world_commands_active;
    m["world_command_queue_peak"] = world_command_queue_peak;
    m["world_command_count"] = world_command_count;
    m["core_command_count"] = world_core_command_count;
    m["regular_command_count"] = world_regular_command_count;
    m["slow_command_count"] = world_slow_command_count;
    m["slow_command_threshold_ms"] = HTTP_SLOW_COMMAND_MS;
    m["max_command_ms"] = world_max_command_ms;
	m["last_slow_time"] = world_last_slow_time;
	m["last_slow_command"] = world_last_slow_command;
	m["non_backend_rejected"] = world_non_backend_rejected;
    destruct(key);

    return m;
}
