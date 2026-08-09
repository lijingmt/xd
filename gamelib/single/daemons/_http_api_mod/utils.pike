/**
 * ========================================================================
 * HTTP API Utility Functions
 * ========================================================================
 *
 * 工具函数集合：URL编码/解码、参数解析、响应发送等
 *
 * ========================================================================
 */

// ========================================================================
// 工具函数模块 - 此文件通过主文件的 #include 加载
// ========================================================================

// ========================================================================
// URL 编码/解码
// ========================================================================

/**
 * URL编码函数
 */
string url_encode(string s)
{
    if(!s) return "";
    string result = "";

    for(int i = 0; i < sizeof(s); i++) {
        int c = s[i];
        if((c >= '0' && c <= '9') ||
           (c >= 'A' && c <= 'Z') ||
           (c >= 'a' && c <= 'z') ||
           c == '-' || c == '_' || c == '.' || c == '~') {
            result += sprintf("%c", c);
        } else if(c == ' ') {
            result += "+";
        } else {
            result += sprintf("%%%02X", c);
        }
    }
    return result;
}

/**
 * URL解码函数
 */
string url_decode(string s)
{
    if(!s) return "";
    s = replace(s, "+", " ");

    int i = 0;
    string result = "";
    while(i < sizeof(s)) {
        if(s[i] == '%' && i + 2 < sizeof(s)) {
            string hex = s[i+1..i+2];
            int byte = 0;
            for(int j = 0; j < sizeof(hex); j++) {
                int c = hex[j];
                if(c >= '0' && c <= '9')
                    byte = byte * 16 + (c - '0');
                else if(c >= 'A' && c <= 'F')
                    byte = byte * 16 + (c - 'A' + 10);
                else if(c >= 'a' && c <= 'f')
                    byte = byte * 16 + (c - 'a' + 10);
            }
            result += sprintf("%c", byte);
            i += 3;
        } else {
            result += s[i..i];
            i++;
        }
    }
    return result;
}

// ========================================================================
// HTTP 参数解析
// ========================================================================

/**
 * 从HTTP请求中提取参数
 */
mapping get_params(Protocols.HTTP.Server.Request req)
{
    mapping params = ([ ]);

    if(req->query) {
        foreach(req->query / "&", string pair) {
            array kv = pair / "=";
            if(sizeof(kv) == 2) {
                params[kv[0]] = url_decode(kv[1]);
            }
        }
    }

    if(req->body_raw && sizeof(req->body_raw)) {
        string ctype = req->request_headers["content-type"] || "";
        if(search(ctype, "json") != -1) {
            mapping body_data = Standards.JSON.decode(req->body_raw);
            if(mappingp(body_data)) {
                params |= body_data;
            }
        } else if(search(ctype, "x-www-form-urlencoded") != -1) {
            foreach(req->body_raw / "&", string pair) {
                array kv = pair / "=";
                if(sizeof(kv) == 2) {
                    params[kv[0]] = url_decode(kv[1]);
                }
            }
        }
    }

    return params;
}

// ========================================================================
// HTTP 响应发送
// ========================================================================

/**
 * Keep a worker request running until its real response callback fires. This
 * includes queued Backend commands and parallel JSON/static-file futures.
 */
private int finalize_map_worker_response_state(string routed_user,
    string request_id)
{
    object routed_player;
    mixed finalize_err;
    int finalized = 1;
    if(routed_user=="")
        return 1;
    routed_player = get_player_from_connection(routed_user,0);
    if(!routed_player)
        routed_player = find_player(routed_user);
    finalize_err = catch {
        if(routed_player &&
           functionp(YUSHID->finalize_wallet_payment_after_worker_request))
            finalized = YUSHID->finalize_wallet_payment_after_worker_request(
                routed_player);
    };
    if(finalize_err || !finalized){
        http_werror(" map worker response finalizer pending: %s %s error=%s\n",
            routed_user,request_id,finalize_err ?
            describe_error(finalize_err) : "retry");
        return 0;
    }
    return 1;
}

private void publish_finished_worker_response(
    Protocols.HTTP.Server.Request req,mapping response,string request_id)
{
    mixed response_err = catch { req->response_and_finish(response); };
    // Socket delivery and world-state completion are separate facts. Once all
    // wallet/player finalizers are durable, publish done even if the client has
    // disconnected; the gateway can then resolve its uncertain request safely.
    MAP_WORKERD->complete_local_gateway_request(request_id);
    if(response_err)
        http_werror(" map worker finalized response socket error: %s\n",
            describe_error(response_err));
}

private void retry_finish_http_response(Protocols.HTTP.Server.Request req,
    mapping response,string request_id,string routed_user)
{
    mapping request_status = MAP_WORKERD->query_local_gateway_request(request_id);
    if(!(int)request_status["ok"] ||
       (string)request_status["state"]!="running")
        return;
    if(!finalize_map_worker_response_state(routed_user,request_id)){
        call_out(retry_finish_http_response,1,req,response,request_id,routed_user);
        return;
    }
    publish_finished_worker_response(req,response,request_id);
}

void finish_http_response(Protocols.HTTP.Server.Request req,mapping response)
{
    string request_id = lower_case(String.trim_all_whites(
        req->request_headers["x-xiand-request-id"] || ""));
    mapping request_status = MAP_WORKERD->query_node_role()=="worker" ?
        MAP_WORKERD->query_local_gateway_request(request_id) : ([]);
    int worker_request = (int)request_status["ok"] &&
        (string)request_status["state"]=="running";
	if(worker_request){
		string routed_user = lower_case(String.trim_all_whites(
			req->request_headers["x-xiand-lease-userid"] || ""));
		if(!mappingp(response["extra_heads"]))
			response["extra_heads"] = ([]);
		// The gateway waits for durable finalizers only when the worker proves
		// that this exact request entered its mutation fence. Pre-fence 403/409
		// responses intentionally carry no such capability.
		response["extra_heads"]["X-Xiand-Request-Accepted"] = request_id;
		if(!finalize_map_worker_response_state(routed_user,request_id)){
            call_out(retry_finish_http_response,1,req,response,request_id,
                routed_user);
            return;
        }
        publish_finished_worker_response(req,response,request_id);
        return;
    }
    req->response_and_finish(response);
}

/**
 * 发送已经在线程池编码完成的JSON字符串。
 */
void send_encoded_json(Protocols.HTTP.Server.Request req,string json,
    void|int code)
{
    mixed err = catch {
        mapping response = ([ ]);
        response["type"] = "application/json";
        response["data"] = json || "{}";
        response["error"] = (int)(code || 200);
        response["extra_heads"] = ([ ]);
        response["extra_heads"]["Access-Control-Allow-Origin"] = "*";
        response["extra_heads"]["Cache-Control"] = "no-store";
        finish_http_response(req,response);
    };
    if(err)
        http_werror(" send_encoded_json error: %s\n",describe_error(err));
}

/**
 * 发送JSON响应
 */
void send_json(Protocols.HTTP.Server.Request req, mapping data, void|int code)
{
    mixed err = catch {
        string json = Standards.JSON.encode(data);
        send_encoded_json(req,json,code);
    };

    if(err) {
        http_werror(" send_json error: %s\n", describe_error(err));
    }
}

/**
 * 发送CORS预检响应
 */
void send_cors(Protocols.HTTP.Server.Request req)
{
    mapping response = ([ ]);
    response["type"] = "text/plain";
    response["data"] = "";
    response["extra_heads"] = ([ ]);
    response["extra_heads"]["Access-Control-Allow-Origin"] = "*";
    response["extra_heads"]["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS";
    response["extra_heads"]["Access-Control-Allow-Headers"] = "Content-Type";
    finish_http_response(req,response);
}

/**
 * 发送HTML错误页面
 */
void send_html_error(Protocols.HTTP.Server.Request req, string error_msg)
{
    mixed err = catch {
        string html = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\">";
        html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">";
        html += "<title>错误</title>";
        html += "<style>body{font:18px sans-serif;background:#1a1a2e;color:#e0e0e0;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}.error-box{background:#2a2a4a;padding:30px;border-radius:10px;border-left:4px solid #fc8181;max-width:400px}.error-title{color:#fc8181;font-size:24px;margin-bottom:10px}.error-msg{color:#e0e0e0}</style>";
        html += "</head><body>";
        html += "<div class=\"error-box\">";
        html += "<div class=\"error-title\">⚠️ 错误</div>";
        html += "<div class=\"error-msg\">" + error_msg + "</div>";
        html += "</div></body></html>";

        mapping resp = ([ ]);
        resp["type"] = "text/html; charset=UTF-8";
        resp["data"] = html;
        resp["error"] = 200;
        resp["extra_heads"] = (["Access-Control-Allow-Origin": "*"]);
        finish_http_response(req,resp);
    };

    if(err) {
        http_werror(" send_html_error error: %s\n", describe_error(err));
    }
}

/**
 * 发送静态文件
 */
private void finish_serve_file(string|zero data,
    Protocols.HTTP.Server.Request req,string type)
{
    if(!data) {
        mapping m = (["error": "File not found"]);
        send_json(req, m, 404);
        return;
    }

    mapping response = ([ ]);
    response["type"] = type;
    response["data"] = data;
    response["extra_heads"] = (["Access-Control-Allow-Origin": "*"]);
    mixed err = catch {
        finish_http_response(req,response);
    };
    if(err)
        http_werror(" async static response error: %s\n",
            describe_error(err));
}

void serve_file(Protocols.HTTP.Server.Request req, string path, string type)
{
    if(!path || path=="" || sizeof(path)>512 || search(path,"..")!=-1 ||
       has_prefix(path,"/")){
        send_json(req,(["error":"Invalid static path"]),404);
        return;
    }
    string fullpath = combine_path(ROOT,path);
    if(!ASYNC_IOD->read_text_async(fullpath,8*1024*1024,
       finish_serve_file,req,type))
        send_json(req,(["error":"Static file service busy"]),503);
}

/**
 * 根据文件路径猜测MIME类型
 */
string guess_type(string path)
{
    if(has_suffix(path, ".html")) return "text/html";
    if(has_suffix(path, ".css")) return "text/css";
    if(has_suffix(path, ".js")) return "application/javascript";
    if(has_suffix(path, ".json")) return "application/json";
    if(has_suffix(path, ".png")) return "image/png";
    if(has_suffix(path, ".jpg") || has_suffix(path, ".jpeg")) return "image/jpeg";
    if(has_suffix(path, ".gif")) return "image/gif";
    if(has_suffix(path, ".svg")) return "image/svg+xml";
    return "text/plain";
}

// ========================================================================
// 字符串处理工具
// ========================================================================

/**
 * 移除ANSI颜色码
 */
string remove_ansi_colors(string text)
{
    while(has_prefix(text, "\x1b[")) {
        int end = search(text, "m");
        if(end > 0) {
            text = text[end+1..];
        } else {
            break;
        }
    }
    return text;
}

/**
 * 移除WAPMUD单字母颜色码（如 e, c, b 等出现在行首或行尾）
 */
string strip_wapmud_color_codes(string text)
{
    if(!text) return text;

    // 移除行首的单字母颜色码（如 e, c, b, y, w 等）
    while(sizeof(text) > 0) {
        int first_char = text[0] & 0xff;
        // 检查是否是小写字母 a-z（可能是颜色码）
        if(first_char >= 'a' && first_char <= 'z') {
            // 检查后面是否是非字母字符（如 ━ 或空格）
            if(sizeof(text) > 1) {
                int next_char = text[1] & 0xff;
                // 如果下一个字符不是小写字母，则认为是颜色码
                if(next_char < 'a' || next_char > 'z') {
                    text = text[1..];
                    continue;
                }
            }
            // 只有单字符或后面也是字母，可能是正常文本
            break;
        }
        break;
    }

    // 移除行尾的单字母颜色码
    while(sizeof(text) > 0) {
        int last_char = text[sizeof(text)-1] & 0xff;
        if(last_char >= 'a' && last_char <= 'z') {
            if(sizeof(text) > 1) {
                int prev_char = text[sizeof(text)-2] & 0xff;
                // 如果前一个字符不是小写字母，则认为是颜色码
                if(prev_char < 'a' || prev_char > 'z') {
                    text = text[0..sizeof(text)-2];
                    continue;
                }
            }
            break;
        }
        break;
    }

    return text;
}

/**
 * 检查是否是方向名称
 */
int is_direction(string label)
{
    return (<"东","西","南","北","上","下","东→","西←","南↓","北↑",
             "east","west","north","south","up","down",
             "东北","西北","东南","西南">)[label];
}

/**
 * 根据标签获取动作样式
 */
string get_action_style(string label)
{
    if((<"吃药","商城","锻造","驿站","奇异小屋">)[label]) return "warning";
    if((<"任务","武功","状态","背包">)[label]) return "success";
    if((<"杀戮","攻击">)[label]) return "danger";
    if((<"帮助","关于">)[label]) return "info";
    return "default";
}

/**
 * 根据内容判断消息类型
 */
string get_message_type(string line)
{
    if(search(line, "攻击") != -1 || search(line, "伤害") != -1 || search(line, "战斗") != -1)
        return "combat";
    if(search(line, "错误") != -1 || search(line, "无法") != -1 || search(line, "失败") != -1)
        return "error";
    if(search(line, "获得") != -1 || search(line, "成功") != -1)
        return "success";
    if(search(line, "系统") != -1 || search(line, "公告") != -1)
        return "system";
    return "info";
}

/**
 * 标准化方向名
 */
string normalize_direction(string dir)
{
    if(!dir) return dir;
    string lower_dir = lower_case(dir);

    mapping dir_map = ([
        "north": "北", "northeast": "东北", "east": "东", "southeast": "东南",
        "south": "南", "southwest": "西南", "west": "西", "northwest": "西北",
        "up": "上", "down": "下", "enter": "进入", "out": "出", "exit": "出",
        "n": "北", "ne": "东北", "e": "东", "se": "东南",
        "s": "南", "sw": "西南", "w": "西", "nw": "西北",
        "u": "上", "d": "下",
        "北": "北", "东北": "东北", "东": "东", "东南": "东南",
        "南": "南", "西南": "西南", "西": "西", "西北": "西北",
        "上": "上", "下": "下"
    ]);

    return dir_map[lower_dir] || dir_map[dir] || dir;
}
