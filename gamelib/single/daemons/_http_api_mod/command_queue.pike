/**
 * ========================================================================
 * HTTP API Command Queue Module
 * ========================================================================
 *
 * 异步请求队列系统：防止并发导致状态不一致
 *
 * ========================================================================
 */

// ========================================================================
// 命令队列模块 - 此文件通过主文件的 #include 加载
// ========================================================================

// ========================================================================
// 全局变量
// ========================================================================

/** 用户请求队列: userid -> array of pending requests */
mapping user_request_queues = ([ ]);

/** 队列处理状态: userid -> processing_flag (0=空闲, 1=处理中) */
mapping queue_processing = ([ ]);

/** 结果缓存: request_id -> ({result, timestamp}) */
mapping request_results = ([ ]);

/** 工作线程状态 */
object worker_thread;
int worker_running = 0;

/** 队列调度状态 */
int queue_tick_count = 0;
int queue_last_tick = 0;
int queue_max_user_size = 0;

// ========================================================================
// 队列管理
// ========================================================================

void remove_user_request_queue(string userid)
{
    if(!userid)
        return;
    m_delete(user_request_queues, userid);
    m_delete(queue_processing, userid);
}

int query_user_request_queue_size(string userid)
{
    mixed queue;

    if(!userid)
        return 0;
    queue = user_request_queues[userid];
    if(!arrayp(queue))
        return 0;
    return sizeof(queue);
}

void store_request_result(string request_id, string result)
{
    if(!request_id)
        return;
    request_results[request_id] = ({ result || "", time() });
}

int query_request_result_count()
{
    return sizeof(request_results);
}

/**
 * 启动工作线程
 */
void start_worker_thread()
{
    if(worker_thread) {
        if(HTTP_API_QUEUE_DEBUG)
            http_werror(" Worker thread already running\n");
        return;
    }
    worker_running = 1;
    if(HTTP_API_QUEUE_DEBUG)
        http_werror(" Starting worker thread\n");
}

/**
 * 添加命令到用户请求队列
 * @param userid 用户ID
 * @param cmd 要执行的命令
 * @param request_id 请求ID
 * @return 1=成功加入队列, 0=队列已满
 */
int enqueue_user_request(string userid, string cmd, string request_id)
{
    if(!userid || !cmd) return 0;

    if(!user_request_queues[userid]) {
        user_request_queues[userid] = ({});
    }

    array queue = user_request_queues[userid];
    int max_size = MAX_QUEUE_SIZE;

    if(sizeof(queue) >= max_size) {
        http_werror(" Queue full for user %s\n", userid);
        return 0;
    }

    queue += ({ ({request_id, cmd, time(), 0}) });
    user_request_queues[userid] = queue;
    if(sizeof(queue) > queue_max_user_size)
        queue_max_user_size = sizeof(queue);

    if(HTTP_API_QUEUE_DEBUG) {
        http_werror(" Enqueued request for %s: cmd=%s, queue_size=%d\n",
               userid, cmd, sizeof(queue));
    }

    if(!queue_processing[userid])
        call_out(process_user_queues, 0);

    return 1;
}

/**
 * 处理用户请求队列
 */
void process_user_queues()
{
    int now = time();
    array users = indices(user_request_queues);

    queue_tick_count++;
    queue_last_tick = now;

    foreach(users, string userid) {
        array queue = user_request_queues[userid];
        if(!arrayp(queue) || sizeof(queue) == 0) {
            remove_user_request_queue(userid);
            continue;
        }

        if(queue_processing[userid]) {
            continue;
        }

        foreach(queue, mixed req) {
            if(arrayp(req) && sizeof(req) >= 4 && req[3] == 0) {
                req[3] = 1;
                queue_processing[userid] = 1;

                string request_id = req[0];
                string cmd = req[1];

                if(HTTP_API_QUEUE_DEBUG)
                    http_werror(" Processing request for %s: %s\n", userid, cmd);

                call_out(execute_queued_command, 0, userid, cmd, request_id);
                break;
            }
        }
    }
}

/**
 * 执行队列中的命令
 * 需要主文件提供 execute_command 函数
 */
void execute_queued_command(string userid, string cmd, string request_id)
{
    if(HTTP_API_QUEUE_DEBUG)
        http_werror(" Executing queued command: %s for %s\n", cmd, userid);

    // 获取主文件的 execute_command 函数
    object main_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
    if(main_daemon && functionp(main_daemon->execute_command_async) &&
       main_daemon->execute_command_async(userid,"",cmd,
           finish_queued_command,userid,cmd,request_id))
        return;
    finish_queued_command("命令线程池繁忙",userid,cmd,request_id);
}

void finish_queued_command(string result,string userid,string cmd,
    string request_id)
{

    // 存储结果到缓存
    store_request_result(request_id, result);

    // 从队列中移除已完成的请求
    if(user_request_queues[userid]) {
        array new_queue = ({});
        foreach(user_request_queues[userid], mixed req) {
            if(arrayp(req) && req[0] != request_id) {
                new_queue += ({req});
            }
        }
        if(sizeof(new_queue) == 0)
            remove_user_request_queue(userid);
        else {
            user_request_queues[userid] = new_queue;
            queue_processing[userid] = 0;
            call_out(process_user_queues, 0);
        }
    } else {
        m_delete(queue_processing, userid);
    }

    if(HTTP_API_QUEUE_DEBUG)
        http_werror(" Command completed for %s, result_len=%d\n", userid, sizeof(result));
}

/**
 * 获取请求结果
 * @param request_id 请求ID
 * @return result 如果完成, 0 如果未完成, UNDEFINED 如果超时
 */
string|zero get_request_result(string request_id)
{
    if(!request_id) return 0;

    mixed cached = request_results[request_id];
    if(!cached || !arrayp(cached)) {
        return 0;
    }

    string result = cached[0];
    int result_time = cached[1];
    int cache_time = RESULT_CACHE_TIME;

    if(time() - result_time > cache_time / 1000) {
        m_delete(request_results, request_id);
        return UNDEFINED;
    }

    m_delete(request_results, request_id);
    return result;
}

/**
 * 清理过期的请求结果
 */
void cleanup_old_results()
{
    int now = time();
    int cache_time = RESULT_CACHE_TIME;
    array ids = indices(request_results);

    foreach(ids, string id) {
        mixed cached = request_results[id];
        if(cached && arrayp(cached) && sizeof(cached) >= 2) {
            if(now - cached[1] > cache_time / 1000) {
                m_delete(request_results, id);
            }
        } else {
            m_delete(request_results, id);
        }
    }
    call_out(cleanup_old_results, RESULT_CLEANUP_INTERVAL);
}

/**
 * 获取队列状态
 */
mapping query_queue_status()
{
    mapping m = ([ ]);
    m["active_queues"] = sizeof(user_request_queues);
    m["processing"] = sizeof(queue_processing);
    m["cached_results"] = sizeof(request_results);
    m["dispatch_mode"] = "event_driven";
    m["tick_count"] = queue_tick_count;
    m["last_tick"] = queue_last_tick;
    m["max_user_queue_size"] = queue_max_user_size;

    m["queues"] = ({});
    array users = indices(user_request_queues);
    foreach(users, string userid) {
        array queue = user_request_queues[userid];
        m["queues"] += ({([
            "userid": userid,
            "queue_size": sizeof(queue),
            "processing": queue_processing[userid] || 0
        ])});
    }

    return m;
}
