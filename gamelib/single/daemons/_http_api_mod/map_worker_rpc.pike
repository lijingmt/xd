/** Internal loopback RPC for map-worker coordination and local handoff. */

private int map_worker_rpc_authorized(Protocols.HTTP.Server.Request req)
{
    string configured = getenv("XIAND_WORKER_TOKEN") || "";
    string supplied = req->request_headers["x-xiand-worker-token"] || "";
    string remote_address = req->remote_addr || "";
    if(remote_address=="" && functionp(req->get_ip))
        remote_address = (string)req->get_ip();
    string client_ip = normalize_http_client_ip(remote_address);
    int authorized = sizeof(configured)>=32 && supplied==configured &&
        (client_ip=="127.0.0.1" || client_ip=="::1");
    if(!authorized)
        werror("[MAP_WORKER_RPC] denied configured_len=%d supplied_len=%d "+
            "token_match=%d client_ip=%s\n",sizeof(configured),sizeof(supplied),
            supplied==configured,client_ip);
    return authorized;
}

private int map_worker_coordinator_role()
{
    string role = MAP_WORKERD->query_node_role();
    return role=="gateway" || role=="standalone";
}

private string map_worker_admin_capability(string manager_userid,
    string target_userid,string account_id,string worker_id,int epoch,
    int fee,string recharge_request_id,string gateway_request_id)
{
    object hash = Crypto.SHA256();
    hash->update((getenv("XIAND_WORKER_TOKEN") || "")+"|admin_recharge|"+
        manager_userid+"|"+target_userid+"|"+account_id+"|"+worker_id+"|"+
        (string)epoch+"|"+(string)fee+"|"+recharge_request_id+"|"+
        gateway_request_id);
    return lower_case(String.string2hex(hash->digest()));
}

private mapping map_worker_internal_http_call(int port,mapping payload)
{
    object query;
    object response;
    mapping decoded;
    string body;
    mixed err;
    if(port<1024 || port>65535)
        return (["ok":0,"code":"invalid_internal_port"]);
    query = Protocols.HTTP.Query();
    query->maxtime = 30;
    err = catch {
        response = Protocols.HTTP.do_method("POST",
            "http://127.0.0.1:"+(string)port+"/internal/map-worker",0,([
                "Content-Type":"application/json",
                "X-Xiand-Worker-Token":getenv("XIAND_WORKER_TOKEN") || "",
            ]),query,Standards.JSON.encode(payload));
        if(!response)
            error("internal worker request failed\n");
        body = response->data(1024*1024+1);
        if(sizeof(body)>1024*1024)
            error("internal worker response too large\n");
        decoded = Standards.JSON.decode(body);
        if(!mappingp(decoded))
            error("invalid internal worker response\n");
    };
    if(err)
        return (["ok":0,"code":"internal_worker_unavailable"]);
    return decoded;
}

/** Called only from txadd while the public Pike gateway holds target account lock. */
mapping(string:mixed) execute_map_worker_admin_recharge(object manager,
    string target_userid,int fee,string recharge_request_id)
{
    string manager_userid;
    string target_worker;
    string target_account;
    string capability;
    string gateway_request_id;
    int target_epoch;
    int worker_index;
    int worker_count;
    int worker_http_base;
    mapping metadata;
    mapping config;
    mapping result;
    target_userid = lower_case(String.trim_all_whites(target_userid || ""));
    recharge_request_id = lower_case(String.trim_all_whites(
        recharge_request_id || ""));
    if(MAP_WORKERD->query_node_role()!="worker" || !manager ||
       MANAGERD->checkpower(manager->query_name())!="admin")
        return (["ok":0,"message":"分布式充值权限校验失败"]);
    manager_userid = lower_case((string)manager->query_name());
    metadata = MAP_WORKERD->query_local_running_admin_target(manager_userid);
    if(!(int)metadata["ok"] ||
       (string)metadata["admin_target_userid"]!=target_userid ||
       (int)metadata["admin_fee"]!=fee ||
       (string)metadata["admin_recharge_request_id"]!=recharge_request_id)
        return (["ok":0,"message":"充值目标没有协调器锁定"]);
    target_worker = (string)metadata["admin_target_worker"];
    target_account = (string)metadata["admin_target_account"];
    target_epoch = (int)metadata["admin_target_epoch"];
    capability = (string)metadata["admin_capability"];
    gateway_request_id = (string)metadata["request_id"];
    if(sizeof(target_worker)!=3 || target_worker[0]!='w' ||
       target_worker[1]<'0' || target_worker[1]>'9' ||
       target_worker[2]<'0' || target_worker[2]>'9')
        return (["ok":0,"message":"充值目标 worker 无效"]);
    worker_index = (int)target_worker[1..];
    config = MAP_WORKERD->query_cluster_config();
    worker_count = MAP_WORKERD->query_runtime_worker_count();
    worker_http_base = (int)config["worker_http_base_port"];
    if(worker_index<1 || worker_index>worker_count)
        return (["ok":0,"message":"充值目标 worker 不在当前拓扑"]);
    mapping target_payload = ([
        "action":"local_admin_recharge","manager_userid":manager_userid,
        "target_userid":target_userid,"account_id":target_account,
        "worker_id":target_worker,"epoch":target_epoch,"fee":fee,
        "recharge_request_id":recharge_request_id,
        "gateway_request_id":gateway_request_id,
        "capability":capability,
    ]);
    // A command is already running on this worker's main Backend. Calling its
    // own HTTP listener here would wait on itself and stop control heartbeats.
    if(target_worker==MAP_WORKERD->query_local_worker_id())
        result = execute_map_worker_local_admin_recharge(target_payload);
    else
        result = map_worker_internal_http_call(
            worker_http_base+worker_index-1,target_payload);
    if(!(int)result["ok"])
        return result+(["message":(string)(result["message"] ||
            "目标 worker 充值失败，本次没有重复入账")]);
    result["worker_id"] = target_worker;
    for(int index=1;index<=worker_count;index++){
        string refresh_worker = sprintf("w%02d",index);
        mapping refreshed;
        if(refresh_worker==MAP_WORKERD->query_local_worker_id())
            refreshed = execute_map_worker_local_account_refresh(
                target_account);
        else
            refreshed = map_worker_internal_http_call(
                worker_http_base+index-1,([
                "action":"local_account_refresh",
                "account_id":target_account,
            ]));
        if(!(int)refreshed["ok"]){
            result["cache_refresh_ok"] = 0;
            result["message"] = "充值已入账，但有 worker 缓存刷新失败，请重试同一确认链接";
            return result;
        }
    }
    result["cache_refresh_ok"] = 1;
    return result;
}

mapping(string:mixed) query_map_worker_cluster_online_users()
{
    if(MAP_WORKERD->query_node_role()!="worker")
        return (["ok":0,"code":"not_worker"]);
    // A public request is already being awaited by the coordinator. Calling
    // it back synchronously here would deadlock both event loops.
    return MAP_WORKERD->query_local_online_snapshot();
}

/** Every public request reaching a worker must come through the loopback gateway. */
private int map_worker_gateway_request_authorized(
    Protocols.HTTP.Server.Request req)
{
    string role = MAP_WORKERD->query_node_role();
    string routed_worker;
    string routed_user;
    string arrival_room;
    string account_owner;
    string account_cache_token;
    int routed_epoch;
    int cache_changed;
    object local_player;
    mapping epoch_result;
    if(role!="worker")
        return 1;
    routed_worker = lower_case(String.trim_all_whites(
        req->request_headers["x-xiand-lease-worker"] || ""));
    routed_user = lower_case(String.trim_all_whites(
        req->request_headers["x-xiand-lease-userid"] || ""));
    routed_epoch = (int)(req->request_headers["x-xiand-lease-epoch"] || "0");
    if(!map_worker_rpc_authorized(req) ||
       routed_worker!=MAP_WORKERD->query_local_worker_id())
        return 0;
    // Public traffic only consumes the current capability; it never renews it.
    // Renewal is reserved for local_control_heartbeat after coordinator ACK.
    if(!MAP_WORKERD->local_control_lease_valid())
        return 0;
    if((routed_user=="" && routed_epoch!=0) ||
       (routed_user!="" && routed_epoch<1))
        return 0;
    account_owner = lower_case(String.trim_all_whites(
        req->request_headers["x-xiand-account-owner"] || ""));
    account_cache_token = lower_case(String.trim_all_whites(
        req->request_headers["x-xiand-account-cache-token"] || ""));
    if((account_owner=="")!=(account_cache_token==""))
        return 0;
    if(account_owner!=""){
        cache_changed = MAP_WORKERD->accept_local_account_cache_token(
            account_owner,account_cache_token);
        if(cache_changed<0)
            return 0;
        if(cache_changed){
            if(functionp(ACCOUNT_STORAGED->invalidate_worker_account_cache))
                ACCOUNT_STORAGED->invalidate_worker_account_cache(account_owner);
            if(functionp(ACCOUNT_WALLETD->invalidate_worker_account_cache))
                ACCOUNT_WALLETD->invalidate_worker_account_cache(account_owner);
            if(functionp(ACCOUNT_CHARACTERD->invalidate_worker_account_cache))
                ACCOUNT_CHARACTERD->invalidate_worker_account_cache(account_owner);
            if(functionp(PETD->invalidate_worker_account_cache))
                PETD->invalidate_worker_account_cache(account_owner);
        }
    }
    if(routed_user!=""){
        if(account_owner=="")
            return 0;
        local_player = find_player(routed_user);
        if(local_player && functionp(local_player->query_account_owner) &&
           lower_case((string)local_player->query_account_owner())!=account_owner)
            return 0;
        epoch_result = MAP_WORKERD->accept_local_player_epoch(
            routed_user,routed_epoch,local_player ? 1 : 0);
        if(!(int)epoch_result["ok"])
            return 0;
        epoch_result = MAP_WORKERD->accept_local_player_account_owner(
            routed_user,routed_epoch,account_owner);
        if(!(int)epoch_result["ok"])
            return 0;
        arrival_room = String.trim_all_whites(
            req->request_headers["x-xiand-arrival-room"] || "");
        if(arrival_room!=""){
            epoch_result = MAP_WORKERD->install_local_player_arrival(
                routed_user,routed_epoch,arrival_room);
            if(!(int)epoch_result["ok"])
                return 0;
        }
    }
    return 1;
}

private string map_worker_player_affinity(object player)
{
    return MAP_WORKERD->query_player_affinity(player);
}

/** Include epoch-owned living objects even when they have no CONND entry. */
private array(object) map_worker_local_players()
{
    array(object) result = ({});
    mapping(object:int) seen = ([]);
    foreach(users(1),object player)
        if(player && !seen[player] && functionp(player->query_name)){
            seen[player] = 1;
            result += ({player});
        }
    foreach(MAP_WORKERD->query_local_player_userids(),string userid){
        object player = get_player_from_connection(userid,0);
        if(!player)
            player = find_player(userid);
        if(player && !seen[player] && functionp(player->query_name)){
            seen[player] = 1;
            result += ({player});
        }
    }
    return result;
}

private void handle_map_worker_local_route(
    Protocols.HTTP.Server.Request req,mapping params)
{
    string userid = lower_case(String.trim_all_whites(
        (string)(params["userid"] || "")));
    object player = get_player_from_connection(userid,0);
    if(!player)
        player = find_player(userid);
    if(!player){
        send_json(req,(["ok":0,"code":"player_not_local"]),404);
        return;
    }
    object room = environment(player);
    mapping redirect = MAP_WORKERD->query_local_move_redirect(userid);
    string account_id = functionp(player->query_account_owner) ?
        lower_case((string)player->query_account_owner()) : userid;
    send_json(req,([
        "ok":1,
        "userid":userid,
        "account_id":account_id,
        "worker_id":MAP_WORKERD->query_local_worker_id(),
        "lease_epoch":MAP_WORKERD->query_local_player_epoch(userid),
        "affinity":map_worker_player_affinity(player),
        "room_path":room ? file_name(room)-ROOT : "",
        "in_combat":(int)player->in_combat,
        "handoff_safe":!(int)player->in_combat,
        "move_redirect":(int)redirect["ok"] ? redirect : 0,
    ]));
}

/** Resolve a user-bound opaque UI token on its currently routed worker. */
private void handle_map_worker_local_resolve_command(
    Protocols.HTTP.Server.Request req,mapping params)
{
    string userid = lower_case(String.trim_all_whites(
        (string)(params["userid"] || "")));
    string command = String.trim_all_whites(
        (string)(params["command"] || ""));
    int epoch = (int)params["epoch"];
    string resolved;
    if(MAP_WORKERD->query_node_role()!="worker" || userid=="" || epoch<1 ||
       !has_prefix(command,"c_") || sizeof(command)>MAX_HTTP_QUERY_SIZE){
        send_json(req,(["ok":0,"code":"invalid_command_token_request"]),409);
        return;
    }
    // 旧 JSP 页面可能在人物离线、worker 重启或跨 worker 迁移后继续
    // 提交原页面令牌。人物尚未在当前 worker 恢复时不能解开旧令牌，
    // 但可安全降级为 look，让后续正常请求恢复人物并生成新令牌。
    // 这里只恢复画面，绝不重放赠送、交易、拍卖或管理命令。
    if(MAP_WORKERD->query_local_player_epoch(userid)!=epoch){
        send_json(req,(["ok":1,"code":"stale_command_token_route",
            "command":"look","recovered":1]));
        return;
    }
    resolved = unhide_command(userid,command);
    if(resolved=="" || sizeof(resolved)>MAX_HTTP_QUERY_SIZE){
        send_json(req,(["ok":0,"code":"invalid_resolved_command"]),409);
        return;
    }
    send_json(req,(["ok":1,"command":resolved]));
}

/**
 * List only already-fenced player moves.  The gateway uses this for moves
 * produced by heartbeat/autofight code when no browser request exists to run
 * the normal post-response reconciliation path.
 */
private void handle_map_worker_local_pending_routes(
    Protocols.HTTP.Server.Request req)
{
    array(mapping(string:mixed)) pending = ({});
    foreach(map_worker_local_players(),object player){
        string userid;
        mapping redirect;
        string account_id;
        if(sizeof(pending)>=128 || !player || !functionp(player->query_name))
            break;
        userid = lower_case((string)player->query_name());
        redirect = MAP_WORKERD->query_local_move_redirect(userid);
        if(!(int)redirect["ok"] || (int)player->in_combat)
            continue;
        account_id = functionp(player->query_account_owner) ?
            lower_case((string)player->query_account_owner()) : userid;
        pending += ({([
            "userid":userid,
            "account_id":account_id,
            "lease_epoch":MAP_WORKERD->query_local_player_epoch(userid),
            "source_affinity":redirect["source_affinity"],
            "target_affinity":redirect["target_affinity"],
            "target_room_path":redirect["target_room_path"],
        ])});
    }
    send_json(req,(["ok":1,"pending":pending,"count":sizeof(pending)]));
}

/**
 * Return a bounded page of exact live-player capabilities for coordinator
 * renewal.  Pending moves still belong to their source affinity until the
 * gateway durably completes the handoff, so they must not be reported as if
 * the target lease had already committed.
 */
private void handle_map_worker_local_live_leases(
    Protocols.HTTP.Server.Request req,mapping params)
{
    mapping(string:mapping(string:mixed)) live = ([]);
    array(string) userids;
    array(mapping(string:mixed)) leases = ({});
    int offset = max(0,(int)params["offset"]);
    int limit = max(1,min(128,(int)(params["limit"] || 128)));
    if(MAP_WORKERD->query_node_role()!="worker" ||
       !MAP_WORKERD->local_control_lease_valid()){
        send_json(req,(["ok":0,"code":"worker_control_fenced"]),409);
        return;
    }
    foreach(map_worker_local_players(),object player){
        string userid;
        string affinity;
        string account_id;
        int epoch;
        mapping redirect;
        if(!player || !functionp(player->query_name))
            continue;
        userid = lower_case((string)player->query_name());
        // A public command already renewed this exact lease before entering
        // the worker. Do not race its response-tail handoff from the monitor.
        if(MAP_WORKERD->local_user_request_running(userid))
            continue;
        epoch = MAP_WORKERD->query_local_player_epoch(userid);
        redirect = MAP_WORKERD->query_local_move_redirect(userid);
        affinity = (int)redirect["ok"] ?
            (string)redirect["source_affinity"] :
            map_worker_player_affinity(player);
        account_id = functionp(player->query_account_owner) ?
            lower_case((string)player->query_account_owner()) : userid;
        if(userid=="" || account_id=="" || epoch<1 || affinity==""){
            send_json(req,(["ok":0,"code":"invalid_live_player",
                "userid":userid]),409);
            return;
        }
        if(mappingp(live[userid])){
            send_json(req,(["ok":0,"code":"duplicate_live_player",
                "userid":userid]),409);
            return;
        }
        live[userid] = (["userid":userid,"account_id":account_id,
            "epoch":epoch,"affinity":affinity]);
    }
    userids = sort(indices(live));
    if(offset>sizeof(userids)){
        send_json(req,(["ok":0,"code":"invalid_live_lease_offset"]),409);
        return;
    }
    for(int index=offset;
        index<sizeof(userids) && sizeof(leases)<limit;index++)
        leases += ({live[userids[index]]});
    int next_offset = offset+sizeof(leases);
    send_json(req,(["ok":1,"leases":leases,"count":sizeof(leases),
        "next_offset":next_offset,
        "done":next_offset>=sizeof(userids) ? 1 : 0]));
}

private void discard_map_worker_internal_arrival(string userid,object player)
{
    remove_virtual_connection(userid);
    MAP_WORKERD->clear_local_player_epoch(userid);
    if(player){
        if(functionp(player->discard_stale_worker_copy))
            player->discard_stale_worker_copy();
        else
            destruct(player);
    }
}

/**
 * Materialize a committed background handoff without a client password or
 * command replay.  The loopback token, exact epoch, account owner and cache
 * capability are all required before the sole disk snapshot is restored.
 */
private void handle_map_worker_local_arrival(
    Protocols.HTTP.Server.Request req,mapping params)
{
    string userid = lower_case(String.trim_all_whites(
        (string)(params["userid"] || "")));
    string room_path = String.trim_all_whites(
        (string)(params["room_path"] || ""));
    string account_owner = lower_case(String.trim_all_whites(
        (string)(params["account_owner"] || "")));
    string cache_token = lower_case(String.trim_all_whites(
        (string)(params["account_cache_token"] || "")));
    int epoch = (int)params["epoch"];
    object player;
    object master;
    program user_program;
    string password;
    int setup_ok;
    int cache_changed;
    mapping result;
    mapping arrival_result;
    mixed setup_err;
    mixed load_err;
    if(MAP_WORKERD->query_node_role()!="worker" ||
       !MAP_WORKERD->local_control_lease_valid() ||
       userid=="" || account_owner=="" || epoch<1 || room_path==""){
        send_json(req,(["ok":0,"code":"invalid_local_arrival"]),409);
        return;
    }
    player = get_player_from_connection(userid,0);
    if(!player)
        player = find_player(userid);
    if(player){
        object room = environment(player);
        string actual_path = room ? file_name(room)-ROOT : "";
        string actual_owner = functionp(player->query_account_owner) ?
            lower_case((string)player->query_account_owner()) : userid;
        if(MAP_WORKERD->query_local_player_epoch(userid)==epoch &&
           actual_path==room_path && actual_owner==account_owner){
            // A previous materialization may have completed while its reply
            // was lost. The exact live player is authoritative; retire any
            // duplicate local arrival capability before the gateway ACKs it.
            mapping pending_arrival =
                MAP_WORKERD->query_local_player_arrival(userid);
            if((int)pending_arrival["ok"] &&
               (int)pending_arrival["epoch"]==epoch &&
               (string)pending_arrival["room_path"]==room_path)
                MAP_WORKERD->clear_local_player_arrival(userid);
            send_json(req,(["ok":1,"replayed":1,"userid":userid,
                "room_path":room_path,
                "affinity":map_worker_player_affinity(player)]));
            return;
        }
        send_json(req,(["ok":0,"code":"live_player_conflict"]),409);
        return;
    }
    result = MAP_WORKERD->accept_local_player_epoch(userid,epoch,0);
    if(!(int)result["ok"]){
        send_json(req,result,409);
        return;
    }
    result = MAP_WORKERD->accept_local_player_account_owner(
        userid,epoch,account_owner);
    if(!(int)result["ok"]){
        MAP_WORKERD->clear_local_player_epoch(userid);
        send_json(req,result,409);
        return;
    }
    cache_changed = MAP_WORKERD->accept_local_account_cache_token(
        account_owner,cache_token);
    if(cache_changed<0){
        MAP_WORKERD->clear_local_player_epoch(userid);
        send_json(req,(["ok":0,"code":"invalid_account_cache_token"]),409);
        return;
    }
    if(cache_changed){
        if(functionp(ACCOUNT_STORAGED->invalidate_worker_account_cache))
            ACCOUNT_STORAGED->invalidate_worker_account_cache(account_owner);
        if(functionp(ACCOUNT_WALLETD->invalidate_worker_account_cache))
            ACCOUNT_WALLETD->invalidate_worker_account_cache(account_owner);
        if(functionp(ACCOUNT_CHARACTERD->invalidate_worker_account_cache))
            ACCOUNT_CHARACTERD->invalidate_worker_account_cache(account_owner);
        if(functionp(PETD->invalidate_worker_account_cache))
            PETD->invalidate_worker_account_cache(account_owner);
    }
    result = MAP_WORKERD->install_local_player_arrival(
        userid,epoch,room_path);
    if(!(int)result["ok"]){
        MAP_WORKERD->clear_local_player_epoch(userid);
        send_json(req,result,409);
        return;
    }
    password = get_user_password(userid);
    load_err = catch { master=(object)(ROOT+"/gamelib/master.pike"); };
    if(!load_err && master && functionp(master->connect))
        user_program = master->connect();
    if(!user_program)
        user_program = (program)(ROOT+"/gamelib/clone/user.pike");
    if(password!="" && user_program){
        player = user_program();
        player->set_name(userid);
        player->set_userip("127.0.0.1");
        player->set_project("gamelib");
        set_http_api_login_pending(userid,1);
        setup_err = catch { setup_ok = player->setup(password); };
        clear_http_api_login_pending(userid);
    }
    if(setup_err || !setup_ok || !player){
        discard_map_worker_internal_arrival(userid,player);
        send_json(req,(["ok":0,"code":"player_restore_failed"]),500);
        return;
    }
    player->is_http_api_user = 1;
    set_virtual_connection(userid,({0,time(),player}));
    if(!map_worker_player_account_authorized(player,userid)){
        discard_map_worker_internal_arrival(userid,player);
        send_json(req,(["ok":0,"code":"account_owner_mismatch"]),409);
        return;
    }
    arrival_result = complete_map_worker_arrival(player,userid);
    player = get_player_from_connection(userid,0);
    if(!(int)arrival_result["handled"] || !player || !environment(player) ||
       file_name(environment(player))-ROOT!=room_path ||
       (int)MAP_WORKERD->query_local_player_arrival(userid)["ok"]){
        discard_map_worker_internal_arrival(userid,player);
        send_json(req,(["ok":0,"code":"arrival_materialize_failed"]),500);
        return;
    }
    send_json(req,(["ok":1,"userid":userid,"epoch":epoch,
        "room_path":room_path,
        "affinity":map_worker_player_affinity(player)]));
}

private void handle_map_worker_local_inventory(
    Protocols.HTTP.Server.Request req)
{
    array(mapping(string:mixed)) players = ({});
    foreach(map_worker_local_players(),object player){
        string userid = functionp(player->query_name) ?
            lower_case((string)player->query_name()) : "";
        string affinity = map_worker_player_affinity(player);
        string account_id = functionp(player->query_account_owner) ?
            lower_case((string)player->query_account_owner()) : userid;
        if(userid!=""){
            if(affinity=="")
                affinity = "session:recovery:"+userid;
            players += ({(["userid":userid,"affinity":affinity,
                "account_id":account_id,
                "lease_epoch":MAP_WORKERD->query_local_player_epoch(userid),
                "in_combat":(int)player->in_combat])});
        }
    }
    // local_inventory is called only after local_inflight proved zero while
    // gateway routing is paused. Epoch entries with no living object can then
    // be removed without hiding an in-flight login from reconciliation.
    foreach(MAP_WORKERD->query_local_player_userids(),string userid){
        object player = get_player_from_connection(userid,0);
        if(!player)
            player = find_player(userid);
        if(!player)
            MAP_WORKERD->clear_local_player_epoch(userid);
    }
    send_json(req,(["ok":1,"players":players,
        "worker_id":MAP_WORKERD->query_local_worker_id()]));
}

private array(mapping(string:mixed)) map_worker_local_online_rows(
    array(object)|void supplied_players)
{
    array(mapping(string:mixed)) rows = ({});
    array(object) players = supplied_players || map_worker_local_players();
    foreach(players,object player){
        mapping(string:mixed) row = ([]);
        mixed row_err;
        if(!player || !functionp(player->query_name))
            continue;
        row_err = catch {
            object room = environment(player);
            string userid = lower_case((string)player->query_name());
            row = (["userid":userid,
                "name_cn":(string)player->query_name_cn(),
                "level":(int)player->query_level(),
                "worker_id":MAP_WORKERD->query_local_worker_id(),
                "epoch":MAP_WORKERD->query_local_player_epoch(userid),
                "room_path":room ? file_name(room)-ROOT : "",
                "room_name":room && functionp(room->query_name_cn) ?
                    (string)room->query_name_cn() : "未知",
                "idle":functionp(player->query_idle_label) ?
                    (string)player->query_idle_label() : "",
                "account_id":functionp(player->query_account_owner) ?
                    lower_case((string)player->query_account_owner()) : userid,
            ]);
        };
        if(!row_err && (string)row["userid"]!="" && (int)row["epoch"]>0)
            rows += ({row});
    }
    return rows;
}

private void handle_map_worker_local_status(
    Protocols.HTTP.Server.Request req)
{
    mapping thread_status = query_thread_status();
    mapping runtime_status = query_runtime_performance();
    mapping(string:int) occupied_rooms = ([]);
    array(object) local_players = map_worker_local_players();
    foreach(local_players,object player){
        object room = environment(player);
        if(room)
            occupied_rooms[file_name(room)] = 1;
    }
    send_json(req,([
        "ok":1,
        "worker_id":MAP_WORKERD->query_local_worker_id(),
        "active_players":sizeof(local_players),
        "active_rooms":sizeof(occupied_rooms),
        "pending_commands":(int)thread_status["world_pending_commands"],
        "heartbeat_ms":(int)runtime_status["heartbeat_last_cycle_ms"],
        "control":MAP_WORKERD->query_local_control_status(),
        "online_users":map_worker_local_online_rows(local_players),
    ]));
}

private void discard_map_worker_offline_admin_player(object|zero player)
{
    if(!player)
        return;
    if(functionp(player->discard_stale_worker_copy))
        player->discard_stale_worker_copy();
    else{
        foreach(all_inventory(player),object item)
            if(item)
                destruct(item);
        destruct(player);
    }
}

private mapping execute_map_worker_local_admin_recharge(mapping params)
{
    string manager_userid = lower_case(String.trim_all_whites(
        (string)(params["manager_userid"] || "")));
    string target_userid = lower_case(String.trim_all_whites(
        (string)(params["target_userid"] || "")));
    string account_id = lower_case(String.trim_all_whites(
        (string)(params["account_id"] || "")));
    string worker_id = lower_case(String.trim_all_whites(
        (string)(params["worker_id"] || "")));
    string recharge_request_id = lower_case(String.trim_all_whites(
        (string)(params["recharge_request_id"] || "")));
    string gateway_request_id = lower_case(String.trim_all_whites(
        (string)(params["gateway_request_id"] || "")));
    string capability = lower_case(String.trim_all_whites(
        (string)(params["capability"] || "")));
    int epoch = (int)params["epoch"];
    int fee = (int)params["fee"];
    object|zero player = 0;
    object recharge_command;
    int offline;
    mapping result;
    string expected_capability = map_worker_admin_capability(manager_userid,
        target_userid,account_id,worker_id,epoch,fee,recharge_request_id,
        gateway_request_id);
    if(MAP_WORKERD->query_node_role()!="worker" ||
       worker_id!=MAP_WORKERD->query_local_worker_id() ||
       !MAP_WORKERD->local_control_lease_valid() ||
       MANAGERD->checkpower(manager_userid)!="admin" ||
       sizeof(recharge_request_id)!=64 || sizeof(gateway_request_id)!=64 ||
       capability!=expected_capability ||
       ACCOUNT_CHARACTERD->query_account_id_for_character(target_userid)!=
        account_id){
        return (["ok":0,"code":"admin_recharge_forbidden",
            "message":"分布式充值能力校验失败"]);
    }
    player = get_player_from_connection(target_userid,0);
    if(!player)
        player = find_player(target_userid);
    if(epoch>0){
        int local_epoch = MAP_WORKERD->query_local_player_epoch(target_userid);
        if(player && local_epoch!=epoch){
            return (["ok":0,"code":"stale_admin_target",
                "message":"目标人物已经切换 worker，请重新确认充值"]);
        }
        if(!player && local_epoch!=0 && local_epoch!=epoch){
            return (["ok":0,"code":"stale_admin_target",
                "message":"目标人物离线租约已变化，请重新确认充值"]);
        }
        if(!player)
            offline = 1;
    }
    else{
        if(player || MAP_WORKERD->query_local_player_epoch(target_userid)>0){
            return (["ok":0,"code":"target_became_online",
                "message":"目标人物刚刚上线，请重新确认充值"]);
        }
        offline = 1;
    }
    if(offline){
        player = clone(GAMELIB_USER);
        if(player){
            player->set_name(target_userid);
            player->set_project("gamelib");
            if(!player->restore()){
                destruct(player);
                player = 0;
            }
        }
    }
    if(!player || !functionp(player->query_account_owner) ||
       lower_case((string)player->query_account_owner())!=account_id){
        if(offline)
            discard_map_worker_offline_admin_player(player);
        return (["ok":0,"code":"target_account_mismatch",
            "message":"目标人物账号归属无效"]);
    }
    recharge_command = (object)(ROOT+"/gamelib/cmds/txadd.pike");
    if(!recharge_command ||
       !functionp(recharge_command->execute_admin_recharge_target))
        result = (["ok":0,"message":"充值处理器不可用"]);
    else
        result = recharge_command->execute_admin_recharge_target(player,fee,
            manager_userid,recharge_request_id,1);
    if(offline)
        discard_map_worker_offline_admin_player(player);
    return result;
}

private void handle_map_worker_local_admin_recharge(
    Protocols.HTTP.Server.Request req,mapping params)
{
    mapping result = execute_map_worker_local_admin_recharge(params);
    send_json(req,result,(int)result["ok"] ? 200 :
        (string)result["code"]=="admin_recharge_forbidden" ? 403 : 409);
}

private mapping execute_map_worker_local_account_refresh(string account_id)
{
    account_id = lower_case(String.trim_all_whites(account_id || ""));
    int refreshed;
    int save_failed;
    if(MAP_WORKERD->query_node_role()!="worker" ||
       !MAP_WORKERD->local_control_lease_valid() || account_id=="")
        return (["ok":0,"code":"invalid_account_refresh"]);
    if(functionp(ACCOUNT_STORAGED->invalidate_worker_account_cache))
        ACCOUNT_STORAGED->invalidate_worker_account_cache(account_id);
    if(functionp(ACCOUNT_WALLETD->invalidate_worker_account_cache))
        ACCOUNT_WALLETD->invalidate_worker_account_cache(account_id);
    if(functionp(ACCOUNT_CHARACTERD->invalidate_worker_account_cache))
        ACCOUNT_CHARACTERD->invalidate_worker_account_cache(account_id);
    if(functionp(PETD->invalidate_worker_account_cache))
        PETD->invalidate_worker_account_cache(account_id);
    foreach(map_worker_local_players(),object player){
        if(!player || !functionp(player->query_account_owner) ||
           lower_case((string)player->query_account_owner())!=account_id)
            continue;
        ACCOUNT_WALLETD->reconcile_player_login(player);
        if(!player->save_with_result())
            save_failed++;
        else
            refreshed++;
    }
    return (["ok":save_failed ? 0 : 1,"refreshed":refreshed,
        "save_failed":save_failed]);
}

private void handle_map_worker_local_account_refresh(
    Protocols.HTTP.Server.Request req,mapping params)
{
    mapping result = execute_map_worker_local_account_refresh(
        (string)(params["account_id"] || ""));
    send_json(req,result,(int)result["ok"] ? 200 :
        (string)result["code"]=="invalid_account_refresh" ? 409 : 500);
}

private void handle_map_worker_local_online_users(
    Protocols.HTTP.Server.Request req)
{
    send_json(req,(["ok":1,"worker_id":
        MAP_WORKERD->query_local_worker_id(),"users":
        map_worker_local_online_rows()]));
}

private void handle_map_worker_local_release(
    Protocols.HTTP.Server.Request req,mapping params)
{
    string userid = lower_case(String.trim_all_whites(
        (string)(params["userid"] || "")));
    string expected_affinity = (string)(params["affinity"] || "");
    int expected_epoch = (int)params["epoch"];
    object player = get_player_from_connection(userid,0);
    if(!player)
        player = find_player(userid);
    if(!player){
        // Idempotent retry after a successful release.
        send_json(req,(["ok":1,"released":1,"replayed":1]));
        return;
    }
    if((int)player->in_combat){
        send_json(req,(["ok":0,"code":"player_in_combat"]),409);
        return;
    }
    if(expected_epoch<1 ||
       MAP_WORKERD->query_local_player_epoch(userid)!=expected_epoch){
        send_json(req,(["ok":0,"code":"stale_local_epoch"]),409);
        return;
    }
    string actual_affinity = map_worker_player_affinity(player);
    if(expected_affinity!="" && actual_affinity!=expected_affinity){
        send_json(req,(["ok":0,"code":"affinity_changed",
            "affinity":actual_affinity]),409);
        return;
    }
    if(functionp(player->detach_worker_follow_links))
        player->detach_worker_follow_links();
    if(functionp(player->prepare_worker_summon_handoff) &&
       !player->prepare_worker_summon_handoff()){
        send_json(req,(["ok":0,"code":"summon_handoff_pending"]),409);
        return;
    }
    int saved = 0;
    mixed save_err = catch {
        if(functionp(player->save_with_result))
            // begin_handoff already froze the exact coordinator epoch. This
            // is the one final atomic source save, even if a slow accepted
            // request made the short worker-control heartbeat expire.
            saved = player->save_with_result(0,1);
        else{
            player->save();
            saved = 1;
        }
    };
    if(save_err || !saved){
        if(functionp(player->cancel_worker_summon_handoff))
            player->cancel_worker_summon_handoff();
        send_json(req,(["ok":0,"code":"save_failed"]),500);
        return;
    }
    remove_virtual_connection(userid);
    MAP_WORKERD->clear_local_move_redirect(userid);
    MAP_WORKERD->clear_local_player_epoch(userid);
    if(functionp(player->retire_worker_copy_after_save))
        player->retire_worker_copy_after_save();
    else
        destruct(player);
    send_json(req,(["ok":1,"released":1,"affinity":actual_affinity]));
}

/** Remove a stale split-brain copy without saving any character or item. */
private void handle_map_worker_local_discard(
    Protocols.HTTP.Server.Request req,mapping params)
{
    string userid = lower_case(String.trim_all_whites(
        (string)(params["userid"] || "")));
    int expected_epoch = (int)params["epoch"];
    int actual_epoch = MAP_WORKERD->query_local_player_epoch(userid);
    object player = get_player_from_connection(userid,0);
    if(!player)
        player = find_player(userid);
    if(expected_epoch>0 && actual_epoch!=expected_epoch){
        send_json(req,(["ok":0,"code":"stale_local_epoch",
            "epoch":actual_epoch]),409);
        return;
    }
    remove_virtual_connection(userid);
    MAP_WORKERD->clear_local_move_redirect(userid);
    MAP_WORKERD->clear_local_player_epoch(userid);
    if(player){
        werror("[MAP_WORKER][STALE_DISCARD] userid=%s epoch=%d\n",
            userid,actual_epoch);
        if(functionp(player->discard_stale_worker_copy))
            player->discard_stale_worker_copy();
        else
            destruct(player);
    }
    send_json(req,(["ok":1,"discarded":1,"replayed":!player]));
}

private void handle_map_worker_local_epoch(
    Protocols.HTTP.Server.Request req,mapping params)
{
    string userid = lower_case(String.trim_all_whites(
        (string)(params["userid"] || "")));
    int epoch = (int)params["epoch"];
    object player = get_player_from_connection(userid,0);
    mapping result;
    if(!player)
        player = find_player(userid);
    if(!player){
        send_json(req,(["ok":0,"code":"player_not_local"]),404);
        return;
    }
    result = MAP_WORKERD->accept_local_player_epoch(userid,epoch,0);
    send_json(req,result,(int)result["ok"] ? 200 : 409);
}

private void handle_map_worker_local_redirect_complete(
    Protocols.HTTP.Server.Request req,mapping params)
{
    string userid = lower_case(String.trim_all_whites(
        (string)(params["userid"] || "")));
    string room_path = String.trim_all_whites(
        (string)(params["room_path"] || ""));
    int expected_epoch = (int)params["epoch"];
    object player = get_player_from_connection(userid,0);
    if(!player)
        player = find_player(userid);
    if(!player || expected_epoch<1 ||
       MAP_WORKERD->query_local_player_epoch(userid)!=expected_epoch ||
       !functionp(player->complete_same_worker_static_redirect) ||
       !player->complete_same_worker_static_redirect(room_path)){
        send_json(req,(["ok":0,"code":"local_redirect_failed"]),409);
        return;
    }
    send_json(req,(["ok":1,"userid":userid,"room_path":room_path]));
}

private void handle_map_worker_local_control_resume(
    Protocols.HTTP.Server.Request req)
{
    foreach(map_worker_local_players(),object player){
        string userid = functionp(player->query_name) ?
            lower_case((string)player->query_name()) : "";
        if(userid=="" || MAP_WORKERD->query_local_player_epoch(userid)<1){
            send_json(req,(["ok":0,"code":"unreconciled_local_player"]),409);
            return;
        }
    }
    mapping result = MAP_WORKERD->resume_local_control();
    send_json(req,result,(int)result["ok"] ? 200 : 409);
}

/**
 * A worker fences itself before coordinator heartbeat expiry. It makes one
 * last atomic save, then destroys every local copy; a failed save is never
 * followed by a second write which could overwrite a recovered character.
 */
void enforce_map_worker_control_fence()
{
    call_out(enforce_map_worker_control_fence,2);
    if(MAP_WORKERD->query_node_role()!="worker" ||
       MAP_WORKERD->local_control_lease_valid())
        return;
    int newly_isolated = MAP_WORKERD->mark_local_control_isolated();
    array(object) local_players = map_worker_local_players();
    if(newly_isolated)
        werror("[MAP_WORKER][CONTROL_FENCE] worker=%s players=%d\n",
            MAP_WORKERD->query_local_worker_id(),sizeof(local_players));
    foreach(local_players,object player){
        string userid;
        int saved;
        mixed save_err;
        if(!player || !functionp(player->query_name))
            continue;
        userid = lower_case((string)player->query_name());
        if(MAP_WORKERD->local_user_request_running(userid)){
            werror("[MAP_WORKER][CONTROL_FENCE_DEFER] userid=%s request=running\n",
                userid);
            continue;
        }
        remove_virtual_connection(userid);
        MAP_WORKERD->clear_local_move_redirect(userid);
        save_err = catch {
            if(functionp(player->save_with_result))
                saved = player->save_with_result(0,1);
        };
        MAP_WORKERD->clear_local_player_epoch(userid);
        if(!save_err && saved){
            if(functionp(player->retire_worker_copy_after_save))
                player->retire_worker_copy_after_save();
            else
                destruct(player);
        }
        else{
            werror("[MAP_WORKER][P0_SAVE_FAILED] userid=%s error=%O\n",
                userid,save_err);
            if(functionp(player->discard_stale_worker_copy))
                player->discard_stale_worker_copy();
            else
                destruct(player);
        }
    }
}

void handle_map_worker_rpc(Protocols.HTTP.Server.Request req)
{
    mapping params;
    string action;
    mapping result;
    if(!map_worker_rpc_authorized(req)){
        send_json(req,(["ok":0,"code":"forbidden"]),403);
        return;
    }
    params = get_params(req);
    action = lower_case(String.trim_all_whites(
        (string)(params["action"] || "status")));

    if(action=="local_route"){
        handle_map_worker_local_route(req,params);
        return;
    }
    if(action=="local_resolve_command"){
        handle_map_worker_local_resolve_command(req,params);
        return;
    }
    if(action=="local_status"){
        handle_map_worker_local_status(req);
        return;
    }
    if(action=="local_pending_routes"){
        handle_map_worker_local_pending_routes(req);
        return;
    }
    if(action=="local_live_leases"){
        handle_map_worker_local_live_leases(req,params);
        return;
    }
    if(action=="local_arrival"){
        handle_map_worker_local_arrival(req,params);
        return;
    }
    if(action=="local_inventory"){
        handle_map_worker_local_inventory(req);
        return;
    }
    if(action=="local_release"){
        handle_map_worker_local_release(req,params);
        return;
    }
    if(action=="local_discard"){
        handle_map_worker_local_discard(req,params);
        return;
    }
    if(action=="local_epoch"){
        handle_map_worker_local_epoch(req,params);
        return;
    }
    if(action=="local_control_resume"){
        handle_map_worker_local_control_resume(req);
        return;
    }
    if(action=="local_control_heartbeat"){
        MAP_WORKERD->note_local_control_heartbeat();
        result = MAP_WORKERD->query_local_control_status();
        result["ok"] = (int)result["control_lease_valid"];
        send_json(req,result,(int)result["ok"] ? 200 : 409);
        return;
    }
    if(action=="local_online_snapshot_update"){
        result = MAP_WORKERD->update_local_online_snapshot(
            mappingp(params["snapshot"]) ? (mapping)params["snapshot"] : ([]));
        send_json(req,result,(int)result["ok"] ? 200 : 409);
        return;
    }
    if(action=="local_prepare_shutdown"){
        result = MAP_WORKERD->prepare_local_shutdown_save_fence();
        send_json(req,result,(int)result["ok"] ? 200 : 409);
        return;
    }
    if(action=="local_admin_recharge"){
        handle_map_worker_local_admin_recharge(req,params);
        return;
    }
    if(action=="local_account_refresh"){
        handle_map_worker_local_account_refresh(req,params);
        return;
    }
    if(action=="local_online_users"){
        handle_map_worker_local_online_users(req);
        return;
    }
    if(action=="local_auction_tick"){
        int ticked = functionp(AUCTIOND->run_map_worker_scheduled_task) &&
            AUCTIOND->run_map_worker_scheduled_task();
        send_json(req,(["ok":ticked ? 1 : 0,
            "code":ticked ? "" : "auction_tick_rejected"]),
            ticked ? 200 : 409);
        return;
    }
    if(action=="local_request_status"){
        result = MAP_WORKERD->query_local_gateway_request(
            (string)params["request_id"]);
        send_json(req,result,(int)result["ok"] ? 200 : 404);
        return;
    }
    if(action=="local_inflight"){
        array running = MAP_WORKERD->query_local_running_requests();
        send_json(req,(["ok":1,"running":running,
            "count":sizeof(running)]));
        return;
    }
    if(action=="local_assignments"){
        result = MAP_WORKERD->update_local_assignments(
            mappingp(params["owners"]) ? params["owners"] : ([]),
            (int)params["generation"]);
        send_json(req,result,(int)result["ok"] ? 200 : 409);
        return;
    }
    if(action=="local_assignment"){
        result = MAP_WORKERD->update_local_assignment(
            (string)params["affinity"],(string)params["worker_id"],
            (int)params["generation"]);
        send_json(req,result,(int)result["ok"] ? 200 : 409);
        return;
    }
    if(action=="local_redirect_clear"){
        MAP_WORKERD->clear_local_move_redirect((string)params["userid"]);
        send_json(req,(["ok":1]));
        return;
    }
    if(action=="local_redirect_complete"){
        handle_map_worker_local_redirect_complete(req,params);
        return;
    }
    if(!map_worker_coordinator_role()){
        send_json(req,(["ok":0,"code":"not_coordinator"]),409);
        return;
    }

    switch(action){
        case "gateway_quiesce":
            result = prepare_pike_gateway_shutdown();
            break;
        case "gateway_failover_quiesce":
            result = prepare_pike_gateway_failover_shutdown(
                arrayp(params["failed_workers"]) ?
                    (array)params["failed_workers"] : ({}));
            break;
        case "online_users":
            result = query_pike_gateway_online_users();
            break;
        case "gateway_status":
            result = query_pike_gateway_status();
            break;
        case "status":
            result = MAP_WORKERD->query_status();
            result["ok"] = 1;
            result["gateway"] = query_pike_gateway_status();
            break;
        case "register":
            result = MAP_WORKERD->register_worker(
                (string)params["worker_id"],(string)params["endpoint"],
                (int)params["capacity"],(string)params["incarnation"]);
            break;
        case "heartbeat":
            result = MAP_WORKERD->heartbeat_worker(
                (string)params["worker_id"],(int)params["generation"],
                mappingp(params["metrics"]) ? params["metrics"] : ([]));
            break;
        case "drain":
            result = MAP_WORKERD->set_worker_draining(
                (string)params["worker_id"],(int)params["draining"]);
            break;
        case "assign_catalog":
            result = MAP_WORKERD->assign_catalog((int)params["force"]);
            break;
        case "assign_room":
            result = MAP_WORKERD->assign_room((string)params["room_path"],
                (string)(params["instance_key"] || ""));
            break;
        case "assign_affinity":
            result = MAP_WORKERD->assign_affinity((string)params["affinity"],
                (int)params["weight"],(int)params["force"]);
            break;
        case "route":
            result = MAP_WORKERD->query_player_route((string)params["userid"]);
            break;
        case "resolve_account":
            {
                string requested_user = lower_case(String.trim_all_whites(
                    (string)(params["userid"] || "")));
                string account_id = ACCOUNT_CHARACTERD->
                    query_account_id_for_character(requested_user);
                if(account_id && account_id!="")
                    result = (["ok":1,"userid":requested_user,
                        "account_id":lower_case(account_id)]);
                else
                    result = (["ok":0,"code":"account_not_resolved"]);
            }
            break;
        case "lease_acquire":
            result = MAP_WORKERD->acquire_player_lease(
                (string)params["userid"],(string)params["worker_id"],
                (string)params["affinity"],(int)params["expected_epoch"]);
            break;
        case "lease_renew":
            result = MAP_WORKERD->renew_player_lease(
                (string)params["userid"],(string)params["worker_id"],
                (int)params["epoch"]);
            break;
        case "lease_renew_batch":
            result = MAP_WORKERD->renew_player_leases_batch(
                (string)params["worker_id"],(int)params["generation"],
                arrayp(params["leases"]) ? (array)params["leases"] : ({}));
            break;
        case "lease_rebind":
            result = MAP_WORKERD->rebind_player_lease(
                (string)params["userid"],(string)params["worker_id"],
                (int)params["epoch"],(string)params["affinity"]);
            break;
        case "lease_recover":
            result = MAP_WORKERD->recover_player_lease(
                (string)params["userid"],(string)params["worker_id"],
                (string)params["affinity"]);
            break;
        case "lease_reconcile_begin":
            result = MAP_WORKERD->begin_lease_reconciliation(
                (string)params["reconciliation_id"]);
            break;
        case "lease_reconcile_add":
            result = MAP_WORKERD->add_lease_reconciliation_users(
                (string)params["reconciliation_id"],
                arrayp(params["users"]) ? (array)params["users"] : ({}));
            break;
        case "lease_reconcile_commit":
            result = MAP_WORKERD->commit_lease_reconciliation(
                (string)params["reconciliation_id"]);
            break;
        case "arrival_ack":
            result = MAP_WORKERD->acknowledge_player_arrival(
                (string)params["userid"],(string)params["worker_id"],
                (int)params["epoch"],(string)params["affinity"]);
            break;
        case "handoff_begin":
            result = MAP_WORKERD->begin_handoff(
                (string)params["userid"],(string)params["source_worker"],
                (int)params["source_epoch"],(string)params["target_affinity"],
                (string)params["target_room_path"],
                (string)params["request_id"]);
            break;
        case "handoff_commit":
            result = MAP_WORKERD->commit_handoff(
                (string)params["request_id"],(string)params["target_worker"]);
            break;
        case "handoff_abort":
            result = MAP_WORKERD->abort_handoff(
                (string)params["request_id"],(string)params["source_worker"]);
            break;
        case "envelope_publish":
            result = MAP_WORKERD->publish_envelope(
                (string)params["message_id"],(string)params["kind"],
                (string)(params["source_user"] || ""),
                (string)params["target_user"],
                mappingp(params["payload"]) ? params["payload"] : ([]));
            break;
        case "envelope_poll":
            result = (["ok":1,"messages":MAP_WORKERD->poll_envelopes(
                (string)params["target_user"],(int)params["limit"])]);
            break;
        case "envelope_ack":
            result = MAP_WORKERD->acknowledge_envelope(
                (string)params["message_id"],(string)params["target_user"],
                (int)params["delivery_epoch"]);
            break;
        case "escrow_create":
            result = MAP_WORKERD->create_escrow(
                (string)params["transaction_id"],(string)params["from_user"],
                (string)params["to_user"],mappingp(params["item"]) ?
                params["item"] : ([]));
            break;
        case "escrow_advance":
            result = MAP_WORKERD->advance_escrow(
                (string)params["transaction_id"],(string)params["actor"],
                (string)params["expected_state"],(string)params["next_state"],
                (string)params["proof_digest"]);
            break;
        case "pk_create":
            result = MAP_WORKERD->create_pk_session(
                (string)params["session_id"],(string)params["first_user"],
                (string)params["second_user"]);
            break;
        default:
            result = (["ok":0,"code":"unknown_action"]);
            break;
    }
    send_json(req,result,(int)result["ok"] ? 200 : 409);
}
