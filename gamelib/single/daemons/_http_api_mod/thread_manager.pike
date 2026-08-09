/**
 * ========================================================================
 * HTTP API 线程管理器 - 世界命令公平串行、纯响应并行模型
 * ========================================================================
 *
 * 所有会进入 player->command() 的命令都由主 Backend 公平轮转执行，
 * 避免工作线程持有人物锁时反向阻塞 Backend。纯文本解析和 JSON 编码
 * 进入有界 Thread.Farm，真正使用多核且不触碰战斗、背包或世界状态。
 *
 * ========================================================================
 */

// ========================================================================
// 常量定义
// ========================================================================

/** 核心命令列表 - 涉及多人共享状态，必须由主 Backend 串行执行。 */
constant CORE_COMMANDS = ({
    // ========== 登录相关 ==========
    "gamelib", "login", "register", "init", "check_login", "check_login_new",
    "choice_race", "choice_profe", "start", "reguser", "tietomobile",
    // 登录会创建/替换人物与连接，保持核心串行。

    // ========== 战斗相关（多人交互）==========
    "attack", "kill", "hit", "fight", "strike",
    "flee", "escape", "run", "surrender",
    "zhaohuan", "zhaohuan_cfm", "summon",  // 召唤（涉及NPC和共享状态）
    "growth_task", "task_guide",  // 职业历练与任务引导传送
	"autofight", "autofightclose",  // 自动战斗
	"profession_assistant",  // 职业助手会改写配置、召唤物与仙玉
	"flushview",  // 挂机循环会改写敌人/房间共享状态
	"npc_kill", "kill_filter", "kill_quick",
	"feedback", "mgr_feedback",  // 反馈提交、审核及玉石奖励
	"account_storage",  // 账号共享宝库读取会分配永久物品ID并保存人物
	"pet", "pet_hunt", "pet_duel", "daily", "daily_cultivation",
	"wanling_rift", "wanling_join",  // 账号图鉴、跨玩家论道与裂隙状态
	"timed_event",  // 活动报名、战斗与令牌兑换会修改人物及共享场景状态

    // ========== 移动相关（可能触发战斗/NPC交互）==========
	"go", "goto", "go_back", "fly",
	"north", "south", "east", "west", "up", "down", "enter", "exit",
	"arrive", "ui_select_room", "qge74hye", "waihai_qge74hye",
	"city_qge74hye", "relife",

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
	"relation", "postcity", "lottery_join_in", "random_award",
	"qianyuanzhutong",
	"transfer_to", "catchup_exp_potion",

    // ========== 其他 ==========
	"tell", "ui_chat", "use_toolbar", "mailbox", "game_deal", "txadd",
	"quit", "save",
	"shutdown", "shutdown_safe"
});

/** 共享系统命令前缀 - 新增子命令也必须进入全局核心锁 */
constant CORE_COMMAND_PREFIXES = ({
	"vendue_", "temai_", "term_", "fb_", "viceskill_", "artisan",
	// 跨玩家/跨档案写入必须与核心世界状态串行，不能只依赖单账号锁。
	"bang_", "mail_", "mailbox_", "present_", "sendother",
	"home_", "trade_", "follow_", "spy_", "spec_", "mgr_", "wiz_",
	"login_", "chatroom_", "city_", "bz_", "bc_", "msg_", "qqlist_",
	"door_", "fee_exchange_", "lottery_", "transfer_", "tuiguang_",
	"dubo_", "gift_", "hb_", "vip_", "yushi_", "yblh_", "yuebing_",
	"user_package_", "account_storage_", "pet_", "wanling_", "shzzh_",
	"add_", "waigua_", "test_", "bx_get_"
});

constant HTTP_SLOW_COMMAND_MS = 500;
constant HTTP_PARALLEL_THREAD_LIMIT = 16;
constant HTTP_PARALLEL_PENDING_LIMIT = 128;
constant HTTP_WORLD_PENDING_LIMIT = 512;
constant HTTP_WORLD_PER_USER_LIMIT = 8;
constant HTTP_REFRESH_CALLBACK_LIMIT = 8;

// ========================================================================
// 全局变量
// ========================================================================

/** 核心命令锁 - 保证因果一致性 */
Thread.Mutex core_lock = Thread.Mutex();

/** 纯响应任务复用有界线程池，不按请求无限创建系统线程。 */
object parallel_command_farm;
Thread.Mutex parallel_command_farm_init_lock = Thread.Mutex();

/** Backend 世界命令按账号公平轮转；同账号重复挂机刷新会合并。 */
mapping(string:array(mapping)) world_user_queues = ([]);
mapping(string:int) world_ready_users = ([]);
array(string) world_ready_order = ({});
int world_dispatch_scheduled = 0;
int world_pending_commands = 0;
int world_pending_callbacks = 0;
int world_pending_peak = 0;
int world_coalesced_refreshes = 0;
int world_coalesced_looks = 0;
int world_queue_rejected = 0;
int world_max_queue_wait_ms = 0;

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
int parallel_pending = 0;
int parallel_active = 0;
int parallel_peak_pending = 0;
int parallel_peak_active = 0;
int parallel_completed = 0;
int parallel_failed = 0;
int parallel_rejected = 0;

void init_parallel_command_farm()
{
    object init_key;
    if(parallel_command_farm)
        return;
    init_key = parallel_command_farm_init_lock->lock();
    if(!parallel_command_farm){
        object new_farm = Thread.Farm();
        new_farm->set_max_num_threads(
            HTTP_PARALLEL_THREAD_LIMIT);
        parallel_command_farm = new_farm;
    }
    destruct(init_key);
}

string query_command_name(string cmd)
{
    string first_word;
    int space_pos;

    first_word = lower_case(String.trim_all_whites(cmd || ""));
    space_pos = search(first_word," ");
    if(space_pos > 0)
        first_word = first_word[0..space_pos-1];
    return first_word;
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

private void schedule_world_command_dispatch()
{
    if(world_dispatch_scheduled || sizeof(world_ready_order)==0)
        return;
    world_dispatch_scheduled = 1;
    call_out(process_world_command_queue,0);
}

void remove_world_user_queue(string userid)
{
    array(mapping) queue;
    array(string) remaining = ({});

    userid = lower_case(String.trim_all_whites(userid || ""));
    if(userid=="")
        return;
    queue = world_user_queues[userid];
    if(arrayp(queue)){
        world_pending_commands -= sizeof(queue);
        foreach(queue,mapping request){
            array callbacks = request["callbacks"];
            if(arrayp(callbacks))
                world_pending_callbacks -= sizeof(callbacks);
        }
    }
    if(world_pending_commands < 0)
        world_pending_commands = 0;
    if(world_pending_callbacks < 0)
        world_pending_callbacks = 0;
    m_delete(world_user_queues,userid);
    m_delete(world_ready_users,userid);
    foreach(world_ready_order,string ready_user)
        if(ready_user!=userid)
            remaining += ({ready_user});
    world_ready_order = remaining;
}

int query_world_user_queue_size(string userid)
{
    userid = lower_case(String.trim_all_whites(userid || ""));
    array queue = world_user_queues[userid];
    if(!arrayp(queue))
        return 0;
    return sizeof(queue);
}

/**
 * 供同一 Backend 上的调度器做轻量拥塞判断。
 * 这里只返回整数快照，不复制队列，也不把游戏对象交给工作线程。
 */
int query_world_pending_command_count()
{
    return world_pending_commands;
}

int enqueue_world_command(string userid,string password,string cmd,
    function callback,array extra)
{
    array(mapping) queue;
    string command_name;
    string queue_userid;

    if(!userid || !cmd || !callback)
        return 0;
    queue_userid = lower_case(String.trim_all_whites(userid));
    if(queue_userid=="")
        return 0;
    queue = world_user_queues[queue_userid];
    if(!arrayp(queue))
        queue = ({});
    command_name = query_command_name(cmd);

    // 只能与队尾刷新合并。若中间已有攻击、移动等命令，跨越它合并会
    // 让后发请求看到过早的状态，破坏同账号命令顺序。
    if((command_name=="flushview" || command_name=="look") &&
       sizeof(queue)>0){
        mapping request = queue[-1];
        if((string)request["command_name"]==command_name &&
           (command_name=="flushview" ||
           String.trim_all_whites((string)request["cmd"])==
           String.trim_all_whites(cmd))){
            array callbacks;
            callbacks = request["callbacks"];
            if(!arrayp(callbacks) ||
               sizeof(callbacks)>=HTTP_REFRESH_CALLBACK_LIMIT){
                world_queue_rejected++;
                return 0;
            }
            callbacks += ({({callback,extra})});
            request["callbacks"] = callbacks;
            world_pending_callbacks++;
            if(command_name=="flushview")
                world_coalesced_refreshes++;
            else
                world_coalesced_looks++;
            return 1;
        }
    }

    if(world_pending_commands>=HTTP_WORLD_PENDING_LIMIT ||
       sizeof(queue)>=HTTP_WORLD_PER_USER_LIMIT){
        world_queue_rejected++;
        return 0;
    }
    queue += ({([
        "userid":userid,
        "password":password || "",
        "cmd":cmd,
        "command_name":command_name,
        "callbacks":({({callback,extra})}),
        "queued_at":gethrtime(),
    ])});
    world_user_queues[queue_userid] = queue;
    world_pending_commands++;
    world_pending_callbacks++;
    if(world_pending_commands>world_pending_peak)
        world_pending_peak = world_pending_commands;
    if(!world_ready_users[queue_userid]){
        world_ready_users[queue_userid] = 1;
        world_ready_order += ({queue_userid});
    }
    schedule_world_command_dispatch();
    return 1;
}

void process_world_command_queue()
{
    string userid;
    array(mapping) queue;
    mapping request;
    array callbacks;
    string result;
    int queue_wait_ms;

    world_dispatch_scheduled = 0;
    if(sizeof(world_ready_order)==0)
        return;
    userid = world_ready_order[0];
    if(sizeof(world_ready_order)>1)
        world_ready_order = world_ready_order[1..];
    else
        world_ready_order = ({});
    m_delete(world_ready_users,userid);

    queue = world_user_queues[userid];
    if(!arrayp(queue) || sizeof(queue)==0){
        remove_world_user_queue(userid);
        schedule_world_command_dispatch();
        return;
    }
    request = queue[0];
    if(sizeof(queue)>1){
        queue = queue[1..];
        world_user_queues[userid] = queue;
        world_ready_users[userid] = 1;
        world_ready_order += ({userid});
    }
    else
        m_delete(world_user_queues,userid);
    if(world_pending_commands>0)
        world_pending_commands--;

    queue_wait_ms = (gethrtime()-(int)request["queued_at"])/1000;
    if(queue_wait_ms>world_max_queue_wait_ms)
        world_max_queue_wait_ms = queue_wait_ms;
    result = execute_core_command((string)request["userid"],
        (string)request["password"],(string)request["cmd"]);
    callbacks = request["callbacks"];
    if(arrayp(callbacks)){
        foreach(callbacks,array callback_entry){
            function callback;
            array extra;
            mixed callback_err;
            if(sizeof(callback_entry)<2){
                if(world_pending_callbacks>0)
                    world_pending_callbacks--;
                continue;
            }
            callback = callback_entry[0];
            extra = callback_entry[1];
            callback_err = catch {
                callback(result,@extra);
            };
            if(callback_err)
                werror("[HTTP_API][WORLD_CALLBACK] %s: %s\n",
                    (string)request["command_name"],
                    describe_error(callback_err));
            if(world_pending_callbacks>0)
                world_pending_callbacks--;
        }
    }
    schedule_world_command_dispatch();
}

/**
 * 获取指定账号稳定复用的命令锁。
 */
object query_user_command_mutex(string userid)
{
	object account_characterd;
    object table_key;
    object mutex;
	string requested_id = String.trim_all_whites(userid || "");

	userid = lower_case(requested_id);
    if(userid == "")
        userid = "_anonymous";
	account_characterd = (object)(ROOT+
		"/gamelib/single/daemons/account_characterd.pike");
	if(account_characterd && functionp(
	   account_characterd->query_account_runtime_mutex))
		return account_characterd->query_account_runtime_mutex(requested_id);
    table_key = user_command_lock_table_lock->lock();
    if(!objectp(user_command_locks[userid]))
        user_command_locks[userid] = Thread.Mutex();
    mutex = user_command_locks[userid];
    destruct(table_key);
    return mutex;
}

int query_user_command_lock_count()
{
	object account_characterd;
    object table_key;
    int count;

    table_key = user_command_lock_table_lock->lock();
    count = sizeof(user_command_locks);
    destruct(table_key);
	account_characterd = (object)(ROOT+
		"/gamelib/single/daemons/account_characterd.pike");
	if(account_characterd && functionp(
	   account_characterd->query_account_runtime_lock_count))
		count += account_characterd->query_account_runtime_lock_count();
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

private int reserve_parallel_command()
{
    int accepted = 0;
    object key = command_status_lock->lock();
    if(parallel_pending < HTTP_PARALLEL_PENDING_LIMIT){
        parallel_pending++;
        if(parallel_pending > parallel_peak_pending)
            parallel_peak_pending = parallel_pending;
        accepted = 1;
    }
    else
        parallel_rejected++;
    destruct(key);
    return accepted;
}

private void start_parallel_command()
{
    object key = command_status_lock->lock();
    parallel_active++;
    if(parallel_active > parallel_peak_active)
        parallel_peak_active = parallel_active;
    destruct(key);
}

private void finish_parallel_command(int ok)
{
    object key = command_status_lock->lock();
    if(parallel_pending > 0)
        parallel_pending--;
    if(parallel_active > 0)
        parallel_active--;
    if(ok)
        parallel_completed++;
    else
        parallel_failed++;
    destruct(key);
}

private void cancel_parallel_command()
{
    object key = command_status_lock->lock();
    if(parallel_pending > 0)
        parallel_pending--;
    parallel_failed++;
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
    if(acquired==1)
        world_commands_active = 0;
    else if(acquired==0 && world_commands_waiting > 0)
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
 * 核心命令统一在主 Backend 执行；同一账号及核心世界写入均串行。
 */
string execute_core_command(string userid,string password,string cmd)
{
    object|zero user_mutex = 0;
    object|zero user_key = 0;
    object|zero core_key = 0;
    object|zero main_daemon = 0;
    string result = "错误: 无法找到主执行器";
    int started_at = gethrtime();
    int acquired = 0;

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
    record_world_command_finish(cmd,is_core_command(cmd),started_at,acquired);
    if(err)
        werror("[HTTP_API][CORE_COMMAND] %s failed\n",(cmd/" ")[0]);
    if(err)
        return "错误: 命令执行失败";
    return result;
}

private string encode_json_mapping_job(mapping data)
{
    return Standards.JSON.encode(data);
}

private string execute_parallel_json_job(function builder,array args)
{
    string json = "";
    int ok = 0;
    mixed err;

    start_parallel_command();
    err = catch {
        json = builder(@args);
        ok = 1;
    };
    finish_parallel_command(ok && !err);
    if(err)
        werror("[HTTP_API][PARALLEL_JSON] %s\n",describe_error(err));
    return json;
}

private void deliver_parallel_json(string json,
    Protocols.HTTP.Server.Request req,int code)
{
    if(!json || json==""){
        send_json(req,(["error":"响应编码失败，请稍后重试"]),500);
        return;
    }
    send_encoded_json(req,json,code);
}

private void deliver_parallel_json_failure(mixed err,
    Protocols.HTTP.Server.Request req,int code)
{
    cancel_parallel_command();
    werror("[HTTP_API][PARALLEL_JSON_FUTURE] %s\n",describe_error(err));
    send_json(req,(["error":"响应线程池暂时不可用"]),503);
}

int send_json_builder_async(Protocols.HTTP.Server.Request req,
    function builder,array args,int code)
{
    object future;
    mixed err;

    if(!req || !builder)
        return 0;
    // 请求对象和builder留在Future回调参数中；线程池只获得一份纯值参数。
    args = copy_value(args || ({}));
    init_parallel_command_farm();
    if(!reserve_parallel_command())
        return 0;
    err = catch {
        future = parallel_command_farm->run(execute_parallel_json_job,
            builder,args);
        future->on_success(deliver_parallel_json,req,code);
        future->on_failure(deliver_parallel_json_failure,req,code);
    };
    if(err){
        cancel_parallel_command();
        return 0;
    }
    return 1;
}

int send_json_mapping_async(Protocols.HTTP.Server.Request req,
    mapping data,int code)
{
    return send_json_builder_async(req,encode_json_mapping_job,({data}),code);
}

/**
 * 异步执行命令。所有 player->command() 都先进入 Backend 公平队列；
 * HTTP 请求处理只负责入队，不再同步等待人物锁或世界命令完成。
 */
int execute_command_async(string userid,string password,string cmd,
    function callback,mixed ... extra)
{
    if(!userid || !cmd || !callback)
        return 0;
    if(sizeof(userid)>64 || sizeof(password || "")>128 || sizeof(cmd)>2048)
        return 0;
    if(!LOGICALZONED->login_allowed(userid)){
        callback("{\"error\":\"该逻辑区尚未开放或正在维护\"}",@extra);
        return 1;
    }
    return enqueue_world_command(userid,password,cmd,callback,extra);
}

/** 同步兼容入口；新 HTTP 处理器必须优先使用 execute_command_async。 */
string execute_parallel_command(string userid,string password,string cmd)
{
    if(master()->backend_thread()!=this_thread()){
        object status_key = command_status_lock->lock();
        world_non_backend_rejected++;
        destruct(status_key);
        return "错误: 游戏命令必须由主事件线程执行";
    }
    return execute_core_command(userid,password,cmd);
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
        result = execute_core_command(userid,password,cmd);
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

    m["mode"] = "deferred_world_parallel_render";
    m["process_model"] = "single_process";
    m["description"] = "world commands use fair Backend queue; pure response work uses bounded Thread.Farm";
    m["core_commands"] = sizeof(CORE_COMMANDS);
    m["core_prefixes"] = sizeof(CORE_COMMAND_PREFIXES);
    m["user_command_locks"] = query_user_command_lock_count();
    m["same_user_policy"] = "serialized";
    m["cross_user_policy"] = "round_robin_world_parallel_render";
    m["parallel_thread_limit"] = HTTP_PARALLEL_THREAD_LIMIT;
    m["parallel_pending_limit"] = HTTP_PARALLEL_PENDING_LIMIT;
    m["world_pending_limit"] = HTTP_WORLD_PENDING_LIMIT;
    m["world_per_user_limit"] = HTTP_WORLD_PER_USER_LIMIT;
    m["world_pending_commands"] = world_pending_commands;
    m["world_pending_callbacks"] = world_pending_callbacks;
    m["world_pending_peak"] = world_pending_peak;
    m["world_ready_users"] = sizeof(world_ready_order);
    m["world_coalesced_refreshes"] = world_coalesced_refreshes;
    m["world_coalesced_looks"] = world_coalesced_looks;
    m["world_queue_rejected"] = world_queue_rejected;
    m["world_max_queue_wait_ms"] = world_max_queue_wait_ms;
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
    m["parallel_pending"] = parallel_pending;
    m["parallel_active"] = parallel_active;
    m["parallel_peak_pending"] = parallel_peak_pending;
    m["parallel_peak_active"] = parallel_peak_active;
    m["parallel_completed"] = parallel_completed;
    m["parallel_failed"] = parallel_failed;
    m["parallel_rejected"] = parallel_rejected;
    destruct(key);

    return m;
}
