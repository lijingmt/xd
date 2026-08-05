/**
 * ========================================================================
 * HTTP API HTML Renderer Module
 * ========================================================================
 *
 * HTML渲染功能：解析MUD输出、生成按钮、处理颜色代码
 *
 * ========================================================================
 */

// 此模块通过主文件的 #include 加载
// 不需要单独 include，所有依赖由主文件提供

// ========================================================================
// 主HTML生成
// ========================================================================

/**
 * 将MUD响应转换为HTML格式 (用于iframe显示)
 */
string response_to_html(string response, string userid, string cmd)
{
    http_werror("========== response_to_html called! cmd=%s userid=%s ==========\n", cmd || "none", userid || "none");
    string txd = generate_txd(userid);
    string html = "";
    string area = getenv("GAME_AREA");
    if(!area) area = "tx01";

    // 检查玩家主题
    int use_dark_mode = 0;
    object player = find_player(userid);
    if(player && functionp(player->query_dark_mode) && player->query_dark_mode()) {
        use_dark_mode = 1;
    }

    http_werror(" Theme mode: %s (player=%s)\n", use_dark_mode ? "dark" : "classic", userid || "none");

    // HTML头部
    html += "<!DOCTYPE html>\n<html>\n<head>\n";
    html += "<meta charset=\"UTF-8\">\n";
    html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">\n";
    html += "<title>天下AI网游 - " + area + "</title>\n";

    // 根据模式选择颜色
    string bg_color, text_color, parent_bg, child_bg, border_color, input_bg, scrollbar_track, scrollbar_thumb;
    string btn_text, link_color, hover_shadow;

    if(use_dark_mode) {
        bg_color = "#1a1a2e";
        text_color = "#e0e0e0";
        parent_bg = "#1a1a2e";
        child_bg = "#1a1a2e";
        border_color = "rgba(255,255,255,0.2)";
        input_bg = "#2a2a4a";
        scrollbar_track = "#2a2a4a";
        scrollbar_thumb = "#4a4a6a";
        btn_text = "#e0e0e0";
        link_color = "#667eea";
        hover_shadow = "rgba(102,126,234,0.4)";
    } else {
        bg_color = "#F5E6D3";
        text_color = "#3d2914";
        parent_bg = "#F5E6D3";
        child_bg = "#F5E6D3";
        border_color = "#8B7765";
        input_bg = "#FFFEF8";
        scrollbar_track = "#E8D9C6";
        scrollbar_thumb = "#C4B5A4";
        btn_text = "#3d2914";
        link_color = "#8B4513";
        hover_shadow = "rgba(139,69,19,0.3)";
    }

    // 内联样式
    html += "<style>\n";
    html += sprintf("html,body{font:Normal 18px \"Noto Sans SC Medium\";background:%s;color:%s;height:100vh;margin:0;padding:0}\n", bg_color, text_color);
    html += sprintf("a{text-decoration:none;margin:1px auto;display:inline-block;padding:4px 8px;border-radius:4px;transition:all 0.2s;color:%s}\n", link_color);
    html += sprintf("a:hover{transform:translateY(-1px);box-shadow:0 2px 8px %s}\n", hover_shadow);
    html += sprintf(".parent{height:calc(100vh - 20px);text-align:center;background:%s;overflow-y:auto;overflow-x:hidden;scroll-behavior:smooth;-webkit-overflow-scrolling:touch;padding-bottom:20px}\n", parent_bg);
    html += ".child{display:inline-block;width:300px;text-align:left;vertical-align:top}\n";
    html += ".parent:before,.parent:after{content:'';display:inline-block;height:100%;vertical-align:top}\n";

    if(use_dark_mode) {
        html += sprintf(".btn{padding:6px 12px;border-radius:6px;border:1px solid %s;background:rgba(102,126,234,0.2);color:%s;font-size:14px;cursor:pointer;margin:2px}\n", border_color, btn_text);
        html += ".btn-outline-info{color:#667eea;border-color:#667eea;background:transparent}\n";
        html += ".btn-outline-success{color:#48bb78;border-color:#48bb78;background:transparent}\n";
        html += ".btn-outline-warning{color:#ed8936;border-color:#ed8936;background:transparent}\n";
        html += ".btn-outline-purple{color:#9f7aea;border-color:#9f7aea;background:transparent}\n";
        html += ".btn-outline-primary{color:#4299e1;border-color:#4299e1;background:transparent}\n";
        html += ".btn-outline-secondary{color:#a0aec0;border-color:#a0aec0;background:transparent}\n";
        html += ".btn-outline-orange{color:#ed8936;border-color:#ed8936;background:transparent}\n";
        html += ".btn-outline-darkorange{color:#dd6b20;border-color:#dd6b20;background:transparent}\n";
        html += ".btn-outline-green{color:#48bb78;border-color:#48bb78;background:transparent}\n";
        html += ".btn-outline-tian{color:#f6e05e;border-color:#f6e05e;background:transparent}\n";
        html += ".btn-outline-di{color:#ecc94b;border-color:#ecc94b;background:transparent}\n";
        html += ".btn-outline-xuan{color:#9f7aea;border-color:#9f7aea;background:transparent}\n";
        html += ".btn-outline-huang{color:#faf089;border-color:#faf089;background:transparent}\n";
    } else {
        html += sprintf(".btn{padding:6px 12px;border-radius:6px;border:1px solid %s;background:#E8D9C6;color:%s;font-size:14px;cursor:pointer;margin:2px}\n", border_color, btn_text);
        html += ".btn-outline-info{color:#8B4513;border-color:#8B4513;background:#FFFEF8}\n";
        html += ".btn-outline-success{color:#228B22;border-color:#228B22;background:#FFFEF8}\n";
        html += ".btn-outline-warning{color:#CC5500;border-color:#CC5500;background:#FFFEF8}\n";
        html += ".btn-outline-purple{color:#800080;border-color:#800080;background:#FFFEF8}\n";
        html += ".btn-outline-primary{color:#0066CC;border-color:#0066CC;background:#FFFEF8}\n";
        html += ".btn-outline-secondary{color:#6c757d;border-color:#6c757d;background:#FFFEF8}\n";
        html += ".btn-outline-orange{color:#FF8C00;border-color:#FF8C00;background:#FFFEF8}\n";
        html += ".btn-outline-darkorange{color:#CC5500;border-color:#CC5500;background:#FFFEF8}\n";
        html += ".btn-outline-green{color:#00AA00;border-color:#00AA00;background:#FFFEF8}\n";
        html += ".btn-outline-tian{color:#FFD700;border-color:#FFD700;background:#FFFEF8}\n";
        html += ".btn-outline-di{color:#DAA520;border-color:#DAA520;background:#FFFEF8}\n";
        html += ".btn-outline-xuan{color:#9370DB;border-color:#9370DB;background:#FFFEF8}\n";
        html += ".btn-outline-huang{color:#F0E68C;border-color:#F0E68C;background:#FFFEF8}\n";
    }

    // ========== 新增境界按钮颜色样式（必须在这里定义）==========
    // 注意：这些样式在if-else之外，不受主题影响，确保始终加载
    // 使用 !important 确保覆盖 Bootstrap 默认样式
    html += "a.btn.btn-outline-yujie{color:#8B7765!important;border-color:#8B7765!important;background:#FFF4EC!important}\n";
    html += "a.btn.btn-outline-sejie{color:#4169E1!important;border-color:#4169E1!important;background:#ECF3FF!important}\n";
    html += "a.btn.btn-outline-wuse{color:#ADD8E6!important;border-color:#ADD8E6!important;background:#F0F8FF!important}\n";
    html += "a.btn.btn-outline-lisan1{color:#228B22!important;border-color:#228B22!important;background:#F0FFF0!important}\n";
    html += "a.btn.btn-outline-lisan2{color:#32CD32!important;border-color:#32CD32!important;background:#F5FFF5!important}\n";
    html += "a.btn.btn-outline-lisan3{color:#FFD700!important;border-color:#FFD700!important;background:#FFFFE0!important;text-shadow:0 0 3px #FFA500!important}\n";
    html += "a.btn.btn-outline-poxu{color:#FF6347!important;border-color:#FF6347!important;background:#FFF0EE!important}\n";
    html += "a.btn.btn-outline-dujie{color:#FF4500!important;border-color:#FF4500!important;background:#FFE0DD!important}\n";
    html += "a.btn.btn-outline-tianxian{color:#00BFFF!important;border-color:#00BFFF!important;background:#E0F7FF!important}\n";
    html += "a.btn.btn-outline-jinxian{color:#FFA500!important;border-color:#FFA500!important;background:#FFF8E7!important}\n";
    html += "a.btn.btn-outline-taiyi{color:#9932CC!important;border-color:#9932CC!important;background:#F3E5F5!important}\n";
    html += "a.btn.btn-outline-hunyuan{color:#8A2BE2!important;border-color:#8A2BE2!important;background:#F3E5FF!important}\n";
    html += "a.btn.btn-outline-daluo{color:#9400D3!important;border-color:#9400D3!important;background:#F3E5FF!important}\n";
    // 大道境 - 金色发光特效
    html += "a.btn.btn-outline-dadao{color:#FFD700!important;border:3px solid #FFD700!important;background:#000!important;font-weight:bold!important;text-shadow:0 0 8px #FFD700,0 0 15px #FFA500,0 0 20px #FF4500!important;box-shadow:0 0 15px rgba(255,215,0,0.8)!important}\n";
    html += "a.btn.btn-outline-dadao:hover{background:#1a1a1a!important;text-shadow:0 0 12px #FFD700,0 0 20px #FFA500,0 0 30px #FF4500!important;box-shadow:0 0 25px rgba(255,215,0,1)!important;transform:scale(1.05)!important}\n";
    // 超凡境 - 红橙金渐变
    html += "a.btn.btn-outline-chaofan{color:#FFF!important;border:2px solid #FFD700!important;background:linear-gradient(90deg,#FF4500,#FF8C00,#FFD700)!important;font-weight:bold!important;box-shadow:0 0 15px rgba(255,215,0,0.8)!important}\n";
    html += "a.btn.btn-outline-chaofan:hover{background:linear-gradient(90deg,#FFD700,#FFA500,#FF4500)!important;box-shadow:0 0 25px rgba(255,215,0,1)!important;transform:scale(1.08)!important}\n";

    html += ".ink-wash-gradient{background:linear-gradient(90deg,#8B4513,#D2691E,#CD853F,#DEB887,#2F4F4F,#696969);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;font-weight:bold}\n";
    html += sprintf(".parent::-webkit-scrollbar{width:8px}\n");
    html += sprintf(".parent::-webkit-scrollbar-track{background:%s}\n", scrollbar_track);
    html += sprintf(".parent::-webkit-scrollbar-thumb{background:%s;border-radius:4px}\n", scrollbar_thumb);
    html += ".parent::-webkit-scrollbar-thumb:hover{background:#a0a0b0}\n";
    html += "</style>\n";

    // JavaScript
    html += "<script>\n";
    html += "function submitInput(inputId,txd){var input=document.getElementById(inputId);if(!input)return;var value=encodeURIComponent(input.value);var url='/api/html?txd='+txd+'&cmd='+value;window.location.href=url}\n";
    html += "function submitCmdInput(inputId,hiddenCmd,txd){var input=document.getElementById(inputId);if(!input)return;var value=encodeURIComponent(input.value);var url='/api/html?txd='+txd+'&cmd='+hiddenCmd+' '+value;window.location.href=url}\n";
    // 翻译语言切换函数 - 支持队列机制和postMessage通信
    html += "console.log('[Iframe Debug] Script loaded');window.pendingLanguage=null;window.changeLanguage=function(lang){console.log('[Iframe Debug] changeLanguage called:',lang);if(typeof translate!=='undefined'&&translate.changeLanguage){console.log('[Iframe Debug] Calling translate.changeLanguage');translate.changeLanguage(lang);window.pendingLanguage=null;window.parent.postMessage({type:'changeLanguage',lang:lang},'*')}else{window.pendingLanguage=lang;console.log('[Iframe Debug] Translate not loaded yet, pending:',lang)}};\n";
    // 监听来自父窗口的语言切换消息
    html += "window.addEventListener('message',function(event){if(event.data&&event.data.type==='changeLanguage'){console.log('[Iframe Debug] Received language change from parent:',event.data.lang);window.changeLanguage(event.data.lang)}});\n";
    html += "</script>\n";

    html += "</head>\n<body>\n";
    html += "<div class=\"parent\">\n<div class=\"child\">\n";

    // 解析并转换内容
    html += parse_mud_content_to_html(response, txd, userid);

    html += "</div>\n</div>\n";

    // 翻译插件
    string translate_bg = use_dark_mode ? "#2a2a4a" : "#E8D9C6";
    string translate_border = use_dark_mode ? "rgba(255,255,255,0.1)" : "#8B7765";
    string translate_select_bg = use_dark_mode ? "#1a1a2e" : "#FFFEF8";
    string translate_text = use_dark_mode ? "#e0e0e0" : "#3d2914";

    html += sprintf("<div class='translate-center' style='position:fixed;bottom:0;left:0;right:0;text-align:center;padding:8px;background:%s;border-top:1px solid %s;z-index:999;'>\n", translate_bg, translate_border);
    html += "<div class='translate-wrapper'>\n";
    html += sprintf("<select id='translateLanguageSelect' onchange='changeLanguage(this.value)' style='padding:4px 8px;border:1px solid %s;border-radius:4px;background:%s;color:%s;font-size:11px;'>\n", translate_border, translate_select_bg, translate_text);
    html += "<option value='chinese_simplified'>简体中文</option>\n<option value='chinese_traditional'>繁體中文</option>\n<option value='english'>English</option>\n<option value='japanese'>日本語</option>\n<option value='korean'>한국어</option>\n<option value='french'>Français</option>\n<option value='german'>Deutsch</option>\n<option value='spanish'>Español</option>\n<option value='russian'>Русский</option>\n<option value='portuguese'>Português</option>\n";
    html += "</select>\n</div>\n</div>\n";

    // 加载翻译插件 - 从当前服务器(8888)加载translate.js，避免跨域问题
    html += "<script src='/includes/translate.js'></script>\n"
         + "<script>\n"
         + "console.log('[Iframe Debug] translate.js loaded');\n"
         + "translate.language.setLocal('chinese_simplified');\n"
         + "translate.service.use('client.edge');\n"
         + "translate.setAutoDiscriminateLocalLanguage();\n"
         + "translate.execute();\n"
         + "setTimeout(function(){\n"
         + "var targetLang=window.pendingLanguage||localStorage.getItem('userLanguage');\n"
         + "if(targetLang&&targetLang!=='chinese_simplified'){\n"
         + "console.log('[Iframe Debug] Applying language:',targetLang);\n"
         + "translate.changeLanguage(targetLang);\n"
         + "}\n"
         + "window.pendingLanguage=null;\n"
         + "},100);\n"
         + "</script>\n";

    html += "</body>\n</html>\n";

    return html;
}

// ========================================================================
// MUD内容解析
// ========================================================================

/**
 * 解析MUD原始输出并转换为HTML
 */
string parse_mud_content_to_html(string response, string txd, string userid)
{
    string html = "";
    if(!response) response = "";

    http_werror(" ===== parse_mud_content_to_html START =====\n");
    http_werror(" Response length: %d bytes\n", sizeof(response));

    array lines = response / "\n";
    http_werror(" Total lines: %d\n", sizeof(lines));

    int line_count = 0;
    foreach(lines, string line) {
        string original_line = line;
        line = String.trim_all_whites(line);
        if(!sizeof(line)) {
            html += "<br/>\n";
            continue;
        }

        line_count++;

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

        if(line_count % 10 == 0) {
            http_werror(" Processing line %d\n", line_count);
        }

        // 检测并处理按钮和输入框
        int has_special = 0;
        array parts = ({});
        int current = 0;

        // 检查内容是否以指定字符串开头
        int has_prefix(string str, string prefix) {
            if(!str || !prefix) return 0;
            return search(str, prefix) == 0;
        }

        while(current < sizeof(line)) {
            int start = search(line, "[", current);
            if(start == -1) {
                if(current < sizeof(line)) {
                    parts += ({line[current..]});
                }
                break;
            }
            if(start > current) {
                parts += ({line[current..start-1]});
            }
            int end = search(line, "]", start);
            if(end == -1) {
                parts += ({line[start..]});
                break;
            }
            parts += ({line[start..end]});
            current = end + 1;
            has_special = 1;
        }

        if(has_special) {
            foreach(parts, string part) {
                part = String.trim_all_whites(part);
                if(!sizeof(part)) continue;

                if(search(part, "[") == 0 && part[-1] == ']') {
                    string content = part[1..<1];
                    string var_name, default_val, width, type;

                    // 输入框格式 [类型 变量名:...] 或 [变量名:默认值...宽度]
                    if(sscanf(content, "%s %s:..*%s...*%s", type, var_name, default_val, width) == 4 ||
                       sscanf(content, "%s:..*%s...*%s", var_name, default_val, width) == 3) {
                        html += format_html_input(var_name, default_val, width, txd, userid, (type == "passwd"));
                    }
                    // submit按钮 [submit 确定:command ...] - HTTP API中跳过不渲染
                    // WAP系统用submit按钮提交前面的输入框，但HTTP API中输入框自带Enter提交
                    else if(has_prefix(content, "submit ")) {
                        http_werror("[DEBUG] submit button skipped in HTML renderer: content='%s'\n", content);
                        // 跳过不渲染任何内容
                    }
                    else if(sscanf(content, "%s %s:...", type, var_name) == 2) {
                        int is_passwd = (type == "passwd" || type == "password");
                        html += format_html_input(var_name, "", "", txd, userid, is_passwd);
                    }
                    else if(search(content, ":") > 0 && content[-4..] == ":...") {
                        int colon_pos = search(content, ":");
                        string cmd_name = content[0..colon_pos-1];
                        html += format_html_command_input(cmd_name, txd, userid);
                    }
                    else if(content[-5..] == " ...") {
                        string cmd_name = content[0..sizeof(content)-5];
                        html += format_html_command_input(cmd_name, txd, userid);
                    }
                    else {
                        int pos = search(content, ":");
                        if(pos > 0) {
                            string label = content[0..pos-1];
                            string action_cmd = content[pos+1..];

                            // DEBUG LOG
                            http_werror("[DEBUG] content='" + content + "'\n");
                            http_werror("[DEBUG] label='" + label + "' action_cmd='" + action_cmd + "'\n");

                            // 图片链接 [miniimg minipicture:/xd/images/xxx.gif]
                            if(search(content, "miniimg ") == 0) {
                                http_werror("[DEBUG] Found miniimg prefix\n");
                                int colon_pos = search(content[8..], ":");
                                http_werror("[DEBUG] colon_pos=" + (string)colon_pos + "\n");
                                if(colon_pos >= 0) {
                                    string img_name = content[8..8+colon_pos-1];
                                    string img_href = content[8+colon_pos+1..];
                                    // 移除游戏前缀 /xd/ 或 /tx/，转换为正确的Web路径
                                    // 例如: /xd/images/humanlike_male.gif -> /images/humanlike_male.gif
                                    if(sscanf(img_href, "/%*s/images/%s", string rest) == 2) {
                                        img_href = "/images/" + rest;
                                    }
                                    http_werror("[DEBUG] img_name='" + img_name + "' img_href='" + img_href + "'\n");
                                    html += sprintf("<img src=\"%s\" alt=\"%s\" height=\"20\" width=\"20\" align=\"middle\"/>",
                                                       img_href, img_name);
                                } else {
                                    http_werror("[DEBUG] colon_pos < 0, falling back to button\n");
                                    html += format_html_button(label, action_cmd, txd, userid);
                                }
                            }
                            // 图片加载 [imgurl name:/path/to/image.gif]
                            else if(search(content, "imgurl ") == 0) {
                                http_werror("[DEBUG] Found imgurl prefix\n");
                                int colon_pos = search(content[7..], ":");
                                http_werror("[DEBUG] colon_pos=" + (string)colon_pos + "\n");
                                if(colon_pos >= 0) {
                                    string img_name = content[7..7+colon_pos-1];
                                    string img_href = content[7+colon_pos+1..];
                                    // 移除游戏前缀 /xd/ 或 /tx/，转换为正确的Web路径
                                    // 例如: /xd/images/humanlike_male.gif -> /images/humanlike_male.gif
                                    if(sscanf(img_href, "/%*s/images/%s", string rest) == 2) {
                                        img_href = "/images/" + rest;
                                    }
                                    http_werror("[DEBUG] img_name='" + img_name + "' img_href='" + img_href + "'\n");
                                    html += sprintf("<img src=\"%s\" alt=\"%s\"/>",
                                                       img_href, img_name);
                                } else {
                                    http_werror("[DEBUG] colon_pos < 0, falling back to button\n");
                                    html += format_html_button(label, action_cmd, txd, userid);
                                }
                            }
                            // URL链接 [url 显示文本:https://...]
                            else if(search(label, "url ") == 0 &&
                               (search(action_cmd, "http://") == 0 || search(action_cmd, "https://") == 0)) {
                                string display_text = label[4..];
                                html += sprintf("<a href=\"javascript:void(0)\" onclick=\"window.top.location='%s';return false;\" class=\"btn btn-outline-info btn-sm\">%s</a>",
                                                   action_cmd, format_text(display_text));
                            } else {
                                http_werror("[DEBUG] No match, using format_html_button\n");
                                html += format_html_button(label, action_cmd, txd, userid);
                            }
                        } else {
                            html += format_text(part);
                        }
                    }
                } else {
                    html += format_text(part);
                }
            }
        } else {
            html += format_text(line);
        }
        html += "<br/>\n";
    }

    http_werror(" ===== parse_mud_content_to_html END =====\n");
    return html;
}

// ========================================================================
// 格式化函数
// ========================================================================

/**
 * 根据链接名称获取对应的 CSS 类
 * 对应 html6.pike 的 get_right_href_css() 函数
 */
string get_button_css_class(string link_name)
{
    string btn_info = "btn btn-outline-info btn-sm";
    string btn_warning = "btn btn-outline-warning btn-sm";
    string btn_primary = "btn btn-outline-primary btn-sm";
    string btn_success = "btn btn-outline-success btn-sm";
    string btn_secondary = "btn btn-outline-secondary btn-sm";
    string btn_orange = "btn btn-outline-orange btn-sm";
    string btn_darkorange = "btn btn-outline-darkorange btn-sm";
    string btn_purple = "btn btn-outline-purple btn-sm";
    string btn_green2 = "btn btn-outline-green btn-sm";
    string btn_tian = "btn btn-outline-tian btn-sm";
    string btn_di = "btn btn-outline-di btn-sm";
    string btn_xuan = "btn btn-outline-xuan btn-sm";
    string btn_huang = "btn btn-outline-huang btn-sm";

    // 新增境界按钮样式类
    string btn_yujie = "btn btn-outline-yujie btn-sm";
    string btn_sejie = "btn btn-outline-sejie btn-sm";
    string btn_wuse = "btn btn-outline-wuse btn-sm";
    string btn_lisan1 = "btn btn-outline-lisan1 btn-sm";
    string btn_lisan2 = "btn btn-outline-lisan2 btn-sm";
    string btn_lisan3 = "btn btn-outline-lisan3 btn-sm";
    string btn_poxu = "btn btn-outline-poxu btn-sm";
    string btn_dujie = "btn btn-outline-dujie btn-sm";
    string btn_tianxian = "btn btn-outline-tianxian btn-sm";
    string btn_jinxian = "btn btn-outline-jinxian btn-sm";
    string btn_taiyi = "btn btn-outline-taiyi btn-sm";
    string btn_hunyuan = "btn btn-outline-hunyuan btn-sm";
    string btn_daluo = "btn btn-outline-daluo btn-sm";
    string btn_dadao = "btn btn-outline-dadao btn-sm";
    string btn_chaofan = "btn btn-outline-chaofan btn-sm";

    mixed err = catch {
        mapping(string:string) primary_key_map = ([]);

        // 数字优先级 (9* 到 1*)
        primary_key_map["9*"] = btn_huang;
        primary_key_map["8*"] = btn_xuan;
        primary_key_map["7*"] = btn_tian;
        primary_key_map["6*"] = btn_di;
        primary_key_map["5*"] = btn_green2;
        primary_key_map["4*"] = btn_orange;
        primary_key_map["3*"] = btn_purple;
        primary_key_map["2*"] = btn_primary;
        primary_key_map["1*"] = btn_secondary;

        // 方向
        primary_key_map["东→"] = btn_success;
        primary_key_map["西←"] = btn_success;
        primary_key_map["南↓"] = btn_success;
        primary_key_map["北↑"] = btn_success;

        // 重要功能
        primary_key_map["快速攻击"] = btn_warning;
        primary_key_map["驿站"] = btn_warning;
        primary_key_map["商城"] = btn_warning;
        primary_key_map["锻造"] = btn_warning;
        primary_key_map["黑市"] = btn_orange;
        primary_key_map["【强化】"] = btn_orange;
        primary_key_map["合成"] = btn_orange;
        primary_key_map["宝商"] = btn_orange;
        primary_key_map["精炼"] = btn_orange;
        primary_key_map["隐秘幻境"] = btn_warning;
        primary_key_map["任务"] = btn_success;
        primary_key_map["尸体"] = btn_secondary;
        primary_key_map["武功"] = btn_success;
        primary_key_map["状态"] = btn_success;
        primary_key_map["吃药"] = btn_purple;
        primary_key_map["白银"] = btn_warning;

        // 盲盒
        primary_key_map["闪亮的石块(盲盒)"] = btn_success;
        primary_key_map["魔皮荷包(盲盒)"] = btn_green2;
        primary_key_map["魔精袋子(盲盒"] = btn_darkorange;
        primary_key_map["魔铁宝箱(盲盒)"] = btn_orange;
        primary_key_map["魔金宝箱(盲盒)"] = btn_purple;
        primary_key_map["幸运宝石"] = btn_purple;

        // 数字标签 (「壹」到「拾叁」)
        primary_key_map["「壹」"] = btn_success;
        primary_key_map["「捌」"] = btn_darkorange;
        primary_key_map["「陆」"] = btn_green2;
        primary_key_map["「伍」"] = btn_green2;
        primary_key_map["「贰」"] = btn_success;
        primary_key_map["「肆」"] = btn_green2;
        primary_key_map["「柒」"] = btn_darkorange;
        primary_key_map["「玖」"] = btn_darkorange;
        primary_key_map["「拾」"] = btn_darkorange;
        primary_key_map["「十贰」"] = btn_orange;
        primary_key_map["「拾壹」"] = btn_orange;
        primary_key_map["「十叁」"] = btn_purple;

        // 品质标签 (「天-」「地-」等)
        primary_key_map["「地-"] = btn_di;
        primary_key_map["「天-"] = btn_tian;
        primary_key_map["「黄-"] = btn_huang;
        primary_key_map["「玄-"] = btn_xuan;

        // 强化等级
        primary_key_map["【优良】"] = btn_primary;
        primary_key_map["【精制】"] = btn_darkorange;
        primary_key_map["【神炼】"] = btn_purple;
        primary_key_map["【天降】"] = btn_green2;
        primary_key_map["【幻化】"] = btn_orange;
        primary_key_map["【空觉】"] = btn_di;
        primary_key_map["【破空】"] = btn_tian;
        primary_key_map["【寂灭】"] = btn_huang;

        // 玉石类型
        primary_key_map["【玉】碎玉"] = btn_primary;
        primary_key_map["【玉】仙缘玉"] = btn_darkorange;
        primary_key_map["【玉】玲珑玉"] = btn_purple;
        primary_key_map["【玉】碧玺玉"] = btn_green2;
        primary_key_map["【玉】玄天宝玉"] = btn_xuan;
        primary_key_map["神秘商店"] = btn_darkorange;

        // VIP 等级颜色 (从 TOPTEN 获取)
        object topten = find_object(ROOT + "/gamelib/single/daemons/topten");
        if(topten && functionp(topten->get_grade_mapping)) {
            mapping(string:int) grade_mapping = topten->get_grade_mapping();
            foreach(grade_mapping; string index; int n) {
                if(n == 1) {
                    primary_key_map[index] = btn_green2;
                } else if(n == 2) {
                    primary_key_map[index] = btn_darkorange;
                } else if(n == 3) {
                    primary_key_map[index] = btn_orange;
                } else if(n == 4) {
                    primary_key_map[index] = btn_purple;
                }
            }
        }

        // ========== 境界检查（最高优先级，在所有其他检查之前）==========
        // 创建单独的境界映射，优先检查
        mapping(string:string) realm_map = ([
            "大道境-" : btn_dadao,
            "超凡境-" : btn_chaofan,
            "大罗境-" : btn_daluo,
            "混元境-" : btn_hunyuan,
            "太乙境-" : btn_taiyi,
            "金仙境-" : btn_jinxian,
            "天仙境-" : btn_tianxian,
            "渡劫境-" : btn_dujie,
            "破虚境-" : btn_poxu,
            "离三界-高阶-" : btn_lisan3,
            "离三界-中阶-" : btn_lisan2,
            "离三界-初阶-" : btn_lisan1,
            "离三界-" : btn_lisan1,  // 兼容旧装备
            "无色界-" : btn_wuse,
            "色界-" : btn_sejie,
            "欲界-" : btn_yujie,
        ]);

        // 先检查境界（优先级最高）
        foreach(realm_map; string realm_key; string realm_css) {
            if(search(link_name, realm_key) != -1) {
                return realm_css;
            }
        }

        // 检查匹配
        array(string) index_array = indices(primary_key_map);
        foreach(index_array, string index) {
            if(search(link_name, index) != -1) {
                return primary_key_map[index];
            }
        }
    };

    if(err) {
        http_werror("[get_button_css_class] error: %s\n", describe_error(err));
    }

    return btn_info;
}

/**
 * 格式化文本（处理颜色代码）
 */
string format_text(string text)
{
    string result = "";
    int i = 0;

    while(i < sizeof(text)) {
        // 检查颜色代码 § (0xc2 0xa7 in UTF-8)
        if(i < sizeof(text) - 2 && (text[i] & 0xff) == 0xc2 && (text[i+1] & 0xff) == 0xa7) {
            int color_code = text[i+2] & 0xff;
            string color_html = "";

            switch(color_code) {
                case 0x30: color_html = "<span style='color:#000000'>"; break;
                case 0x31: color_html = "<span style='color:#FF0000;font-weight:bold'>"; break;
                case 0x32: color_html = "<span style='color:#00AA00;font-weight:bold'>"; break;
                case 0x33: color_html = "<span style='color:#0066CC;font-weight:bold'>"; break;
                case 0x34: color_html = "<span style='color:#FFD700;font-weight:bold'>"; break;
                case 0x35: color_html = "<span style='color:#8B00FF;font-weight:bold'>"; break;
                case 0x36: color_html = "<span style='color:#FF8C00;font-weight:bold'>"; break;
                case 0x37: color_html = "<span style='color:#FFFFFF;font-weight:bold'>"; break;
                case 0x38: color_html = "<span style='color:#888888'>"; break;
                case 0x39: color_html = "<span style='color:#003366;font-weight:bold'>"; break;
                case 0x61: color_html = "<span style='color:#90EE90;font-weight:bold'>"; break;  // §a 浅绿
                case 0x62: color_html = "<span style='color:#ADD8E6;font-weight:bold'>"; break;  // §b 浅蓝
                case 0x63: color_html = "<span style='color:#FF6B6B;font-weight:bold'>"; break;  // §c 浅红
                case 0x64: color_html = "<span style='color:#DDA0DD;font-weight:bold'>"; break;  // §d 浅紫
                case 0x65: color_html = "<span style='color:#FFFF00;font-weight:bold'>"; break;  // §e 黄色
                case 0x66: color_html = "<span style='color:#333333;font-weight:bold'>"; break;  // §f 深灰
                case 0x67: color_html = "<span class='ink-wash-gradient' style='font-weight:bold'>"; break;  // §g 水墨
                case 0x72: color_html = "</span>"; break;  // §r 重置
                // 大写字母颜色代码
                case 0x41: color_html = "<span style='color:#00FF00;font-weight:bold'>"; break;  // §A 亮绿
                case 0x42: color_html = "<span style='color:#0099FF;font-weight:bold'>"; break;  // §B 亮蓝
                case 0x43: color_html = "<span style='color:#FF0000;font-weight:bold'>"; break;  // §C 鲜红
                case 0x44: color_html = "<span style='color:#FF1493;font-weight:bold'>"; break;  // §D 深粉
                case 0x45: color_html = "<span style='color:#FFD700;font-weight:bold'>"; break;  // §E 金色
                case 0x46: color_html = "<span style='color:#FFFFFF;font-weight:bold'>"; break;  // §F 纯白
                case 0x52: color_html = "</span>"; break;  // §R 重置（大写）
                case 0x59: color_html = "<span style='color:#FFFF00;font-weight:bold'>"; break;  // §Y 黄色
                default:
                    i += 2;
                    continue;
            }

            result += color_html;
            i += 3;
        }
        else if((text[i] & 0xff) >= 0 && (text[i] & 0xff) < 128) {
            int c = text[i];
            if(c == '\n') {
                result += "<br/>";
            } else if(c == '&') {
                result += "&amp;";
            } else {
                result += sprintf("%c", c);
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
                result += text[i..i+byte_count-1];
                i += byte_count;
            } else {
                result += text[i..];
                i = sizeof(text);
            }
        }
    }

    return result;
}

/**
 * 格式化HTML按钮
 */
string format_html_button(string label, string cmd, string txd, string userid)
{
    // 使用 get_button_css_class 获取按钮颜色
    string css_class = get_button_css_class(label);

    string hidden_cmd = hide_command(userid, cmd);
    string label_formatted = format_text(label);

    return sprintf("<a href=\"/api/html?txd=%s&cmd=%s\" class=\"%s\">%s</a>",
                   txd, hidden_cmd, css_class, label_formatted);
}

/**
 * 格式化HTML输入框
 */
string format_html_input(string name, string default_val, string width, string txd, string userid, int is_passwd)
{
    string size = (sizeof(width) > 0) ? width : "20";
    string value = (sizeof(default_val) > 0) ? default_val : "";
    string input_type = is_passwd ? "password" : "text";

    string input_id = "input_" + name + "_" + (random(9000) + 1000);

    // 检查主题模式
    string border_color, input_bg, text_color;
    int use_dark_mode = 0;
    object player = find_player(userid);
    if(player && functionp(player->query_dark_mode) && player->query_dark_mode()) {
        use_dark_mode = 1;
    }

    if(use_dark_mode) {
        border_color = "#667eea";
        input_bg = "#2a2a4a";
        text_color = "#e0e0e0";
    } else {
        border_color = "#8B7765";
        input_bg = "#FFFEF8";
        text_color = "#3d2914";
    }

    return sprintf("<input type='%s' id='%s' size='%s' value='%s' placeholder='%s' " +
                   "style='padding:4px 8px;border:1px solid %s;border-radius:4px;background:%s;color:%s;' " +
                   "onkeypress='if(event.key==\"Enter\"){submitInput(\"%s\", \"%s\");return false;}'>",
                   input_type, input_id, size, value, name, border_color, input_bg, text_color, input_id, txd);
}

/**
 * 格式化HTML命令输入框（带确定按钮）
 */
string format_html_command_input(string cmd, string txd, string userid)
{
    string input_id = "input_cmd_" + (random(9000) + 1000);
    string hidden_cmd = hide_command(userid, cmd);

    // 检查主题模式
    string border_color, input_bg, text_color, btn_border, btn_bg, btn_text;
    int use_dark_mode = 0;
    object player = find_player(userid);
    if(player && functionp(player->query_dark_mode) && player->query_dark_mode()) {
        use_dark_mode = 1;
    }

    if(use_dark_mode) {
        border_color = "#667eea";
        input_bg = "#2a2a4a";
        text_color = "#e0e0e0";
        btn_border = "#48bb78";
        btn_bg = "#48bb78";
        btn_text = "#fff";
    } else {
        border_color = "#8B7765";
        input_bg = "#FFFEF8";
        text_color = "#3d2914";
        btn_border = "#228B22";
        btn_bg = "#228B22";
        btn_text = "#fff";
    }

    return sprintf("<input type='text' id='%s' placeholder='输入参数...' " +
                   "style='padding:4px 8px;border:1px solid %s;border-radius:4px;background:%s;color:%s;width:120px;' " +
                   "onkeypress='if(event.key==\"Enter\"){submitCmdInput(\"%s\", \"%s\", \"%s\");return false;}'> " +
                   "<a href=\"#\" onclick='submitCmdInput(\"%s\", \"%s\", \"%s\");return false;' " +
                   "style='padding:4px 12px;border:1px solid %s;border-radius:4px;background:%s;color:%s;text-decoration:none;'>确定</a>",
                   input_id, border_color, input_bg, text_color, input_id, hidden_cmd, txd,
                   input_id, hidden_cmd, txd, btn_border, btn_bg, btn_text);
}

// ========================================================================
// 聊天消息清理
// ========================================================================

/**
 * 清理聊天消息格式
 * 原始格式: (时间)[中文名:ui_char userid]：消息
 * 输出格式: (时间)中文名: 消息
 */
string clean_chat_message(string raw_msg)
{
    if(!raw_msg || sizeof(raw_msg) == 0) {
        return "";
    }

    int bracket_start = search(raw_msg, "[");
    int bracket_end = search(raw_msg, "]");

    string time_part = "";
    string name_part = "";
    string content_part = "";

    if(bracket_start != -1 && bracket_end != -1 && bracket_end > bracket_start) {
        if(bracket_start > 0) {
            time_part = raw_msg[0..bracket_start - 1];
        }

        string bracket_content = raw_msg[bracket_start + 1..bracket_end - 1];
        int colon_pos = search(bracket_content, ":");
        if(colon_pos != -1) {
            name_part = bracket_content[0..colon_pos - 1];
        }

        if(bracket_end < sizeof(raw_msg) - 1) {
            content_part = raw_msg[bracket_end + 1..];
            if(sizeof(content_part) > 0 && (content_part[0] == ':' || content_part[0] == '：')) {
                content_part = content_part[1..];
            }
            content_part = String.trim_all_whites(content_part);
        }
    }

    string result = "";
    if(sizeof(time_part) > 0) {
        result += time_part;
    }
    if(sizeof(name_part) > 0) {
        result += name_part;
    }
    if(sizeof(content_part) > 0) {
        result += ": " + content_part;
    }

    return sizeof(result) > 0 ? result : raw_msg;
}

// ========================================================================
// JSON响应解析
// ========================================================================

/**
 * 解析MUD响应为JSON
 */
mapping parse_response_to_json(string response, string userid)
{
    mapping result = ([ ]);
    result["timestamp"] = time();
    result["messages"] = ({});
    result["actions"] = ({});
    result["images"] = ({});
    result["navigation"] = ([ "exits": ({}) ]);

    if(!response) response = "";

    response = remove_ansi_colors(response);
    array lines = response / "\n";

    foreach(lines, string line) {
        line = strip_wapmud_color_codes(line);
        line = String.trim_all_whites(line);
        if(!sizeof(line)) continue;

        // 检测按钮
        int has_button = 0;
        array parts = ({});
        int current = 0;
        while(current < sizeof(line)) {
            int start = search(line, "[", current);
            if(start == -1) {
                if(current < sizeof(line)) {
                    parts += ({line[current..]});
                }
                break;
            }
            if(start > current) {
                parts += ({line[current..start-1]});
            }
            int end = search(line, "]", start);
            if(end == -1) {
                parts += ({line[start..]});
                break;
            }
            parts += ({line[start..end]});
            current = end + 1;
            has_button = 1;
        }

        if(has_button) {
            foreach(parts, string part) {
                part = String.trim_all_whites(part);
                if(!sizeof(part)) continue;

                if(search(part, "[") == 0 && part[-1] == ']') {
                    string content = part[1..<1];
                    int pos = search(content, ":");
                    if(pos > 0) {
                        string label = content[0..pos-1];
                        string action_cmd = content[pos+1..];

                        // 图片链接 [miniimg minipicture:/xd/images/xxx.gif]
                        if(search(content, "miniimg ") == 0) {
                            int colon_pos = search(content[8..], ":");
                            if(colon_pos >= 0) {
                                string img_name = content[8..8+colon_pos-1];
                                string img_href = content[8+colon_pos+1..];
                                // 移除游戏前缀 /xd/ 或 /tx/，转换为正确的Web路径
                                if(sscanf(img_href, "/%*s/images/%s", string rest) == 2) {
                                    img_href = "/images/" + rest;
                                }
                                mapping img = ([
                                    "type": "image",
                                    "src": img_href,
                                    "alt": img_name
                                ]);
                                result["images"] += ({img});
                            } else {
                                mapping action = ([ ]);
                                action["label"] = label;
                                action["command"] = action_cmd;
                                action["style"] = get_action_style(label);
                                result["actions"] += ({action});
                            }
                        }
                        // 图片加载 [imgurl name:/path/to/image.gif]
                        else if(search(content, "imgurl ") == 0) {
                            int colon_pos = search(content[7..], ":");
                            if(colon_pos >= 0) {
                                string img_name = content[7..7+colon_pos-1];
                                string img_href = content[7+colon_pos+1..];
                                // 移除游戏前缀 /xd/ 或 /tx/，转换为正确的Web路径
                                if(sscanf(img_href, "/%*s/images/%s", string rest) == 2) {
                                    img_href = "/images/" + rest;
                                }
                                mapping img = ([
                                    "type": "image",
                                    "src": img_href,
                                    "alt": img_name
                                ]);
                                result["images"] += ({img});
                            } else {
                                mapping action = ([ ]);
                                action["label"] = label;
                                action["command"] = action_cmd;
                                action["style"] = get_action_style(label);
                                result["actions"] += ({action});
                            }
                        }
                        else if(is_direction(label)) {
                            mapping exit = ([ ]);
                            exit["direction"] = label;
                            exit["label"] = label;
                            exit["command"] = action_cmd;
                            result["navigation"]["exits"] += ({exit});
                        } else {
                            mapping action = ([ ]);
                            action["label"] = label;
                            action["command"] = action_cmd;
                            action["style"] = get_action_style(label);
                            result["actions"] += ({action});
                        }
                    }
                } else if(sizeof(part) > 0) {
                    mapping msg = ([ ]);
                    msg["type"] = get_message_type(part);
                    msg["text"] = part;
                    msg["timestamp"] = time();
                    result["messages"] += ({msg});
                }
            }
        } else {
            mapping msg = ([ ]);
            msg["type"] = get_message_type(line);
            msg["text"] = line;
            msg["timestamp"] = time();
            result["messages"] += ({msg});
        }
    }

    object player = find_player(userid);
    if(player) {
        result["player"] = query_player_state(player);
    }

    return result;
}

/**
 * 查询玩家状态 (xiand 版本 - 仙道游戏)
 */
mapping query_player_state(object player)
{
    if(!player) return 0;

    mapping result = ([ ]);

    // 使用 catch 防止属性不存在时报错
    mixed err = catch {
        // 玩家中文名
        string name_cn = "";
        if(functionp(player->query_name_cn)) {
            name_cn = player->query_name_cn();
        } else if(player["name_cn"]) {
            name_cn = player["name_cn"];
        }
        result["name_cn"] = name_cn || "";

        // 性别
        string gender = "";
        if(functionp(player->query_gender)) {
            gender = player->query_gender();
        } else if(player["gender"]) {
            gender = player["gender"];
        }
        result["gender"] = gender || "";

        // 玩家当前选择的头像，供 Vue 顶部状态栏直接显示。
        string avatar = "";
        if(player->user_pic && player->user_pic != "") {
            avatar = "/images/" + player->user_pic + ".gif";
        }
        result["avatar"] = avatar;

        // 称谓
        string honer = "";
        if(functionp(player->query_raceId)) {
            honer = WAP_HONERD->query_honer_level_desc((int)player->honerlv, player->query_raceId());
        } else {
            honer = sprintf("%d", (int)player->honerlv);
        }
        result["honer"] = honer || "";

        // 种族
        string race = "";
        if(functionp(player->query_raceId) && functionp(player->query_race_cn)) {
            race = player->query_race_cn(player->query_raceId());
        } else if(player["raceId"]) {
            race = sprintf("%d", player->raceId);
        }
        result["race"] = race || "";

        // 职业
        string profe = "";
        if(functionp(player->query_profeId) && functionp(player->query_profe_cn)) {
            profe = player->query_profe_cn(player->query_profeId());
        } else if(player["profeId"]) {
            profe = sprintf("%d", player->profeId);
        }
		result["profe"] = profe || "";
		// 新职业助手状态由服务端统一判定，前端只负责展示。
		result["profession_assistant"] =
			PROFESSIONVIPD->query_status(player);

		// 网页连接无法直接接收tell_object异步消息，状态轮询返回待处理组队邀请。
		mapping team_invite = TERMD->query_term_invite(player->query_name());
		result["team_invite"] = team_invite;
		result["team_id"] = player->query_term();

        // 等级
        int level = 0;
        if(functionp(player->query_level)) {
            level = player->query_level();
        } else if(player["level"]) {
            level = player["level"];
        }
        result["level"] = level;

		// 等级突破状态：普通120级封顶，有效VIP每级增加20级。
		int vip_level = VIPD->query_active_vip_level(player);
		int level_limit = VIPD->query_vip_level_limit(vip_level);
		string vip_name = "";
		string breakthrough_state = "normal";
		string breakthrough_label = "上限"+level_limit+
			" · VIP每级+"+VIP_LEVEL_LIMIT_STEP;
		string breakthrough_message =
			"普通玩家上限"+NORMAL_MAX_LEVEL+"级；有效VIP每提高一级，"+
			"等级上限增加"+VIP_LEVEL_LIMIT_STEP+"级。";
		if(vip_level>0 && VIPD->get_vip_name(vip_level))
			vip_name = VIPD->get_vip_name(vip_level);
		if(vip_level>0){
			breakthrough_state = "active";
			breakthrough_label = "VIP"+vip_level+" · 上限"+
				level_limit;
			breakthrough_message = "当前"+vip_name+"有效，可升级至"+
				level_limit+"级。会员过期后保留等级，但停止继续升级。";
		}
		if(level>=level_limit){
			breakthrough_state = vip_level>0 ? "tier-blocked" : "blocked";
			breakthrough_label = vip_level>0 ?
				"VIP"+vip_level+"已达"+level_limit :
				"突破受阻 · 需有效VIP";
			breakthrough_message = vip_level>0 ?
				"你已达到当前VIP等级上限"+level_limit+
				"级，提高VIP等级后可继续突破。" :
				"你已达到普通玩家上限"+NORMAL_MAX_LEVEL+
				"级，开通有效VIP后才可继续获得升级经验。";
		}
		if(level>level_limit){
			breakthrough_state = vip_level>0 ? "tier-expired" : "expired";
			breakthrough_label = vip_level>0 ?
				"当前VIP上限"+level_limit : "VIP已失效 · 重新开通";
			breakthrough_message = vip_level>0 ?
				"你的已有等级会保留，但当前VIP等级上限仅为"+
				level_limit+"级，提高VIP等级后才可继续升级。" :
				"你的已有等级会保留；当前没有有效VIP，重新开通并恢复足够VIP等级后才可继续升级。";
		}
		result["vip_level"] = vip_level;
		result["vip_name"] = vip_name;
		result["vip_active"] = vip_level>0 ? 1 : 0;
		result["vip_end_time"] = vip_level>0 ?
			(int)player->query_vip_end_time() : 0;
		result["normal_level_limit"] = NORMAL_MAX_LEVEL;
		result["vip_level_limit_step"] = VIP_LEVEL_LIMIT_STEP;
		result["level_limit"] = level_limit;
		result["level_can_progress"] = level<level_limit ? 1 : 0;
		result["level_breakthrough_state"] = breakthrough_state;
		result["level_breakthrough_label"] = breakthrough_label;
		result["level_breakthrough_message"] = breakthrough_message;

        // 自动挂机状态与当日剩余时间
        int autofight = 0;
        int autofight_time_left = 0;
        int autofight_daily_limit = 0;
        if(functionp(player->query_autofight)) {
            autofight = player->query_autofight() == "enable" ? 1 : 0;
        }
        AUTOFIGHTD->initialize_player(player);
        autofight_time_left = AUTOFIGHTD->query_time_left(player);
        autofight_daily_limit = AUTOFIGHTD->query_daily_seconds_for(player);
        result["autofight"] = autofight;
        result["autofight_time_left"] = autofight_time_left;
        result["autofight_daily_limit"] = autofight_daily_limit;

        // 生命值 HP (xiand 使用 life 而不是 jing)
        int hp = 0, hp_max = 0;
        if(functionp(player->get_cur_life)) {
            hp = player->get_cur_life();
        } else if(player["life"]) {
            hp = player["life"];
        }
        if(functionp(player->query_life_max)) {
            hp_max = player->query_life_max();
        } else if(player["life_max"]) {
            hp_max = player["life_max"];
        }
        result["hp"] = hp;
        result["hp_max"] = hp_max;

        // 镇越队伍护盾属于独立 buff 槽位。战斗状态轮询直接返回剩余
        // 吸收量和秒数，让施法者、队友都能看见实际保护效果。
        int guard = 0;
        int guard_time = 0;
        if(functionp(player->query_buff) &&
           player->query_buff("team_guard", 0) == "absorb") {
            guard = (int)player->query_buff("team_guard", 1);
            guard_time = (int)player->query_buff("team_guard", 2);
            if(guard < 0) guard = 0;
            if(guard_time < 0) guard_time = 0;
        }
        result["guard"] = guard;
        result["guard_time"] = guard_time;
        result["guard_active"] = guard > 0 && guard_time > 0 ? 1 : 0;

        // 天象星痕由服务端维护。前端只读取层数，不能自行生成或消费。
        int star_marks = 0;
        if(functionp(player->query_tianxiang_star_marks)) {
            star_marks = player->query_tianxiang_star_marks();
        }
        result["star_marks"] = star_marks;
        result["star_marks_max"] = 3;

		// 灵医药契同样由服务端维护，客户端只能展示。
		int medicine_pacts = 0;
		if(functionp(player->query_lingyi_medicine_pacts))
			medicine_pacts = player->query_lingyi_medicine_pacts();
		result["medicine_pacts"] = medicine_pacts;
		result["medicine_pacts_max"] = 3;

		// 灵医百炼复苏和最近一次房间群攻战果都由服务端权威生成。
		// 战果短暂保留，使最后一个目标死亡后小窗仍能展示全部结果。
		mapping(string:int) lingyi_revive = ([]);
		mapping(string:mixed) recent_aoe_report = ([]);
		if(functionp(player->query_lingyi_auto_revive_status))
			lingyi_revive = player->query_lingyi_auto_revive_status();
		if(functionp(player->query_recent_aoe_battle_report))
			recent_aoe_report = player->query_recent_aoe_battle_report();
		result["lingyi_revive"] = lingyi_revive;
		result["recent_aoe_report"] = recent_aoe_report;

		// 山海万灵只返回当前人物的轻量陪伴快照和最近一次协战事件。
		// 该查询不读账号文件，适合战斗状态每秒轮询；客户端按事件ID去重。
		result["pet_assist"] = PETD->query_pet_battle_presence(player);
		// 每日摘要保持纯读取；跨日时返回虚拟空状态，不在轮询线程改档。
		result["daily_goal"] = DAILYGOALD->query_summary(player);
		result["timed_event"] = TIMED_EVENTD->query_player_status(player);

        // 法力值 Mana (xiand 使用 mofa 而不是 qi)
        int mana = 0, mana_max = 0;
        if(functionp(player->get_cur_mofa)) {
            mana = player->get_cur_mofa();
        } else if(player["mofa"]) {
            mana = player["mofa"];
        }
        if(functionp(player->query_mofa_max)) {
            mana_max = player->query_mofa_max();
        } else if(player["mofa_max"]) {
            mana_max = player["mofa_max"];
        }
        result["mana"] = mana;
        result["mana_max"] = mana_max;

        // 精力值 Energy
        int energy = 0;
        if(functionp(player->query_jingli)) {
            energy = player->query_jingli();
        } else if(player["jingli"]) {
            energy = player["jingli"];
        }
        result["energy"] = energy;

        // 经验值
        int exp = 0;
        if(player["current_exp"]) {
            exp = player["current_exp"];
        }
        result["exp"] = exp;

        // 升级所需经验
        int exp_need = 0;
        if(functionp(player->query_levelUp_need_exp)) {
            exp_need = player->query_levelUp_need_exp();
        }
        result["exp_need"] = exp_need;

        // 仙气/妖气
        int honerpt = 0;
        if(player["honerpt"]) {
            honerpt = player["honerpt"];
        }
        result["honerpt"] = honerpt;

        // 杀敌数
        int killcount = 0;
        if(player["killcount"]) {
            killcount = player["killcount"];
        }
        result["killcount"] = killcount;

        // 轮回值
        int lunhuipt = 0;
        if(player["lunhuipt"]) {
            lunhuipt = player["lunhuipt"];
        }
        result["lunhuipt"] = lunhuipt;

        // 当前生效的丹药/特药 buff：让前端战斗小窗能直接显示生效中的特效名称与剩余分钟。
        // 服务端读 buff[kind][0/2] 与 /danyao/、/teyao/ 名称缓存，前端只负责展示。
        array(mapping(string:mixed)) active_buffs = ({});
        array(string) buff_kinds = ({
            "attri_base","attri_attack","attri_defend","attri_vice",
            "attri_luck","attri_honer","attri_exp",
            "te_base","te_attack","te_defend","te_vice",
            "te_luck","te_honer","te_exp",
        });
        foreach(buff_kinds, string bkind){
            if(player->query_buff(bkind,0) == "none")
                continue;
            int remain_min = (int)player->query_buff(bkind,2);
            if(remain_min <= 0)
                continue;
            string buff_name = "";
            if(has_prefix(bkind,"te_")){
                mixed te = player["/teyao/"+bkind];
                if(te && arrayp(te) && sizeof(te) >= 4)
                    buff_name = (string)te[3];
            }
            else{
                buff_name = (string)player["/danyao/"+bkind];
            }
            if(buff_name == "")
                continue;
            active_buffs += ({ ([
                "kind":bkind,
                "name_cn":buff_name,
                "remain_min":remain_min,
            ]) });
        }
        result["active_buffs"] = active_buffs;

        // 无相专属：心法 + 化身状态。前端用于战斗小窗标签展示。
        if(player->query_profeId() == "wuxiang"){
            // 找出当前三系最高项给前端展示
            int s = (int)player->query_str();
            int d = (int)player->query_dex();
            int t = (int)player->query_think();
            string highest = s>=d && s>=t ? "力量" :
                d>=s && d>=t ? "敏捷" : "智力";
            result["wuxiang_heart_highest"] = highest;
            // 化身次数（120 级后才有）
            if((int)player->query_level() >= 120){
                int avatar_used = 0;
                mixed used_val = player["/plus/wuxiang/avatar_used"];
                if(used_val)
                    avatar_used = (int)used_val;
                string day_key = "";
                mixed dk = player["/plus/wuxiang/avatar_day_key"];
                if(dk)
                    day_key = (string)dk;
                string today = "";
                mixed avatar_fn = player->query_wuxiang_avatar_day_key;
                if(functionp(avatar_fn))
                    today = player->query_wuxiang_avatar_day_key();
                result["wuxiang_avatar"] = ([
                    "unlocked":1,
                    "used_today":(day_key==today ? avatar_used : 0),
                    "remaining_today":(day_key==today ? (1-avatar_used) : 1),
                ]);
            }
        }
    };

    if(err) {
        http_werror("[HTTP_API] query_player_state error: %s\n", describe_error(err));
        result["error"] = "获取状态失败";
    }

    return result;
}
