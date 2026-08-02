/**
 * 多人物账号HTTP会话与选角接口。
 *
 * 游戏命令仍使用具体人物TXD；账号令牌只允许读取、创建和选择该账号的人物，
 * 不替代旧TXD，也不会改变旧Socket/JSP登录协议。
 */

#define ACCOUNT_SESSION_TTL (12*60*60)
#define ACCOUNT_SESSION_LIMIT 4096
#define ACCOUNT_SESSION_PER_ACCOUNT_LIMIT 8

mapping(string:mapping(string:mixed)) account_sessions = ([]);
Thread.Mutex account_sessions_lock = Thread.Mutex();

private void cleanup_account_sessions_unlocked()
{
	int now = time();
	foreach(indices(account_sessions),string token){
		mapping session = account_sessions[token];
		if(!session || (int)session["expires"]<=now)
			m_delete(account_sessions,token);
	}
}

private string create_account_session(string account_id)
{
	string token = "";
	object key = account_sessions_lock->lock();
	cleanup_account_sessions_unlocked();
	if(sizeof(account_sessions)<ACCOUNT_SESSION_LIMIT){
		array(string) owned_tokens = ({});
		foreach(indices(account_sessions),string one_token){
			mapping one_session = account_sessions[one_token];
			if(one_session && one_session["account_id"]==account_id)
				owned_tokens += ({one_token});
		}
		if(sizeof(owned_tokens)>=ACCOUNT_SESSION_PER_ACCOUNT_LIMIT){
			string oldest_token = owned_tokens[0];
			foreach(owned_tokens,string one_token){
				if((int)account_sessions[one_token]["created_at"]<
				   (int)account_sessions[oldest_token]["created_at"])
					oldest_token = one_token;
			}
			m_delete(account_sessions,oldest_token);
		}
		for(int attempt=0;attempt<10;attempt++){
			string candidate = String.string2hex(
				Crypto.Random.random_string(32));
			if(!account_sessions[candidate]){
				token = candidate;
				break;
			}
		}
		if(token!="")
			account_sessions[token] = ([
				"account_id":account_id,
				"created_at":time(),
				"expires":time()+ACCOUNT_SESSION_TTL,
			]);
	}
	destruct(key);
	return token;
}

private string query_account_session(string token)
{
	string account_id = "";
	object key;
	if(!token || sizeof(token)!=64)
		return "";
	key = account_sessions_lock->lock();
	cleanup_account_sessions_unlocked();
	if(account_sessions[token]){
		account_id = (string)account_sessions[token]["account_id"];
		account_sessions[token]["expires"] = time()+ACCOUNT_SESSION_TTL;
	}
	destruct(key);
	return account_id;
}

private void revoke_account_session(string token)
{
	object key;
	if(!token)
		return;
	key = account_sessions_lock->lock();
	m_delete(account_sessions,token);
	destruct(key);
}

void revoke_account_sessions_for(string account_id)
{
	object key;
	if(!account_id)
		return;
	key = account_sessions_lock->lock();
	foreach(indices(account_sessions),string token){
		mapping session = account_sessions[token];
		if(session && session["account_id"]==account_id)
			m_delete(account_sessions,token);
	}
	destruct(key);
}

mapping query_account_session_status()
{
	mapping result;
	object key = account_sessions_lock->lock();
	cleanup_account_sessions_unlocked();
	result = ([
		"active":sizeof(account_sessions),
		"limit":ACCOUNT_SESSION_LIMIT,
		"ttl_seconds":ACCOUNT_SESSION_TTL,
	]);
	destruct(key);
	return result;
}

private void send_account_auth_error(Protocols.HTTP.Server.Request req,
	string client_ip)
{
	record_login_failure(client_ip);
	send_json(req,(["error":"账号或密码错误"]),401);
}

void handle_api_account_login(Protocols.HTTP.Server.Request req)
{
	mapping params;
	string requested_id;
	string password;
	string challenge;
	string account_id;
	string stored_password;
	string token;
	string client_ip = req->remote_addr || "unknown";
	mapping account_data;
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST登录账号"]),405);
		return;
	}
	if(check_login_rate_limit(client_ip)){
		send_json(req,(["error":"登录尝试过于频繁，请稍后再试"]),429);
		return;
	}
	params = get_params(req);
	requested_id = (string)(params["userid"] || "");
	password = (string)(params["password"] || "");
	challenge = (string)(params["challenge"] || "");
	account_id = ACCOUNT_CHARACTERD->
		query_account_id_for_character(requested_id);
	stored_password = get_user_password(account_id);
	if(!stored_password || stored_password==""){
		send_account_auth_error(req,client_ip);
		return;
	}
	if(challenge!=""){
		if(!verify_password_hash(challenge,password,stored_password)){
			send_account_auth_error(req,client_ip);
			return;
		}
	}
	else if(password!=stored_password){
		send_account_auth_error(req,client_ip);
		return;
	}
	account_data = ACCOUNT_CHARACTERD->query_account_characters(account_id);
	if(!account_data["ok"]){
		send_json(req,(["error":"账号人物档案不可用"]),409);
		return;
	}
	token = create_account_session(account_id);
	if(token==""){
		send_json(req,(["error":"账号会话繁忙，请稍后再试"]),503);
		return;
	}
	reset_login_failures(client_ip);
	account_data["token"] = token;
	account_data["expires_in"] = ACCOUNT_SESSION_TTL;
	send_json(req,account_data);
}

void handle_api_account_characters(Protocols.HTTP.Server.Request req)
{
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST读取人物档案"]),405);
		return;
	}
	mapping params = get_params(req);
	string token = (string)(params["token"] || "");
	string account_id = query_account_session(token);
	mapping result;
	if(account_id==""){
		send_json(req,(["error":"账号会话已过期，请重新登录"]),401);
		return;
	}
	result = ACCOUNT_CHARACTERD->query_account_characters(account_id);
	if(!result["ok"]){
		send_json(req,(["error":result["message"] ||
			"账号人物档案不可用"]),409);
		return;
	}
	result["expires_in"] = ACCOUNT_SESSION_TTL;
	send_json(req,result);
}

void handle_api_account_character_create(Protocols.HTTP.Server.Request req)
{
	mapping params;
	string token;
	string account_id;
	string race_id;
	string profession_id;
	mapping result;
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST创建人物"]),405);
		return;
	}
	params = get_params(req);
	token = (string)(params["token"] || "");
	account_id = query_account_session(token);
	if(account_id==""){
		send_json(req,(["error":"账号会话已过期，请重新登录"]),401);
		return;
	}
	race_id = (string)(params["race_id"] || "");
	profession_id = (string)(params["profession_id"] || "");
	result = ACCOUNT_CHARACTERD->create_character(account_id,
		race_id,profession_id);
	if(!result["ok"]){
		send_json(req,(["error":result["message"] || "创建人物失败"]),409);
		return;
	}
	send_json(req,result,201);
}

private int disconnect_account_siblings(string account_id,
	string selected_id)
{
	array(string) character_ids = ACCOUNT_CHARACTERD->
		query_character_ids(account_id);
	foreach(character_ids,string character_id){
		mixed connection;
		object player;
		object user_key;
		if(character_id==selected_id)
			continue;
		// 与非核心命令线程池复用同一把人物锁，不能在命令执行中途保存
		// 或销毁人物对象。
		user_key = query_user_command_mutex(character_id)->lock();
		connection = get_virtual_connection(character_id);
		if(!arrayp(connection) || sizeof(connection)<3){
			destruct(user_key);
			continue;
		}
		player = connection[2];
		if(player){
			int saved = 0;
			mixed err = catch{
				if(functionp(player->save_with_result))
					saved = player->save_with_result();
			};
			if(err || !saved){
				destruct(user_key);
				http_werror(" account sibling save failed: %s\n",
					character_id);
				return 0;
			}
			remove_virtual_connection(character_id);
			err = catch{
				player->remove();
			};
			if(err)
				http_werror(" account sibling disconnect failed: %s\n",
					describe_error(err));
		}
		else
			remove_virtual_connection(character_id);
		destruct(user_key);
	}
	return 1;
}

void handle_api_account_character_select(Protocols.HTTP.Server.Request req)
{
	mapping params;
	string token;
	string account_id;
	string character_id;
	string password;
	string bootstrap_command;
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST选择人物"]),405);
		return;
	}
	params = get_params(req);
	token = (string)(params["token"] || "");
	account_id = query_account_session(token);
	character_id = (string)(params["character_id"] || "");
	if(account_id==""){
		send_json(req,(["error":"账号会话已过期，请重新登录"]),401);
		return;
	}
	if(!ACCOUNT_CHARACTERD->account_owns_character(account_id,character_id)){
		send_json(req,(["error":"人物不属于当前账号"]),403);
		return;
	}
	password = get_user_password(character_id);
	if(!password || password==""){
		send_json(req,(["error":"人物物理档案不可用"]),409);
		return;
	}
	if(!disconnect_account_siblings(account_id,character_id)){
		send_json(req,(["error":"当前人物保存失败，请稍后重试"]),503);
		return;
	}
	bootstrap_command = ACCOUNT_CHARACTERD->query_bootstrap_command(
		account_id,character_id);
	send_json(req,([
		"ok":1,
		"account_id":account_id,
		"character_id":character_id,
		"txd":generate_txd(character_id,password),
		"bootstrap_command":bootstrap_command,
	]));
}

void handle_api_account_logout(Protocols.HTTP.Server.Request req)
{
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST退出账号"]),405);
		return;
	}
	mapping params = get_params(req);
	string token = (string)(params["token"] || "");
	revoke_account_session(token);
	send_json(req,(["ok":1]));
}
