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

/** Internal loopback-only resolver used by the Pike coordinator on a cold
 * token cache. Public clients cannot invoke this function directly. */
string query_account_session_owner_for_gateway(string token)
{
	return query_account_session(lower_case(String.trim_all_whites(token || "")));
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

private void attach_account_wallet_status(mapping result,string account_id)
{
	mapping wallet = ACCOUNT_WALLETD->query_account_wallet(account_id);
	result["shared_recharge_available"] = wallet["ok"] ? 1 : 0;
	result["shared_recharge_balance"] = wallet["ok"] ?
		(int)wallet["balance"] : 0;
}

private void attach_illusion_realm_status(mapping result)
{
	result["illusion_realm"] = SEASONALD->query_public_status();
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
	string client_ip = normalize_http_client_ip(
		req->remote_addr || "unknown");
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
	attach_account_wallet_status(account_data,account_id);
	attach_illusion_realm_status(account_data);
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
	attach_account_wallet_status(result,account_id);
	attach_illusion_realm_status(result);
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
	string name_cn;
	string sex;
	string avatar_id;
	string realm_type;
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
	name_cn = (string)(params["name_cn"] || "");
	sex = (string)(params["sex"] || "");
	avatar_id = (string)(params["avatar_id"] || "");
	realm_type = (string)(params["realm_type"] || "eternal");
	if(String.trim_all_whites(name_cn)=="" || sex=="" || avatar_id==""){
		send_json(req,(["error":"请完整选择人物姓名、性别和头像"]),400);
		return;
	}
	if(realm_type=="illusion")
		result = SEASONALD->create_illusion_character(account_id,
			race_id,profession_id,name_cn,sex,avatar_id);
	else if(realm_type=="eternal")
		result = ACCOUNT_CHARACTERD->create_character(account_id,
			race_id,profession_id,name_cn,sex,avatar_id);
	else{
		send_json(req,(["error":"人物世界类型无效"]),400);
		return;
	}
	if(!result["ok"]){
		send_json(req,(["error":result["message"] || "创建人物失败"]),409);
		return;
	}
	send_json(req,result,201);
}

void handle_api_character_profile(Protocols.HTTP.Server.Request req)
{
	mapping params;
	mapping auth;
	mapping result = ([]);
	string txd;
	string userid;
	object player;
	object user_mutex;
	object user_key;
	mixed update_err;
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST补全人物资料"]),405);
		return;
	}
	params = get_params(req);
	txd = url_decode((string)(params["txd"] || ""));
	auth = decode_txd(txd);
	if(!auth){
		send_json(req,(["error":"人物会话已过期，请重新登录"]),401);
		return;
	}
	userid = (string)auth["userid"];
	if(!authenticated_character_password_matches(userid,
		(string)(auth["password"] || ""))){
		send_json(req,(["error":"人物认证信息无效，请重新登录"]),401);
		return;
	}
	player = get_player_from_connection(userid,1);
	if(!player)
		player = find_player(userid);
	if(!player){
		send_json(req,(["error":"人物当前不在线，请重新登录"]),401);
		return;
	}
	user_mutex = query_user_command_mutex(userid);
	user_key = user_mutex->lock();
	update_err = catch {
		result = ACCOUNT_CHARACTERD->complete_character_profile(player,
			(string)(params["name_cn"] || ""),
			(string)(params["sex"] || ""),
			(string)(params["avatar_id"] || ""));
	};
	destruct(user_key);
	if(update_err){
		http_werror(" profile completion failed userid=%s error=%s\n",
			userid,describe_error(update_err));
		send_json(req,(["error":"人物资料保存失败，请稍后重试"]),500);
		return;
	}
	if(!(int)result["ok"]){
		send_json(req,(["error":result["message"] ||
			"人物资料补全失败"]),409);
		return;
	}
	send_json(req,result);
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
	bootstrap_command = ACCOUNT_CHARACTERD->query_bootstrap_command(
		account_id,character_id);
	// 人物中心点击属于玩家明确选择，允许重新进入此前因在线上限被
	// 清退的人物；后台轮询和旧标签页则仍会被/api/json拒绝。
	ACCOUNT_CHARACTERD->clear_recent_forced_logout(character_id);
	send_json(req,([
		"ok":1,
		"account_id":account_id,
		"character_id":character_id,
		"txd":generate_txd(character_id,password),
		"bootstrap_command":bootstrap_command,
	]));
}

void handle_api_account_bookmark_create(Protocols.HTTP.Server.Request req)
{
	mapping params;
	string token;
	string account_id;
	string character_id;
	string account_password;
	mapping result;
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST创建直达书签"]),405);
		return;
	}
	params = get_params(req);
	token = lower_case(String.trim_all_whites(
		(string)(params["token"] || "")));
	account_id = query_account_session(token);
	character_id = String.trim_all_whites(
		(string)(params["character_id"] || ""));
	if(account_id==""){
		send_json(req,(["error":"账号会话已过期，请重新登录"]),401);
		return;
	}
	if(!ACCOUNT_CHARACTERD->account_owns_character(account_id,character_id)){
		send_json(req,(["error":"人物不属于当前账号"]),403);
		return;
	}
	account_password = get_user_password(account_id);
	if(!account_password || account_password==""){
		send_json(req,(["error":"账号认证档案不可用"]),409);
		return;
	}
	result = ACCOUNT_CHARACTERD->create_character_bookmark(account_id,
		character_id,account_password);
	if(!(int)result["ok"]){
		send_json(req,(["error":result["message"] ||
			"直达书签创建失败"]),500);
		return;
	}
	// 原始书签令牌只在这一次TLS响应里返回。服务端磁盘只保存摘要。
	send_json(req,result,201);
}

void handle_api_account_bookmark_open(Protocols.HTTP.Server.Request req)
{
	mapping params;
	string requested_id;
	string account_id;
	string character_id;
	string bookmark_token;
	string account_password;
	string character_password;
	string bootstrap_command;
	mapping verified;
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST打开直达书签"]),405);
		return;
	}
	params = get_params(req);
	requested_id = String.trim_all_whites(
		(string)(params["userid"] || ""));
	character_id = String.trim_all_whites(
		(string)(params["character_id"] || ""));
	bookmark_token = lower_case(String.trim_all_whites(
		(string)(params["bookmark_token"] || "")));
	account_id = ACCOUNT_CHARACTERD->query_account_id_for_character(
		requested_id);
	account_password = get_user_password(account_id);
	verified = ACCOUNT_CHARACTERD->verify_character_bookmark(account_id,
		character_id,bookmark_token,account_password);
	if(!(int)verified["ok"]){
		// 不区分账号、人物、令牌和密码变更，避免书签入口泄露档案存在性。
		send_json(req,(["error":"直达书签无效、已撤销或账号密码已修改"]),401);
		return;
	}
	character_password = get_user_password(character_id);
	if(!character_password || character_password==""){
		send_json(req,(["error":"人物物理档案不可用"]),409);
		return;
	}
	bootstrap_command = ACCOUNT_CHARACTERD->query_bootstrap_command(
		account_id,character_id);
	ACCOUNT_CHARACTERD->clear_recent_forced_logout(character_id);
	send_json(req,([
		"ok":1,
		"account_id":account_id,
		"character_id":character_id,
		"txd":generate_txd(character_id,character_password),
		"bootstrap_command":bootstrap_command,
	]));
}

void handle_api_account_bookmark_revoke(Protocols.HTTP.Server.Request req)
{
	mapping params;
	string token;
	string account_id;
	string character_id;
	mapping result;
	if(req->request_type!="POST"){
		send_json(req,(["error":"请使用POST撤销直达书签"]),405);
		return;
	}
	params = get_params(req);
	token = lower_case(String.trim_all_whites(
		(string)(params["token"] || "")));
	account_id = query_account_session(token);
	character_id = String.trim_all_whites(
		(string)(params["character_id"] || ""));
	if(account_id==""){
		send_json(req,(["error":"账号会话已过期，请重新登录"]),401);
		return;
	}
	result = ACCOUNT_CHARACTERD->revoke_character_bookmarks(account_id,
		character_id);
	if(!(int)result["ok"]){
		send_json(req,(["error":result["message"] ||
			"直达书签撤销失败"]),409);
		return;
	}
	send_json(req,result);
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
