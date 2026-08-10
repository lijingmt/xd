/**
 * Pike map-worker gateway.
 *
 * The coordinator Pike process owns both the routing control plane and the
 * transparent public HTTP proxy.  It never executes player commands locally:
 * every public request is fenced, sent to exactly one loopback worker and
 * reconciled before its account/user transaction lock is released.
 *
 * This module is included by http_api_daemon.pike.  The normal standalone and
 * worker roles do not initialize it.
 */

constant PIKE_GATEWAY_MAX_BODY_BYTES = 1048576;
constant PIKE_GATEWAY_USER_LOCKS = 4096;
constant PIKE_GATEWAY_MAX_PENDING = 128;
constant PIKE_GATEWAY_MAX_UNCERTAIN = 1024;
constant PIKE_GATEWAY_MAX_RECONCILE_USERS = 20000;

private multiset(string) pike_gateway_hop_headers = (<
	"connection","keep-alive","proxy-authenticate",
	"proxy-authorization","te","trailers","transfer-encoding","upgrade"
>);

private Protocols.HTTP.Server.Port pike_gateway_public_port;
private object pike_gateway_request_farm;
private object pike_gateway_controller_thread;
private Thread.Mutex pike_gateway_state_lock = Thread.Mutex();
private Thread.Mutex pike_gateway_identity_lock = Thread.Mutex();
private Thread.Mutex pike_gateway_account_resolver_lock = Thread.Mutex();
private Thread.Mutex pike_gateway_recovery_lock = Thread.Mutex();
private Thread.Mutex pike_gateway_assignment_lock = Thread.Mutex();
private Thread.Mutex pike_gateway_account_management_lock = Thread.Mutex();
private Thread.Mutex pike_gateway_auction_lock = Thread.Mutex();
private array(object) pike_gateway_user_locks = ({});
private object pike_gateway_account_resolver;

private mapping(string:int) pike_gateway_worker_ports = ([]);
private mapping(string:int) pike_gateway_generations = ([]);
private mapping(string:int) pike_gateway_worker_reachable = ([]);
private mapping(string:array(mapping(string:mixed)))
	pike_gateway_online_rows_by_worker = ([]);
private mapping(string:int) pike_gateway_online_rows_at = ([]);
private mapping(string:string) pike_gateway_account_by_user = ([]);
private mapping(string:mapping(string:mixed)) pike_gateway_account_by_token = ([]);
private mapping(string:string) pike_gateway_account_last_worker = ([]);
private mapping(string:int) pike_gateway_account_cache_epoch = ([]);
private mapping(string:mapping(string:mixed)) pike_gateway_background_arrivals = ([]);
private multiset(string) pike_gateway_pending_reconcile_users = (<>);
private multiset(string) pike_gateway_uncertain_requests = (<>);
private multiset(string) pike_gateway_uncertain_done = (<>);

private string pike_gateway_token = "";
private string pike_gateway_primary = "";
private string pike_gateway_controller_nonce = "";
private string pike_gateway_last_error = "";
private int pike_gateway_worker_capacity = 100;
private int pike_gateway_listen_port = 8888;
private int pike_gateway_timeout = 30;
private int pike_gateway_control_timeout = 2;
private int pike_gateway_max_requests = 128;
private int pike_gateway_lease_gc_seconds = 3600;
private int pike_gateway_shadow = 1;
private int pike_gateway_enabled;
private int pike_gateway_controller_ready;
private int pike_gateway_routing_ready;
private int pike_gateway_stop;
private int pike_gateway_active_requests;
private int pike_gateway_pending_requests;
private int pike_gateway_completed_requests;
private int pike_gateway_failed_requests;
private int pike_gateway_rejected_requests;
private int pike_gateway_started_at;
private int pike_gateway_last_monitor_at;
private int pike_gateway_last_handoff_at;
private int pike_gateway_last_auction_at;
private int pike_gateway_last_lease_gc_at;
private int pike_gateway_shutdown_prepared;

private int pike_gateway_env_int(string name,int fallback,int minimum,
	int maximum)
{
	string raw = String.trim_all_whites(getenv(name) || "");
	int value = fallback;
	if(raw!="" && (string)(int)raw!=raw)
		error("invalid integer environment value: "+name+"\n");
	if(raw!="")
		value = (int)raw;
	if(value<minimum || value>maximum)
		error("environment value out of range: "+name+"\n");
	return value;
}

private string pike_gateway_digest(string source)
{
	object hash = Crypto.SHA256();
	hash->update(source || "");
	return lower_case(String.string2hex(hash->digest()));
}

private string pike_gateway_random_hex(int bytes)
{
	return lower_case(String.string2hex(Crypto.Random.random_string(bytes)));
}

private int pike_gateway_valid_userid(string userid)
{
	string allowed = "abcdefghijklmnopqrstuvwxyz0123456789_.-";
	if(sizeof(userid)<2 || sizeof(userid)>64 || search(userid,"..")!=-1)
		return 0;
	for(int index=0;index<sizeof(userid);index++)
		if(search(allowed,sprintf("%c",userid[index]))==-1)
			return 0;
	return 1;
}

private int pike_gateway_valid_hex_token(string token,int size)
{
	if(sizeof(token)!=size)
		return 0;
	for(int index=0;index<sizeof(token);index++)
		if(search("0123456789abcdef",sprintf("%c",token[index]))==-1)
			return 0;
	return 1;
}

private string pike_gateway_decode_txd_userid(string txd)
{
	array(string) parts = txd / "~";
	string encoded;
	string decoded = "";
	if(sizeof(parts)<2)
		return "";
	encoded = parts[0];
	if(encoded=="" || sizeof(encoded)>128)
		return "";
	for(int index=0;index<sizeof(encoded);index++){
		int offset = index/2==0 ? 2 : 1;
		int value = encoded[index]-offset;
		if(value<0 || value>127)
			return "";
		decoded += sprintf("%c",value);
	}
	return lower_case(String.trim_all_whites(decoded));
}

private mapping(string:mixed) pike_gateway_extract_params(mapping snapshot)
{
	mapping(string:mixed) params = ([]);
	string query = (string)snapshot["query"];
	string body = (string)snapshot["body"];
	mapping headers = (mapping)snapshot["headers"];
	string content_type = lower_case((string)(headers["content-type"] || ""));
	if(query!=""){
		array(string) fields = query / "&";
		if(sizeof(fields)>128)
			error("too many query fields\n");
		foreach(fields,string field){
			array(string) pair = field / "=";
			string key;
			string value;
			if(sizeof(pair)<2)
				continue;
			key = url_decode(pair[0]);
			value = url_decode(pair[1..]*"=");
			if(sizeof(key)>128 || sizeof(value)>4096)
				error("request parameter too large\n");
			params[key] = value;
		}
	}
	if(body!="" && search(content_type,"json")!=-1){
		mixed decoded;
		mixed decode_err = catch { decoded = Standards.JSON.decode(body); };
		if(!decode_err && mappingp(decoded))
			params |= (mapping)decoded;
	}
	else if(body!="" && search(content_type,"x-www-form-urlencoded")!=-1){
		array(string) fields = body / "&";
		if(sizeof(fields)>128)
			error("too many form fields\n");
		foreach(fields,string field){
			array(string) pair = field / "=";
			if(sizeof(pair)>=2){
				string key = url_decode(pair[0]);
				string value = url_decode(pair[1..]*"=");
				if(sizeof(key)>128 || sizeof(value)>4096)
					error("request parameter too large\n");
				params[key] = value;
			}
		}
	}
	return params;
}

private string pike_gateway_extract_userid(mapping params)
{
	multiset(string) candidates = (<>);
	foreach(({"userid","character_id","auth_userid"}),string key){
		mixed raw = params[key];
		if(stringp(raw)){
			string candidate = lower_case(String.trim_all_whites((string)raw));
			if(pike_gateway_valid_userid(candidate))
				candidates[candidate] = 1;
		}
	}
	if(stringp(params["txd"])){
		string candidate = pike_gateway_decode_txd_userid(
			url_decode((string)params["txd"]));
		if(pike_gateway_valid_userid(candidate))
			candidates[candidate] = 1;
	}
	if(sizeof(candidates)>1)
		error("conflicting request identities\n");
	return sizeof(candidates) ? indices(candidates)[0] : "";
}

private string pike_gateway_extract_account_token(mapping params)
{
	if(!stringp(params["token"]))
		return "";
	string token = lower_case(String.trim_all_whites((string)params["token"]));
	return pike_gateway_valid_hex_token(token,64) ? token : "";
}

private string pike_gateway_extract_command(mapping params)
{
	if(!stringp(params["cmd"]))
		return "";
	// Command arguments can contain case-sensitive passwords, messages and
	// form values. Normalize only routing metadata, never the forwarded command.
	return String.trim_all_whites((string)params["cmd"]);
}

private string pike_gateway_command_verb(string command)
{
	string normalized = String.trim_all_whites(command || "");
	int space = search(normalized," ");
	if(space!=-1)
		normalized = normalized[0..space-1];
	return lower_case(normalized);
}

/** Serialize creation of the one canonical archive even before login exists. */
private string pike_gateway_registration_target(string command)
{
	array(string) parts = (command || "")/" ";
	string userid;
	parts -= ({""});
	if(sizeof(parts)<6 || lower_case(parts[0])!="login_regnew" ||
	   lower_case(parts[1])!="gamelib")
		return "";
	userid = lower_case(String.trim_all_whites(parts[2]));
	// Old JSP: login_regnew project user pass sid logical_zone ...
	if(sizeof(parts)>=9 && sizeof(parts[5])==4 &&
	   (has_prefix(parts[5],"xd") || has_prefix(parts[5],"tx")) &&
	   parts[5][2]>='0' && parts[5][2]<='9' &&
	   parts[5][3]>='0' && parts[5][3]<='9')
		userid = lower_case(parts[5]+userid);
	return pike_gateway_valid_userid(userid) ? userid : "";
}

private int pike_gateway_auction_command(string command)
{
	string first = pike_gateway_command_verb(command);
	return first=="vendue" || has_prefix(first,"vendue_");
}

private mapping(string:mixed) pike_gateway_admin_recharge_target(
	string command)
{
	string target_userid = "";
	string request_id = "";
	string account_id;
	string worker_id;
	int fee;
	int epoch;
	mapping route;
	string verb = "";
	if(sscanf(command,"%s %s %d %s",verb,target_userid,fee,request_id)!=4 ||
	   lower_case(verb)!="txadd")
		return ([]);
	target_userid = lower_case(target_userid);
	request_id = lower_case(request_id);
	if(!pike_gateway_valid_userid(target_userid) || fee<=0 ||
	   fee>100000000 || !pike_gateway_valid_hex_token(request_id,64))
		return ([]);
	account_id = pike_gateway_resolve_account(target_userid);
	route = MAP_WORKERD->query_player_route(target_userid);
	if((int)route["ok"]){
		worker_id = (string)route["worker_id"];
		epoch = (int)route["epoch"];
	}
	else if((string)route["code"]=="lease_missing"){
		worker_id = pike_gateway_primary;
		epoch = 0;
	}
	else
		error("admin target route is not settled\n");
	if(!pike_gateway_worker_ports[worker_id] ||
	   !pike_gateway_worker_is_reachable(worker_id))
		error("admin target worker is unavailable\n");
	return (["userid":target_userid,"account_id":account_id,
		"worker_id":worker_id,"epoch":epoch,"fee":fee,
		"recharge_request_id":request_id]);
}

private int pike_gateway_account_path(string path)
{
	return has_prefix(path,"/api/account/");
}

private int pike_gateway_response_header_allowed(string name)
{
	name = lower_case(name || "");
	return !pike_gateway_hop_headers[name] &&
		!has_prefix(name,"x-xiand-") &&
		!has_value(({"server","date","content-length"}),name);
}

private int pike_gateway_has_transfer_encoding(mapping headers)
{
	mixed value = headers["transfer-encoding"];
	if(!value)
		return 0;
	if(stringp(value))
		return String.trim_all_whites((string)value)!="";
	/* Multiple or non-string framing values are ambiguous and fail closed. */
	return 1;
}

/** Pure-value probes used by TestUnit; they never start workers or mutate data. */
mapping test_pike_gateway_parse_snapshot(mapping snapshot)
{
	mapping params = pike_gateway_extract_params(copy_value(snapshot));
	return ([
		"userid":pike_gateway_extract_userid(params),
		"token":pike_gateway_extract_account_token(params),
		"command":pike_gateway_extract_command(params),
	]);
}

int test_pike_gateway_userid(string userid)
{
	return pike_gateway_valid_userid(userid);
}

int test_pike_gateway_auction(string command)
{
	return pike_gateway_auction_command(command);
}

int test_pike_gateway_header(string name)
{
	return pike_gateway_response_header_allowed(name);
}

int test_pike_gateway_transfer_encoding(mapping headers)
{
	return pike_gateway_has_transfer_encoding(headers);
}

mapping test_pike_gateway_migration_plan(string source_worker,
	mapping migration,int before_command)
{
	return pike_gateway_migration_plan(source_worker,migration,before_command);
}

string test_pike_gateway_registration(string command)
{
	return pike_gateway_registration_target(
		String.trim_all_whites(command || ""));
}

private object pike_gateway_user_mutex(string userid,string account_hint)
{
	string identity;
	int hash_value;
	object key;
	if(pike_gateway_valid_userid(account_hint)){
		key = pike_gateway_identity_lock->lock();
		pike_gateway_account_by_user[userid] = account_hint;
		destruct(key);
	}
	key = pike_gateway_identity_lock->lock();
	identity = pike_gateway_account_by_user[userid] || userid;
	destruct(key);
	sscanf(pike_gateway_digest(identity)[0..3],"%x",hash_value);
	return pike_gateway_user_locks[hash_value%PIKE_GATEWAY_USER_LOCKS];
}

mapping query_pike_gateway_status()
{
	object key = pike_gateway_state_lock->lock();
	mapping result = ([
		"ok":pike_gateway_enabled ? 1 : 0,
		"enabled":pike_gateway_enabled,
		"shadow":pike_gateway_shadow,
		"controller_ready":pike_gateway_controller_ready,
		"routing_ready":pike_gateway_routing_ready,
		"public_listening":pike_gateway_public_port ? 1 : 0,
		"listen_port":pike_gateway_listen_port,
		"primary_worker":pike_gateway_primary,
		"worker_count":sizeof(pike_gateway_worker_ports),
		"control_timeout":pike_gateway_control_timeout,
		"active_requests":pike_gateway_active_requests,
		"pending_requests":pike_gateway_pending_requests,
		"uncertain_requests":sizeof(pike_gateway_uncertain_requests),
		"pending_reconcile_users":sizeof(pike_gateway_pending_reconcile_users),
		"background_arrivals":sizeof(pike_gateway_background_arrivals),
		"shutdown_prepared":pike_gateway_shutdown_prepared,
		"completed_requests":pike_gateway_completed_requests,
		"failed_requests":pike_gateway_failed_requests,
		"rejected_requests":pike_gateway_rejected_requests,
		"started_at":pike_gateway_started_at,
		"last_error":pike_gateway_last_error,
	]);
	destruct(key);
	return result;
}

mapping query_pike_gateway_online_users()
{
	mapping(string:mapping(string:mixed)) by_user = ([]);
	mapping(string:int) counts = ([]);
	array(mapping(string:mixed)) users = ({});
	if(MAP_WORKERD->query_node_role()!="gateway" ||
	   !pike_gateway_controller_ready)
		return (["ok":0,"code":"gateway_not_ready"]);
	foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
		array worker_users;
		int rows_at;
		int worker_reachable;
		object cache_key = pike_gateway_state_lock->lock();
		worker_users = copy_value(pike_gateway_online_rows_by_worker[worker_id]);
		rows_at = pike_gateway_online_rows_at[worker_id];
		worker_reachable = pike_gateway_worker_reachable[worker_id];
		destruct(cache_key);
		if(!arrayp(worker_users) || rows_at<time()-15 || !worker_reachable)
			return (["ok":0,"code":"worker_online_snapshot_stale",
				"worker_id":worker_id]);
		foreach(worker_users,mixed raw){
			mapping row;
			mapping route;
			string userid;
			if(!mappingp(raw))
				return (["ok":0,"code":"invalid_online_row"]);
			row = (mapping)raw;
			userid = (string)row["userid"];
			if(!pike_gateway_valid_userid(userid) ||
			   (string)row["worker_id"]!=worker_id ||
			   (int)row["epoch"]<1 || by_user[userid])
				return (["ok":0,"code":by_user[userid] ?
					"duplicate_online_owner" : "invalid_online_owner",
					"userid":userid]);
			route = MAP_WORKERD->query_player_route(userid);
			if(!(int)route["ok"] || (string)route["state"]!="active" ||
			   (string)route["worker_id"]!=worker_id ||
			   (int)route["epoch"]!=(int)row["epoch"])
				return (["ok":0,"code":"online_route_mismatch",
					"userid":userid]);
			by_user[userid] = copy_value(row);
			counts[worker_id]++;
		}
	}
	foreach(sort(indices(by_user)),string userid)
		users += ({by_user[userid]});
	return (["ok":1,"count":sizeof(users),"users":users,
		"worker_counts":counts,"worker_count":sizeof(pike_gateway_worker_ports),
		"snapshot_at":time()]);
}

/**
 * Fail-closed shutdown barrier used by the local/Docker supervisors.
 * No worker receives a shutdown-save capability until public routing is
 * paused, accepted requests are drained and uncertain work is reconciled.
 */
private mapping pike_gateway_prepare_shutdown(array failed_workers)
{
	object recovery_key;
	object key;
	multiset(string) skipped_workers = (<>);
	int deadline;
	int active;
	int pending;
	int uncertain;
	int reconcile;
	int background;
	int failover = sizeof(failed_workers) ? 1 : 0;
	mixed prepare_err;
	if(MAP_WORKERD->query_node_role()!="gateway" || !pike_gateway_enabled)
		return (["ok":0,"code":"gateway_not_active"]);
	foreach(failed_workers,mixed raw_worker_id){
		string worker_id = (string)raw_worker_id;
		if(!pike_gateway_worker_ports[worker_id] || skipped_workers[worker_id])
			return (["ok":0,"code":"invalid_failed_worker"]);
		skipped_workers[worker_id] = 1;
	}
	if(failover){
		key = pike_gateway_state_lock->lock();
		foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
			if(skipped_workers[worker_id] &&
			   pike_gateway_worker_reachable[worker_id]){
				destruct(key);
				return (["ok":0,"code":"failed_worker_still_reachable",
					"worker_id":worker_id]);
			}
			if(!skipped_workers[worker_id] &&
			   !pike_gateway_worker_reachable[worker_id]){
				destruct(key);
				return (["ok":0,"code":"unlisted_unreachable_worker",
					"worker_id":worker_id]);
			}
		}
		destruct(key);
	}
	key = pike_gateway_state_lock->lock();
	if(pike_gateway_shutdown_prepared){
		destruct(key);
		return (["ok":1,"routing_ready":0,"active_requests":0,
			"pending_requests":0,"uncertain_requests":0,
			"pending_reconcile_users":0,"background_arrivals":0,
			"worker_count":sizeof(pike_gateway_worker_ports),
			"replayed":1]);
	}
	destruct(key);
	recovery_key = pike_gateway_recovery_lock->trylock();
	if(!recovery_key)
		return (["ok":0,"code":"gateway_recovery_busy"]);
	// Pause admission without waiting here. The bounded loop below must also
	// cover a request which is stuck inside a worker.
	key = pike_gateway_state_lock->lock();
	pike_gateway_routing_ready = 0;
	destruct(key);
	deadline = time()+30;
	while(1){
		key = pike_gateway_state_lock->lock();
		active = pike_gateway_active_requests;
		pending = pike_gateway_pending_requests;
		uncertain = sizeof(pike_gateway_uncertain_requests);
		reconcile = sizeof(pike_gateway_pending_reconcile_users);
		background = sizeof(pike_gateway_background_arrivals);
		destruct(key);
		if(!active && !pending && !uncertain &&
		   (!failover || (!reconcile && !background)))
			break;
		if(time()>=deadline){
			destruct(recovery_key);
			return (["ok":0,"code":"gateway_not_quiescent",
				"active_requests":active,"pending_requests":pending,
				"uncertain_requests":uncertain,
				"pending_reconcile_users":reconcile,
				"background_arrivals":background]);
		}
		sleep(0.01);
	}
	prepare_err = catch {
		// A failed client response may leave a committed arrival without a
		// process owner. A full all-worker inventory is the only safe proof for
		// retiring that exact route before shutdown.
		if(!failover)
			pike_gateway_recover_local_players();
		key = pike_gateway_state_lock->lock();
		reconcile = sizeof(pike_gateway_pending_reconcile_users);
		background = sizeof(pike_gateway_background_arrivals);
		foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
			if(skipped_workers[worker_id] &&
			   pike_gateway_worker_reachable[worker_id]){
				destruct(key);
				error("failed worker became reachable: "+worker_id+"\n");
			}
			if(!skipped_workers[worker_id] &&
			   !pike_gateway_worker_reachable[worker_id]){
				destruct(key);
				error("unlisted unreachable worker: "+worker_id+"\n");
			}
		}
		destruct(key);
		if(reconcile || background)
			error("gateway recovery left pending arrivals\n");
		foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
			if(skipped_workers[worker_id])
				continue;
			mapping prepared = pike_gateway_worker_rpc(worker_id,
				"local_prepare_shutdown",([]));
			if(!(int)prepared["ok"])
				error("worker refused shutdown fence: "+worker_id+"\n");
		}
	};
	if(prepare_err){
		destruct(recovery_key);
		return (["ok":0,"code":"worker_shutdown_fence_failed"]);
	}
	key = pike_gateway_state_lock->lock();
	pike_gateway_stop = 1;
	pike_gateway_controller_ready = 0;
	pike_gateway_shutdown_prepared = 1;
	pike_gateway_last_error = "shutdown quiesced";
	destruct(key);
	destruct(recovery_key);
	return (["ok":1,"routing_ready":0,"active_requests":0,
		"pending_requests":0,"uncertain_requests":0,
		"pending_reconcile_users":0,"background_arrivals":0,
		"worker_count":sizeof(pike_gateway_worker_ports),
		"failed_workers":sort(indices(skipped_workers))]);
}

mapping prepare_pike_gateway_shutdown()
{
	return pike_gateway_prepare_shutdown(({}));
}

mapping prepare_pike_gateway_failover_shutdown(array failed_workers)
{
	if(!sizeof(failed_workers))
		return (["ok":0,"code":"failover_requires_failed_worker"]);
	return pike_gateway_prepare_shutdown(failed_workers);
}

private mapping pike_gateway_http_request(string worker_id,string method,
	string path,mapping headers,string body,void|int request_timeout)
{
	int port = pike_gateway_worker_ports[worker_id];
	object query;
	object response;
	string data;
	mapping response_headers;
	if(port<1024 || port>65535 || !has_prefix(path,"/"))
		error("invalid worker HTTP target\n");
	query = Protocols.HTTP.Query();
	query->maxtime = request_timeout || pike_gateway_timeout;
	response = Protocols.HTTP.do_method(method,
		"http://127.0.0.1:"+(string)port+path,0,headers,query,body || "");
	if(!response)
		error("worker HTTP request failed: "+worker_id+"\n");
	data = response->data(PIKE_GATEWAY_MAX_BODY_BYTES+1);
	if(sizeof(data)>PIKE_GATEWAY_MAX_BODY_BYTES)
		error("worker HTTP response exceeded limit\n");
	response_headers = mappingp(response->headers) ?
		copy_value(response->headers) : ([]);
	return ([
		"status":(int)response->status,
		"reason":(string)(response->status_desc || ""),
		"headers":response_headers,
		"body":data || "",
	]);
}

private mapping pike_gateway_worker_rpc(string worker_id,string action,
	mapping params)
{
	mapping headers = ([
		"Content-Type":"application/json",
		"X-Xiand-Worker-Token":pike_gateway_token,
	]);
	mapping payload = copy_value(params || ([]));
	mapping http_result;
	mapping decoded;
	mixed decode_err;
	payload["action"] = action;
	http_result = pike_gateway_http_request(worker_id,"POST",
		"/internal/map-worker",headers,Standards.JSON.encode(payload),
		pike_gateway_control_timeout);
	decode_err = catch { decoded = Standards.JSON.decode(
		(string)http_result["body"]); };
	if(decode_err || !mappingp(decoded))
		error("worker returned invalid RPC JSON: "+worker_id+"\n");
	return decoded;
}

private void pike_gateway_record_account(string userid,string account_id)
{
	object key;
	if(!pike_gateway_valid_userid(userid) ||
	   !pike_gateway_valid_userid(account_id))
		return;
	key = pike_gateway_identity_lock->lock();
	pike_gateway_account_by_user[userid] = account_id;
	destruct(key);
}

private void pike_gateway_record_account_token(string token,string account_id)
{
	object key;
	string oldest = "";
	int oldest_expiry = 0;
	if(!pike_gateway_valid_hex_token(token,64) ||
	   !pike_gateway_valid_userid(account_id))
		return;
	key = pike_gateway_identity_lock->lock();
	if(!pike_gateway_account_by_token[token] &&
	   sizeof(pike_gateway_account_by_token)>=4096){
		foreach(indices(pike_gateway_account_by_token),string one){
			int expiry = (int)pike_gateway_account_by_token[one]["expires_at"];
			if(oldest=="" || expiry<oldest_expiry){
				oldest = one;
				oldest_expiry = expiry;
			}
		}
		if(oldest!="")
			m_delete(pike_gateway_account_by_token,oldest);
	}
	pike_gateway_account_by_token[token] = ([
		"account_id":account_id,"expires_at":time()+43200,
	]);
	destruct(key);
}

private string pike_gateway_account_for_token(string token)
{
	object key;
	mapping cached;
	string result = "";
	if(!pike_gateway_valid_hex_token(token,64))
		return "";
	key = pike_gateway_identity_lock->lock();
	cached = pike_gateway_account_by_token[token];
	if(mappingp(cached) && (int)cached["expires_at"]>=time())
		result = (string)cached["account_id"];
	else
		m_delete(pike_gateway_account_by_token,token);
	destruct(key);
	return result;
}

/**
 * Map nodes intentionally skip most eager daemons. The first burst of browser
 * polls can therefore race Pike's lazy account daemon construction and observe
 * an object whose public functions are not installed yet. Publish exactly one
 * fully constructed resolver before account lookups run concurrently.
 */
private object pike_gateway_account_resolver_daemon()
{
	object resolver;
	object key;
	if(objectp(pike_gateway_account_resolver) && functionp(
	   pike_gateway_account_resolver->query_account_id_for_character))
		return pike_gateway_account_resolver;
	key = pike_gateway_account_resolver_lock->lock();
	resolver = pike_gateway_account_resolver;
	if(!objectp(resolver) || !functionp(
	   resolver->query_account_id_for_character)){
		resolver = (object)(ROOT+
			"/gamelib/single/daemons/account_characterd.pike");
		if(!objectp(resolver) || !functionp(
		   resolver->query_account_id_for_character)){
			destruct(key);
			error("account character resolver is not ready\n");
		}
		pike_gateway_account_resolver = resolver;
	}
	destruct(key);
	return resolver;
}

private string pike_gateway_resolve_account(string userid)
{
	object key;
	object resolver;
	string account_id;
	key = pike_gateway_identity_lock->lock();
	account_id = pike_gateway_account_by_user[userid] || "";
	destruct(key);
	if(pike_gateway_valid_userid(account_id))
		return account_id;
	resolver = pike_gateway_account_resolver_daemon();
	account_id = lower_case(String.trim_all_whites((string)
		resolver->query_account_id_for_character(userid)));
	if(!pike_gateway_valid_userid(account_id))
		error("cannot resolve account owner for "+userid+"\n");
	pike_gateway_record_account(userid,account_id);
	return account_id;
}

private string pike_gateway_account_cache_token(string account_id,
	string worker_id)
{
	object key;
	int epoch;
	key = pike_gateway_identity_lock->lock();
	if(pike_gateway_account_last_worker[account_id]!=worker_id){
		pike_gateway_account_last_worker[account_id] = worker_id;
		pike_gateway_account_cache_epoch[account_id] =
			(pike_gateway_account_cache_epoch[account_id] || 0)+1;
	}
	epoch = pike_gateway_account_cache_epoch[account_id] || 1;
	destruct(key);
	return pike_gateway_digest(pike_gateway_controller_nonce+"|"+
		account_id+"|"+(string)epoch);
}

private int pike_gateway_worker_is_reachable(string worker_id)
{
	object key = pike_gateway_state_lock->lock();
	int reachable = pike_gateway_worker_reachable[worker_id];
	destruct(key);
	return reachable;
}

private void pike_gateway_set_worker_reachable(string worker_id,int reachable)
{
	object key = pike_gateway_state_lock->lock();
	pike_gateway_worker_reachable[worker_id] = reachable ? 1 : 0;
	destruct(key);
}

private void pike_gateway_observe_account_response(string path,
	string request_token,mapping response)
{
	mapping payload;
	string token;
	string account_id;
	mixed decode_err;
	if((int)response["status"]>=400)
		return;
	if(path=="/api/account/logout"){
		object key = pike_gateway_identity_lock->lock();
		m_delete(pike_gateway_account_by_token,request_token);
		destruct(key);
		return;
	}
	decode_err = catch { payload = Standards.JSON.decode(
		(string)response["body"]); };
	if(decode_err || !mappingp(payload))
		return;
	token = lower_case(String.trim_all_whites(
		(string)(payload["token"] || request_token)));
	account_id = lower_case(String.trim_all_whites(
		(string)(payload["account_id"] || "")));
	pike_gateway_record_account_token(token,account_id);
}

private void pike_gateway_begin_request()
{
	object key = pike_gateway_state_lock->lock();
	int ready = pike_gateway_routing_ready;
	if(ready)
		pike_gateway_active_requests++;
	destruct(key);
	if(!ready)
		error("map worker recovery is in progress\n");
}

private void pike_gateway_ensure_routing_ready()
{
	object key = pike_gateway_state_lock->lock();
	int ready = pike_gateway_routing_ready;
	destruct(key);
	if(!ready)
		error("map worker recovery is in progress\n");
}

private void pike_gateway_end_request()
{
	object key = pike_gateway_state_lock->lock();
	pike_gateway_active_requests = max(0,pike_gateway_active_requests-1);
	destruct(key);
}

private void pike_gateway_pause_routing()
{
	int active = 1;
	object key = pike_gateway_state_lock->lock();
	pike_gateway_routing_ready = 0;
	destruct(key);
	while(active && !pike_gateway_stop){
		key = pike_gateway_state_lock->lock();
		active = pike_gateway_active_requests;
		destruct(key);
		if(active)
			sleep(0.01);
	}
}

private void pike_gateway_resume_routing()
{
	object key = pike_gateway_state_lock->lock();
	if(!sizeof(pike_gateway_uncertain_requests))
		pike_gateway_routing_ready = 1;
	destruct(key);
}

private void pike_gateway_mark_reconciliation_pending(string userid)
{
	object key;
	if(!pike_gateway_valid_userid(userid))
		return;
	key = pike_gateway_state_lock->lock();
	if(!pike_gateway_pending_reconcile_users[userid] &&
	   sizeof(pike_gateway_pending_reconcile_users)>=
	   PIKE_GATEWAY_MAX_RECONCILE_USERS)
		pike_gateway_routing_ready = 0;
	else
		pike_gateway_pending_reconcile_users[userid] = 1;
	destruct(key);
}

private int pike_gateway_reconciliation_pending(string userid)
{
	object key = pike_gateway_state_lock->lock();
	int result = pike_gateway_pending_reconcile_users[userid];
	destruct(key);
	return result;
}

private void pike_gateway_clear_reconciliation_pending(string userid)
{
	object key = pike_gateway_state_lock->lock();
	pike_gateway_pending_reconcile_users[userid] = 0;
	destruct(key);
}

private void pike_gateway_set_background_arrival(string userid,
	mapping pending)
{
	object key = pike_gateway_state_lock->lock();
	pike_gateway_background_arrivals[userid] = copy_value(pending);
	destruct(key);
}

private void pike_gateway_delete_background_arrival(string userid)
{
	object key = pike_gateway_state_lock->lock();
	m_delete(pike_gateway_background_arrivals,userid);
	destruct(key);
}

private mapping(string:mapping(string:mixed))
	pike_gateway_background_arrival_snapshot()
{
	object key = pike_gateway_state_lock->lock();
	mapping snapshot = copy_value(pike_gateway_background_arrivals);
	destruct(key);
	return snapshot;
}

private void pike_gateway_quarantine_uncertain(string worker_id,
	string request_id)
{
	string request_key = worker_id+"|"+request_id;
	object key = pike_gateway_state_lock->lock();
	if(!pike_gateway_uncertain_requests[request_key] &&
	   sizeof(pike_gateway_uncertain_requests)>=PIKE_GATEWAY_MAX_UNCERTAIN){
		pike_gateway_routing_ready = 0;
		pike_gateway_last_error = "uncertain request capacity exhausted";
	}
	else{
		pike_gateway_uncertain_requests[request_key] = 1;
		pike_gateway_routing_ready = 0;
	}
	destruct(key);
}

private void pike_gateway_register_all()
{
	foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
		mapping result = MAP_WORKERD->register_worker(worker_id,
			"http://127.0.0.1:"+(string)pike_gateway_worker_ports[worker_id],
			pike_gateway_worker_capacity,
			"pike-gateway-"+pike_gateway_controller_nonce+"-"+worker_id);
		if(!(int)result["ok"])
			error("cannot register worker "+worker_id+"\n");
		pike_gateway_generations[worker_id] = (int)result["generation"];
	}
}

private void pike_gateway_sync_catalog_unlocked()
{
	int force_rebalance = MAP_WORKERD->
		placement_topology_requires_rebalance();
	mapping catalog = MAP_WORKERD->assign_catalog(force_rebalance);
	mapping status;
	mapping(string:string) owners = ([]);
	int generation;
	if(!(int)catalog["ok"])
		error("cannot assign map catalog\n");
	if(force_rebalance)
		werror("[PIKE_GATEWAY] topology size changed; rebalanced catalog across %d workers\n",
			(int)catalog["placement_topology_worker_count"]);
	status = MAP_WORKERD->query_status();
	generation = (int)status["placement_generation"];
	if(arrayp(status["placements"]))
		foreach((array)status["placements"],mixed raw)
			if(mappingp(raw) && (string)raw["affinity"]!="" &&
			   pike_gateway_worker_ports[(string)raw["worker_id"]])
				owners[(string)raw["affinity"]] = (string)raw["worker_id"];
	if(generation<1 || !sizeof(owners))
		error("coordinator returned empty placement catalog\n");
	foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
		mapping installed = pike_gateway_worker_rpc(worker_id,
			"local_assignments",(["owners":owners,"generation":generation]));
		if(!(int)installed["ok"])
			error("cannot install placement catalog on "+worker_id+"\n");
	}
}

private void pike_gateway_sync_catalog()
{
	object assignment_key = pike_gateway_assignment_lock->lock();
	mixed sync_err = catch { pike_gateway_sync_catalog_unlocked(); };
	destruct(assignment_key);
	if(sync_err)
		error(describe_error(sync_err));
}

private void pike_gateway_sync_assignment(string affinity,mapping placement)
{
	string owner = (string)placement["worker_id"];
	int generation = (int)placement["placement_generation"];
	if(affinity=="" || !pike_gateway_worker_ports[owner] || generation<1)
		error("invalid affinity placement\n");
	foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
		mapping installed = pike_gateway_worker_rpc(worker_id,
			"local_assignment",(["affinity":affinity,
			"worker_id":owner,"generation":generation]));
		if(!(int)installed["ok"])
			error("cannot update affinity on "+worker_id+"\n");
	}
}

private mapping pike_gateway_assign_affinity(string affinity,int weight,
	int force)
{
	object assignment_key = pike_gateway_assignment_lock->lock();
	mapping placement;
	mixed assignment_err = catch {
		placement = MAP_WORKERD->assign_affinity(affinity,weight,force);
		if((int)placement["ok"])
			pike_gateway_sync_assignment(affinity,placement);
	};
	destruct(assignment_key);
	if(assignment_err)
		error(describe_error(assignment_err));
	return placement;
}

private mapping pike_gateway_prune_reconciled_tombstones(
	array(string) live_users)
{
	string reconciliation_id = pike_gateway_random_hex(32);
	mapping result = MAP_WORKERD->begin_lease_reconciliation(reconciliation_id);
	if(!(int)result["ok"])
		error("cannot begin lease reconciliation\n");
	for(int offset=0;offset<sizeof(live_users);offset+=500){
		int last = min(sizeof(live_users)-1,offset+499);
		result = MAP_WORKERD->add_lease_reconciliation_users(
			reconciliation_id,live_users[offset..last]);
		if(!(int)result["ok"])
			error("cannot upload lease reconciliation\n");
	}
	result = MAP_WORKERD->commit_lease_reconciliation(reconciliation_id);
	if(!(int)result["ok"])
		error("cannot commit lease reconciliation\n");
	return result;
}

private void pike_gateway_recover_local_players()
{
	mapping(string:array(mapping(string:mixed))) inventoried = ([]);
	mapping(string:mapping(string:mixed)) recovered = ([]);
	array(string) live_users;
	foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
		mapping inflight = pike_gateway_worker_rpc(worker_id,
			"local_inflight",([]));
		mapping inventory;
		if(!(int)inflight["ok"] || (int)inflight["count"])
			error("worker has unresolved requests: "+worker_id+"\n");
		inventory = pike_gateway_worker_rpc(worker_id,"local_inventory",([]));
		if(!(int)inventory["ok"] || !arrayp(inventory["players"]))
			error("cannot inventory worker: "+worker_id+"\n");
		foreach((array)inventory["players"],mixed raw){
			mapping item;
			string userid;
			string affinity;
			string account_id;
			if(!mappingp(raw))
				error("invalid worker inventory entry\n");
			item = (mapping)raw;
			userid = (string)item["userid"];
			affinity = (string)item["affinity"];
			account_id = (string)item["account_id"];
			if(!pike_gateway_valid_userid(userid) || affinity=="")
				error("invalid live player inventory\n");
			if(!arrayp(inventoried[userid]))
				inventoried[userid] = ({});
			inventoried[userid] += ({([
				"worker_id":worker_id,"affinity":affinity,
				"epoch":(int)item["lease_epoch"],
				"room_path":(string)item["room_path"],
			])});
			if(pike_gateway_valid_userid(account_id))
				pike_gateway_record_account(userid,account_id);
		}
	}
	foreach(sort(indices(inventoried)),string userid){
		array(mapping) copies = inventoried[userid];
		if(sizeof(copies)==1){
			recovered[userid] = copies[0];
			continue;
		}
		foreach(copies,mapping copy){
			mapping discarded = pike_gateway_worker_rpc(
				(string)copy["worker_id"],"local_discard",([
					"userid":userid,"epoch":(int)copy["epoch"],
				]));
			if(!(int)discarded["ok"])
				error("cannot discard duplicate player copy\n");
		}
		mapping route = MAP_WORKERD->query_player_route(userid);
		if((int)route["ok"] && (string)route["state"]=="frozen" &&
		   (string)route["handoff_request_id"]!=""){
			mapping aborted = MAP_WORKERD->abort_handoff(
				(string)route["handoff_request_id"],
				(string)route["worker_id"]);
			if(!(int)aborted["ok"])
				error("cannot thaw duplicate player lease\n");
		}
		werror("[PIKE_GATEWAY][STALE_DISCARD] userid=%s copies=%d\n",
			userid,sizeof(copies));
	}
	// Resolve committed arrivals only after every worker has proven its full
	// inventory. An exact target copy is acknowledged; otherwise the canonical
	// archive is authoritative and only the exact abandoned route is retired.
	multiset(string) arrival_candidates = (<>);
	object state_key = pike_gateway_state_lock->lock();
	foreach(indices(pike_gateway_pending_reconcile_users),string userid)
		arrival_candidates[userid] = 1;
	foreach(indices(pike_gateway_background_arrivals),string userid)
		arrival_candidates[userid] = 1;
	destruct(state_key);
	foreach(sort(indices(arrival_candidates)),string userid){
		mapping route = MAP_WORKERD->query_player_route(userid);
		string arrival_room = (string)(route["arrival_room_path"] || "");
		if(!(int)route["ok"] || (string)route["state"]!="active" ||
		   arrival_room=="")
			continue;
		array(mapping) copies = inventoried[userid] || ({});
		int exact_arrival;
		if(sizeof(copies)==1){
			mapping copy = copies[0];
			exact_arrival = (string)copy["worker_id"]==
				(string)route["worker_id"] &&
				(int)copy["epoch"]==(int)route["epoch"] &&
				(string)copy["affinity"]==(string)route["affinity"] &&
				(string)copy["room_path"]==arrival_room;
		}
		mapping resolved;
		if(exact_arrival)
			resolved = MAP_WORKERD->acknowledge_player_arrival(userid,
				(string)route["worker_id"],(int)route["epoch"],
				(string)route["affinity"]);
		else
			resolved = MAP_WORKERD->retire_abandoned_player_arrival(userid,
				(string)route["worker_id"],(int)route["epoch"],arrival_room);
		if(!(int)resolved["ok"])
			error("cannot resolve abandoned player arrival\n");
	}
	foreach(sort(indices(recovered)),string userid){
		mapping copy = recovered[userid];
		string worker_id = (string)copy["worker_id"];
		string affinity = (string)copy["affinity"];
		int local_epoch = (int)copy["epoch"];
		mapping route = MAP_WORKERD->query_player_route(userid);
		mapping result;
		if((int)route["ok"] && (string)route["state"]=="frozen" &&
		   (string)route["worker_id"]==worker_id &&
		   (string)route["handoff_request_id"]!=""){
			mapping aborted = MAP_WORKERD->abort_handoff(
				(string)route["handoff_request_id"],worker_id);
			if(!(int)aborted["ok"])
				error("cannot roll back frozen lease\n");
			route = MAP_WORKERD->query_player_route(userid);
		}
		if((int)route["ok"] && (string)route["state"]=="active" &&
		   (string)route["worker_id"]==worker_id &&
		   (!local_epoch || local_epoch==(int)route["epoch"])){
			if((string)route["affinity"]==affinity){
				mapping renewed = MAP_WORKERD->renew_player_lease(userid,
					worker_id,(int)route["epoch"]);
				if((int)renewed["ok"])
					result = route;
			}
			else{
				mapping placement = pike_gateway_assign_affinity(affinity,1,0);
				if(!(int)placement["ok"])
					error("cannot restore player affinity\n");
				if((string)placement["worker_id"]!=worker_id)
					error("live player is on wrong affinity owner\n");
				result = MAP_WORKERD->rebind_player_lease(userid,worker_id,
					(int)route["epoch"],affinity);
			}
		}
		else
			result = MAP_WORKERD->recover_player_lease(userid,worker_id,affinity);
		if(!mappingp(result) || !(int)result["ok"])
			error("cannot recover player lease\n");
		mapping installed = pike_gateway_worker_rpc(worker_id,"local_epoch",([
			"userid":userid,"epoch":(int)result["epoch"],
		]));
		if(!(int)installed["ok"])
			error("cannot install recovered player epoch\n");
	}
	live_users = sort(indices(recovered));
	mapping prune = pike_gateway_prune_reconciled_tombstones(live_users);
	if((int)prune["pruned_assignments"])
		pike_gateway_sync_catalog();
	foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
		mapping resumed = pike_gateway_worker_rpc(worker_id,
			"local_control_resume",([]));
		if(!(int)resumed["ok"])
			error("cannot resume worker control: "+worker_id+"\n");
		pike_gateway_set_worker_reachable(worker_id,1);
	}
	state_key = pike_gateway_state_lock->lock();
	pike_gateway_pending_reconcile_users = (<>);
	pike_gateway_background_arrivals = ([]);
	destruct(state_key);
}

private void pike_gateway_reconcile_recovered_worker(string worker_id)
{
	mapping inflight = pike_gateway_worker_rpc(worker_id,"local_inflight",([]));
	mapping inventory;
	if(!(int)inflight["ok"] || (int)inflight["count"])
		error("recovered worker has unresolved requests\n");
	inventory = pike_gateway_worker_rpc(worker_id,"local_inventory",([]));
	if(!(int)inventory["ok"] || !arrayp(inventory["players"]))
		error("cannot inventory recovered worker\n");
	foreach((array)inventory["players"],mixed raw){
		mapping item;
		string userid;
		string affinity;
		int local_epoch;
		mapping route;
		int coordinator_epoch;
		int exact_owner;
		if(!mappingp(raw))
			error("invalid recovered inventory entry\n");
		item = (mapping)raw;
		userid = (string)item["userid"];
		affinity = (string)item["affinity"];
		local_epoch = (int)item["lease_epoch"];
		if(!pike_gateway_valid_userid(userid) || affinity=="")
			error("invalid player on recovered worker\n");
		route = MAP_WORKERD->query_player_route(userid);
		if((int)route["ok"] && (string)route["state"]=="frozen" &&
		   (string)route["worker_id"]==worker_id &&
		   (string)route["handoff_request_id"]!=""){
			mapping aborted = MAP_WORKERD->abort_handoff(
				(string)route["handoff_request_id"],worker_id);
			if((int)aborted["ok"])
				route = MAP_WORKERD->query_player_route(userid);
		}
		coordinator_epoch = (int)route["epoch"];
		exact_owner = (int)route["ok"] &&
			(string)route["state"]=="active" &&
			(string)route["worker_id"]==worker_id &&
			(string)route["affinity"]==affinity &&
			(!local_epoch || local_epoch==coordinator_epoch);
		if(exact_owner){
			mapping renewed = MAP_WORKERD->renew_player_lease(userid,
				worker_id,coordinator_epoch);
			mapping installed = pike_gateway_worker_rpc(worker_id,
				"local_epoch",(["userid":userid,"epoch":coordinator_epoch]));
			if((int)renewed["ok"] && (int)installed["ok"])
				continue;
		}
		mapping discarded = pike_gateway_worker_rpc(worker_id,
			"local_discard",(["userid":userid,"epoch":local_epoch]));
		if(!(int)discarded["ok"])
			error("cannot discard stale recovered player\n");
	}
	mapping resumed = pike_gateway_worker_rpc(worker_id,
		"local_control_resume",([]));
	if(!(int)resumed["ok"])
		error("cannot resume recovered worker\n");
}

private mapping pike_gateway_lease_for_new_user(string userid)
{
	string affinity = "session:"+pike_gateway_digest(userid)[0..23];
	mapping placement = pike_gateway_assign_affinity(affinity,1,0);
	mapping lease;
	if(!(int)placement["ok"])
		error("no worker placement for new user\n");
	lease = MAP_WORKERD->acquire_player_lease(userid,
		(string)placement["worker_id"],affinity,0);
	if(!(int)lease["ok"])
		error("cannot acquire new player lease\n");
	return ([
		"worker_id":(string)lease["worker_id"],
		"epoch":(int)lease["epoch"],"affinity":affinity,
		"arrival_room":"",
	]);
}

private mapping pike_gateway_route_user(string userid)
{
	mapping route = MAP_WORKERD->query_player_route(userid);
	if((int)route["ok"] &&
	   pike_gateway_worker_ports[(string)route["worker_id"]]){
		if((string)route["state"]=="frozen")
			error("player handoff is in progress\n");
		mapping renewed = MAP_WORKERD->renew_player_lease(userid,
			(string)route["worker_id"],(int)route["epoch"]);
		if((int)renewed["ok"])
			return ([
				"worker_id":(string)route["worker_id"],
				"epoch":(int)route["epoch"],
				"affinity":(string)route["affinity"],
				"arrival_room":(string)(route["arrival_room_path"] || ""),
			]);
	}
	if((string)route["code"]=="lease_missing")
		return pike_gateway_lease_for_new_user(userid);
	if((string)route["code"]=="lease_expired"){
		string old_worker;
		string old_affinity;
		int old_epoch;
		mapping reopened;
		if((string)route["state"]=="frozen")
			error("expired frozen handoff cannot reopen\n");
		old_worker = (string)route["worker_id"];
		old_affinity = (string)route["affinity"];
		old_epoch = (int)route["epoch"];
		if(!pike_gateway_worker_ports[old_worker] || old_affinity=="" ||
		   old_epoch<1)
			error("expired lease requires inventory recovery\n");
		reopened = MAP_WORKERD->acquire_player_lease(userid,old_worker,
			old_affinity,old_epoch);
		if(!(int)reopened["ok"])
			error("expired lease cannot safely reopen\n");
		return ([
			"worker_id":old_worker,"epoch":(int)reopened["epoch"],
			"affinity":old_affinity,
			"arrival_room":(string)(reopened["arrival_room_path"] || ""),
		]);
	}
	return pike_gateway_lease_for_new_user(userid);
}

private void pike_gateway_wait_for_request_done(string worker_id,
	string request_id)
{
	int deadline = time()+pike_gateway_timeout;
	while(1){
		mapping status = pike_gateway_worker_rpc(worker_id,
			"local_request_status",(["request_id":request_id]));
		if((int)status["ok"] && (string)status["state"]=="done")
			return;
		if(!(int)status["ok"] || (string)status["state"]!="running")
			error("worker cannot prove request completion\n");
		if(time()>=deadline)
			error("worker request finalization timed out\n");
		sleep(0.005);
	}
}

private mapping pike_gateway_proxy(string worker_id,string method,string path,
	mapping request_headers,string body,string userid,int epoch,
	string arrival_room,string account_id,string command_kind,
	void|mapping admin_target)
{
	mapping headers = ([]);
	mapping response;
	string request_id = pike_gateway_random_hex(32);
	string accepted = "";
	int request_may_be_running;
	mixed proxy_err;
	foreach(indices(request_headers),mixed raw_name){
		string name;
		string lowered;
		mixed value;
		if(!stringp(raw_name))
			continue;
		name = (string)raw_name;
		lowered = lower_case(name);
		value = request_headers[raw_name];
		if(!pike_gateway_hop_headers[lowered] && lowered!="host" &&
		   lowered!="content-length" && !has_prefix(lowered,"x-xiand-") &&
		   (stringp(value) || intp(value)))
			headers[name] = (string)value;
	}
	headers["Host"] = "127.0.0.1:"+
		(string)pike_gateway_worker_ports[worker_id];
	headers["Content-Length"] = (string)sizeof(body || "");
	headers["X-Xiand-Worker-Token"] = pike_gateway_token;
	headers["X-Xiand-Lease-Worker"] = worker_id;
	headers["X-Xiand-Lease-Userid"] = userid;
	headers["X-Xiand-Lease-Epoch"] = (string)epoch;
	headers["X-Xiand-Request-Id"] = request_id;
	headers["X-Xiand-Command-Kind"] = command_kind;
	if(mappingp(admin_target) && sizeof(admin_target)){
		string target_userid = (string)admin_target["userid"];
		string target_account = (string)admin_target["account_id"];
		string target_worker = (string)admin_target["worker_id"];
		int target_epoch = (int)admin_target["epoch"];
		int admin_fee = (int)admin_target["fee"];
		string recharge_request_id =
			(string)admin_target["recharge_request_id"];
		string capability = pike_gateway_digest(pike_gateway_token+"|"+
			"admin_recharge|"+userid+"|"+target_userid+"|"+
			target_account+"|"+target_worker+"|"+(string)target_epoch+"|"+
			(string)admin_fee+"|"+recharge_request_id+"|"+request_id);
		headers["X-Xiand-Admin-Target-Userid"] = target_userid;
		headers["X-Xiand-Admin-Target-Account"] = target_account;
		headers["X-Xiand-Admin-Target-Worker"] = target_worker;
		headers["X-Xiand-Admin-Target-Epoch"] = (string)target_epoch;
		headers["X-Xiand-Admin-Fee"] = (string)admin_fee;
		headers["X-Xiand-Admin-Recharge-Request"] = recharge_request_id;
		headers["X-Xiand-Admin-Capability"] = capability;
	}
	if(arrival_room!="")
		headers["X-Xiand-Arrival-Room"] = arrival_room;
	if(pike_gateway_valid_userid(account_id)){
		headers["X-Xiand-Account-Owner"] = account_id;
		headers["X-Xiand-Account-Cache-Token"] =
			pike_gateway_account_cache_token(account_id,worker_id);
	}
	proxy_err = catch {
		request_may_be_running = 1;
		response = pike_gateway_http_request(worker_id,method,path,headers,body,
			pike_gateway_timeout);
		mapping response_headers = (mapping)response["headers"];
		mixed raw_accepted = response_headers["x-xiand-request-accepted"];
		if(stringp(raw_accepted))
			accepted = lower_case(String.trim_all_whites((string)raw_accepted));
		if(accepted==request_id)
			pike_gateway_wait_for_request_done(worker_id,request_id);
		else if(!has_value(({403,409,413}),(int)response["status"]))
			error("worker response lacks request fence proof\n");
	};
	if(proxy_err){
		if(request_may_be_running)
			pike_gateway_quarantine_uncertain(worker_id,request_id);
		error("uncertain worker request on "+worker_id+": "+
			describe_error(proxy_err)+"\n");
	}
	return response;
}

private mapping pike_gateway_confirmed_route(string userid,string worker_id,
	int epoch)
{
	mapping route = MAP_WORKERD->query_player_route(userid);
	if(!(int)route["ok"] || (string)route["state"]!="active" ||
	   (string)route["worker_id"]!=worker_id || (int)route["epoch"]!=epoch ||
	   (string)route["affinity"]=="")
		error("coordinator route confirmation failed\n");
	return ([
		"affinity":(string)route["affinity"],
		"arrival_room":(string)(route["arrival_room_path"] || ""),
	]);
}

private void pike_gateway_acknowledge_arrival(string userid,string worker_id,
	int epoch,string affinity,string arrival_room)
{
	if(arrival_room=="")
		return;
	mapping local_route = pike_gateway_worker_rpc(worker_id,"local_route",([
		"userid":userid,
	]));
	if(!(int)local_route["ok"] ||
	   (int)local_route["lease_epoch"]!=epoch ||
	   (string)local_route["affinity"]!=affinity ||
	   (string)local_route["room_path"]!=arrival_room)
		error("worker arrival confirmation failed\n");
	mapping acknowledged = MAP_WORKERD->acknowledge_player_arrival(userid,
		worker_id,epoch,affinity);
	if(!(int)acknowledged["ok"])
		error("coordinator arrival acknowledgement failed\n");
}

private mixed pike_gateway_reconcile(string userid,string source_worker,
	int source_epoch,string leased_affinity,int require_settled)
{
	mapping local_route = pike_gateway_worker_rpc(source_worker,"local_route",([
		"userid":userid,
	]));
	mapping redirect;
	int replay_request;
	string affinity;
	string target_room_path;
	string local_room_path;
	string source_affinity;
	mapping placement;
	string target_worker;
	if(!(int)local_route["ok"]){
		if((string)local_route["code"]=="player_not_local")
			return 0;
		if(require_settled)
			error("cannot inspect pending player route\n");
		return 0;
	}
	if(!(int)local_route["handoff_safe"]){
		if(require_settled)
			error("pending player route is not handoff safe\n");
		return 0;
	}
	if(pike_gateway_valid_userid((string)local_route["account_id"]))
		pike_gateway_record_account(userid,
			(string)local_route["account_id"]);
	redirect = mappingp(local_route["move_redirect"]) ?
		(mapping)local_route["move_redirect"] : ([]);
	replay_request = (int)redirect["ok"];
	affinity = replay_request ? (string)redirect["target_affinity"] :
		(string)local_route["affinity"];
	target_room_path = replay_request ?
		(string)redirect["target_room_path"] : "";
	local_room_path = (string)local_route["room_path"];
	source_affinity = (string)local_route["affinity"];
	if(affinity=="" || source_affinity=="")
		return 0;
	if(replay_request && target_room_path=="")
		return 0;
	if(!replay_request && source_affinity==leased_affinity)
		return 0;
	placement = pike_gateway_assign_affinity(affinity,1,0);
	if(!(int)placement["ok"])
		error("cannot place reconciled affinity\n");
	target_worker = (string)placement["worker_id"];
	if(target_worker==source_worker){
		if(replay_request){
			mapping completed = pike_gateway_worker_rpc(source_worker,
				"local_redirect_complete",(["userid":userid,
				"epoch":source_epoch,"room_path":target_room_path]));
			if(!(int)completed["ok"])
				error("same-worker redirect failed\n");
		}
		mapping rebound = MAP_WORKERD->rebind_player_lease(userid,
			source_worker,source_epoch,affinity);
		if(!(int)rebound["ok"])
			error("same-worker lease rebind failed\n");
		return ([
			"worker_id":source_worker,"epoch":source_epoch,
			"redirect":replay_request,
			"arrival_room":replay_request ? target_room_path : "",
		]);
	}
	if(!replay_request){
		if(!has_prefix(local_room_path,"/gamelib/d/") ||
		   search(local_room_path,"#")!=-1)
			error("dynamic instance cannot cross workers\n");
		target_room_path = local_room_path;
	}
	string request_id = pike_gateway_digest(userid+"|"+source_worker+"|"+
		(string)source_epoch+"|"+affinity+"|"+target_room_path)[0..47];
	mapping prepared = MAP_WORKERD->begin_handoff(userid,source_worker,
		source_epoch,affinity,target_room_path,request_id);
	string prepared_target = (string)prepared["target_worker"];
	if(!(int)prepared["ok"] || (int)prepared["local"] ||
	   (string)prepared["state"]!="prepared" ||
	   prepared_target!=target_worker ||
	   !pike_gateway_worker_ports[prepared_target])
		error("cannot prepare cross-worker handoff\n");
	if(target_worker==source_worker){
		MAP_WORKERD->abort_handoff(request_id,source_worker);
		error("handoff unexpectedly resolved to source worker\n");
	}
	mapping released = pike_gateway_worker_rpc(source_worker,"local_release",([
		"userid":userid,"affinity":source_affinity,"epoch":source_epoch,
	]));
	if(!(int)released["ok"]){
		string release_code = stringp(released["code"]) ?
			(string)released["code"] : "unknown";
		MAP_WORKERD->abort_handoff(request_id,source_worker);
		error("cannot release handoff source: "+release_code+"\n");
	}
	mapping committed = MAP_WORKERD->commit_handoff(request_id,target_worker);
	if(!(int)committed["ok"]){
		MAP_WORKERD->abort_handoff(request_id,source_worker);
		error("cannot commit cross-worker handoff\n");
	}
	return ([
		"worker_id":target_worker,"epoch":(int)committed["target_epoch"],
		"redirect":replay_request,
		"arrival_room":(string)(committed["target_room_path"] ||
			target_room_path),
	]);
}

private mapping pike_gateway_migration_plan(string source_worker,
	mapping migration,int before_command)
{
	if(!mappingp(migration))
		return (["deliver":0,"replace":0]);
	int cross_worker = (string)migration["worker_id"]!=source_worker;
	int redirect_response = (int)migration["redirect"];
	if(before_command)
		return (["deliver":cross_worker,"replace":0]);
	return (["deliver":cross_worker || redirect_response,
		"replace":redirect_response]);
}

private string pike_gateway_resolve_routed_command(string worker_id,
	string userid,int epoch,string command)
{
	if(!has_prefix(command,"c_"))
		return command;
	mapping result = pike_gateway_worker_rpc(worker_id,
		"local_resolve_command",(["userid":userid,"epoch":epoch,
			"command":command]));
	if(!(int)result["ok"] || (string)result["command"]=="")
		error("cannot resolve routed command token\n");
	return (string)result["command"];
}

private mapping pike_gateway_materialize_route_arrival(string userid,
	string account_id,mapping route)
{
	// A committed arrival is independent of the current browser endpoint.
	// Read-only polling endpoints cannot materialize a player themselves.
	string worker_id = (string)route["worker_id"];
	int epoch = (int)route["epoch"];
	string affinity = (string)route["affinity"];
	string arrival_room = (string)route["arrival_room"];
	if(arrival_room!=""){
		pike_gateway_deliver_background_arrival(userid,worker_id,epoch,
			arrival_room,account_id);
		pike_gateway_delete_background_arrival(userid);
		mapping arrived = pike_gateway_confirmed_route(userid,worker_id,epoch);
		affinity = (string)arrived["affinity"];
	}
	return (["worker_id":worker_id,"epoch":epoch,"affinity":affinity,
		"arrival_room":""]);
}

/** Acquire two account-sharded locks in stable shard order. */
private array(object) pike_gateway_lock_user_pair(string first_user,
	string first_account,string second_user,string second_account)
{
	object first_mutex = pike_gateway_user_mutex(first_user,first_account);
	object second_mutex = pike_gateway_user_mutex(second_user,second_account);
	array(object) locks = ({});
	if(first_mutex==second_mutex)
		return ({first_mutex->lock()});
	int first_index = search(pike_gateway_user_locks,first_mutex);
	int second_index = search(pike_gateway_user_locks,second_mutex);
	if(first_index<0 || second_index<0)
		error("account lock shard missing\n");
	if(first_index<second_index){
		locks += ({first_mutex->lock()});
		locks += ({second_mutex->lock()});
	}
	else{
		locks += ({second_mutex->lock()});
		locks += ({first_mutex->lock()});
	}
	return locks;
}

private mapping pike_gateway_busy_response(string message,void|int status)
{
	return ([
		"status":status || 503,
		"reason":"Service Unavailable",
		"headers":(["content-type":"application/json; charset=utf-8",
			"retry-after":"1","cache-control":"no-store"]),
		"body":Standards.JSON.encode((["error":message])),
	]);
}

private mapping pike_gateway_process_public_snapshot(mapping snapshot)
{
	string path = (string)snapshot["path"];
	string method = (string)snapshot["method"];
	mapping headers = (mapping)snapshot["headers"];
	string body = (string)snapshot["body"];
	mapping params;
	string userid = "";
	string account_id = "";
	string account_token = "";
	string token_account = "";
	string game_command = "";
	string registration_user = "";
	string command_kind = "general";
	mapping admin_target = ([]);
	mapping proxied;
	object user_key;
	object auction_key;
	object account_management_key;
	array(object) all_account_keys = ({});
	int request_entered;
	int command_may_have_run;
	mixed request_err;

	request_err = catch {
		params = pike_gateway_extract_params(snapshot);
		userid = pike_gateway_extract_userid(params);
		account_token = pike_gateway_extract_account_token(params);
		game_command = pike_gateway_extract_command(params);
		registration_user = pike_gateway_registration_target(game_command);
		if(pike_gateway_command_verb(game_command)=="login_regnew" &&
		   registration_user=="")
			error("invalid registration target\n");
		if(registration_user!="" && userid!="" && userid!=registration_user)
			error("conflicting registration identity\n");
		pike_gateway_begin_request();
		request_entered = 1;
		if(pike_gateway_account_path((string)snapshot["path_only"])){
			token_account = pike_gateway_account_for_token(account_token);
			if(userid!=""){
				account_id = pike_gateway_resolve_account(userid);
				if(token_account!="" && token_account!=account_id)
					error("account token owner mismatch\n");
				user_key = pike_gateway_user_mutex(userid,account_id)->lock();
			}
			else if(token_account!=""){
				account_id = token_account;
				user_key = pike_gateway_user_mutex(account_id,account_id)->lock();
			}
			else{
				account_management_key =
					pike_gateway_account_management_lock->lock();
				foreach(pike_gateway_user_locks,object mutex)
					all_account_keys += ({mutex->lock()});
			}
			pike_gateway_ensure_routing_ready();
			proxied = pike_gateway_proxy(pike_gateway_primary,method,path,
				headers,body,"",0,"",account_id,"account");
			pike_gateway_observe_account_response(
				(string)snapshot["path_only"],account_token,proxied);
		}
		else if(registration_user!=""){
			// There is no character lease before the first archive exists. The
			// gateway user/account mutex is the exclusive creation fence and the
			// primary worker performs the atomic save.
			user_key = pike_gateway_user_mutex(registration_user,
				registration_user)->lock();
			pike_gateway_ensure_routing_ready();
			proxied = pike_gateway_proxy(pike_gateway_primary,method,path,
				headers,body,"",0,"","","registration");
		}
		else if(userid!=""){
			account_id = pike_gateway_resolve_account(userid);
			token_account = pike_gateway_account_for_token(account_token);
			if(token_account!="" && token_account!=account_id)
				error("gameplay token owner mismatch\n");
			user_key = pike_gateway_user_mutex(userid,account_id)->lock();
			pike_gateway_ensure_routing_ready();
			mapping route = pike_gateway_materialize_route_arrival(userid,
				account_id,pike_gateway_route_user(userid));
			game_command = pike_gateway_resolve_routed_command(
				(string)route["worker_id"],userid,(int)route["epoch"],
				game_command);
			admin_target = pike_gateway_admin_recharge_target(game_command);
			if(sizeof(admin_target)){
				// Upgrade from the manager-only lock to a stable two-account lock,
				// then re-resolve the immutable token after the unlocked window.
				destruct(user_key);
				user_key = 0;
				all_account_keys = pike_gateway_lock_user_pair(userid,account_id,
					(string)admin_target["userid"],
					(string)admin_target["account_id"]);
				pike_gateway_ensure_routing_ready();
				route = pike_gateway_materialize_route_arrival(userid,
					account_id,pike_gateway_route_user(userid));
				string confirmed_command = pike_gateway_resolve_routed_command(
					(string)route["worker_id"],userid,(int)route["epoch"],
					pike_gateway_extract_command(params));
				mapping confirmed_target =
					pike_gateway_admin_recharge_target(confirmed_command);
				if(!sizeof(confirmed_target) ||
				   (string)confirmed_target["userid"]!=
					(string)admin_target["userid"] ||
				   (string)confirmed_target["account_id"]!=
					(string)admin_target["account_id"] ||
				   (int)confirmed_target["fee"]!=(int)admin_target["fee"] ||
				   (string)confirmed_target["recharge_request_id"]!=
					(string)admin_target["recharge_request_id"])
					error("admin command changed during lock upgrade\n");
				game_command = confirmed_command;
				admin_target = confirmed_target;
			}
			if(pike_gateway_auction_command(game_command))
				auction_key = pike_gateway_auction_lock->lock();
			command_kind = sizeof(admin_target) ? "admin_recharge" :
				(pike_gateway_auction_command(game_command) ?
				"auction" : "gameplay");
			string worker_id = (string)route["worker_id"];
			int epoch = (int)route["epoch"];
			string leased_affinity = (string)route["affinity"];
			string arrival_room = (string)route["arrival_room"];
			if(arrival_room=="" &&
			   pike_gateway_reconciliation_pending(userid)){
				string source_worker = worker_id;
				mapping migration = pike_gateway_reconcile(userid,worker_id,
					epoch,leased_affinity,1);
				mapping plan = pike_gateway_migration_plan(source_worker,
					migration,1);
				if(mappingp(migration)){
					worker_id = (string)migration["worker_id"];
					epoch = (int)migration["epoch"];
					arrival_room = (string)migration["arrival_room"];
					mapping confirmed = pike_gateway_confirmed_route(
						userid,worker_id,epoch);
					leased_affinity = (string)confirmed["affinity"];
					if((int)plan["deliver"]){
						if(arrival_room=="" ||
						   (string)confirmed["arrival_room"]!=arrival_room)
							error("pre-command arrival capability mismatch\n");
						pike_gateway_set_background_arrival(userid,([
							"worker_id":worker_id,"epoch":epoch,
							"room_path":arrival_room,"account_id":account_id,
						]));
						mapping arrival_response = pike_gateway_proxy(
							worker_id,method,path,headers,body,userid,epoch,
							arrival_room,account_id,command_kind,admin_target);
						if((int)arrival_response["status"]>=500)
							error("pre-command arrival delivery failed\n");
						pike_gateway_acknowledge_arrival(userid,worker_id,
							epoch,leased_affinity,arrival_room);
						pike_gateway_delete_background_arrival(userid);
						confirmed = pike_gateway_confirmed_route(userid,
							worker_id,epoch);
						if((string)confirmed["arrival_room"]!="")
							error("pre-command arrival remains pending\n");
					}
					arrival_room = "";
				}
			}
			command_may_have_run = 1;
			proxied = pike_gateway_proxy(worker_id,method,path,headers,body,
				userid,epoch,arrival_room,account_id,command_kind,admin_target);
			if((int)proxied["status"]<500){
				pike_gateway_acknowledge_arrival(userid,worker_id,epoch,
					leased_affinity,arrival_room);
				mapping migration = pike_gateway_reconcile(userid,worker_id,
					epoch,leased_affinity,0);
				mapping plan = pike_gateway_migration_plan(worker_id,migration,0);
				if(mappingp(migration)){
					string source_worker = worker_id;
					worker_id = (string)migration["worker_id"];
					epoch = (int)migration["epoch"];
					arrival_room = (string)migration["arrival_room"];
					mapping confirmed = pike_gateway_confirmed_route(
						userid,worker_id,epoch);
					leased_affinity = (string)confirmed["affinity"];
					if((int)plan["deliver"]){
						if(worker_id!=source_worker &&
						   (arrival_room=="" ||
						   (string)confirmed["arrival_room"]!=arrival_room))
							error("post-command arrival capability mismatch\n");
						if(worker_id!=source_worker)
							pike_gateway_set_background_arrival(userid,([
								"worker_id":worker_id,"epoch":epoch,
								"room_path":arrival_room,
								"account_id":account_id,
							]));
						mapping arrival_response = pike_gateway_proxy(
							worker_id,method,path,headers,body,userid,epoch,
							arrival_room,account_id,command_kind,admin_target);
						if((int)arrival_response["status"]>=500)
							error("post-command arrival delivery failed\n");
						if(worker_id!=source_worker){
							pike_gateway_acknowledge_arrival(userid,
								worker_id,epoch,leased_affinity,arrival_room);
							pike_gateway_delete_background_arrival(userid);
							confirmed = pike_gateway_confirmed_route(userid,
								worker_id,epoch);
							if((string)confirmed["arrival_room"]!="")
								error("post-command arrival remains pending\n");
						}
						if((int)plan["replace"])
							proxied = arrival_response;
					}
				}
				pike_gateway_clear_reconciliation_pending(userid);
			}
			else
				pike_gateway_mark_reconciliation_pending(userid);
		}
		else
			proxied = pike_gateway_proxy(pike_gateway_primary,method,path,
				headers,body,"",0,"","","general");
	};

	if(auction_key)
		destruct(auction_key);
	if(user_key)
		destruct(user_key);
	for(int index=sizeof(all_account_keys)-1;index>=0;index--)
		destruct(all_account_keys[index]);
	if(account_management_key)
		destruct(account_management_key);
	if(request_entered)
		pike_gateway_end_request();
	if(request_err){
		if(userid!="" && command_may_have_run)
			pike_gateway_mark_reconciliation_pending(userid);
		object key = pike_gateway_state_lock->lock();
		pike_gateway_failed_requests++;
		pike_gateway_last_error = describe_error(request_err);
		destruct(key);
		werror("[PIKE_GATEWAY][REQUEST_FAILED] path=%s userid=%s error=%s\n",
			(string)snapshot["path_only"],userid,describe_error(request_err));
		return pike_gateway_busy_response("地图服务暂时繁忙，请稍后重试");
	}
	object key = pike_gateway_state_lock->lock();
	pike_gateway_completed_requests++;
	destruct(key);
	return proxied;
}

private void pike_gateway_release_request_slot()
{
	object key = pike_gateway_state_lock->lock();
	pike_gateway_pending_requests = max(0,pike_gateway_pending_requests-1);
	destruct(key);
}

private void pike_gateway_deliver_response(mapping proxied,
	Protocols.HTTP.Server.Request req,string method)
{
	mapping response = ([]);
	mapping extra_heads = ([]);
	mapping headers = mappingp(proxied["headers"]) ?
		(mapping)proxied["headers"] : ([]);
	string content_type = "application/octet-stream";
	foreach(indices(headers),mixed raw_name){
		string name;
		mixed value;
		if(!stringp(raw_name))
			continue;
		name = lower_case((string)raw_name);
		value = headers[raw_name];
		if(name=="content-type" && stringp(value))
			content_type = (string)value;
		else if(pike_gateway_response_header_allowed(name) &&
			(stringp(value) || arrayp(value)))
			extra_heads[name] = value;
	}
	response["error"] = (int)(proxied["status"] || 502);
	response["type"] = content_type;
	response["data"] = method=="HEAD" ? "" : (string)(proxied["body"] || "");
	response["extra_heads"] = extra_heads;
	pike_gateway_release_request_slot();
	finish_http_response(req,response);
}

private void pike_gateway_deliver_failure(mixed err,
	Protocols.HTTP.Server.Request req,string method)
{
	werror("[PIKE_GATEWAY][FUTURE_FAILED] %s\n",describe_error(err));
	mapping proxied = pike_gateway_busy_response(
		"地图服务暂时繁忙，请稍后重试");
	pike_gateway_deliver_response(proxied,req,method);
}

void handle_pike_gateway_request(Protocols.HTTP.Server.Request req)
{
	string path_only = req->not_query || "/";
	string query = req->query || "";
	string method = upper_case(req->request_type || "GET");
	string body = req->body_raw || "";
	mapping headers = copy_value(req->request_headers || ([]));
	mapping snapshot;
	object future;
	int reserved;
	mixed schedule_err;
	if(has_prefix(path_only,"/internal/")){
		send_json(req,(["error":"not found"]),404);
		return;
	}
	if(!has_value(({"GET","HEAD","POST","OPTIONS"}),method)){
		send_json(req,(["error":"method not allowed"]),405);
		return;
	}
	if(sizeof(path_only)>MAX_HTTP_QUERY_SIZE ||
	   sizeof(query)>MAX_HTTP_QUERY_SIZE ||
	   sizeof(body)>PIKE_GATEWAY_MAX_BODY_BYTES ||
	   pike_gateway_has_transfer_encoding(headers)){
		send_json(req,(["error":"invalid request framing"]),413);
		return;
	}
	if(headers["content-length"] &&
	   (int)headers["content-length"]!=sizeof(body)){
		send_json(req,(["error":"invalid request framing"]),400);
		return;
	}
	object key = pike_gateway_state_lock->lock();
	if(pike_gateway_routing_ready &&
	   pike_gateway_pending_requests<pike_gateway_max_requests){
		pike_gateway_pending_requests++;
		reserved = 1;
	}
	else
		pike_gateway_rejected_requests++;
	destruct(key);
	if(!reserved){
		mapping response = ([
			"error":503,"type":"application/json; charset=utf-8",
			"data":method=="HEAD" ? "" :
				Standards.JSON.encode((["error":"gateway busy"])),
			"extra_heads":(["Retry-After":"1","Cache-Control":"no-store"]),
		]);
		finish_http_response(req,response);
		return;
	}
	snapshot = ([
		"path_only":path_only,"query":query,
		"path":path_only+(query!="" ? "?"+query : ""),
		"method":method,"headers":headers,"body":body,
	]);
	schedule_err = catch {
		future = pike_gateway_request_farm->run(
			pike_gateway_process_public_snapshot,copy_value(snapshot));
		future->on_success(pike_gateway_deliver_response,req,method);
		future->on_failure(pike_gateway_deliver_failure,req,method);
	};
	if(schedule_err){
		pike_gateway_release_request_slot();
		send_json(req,(["error":"gateway busy"]),503);
	}
}

private mapping pike_gateway_collect_worker_metrics(string worker_id)
{
	mapping local_status = pike_gateway_worker_rpc(worker_id,
		"local_status",([]));
	if(!(int)local_status["ok"] || !arrayp(local_status["online_users"]))
		error("worker status rejected\n");
	object key = pike_gateway_state_lock->lock();
	pike_gateway_online_rows_by_worker[worker_id] =
		copy_value((array)local_status["online_users"]);
	pike_gateway_online_rows_at[worker_id] = time();
	destruct(key);
	return ([
		"active_players":(int)local_status["active_players"],
		"active_rooms":(int)local_status["active_rooms"],
		"pending_commands":(int)local_status["pending_commands"],
		"heartbeat_ms":(int)local_status["heartbeat_ms"],
	]);
}

/** Publish only after a complete monitor pass produced one coherent view. */
private void pike_gateway_publish_online_snapshot()
{
	mapping snapshot = query_pike_gateway_online_users();
	if(!(int)snapshot["ok"])
		return;
	foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
		if(!pike_gateway_worker_is_reachable(worker_id))
			continue;
		mixed publish_err = catch {
			mapping published = pike_gateway_worker_rpc(worker_id,
				"local_online_snapshot_update",(["snapshot":snapshot]));
			if(!(int)published["ok"])
				error("worker rejected online snapshot\n");
		};
		if(publish_err)
			werror("[PIKE_GATEWAY][ONLINE_SNAPSHOT] worker=%s error=%s\n",
				worker_id,describe_error(publish_err));
	}
}

private void pike_gateway_renew_live_player_leases(string worker_id,
	int generation)
{
	int offset;
	for(int page=0;page<158;page++){
		mapping live_page = pike_gateway_worker_rpc(worker_id,
			"local_live_leases",(["offset":offset,"limit":128]));
		array leases = arrayp(live_page["leases"]) ?
			(array)live_page["leases"] : 0;
		mapping(object:array(mapping)) lock_groups = ([]);
		array(object) acquired = ({});
		array(mapping) candidates = ({});
		if(!(int)live_page["ok"] || !arrayp(leases) || sizeof(leases)>128)
			error("invalid worker live-lease page\n");
		foreach(leases,mixed raw){
			mapping entry;
			string userid;
			string account_id;
			object mutex;
			if(!mappingp(raw))
				error("invalid worker live lease\n");
			entry = (mapping)raw;
			userid = (string)entry["userid"];
			account_id = (string)entry["account_id"];
			if(!pike_gateway_valid_userid(userid) ||
			   !pike_gateway_valid_userid(account_id))
				error("invalid live lease identity\n");
			pike_gateway_record_account(userid,account_id);
			mutex = pike_gateway_user_mutex(userid,account_id);
			if(!arrayp(lock_groups[mutex]))
				lock_groups[mutex] = ({});
			lock_groups[mutex] += ({entry});
		}
		foreach(indices(lock_groups),object mutex){
			object lock_key = mutex->trylock();
			if(lock_key){
				acquired += ({lock_key});
				candidates += lock_groups[mutex];
			}
		}
		mapping refreshed;
		mixed refresh_err = catch {
			refreshed = pike_gateway_worker_rpc(worker_id,
				"local_live_leases",(["offset":offset,"limit":128]));
			array refreshed_leases = arrayp(refreshed["leases"]) ?
				(array)refreshed["leases"] : 0;
			if(!(int)refreshed["ok"] || !arrayp(refreshed_leases) ||
			   sizeof(refreshed_leases)>128)
				error("invalid refreshed lease page\n");
			multiset(string) capabilities = (<>);
			foreach(refreshed_leases,mixed raw)
				if(mappingp(raw))
					capabilities[(string)raw["userid"]+"|"+
						(string)raw["account_id"]+"|"+
						(string)(int)raw["epoch"]+"|"+
						(string)raw["affinity"]] = 1;
			array(mapping) verified = ({});
			foreach(candidates,mapping item){
				string capability = (string)item["userid"]+"|"+
					(string)item["account_id"]+"|"+
					(string)(int)item["epoch"]+"|"+
					(string)item["affinity"];
				if(capabilities[capability])
					verified += ({(["userid":(string)item["userid"],
						"epoch":(int)item["epoch"],
						"affinity":(string)item["affinity"]])});
			}
			if(sizeof(verified)){
				mapping renewed = MAP_WORKERD->renew_player_leases_batch(
					worker_id,generation,verified);
				if(!(int)renewed["ok"] ||
				   (int)renewed["count"]!=sizeof(verified))
					error("live lease renewal rejected\n");
			}
		};
		for(int index=sizeof(acquired)-1;index>=0;index--)
			destruct(acquired[index]);
		if(refresh_err)
			error(describe_error(refresh_err));
		array refreshed_leases = (array)refreshed["leases"];
		int next_offset = (int)refreshed["next_offset"];
		if((int)refreshed["done"])
			return;
		if(next_offset<=offset ||
		   next_offset!=offset+sizeof(refreshed_leases))
			error("non-progressing live lease page\n");
		offset = next_offset;
	}
	error("worker live lease inventory exceeded hard limit\n");
}

private void pike_gateway_monitor_worker(string worker_id)
{
	mapping metrics;
	mapping heartbeat;
	int generation = pike_gateway_generations[worker_id];
	mixed monitor_err = catch {
		metrics = pike_gateway_collect_worker_metrics(worker_id);
		if(generation<1)
			error("worker generation unavailable\n");
		heartbeat = MAP_WORKERD->heartbeat_worker(worker_id,generation,metrics);
		if((string)heartbeat["code"]=="stale_generation"){
			object recovery_key = pike_gateway_recovery_lock->lock();
			pike_gateway_pause_routing();
			mixed recovery_err = catch {
				pike_gateway_register_all();
				pike_gateway_sync_catalog();
				pike_gateway_recover_local_players();
			};
			if(!recovery_err)
				pike_gateway_resume_routing();
			destruct(recovery_key);
			if(recovery_err)
				error(describe_error(recovery_err));
		}
		else{
			if(!(int)heartbeat["ok"])
				error("worker heartbeat rejected\n");
			if(!pike_gateway_worker_is_reachable(worker_id)){
				object recovery_key = pike_gateway_recovery_lock->lock();
				pike_gateway_pause_routing();
				mixed recovery_err = catch {
					pike_gateway_reconcile_recovered_worker(worker_id);
					pike_gateway_set_worker_reachable(worker_id,1);
				};
				if(!recovery_err)
					pike_gateway_resume_routing();
				destruct(recovery_key);
				if(recovery_err)
					error(describe_error(recovery_err));
			}
			else{
				mapping control = pike_gateway_worker_rpc(worker_id,
					"local_control_heartbeat",([]));
				if(!(int)control["ok"])
					error("worker control heartbeat rejected\n");
				/* Renew control before paging live leases. A slow accepted
				 * request may consume most of the 15-second control window. */
				pike_gateway_renew_live_player_leases(worker_id,generation);
			}
		}
	};
	if(monitor_err){
		pike_gateway_set_worker_reachable(worker_id,0);
		object key = pike_gateway_state_lock->lock();
		pike_gateway_last_error = "monitor "+worker_id+": "+
			describe_error(monitor_err);
		m_delete(pike_gateway_online_rows_by_worker,worker_id);
		m_delete(pike_gateway_online_rows_at,worker_id);
		destruct(key);
	}
	else{
		object key = pike_gateway_state_lock->lock();
		string prefix = "monitor "+worker_id+":";
		if(has_prefix(pike_gateway_last_error,prefix))
			pike_gateway_last_error = "";
		destruct(key);
	}
}

private void pike_gateway_resolve_uncertain_requests()
{
	array(string) requests;
	object key = pike_gateway_state_lock->lock();
	requests = indices(pike_gateway_uncertain_requests);
	destruct(key);
	if(!sizeof(requests))
		return;
	foreach(requests,string request_key){
		array(string) parts = request_key / "|";
		if(sizeof(parts)!=2)
			continue;
		mixed status;
		mixed status_err = catch {
			status = pike_gateway_worker_rpc(parts[0],
				"local_request_status",(["request_id":parts[1]]));
		};
		if(status_err || !mappingp(status))
			continue;
		if((int)status["ok"] && (string)status["state"]!="done")
			continue;
		if(!(int)status["ok"] && (string)status["code"]!="unknown_request")
			continue;
		key = pike_gateway_state_lock->lock();
		pike_gateway_uncertain_done[request_key] = 1;
		destruct(key);
	}
	key = pike_gateway_state_lock->lock();
	int all_done = sizeof(pike_gateway_uncertain_done)==
		sizeof(pike_gateway_uncertain_requests);
	destruct(key);
	if(!all_done)
		return;
	object recovery_key = pike_gateway_recovery_lock->lock();
	pike_gateway_pause_routing();
	mixed recovery_err = catch { pike_gateway_recover_local_players(); };
	if(!recovery_err){
		key = pike_gateway_state_lock->lock();
		pike_gateway_uncertain_requests = (<>);
		pike_gateway_uncertain_done = (<>);
		destruct(key);
		pike_gateway_resume_routing();
	}
	destruct(recovery_key);
	if(recovery_err){
		key = pike_gateway_state_lock->lock();
		pike_gateway_last_error = "uncertain recovery: "+
			describe_error(recovery_err);
		destruct(key);
	}
}

private void pike_gateway_deliver_background_arrival(string userid,
	string worker_id,int epoch,string room_path,string account_id)
{
	if(!pike_gateway_valid_userid(userid) ||
	   !pike_gateway_worker_ports[worker_id] || epoch<1 ||
	   !has_prefix(room_path,"/gamelib/d/") || search(room_path,"#")!=-1 ||
	   !pike_gateway_valid_userid(account_id))
		error("invalid background arrival capability\n");
	mapping result = pike_gateway_worker_rpc(worker_id,"local_arrival",([
		"userid":userid,"epoch":epoch,"room_path":room_path,
		"account_owner":account_id,
		"account_cache_token":pike_gateway_account_cache_token(
			account_id,worker_id),
	]));
	if(!(int)result["ok"])
		error("background arrival failed\n");
	mapping confirmed = pike_gateway_confirmed_route(userid,worker_id,epoch);
	if((string)confirmed["arrival_room"]!=room_path ||
	   (string)result["affinity"]!=(string)confirmed["affinity"])
		error("background arrival route mismatch\n");
	pike_gateway_acknowledge_arrival(userid,worker_id,epoch,
		(string)confirmed["affinity"],room_path);
	confirmed = pike_gateway_confirmed_route(userid,worker_id,epoch);
	if((string)confirmed["arrival_room"]!="")
		error("background arrival remains pending\n");
}

private void pike_gateway_settle_background_move(string source_worker,
	mapping item)
{
	string userid = lower_case(String.trim_all_whites(
		(string)(item["userid"] || "")));
	string account_id = lower_case(String.trim_all_whites(
		(string)(item["account_id"] || "")));
	int source_epoch = (int)item["lease_epoch"];
	object user_key;
	int request_entered;
	mixed settle_err = catch {
		if(!pike_gateway_worker_ports[source_worker] ||
		   !pike_gateway_valid_userid(userid) ||
		   !pike_gateway_valid_userid(account_id) || source_epoch<1)
			error("invalid background movement\n");
		pike_gateway_record_account(userid,account_id);
		user_key = pike_gateway_user_mutex(userid,account_id)->lock();
		pike_gateway_begin_request();
		request_entered = 1;
		pike_gateway_ensure_routing_ready();
		mapping route = MAP_WORKERD->query_player_route(userid);
		if((int)route["ok"] && (string)route["state"]=="active" &&
		   (string)route["worker_id"]==source_worker &&
		   (int)route["epoch"]==source_epoch){
			mapping migration = pike_gateway_reconcile(userid,source_worker,
				source_epoch,(string)route["affinity"],1);
			if(mappingp(migration) &&
			   (string)migration["worker_id"]!=source_worker){
				string target_worker = (string)migration["worker_id"];
				int target_epoch = (int)migration["epoch"];
				string room_path = (string)migration["arrival_room"];
				pike_gateway_set_background_arrival(userid,([
					"worker_id":target_worker,"epoch":target_epoch,
					"room_path":room_path,"account_id":account_id,
				]));
				pike_gateway_deliver_background_arrival(userid,target_worker,
					target_epoch,room_path,account_id);
				pike_gateway_delete_background_arrival(userid);
			}
		}
	};
	if(request_entered)
		pike_gateway_end_request();
	if(user_key)
		destruct(user_key);
	if(settle_err)
		error(describe_error(settle_err));
}

private void pike_gateway_retry_background_arrival(string userid,
	mapping pending)
{
	string worker_id = (string)pending["worker_id"];
	int epoch = (int)pending["epoch"];
	string room_path = (string)pending["room_path"];
	string account_id = (string)pending["account_id"];
	object user_key = pike_gateway_user_mutex(userid,account_id)->lock();
	int request_entered;
	mixed retry_err = catch {
		pike_gateway_begin_request();
		request_entered = 1;
		pike_gateway_ensure_routing_ready();
		mapping route = MAP_WORKERD->query_player_route(userid);
		if(!(int)route["ok"] || (string)route["state"]!="active" ||
		   (string)route["worker_id"]!=worker_id ||
		   (int)route["epoch"]!=epoch)
			pike_gateway_delete_background_arrival(userid);
		else{
			string authoritative_room =
				(string)(route["arrival_room_path"] || "");
			if(authoritative_room=="")
				pike_gateway_delete_background_arrival(userid);
			else{
				if(authoritative_room!=room_path)
					error("background arrival capability changed\n");
				pike_gateway_deliver_background_arrival(userid,worker_id,
					epoch,room_path,account_id);
				pike_gateway_delete_background_arrival(userid);
			}
		}
	};
	if(request_entered)
		pike_gateway_end_request();
	destruct(user_key);
	if(retry_err)
		error(describe_error(retry_err));
}

private void pike_gateway_run_background_handoffs()
{
	foreach(pike_gateway_background_arrival_snapshot();
		string userid;mapping pending){
		mixed retry_err = catch {
			pike_gateway_retry_background_arrival(userid,pending);
		};
		if(retry_err)
			werror("[PIKE_GATEWAY][ARRIVAL_RETRY] userid=%s error=%s\n",
				userid,describe_error(retry_err));
	}
	foreach(sort(indices(pike_gateway_worker_ports)),string worker_id){
		if(!pike_gateway_worker_is_reachable(worker_id))
			continue;
		mapping routes;
		mixed routes_err = catch {
			routes = pike_gateway_worker_rpc(worker_id,
				"local_pending_routes",([]));
		};
		if(routes_err || !mappingp(routes) || !(int)routes["ok"] ||
		   !arrayp(routes["pending"]))
			continue;
		foreach((array)routes["pending"],mixed raw){
			if(!mappingp(raw))
				continue;
			mixed settle_err = catch {
				pike_gateway_settle_background_move(worker_id,(mapping)raw);
			};
			if(settle_err)
				werror("[PIKE_GATEWAY][BACKGROUND_HANDOFF] worker=%s error=%s\n",
					worker_id,describe_error(settle_err));
		}
	}
}

private void pike_gateway_run_lease_gc()
{
	object recovery_key = pike_gateway_recovery_lock->lock();
	pike_gateway_pause_routing();
	mixed recovery_err = catch { pike_gateway_recover_local_players(); };
	if(!recovery_err)
		pike_gateway_resume_routing();
	destruct(recovery_key);
	if(recovery_err)
		error(describe_error(recovery_err));
}

private void pike_gateway_run_auction_tick()
{
	if(pike_gateway_shadow ||
	   !pike_gateway_worker_is_reachable(pike_gateway_primary))
		return;
	object auction_key = pike_gateway_auction_lock->trylock();
	if(!auction_key)
		return;
	mixed tick_err = catch {
		pike_gateway_worker_rpc(pike_gateway_primary,"local_auction_tick",([]));
	};
	destruct(auction_key);
	if(tick_err)
		werror("[PIKE_GATEWAY][AUCTION_TICK] %s\n",describe_error(tick_err));
}

private void pike_gateway_start_public_listener()
{
	if(pike_gateway_shadow || !pike_gateway_controller_ready ||
	   pike_gateway_public_port)
		return;
	if((getenv("XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK") || "")!=
	   "isolated-test-server-only"){
		object key = pike_gateway_state_lock->lock();
		pike_gateway_last_error = "active gateway acknowledgement missing";
		pike_gateway_routing_ready = 0;
		destruct(key);
		werror("[PIKE_GATEWAY] active listener refused: trial acknowledgement missing\n");
		return;
	}
	mixed listener_err = catch {
		pike_gateway_public_port = Protocols.HTTP.Server.Port(
			handle_pike_gateway_request,pike_gateway_listen_port,"0.0.0.0");
	};
	if(listener_err){
		object key = pike_gateway_state_lock->lock();
		pike_gateway_last_error = "public listener: "+
			describe_error(listener_err);
		pike_gateway_routing_ready = 0;
		destruct(key);
		werror("[PIKE_GATEWAY] public listener failed: %s\n",
			describe_error(listener_err));
	}
	else
		werror("[PIKE_GATEWAY] public listener ready on 0.0.0.0:%d\n",
			pike_gateway_listen_port);
}

private void pike_gateway_controller_loop()
{
	while(!pike_gateway_stop){
		if(!pike_gateway_controller_ready){
			mixed startup_err = catch {
				pike_gateway_register_all();
				pike_gateway_sync_catalog();
				pike_gateway_recover_local_players();
			};
			if(startup_err){
				object key = pike_gateway_state_lock->lock();
				pike_gateway_last_error = "startup: "+
					describe_error(startup_err);
				destruct(key);
				sleep(2);
				continue;
			}
			object key = pike_gateway_state_lock->lock();
			pike_gateway_controller_ready = 1;
			pike_gateway_routing_ready = 1;
			pike_gateway_last_error = "";
			pike_gateway_last_monitor_at = time();
			pike_gateway_last_handoff_at = time();
			pike_gateway_last_auction_at = time();
			pike_gateway_last_lease_gc_at = time();
			destruct(key);
			call_out(pike_gateway_start_public_listener,0);
			werror("[PIKE_GATEWAY] controller ready; mode=%s workers=%d\n",
				pike_gateway_shadow ? "shadow" : "active",
				sizeof(pike_gateway_worker_ports));
		}
		pike_gateway_resolve_uncertain_requests();
		int now = time();
		if(now-pike_gateway_last_monitor_at>=5){
			pike_gateway_last_monitor_at = now;
			foreach(sort(indices(pike_gateway_worker_ports)),string worker_id)
				pike_gateway_monitor_worker(worker_id);
			pike_gateway_publish_online_snapshot();
		}
		if(pike_gateway_routing_ready &&
		   now-pike_gateway_last_handoff_at>=1){
			pike_gateway_last_handoff_at = now;
			pike_gateway_run_background_handoffs();
		}
		if(pike_gateway_routing_ready &&
		   now-pike_gateway_last_lease_gc_at>=pike_gateway_lease_gc_seconds){
			pike_gateway_last_lease_gc_at = now;
			mixed gc_err = catch { pike_gateway_run_lease_gc(); };
			if(gc_err){
				object key = pike_gateway_state_lock->lock();
				pike_gateway_last_error = "lease GC: "+describe_error(gc_err);
				destruct(key);
			}
		}
		if(!pike_gateway_shadow &&
		   now-pike_gateway_last_auction_at>=1200){
			pike_gateway_last_auction_at = now;
			pike_gateway_run_auction_tick();
		}
		sleep(0.25);
	}
}

void init_pike_gateway()
{
	mapping config;
	int worker_count;
	int worker_http_base;
	if(MAP_WORKERD->query_node_role()!="gateway" || pike_gateway_enabled)
		return;
	config = MAP_WORKERD->query_cluster_config();
	if(!(int)config["enabled"])
		return;
	pike_gateway_token = getenv("XIAND_WORKER_TOKEN") || "";
	if(sizeof(pike_gateway_token)<32){
		werror("[PIKE_GATEWAY] XIAND_WORKER_TOKEN must be at least 32 characters\n");
		return;
	}
	worker_count = (int)config["worker_count"];
	worker_http_base = (int)config["worker_http_base_port"];
	if(worker_count<1 || worker_count>16 || worker_http_base<1024 ||
	   worker_http_base+worker_count-1>65535){
		werror("[PIKE_GATEWAY] invalid worker topology\n");
		return;
	}
	pike_gateway_shadow = (getenv("XIAND_MAP_WORKER_SHADOW") || "") == "1";
	pike_gateway_worker_capacity = (int)config["worker_capacity"];
	pike_gateway_listen_port = (int)config["gateway_port"];
	pike_gateway_timeout = pike_gateway_env_int(
		"XIAND_WORKER_TIMEOUT",30,1,120);
	pike_gateway_control_timeout = pike_gateway_env_int(
		"XIAND_WORKER_CONTROL_TIMEOUT",2,1,10);
	pike_gateway_max_requests = pike_gateway_env_int(
		"XIAND_GATEWAY_MAX_REQUESTS",128,8,1024);
	pike_gateway_lease_gc_seconds = pike_gateway_env_int(
		"XIAND_MAP_WORKER_LEASE_GC_SECONDS",3600,300,86400);
	for(int index=1;index<=worker_count;index++){
		string worker_id = sprintf("w%02d",index);
		pike_gateway_worker_ports[worker_id] = worker_http_base+index-1;
		pike_gateway_worker_reachable[worker_id] = 0;
	}
	pike_gateway_primary = sort(indices(pike_gateway_worker_ports))[0];
	pike_gateway_controller_nonce = pike_gateway_random_hex(16);
	for(int index=0;index<PIKE_GATEWAY_USER_LOCKS;index++)
		pike_gateway_user_locks += ({Thread.Mutex()});
	pike_gateway_request_farm = Thread.Farm();
	pike_gateway_request_farm->set_max_num_threads(
		min(64,max(8,pike_gateway_max_requests)));
	pike_gateway_started_at = time();
	pike_gateway_enabled = 1;
	pike_gateway_controller_thread = Thread.Thread(
		pike_gateway_controller_loop);
	werror("[PIKE_GATEWAY] embedded controller starting; mode=%s workers=%d\n",
		pike_gateway_shadow ? "shadow" : "active",worker_count);
}
