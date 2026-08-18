/**
 * S1 新月回响：九卷确定性秘迹、行旅秘术与月忆兽收藏。
 *
 * 永久状态只进入人物唯一 .o 档案的 /plus/illusion_realm/S1 子树。
 * 不创建技能书、不写 player->skills、不接入战斗公式，也不触碰账号
 * 共享宠物或本命灵伴记录。所有领取动作均先复制、后保存，失败完整回滚。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define JOURNEY_CONFIG ROOT "/gamelib/etc/illusion_s1_journey.json"
#define STORY_CONFIG ROOT "/gamelib/etc/illusion_s1_story.json"
#define PROGRESS_ROOT "/plus/illusion_realm"
#define JOURNEY_KEY "newmoon_journey"
#define JOURNEY_LOG ROOT "/log/illusion_journey.log"
#define PACT_COMBAT_CACHE "/tmp/illusion_journey_pact_combat"

private mapping(string:mixed) journey_config = ([]);
private int config_valid;
private Thread.Mutex journey_lock = Thread.Mutex();
private mapping(string:int) journey_test_save_failures = ([]);

private int is_test_journey_player(object player)
{
	return getenv("XIAND_RUN_TESTUNIT")=="1" && player &&
		has_prefix((string)player->query_name(),"__testunit_");
}

private int valid_slug(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>40)
		return 0;
	foreach(value;int index;int one)
		if(!((one>='a' && one<='z') || (one>='0' && one<='9') ||
		   one=='_'))
			return 0;
	return 1;
}

private int valid_hex_id(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	foreach(value;int index;int one)
		if(!((one>='a' && one<='f') || (one>='0' && one<='9')))
			return 0;
	return 1;
}

private int valid_room(string value)
{
	return value && has_prefix(value,"/gamelib/d/illusion_s1/") &&
		has_suffix(value,".pike") && search(value,"..")==-1 &&
		search(value,"#")==-1 && Stdio.file_size(ROOT+value)>0;
}

private int valid_target_path(string value)
{
	return value &&
		has_prefix(value,"/gamelib/clone/npc/illusion_s1/") &&
		has_suffix(value,".pike") && search(value,"..")==-1 &&
		search(value,"#")==-1 && Stdio.file_size(ROOT+value)>0;
}

private string normalized_object_path(mixed value)
{
	string path = "";
	if(objectp(value))
		path = file_name(value);
	else if(stringp(value))
		path = (string)value;
	if(has_prefix(path,ROOT))
		path = path[sizeof(ROOT)..];
	if(search(path,"#")!=-1)
		path = (path/"#")[0];
	return path;
}

private mapping find_by_id(array rows,string id)
{
	if(!arrayp(rows) || !valid_slug(id))
		return ([]);
	foreach(rows,mapping row)
		if((string)row["id"]==id)
			return row;
	return ([]);
}

private mapping secret_config(string id)
{
	return find_by_id((array)(journey_config["secrets"] || ({})),id);
}

private mapping species_config(string id)
{
	return find_by_id((array)(journey_config["companion_species"] || ({})),id);
}

private mapping quest_config(string id)
{
	return find_by_id((array)(journey_config["side_quests"] || ({})),id);
}

private mapping encounter_config(string id)
{
	return find_by_id((array)(journey_config["wander_events"] || ({})),id);
}

private mapping signature_config(string id)
{
	return find_by_id((array)(journey_config["signature_trials"] || ({})),id);
}

private mapping pact_config(string id)
{
	return find_by_id((array)(journey_config["pact_catalog"] || ({})),id);
}

private mapping loot_focus_config(string id)
{
	return find_by_id((array)(journey_config["loot_focus_catalog"] || ({})),id);
}

private mapping route_arc_config(string path)
{
	mapping routes = mappingp(journey_config["route_arcs"]) ?
		(mapping)journey_config["route_arcs"] : ([]);
	return mappingp(routes[path]) ? (mapping)routes[path] : ([]);
}

private int valid_event_target(mapping one,int with_id)
{
	string room_source;
	string target_file;
	string target_id;
	if(!mappingp(one) || !valid_room((string)one["room"]) ||
	   !valid_target_path((string)one["target_path"]))
		return 0;
	room_source = Stdio.read_file(ROOT+(string)one["room"]) || "";
	target_file = ((string)one["target_path"]/"/")[-1];
	target_id = has_suffix(target_file,".pike") ?
		target_file[..sizeof(target_file)-6] : target_file;
	return sizeof(one)<=12 &&
		(!with_id || valid_slug((string)one["id"])) &&
		stringp(one["location"]) && sizeof((string)one["location"])>=2 &&
		search(room_source,target_id)!=-1 &&
		stringp(one["target_name"]) &&
		sizeof((string)one["target_name"])>=2 &&
		sizeof((string)one["target_name"])<=32;
}

private int valid_signature_trials(array trials)
{
	mapping(string:int) ids = ([]);
	if(sizeof(trials)!=9)
		return 0;
	foreach(trials;int index;mapping trial){
		array stages = arrayp(trial["stages"]) ?
			(array)trial["stages"] : ({});
		string id = (string)trial["id"];
		if(!valid_slug(id) || ids[id] || (int)trial["volume"]!=index+1 ||
		   (int)trial["unlock_claimed"]!=(index+1)*9 ||
		   !stringp(trial["title"]) || !stringp(trial["mechanic"]) ||
		   sizeof(stages)!=3)
			return 0;
		foreach(stages;int stage_index;mapping stage){
			string kind = (string)stage["kind"];
			if(!mappingp(stage) || sizeof(stage)>12 ||
			   !stringp(stage["title"]) || !stringp(stage["text"]) ||
			   !stringp(stage["location"]) ||
			   !valid_room((string)stage["room"]) ||
			   kind!=({"ritual","hunt","boss"})[stage_index])
				return 0;
			if(kind!="ritual" &&
			   (!valid_event_target(stage,0) ||
			    (int)stage["required_kills"]<1 ||
			    (int)stage["required_kills"]>3 ||
			    (kind=="boss" && (int)stage["required_kills"]!=1)))
				return 0;
		}
		ids[id] = 1;
	}
	return 1;
}

private int valid_route_arcs(mapping routes)
{
	if(sizeof(routes)!=3)
		return 0;
	foreach(({"pioneer","hunter","companion"}),string path){
		mapping route = mappingp(routes[path]) ? (mapping)routes[path] : ([]);
		array stages = arrayp(route["stages"]) ? (array)route["stages"] : ({});
		int previous_unlock;
		if(sizeof(route)>5 || !stringp(route["title"]) ||
		   !stringp(route["description"]) || sizeof(stages)!=6)
			return 0;
		foreach(stages,mapping stage){
			int unlock = (int)stage["unlock_claimed"];
			if(sizeof(stage)>12 || !stringp(stage["title"]) ||
			   !valid_event_target(stage,0) || unlock<=previous_unlock ||
			   unlock<9 || unlock>72 || (int)stage["required_kills"]<1 ||
			   (int)stage["required_kills"]>3)
				return 0;
			previous_unlock = unlock;
		}
	}
	return 1;
}

private int valid_pacts(array slots,array pacts)
{
	mapping(string:int) ids = ([]);
	if(sizeof(slots)!=3 || (int)slots[0]!=18 || (int)slots[1]!=45 ||
	   (int)slots[2]!=72 || sizeof(pacts)!=6)
		return 0;
	foreach(pacts,mapping pact){
		string id = (string)pact["id"];
		if(sizeof(pact)>8 || !valid_slug(id) || ids[id] ||
		   !stringp(pact["name"]) || !stringp(pact["description"]) ||
		   !intp(pact["outgoing_delta"]) ||
		   (int)pact["outgoing_delta"]<-10 ||
		   (int)pact["outgoing_delta"]>10 ||
		   !intp(pact["incoming_delta"]) ||
		   (int)pact["incoming_delta"]<-10 ||
		   (int)pact["incoming_delta"]>10 ||
		   ((int)pact["outgoing_delta"]>0 &&
		    (int)pact["incoming_delta"]<=0))
			return 0;
		ids[id] = 1;
	}
	return 1;
}

private int valid_loot_focus_catalog(array catalog)
{
	array(string) expected = ({"single_main_weapon","armor_head",
		"armor_cloth","armor_waste","armor_hand","armor_thou",
		"armor_shoes","jewelry_ring","jewelry_neck","jewelry_bangle"});
	if(sizeof(catalog)!=sizeof(expected))
		return 0;
	foreach(catalog;int index;mapping row)
		if(sizeof(row)>3 || (string)row["id"]!=expected[index] ||
		   !stringp(row["name"]) || sizeof((string)row["name"])<2)
			return 0;
	return 1;
}

private int valid_config(mapping candidate)
{
	mapping(string:int) quest_ids = ([]);
	mapping(string:int) gate_ids = ([]);
	mapping(string:int) secret_ids = ([]);
	mapping(string:int) species_ids = ([]);
	mapping(string:int) quest_secret_ids = ([]);
	mapping(string:int) event_ids = ([]);
	mapping(string:int) choice_ids = ([]);
	mapping(string:int) choice_traits = ([]);
	array quests;
	array secrets;
	array species;
	array memories;
	array choices;
	array encounters;
	array rotations;
	array signature_trials;
	array pact_slots;
	array pact_catalog;
	array loot_focus_catalog;
	mapping rules;
	mapping community;
	mapping route_arcs;
	if(!mappingp(candidate) || sizeof(candidate)>20 ||
	   (int)candidate["version"]!=1 ||
	   (string)candidate["illusion_id"]!="S1" ||
	   (int)candidate["feature_revision"]!=4 ||
	   !arrayp(candidate["side_quests"]) ||
	   !arrayp(candidate["secrets"]) ||
	   !arrayp(candidate["companion_species"]) ||
	   !arrayp(candidate["companion_memories"]) ||
	   !arrayp(candidate["memory_choices"]) ||
	   !mappingp(candidate["encounter_rules"]) ||
	   !arrayp(candidate["wander_events"]) ||
	   !arrayp(candidate["echo_rotations"]) ||
	   !arrayp(candidate["signature_trials"]) ||
	   !mappingp(candidate["route_arcs"]) ||
	   !arrayp(candidate["pact_slots"]) ||
	   !arrayp(candidate["pact_catalog"]) ||
	   !arrayp(candidate["loot_focus_catalog"]) ||
	   !mappingp(candidate["community_goal"]))
		return 0;
	quests = (array)candidate["side_quests"];
	secrets = (array)candidate["secrets"];
	species = (array)candidate["companion_species"];
	memories = (array)candidate["companion_memories"];
	choices = (array)candidate["memory_choices"];
	encounters = (array)candidate["wander_events"];
	rotations = (array)candidate["echo_rotations"];
	signature_trials = (array)candidate["signature_trials"];
	route_arcs = (mapping)candidate["route_arcs"];
	pact_slots = (array)candidate["pact_slots"];
	pact_catalog = (array)candidate["pact_catalog"];
	loot_focus_catalog = (array)candidate["loot_focus_catalog"];
	rules = (mapping)candidate["encounter_rules"];
	community = (mapping)candidate["community_goal"];
	if(sizeof(quests)!=9 || sizeof(secrets)!=9 || sizeof(species)!=5 ||
	   sizeof(memories)!=9 || sizeof(choices)!=4 ||
	   sizeof(encounters)!=3 || sizeof(rotations)!=3 ||
	   sizeof(rules)>5 || (int)rules["first_trigger_kills"]<1 ||
	   (int)rules["first_trigger_kills"]>1000 ||
	   (int)rules["interval_kills"]<10 ||
	   (int)rules["interval_kills"]>1000 ||
	   (int)rules["max_completions"]<1 ||
	   (int)rules["max_completions"]>24 || sizeof(community)>6 ||
	   !stringp(community["title"]) ||
	   (int)community["target"]<100 || (int)community["target"]>1000000 ||
	   !arrayp(community["milestones"]) ||
	   sizeof((array)community["milestones"])!=3 ||
	   !valid_signature_trials(signature_trials) ||
	   !valid_route_arcs(route_arcs) ||
	   !valid_pacts(pact_slots,pact_catalog) ||
	   !valid_loot_focus_catalog(loot_focus_catalog))
		return 0;
	foreach(secrets,mapping one){
		string id = (string)one["id"];
		if(!valid_slug(id) || secret_ids[id] ||
		   !stringp(one["name"]) || sizeof((string)one["name"])<2 ||
		   !stringp(one["description"]) ||
		   sizeof((string)one["description"])<4)
			return 0;
		secret_ids[id] = 1;
	}
	foreach(species,mapping one){
		string id = (string)one["id"];
		if(!valid_slug(id) || species_ids[id] ||
		   !stringp(one["name"]) || sizeof((string)one["name"])<2 ||
		   !stringp(one["short_name"]) ||
		   !stringp(one["gift"]))
			return 0;
		species_ids[id] = 1;
	}
	foreach(quests;int index;mapping one){
		string id = (string)one["id"];
		string gate_id = (string)one["gate_id"];
		array acts = (array)one["acts"];
		if(!valid_slug(id) || quest_ids[id] || !valid_slug(gate_id) ||
		   gate_ids[gate_id] || (int)one["volume"]!=index+1 ||
		   (int)one["unlock_claimed"]!=index*9 ||
		   !secret_ids[(string)one["secret_id"]] ||
		   quest_secret_ids[(string)one["secret_id"]] ||
		   !valid_slug((string)one["final_event"]) ||
		   event_ids[(string)one["final_event"]] ||
		   !arrayp(one["acts"]) || sizeof(acts)!=4)
			return 0;
		foreach(acts;int act_index;mapping act)
			if(!valid_room((string)act["room"]) ||
			   !stringp(act["title"]) || !stringp(act["location"]) ||
			   !stringp(act["text"]) ||
			   !valid_target_path((string)act["target_path"]) ||
			   !stringp(act["target_name"]) ||
			   sizeof((string)act["target_name"])<2 ||
			   sizeof((string)act["target_name"])>32 ||
			   (int)act["required_kills"]<1 ||
			   (int)act["required_kills"]>5 ||
			   (act_index==3 && (int)act["required_kills"]!=1))
				return 0;
		quest_ids[id] = 1;
		gate_ids[gate_id] = 1;
		quest_secret_ids[(string)one["secret_id"]] = 1;
		event_ids[(string)one["final_event"]] = 1;
	}
	foreach(memories;int index;mapping one)
		if((int)one["volume"]!=index+1 ||
		   !stringp(one["title"]) || !stringp(one["text"]) ||
		   ((string)one["rescue"]!="" &&
		    !species_ids[(string)one["rescue"]]))
			return 0;
	foreach(choices,mapping one){
		string id = (string)one["id"];
		string trait = (string)one["trait"];
		if(!valid_slug(id) || choice_ids[id] || choice_traits[trait] ||
		   search(({"courage","care","curiosity","freedom"}),trait)==-1 ||
		   !stringp(one["name"]))
			return 0;
		choice_ids[id] = 1;
		choice_traits[trait] = 1;
	}
	mapping(string:int) encounter_ids = ([]);
	foreach(encounters,mapping one){
		string id = (string)one["id"];
		if(!valid_event_target(one,1) || encounter_ids[id] ||
		   !stringp(one["title"]) || !stringp(one["text"]) ||
		   sizeof((string)one["text"])<20 ||
		   (int)one["unlock_claimed"]<0 ||
		   (int)one["unlock_claimed"]>72 ||
		   (int)one["required_kills"]<1 ||
		   (int)one["required_kills"]>5 ||
		   (int)one["community_points"]<1 ||
		   (int)one["community_points"]>100)
			return 0;
		encounter_ids[id] = 1;
	}
	mapping(string:int) rotation_ids = ([]);
	foreach(rotations,mapping rotation){
		string id = (string)rotation["id"];
		array stages = arrayp(rotation["stages"]) ?
			(array)rotation["stages"] : ({});
		if(!valid_slug(id) || rotation_ids[id] ||
		   !stringp(rotation["title"]) || sizeof(stages)!=3)
			return 0;
		foreach(stages,mapping stage)
			if(!valid_event_target(stage,0))
				return 0;
		rotation_ids[id] = 1;
	}
	int last_milestone;
	foreach((array)community["milestones"],mapping milestone){
		if(!mappingp(milestone) || sizeof(milestone)>4 ||
		   (int)milestone["points"]<=last_milestone ||
		   (int)milestone["points"]>(int)community["target"] ||
		   !stringp(milestone["name"]) || !stringp(milestone["text"]))
			return 0;
		last_milestone = (int)milestone["points"];
	}
	if(last_milestone!=(int)community["target"])
		return 0;
	return 1;
}

private int valid_story_links(mapping candidate)
{
	mixed decoded;
	mixed err;
	array volumes;
	if(Stdio.file_size(STORY_CONFIG)<=0 ||
	   Stdio.file_size(STORY_CONFIG)>2*1024*1024)
		return 0;
	err = catch{ decoded=Standards.JSON.decode(Stdio.read_file(STORY_CONFIG)); };
	if(err || !mappingp(decoded) ||
	   (string)((mapping)decoded)["illusion_id"]!="S1" ||
	   !arrayp(((mapping)decoded)["volumes"]))
		return 0;
	volumes = (array)((mapping)decoded)["volumes"];
	if(sizeof(volumes)!=9)
		return 0;
	foreach((array)candidate["side_quests"];int index;mapping quest){
		mapping volume = mappingp(volumes[index]) ?
			(mapping)volumes[index] : ([]);
		array chapters = arrayp(volume["chapters"]) ?
			(array)volume["chapters"] : ({});
		mapping finale = sizeof(chapters) && mappingp(chapters[-1]) ?
			(mapping)chapters[-1] : ([]);
		mapping gate = mappingp(finale["quest_item_gate"]) ?
			(mapping)finale["quest_item_gate"] : ([]);
		if(sizeof(chapters)!=9 ||
		   (string)finale["id"]!="S1-C"+(string)((index+1)*9) ||
		   (string)finale["story_event"]!=(string)quest["final_event"] ||
		   (string)gate["id"]!=(string)quest["gate_id"])
			return 0;
	}
	return 1;
}

private void reload_config()
{
	string source;
	mixed decoded;
	mixed err;
	config_valid = 0;
	journey_config = ([]);
	if(Stdio.file_size(JOURNEY_CONFIG)<=0 ||
	   Stdio.file_size(JOURNEY_CONFIG)>512*1024)
		return;
	source = Stdio.read_file(JOURNEY_CONFIG);
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) || !valid_config((mapping)decoded) ||
	   !valid_story_links((mapping)decoded))
		return;
	journey_config = (mapping)decoded;
	config_valid = 1;
}

mapping(string:mixed) query_config_status()
{
	return (["ok":config_valid,"version":(int)journey_config["version"],
		"feature_revision":(int)journey_config["feature_revision"],
		"quests":arrayp(journey_config["side_quests"]) ?
			sizeof((array)journey_config["side_quests"]) : 0,
		"secrets":arrayp(journey_config["secrets"]) ?
			sizeof((array)journey_config["secrets"]) : 0,
		"species":arrayp(journey_config["companion_species"]) ?
			sizeof((array)journey_config["companion_species"]) : 0]);
}

mapping(string:mixed) query_catalog_for_test()
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return ([]);
	return copy_value(journey_config);
}

int force_next_save_failure_for_test(object player)
{
	if(!is_test_journey_player(player))
		return 0;
	journey_test_save_failures[(string)player->query_name()] = 1;
	return 1;
}

/**
 * Main-story gate validation deliberately lives here rather than trusting a
 * single saved flag.  A deterministic substitute is valid only when the
 * owner-bound journey record, the matching four-act quest, its secret, and
 * the authoritative volume-end story event all agree.
 */
int query_gate_substitution_ready(object player,string gate_id)
{
	mapping progress;
	mapping state;
	mapping quest;
	mapping quest_state;
	mapping events;
	mixed substituted_at;
	if(!config_valid || !player || !valid_slug(gate_id))
		return 0;
	progress = raw_progress(player);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	if(!sizeof(state))
		return 0;
	foreach((array)journey_config["side_quests"],mapping candidate)
		if((string)candidate["gate_id"]==gate_id){
			quest = candidate;
			break;
		}
	if(!sizeof(quest))
		return 0;
	quest_state = mappingp(((mapping)state["side_quests"])[
		(string)quest["id"]]) ? (mapping)((mapping)state["side_quests"])[
		(string)quest["id"]] : ([]);
	events = mappingp(progress["story_events"]) ?
		(mapping)progress["story_events"] : ([]);
	substituted_at = ((mapping)state["gate_substitutions"])[gate_id];
	return (int)quest_state["act"]==4 &&
		valid_timestamp(quest_state["completed_at"]) &&
		(int)quest_state["completed_at"]>0 &&
		valid_timestamp(substituted_at) && (int)substituted_at>0 &&
		valid_timestamp(((mapping)state["secrets"])[
			(string)quest["secret_id"]]) &&
		(int)((mapping)state["secrets"])[(string)quest["secret_id"]]>0 &&
		(int)events[(string)quest["final_event"]]>0;
}

private int claimed_chapter_count(mapping progress)
{
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	int count;
	for(int chapter=1;chapter<=81;chapter++){
		if(!(int)claims["S1-C"+(string)chapter])
			break;
		count++;
	}
	return count;
}

private mapping raw_progress(object player)
{
	mapping all_progress;
	mapping progress;
	string content_id;
	if(!player)
		return ([]);
	all_progress = player[PROGRESS_ROOT];
	if(!mappingp(all_progress))
		return ([]);
	progress = all_progress["S1"];
	if(!mappingp(progress))
		return ([]);
	content_id = (string)(progress["content_id"] || "");
	// S1首批人物档案早于content_id字段。映射键本身已经是S1，缺失
	// 字段可安全补齐；显式写成其它内容编号仍失败关闭，避免串档。
	if(content_id!="" && content_id!="S1")
		return ([]);
	if(content_id=="")
		progress["content_id"] = "S1";
	return progress;
}

private string owner_account(object player)
{
	string account;
	if(!player)
		return "";
	account = functionp(player->query_account_owner) ?
		(string)player->query_account_owner() : "";
	return account!="" ? account : (string)player->query_name();
}

private mapping default_state(object player,void|mapping progress)
{
	int first_trigger = mappingp(journey_config["encounter_rules"]) ?
		(int)((mapping)journey_config["encounter_rules"])[
			"first_trigger_kills"] : 18;
	return ([
		"version":1,"illusion_id":"S1",
		"owner_id":(string)player->query_name(),
		"registration_account":owner_account(player),
		"side_quests":([]),"secrets":([]),
		"gate_substitutions":([]),
		"companion":(["pets":([]),"active_id":"",
			"memories":([]),"traits":(["courage":0,"care":0,
				"curiosity":0,"freedom":0])]),
		"encounter":(["active_id":"","kills":0,"completed":0,
			"next_at":first_trigger,
			"activated_at":0,"last_completed_at":0]),
		"echo":(["week":0,"rotation":"","stage":0,
			"completed_weeks":([]),"last_completed_at":0]),
		"signature_trials":([]),
		"route_arc":(["path":mappingp(progress) ?
			(string)(progress["path"] || "") : "","stage":0,
			"kills":0,"completed_at":0]),
		"pacts":(["active":({}),"changed_at":0]),
		"loot_focus":(["kind":"all","changed_at":0]),
		"community_points":0,
	]);
}

private mapping normalized_state(object player,mapping state,mapping progress)
{
	mapping normalized;
	mapping defaults;
	if(!mappingp(state))
		return default_state(player,progress);
	normalized = copy_value(state);
	defaults = default_state(player,progress);
	foreach(({"encounter","echo","signature_trials","route_arc","pacts",
	   "loot_focus"}),
	   string key)
		if(!mappingp(normalized[key])){
			normalized[key] = copy_value((mapping)defaults[key]);
			// Existing revision-2 characters receive an encounter on their
			// next eligible kill instead of starting a second long counter.
			if(key=="encounter" && mappingp(progress) &&
			   (int)progress["kills"]>=(int)((mapping)defaults[
				"encounter"])["next_at"])
				((mapping)normalized[key])["next_at"] =
					(int)progress["kills"];
		}
	if(!has_index(normalized,"community_points"))
		normalized["community_points"] = 0;
	return normalized;
}

private int valid_timestamp(mixed value)
{
	return intp(value) && (int)value>=0 && (int)value<=2000000000;
}

private int valid_state(object player,mapping state)
{
	mapping quests;
	mapping secrets;
	mapping substitutions;
	mapping companion;
	mapping pets;
	mapping memories;
	mapping traits;
	mapping encounter;
	mapping echo;
	mapping completed_weeks;
	mapping signature_trials;
	mapping route_arc;
	mapping pacts;
	mapping loot_focus;
	array active_pacts;
	int trait_total;
	if(!mappingp(state) || sizeof(state)>16 ||
	   (int)state["version"]!=1 || (string)state["illusion_id"]!="S1" ||
	   (string)state["owner_id"]!=(string)player->query_name() ||
	   (string)state["registration_account"]!=owner_account(player) ||
	   !mappingp(state["side_quests"]) || !mappingp(state["secrets"]) ||
	   !mappingp(state["gate_substitutions"]) ||
	   !mappingp(state["companion"]) || !mappingp(state["encounter"]) ||
	   !mappingp(state["echo"]) ||
	   !mappingp(state["signature_trials"]) ||
	   !mappingp(state["route_arc"]) || !mappingp(state["pacts"]) ||
	   !mappingp(state["loot_focus"]) ||
	   !intp(state["community_points"]) ||
	   (int)state["community_points"]<0 ||
	   (int)state["community_points"]>2000000000)
		return 0;
	quests = (mapping)state["side_quests"];
	secrets = (mapping)state["secrets"];
	substitutions = (mapping)state["gate_substitutions"];
	companion = (mapping)state["companion"];
	encounter = (mapping)state["encounter"];
	echo = (mapping)state["echo"];
	signature_trials = (mapping)state["signature_trials"];
	route_arc = (mapping)state["route_arc"];
	pacts = (mapping)state["pacts"];
	loot_focus = (mapping)state["loot_focus"];
	if(sizeof(quests)>9 || sizeof(secrets)>9 || sizeof(substitutions)>9 ||
	   sizeof(companion)>8 || !mappingp(companion["pets"]) ||
	   !mappingp(companion["memories"]) || !mappingp(companion["traits"]))
		return 0;
	foreach(quests;mixed id;mixed value){
		mapping quest;
		mapping one;
		if(!stringp(id) || !sizeof(quest_config((string)id)) ||
		   !mappingp(value) || sizeof((mapping)value)>6 ||
		   !intp(((mapping)value)["act"]) ||
		   (int)((mapping)value)["act"]<0 ||
		   (int)((mapping)value)["act"]>4 ||
		   (has_index((mapping)value,"act_kills") &&
		    (!intp(((mapping)value)["act_kills"]) ||
		     (int)((mapping)value)["act_kills"]<0 ||
		     (int)((mapping)value)["act_kills"]>5)) ||
		   (has_index((mapping)value,"started_at") &&
		    !valid_timestamp(((mapping)value)["started_at"])) ||
		   (has_index((mapping)value,"updated_at") &&
		    !valid_timestamp(((mapping)value)["updated_at"])) ||
		   (has_index((mapping)value,"completed_at") &&
		    !valid_timestamp(((mapping)value)["completed_at"])))
			return 0;
		quest = quest_config((string)id);
		one = (mapping)value;
		if(((int)one["act"]==4) !=
		   (has_index(one,"completed_at") &&
		    (int)one["completed_at"]>0) ||
		   ((int)one["act"]==4 && (int)one["act_kills"]!=0) ||
		   ((int)one["act"]==4 &&
		    ((int)secrets[(string)quest["secret_id"]]<=0 ||
		     (int)substitutions[(string)quest["gate_id"]]<=0)))
			return 0;
	}
	foreach(secrets;mixed id;mixed value){
		mapping linked_quest;
		if(!stringp(id) || !sizeof(secret_config((string)id)) ||
		   !valid_timestamp(value) || (int)value<=0)
			return 0;
		foreach((array)journey_config["side_quests"],mapping candidate)
			if((string)candidate["secret_id"]==(string)id){
				linked_quest = candidate;
				break;
			}
		if(!sizeof(linked_quest) ||
		   !mappingp(quests[(string)linked_quest["id"]]) ||
		   (int)((mapping)quests[(string)linked_quest["id"]])["act"]!=4)
			return 0;
	}
	foreach(substitutions;mixed id;mixed value){
		mapping linked_quest;
		foreach((array)journey_config["side_quests"],mapping quest)
			if((string)quest["gate_id"]==(string)id){
				linked_quest = quest;
				break;
			}
		if(!sizeof(linked_quest) || !valid_timestamp(value) ||
		   (int)value<=0 ||
		   !mappingp(quests[(string)linked_quest["id"]]) ||
		   (int)((mapping)quests[(string)linked_quest["id"]])["act"]!=4)
			return 0;
	}
	pets = (mapping)companion["pets"];
	memories = (mapping)companion["memories"];
	traits = (mapping)companion["traits"];
	if(sizeof(pets)>5 || sizeof(memories)>9 || sizeof(traits)!=4 ||
	   (sizeof(memories)>0 && !sizeof(pets)) ||
	   ((string)(companion["active_id"] || "")!="" &&
	    !mappingp(pets[(string)companion["active_id"]])))
		return 0;
	foreach(pets;mixed id;mixed value)
		if(!stringp(id) || !sizeof(species_config((string)id)) ||
		   !mappingp(value) || sizeof((mapping)value)>5 ||
		   (string)((mapping)value)["species"]!=(string)id ||
		   !valid_hex_id((string)((mapping)value)["id"]) ||
		   !valid_timestamp(((mapping)value)["joined_at"]) ||
		   (int)((mapping)value)["joined_at"]<=0)
			return 0;
	foreach(memories;mixed volume;mixed value){
		int number;
		if(!stringp(volume) || sscanf((string)volume,"%d",number)!=1 ||
		   number<1 || number>9 || (string)volume!=(string)number ||
		   number>sizeof(memories) || !mappingp(value) ||
		   !sizeof(find_by_id((array)journey_config["memory_choices"],
			(string)((mapping)value)["choice"])) ||
		   !valid_timestamp(((mapping)value)["claimed_at"]) ||
		   (int)((mapping)value)["claimed_at"]<=0)
			return 0;
	}
	foreach(({"courage","care","curiosity","freedom"}),string trait){
		if(!intp(traits[trait]) || (int)traits[trait]<0 ||
		   (int)traits[trait]>9)
			return 0;
		trait_total += (int)traits[trait];
	}
	if(trait_total!=sizeof(memories))
		return 0;
	if(sizeof(encounter)>8 || !stringp(encounter["active_id"]) ||
	   ((string)encounter["active_id"]!="" &&
	    !sizeof(encounter_config((string)encounter["active_id"]))) ||
	   !intp(encounter["kills"]) || (int)encounter["kills"]<0 ||
	   (int)encounter["kills"]>5 || !intp(encounter["completed"]) ||
	   (int)encounter["completed"]<0 || (int)encounter["completed"]>24 ||
	   !intp(encounter["next_at"]) || (int)encounter["next_at"]<1 ||
	   (int)encounter["next_at"]>2000000000 ||
	   !valid_timestamp(encounter["activated_at"]) ||
	   !valid_timestamp(encounter["last_completed_at"]) ||
	   ((string)encounter["active_id"]=="" &&
	    ((int)encounter["kills"]!=0 || (int)encounter["activated_at"]!=0)) ||
	   ((string)encounter["active_id"]!="" &&
	    ((int)encounter["activated_at"]<=0 ||
	     (int)encounter["kills"]>=(int)encounter_config(
		(string)encounter["active_id"])["required_kills"])))
		return 0;
	completed_weeks = mappingp(echo["completed_weeks"]) ?
		(mapping)echo["completed_weeks"] : ([]);
	if(sizeof(echo)>8 || !intp(echo["week"]) || (int)echo["week"]<0 ||
	   (int)echo["week"]>60 || !stringp(echo["rotation"]) ||
	   ((string)echo["rotation"]!="" &&
	    !sizeof(find_by_id((array)journey_config["echo_rotations"],
		(string)echo["rotation"]))) || !intp(echo["stage"]) ||
	   (int)echo["stage"]<0 || (int)echo["stage"]>3 ||
	   !mappingp(echo["completed_weeks"]) || sizeof(completed_weeks)>60 ||
	   !valid_timestamp(echo["last_completed_at"]))
		return 0;
	foreach(completed_weeks;mixed week;mixed completed_at){
		int number;
		if(!stringp(week) || sscanf((string)week,"%d",number)!=1 ||
		   number<1 || number>60 || (string)week!=(string)number ||
		   !valid_timestamp(completed_at) || (int)completed_at<=0)
			return 0;
	}
	if(((int)echo["week"]==0) != ((string)echo["rotation"]=="") ||
	   ((int)echo["week"]==0 && (int)echo["stage"]!=0) ||
	   ((int)echo["stage"]==3 &&
	    !(int)completed_weeks[(string)(int)echo["week"]]))
		return 0;
	if(sizeof(signature_trials)>9)
		return 0;
	foreach(signature_trials;mixed id;mixed value){
		mapping trial;
		mapping one;
		array stages;
		int stage;
		int required;
		if(!stringp(id) || !mappingp(value) ||
		   !sizeof(trial=signature_config((string)id)) ||
		   sizeof((mapping)value)>5)
			return 0;
		one = (mapping)value;
		stage = (int)one["stage"];
		stages = (array)trial["stages"];
		if(!intp(one["stage"]) || stage<0 || stage>3 ||
		   !intp(one["kills"]) || (int)one["kills"]<0 ||
		   (int)one["kills"]>3 ||
		   !valid_timestamp(one["updated_at"]) ||
		   !valid_timestamp(one["completed_at"]) ||
		   ((stage==3) != ((int)one["completed_at"]>0)) ||
		   (stage==3 && (int)one["kills"]!=0))
			return 0;
		if(stage<3){
			required = (string)((mapping)stages[stage])["kind"]=="ritual" ?
				0 : (int)((mapping)stages[stage])["required_kills"];
			if((required==0 && (int)one["kills"]!=0) ||
			   (required>0 && (int)one["kills"]>=required))
				return 0;
		}
	}
	if(sizeof(route_arc)>6 || !stringp(route_arc["path"]) ||
	   search(({"","pioneer","hunter","companion"}),
		(string)route_arc["path"])==-1 || !intp(route_arc["stage"]) ||
	   (int)route_arc["stage"]<0 || (int)route_arc["stage"]>6 ||
	   !intp(route_arc["kills"]) || (int)route_arc["kills"]<0 ||
	   (int)route_arc["kills"]>3 ||
	   !valid_timestamp(route_arc["completed_at"]) ||
	   (((int)route_arc["stage"]==6) !=
		((int)route_arc["completed_at"]>0)) ||
	   ((int)route_arc["stage"]==6 && (int)route_arc["kills"]!=0))
		return 0;
	if((string)route_arc["path"]=="" &&
	   ((int)route_arc["stage"]!=0 || (int)route_arc["kills"]!=0 ||
	    (int)route_arc["completed_at"]!=0))
		return 0;
	if((string)route_arc["path"]!="" && (int)route_arc["stage"]<6){
		mapping route = route_arc_config((string)route_arc["path"]);
		mapping stage_config = (mapping)((array)route["stages"])[
			(int)route_arc["stage"]];
		if((int)route_arc["kills"]>=(int)stage_config["required_kills"])
			return 0;
	}
	active_pacts = arrayp(pacts["active"]) ? (array)pacts["active"] : ({});
	if(sizeof(pacts)>4 || !arrayp(pacts["active"]) ||
	   sizeof(active_pacts)>3 || !valid_timestamp(pacts["changed_at"]))
		return 0;
	mapping(string:int) seen_pacts = ([]);
	foreach(active_pacts,mixed id)
		if(!stringp(id) || seen_pacts[(string)id] ||
		   !sizeof(pact_config((string)id)))
			return 0;
		else
			seen_pacts[(string)id] = 1;
	if(sizeof(loot_focus)>3 || !stringp(loot_focus["kind"]) ||
	   ((string)loot_focus["kind"]!="all" &&
	    !sizeof(loot_focus_config((string)loot_focus["kind"]))) ||
	   !valid_timestamp(loot_focus["changed_at"]))
		return 0;
	return 1;
}

private mapping state_for(object player,mapping progress)
{
	mapping state = progress[JOURNEY_KEY];
	mapping normalized = normalized_state(player,state,progress);
	mapping route_arc = mappingp(normalized["route_arc"]) ?
		(mapping)normalized["route_arc"] : ([]);
	string selected_path = (string)(progress["path"] || "");
	if(!valid_state(player,normalized) ||
	   ((string)route_arc["path"]!="" &&
	    (string)route_arc["path"]!=selected_path))
		return ([]);
	return normalized;
}

private mapping current_quest(mapping progress,mapping state)
{
	int claimed = claimed_chapter_count(progress);
	mapping quest_states = (mapping)state["side_quests"];
	foreach((array)journey_config["side_quests"],mapping quest){
		mapping one = mappingp(quest_states[(string)quest["id"]]) ?
			(mapping)quest_states[(string)quest["id"]] : ([]);
		if((int)one["act"]>=4)
			continue;
		if(claimed<(int)quest["unlock_claimed"])
			return ([]);
		return quest;
	}
	return ([]);
}

private mapping current_quest_view(mapping progress,mapping state)
{
	mapping quest = current_quest(progress,state);
	mapping quest_states;
	mapping one;
	mapping events;
	array acts;
	int act_index;
	if(!sizeof(quest))
		return ([]);
	quest_states = (mapping)state["side_quests"];
	one = mappingp(quest_states[(string)quest["id"]]) ?
		(mapping)quest_states[(string)quest["id"]] : ([]);
	act_index = (int)one["act"];
	acts = (array)quest["acts"];
	events = mappingp(progress["story_events"]) ?
		(mapping)progress["story_events"] : ([]);
	int required_kills = (int)((mapping)acts[act_index])["required_kills"];
	int act_kills = min(required_kills,(int)one["act_kills"]);
	if(act_index==3 && (int)events[(string)quest["final_event"]]>0)
		act_kills = required_kills;
	return copy_value(quest)+(["act":act_index,"act_total":4,
		"current_act":copy_value((mapping)acts[act_index]),
		"act_kills":act_kills,"required_kills":required_kills,
		"act_ready":act_kills>=required_kills,
		"final_event_ready":(int)events[(string)quest["final_event"]]>0]);
}

private int companion_stage(mapping companion)
{
	int memories = mappingp(companion["memories"]) ?
		sizeof((mapping)companion["memories"]) : 0;
	if(memories>=9) return 5;
	if(memories>=7) return 4;
	if(memories>=5) return 3;
	if(memories>=3) return 2;
	return memories>=1 ? 1 : 0;
}

private mapping public_companion(mapping state)
{
	mapping companion = copy_value((mapping)state["companion"]);
	mapping pets = (mapping)companion["pets"];
	array rows = ({});
	foreach((array)journey_config["companion_species"],mapping species){
		mapping owned = mappingp(pets[(string)species["id"]]) ?
			(mapping)pets[(string)species["id"]] : ([]);
		rows += ({copy_value(species)+(["owned":sizeof(owned)>0,
			"active":(string)companion["active_id"]==
				(string)species["id"],
			"pet_id":(string)(owned["id"] || "")])});
	}
	companion["catalog"] = rows;
	companion["stage"] = companion_stage(companion);
	companion["memory_count"] = sizeof((mapping)companion["memories"]);
	companion["choices"] = copy_value((array)journey_config["memory_choices"]);
	if((int)companion["memory_count"]<9)
		companion["next_memory"] = copy_value((mapping)
			((array)journey_config["companion_memories"])[
				(int)companion["memory_count"]]);
	return companion;
}

private int current_echo_week(mapping progress)
{
	int starts_at = (int)progress["season_starts_at"];
	if(starts_at<=0)
		starts_at = (int)progress["joined_at"];
	if(starts_at<=0 || time()<starts_at)
		return 1;
	return min(60,max(1,(time()-starts_at)/(7*86400)+1));
}

private mapping public_encounter(mapping progress,mapping state,string mode)
{
	mapping encounter = copy_value((mapping)state["encounter"]);
	mapping rules = (mapping)journey_config["encounter_rules"];
	mapping active = encounter_config((string)encounter["active_id"]);
	int maximum = (int)rules["max_completions"];
	encounter["available"] = mode=="season";
	encounter["max_completions"] = maximum;
	encounter["remaining_kills"] = max(0,(int)encounter["next_at"]-
		(int)progress["kills"]);
	if(sizeof(active)){
		encounter["active"] = copy_value(active);
		encounter["required_kills"] = (int)active["required_kills"];
		encounter["ready"] = (int)encounter["kills"]>=
			(int)active["required_kills"];
	}
	else
		encounter["active"] = ([]);
	encounter["finished"] = (int)encounter["completed"]>=maximum;
	return encounter;
}

private mapping public_echo(mapping progress,mapping state,string mode)
{
	mapping echo = copy_value((mapping)state["echo"]);
	array rotations = (array)journey_config["echo_rotations"];
	int week = current_echo_week(progress);
	mapping rotation = (mapping)rotations[(week-1)%sizeof(rotations)];
	mapping completed = (mapping)echo["completed_weeks"];
	int stage = ((int)echo["week"]==week &&
		(string)echo["rotation"]==(string)rotation["id"]) ?
		(int)echo["stage"] : 0;
	echo["available"] = mode=="season" && claimed_chapter_count(progress)>=81;
	echo["week"] = week;
	echo["rotation"] = (string)rotation["id"];
	echo["title"] = (string)rotation["title"];
	echo["stage"] = stage;
	echo["completed"] = (int)completed[(string)week]>0;
	if(!(int)echo["completed"] && stage<3)
		echo["target"] = copy_value((mapping)((array)rotation["stages"])[stage]);
	else
		echo["target"] = ([]);
	return echo;
}

private mapping public_resonance(object player,mapping state)
{
	mapping companion = (mapping)state["companion"];
	mapping active_set = NEWMOON_SET_SKILLD->query_active_set_skill(player);
	int secrets = sizeof((mapping)state["secrets"]);
	int memories = sizeof((mapping)companion["memories"]);
	int has_companion = (string)companion["active_id"]!="";
	int tier;
	if(has_companion && secrets>=3)
		tier = 1;
	if(has_companion && secrets>=6 && sizeof(active_set))
		tier = 2;
	if(has_companion && secrets>=9 && memories>=9 && sizeof(active_set))
		tier = 3;
	return (["tier":tier,"name":({"尚未共鸣","同行初鸣",
		"三途共振","人间满月"})[tier],"secret_count":secrets,
		"memory_count":memories,"has_companion":has_companion,
		"full_set":sizeof(active_set)>0,
		"set_name":sizeof(active_set) ? (string)active_set["name_cn"] : ""]);
}

private mapping current_signature(mapping progress,mapping state)
{
	int claimed = claimed_chapter_count(progress);
	mapping saved = (mapping)state["signature_trials"];
	foreach((array)journey_config["signature_trials"],mapping trial){
		mapping one = mappingp(saved[(string)trial["id"]]) ?
			(mapping)saved[(string)trial["id"]] :
			(["stage":0,"kills":0,"updated_at":0,"completed_at":0]);
		if((int)one["stage"]>=3)
			continue;
		if(claimed<(int)trial["unlock_claimed"])
			return ([]);
		mapping stage = (mapping)((array)trial["stages"])[(int)one["stage"]];
		int required = (string)stage["kind"]=="ritual" ? 0 :
			(int)stage["required_kills"];
		return copy_value(trial)+(["stage":(int)one["stage"],
			"completed_stages":(int)one["stage"],
			"current_stage":copy_value(stage),"kills":(int)one["kills"],
			"required_kills":required,
			"ready":required>0 && (int)one["kills"]>=required]);
	}
	return ([]);
}

private mapping public_signatures(mapping progress,mapping state,string mode)
{
	mapping saved = (mapping)state["signature_trials"];
	array rows = ({});
	int claimed = claimed_chapter_count(progress);
	int completed;
	foreach((array)journey_config["signature_trials"],mapping trial){
		mapping one = mappingp(saved[(string)trial["id"]]) ?
			(mapping)saved[(string)trial["id"]] : ([]);
		int done = (int)one["stage"]>=3;
		completed += done;
		rows += ({(["id":(string)trial["id"],"volume":(int)trial["volume"],
			"title":(string)trial["title"],"mechanic":(string)trial["mechanic"],
			"unlocked":claimed>=(int)trial["unlock_claimed"],
			"completed":done,"stage":(int)one["stage"]])});
	}
	return (["available":mode=="season","completed":completed,"total":9,
		"rows":rows,"current":current_signature(progress,state)]);
}

private mapping public_route_arc(mapping progress,mapping state,string mode)
{
	string path = (string)(progress["path"] || "");
	mapping route = route_arc_config(path);
	mapping saved = (mapping)state["route_arc"];
	int stage = (string)saved["path"]==path ? (int)saved["stage"] : 0;
	int kills = (string)saved["path"]==path ? (int)saved["kills"] : 0;
	mapping current = ([]);
	int claimed = claimed_chapter_count(progress);
	if(sizeof(route) && stage<6){
		current = copy_value((mapping)((array)route["stages"])[stage]);
		current["index"] = stage;
		current["kills"] = kills;
		current["unlocked"] = claimed>=(int)current["unlock_claimed"];
	}
	return (["available":mode=="season" && sizeof(route)>0,
		"path":path,"title":(string)(route["title"] || "尚未选择命途"),
		"description":(string)(route["description"] || ""),
		"stage":stage,"total":6,"completed":stage>=6,
		"path_mismatch":(string)saved["path"]!="" &&
			(string)saved["path"]!=path,"current":current]);
}

private int pact_slot_count(mapping progress)
{
	int claimed = claimed_chapter_count(progress);
	int slots;
	foreach((array)journey_config["pact_slots"],mixed unlock)
		if(claimed>=(int)unlock)
			slots++;
	return slots;
}

private mapping pact_modifiers(mapping state)
{
	mapping pacts = (mapping)state["pacts"];
	array active = arrayp(pacts["active"]) ? (array)pacts["active"] : ({});
	int outgoing = 100;
	int incoming = 100;
	foreach(active,mixed id){
		mapping pact = stringp(id) ? pact_config((string)id) : ([]);
		if(sizeof(pact)){
			outgoing += (int)pact["outgoing_delta"];
			incoming += (int)pact["incoming_delta"];
		}
	}
	return (["outgoing_percent":max(85,min(115,outgoing)),
		"incoming_percent":max(85,min(120,incoming))]);
}

private mapping public_pacts(mapping progress,mapping state,string mode)
{
	mapping stored = (mapping)state["pacts"];
	array active = arrayp(stored["active"]) ? (array)stored["active"] : ({});
	array rows = ({});
	foreach((array)journey_config["pact_catalog"],mapping pact)
		rows += ({copy_value(pact)+(["active":
			search(active,(string)pact["id"])!=-1])});
	return (["available":mode=="season","slots":pact_slot_count(progress),
		"active":active+({}),"catalog":rows])+pact_modifiers(state);
}

private mapping public_loot_focus(mapping progress,mapping state,string mode)
{
	mapping stored = (mapping)state["loot_focus"];
	string selected = (string)stored["kind"];
	array rows = ({});
	foreach((array)journey_config["loot_focus_catalog"],mapping row)
		rows += ({copy_value(row)+(["active":selected==(string)row["id"]])});
	return (["available":mode=="season" && claimed_chapter_count(progress)>=81,
		"kind":selected,"name":selected=="all" ? "全职业全部位" :
			(string)loot_focus_config(selected)["name"],"catalog":rows]);
}

string query_newmoon_drop_focus(object player)
{
	mapping progress;
	mapping state;
	mapping focus;
	mapping context;
	if(!player || !config_valid)
		return "all";
	context = is_test_journey_player(player) ?
		(["ok":1,"mode":"season","illusion_id":"S1"]) :
		SEASONALD->query_player_progress(player);
	if(!(int)context["ok"] || (string)context["mode"]!="season" ||
	   (string)context["illusion_id"]!="S1")
		return "all";
	progress = raw_progress(player);
	if(claimed_chapter_count(progress)<81)
		return "all";
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	focus = sizeof(state) ? (mapping)state["loot_focus"] : ([]);
	return sizeof(loot_focus_config((string)focus["kind"])) ?
		(string)focus["kind"] : "all";
}

mapping(string:int) query_pact_combat_modifiers(object player)
{
	mapping progress;
	mapping state;
	mapping pacts;
	mapping cache;
	mapping(string:int) seen = ([]);
	array active;
	string signature;
	if(!player || !config_valid)
		return (["outgoing_percent":100,"incoming_percent":100]);
	progress = raw_progress(player);
	state = sizeof(progress) && mappingp(progress[JOURNEY_KEY]) ?
		(mapping)progress[JOURNEY_KEY] : ([]);
	pacts = mappingp(state["pacts"]) ? (mapping)state["pacts"] : ([]);
	active = arrayp(pacts["active"]) ? (array)pacts["active"] : ({});
	if((string)state["owner_id"]!=(string)player->query_name() ||
	   (string)state["registration_account"]!=owner_account(player) ||
	   sizeof(active)>3 || !valid_timestamp(pacts["changed_at"]))
		return (["outgoing_percent":100,"incoming_percent":100]);
	foreach(active,mixed id)
		if(!stringp(id) || seen[(string)id] ||
		   !sizeof(pact_config((string)id)))
			return (["outgoing_percent":100,"incoming_percent":100]);
		else
			seen[(string)id] = 1;
	signature = active*"|"+":"+(string)(int)pacts["changed_at"];
	cache = mappingp(player[PACT_COMBAT_CACHE]) ?
		(mapping)player[PACT_COMBAT_CACHE] : ([]);
	if((string)cache["signature"]==signature &&
	   (int)cache["outgoing_percent"]>=85 &&
	   (int)cache["outgoing_percent"]<=115 &&
	   (int)cache["incoming_percent"]>=85 &&
	   (int)cache["incoming_percent"]<=120)
		return (["outgoing_percent":(int)cache["outgoing_percent"],
			"incoming_percent":(int)cache["incoming_percent"]]);
	cache = pact_modifiers(state)+(["signature":signature]);
	player[PACT_COMBAT_CACHE] = cache;
	return (["outgoing_percent":(int)cache["outgoing_percent"],
		"incoming_percent":(int)cache["incoming_percent"]]);
}

private mapping(string:mixed) query_journey_internal(object player,
	int test_bypass_context)
{
	mapping progress_view;
	mapping progress;
	mapping state;
	array quest_rows = ({});
	if(!config_valid || !player)
		return (["ok":0,"message":"新月回响配置未通过安全校验。"]) ;
	progress_view = test_bypass_context && is_test_journey_player(player) ?
		(["ok":1,"mode":"season","illusion_id":"S1"]) :
		SEASONALD->query_player_progress(player);
	if(!(int)progress_view["ok"] ||
	   (string)progress_view["illusion_id"]!="S1")
		return (["ok":0,"message":"当前人物没有可进行的S1新月回响。"]) ;
	progress = raw_progress(player);
	if(!sizeof(progress))
		return (["ok":0,"message":"S1人物进度暂不可验证。"]) ;
	state = state_for(player,progress);
	if(!sizeof(state))
		return (["ok":0,"security_blocked":1,
			"message":"新月回响记录所有者或结构异常，已冻结写入以保护人物档案。"]) ;
	foreach((array)journey_config["side_quests"],mapping quest){
		mapping one = mappingp(((mapping)state["side_quests"])[
			(string)quest["id"]]) ? (mapping)((mapping)state["side_quests"])[
			(string)quest["id"]] : ([]);
		quest_rows += ({(["id":(string)quest["id"],
			"volume":(int)quest["volume"],"title":(string)quest["title"],
			"act":(int)one["act"],"completed":(int)one["act"]>=4,
			"unlocked":claimed_chapter_count(progress)>=
				(int)quest["unlock_claimed"]])});
	}
	return (["ok":1,"mode":(string)progress_view["mode"],
		"illusion_id":"S1","display_name":(string)journey_config["display_name"],
		"chapter_claimed":claimed_chapter_count(progress),
		"quests":quest_rows,"current_quest":current_quest_view(progress,state),
		"secrets":copy_value((mapping)state["secrets"]),
		"secret_catalog":copy_value((array)journey_config["secrets"]),
		"gate_substitutions":copy_value((mapping)state["gate_substitutions"]),
		"companion":public_companion(state),
		"encounter":public_encounter(progress,state,
			(string)progress_view["mode"]),
		"echo":public_echo(progress,state,(string)progress_view["mode"]),
		"signatures":public_signatures(progress,state,
			(string)progress_view["mode"]),
		"route_arc":public_route_arc(progress,state,
			(string)progress_view["mode"]),
		"pacts":public_pacts(progress,state,(string)progress_view["mode"]),
		"loot_focus":public_loot_focus(progress,state,
			(string)progress_view["mode"]),
		"resonance":public_resonance(player,state),
		"community":SEASONALD->query_community_progress("S1")+
			copy_value((mapping)journey_config["community_goal"])]);
}

mapping(string:mixed) query_journey(object player)
{
	return query_journey_internal(player,0);
}

mapping(string:mixed) query_journey_for_test(object player)
{
	if(!is_test_journey_player(player))
		return (["ok":0,"message":"测试入口不可用。"]);
	return query_journey_internal(player,1);
}

private mapping save_state(object player,mapping old_all,mapping all_progress,
	mapping progress,mapping state,string action)
{
	mixed err;
	int saved;
	int published;
	int old_community_points;
	mapping old_progress = mappingp(old_all["S1"]) ?
		(mapping)old_all["S1"] : ([]);
	mapping old_state = mappingp(old_progress[JOURNEY_KEY]) ?
		(mapping)old_progress[JOURNEY_KEY] : ([]);
	old_community_points = (int)old_state["community_points"];
	progress["community_points"] = (int)state["community_points"];
	progress[JOURNEY_KEY] = state;
	all_progress["S1"] = progress;
	player[PROGRESS_ROOT] = all_progress;
	if(is_test_journey_player(player) &&
	   (int)journey_test_save_failures[(string)player->query_name()]>0){
		m_delete(journey_test_save_failures,(string)player->query_name());
		saved = 0;
	}
	else
		err = catch{ saved=player->save_with_result(); };
	if(err || !saved){
		player[PROGRESS_ROOT] = old_all;
		return (["ok":0,"message":"人物档案保存失败，本次新月回响操作已完整回滚。"]) ;
	}
	// Audit I/O is intentionally outside the commit result: a read-only disk or
	// log rotation failure must not turn a durable mutation into an ambiguous
	// client error that encourages a second action.
	catch{ Stdio.append_file(JOURNEY_LOG,sprintf(
		"%d|%s|user=%s|account=%s\n",time(),action,
		(string)player->query_name(),owner_account(player))); };
	if(!is_test_journey_player(player) &&
	   old_community_points!=(int)state["community_points"])
		catch{ published=SEASONALD->publish_journey_snapshot(player); };
	if(!published && !is_test_journey_player(player) &&
	   old_community_points!=(int)state["community_points"])
		werror("[ILLUSION_JOURNEY] 衍生排行快照待后续补写: %s action=%s\n",
			(string)player->query_name(),action);
	return (["ok":1]);
}

mapping(string:mixed) travel_to_current_quest(object player)
{
	mapping view = query_journey(player);
	mapping quest = mappingp(view["current_quest"]) ?
		(mapping)view["current_quest"] : ([]);
	mapping act = mappingp(quest["current_act"]) ?
		(mapping)quest["current_act"] : ([]);
	if(!(int)view["ok"] || !sizeof(quest) || !sizeof(act))
		return (["ok":0,"message":sizeof(quest) ?
			"当前秘迹步骤不可验证。" : "当前没有已开放的秘迹步骤。"]) ;
	return SEASONALD->travel_to_s1_feature_room(player,(string)act["room"],
		"journey:"+(string)quest["id"]+":"+(string)(int)quest["act"]);
}

mapping(string:mixed) start_current_quest_hunt(object player)
{
	mapping view = query_journey(player);
	mapping quest = mappingp(view["current_quest"]) ?
		(mapping)view["current_quest"] : ([]);
	mapping act = mappingp(quest["current_act"]) ?
		(mapping)quest["current_act"] : ([]);
	if(!(int)view["ok"] || !sizeof(quest) || !sizeof(act))
		return (["ok":0,"message":"当前没有可执行的新月支线战斗。"]);
	if((int)quest["act_ready"])
		return (["ok":0,"message":"本幕战斗目标已经完成，请记录战果并继续下一幕。"]);
	if((int)quest["act"]==3)
		return (["ok":0,"message":"这是卷末支线收束；请按幻境主线挑战本卷首领，胜利后再回来记录战果。"]);
	if(!environment(player) ||
	   !MAP_WORKERD->static_room_locations_match(file_name(environment(player)),
		(string)act["room"]))
		return (["ok":0,"message":"请先一键前往【"+
			(string)act["location"]+"】，再开启本幕支线挂机。"]);
	player["/tmp/illusion_journey_autofight"] = ([
		"illusion_id":"S1","quest_id":(string)quest["id"],
		"act":(int)quest["act"],"target_path":(string)act["target_path"],
		"target_room":(string)act["room"],
		"target_kills":(int)quest["required_kills"],"created_at":time(),
	]);
	AUTOFIGHTD->start_journey_autofight(player);
	return (["ok":1,"message":"§g【新月支线挂机】§r 已开启：只在【"+
		(string)act["location"]+"】完成“"+(string)act["target_name"]+
		"”的本幕目标；达到数量后自动停止并返回支线页。"]);
}

private mapping next_encounter(mapping progress,mapping state)
{
	array eligible = ({});
	mapping encounter = (mapping)state["encounter"];
	foreach((array)journey_config["wander_events"],mapping event)
		if(claimed_chapter_count(progress)>=(int)event["unlock_claimed"])
			eligible += ({event});
	if(!sizeof(eligible))
		return ([]);
	return (mapping)eligible[((int)progress["kills"]+
		(int)encounter["completed"])%sizeof(eligible)];
}

mapping(string:mixed) travel_to_active_encounter(object player)
{
	mapping view = query_journey(player);
	mapping encounter = mappingp(view["encounter"]) ?
		(mapping)view["encounter"] : ([]);
	mapping active = mappingp(encounter["active"]) ?
		(mapping)encounter["active"] : ([]);
	if(!(int)view["ok"] || !(int)encounter["available"] || !sizeof(active))
		return (["ok":0,"message":"当前没有可前往的新月偶遇战。"]);
	return SEASONALD->travel_to_s1_feature_room(player,(string)active["room"],
		"journey:encounter:"+(string)active["id"]);
}

mapping(string:mixed) travel_to_echo_target(object player)
{
	mapping view = query_journey(player);
	mapping echo = mappingp(view["echo"]) ? (mapping)view["echo"] : ([]);
	mapping target = mappingp(echo["target"]) ?
		(mapping)echo["target"] : ([]);
	if(!(int)view["ok"] || !(int)echo["available"] ||
	   (int)echo["completed"] || !sizeof(target))
		return (["ok":0,"message":"当前没有可前往的月蚀回廊目标。"]);
	return SEASONALD->travel_to_s1_feature_room(player,(string)target["room"],
		"journey:echo:"+(string)echo["rotation"]+":"+
		(string)((int)echo["stage"]+1));
}

mapping(string:mixed) travel_to_signature_target(object player)
{
	mapping view = query_journey(player);
	mapping signatures = mappingp(view["signatures"]) ?
		(mapping)view["signatures"] : ([]);
	mapping current = mappingp(signatures["current"]) ?
		(mapping)signatures["current"] : ([]);
	mapping stage = mappingp(current["current_stage"]) ?
		(mapping)current["current_stage"] : ([]);
	if(!(int)view["ok"] || !(int)signatures["available"] || !sizeof(stage))
		return (["ok":0,"message":"当前没有可前往的卷印试炼阶段。"]);
	return SEASONALD->travel_to_s1_feature_room(player,(string)stage["room"],
		"journey:signature:"+(string)current["id"]+":"+
		(string)((int)current["stage"]+1));
}

mapping(string:mixed) travel_to_route_arc_target(object player)
{
	mapping view = query_journey(player);
	mapping route = mappingp(view["route_arc"]) ?
		(mapping)view["route_arc"] : ([]);
	mapping current = mappingp(route["current"]) ?
		(mapping)route["current"] : ([]);
	if(!(int)view["ok"] || !(int)route["available"] ||
	   !(int)current["unlocked"] || !sizeof(current))
		return (["ok":0,"message":"当前命途历练尚未开放或已经完成。"]);
	return SEASONALD->travel_to_s1_feature_room(player,(string)current["room"],
		"journey:route:"+(string)route["path"]+":"+
		(string)((int)route["stage"]+1));
}

private mapping start_feature_hunt(object player,mapping target,string mode,
	string feature_id,string title)
{
	if(!player || !sizeof(target) ||
	   (string)target["kind"]=="ritual" ||
	   !environment(player) ||
	   !MAP_WORKERD->static_room_locations_match(file_name(environment(player)),
		(string)target["room"]))
		return (["ok":0,"message":"请先一键前往当前目标场景。"]);
	player["/tmp/illusion_journey_autofight"] = ([
		"illusion_id":"S1","mode":mode,"feature_id":feature_id,
		"target_path":(string)target["target_path"],
		"target_room":(string)target["room"],
		"target_kills":(int)target["required_kills"],"created_at":time(),
	]);
	AUTOFIGHTD->start_journey_autofight(player);
	return (["ok":1,"message":"§g【"+title+"】§r 已开启限定挂机；只攻击【"+
		(string)target["target_name"]+"】，本阶段完成后自动停止。"]);
}

mapping(string:mixed) start_signature_hunt(object player)
{
	mapping view = query_journey(player);
	mapping signatures = mappingp(view["signatures"]) ?
		(mapping)view["signatures"] : ([]);
	mapping current = mappingp(signatures["current"]) ?
		(mapping)signatures["current"] : ([]);
	mapping stage = mappingp(current["current_stage"]) ?
		(mapping)current["current_stage"] : ([]);
	if((string)stage["kind"]=="ritual")
		return (["ok":0,"message":"当前是场景仪式，请完成仪式而不是挂机。"]);
	return start_feature_hunt(player,stage,"signature",(string)current["id"],
		"卷印试炼挂机");
}

mapping(string:mixed) start_route_arc_hunt(object player)
{
	mapping view = query_journey(player);
	mapping route = mappingp(view["route_arc"]) ?
		(mapping)view["route_arc"] : ([]);
	mapping current = mappingp(route["current"]) ?
		(mapping)route["current"] : ([]);
	if(!(int)current["unlocked"])
		return (["ok":0,"message":"当前命途历练尚未开放。"]);
	return start_feature_hunt(player,current,"route",(string)route["path"],
		"命途历练挂机");
}

mapping(string:mixed) perform_signature_ritual(object player)
{
	object key;
	mapping old_all;
	mapping all_progress;
	mapping progress;
	mapping state;
	mapping current;
	mapping stage;
	mapping trial_states;
	mapping one;
	mapping saved;
	if(!player || !config_valid)
		return (["ok":0,"message":"卷印试炼暂不可用。"]);
	key = journey_lock->lock();
	old_all = copy_value((mapping)(player[PROGRESS_ROOT] || ([])));
	all_progress = copy_value(old_all);
	progress = mappingp(all_progress["S1"]) ?
		(mapping)all_progress["S1"] : ([]);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	current = sizeof(state) ? current_signature(progress,state) : ([]);
	stage = mappingp(current["current_stage"]) ?
		(mapping)current["current_stage"] : ([]);
	if(!sizeof(stage) || (string)stage["kind"]!="ritual" ||
	   !environment(player) ||
	   !MAP_WORKERD->static_room_locations_match(file_name(environment(player)),
		(string)stage["room"])){
		destruct(key);
		return (["ok":0,"message":"请先前往【"+
			(string)(stage["location"] || "当前仪式场景")+"】完成卷印仪式。"]);
	}
	trial_states = (mapping)state["signature_trials"];
	one = mappingp(trial_states[(string)current["id"]]) ?
		copy_value((mapping)trial_states[(string)current["id"]]) :
		(["stage":0,"kills":0,"updated_at":0,"completed_at":0]);
	one["stage"] = (int)one["stage"]+1;
	one["kills"] = 0;
	one["updated_at"] = time();
	trial_states[(string)current["id"]] = one;
	state["signature_trials"] = trial_states;
	saved = save_state(player,old_all,all_progress,progress,state,
		"signature_ritual:"+(string)current["id"]);
	destruct(key);
	if(!(int)saved["ok"])
		return saved;
	return (["ok":1,"message":"【"+(string)stage["title"]+"】\n"+
		(string)stage["text"]+"\n仪式完成，卷印试炼进入第二阶段。"]);
}

mapping(string:mixed) toggle_pact(object player,string pact_id)
{
	object key;
	mapping old_all;
	mapping all_progress;
	mapping progress;
	mapping state;
	mapping pacts;
	mapping saved;
	array active;
	int index;
	int slots;
	if(!sizeof(pact_config(pact_id)))
		return (["ok":0,"message":"月相契印不存在。"]);
	key = journey_lock->lock();
	old_all = copy_value((mapping)(player[PROGRESS_ROOT] || ([])));
	all_progress = copy_value(old_all);
	progress = mappingp(all_progress["S1"]) ?
		(mapping)all_progress["S1"] : ([]);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	if(!sizeof(state)){
		destruct(key);
		return (["ok":0,"message":"S1人物进度暂不可验证。"]);
	}
	pacts = (mapping)state["pacts"];
	active = ((array)pacts["active"])+({});
	index = search(active,pact_id);
	slots = pact_slot_count(progress);
	if(index!=-1)
		active = (index>0 ? active[..index-1] : ({}))+
			(index+1<sizeof(active) ? active[index+1..] : ({}));
	else if(sizeof(active)>=slots){
		destruct(key);
		return (["ok":0,"message":slots ?
			"契印槽已满，请先卸下一枚契印。" :
			"完成第18章后开放第一个月相契印槽。"]);
	}
	else
		active += ({pact_id});
	pacts["active"] = active;
	pacts["changed_at"] = time();
	state["pacts"] = pacts;
	saved = save_state(player,old_all,all_progress,progress,state,
		"pact_toggle:"+pact_id+":"+(index==-1 ? "on" : "off"));
	destruct(key);
	if(!(int)saved["ok"])
		return saved;
	return (["ok":1,"active":index==-1,"message":"月相契印【"+
		(string)pact_config(pact_id)["name"]+"】已"+
		(index==-1 ? "装配" : "卸下")+"。契印只作用于S1 PVE。"]);
}

mapping(string:mixed) set_loot_focus(object player,string kind)
{
	object key;
	mapping old_all;
	mapping all_progress;
	mapping progress;
	mapping state;
	mapping focus;
	mapping saved;
	if(kind!="all" && !sizeof(loot_focus_config(kind)))
		return (["ok":0,"message":"定向部位不存在。"]);
	key = journey_lock->lock();
	old_all = copy_value((mapping)(player[PROGRESS_ROOT] || ([])));
	all_progress = copy_value(old_all);
	progress = mappingp(all_progress["S1"]) ?
		(mapping)all_progress["S1"] : ([]);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	if(!sizeof(state) || claimed_chapter_count(progress)<81){
		destruct(key);
		return (["ok":0,"message":"完成S1八十一章后开放新月套装定向。"]);
	}
	focus = (mapping)state["loot_focus"];
	focus["kind"] = kind;
	focus["changed_at"] = time();
	state["loot_focus"] = focus;
	saved = save_state(player,old_all,all_progress,progress,state,
		"loot_focus:"+kind);
	destruct(key);
	if(!(int)saved["ok"])
		return saved;
	return (["ok":1,"message":kind=="all" ?
		"已取消套装部位定向，恢复全职业全槽位随机。" :
		"已定向【"+(string)loot_focus_config(kind)["name"]+
		"】；只在下一次合法命中新月套装掉落时缩小模板池，不增加掉率或品质。"]);
}

private mapping(string:mixed) record_npc_kill_internal(object player,object npc,
	int test_bypass_active)
{
	object key;
	mapping old_all;
	mapping all_progress;
	mapping progress;
	mapping state;
	mapping quest;
	mapping quest_states = ([]);
	mapping one = ([]);
	mapping act = ([]);
	mapping events;
	mapping saved;
	mapping task_mode;
	mapping encounter;
	mapping active_event;
	mapping echo;
	mapping rotation;
	mapping echo_target;
	mapping progress_view;
	mapping signature;
	mapping signature_stage;
	mapping signature_states;
	mapping signature_one;
	mapping route_arc;
	mapping route_config;
	mapping route_stage;
	string npc_path;
	string room_path;
	string route_path;
	string message = "";
	string action = "journey_kill";
	int act_index;
	int kills;
	int required;
	int sidequest_complete;
	int sidequest_credited;
	int encounter_credited;
	int encounter_activated;
	int echo_credited;
	int signature_credited;
	int signature_stage_complete;
	int route_credited;
	int route_stage_complete;
	int changed;
	int live;
	if(!player || !npc || !config_valid || !environment(player) ||
	   environment(npc)!=environment(player))
		return (["ok":0,"credited":0]);
	string credit_marker = "/tmp/illusion_journey_credit/"+
		(string)player->query_name();
	if((int)npc[credit_marker])
		return (["ok":1,"credited":0,"duplicate":1]);
	npc_path = normalized_object_path(npc);
	room_path = normalized_object_path(environment(player));
	progress_view = SEASONALD->query_player_progress(player);
	live = test_bypass_active && is_test_journey_player(player) ? 1 :
		((int)progress_view["ok"] &&
		(string)progress_view["illusion_id"]=="S1" &&
		(string)progress_view["mode"]=="season");
	key = journey_lock->lock();
	old_all = copy_value((mapping)(player[PROGRESS_ROOT] || ([])));
	all_progress = copy_value(old_all);
	progress = mappingp(all_progress["S1"]) ?
		(mapping)all_progress["S1"] : ([]);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	if(!sizeof(state)){
		destruct(key);
		return (["ok":0,"credited":0]);
	}
	quest = current_quest(progress,state);
	events = mappingp(progress["story_events"]) ?
		(mapping)progress["story_events"] : ([]);
	if(sizeof(quest)){
		quest_states = (mapping)state["side_quests"];
		one = mappingp(quest_states[(string)quest["id"]]) ?
			copy_value((mapping)quest_states[(string)quest["id"]]) :
			(["act":0,"act_kills":0,"started_at":time()]);
		act_index = (int)one["act"];
		act = (mapping)((array)quest["acts"])[act_index];
		required = (int)act["required_kills"];
		if(npc_path==(string)act["target_path"] &&
		   MAP_WORKERD->static_room_locations_match(room_path,
			(string)act["room"]) &&
		   (act_index<3 || (int)events[(string)quest["final_event"]])){
			kills = min(required,(int)one["act_kills"]);
			if(act_index==3)
				kills = required;
			else if(kills<required)
				kills++;
			if(kills>(int)one["act_kills"]){
				one["act_kills"] = kills;
				one["updated_at"] = time();
				quest_states[(string)quest["id"]] = one;
				state["side_quests"] = quest_states;
				sidequest_credited = changed = 1;
				sidequest_complete = kills>=required;
				action = "sidequest_kill:"+(string)quest["id"]+":"+
					(string)(act_index+1)+":"+(string)kills;
				message = "§p【新月支线】§r "+
					(string)act["target_name"]+" "+(string)kills+"/"+
					(string)required+(sidequest_complete ?
					"，本幕战斗目标已经完成。" : "。");
			}
		}
	}

	if(live){
		signature = current_signature(progress,state);
		signature_stage = mappingp(signature["current_stage"]) ?
			(mapping)signature["current_stage"] : ([]);
		if(sizeof(signature_stage) &&
		   (string)signature_stage["kind"]!="ritual" &&
		   npc_path==(string)signature_stage["target_path"] &&
		   MAP_WORKERD->static_room_locations_match(room_path,
			(string)signature_stage["room"])){
			signature_states = (mapping)state["signature_trials"];
			signature_one = mappingp(signature_states[(string)signature["id"]]) ?
				copy_value((mapping)signature_states[(string)signature["id"]]) :
				(["stage":0,"kills":0,"updated_at":0,"completed_at":0]);
			required = (int)signature_stage["required_kills"];
			kills = min(required,(int)signature_one["kills"]+1);
			signature_one["kills"] = kills;
			signature_one["updated_at"] = time();
			signature_credited = changed = 1;
			if(kills>=required){
				signature_one["stage"] = (int)signature_one["stage"]+1;
				signature_one["kills"] = 0;
				signature_stage_complete = 1;
				if((int)signature_one["stage"]>=3){
					signature_one["completed_at"] = time();
					state["community_points"] =
						(int)state["community_points"]+25;
				}
			}
			signature_states[(string)signature["id"]] = signature_one;
			state["signature_trials"] = signature_states;
			action = "signature_kill:"+(string)signature["id"]+":"+
				(string)((int)signature["stage"]+1)+":"+(string)kills;
			message += (message!="" ? "\n" : "")+
				"§y【卷印试炼】§r "+(string)signature_stage["target_name"]+
				" "+(string)kills+"/"+(string)required+
				(signature_stage_complete ?
				 ((int)signature_one["stage"]>=3 ?
				  "，本卷标志试炼完成。" : "，本阶段完成。") : "。");
		}
	}

	if(live){
		route_path = (string)(progress["path"] || "");
		route_config = route_arc_config(route_path);
		route_arc = copy_value((mapping)state["route_arc"]);
		if(sizeof(route_config) &&
		   ((string)route_arc["path"]=="" ||
		    (string)route_arc["path"]==route_path) &&
		   (int)route_arc["stage"]<6){
			route_stage = (mapping)((array)route_config["stages"])[
				(int)route_arc["stage"]];
			if(claimed_chapter_count(progress)>=(int)route_stage["unlock_claimed"] &&
			   npc_path==(string)route_stage["target_path"] &&
			   MAP_WORKERD->static_room_locations_match(room_path,
				(string)route_stage["room"])){
				route_arc["path"] = route_path;
				required = (int)route_stage["required_kills"];
				kills = min(required,(int)route_arc["kills"]+1);
				route_arc["kills"] = kills;
				route_credited = changed = 1;
				if(kills>=required){
					route_arc["stage"] = (int)route_arc["stage"]+1;
					route_arc["kills"] = 0;
					route_stage_complete = 1;
					state["community_points"] =
						(int)state["community_points"]+15;
					if((int)route_arc["stage"]>=6)
						route_arc["completed_at"] = time();
				}
				state["route_arc"] = route_arc;
				action = "route_arc:"+route_path+":"+
					(string)((int)route_arc["stage"]+1)+":"+(string)kills;
				message += (message!="" ? "\n" : "")+
					"§p【命途历练】§r "+(string)route_stage["target_name"]+
					" "+(string)kills+"/"+(string)required+
					(route_stage_complete ?
					 ((int)route_arc["stage"]>=6 ?
					  "，六段命途篇章完成。" : "，本段完成。") : "。");
			}
		}
	}

	encounter = copy_value((mapping)state["encounter"]);
	if(live && (int)encounter["completed"]<
	   (int)((mapping)journey_config["encounter_rules"])["max_completions"]){
		active_event = encounter_config((string)encounter["active_id"]);
		if(sizeof(active_event) &&
		   npc_path==(string)active_event["target_path"] &&
		   MAP_WORKERD->static_room_locations_match(room_path,
			(string)active_event["room"]) &&
		   (int)encounter["kills"]<(int)active_event["required_kills"]){
			encounter["kills"] = (int)encounter["kills"]+1;
			encounter_credited = changed = 1;
			if((int)encounter["kills"]>=(int)active_event["required_kills"]){
				int points = (int)active_event["community_points"]+
					(int)public_resonance(player,state)["tier"]*2;
				encounter["completed"] = (int)encounter["completed"]+1;
				encounter["last_completed_at"] = time();
				encounter["next_at"] = (int)progress["kills"]+
					(int)((mapping)journey_config["encounter_rules"])[
						"interval_kills"];
				encounter["active_id"] = "";
				encounter["kills"] = 0;
				encounter["activated_at"] = 0;
				state["community_points"] =
					(int)state["community_points"]+points;
				message += (message!="" ? "\n" : "")+
					"§y【月下偶遇完成】§r "+(string)active_event["title"]+
					"，为全服同心筑月贡献 "+(string)points+" 点。";
			}
			else
				message += (message!="" ? "\n" : "")+
					"§y【月下偶遇】§r "+(string)active_event["target_name"]+
					" "+(string)(int)encounter["kills"]+"/"+
					(string)(int)active_event["required_kills"]+"。";
		}
		else if(!sizeof(active_event) &&
		   (int)progress["kills"]>=(int)encounter["next_at"]){
			active_event = next_encounter(progress,state);
			if(sizeof(active_event)){
				encounter["active_id"] = (string)active_event["id"];
				encounter["kills"] = 0;
				encounter["activated_at"] = time();
				encounter_activated = changed = 1;
				message += (message!="" ? "\n" : "")+
					"§y【月下偶遇】§r "+(string)active_event["title"]+
					"已经出现，可从新月支线页一键前往。";
			}
		}
		state["encounter"] = encounter;
	}

	if(live && claimed_chapter_count(progress)>=81){
		int week = current_echo_week(progress);
		array rotations = (array)journey_config["echo_rotations"];
		rotation = (mapping)rotations[(week-1)%sizeof(rotations)];
		echo = copy_value((mapping)state["echo"]);
		if((int)echo["week"]!=week ||
		   (string)echo["rotation"]!=(string)rotation["id"]){
			echo["week"] = week;
			echo["rotation"] = (string)rotation["id"];
			echo["stage"] = 0;
		}
		if(!(int)((mapping)echo["completed_weeks"])[(string)week] &&
		   (int)echo["stage"]<3){
			echo_target = (mapping)((array)rotation["stages"])[
				(int)echo["stage"]];
			if(npc_path==(string)echo_target["target_path"] &&
			   MAP_WORKERD->static_room_locations_match(room_path,
				(string)echo_target["room"])){
				echo["stage"] = (int)echo["stage"]+1;
				state["community_points"] =
					(int)state["community_points"]+30;
				echo_credited = changed = 1;
				message += (message!="" ? "\n" : "")+
					"§p【月蚀回廊】§r 击败"+
					(string)echo_target["target_name"]+"，本周 "+
					(string)(int)echo["stage"]+"/3，为同心筑月贡献30点。";
				if((int)echo["stage"]>=3){
					((mapping)echo["completed_weeks"])[(string)week] = time();
					echo["last_completed_at"] = time();
					message += "\n§g本周回廊三战已经完成；下周会轮换另一组旧敌。§r";
				}
			}
		}
		state["echo"] = echo;
	}

	if(!changed){
		destruct(key);
		return (["ok":1,"credited":0]);
	}
	saved = save_state(player,old_all,all_progress,progress,state,action+
		(encounter_credited ? ":encounter" : "")+
		(echo_credited ? ":echo" : "")+
		(signature_credited ? ":signature" : "")+
		(route_credited ? ":route" : "")+
		(encounter_activated ? ":activated" : ""));
	destruct(key);
	if(!(int)saved["ok"])
		return saved+(["credited":0]);
	npc[credit_marker] = 1;
	task_mode = mappingp(player["/tmp/illusion_journey_autofight"]) ?
		(mapping)player["/tmp/illusion_journey_autofight"] : ([]);
	if(sidequest_complete && (string)task_mode["quest_id"]==(string)quest["id"] &&
	   (int)task_mode["act"]==act_index){
		AUTOFIGHTD->stop_autofight(player);
		player->m_delete_foruser("/tmp/illusion_journey_autofight");
		AUTOFIGHTD->publish_server_autofight_final_view(player,
			"§y【新月支线战斗完成】§r 已停止本幕挂机。\n"+
			"目标："+(string)act["target_name"]+" "+(string)kills+"/"+
			(string)required+"\n"+
			"[记录战果并进入下一幕:illusion_journey advance]|"+
			"[返回游戏:look]\n");
	}
	else if(signature_stage_complete && (string)task_mode["mode"]=="signature" &&
	   (string)task_mode["feature_id"]==(string)signature["id"]){
		AUTOFIGHTD->stop_autofight(player);
		AUTOFIGHTD->publish_server_autofight_final_view(player,
			"§y【卷印试炼阶段完成】§r 已停止限定挂机。\n"+
			"[继续卷印试炼:illusion_journey signatures]|[返回游戏:look]\n");
	}
	else if(route_stage_complete && (string)task_mode["mode"]=="route" &&
	   (string)task_mode["feature_id"]==route_path){
		AUTOFIGHTD->stop_autofight(player);
		AUTOFIGHTD->publish_server_autofight_final_view(player,
			"§p【命途历练阶段完成】§r 已停止限定挂机。\n"+
			"[继续命途历练:illusion_journey route]|[返回游戏:look]\n");
	}
	return (["ok":1,"credited":sidequest_credited || encounter_credited ||
		echo_credited || signature_credited || route_credited,
		"activated":encounter_activated,
		"complete":sidequest_complete,"kills":kills,
		"required":required,"message":message]);
}

mapping(string:mixed) record_npc_kill(object player,object npc)
{
	return record_npc_kill_internal(player,npc,0);
}

mapping(string:mixed) record_npc_kill_for_test(object player,object npc)
{
	if(!is_test_journey_player(player))
		return (["ok":0,"credited":0,"message":"测试入口不可用。"]);
	return record_npc_kill_internal(player,npc,1);
}

mapping(string:mixed) advance_current_quest(object player)
{
	object key;
	mapping old_all;
	mapping all_progress;
	mapping progress;
	mapping state;
	mapping quest;
	mapping quest_states;
	mapping one;
	mapping act;
	mapping events;
	mapping saved;
	int act_index;
	if(!player || !config_valid)
		return (["ok":0,"message":"新月回响暂不可用。"]) ;
	key = journey_lock->lock();
	old_all = copy_value((mapping)(player[PROGRESS_ROOT] || ([])));
	all_progress = copy_value(old_all);
	progress = mappingp(all_progress["S1"]) ?
		(mapping)all_progress["S1"] : ([]);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	quest = sizeof(state) ? current_quest(progress,state) : ([]);
	if(!sizeof(state) || !sizeof(quest)){
		destruct(key);
		return (["ok":0,"message":sizeof(state) ?
			"当前没有已开放的秘迹步骤。" :
			"新月回响记录校验失败，未写入任何数据。"]) ;
	}
	quest_states = (mapping)state["side_quests"];
	one = mappingp(quest_states[(string)quest["id"]]) ?
		copy_value((mapping)quest_states[(string)quest["id"]]) :
		(["act":0,"started_at":time()]);
	act_index = (int)one["act"];
	act = (mapping)((array)quest["acts"])[act_index];
	if(!environment(player) ||
	   !MAP_WORKERD->static_room_locations_match(file_name(environment(player)),
		(string)act["room"])){
		destruct(key);
		return (["ok":0,"message":"请先前往【"+(string)act["location"]+
			"】完成“"+(string)act["title"]+"”。"]);
	}
	if(act_index<3 &&
	   (int)one["act_kills"]<(int)act["required_kills"]){
		destruct(key);
		return (["ok":0,"message":"本幕是新月支线战斗任务；请击败【"+
			(string)act["target_name"]+"】 "+
			(string)(int)one["act_kills"]+"/"+
			(string)(int)act["required_kills"]+" 后再记录战果。"]);
	}
	if(act_index==3){
		events = mappingp(progress["story_events"]) ?
			(mapping)progress["story_events"] : ([]);
		if(!(int)events[(string)quest["final_event"]]){
			destruct(key);
			return (["ok":0,"message":"卷末关键剧情尚未完成；请先按主线击败或见证当前卷末事件，再回来收束秘迹。"]) ;
		}
	}
	one["act"] = act_index+1;
	one["act_kills"] = 0;
	one["updated_at"] = time();
	if(act_index==3){
		one["completed_at"] = time();
		((mapping)state["secrets"])[(string)quest["secret_id"]] = time();
		((mapping)state["gate_substitutions"])[(string)quest["gate_id"]] = time();
	}
	quest_states[(string)quest["id"]] = one;
	state["side_quests"] = quest_states;
	saved = save_state(player,old_all,all_progress,progress,state,
		"sidequest:"+(string)quest["id"]+":"+(string)(act_index+1));
	destruct(key);
	if(!(int)saved["ok"])
		return saved;
	player->m_delete_foruser("/tmp/illusion_journey_autofight");
	return (["ok":1,"completed":act_index==3,
		"message":"【新月支线·"+(string)act["title"]+"】\n"+(string)act["text"]+
			(act_index==3 ? "\n支线完成：获得行旅秘术【"+
			 (string)secret_config((string)quest["secret_id"])["name"]+
			 "】；本卷剧情凭证已确定写入，不再强制依赖随机掉落。" :
			 "\n本幕支线战果已经记录，可以继续下一幕。")]);
}

private string new_pet_id(object player,string species_id)
{
	object hash = Crypto.SHA256();
	hash->update((string)player->query_name()+"|"+owner_account(player)+
		"|S1|"+species_id+"|"+(string)time()+"|"+
		String.string2hex(Crypto.Random.random_string(16)));
	return lower_case(String.string2hex(hash->digest()));
}

private void add_species(object player,mapping companion,string species_id)
{
	mapping pets = (mapping)companion["pets"];
	if(mappingp(pets[species_id]))
		return;
	pets[species_id] = (["id":new_pet_id(player,species_id),
		"species":species_id,"joined_at":time()]);
	companion["pets"] = pets;
	if((string)companion["active_id"]=="")
		companion["active_id"] = species_id;
}

mapping(string:mixed) choose_starter_companion(object player,string species_id)
{
	object key;
	mapping old_all;
	mapping all_progress;
	mapping progress;
	mapping state;
	mapping companion;
	mapping quest_state;
	mapping saved;
	if(search(({"ink_tail","fog_horn","mirror_fin"}),species_id)==-1)
		return (["ok":0,"message":"首只月忆兽只能从墨尾、雾角、镜鳍中选择。"]) ;
	key = journey_lock->lock();
	old_all = copy_value((mapping)(player[PROGRESS_ROOT] || ([])));
	all_progress = copy_value(old_all);
	progress = mappingp(all_progress["S1"]) ?
		(mapping)all_progress["S1"] : ([]);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	quest_state = sizeof(state) && mappingp(((mapping)state["side_quests"])[
		"ink_without_name"]) ? (mapping)((mapping)state["side_quests"])[
		"ink_without_name"] : ([]);
	if(!sizeof(state) || (int)quest_state["act"]<4){
		destruct(key);
		return (["ok":0,"message":"完成第一卷秘迹《墨下无名》后，才能唤醒无名月茧。"]) ;
	}
	companion = (mapping)state["companion"];
	if(sizeof((mapping)companion["pets"])){
		destruct(key);
		return (["ok":0,"message":"无名月茧已经孵化，不能用重复选择覆盖月忆兽档案。"]) ;
	}
	add_species(player,companion,species_id);
	state["companion"] = companion;
	saved = save_state(player,old_all,all_progress,progress,state,
		"companion_choose:"+species_id);
	destruct(key);
	if(!(int)saved["ok"])
		return saved;
	return (["ok":1,"message":"无名月茧孵化为【"+
		(string)species_config(species_id)["name"]+"】。它只属于本S1人物档案，当前不会改写共享宠物或本命灵伴。"]);
}

mapping(string:mixed) choose_active_companion(object player,string species_id)
{
	object key;
	mapping old_all;
	mapping all_progress;
	mapping progress;
	mapping state;
	mapping companion;
	mapping saved;
	key = journey_lock->lock();
	old_all = copy_value((mapping)(player[PROGRESS_ROOT] || ([])));
	all_progress = copy_value(old_all);
	progress = mappingp(all_progress["S1"]) ?
		(mapping)all_progress["S1"] : ([]);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	companion = sizeof(state) ? (mapping)state["companion"] : ([]);
	if(!sizeof(companion) || !mappingp(((mapping)companion["pets"])[species_id])){
		destruct(key);
		return (["ok":0,"message":"这只月忆兽尚未加入你的行旅图鉴。"]) ;
	}
	companion["active_id"] = species_id;
	state["companion"] = companion;
	saved = save_state(player,old_all,all_progress,progress,state,
		"companion_active:"+species_id);
	destruct(key);
	if(!(int)saved["ok"])
		return saved;
	return (["ok":1,"message":"当前同行月忆兽已切换为【"+
		(string)species_config(species_id)["name"]+"】。这是探索同行选择，不占用或覆盖旧宠物战斗位。"]);
}

mapping(string:mixed) claim_companion_memory(object player,string choice_id)
{
	object key;
	mapping choice = find_by_id((array)(journey_config["memory_choices"] || ({})),choice_id);
	mapping old_all;
	mapping all_progress;
	mapping progress;
	mapping state;
	mapping companion;
	mapping memories;
	mapping quest_states;
	mapping memory;
	mapping saved;
	int volume;
	if(!sizeof(choice))
		return (["ok":0,"message":"月忆选择无效，本次没有写入档案。"]) ;
	key = journey_lock->lock();
	old_all = copy_value((mapping)(player[PROGRESS_ROOT] || ([])));
	all_progress = copy_value(old_all);
	progress = mappingp(all_progress["S1"]) ?
		(mapping)all_progress["S1"] : ([]);
	state = sizeof(progress) ? state_for(player,progress) : ([]);
	companion = sizeof(state) ? (mapping)state["companion"] : ([]);
	if(!sizeof(companion) || !sizeof((mapping)companion["pets"])){
		destruct(key);
		return (["ok":0,"message":"请先完成第一卷秘迹并选择初始月忆兽。"]) ;
	}
	memories = (mapping)companion["memories"];
	volume = sizeof(memories)+1;
	if(volume<1 || volume>9){
		destruct(key);
		return (["ok":0,"message":"九卷月忆已经全部完成。"]) ;
	}
	quest_states = (mapping)state["side_quests"];
	mapping volume_quest = (mapping)((array)journey_config["side_quests"])[volume-1];
	if(!mappingp(quest_states[(string)volume_quest["id"]]) ||
	   (int)((mapping)quest_states[(string)volume_quest["id"]])["act"]<4){
		destruct(key);
		return (["ok":0,"message":"请先完成第"+(string)volume+
			"卷秘迹，再记录这一段月忆。"]) ;
	}
	memory = (mapping)((array)journey_config["companion_memories"])[volume-1];
	memories[(string)volume] = (["choice":choice_id,"claimed_at":time()]);
	companion["memories"] = memories;
	((mapping)companion["traits"])[(string)choice["trait"]] =
		(int)((mapping)companion["traits"])[(string)choice["trait"]]+1;
	if((string)memory["rescue"]!="")
		add_species(player,companion,(string)memory["rescue"]);
	state["companion"] = companion;
	saved = save_state(player,old_all,all_progress,progress,state,
		"companion_memory:"+(string)volume+":"+choice_id);
	destruct(key);
	if(!(int)saved["ok"])
		return saved;
	return (["ok":1,"volume":volume,"stage":companion_stage(companion),
		"message":"【月忆·"+(string)memory["title"]+"】\n"+
			(string)memory["text"]+"\n你的选择："+(string)choice["name"]+
			((string)memory["rescue"]!="" ? "\n图鉴新增：【"+
			 (string)species_config((string)memory["rescue"])["name"]+"】" : "")]);
}

mapping(string:mixed) use_secret(object player,string secret_id)
{
	mapping view = query_journey(player);
	mapping config = secret_config(secret_id);
	mapping progress;
	string room_name = "当前场景";
	string insight;
	if(!(int)view["ok"] || !sizeof(config) ||
	   !(int)((mapping)view["secrets"])[secret_id])
		return (["ok":0,"message":"这项行旅秘术尚未取得。"]) ;
	if(environment(player) && functionp(environment(player)->query_name_cn))
		room_name = (string)environment(player)->query_name_cn();
	progress = SEASONALD->query_player_progress(player);
	switch(secret_id){
	case "hidden_name_trace":
		insight = "月光掠过"+room_name+"，被反复涂抹的旧笔画在墙角短暂复原。";
		break;
	case "fog_oath_hearing":
		insight = "雾角替你分开誓言与恐惧：承诺是否真实，要看承担代价的人是谁。";
		break;
	case "borrow_blank_page":
		insight = "空经借页写下当前真正缺少的一步：继续第"+
			(string)((int)progress["chapter_claimed"]+1)+"章，而不是重复已经完成的目标。";
		break;
	case "ask_truth_in_water":
		insight = room_name+"的倒影没有美化遗憾；你看见事实留下的裂纹仍与原处一致。";
		break;
	case "keep_yesterday_frost":
		insight = "霜签亮起：月忆兽已经与你共同保存"+
			(string)(int)((mapping)view["companion"])["memory_count"]+"段不会被月炉改写的昨日。";
		break;
	case "witness_on_snow":
		insight = "证据链记录了"+(string)(int)progress["story_event_count"]+
			"次关键见证；单独一句传闻不能覆盖这些亲历。";
		break;
	case "promise_in_one_day":
		insight = "今天可以完成的约定很清楚：推进当前章节，并在离开前亲自确认结果。";
		break;
	case "discern_lamp_shadow":
		insight = "灯影将当前线索标为“亲见”；转述、推断与伪造不会再冒充同一种证据。";
		break;
	default:
		insight = "你展开人间名册：已走过"+
			(string)(int)progress["chapter_claimed"]+"章，完成"+
			(string)sizeof((mapping)view["secrets"])+"项行旅秘术，命途为【"+
			(string)progress["path_name"]+"】。";
	}
	return (["ok":1,"message":"【"+(string)config["name"]+"】\n"+insight]);
}

protected void create()
{
	reload_config();
}
