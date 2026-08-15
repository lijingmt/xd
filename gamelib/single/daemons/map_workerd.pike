/**
 * Map worker control plane.
 *
 * This daemon never runs world mutations in a Thread.Farm.  It only owns
 * primitive routing metadata: worker heartbeats, affinity placement, player
 * leases, handoff state and idempotent cross-worker envelopes.  A room and
 * every object inside it always remain in one Pike process.
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

constant MAP_WORKER_HEARTBEAT_TTL = 20;
constant MAP_WORKER_PLAYER_LEASE_TTL = 45;
constant MAP_WORKER_HANDOFF_TTL = 60;
constant MAP_WORKER_ENVELOPE_TTL = 86400;
constant MAP_WORKER_MAX_NODES = 32;
constant MAP_WORKER_MAX_NODE_ID = 48;
constant MAP_WORKER_MAX_ENDPOINT = 160;
constant MAP_WORKER_MAX_AFFINITY = 192;
constant MAP_WORKER_MAX_USERID = 64;
constant MAP_WORKER_MAX_PAYLOAD_BYTES = 32768;
constant MAP_WORKER_MAX_ESCROW_BYTES = 4096;
constant MAP_WORKER_MAX_CONTROL_BYTES = 64*1024*1024;
constant MAP_WORKER_MAX_AFFINITIES = 20000;
constant MAP_WORKER_MAX_PLAYER_LEASES = 20000;
constant MAP_WORKER_MAX_HANDOFFS = 4096;
constant MAP_WORKER_MAX_ENVELOPES = 1024;
constant MAP_WORKER_MAX_ESCROWS = 4096;
constant MAP_WORKER_MAX_PK_SESSIONS = 4096;
constant MAP_WORKER_DELIVERY_LEASE_TTL = 30;
constant MAP_WORKER_ESCROW_RESERVATION_TTL = 86400;
constant MAP_WORKER_FINAL_STATE_TTL = 604800;
// The coordinator monitors as many as 16 workers serially. Control RPCs use
// a short timeout, but unavailable siblings must not make a healthy worker
// fence itself before its next heartbeat arrives.
constant MAP_WORKER_LOCAL_CONTROL_TTL = 45;
constant MAP_WORKER_ONLINE_SNAPSHOT_TTL = 30;
constant MAP_WORKER_LOCAL_REQUEST_TTL = 180;
constant MAP_WORKER_MAX_LOCAL_REQUESTS = 65536;
constant MAP_WORKER_MAX_LOCAL_SOCIAL_EVENTS = 4096;
constant MAP_WORKER_LOCAL_SOCIAL_TTL = 300;
constant MAP_WORKER_LOCAL_BROADCAST_TTL = 86400;
// Team membership is structural state, not chat.  Keep its retry envelope
// across ordinary maintenance windows and persist target-by-target ACKs.
constant MAP_WORKER_LOCAL_TEAM_DURABLE_TTL = 604800;
constant MAP_WORKER_MAX_SOCIAL_OUTBOX_BYTES = 64*1024*1024;
constant MAP_WORKER_MAX_HEAT_BYTES = 1024*1024;
constant MAP_WORKER_MAX_HEAT_SCORE = 10000000;
constant MAP_WORKER_HEAT_SCALE = 100;
constant MAP_WORKER_HEAT_EWMA_DENOMINATOR = 60;
constant MAP_WORKER_HEAT_WEIGHT_PER_PLAYER = 25;
constant MAP_WORKER_HEAT_PERSIST_SECONDS = 60;
constant MAP_WORKER_HEAT_SEED_MAX_AGE = 3600;

private Thread.Mutex worker_state_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) worker_nodes = ([]);
private mapping(string:mapping(string:mixed)) affinity_assignments = ([]);
private mapping(string:int) affinity_room_weights = ([]);
private mapping(string:int) affinity_heat_scores = ([]);
private mapping(string:string) illusion_s1_room_groups = ([
	"moon_gate":"hub",
	"silver_path":"silver","fog_forest":"silver",
	"mirror_lake":"silver",
	"broken_observatory":"ruins","echo_ruins":"ruins",
	"star_bridge":"ruins",
	"abyss_garden":"depths","moon_palace":"depths",
	"newmoon_altar":"depths","hidden_crater":"depths",
]);
private multiset(string) catalog_rebalance_pending = (<>);
private int placement_generation;
private int placement_topology_worker_count;
private int affinity_heat_generation;
private int affinity_heat_last_observed_at;
private int affinity_heat_last_persisted_at;
private int affinity_heat_dirty;
private int affinity_heat_persist_scheduled;
private int affinity_heat_restored_from_backup;

private Thread.Mutex player_lease_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) player_leases = ([]);
private mapping(string:mapping(string:mixed)) handoffs = ([]);
private string lease_reconciliation_id = "";
private multiset(string) lease_reconciliation_live_users = (<>);
private int lease_reconciliation_expires_at;

private Thread.Mutex envelope_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) envelopes = ([]);
private mapping(string:mapping(string:mixed)) escrow_transactions = ([]);
private mapping(string:mapping(string:mixed)) pk_sessions = ([]);

// Worker-local routing cache. It contains no world objects and is replaced
// atomically by the loopback gateway when coordinator placement changes.
private Thread.Mutex local_route_lock = Thread.Mutex();
private mapping(string:string) local_affinity_owners = ([]);
private mapping(string:mapping(string:mixed)) pending_player_moves = ([]);
private mapping(string:int) local_player_epochs = ([]);
private mapping(string:string) local_player_account_owners = ([]);
private int local_shutdown_save_fence_expires_at;
private mapping(string:mapping(string:mixed)) local_player_arrivals = ([]);
private mapping(string:string) local_account_cache_tokens = ([]);
private mapping(string:mapping(string:mixed)) local_requests = ([]);
private mapping(string:string) local_running_request_by_user = ([]);
private mapping(string:string) local_running_request_by_account = ([]);
private mapping(string:mixed) local_online_snapshot = ([]);
private int local_online_snapshot_at;
private int local_assignment_generation;
private int local_control_seen_at;
private int local_control_isolated;
private int local_save_fence_block_total;
private mapping(string:int) local_save_fence_blocks = ([]);
private Thread.Mutex local_social_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) local_social_events = ([]);
private array(string) local_social_event_order = ({});
private mapping(string:int) local_social_delivered = ([]);
private mapping(string:int) local_social_completed = ([]);
private multiset(string) local_social_durable_deliveries = (<>);
private int local_social_sequence;

private string node_role = "standalone";
private string local_worker_id = "standalone";
private string local_process_incarnation = "";
private Thread.Mutex control_persist_lock = Thread.Mutex();
private int control_persist_scheduled;
private int control_last_persisted_at;
private string control_last_persist_error = "";
private int control_persist_attempts;
private int control_persist_failures;
private int control_persist_total_ms;
private int control_persist_max_ms;
private int control_persist_last_ms;
private int control_persist_last_bytes;
private int control_restore_discarded;
private int control_restored_from_backup;
private Thread.Mutex cluster_config_lock = Thread.Mutex();
private mapping(string:mixed) cluster_config = ([
	"schema_version":2,
	"enabled":0,
	"traffic_mode":"shadow",
	"worker_count":3,
	"worker_capacity":100,
	"placement":"load_aware_rendezvous",
	"coordinator_http_port":18880,
	"worker_http_base_port":18881,
	"worker_mud_base_port":14801,
	"gateway_port":8888,
]);

private string cluster_config_path()
{
	return DATA_ROOT+"map_workers/config.json";
}

private int valid_cluster_config(mapping config)
{
	array(int) ports = ({});
	multiset(int) seen_ports = (<>);
	int worker_count;
	if(!mappingp(config) || (int)config["schema_version"]!=2)
		return 0;
	worker_count = (int)config["worker_count"];
	if(!(
		((int)config["enabled"]==0 || (int)config["enabled"]==1) &&
		has_value(({"shadow","active"}),(string)config["traffic_mode"]) &&
		worker_count>=1 && worker_count<=16 &&
		(int)config["worker_capacity"]>=10 &&
		(int)config["worker_capacity"]<=10000 &&
		(string)config["placement"]=="load_aware_rendezvous" &&
		(int)config["coordinator_http_port"]>=1024 &&
		(int)config["coordinator_http_port"]<=65535 &&
		(int)config["worker_http_base_port"]>=1024 &&
		(int)config["worker_http_base_port"]+15<=65535 &&
		(int)config["worker_mud_base_port"]>=1024 &&
		(int)config["worker_mud_base_port"]+15<=65535 &&
		(int)config["gateway_port"]>=1024 &&
		(int)config["gateway_port"]<=65535 &&
		(int)config["worker_mud_base_port"]-1>=1024))
		return 0;
	ports = ({(int)config["coordinator_http_port"],
		(int)config["worker_mud_base_port"]-1,
		(int)config["gateway_port"]});
	for(int index=0;index<worker_count;index++){
		ports += ({(int)config["worker_http_base_port"]+index,
			(int)config["worker_mud_base_port"]+index});
	}
	foreach(ports,int port){
		if(seen_ports[port])
			return 0;
		seen_ports[port] = 1;
	}
	return 1;
}

private void load_cluster_config()
{
	string path = cluster_config_path();
	string source;
	mapping decoded;
	mixed err;
	if(Stdio.file_size(path)<=0 || Stdio.file_size(path)>65536)
		return;
	source = Stdio.read_file(path);
	err = catch { decoded = Standards.JSON.decode(source); };
	if(!err && mappingp(decoded) && (int)decoded["schema_version"]==1){
		decoded["schema_version"] = 2;
		decoded["traffic_mode"] = "shadow";
	}
	if(!err && valid_cluster_config(decoded))
	{
		object key = cluster_config_lock->lock();
		cluster_config = copy_value(decoded);
		destruct(key);
	}
	else
		werror("[MAP_WORKERD] ignored invalid map worker config\n");
}

private int save_cluster_config(mapping candidate)
{
	object key;
	string path = cluster_config_path();
	// Every Pike process has its own mutex.  Use a node-specific staging file
	// as well so two administrators on different workers cannot truncate the
	// same temporary generation before atomic rename.
	string temp_path = path+"."+local_worker_id+".tmp";
	string backup_path = path+".bak";
	string encoded;
	int ok;
	mixed err;
	if(!valid_cluster_config(candidate))
		return 0;
	key = cluster_config_lock->lock();
	err = catch {
		encoded = Standards.JSON.encode(candidate);
		mkdir(DATA_ROOT+"map_workers");
		rm(temp_path);
		if(Stdio.write_file(temp_path,encoded)==sizeof(encoded) &&
		   Stdio.file_size(temp_path)>0){
			if(Stdio.file_size(path)>0)
				Stdio.cp(path,backup_path);
			if(mv(temp_path,path))
				ok = 1;
		}
	};
	if(err || !ok){
		rm(temp_path);
		destruct(key);
		return 0;
	}
	cluster_config = copy_value(candidate);
	destruct(key);
	return 1;
}

mapping(string:mixed) query_cluster_config()
{
	object key = cluster_config_lock->lock();
	mapping result = copy_value(cluster_config);
	destruct(key);
	return result;
}

mapping(string:mixed) admin_set_cluster_config(string operator,
	int enabled,int worker_count,int worker_capacity,void|string traffic_mode)
{
	mapping candidate;
	string now;
	if(!operator || MANAGERD->checkpower(operator)!="admin")
		return (["ok":0,"message":"需要管理员权限。"]);
	candidate = query_cluster_config();
	candidate["enabled"] = enabled ? 1 : 0;
	candidate["worker_count"] = worker_count;
	candidate["worker_capacity"] = worker_capacity;
	if(traffic_mode && traffic_mode!="")
		candidate["traffic_mode"] = lower_case(traffic_mode);
	if(!valid_cluster_config(candidate))
		return (["ok":0,"message":"worker 数量、容量或端口配置无效。"]);
	if(!save_cluster_config(candidate))
		return (["ok":0,"message":"配置原子写入失败，旧配置保持不变。"]);
	now = ctime(time());
	Stdio.append_file(ROOT+"/log/map_worker_admin.log",
		now[0..sizeof(now)-2]+" admin="+operator+
		" enabled="+(string)candidate["enabled"]+
		" workers="+(string)candidate["worker_count"]+
		" capacity="+(string)candidate["worker_capacity"]+
		" traffic_mode="+(string)candidate["traffic_mode"]+"\n");
	return (["ok":1,
		"message":"配置已保存；试运行编排器下次 apply 时生效。",
		"config":copy_value(candidate)]);
}

private string control_state_path()
{
	return DATA_ROOT+"map_workers/control_plane.json";
}

/** Validate every persisted primitive before it can affect routing. */
mapping(string:mixed) validate_control_plane_snapshot(mapping decoded)
{
	mapping(string:mapping(string:mixed)) placements = ([]);
	mapping(string:mapping(string:mixed)) leases = ([]);
	mapping(string:mapping(string:mixed)) restored_handoffs = ([]);
	mapping(string:mapping(string:mixed)) restored_envelopes = ([]);
	mapping(string:mapping(string:mixed)) restored_escrows = ([]);
	mapping(string:mapping(string:mixed)) restored_pk = ([]);
	multiset(string) active_escrow_item_ids = (<>);
	int discarded;
	int snapshot_version = mappingp(decoded) ? (int)decoded["version"] : 0;
	if(!mappingp(decoded) ||
	   !has_value(({1,2,3}),snapshot_version))
		return (["ok":0,"code":"invalid_snapshot"]);
	// Version 2 snapshots carry exact collection counts. A syntactically valid
	// but truncated JSON object must never silently erase leases or equipment
	// escrow state; reject the whole generation and let restore use .bak.
	if(snapshot_version>=2){
		mapping counts = mappingp(decoded["counts"]) ? decoded["counts"] : ([]);
		array(string) state_fields = ({"affinity_assignments","player_leases",
			"handoffs","envelopes","escrow_transactions","pk_sessions"});
		foreach(state_fields,string field)
			if(!mappingp(decoded[field]) || !intp(counts[field]) ||
			   (int)counts[field]!=sizeof((mapping)decoded[field]))
				return (["ok":0,"code":"incomplete_snapshot"]);
	}
	if(snapshot_version==3 &&
	   ((int)decoded["placement_topology_worker_count"]<1 ||
	    (int)decoded["placement_topology_worker_count"]>MAP_WORKER_MAX_NODES))
		return (["ok":0,"code":"invalid_snapshot_topology"]);

	if(mappingp(decoded["affinity_assignments"]))
		foreach(indices(decoded["affinity_assignments"]),mixed raw_key){
			mixed raw = decoded["affinity_assignments"][raw_key];
			string affinity = stringp(raw_key) ?
				normalize_token((string)raw_key,MAP_WORKER_MAX_AFFINITY) : "";
			if(sizeof(placements)>=MAP_WORKER_MAX_AFFINITIES)
				break;
			if(affinity=="" || affinity!=(string)raw_key || !mappingp(raw) ||
			   normalize_worker_id((string)raw["worker_id"])=="" ||
			   (int)raw["epoch"]<1 || (int)raw["weight"]<1 ||
			   (int)raw["weight"]>1000000){
				discarded++;
				continue;
			}
			placements[affinity] = ([
				"affinity":affinity,
				"worker_id":normalize_worker_id((string)raw["worker_id"]),
				"epoch":(int)raw["epoch"],"weight":(int)raw["weight"],
				"assigned_at":max(0,(int)raw["assigned_at"]),
			]);
		}

	if(mappingp(decoded["player_leases"]))
		foreach(indices(decoded["player_leases"]),mixed raw_key){
			mixed raw = decoded["player_leases"][raw_key];
			string userid = stringp(raw_key) ?
				normalize_userid((string)raw_key) : "";
			if(sizeof(leases)>=MAP_WORKER_MAX_PLAYER_LEASES)
				break;
			if(userid=="" || userid!=(string)raw_key || !mappingp(raw) ||
			   normalize_worker_id((string)raw["worker_id"])=="" ||
			   normalize_token((string)raw["affinity"],
				MAP_WORKER_MAX_AFFINITY)=="" || (int)raw["epoch"]<1 ||
			   !has_value(({"active","frozen"}),(string)raw["state"]) ||
			   (int)raw["expires_at"]<1){
				discarded++;
				continue;
			}
			mapping restored_lease = ([
				"userid":userid,
				"worker_id":normalize_worker_id((string)raw["worker_id"]),
				"affinity":normalize_token((string)raw["affinity"],
					MAP_WORKER_MAX_AFFINITY),
				"epoch":(int)raw["epoch"],"state":(string)raw["state"],
				"expires_at":(int)raw["expires_at"],
				"updated_at":max(0,(int)raw["updated_at"]),
			]);
			if(stringp(raw["arrival_room_path"]) &&
			   (string)raw["arrival_room_path"]!=""){
				string arrival_room = normalize_room_location(
					(string)raw["arrival_room_path"]);
				if(arrival_room!="" &&
				   (int)raw["arrival_epoch"]==(int)raw["epoch"] &&
				   room_matches_affinity(arrival_room,
					(string)restored_lease["affinity"])){
					restored_lease["arrival_room_path"] = arrival_room;
					restored_lease["arrival_epoch"] = (int)raw["arrival_epoch"];
				}
				else
					discarded++;
			}
			leases[userid] = restored_lease;
		}

	if(mappingp(decoded["handoffs"]))
		foreach(indices(decoded["handoffs"]),mixed raw_key){
			mixed raw = decoded["handoffs"][raw_key];
			string request_id = stringp(raw_key) ?
				normalize_token((string)raw_key,96) : "";
			string userid = mappingp(raw) ?
				normalize_userid((string)raw["userid"]) : "";
			string source_worker = mappingp(raw) ?
				normalize_worker_id((string)raw["source_worker"]) : "";
			string target_worker = mappingp(raw) ?
				normalize_worker_id((string)raw["target_worker"]) : "";
			if(sizeof(restored_handoffs)>=MAP_WORKER_MAX_HANDOFFS)
				break;
			if(request_id=="" || request_id!=(string)raw_key || userid=="" ||
			   source_worker=="" || target_worker=="" ||
			   source_worker==target_worker ||
			   normalize_token((string)raw["target_affinity"],
				MAP_WORKER_MAX_AFFINITY)=="" ||
			   normalize_room_location((string)raw["target_room_path"])=="" ||
			   !room_matches_affinity((string)raw["target_room_path"],
				(string)raw["target_affinity"]) ||
			   (int)raw["source_epoch"]<1 ||
			   (int)raw["target_epoch"]!=(int)raw["source_epoch"]+1 ||
			   !has_value(({"prepared","committed","aborted","expired"}),
				(string)raw["state"])){
				discarded++;
				continue;
			}
			restored_handoffs[request_id] = ([
				"request_id":request_id,"userid":userid,
				"source_worker":source_worker,"target_worker":target_worker,
				"source_epoch":(int)raw["source_epoch"],
				"target_epoch":(int)raw["target_epoch"],
				"target_affinity":normalize_token(
					(string)raw["target_affinity"],MAP_WORKER_MAX_AFFINITY),
				"target_room_path":normalize_room_location(
					(string)raw["target_room_path"]),
				"state":(string)raw["state"],
				"created_at":max(0,(int)raw["created_at"]),
				"expires_at":max(0,(int)raw["expires_at"]),
				"committed_at":max(0,(int)raw["committed_at"]),
				"aborted_at":max(0,(int)raw["aborted_at"]),
			]);
		}

	if(mappingp(decoded["envelopes"]))
		foreach(indices(decoded["envelopes"]),mixed raw_key){
			mixed raw = decoded["envelopes"][raw_key];
			string message_id = stringp(raw_key) ?
				normalize_token((string)raw_key,96) : "";
			if(sizeof(restored_envelopes)>=MAP_WORKER_MAX_ENVELOPES)
				break;
			if(message_id=="" || message_id!=(string)raw_key || !mappingp(raw) ||
			   normalize_token((string)raw["kind"],48)=="" ||
			   normalize_userid((string)raw["target_user"])=="" ||
			   !valid_payload(mappingp(raw["payload"]) ? raw["payload"] : ([])) ||
			   !has_value(({"pending","delivering","acked"}),
				(string)raw["state"]) || (int)raw["expires_at"]<1){
				discarded++;
				continue;
			}
			restored_envelopes[message_id] = copy_value(raw);
		}

	if(mappingp(decoded["escrow_transactions"]))
		foreach(indices(decoded["escrow_transactions"]),mixed raw_key){
			mixed raw = decoded["escrow_transactions"][raw_key];
			string transaction_id = stringp(raw_key) ?
				normalize_token((string)raw_key,96) : "";
			string escrow_item_id = mappingp(raw) && mappingp(raw["item"]) ?
				(string)raw["item"]["item_id"] : "";
			if(sizeof(restored_escrows)>=MAP_WORKER_MAX_ESCROWS)
				break;
			if(transaction_id=="" || transaction_id!=(string)raw_key ||
			   !mappingp(raw) || normalize_userid((string)raw["from_user"])=="" ||
			   normalize_userid((string)raw["to_user"])=="" ||
			   (string)raw["from_user"]==(string)raw["to_user"] ||
			   !valid_escrow_item_descriptor(mappingp(raw["item"]) ?
				raw["item"] : ([])) ||
			   !has_value(({"reserved","funded","delivered","cancelled"}),
				(string)raw["state"]) ||
			   (has_value(({"reserved","funded"}),(string)raw["state"]) &&
			    active_escrow_item_ids[escrow_item_id])){
				discarded++;
				continue;
			}
			restored_escrows[transaction_id] = copy_value(raw);
			if(has_value(({"reserved","funded"}),(string)raw["state"]))
				active_escrow_item_ids[escrow_item_id] = 1;
		}

	if(mappingp(decoded["pk_sessions"]))
		foreach(indices(decoded["pk_sessions"]),mixed raw_key){
			mixed raw = decoded["pk_sessions"][raw_key];
			string session_id = stringp(raw_key) ?
				normalize_token((string)raw_key,96) : "";
			if(sizeof(restored_pk)>=MAP_WORKER_MAX_PK_SESSIONS)
				break;
			if(session_id=="" || session_id!=(string)raw_key || !mappingp(raw) ||
			   normalize_userid((string)raw["first_user"])=="" ||
			   normalize_userid((string)raw["second_user"])=="" ||
			   (string)raw["first_user"]==(string)raw["second_user"] ||
			   normalize_worker_id((string)raw["worker_id"])=="" ||
			   !has_prefix((string)raw["affinity"],"pk:") ||
			   (string)raw["state"]!="gathering"){
				discarded++;
				continue;
			}
			restored_pk[session_id] = copy_value(raw);
		}

	// A restored prepared/committed handoff is authoritative only when its
	// player lease proves the exact same owner, affinity and epoch. This also
	// removes old committed history after a later migration advanced epoch.
	multiset(string) prepared_users = (<>);
	foreach(indices(restored_handoffs),string request_id){
		mapping handoff = restored_handoffs[request_id];
		mapping lease = leases[(string)handoff["userid"]];
		int consistent = 1;
		if((string)handoff["state"]=="prepared"){
			consistent = mappingp(lease) &&
				(string)lease["state"]=="frozen" &&
				(string)lease["worker_id"]==(string)handoff["source_worker"] &&
				(int)lease["epoch"]==(int)handoff["source_epoch"] &&
				!prepared_users[(string)handoff["userid"]];
			if(consistent)
				prepared_users[(string)handoff["userid"]] = 1;
		}
		else if((string)handoff["state"]=="committed")
			consistent = mappingp(lease) &&
				(string)lease["state"]=="active" &&
				(string)lease["worker_id"]==(string)handoff["target_worker"] &&
				(string)lease["affinity"]==(string)handoff["target_affinity"] &&
				(int)lease["epoch"]==(int)handoff["target_epoch"];
		if(!consistent){
			m_delete(restored_handoffs,request_id);
			discarded++;
		}
	}

	// A frozen lease without its exact prepared handoff would never thaw.
	foreach(indices(leases),string userid){
		mapping lease = leases[userid];
		if((string)lease["state"]!="frozen")
			continue;
		int matched;
		foreach(values(restored_handoffs),mapping handoff)
			if((string)handoff["state"]=="prepared" &&
			   (string)handoff["userid"]==userid &&
			   (string)handoff["source_worker"]==(string)lease["worker_id"] &&
			   (int)handoff["source_epoch"]==(int)lease["epoch"]){
				matched = 1;
				break;
			}
		if(!matched){
			m_delete(leases,userid);
			discarded++;
		}
	}
	if(snapshot_version>=2 && discarded)
		return (["ok":0,"code":"corrupt_snapshot",
			"discarded":discarded]);
	int restored_topology_count =
		(int)decoded["placement_topology_worker_count"];
	if(snapshot_version<3){
		multiset(string) catalog_owners = (<>);
		foreach(indices(placements),string affinity)
			if(affinity_room_weights[affinity])
				catalog_owners[(string)placements[affinity]["worker_id"]] = 1;
		restored_topology_count = sizeof(catalog_owners);
	}
	return (["ok":1,"discarded":discarded,
		"snapshot":(["affinity_assignments":placements,
			"placement_topology_worker_count":restored_topology_count,
			"player_leases":leases,"handoffs":restored_handoffs,
			"envelopes":restored_envelopes,
			"escrow_transactions":restored_escrows,
			"pk_sessions":restored_pk])]);
}

private void restore_control_plane()
{
	string source;
	mapping decoded;
	mapping validated;
	mapping snapshot;
	mixed err;
	string path = control_state_path();
	string selected_path = "";
	int found_candidate;
	if(node_role!="gateway")
		return;
	foreach(({path,path+".bak"}),string candidate){
		int file_size = Stdio.file_size(candidate);
		if(file_size<=0)
			continue;
		found_candidate = 1;
		if(file_size>MAP_WORKER_MAX_CONTROL_BYTES)
			continue;
		source = Stdio.read_file(candidate);
		decoded = 0;
		err = catch { decoded = Standards.JSON.decode(source); };
		if(err || !mappingp(decoded))
			continue;
		validated = validate_control_plane_snapshot(decoded);
		if((int)validated["ok"]){
			selected_path = candidate;
			break;
		}
	}
	if(selected_path==""){
		if(found_candidate)
			control_last_persist_error = "invalid persisted control plane";
		return;
	}
	if(selected_path!=path){
		control_restored_from_backup = 1;
		werror("[MAP_WORKERD] restored control plane from backup\n");
	}
	if(!(int)validated["ok"]){
		control_last_persist_error = "invalid persisted control plane";
		return;
	}
	snapshot = validated["snapshot"];
	affinity_assignments = snapshot["affinity_assignments"];
	placement_topology_worker_count =
		(int)snapshot["placement_topology_worker_count"];
	player_leases = snapshot["player_leases"];
	handoffs = snapshot["handoffs"];
	envelopes = snapshot["envelopes"];
	escrow_transactions = snapshot["escrow_transactions"];
	pk_sessions = snapshot["pk_sessions"];
	control_restore_discarded = (int)validated["discarded"];
	placement_generation = max(0,(int)decoded["placement_generation"]);
	control_last_persisted_at = (int)decoded["saved_at"];
	if(control_restored_from_backup)
		schedule_control_persist();
}

private int persist_control_plane()
{
	object persist_key = control_persist_lock->lock();
	mapping snapshot;
	string encoded = "";
	string path;
	string temp_path;
	string backup_path;
	string backup_temp_path;
	mixed err;
	int ok;
	int live_size;
	int backup_size;
	int started_at;
	int elapsed_ms;
	control_persist_scheduled = 0;
	if(node_role!="gateway"){
		destruct(persist_key);
		return 1;
	}
	control_persist_attempts++;
	started_at = gethrtime();
	{
		object worker_key = worker_state_lock->lock();
		snapshot = ([
			"version":3,
			"saved_at":time(),
			"placement_generation":placement_generation,
			"placement_topology_worker_count":
				placement_topology_worker_count,
			"affinity_assignments":copy_value(affinity_assignments),
		]);
		destruct(worker_key);
	}
	{
		object lease_key = player_lease_lock->lock();
		snapshot["player_leases"] = copy_value(player_leases);
		snapshot["handoffs"] = copy_value(handoffs);
		destruct(lease_key);
	}
	{
		object message_key = envelope_lock->lock();
		snapshot["envelopes"] = copy_value(envelopes);
		snapshot["escrow_transactions"] = copy_value(escrow_transactions);
		snapshot["pk_sessions"] = copy_value(pk_sessions);
		destruct(message_key);
	}
	snapshot["counts"] = ([
		"affinity_assignments":sizeof((mapping)snapshot["affinity_assignments"]),
		"player_leases":sizeof((mapping)snapshot["player_leases"]),
		"handoffs":sizeof((mapping)snapshot["handoffs"]),
		"envelopes":sizeof((mapping)snapshot["envelopes"]),
		"escrow_transactions":sizeof((mapping)snapshot["escrow_transactions"]),
		"pk_sessions":sizeof((mapping)snapshot["pk_sessions"]),
	]);
	path = control_state_path();
	temp_path = path+".tmp";
	backup_path = path+".bak";
	backup_temp_path = path+".bak.tmp";
	err = catch {
		encoded = Standards.JSON.encode(snapshot);
		control_persist_last_bytes = sizeof(encoded);
		if(sizeof(encoded)>MAP_WORKER_MAX_CONTROL_BYTES)
			error("control plane exceeds durable size budget\n");
		mkdir(DATA_ROOT+"map_workers");
		rm(temp_path);
		rm(backup_temp_path);
		if(Stdio.write_file(temp_path,encoded)==sizeof(encoded) &&
		   Stdio.file_size(temp_path)>0){
			live_size = Stdio.file_size(path);
			if(live_size>0 && !control_restored_from_backup){
				Stdio.cp(path,backup_temp_path);
				backup_size = Stdio.file_size(backup_temp_path);
				if(backup_size==live_size &&
				   mv(backup_temp_path,backup_path) &&
				   mv(temp_path,path) && Stdio.file_size(path)>0)
					ok = 1;
			}
			else if(mv(temp_path,path) && Stdio.file_size(path)>0)
				ok = 1;
		}
	};
	elapsed_ms = max(0,(gethrtime()-started_at)/1000);
	control_persist_last_ms = elapsed_ms;
	control_persist_total_ms += elapsed_ms;
	if(elapsed_ms>control_persist_max_ms)
		control_persist_max_ms = elapsed_ms;
	if(err || !ok){
		rm(temp_path);
		rm(backup_temp_path);
		control_last_persist_error = "control plane persistence failed";
		control_persist_failures++;
		werror("[MAP_WORKERD] control plane persistence failed\n");
		destruct(persist_key);
		return 0;
	}
	control_last_persisted_at = time();
	control_last_persist_error = "";
	control_restored_from_backup = 0;
	destruct(persist_key);
	return 1;
}

private void schedule_control_persist()
{
	int schedule;
	object key;
	if(node_role!="gateway")
		return;
	key = control_persist_lock->lock();
	if(!control_persist_scheduled){
		control_persist_scheduled = 1;
		schedule = 1;
	}
	destruct(key);
	if(schedule)
		call_out(persist_control_plane,1);
}

private string normalize_token(string value,int max_length)
{
	string result = lower_case(String.trim_all_whites(value || ""));
	if(result=="" || sizeof(result)>max_length || search(result,"..")!=-1)
		return "";
	foreach(result;int index;int one){
		if((one>='a' && one<='z') || (one>='0' && one<='9') ||
		   one=='_' || one=='-' || one==':' || one=='.' || one=='/')
			continue;
		return "";
	}
	return result;
}

private string normalize_userid(string userid)
{
	string result = String.trim_all_whites(userid || "");
	if(result=="" || sizeof(result)>MAP_WORKER_MAX_USERID ||
	   search(result,"..")!=-1)
		return "";
	foreach(result;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='_' || one=='-' ||
		   one==':' || one=='.' || one=='/')
			continue;
		return "";
	}
	return result;
}

private string normalize_worker_id(string worker_id)
{
	return normalize_token(worker_id,MAP_WORKER_MAX_NODE_ID);
}

private string affinity_heat_path()
{
	return DATA_ROOT+"map_workers/affinity_heat.json";
}

/** Heat is heuristic only: malformed generations are ignored as a whole. */
mapping(string:mixed) validate_affinity_heat_snapshot(mapping decoded)
{
	mapping(string:int) scores = ([]);
	if(!mappingp(decoded) || (int)decoded["version"]!=1 ||
	   !mappingp(decoded["scores"]) ||
	   sizeof((mapping)decoded["scores"])>MAP_WORKER_MAX_AFFINITIES ||
	   (int)decoded["generation"]<0 || (int)decoded["saved_at"]<1 ||
	   (int)decoded["saved_at"]>time()+300)
		return (["ok":0,"code":"invalid_affinity_heat"]);
	foreach(indices((mapping)decoded["scores"]),mixed raw_affinity){
		string affinity;
		mixed raw_score;
		if(!stringp(raw_affinity))
			return (["ok":0,"code":"invalid_affinity_heat_key"]);
		affinity = normalize_token((string)raw_affinity,
			MAP_WORKER_MAX_AFFINITY);
		raw_score = decoded["scores"][raw_affinity];
		if(affinity=="" || affinity!=(string)raw_affinity ||
		   !affinity_room_weights[affinity] || !intp(raw_score) ||
		   (int)raw_score<0 || (int)raw_score>MAP_WORKER_MAX_HEAT_SCORE)
			return (["ok":0,"code":"invalid_affinity_heat_entry"]);
		if((int)raw_score>0)
			scores[affinity] = (int)raw_score;
	}
	return (["ok":1,"scores":scores,
		"generation":(int)decoded["generation"],
		"observed_at":max(0,(int)decoded["observed_at"]),
		"saved_at":(int)decoded["saved_at"]]);
}

private void restore_affinity_heat()
{
	string path = affinity_heat_path();
	string selected = "";
	mapping validated = ([]);
	foreach(({path,path+".bak"}),string candidate){
		int file_size = Stdio.file_size(candidate);
		string source;
		mapping decoded;
		mixed err;
		if(file_size<=0 || file_size>MAP_WORKER_MAX_HEAT_BYTES)
			continue;
		source = Stdio.read_file(candidate);
		err = catch { decoded = Standards.JSON.decode(source); };
		if(err || !mappingp(decoded))
			continue;
		validated = validate_affinity_heat_snapshot(decoded);
		if((int)validated["ok"]){
			selected = candidate;
			break;
		}
	}
	if(selected=="")
		return;
	{
		object key = worker_state_lock->lock();
		affinity_heat_scores = copy_value((mapping)validated["scores"]);
		affinity_heat_generation = (int)validated["generation"];
		affinity_heat_last_observed_at = (int)validated["observed_at"];
		affinity_heat_last_persisted_at = (int)validated["saved_at"];
		affinity_heat_restored_from_backup = selected!=path;
		destruct(key);
	}
	if(selected!=path)
		werror("[MAP_WORKERD] restored affinity heat from backup\n");
	if(selected!=path){
		object key = worker_state_lock->lock();
		affinity_heat_dirty = 1;
		destruct(key);
		schedule_affinity_heat_persist();
	}
}

private int persist_affinity_heat()
{
	string path = affinity_heat_path();
	string temp_path = path+".tmp";
	string backup_path = path+".bak";
	string backup_temp_path = path+".bak.tmp";
	string encoded;
	mapping snapshot;
	int saved_generation;
	int restored_from_backup;
	int live_size;
	int backup_size;
	int ok;
	int reschedule;
	mixed err;
	{
		object key = worker_state_lock->lock();
		affinity_heat_persist_scheduled = 0;
		if(!affinity_heat_dirty){
			destruct(key);
			return 1;
		}
		saved_generation = affinity_heat_generation;
		restored_from_backup = affinity_heat_restored_from_backup;
		snapshot = (["version":1,"saved_at":time(),
			"observed_at":affinity_heat_last_observed_at,
			"generation":saved_generation,
			"scores":copy_value(affinity_heat_scores)]);
		destruct(key);
	}
	err = catch {
		encoded = Standards.JSON.encode(snapshot);
		if(sizeof(encoded)>MAP_WORKER_MAX_HEAT_BYTES)
			error("affinity heat exceeds durable size budget\n");
		mkdir(DATA_ROOT+"map_workers");
		rm(temp_path);
		rm(backup_temp_path);
		if(Stdio.write_file(temp_path,encoded)==sizeof(encoded) &&
		   Stdio.file_size(temp_path)==sizeof(encoded)){
			live_size = Stdio.file_size(path);
			if(live_size>0 && !restored_from_backup){
				Stdio.cp(path,backup_temp_path);
				backup_size = Stdio.file_size(backup_temp_path);
				if(backup_size==live_size &&
				   mv(backup_temp_path,backup_path) &&
				   mv(temp_path,path) &&
				   Stdio.file_size(path)==sizeof(encoded))
					ok = 1;
			}
			else if(mv(temp_path,path) &&
			   Stdio.file_size(path)==sizeof(encoded))
				ok = 1;
		}
	};
	if(!ok){
		rm(temp_path);
		rm(backup_temp_path);
		werror("[MAP_WORKERD] affinity heat persistence failed\n");
	}
	{
		object key = worker_state_lock->lock();
		if(ok){
			affinity_heat_last_persisted_at = time();
			affinity_heat_restored_from_backup = 0;
			if(affinity_heat_generation==saved_generation)
				affinity_heat_dirty = 0;
		}
		reschedule = affinity_heat_dirty;
		destruct(key);
	}
	if(reschedule)
		schedule_affinity_heat_persist();
	return ok && !err;
}

private void schedule_affinity_heat_persist()
{
	int schedule;
	object key;
	if(node_role!="gateway")
		return;
	key = worker_state_lock->lock();
	if(affinity_heat_dirty && !affinity_heat_persist_scheduled){
		affinity_heat_persist_scheduled = 1;
		schedule = 1;
	}
	destruct(key);
	if(schedule)
		call_out(persist_affinity_heat,MAP_WORKER_HEAT_PERSIST_SECONDS);
}

private int affinity_effective_weight_unlocked(string affinity)
{
	int static_weight = max(1,affinity_room_weights[affinity] || 1);
	int heat_score = max(0,affinity_heat_scores[affinity]);
	return calculate_affinity_effective_weight(static_weight,heat_score);
}

/** Pure helper used by placement and TestUnit boundary checks. */
int calculate_affinity_effective_weight(int static_weight,int heat_score)
{
	int heat_weight;
	static_weight = max(1,min(1000000,static_weight));
	heat_score = max(0,min(MAP_WORKER_MAX_HEAT_SCORE,heat_score));
	heat_weight = (heat_score*MAP_WORKER_HEAT_WEIGHT_PER_PLAYER+
		MAP_WORKER_HEAT_SCALE-1)/MAP_WORKER_HEAT_SCALE;
	return min(1000000,static_weight+heat_weight);
}

mapping(string:mixed) query_affinity_weight_info(string affinity)
{
	mapping result;
	affinity = normalize_token(affinity,MAP_WORKER_MAX_AFFINITY);
	if(affinity=="" || !affinity_room_weights[affinity])
		return (["ok":0,"code":"unknown_static_affinity"]);
	{
		object key = worker_state_lock->lock();
		int heat_score = max(0,affinity_heat_scores[affinity]);
		result = (["ok":1,"affinity":affinity,
			"static_weight":max(1,affinity_room_weights[affinity]),
			"heat_score":heat_score,
			"estimated_players":(heat_score+MAP_WORKER_HEAT_SCALE/2)/
				MAP_WORKER_HEAT_SCALE,
			"effective_weight":affinity_effective_weight_unlocked(affinity)]);
		destruct(key);
	}
	return result;
}

int affinity_heat_ready()
{
	object key = worker_state_lock->lock();
	int ready = sizeof(affinity_heat_scores)>0;
	destruct(key);
	return ready;
}

/** Record one complete coordinator-verified online snapshot. */
mapping(string:mixed) observe_affinity_heat(mapping observed)
{
	mapping(string:int) validated = ([]);
	int changed;
	if(node_role!="gateway" || !mappingp(observed) ||
	   sizeof(observed)>MAP_WORKER_MAX_AFFINITIES)
		return (["ok":0,"code":"invalid_affinity_heat_observation"]);
	foreach(indices(observed),mixed raw_affinity){
		string affinity;
		mixed raw_count;
		if(!stringp(raw_affinity))
			return (["ok":0,"code":"invalid_affinity_heat_observation"]);
		affinity = normalize_token((string)raw_affinity,
			MAP_WORKER_MAX_AFFINITY);
		raw_count = observed[raw_affinity];
		if(affinity=="" || affinity!=(string)raw_affinity ||
		   !intp(raw_count) || (int)raw_count<0 || (int)raw_count>100000)
			return (["ok":0,"code":"invalid_affinity_heat_observation"]);
		if(affinity_room_weights[affinity])
			validated[affinity] = (int)raw_count;
	}
	{
		object key = worker_state_lock->lock();
		foreach(indices(affinity_room_weights),string affinity){
			int old_score = max(0,affinity_heat_scores[affinity]);
			int target_score = min(MAP_WORKER_MAX_HEAT_SCORE,
				validated[affinity]*MAP_WORKER_HEAT_SCALE);
			int next_score = (old_score*
				(MAP_WORKER_HEAT_EWMA_DENOMINATOR-1)+target_score)/
				MAP_WORKER_HEAT_EWMA_DENOMINATOR;
			if(next_score==old_score)
				continue;
			if(next_score>0)
				affinity_heat_scores[affinity] = next_score;
			else
				m_delete(affinity_heat_scores,affinity);
			changed++;
		}
		affinity_heat_last_observed_at = time();
		if(changed){
			affinity_heat_generation++;
			affinity_heat_dirty = 1;
		}
		destruct(key);
	}
	if(changed)
		schedule_affinity_heat_persist();
	return (["ok":1,"changed":changed,
		"observed_affinities":sizeof(validated)]);
}

/** A clean restart's recent leases seed first-deploy popularity immediately. */
private void seed_affinity_heat_from_restored_leases()
{
	mapping(string:int) counts = ([]);
	int now = time();
	int changed;
	if(node_role!="gateway")
		return;
	{
		object lease_key = player_lease_lock->lock();
		foreach(values(player_leases),mapping lease){
			string affinity = (string)lease["affinity"];
			if(!has_value(({"active","frozen"}),(string)lease["state"]) ||
			   ((int)lease["updated_at"]<now-MAP_WORKER_HEAT_SEED_MAX_AGE &&
			    (int)lease["expires_at"]<now-300))
				continue;
			counts[affinity]++;
		}
		destruct(lease_key);
	}
	{
		object key = worker_state_lock->lock();
		foreach(indices(counts),string affinity){
			int seed_score;
			if(!affinity_room_weights[affinity])
				continue;
			seed_score = min(MAP_WORKER_MAX_HEAT_SCORE,
				counts[affinity]*MAP_WORKER_HEAT_SCALE);
			if(seed_score>affinity_heat_scores[affinity]){
				affinity_heat_scores[affinity] = seed_score;
				changed++;
			}
		}
		if(changed){
			affinity_heat_generation++;
			affinity_heat_last_observed_at = now;
			affinity_heat_dirty = 1;
		}
		destruct(key);
	}
	if(changed)
		schedule_affinity_heat_persist();
}

/** Static room location safe to persist in a handoff or trusted header. */
private string normalize_room_location(string room_path)
{
	string path = String.trim_all_whites(room_path || "");
	if(has_prefix(path,ROOT))
		path = path[sizeof(ROOT)..];
	if(sizeof(path)<12 || sizeof(path)>320 ||
	   !has_prefix(path,"/gamelib/d/") || search(path,"..")!=-1 ||
	   search(path,"#")!=-1 || search(path,"\n")!=-1 ||
	   search(path,"\r")!=-1)
		return "";
	foreach(path;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='/' || one=='_' || one=='-' ||
		   one=='.')
			continue;
		return "";
	}
	return path;
}

private string normalize_endpoint(string endpoint)
{
	endpoint = String.trim_all_whites(endpoint || "");
	if(endpoint=="" || sizeof(endpoint)>MAP_WORKER_MAX_ENDPOINT ||
	   search(endpoint,"\n")!=-1 || search(endpoint,"\r")!=-1)
		return "";
	if(!has_prefix(endpoint,"http://127.0.0.1:") &&
	   !has_prefix(endpoint,"http://localhost:") &&
	   !has_prefix(endpoint,"http://[::1]:"))
		return "";
	return endpoint;
}

private string stable_digest(string source)
{
	object hash = Crypto.SHA256();
	hash->update(source || "");
	return String.string2hex(hash->digest());
}

private int stable_hash_value(string source)
{
	string digest = stable_digest(source);
	int value = 0;
	if(sizeof(digest)>=7)
		sscanf(digest[0..6],"%x",value);
	return value;
}

private string strip_room_root(string room_path)
{
	string path = String.trim_all_whites(room_path || "");
	if(path=="")
		return "";
	if(has_prefix(path,ROOT))
		path = path[sizeof(ROOT)..];
	if(has_prefix(path,"/"))
		path = path[1..];
	if(has_prefix(path,"gamelib/d/"))
		path = path[sizeof("gamelib/d/")..];
	if(search(path,"#")!=-1)
		path = (path/"#")[0];
	return path;
}

/**
 * S1 is one logical world, but it must not be one process-sized hotspot.
 * Shared rooms stay exact-affinity singletons while connected field chapters
 * form a few stable placement units.  The coordinator may place those units
 * on any healthy worker; no worker is permanently reserved for one realm.
 */
private string illusion_s1_affinity(array(string) parts)
{
	string room_name;
	if(sizeof(parts)<2)
		return "illusion_s1:frontier";
	room_name = (parts[1]/".")[0];
	return "illusion_s1:"+
		(illusion_s1_room_groups[room_name] || "frontier");
}

/**
 * Static rooms normally use their top-level map directory as an affinity
 * group. S1 is deliberately split into stable chapter groups so one popular
 * season can use multiple workers without ever cloning one shared room.
 * Dynamic dungeons/events may supply an instance key so separate instances
 * can be spread without splitting one shared room. All homes intentionally
 * share one affinity because HOMED owns one global marketplace/property
 * snapshot; spreading homes across processes would allow stale snapshots to
 * overwrite each other.
 */
string query_affinity_key(string room_path,void|string instance_key)
{
	string path = strip_room_root(room_path);
	array(string) parts;
	string block;
	string instance;
	if(path=="" || search(path,"..")!=-1)
		return "";
	parts = path/"/";
	if(sizeof(parts)==0)
		return "";
	block = normalize_token(parts[0],64);
	if(block=="")
		return "";
	if(block=="illusion_s1")
		return illusion_s1_affinity(parts);
	// 传统 FBD 幻境的实际目录并不以 fb_ 命名。统一折叠到虚拟
	// block，并由服务端 team/fb_name 实例键分片，确保同一队伍的
	// 克隆房只存在于一个 Worker，不复制怪物与奖励。
	if(FBD->is_fb_room_path(path))
		block = "fb_runtime";
	// 家园商户、地契和杂货 NPC 都在凝阁殿。它们与家园共用
	// HOMED 的一份全局快照，因此必须归属同一个一致性域。
	if(block=="home" || block=="ninggedian")
		return "home";
	// TIMED_EVENTD owns one shared session snapshot and one scheduler.  Every
	// timed-event lobby/stage/duel must therefore stay in a single consistency
	// domain; splitting instance keys across workers races the same state file
	// and prevents players on different maps from joining one event.
	if(block=="timed_event")
		return "timed_event";
	// Dungeon instance keys historically use server-owned separators. Convert
	// only that separator into the affinity token alphabet; all remaining
	// unsafe input is still rejected by normalize_token().
	instance = normalize_token(replace(instance_key || "","|",":"),96);
	if(instance!="" &&
	   (has_prefix(block,"fb_") || has_suffix(block,"_fb")))
		return block+":"+instance;
	return block;
}

/**
 * A persisted room path identifies the static map block, while a dungeon
 * affinity may additionally carry its server-owned team/instance key.  Check
 * the suffix by feeding it back through the one canonical affinity function;
 * ordinary maps, homes and timed events still require an exact match.
 */
private int room_matches_affinity(string room_path,string affinity)
{
	string room_affinity = query_affinity_key(room_path,"");
	string normalized_affinity = normalize_token(affinity,
		MAP_WORKER_MAX_AFFINITY);
	string instance_key;
	if(room_affinity=="" || normalized_affinity=="")
		return 0;
	if(room_affinity==normalized_affinity)
		return 1;
	if((!has_prefix(room_affinity,"fb_") &&
	   !has_suffix(room_affinity,"_fb")) ||
	   !has_prefix(normalized_affinity,room_affinity+":"))
		return 0;
	instance_key = normalized_affinity[sizeof(room_affinity)+1..];
	return instance_key!="" &&
		query_affinity_key(room_path,instance_key)==normalized_affinity;
}

string query_node_role()
{
	return node_role;
}

string query_local_worker_id()
{
	return local_worker_id;
}

string query_local_process_incarnation()
{
	return local_process_incarnation;
}

/** Resource/event daemons must not create room-owned state before routing lands. */
int local_affinity_assignments_ready()
{
	object key;
	int ready;
	if(node_role!="worker")
		return 1;
	key = local_route_lock->lock();
	ready = local_assignment_generation>0 && sizeof(local_affinity_owners)>0;
	destruct(key);
	return ready;
}

int query_local_assignment_generation()
{
	object key;
	int generation;
	if(node_role!="worker")
		return 0;
	key = local_route_lock->lock();
	generation = local_assignment_generation;
	destruct(key);
	return generation;
}

int query_runtime_worker_count()
{
	int runtime_count = (int)(getenv("XIAND_MAP_WORKER_RUNTIME_COUNT") || "0");
	if(runtime_count>=1 && runtime_count<=16)
		return runtime_count;
	return (int)query_cluster_config()["worker_count"];
}

int distributed_mode_enabled()
{
	return node_role=="gateway" || node_role=="worker";
}

void note_local_control_heartbeat()
{
	if(node_role=="worker"){
		object key = local_route_lock->lock();
		local_control_seen_at = time();
		destruct(key);
	}
}

int local_control_lease_valid()
{
	object key;
	int valid;
	if(node_role!="worker")
		return 1;
	key = local_route_lock->lock();
	valid = !local_control_isolated &&
		local_control_seen_at+MAP_WORKER_LOCAL_CONTROL_TTL>=time();
	destruct(key);
	return valid;
}

/** Permanently fence an expired worker until the gateway inventories it. */
int mark_local_control_isolated()
{
	object key;
	int changed;
	if(node_role!="worker")
		return 0;
	key = local_route_lock->lock();
	if(!local_control_isolated){
		local_control_isolated = 1;
		changed = 1;
	}
	destruct(key);
	return changed;
}

/** Called only after the gateway has reconciled every local live player. */
mapping(string:mixed) resume_local_control()
{
	object key;
	if(node_role!="worker")
		return (["ok":0,"code":"not_worker"]);
	key = local_route_lock->lock();
	local_control_seen_at = time();
	local_control_isolated = 0;
	destruct(key);
	return (["ok":1,"worker_id":local_worker_id]);
}

/**
 * Fence every public player request by the coordinator epoch. A higher epoch
 * may only be installed when no old live player object exists locally.
 */
mapping(string:mixed) accept_local_player_epoch(string userid,int epoch,
	int player_is_live)
{
	object key;
	int current;
	userid = normalize_userid(userid);
	if(node_role!="worker")
		return (["ok":1,"epoch":epoch]);
	if(userid=="" || epoch<1)
		return (["ok":0,"code":"invalid_local_epoch"]);
	key = local_route_lock->lock();
	current = local_player_epochs[userid];
	if(current>epoch || (current>0 && current!=epoch && player_is_live)){
		destruct(key);
		return (["ok":0,"code":"stale_local_epoch","epoch":current]);
	}
	if(!current && sizeof(local_player_epochs)>=MAP_WORKER_MAX_PLAYER_LEASES){
		destruct(key);
		return (["ok":0,"code":"local_epoch_limit"]);
	}
	local_player_epochs[userid] = epoch;
	destruct(key);
	return (["ok":1,"epoch":epoch]);
}

int query_local_player_epoch(string userid)
{
	object key;
	int epoch;
	userid = normalize_userid(userid);
	if(userid=="")
		return 0;
	key = local_route_lock->lock();
	epoch = local_player_epochs[userid];
	destruct(key);
	return epoch;
}

array(string) query_local_player_userids()
{
	object key = local_route_lock->lock();
	array(string) result = sort(indices(local_player_epochs));
	destruct(key);
	return result;
}

void clear_local_player_epoch(string userid)
{
	object key;
	userid = normalize_userid(userid);
	if(userid=="")
		return;
	key = local_route_lock->lock();
	m_delete(local_player_epochs,userid);
	m_delete(local_player_account_owners,userid);
	m_delete(local_player_arrivals,userid);
	destruct(key);
}

mapping(string:mixed) accept_local_player_account_owner(string userid,
	int epoch,string account_owner)
{
	object key;
	userid = normalize_userid(userid);
	account_owner = normalize_userid(account_owner);
	if(node_role!="worker" || userid=="" || account_owner=="" || epoch<1)
		return (["ok":0,"code":"invalid_local_account_owner"]);
	key = local_route_lock->lock();
	if(local_player_epochs[userid]!=epoch){
		destruct(key);
		return (["ok":0,"code":"stale_local_epoch"]);
	}
	local_player_account_owners[userid] = account_owner;
	destruct(key);
	return (["ok":1,"account_owner":account_owner]);
}

string query_local_player_account_owner(string userid)
{
	object key;
	string result;
	userid = normalize_userid(userid);
	if(userid=="")
		return "";
	key = local_route_lock->lock();
	result = local_player_account_owners[userid] || "";
	destruct(key);
	return result;
}

/**
 * Return 1 only when this worker must discard a shared-account cache. The
 * gateway changes the opaque token whenever an account moves between workers
 * (and after every gateway restart), so a process cannot overwrite newer
 * wallet/storage state from another process' stale cache.
 */
int accept_local_account_cache_token(string account_id,string cache_token)
{
	object key;
	int changed;
	account_id = normalize_userid(account_id);
	cache_token = lower_case(String.trim_all_whites(cache_token || ""));
	if(node_role!="worker")
		return 0;
	if(account_id=="" || sizeof(cache_token)!=64 ||
	   !valid_hex_identifier(cache_token))
		return -1;
	key = local_route_lock->lock();
	if(!local_account_cache_tokens[account_id] &&
	   sizeof(local_account_cache_tokens)>=MAP_WORKER_MAX_PLAYER_LEASES){
		destruct(key);
		return -1;
	}
	if(local_account_cache_tokens[account_id]!=cache_token){
		local_account_cache_tokens[account_id] = cache_token;
		changed = 1;
	}
	destruct(key);
	return changed;
}

mapping(string:mixed) begin_local_gateway_request(string request_id,
	string userid,int epoch,string kind,void|string admin_target_userid,
	void|string admin_target_account,void|string admin_target_worker,
	void|int admin_target_epoch,void|int admin_fee,
	void|string admin_recharge_request_id,void|string admin_item_path,
	void|int admin_item_count,void|string admin_item_request_id,
	void|string admin_capability,void|string account_owner)
{
	object key;
	mapping existing;
	int admin_operation;
	request_id = lower_case(String.trim_all_whites(request_id || ""));
	userid = normalize_userid(userid);
	kind = normalize_token(kind,32);
	admin_target_userid = normalize_userid(admin_target_userid || "");
	admin_target_account = normalize_userid(admin_target_account || "");
	admin_target_worker = normalize_worker_id(admin_target_worker || "");
	admin_capability = lower_case(String.trim_all_whites(
		admin_capability || ""));
	account_owner = normalize_userid(account_owner || "");
	admin_recharge_request_id = lower_case(String.trim_all_whites(
		admin_recharge_request_id || ""));
	admin_item_path = String.trim_all_whites(admin_item_path || "");
	admin_item_request_id = lower_case(String.trim_all_whites(
		admin_item_request_id || ""));
	if(node_role!="worker" || sizeof(request_id)!=64 ||
	   !valid_hex_identifier(request_id) || kind=="")
		return (["ok":0,"code":"invalid_local_request"]);
	admin_operation = kind=="admin_recharge" || kind=="admin_item_grant";
	if(admin_operation &&
	   (admin_target_userid=="" || admin_target_account=="" ||
	    admin_target_worker=="" || admin_target_epoch<0 ||
	    sizeof(admin_capability)!=64 ||
	    !valid_hex_identifier(admin_capability)))
		return (["ok":0,"code":"invalid_admin_target_capability"]);
	if(kind=="admin_recharge" &&
	   (admin_fee<=0 || admin_fee>100000000 ||
	    sizeof(admin_recharge_request_id)!=64 ||
	    !valid_hex_identifier(admin_recharge_request_id) ||
	    admin_item_path!="" || admin_item_count ||
	    admin_item_request_id!=""))
		return (["ok":0,"code":"invalid_admin_recharge_capability"]);
	if(kind=="admin_item_grant" &&
	   (admin_fee || admin_recharge_request_id!="" ||
	    admin_item_path=="" || sizeof(admin_item_path)>128 ||
	    search(admin_item_path,"..")!=-1 || admin_item_count<1 ||
	    admin_item_count>9999 || sizeof(admin_item_request_id)!=64 ||
	    !valid_hex_identifier(admin_item_request_id)))
		return (["ok":0,"code":"invalid_admin_item_capability"]);
	if(!admin_operation &&
	   (admin_target_userid!="" || admin_target_account!="" ||
	    admin_target_worker!="" || admin_target_epoch ||
	    admin_fee || admin_recharge_request_id!="" ||
	    admin_item_path!="" || admin_item_count ||
	    admin_item_request_id!="" || admin_capability!=""))
		return (["ok":0,"code":"unexpected_admin_target_capability"]);
	key = local_route_lock->lock();
	existing = local_requests[request_id];
	if(mappingp(existing)){
		destruct(key);
		return (["ok":0,"code":(string)existing["state"]=="running" ?
			"request_running" : "request_already_completed"]);
	}
	if(userid!="" && (epoch<1 || local_player_epochs[userid]!=epoch)){
		destruct(key);
		return (["ok":0,"code":"stale_local_epoch"]);
	}
	if(userid!="" && local_running_request_by_user[userid]!=""){
		string running_id = local_running_request_by_user[userid];
		mapping running = local_requests[running_id];
		// A completed/expired request record must never leave a permanent
		// per-user fence. Repair the redundant index before rejecting work.
		if(!mappingp(running) || (string)running["state"]!="running" ||
		   (string)running["userid"]!=userid)
			m_delete(local_running_request_by_user,userid);
		else{
			destruct(key);
			return (["ok":0,"code":"user_request_running"]);
		}
	}
	if(kind=="account" && account_owner!="" &&
	   local_running_request_by_account[account_owner]!=""){
		string running_id = local_running_request_by_account[account_owner];
		mapping running = local_requests[running_id];
		if(!mappingp(running) || (string)running["state"]!="running" ||
		   (string)running["kind"]!="account" ||
		   (string)running["account_owner"]!=account_owner)
			m_delete(local_running_request_by_account,account_owner);
		else{
			destruct(key);
			return (["ok":0,"code":"account_request_running"]);
		}
	}
	if(sizeof(local_requests)>=MAP_WORKER_MAX_LOCAL_REQUESTS){
		destruct(key);
		return (["ok":0,"code":"local_request_limit"]);
	}
	local_requests[request_id] = (["request_id":request_id,
		"userid":userid,"epoch":epoch,"kind":kind,"state":"running",
		"account_owner":account_owner,"started_at":time(),
		"expires_at":time()+MAP_WORKER_LOCAL_REQUEST_TTL]);
	if(admin_operation){
		local_requests[request_id]["admin_target_userid"] =
			admin_target_userid;
		local_requests[request_id]["admin_target_account"] =
			admin_target_account;
		local_requests[request_id]["admin_target_worker"] =
			admin_target_worker;
		local_requests[request_id]["admin_target_epoch"] =
			admin_target_epoch;
		local_requests[request_id]["admin_capability"] = admin_capability;
		if(kind=="admin_recharge"){
			local_requests[request_id]["admin_fee"] = admin_fee;
			local_requests[request_id]["admin_recharge_request_id"] =
				admin_recharge_request_id;
		}
		else{
			local_requests[request_id]["admin_item_path"] = admin_item_path;
			local_requests[request_id]["admin_item_count"] = admin_item_count;
			local_requests[request_id]["admin_item_request_id"] =
				admin_item_request_id;
		}
	}
	if(userid!="")
		local_running_request_by_user[userid] = request_id;
	if(kind=="account" && account_owner!="")
		local_running_request_by_account[account_owner] = request_id;
	destruct(key);
	return (["ok":1,"request_id":request_id]);
}

/**
 * Bind one account-management request to one not-yet-routed child archive.
 * The capability is consumed by the first exact save-fence check; it cannot
 * authorize a sibling, an ordinary gameplay save or a later request.
 */
mapping(string:mixed) prepare_local_account_character_save(
	string account_owner,string userid)
{
	object key;
	string request_id;
	mapping request;
	account_owner = normalize_userid(account_owner);
	userid = normalize_userid(userid);
	if(node_role!="worker" || account_owner=="" || userid=="" ||
	   userid==account_owner || !has_prefix(userid,account_owner+"c"))
		return (["ok":0,"code":"invalid_account_character_save"]);
	key = local_route_lock->lock();
	request_id = local_running_request_by_account[account_owner];
	request = local_requests[request_id];
	if(!mappingp(request) || (string)request["state"]!="running" ||
	   (string)request["kind"]!="account" ||
	   (string)request["account_owner"]!=account_owner){
		werror("[MAP_WORKER][ACCOUNT_SAVE_CAPABILITY] rejected account=%s "+
			"userid=%s request=%s state=%s kind=%s owner=%s\n",
			account_owner,userid,request_id || "",
			mappingp(request) ? (string)request["state"] : "missing",
			mappingp(request) ? (string)request["kind"] : "missing",
			mappingp(request) ? (string)request["account_owner"] : "missing");
		if(request_id!="")
			m_delete(local_running_request_by_account,account_owner);
		destruct(key);
		return (["ok":0,"code":"account_request_missing"]);
	}
	string bound_userid = stringp(
		request["account_character_save_userid"]) ?
		(string)request["account_character_save_userid"] : "";
	if(stringp(request["account_character_save_consumed_userid"])){
		destruct(key);
		return (["ok":0,"code":"account_character_save_already_consumed"]);
	}
	if(bound_userid==userid){
		destruct(key);
		return (["ok":1,"request_id":request_id,"userid":userid,
			"replayed":1]);
	}
	if(bound_userid!=""){
		werror("[MAP_WORKER][ACCOUNT_SAVE_CAPABILITY] collision account=%s "+
			"bound=%s requested=%s request=%s\n",account_owner,
			bound_userid,userid,request_id);
		destruct(key);
		return (["ok":0,"code":"account_character_save_already_bound"]);
	}
	request["account_character_save_userid"] = userid;
	destruct(key);
	return (["ok":1,"request_id":request_id,"userid":userid]);
}

private int local_account_character_save_capability_matches(mapping request,
	string account_owner,string userid)
{
	return mappingp(request) && account_owner!="" && userid!="" &&
		userid!=account_owner && has_prefix(userid,account_owner+"c") &&
		(string)request["state"]=="running" &&
		(string)request["kind"]=="account" &&
		(string)request["account_owner"]==account_owner &&
		!stringp(request["account_character_save_consumed_userid"]) &&
		(string)request["account_character_save_userid"]==userid;
}

int test_local_account_character_save_capability(mapping request,
	string account_owner,string userid)
{
	return local_account_character_save_capability_matches(request,
		normalize_userid(account_owner),normalize_userid(userid));
}

/** Consume the exact one-shot child-archive save capability. */
int consume_local_account_character_save_fence(string account_owner,
	string userid)
{
	object key;
	string request_id;
	mapping request;
	int valid;
	account_owner = normalize_userid(account_owner);
	userid = normalize_userid(userid);
	if(node_role!="worker" || account_owner=="" || userid=="")
		return 0;
	key = local_route_lock->lock();
	request_id = local_running_request_by_account[account_owner];
	request = local_requests[request_id];
	valid = request_id!="" &&
		local_account_character_save_capability_matches(request,
			account_owner,userid);
	if(valid){
		request["account_character_save_consumed_userid"] = userid;
		m_delete(request,"account_character_save_userid");
	}
	destruct(key);
	return valid;
}

void clear_local_account_character_save(string account_owner,string userid)
{
	object key;
	string request_id;
	mapping request;
	account_owner = normalize_userid(account_owner);
	userid = normalize_userid(userid);
	if(account_owner=="" || userid=="")
		return;
	key = local_route_lock->lock();
	request_id = local_running_request_by_account[account_owner];
	request = local_requests[request_id];
	if(mappingp(request) &&
	   (string)request["account_character_save_userid"]==userid){
		// Even an aborted reservation is terminal for this request. A retry
		// must enter through a fresh gateway request id and account fence.
		request["account_character_save_consumed_userid"] = userid;
		m_delete(request,"account_character_save_userid");
	}
	destruct(key);
}

mapping(string:mixed) query_local_running_admin_target(string userid,
	void|string expected_kind)
{
	object key;
	string request_id;
	mapping request;
	userid = normalize_userid(userid);
	expected_kind = normalize_token(expected_kind || "",32);
	if(userid=="")
		return (["ok":0,"code":"invalid_userid"]);
	key = local_route_lock->lock();
	request_id = local_running_request_by_user[userid];
	request = local_requests[request_id];
	if(mappingp(request) && (string)request["state"]=="running" &&
	   ((expected_kind!="" && (string)request["kind"]==expected_kind) ||
	    (expected_kind=="" && has_prefix((string)request["kind"],"admin_"))))
		request = copy_value(request);
	else
		request = 0;
	destruct(key);
	if(!mappingp(request))
		return (["ok":0,"code":"admin_target_missing"]);
	request["ok"] = 1;
	return request;
}

void complete_local_gateway_request(string request_id)
{
	object key;
	mapping request;
	request_id = lower_case(String.trim_all_whites(request_id || ""));
	key = local_route_lock->lock();
	request = local_requests[request_id];
	if(mappingp(request) && (string)request["state"]=="running"){
		request["state"] = "done";
		request["finished_at"] = time();
		request["expires_at"] = time()+MAP_WORKER_LOCAL_REQUEST_TTL;
		if((string)request["userid"]!="" &&
		   local_running_request_by_user[(string)request["userid"]]==request_id)
			m_delete(local_running_request_by_user,(string)request["userid"]);
		if((string)request["account_owner"]!="" &&
		   local_running_request_by_account[
			(string)request["account_owner"]]==request_id)
			m_delete(local_running_request_by_account,
				(string)request["account_owner"]);
	}
	// Defensive repair for a record removed by recovery/expiry before a late
	// response callback reaches this function.
	foreach(indices(local_running_request_by_user),string running_user)
		if(local_running_request_by_user[running_user]==request_id)
			m_delete(local_running_request_by_user,running_user);
	foreach(indices(local_running_request_by_account),string running_account)
		if(local_running_request_by_account[running_account]==request_id)
			m_delete(local_running_request_by_account,running_account);
	destruct(key);
}

mapping(string:mixed) query_local_gateway_request(string request_id)
{
	object key;
	mapping result;
	request_id = lower_case(String.trim_all_whites(request_id || ""));
	key = local_route_lock->lock();
	result = local_requests[request_id];
	if(mappingp(result))
		result = copy_value(result);
	destruct(key);
	if(!mappingp(result))
		return (["ok":0,"code":"unknown_request"]);
	result["ok"] = 1;
	return result;
}

array(mapping(string:mixed)) query_local_running_requests()
{
	object key;
	array(mapping(string:mixed)) result = ({});
	key = local_route_lock->lock();
	foreach(values(local_requests),mapping request)
		if((string)request["state"]=="running")
			result += ({copy_value(request)});
	destruct(key);
	return result;
}

int local_user_request_running(string userid)
{
	object key;
	int running;
	string request_id;
	mapping request;
	userid = normalize_userid(userid);
	if(userid=="")
		return 0;
	key = local_route_lock->lock();
	request_id = local_running_request_by_user[userid];
	request = local_requests[request_id];
	running = request_id!="" && mappingp(request) &&
		(string)request["state"]=="running" &&
		(string)request["userid"]==userid;
	if(request_id!="" && !running)
		m_delete(local_running_request_by_user,userid);
	destruct(key);
	return running;
}

/** A slow accepted request may finish after control heartbeat expiry only. */
int local_user_request_save_fence_valid(string userid)
{
	object key;
	int valid;
	string request_id;
	mapping request;
	userid = normalize_userid(userid);
	if(node_role!="worker" || userid=="")
		return 0;
	key = local_route_lock->lock();
	request_id = local_running_request_by_user[userid];
	request = local_requests[request_id];
	valid = request_id!="" && mappingp(request) &&
		(string)request["state"]=="running" &&
		(string)request["userid"]==userid &&
		(int)request["epoch"]>0 &&
		(int)request["epoch"]==local_player_epochs[userid];
	destruct(key);
	return valid;
}

/**
 * The coordinator may grant this worker one bounded shutdown-save window only
 * after public routing has been paused and every accepted request has settled.
 * This does not transfer character ownership; it merely lets shutdown_safe
 * persist the worker's existing epoch-owned objects after control heartbeats
 * have intentionally stopped.
 */
mapping(string:mixed) prepare_local_shutdown_save_fence()
{
	object key;
	if(node_role!="worker")
		return (["ok":0,"code":"not_worker"]);
	key = local_route_lock->lock();
	local_shutdown_save_fence_expires_at = time()+1800;
	destruct(key);
	return (["ok":1,"expires_at":local_shutdown_save_fence_expires_at]);
}

/**
 * A normal coordinator restart may abort before any process is stopped.  Its
 * shutdown-save capability must then be revoked explicitly before public
 * routing is reopened; otherwise a later control interruption could permit a
 * stale worker save during the old 30-minute capability window.
 */
mapping(string:mixed) cancel_local_shutdown_save_fence()
{
	object key;
	if(node_role!="worker")
		return (["ok":0,"code":"not_worker"]);
	key = local_route_lock->lock();
	local_shutdown_save_fence_expires_at = 0;
	destruct(key);
	return (["ok":1]);
}

int local_shutdown_save_fence_valid()
{
	object key;
	int valid;
	if(node_role!="worker")
		return 0;
	key = local_route_lock->lock();
	valid = local_shutdown_save_fence_expires_at>=time();
	destruct(key);
	return valid;
}

mapping(string:mixed) install_local_player_arrival(string userid,int epoch,
	string room_path,string expected_affinity)
{
	object key;
	string affinity;
	string owner;
	userid = normalize_userid(userid);
	room_path = normalize_room_location(room_path);
	affinity = normalize_token(expected_affinity || "",
		MAP_WORKER_MAX_AFFINITY);
	if(node_role!="worker" || userid=="" || epoch<1 || room_path=="" ||
	   affinity=="" || !room_matches_affinity(room_path,affinity))
		return (["ok":0,"code":"invalid_local_arrival"]);
	key = local_route_lock->lock();
	owner = local_affinity_owners[affinity] || "";
	if(local_player_epochs[userid]!=epoch || owner!=local_worker_id){
		destruct(key);
		return (["ok":0,"code":"stale_local_arrival"]);
	}
	local_player_arrivals[userid] = (["userid":userid,"epoch":epoch,
		"room_path":room_path,"affinity":affinity,"expires_at":time()+60]);
	destruct(key);
	return (["ok":1,"room_path":room_path,"affinity":affinity]);
}

mapping(string:mixed) query_local_player_arrival(string userid)
{
	object key;
	mapping result;
	userid = normalize_userid(userid);
	key = local_route_lock->lock();
	result = local_player_arrivals[userid];
	if(mappingp(result) && ((int)result["expires_at"]<time() ||
	   (int)result["epoch"]!=local_player_epochs[userid])){
		m_delete(local_player_arrivals,userid);
		result = 0;
	}
	if(mappingp(result))
		result = copy_value(result);
	destruct(key);
	if(!mappingp(result))
		return (["ok":0,"code":"no_local_arrival"]);
	result["ok"] = 1;
	return result;
}

void clear_local_player_arrival(string userid)
{
	object key;
	userid = normalize_userid(userid);
	if(userid=="")
		return;
	key = local_route_lock->lock();
	m_delete(local_player_arrivals,userid);
	destruct(key);
}

mapping(string:mixed) query_local_control_status()
{
	object key;
	mapping(string:mixed) result;
	key = local_route_lock->lock();
	result = (["worker_id":local_worker_id,
		"last_control_seen_at":local_control_seen_at,
		"control_lease_valid":node_role!="worker" ||
			(!local_control_isolated && local_control_seen_at+
			MAP_WORKER_LOCAL_CONTROL_TTL>=time()),
		"isolated":local_control_isolated,
		"save_fence_blocks":local_save_fence_block_total,
		"save_fence_block_reasons":copy_value(local_save_fence_blocks),
		"tracked_player_epochs":sizeof(local_player_epochs),
		"control_ttl":MAP_WORKER_LOCAL_CONTROL_TTL,
		"shutdown_save_fence_valid":
			local_shutdown_save_fence_expires_at>=time()]);
	destruct(key);
	key = local_social_lock->lock();
	result["social_outbox_pending"] = sizeof(local_social_events);
	result["social_delivery_markers"] = sizeof(local_social_completed);
	destruct(key);
	return result;
}

void note_local_save_fence_block(string reason)
{
	object key;
	reason = normalize_token(reason,48);
	if(!has_value(({"control_lease","player_epoch",
	   "control_and_epoch"}),reason))
		reason = "unknown";
	key = local_route_lock->lock();
	local_save_fence_block_total++;
	local_save_fence_blocks[reason]++;
	destruct(key);
}

/**
 * Cache an already validated coordinator snapshot for management commands.
 * A worker must never synchronously call the coordinator from inside a public
 * request: the coordinator is already waiting for that worker response.
 */
mapping(string:mixed) update_local_online_snapshot(mapping snapshot)
{
	object key;
	array users;
	mapping counts;
	int worker_count;
	int snapshot_at;
	if(node_role!="worker" || !mappingp(snapshot))
		return (["ok":0,"code":"invalid_online_snapshot"]);
	users = arrayp(snapshot["users"]) ? (array)snapshot["users"] : 0;
	counts = mappingp(snapshot["worker_counts"]) ?
		(mapping)snapshot["worker_counts"] : 0;
	worker_count = (int)snapshot["worker_count"];
	snapshot_at = (int)snapshot["snapshot_at"];
	if(!(int)snapshot["ok"] || !arrayp(users) || !mappingp(counts) ||
	   sizeof(users)>MAP_WORKER_MAX_PLAYER_LEASES ||
	   (int)snapshot["count"]!=sizeof(users) ||
	   worker_count!=query_runtime_worker_count() ||
	   snapshot_at<time()-MAP_WORKER_ONLINE_SNAPSHOT_TTL ||
	   snapshot_at>time()+5)
		return (["ok":0,"code":"invalid_online_snapshot"]);
	foreach(users,mixed raw){
		mapping row;
		string userid;
		string worker_id;
		if(!mappingp(raw))
			return (["ok":0,"code":"invalid_online_snapshot"]);
		row = (mapping)raw;
		userid = normalize_userid((string)(row["userid"] || ""));
		worker_id = normalize_worker_id((string)(row["worker_id"] || ""));
		if(userid=="" || worker_id=="" || (int)row["epoch"]<1)
			return (["ok":0,"code":"invalid_online_snapshot"]);
	}
	key = local_route_lock->lock();
	local_online_snapshot = copy_value(snapshot);
	local_online_snapshot_at = snapshot_at;
	destruct(key);
	return (["ok":1,"snapshot_at":snapshot_at,"count":sizeof(users)]);
}

mapping(string:mixed) query_local_online_snapshot()
{
	object key;
	mapping result;
	int snapshot_at;
	key = local_route_lock->lock();
	result = copy_value(local_online_snapshot);
	snapshot_at = local_online_snapshot_at;
	destruct(key);
	if(node_role!="worker" || !mappingp(result) || !(int)result["ok"] ||
	   snapshot_at<time()-MAP_WORKER_ONLINE_SNAPSHOT_TTL)
		return (["ok":0,"code":"online_snapshot_stale",
			"snapshot_at":snapshot_at]);
	result["age_seconds"] = max(0,time()-snapshot_at);
	return result;
}

/**
 * Check the worker's authoritative local lease table, not the coordinator's
 * periodically published online snapshot. This closes the short arrival
 * window where a newly handed-off team member is already local but has not
 * appeared in the next cluster snapshot yet.
 */
int local_team_player_exists(string tid)
{
	object key;
	array(string) userids;
	if(node_role!="worker")
		return 1;
	if(!tid || tid=="")
		return 0;
	key = local_route_lock->lock();
	userids = indices(local_player_epochs);
	destruct(key);
	foreach(userids,string userid){
		object player = find_player(userid);
		if(player && (string)player->query_term()==tid)
			return 1;
	}
	return 0;
}

/** Look up one coordinator-verified online row without a synchronous callback. */
mapping(string:mixed) query_local_online_user(string userid)
{
	mapping snapshot = query_local_online_snapshot();
	userid = normalize_userid(userid);
	if(userid=="" || !(int)snapshot["ok"] || !arrayp(snapshot["users"]))
		return (["ok":0,"code":"online_user_unavailable"]);
	foreach((array)snapshot["users"],mixed raw)
		if(mappingp(raw) && (string)raw["userid"]==userid){
			mapping result = copy_value((mapping)raw);
			result["ok"] = 1;
			return result;
		}
	return (["ok":0,"code":"online_user_not_found"]);
}

private string local_social_outbox_path()
{
	return DATA_ROOT+"map_workers/social_outbox/"+local_worker_id+".json";
}

/** Paid broadcasts and structural team changes must survive a worker crash. */
private int local_social_kind_is_durable(string kind)
{
	return kind=="world_broadcast" || kind=="team_snapshot" ||
		kind=="team_invite";
}

int query_local_social_event_ttl(string kind)
{
	kind = normalize_token(kind,48);
	if(kind=="team_snapshot" || kind=="team_invite")
		return MAP_WORKER_LOCAL_TEAM_DURABLE_TTL;
	if(kind=="world_broadcast")
		return MAP_WORKER_LOCAL_BROADCAST_TTL;
	return MAP_WORKER_LOCAL_SOCIAL_TTL;
}

private mapping(string:mixed) validate_local_social_outbox(mapping decoded)
{
	mapping(string:mapping(string:mixed)) restored = ([]);
	array(string) restored_order = ({});
	multiset(string) seen = (<>);
	mapping raw_events = mappingp(decoded) ?
		(mapping)decoded["events"] : ([]);
	mapping raw_delivered = mappingp(decoded) && mappingp(decoded["delivered"]) ?
		(mapping)decoded["delivered"] : ([]);
	mapping(string:int) restored_delivered = ([]);
	array raw_order = mappingp(decoded) && arrayp(decoded["order"]) ?
		(array)decoded["order"] : ({});
	int now = time();
	if(!mappingp(decoded) || (int)decoded["version"]!=1 ||
	   (string)decoded["worker_id"]!=local_worker_id ||
	   !mappingp(decoded["events"]) || !arrayp(decoded["order"]) ||
	   !intp(decoded["sequence"]) || (int)decoded["sequence"]<0 ||
	   !intp(decoded["event_count"]) ||
	   (int)decoded["event_count"]!=sizeof(raw_events) ||
	   !mappingp(decoded["delivered"]) ||
	   !intp(decoded["delivered_count"]) ||
	   (int)decoded["delivered_count"]!=sizeof(raw_delivered) ||
	   sizeof(raw_events)>MAP_WORKER_MAX_LOCAL_SOCIAL_EVENTS ||
	   sizeof(raw_delivered)>MAP_WORKER_MAX_LOCAL_REQUESTS ||
	   sizeof(raw_order)!=sizeof(raw_events))
		return (["ok":0,"code":"invalid_social_outbox"]);
	foreach(raw_order,mixed raw_event_id){
		string event_id = stringp(raw_event_id) ?
			normalize_token((string)raw_event_id,96) : "";
		mapping event = event_id!="" && mappingp(raw_events[event_id]) ?
			(mapping)raw_events[event_id] : ([]);
		string kind = normalize_token((string)(event["kind"] || ""),48);
		string source_user = normalize_userid(
			(string)(event["source_user"] || ""));
		string target_user = normalize_userid(
			(string)(event["target_user"] || ""));
		mapping raw_acked_workers = mappingp(event["acked_workers"]) ?
			(mapping)event["acked_workers"] : ([]);
		mapping(string:string) acked_workers = ([]);
		mixed raw_retry_count = event["retry_count"];
		mixed raw_next_retry_at = event["next_retry_at"];
		mixed raw_last_log_at = event["last_log_at"];
		if((has_index(event,"acked_workers") &&
		    !mappingp(event["acked_workers"])) ||
		   (has_index(event,"retry_count") && !intp(raw_retry_count)) ||
		   (has_index(event,"next_retry_at") && !intp(raw_next_retry_at)) ||
		   (has_index(event,"last_log_at") && !intp(raw_last_log_at)))
			return (["ok":0,"code":"invalid_social_outbox_retry"]);
		int retry_count = intp(raw_retry_count) ? (int)raw_retry_count : 0;
		int next_retry_at = intp(raw_next_retry_at) ?
			(int)raw_next_retry_at : 0;
		int last_log_at = intp(raw_last_log_at) ? (int)raw_last_log_at : 0;
		int maximum_ttl = query_local_social_event_ttl(kind);
		if(sizeof(raw_acked_workers)>MAP_WORKER_MAX_NODES)
			return (["ok":0,"code":"invalid_social_outbox_ack"]);
		foreach(indices(raw_acked_workers),mixed raw_worker_id){
			string acked_worker_id = stringp(raw_worker_id) ?
				normalize_worker_id((string)raw_worker_id) : "";
			mixed raw_incarnation = raw_acked_workers[raw_worker_id];
			if(acked_worker_id=="" || acked_worker_id!=(string)raw_worker_id)
				return (["ok":0,"code":"invalid_social_outbox_ack"]);
			// A short-lived development build stored coordinator generations.
			// Accept and discard those values so the event safely re-fanouts.
			if(intp(raw_incarnation) && (int)raw_incarnation>=1 &&
			   (int)raw_incarnation<=1000000000)
				continue;
			string incarnation = stringp(raw_incarnation) ?
				normalize_token((string)raw_incarnation,96) : "";
			if(incarnation!=(string)raw_incarnation ||
			   sizeof(incarnation)!=64)
				return (["ok":0,"code":"invalid_social_outbox_ack"]);
			acked_workers[acked_worker_id] = incarnation;
		}
		if(event_id=="" || event_id!=(string)raw_event_id || seen[event_id] ||
		   (string)event["event_id"]!=event_id ||
		   !local_social_kind_is_durable(kind) ||
		   (string)event["kind"]!=kind || source_user=="" ||
		   (string)event["source_user"]!=source_user ||
		   (string)(event["target_user"] || "")!=target_user ||
		   (string)event["source_worker"]!=local_worker_id ||
		   !valid_payload(mappingp(event["payload"]) ?
			(mapping)event["payload"] : ([])) ||
		   (has_value(({"private_tell","team_invite"}),kind) &&
		    target_user=="") || (int)event["created_at"]<1 ||
		   (int)event["created_at"]>now+5 ||
		   (int)event["expires_at"]<(int)event["created_at"] ||
		   (int)event["expires_at"]>
			(int)event["created_at"]+maximum_ttl+5 || retry_count<0 ||
		   retry_count>1000000 || next_retry_at<0 ||
		   next_retry_at>(int)event["expires_at"]+60 || last_log_at<0 ||
		   last_log_at>now+5)
			return (["ok":0,"code":"invalid_social_outbox_event"]);
		seen[event_id] = 1;
		// Membership snapshots remain authoritative until every current worker
		// ACKs them or a newer snapshot for the same team supersedes them.
		if((int)event["expires_at"]>=now || kind=="team_snapshot"){
			mapping restored_event = copy_value(event);
			restored_event["acked_workers"] = acked_workers;
			restored_event["retry_count"] = retry_count;
			restored_event["next_retry_at"] = next_retry_at;
			restored_event["last_log_at"] = last_log_at;
			if((int)event["expires_at"]<now){
				restored_event["created_at"] = now;
				restored_event["expires_at"] =
					now+MAP_WORKER_LOCAL_TEAM_DURABLE_TTL;
				restored_event["next_retry_at"] = 0;
			}
			restored[event_id] = restored_event;
			restored_order += ({event_id});
		}
	}
	foreach(indices(raw_delivered),mixed raw_event_id){
		string event_id = stringp(raw_event_id) ?
			normalize_token((string)raw_event_id,96) : "";
		if(event_id=="" || event_id!=(string)raw_event_id ||
		   !intp(raw_delivered[raw_event_id]) ||
		   (int)raw_delivered[raw_event_id]>
			now+MAP_WORKER_LOCAL_TEAM_DURABLE_TTL+5)
			return (["ok":0,"code":"invalid_social_delivery_marker"]);
		if((int)raw_delivered[raw_event_id]>=now)
			restored_delivered[event_id] =
				(int)raw_delivered[raw_event_id];
	}
	return (["ok":1,"events":restored,"order":restored_order,
		"delivered":restored_delivered,
		"sequence":(int)decoded["sequence"]]);
}

/** Caller holds local_social_lock. */
private int persist_local_social_outbox_unlocked()
{
	string path = local_social_outbox_path();
	string temp_path = path+".tmp";
	string backup_path = path+".bak";
	mapping(string:mapping(string:mixed)) durable_events = ([]);
	array(string) durable_order = ({});
	mapping(string:int) durable_delivered = ([]);
	foreach(local_social_event_order,string event_id)
		if(mappingp(local_social_events[event_id]) &&
		   local_social_kind_is_durable(
			(string)local_social_events[event_id]["kind"])){
			durable_events[event_id] = copy_value(local_social_events[event_id]);
			durable_order += ({event_id});
		}
	foreach(indices(local_social_completed),string event_id)
		if(local_social_durable_deliveries[event_id])
			durable_delivered[event_id] = local_social_completed[event_id];
	mapping snapshot = (["version":1,"worker_id":local_worker_id,
		"saved_at":time(),"sequence":local_social_sequence,
		"event_count":sizeof(durable_events),
		"delivered_count":sizeof(durable_delivered),
		"events":durable_events,"order":durable_order,
		"delivered":durable_delivered]);
	string encoded;
	mixed err;
	int ok;
	err = catch {
		encoded = Standards.JSON.encode(snapshot);
		if(sizeof(encoded)>MAP_WORKER_MAX_SOCIAL_OUTBOX_BYTES)
			error("social outbox exceeds durable size budget\n");
		mkdir(DATA_ROOT+"map_workers");
		mkdir(DATA_ROOT+"map_workers/social_outbox");
		rm(temp_path);
		if(Stdio.write_file(temp_path,encoded)==sizeof(encoded) &&
		   Stdio.file_size(temp_path)>0){
			if(Stdio.file_size(path)>0)
				Stdio.cp(path,backup_path);
			if(mv(temp_path,path) && Stdio.file_size(path)>0)
				ok = 1;
		}
	};
	if(err || !ok){
		rm(temp_path);
		werror("[MAP_WORKERD][SOCIAL_OUTBOX] persist failed worker=%s\n",
			local_worker_id);
		return 0;
	}
	return 1;
}

private void restore_local_social_outbox()
{
	array(string) candidates;
	if(node_role!="worker")
		return;
	candidates = ({local_social_outbox_path(),
		local_social_outbox_path()+".bak"});
	foreach(candidates,string path){
		mapping decoded;
		mapping validated;
		mixed err;
		int size = Stdio.file_size(path);
		if(size<=0 || size>MAP_WORKER_MAX_SOCIAL_OUTBOX_BYTES)
			continue;
		err = catch { decoded = Standards.JSON.decode(Stdio.read_file(path)); };
		if(err)
			continue;
		validated = validate_local_social_outbox(decoded);
		if(!(int)validated["ok"])
			continue;
		local_social_events = (mapping)validated["events"];
		local_social_event_order = (array(string))validated["order"];
		local_social_completed = (mapping)validated["delivered"];
		local_social_delivered = copy_value(local_social_completed);
		local_social_durable_deliveries = (<>);
		foreach(indices(local_social_completed),string event_id)
			local_social_durable_deliveries[event_id] = 1;
		local_social_sequence = (int)validated["sequence"];
		if(path!=candidates[0])
			werror("[MAP_WORKERD][SOCIAL_OUTBOX] restored backup worker=%s\n",
				local_worker_id);
		return;
	}
}

/**
 * A structural mutation may have reached the durable source outbox just before
 * that worker crashed. Rebuild its primitive TERMD replica before the gateway
 * retries fanout; otherwise the source player would retain a team id whose
 * local daemon no longer knew its members.
 */
private void restore_local_team_outbox_snapshots()
{
	array(mapping) snapshots = ({});
	object key;
	if(node_role!="worker")
		return;
	key = local_social_lock->lock();
	foreach(local_social_event_order,string event_id){
		mapping event = local_social_events[event_id];
		mapping payload;
		mapping snapshot;
		string kind;
		if(!mappingp(event))
			continue;
		kind = (string)event["kind"];
		if(kind!="team_snapshot" && kind!="team_invite")
			continue;
		payload = mappingp(event["payload"]) ?
			(mapping)event["payload"] : ([]);
		snapshot = mappingp(payload["snapshot"]) ?
			(mapping)payload["snapshot"] : ([]);
		if(sizeof(snapshot))
			snapshots += ({copy_value(snapshot)});
	}
	destruct(key);
	foreach(snapshots,mapping snapshot){
		mapping result = TERMD->apply_distributed_team_snapshot(snapshot);
		if(!(int)result["ok"])
			werror("[MAP_WORKERD][TEAM_OUTBOX] restore failed team=%s code=%s\n",
				(string)(snapshot["team_id"] || ""),
				(string)(result["code"] || "unknown"));
	}
}

private string local_social_team_id(mapping payload)
{
	mapping snapshot = mappingp(payload["snapshot"]) ?
		(mapping)payload["snapshot"] : ([]);
	return normalize_token((string)(snapshot["team_id"] || ""),96);
}

/**
 * A public worker request may not call the coordinator synchronously.  It
 * stages a bounded primitive event instead; the Pike gateway drains it only
 * after the worker response has completed.
 */
mapping(string:mixed) stage_local_social_event(string kind,string source_user,
	string target_user,mapping(string:mixed) payload)
{
	object key;
	string event_id;
	string team_id;
	mapping(string:mapping(string:mixed)) superseded = ([]);
	array(string) previous_order = ({});
	kind = normalize_token(kind,48);
	source_user = normalize_userid(source_user);
	target_user = normalize_userid(target_user);
	if(node_role!="worker" || !local_control_lease_valid() || kind=="" ||
	   !has_value(({"private_tell","world_broadcast","channel_chat",
		"team_invite","team_snapshot","team_chat","team_notice"}),kind) ||
	   source_user=="" || !valid_payload(payload) ||
	   (has_value(({"private_tell","team_invite"}),kind) &&
	    target_user==""))
		return (["ok":0,"code":"invalid_local_social_event"]);
	key = local_social_lock->lock();
	// A newer authoritative membership snapshot makes older snapshots for the
	// same team obsolete.  This bounds the durable outbox during an outage and
	// avoids replaying intermediate membership states after recovery.
	if(kind=="team_snapshot"){
		team_id = local_social_team_id(payload);
		if(team_id!=""){
			previous_order = copy_value(local_social_event_order);
			foreach(local_social_event_order,string old_event_id){
				mapping old_event = local_social_events[old_event_id];
				mapping old_payload;
				if(!mappingp(old_event) ||
				   (string)old_event["kind"]!="team_snapshot")
					continue;
				old_payload = mappingp(old_event["payload"]) ?
					(mapping)old_event["payload"] : ([]);
				if(local_social_team_id(old_payload)==team_id){
					superseded[old_event_id] = old_event;
					m_delete(local_social_events,old_event_id);
				}
			}
			if(sizeof(superseded))
				local_social_event_order -= indices(superseded);
		}
	}
	if(sizeof(local_social_events)>=MAP_WORKER_MAX_LOCAL_SOCIAL_EVENTS){
		foreach(indices(superseded),string old_event_id)
			local_social_events[old_event_id] = superseded[old_event_id];
		if(sizeof(superseded))
			local_social_event_order = previous_order;
		destruct(key);
		return (["ok":0,"code":"local_social_event_limit"]);
	}
	local_social_sequence++;
	event_id = lower_case(stable_digest(local_worker_id+"|"+
		(string)time()+"|"+(string)local_social_sequence+"|"+
		(string)random(1000000000)));
	local_social_events[event_id] = ([
		"event_id":event_id,"kind":kind,"source_user":source_user,
		"target_user":target_user,"source_worker":local_worker_id,
		"payload":copy_value(payload),"created_at":time(),
		"expires_at":time()+query_local_social_event_ttl(kind),
		"acked_workers":([]),"retry_count":0,"next_retry_at":0,
		"last_log_at":0,
	]);
	local_social_event_order += ({event_id});
	if(local_social_kind_is_durable(kind) &&
	   !persist_local_social_outbox_unlocked()){
		m_delete(local_social_events,event_id);
		foreach(indices(superseded),string old_event_id)
			local_social_events[old_event_id] = superseded[old_event_id];
		if(sizeof(superseded))
			local_social_event_order = previous_order;
		else
			local_social_event_order -= ({event_id});
		destruct(key);
		return (["ok":0,"code":"local_social_persist_failed"]);
	}
	destruct(key);
	return (["ok":1,"event_id":event_id]);
}

array(mapping(string:mixed)) poll_local_social_events(void|int limit)
{
	object key;
	array(mapping(string:mixed)) result = ({});
	int max_items = max(1,min(100,limit || 20));
	key = local_social_lock->lock();
	foreach(local_social_event_order,string event_id){
		mapping event = local_social_events[event_id];
		if(sizeof(result)>=max_items)
			break;
		if(mappingp(event) && (int)event["expires_at"]>=time() &&
		   (int)(event["next_retry_at"] || 0)<=time())
			result += ({copy_value(event)});
	}
	destruct(key);
	return result;
}

mapping(string:mixed) acknowledge_local_social_event(string event_id)
{
	object key;
	mapping removed;
	array(string) old_order;
	event_id = normalize_token(event_id,96);
	key = local_social_lock->lock();
	if(event_id=="" || !mappingp(local_social_events[event_id])){
		destruct(key);
		return (["ok":0,"code":"unknown_local_social_event"]);
	}
	removed = local_social_events[event_id];
	old_order = copy_value(local_social_event_order);
	m_delete(local_social_events,event_id);
	local_social_event_order -= ({event_id});
	if(local_social_kind_is_durable((string)removed["kind"]) &&
	   !persist_local_social_outbox_unlocked()){
		local_social_events[event_id] = removed;
		local_social_event_order = old_order;
		destruct(key);
		return (["ok":0,"code":"local_social_persist_failed"]);
	}
	destruct(key);
	return (["ok":1,"event_id":event_id]);
}

/** Persist each successful fanout target so retries only visit missing nodes. */
mapping(string:mixed) acknowledge_local_social_target(string event_id,
	string worker_id,string incarnation)
{
	object key;
	mapping event;
	mapping previous_acks;
	event_id = normalize_token(event_id,96);
	worker_id = normalize_worker_id(worker_id);
	incarnation = normalize_token(incarnation,96);
	key = local_social_lock->lock();
	event = local_social_events[event_id];
	if(event_id=="" || worker_id=="" || sizeof(incarnation)!=64 ||
	   !mappingp(event) ||
	   !local_social_kind_is_durable((string)event["kind"])){
		destruct(key);
		return (["ok":0,"code":"invalid_local_social_target_ack"]);
	}
	previous_acks = mappingp(event["acked_workers"]) ?
		copy_value((mapping)event["acked_workers"]) : ([]);
	if((string)previous_acks[worker_id]==incarnation){
		destruct(key);
		return (["ok":1,"event_id":event_id,"worker_id":worker_id,
			"replayed":1]);
	}
	event["acked_workers"] = previous_acks+([worker_id:incarnation]);
	if(!persist_local_social_outbox_unlocked()){
		event["acked_workers"] = previous_acks;
		destruct(key);
		return (["ok":0,"code":"local_social_persist_failed"]);
	}
	destruct(key);
	return (["ok":1,"event_id":event_id,"worker_id":worker_id]);
}

/** Exponential retry with a one-minute log gate prevents outage log storms. */
mapping(string:mixed) defer_local_social_event(string event_id)
{
	object key;
	mapping event;
	mapping previous;
	array(int) delays = ({1,2,4,8,15,30,60});
	int retry_count;
	int delay;
	int now = time();
	int should_log;
	event_id = normalize_token(event_id,96);
	key = local_social_lock->lock();
	event = local_social_events[event_id];
	if(event_id=="" || !mappingp(event)){
		destruct(key);
		return (["ok":0,"code":"unknown_local_social_event"]);
	}
	previous = copy_value(event);
	retry_count = (int)(event["retry_count"] || 0)+1;
	delay = delays[min(sizeof(delays)-1,retry_count-1)];
	should_log = !(int)(event["last_log_at"] || 0) ||
		(int)event["last_log_at"]+60<=now;
	event["retry_count"] = retry_count;
	event["next_retry_at"] = now+delay;
	if(should_log)
		event["last_log_at"] = now;
	if(local_social_kind_is_durable((string)event["kind"]) &&
	   !persist_local_social_outbox_unlocked()){
		local_social_events[event_id] = previous;
		destruct(key);
		return (["ok":0,"code":"local_social_persist_failed"]);
	}
	destruct(key);
	return (["ok":1,"event_id":event_id,"retry_count":retry_count,
		"retry_after":delay,"should_log":should_log]);
}

/** Reserve one idempotent worker-local delivery before mutating chat state. */
int begin_local_social_delivery(string event_id,void|int durable,
	void|int ttl_seconds)
{
	object key;
	event_id = normalize_token(event_id,96);
	if(node_role!="worker" || event_id=="")
		return 0;
	key = local_social_lock->lock();
	if(local_social_delivered[event_id]>=time()){
		destruct(key);
		return 0;
	}
	if(sizeof(local_social_delivered)>=MAP_WORKER_MAX_LOCAL_REQUESTS){
		destruct(key);
		return 0;
	}
	local_social_delivered[event_id] =
		time()+(ttl_seconds>0 ?
			min(MAP_WORKER_LOCAL_TEAM_DURABLE_TTL,ttl_seconds) :
			(durable ? MAP_WORKER_LOCAL_BROADCAST_TTL :
			MAP_WORKER_LOCAL_SOCIAL_TTL));
	if(durable)
		local_social_durable_deliveries[event_id] = 1;
	destruct(key);
	return 1;
}

/** Persist exactly-once completion only after the target mutation succeeded. */
int complete_local_social_delivery(string event_id,void|int durable)
{
	object key;
	int expiry;
	event_id = normalize_token(event_id,96);
	if(node_role!="worker" || event_id=="")
		return 0;
	key = local_social_lock->lock();
	if(local_social_completed[event_id]>=time()){
		destruct(key);
		return 1;
	}
	if(local_social_delivered[event_id]<time()){
		destruct(key);
		return 0;
	}
	expiry = local_social_delivered[event_id];
	local_social_completed[event_id] = expiry;
	if(durable)
		local_social_durable_deliveries[event_id] = 1;
	if(local_social_durable_deliveries[event_id] &&
	   !persist_local_social_outbox_unlocked()){
		m_delete(local_social_completed,event_id);
		destruct(key);
		return 0;
	}
	destruct(key);
	return 1;
}

void abort_local_social_delivery(string event_id)
{
	object key;
	event_id = normalize_token(event_id,96);
	if(event_id=="")
		return;
	key = local_social_lock->lock();
	m_delete(local_social_delivered,event_id);
	m_delete(local_social_completed,event_id);
	local_social_durable_deliveries[event_id] = 0;
	destruct(key);
}

/** Replace the worker-local affinity cache with a coordinator snapshot. */
mapping(string:mixed) update_local_assignments(mapping owners,int generation)
{
	mapping(string:string) validated = ([]);
	object key;
	if(node_role!="worker")
		return (["ok":0,"code":"not_worker"]);
	if(!mappingp(owners) || sizeof(owners)>MAP_WORKER_MAX_AFFINITIES ||
	   generation<1)
		return (["ok":0,"code":"invalid_assignment_snapshot"]);
	foreach(indices(owners),mixed raw_affinity){
		string affinity;
		string owner;
		if(!stringp(raw_affinity) || !stringp(owners[raw_affinity]))
			return (["ok":0,"code":"invalid_assignment_snapshot"]);
		affinity = normalize_token((string)raw_affinity,
			MAP_WORKER_MAX_AFFINITY);
		owner = normalize_worker_id((string)owners[raw_affinity]);
		if(affinity=="" || owner=="")
			return (["ok":0,"code":"invalid_assignment_snapshot"]);
		validated[affinity] = owner;
	}
	key = local_route_lock->lock();
	if(generation<local_assignment_generation){
		destruct(key);
		return (["ok":0,"code":"stale_assignment_generation"]);
	}
	local_affinity_owners = validated;
	local_assignment_generation = generation;
	destruct(key);
	return (["ok":1,"assignments":sizeof(validated),
		"generation":generation]);
}

mapping(string:mixed) update_local_assignment(string affinity,string owner,
	int generation)
{
	object key;
	affinity = normalize_token(affinity,MAP_WORKER_MAX_AFFINITY);
	owner = normalize_worker_id(owner);
	if(node_role!="worker")
		return (["ok":0,"code":"not_worker"]);
	if(affinity=="" || owner=="" || generation<1)
		return (["ok":0,"code":"invalid_assignment"]);
	key = local_route_lock->lock();
	if(generation<local_assignment_generation){
		destruct(key);
		return (["ok":0,"code":"stale_assignment_generation"]);
	}
	local_affinity_owners[affinity] = owner;
	local_assignment_generation = generation;
	destruct(key);
	return (["ok":1,"affinity":affinity,"worker_id":owner,
		"generation":generation]);
}

private string player_instance_hint(object player,object room,string room_path)
{
	string normalized = strip_room_root(room_path);
	string block = sizeof(normalized/"/") ? (normalized/"/")[0] : "";
	string fb_name = FBD->query_fb_name_by_room_path(normalized);
	string fb_id = "";
	string term = "";
	// Keep the server-owned home identity hint for recovery metadata. The
	// affinity function deliberately collapses every home to the single
	// "home" consistency domain owned by HOMED's persistence worker.
	if(block=="home"){
		if(room && functionp(room->query_masterId) &&
		   (string)room->query_masterId()!="")
			return (string)room->query_masterId();
		if(functionp(player->query_inhome_pos) &&
		   (string)player->query_inhome_pos()!="")
			return (string)player->query_inhome_pos();
		if(functionp(player->query_home_path))
			return (string)player->query_home_path();
	}
	if(block=="fb_runtime" || fb_name!=""){
		fb_id = (string)(player->fb_id || "");
		if(fb_id!="" && sizeof(fb_id)<=160 && search(fb_id,"..")==-1)
			return fb_id;
		if(functionp(player->query_term))
			term = (string)player->query_term();
		if(fb_name=="")
			fb_name = FBD->query_fb_name_by_id(fb_id);
		if(term!="" && term!="noterm" && fb_name!="")
			return term+"/"+fb_name;
	}
	if((has_prefix(block,"fb_") || has_suffix(block,"_fb")) &&
	   functionp(player->query_term)){
		term = (string)player->query_term();
		return term!="" ? term : (string)player->query_name();
	}
	if(block=="timed_event" && room &&
	   functionp(room->query_timed_event_session) &&
	   (string)room->query_timed_event_session()!="")
		return (string)room->query_timed_event_session();
	if(block=="timed_event" && functionp(player->query_term)){
		term = (string)player->query_term();
		return term!="" ? term : (string)player->query_name();
	}
	return "";
}

string query_player_affinity(object player)
{
	object room;
	if(!player)
		return "";
	room = environment(player);
	if(!room)
		return "";
	return query_affinity_key(file_name(room),
		player_instance_hint(player,room,file_name(room)));
}

/** Dynamic overflow rooms may only be cloned by their static map owner. */
int local_worker_owns_room(string room_path,void|string instance_key)
{
	string affinity;
	string owner;
	object key;
	if(node_role!="worker")
		return 1;
	affinity = query_affinity_key(room_path,instance_key || "");
	if(affinity=="")
		return 0;
	key = local_route_lock->lock();
	owner = local_affinity_owners[affinity] || "";
	destruct(key);
	return owner==local_worker_id;
}

/**
 * Called from the player move boundary before move_object(). Returning 1
 * means the gateway must fence, release and replay the move on the owner.
 * Returning 2 suppresses login's stale saved-room move while an exact
 * coordinator arrival capability is waiting on this worker.
 */
int guard_local_player_move(object player,mixed destination)
{
	object current_room;
	string destination_path;
	string current_affinity;
	string target_affinity;
	string owner;
	string userid;
	string target_room_path;
	object key;
	if(node_role!="worker" || !player)
		return 0;
	current_room = environment(player);
	if(!current_room)
		return 0;
	if(objectp(destination))
		destination_path = file_name((object)destination);
	else if(stringp(destination))
		destination_path = (string)destination;
	else
		return 0;
	userid = normalize_userid((string)player->query_name());
	target_room_path = normalize_room_location(destination_path);
	current_affinity = query_affinity_key(file_name(current_room),
		player_instance_hint(player,current_room,file_name(current_room)));
	target_affinity = query_affinity_key(destination_path,
		player_instance_hint(player,objectp(destination) ?
		(object)destination : 0,destination_path));
	if(userid=="" || current_affinity=="" || target_affinity=="" ||
	   current_affinity==target_affinity)
		return 0;
	key = local_route_lock->lock();
	// The target worker may enter exactly one coordinator-fenced static room
	// from the login menu. Suppress a saved old last_pos instead of generating
	// a reverse redirect before complete_map_worker_arrival lands the player.
	if(current_room->is("menu") && mappingp(local_player_arrivals[userid]) &&
	   (int)local_player_arrivals[userid]["epoch"]==
	   local_player_epochs[userid]){
		int exact_arrival = target_room_path!="" &&
			(string)local_player_arrivals[userid]["room_path"]==target_room_path;
		destruct(key);
		return exact_arrival ? 0 : 2;
	}
	owner = local_affinity_owners[target_affinity] || "";
	if(owner==local_worker_id){
		m_delete(pending_player_moves,userid);
		destruct(key);
		return 0;
	}
	// A non-empty saved team id is movable only when this worker has the full
	// primitive replica. The gateway installs that snapshot on the target before
	// releasing this source, while room-owned loot objects never cross processes.
	if(functionp(player->query_term) &&
	   (string)player->query_term()!="" &&
	   (string)player->query_term()!="noterm" &&
	   !TERMD->query_termId((string)player->query_term())){
		destruct(key);
		return 3;
	}
	pending_player_moves[userid] = ([
		"userid":userid,"source_affinity":current_affinity,
		"target_affinity":target_affinity,"target_worker":owner,
		"target_room_path":target_room_path,
		"assignment_generation":local_assignment_generation,
		"expires_at":time()+MAP_WORKER_HANDOFF_TTL,
	]);
	destruct(key);
	return 1;
}

mapping(string:mixed) query_local_move_redirect(string userid)
{
	object key;
	mapping result;
	userid = normalize_userid(userid);
	if(userid=="")
		return (["ok":0,"code":"invalid_userid"]);
	key = local_route_lock->lock();
	result = pending_player_moves[userid];
	if(mappingp(result) && (int)result["expires_at"]<time()){
		m_delete(pending_player_moves,userid);
		result = 0;
	}
	if(mappingp(result))
		result = copy_value(result);
	destruct(key);
	if(!mappingp(result))
		return (["ok":0,"code":"no_redirect"]);
	result["ok"] = 1;
	return result;
}

void clear_local_move_redirect(string userid)
{
	object key;
	userid = normalize_userid(userid);
	if(userid=="")
		return;
	key = local_route_lock->lock();
	m_delete(pending_player_moves,userid);
	destruct(key);
}

private int worker_alive_unlocked(mapping node,int now)
{
	return mappingp(node) && !(int)node["draining"] &&
		(int)node["last_heartbeat"]+MAP_WORKER_HEARTBEAT_TTL>=now;
}

private int worker_registered_unlocked(string worker_id)
{
	return mappingp(worker_nodes[worker_id]);
}

private int worker_available(string worker_id)
{
	object key = worker_state_lock->lock();
	int result = worker_alive_unlocked(worker_nodes[worker_id],time());
	destruct(key);
	return result;
}

/** Register or replace a worker incarnation.  Generation fences old owners. */
mapping(string:mixed) register_worker(string worker_id,string endpoint,
	int capacity,string incarnation)
{
	object key;
	mapping old;
	int generation = 1;
	worker_id = normalize_worker_id(worker_id);
	endpoint = normalize_endpoint(endpoint);
	incarnation = normalize_token(incarnation,96);
	if(worker_id=="" || endpoint=="" || incarnation=="" ||
	   capacity<10 || capacity>10000)
		return (["ok":0,"code":"invalid_worker"]);
	key = worker_state_lock->lock();
	if(!worker_nodes[worker_id] && sizeof(worker_nodes)>=MAP_WORKER_MAX_NODES){
		destruct(key);
		return (["ok":0,"code":"worker_limit"]);
	}
	old = worker_nodes[worker_id];
	if(mappingp(old)){
		generation = (int)old["generation"];
		if((string)old["incarnation"]!=incarnation)
			generation++;
	}
	worker_nodes[worker_id] = ([
		"worker_id":worker_id,
		"endpoint":endpoint,
		"capacity":capacity,
		"incarnation":incarnation,
		"generation":generation,
		"last_heartbeat":time(),
		"draining":0,
		"active_players":0,
		"active_rooms":0,
		"pending_commands":0,
		"heartbeat_ms":0,
		"commands_waiting":0,
		"commands_active":0,
		"backend_lag_ms":0,
		"cpu_percent":0,
		"queue_wait_max_ms":0,
		"command_max_ms":0,
		"backend_max_lag_ms":0,
		"call_outs":0,
		"save_average_ms":0,
		"save_max_ms":0,
		"save_failures":0,
		"save_fence_blocks":0,
		"social_outbox_pending":0,
		"social_delivery_markers":0,
	]);
	placement_generation++;
	destruct(key);
	return (["ok":1,"worker_id":worker_id,"generation":generation]);
}

mapping(string:mixed) heartbeat_worker(string worker_id,int generation,
	mapping(string:mixed) metrics)
{
	object key;
	mapping node;
	worker_id = normalize_worker_id(worker_id);
	if(worker_id=="" || !mappingp(metrics))
		return (["ok":0,"code":"invalid_heartbeat"]);
	key = worker_state_lock->lock();
	node = worker_nodes[worker_id];
	if(!mappingp(node) || (int)node["generation"]!=generation){
		destruct(key);
		return (["ok":0,"code":"stale_generation"]);
	}
	node["last_heartbeat"] = time();
	node["active_players"] = max(0,min(100000,(int)metrics["active_players"]));
	node["active_rooms"] = max(0,min(100000,(int)metrics["active_rooms"]));
	node["pending_commands"] = max(0,min(100000,(int)metrics["pending_commands"]));
	node["heartbeat_ms"] = max(0,min(600000,(int)metrics["heartbeat_ms"]));
	node["commands_waiting"] = max(0,min(100000,
		(int)metrics["commands_waiting"]));
	node["commands_active"] = max(0,min(100000,
		(int)metrics["commands_active"]));
	node["backend_lag_ms"] = max(0,min(600000,
		(int)metrics["backend_lag_ms"]));
	node["cpu_percent"] = max(0,min(10000,(int)metrics["cpu_percent"]));
	node["queue_wait_max_ms"] = max(0,min(3600000,
		(int)metrics["queue_wait_max_ms"]));
	node["command_max_ms"] = max(0,min(3600000,
		(int)metrics["command_max_ms"]));
	node["backend_max_lag_ms"] = max(0,min(3600000,
		(int)metrics["backend_max_lag_ms"]));
	node["call_outs"] = max(0,min(1000000,(int)metrics["call_outs"]));
	node["save_average_ms"] = max(0,min(3600000,
		(int)metrics["save_average_ms"]));
	node["save_max_ms"] = max(0,min(3600000,(int)metrics["save_max_ms"]));
	node["save_failures"] = max(0,min(1000000,
		(int)metrics["save_failures"]));
	node["save_fence_blocks"] = max(0,min(100000000,
		(int)metrics["save_fence_blocks"]));
	node["social_outbox_pending"] = max(0,
		min(MAP_WORKER_MAX_LOCAL_SOCIAL_EVENTS,
		(int)metrics["social_outbox_pending"]));
	node["social_delivery_markers"] = max(0,
		min(MAP_WORKER_MAX_LOCAL_REQUESTS,
		(int)metrics["social_delivery_markers"]));
	destruct(key);
	return (["ok":1,"generation":generation]);
}

mapping(string:mixed) set_worker_draining(string worker_id,int draining)
{
	object key;
	mapping node;
	worker_id = normalize_worker_id(worker_id);
	key = worker_state_lock->lock();
	node = worker_nodes[worker_id];
	if(!mappingp(node)){
		destruct(key);
		return (["ok":0,"code":"unknown_worker"]);
	}
	node["draining"] = draining ? 1 : 0;
	placement_generation++;
	destruct(key);
	schedule_control_persist();
	return (["ok":1,"worker_id":worker_id,"draining":draining ? 1 : 0]);
}

private int worker_load_score_unlocked(mapping node)
{
	int capacity = max(1,(int)node["capacity"]);
	int raw = (int)node["active_players"]*1000+
		(int)node["active_rooms"]*120+
		(int)node["pending_commands"]*400+
		(int)node["commands_waiting"]*600+
		(int)node["commands_active"]*200+
		(int)node["heartbeat_ms"]*10+
		(int)node["backend_lag_ms"]*20+
		(int)node["cpu_percent"]*30;
	return raw/capacity;
}

private int assigned_weight_unlocked(string worker_id,string except_affinity)
{
	int assigned;
	foreach(indices(affinity_assignments),string affinity){
		mapping placement = affinity_assignments[affinity];
		if(affinity!=except_affinity &&
		   (string)placement["worker_id"]==worker_id)
			assigned += max(1,(int)placement["weight"]);
	}
	return assigned;
}

private int assigned_catalog_weight_unlocked(string worker_id,
	string except_affinity)
{
	int assigned;
	foreach(indices(affinity_assignments),string affinity){
		mapping placement = affinity_assignments[affinity];
		if(affinity!=except_affinity && affinity_room_weights[affinity] &&
		   !catalog_rebalance_pending[affinity] &&
		   (string)placement["worker_id"]==worker_id)
			assigned += max(1,(int)placement["weight"]);
	}
	return assigned;
}

/** Strict least-loaded bin packing for a proven-cold catalog rebuild. */
private string choose_catalog_worker_unlocked(string affinity,int weight,
	int now)
{
	string best = "";
	int best_cost;
	int best_hash;
	foreach(sort(indices(worker_nodes)),string worker_id){
		mapping node = worker_nodes[worker_id];
		int capacity;
		int assigned;
		int cost;
		int rendezvous_hash;
		if(!worker_alive_unlocked(node,now))
			continue;
		capacity = max(1,(int)node["capacity"]);
		assigned = assigned_catalog_weight_unlocked(worker_id,affinity)+
			max(1,weight);
		cost = assigned*100000/capacity+
			worker_load_score_unlocked(node)*100;
		rendezvous_hash = stable_hash_value(affinity+"|"+worker_id)+1;
		if(best=="" || cost<best_cost ||
		   (cost==best_cost && rendezvous_hash>best_hash) ||
		   (cost==best_cost && rendezvous_hash==best_hash && worker_id<best)){
			best = worker_id;
			best_cost = cost;
			best_hash = rendezvous_hash;
		}
	}
	return best;
}

private string choose_worker_unlocked(string affinity,int weight,int now)
{
	string best = "";
	int best_hash;
	int best_denominator;
	foreach(sort(indices(worker_nodes)),string worker_id){
		mapping node = worker_nodes[worker_id];
		int capacity;
		int assigned;
		int denominator;
		int rendezvous_hash;
		if(!worker_alive_unlocked(node,now))
			continue;
		capacity = max(1,(int)node["capacity"]);
		assigned = assigned_weight_unlocked(worker_id,affinity)+max(1,weight);
		// Highest-random-weight rendezvous gives stable ownership. Live load
		// and already assigned map weight reduce a node's effective score,
		// while capacity lets larger nodes accept proportionally more work.
		rendezvous_hash = stable_hash_value(affinity+"|"+worker_id)+1;
		denominator = 100000+
			worker_load_score_unlocked(node)*100+
			assigned*100000/capacity;
		if(best=="" ||
		   rendezvous_hash*best_denominator>best_hash*denominator ||
		   (rendezvous_hash*best_denominator==best_hash*denominator &&
		    worker_id<best)){
			best = worker_id;
			best_hash = rendezvous_hash;
			best_denominator = denominator;
		}
	}
	return best;
}

mapping(string:mixed) assign_affinity(string affinity,void|int weight,
	void|int force)
{
	object key;
	mapping current;
	mapping previous;
	mapping installed;
	string worker_id;
	int previous_generation;
	int installed_generation;
	int now = time();
	affinity = normalize_token(affinity,MAP_WORKER_MAX_AFFINITY);
	if(affinity=="")
		return (["ok":0,"code":"invalid_affinity"]);
	int room_weight = max(1,weight || affinity_room_weights[affinity] || 1);
	key = worker_state_lock->lock();
	current = affinity_assignments[affinity];
	if(!force && mappingp(current) &&
	   worker_alive_unlocked(worker_nodes[(string)current["worker_id"]],now)){
		mapping result = copy_value(current);
		result["ok"] = 1;
		result["sticky"] = 1;
		result["placement_generation"] = placement_generation;
		destruct(key);
		return result;
	}
	if(!mappingp(current) && sizeof(affinity_assignments)>=
	   MAP_WORKER_MAX_AFFINITIES){
		destruct(key);
		return (["ok":0,"code":"affinity_limit"]);
	}
	previous = mappingp(current) ? copy_value(current) : 0;
	previous_generation = placement_generation;
	if(force>1)
		worker_id = choose_catalog_worker_unlocked(affinity,room_weight,now);
	else
		worker_id = choose_worker_unlocked(affinity,room_weight,now);
	if(worker_id==""){
		destruct(key);
		return (["ok":0,"code":"no_healthy_worker"]);
	}
	int epoch = mappingp(current) ? (int)current["epoch"]+1 : 1;
	affinity_assignments[affinity] = ([
		"affinity":affinity,
		"worker_id":worker_id,
		"epoch":epoch,
		"weight":room_weight,
		"assigned_at":now,
	]);
	if(force>1)
		catalog_rebalance_pending[affinity] = 0;
	placement_generation++;
	current = copy_value(affinity_assignments[affinity]);
	current["ok"] = 1;
	current["sticky"] = 0;
	current["placement_generation"] = placement_generation;
	installed = copy_value(affinity_assignments[affinity]);
	installed_generation = placement_generation;
	destruct(key);
	// New routing authority is usable only after its exact owner/epoch is
	// durable. A coordinator crash must never forget a placement which already
	// allowed a worker to load a player's inventory.
	if(!persist_control_plane()){
		key = worker_state_lock->lock();
		mapping latest = affinity_assignments[affinity];
		if(placement_generation==installed_generation && mappingp(latest) &&
		   (string)latest["worker_id"]==(string)installed["worker_id"] &&
		   (int)latest["epoch"]==(int)installed["epoch"]){
			if(mappingp(previous))
				affinity_assignments[affinity] = previous;
			else
				m_delete(affinity_assignments,affinity);
			placement_generation = previous_generation;
		}
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return current;
}

mapping(string:mixed) query_affinity_assignment(string affinity)
{
	object key;
	mapping result;
	affinity = normalize_token(affinity,MAP_WORKER_MAX_AFFINITY);
	if(affinity=="")
		return (["ok":0,"code":"invalid_affinity"]);
	key = worker_state_lock->lock();
	result = affinity_assignments[affinity];
	if(mappingp(result))
		result = copy_value(result);
	destruct(key);
	if(!mappingp(result))
		return (["ok":0,"code":"unassigned"]);
	result["ok"] = 1;
	return result;
}

mapping(string:mixed) assign_room(string room_path,void|string instance_key)
{
	string affinity = query_affinity_key(room_path,instance_key);
	mapping weight_info;
	if(affinity=="")
		return (["ok":0,"code":"invalid_room"]);
	weight_info = query_affinity_weight_info(affinity);
	return assign_affinity(affinity,
		(int)(weight_info["effective_weight"] || 1),0);
}

private void load_room_catalog()
{
	array(string)|zero blocks = get_dir(ROOT+"/gamelib/d");
	if(!arrayp(blocks))
		return;
	foreach(blocks,string block){
		string normalized = normalize_token(block,64);
		array(string)|zero files;
		int count = 0;
		if(normalized=="" || !Stdio.is_dir(ROOT+"/gamelib/d/"+block))
			continue;
		files = get_dir(ROOT+"/gamelib/d/"+block);
		// S1 has several stable placement groups rather than one top-level
		// affinity. Register every group with its real static-room weight so
		// cold-start bin packing and later heat observations can balance it.
		if(normalized=="illusion_s1" && arrayp(files)){
			foreach(files,string one){
				string affinity;
				if(!Stdio.is_file(ROOT+"/gamelib/d/"+block+"/"+one))
					continue;
				affinity = query_affinity_key(
					"/gamelib/d/"+block+"/"+one,"");
				if(affinity!="")
					affinity_room_weights[affinity]++;
			}
			continue;
		}
		if(arrayp(files)){
			foreach(files,string one)
				if(Stdio.is_file(ROOT+"/gamelib/d/"+block+"/"+one))
					count++;
		}
		affinity_room_weights[normalized] = max(1,count);
	}
}

/** Cold-start bin packing for all top-level maps. Existing live placements stay sticky. */
mapping(string:mixed) assign_catalog(void|int force)
{
	array(string) affinities = sort(indices(affinity_room_weights));
	mapping(string:int) effective_weights = ([]);
	int assigned;
	array(mapping(string:mixed)) failures = ({});
	{
		object key = worker_state_lock->lock();
		foreach(affinities,string affinity)
			effective_weights[affinity] =
				affinity_effective_weight_unlocked(affinity);
		if(force)
			foreach(affinities,string affinity)
				catalog_rebalance_pending[affinity] = 1;
		destruct(key);
	}
	// Largest effective maps first keeps real player hotspots apart.
	sort(map(affinities,lambda(string affinity){
		return -effective_weights[affinity];
	}),affinities);
	foreach(affinities,string affinity){
		mapping result = assign_affinity(affinity,
			effective_weights[affinity],force ? 2 : 0);
		if((int)result["ok"])
			assigned++;
		else
			failures += ({result});
	}
	{
		object key = worker_state_lock->lock();
		catalog_rebalance_pending = (<>);
		destruct(key);
	}
	if(!sizeof(failures)){
		object key = worker_state_lock->lock();
		int current_worker_count;
		foreach(values(worker_nodes),mapping node)
			if(worker_alive_unlocked(node,time()))
				current_worker_count++;
		placement_topology_worker_count = current_worker_count;
		destruct(key);
		if(current_worker_count<1 || !persist_control_plane())
			failures += ({(["ok":0,"code":"topology_persist_failed"])});
	}
	return (["ok":sizeof(failures)==0,"assigned":assigned,
		"failed":failures,"catalog_size":sizeof(affinities),
		"placement_generation":placement_generation,
		"placement_topology_worker_count":placement_topology_worker_count]);
}

int placement_topology_requires_rebalance()
{
	object key = worker_state_lock->lock();
	int current_worker_count;
	int previous_worker_count = placement_topology_worker_count;
	foreach(values(worker_nodes),mapping node)
		if(worker_alive_unlocked(node,time()))
			current_worker_count++;
	destruct(key);
	return previous_worker_count>0 &&
		current_worker_count!=previous_worker_count;
}

mapping(string:mixed) acquire_player_lease(string userid,string worker_id,
	string affinity,void|int expected_epoch)
{
	object key;
	mapping lease;
	mapping previous_lease;
	int now = time();
	userid = normalize_userid(userid);
	worker_id = normalize_worker_id(worker_id);
	affinity = normalize_token(affinity,MAP_WORKER_MAX_AFFINITY);
	if(userid=="" || worker_id=="" || affinity=="")
		return (["ok":0,"code":"invalid_lease"]);
	{
		object worker_key = worker_state_lock->lock();
		int registered = worker_registered_unlocked(worker_id) &&
			worker_alive_unlocked(worker_nodes[worker_id],now);
		destruct(worker_key);
		if(!registered)
			return (["ok":0,"code":"worker_unavailable"]);
	}
	key = player_lease_lock->lock();
	lease = player_leases[userid];
	previous_lease = mappingp(lease) ? copy_value(lease) : 0;
	string pending_arrival = "";
	if(mappingp(lease) && (string)lease["state"]=="active" &&
	   (string)lease["worker_id"]==worker_id &&
	   (string)lease["affinity"]==affinity &&
	   (int)lease["arrival_epoch"]==(int)lease["epoch"]){
		pending_arrival = normalize_room_location(
			(string)lease["arrival_room_path"]);
		if(pending_arrival!="" &&
		   !room_matches_affinity(pending_arrival,affinity))
			pending_arrival = "";
	}
	if(mappingp(lease) && (string)lease["state"]=="frozen"){
		destruct(key);
		return (["ok":0,"code":"lease_frozen","owner":lease["worker_id"],
			"epoch":lease["epoch"]]);
	}
	// Expiry is not proof that the old process stopped mutating the player: a
	// command can outlive both HTTP and lease timeouts. Cross-worker takeover
	// therefore requires the gateway's explicit all-worker inventory recovery;
	// an ordinary acquire may only reopen the same logical worker owner.
	if(mappingp(lease) && (string)lease["worker_id"]!=worker_id){
		destruct(key);
		return (["ok":0,"code":"lease_owned","owner":lease["worker_id"],
			"epoch":lease["epoch"]]);
	}
	if(expected_epoch && mappingp(lease) &&
	   (int)lease["epoch"]!=expected_epoch){
		destruct(key);
		return (["ok":0,"code":"stale_lease","epoch":lease["epoch"]]);
	}
	if(!mappingp(lease) && sizeof(player_leases)>=MAP_WORKER_MAX_PLAYER_LEASES){
		destruct(key);
		return (["ok":0,"code":"player_lease_limit"]);
	}
	int epoch = mappingp(lease) ? (int)lease["epoch"] : 0;
	if(!mappingp(lease) || (string)lease["worker_id"]!=worker_id ||
	   (int)lease["expires_at"]<now)
		epoch++;
	lease = ([
		"userid":userid,
		"worker_id":worker_id,
		"affinity":affinity,
		"epoch":epoch,
		"state":"active",
		"expires_at":now+MAP_WORKER_PLAYER_LEASE_TTL,
		"updated_at":now,
	]);
	// A committed arrival is a durable movement capability, not an ordinary
	// lease heartbeat field. Reopening the same expired owner advances the epoch
	// and must re-sign that exact room for the new epoch instead of dropping it.
	if(pending_arrival!=""){
		lease["arrival_room_path"] = pending_arrival;
		lease["arrival_epoch"] = epoch;
	}
	player_leases[userid] = lease;
	lease = copy_value(lease);
	lease["ok"] = 1;
	destruct(key);
	// A lease is the equipment single-owner fence. Never let the gateway load a
	// character until the owner and epoch survive coordinator restart.
	if(!persist_control_plane()){
		key = player_lease_lock->lock();
		mapping current = player_leases[userid];
		if(mappingp(current) && (string)current["worker_id"]==worker_id &&
		   (int)current["epoch"]==epoch){
			if(mappingp(previous_lease))
				player_leases[userid] = previous_lease;
			else
				m_delete(player_leases,userid);
		}
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return lease;
}

mapping(string:mixed) renew_player_lease(string userid,string worker_id,int epoch)
{
	object key;
	mapping lease;
	userid = normalize_userid(userid);
	worker_id = normalize_worker_id(worker_id);
	if(!worker_available(worker_id))
		return (["ok":0,"code":"worker_unavailable"]);
	key = player_lease_lock->lock();
	lease = player_leases[userid];
	if(!mappingp(lease) || (string)lease["worker_id"]!=worker_id ||
	   (int)lease["epoch"]!=epoch || (string)lease["state"]!="active"){
		destruct(key);
		return (["ok":0,"code":"stale_lease"]);
	}
	lease["expires_at"] = time()+MAP_WORKER_PLAYER_LEASE_TTL;
	lease["updated_at"] = time();
	destruct(key);
	schedule_control_persist();
	return (["ok":1,"epoch":epoch]);
}

/**
 * Renew one bounded page of live-player leases after an exact worker
 * generation heartbeat.  The whole page is validated before any lease is
 * touched: one stale local copy therefore withholds the worker control
 * heartbeat instead of silently keeping a possible duplicate alive.
 *
 * Frozen leases are valid only while the source object is being saved for a
 * prepared handoff.  They are verified but never extended here; the handoff
 * timeout remains authoritative.  Persistence is deliberately coalesced by
 * schedule_control_persist(), so a heartbeat page is not one disk rewrite per
 * player.  Expired leases remain fencing tombstones and cannot be stolen by a
 * different worker.
 */
mapping(string:mixed) renew_player_leases_batch(string worker_id,
	int generation,array entries)
{
	object worker_key;
	object lease_key;
	multiset(string) seen = (<>);
	array(mapping(string:mixed)) normalized = ({});
	int now = time();
	int renewed;
	int frozen;
	worker_id = normalize_worker_id(worker_id);
	if(worker_id=="" || generation<1 || !arrayp(entries) ||
	   !sizeof(entries) || sizeof(entries)>128)
		return (["ok":0,"code":"invalid_lease_batch"]);
	worker_key = worker_state_lock->lock();
	mapping node = worker_nodes[worker_id];
	if(!mappingp(node) || (int)node["generation"]!=generation ||
	   !worker_alive_unlocked(node,now)){
		destruct(worker_key);
		return (["ok":0,"code":"stale_generation"]);
	}
	destruct(worker_key);
	foreach(entries,mixed raw){
		string userid;
		string affinity;
		int epoch;
		if(!mappingp(raw))
			return (["ok":0,"code":"invalid_lease_batch_entry"]);
		userid = normalize_userid((string)raw["userid"]);
		affinity = normalize_token((string)raw["affinity"],
			MAP_WORKER_MAX_AFFINITY);
		epoch = (int)raw["epoch"];
		if(userid=="" || userid!=(string)raw["userid"] ||
		   affinity=="" || affinity!=(string)raw["affinity"] ||
		   epoch<1 || seen[userid])
			return (["ok":0,"code":"invalid_lease_batch_entry"]);
		seen[userid] = 1;
		normalized += ({(["userid":userid,"affinity":affinity,
			"epoch":epoch])});
	}
	lease_key = player_lease_lock->lock();
	// Validate the complete page first so a partial renewal cannot disguise a
	// stale copy later in the same authenticated worker inventory.
	foreach(normalized,mapping entry){
		mapping lease = player_leases[(string)entry["userid"]];
		if(!mappingp(lease) || (string)lease["worker_id"]!=worker_id ||
		   (int)lease["epoch"]!=(int)entry["epoch"] ||
		   (string)lease["affinity"]!=(string)entry["affinity"] ||
		   !has_value(({"active","frozen"}),(string)lease["state"])){
			destruct(lease_key);
			return (["ok":0,"code":"stale_lease",
				"userid":entry["userid"]]);
		}
	}
	foreach(normalized,mapping entry){
		mapping lease = player_leases[(string)entry["userid"]];
		if((string)lease["state"]=="active"){
			lease["expires_at"] = now+MAP_WORKER_PLAYER_LEASE_TTL;
			lease["updated_at"] = now;
			renewed++;
		}
		else
			frozen++;
	}
	destruct(lease_key);
	schedule_control_persist();
	return (["ok":1,"renewed":renewed,"verified_frozen":frozen,
		"count":sizeof(normalized)]);
}

/**
 * Record an already completed same-worker room transition. This is not a
 * migration and never changes the epoch: the exact live owner must hold both
 * the player lease and the target affinity assignment.
 */
mapping(string:mixed) rebind_player_lease(string userid,string worker_id,
	int epoch,string affinity)
{
	object worker_key;
	object lease_key;
	mapping assignment;
	mapping lease;
	string previous_affinity;
	int previous_expires_at;
	int previous_updated_at;
	userid = normalize_userid(userid);
	worker_id = normalize_worker_id(worker_id);
	affinity = normalize_token(affinity,MAP_WORKER_MAX_AFFINITY);
	if(userid=="" || worker_id=="" || epoch<1 || affinity=="")
		return (["ok":0,"code":"invalid_lease_rebind"]);
	worker_key = worker_state_lock->lock();
	assignment = affinity_assignments[affinity];
	if(!mappingp(assignment) ||
	   (string)assignment["worker_id"]!=worker_id ||
	   !worker_alive_unlocked(worker_nodes[worker_id],time())){
		destruct(worker_key);
		return (["ok":0,"code":"affinity_owner_mismatch"]);
	}
	destruct(worker_key);
	lease_key = player_lease_lock->lock();
	lease = player_leases[userid];
	if(!mappingp(lease) || (string)lease["state"]!="active" ||
	   (string)lease["worker_id"]!=worker_id ||
	   (int)lease["epoch"]!=epoch || (int)lease["expires_at"]<time()){
		destruct(lease_key);
		return (["ok":0,"code":"stale_lease"]);
	}
	previous_affinity = (string)lease["affinity"];
	previous_expires_at = (int)lease["expires_at"];
	previous_updated_at = (int)lease["updated_at"];
	lease["affinity"] = affinity;
	lease["expires_at"] = time()+MAP_WORKER_PLAYER_LEASE_TTL;
	lease["updated_at"] = time();
	destruct(lease_key);
	// The room move already happened. Never acknowledge its new fencing state
	// until the coordinator snapshot is durable, or restart could revive the
	// previous affinity while the worker holds the player in the new room.
	if(!persist_control_plane()){
		lease_key = player_lease_lock->lock();
		lease = player_leases[userid];
		if(mappingp(lease) && (string)lease["state"]=="active" &&
		   (string)lease["worker_id"]==worker_id &&
		   (int)lease["epoch"]==epoch &&
		   (string)lease["affinity"]==affinity){
			lease["affinity"] = previous_affinity;
			lease["expires_at"] = previous_expires_at;
			lease["updated_at"] = previous_updated_at;
		}
		destruct(lease_key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return (["ok":1,"userid":userid,"worker_id":worker_id,
		"epoch":epoch,"affinity":affinity]);
}

/** Rebuild coordinator leases only after the gateway inventories all workers. */
mapping(string:mixed) recover_player_lease(string userid,string worker_id,
	string affinity)
{
	object key;
	mapping lease;
	mapping previous_lease;
	int now = time();
	userid = normalize_userid(userid);
	worker_id = normalize_worker_id(worker_id);
	affinity = normalize_token(affinity,MAP_WORKER_MAX_AFFINITY);
	if(userid=="" || worker_id=="" || affinity=="" ||
	   !worker_available(worker_id))
		return (["ok":0,"code":"invalid_recovery"]);
	key = player_lease_lock->lock();
	lease = player_leases[userid];
	previous_lease = mappingp(lease) ? copy_value(lease) : 0;
	if(!mappingp(lease) && sizeof(player_leases)>=MAP_WORKER_MAX_PLAYER_LEASES){
		destruct(key);
		return (["ok":0,"code":"player_lease_limit"]);
	}
	int epoch = mappingp(lease) ? (int)lease["epoch"]+1 : 1;
	player_leases[userid] = ([
		"userid":userid,"worker_id":worker_id,"affinity":affinity,
		"epoch":epoch,"state":"active",
		"expires_at":now+MAP_WORKER_PLAYER_LEASE_TTL,"updated_at":now,
		"recovered_at":now,
	]);
	lease = copy_value(player_leases[userid]);
	lease["ok"] = 1;
	destruct(key);
	// Inventory recovery is also an ownership grant. Do not resume routing until
	// the recovered epoch is durable.
	if(!persist_control_plane()){
		key = player_lease_lock->lock();
		mapping current = player_leases[userid];
		if(mappingp(current) && (string)current["worker_id"]==worker_id &&
		   (int)current["epoch"]==epoch){
			if(mappingp(previous_lease))
				player_leases[userid] = previous_lease;
			else
				m_delete(player_leases,userid);
		}
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return lease;
}

/**
 * A lease tombstone may be removed only after the singleton gateway has paused
 * routing, waited for zero in-flight requests and inventoried every worker.
 * The live userid set is uploaded in bounded chunks so the internal RPC never
 * exceeds the HTTP body limit.
 */
mapping(string:mixed) begin_lease_reconciliation(string reconciliation_id)
{
	object key;
	reconciliation_id = normalize_token(reconciliation_id,96);
	if(reconciliation_id=="")
		return (["ok":0,"code":"invalid_reconciliation"]);
	key = player_lease_lock->lock();
	lease_reconciliation_id = reconciliation_id;
	lease_reconciliation_live_users = (<>);
	lease_reconciliation_expires_at = time()+60;
	destruct(key);
	return (["ok":1,"reconciliation_id":reconciliation_id]);
}

mapping(string:mixed) add_lease_reconciliation_users(string reconciliation_id,
	array users)
{
	object key;
	array(string) normalized = ({});
	reconciliation_id = normalize_token(reconciliation_id,96);
	if(reconciliation_id=="" || !arrayp(users) || sizeof(users)>500)
		return (["ok":0,"code":"invalid_reconciliation_chunk"]);
	foreach(users,mixed raw_user){
		string userid = stringp(raw_user) ? normalize_userid((string)raw_user) : "";
		if(userid=="" || userid!=(string)raw_user)
			return (["ok":0,"code":"invalid_reconciliation_user"]);
		normalized += ({userid});
	}
	key = player_lease_lock->lock();
	if(lease_reconciliation_id!=reconciliation_id ||
	   lease_reconciliation_expires_at<time()){
		destruct(key);
		return (["ok":0,"code":"stale_reconciliation"]);
	}
	foreach(normalized,string userid)
		lease_reconciliation_live_users[userid] = 1;
	if(sizeof(lease_reconciliation_live_users)>MAP_WORKER_MAX_PLAYER_LEASES){
		lease_reconciliation_id = "";
		lease_reconciliation_live_users = (<>);
		lease_reconciliation_expires_at = 0;
		destruct(key);
		return (["ok":0,"code":"reconciliation_limit"]);
	}
	int live_count = sizeof(lease_reconciliation_live_users);
	destruct(key);
	return (["ok":1,"live_users":live_count]);
}

mapping(string:mixed) commit_lease_reconciliation(string reconciliation_id)
{
	object lease_key;
	object worker_key;
	mapping(string:mapping(string:mixed)) removed_leases = ([]);
	mapping(string:mapping(string:mixed)) removed_handoffs = ([]);
	mapping(string:mapping(string:mixed)) removed_assignments = ([]);
	multiset(string) referenced_affinities = (<>);
	int previous_generation;
	int next_generation;
	int now = time();
	reconciliation_id = normalize_token(reconciliation_id,96);
	lease_key = player_lease_lock->lock();
	if(reconciliation_id=="" || lease_reconciliation_id!=reconciliation_id ||
	   lease_reconciliation_expires_at<now){
		destruct(lease_key);
		return (["ok":0,"code":"stale_reconciliation"]);
	}
	foreach(indices(player_leases),string userid){
		mapping lease = player_leases[userid];
		if((string)lease["state"]=="active" &&
		   (int)lease["expires_at"]<now &&
		   !lease_reconciliation_live_users[userid] &&
		   normalize_room_location((string)lease["arrival_room_path"])==""){
			removed_leases[userid] = copy_value(lease);
			m_delete(player_leases,userid);
		}
	}
	foreach(indices(handoffs),string request_id){
		mapping handoff = handoffs[request_id];
		if(removed_leases[(string)handoff["userid"]] &&
		   (string)handoff["state"]!="prepared"){
			removed_handoffs[request_id] = copy_value(handoff);
			m_delete(handoffs,request_id);
		}
	}
	foreach(values(player_leases),mapping lease)
		referenced_affinities[(string)lease["affinity"]] = 1;
	foreach(values(handoffs),mapping handoff)
		referenced_affinities[(string)handoff["target_affinity"]] = 1;
	lease_reconciliation_id = "";
	lease_reconciliation_live_users = (<>);
	lease_reconciliation_expires_at = 0;
	destruct(lease_key);

	worker_key = worker_state_lock->lock();
	previous_generation = placement_generation;
	foreach(indices(affinity_assignments),string affinity)
		if(has_prefix(affinity,"session:") &&
		   !referenced_affinities[affinity]){
			removed_assignments[affinity] =
				copy_value(affinity_assignments[affinity]);
			m_delete(affinity_assignments,affinity);
		}
	if(sizeof(removed_assignments))
		placement_generation++;
	next_generation = placement_generation;
	destruct(worker_key);

	if((sizeof(removed_leases) || sizeof(removed_handoffs) ||
	    sizeof(removed_assignments)) && !persist_control_plane()){
		lease_key = player_lease_lock->lock();
		foreach(indices(removed_leases),string userid)
			if(!player_leases[userid])
				player_leases[userid] = removed_leases[userid];
		foreach(indices(removed_handoffs),string request_id)
			if(!handoffs[request_id])
				handoffs[request_id] = removed_handoffs[request_id];
		destruct(lease_key);
		worker_key = worker_state_lock->lock();
		foreach(indices(removed_assignments),string affinity)
			if(!affinity_assignments[affinity])
				affinity_assignments[affinity] = removed_assignments[affinity];
		if(placement_generation==next_generation)
			placement_generation = previous_generation;
		destruct(worker_key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return (["ok":1,"pruned_leases":sizeof(removed_leases),
		"pruned_handoffs":sizeof(removed_handoffs),
		"pruned_assignments":sizeof(removed_assignments),
		"placement_generation":next_generation]);
}

mapping(string:mixed) query_player_route(string userid)
{
	object key;
	mapping lease;
	string handoff_request_id = "";
	userid = normalize_userid(userid);
	if(userid=="")
		return (["ok":0,"code":"invalid_userid"]);
	key = player_lease_lock->lock();
	lease = player_leases[userid];
	if(mappingp(lease)){
		lease = copy_value(lease);
		if((string)lease["state"]=="frozen"){
			foreach(indices(handoffs),string request_id){
				mapping handoff = handoffs[request_id];
				if((string)handoff["userid"]==userid &&
				   (string)handoff["state"]=="prepared" &&
				   (int)handoff["source_epoch"]==(int)lease["epoch"]){
					handoff_request_id = request_id;
					break;
				}
			}
		}
	}
	destruct(key);
	if(!mappingp(lease))
		return (["ok":0,"code":"lease_missing"]);
	if((int)lease["expires_at"]<time()){
		lease["ok"] = 0;
		lease["code"] = "lease_expired";
		lease["expired"] = 1;
		return lease;
	}
	lease["ok"] = 1;
	if(handoff_request_id!="")
		lease["handoff_request_id"] = handoff_request_id;
	return lease;
}

mapping(string:mixed) acknowledge_player_arrival(string userid,
	string worker_id,int epoch,string affinity)
{
	object key;
	mapping lease;
	userid = normalize_userid(userid);
	worker_id = normalize_worker_id(worker_id);
	affinity = normalize_token(affinity,MAP_WORKER_MAX_AFFINITY);
	key = player_lease_lock->lock();
	lease = player_leases[userid];
	if(!mappingp(lease) || (string)lease["state"]!="active" ||
	   (string)lease["worker_id"]!=worker_id || (int)lease["epoch"]!=epoch ||
	   (string)lease["affinity"]!=affinity ||
	   (int)lease["arrival_epoch"]!=epoch ||
	   normalize_room_location((string)lease["arrival_room_path"])==""){
		destruct(key);
		return (["ok":0,"code":"arrival_fence_failed"]);
	}
	m_delete(lease,"arrival_room_path");
	m_delete(lease,"arrival_epoch");
	lease["updated_at"] = time();
	destruct(key);
	schedule_control_persist();
	return (["ok":1,"userid":userid,"epoch":epoch]);
}

mapping(string:mixed) begin_handoff(string userid,string source_worker,
	int source_epoch,string target_affinity,string target_room_path,
	string request_id)
{
	object key;
	mapping lease;
	mapping existing;
	mapping previous_handoff;
	mapping assignment;
	string target_worker;
	int previous_updated_at;
	userid = normalize_userid(userid);
	source_worker = normalize_worker_id(source_worker);
	target_affinity = normalize_token(target_affinity,MAP_WORKER_MAX_AFFINITY);
	target_room_path = normalize_room_location(target_room_path);
	request_id = normalize_token(request_id,96);
	if(userid=="" || source_worker=="" || target_affinity=="" ||
	   target_room_path=="" ||
	   !room_matches_affinity(target_room_path,target_affinity) ||
	   request_id=="")
		return (["ok":0,"code":"invalid_handoff"]);
	assignment = assign_affinity(target_affinity,
		affinity_room_weights[target_affinity] || 1,0);
	if(!(int)assignment["ok"])
		return assignment;
	target_worker = (string)assignment["worker_id"];
	key = player_lease_lock->lock();
	existing = handoffs[request_id];
	if(mappingp(existing)){
		if((string)existing["userid"]!=userid ||
		   (string)existing["source_worker"]!=source_worker ||
		   (int)existing["source_epoch"]!=source_epoch ||
		   (string)existing["target_affinity"]!=target_affinity ||
		   (string)existing["target_room_path"]!=target_room_path){
			destruct(key);
			return (["ok":0,"code":"idempotency_conflict"]);
		}
		if((string)existing["state"]=="prepared" &&
		   (string)existing["target_worker"]!=target_worker){
			// Placement changed while this prepare was unresolved. Thaw the
			// source first; never retire it and then attempt a different target
			// under the old prepare record.
			destruct(key);
			mapping aborted = abort_handoff(request_id,source_worker);
			if(!(int)aborted["ok"])
				return aborted;
			return (["ok":0,"code":"handoff_retargeted"]);
		}
		if(has_value(({"committed","prepared"}),(string)existing["state"])){
			existing = copy_value(existing);
			existing["ok"] = 1;
			existing["replayed"] = 1;
			destruct(key);
			return existing;
		}
		if(!has_value(({"aborted","expired"}),(string)existing["state"])){
			destruct(key);
			return (["ok":0,"code":"invalid_handoff_state"]);
		}
		// A safe retry reuses the same idempotency key after the old prepare
		// was durably aborted/expired. The exact source lease is revalidated
		// below before it can be frozen again.
		previous_handoff = copy_value(existing);
		m_delete(handoffs,request_id);
	}
	lease = player_leases[userid];
	if(!mappingp(lease) || (string)lease["worker_id"]!=source_worker ||
	   (int)lease["epoch"]!=source_epoch ||
	   (string)lease["state"]!="active" ||
	   (int)lease["expires_at"]<time()){
		if(mappingp(previous_handoff))
			handoffs[request_id] = previous_handoff;
		destruct(key);
		return (["ok":0,"code":"stale_source_lease"]);
	}
	if(target_worker==source_worker){
		if(mappingp(previous_handoff))
			handoffs[request_id] = previous_handoff;
		destruct(key);
		// The worker must complete the room move first and then call
		// rebind_player_lease synchronously. Preparing a handoff must not claim a
		// room transition which has not happened yet.
		return (["ok":1,"local":1,"worker_id":source_worker,
			"epoch":source_epoch,"affinity":target_affinity]);
	}
	if(sizeof(handoffs)>=MAP_WORKER_MAX_HANDOFFS){
		if(mappingp(previous_handoff))
			handoffs[request_id] = previous_handoff;
		destruct(key);
		return (["ok":0,"code":"handoff_limit"]);
	}
	lease["state"] = "frozen";
	previous_updated_at = (int)lease["updated_at"];
	lease["updated_at"] = time();
	handoffs[request_id] = ([
		"request_id":request_id,
		"userid":userid,
		"source_worker":source_worker,
		"target_worker":target_worker,
		"source_epoch":source_epoch,
		"target_epoch":source_epoch+1,
		"target_affinity":target_affinity,
		"target_room_path":target_room_path,
		"state":"prepared",
		"created_at":time(),
		"expires_at":time()+MAP_WORKER_HANDOFF_TTL,
	]);
	existing = copy_value(handoffs[request_id]);
	existing["ok"] = 1;
	destruct(key);
	if(!persist_control_plane()){
		key = player_lease_lock->lock();
		mapping current_handoff = handoffs[request_id];
		mapping current_lease = player_leases[userid];
		if(mappingp(current_handoff) &&
		   (string)current_handoff["state"]=="prepared" &&
		   mappingp(current_lease) &&
		   (string)current_lease["state"]=="frozen" &&
		   (int)current_lease["epoch"]==source_epoch){
			current_lease["state"] = "active";
			current_lease["updated_at"] = previous_updated_at;
			if(mappingp(previous_handoff))
				handoffs[request_id] = previous_handoff;
			else
				m_delete(handoffs,request_id);
		}
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return existing;
}

mapping(string:mixed) commit_handoff(string request_id,string target_worker)
{
	object key;
	object worker_key;
	mapping handoff;
	mapping lease;
	mapping target_assignment;
	mapping original_handoff;
	mapping original_lease;
	request_id = normalize_token(request_id,96);
	target_worker = normalize_worker_id(target_worker);
	if(request_id=="" || target_worker=="")
		return (["ok":0,"code":"target_unavailable"]);
	key = player_lease_lock->lock();
	handoff = handoffs[request_id];
	if(!mappingp(handoff) || (string)handoff["target_worker"]!=target_worker){
		destruct(key);
		return (["ok":0,"code":"unknown_handoff"]);
	}
	if((string)handoff["state"]=="committed"){
		handoff = copy_value(handoff);
		handoff["ok"] = 1;
		handoff["replayed"] = 1;
		destruct(key);
		if(!persist_control_plane())
			return (["ok":0,"code":"control_persist_failed"]);
		return handoff;
	}
	worker_key = worker_state_lock->lock();
	target_assignment = affinity_assignments[
		(string)handoff["target_affinity"]];
	if(!worker_alive_unlocked(worker_nodes[target_worker],time())){
		destruct(worker_key);
		destruct(key);
		return (["ok":0,"code":"target_unavailable"]);
	}
	if(!mappingp(target_assignment) ||
	   (string)target_assignment["worker_id"]!=target_worker){
		destruct(worker_key);
		destruct(key);
		return (["ok":0,"code":"target_affinity_moved"]);
	}
	destruct(worker_key);
	if((string)handoff["state"]!="prepared" ||
	   (int)handoff["expires_at"]<time()){
		destruct(key);
		return (["ok":0,"code":"handoff_expired"]);
	}
	lease = player_leases[(string)handoff["userid"]];
	if(!mappingp(lease) || (int)lease["epoch"]!=(int)handoff["source_epoch"] ||
	   (string)lease["worker_id"]!=(string)handoff["source_worker"] ||
	   (string)lease["state"]!="frozen"){
		destruct(key);
		return (["ok":0,"code":"handoff_fence_failed"]);
	}
	original_lease = copy_value(lease);
	original_handoff = copy_value(handoff);
	lease["worker_id"] = target_worker;
	lease["affinity"] = handoff["target_affinity"];
	lease["epoch"] = handoff["target_epoch"];
	lease["state"] = "active";
	lease["arrival_room_path"] = handoff["target_room_path"];
	lease["arrival_epoch"] = handoff["target_epoch"];
	lease["expires_at"] = time()+MAP_WORKER_PLAYER_LEASE_TTL;
	lease["updated_at"] = time();
	handoff["state"] = "committed";
	handoff["committed_at"] = time();
	handoff = copy_value(handoff);
	handoff["ok"] = 1;
	destruct(key);
	if(!persist_control_plane()){
		key = player_lease_lock->lock();
		mapping current_handoff = handoffs[request_id];
		mapping current_lease = player_leases[(string)original_handoff["userid"]];
		if(mappingp(current_handoff) && mappingp(current_lease) &&
		   (string)current_handoff["state"]=="committed" &&
		   (int)current_lease["epoch"]==(int)original_handoff["target_epoch"]){
			player_leases[(string)original_handoff["userid"]] = original_lease;
			handoffs[request_id] = original_handoff;
		}
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return handoff;
}

mapping(string:mixed) abort_handoff(string request_id,string source_worker)
{
	object key;
	mapping handoff;
	mapping lease;
	mapping original_handoff;
	mapping original_lease;
	request_id = normalize_token(request_id,96);
	source_worker = normalize_worker_id(source_worker);
	key = player_lease_lock->lock();
	handoff = handoffs[request_id];
	if(!mappingp(handoff) || (string)handoff["source_worker"]!=source_worker){
		destruct(key);
		return (["ok":0,"code":"cannot_abort"]);
	}
	if((string)handoff["state"]=="aborted"){
		destruct(key);
		if(!persist_control_plane())
			return (["ok":0,"code":"control_persist_failed"]);
		return (["ok":1,"state":"aborted","replayed":1]);
	}
	if((string)handoff["state"]!="prepared"){
		destruct(key);
		return (["ok":0,"code":"cannot_abort"]);
	}
	lease = player_leases[(string)handoff["userid"]];
	original_handoff = copy_value(handoff);
	original_lease = mappingp(lease) ? copy_value(lease) : 0;
	if(mappingp(lease) && (string)lease["worker_id"]==source_worker &&
	   (int)lease["epoch"]==(int)handoff["source_epoch"]){
		lease["state"] = "active";
		lease["expires_at"] = time()+MAP_WORKER_PLAYER_LEASE_TTL;
		lease["updated_at"] = time();
	}
	handoff["state"] = "aborted";
	handoff["aborted_at"] = time();
	destruct(key);
	if(!persist_control_plane()){
		key = player_lease_lock->lock();
		mapping current_handoff = handoffs[request_id];
		mapping current_lease = player_leases[(string)original_handoff["userid"]];
		if(mappingp(current_handoff) &&
		   (string)current_handoff["state"]=="aborted"){
			handoffs[request_id] = original_handoff;
			if(mappingp(original_lease) && mappingp(current_lease) &&
			   (int)current_lease["epoch"]==(int)original_lease["epoch"])
				player_leases[(string)original_handoff["userid"]] = original_lease;
		}
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return (["ok":1,"state":"aborted"]);
}

/**
 * Retire a committed arrival only after the gateway has paused routing and
 * inventoried every worker. The exact epoch/worker/room tuple prevents an old
 * recovery pass from deleting a newer player owner.
 */
mapping(string:mixed) retire_abandoned_player_arrival(string userid,
	string worker_id,int epoch,string room_path)
{
	object key;
	mapping lease;
	mapping original_lease;
	mapping(string:mapping(string:mixed)) removed_handoffs = ([]);
	userid = normalize_userid(userid);
	worker_id = normalize_worker_id(worker_id);
	room_path = normalize_room_location(room_path);
	if(userid=="" || worker_id=="" || epoch<1 || room_path=="")
		return (["ok":0,"code":"invalid_abandoned_arrival"]);
	key = player_lease_lock->lock();
	lease = player_leases[userid];
	if(!mappingp(lease) || (string)lease["state"]!="active" ||
	   (string)lease["worker_id"]!=worker_id ||
	   (int)lease["epoch"]!=epoch ||
	   normalize_room_location((string)lease["arrival_room_path"])!=room_path){
		destruct(key);
		return (["ok":0,"code":"stale_abandoned_arrival"]);
	}
	original_lease = copy_value(lease);
	foreach(indices(handoffs),string request_id){
		mapping handoff = handoffs[request_id];
		if((string)handoff["state"]=="committed" &&
		   (string)handoff["userid"]==userid &&
		   (string)handoff["target_worker"]==worker_id &&
		   (int)handoff["target_epoch"]==epoch){
			removed_handoffs[request_id] = copy_value(handoff);
			m_delete(handoffs,request_id);
		}
	}
	m_delete(player_leases,userid);
	destruct(key);
	if(!persist_control_plane()){
		key = player_lease_lock->lock();
		if(!mappingp(player_leases[userid])){
			player_leases[userid] = original_lease;
			foreach(indices(removed_handoffs),string request_id)
				if(!mappingp(handoffs[request_id]))
					handoffs[request_id] = removed_handoffs[request_id];
		}
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return (["ok":1,"userid":userid,"worker_id":worker_id,
		"epoch":epoch,"removed_handoffs":sizeof(removed_handoffs)]);
}

private int valid_payload(mapping payload)
{
	string encoded;
	mixed err;
	if(!mappingp(payload))
		return 0;
	err = catch { encoded = Standards.JSON.encode(payload); };
	return !err && sizeof(encoded)<=MAP_WORKER_MAX_PAYLOAD_BYTES;
}

private int valid_hex_identifier(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	for(int i=0;i<sizeof(value);i++){
		int one = value[i];
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

private int valid_escrow_item_descriptor(mapping item)
{
	string encoded;
	mixed err;
	err = catch { encoded = Standards.JSON.encode(item); };
	return !err && sizeof(encoded)<=MAP_WORKER_MAX_ESCROW_BYTES &&
		valid_hex_identifier((string)item["item_id"]) &&
		valid_hex_identifier((string)item["digest"]) &&
		(int)item["amount"]>=1 && (int)item["amount"]<=1000000;
}

/** Durable transport envelope. Consumers ACK by id; duplicate publish is safe. */
mapping(string:mixed) publish_envelope(string message_id,string kind,
	string source_user,string target_user,mapping(string:mixed) payload)
{
	object key;
	mapping message;
	message_id = normalize_token(message_id,96);
	kind = normalize_token(kind,48);
	source_user = normalize_userid(source_user);
	target_user = normalize_userid(target_user);
	if(message_id=="" || kind=="" || target_user=="" || !valid_payload(payload))
		return (["ok":0,"code":"invalid_envelope"]);
	key = envelope_lock->lock();
	message = envelopes[message_id];
	if(mappingp(message)){
		if((string)message["kind"]!=kind ||
		   (string)message["source_user"]!=source_user ||
		   (string)message["target_user"]!=target_user ||
		   !equal(message["payload"],payload)){
			destruct(key);
			return (["ok":0,"code":"idempotency_conflict"]);
		}
		message = copy_value(message);
		message["ok"] = 1;
		message["replayed"] = 1;
		destruct(key);
		return message;
	}
	if(sizeof(envelopes)>=MAP_WORKER_MAX_ENVELOPES){
		destruct(key);
		return (["ok":0,"code":"envelope_limit"]);
	}
	envelopes[message_id] = ([
		"message_id":message_id,"kind":kind,"source_user":source_user,
		"target_user":target_user,"payload":copy_value(payload),
		"state":"pending","attempts":0,"delivery_epoch":0,
		"created_at":time(),
		"expires_at":time()+MAP_WORKER_ENVELOPE_TTL,
	]);
	message = copy_value(envelopes[message_id]);
	message["ok"] = 1;
	destruct(key);
	if(!persist_control_plane()){
		key = envelope_lock->lock();
		mapping current = envelopes[message_id];
		if(mappingp(current) && (string)current["state"]=="pending" &&
		   (string)current["target_user"]==target_user)
			m_delete(envelopes,message_id);
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return message;
}

array(mapping(string:mixed)) poll_envelopes(string target_user,void|int limit)
{
	object key;
	array(mapping(string:mixed)) result = ({});
	int max_items = max(1,min(100,limit || 20));
	target_user = normalize_userid(target_user);
	if(target_user=="")
		return result;
	key = envelope_lock->lock();
	foreach(sort(indices(envelopes)),string message_id){
		mapping message = envelopes[message_id];
		if(sizeof(result)>=max_items)
			break;
		if((string)message["target_user"]!=target_user ||
		   !has_value(({"pending","delivering"}),(string)message["state"]) ||
		   ((string)message["state"]=="delivering" &&
		    (int)message["delivery_expires_at"]>=time()) ||
		   (int)message["expires_at"]<time())
			continue;
		message["attempts"] = (int)message["attempts"]+1;
		message["delivery_epoch"] = (int)message["delivery_epoch"]+1;
		message["state"] = "delivering";
		message["delivery_expires_at"] =
			time()+MAP_WORKER_DELIVERY_LEASE_TTL;
		message["last_delivery_at"] = time();
		result += ({copy_value(message)});
	}
	destruct(key);
	return result;
}

mapping(string:mixed) acknowledge_envelope(string message_id,string target_user,
	int delivery_epoch)
{
	object key;
	mapping message;
	mapping original_message;
	message_id = normalize_token(message_id,96);
	target_user = normalize_userid(target_user);
	key = envelope_lock->lock();
	message = envelopes[message_id];
	if(!mappingp(message) || (string)message["target_user"]!=target_user){
		destruct(key);
		return (["ok":0,"code":"unknown_envelope"]);
	}
	if((string)message["state"]=="acked"){
		if(delivery_epoch!=(int)message["delivery_epoch"]){
			destruct(key);
			return (["ok":0,"code":"stale_delivery"]);
		}
		destruct(key);
		return (["ok":1,"message_id":message_id,"replayed":1]);
	}
	if((string)message["state"]!="delivering" || delivery_epoch<1 ||
	   delivery_epoch!=(int)message["delivery_epoch"]){
		destruct(key);
		return (["ok":0,"code":"stale_delivery"]);
	}
	original_message = copy_value(message);
	message["state"] = "acked";
	message["acked_at"] = time();
	destruct(key);
	if(!persist_control_plane()){
		key = envelope_lock->lock();
		message = envelopes[message_id];
		if(mappingp(message) && (string)message["state"]=="acked" &&
		   (int)message["delivery_epoch"]==delivery_epoch)
			envelopes[message_id] = original_message;
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return (["ok":1,"message_id":message_id]);
}

/**
 * Escrow is metadata, not an item clone. The source worker must remove and
 * persist the item before mark_escrow_funded; the target applies it once and
 * ACKs with the same transaction id.
 */
mapping(string:mixed) create_escrow(string transaction_id,string from_user,
	string to_user,mapping(string:mixed) item_descriptor)
{
	object key;
	mapping tx;
	transaction_id = normalize_token(transaction_id,96);
	from_user = normalize_userid(from_user);
	to_user = normalize_userid(to_user);
	if(transaction_id=="" || from_user=="" || to_user=="" ||
	   from_user==to_user || !valid_escrow_item_descriptor(item_descriptor))
		return (["ok":0,"code":"invalid_escrow"]);
	key = envelope_lock->lock();
	tx = escrow_transactions[transaction_id];
	if(mappingp(tx)){
		if((string)tx["from_user"]!=from_user ||
		   (string)tx["to_user"]!=to_user ||
		   !equal(tx["item"],item_descriptor)){
			destruct(key);
			return (["ok":0,"code":"idempotency_conflict"]);
		}
		tx = copy_value(tx);
		tx["ok"] = 1;
		tx["replayed"] = 1;
		destruct(key);
		return tx;
	}
	if(sizeof(escrow_transactions)>=MAP_WORKER_MAX_ESCROWS){
		destruct(key);
		return (["ok":0,"code":"escrow_limit"]);
	}
	foreach(indices(escrow_transactions),string active_id){
		mapping active = escrow_transactions[active_id];
		if(has_value(({"reserved","funded"}),(string)active["state"]) &&
		   (string)active["item"]["item_id"]==
		   (string)item_descriptor["item_id"]){
			destruct(key);
			return (["ok":0,"code":"item_already_escrowed",
				"transaction_id":active_id]);
		}
	}
	escrow_transactions[transaction_id] = ([
		"transaction_id":transaction_id,"from_user":from_user,
		"to_user":to_user,"item":copy_value(item_descriptor),
		"state":"reserved","created_at":time(),
		"expires_at":time()+MAP_WORKER_ESCROW_RESERVATION_TTL,
	]);
	tx = copy_value(escrow_transactions[transaction_id]);
	tx["ok"] = 1;
	destruct(key);
	// An equipment reservation is not acknowledged until durable. Otherwise a
	// coordinator crash could forget it while the source still removes item.
	if(!persist_control_plane()){
		key = envelope_lock->lock();
		mapping current = escrow_transactions[transaction_id];
		if(mappingp(current) && (string)current["state"]=="reserved" &&
		   (string)current["item"]["item_id"]==
		   (string)item_descriptor["item_id"])
			m_delete(escrow_transactions,transaction_id);
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return tx;
}

mapping(string:mixed) advance_escrow(string transaction_id,string actor,
	string expected_state,string next_state,string proof_digest)
{
	object key;
	mapping tx;
	mapping original_tx;
	transaction_id = normalize_token(transaction_id,96);
	actor = normalize_userid(actor);
	proof_digest = lower_case(String.trim_all_whites(proof_digest || ""));
	if(transaction_id=="" || actor=="" ||
	   !valid_hex_identifier(proof_digest) ||
	   !has_value(({"reserved","funded"}),expected_state) ||
	   !has_value(({"funded","delivered","cancelled"}),next_state) ||
	   !((expected_state=="reserved" && next_state=="funded") ||
	     (expected_state=="reserved" && next_state=="cancelled") ||
	     (expected_state=="funded" && next_state=="delivered")))
		return (["ok":0,"code":"invalid_state"]);
	key = envelope_lock->lock();
	tx = escrow_transactions[transaction_id];
	if(!mappingp(tx)){
		destruct(key);
		return (["ok":0,"code":"unknown_escrow"]);
	}
	if((string)tx["item"]["digest"]!=proof_digest){
		destruct(key);
		return (["ok":0,"code":"item_digest_mismatch"]);
	}
	string required_actor = next_state=="delivered" ?
		(string)tx["to_user"] : (string)tx["from_user"];
	if(actor!=required_actor){
		destruct(key);
		return (["ok":0,"code":"escrow_fence_failed"]);
	}
	if((string)tx["state"]==next_state &&
	   (string)tx[next_state+"_by"]==actor){
		tx = copy_value(tx);
		tx["ok"] = 1;
		tx["replayed"] = 1;
		destruct(key);
		return tx;
	}
	if((string)tx["state"]!=expected_state){
		destruct(key);
		return (["ok":0,"code":"escrow_fence_failed"]);
	}
	original_tx = copy_value(tx);
	tx["state"] = next_state;
	tx[next_state+"_at"] = time();
	tx[next_state+"_by"] = actor;
	if(next_state=="funded")
		tx["expires_at"] = 0;
	else
		tx["expires_at"] = time()+MAP_WORKER_FINAL_STATE_TTL;
	tx = copy_value(tx);
	tx["ok"] = 1;
	destruct(key);
	if(!persist_control_plane()){
		key = envelope_lock->lock();
		mapping current = escrow_transactions[transaction_id];
		if(mappingp(current) && (string)current["state"]==next_state &&
		   (string)current[next_state+"_by"]==actor)
			escrow_transactions[transaction_id] = original_tx;
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return tx;
}

/** PK never spans two workers: both players are handed to one arena affinity. */
mapping(string:mixed) create_pk_session(string session_id,string first_user,
	string second_user)
{
	object key;
	mapping session;
	mapping assignment;
	string low_user;
	string high_user;
	string affinity;
	int replayed;
	session_id = normalize_token(session_id,96);
	first_user = normalize_userid(first_user);
	second_user = normalize_userid(second_user);
	if(session_id=="" || first_user=="" || second_user=="" ||
	   first_user==second_user)
		return (["ok":0,"code":"invalid_pk_session"]);
	low_user = first_user<second_user ? first_user : second_user;
	high_user = first_user<second_user ? second_user : first_user;
	affinity = "pk:"+stable_digest(low_user+"|"+high_user)[0..23];
	assignment = assign_affinity(affinity,10,0);
	if(!(int)assignment["ok"])
		return assignment;
	key = envelope_lock->lock();
	session = pk_sessions[session_id];
	replayed = mappingp(session);
	if(mappingp(session) &&
	   !(((string)session["first_user"]==first_user &&
	      (string)session["second_user"]==second_user) ||
	     ((string)session["first_user"]==second_user &&
	      (string)session["second_user"]==first_user))){
		destruct(key);
		return (["ok":0,"code":"idempotency_conflict"]);
	}
	if(!mappingp(session)){
		if(sizeof(pk_sessions)>=MAP_WORKER_MAX_PK_SESSIONS){
			destruct(key);
			return (["ok":0,"code":"pk_session_limit"]);
		}
		pk_sessions[session_id] = ([
			"session_id":session_id,"first_user":first_user,
			"second_user":second_user,"affinity":affinity,
			"worker_id":assignment["worker_id"],"state":"gathering",
			"created_at":time(),"expires_at":time()+MAP_WORKER_HANDOFF_TTL,
		]);
		session = pk_sessions[session_id];
	}
	session = copy_value(session);
	session["ok"] = 1;
	if(replayed)
		session["replayed"] = 1;
	destruct(key);
	if(!replayed && !persist_control_plane()){
		key = envelope_lock->lock();
		mapping current = pk_sessions[session_id];
		if(mappingp(current) && (string)current["state"]=="gathering" &&
		   (string)current["affinity"]==affinity)
			m_delete(pk_sessions,session_id);
		destruct(key);
		return (["ok":0,"code":"control_persist_failed"]);
	}
	return session;
}

mapping(string:mixed) rebalance_idle_affinities(string operator)
{
	mapping(string:int) active_affinities = ([]);
	array(string) affinities;
	int moved;
	int unchanged;
	int skipped;
	string now;
	if(!operator || MANAGERD->checkpower(operator)!="admin")
		return (["ok":0,"message":"需要管理员权限。"]);
	{
		object lease_key = player_lease_lock->lock();
		foreach(indices(player_leases),string userid){
			mapping lease = player_leases[userid];
			if(((string)lease["state"]=="active" &&
			    (int)lease["expires_at"]>=time()) ||
			   (string)lease["state"]=="frozen")
				active_affinities[(string)lease["affinity"]] = 1;
		}
		foreach(values(handoffs),mapping handoff)
			if((string)handoff["state"]=="prepared")
				active_affinities[(string)handoff["target_affinity"]] = 1;
		destruct(lease_key);
	}
	{
		object worker_key = worker_state_lock->lock();
		affinities = sort(indices(affinity_assignments));
		destruct(worker_key);
	}
	foreach(affinities,string affinity){
		if(active_affinities[affinity]){
			skipped++;
			continue;
		}
		mapping before = query_affinity_assignment(affinity);
		mapping after = assign_affinity(affinity,
			(int)before["weight"],1);
		if(!(int)after["ok"])
			skipped++;
		else if((string)before["worker_id"]!=(string)after["worker_id"])
			moved++;
		else
			unchanged++;
	}
	now = ctime(time());
	Stdio.append_file(ROOT+"/log/map_worker_admin.log",
		now[0..sizeof(now)-2]+" admin="+operator+
		" rebalance moved="+moved+" unchanged="+unchanged+
		" skipped="+skipped+"\n");
	return (["ok":1,"message":"仅空闲地图完成稳定重均衡。",
		"moved":moved,"unchanged":unchanged,"skipped_active":skipped]);
}

mapping(string:mixed) admin_set_worker_draining(string operator,
	string worker_id,int draining)
{
	mapping result;
	string now;
	if(!operator || MANAGERD->checkpower(operator)!="admin")
		return (["ok":0,"message":"需要管理员权限。"]);
	result = set_worker_draining(worker_id,draining);
	if(!(int)result["ok"])
		return (["ok":0,"message":"worker 不存在。"]);
	now = ctime(time());
	Stdio.append_file(ROOT+"/log/map_worker_admin.log",
		now[0..sizeof(now)-2]+" admin="+operator+
		" worker="+worker_id+" draining="+(draining ? "1" : "0")+"\n");
	return (["ok":1,"message":draining ?
		"worker 已进入排空状态；现有玩家不会被强制迁移。" :
		"worker 已恢复接收新地图。"]);
}

private void cleanup_expired_state()
{
	int now = time();
	int changed;
	if(node_role=="worker"){
		object local_key = local_route_lock->lock();
		foreach(indices(local_requests),string local_request_id){
			mapping local_request = local_requests[local_request_id];
			if((string)local_request["state"]=="done" &&
			   (int)local_request["expires_at"]<now){
				string local_userid = (string)local_request["userid"];
				if(local_userid!="" &&
				   local_running_request_by_user[local_userid]==local_request_id)
					m_delete(local_running_request_by_user,local_userid);
				string local_account =
					(string)local_request["account_owner"];
				if(local_account!="" &&
				   local_running_request_by_account[local_account]==
					local_request_id)
					m_delete(local_running_request_by_account,local_account);
				m_delete(local_requests,local_request_id);
			}
		}
		destruct(local_key);
		object social_key = local_social_lock->lock();
		int social_changed;
		foreach(indices(local_social_events),string event_id)
			if((int)local_social_events[event_id]["expires_at"]<now){
				mapping expired_event = local_social_events[event_id];
				if((string)expired_event["kind"]=="team_snapshot"){
					expired_event["created_at"] = now;
					expired_event["expires_at"] =
						now+MAP_WORKER_LOCAL_TEAM_DURABLE_TTL;
					expired_event["next_retry_at"] = 0;
				}
				else
					m_delete(local_social_events,event_id);
				social_changed = 1;
			}
		array(string) remaining_social_order = ({});
		foreach(local_social_event_order,string ordered_event_id)
			if(mappingp(local_social_events[ordered_event_id]))
				remaining_social_order += ({ordered_event_id});
		if(!equal(local_social_event_order,remaining_social_order)){
			local_social_event_order = remaining_social_order;
			social_changed = 1;
		}
		foreach(indices(local_social_delivered),string delivered_id)
			if(local_social_delivered[delivered_id]<now)
				m_delete(local_social_delivered,delivered_id);
		foreach(indices(local_social_completed),string delivered_id)
			if(local_social_completed[delivered_id]<now){
				m_delete(local_social_completed,delivered_id);
				local_social_durable_deliveries[delivered_id] = 0;
				social_changed = 1;
			}
		if(social_changed)
			persist_local_social_outbox_unlocked();
		destruct(social_key);
	}
	object lease_key = player_lease_lock->lock();
	if(lease_reconciliation_id!="" &&
	   lease_reconciliation_expires_at<now){
		lease_reconciliation_id = "";
		lease_reconciliation_live_users = (<>);
		lease_reconciliation_expires_at = 0;
	}
	foreach(indices(handoffs),string request_id){
		mapping handoff = handoffs[request_id];
		if((int)handoff["expires_at"]<now &&
		   (string)handoff["state"]=="prepared"){
			mapping lease = player_leases[(string)handoff["userid"]];
			if(mappingp(lease) && (string)lease["state"]=="frozen" &&
			   (int)lease["epoch"]==(int)handoff["source_epoch"]){
				lease["state"] = "active";
				lease["expires_at"] = now+MAP_WORKER_PLAYER_LEASE_TTL;
			}
			handoff["state"] = "expired";
			changed = 1;
		}
		else if((string)handoff["state"]!="prepared" &&
		        (int)(handoff["committed_at"] || handoff["aborted_at"] ||
		        handoff["expires_at"])+MAP_WORKER_ENVELOPE_TTL<now){
			m_delete(handoffs,request_id);
			changed = 1;
		}
	}
	// Expired player leases are durable fencing tombstones. Deleting one on a
	// timer could permit a second worker to load the same equipment while an
	// indefinitely stalled command is still alive on the old process.
	destruct(lease_key);
	object message_key = envelope_lock->lock();
	foreach(indices(envelopes),string message_id){
		mapping message = envelopes[message_id];
		if(((string)message["state"]=="acked" &&
		    (int)message["acked_at"]+MAP_WORKER_ENVELOPE_TTL<now) ||
		   (has_value(({"pending","delivering"}),(string)message["state"]) &&
		    (int)message["expires_at"]<now)){
			m_delete(envelopes,message_id);
			changed = 1;
		}
	}
	foreach(indices(escrow_transactions),string transaction_id){
		mapping tx = escrow_transactions[transaction_id];
		if(((string)tx["state"]=="reserved" ||
		    (string)tx["state"]=="delivered" ||
		    (string)tx["state"]=="cancelled") &&
		   (int)tx["expires_at"]>0 && (int)tx["expires_at"]<now){
			m_delete(escrow_transactions,transaction_id);
			changed = 1;
		}
	}
	foreach(indices(pk_sessions),string session_id){
		mapping session = pk_sessions[session_id];
		if((int)session["expires_at"]>0 &&
		   (int)session["expires_at"]<now){
			m_delete(pk_sessions,session_id);
			changed = 1;
		}
	}
	destruct(message_key);
	if(changed)
		schedule_control_persist();
	call_out(cleanup_expired_state,10);
}

mapping(string:mixed) query_status()
{
	array(mapping(string:mixed)) nodes = ({});
	array(mapping(string:mixed)) placements = ({});
	mapping desired_config = query_cluster_config();
	object worker_key = worker_state_lock->lock();
	foreach(sort(indices(worker_nodes)),string worker_id){
		mapping node = copy_value(worker_nodes[worker_id]);
		node["healthy"] = worker_alive_unlocked(node,time());
		node["load_score"] = worker_load_score_unlocked(node);
		nodes += ({node});
	}
	foreach(sort(indices(affinity_assignments)),string affinity){
		mapping placement = copy_value(affinity_assignments[affinity]);
		if(affinity_room_weights[affinity]){
			placement["static_weight"] = affinity_room_weights[affinity];
			placement["heat_score"] = max(0,affinity_heat_scores[affinity]);
			placement["effective_weight"] =
				affinity_effective_weight_unlocked(affinity);
		}
		placements += ({placement});
	}
	int generation = placement_generation;
	int topology_worker_count = placement_topology_worker_count;
	int heat_generation = affinity_heat_generation;
	int heat_maps = sizeof(affinity_heat_scores);
	int heat_observed_at = affinity_heat_last_observed_at;
	int heat_persisted_at = affinity_heat_last_persisted_at;
	destruct(worker_key);
	object lease_key = player_lease_lock->lock();
	int lease_count = sizeof(player_leases);
	int handoff_count = sizeof(handoffs);
	mapping(string:int) handoff_states = ([]);
	int oldest_prepared_age;
	int status_now = time();
	foreach(values(handoffs),mapping handoff){
		string state = normalize_token((string)(handoff["state"] || ""),32);
		if(state=="")
			state = "unknown";
		handoff_states[state]++;
		if(state=="prepared")
			oldest_prepared_age = max(oldest_prepared_age,
				max(0,status_now-(int)handoff["created_at"]));
	}
	destruct(lease_key);
	object message_key = envelope_lock->lock();
	int envelope_count = sizeof(envelopes);
	int escrow_count = sizeof(escrow_transactions);
	int pk_count = sizeof(pk_sessions);
	destruct(message_key);
	object persist_key = control_persist_lock->lock();
	int last_persisted_at = control_last_persisted_at;
	string persist_error = control_last_persist_error;
	int persist_attempts = control_persist_attempts;
	int persist_failures = control_persist_failures;
	int persist_total_ms = control_persist_total_ms;
	int persist_max_ms = control_persist_max_ms;
	int persist_last_ms = control_persist_last_ms;
	int persist_last_bytes = control_persist_last_bytes;
	destruct(persist_key);
	return ([
		"mode":distributed_mode_enabled() ? "distributed" : "standalone",
		"node_role":node_role,"local_worker_id":local_worker_id,
		"desired_config":desired_config,
		"last_persisted_at":last_persisted_at,
		"persist_healthy":persist_error=="",
		"persist_error":persist_error,
		"persist_attempts":persist_attempts,
		"persist_failures":persist_failures,
		"persist_average_ms":persist_attempts ?
			persist_total_ms/persist_attempts : 0,
		"persist_max_ms":persist_max_ms,
		"persist_last_ms":persist_last_ms,
		"persist_last_bytes":persist_last_bytes,
		"restore_discarded":control_restore_discarded,
		"placement_generation":generation,"catalog_size":sizeof(affinity_room_weights),
		"placement_topology_worker_count":topology_worker_count,
		"affinity_heat_generation":heat_generation,
		"affinity_heat_maps":heat_maps,
		"affinity_heat_last_observed_at":heat_observed_at,
		"affinity_heat_last_persisted_at":heat_persisted_at,
		"nodes":nodes,"placements":placements,"player_leases":lease_count,
		"handoffs":handoff_count,"handoff_states":handoff_states,
		"oldest_prepared_handoff_age":oldest_prepared_age,
		"envelopes":envelope_count,
		"escrows":escrow_count,"pk_sessions":pk_count,
	]);
}

protected void create()
{
	string configured_role = lower_case(String.trim_all_whites(
		getenv("XIAND_NODE_ROLE") || "standalone"));
	string configured_worker = normalize_worker_id(
		getenv("XIAND_WORKER_ID") || "standalone");
	if(has_value(({"standalone","gateway","worker"}),configured_role))
		node_role = configured_role;
	if(configured_worker!="")
		local_worker_id = configured_worker;
	local_process_incarnation = lower_case(stable_digest(local_worker_id+"|"+
		(string)time()+"|"+(string)random(1000000000)+"|"+
		(string)gethrtime()));
	local_control_seen_at = time();
	load_cluster_config();
	load_room_catalog();
	restore_affinity_heat();
	restore_control_plane();
	seed_affinity_heat_from_restored_leases();
	restore_local_social_outbox();
	restore_local_team_outbox_snapshots();
	call_out(cleanup_expired_state,10);
}
