/**
 * ========================================================================
 * HTTP API Daemon - Vue UI Backend (Adapted for xiand)
 * ========================================================================
 *
 * 提供Vue前端与MUD游戏服务器之间的HTTP API接口
 *
 * 架构：
 *   Vue Browser → HTTP API (8888) → Virtual Connection → MUD Game (5555)
 *
 * 模块化设计：
 *   - config.pike: 配置常量
 *   - utils.pike: 工具函数
 *   - virtual_conn.pike: 虚拟连接池
 *   - auth.pike: 认证功能
 *   - command_queue.pike: 异步请求队列
 *   - html_renderer.pike: HTML渲染
 *   - rate_limit.pike: 速率限制
 *
 * ========================================================================
 * @author  Claude Code
 * @version 3.0.0 (Modular Refactor - xiand)
 * @since   2024
 * ========================================================================
 */

#include <globals.h>
#include <lowlib.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

// ========================================================================
// HTTP API 日志函数 (必须在 include 之前定义)
// ========================================================================

/** HTTP API 调试开关：1=启用日志(werror输出), 0=关闭日志 */
constant HTTP_API_DEBUG = 1;

/**
 * HTTP API 专用日志函数 - 根据调试开关输出
 * @param fmt 格式化字符串
 * @param args ... 参数
 */
void http_werror(string fmt, mixed ... args)
{
    if(HTTP_API_DEBUG) {
        werror("[HTTP_API]" + sprintf(fmt, @args));
    }
}

// ========================================================================
// 导入模块
// ========================================================================

#include "_http_api_mod/config.pike"
#include "_http_api_mod/utils.pike"
#include "_http_api_mod/virtual_conn.pike"
#include "_http_api_mod/auth.pike"
#include "_http_api_mod/command_queue.pike"
#include "_http_api_mod/thread_manager.pike"
#include "_http_api_mod/html_renderer.pike"
#include "_http_api_mod/rate_limit.pike"

// ========================================================================
// 全局变量
// ========================================================================

/** HTTP服务器端口对象 */
Protocols.HTTP.Server.Port http_port;

/** API只读模式 */
int api_only_mode = 1;

/** HTTP API 登录待定标记 - 用于 login_check.pike 检测是否为 HTTP API 模式 */
mapping(string:int) http_api_login_pending = ([]);

// 设置 HTTP API 登录标记
void set_http_api_login_pending(string userid, int value) {
    http_api_login_pending[userid] = value;
}

// 查询 HTTP API 登录标记
int query_http_api_login_pending(string userid) {
    return http_api_login_pending[userid] || 0;
}

// 清除 HTTP API 登录标记
void clear_http_api_login_pending(string userid) {
    m_delete(http_api_login_pending, userid);
}

// ========================================================================
// 经验加成配置查询
// ========================================================================

/**
 * 查询 HTTP API 经验加成是否启用
 * @return 1=启用, 0=禁用
 */
int query_exp_bonus_enabled() {
    return HTTP_API_EXP_BONUS_ENABLED;
}

/**
 * 查询 HTTP API 经验加成倍率
 * @return 倍率 (100=原始, 150=1.5倍)
 */
int query_exp_bonus_rate() {
    return HTTP_API_EXP_BONUS_RATE;
}

// ========================================================================
// 初始化
// ========================================================================

protected void create()
{
    werror("========================================\n");
    werror("[HTTP_API] Daemon Loading...\n");
    werror("[HTTP_API] HTTP_PORT = %d\n", HTTP_PORT);
    werror("[HTTP_API] HTTP_API_DEBUG = %d\n", HTTP_API_DEBUG);
    werror("[HTTP_API] EXP_BONUS_ENABLED = %d\n", HTTP_API_EXP_BONUS_ENABLED);
    werror("[HTTP_API] EXP_BONUS_RATE = %d%%\n", HTTP_API_EXP_BONUS_RATE);
    werror("[HTTP_API] ROOT = %s\n", ROOT);
    werror("[HTTP_API] SROOT = %s\n", SROOT);
    werror("========================================\n");

    call_out(start_server, 5);
    // 定期清理
    call_out(cleanup_rate_limits, 60);
    call_out(cleanup_idle_connections, 60);
    // 启动队列处理
    call_out(start_worker_thread, 10);
    call_out(process_user_queues, QUEUE_CHECK_INTERVAL / 1000);
}

void start_server()
{
    werror("[HTTP_API] start_server() called, http_port=%O\n", http_port);
    if(http_port) {
        werror("[HTTP_API] Server already running!\n");
        return;
    }

    werror("[HTTP_API] Creating HTTP.Server.Port on 0.0.0.0:%d\n", HTTP_PORT);
    mixed err = catch {
        http_port = Protocols.HTTP.Server.Port(handle_request, HTTP_PORT, "0.0.0.0");
    };

    if(err) {
        werror("[HTTP_API] ERROR starting server: %O\n", err);
    } else {
        werror("[HTTP_API] Successfully started on port %d\n", HTTP_PORT);
        werror("[HTTP_API] Listening on http://0.0.0.0:%d\n", HTTP_PORT);
        werror("[HTTP_API] API Endpoints available:\n");
        werror("[HTTP_API]   - GET  /health\n");
        werror("[HTTP_API]   - GET  /api/partitions\n");
        werror("[HTTP_API]   - GET  /api/challenge\n");
        werror("[HTTP_API]   - POST /api/login\n");
        werror("[HTTP_API]   - GET  /api (execute command)\n");
        werror("========================================\n");
    }
}

void set_api_only_mode(int mode)
{
    api_only_mode = mode;
}

// ========================================================================
// 命令执行系统
// ========================================================================

/**
 * 执行系统级命令
 */
string execute_system_command(string cmd)
{
    http_werror(" execute_system: %s\n", cmd);

    string output = "";
    array args = cmd / " ";
    string cmd_name = args[0];

    string cmd_file = ROOT + "/gamelib/cmds/" + cmd_name + ".pike";
    object cmd_obj = load_object(cmd_file);

    if(cmd_obj) {
        mixed err = catch {
            mixed result = cmd_obj->main(cmd[sizeof(cmd_name)..]);
            if(stringp(result)) {
                output += result;
            }
        };
        if(err) {
            http_werror(" System command error: %s\n", describe_error(err));
            output += "命令执行错误\n";
        }
    } else {
        output += "未知系统命令: " + cmd_name + "\n";
    }

    return output;
}

/**
 * 执行内部命令 (通过玩家的command方法)
 */
string execute_internal_command(object player, string cmd)
{
    // http_werror(" execute_internal: %s\n", cmd);

    // 解析命令
    string first_word = cmd;
    string target_arg = "";
    int space_pos = search(cmd, " ");
    if(space_pos > 0) {
        first_word = cmd[0..space_pos-1];
        target_arg = cmd[space_pos+1..];
    }

    // 保存原始this_player
    object original_this_player = this_player();
    set_this_player(player);

    // 创建虚拟连接对象来捕获输出
    object buffer_conn = BufferConnection();

    // xiand: 使用绝对路径加载 CONND
    object connd = find_object(SROOT + "/connd.pike");
    if(!connd) {
        connd = load_object(SROOT + "/connd.pike");
    }

    // 保存原始连接并设置虚拟连接
    object original_conn = connd->query_conn(player);
    connd->set_conn(player, buffer_conn);

    // 直接调用command()
    mixed err = catch {
        player->command(cmd);
        // http_werror(" command() executed\n");
    };

    // 获取命令输出
    string output_buffer = buffer_conn->get_output();

    // 恢复原始连接
    connd->set_conn(player, original_conn);
    set_this_player(original_this_player);

    if(err) {
        http_werror(" Command error: %s\n", describe_error(err));
        output_buffer += "命令执行错误\n";
    }

    // http_werror(" Captured output: %d bytes\n", sizeof(output_buffer));

    // 如果没有捕获到输出，生成默认输出
    if(sizeof(output_buffer) == 0) {
        if((first_word == "look" || first_word == "l") && sizeof(target_arg) > 0) {
            output_buffer = get_target_info(player, target_arg);
        } else {
            output_buffer = get_room_info(player);
        }
        // http_werror(" Generated output: %d bytes\n", sizeof(output_buffer));
    }

    return output_buffer;
}

/**
 * 获取目标对象信息
 */
string get_target_info(object player, string target_name)
{
    string output = "";
    object room = environment(player);
    mixed target;

    if(!room) {
        return "你处于虚空中。\n[返回:look]";
    }

    array inv = all_inventory(room);
    foreach(inv, object ob) {
        if(ob == player) continue;
        string ob_name = functionp(ob->query_name) ? ob->query_name() : "";
        if(ob_name == target_name) {
            target = ob;
            break;
        }
        if(functionp(ob->query_name_cn) && ob->query_name_cn() == target_name) {
            target = ob;
            break;
        }
        if(functionp(ob->query_short)) {
            string short_name = ob->query_short();
            if(search(short_name, target_name) >= 0) {
                target = ob;
                break;
            }
        }
    }

    if(!target) {
        return sprintf("这里没有 %s。\n[返回:look]", target_name);
    }

    string name = "";
    if(functionp(target->query_short)) {
        name = target->query_short();
    } else if(functionp(target->query_name_cn)) {
        name = target->query_name_cn();
    } else {
        name = target_name;
    }
    output += name + "\n";

    if(functionp(target->query_long)) {
        string long_desc = target->query_long();
        if(long_desc && sizeof(long_desc) > 0) {
            output += long_desc + "\n";
        }
    }
    if(functionp(target->query_desc)) {
        string desc = target->query_desc();
        if(desc && sizeof(desc) > 0) {
            output += desc + "\n";
        }
    }

    int is_npc = 0;
    if(functionp(target->attack) || functionp(target->kill) ||
       (target->query_hp && functionp(target->query_hp))) {
        is_npc = 1;
    }

    output += "\n";
    if(is_npc) {
        output += "[切磋:" + target_name + "]\n";
        output += "[杀戮:" + target_name + "]\n";
    }
    output += "[返回:look]";

    return output;
}

/**
 * 获取房间信息
 */
string get_room_info(object player)
{
    string output = "";
    object room = environment(player);

    if(!room) {
        return "你处于虚空中...\n";
    }

    if(functionp(room->query_short)) {
        output += room->query_short() + "\n";
    }

    if(functionp(room->query_desc)) {
        string desc = room->query_desc();
        if(desc && sizeof(desc) > 0) {
            output += desc + "\n";
        }
    }
    else if(functionp(room->query_long)) {
        output += room->query_long() + "\n";
    }

    if(functionp(room->query_exits)) {
        mapping exits = room->query_exits();
        if(exits && sizeof(exits) > 0) {
            output += "\n";
            foreach(indices(exits), string dir) {
                output += sprintf("[%s:go %s]", dir, dir);
            }
        }
    }

    array inv = all_inventory(room);
    if(sizeof(inv) > 1) {
        output += "\n\n";
        foreach(inv, object ob) {
            if(ob != player && functionp(ob->query_short)) {
                string name = ob->query_short();
                if(name) {
                    string cmd_name = name;
                    if(functionp(ob->query_name)) {
                        string ob_name = ob->query_name();
                        if(ob_name && sizeof(ob_name) > 0) {
                            cmd_name = ob_name;
                        }
                    }
                    output += sprintf("[%s:look %s]", name, cmd_name);
                }
            }
        }
    }

    return output;
}

/**
 * 登录并执行命令 (主入口函数)
 *
 * 线程路由策略:
 * - 因果类命令: 主线程单队列执行 (战斗、交易等)
 * - 非因果命令: 用户独立线程执行 (look、score等，并行不互斥)
 */
string execute_command(string userid, string password, string cmd)
{
    // 使用线程管理器路由执行
    return route_and_execute(userid, password, cmd);
}

// ========================================================================
// 同步版本的命令执行函数 (供线程管理器调用)
// ========================================================================

/**
 * 同步执行命令 (用于核心命令主线程执行)
 */
string execute_command_sync(string userid, string password, string cmd)
{
    // http_werror(" execute_command_sync: %s for %s\n", cmd, userid);

    // 立即更新连接活跃时间 - 确保活跃用户不会被踢出
    update_connection_time(userid);

    mixed err = catch {
        // 检查是否已有虚拟连接
        object player = get_player_from_connection(userid);
        if(player) {
            return execute_internal_command(player, cmd);
        }

        // 设置 HTTP API 登录标记（让 login_check 知道这是 HTTP API 模式）
        set_http_api_login_pending(userid, 1);

        // 生成 session ID
        string session_id = sprintf("%d", time());

        // 调用 login_check 进行完整登录（包含密码验证和 setup）
        // login_check 会：
        // 1. 验证密码
        // 2. 创建/找到玩家对象
        // 3. 调用 setup()
        // 4. 检查 http_api_login_pending 标记，跳过 exec()
        // 5. 将玩家存入虚拟连接池
        string login_arg = sprintf("gamelib %s %s %s", userid, password, session_id);
        object login_cmd = load_object(ROOT + "/lowlib/system/cmds/login_check.pike");
        if(login_cmd) {
            login_cmd->main(login_arg);
        }

        // 清除登录标记
        clear_http_api_login_pending(userid);

        // 从虚拟连接池获取登录后的玩家
        player = get_player_from_connection(userid);

        if(!player) {
            return "{\"error\":\"登录失败\"}";
        }

        return execute_internal_command(player, cmd);
    };

    // 清除登录标记（即使出错也要清除）
    clear_http_api_login_pending(userid);

    if(err) {
        http_werror(" execute_command_sync error: %s\n", describe_error(err));
        return "{\"error\":\"命令执行失败: " + replace(describe_error(err), "\n", " ") + "\"}";
    }
}

/**
 * 同步执行内部命令 (供用户线程调用)
 * 支持创建玩家对象（如果不存在）
 */
string execute_internal_command_sync(string userid, string password, string cmd)
{
    // http_werror(" execute_internal_command_sync: %s for %s\n", cmd, userid);

    object player = get_player_from_connection(userid);
    if(!player && password && password != "") {
        // 设置 HTTP API 登录标记（让 login_check 知道这是 HTTP API 模式）
        set_http_api_login_pending(userid, 1);

        // 生成 session ID
        string session_id = sprintf("%d", time());

        // 调用 login_check 进行完整登录
        string login_arg = sprintf("gamelib %s %s %s", userid, password, session_id);
        object login_cmd = load_object(ROOT + "/lowlib/system/cmds/login_check.pike");
        if(login_cmd) {
            login_cmd->main(login_arg);
        }

        // 清除登录标记
        clear_http_api_login_pending(userid);

        // 从虚拟连接池获取登录后的玩家
        player = get_player_from_connection(userid);
    }

    if(!player) {
        return "{\"error\":\"未登录\"}";
    }

    return execute_internal_command(player, cmd);
}

// ========================================================================
// HTTP路由
// ========================================================================

void handle_request(Protocols.HTTP.Server.Request req)
{
    string path = req->not_query;
    string method = req->request_type;

    // http_werror(" %s %s from %s\n", method, path, req->remote_addr || "unknown");

    mixed err = catch {
        // CORS预检
        if(method == "OPTIONS") {
            send_cors(req);
            return;
        }

        // API路由分发
        switch(path) {
            case "/api":
                handle_api(req);
                break;
            case "/api/partitions":
                handle_api_partitions(req);
                break;
            case "/api/challenge":
                handle_api_challenge(req);
                break;
            case "/api/status":
                handle_api_status(req);
                break;
            case "/api/autofight":
                handle_api_autofight(req);
                break;
            case "/api/async":
                handle_api_async(req);
                break;
            case "/api/result":
                handle_api_result(req);
                break;
            case "/api/chat/messages":
                handle_api_chat_messages(req);
                break;
            case "/api/chat/send":
                handle_api_chat_send(req);
                break;
            case "/exits":
                handle_exits(req);
                break;
            case "/room":
                handle_room(req);
                break;
            case "/health":
                mapping m = ([ "status": "ok", "time": time(), "port": HTTP_PORT ]);
                send_json(req, m);
                break;
            case "/":
                if(api_only_mode) {
                    mapping info = ([ "message": "HTTP API Server", "api": "/api", "health": "/health" ]);
                    send_json(req, info);
                } else {
                    serve_file(req, "web/web_vue/index.html", "text/html");
                }
                break;
            default:
                // 处理 /api/html?xxx 格式
                if(search(path, "/api/html") == 0) {
                    handle_api_html(req);
                }
                // 处理 /api/json?xxx 格式 - 返回JSON供Vue前端解析
                else if(search(path, "/api/json") == 0) {
                    handle_api_json(req);
                }
                // 处理 /api/battle_status?xxx 格式 - 获取战斗状态（敌我双方）
                else if(search(path, "/api/battle_status") == 0) {
                    handle_api_battle_status(req);
                }
                // 处理 /api/performs?xxx 格式 - 获取可用招式列表
                else if(search(path, "/api/performs") == 0) {
                    handle_api_performs(req);
                }
                // 处理 /api/invite/seturl 格式 - 设置邀请URL
                else if(path == "/api/invite/seturl") {
                    handle_api_invite_seturl(req);
                }
                // translate.js 从 http_api 目录提供（始终允许，不受api_only_mode限制）
                else if(path == "/includes/translate.js") {
                    serve_file(req, "gamelib/single/d/http_api/translate.js", "application/javascript");
                }
                // 静态资源
                else if(search(path, "/css/") == 0 || search(path, "/js/") == 0) {
                    if(!api_only_mode) {
                        serve_file(req, "web/web_vue" + path, guess_type(path));
                    } else {
                        send_json(req, ([ "error": "API only mode" ]), 404);
                    }
                }
                // images 目录在 web/ 下
                else if(search(path, "/images/") == 0) {
                    if(!api_only_mode) {
                        serve_file(req, "web" + path, guess_type(path));
                    } else {
                        send_json(req, ([ "error": "API only mode" ]), 404);
                    }
                }
                else {
                    send_json(req, ([ "error": "Not found" ]), 404);
                }
                break;
        }
    };

    if(err) {
        http_werror(" Request error: %s\n", describe_error(err));
        // 检查对象是否已被析构，避免再次调用函数导致错误
        if(objectp(req)) {
            mixed send_err = catch {
                send_json(req, ([ "error": "Internal error" ]), 500);
            };
            if(send_err) {
                http_werror(" Failed to send error response: %s\n", describe_error(send_err));
            }
        }
    }
}

// ========================================================================
// API处理函数
// ========================================================================

void handle_api(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string userid = params["userid"];
    string password = params["password"];
    string cmd = params["cmd"];
    if(!cmd || cmd == "") cmd = "look";

    string auth_userid, auth_password;
    string challenge = params["challenge"];

    if(txd && txd != "" && txd != " ") {
        mapping auth = decode_txd(txd);
        if(!auth) {
            send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
            return;
        }
        auth_userid = auth["userid"];
        auth_password = auth["password"];

        // TXD 也需要验证密码
        string stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_json(req, ([ "error": "用户不存在" ]), 401);
            return;
        }
        if(auth_password != stored_password) {
            send_json(req, ([ "error": "用户名或密码错误" ]), 401);
            return;
        }
    }
    else if(userid && password && userid != "" && password != "") {
        auth_userid = userid;
        auth_password = password;

        // 密码验证
        string stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_json(req, ([ "error": "用户不存在" ]), 401);
            return;
        }
        // 如果有 challenge，使用 challenge 验证；否则直接比较明文密码
        if(challenge && sizeof(challenge) > 0) {
            if(!verify_password_hash(challenge, password, stored_password)) {
                send_json(req, ([ "error": "用户名或密码错误" ]), 401);
                return;
            }
        } else {
            if(password != stored_password) {
                send_json(req, ([ "error": "用户名或密码错误" ]), 401);
                return;
            }
        }
    }
    else {
        send_json(req, ([ "error": "缺少认证信息" ]), 400);
        return;
    }

    string response = execute_command(auth_userid, auth_password, cmd);

    if(!response) {
        send_json(req, ([ "error": "命令执行失败" ]), 500);
        return;
    }

    if(search(response, "登录错误") != -1 || search(response, "用户名不存在") != -1) {
        send_json(req, ([ "error": "用户名或密码错误" ]), 401);
        return;
    }

    mapping result = parse_response_to_json(response, auth_userid);
    send_json(req, result);
}

void handle_api_html(Protocols.HTTP.Server.Request req)
{
    http_werror("========== handle_api_html called! ==========\n");
    mapping params = get_params(req);
    http_werror("  params: %O\n", params);
    string txd = url_decode(params["txd"]);
    string userid = params["userid"];
    string password = params["password"];
    string cmd = params["cmd"];
    http_werror("  cmd=%s userid=%s\n", cmd || "none", userid || "none");
    if(!cmd || cmd == "") cmd = "look";

    string client_ip = req->remote_addr || "unknown";

    // 注册命令处理 - 直接实现注册逻辑（xiand没有login_regnew命令）
    if(search(cmd, "login_regnew ") == 0) {
        http_werror("=== REGISTER REQUEST ===\n");
        http_werror(" RAW CMD: %s\n", cmd);

        if(check_register_rate_limit(client_ip)) {
            http_werror(" RATE LIMIT EXCEEDED for IP: %s\n", client_ip);
            send_html_error(req, "注册尝试过于频繁，请稍后再试");
            return;
        }

        // 解析参数: Vue发送 login_regnew gamenv xd01username password sid challenge (6个部分)
        // JSP发送: login_regnew gamenv user password sid game_pre m_key userip userua (9个部分)
        // 先初始化所有变量为空字符串
        string projname = "", user_name = "", pswd = "", sid = "";
        string game_pre = "", m_key = "", userip = "", userua = "";
        string challenge = "";

        // 先尝试Vue格式（更常见，6个部分）
        int parse_result = sscanf(cmd, "login_regnew %s %s %s %s %s %s",
                                  projname, user_name, pswd, sid, challenge, game_pre);
        http_werror(" sscanf Vue format result: %d\n", parse_result);

        // 如果Vue格式解析失败（少于5个参数），尝试JSP格式（9个部分）
        if(parse_result < 5) {
            parse_result = sscanf(cmd, "login_regnew %s %s %s %s %s %s %s %s",
                                  projname, user_name, pswd, sid, game_pre, m_key, userip, userua);
            http_werror(" sscanf JSP format result: %d\n", parse_result);
        }

        http_werror(" projname=%s, user=%s, pswd_len=%d, sid=%s, game_pre=%s\n",
                    projname || "", user_name || "", sizeof(pswd), sid || "", game_pre || "");
        http_werror(" m_key=%s, userip=%s, userua=%s, challenge=%s\n",
                    m_key || "", userip || "", userua || "", challenge || "");

        if(parse_result >= 3) {
            // 解析用户名和分区前缀
            // Vue发送: tx01jinghaha152 (已含前缀), JSP发送: jinghaha152 (不含前缀，game_pre单独传)
            string game_fg = game_pre || "";  // 分区前缀如 xd01, tx01
            string actual_user = user_name;   // 实际用户名（不含前缀）

            // 如果user_name包含分区前缀(字母+2位数字)，提取出来
            string prefix = "";
            int num = 0;
            string rest = "";
            if(sscanf(user_name, "%[a-zA-Z]%d%s", prefix, num, rest) == 3 && sizeof(prefix) == 2 && num >= 1 && num <= 99) {
                // user_name包含前缀，如 tx01jinghaha152
                if(game_fg == "") {
                    game_fg = prefix + sprintf("%02d", num);
                }
                actual_user = rest;  // 实际用户名是去掉前缀的部分
            }

            http_werror(" Parsed: game_fg=%s, user_name=%s (len=%d), actual_user=%s (len=%d), password_len=%d\n",
                        game_fg, user_name, sizeof(user_name), actual_user, sizeof(actual_user), sizeof(pswd));

            // 构建完整用户名（含分区前缀）用于存储
            string full_username = game_fg + actual_user;
            http_werror(" Full username for storage: %s\n", full_username);

            // HTTP API 模式下直接实现注册逻辑
            // 注意：存储明文密码，登录时用challenge做哈希验证
            string result;
            string error_msg = "";  // 详细错误信息

            // 验证实际用户名长度（不含分区前缀）
            if(sizeof(actual_user) < 2) {
                http_werror(" VALIDATION FAILED: actual_user_len=%d (need >=2)\n", sizeof(actual_user));
                result = "error2";
                error_msg = "用户名过短，最少2个字符";
            } else if(sizeof(actual_user) > 12) {
                http_werror(" VALIDATION FAILED: actual_user_len=%d (need <=12)\n", sizeof(actual_user));
                result = "error2";
                error_msg = "用户名过长，最多12个字符（当前" + sizeof(actual_user) + "个）";
            } else if(sizeof(pswd) < 2) {
                http_werror(" VALIDATION FAILED: password_len=%d (need >=2)\n", sizeof(pswd));
                result = "error2";
                error_msg = "密码过短，最少2个字符";
            } else {
                // 检查用户名只包含字母数字（检查实际用户名，不含前缀）
                int valid_name = 1;
                for(int i = 0; i < sizeof(actual_user); i++) {
                    int c = actual_user[i];
                    if(!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))) {
                        http_werror(" INVALID CHAR at position %d: %c (%d)\n", i, c, c);
                        valid_name = 0;
                        break;
                    }
                }
                if(!valid_name) {
                    http_werror(" VALIDATION FAILED: invalid characters in actual_user\n");
                    result = "error2";
                    error_msg = "用户名只能包含字母和数字";
                } else {
                    // full_username已在上面定义: game_fg + actual_user
                    // 检查用户是否已存在 - 使用 gamelib 路径
                    string user_file_path = ROOT + "/gamelib/u/" + full_username[sizeof(full_username)-2..] + "/" + full_username + ".o";
                    http_werror(" Checking user file: %s\n", user_file_path);
                    string existing_user = Stdio.read_file(user_file_path);

                    if(existing_user) {
                        // 用户已存在
                        http_werror(" User already exists: %s\n", full_username);
                        result = "error1";
                        error_msg = "用户名已存在";
                    } else {
                        // 检查内存中是否有在线用户
                        http_werror(" Checking if user in memory...\n");
                        object user_in_memory = find_player(full_username);
                        if(user_in_memory) {
                            http_werror(" User already in memory: %s\n", full_username);
                            result = "error1";
                            error_msg = "用户已在线";
                        } else {
                            // 创建新用户 - 直接创建用户文件
                            http_werror(" Creating new user...\n");
                            http_werror(" ROOT=%s\n", ROOT);

                            program u;
                            object m;

                            // 尝试加载 master.pike（如果失败则忽略）
                            http_werror(" Step 1: Loading master.pike...\n");
                            mixed master_err = catch {
                                m = (object)(ROOT + "/gamelib/master.pike");
                                http_werror(" master.pike loaded: %O\n", m);
                                if(m) http_werror(" master.pike functions: %O\n", indices(m));
                            };
                            if(master_err) {
                                http_werror(" master.pike load ERROR: %s\n", describe_error(master_err));
                            }

                            http_werror(" Step 2: Getting user program...\n");
                            if(m && functionp(m->connect)) {
                                http_werror(" Found master->connect function\n");
                                u = m->connect();
                                http_werror(" Using master.pike->connect(): %O\n", u);
                            }
                            if(!u) {
                                http_werror(" No master->connect, loading user.pike directly...\n");
                                mixed user_prog_err = catch {
                                    u = (program)(ROOT + "/gamelib/clone/user.pike");
                                    http_werror(" Using user.pike: %O\n", u);
                                };
                                if(user_prog_err) {
                                    http_werror(" user.pike load ERROR: %s\n", describe_error(user_prog_err));
                                }
                            }

                            if(!u) {
                                http_werror(" FATAL: Cannot load user program!\n");
                                result = "error2";
                                error_msg = "系统错误: 无法加载用户程序";
                            } else {
                                http_werror(" Step 3: Creating user instance...\n");
                                mixed err = catch {
                                    object me = u();
                                    http_werror(" user object created: %O\n", me);
                                    if(!me) {
                                        http_werror(" FATAL: u() returned NULL!\n");
                                        result = "error2";
                                        error_msg = "系统错误: 无法创建用户对象";
                                    } else {
                                        http_werror(" Step 4: Setting user properties...\n");

                                        http_werror("  Calling set_name(%s)...\n", full_username);
                                        me->set_name(full_username);

                                        http_werror("  Calling set_password()...\n");
                                        me->set_password(pswd);

                                        http_werror("  Calling set_project(%s)...\n", projname || "gamelib");
                                        me->set_project(projname || "gamelib");

                                        http_werror("  Calling set_userip(%s)...\n", client_ip);
                                        me->set_userip(client_ip);

                                        // 初始化必要字段，避免 query_desc() 出错
                                        http_werror("  Initializing basic fields...\n");
                                        if(!me->sid) {
                                            me->sid = sid || "tmpUser";
                                            http_werror("  Initialized sid: %s\n", sid || "tmpUser");
                                        }

                                        http_werror(" Step 5: Calling setup()...\n");
                                        mixed setup_err = catch {
                                            if(me->setup(pswd)) {
                                                // 注册成功
                                                http_werror("  setup() returned SUCCESS\n");
                                                if(environment(me) == 0) {
                                                    http_werror("  Moving to LOW_VOID_OB...\n");
                                                    me->move(LOW_VOID_OB);
                                                }

                                                // 保存用户档案到文件
                                                http_werror("  Saving user file...\n");
                                                if(functionp(me->save)) {
                                                    me->save();
                                                    http_werror("  User file saved successfully\n");
                                                }

                                                http_werror(" Registration SUCCESS: %s\n", full_username);
                                                result = actual_user + "," + pswd;  // 返回不含前缀的用户名
                                            } else {
                                                http_werror("  setup() returned FALSE\n");
                                                result = "error2";
                                                error_msg = "用户初始化失败";
                                            }
                                        };
                                        if(setup_err) {
                                            http_werror("  setup() EXCEPTION: %s\n", describe_error(setup_err));
                                            result = "error2";
                                            error_msg = "用户初始化异常: " + describe_error(setup_err);
                                        }
                                    }
                                };
                                if(err) {
                                    http_werror(" User creation EXCEPTION: %s\n", describe_error(err));
                                    result = "error2";
                                    error_msg = "创建用户异常: " + describe_error(err);
                                }
                            }
                        }
                    }
                }
            }

            http_werror(" Registration result: %s, error_msg: %s\n", result, error_msg);

            // 返回注册结果 - 格式: result 或 result,error_msg
            string response_data = result;
            if(error_msg && sizeof(error_msg) > 0) {
                response_data = result + "," + error_msg;
            }
            string html = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>注册</title></head><body><div>" + response_data + "</div></body></html>";
            mapping resp = ([ ]);
            resp["type"] = "text/html; charset=UTF-8";
            resp["data"] = html;
            resp["error"] = 200;
            resp["extra_heads"] = (["cache-control": "no-cache", "Access-Control-Allow-Origin": "*"]);
            req->response_and_finish(resp);
            return;
        }

        // 参数格式错误或加载失败
        http_werror(" Registration FAILED: invalid parameters (sscanf returned %d, need >=3)\n", parse_result);
        send_html_error(req, "error2");
        return;
    }

    // 认证
    string auth_userid, auth_password;
    string challenge = params["challenge"];

    if(txd && txd != "" && txd != " ") {
        mapping auth = decode_txd(txd);
        if(!auth) {
            send_html_error(req, "TXD认证信息无效");
            return;
        }
        auth_userid = auth["userid"];
        auth_password = auth["password"];

        // TXD 也需要验证密码
        string stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_html_error(req, "用户不存在");
            return;
        }
        if(auth_password != stored_password) {
            send_html_error(req, "用户名或密码错误");
            return;
        }
    }
    else if(userid && password && userid != "" && password != "") {
        auth_userid = userid;
        auth_password = password;

        // 密码验证
        string stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_html_error(req, "用户不存在");
            return;
        }
        // 如果有 challenge，使用 challenge 验证；否则直接比较明文密码
        if(challenge && sizeof(challenge) > 0) {
            if(!verify_password_hash(challenge, password, stored_password)) {
                send_html_error(req, "用户名或密码错误");
                return;
            }
        } else {
            // 没有 challenge 时，直接比较明文密码
            if(password != stored_password) {
                send_html_error(req, "用户名或密码错误");
                return;
            }
        }
    }
    else {
        send_html_error(req, "缺少认证信息");
        return;
    }

    // 登录速率限制
    int is_login_attempt = (!txd || txd == "" || txd == " ");
    if(is_login_attempt) {
        if(check_login_rate_limit(client_ip)) {
            send_html_error(req, "登录尝试过于频繁，请稍后再试");
            return;
        }
    }

    // 解码命令
    int hidden_index;
    string input;
    if(sscanf(cmd, "%d %s", hidden_index, input) == 2) {
        string base_cmd = unhide_command(auth_userid, (string)hidden_index);
        cmd = base_cmd + " " + input;
    } else {
        cmd = unhide_command(auth_userid, cmd);
    }

    string response = execute_command(auth_userid, auth_password, cmd);

    if(!response) {
        if(is_login_attempt) record_login_failure(client_ip);
        send_html_error(req, "命令执行失败");
        return;
    }

    int login_success = 0, login_failed = 0;
    if(is_login_attempt) {
        if(search(response, "登录错误") != -1 || search(response, "用户名不存在") != -1) {
            login_failed = 1;
        } else if(search(response, "error") == -1 && sizeof(response) > 10) {
            login_success = 1;
        }
    }

    if(login_failed) {
        record_login_failure(client_ip);
    } else if(login_success) {
        reset_login_failures(client_ip);
    }

    string html = response_to_html(response, auth_userid, cmd);

    mapping resp = ([ ]);
    resp["type"] = "text/html; charset=UTF-8";
    resp["data"] = html;
    resp["error"] = 200;
    resp["extra_heads"] = (["cache-control": "no-cache", "Access-Control-Allow-Origin": "*"]);
    req->response_and_finish(resp);
}

// ========================================================================
// JSON API - 返回解析后的结构化数据供Vue前端渲染
// ========================================================================

void handle_api_json(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string userid = params["userid"];
    string password = params["password"];
    string cmd = params["cmd"];
    if(!cmd || cmd == "") cmd = "look";

    string client_ip = req->remote_addr || "unknown";

    // 认证
    string auth_userid, auth_password;
    string challenge = params["challenge"];

    if(txd && txd != "" && txd != " ") {
        mapping auth = decode_txd(txd);
        if(!auth) {
            send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
            return;
        }
        auth_userid = auth["userid"];
        auth_password = auth["password"];

        // TXD 也需要验证密码
        string stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_json(req, ([ "error": "用户不存在" ]), 401);
            return;
        }
        if(auth_password != stored_password) {
            send_json(req, ([ "error": "用户名或密码错误" ]), 401);
            return;
        }
    }
    else if(userid && password && userid != "" && password != "") {
        auth_userid = userid;
        auth_password = password;

        // 密码验证
        string stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_json(req, ([ "error": "用户不存在" ]), 401);
            return;
        }
        // 如果有 challenge，使用 challenge 验证；否则直接比较明文密码
        if(challenge && sizeof(challenge) > 0) {
            if(!verify_password_hash(challenge, password, stored_password)) {
                send_json(req, ([ "error": "用户名或密码错误" ]), 401);
                return;
            }
        } else {
            if(password != stored_password) {
                send_json(req, ([ "error": "用户名或密码错误" ]), 401);
                return;
            }
        }
    }
    else {
        send_json(req, ([ "error": "缺少认证信息" ]), 400);
        return;
    }

    // 解码隐藏命令（cmd可能是数字索引）
    string actual_cmd = unhide_command(auth_userid, cmd);

    // 执行命令
    string response = execute_command(auth_userid, auth_password, actual_cmd);

    // 生成新的 TXD - 使用存储的明文密码（因为 auth_password 可能是哈希）
    string stored_password = get_user_password(auth_userid);
    string new_txd = generate_txd(auth_userid, stored_password || auth_password);

    // 解析MUD输出为结构化数据
    array(mapping) lines = parse_mud_to_json(response, new_txd, auth_userid);

    // 检测复制命令
    string copy_data;
    string copy_type;
    if(search(response, "COPY_CODE:") != -1) {
        // 提取复制数据 - 只提取到行尾或UI按钮前
        sscanf(response, "%*sCOPY_CODE:%[^[ \n\r]", copy_data);
        copy_type = "code";
        // 从lines中移除这一行
        lines = filter(lines, lambda(mapping m) {
            string text = get_line_text(m);
            return search(text, "COPY_CODE:") == -1;
        });
    } else if(search(response, "COPY_LINK:") != -1) {
        // 提取复制数据 - 只提取到行尾或UI按钮前
        sscanf(response, "%*sCOPY_LINK:%[^[ \n\r]", copy_data);
        copy_type = "link";
        lines = filter(lines, lambda(mapping m) {
            string text = get_line_text(m);
            return search(text, "COPY_LINK:") == -1;
        });
    }

    // 构建响应
    mapping json_result = ([
        "lines": lines,
        "userid": auth_userid,
        "cmd": cmd,
        "txd": new_txd,
        "timestamp": time()
    ]);

    // 如果有复制数据，添加到响应中
    if(copy_data && sizeof(copy_data) > 0 && copy_type) {
        json_result->copy = (["type":copy_type, "data":copy_data]);
    }

    // 返回JSON格式
    send_json(req, json_result);
}

/**
 * 获取行的完整文本内容
 */
string get_line_text(mapping m)
{
    if(!m["segments"]) return "";

    string text = "";
    array segments = m["segments"];
    foreach(segments, mixed seg) {
        if(seg["type"] == "text") {
            if(seg["parts"]) {
                foreach(seg["parts"], mixed p) {
                    if(p["content"]) text += p["content"];
                }
            }
        } else if(seg["type"] == "button") {
            text += seg["label"] || "";
        }
    }
    return text;
}

/**
 * 解析MUD输出为结构化JSON数组
 * 每行是一个对象，包含type和content
 * 支持跨行表单：连续的 [string name:...] 输入框后跟 [submit label:cmd ...]
 */
array(mapping) parse_mud_to_json(string response, string txd, string userid)
{
    array(mapping) result = ({});

    if(!response) return result;

    array raw_lines = response / "\n";

    // 跨行表单状态追踪
    array(mapping) form_inputs = ({});     // 积累的输入框
    array(int) form_line_indices = ({});   // 包含输入框的行索引
    int in_form = 0;

    foreach(raw_lines, string line) {
        string original_line = line;
        line = String.trim_all_whites(line);

        // 去掉行尾的{数字}标记
        while(1) {
            int start = search(line, "{");
            if(start == -1) break;
            int end = search(line, "}", start);
            if(end == -1) break;
            string between = line[start+1..end-1];
            int is_all_digits = 1;
            for(int i = 0; i < sizeof(between); i++) {
                if(between[i] < '0' || between[i] > '9') {
                    is_all_digits = 0;
                    break;
                }
            }
            if(is_all_digits) {
                line = line[0..start-1] + line[end+1..];
            } else {
                break;
            }
        }

        if(!sizeof(line)) {
            result += ({(["type": "empty"])});
            continue;
        }

        // 先扫描行中是否有输入框或submit按钮
        int has_input = 0;
        int has_submit = 0;
        array(mapping) raw_segments = ({});

        int current = 0;
        while(current < sizeof(line)) {
            int start = search(line, "[", current);
            if(start == -1) break;
            int end = search(line, "]", start);
            if(end == -1) break;

            string bracket_content = line[start+1..end-1];
            mapping parsed = parse_bracket_content(bracket_content, txd, userid);

            if(parsed) {
                string ptype = parsed["type"];
                if(ptype == "input") {
                    has_input = 1;
                    raw_segments += ({parsed});
                }
                else if(ptype == "submit") {
                    has_submit = 1;
                    raw_segments += ({parsed});
                }
                else if(ptype != "skip") {
                    raw_segments += ({parsed});
                }
            }
            current = end + 1;
        }

        // 处理表单逻辑
        if(has_submit && in_form) {
            // 找到submit segment
            mapping submit_seg;
            foreach(raw_segments, mapping seg) {
                if(seg["type"] == "submit") {
                    submit_seg = seg;
                    break;
                }
            }

            if(submit_seg) {
                // 创建form-submit segment，包含所有积累的输入框
                mapping form_submit = ([
                    "type": "form-submit",
                    "label": submit_seg["label"],
                    "cmd": submit_seg["cmd"],
                    "inputs": form_inputs,
                    "class": submit_seg["class"] || "btn btn-outline-info btn-sm"
                ]);

                // 更新之前行中的输入框标记
                foreach(form_line_indices, int line_idx) {
                    if(result[line_idx] && result[line_idx]["segments"]) {
                        foreach(result[line_idx]["segments"], mapping seg) {
                            if(seg["type"] == "input") {
                                seg["inForm"] = 1;
                            }
                        }
                    }
                }

                // 当前行：添加form-submit和其他非input元素
                array final_segments = ({});
                foreach(raw_segments, mapping seg) {
                    if(seg["type"] == "submit") {
                        final_segments += ({form_submit});
                    } else if(seg["type"] != "input") {
                        final_segments += ({seg});
                    }
                }
                result += ({(["type": "line", "segments": final_segments])});

                // 重置表单状态
                form_inputs = ({});
                form_line_indices = ({});
                in_form = 0;
            }
        }
        else if(has_input) {
            // 有输入框，加入表单状态
            array final_segments = ({});
            foreach(raw_segments, mapping seg) {
                if(seg["type"] == "input") {
                    mapping input_seg = ([
                        "type": "input",
                        "name": seg["name"],
                        "default": seg["default"] || "",
                        "width": seg["width"] || "",
                        "isPassword": seg["isPassword"] || 0,
                        "inForm": 0,  // 后续有submit时会改成1
                        "txd": txd
                    ]);
                    final_segments += ({input_seg});
                    form_inputs += ({input_seg});
                    in_form = 1;
                } else {
                    final_segments += ({seg});
                }
            }

            int line_idx = sizeof(result);
            result += ({(["type": "line", "segments": final_segments])});
            form_line_indices += ({line_idx});
        }
        else {
            // 普通行，使用原有解析
            array segments = parse_line_segments(line, txd, userid);
            result += ({(["type": "line", "segments": segments])});
        }
    }

    // 如果仍有未提交的表单输入，显示独立确定按钮
    if(in_form && sizeof(form_inputs) > 0) {
        foreach(form_line_indices, int line_idx) {
            if(result[line_idx] && result[line_idx]["segments"]) {
                foreach(result[line_idx]["segments"], mapping seg) {
                    if(seg["type"] == "input") {
                        seg["inForm"] = 0;
                    }
                }
            }
        }
    }

    return result;
}

/**
 * 解析一行中的多个段落
 */
array(mapping) parse_line_segments(string line, string txd, string userid)
{
    array(mapping) segments = ({});
    int current = 0;

    while(current < sizeof(line)) {
        int start = search(line, "[", current);
        if(start == -1) {
            if(current < sizeof(line)) {
                string text = line[current..];
                segments += ({parse_text_segment(text)});
            }
            break;
        }
        if(start > current) {
            string text = line[current..start-1];
            segments += ({parse_text_segment(text)});
        }
        int end = search(line, "]", start);
        if(end == -1) {
            segments += ({parse_text_segment(line[start..])});
            break;
        }

        string bracket_content = line[start+1..end-1];
        mapping parsed = parse_bracket_content(bracket_content, txd, userid);
        if(parsed && parsed["type"] != "skip") {
            segments += ({parsed});
        }
        // else: parsed是0或type是"skip"时，完全跳过不渲染
        // 不要将submit按钮转换为文本显示
        current = end + 1;
    }

    return segments;
}

/**
 * 解析文本段落（处理颜色代码）
 */
mapping parse_text_segment(string text)
{
    if(!sizeof(text)) return 0;

    array(mapping) parts = ({});
    int i = 0;

    while(i < sizeof(text)) {
        // 检查颜色代码 § (0xc2 0xa7 in UTF-8)
        if(i < sizeof(text) - 2 && (text[i] & 0xff) == 0xc2 && (text[i+1] & 0xff) == 0xa7) {
            int color_code = text[i+2] & 0xff;
            string color_class = "";

            switch(color_code) {
                case 0x30: color_class = "color-black"; break;
                case 0x31: color_class = "color-red-bold"; break;
                case 0x32: color_class = "color-green-bold"; break;
                case 0x33: color_class = "color-blue-bold"; break;
                case 0x34: color_class = "color-cyan-bold"; break;
                case 0x35: color_class = "color-purple-bold"; break;
                case 0x36: color_class = "color-orange-bold"; break;
                case 0x37: color_class = "color-gray"; break;
                case 0x38: color_class = "color-dark-gray"; break;
                case 0x39: color_class = "color-light-gray"; break;
                // 小写字母颜色码 (WAPMUD扩展)
                case 0x61: color_class = "color-red"; break;      // a
                case 0x62: color_class = "color-green"; break;     // b
                case 0x63: color_class = "color-cyan"; break;      // c
                case 0x64: color_class = "color-purple"; break;    // d
                case 0x65: color_class = "color-yellow"; break;    // e
                case 0x66: color_class = "color-white"; break;     // f
                case 0x67: color_class = "color-gold"; break;      // g
                case 0x72: parts += ({(["type": "color-end"])}); i += 3; continue;  // r = reset
                case 0x78: color_class = "color-bold"; break;     // x
                default: i += 2; continue;
            }

            parts += ({(["type": "color-start", "class": color_class])});
            i += 3;
        }
        else if((text[i] & 0xff) >= 0 && (text[i] & 0xff) < 128) {
            int c = text[i];
            if(c == '&') {
                parts += ({(["type": "text", "content": "&amp;"])});
            } else {
                parts += ({(["type": "text", "content": sprintf("%c", c)])});
            }
            i++;
        }
        else {
            // UTF-8多字节字符
            int byte_count = 2;
            int first_byte = text[i] & 0xff;
            if((first_byte & 0xE0) == 0xC0) byte_count = 2;
            else if((first_byte & 0xF0) == 0xE0) byte_count = 3;
            else if((first_byte & 0xF8) == 0xF0) byte_count = 4;

            if(i + byte_count - 1 < sizeof(text)) {
                parts += ({(["type": "text", "content": text[i..i+byte_count-1]])});
                i += byte_count;
            } else {
                parts += ({(["type": "text", "content": text[i..]])});
                i = sizeof(text);
            }
        }
    }

    return (["type": "text", "parts": parts]);
}

/**
 * 解析方括号内容 [label:command] 等
 */
mapping parse_bracket_content(string content, string txd, string userid)
{
    string var_name, default_val, width, type, label, action_cmd;

    // 输入框 [类型 变量名:...] 或 [变量名:默认值...宽度]
    if(sscanf(content, "%s %s:..*%s...*%s", type, var_name, default_val, width) == 4 ||
       sscanf(content, "%s:..*%s...*%s", var_name, default_val, width) == 3) {
        return ([
            "type": "input",
            "name": var_name,
            "default": default_val,
            "width": width,
            "isPassword": (type == "passwd"),
            "txd": txd
        ]);
    }
    // submit按钮 [submit 确定:command ...] - 返回submit类型用于表单处理
    else if(search(content, "submit ") == 0) {
        // 解析: submit 标签:命令 ...
        string submit_label, submit_cmd;
        if(sscanf(content, "submit %s:%s ...", submit_label, submit_cmd) == 2) {
            string css_class = get_button_css_class(submit_label);
            return ([
                "type": "submit",
                "label": submit_label,
                "cmd": submit_cmd,
                "class": css_class
            ]);
        }
        // 解析失败则跳过
        return (["type": "skip"]);
    }
    else if(sscanf(content, "%s %s:...", type, var_name) == 2) {
        // 特殊处理word输入框：如果是"word"，返回cmd-input类型
        // 因为bc_confirm.pike需要word参数，格式是"word=xxx"
        if(var_name == "word") {
            http_werror("[DEBUG] word input detected, using cmd-input type\n");
            return ([
                "type": "cmd-input",
                "name": var_name,
                "cmd": "bc_confirm",
                "txd": txd,
                "placeholder": "请输入您想说的话"
            ]);
        }
        return ([
            "type": "input",
            "name": var_name,
            "default": "",
            "width": "",
            "isPassword": (type == "passwd" || type == "password"),
            "txd": txd
        ]);
    }
    // 检查是否以 ":..." 结尾 (Pike没有has_suffix函数)
    else if(search(content, ":") > 0 && sizeof(content) >= 4 && content[sizeof(content)-4..] == ":...") {
        int colon_pos = search(content, ":");
        string cmd_name = content[0..colon_pos-1];
        return ([
            "type": "cmd-input",
            "cmd": cmd_name,
            "txd": txd
        ]);
    }
    // 处理 [类型:变量名: ...] 格式（如 [string:manage_userMain ...]）
    // 检查是否以 " ...]" 结尾
    else if(sizeof(content) >= 6 && content[sizeof(content)-6..] == " ...]") {
        // 去掉开头的 [ 和结尾的: ...]
        string inner = content[1..sizeof(content)-6];  // 去掉 [ 和 : ...]
        // 查找第一个 : 分隔类型和变量名
        int colon_pos = search(inner, ":");
        if(colon_pos > 0) {
            type = inner[0..colon_pos-1];
            var_name = inner[colon_pos+1..];
            // 检查类型是否是已知的输入类型
            if(type == "string" || type == "passwd" || type == "password" ||
               type == "int" || type == "number" || type == "float") {
                return ([
                    "type": "input",
                    "name": var_name,
                    "default": "",
                    "width": "",
                    "isPassword": (type == "passwd" || type == "password"),
                    "txd": txd
                ]);
            }
        }
        // 如果不是 [类型:变量名: ...] 格式，回退到原来的 cmd-input 处理
        string cmd_name = content[0..sizeof(content)-5];
        return ([
            "type": "cmd-input",
            "cmd": cmd_name,
            "txd": txd
        ]);
    }
    // 处理 类型:变量名 ... 格式（如 string:manage_userMain ...）
    // 注意：这里content没有方括号，已经被strip掉了
    // 检查是否以 " ..." 结尾
    else if(sizeof(content) >= 4 && content[sizeof(content)-4..] == " ...") {
        // 去掉结尾的 " ..."
        string prefix = content[0..sizeof(content)-4];
        // 检查是否是 类型:变量名 格式
        int colon_pos = search(prefix, ":");
        if(colon_pos > 0) {
            type = String.trim_all_whites(prefix[0..colon_pos-1]);
            var_name = String.trim_all_whites(prefix[colon_pos+1..]);
            // 检查类型是否是已知的输入类型
            if(type == "string" || type == "passwd" || type == "password" ||
               type == "int" || type == "number" || type == "float") {
                return (([
                    "type": "input",
                    "name": var_name,
                    "default": "",
                    "width": "",
                    "isPassword": (type == "passwd" || type == "password"),
                    "txd": txd
                ]));
            }
        }
        // 不是已知类型，回退到 cmd-input
        string cmd_name = String.trim_all_whites(prefix);
        return (([
            "type": "cmd-input",
            "cmd": cmd_name,
            "txd": txd
        ]));
    }
    else {
        int pos = search(content, ":");
        if(pos > 0) {
            label = content[0..pos-1];
            action_cmd = content[pos+1..];

            // 图片链接 [imgurl xxx:/images/...] 或 [miniimg xxx:/xd/images/...]
            // 支持任意第二部分，如: imgurl picture, imgurl loading, miniimg minipicture 等
            int is_imgurl = (search(label, "imgurl ") == 0);
            int is_miniimg = (search(label, "miniimg ") == 0);

            if(is_imgurl || is_miniimg) {
                // 提取图片路径
                string image_path = action_cmd;
                // 如果 action_cmd 以 picture: 或 loading: 等开头，去掉前缀
                int colon_in_path = search(image_path, ":");
                if(colon_in_path >= 0) {
                    image_path = image_path[colon_in_path+1..];
                }
                // 移除游戏前缀 /xd/ 或 /tx/ 等，转换为正确的Web路径
                // 例如: /xd/images/humanlike_male.gif -> /images/humanlike_male.gif
                if(sscanf(image_path, "/%*s/images/%s", string rest) == 2) {
                    image_path = "/images/" + rest;
                }
                return ([
                    "type": "image",
                    "src": image_path,
                    "alt": "图片"
                ]);
            }
            // URL链接 [url 显示文本:https://...]
            else if(search(label, "url ") == 0 &&
               (search(action_cmd, "http://") == 0 || search(action_cmd, "https://") == 0)) {
                return ([
                    "type": "url-link",
                    "text": label[4..],
                    "url": action_cmd
                ]);
            } else {
                // 普通按钮 - 处理标签中的颜色代码
                string hidden_cmd = hide_command(userid, action_cmd);
                string css_class = get_button_css_class(label);
                string processed_label = process_color_codes(label);
                return ([
                    "type": "button",
                    "label": processed_label,
                    "cmd": hidden_cmd,
                    "class": css_class
                ]);
            }
        }
    }

    return 0;
}

/**
 * 处理字符串中的颜色代码，返回HTML
 * 将 §X...§r 转换为 <span class="color-...">...</span>
 */
string process_color_codes(string text)
{
    if(!text || sizeof(text) == 0) return text;

    string result = "";
    int i = 0;
    string current_class = "";

    while(i < sizeof(text)) {
        // 检查颜色代码 § (0xc2 0xa7 in UTF-8)
        if(i < sizeof(text) - 2 && (text[i] & 0xff) == 0xc2 && (text[i+1] & 0xff) == 0xa7) {
            int color_code = text[i+2] & 0xff;

            // 先关闭之前的span
            if(sizeof(current_class) > 0) {
                result += "</span>";
                current_class = "";
            }

            string color_class = "";
            int is_reset = 0;

            switch(color_code) {
                case 0x30: color_class = "color-black"; break;
                case 0x31: color_class = "color-red-bold"; break;
                case 0x32: color_class = "color-green-bold"; break;
                case 0x33: color_class = "color-blue-bold"; break;
                case 0x34: color_class = "color-cyan-bold"; break;
                case 0x35: color_class = "color-purple-bold"; break;
                case 0x36: color_class = "color-orange-bold"; break;
                case 0x37: color_class = "color-gray"; break;
                case 0x38: color_class = "color-dark-gray"; break;
                case 0x39: color_class = "color-light-gray"; break;
                // 小写字母颜色码
                case 0x61: color_class = "color-red"; break;      // a
                case 0x62: color_class = "color-green"; break;     // b
                case 0x63: color_class = "color-cyan"; break;      // c
                case 0x64: color_class = "color-purple"; break;    // d
                case 0x65: color_class = "color-yellow"; break;    // e
                case 0x66: color_class = "color-white"; break;     // f
                case 0x67: color_class = "color-gold"; break;      // g
                case 0x72: is_reset = 1; break;                   // r = reset
                case 0x78: color_class = "color-bold"; break;     // x
                default: break;
            }

            if(is_reset) {
                // 重置颜色，不开启新span
            } else if(sizeof(color_class) > 0) {
                result += "<span class='" + color_class + "'>";
                current_class = color_class;
            }

            i += 3;
        }
        else {
            // 普通字符，需要转义HTML特殊字符
            int c = text[i] & 0xff;
            if(c == '&') {
                result += "&amp;";
                i++;
            } else if(c == '<') {
                result += "&lt;";
                i++;
            } else if(c == '>') {
                result += "&gt;";
                i++;
            } else if(c == '"') {
                result += "&quot;";
                i++;
            } else if(c == '\'') {
                result += "&#039;";
                i++;
            } else if((text[i] & 0xff) >= 0 && (text[i] & 0xff) < 128) {
                result += sprintf("%c", c);
                i++;
            } else {
                // UTF-8多字节字符
                int byte_count = 2;
                int first_byte = text[i] & 0xff;
                if((first_byte & 0xE0) == 0xC0) byte_count = 2;
                else if((first_byte & 0xF0) == 0xE0) byte_count = 3;
                else if((first_byte & 0xF8) == 0xF0) byte_count = 4;
                else if((first_byte & 0xC0) == 0x80) byte_count = 1;
                else byte_count = 2;

                if(i + byte_count <= sizeof(text)) {
                    result += text[i..i+byte_count-1];
                } else {
                    result += text[i..];
                }
                i += byte_count;
            }
        }
    }

    // 关闭未关闭的span
    if(sizeof(current_class) > 0) {
        result += "</span>";
    }

    return result;
}

// get_button_css_class 已移至 html_renderer.pike 模块

void handle_api_partitions(Protocols.HTTP.Server.Request req)
{
    string area = getenv("GAME_AREA");
    if(!area || area == "") area = "01";
    if(search(area, "xd") == 0) area = area[2..];

    int start_area, end_area;
    if(search(area, "-") > 0) {
        array(string) parts = area / "-";
        start_area = (int)parts[0];
        end_area = (int)parts[1];
    } else {
        start_area = (int)area;
        end_area = start_area;
    }

    array(mapping) partitions = ({});
    for(int i = start_area; i <= end_area; i++) {
        string zone_num = sprintf("%02d", i);
        partitions += ({([
            "value": "xd" + zone_num,
            "label": "原" + i + "区"
        ])});
    }

    send_json(req, ([
        "partitions": partitions,
        "game_area": getenv("GAME_AREA") || "01"
    ]));
}

void handle_api_challenge(Protocols.HTTP.Server.Request req)
{
    string salt = "";
    for(int i = 0; i < 32; i++) {
        int r = random(62);
        if(r < 26) salt += sprintf("%c", 'a' + r);
        else if(r < 52) salt += sprintf("%c", 'A' + r - 26);
        else salt += sprintf("%c", '0' + r - 52);
    }

    string timestamp = sprintf("%d", time());
    send_json(req, ([
        "challenge": salt + ":" + timestamp,
        "timestamp": (int)timestamp
    ]));
}

void handle_api_status(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 更新闲置时间 - 活跃用户不应被踢出
    update_connection_time(userid);
    object player = get_player_from_connection(userid, 0);

    // 如果虚拟连接池中没有，尝试从 find_player 获取
    if(!player) {
        player = find_player(userid);
    }

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    mapping result = query_player_state(player);
    send_json(req, result);
}

/**
 * 获取战斗状态 API
 * 返回玩家和敌人的状态信息
 */
void handle_api_battle_status(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 只读API：不更新闲置时间
    object player = get_player_from_connection(userid, 0);

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    // 获取玩家状态
    mapping player_state = query_player_state(player);
    player_state["userid"] = userid;

    // 查找敌人
    mapping enemy_state = ([]);

    // 方法1: 检查玩家是否在战斗中
    int in_combat = 0;
    if(functionp(player->query_in_combat)) {
        in_combat = player->query_in_combat();
    }

    if(!in_combat) {
        // 不在战斗中
        send_json(req, ([
            "in_battle": false,
            "player": player_state
        ]));
        return;
    }

    // 方法2: 获取房间中的所有对象，找到敌人的敌人
    object room = environment(player);
    if(!room) {
        send_json(req, ([
            "in_battle": true,
            "player": player_state,
            "enemy": 0
        ]));
        return;
    }

    // 获取房间中的所有生物
    array inv = all_inventory(room);
    object|zero enemy_obj = UNDEFINED;

    foreach(inv, object ob) {
        if(ob == player) continue;  // 跳过自己

        // 检查是否是生物
        if(functionp(ob->query_living) && ob->query_living()) {
            // 检查该对象是否在战斗中，且敌人是玩家
            if(functionp(ob->query_in_combat) && ob->query_in_combat()) {
                // 检查该对象的敌人是否是玩家
                // 通过检查该对象是否正在攻击玩家
                if(functionp(ob->query_attack_target)) {
                    if(ob->query_attack_target() == player) {
                        enemy_obj = ob;
                        break;
                    }
                }
            }
        }
    }

    // 如果没找到，尝试通过环境中的其他方式判断
    if(!enemy_obj) {
        // 检查房间中是否有其他玩家/NPC在战斗
        foreach(inv, object ob) {
            if(ob == player) continue;
            if(functionp(ob->is_npc) || functionp(ob->query_player)) {
                // 这是一个潜在敌人
                if(functionp(ob->query_in_combat) && ob->query_in_combat()) {
                    enemy_obj = ob;
                    break;
                }
            }
        }
    }

    if(enemy_obj) {
        // 获取敌人状态
        string e_name = "未知";
        if(functionp(enemy_obj->query_name)) {
            e_name = enemy_obj->query_name();
        }
        enemy_state["name"] = e_name;

        string e_name_cn = e_name;
        if(functionp(enemy_obj->query_name_cn)) {
            e_name_cn = enemy_obj->query_name_cn();
        }
        enemy_state["name_cn"] = e_name_cn;

        int e_is_npc = 1;
        if(functionp(enemy_obj->is_npc)) {
            e_is_npc = enemy_obj->is_npc();
        }
        enemy_state["is_npc"] = e_is_npc;

        // 获取敌人等级
        if(functionp(enemy_obj->query_level)) {
            enemy_state["level"] = enemy_obj->query_level();
        }

        // 获取敌人职业/种类
        if(functionp(enemy_obj->query_profeId)) {
            enemy_state["profe_id"] = enemy_obj->query_profeId();
        }
        if(functionp(enemy_obj->query_profe_cn)) {
            enemy_state["profe"] = enemy_obj->query_profe_cn(enemy_obj->query_profeId());
        }

        // 获取敌人种族
        if(functionp(enemy_obj->query_raceId)) {
            enemy_state["race_id"] = enemy_obj->query_raceId();
        }
        if(functionp(enemy_obj->query_race_cn)) {
            enemy_state["race"] = enemy_obj->query_race_cn(enemy_obj->query_raceId());
        }

        // 获取敌人攻击力
        if(functionp(enemy_obj->query_attack_power)) {
            enemy_state["attack"] = enemy_obj->query_attack_power();
        }

        // 获取敌人防御力
        if(functionp(enemy_obj->query_defend_power)) {
            enemy_state["defend"] = enemy_obj->query_defend_power();
        }

        // 获取敌人血量：使用 get_cur_life() 和 query_life_max()
        int e_hp = 0;
        int e_hp_max = 0;

        if(functionp(enemy_obj->get_cur_life)) {
            e_hp = enemy_obj->get_cur_life();
        }
        if(functionp(enemy_obj->query_life_max)) {
            e_hp_max = enemy_obj->query_life_max();
        }

        // -1 表示死亡，转为 0
        if(e_hp < 0) {
            e_hp = 0;
        }

        // 直接显示真实值
        enemy_state["hp"] = e_hp;
        enemy_state["hp_max"] = e_hp_max;
        enemy_state["is_dead"] = (e_hp <= 0);

        http_werror(" Enemy %s HP: %d/%d (is_npc=%d)\n",
                   e_name, e_hp, e_hp_max, e_is_npc);

        // 如果敌人是玩家，尝试获取userid
        if(!e_is_npc && functionp(enemy_obj->query_userid)) {
            enemy_state["userid"] = enemy_obj->query_userid();
        }
    }

    // http_werror(" battle_status response: in_battle=%d, enemy=%O\n", 1, enemy_obj ? enemy_state : 0);
    send_json(req, ([
        "in_battle": true,
        "player": player_state,
        "enemy": enemy_obj ? enemy_state : 0
    ]));
}

void handle_api_autofight(Protocols.HTTP.Server.Request req)
{
    if(req->request_type != "POST") {
        send_json(req, ([ "error": "只支持 POST 请求" ]), 405);
        return;
    }

    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string action = url_decode(params["action"] || "toggle");

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 用户主动操作：更新闲置时间
    object player = get_player_from_connection(userid, 1);

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    int new_state = 0;
    string current = player->query_autofight();

    if(action == "on" || (action == "toggle" && current != "enable")) {
        player->set_autofight("enable");
        new_state = 1;
    } else {
        player->set_autofight("disable");
        new_state = 0;
    }

    send_json(req, ([
        "autofight": new_state,
        "message": new_state ? "自动战斗已开启" : "自动战斗已关闭"
    ]));
}

/**
 * 获取可用招式列表 API
 * 通过执行 MUD 命令获取招式列表，兼容不同 MUD 实现
 */
void handle_api_performs(Protocols.HTTP.Server.Request req)
{
    mixed err = catch {
        mapping params = get_params(req);
        string txd = url_decode(params["txd"]);

        if(!txd || txd == "" || txd == " ") {
            send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
            return;
        }

        mapping auth = decode_txd(txd);
        if(!auth) {
            send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
            return;
        }

        string auth_userid = auth["userid"];
        string auth_password = auth["password"];

        // 执行 use_perform 命令获取技能列表（xiand使用use_perform）
        string response = execute_command(auth_userid, auth_password, "use_perform");

        // 生成新的 TXD - 使用存储的明文密码（因为 auth_password 可能是哈希）
        string stored_password = get_user_password(auth_userid);
        string new_txd = generate_txd(auth_userid, stored_password || auth_password);

        array performs_list = ({});
        string skill_name = "xiand";
        string skill_name_cn = "技能";
        int skill_level = 0;
        int in_combat = 0;

        // 检查是否在战斗中
        if(search(response, "察看战况") >= 0 || search(response, "fight") >= 0) {
            in_combat = 1;
        }

        // 解析 xiand 技能列表格式
        // 格式: □[技能名(1级/10%):use_perform skill_id] 或 □[技能名(2级):use_perform skill_id](冷却时间)
        array lines = response / "\n";

        foreach(lines, string line) {
            line = String.trim_all_whites(line);
            if(sizeof(line) == 0) continue;

            // 去掉行首的 □ 标记
            if(line[0] == 0 || line[0] == ' ') {
                line = String.trim_all_whites(line[1..]);
            }

            // 解析 xiand 技能格式: [技能名(1级/10%):use_perform skill_id]
            // 或: [技能名(2级):use_perform skill_id]
            // 或: [技能名:use_perform skill_id]
            string perform_name, perform_id;
            int level = 0;
            int exp_percent = 0;
            int cooling = 0;

            // 检查是否有冷却时间标记 (5s) 或 (3m)
            string clean_line = line;
            if(search(line, "秒") > 0 || search(line, "分") > 0 ||
               search(line, "s)") > 0 || search(line, "m)") > 0) {
                cooling = 1;
            }

            // 尝试匹配带等级和经验的格式: [技能名(1级/10%):use_perform skill_id]
            if(sscanf(line, "[%s(%d级/%d%%):use_perform %s]",
                       perform_name, level, exp_percent, perform_id) == 4) {
                perform_name = String.trim_all_whites(perform_name);
                perform_id = String.trim_all_whites(perform_id);
                performs_list += ({
                    ([
                        "id": perform_id,
                        "name_cn": perform_name,
                        "neili_cost": 0,
                        "level_req": 0,
                        "skill_level": level,
                        "exp_percent": exp_percent,
                        "available": !cooling,
                        "enough_neili": 1,
                        "cooling": cooling
                    ])
                });
            }
            // 尝试匹配满级格式: [技能名(10级):use_perform skill_id]
            else if(sscanf(line, "[%s(%d级):use_perform %s]",
                             perform_name, level, perform_id) == 3) {
                perform_name = String.trim_all_whites(perform_name);
                perform_id = String.trim_all_whites(perform_id);
                performs_list += ({
                    ([
                        "id": perform_id,
                        "name_cn": perform_name,
                        "neili_cost": 0,
                        "level_req": 0,
                        "skill_level": level,
                        "exp_percent": 100,
                        "available": !cooling,
                        "enough_neili": 1,
                        "cooling": cooling
                    ])
                });
            }
            // 尝试匹配基本格式: [技能名:use_perform skill_id]
            else if(sscanf(line, "[%s:use_perform %s]", perform_name, perform_id) == 2) {
                perform_name = String.trim_all_whites(perform_name);
                perform_id = String.trim_all_whites(perform_id);
                performs_list += ({
                    ([
                        "id": perform_id,
                        "name_cn": perform_name,
                        "neili_cost": 0,
                        "level_req": 0,
                        "skill_level": 0,
                        "exp_percent": 0,
                        "available": !cooling,
                        "enough_neili": 1,
                        "cooling": cooling
                    ])
                });
            }
        }

        // 如果通过命令解析失败，尝试直接从玩家对象读取（txpike9兼容）
        if(sizeof(performs_list) == 0) {
            object player = get_player_from_connection(auth_userid);
            if(player) {
                // 尝试获取装备的武功（多种方式）
                object|zero attack_skill = 0;
                if(functionp(player->query_attack_skill)) {
                    attack_skill = player->query_attack_skill();
                } else if(mappingp(player->equipped) && player->equipped["weapon"]) {
                    // 从装备的武器获取武功
                    object weapon = player->equipped["weapon"];
                    if(functionp(weapon->query_skill)) {
                        attack_skill = weapon->query_skill();
                    }
                }

                if(attack_skill) {
                    if(functionp(attack_skill->query_name_cn)) {
                        skill_name_cn = attack_skill->query_name_cn() || "未知武功";
                    }

                    mapping skills = player->skills;
                    if(skills && sizeof(skills) > 0) {
                        // 获取第一个技能的等级
                        foreach(indices(skills), string sk) {
                            if(arrayp(skills[sk]) && sizeof(skills[sk]) > 0) {
                                skill_level = skills[sk][0];
                                break;
                            }
                        }
                    }

                    // 获取内力
                    int player_neili = 0;
                    if(functionp(player->query_neili)) {
                        player_neili = player->query_neili();
                    }

                    // 获取所有可用招式
                    array(object) performs = ({});
                    if(functionp(attack_skill->all_performs)) {
                        performs = attack_skill->all_performs(player);
                    }

                    if(performs && sizeof(performs) > 0) {
                        foreach(performs, object perform_obj) {
                            if(!perform_obj) continue;

                            string perform_id = object_name(perform_obj);
                            string perform_name_cn = perform_obj->name_cn || "";

                            int neili_cost = 0;
                            if(intp(perform_obj->neili_cost)) {
                                neili_cost = perform_obj->neili_cost;
                            } else if(intp(perform_obj->qi_damage)) {
                                neili_cost = perform_obj->qi_damage;
                            }

                            if(sizeof(perform_name_cn) > 0) {
                                performs_list += ({
                                    ([
                                        "id": perform_id,
                                        "name_cn": perform_name_cn,
                                        "neili_cost": neili_cost,
                                        "level_req": 0,
                                        "skill_level": skill_level,
                                        "available": 1,
                                        "enough_neili": player_neili >= neili_cost
                                    ])
                                });
                            }
                        }
                    }
                }
            }
        }

        send_json(req, ([
            "performs": performs_list,
            "skill_name": "xiand",
            "skill_name_cn": skill_name_cn,
            "skill_level": 0,
            "player_neili": 0,
            "in_combat": in_combat,
            "txd": new_txd
        ]));
    };

    if(err) {
        werror("[API] /api/performs EXCEPTION: %s\n", describe_error(err));
        send_json(req, ([ "error": "服务器错误" ]), 500);
    }
}

/**
 * ========================================================================
 * 设置邀请URL API
 * ========================================================================
 *
 * 用于设置玩家的邀请链接URL
 *
 * 请求参数:
 *   - txd: 认证token
 *   - url: 邀请链接URL
 *
 * ========================================================================
 */
void handle_api_invite_seturl(Protocols.HTTP.Server.Request req)
{
    mixed err = catch {
        mapping params = get_params(req);
        string txd = url_decode(params["txd"]);
        string invite_url = url_decode(params["url"]);

        if(!txd || txd == "" || txd == " ") {
            send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
            return;
        }

        mapping auth = decode_txd(txd);
        if(!auth) {
            send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
            return;
        }

        string userid = auth["userid"];

        if(!invite_url || invite_url == "") {
            send_json(req, ([ "error": "缺少url参数" ]), 400);
            return;
        }

        http_werror("[API] /api/invite/seturl: userid=%s, url=%s\n", userid, invite_url);

        // 这里可以将邀请URL保存到用户数据或做其他处理
        // 目前暂时返回成功响应
        send_json(req, ([
            "status": "success",
            "userid": userid,
            "url": invite_url
        ]));
    };

    if(err) {
        http_werror("[API] /api/invite/seturl EXCEPTION: %s\n", describe_error(err));
        send_json(req, ([ "error": "服务器错误" ]), 500);
    }
}

void handle_api_async(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string cmd = params["cmd"];
    if(!cmd || cmd == "") cmd = "look";

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    cmd = unhide_command(userid, cmd);

    string request_id = userid + "_" + sprintf("%d", time() * 1000 + random(999));
    int enqueued = enqueue_user_request(userid, cmd, request_id);

    if(enqueued) {
        send_json(req, ([
            "request_id": request_id,
            "status": "queued",
            "message": "命令已加入队列"
        ]));
    } else {
        send_json(req, ([ "error": "队列已满，请稍后重试" ]), 503);
    }
}

void handle_api_result(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string request_id = params["request_id"];

    if(!request_id || request_id == "") {
        send_json(req, ([ "error": "缺少request_id参数" ]), 400);
        return;
    }

    string|zero result = get_request_result(request_id);

    if(result == 0) {
        // 更新闲置时间 - 活跃用户不应被踢出
        string txd = params["txd"];
        if(txd && txd != "") {
            mapping auth = decode_txd(txd);
            if(auth) update_connection_time(auth["userid"]);
        }
        send_json(req, ([ "status": "pending", "message": "命令正在执行中" ]));
    } else if(result == UNDEFINED) {
        send_json(req, ([ "error": "请求超时或已过期" ]), 408);
    } else {
        string txd = params["txd"];
        string userid = "";
        if(txd && txd != "") {
            mapping auth = decode_txd(txd);
            if(auth) {
                userid = auth["userid"];
                // 更新闲置时间 - 活跃用户不应被踢出
                update_connection_time(userid);
            }
        }

        string html = response_to_html(result, userid, "look");
        mapping resp = ([ ]);
        resp["type"] = "text/html; charset=UTF-8";
        resp["data"] = html;
        resp["error"] = 200;
        resp["extra_heads"] = (["cache-control": "no-cache", "Access-Control-Allow-Origin": "*"]);
        req->response_and_finish(resp);
    }
}

void handle_exits(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 只读API：不更新闲置时间
    object player = get_player_from_connection(userid, 0);

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    send_json(req, query_room_exits(player));
}

void handle_room(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 只读API：不更新闲置时间
    object player = get_player_from_connection(userid, 0);

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    send_json(req, query_room_info(player));
}

void handle_api_chat_messages(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = params["txd"];
    string channel = params["channel"] || "pub_channel";

    if(!txd || txd == "") {
        send_json(req, ([ "error": "缺少txd参数" ]), 401);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "无效的txd" ]), 401);
        return;
    }

    string userid = auth["userid"];

    object chatroomd = find_object(ROOT + "/gamelib/single/daemons/chatroomd");
    if(!chatroomd) {
        chatroomd = load_object(ROOT + "/gamelib/single/daemons/chatroomd");
    }

    if(!chatroomd) {
        send_json(req, ([ "error": "聊天服务不可用" ]), 503);
        return;
    }

    string chat_msg = chatroomd->query_chat_msg(channel, userid);

    array(string) messages = ({});
    if(chat_msg && sizeof(chat_msg)) {
        foreach(chat_msg / "\n", string line) {
            line = String.trim_all_whites(line);
            if(sizeof(line) > 0) {
                string cleaned = clean_chat_message(line);
                if(sizeof(cleaned) > 0) {
                    messages += ({cleaned});
                }
            }
        }
    }

    send_json(req, ([
        "channel": channel,
        "messages": messages,
        "count": sizeof(messages),
        "timestamp": time()
    ]));
}

void handle_api_chat_send(Protocols.HTTP.Server.Request req)
{
    if(req->request_type != "POST") {
        send_json(req, ([ "error": "只支持POST请求" ]), 405);
        return;
    }

    mapping params = get_params(req);
    string txd = params["txd"];
    string channel = params["channel"] || "pub_channel";
    string message = params["message"];

    if(!txd || txd == "") {
        send_json(req, ([ "error": "缺少txd参数" ]), 401);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "无效的txd" ]), 401);
        return;
    }

    string userid = auth["userid"];
    string password = auth["password"];

    if(!message || message == "") {
        send_json(req, ([ "error": "消息内容不能为空" ]), 400);
        return;
    }

    execute_command(userid, password, "ui_chat " + message);

    send_json(req, ([
        "success": 1,
        "channel": channel,
        "message": message,
        "timestamp": time()
    ]));
}

// ========================================================================
// 辅助查询函数
// ========================================================================

mapping query_room_exits(object player)
{
    mapping result = ([ ]);
    result["timestamp"] = time();
    result["room"] = ([ ]);
    result["exits"] = (["北": 0, "东": 0, "南": 0, "西": 0]);

    object room = environment(player);
    if(!room) {
        result["room"]["name"] = "虚空";
        result["room"]["desc"] = "你处于虚空中...";
        return result;
    }

    if(functionp(room->query_short)) {
        result["room"]["name"] = room->query_short();
    } else if(functionp(room->query_name_cn)) {
        result["room"]["name"] = room->query_name_cn();
    } else {
        result["room"]["name"] = "未知房间";
    }

    if(functionp(room->query_desc)) {
        string desc = room->query_desc();
        if(desc) result["room"]["desc"] = desc;
    }

    if(functionp(room->query_exits)) {
        mapping exits = room->query_exits();
        if(exits && sizeof(exits) > 0) {
            foreach(indices(exits), string dir) {
                string dest_path = exits[dir];
                string dest_name = "";

                if(dest_path && sizeof(dest_path) > 0) {
                    if(search(dest_path, ROOT) != 0 && search(dest_path, "/") != 0) {
                        dest_path = ROOT + "/" + dest_path;
                    } else if(search(dest_path, "/") == 0 && search(dest_path, ROOT) != 0) {
                        dest_path = ROOT + dest_path;
                    }

                    object dest_room = load_object(dest_path);
                    if(dest_room) {
                        if(functionp(dest_room->query_short)) {
                            dest_name = dest_room->query_short();
                        } else if(functionp(dest_room->query_name_cn)) {
                            dest_name = dest_room->query_name_cn();
                        }
                    }
                }

                string norm_dir = normalize_direction(dir);
                array valid_dirs = indices(result["exits"]);
                if(search(valid_dirs, norm_dir) >= 0) {
                    result["exits"][norm_dir] = ([
                        "direction": dir,
                        "command": "leave " + dir,
                        "destination": dest_name || ""
                    ]);
                }
            }
        }
    }

    return result;
}

mapping query_room_info(object player)
{
    mapping result = ([ ]);
    result["timestamp"] = time();
    result["room"] = ([ ]);
    result["npcs"] = ({});

    object room = environment(player);
    if(!room) {
        result["room"]["name"] = "虚空";
        result["room"]["desc"] = "你处于虚空中...";
        return result;
    }

    if(functionp(room->query_short)) {
        result["room"]["name"] = room->query_short();
    } else if(functionp(room->query_name_cn)) {
        result["room"]["name"] = room->query_name_cn();
    } else {
        result["room"]["name"] = "未知房间";
    }

    if(functionp(room->query_desc)) {
        string desc = room->query_desc();
        if(desc) result["room"]["desc"] = desc;
    } else if(functionp(room->query_long)) {
        result["room"]["desc"] = room->query_long();
    }

    array inv = all_inventory(room);
    foreach(inv, object ob) {
        if(ob != player && functionp(ob->query_short)) {
            string name = ob->query_short();
            if(name) {
                mapping npc = ([ "name": name ]);
                if(functionp(ob->query_name)) {
                    string ob_name = ob->query_name();
                    if(ob_name && sizeof(ob_name) > 0) {
                        npc["command"] = "look " + ob_name;
                    } else {
                        npc["command"] = "look " + name;
                    }
                } else {
                    npc["command"] = "look " + name;
                }
                result["npcs"] += ({npc});
            }
        }
    }

    return result;
}

// ========================================================================
// 状态查询
// ========================================================================

mapping query_status()
{
    mapping m = ([ ]);
    m["running"] = http_port != 0;
    m["port"] = HTTP_PORT;
    m["api_only"] = api_only_mode;
    m["connections"] = query_connection_status();
    m["queue"] = query_queue_status();
    m["rate_limits"] = query_rate_limit_status();
    return m;
}
