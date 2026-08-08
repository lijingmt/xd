/**
 * ========================================================================
 * HTTP API Authentication Module
 * ========================================================================
 *
 * 认证相关功能：TXD Token编解码、密码哈希验证、挑战-响应认证
 *
 * ========================================================================
 */

// ========================================================================
// 认证模块 - 此文件通过主文件的 #include 加载
// ========================================================================

// ========================================================================
// 全局变量 - 命令隐藏系统
// ========================================================================

constant HIDDEN_COMMAND_TTL = 30*60;
constant HIDDEN_COMMAND_LIMIT = 100000;
mapping(string:mapping(string:mixed)) hidden_command_tokens = ([]);
mapping(string:mapping(string:int)) hidden_command_user_tokens = ([]);
mapping(int:string) hidden_command_order = ([]);
Thread.Mutex hidden_command_lock = Thread.Mutex();
int hidden_command_created;
int hidden_command_next_serial;
int hidden_command_oldest_serial = 1;

constant AUTH_PASSWORD_CACHE_TTL = 2;
constant AUTH_PASSWORD_CACHE_LIMIT = 2048;
mapping(string:mapping(string:mixed)) auth_password_cache = ([]);
Thread.Mutex auth_password_cache_lock = Thread.Mutex();
int auth_password_cache_hits = 0;
int auth_password_cache_misses = 0;
int auth_password_cache_rejected = 0;

// 这些函数依赖主文件提供的 includes
// hidden_commands, hidden_positions 全局变量

// ========================================================================
// TXD Token 编解码
// ========================================================================

/**
 * 生成TXD Token
 */
string generate_txd(string userid, void|string password)
{
    string uid = "";
    for(int i = 0; i < sizeof(userid); i++) {
        int tp = userid[i];
        if(i/2 == 0) {
            if(tp == 121) uid += "%7B";
            else if(tp == 122) uid += "%7C";
            else uid += sprintf("%c", userid[i] + 2);
        } else {
            if(tp == 122) uid += "%7B";
            else uid += sprintf("%c", userid[i] + 1);
        }
    }

    string pwd = "";
    if(password) {
        for(int i = 0; i < sizeof(password); i++) {
            int tp = password[i];
            if(i/2 == 0) {
                pwd += sprintf("%c", password[i] + 1);
            } else {
                if(tp == 121) pwd += "%7C";
                else if(tp == 122) pwd += "%7B";
                else pwd += sprintf("%c", password[i] + 2);
            }
        }
    } else {
        pwd = "dummy";
    }

    return uid + "~" + pwd;
}

/**
 * 解码TXD Token
 */
mapping decode_txd(string txd)
{
    // http_werror(" decode_txd RAW: %s\n", txd);
    if(!txd || txd == "" || txd == " ") return 0;

    mixed err = catch {
        string uid = "";
        string pid = "";
        int pos = search(txd, "~");
        if(pos == -1) {
            // http_werror(" decode_txd: No ~ found\n");
            return 0;
        }

        string stru = txd[0..pos-1];
        string strp = txd[pos+1..];
        // http_werror(" stru=%s strp=%s\n", stru, strp);

        // 解码userid
        for(int m = 0; m < sizeof(stru); m++) {
            int u = stru[m];
            if(m / 2 == 0) {
                uid += sprintf("%c", u - 2);
            } else {
                uid += sprintf("%c", u - 1);
            }
        }

        // 解码password
        for(int n = 0; n < sizeof(strp); n++) {
            int p = strp[n];
            if(n / 2 == 0) {
                pid += sprintf("%c", p - 1);
            } else {
                pid += sprintf("%c", p - 2);
            }
        }

        // http_werror(" decoded: userid=%s password=%s\n", uid, pid);

        return ([
            "userid": uid,
            "password": pid
        ]);
    };

    if(err) {
        http_werror(" decode_txd error: %s\n", describe_error(err));
        return 0;
    }
}

// ========================================================================
// 密码哈希与验证
// ========================================================================

/**
 * 计算SHA-256哈希
 */
string sha256_hash(string data)
{
    object hash = Crypto.SHA256();
    hash->update(data);
    return String.string2hex(hash->digest());
}

/**
 * 生成随机盐值
 */
string generate_salt(int|void length)
{
    int len = length || 32;
    string salt = "";
    for(int i = 0; i < len; i++) {
        int r = random(62);
        if(r < 26) {
            salt += sprintf("%c", 'a' + r);
        } else if(r < 52) {
            salt += sprintf("%c", 'A' + r - 26);
        } else {
            salt += sprintf("%c", '0' + r - 52);
        }
    }
    return salt;
}

/**
 * 验证哈希密码
 */
int verify_password_hash(string challenge, string password_hash, string stored_password)
{
    if(!challenge || !password_hash || !stored_password) {
        return 0;
    }

    // http_werror(" verify_password_hash: challenge=%s, hash_len=%d, stored_len=%d\n",
    //        challenge, sizeof(password_hash), sizeof(stored_password));

    // 检查是否是新的哈希格式 (salt:hash)
    if(search(stored_password, ":") != -1) {
        array(string) parts = stored_password / ":";
        if(sizeof(parts) == 2) {
            string stored_salt = parts[0];
            string expected = sha256_hash(challenge + stored_salt);
            // http_werror(" Hash format: expected=%s, received=%s\n", expected, password_hash);
            return (expected == password_hash) ? 1 : 0;
        }
    }

    // 兼容旧格式（明文密码）
    string expected = sha256_hash(challenge + stored_password);
    // http_werror(" Plaintext format: expected=%s, received=%s\n", expected, password_hash);
    return (expected == password_hash) ? 1 : 0;
}

/**
 * 获取用户的存储密码
 */
private int valid_auth_userid(string userid)
{
    if(!userid || sizeof(userid)<2 || sizeof(userid)>64 ||
       search(userid,"..")!=-1)
        return 0;
    foreach(userid;int index;int one){
        if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
           (one>='0' && one<='9') || one=='_' || one=='-' || one=='.')
            continue;
        return 0;
    }
    return 1;
}

private string|zero query_cached_user_password(string userid)
{
    mapping(string:mixed)|zero entry;
    string|zero password = 0;
    object key = auth_password_cache_lock->lock();
    entry = auth_password_cache[userid];
    if(entry && (int)entry["expires"]>=time()){
        password = (string)entry["password"];
        auth_password_cache_hits++;
    }
    else{
        if(entry)
            m_delete(auth_password_cache,userid);
        auth_password_cache_misses++;
    }
    destruct(key);
    return password;
}

private void cache_user_password(string userid,string password)
{
    object key = auth_password_cache_lock->lock();
    if(sizeof(auth_password_cache)>=AUTH_PASSWORD_CACHE_LIMIT){
        foreach(indices(auth_password_cache),string one){
            if((int)auth_password_cache[one]["expires"]<time())
                m_delete(auth_password_cache,one);
        }
    }
    if(sizeof(auth_password_cache)<AUTH_PASSWORD_CACHE_LIMIT)
        auth_password_cache[userid] = ([
            "password":password,
            "expires":time()+AUTH_PASSWORD_CACHE_TTL,
        ]);
    else
        auth_password_cache_rejected++;
    destruct(key);
}

void invalidate_user_password_cache(string userid)
{
    object key;
    if(!userid)
        return;
    key = auth_password_cache_lock->lock();
    m_delete(auth_password_cache,userid);
    destruct(key);
}

mapping query_auth_cache_status()
{
    mapping result;
    object key = auth_password_cache_lock->lock();
    result = ([
        "entries":sizeof(auth_password_cache),
        "limit":AUTH_PASSWORD_CACHE_LIMIT,
        "ttl_seconds":AUTH_PASSWORD_CACHE_TTL,
        "hits":auth_password_cache_hits,
        "misses":auth_password_cache_misses,
        "rejected":auth_password_cache_rejected,
    ]);
    destruct(key);
    return result;
}

string get_user_password(string userid)
{
    object|zero active_player;
    string|zero cached;
    if(!valid_auth_userid(userid)) {
        return 0;
    }

    active_player = get_player_from_connection(userid);
    if(active_player && functionp(active_player->query_password) &&
       active_player->query_password()!="")
        return active_player->query_password();

    cached = query_cached_user_password(userid);
    if(cached)
        return cached;

    string user_file = ROOT + "/data_xiand/u/" + userid[sizeof(userid)-2..] + "/" + userid + ".o";
    // http_werror(" get_user_password: loading %s\n", user_file);

    mixed err = catch {
        string content = ASYNC_IOD->read_text(user_file,1024*1024);
        if(!content || sizeof(content) == 0) {
            return 0;
        }

        int pass_idx = search(content, "password ");
        if(pass_idx == -1) {
            // http_werror(" Password field not found in user file\n");
            return 0;
        }

        string after_pass = content[pass_idx + 9..];
        int quote_start = search(after_pass, "\"");
        if(quote_start == -1) {
            return 0;
        }

        string after_quote = after_pass[quote_start + 1..];
        int quote_end = search(after_quote, "\"");
        if(quote_end == -1) {
            return 0;
        }

        string password = after_quote[0..quote_end - 1];
        cache_user_password(userid,password);
        // http_werror(" Found password, len=%d\n", sizeof(password));
        return password;
    };

    if(err) {
        http_werror(" Error reading user file: %s\n", describe_error(err));
        return 0;
    }

    return 0;
}

// ========================================================================
// 命令隐藏系统
// ========================================================================

private void remove_hidden_command_token_locked(string token)
{
    mapping entry = hidden_command_tokens[token];
    if(!entry)
        return;
    string userid = (string)entry["userid"];
    int serial = (int)entry["serial"];
    mapping(string:int) user_tokens = hidden_command_user_tokens[userid];
    m_delete(hidden_command_tokens,token);
    if(serial>0)
        m_delete(hidden_command_order,serial);
    if(user_tokens) {
        m_delete(user_tokens,token);
        if(!sizeof(user_tokens))
            m_delete(hidden_command_user_tokens,userid);
    }
}

private void reset_hidden_command_order_if_empty_locked()
{
    if(sizeof(hidden_command_tokens))
        return;
    hidden_command_order = ([]);
    hidden_command_next_serial = 0;
    hidden_command_oldest_serial = 1;
}

private void cleanup_hidden_command_tokens_locked()
{
    int now = time();
    // 令牌过期顺序与创建顺序一致。只向前推进游标，避免达到上限后
    // 每创建一个页面动作都全表扫描十万条记录。
    while(hidden_command_oldest_serial<=hidden_command_next_serial) {
        string token = hidden_command_order[hidden_command_oldest_serial];
        mapping entry = token && hidden_command_tokens[token];
        if(entry && (int)entry["expires"]>=now &&
           sizeof(hidden_command_tokens)<HIDDEN_COMMAND_LIMIT)
            break;
        if(token)
            remove_hidden_command_token_locked(token);
        hidden_command_oldest_serial++;
    }
    reset_hidden_command_order_if_empty_locked();
}

/**
 * 隐藏命令：为每个页面动作创建不可变、不可预测且绑定账号的令牌。
 */
string hide_command(string userid, string cmd)
{
    string token;
    object key;
    if(!userid || !cmd)
        return "c_invalid";
    key = hidden_command_lock->lock();
    hidden_command_created++;
    if(hidden_command_created%256 == 0 ||
       sizeof(hidden_command_tokens) >= HIDDEN_COMMAND_LIMIT)
        cleanup_hidden_command_tokens_locked();
    do {
        token = "c_"+String.string2hex(Crypto.Random.random_string(24));
    } while(hidden_command_tokens[token]);
    hidden_command_next_serial++;
    hidden_command_tokens[token] = ([
        "userid":userid,
        "cmd":cmd,
        "created":time(),
        "expires":time()+HIDDEN_COMMAND_TTL,
        "serial":hidden_command_next_serial,
    ]);
    hidden_command_order[hidden_command_next_serial] = token;
    mapping(string:int) user_tokens = hidden_command_user_tokens[userid];
    if(!user_tokens) {
        user_tokens = ([]);
        hidden_command_user_tokens[userid] = user_tokens;
    }
    user_tokens[token] = 1;
    destruct(key);
    return token;
}

/**
 * 解码命令令牌；输入框可在令牌后附加用户输入内容。
 */
string unhide_command(string userid, string token_input)
{
    string token;
    string input = "";
    string result;
    mapping entry;
    object key;
    int space_pos;
    if(!userid || !token_input)
        return "look";
    token = token_input;
    space_pos = search(token_input," ");
    if(space_pos > 0) {
        token = token_input[0..space_pos-1];
        input = token_input[space_pos+1..];
    }
    if(!has_prefix(token,"c_"))
        return token_input;
    key = hidden_command_lock->lock();
    entry = hidden_command_tokens[token];
    if(!entry || (string)entry["userid"] != userid ||
       (int)entry["expires"] < time()) {
        if(entry && (int)entry["expires"] < time())
            remove_hidden_command_token_locked(token);
        reset_hidden_command_order_if_empty_locked();
        destruct(key);
        return "look";
    }
    result = (string)entry["cmd"];
    destruct(key);
    if(input != "")
        result += " "+input;
    return result;
}

/**
 * 清理用户的隐藏命令缓存
 */
void clear_hidden_commands(string userid)
{
    object key;
    if(!userid)
        return;
    key = hidden_command_lock->lock();
    mapping(string:int) user_tokens = hidden_command_user_tokens[userid];
    foreach(indices(user_tokens || ([])),string token)
        remove_hidden_command_token_locked(token);
    reset_hidden_command_order_if_empty_locked();
    destruct(key);
}
