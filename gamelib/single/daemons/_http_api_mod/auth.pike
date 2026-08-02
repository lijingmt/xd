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

mapping hidden_commands = ([ ]);
mapping hidden_positions = ([ ]);

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

/**
 * 隐藏命令：将明文命令存储到数组，返回数字索引
 */
string hide_command(string userid, string cmd)
{
    if(!userid || !cmd) return "0";

    if(!hidden_commands[userid]) {
        hidden_commands[userid] = allocate(HIDDEN_SIZE);
        hidden_positions[userid] = 0;
    }

    array(string) cmds = hidden_commands[userid];
    int pos = hidden_positions[userid];

    if(pos >= HIDDEN_SIZE) {
        pos = 0;
    }

    cmds[pos] = cmd;
    hidden_positions[userid] = pos + 1;

    // http_werror(" hide_command: userid=%s, cmd=%s, index=%d\n", userid, cmd, pos);
    return (string)pos;
}

/**
 * 解码命令：将数字索引转换为实际命令
 */
string unhide_command(string userid, string index_str)
{
    if(!userid || !index_str) return "look";

    int index;

    if(!sscanf(index_str, "%d", index)) {
        return index_str;
    }

    if(!hidden_commands[userid]) {
        // http_werror(" unhide_command: no commands for userid=%s\n", userid);
        return "look";
    }

    array(string) cmds = hidden_commands[userid];

    if(index < 0 || index >= sizeof(cmds) || !cmds[index]) {
        // http_werror(" unhide_command: invalid index=%d for userid=%s\n", index, userid);
        return "look";
    }

    string cmd = cmds[index];
    // http_werror(" unhide_command: userid=%s, index=%d, cmd=%s\n", userid, index, cmd);
    return cmd;
}

/**
 * 清理用户的隐藏命令缓存
 */
void clear_hidden_commands(string userid)
{
    if(hidden_commands[userid]) {
        hidden_commands[userid] = 0;
        hidden_positions[userid] = 0;
        // http_werror(" clear_hidden_commands: userid=%s\n", userid);
    }
}
