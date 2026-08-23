/**
 * 幻境区生命周期与人物隔离守护。
 *
 * 历史宏名 SEASONALD 保留给旧代码兼容；所有玩家界面统一称“幻境区”。
 * 幻境人物始终使用唯一的原 user .o 存档。回归只原子切换账号索引，
 * 不复制人物、不搬运背包，从存储模型上杜绝结算克隆装备。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ILLUSION_CONFIG ROOT "/gamelib/etc/illusion_realm.json"
#define ILLUSION_STORY_CONFIG ROOT "/gamelib/etc/illusion_s1_story.json"
#define ILLUSION_STATE_DIR DATA_ROOT "illusion_realm"
#define ILLUSION_STATE_FILE ILLUSION_STATE_DIR "/runtime.json"
#define ILLUSION_CONTROL_LOCK ILLUSION_STATE_DIR "/control.lock"
#define ILLUSION_HISTORY_DIR ILLUSION_STATE_DIR "/history"
#define ILLUSION_CONTENT_DIR ILLUSION_STATE_DIR "/content"
#define ILLUSION_CONTENT_REVISION_DIR ILLUSION_CONTENT_DIR "/revisions"
#define ILLUSION_RANKING_DIR ILLUSION_STATE_DIR "/rankings"
#define ILLUSION_STATE_VERSION 1
#define ILLUSION_PROGRESS_ROOT "/plus/illusion_realm"
#define ILLUSION_PAYMENT_ROOT "/plus/illusion_entitlement_purchase"
#define ILLUSION_EXPANSION_PAYMENT_ROOT "/plus/illusion_character_expansion_purchase"
#define ILLUSION_LOG ROOT "/log/illusion_realm.log"
#define ILLUSION_ACCOUNT_EXPANSION_REASON "illusion_character_expansion:"
#define ILLUSION_AUTOMATION_INTERVAL 10
#define ILLUSION_SETTLING_GRACE_SECONDS 30
#define ILLUSION_RANKING_WEEK_SECONDS (7*86400)
#define ILLUSION_RANKING_CACHE_TTL 30
#define ILLUSION_TIMESTAMP_MAX 4102444800

private Thread.Mutex runtime_lock = Thread.Mutex();
private mapping(string:mixed) illusion_config = ([]);
private mapping(string:mapping(string:mixed)) content_configs = ([]);
private mapping(string:mixed) runtime_cache = ([]);
private string runtime_source_cache = "";
private int config_valid;
private int runtime_valid = 1;
private int last_closed_reconcile_revision = -1;
private int closed_reconcile_until;
private mapping(string:int) realm_error_log_times=([]);
private mapping(string:int) gate_substitution_error_log_times=([]);
private int illusion_log_error_at;
private mapping(string:mapping(string:mixed)) ranking_cache = ([]);
// 仅供 TestUnit 注入一次十问存档失败，不对游戏命令或 HTTP API 暴露。
private mapping(string:int) story_quiz_test_save_failures = ([]);

/**
 * 审计日志是人物唯一档案之外的附加证据。任何日志目录只读、轮转竞争
 * 或磁盘瞬时异常都不能把已经提交的创建、奖励、传送、购买或结算误报
 * 成失败，否则客户端重试可能造成重复操作。所有 S1 审计统一走这里。
 */
private int safe_append_illusion_log(string line)
{
	int appended;
	mixed err=catch{ appended=Stdio.append_file(ILLUSION_LOG,line); };
	if(err || !appended){
		// 任务道具掉落会在多人挂机时高频审计。磁盘持续故障时
		// 每次击杀都 werror 反而会造成日志风暴，因此全局每分钟最多告警一次。
		if(time()-illusion_log_error_at>=60){
			illusion_log_error_at=time();
			werror("[ILLUSION_REALM] 审计日志写入失败，主操作结果保持不变: error=%s\n",
				err ? describe_error(err) : "append returned false");
		}
		return 0;
	}
	return 1;
}

private mapping(string:string) ranking_names = ([
	"journey":"幻境征途榜","level":"境界榜","experience":"经验榜",
	"pk":"论剑榜","set":"新月套装榜","speed":"极速榜",
]);

private int valid_nonnegative(mapping one,string key,int maximum)
{
	return intp(one[key]) && (int)one[key]>=0 && (int)one[key]<=maximum;
}

private int valid_identifier(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>16)
		return 0;
	foreach(value;int index;int one){
		if((one>='A' && one<='Z') || (one>='0' && one<='9') ||
		   one=='_')
			continue;
		return 0;
	}
	return 1;
}

private int valid_sha256_hex(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	foreach(value;int index;int one){
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

private int valid_route_mark_id(string value)
{
	if(!value || sizeof(value)>32)
		return 0;
	foreach(value;int index;int one){
		if((one>='a' && one<='z') || (one>='0' && one<='9') || one=='_')
			continue;
		return 0;
	}
	return 1;
}

private int valid_room_path(string path)
{
	if(!path || sizeof(path)<12 || sizeof(path)>256 ||
	   !has_prefix(path,"/gamelib/d/") || search(path,"..")!=-1 ||
	   search(path,"#")!=-1)
		return 0;
	foreach(path;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='/' || one=='_' || one=='-' ||
		   one=='.')
			continue;
		return 0;
	}
	return 1;
}

private int valid_quest_item_gate(mixed value,string illusion_id)
{
	mapping gate;
	array rooms;
	string room_prefix = "/gamelib/d/illusion_"+
		lower_case(illusion_id)+"/";
	string npc_prefix = "/gamelib/clone/npc/illusion_"+
		lower_case(illusion_id)+"/";
	string item_prefix = "/gamelib/clone/item/other/illusion_"+
		lower_case(illusion_id)+"_";
	if(!mappingp(value))
		return 0;
	gate = (mapping)value;
	if(!valid_route_mark_id((string)gate["id"]) ||
	   !stringp(gate["name"]) || sizeof((string)gate["name"])<2 ||
	   sizeof((string)gate["name"])>32 ||
	   !stringp(gate["item_path"]) ||
	   !has_prefix((string)gate["item_path"],item_prefix) ||
	   search((string)gate["item_path"],"..")!=-1 ||
	   Stdio.file_size(ROOT+(string)gate["item_path"])<=0 ||
	   !stringp(gate["source_name"]) ||
	   sizeof((string)gate["source_name"])<2 ||
	   sizeof((string)gate["source_name"])>32 ||
	   !stringp(gate["source_location"]) ||
	   sizeof((string)gate["source_location"])<2 ||
	   sizeof((string)gate["source_location"])>64 ||
	   !stringp(gate["source_path"]) ||
	   !has_prefix((string)gate["source_path"],npc_prefix) ||
	   !has_suffix((string)gate["source_path"],".pike") ||
	   search((string)gate["source_path"],"..")!=-1 ||
	   Stdio.file_size(ROOT+(string)gate["source_path"])<=0 ||
	   !valid_room_path((string)gate["source_room"]) ||
	   !has_prefix((string)gate["source_room"],room_prefix) ||
	   Stdio.file_size(ROOT+(string)gate["source_room"])<=0 ||
	   !arrayp(gate["source_rooms"]) ||
	   !valid_nonnegative(gate,"required",10) ||
	   (int)gate["required"]<1 ||
	   !valid_nonnegative(gate,"drop_basis_points",10000) ||
	   (int)gate["drop_basis_points"]<1 ||
	   !valid_nonnegative(gate,"pity_kills",10000) ||
	   (int)gate["pity_kills"]<1)
		return 0;
	rooms = (array)gate["source_rooms"];
	if(sizeof(rooms)<1 || sizeof(rooms)>8 ||
	   search(rooms,(string)gate["source_room"])==-1)
		return 0;
	foreach(rooms,string room)
		if(!valid_room_path(room) || !has_prefix(room,room_prefix) ||
		   Stdio.file_size(ROOT+room)<=0)
			return 0;
	return 1;
}

/** 保留作者人工编排的章回段落，只清理段首段尾空白。 */
private string normalize_novel_section(string source)
{
	array(string) lines;
	lines = ({});
	foreach(source/"\n",string line){
		line = String.trim_all_whites(line);
		if(line!="")
			lines += ({line});
	}
	return lines*"\n";
}

/** 章前五段、过关三段；每段必须有足够的场景与人物细节。 */
private int valid_novel_section(mixed value,int expected_lines,
	int minimum_line_size,int minimum_total_size)
{
	array(string) lines;
	int total_size;
	if(!stringp(value))
		return 0;
	lines = ({});
	foreach(((string)value)/"\n",string line){
		line = String.trim_all_whites(line);
		if(line!="")
			lines += ({line});
	}
	if(sizeof(lines)!=expected_lines)
		return 0;
	foreach(lines,string line){
		if(sizeof(line)<minimum_line_size)
			return 0;
		total_size += sizeof(line);
	}
	return total_size>=minimum_total_size;
}

private int valid_chapter(mapping chapter,string illusion_id)
{
	int chapter_number;
	string expected_image;
	if(!mappingp(chapter) || !stringp(chapter["id"]) ||
	   sscanf((string)chapter["id"],illusion_id+"-C%d",chapter_number)!=1 ||
	   (string)chapter["id"]!=illusion_id+"-C"+(string)chapter_number ||
	   chapter_number<1 || chapter_number>81)
		return 0;
	expected_image = sprintf(
		"/xd/images/illusion_s1/story/chapters/chapter_%03d.png",
		chapter_number);
	return mappingp(chapter) && stringp(chapter["id"]) &&
		has_prefix((string)chapter["id"],illusion_id+"-C") &&
		stringp(chapter["volume_title"]) &&
		sizeof((string)chapter["volume_title"])>=2 &&
		sizeof((string)chapter["volume_title"])<=96 &&
		stringp(chapter["title"]) && sizeof((string)chapter["title"])>0 &&
		sizeof((string)chapter["title"])<=64 &&
		valid_novel_section(chapter["intro"],5,24,180) &&
		sizeof((string)chapter["intro"])<=4096 &&
		valid_novel_section(chapter["outro"],3,24,96) &&
		sizeof((string)chapter["outro"])<=4096 &&
		valid_nonnegative(chapter,"active_days",30) &&
		(int)chapter["active_days"]>=1 &&
		valid_nonnegative(chapter,"reward_count",10) &&
		(int)chapter["reward_count"]<=2 &&
		valid_nonnegative(chapter,"volume_number",9) &&
		(int)chapter["volume_number"]>=1 &&
		valid_nonnegative(chapter,"image_cell",9) &&
		(int)chapter["image_cell"]>=1 &&
		stringp(chapter["atlas"]) &&
		has_prefix((string)chapter["atlas"],
			"/xd/images/illusion_s1/story/") &&
		Stdio.file_size(ROOT+"/images/"+
			((string)chapter["atlas"])[sizeof("/xd/images/")..])>0 &&
		stringp(chapter["image"]) &&
		(string)chapter["image"]==expected_image &&
		Stdio.file_size(ROOT+"/images/"+
			((string)chapter["image"])[sizeof("/xd/images/")..])>200000 &&
		(!has_index(chapter,"story_event") ||
			(stringp(chapter["story_event"]) &&
			 valid_route_mark_id((string)chapter["story_event"]))) &&
		(!has_index(chapter,"quest_item_gate") ||
			valid_quest_item_gate(chapter["quest_item_gate"],
				illusion_id)) &&
		(!has_index(chapter,"path_required") ||
			(intp(chapter["path_required"]) &&
			 ((int)chapter["path_required"]==0 ||
			  (int)chapter["path_required"]==1))) &&
		(!has_index(chapter,"route_final_required") ||
			(intp(chapter["route_final_required"]) &&
			 ((int)chapter["route_final_required"]==0 ||
			  (int)chapter["route_final_required"]==1)));
}

/**
 * 十问答案只保存在服务端配置；公开查询会重新组装题面，绝不把 answer
 * 字段下发给命令层或 HTTP 客户端。
 */
private int valid_story_quiz(mapping decoded,string illusion_id)
{
	array quiz;
	mapping route_epilogues;
	multiset(string) ids = (<>);
	if(!valid_novel_section(decoded["quiz_intro"],3,20,90) ||
	   !valid_novel_section(decoded["quiz_epilogue"],5,24,180) ||
	   !mappingp(decoded["route_epilogues"]) ||
	   !arrayp(decoded["quiz"]))
		return 0;
	route_epilogues = (mapping)decoded["route_epilogues"];
	if(sizeof(route_epilogues)!=3)
		return 0;
	foreach(({"pioneer","hunter","companion"}),string path){
		mapping epilogue = mappingp(route_epilogues[path]) ?
			(mapping)route_epilogues[path] : ([]);
		if(sizeof(epilogue)!=2 || !stringp(epilogue["title"]) ||
		   sizeof((string)epilogue["title"])<2 ||
		   sizeof((string)epilogue["title"])>96 ||
		   !valid_novel_section(epilogue["text"],5,24,180))
			return 0;
	}
	quiz = (array)decoded["quiz"];
	if(sizeof(quiz)!=10)
		return 0;
	foreach(quiz;int index;mapping question){
		string id = (string)question["id"];
		array options;
		multiset(string) option_values = (<>);
		if(id!=illusion_id+"-Q"+(string)(index+1) || ids[id] ||
		   !stringp(question["question"]) ||
		   sizeof((string)question["question"])<12 ||
		   sizeof((string)question["question"])>256 ||
		   !arrayp(question["options"]) ||
		   !intp(question["answer"]) ||
		   (int)question["answer"]<1 || (int)question["answer"]>4 ||
		   !stringp(question["explanation"]) ||
		   sizeof((string)question["explanation"])<12 ||
		   sizeof((string)question["explanation"])>512)
			return 0;
		options = (array)question["options"];
		if(sizeof(options)!=4)
			return 0;
		foreach(options,mixed option){
			string value;
			if(!stringp(option))
				return 0;
			value = String.trim_all_whites((string)option);
			if(sizeof(value)<2 || sizeof(value)>128 || option_values[value])
				return 0;
			option_values[value] = 1;
		}
		ids[id] = 1;
	}
	return 1;
}

private int valid_story_events(mapping candidate,string illusion_id)
{
	array events;
	multiset(string) ids = (<>);
	int story_level_cap = (int)candidate["story_level_cap"];
	string room_prefix = "/gamelib/d/illusion_"+
		lower_case(illusion_id)+"/";
	string npc_prefix = "/gamelib/clone/npc/illusion_"+
		lower_case(illusion_id)+"/";
	if(!arrayp(candidate["story_events"]))
		return 0;
	events = candidate["story_events"];
	if(sizeof(events)<9 || sizeof(events)>128)
		return 0;
	foreach(events,mapping event){
		string id = (string)event["id"];
		string kind = (string)event["kind"];
		string path = (string)event["path"];
		int chapter = (int)event["chapter"];
		if(!valid_route_mark_id(id) || ids[id] ||
		   search(({"echo","boss"}),kind)==-1 ||
		   chapter<1 || chapter>81 ||
		   !stringp(event["title"]) ||
		   sizeof((string)event["title"])<2 ||
		   sizeof((string)event["title"])>96 ||
		   !stringp(event["location"]) ||
		   sizeof((string)event["location"])<2 ||
		   sizeof((string)event["location"])>48 ||
		   !stringp(event["message"]) ||
		   sizeof((string)event["message"])<2 ||
		   sizeof((string)event["message"])>1024)
			return 0;
		if(kind=="echo"){
			if(!valid_room_path(path) || !has_prefix(path,room_prefix) ||
			   Stdio.file_size(ROOT+path)<=0)
				return 0;
		}
		else{
			string room = (string)event["room"];
			string monster = (string)event["monster"];
			string room_source;
			int event_level = (int)event["level"];
			if(!intp(event["level"]) ||
			   event_level!=min(story_level_cap,chapter))
				return 0;
			if(!has_prefix(path,npc_prefix) || !has_suffix(path,".pike") ||
			   search(path,"..")!=-1 || search(path,"#")!=-1 ||
			   Stdio.file_size(ROOT+path)<=0)
				return 0;
			if(!valid_room_path(room) || !has_prefix(room,room_prefix) ||
			   Stdio.file_size(ROOT+room)<=0 || sizeof(monster)<2 ||
			   sizeof(monster)>48)
				return 0;
			room_source = Stdio.read_file(ROOT+room);
			if(!room_source || search(room_source,path)==-1)
				return 0;
			foreach(path;int index;int one)
				if(!((one>='a' && one<='z') ||
				   (one>='A' && one<='Z') ||
				   (one>='0' && one<='9') || one=='/' || one=='_' ||
				   one=='-' || one=='.'))
					return 0;
		}
		ids[id] = 1;
	}
	return 1;
}

private mapping(string:mixed) load_story_config(mapping candidate)
{
	string source;
	mixed decoded;
	mixed err;
	array chapters = ({});
	if((string)candidate["story_file"]!=
	   "/gamelib/etc/illusion_s1_story.json" ||
	   Stdio.file_size(ILLUSION_STORY_CONFIG)<=0 ||
	   Stdio.file_size(ILLUSION_STORY_CONFIG)>1024*1024)
		return ([]);
	source = Stdio.read_file(ILLUSION_STORY_CONFIG);
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) || (int)decoded["version"]!=2 ||
	   (string)decoded["illusion_id"]!=(string)candidate["current_id"] ||
	   (string)decoded["story_title"]!=(string)candidate["story_title"] ||
	   (string)decoded["story_premise"]!=(string)candidate["story_premise"] ||
	   !valid_story_quiz((mapping)decoded,(string)candidate["current_id"]) ||
	   !arrayp(decoded["volumes"]) ||
	   sizeof((array)decoded["volumes"])!=9)
		return ([]);
	foreach((array)decoded["volumes"];int volume_index;mapping volume){
		array volume_chapters;
		if((string)volume["id"]!=(string)candidate["current_id"]+
		   "-V"+(string)(volume_index+1) ||
		   !stringp(volume["title"]) ||
		   !stringp(volume["atlas"]) ||
		   !arrayp(volume["chapters"]))
			return ([]);
		volume_chapters = volume["chapters"];
		if(sizeof(volume_chapters)!=9)
			return ([]);
		foreach(volume_chapters;int cell_index;mapping source_chapter){
			mapping chapter = copy_value(source_chapter);
			int chapter_number = volume_index*9+cell_index+1;
			chapter["volume_title"] = (string)volume["title"];
			chapter["volume_number"] = volume_index+1;
			chapter["atlas"] = (string)volume["atlas"];
			chapter["image_cell"] = cell_index+1;
			chapter["image"] = sprintf(
				"/xd/images/illusion_s1/story/chapters/chapter_%03d.png",
				chapter_number);
			chapter["intro"] = normalize_novel_section(
				(string)chapter["intro"]);
			chapter["outro"] = normalize_novel_section(
				(string)chapter["outro"]);
			chapters += ({chapter});
		}
	}
	if(sizeof(chapters)!=81)
		return ([]);
	candidate = copy_value(candidate);
	candidate["chapters"] = chapters;
	candidate["story_quiz"] = copy_value((array)decoded["quiz"]);
	candidate["quiz_intro"] = normalize_novel_section(
		(string)decoded["quiz_intro"]);
	candidate["quiz_epilogue"] = normalize_novel_section(
		(string)decoded["quiz_epilogue"]);
	candidate["route_epilogues"] = ([]);
	foreach(({"pioneer","hunter","companion"}),string path){
		mapping source_epilogue = (mapping)((mapping)
			decoded["route_epilogues"])[path];
		((mapping)candidate["route_epilogues"])[path] = ([
			"title":(string)source_epilogue["title"],
			"text":normalize_novel_section(
				(string)source_epilogue["text"]),
		]);
	}
	return candidate;
}

private int valid_route_challenges(mapping routes,string illusion_id)
{
	array secrets;
	array bosses;
	string room_prefix = "/gamelib/d/illusion_"+
		lower_case(illusion_id)+"/";
	string npc_prefix = "/gamelib/clone/npc/illusion_"+
		lower_case(illusion_id)+"/";
	multiset(string) ids = (<>);
	multiset(string) paths = (<>);
	if(!mappingp(routes) || !arrayp(routes["pioneer_secrets"]) ||
	   !arrayp(routes["hunter_bosses"]) ||
	   !intp(routes["companion_team_kills"]) ||
	   (int)routes["companion_team_kills"]<1 ||
	   (int)routes["companion_team_kills"]>10000)
		return 0;
	secrets = routes["pioneer_secrets"];
	bosses = routes["hunter_bosses"];
	if(sizeof(secrets)!=3 || sizeof(bosses)!=3)
		return 0;
	foreach(secrets,mapping secret){
		string id = (string)secret["id"];
		string path = (string)secret["path"];
		if(!valid_room_path(path) || !has_prefix(path,room_prefix) ||
		   Stdio.file_size(ROOT+path)<=0 ||
		   !valid_route_mark_id(id) || ids[id] ||
		   paths[path] || !stringp(secret["message"]) ||
		   sizeof((string)secret["message"])<2 ||
		   sizeof((string)secret["message"])>256)
			return 0;
		ids[id] = 1;
		paths[path] = 1;
	}
	foreach(bosses,mapping boss){
		string id = (string)boss["id"];
		string path = (string)boss["path"];
		if(!path || sizeof(path)>256 ||
		   !has_prefix(path,npc_prefix) ||
		   !has_suffix(path,".pike") || search(path,"..")!=-1 ||
		   search(path,"#")!=-1 || Stdio.file_size(ROOT+path)<=0 ||
		   !valid_route_mark_id(id) || ids[id] ||
		   paths[path])
			return 0;
		foreach(path;int index;int one)
			if(!((one>='a' && one<='z') || (one>='A' && one<='Z') ||
			   (one>='0' && one<='9') || one=='/' || one=='_' ||
			   one=='-' || one=='.'))
				return 0;
		ids[id] = 1;
		paths[path] = 1;
	}
	return 1;
}

private int valid_config(mapping candidate)
{
	array chapters;
	int rewards;
	int quest_item_gate_count;
	string illusion_id = (string)candidate["current_id"];
	string room_prefix = "/gamelib/d/illusion_"+
		lower_case(illusion_id)+"/";
	mapping expected_quest_gates = ([
		8:(["event":"life_collector","id":"mortal_lifespan_thread",
			"item":"/gamelib/clone/item/other/illusion_s1_lifespan_thread",
			"source":"/gamelib/clone/npc/illusion_s1/moon_wisp.pike",
			"rate":2000,"pity":5]),
		17:(["event":"fog_trial_warden","id":"fog_oath_leaf",
			"item":"/gamelib/clone/item/other/illusion_s1_fog_oath_leaf",
			"source":"/gamelib/clone/npc/illusion_s1/fog_wolf.pike",
			"rate":1500,"pity":7]),
		26:(["event":"empty_sutra_abbot","id":"nameless_bone_shard",
			"item":"/gamelib/clone/item/other/illusion_s1_nameless_bone_shard",
			"source":"/gamelib/clone/npc/illusion_s1/mirror_spider.pike",
			"rate":1000,"pity":10]),
		35:(["event":"mirror_weaver","id":"mirror_heart_shard",
			"item":"/gamelib/clone/item/other/illusion_s1_mirror_heart_shard",
			"source":"/gamelib/clone/npc/illusion_s1/ruin_guard.pike",
			"rate":800,"pity":13]),
		44:(["event":"frozen_age_king","id":"beiju_memory_crystal",
			"item":"/gamelib/clone/item/other/illusion_s1_memory_crystal",
			"source":"/gamelib/clone/npc/illusion_s1/star_wraith.pike",
			"rate":600,"pity":17]),
		53:(["event":"frost_inquisitor","id":"snow_verdict_seal",
			"item":"/gamelib/clone/item/other/illusion_s1_snow_verdict_seal",
			"source":"/gamelib/clone/npc/illusion_s1/abyss_beast.pike",
			"rate":500,"pity":20]),
		62:(["event":"dongsheng_fusang_flame","id":"dawn_flame_seed",
			"item":"/gamelib/clone/item/other/illusion_s1_dawn_flame_seed",
			"source":"/gamelib/clone/npc/illusion_s1/abyss_beast.pike",
			"rate":400,"pity":25]),
		71:(["event":"eclipse_priest","id":"moon_furnace_life_rune",
			"item":"/gamelib/clone/item/other/illusion_s1_life_rune",
			"source":"/gamelib/clone/npc/illusion_s1/abyss_beast.pike",
			"rate":300,"pity":34]),
		80:(["event":"newmoon_lord_truth","id":"human_world_true_name",
			"item":"/gamelib/clone/item/other/illusion_s1_human_world_true_name",
			"source":"/gamelib/clone/npc/illusion_s1/abyss_beast.pike",
			"rate":200,"pity":50]),
	]);
	if(!mappingp(candidate) || (int)candidate["version"]!=1 ||
	   !valid_identifier((string)candidate["current_id"]) ||
	   !stringp(candidate["display_name"]) ||
	   sizeof((string)candidate["display_name"])<2 ||
	   (has_index(candidate,"manual_close_only") &&
	    (!intp(candidate["manual_close_only"]) ||
	     (int)candidate["manual_close_only"]!=1)) ||
	   !valid_nonnegative(candidate,"duration_days",366) ||
	   ((int)candidate["manual_close_only"]!=1 &&
	    (int)candidate["duration_days"]<30) ||
	   !valid_nonnegative(candidate,"story_level_cap",300) ||
	   (int)candidate["story_level_cap"]<1 ||
	   !valid_nonnegative(candidate,"entitlement_cost_suiyu",1000000) ||
	   !valid_nonnegative(candidate,"extra_character_slot_cost_suiyu",1000000) ||
	   (int)candidate["extra_character_slot_cost_suiyu"]!=100 ||
	   !valid_nonnegative(candidate,"multi_character_unlock_cost_suiyu",1000000) ||
	   (int)candidate["multi_character_unlock_cost_suiyu"]!=500 ||
	   !valid_room_path((string)candidate["entry_room"]) ||
	   !has_prefix((string)candidate["entry_room"],room_prefix) ||
	   Stdio.file_size(ROOT+(string)candidate["entry_room"])<=0 ||
	   !valid_room_path((string)candidate["return_room"]) ||
	   has_prefix((string)candidate["return_room"],room_prefix) ||
	   Stdio.file_size(ROOT+(string)candidate["return_room"])<=0 ||
	   !valid_route_challenges(candidate["route_challenges"],illusion_id) ||
	   !valid_story_events(candidate,illusion_id) ||
	   !arrayp(candidate["chapters"]))
		return 0;
	chapters = candidate["chapters"];
	if(sizeof(chapters)!=81)
		return 0;
	foreach(chapters;int index;mapping chapter){
		string story_event;
		int matched_event;
		if(!valid_chapter(chapter,illusion_id) ||
		   (string)chapter["id"]!=illusion_id+"-C"+(string)(index+1))
			return 0;
		story_event = (string)(chapter["story_event"] || "");
		if(story_event!=""){
			foreach((array)candidate["story_events"],mapping event)
				if((string)event["id"]==story_event &&
				   (int)event["chapter"]==index+1){
					matched_event = 1;
					break;
				}
			if(!matched_event)
				return 0;
		}
		if(has_index(chapter,"quest_item_gate")){
			mapping gate = (mapping)chapter["quest_item_gate"];
			mapping expected = mappingp(expected_quest_gates[index]) ?
				(mapping)expected_quest_gates[index] : ([]);
			quest_item_gate_count++;
			if(!sizeof(expected) ||
			   (string)chapter["story_event"]!=(string)expected["event"] ||
			   (string)gate["id"]!=(string)expected["id"] ||
			   (string)gate["item_path"]!=(string)expected["item"] ||
			   (string)gate["source_path"]!=(string)expected["source"] ||
			   (int)gate["required"]!=1 ||
			   (int)gate["drop_basis_points"]!=(int)expected["rate"] ||
			   (int)gate["pity_kills"]!=(int)expected["pity"])
				return 0;
		}
		else if(mappingp(expected_quest_gates[index]))
			return 0;
		rewards += (int)chapter["reward_count"];
	}
	// 每期终章正好发完一个职业的十件新月底版套装。
	return rewards==10 &&
		quest_item_gate_count==sizeof(expected_quest_gates);
}

private string content_archive_digest(string encoded)
{
	object hash = Crypto.SHA256();
	hash->update(encoded || "");
	return lower_case(String.string2hex(hash->digest()));
}

private int save_content_revision(string illusion_id,string encoded)
{
	string digest = content_archive_digest(encoded);
	string directory = ILLUSION_CONTENT_REVISION_DIR+"/"+illusion_id;
	string target = directory+"/"+digest+".json";
	string temp;
	int ok;
	if(!valid_identifier(illusion_id) || !valid_sha256_hex(digest))
		return 0;
	Stdio.mkdirhier(directory);
	if(Stdio.file_size(target)>0)
		return Stdio.file_size(target)==sizeof(encoded) &&
			Stdio.read_file(target)==encoded;
	temp=target+"."+String.string2hex(Crypto.Random.random_string(8))+".tmp";
	rm(temp);
	mixed err=catch{
		ok=Stdio.write_file(temp,encoded)==sizeof(encoded) &&
			Stdio.file_size(temp)==sizeof(encoded) && mv(temp,target) &&
			Stdio.file_size(target)==sizeof(encoded);
	};
	if(err || !ok){
		rm(temp);
		return 0;
	}
	return 1;
}

private int save_content_archive(mapping config)
{
	string illusion_id=(string)config["current_id"];
	string target;
	string temp;
	string encoded;
	int ok;
	if(!valid_config(config) || !valid_identifier(illusion_id))
		return 0;
	mkdir(ILLUSION_STATE_DIR);
	mkdir(ILLUSION_CONTENT_DIR);
	target=ILLUSION_CONTENT_DIR+"/"+illusion_id+".json";
	// 普通 mapping 编码顺序随进程哈希种子变化；必须使用规范 JSON，
	// 否则同一份内容会被不同 Worker 误记成多个修订。
	encoded=Standards.JSON.encode(config,Standards.JSON.CANONICAL);
	if(!save_content_revision(illusion_id,encoded))
		return 0;
	if(Stdio.file_size(target)==sizeof(encoded) &&
	   Stdio.read_file(target)==encoded)
		return 1;
	temp=target+"."+String.string2hex(Crypto.Random.random_string(8))+".tmp";
	rm(temp);
	mixed err=catch{
		ok=Stdio.write_file(temp,encoded)==sizeof(encoded) &&
			Stdio.file_size(temp)==sizeof(encoded) && mv(temp,target) &&
			Stdio.file_size(target)==sizeof(encoded);
	};
	if(err || !ok){
		rm(temp);
		return 0;
	}
	return 1;
}

string query_content_revision_path_for_test(string encoded)
{
	string illusion_id;
	mixed decoded;
	mixed err;
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !encoded)
		return "";
	err=catch{ decoded=Standards.JSON.decode(encoded); };
	if(err || !mappingp(decoded) || !valid_config((mapping)decoded))
		return "";
	illusion_id=(string)decoded["current_id"];
	return ILLUSION_CONTENT_REVISION_DIR+"/"+illusion_id+"/"+
		content_archive_digest(encoded)+".json";
}

int query_content_revision_saved_for_test(string encoded)
{
	string path = query_content_revision_path_for_test(encoded);
	return path!="" && Stdio.file_size(path)==sizeof(encoded) &&
		Stdio.read_file(path)==encoded;
}

private void load_content_archives()
{
	mapping(string:mapping(string:mixed)) loaded=([]);
	foreach(get_dir(ILLUSION_CONTENT_DIR) || ({}),string filename){
		string source;
		mixed decoded;
		mixed err;
		if(!has_suffix(filename,".json") || sizeof(filename)>40 ||
		   Stdio.file_size(ILLUSION_CONTENT_DIR+"/"+filename)<=0 ||
		   Stdio.file_size(ILLUSION_CONTENT_DIR+"/"+filename)>2*1024*1024)
			continue;
		source=Stdio.read_file(ILLUSION_CONTENT_DIR+"/"+filename);
		err=catch{ decoded=Standards.JSON.decode(source); };
		if(!err && mappingp(decoded) && valid_config((mapping)decoded))
			loaded[(string)decoded["current_id"]]=copy_value((mapping)decoded);
	}
	content_configs=loaded;
}

private mapping(string:mixed) content_config_for_id(string illusion_id)
{
	if(valid_identifier(illusion_id) && mappingp(content_configs[illusion_id]))
		return content_configs[illusion_id];
	return ([]);
}

int reload_config()
{
	string source;
	mixed decoded = 0;
	mixed err;
	if(Stdio.file_size(ILLUSION_CONFIG)<=0 ||
	   Stdio.file_size(ILLUSION_CONFIG)>256*1024){
		config_valid = 0;
		illusion_config = ([]);
		werror("[ILLUSION_REALM] 配置缺失或过大，功能已安全关闭。\n");
		return 0;
	}
	source = Stdio.read_file(ILLUSION_CONFIG);
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(!err && mappingp(decoded))
		decoded = load_story_config((mapping)decoded);
	if(err || !mappingp(decoded) || !valid_config((mapping)decoded)){
		config_valid = 0;
		illusion_config = ([]);
		werror("[ILLUSION_REALM] 配置校验失败，功能已安全关闭。\n");
		return 0;
	}
	illusion_config = copy_value(decoded);
	load_content_archives();
	content_configs[(string)illusion_config["current_id"]]=
		copy_value(illusion_config);
	if(!save_content_archive(illusion_config))
		werror("[ILLUSION_REALM] 本期内容归档暂未写入，将在下次重载重试。\n");
	config_valid = 1;
	return 1;
}

private mapping(string:mixed) default_runtime_state()
{
	return ([
		"version":ILLUSION_STATE_VERSION,
		"current_id":(string)(illusion_config["current_id"] || "S1"),
		"phase":"draft",
		"revision":0,
		"starts_at":0,
		"ends_at":0,
		"updated_at":time(),
		"closed_ids":({}),
		"audit":({}),
	]);
}

private int valid_runtime_state_for_id(mapping state,string expected_id)
{
	string phase;
	if(!mappingp(state) ||
	   (int)state["version"]!=ILLUSION_STATE_VERSION ||
	   (string)state["current_id"]!=expected_id ||
	   !intp(state["revision"]) || (int)state["revision"]<0 ||
	   !intp(state["starts_at"]) || !intp(state["ends_at"]) ||
	   !intp(state["updated_at"]) || !arrayp(state["audit"]) ||
	   (state["closed_ids"] && !arrayp(state["closed_ids"])))
		return 0;
	array closed_ids = state["closed_ids"] || ({});
	if(sizeof(closed_ids)>64)
		return 0;
	multiset(string) seen_closed = (<>);
	foreach(closed_ids,mixed raw_id){
		string closed_id = (string)raw_id;
		if(!valid_identifier(closed_id) || closed_id==expected_id ||
		   seen_closed[closed_id])
			return 0;
		seen_closed[closed_id] = 1;
	}
	phase = (string)state["phase"];
	if(search(({"draft","registration","active","settling","closed"}),
	   phase)==-1 || sizeof((array)state["audit"])>2000)
		return 0;
	// S1 采用管理员显式关闭：active 的 ends_at 必须允许为 0。
	// 旧运行状态中已经写入的未来结束时间继续作为历史字段读取，
	// 但不再能驱动阶段变化，避免内容打磨期间意外自动结算。
	if((phase=="active" || phase=="settling" || phase=="closed") &&
	   ((int)state["starts_at"]<=0 || (int)state["ends_at"]<0))
		return 0;
	return 1;
}

private int valid_runtime_state(mapping state)
{
	return valid_runtime_state_for_id(state,
		(string)illusion_config["current_id"]);
}

private mapping(string:mixed) decode_runtime_state_source(string source)
{
	mixed decoded = 0;
	mixed err;
	if(!source || sizeof(source)<=0 || sizeof(source)>1024*1024)
		return ([]);
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) ||
	   !valid_runtime_state((mapping)decoded))
		return ([]);
	if(!arrayp(decoded["closed_ids"]))
		decoded["closed_ids"] = ({});
	return (mapping)decoded;
}

private int repair_runtime_primary_from_backup(string source)
{
	string temp_file;
	int ok;
	mixed err;
	if(!sizeof(decode_runtime_state_source(source)))
		return 0;
	mkdir(ILLUSION_STATE_DIR);
	temp_file = ILLUSION_STATE_FILE+".recovery."+
		String.string2hex(Crypto.Random.random_string(8))+".tmp";
	err = catch{
		rm(temp_file);
		if(Stdio.write_file(temp_file,source)==sizeof(source) &&
		   Stdio.file_size(temp_file)==sizeof(source) &&
		   mv(temp_file,ILLUSION_STATE_FILE))
			ok = Stdio.file_size(ILLUSION_STATE_FILE)==sizeof(source);
	};
	if(err || !ok){
		rm(temp_file);
		return 0;
	}
	return 1;
}

string query_runtime_recovery_choice_for_test(string primary,string backup)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return "invalid";
	if(sizeof(decode_runtime_state_source(primary)))
		return "primary";
	if(sizeof(decode_runtime_state_source(backup)))
		return "backup";
	return "invalid";
}

private mapping(string:mixed) load_runtime_state()
{
	string source = "";
	string backup_source = "";
	mapping decoded = ([]);
	int live_size;
	int backup_size;
	int recovered;
	object key = runtime_lock->lock();
	live_size = Stdio.file_size(ILLUSION_STATE_FILE);
	backup_size = Stdio.file_size(ILLUSION_STATE_FILE+".bak");
	if(live_size<=0 && backup_size<=0){
		// 首次落地只能建立不可变的S1。后续编号必须从已关闭运行状态
		// 经过显式换期，不能靠删状态文件跳过归档和closed_ids。
		if((string)illusion_config["current_id"]!="S1"){
			runtime_valid = 0;
			werror("[ILLUSION_REALM] 非S1配置缺少旧运行状态，已拒绝隐式换期。\n");
			destruct(key);
			return ([]);
		}
		runtime_cache = default_runtime_state();
		runtime_source_cache = "";
		runtime_valid = 1;
		mapping result = copy_value(runtime_cache);
		destruct(key);
		return result;
	}
	if(live_size>0 && live_size<=1024*1024){
		source = Stdio.read_file(ILLUSION_STATE_FILE) || "";
		if(source==runtime_source_cache && sizeof(runtime_cache)){
			mapping result = copy_value(runtime_cache);
			destruct(key);
			return result;
		}
		decoded = decode_runtime_state_source(source);
	}
	if(!sizeof(decoded) && backup_size>0 && backup_size<=1024*1024){
		backup_source = Stdio.read_file(ILLUSION_STATE_FILE+".bak") || "";
		decoded = decode_runtime_state_source(backup_source);
		if(sizeof(decoded)){
			source = backup_source;
			recovered = 1;
		}
	}
	if(!sizeof(decoded)){
		runtime_valid = 0;
		destruct(key);
		werror("[ILLUSION_REALM] 主状态及备份均不可验证，功能已安全关闭。\n");
		return ([]);
	}
	if(recovered){
		if(repair_runtime_primary_from_backup(source))
			werror("[ILLUSION_REALM] 主状态损坏，已从有效备份原子恢复。\n");
		else
			werror("[ILLUSION_REALM] 已使用有效备份运行，但主状态修复待重试。\n");
	}
	runtime_cache = copy_value(decoded);
	runtime_source_cache = source;
	runtime_valid = 1;
	mapping result = copy_value(runtime_cache);
	destruct(key);
	return result;
}

private int acquire_control_lock()
{
	mkdir(ILLUSION_STATE_DIR);
	for(int attempt=0;attempt<200;attempt++){
		if(mkdir(ILLUSION_CONTROL_LOCK))
			return 1;
		Stdio.Stat stat = file_stat(ILLUSION_CONTROL_LOCK);
		if(stat && stat->isdir && time()-stat->mtime>30){
			rm(ILLUSION_CONTROL_LOCK);
			continue;
		}
		sleep(0.005);
	}
	return 0;
}

private void release_control_lock()
{
	rm(ILLUSION_CONTROL_LOCK);
}

private int save_runtime_state(mapping state)
{
	string temp_file;
	string backup_temp;
	string encoded;
	int live_size;
	int ok;
	mixed err;
	if(!valid_runtime_state(state))
		return 0;
	state["updated_at"] = time();
	encoded = Standards.JSON.encode(state);
	temp_file = ILLUSION_STATE_FILE+"."+
		String.string2hex(Crypto.Random.random_string(8))+".tmp";
	backup_temp = temp_file+".bak";
	err = catch{
		rm(temp_file);
		rm(backup_temp);
		if(Stdio.write_file(temp_file,encoded)==sizeof(encoded) &&
		   Stdio.file_size(temp_file)==sizeof(encoded)){
			live_size = Stdio.file_size(ILLUSION_STATE_FILE);
			if(live_size>0){
				Stdio.cp(ILLUSION_STATE_FILE,backup_temp);
				if(Stdio.file_size(backup_temp)==live_size &&
				   mv(backup_temp,ILLUSION_STATE_FILE+".bak") &&
				   mv(temp_file,ILLUSION_STATE_FILE))
					ok = Stdio.file_size(ILLUSION_STATE_FILE)==sizeof(encoded);
			}
			else if(mv(temp_file,ILLUSION_STATE_FILE))
				ok = Stdio.file_size(ILLUSION_STATE_FILE)==sizeof(encoded);
		}
	};
	if(err)
		werror("[ILLUSION_REALM] 状态保存异常: %s\n",describe_error(err));
	if(!ok){
		rm(temp_file);
		rm(backup_temp);
		return 0;
	}
	object key = runtime_lock->lock();
	runtime_cache = copy_value(state);
	runtime_source_cache = encoded;
	runtime_valid = 1;
	destruct(key);
	return 1;
}

private string effective_phase(mapping state)
{
	return (string)(state["phase"] || "disabled");
}

private string phase_name(string phase)
{
	if(phase=="draft") return "筹备中";
	if(phase=="registration") return "资格开放";
	if(phase=="active") return "进行中";
	if(phase=="settling") return "回归结算";
	if(phase=="closed") return "已关闭";
	return "不可用";
}

mapping(string:mixed) query_public_status()
{
	mapping state = config_valid ? load_runtime_state() : ([]);
	string phase = sizeof(state) ? effective_phase(state) : "disabled";
	return ([
		"ok":config_valid && runtime_valid && sizeof(state)>0,
		"illusion_id":(string)(illusion_config["current_id"] || "S1"),
		"display_name":(string)(illusion_config["display_name"] ||
			"新月幻境·S1"),
		"phase":phase,
		"phase_name":phase_name(phase),
		"revision":(int)state["revision"],
		"starts_at":(int)state["starts_at"],
		// 进行中赛季没有自动结束日期。settling/closed 才公开管理员
		// 发起关闭的时间，避免旧 ends_at 让玩家误以为仍会自动到期。
		"ends_at":phase=="settling" || phase=="closed" ?
			(int)state["ends_at"] : 0,
		"manual_close_only":(int)illusion_config["manual_close_only"]==1,
		"season_open":phase=="active",
		"closed_ids":arrayp(state["closed_ids"]) ?
			((array)state["closed_ids"])+({}) : ({}),
		"duration_days":(int)illusion_config["duration_days"],
		"entitlement_cost_suiyu":
			(int)illusion_config["entitlement_cost_suiyu"],
		"extra_character_slot_cost_suiyu":
			(int)illusion_config["extra_character_slot_cost_suiyu"],
		"multi_character_unlock_cost_suiyu":
			(int)illusion_config["multi_character_unlock_cost_suiyu"],
		"creation_open":phase=="active",
		"entitlement_open":phase=="registration" || phase=="active",
		"entry_room":(string)(illusion_config["entry_room"] || ""),
		"return_room":(string)(illusion_config["return_room"] || ""),
		"rules":({
			"资格按注册账号和赛季分别生效；每个本期人物栏位100碎玉，500碎玉可一次购买5格。",
			(string)illusion_config["current_id"]+
				"人物使用唯一原档案；回归永恒服时不复制人物或背包。",
			"幻境期间不开放家园，也不接入共享仓库、共享玉石、拍卖与跨世界交易。",
			"任务套装会随人物原档案回归永恒服。",
		}),
	]);
}

private mapping(string:mixed) read_runtime_for_rollover()
{
	string source;
	mixed decoded;
	mixed err;
	if(Stdio.file_size(ILLUSION_STATE_FILE)<=0 ||
	   Stdio.file_size(ILLUSION_STATE_FILE)>1024*1024)
		return ([]);
	source = Stdio.read_file(ILLUSION_STATE_FILE);
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) ||
	   !valid_identifier((string)decoded["current_id"]) ||
	   !valid_runtime_state_for_id(decoded,(string)decoded["current_id"]))
		return ([]);
	if(!arrayp(decoded["closed_ids"]))
		decoded["closed_ids"] = ({});
	return decoded;
}

private int rollover_content_available(string illusion_id)
{
	mapping config = content_config_for_id(illusion_id);
	return valid_identifier(illusion_id) && sizeof(config) &&
		(string)config["current_id"]==illusion_id;
}

int query_rollover_content_available_for_test(string illusion_id)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return 0;
	return rollover_content_available(illusion_id);
}

private string rollover_digest(mapping old_state,string new_id)
{
	object hash = Crypto.SHA256();
	hash->update("rollover|"+(string)old_state["current_id"]+"|"+
		(string)(int)old_state["revision"]+"|"+
		(string)(int)old_state["updated_at"]+"|"+new_id);
	return lower_case(String.string2hex(hash->digest()));
}

mapping(string:mixed) preview_cycle_rollover()
{
	mapping old_state = read_runtime_for_rollover();
	string new_id = (string)illusion_config["current_id"];
	string old_id = (string)(old_state["current_id"] || "");
	mapping population = old_id!="" ?
		ACCOUNT_CHARACTERD->query_illusion_population(old_id) : ([]);
	int allowed = config_valid && sizeof(old_state) &&
		(string)old_state["phase"]=="closed" && old_id!=new_id &&
		(int)population["ok"] && rollover_content_available(old_id);
	return ([
		"ok":allowed,"old_id":old_id,"new_id":new_id,
		"confirmation":allowed ? rollover_digest(old_state,new_id) : "",
		"population":population,
		"message":allowed ?
			"旧周期已关闭，可以建立新周期草稿。" :
			(!rollover_content_available(old_id) && old_id!="" ?
				"旧周期内容归档缺失，恢复归档后才能换期。" :
			(!(int)population["ok"] && sizeof(old_state) ?
				 "账号索引审计未通过，修复异常索引后才能换期。" :
				 "只有旧周期关闭且配置已换成新编号后才能换期。")),
	]);
}

mapping(string:mixed) apply_cycle_rollover(string confirmation,
	string operator_id)
{
	mapping result = (["ok":0,"message":"幻境换期失败。"]) ;
	mapping old_state;
	mapping new_state;
	string old_id;
	string new_id = (string)illusion_config["current_id"];
	string archive_path;
	string archive_temp;
	int archive_ok;
	mapping population;
	if(!config_valid || !operator_id || operator_id=="" ||
	   !acquire_control_lock())
		return result;
	old_state = read_runtime_for_rollover();
	old_id = (string)(old_state["current_id"] || "");
	if(!sizeof(old_state) || (string)old_state["phase"]!="closed" ||
	   old_id==new_id)
		result["message"] = "旧周期尚未关闭，或新配置编号没有变化。";
	else if(confirmation!=rollover_digest(old_state,new_id))
		result["message"] = "换期预览已过期，请重新确认。";
	else if(!rollover_content_available(old_id))
		result["message"] = "旧周期内容归档缺失，已拒绝换期。";
	else{
		population = ACCOUNT_CHARACTERD->query_illusion_population(old_id);
		if(!(int)population["ok"]){
			result["message"] = "账号索引审计未通过，已拒绝换期。";
			release_control_lock();
			return result;
		}
		mkdir(ILLUSION_HISTORY_DIR);
		archive_path = ILLUSION_HISTORY_DIR+"/"+old_id+"-r"+
			(string)(int)old_state["revision"]+"-"+
			(string)(int)old_state["updated_at"]+".json";
		if(Stdio.file_size(archive_path)>0)
			archive_ok = Stdio.read_file(archive_path)==
				Stdio.read_file(ILLUSION_STATE_FILE);
		else{
			archive_temp = archive_path+"."+
				String.string2hex(Crypto.Random.random_string(8))+".tmp";
			rm(archive_temp);
			archive_ok = Stdio.cp(ILLUSION_STATE_FILE,archive_temp) &&
				Stdio.file_size(archive_temp)==
				Stdio.file_size(ILLUSION_STATE_FILE) &&
				mv(archive_temp,archive_path);
			if(!archive_ok)
				rm(archive_temp);
		}
		if(!archive_ok)
			result["message"] = "旧周期状态归档失败，未建立新周期。";
		else{
			new_state = default_runtime_state();
			array closed_ids = ((array)old_state["closed_ids"])+({old_id});
			if(sizeof(closed_ids)>64)
				closed_ids = closed_ids[sizeof(closed_ids)-64..];
			new_state["closed_ids"] = closed_ids;
			new_state["revision"] = 1;
			new_state["audit"] = ({(["at":time(),"operator":operator_id,
				"action":"rollover","from":old_id,"to":new_id,
				"revision":1])});
			if(save_runtime_state(new_state))
				result = (["ok":1,"message":"已建立"+new_id+
					"草稿；旧人物仍按原档案登录回归。",
					"status":query_public_status(),
					"population":ACCOUNT_CHARACTERD->
						query_illusion_population(old_id)]);
			else
				result["message"] = "新周期状态落盘失败，旧归档仍保留。";
		}
	}
	release_control_lock();
	return result;
}

private string transition_digest(string action,mapping state)
{
	object hash = Crypto.SHA256();
	hash->update((string)illusion_config["current_id"]+"|"+action+"|"+
		(string)(int)state["revision"]+"|"+(string)state["phase"]);
	return lower_case(String.string2hex(hash->digest()));
}

private int valid_end_time_change(mapping state,string phase,int ends_at)
{
	// 保留旧接口供旧管理页安全失败；S1 不再允许用日期触发关闭。
	return 0;
}

int query_end_time_valid_for_test(mapping state,string phase,int ends_at)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return valid_end_time_change(state,phase,ends_at);
}

mapping(string:mixed) preview_end_time(int ends_at)
{
	return (["ok":0,"ends_at":ends_at,"confirmation":"",
		"message":"当前幻境仅由管理员关闭开关触发结算，不使用结束日期。"]);
}

mapping(string:mixed) apply_end_time(int ends_at,string confirmation,
	string operator_id)
{
	return (["ok":0,
		"message":"当前幻境仅由管理员关闭开关触发结算，不使用结束日期。"]);
}

private string manual_action_expected_phase(string action)
{
	switch(action){
	case "open_registration":
		return "draft";
	case "start":
		return "registration";
	case "settle":
		return "active";
	}
	return "";
}

int query_manual_action_allowed_for_test(string action,string phase)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return 0;
	return manual_action_expected_phase(action)==phase;
}

mapping(string:mixed) preview_lifecycle_transition(string action)
{
	mapping state = load_runtime_state();
	string phase = sizeof(state) ? effective_phase(state) : "disabled";
	string expected = manual_action_expected_phase(action);
	int allowed = config_valid && runtime_valid && expected && phase==expected;
	// 预览和执行必须使用同一有效阶段，否则管理员刚拿到的确认码
	// 会在执行时失效。
	if(sizeof(state) && phase!=(string)state["phase"])
		state["phase"] = phase;
	return ([
		"ok":allowed,
		"action":action,
		"current_phase":phase,
		"expected_phase":expected || "",
		"confirmation":allowed ? transition_digest(action,state) : "",
		"status":query_public_status(),
	]);
}

mapping(string:mixed) apply_lifecycle_transition(string action,
	string confirmation,string operator_id)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"幻境生命周期切换失败。"]);
	mapping state;
	string phase;
	string next_phase;
	string expected_phase=manual_action_expected_phase(action);
	if(!config_valid || !runtime_valid || !operator_id || operator_id=="" ||
	   expected_phase=="")
		return result;
	if(!acquire_control_lock()){
		result["message"] = "另一名管理员正在调整幻境配置。";
		return result;
	}
	// 获得跨Worker文件锁后丢弃本进程缓存，读取唯一最新修订。
	{
		object key = runtime_lock->lock();
		runtime_source_cache = "__reload__";
		destruct(key);
	}
	state = load_runtime_state();
	phase = effective_phase(state);
	if(phase!=(string)state["phase"])
		state["phase"] = phase;
	if(confirmation!=transition_digest(action,state))
		result["message"] = "预览已过期，请重新确认当前修订。";
	else{
		next_phase = ([
			"open_registration":"registration",
			"start":"active",
			"settle":"settling",
		])[action];
		if(phase!=expected_phase)
			result["message"] = "当前阶段不允许执行该操作。";
		else{
			if(action=="start"){
				int starts_at = time();
				state["starts_at"] = starts_at;
				state["ends_at"] = 0;
			}
			else if(action=="settle")
				state["ends_at"] = time();
			state["phase"] = next_phase;
			state["revision"] = (int)state["revision"]+1;
			array audit = state["audit"];
			audit += ({(["at":time(),"operator":operator_id,
				"action":action,"from":phase,"to":next_phase,
				"revision":(int)state["revision"]])});
			if(sizeof(audit)>2000)
				audit = audit[sizeof(audit)-2000..];
			state["audit"] = audit;
			if(save_runtime_state(state))
				result = (["ok":1,"message":"幻境阶段已切换为"+
					phase_name(next_phase)+"。","status":query_public_status()]);
			else
				result["message"] = "幻境状态落盘失败，未发布新修订。";
		}
	}
	release_control_lock();
	// 管理员关闭后立即让本 Worker 进入在线人物回归扫描；其他 Worker
	// 最迟在固定心跳内加入。真正 closed 仍由宽限窗口后的自动阶段完成。
	if((int)result["ok"] && action=="settle")
		call_out(run_lifecycle_automation_once,0);
	return result;
}

private string automatic_action(mapping state,int now_time)
{
	string phase = (string)state["phase"];
	if(phase=="settling" &&
	   now_time>=(int)state["updated_at"]+ILLUSION_SETTLING_GRACE_SECONDS)
		return "auto_close";
	return "";
}

string query_automatic_action_for_test(mapping state,int now_time)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !mappingp(state))
		return "";
	return automatic_action(state,now_time);
}

private mapping(string:mixed) apply_automatic_transition()
{
	mapping(string:mixed) result = (["ok":0,"action":""]);
	mapping state;
	string action;
	string from_phase;
	string to_phase;
	int now_time = time();
	array audit;
	mixed transition_err;
	if(!config_valid || !runtime_valid || !acquire_control_lock())
		return result;
	transition_err=catch{
		{
			object key = runtime_lock->lock();
			runtime_source_cache = "__reload__";
			destruct(key);
		}
		state = load_runtime_state();
		action = automatic_action(state,now_time);
		if(action!=""){
			from_phase = (string)state["phase"];
			if(action=="auto_settle"){
				state["phase"] = "settling";
				to_phase = "settling";
			}
			else if(action=="auto_close"){
				state["phase"] = "closed";
				to_phase = "closed";
			}
			state["revision"] = (int)state["revision"]+1;
			audit = state["audit"];
			audit += ({(["at":now_time,"operator":"system",
				"action":action,"from":from_phase,"to":to_phase,
				"revision":(int)state["revision"]])});
			if(sizeof(audit)>2000)
				audit = audit[sizeof(audit)-2000..];
			state["audit"] = audit;
			if(save_runtime_state(state)){
				safe_append_illusion_log(sprintf(
					"%d|lifecycle|action=%s|cycle=%s|phase=%s|revision=%d\n",
					now_time,action,(string)state["current_id"],
					(string)state["phase"],(int)state["revision"]));
				result = (["ok":1,"action":action,
					"status":query_public_status()]);
			}
		}
	};
	// 控制锁是目录锁，不会像 Thread.Mutex key 一样随栈自动释放。
	// 无论读取、编码、保存还是状态查询在哪一步抛错，都先解锁，再让
	// 外层调度记录异常并在下一轮立即重试。
	release_control_lock();
	if(transition_err)
		error("automatic illusion transition failed after lock release: %s",
			describe_error(transition_err));
	return result;
}

private mapping(string:int) reconcile_local_expired_players()
{
	mapping status = query_public_status();
	array(object) list = users(1);
	int active;
	int settled;
	int failed;
	for(int index=0;index<sizeof(list);index++){
		mapping realm;
		mapping result;
		if(!list[index])
			continue;
		realm = query_realm_for_player(list[index]);
		if(!(int)realm["ok"] ||
		   (string)realm["realm_type"]!="illusion" ||
		   (string)realm["illusion_state"]!="active")
			continue;
		if((string)realm["illusion_id"]==
		   (string)status["illusion_id"] &&
		   (string)status["phase"]=="active")
			continue;
		active++;
		result = settle_player(list[index]);
		if((int)result["ok"])
			settled++;
		else{
			failed++;
			werror("[ILLUSION_REALM] 在线人物自动回归失败 user=%s message=%s\n",
				(string)list[index]->query_name(),
				(string)result["message"]);
		}
	}
	return (["active":active,"settled":settled,"failed":failed]);
}

void run_lifecycle_automation_once()
{
	mapping transition;
	mapping reconciliation;
	for(int attempt=0;attempt<4;attempt++){
		transition = apply_automatic_transition();
		if(!(int)transition["ok"])
			break;
		if((string)transition["action"]=="auto_settle" ||
		   (string)transition["action"]=="auto_close")
			reconciliation = reconcile_local_expired_players();
	}
	{
		mapping status = query_public_status();
		if((string)status["phase"]=="settling")
			reconcile_local_expired_players();
		else if((string)status["phase"]=="closed"){
			// A handoff accepted just before close can arrive after this Worker's
			// first scan. Keep a bounded reconciliation window rather than scanning
			// every online player forever while the realm remains closed.
			if(last_closed_reconcile_revision!=(int)status["revision"]){
				last_closed_reconcile_revision = (int)status["revision"];
				closed_reconcile_until = time()+180;
			}
			if(time()<=closed_reconcile_until){
				reconciliation = reconcile_local_expired_players();
				if((int)reconciliation["failed"])
					closed_reconcile_until = max(closed_reconcile_until,
						time()+60);
			}
		}
	}
}

private void lifecycle_automation_tick()
{
	mixed err = catch{ run_lifecycle_automation_once(); };
	if(err)
		werror("[ILLUSION_REALM] 自动生命周期异常: %s\n",
			describe_error(err));
	call_out(lifecycle_automation_tick,ILLUSION_AUTOMATION_INTERVAL);
}

private mapping(string:mixed) query_realm_for_user_id(string userid)
{
	mapping realm=([]);
	mixed err;
	// 建角/头像旧流程在人物对象已经存在、ID尚未落定时会传空串；
	// ACCOUNT_CHARACTERD 对这种合法临时态返回普通未索引人物。不要把它
	// 与账号索引损坏混为一谈，否则创建页会被跨世界移动守卫冻结。
	err=catch{
		if(getenv("XIAND_RUN_TESTUNIT")=="1" &&
		   userid=="xd99testunitrealmthrow")
			error("forced realm lookup exception for routing test\n");
		realm=ACCOUNT_CHARACTERD->query_character_realm(userid);
	};
	if(err || !mappingp(realm)){
		// 账号索引是世界隔离的权威来源。异常时失败关闭，不能把未知人物
		// 猜成永恒服，也不能让结算自动化把“未处理”统计成成功。
		if(sizeof(realm_error_log_times)>=4096 &&
		   !has_index(realm_error_log_times,userid))
			realm_error_log_times=([]);
		if(time()-(int)realm_error_log_times[userid]>=60){
			realm_error_log_times[userid]=time();
			werror("[ILLUSION_REALM] 世界归属读取异常，已阻止跨世界操作: user=%s error=%s\n",
				userid,err ? describe_error(err) : "invalid realm result");
		}
		return (["ok":0,"security_blocked":1,"realm_type":"unknown",
			"message":"世界归属暂不可验证，请稍后重试。"]) ;
	}
	return realm;
}

private mapping(string:mixed) query_realm_for_player(object player)
{
	if(!player || !functionp(player->query_name))
		return (["ok":0,"security_blocked":1,"realm_type":"unknown",
			"message":"人物对象无效，世界归属不可验证。"]) ;
	return query_realm_for_user_id((string)player->query_name());
}

int is_active_illusion_character(object player)
{
	mapping realm = query_realm_for_player(player);
	return (int)realm["ok"] && (string)realm["realm_type"]=="illusion" &&
		(string)realm["illusion_state"]=="active";
}

private string content_room_prefix(mapping config)
{
	string entry=(string)(config["entry_room"] || "");
	return entry!="" ? dirname(entry)+"/" : "";
}

private int is_content_room_path(mapping config,string path)
{
	string prefix=content_room_prefix(config);
	return path!="" && prefix!="" && has_prefix(path,prefix);
}

private string content_id_for_room_path(string path)
{
	foreach(sort(indices(content_configs)),string illusion_id)
		if(is_content_room_path(content_configs[illusion_id],path))
			return illusion_id;
	return "";
}

private int content_cycle_closed(string illusion_id)
{
	mapping status=query_public_status();
	if(!valid_identifier(illusion_id) || !(int)status["ok"])
		return 0;
	if(illusion_id==(string)status["illusion_id"])
		return (string)status["phase"]=="closed";
	return search((array)(status["closed_ids"] || ({})),illusion_id)!=-1;
}

array(mapping(string:mixed)) query_eternal_echoes()
{
	array(mapping(string:mixed)) result=({});
	foreach(sort(indices(content_configs)),string illusion_id){
		mapping config=content_configs[illusion_id];
		if(content_cycle_closed(illusion_id))
			result+=({(["illusion_id":illusion_id,
				"display_name":(string)config["display_name"],
				"story_title":(string)config["story_title"],
				"entry_room":(string)config["entry_room"]])});
	}
	return result;
}

/**
 * Active seasonal characters use their exact cycle. Eternal characters may
 * use only a closed, archived cycle (Eternal Echo). Room identity wins over
 * the saved menu selection so concurrent S1/S2 archives never mix progress.
 */
private mapping(string:mixed) story_context(object player)
{
	mapping realm;
	mapping status;
	string illusion_id;
	string current_path;
	mapping config;
	if(!player)
		return ([]);
	realm=query_realm_for_player(player);
	if(!(int)realm["ok"] || (int)realm["security_blocked"])
		return ([]);
	status=query_public_status();
	if((string)realm["realm_type"]=="illusion" &&
	   (string)realm["illusion_state"]=="active"){
		illusion_id=(string)realm["illusion_id"];
		config=content_config_for_id(illusion_id);
		if(illusion_id!=(string)status["illusion_id"] ||
		   (string)status["phase"]!="active" || !sizeof(config))
			return ([]);
		return (["ok":1,"mode":"season","illusion_id":illusion_id,
			"config":config,"ranking_enabled":1]);
	}
	current_path=normalized_destination_path(environment(player));
	illusion_id=content_id_for_room_path(current_path);
	if(illusion_id=="")
		illusion_id=(string)(player["/plus/illusion_echo/selected_id"] || "");
	if(illusion_id=="" || !content_cycle_closed(illusion_id)){
		array echoes=query_eternal_echoes();
		if(sizeof(echoes))
			illusion_id=(string)echoes[-1]["illusion_id"];
	}
	config=content_config_for_id(illusion_id);
	if(!content_cycle_closed(illusion_id) || !sizeof(config))
		return ([]);
	return (["ok":1,"mode":"echo","illusion_id":illusion_id,
		"config":config,"ranking_enabled":0]);
}

mapping(string:mixed) query_story_access(object player)
{
	mapping context=story_context(player);
	if(!sizeof(context))
		return (["ok":0,"mode":"none","echoes":query_eternal_echoes()]);
	return (["ok":1,"mode":(string)context["mode"],
		"illusion_id":(string)context["illusion_id"],
		"display_name":(string)((mapping)context["config"])["display_name"],
		"in_content_room":is_content_room_path((mapping)context["config"],
			normalized_destination_path(environment(player))),
		"ranking_enabled":(int)context["ranking_enabled"],
		"echoes":query_eternal_echoes()]);
}

/**
 * S1 八十一章结束后的自然成长入口。
 *
 * 120 级只是照命资格里程碑，不是这里的等级上限。赛季进行中与赛季
 * 关闭后的永恒回响共用同一份人物进度和动态猎场；本接口只证明访问
 * 资格，不修改等级、经验、VIP 上限或任何战斗公式。
 */
mapping(string:mixed) query_post_story_training_status(object player)
{
	mapping context;
	mapping config;
	mapping progress;
	int claimed;
	int total;
	int level;
	if(!player)
		return (["ok":0,"unlocked":0,
			"message":"归真修行人物不存在。"]) ;
	context = story_context(player);
	if(!sizeof(context) || (string)context["illusion_id"]!="S1" ||
	   search(({"season","echo"}),(string)context["mode"])==-1)
		return (["ok":1,"unlocked":0,
			"message":"请先进入S1幻境或已经开放的S1永恒回响。"]) ;
	config = (mapping)context["config"];
	progress = player_progress(player,0);
	if(!sizeof(progress))
		return (["ok":1,"unlocked":0,
			"message":"请先开始S1九卷八十一章历程。"]) ;
	total = sizeof((array)(config["chapters"] || ({})));
	claimed = claimed_chapter_count(progress);
	level = (int)player->query_level();
	if(total<1 || claimed!=total)
		return (["ok":1,"unlocked":0,"chapter_claimed":claimed,
			"chapter_total":total,"level":level,"target_level":999,
			"message":"完成九卷八十一章后开启归真修行。"]) ;
	return (["ok":1,"unlocked":1,"mode":(string)context["mode"],
		"chapter_claimed":claimed,"chapter_total":total,
		"level":level,"target_level":999,"max_level":999,
		"hidden_milestone":level>=120,
		"complete":level>=999,
		"remaining_levels":max(0,999-level),
		"message":level>=999 ? "归真修行已经达到999级。" :
			"归真修行已开启，可在动态同级猎场继续成长至999级。"]) ;
}

private mapping(string:mixed) config_for_progress(mapping progress)
{
	string illusion_id=(string)(progress["content_id"] || "");
	mapping config=content_config_for_id(illusion_id);
	// S1上线前的进度和轻量排行榜快照没有content_id。它们的章节ID
	// 仍属于当前配置；只读兼容时回退当前内容，新进度会补写明确编号。
	if(!sizeof(config) && sizeof(illusion_config))
		config=illusion_config;
	return config;
}

/**
 * Return the current season's safe public grinding route.  Seasonal route
 * selection lives beside the season map contract so the generic AFK daemon
 * never guesses an Eternal-world destination for an isolated character.
 */
mapping(string:mixed) query_autofight_route(object player)
{
	mapping context=story_context(player);
	mapping post_story;
	string illusion_id;
	string path;
	string name;
	array(string) paths;
	int level;
	int target_level;
	if(!player || !sizeof(context))
		return ([]);
	if((string)context["mode"]=="echo" &&
	   !is_content_room_path((mapping)context["config"],
		normalized_destination_path(environment(player))))
		return ([]);
	illusion_id = (string)context["illusion_id"];
	level = player->query_level();
	if(illusion_id!="S1")
		return ([]);
	post_story = query_post_story_training_status(player);
	if((int)post_story["unlocked"]){
		target_level = min(999,max(69,level));
		paths = ({
			"illusion_s1/returning_moon_steps",
			"illusion_s1/returning_star_pass",
			"illusion_s1/returning_heart_terrace",
		});
		return ([
			"max":999,
			"level":target_level,
			"name":"归真修行",
			"path":paths[0],
			"paths":paths,
			"capacity":18,
			"total_capacity":sizeof(paths)*18,
			"target_min":target_level,
			"target_max":min(999,target_level+2),
			"disable_overflow":1,
			"illusion_id":illusion_id,
			"post_story_training":1,
		]);
	}
	if(level<10){
		paths = ({
			"illusion_s1/moon_dew_field",
			"illusion_s1/silver_reed_bank",
			"illusion_s1/starlight_slope",
		});
		name = "银痕初猎";
		target_level = 1;
	}
	else if(level<20){
		paths = ({
			"illusion_s1/mist_bamboo_glen",
			"illusion_s1/cloud_pine_hollow",
			"illusion_s1/moonshadow_wood",
		});
		name = "雾林寻星";
		target_level = 10;
	}
	else if(level<30){
		paths = ({
			"illusion_s1/mirror_sandbar",
			"illusion_s1/glasswater_bank",
			"illusion_s1/moonwave_shoal",
		});
		name = "镜湖逆潮";
		target_level = 20;
	}
	else if(level<40){
		paths = ({
			"illusion_s1/broken_star_court",
			"illusion_s1/astral_stonewood",
			"illusion_s1/observatory_outfield",
		});
		name = "折星破阵";
		target_level = 30;
	}
	else if(level<50){
		paths = ({
			"illusion_s1/echo_battlement",
			"illusion_s1/old_city_square",
			"illusion_s1/stardust_lane",
		});
		name = "古城回声";
		target_level = 40;
	}
	else{
		paths = ({
			"illusion_s1/abyss_flower_sea",
			"illusion_s1/deepmoon_valley",
			"illusion_s1/starfall_garden",
		});
		name = "深渊同辉";
		target_level = 50;
	}
	path = paths[0];
	return ([
		"max":69,
		"level":target_level,
		"name":name,
		"path":path,
		"paths":paths,
		"capacity":18,
		"total_capacity":sizeof(paths)*18,
		"target_min":target_level,
		// 50档猎场自51级起刷动态同级怪：窗口上限跟人物等级走，
		// 否则高等级人物在动态怪房里无怪可打。
		"target_max":min(999,max(target_level+2,level+2)),
		"disable_overflow":1,
		"illusion_id":illusion_id,
	]);
}

/** Return qge74hye's relative path for the current season's safe bedroom. */
string query_autofight_rest_room(object player)
{
	mapping context=story_context(player);
	mapping config;
	string room;
	string prefix = "/gamelib/d/";
	if(!player || !sizeof(context))
		return "";
	config=(mapping)context["config"];
	if((string)context["mode"]=="echo" &&
	   !is_content_room_path(config,
		normalized_destination_path(environment(player))))
		return "";
	room = (string)(config["entry_room"] || "");
	if(!has_prefix(room,prefix))
		return "";
	room = room[sizeof(prefix)..];
	if(has_suffix(room,".pike"))
		room = room[..sizeof(room)-6];
	return room;
}

// 登录落点修复必须与世界身份使用同一份账号索引判断。否则一个仍在
// 幻境中的人物若保存了已删除的S1房间，通用修复会把他送往永恒主城，
// 随后又被跨世界守卫拒绝，最终表现为登录后卡住。
string query_login_fallback_room(object player)
{
	mapping realm = query_realm_for_player(player);
	if(!(int)realm["ok"] || (int)realm["security_blocked"] ||
	   (string)realm["realm_type"]!="illusion" ||
	   (string)realm["illusion_state"]!="active" ||
	   (string)realm["illusion_id"]!=(string)illusion_config["current_id"])
		return "";
	return (string)(illusion_config["entry_room"] || "");
}

string query_character_group(string user_id)
{
	// 这是 Worker 路由热路径。账号索引异常必须收敛为人物专属隔离组，
	// 不能把异常抛给逻辑区策略，也不能猜回永恒服共享组。
	mapping realm = query_realm_for_user_id(user_id);
	if(!(int)realm["ok"] && (int)realm["security_blocked"])
		return "realm-unavailable:"+user_id;
	if((int)realm["ok"] && (string)realm["realm_type"]=="illusion" &&
	   (string)realm["illusion_state"]=="active")
		return "illusion:"+(string)realm["illusion_id"];
	return "";
}

int shared_account_assets_blocked(object player)
{
	mapping realm = query_realm_for_player(player);
	return (int)realm["security_blocked"] ||
		((int)realm["ok"] && (string)realm["realm_type"]=="illusion" &&
		 (string)realm["illusion_state"]=="active");
}

private string normalized_destination_path(mixed destination)
{
	string path = "";
	if(objectp(destination))
		path = file_name(destination);
	else if(stringp(destination))
		path = (string)destination;
	if(has_prefix(path,ROOT))
		path = path[sizeof(ROOT)..];
	if(search(path,"#")!=-1)
		path = (path/"#")[0];
	return path;
}

private int is_illusion_room_path(string path)
{
	return is_content_room_path(illusion_config,path);
}

// 归真猎场仍属于S1世界，因此通用跨世界守卫本身无法区分“已通关”
// 与“尚未通关”。入口命令会做资格检查，这里再封住手工构造旧移动
// 命令的旁路；赛季关闭后的永恒回响沿用同一份八十一章进度判定。
private int is_post_story_training_room_path(string path)
{
	if(has_suffix(path,".pike"))
		path = path[..sizeof(path)-6];
	return search(({
		"/gamelib/d/illusion_s1/returning_moon_steps",
		"/gamelib/d/illusion_s1/returning_star_pass",
		"/gamelib/d/illusion_s1/returning_heart_terrace",
	}),path)!=-1;
}

// 返回0表示允许；非0分别表示阶段冻结、幻境人物越界、永恒人物闯入。
// 守卫与TestUnit共用这一纯策略，避免测试为改变生命周期去写运行状态。
private int move_policy(mapping realm,string target,string phase)
{
	string target_content=content_id_for_room_path(target);
	if((int)realm["security_blocked"])
		return 4;
	if((string)realm["realm_type"]=="illusion" &&
	   (string)realm["illusion_state"]=="active"){
		string realm_id=(string)realm["illusion_id"];
		mapping realm_config=content_config_for_id(realm_id);
		if(realm_id!=(string)illusion_config["current_id"] ||
		   !sizeof(realm_config))
			return 1;
		if(phase!="active")
			return 1;
		return is_content_room_path(realm_config,target) ? 0 : 2;
	}
	if(target_content=="")
		return 0;
	if(target_content==(string)illusion_config["current_id"])
		return phase=="closed" ? 0 : 3;
	return content_cycle_closed(target_content) ? 0 : 3;
}

int query_move_policy_for_test(mapping realm,string target,string phase)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return move_policy(realm,normalized_destination_path(target),phase);
}

int guard_player_move(object player,mixed destination)
{
	string target;
	string current;
	mapping realm;
	int policy;
	if(!player || player["/tmp/illusion_move_bypass"])
		return 0;
	target = normalized_destination_path(destination);
	current = normalized_destination_path(environment(player));
	// The per-session entrance is outside both Eternal and S1 worlds. Only a
	// freshly restored object that is not yet in /gamelib/d may enter it; an
	// active character cannot use this exception to escape a real world room.
	if(target=="/gamelib/d/init" &&
	   !has_prefix(current,"/gamelib/d/"))
		return 0;
	realm = query_realm_for_player(player);
	policy = move_policy(realm,target,(string)query_public_status()["phase"]);
	if(!policy && is_post_story_training_room_path(target) &&
	   !(int)query_post_story_training_status(player)["unlocked"]){
		tell_object(player,"完成S1九卷八十一章后，才可进入归真修行猎场。\n");
		return 1;
	}
	if(policy==1){
		tell_object(player,(string)illusion_config["display_name"]+
			"已进入回归结算，请使用“幻境区”完成安全回归。\n");
		return 1;
	}
	if(policy==2){
		tell_object(player,"幻境人物暂不能离开新月幻境；任务与装备会在期满结算后随原档案回归。\n");
		return 1;
	}
	if(policy==3){
		tell_object(player,"这里是仍在进行中的幻境，仅本期幻境人物可以进入；已关闭内容会自动开放为永恒回响。\n");
		return 1;
	}
	if(policy==4){
		tell_object(player,"账号世界索引暂不可验证，已冻结移动以保护人物与装备，请联系管理员。\n");
		return 1;
	}
	return 0;
}

private mapping player_progress(object player,int create_if_missing)
{
	mapping context=story_context(player);
	if(!sizeof(context))
		return ([]);
	return player_progress_for_id(player,(string)context["illusion_id"],
		create_if_missing);
}

private mapping player_progress_for_id(object player,string illusion_id,
	int create_if_missing)
{
	mapping all_progress = player[ILLUSION_PROGRESS_ROOT];
	mapping progress;
	if(!mappingp(all_progress))
		all_progress = ([]);
	progress = all_progress[illusion_id];
	if(!mappingp(progress) && create_if_missing){
		mapping public_status = query_public_status();
		int starts_at = (int)public_status["starts_at"];
		mapping config=content_config_for_id(illusion_id);
		array chapters = sizeof(config) ? (array)config["chapters"] : ({});
		string first_chapter_id = sizeof(chapters) ?
			(string)chapters[0]["id"] : "";
		if(starts_at<=0 || starts_at>time())
			starts_at = time();
		progress = ([
			"version":1,"content_id":illusion_id,
			"joined_at":time(),"kills":0,"boss_kills":0,
			"team_kills":0,"visited":([]),"path":"","route_marks":([]),
			"active_days":([]),"story_events":([]),
			"quest_item_pity":([]),
			"claims":([]),"season_starts_at":starts_at,
			"chapter_counter_version":2,
			"chapter_route_rhythm_version":1,
			"chapter_counter_id":first_chapter_id,
			"chapter_started_at":time(),
			"chapter_kills":0,"chapter_boss_kills":0,
			"chapter_visit_rooms":([]),
			"ranking_weeks":([]),"ranking_titles":({}),
			"ranking_reward_claims":([]),"pvp_honor":0,"pvp_wins":0,
			"ranking_level":0,"ranking_experience_start":-1,
			"ranking_experience_latest":0,
		]);
		all_progress[illusion_id] = progress;
		player[ILLUSION_PROGRESS_ROOT] = all_progress;
	}
	else if(mappingp(progress) &&
	   (string)(progress["content_id"] || "")=="")
		progress["content_id"]=illusion_id;
	return mappingp(progress) ? progress : ([]);
}

private int ranking_week_index(mapping progress,int timestamp)
{
	int starts_at = (int)progress["season_starts_at"];
	if(starts_at<=0){
		starts_at = (int)progress["joined_at"];
		if(starts_at<=0)
			starts_at = timestamp;
		progress["season_starts_at"] = starts_at;
	}
	if(timestamp<starts_at)
		return 1;
	return min(60,1+(timestamp-starts_at)/ILLUSION_RANKING_WEEK_SECONDS);
}

private mapping ranking_week_state(mapping progress,int timestamp,
	int create_if_missing)
{
	mapping weeks = mappingp(progress["ranking_weeks"]) ?
		(mapping)progress["ranking_weeks"] : ([]);
	string key = (string)ranking_week_index(progress,timestamp);
	mapping state = mappingp(weeks[key]) ? (mapping)weeks[key] : ([]);
	if(!sizeof(state) && create_if_missing){
		state = ([
			"kills":0,"boss_kills":0,"team_kills":0,"visits":0,
			"route_marks":0,"story_events":0,"active_days":0,
			"chapter_claims":0,"set_parts":0,
			"pvp_honor":0,"pvp_wins":0,"level":0,
			"experience_start":-1,"experience_latest":0,
			"completed_at":0,
		]);
		weeks[key] = state;
		progress["ranking_weeks"] = weeks;
	}
	return state;
}

private int claimed_set_parts(mapping progress)
{
	mapping config=config_for_progress(progress);
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	int parts;
	foreach((array)(config["chapters"] || ({})),mapping chapter)
		if((int)claims[(string)chapter["id"]])
			parts += (int)chapter["reward_count"];
	return min(10,max(0,parts));
}

private int final_completion_at(mapping progress)
{
	mapping config=config_for_progress(progress);
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	array chapters = (array)(config["chapters"] || ({}));
	if(!sizeof(chapters))
		return 0;
	return (int)claims[(string)chapters[-1]["id"]];
}

private void update_ranking_snapshot(object player,mapping progress,
	void|int timestamp)
{
	int now = timestamp || time();
	mapping week;
	int experience;
	if(!player || !mappingp(progress))
		return;
	week = ranking_week_state(progress,now,1);
	experience = max(0,(int)player->exp);
	if((int)week["experience_start"]<0)
		week["experience_start"] = experience;
	week["experience_latest"] = max((int)week["experience_latest"],
		experience);
	week["level"] = max((int)week["level"],(int)player->query_level());
	if(!has_index(progress,"ranking_experience_start") ||
	   (int)progress["ranking_experience_start"]<0)
		progress["ranking_experience_start"] = experience;
	progress["ranking_experience_latest"] = max(
		(int)progress["ranking_experience_latest"],experience);
	progress["ranking_level"] = max((int)progress["ranking_level"],
		(int)player->query_level());
	progress["set_parts"] = claimed_set_parts(progress);
	progress["completed_at"] = final_completion_at(progress);
}

private void invalidate_ranking_cache(string illusion_id)
{
	foreach(indices(ranking_cache),string key)
		if(has_prefix(key,illusion_id+"|"))
			m_delete(ranking_cache,key);
}

private int progress_visit_count(mapping progress)
{
	return mappingp(progress["visited"]) ?
		sizeof((mapping)progress["visited"]) : 0;
}

private int story_beijing_day_index(int timestamp)
{
	return (timestamp+8*3600)/86400;
}

private int story_active_day_count(mapping progress)
{
	return mappingp(progress["active_days"]) ?
		sizeof((mapping)progress["active_days"]) : 0;
}

private int story_event_count(mapping progress)
{
	return mappingp(progress["story_events"]) ?
		sizeof((mapping)progress["story_events"]) : 0;
}

private int record_story_activity_day(mapping progress,int timestamp)
{
	mapping days = mappingp(progress["active_days"]) ?
		(mapping)progress["active_days"] : ([]);
	string day_key = (string)story_beijing_day_index(timestamp);
	if((int)days[day_key])
		return 0;
	if(sizeof(days)>=64)
		return 0;
	days[day_key] = timestamp;
	progress["active_days"] = days;
	mapping week = ranking_week_state(progress,timestamp,1);
	week["active_days"] = (int)week["active_days"]+1;
	return 1;
}

private int story_event_unlocked(mapping progress,mapping event)
{
	mapping config=config_for_progress(progress);
	int chapter_number = (int)event["chapter"];
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	if(chapter_number<=1)
		return 1;
	return (int)claims[(string)((array)config["chapters"])
		[chapter_number-2]["id"]]>0;
}

private mapping(string:mixed) find_story_event(string kind,string path,
	mapping progress)
{
	mapping config=config_for_progress(progress);
	mapping collected = mappingp(progress["story_events"]) ?
		(mapping)progress["story_events"] : ([]);
	foreach((array)(config["story_events"] || ({})),mapping event)
		if((string)event["kind"]==kind &&
		   (string)event["path"]==path &&
		   !(int)collected[(string)event["id"]] &&
		   story_event_unlocked(progress,event))
			return event;
	return ([]);
}

private int record_story_event(mapping progress,mapping event,int timestamp)
{
	mapping collected = mappingp(progress["story_events"]) ?
		(mapping)progress["story_events"] : ([]);
	string event_id = (string)event["id"];
	if(event_id=="" || (int)collected[event_id] || sizeof(collected)>=128)
		return 0;
	collected[event_id] = timestamp;
	progress["story_events"] = collected;
	mapping week = ranking_week_state(progress,timestamp,1);
	week["story_events"] = (int)week["story_events"]+1;
	return 1;
}

private int is_test_illusion_player(object player)
{
	return getenv("XIAND_RUN_TESTUNIT")=="1" && player &&
		functionp(player->query_name) &&
		has_prefix((string)player->query_name(),"xd99testunitillusion");
}

/** TestUnit 用的一次性故障注入，验证十问写盘失败时状态完整回滚。 */
int force_next_story_quiz_save_failure_for_test(object player)
{
	string player_name;
	if(!is_test_illusion_player(player))
		return 0;
	player_name = (string)player->query_name();
	story_quiz_test_save_failures[player_name] = 1;
	return 1;
}

private int save_story_quiz_player(object player)
{
	string player_name = (string)player->query_name();
	if(is_test_illusion_player(player) &&
	   (int)story_quiz_test_save_failures[player_name]>0){
		m_delete(story_quiz_test_save_failures,player_name);
		return 0;
	}
	return player->save_with_result();
}

private void restore_mapping_snapshot(mapping target,mapping snapshot)
{
	// 多个查询可能持有同一进度映射引用。只替换档案根路径会让旧引用
	// 继续看见未提交状态，因此存档失败时必须原地恢复事务快照。
	foreach(indices(target),mixed key)
		m_delete(target,key);
	foreach(indices(snapshot),mixed key)
		target[key]=copy_value(snapshot[key]);
}

private int claimed_chapter_count(mapping progress)
{
	mapping config=config_for_progress(progress);
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	int count;
	foreach((array)(config["chapters"] || ({})),mapping chapter){
		if((int)claims[(string)chapter["id"]]<=0)
			break;
		count++;
	}
	return count;
}

/**
 * 章回墙钟耗时用于定位真实流失点，不参与奖励、排行或解锁。新档使用
 * 独立起点；旧档没有该字段时，以前一章领取时间（首章用加入时间）
 * 安全补算，因此无需批量迁移人物档案。
 */
private int current_chapter_started_at(mapping progress,int chapter_number)
{
	int started=(int)progress["chapter_started_at"];
	if(started>0)
		return started;
	if(chapter_number>1){
		mapping config=config_for_progress(progress);
		array chapters=(array)(config["chapters"] || ({}));
		mapping claims=mappingp(progress["claims"]) ?
			(mapping)progress["claims"] : ([]);
		if(chapter_number-2<sizeof(chapters))
			started=(int)claims[(string)chapters[chapter_number-2]["id"]];
	}
	if(started<=0)
		started=(int)progress["joined_at"];
	return started>0 ? started : time();
}

private string quest_item_account_owner(object player)
{
	string owner;
	if(!player)
		return "";
	owner = functionp(player->query_account_owner) ?
		(string)player->query_account_owner() : "";
	return owner!="" ? owner : (string)player->query_name();
}

private int player_quest_item_count(object player,mapping gate)
{
	string gate_id = (string)(gate["id"] || "");
	string owner = quest_item_account_owner(player);
	int count;
	if(!player || gate_id=="" || owner=="")
		return 0;
	foreach(all_inventory(player),object item)
		if(item && functionp(item->query_illusion_quest_item_id) &&
		   functionp(item->query_account_bind_owner) &&
		   (string)item->query_illusion_quest_item_id()==gate_id &&
		   (string)item->query_account_bind_owner()==owner)
			count++;
	return count;
}

private string quest_item_drop_rate_text(int basis_points);
private int ensure_current_chapter_counters(object player,mapping progress);

private mapping(string:mixed) quest_item_gate_status(object player,
	mapping progress,mapping chapter)
{
	mapping gate = mappingp(chapter["quest_item_gate"]) ?
		(mapping)chapter["quest_item_gate"] : ([]);
	mapping pities = mappingp(progress["quest_item_pity"]) ?
		(mapping)progress["quest_item_pity"] : ([]);
	string gate_id = (string)(gate["id"] || "");
	int pity_limit = (int)(gate["pity_kills"] || 0);
	int pity = gate_id!="" ? (int)pities[gate_id] : 0;
	int count;
	int substitute_ready;
	mixed substitution_err;
	if(!sizeof(gate))
		return (["required":0,"count":0,"ready":1,"pity":0]);
	pity = max(0,min(max(0,pity_limit-1),pity));
	count = player_quest_item_count(player,gate);
	// 新月回响只提供确定性剧情凭证，不伪造或复制实体道具。旧物品、
	// 原保底和已刷进度逐字保留；结构或所有者异常时忽略替代凭证，
	// 失败关闭到原掉落路径。
	if(player && gate_id!=""){
		substitution_err = catch{
			substitute_ready = ILLUSION_JOURNEYD->
				query_gate_substitution_ready(player,gate_id);
		};
		if(substitution_err){
			string user_id = functionp(player->query_name) ?
				(string)player->query_name() : "";
			string error_key = user_id+":"+gate_id;
			substitute_ready = 0;
			// 任务页、挂机路由和每次击杀都会读取凭证。依赖守护
			// 持续异常时按人物+信物限频，避免多人挂机写爆日志；
			// 缓存也必须有界，不让恶意或损坏档案撑大 Worker 内存。
			if(sizeof(gate_substitution_error_log_times)>=4096 &&
			   !has_index(gate_substitution_error_log_times,error_key))
				gate_substitution_error_log_times=([]);
			if(time()-(int)gate_substitution_error_log_times[error_key]>=60){
				gate_substitution_error_log_times[error_key]=time();
				werror("[ILLUSION_GATE] 支线替代凭证查询异常，已回退实体道具: user=%s gate=%s error=%s\n",
					user_id,gate_id,describe_error(substitution_err));
			}
		}
	}
	return copy_value(gate)+([
		"count":count,
		"ready":count>=(int)gate["required"] || substitute_ready,
		"substitute_ready":substitute_ready,
		"pity":pity,
		"pity_remaining":max(0,pity_limit-pity),
		"drop_rate_text":quest_item_drop_rate_text(
			(int)gate["drop_basis_points"]),
	]);
}

private mapping(string:mixed) current_quest_item_gate_for_kill(
	object player,mapping progress,string npc_path,string room_path)
{
	mapping config = config_for_progress(progress);
	array chapters = (array)(config["chapters"] || ({}));
	int index = claimed_chapter_count(progress);
	mapping chapter;
	mapping gate;
	if(index<0 || index>=sizeof(chapters))
		return ([]);
	chapter = (mapping)chapters[index];
	if(!mappingp(chapter["quest_item_gate"]))
		return ([]);
	gate = quest_item_gate_status(player,progress,chapter);
	if((int)gate["ready"] ||
	   npc_path!=(string)gate["source_path"] ||
	   !arrayp(gate["source_rooms"]) ||
	   search((array)gate["source_rooms"],room_path)==-1)
		return ([]);
	return gate;
}

mapping(string:mixed) query_quest_item_gate_status_for_test(object player,
	mapping progress,mapping chapter)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return ([]);
	return quest_item_gate_status(player,progress,chapter);
}

private string quest_item_drop_rate_text(int basis_points)
{
	basis_points = max(1,min(10000,basis_points));
	if(basis_points%100==0)
		return (string)(basis_points/100)+"%";
	if(basis_points%10==0)
		return sprintf("%d.%d%%",basis_points/100,
			(basis_points%100)/10);
	return sprintf("%d.%02d%%",basis_points/100,basis_points%100);
}

private int quest_item_random_drop(int basis_points,int roll)
{
	return basis_points>=1 && basis_points<=10000 &&
		roll>=1 && roll<=10000 && roll<=basis_points;
}

private mapping(string:mixed) attempt_quest_item_drop(object player,
	mapping progress,string npc_path,string room_path)
{
	mapping gate = current_quest_item_gate_for_kill(player,progress,
		npc_path,room_path);
	mapping pities;
	object|zero item = 0;
	string gate_id;
	int pity;
	int roll;
	int forced;
	int dropped;
	if(!sizeof(gate))
		return (["ok":1,"attempted":0]);
	gate_id = (string)gate["id"];
	pity = (int)gate["pity"]+1;
	roll = random(10000)+1;
	forced = pity>=(int)gate["pity_kills"];
	dropped = forced || quest_item_random_drop(
		(int)gate["drop_basis_points"],roll);
	if(dropped){
		mixed err = catch{
			item = clone(ROOT+(string)gate["item_path"]);
		};
		if(err || !item || !functionp(item->bind_to_account) ||
		   !item->bind_to_account(player) || item->move(player)!=1 ||
		   environment(item)!=player){
			if(item)
				destruct(item);
			return (["ok":0,"attempted":1,
				"message":"剧情道具生成失败，本次击杀未消耗保底进度。"]);
		}
		pity = 0;
	}
	pities = mappingp(progress["quest_item_pity"]) ?
		(mapping)progress["quest_item_pity"] : ([]);
	pities[gate_id] = pity;
	progress["quest_item_pity"] = pities;
	return ([
		"ok":1,"attempted":1,"dropped":dropped,"forced":forced,
		"roll":roll,"pity":pity,"item":item,"gate":gate,
		"count":player_quest_item_count(player,gate),
	]);
}

/** TestUnit只读验证万分比边界，生产掉落与测试共用同一判定。 */
int query_quest_item_random_drop_for_test(object player,
	int basis_points,int roll)
{
	if(!is_test_illusion_player(player))
		return 0;
	return quest_item_random_drop(basis_points,roll);
}

/**
 * 将测试人物当前剧情道具置于下一次有效击杀触发硬保底的位置。
 * 只在XIAND_RUN_TESTUNIT且固定测试账号前缀下开放，避免端到端测试
 * 为验证万分比边界进行大量磁盘写入。
 */
int prime_current_quest_item_pity_for_test(object player)
{
	mapping context;
	mapping progress;
	mapping old_progress;
	mapping config;
	array chapters;
	mapping chapter;
	mapping gate;
	mapping pities;
	int index;
	if(!is_test_illusion_player(player))
		return 0;
	context = story_context(player);
	if(!sizeof(context) || (string)context["illusion_id"]!="S1")
		return 0;
	progress = player_progress(player,1);
	if(!ensure_current_chapter_counters(player,progress))
		return 0;
	config = config_for_progress(progress);
	chapters = (array)(config["chapters"] || ({}));
	index = claimed_chapter_count(progress);
	if(index<0 || index>=sizeof(chapters))
		return 0;
	chapter = (mapping)chapters[index];
	gate = quest_item_gate_status(player,progress,chapter);
	if((int)gate["required"]<=0 || (int)gate["ready"] ||
	   (int)gate["pity_kills"]<=0)
		return 0;
	old_progress = copy_value(progress);
	pities = mappingp(progress["quest_item_pity"]) ?
		(mapping)progress["quest_item_pity"] : ([]);
	pities[(string)gate["id"]] = (int)gate["pity_kills"]-1;
	progress["quest_item_pity"] = pities;
	if(!player->save_with_result()){
		restore_mapping_snapshot(progress,old_progress);
		return 0;
	}
	return 1;
}

private mapping(string:int) chapter_step_requirements(mapping progress,
	int index);
private mapping(string:string) chapter_exploration_target(mapping progress,
	int index);
private mapping(string:int) current_chapter_kill_credit(object player,
	mapping progress,string npc_path,string room_path);
private int current_chapter_visit_credit(object player,mapping progress,
	string room_path);

private int is_illusion_progress_checkpoint(mapping progress,
	int boss_kill,int route_mark_added,int previous_team_kills,
	int activity_day_added,int story_event_added)
{
	mapping config=config_for_progress(progress);
	int kills = (int)progress["kills"];
	int chapter_index = claimed_chapter_count(progress);
	if(boss_kill || route_mark_added || activity_day_added ||
	   story_event_added || kills%25==0)
		return 1;
	if(chapter_index<sizeof((array)(config["chapters"] || ({})))){
		mapping step = chapter_step_requirements(progress,chapter_index);
		if(((int)step["kills"]>0 &&
		    (int)progress["chapter_kills"]==(int)step["kills"]) ||
		   ((int)step["boss_kills"]>0 &&
		    (int)progress["chapter_boss_kills"]==
			(int)step["boss_kills"]))
			return 1;
	}
	if(previous_team_kills<
	   (int)config["route_challenges"]["companion_team_kills"] &&
	   (int)progress["team_kills"]>=
	   (int)config["route_challenges"]["companion_team_kills"])
		return 1;
	return 0;
}

private mapping(string:mixed) chapter_progress_guide(object player,
	mapping progress);

/**
 * 限章挂机完成时，只脱离当前S1房间中的普通NPC战斗。
 *
 * 群攻或同房间多怪会让玩家在最后一只任务怪结算后继续锁定另一只怪，
 * 导致任务页回跳一直等待。若仇恨表混入玩家、召唤物、其它世界NPC或
 * 跨房对象则失败关闭，绝不借任务完成强制中止PVP或其它战斗。
 */
private int disengage_completed_chapter_hunt(object player,
	string illusion_id)
{
	array targets;
	string npc_prefix;
	object room;
	if(!player || illusion_id=="" || !functionp(player->get_all_targets) ||
	   !functionp(player->_clean_fight))
		return 0;
	room = environment(player);
	if(!room)
		return 0;
	targets = player->get_all_targets() || ({});
	npc_prefix = "/gamelib/clone/npc/illusion_"+
		lower_case(illusion_id)+"/";
	foreach(targets,object target){
		string target_path;
		if(!target || !objectp(target) || !functionp(target->is) ||
		   !target->is("npc") || environment(target)!=room)
			return 0;
		target_path = normalized_destination_path(target);
		if(!has_prefix(target_path,npc_prefix))
			return 0;
	}
	foreach(targets,object target){
		mixed remaining;
		target->clean_targets(player);
		remaining = target->get_all_targets();
		if(functionp(target->query_in_combat) &&
		   target->query_in_combat() &&
		   (!arrayp(remaining) || !sizeof((array)remaining)))
			target->_clean_fight();
	}
	if(functionp(player->query_in_combat) && player->query_in_combat())
		player->_clean_fight();
	return 1;
}

private int return_completed_chapter_task_view(object player,
	string illusion_id,string chapter_id,int retry)
{
	mapping pending;
	mapping context;
	if(!player || !player->is || !player->is("player"))
		return 0;
	pending = mappingp(player["/tmp/illusion_chapter_return_pending"]) ?
		(mapping)player["/tmp/illusion_chapter_return_pending"] : ([]);
	if((string)pending["illusion_id"]!=illusion_id ||
	   (string)pending["chapter_id"]!=chapter_id)
		return (string)player[
			"/tmp/illusion_chapter_last_return"]==chapter_id;
	if((int)player->in_combat){
		if(retry<10)
			call_out(return_completed_chapter_task_view,1,player,
				illusion_id,chapter_id,retry+1);
		return 0;
	}
	context = story_context(player);
	if(!sizeof(context) ||
	   (string)context["illusion_id"]!=illusion_id){
		player->m_delete_foruser(
			"/tmp/illusion_chapter_return_pending");
		return 0;
	}
	player->m_delete_foruser("/tmp/illusion_chapter_return_pending");
	player["/tmp/illusion_chapter_last_return"] = chapter_id;
	player->reset_view();
	player->command("illusion_realm");
	return 1;
}

int complete_chapter_task_return_for_test(object player)
{
	mapping pending;
	if(!is_test_illusion_player(player))
		return 0;
	pending = mappingp(player["/tmp/illusion_chapter_return_pending"]) ?
		(mapping)player["/tmp/illusion_chapter_return_pending"] : ([]);
	if(!sizeof(pending))
		return 0;
	return return_completed_chapter_task_view(player,
		(string)pending["illusion_id"],(string)pending["chapter_id"],10);
}

void record_room_visit(object player,object room)
{
	mapping context;
	mapping config;
	string illusion_id;
	string path;
	mapping progress;
	mapping old_progress;
	mapping visited;
	mapping chapter_visit_rooms;
	int visit_added;
	int chapter_visit_added;
	int activity_day_added;
	context=story_context(player);
	if(!sizeof(context) || !room)
		return;
	config=(mapping)context["config"];
	illusion_id=(string)context["illusion_id"];
	path = normalized_destination_path(room);
	if(!is_content_room_path(config,path))
		return;
	progress = player_progress(player,1);
	if(!ensure_current_chapter_counters(player,progress))
		return;
	old_progress = copy_value(progress);
	activity_day_added = record_story_activity_day(progress,time());
	chapter_visit_rooms = mappingp(progress["chapter_visit_rooms"]) ?
		(mapping)progress["chapter_visit_rooms"] : ([]);
	if(current_chapter_visit_credit(player,progress,path) &&
	   !(int)chapter_visit_rooms[path]){
		chapter_visit_rooms[path] = 1;
		progress["chapter_visit_rooms"] = chapter_visit_rooms;
		chapter_visit_added = 1;
	}
	visited = mappingp(progress["visited"]) ? progress["visited"] : ([]);
	if(!(int)visited[path]){
		visited[path] = 1;
		progress["visited"] = visited;
		visit_added = 1;
	}
	if(visit_added || chapter_visit_added || activity_day_added){
		if(visit_added){
			mapping visit_week = ranking_week_state(progress,time(),1);
			visit_week["visits"] = (int)visit_week["visits"]+1;
		}
		update_ranking_snapshot(player,progress);
		if(!player->save_with_result()){
			player[ILLUSION_PROGRESS_ROOT+"/"+
				illusion_id] = old_progress;
			werror("[ILLUSION_REALM] 到访或修行日进度存档失败并已回滚: %s %s\n",
				(string)player->query_name(),path);
			// 隐藏支线的保存会写整个人物档案。主线失败时不能继续，
			// 否则会把已在内存回滚的主线到访重新写进磁盘。
			return;
		}
		if((int)context["ranking_enabled"] &&
		   !persist_ranking_snapshot(player,progress,illusion_id))
			werror("[ILLUSION_RANKING] 首次到访快照待后续补写: %s\n",
				(string)player->query_name());
		if((int)context["ranking_enabled"])
			invalidate_ranking_cache(illusion_id);
	}
	// 照命四十九难使用同一次真实到访，但它会独立保存整个人物档案，
	// 因此必须位于主线成功提交之后。若本次主线没有新变化则可直接记账。
	// 它的异常仍不能打断已提交的主线、排行榜或普通移动。
	mixed hidden_visit_err = catch{
		ILLUSION_HIDDEN_PROFESSIOND->record_room_visit(player,room);
	};
	if(hidden_visit_err)
		werror("[ILLUSION_HIDDEN] 到访记账异常: user=%s room=%s error=%s\n",
			(string)player->query_name(),path,describe_error(hidden_visit_err));
}

void record_npc_kill(object player,object npc,void|int team_count)
{
	mapping context;
	mapping config;
	string illusion_id;
	mapping progress;
	mapping old_progress;
	mapping marks;
	object env;
	string npc_path;
	string room_path;
	string npc_prefix;
	int boss_kill;
	int route_mark_added;
	int activity_day_added;
	int story_event_added;
	int checkpoint;
	int previous_team_kills;
	mapping task_credit;
	mapping guide;
	mapping task_mode;
	int task_mode_finished;
	int chapter_index;
	int mastery_level;
	mapping story_event = ([]);
	mapping quest_drop = ([]);
	mapping journey_result = ([]);
	object|zero quest_item = 0;
	string story_message = "";
	string experience_beat = "";
	mixed journey_err;
	context=story_context(player);
	if(!sizeof(context) || !npc)
		return;
	config=(mapping)context["config"];
	illusion_id=(string)context["illusion_id"];
	env = environment(player);
	npc_path = normalized_destination_path(npc);
	room_path = env ? normalized_destination_path(env) : "";
	npc_prefix = "/gamelib/clone/npc/illusion_"+
		lower_case(illusion_id)+"/";
	if(!env || environment(npc)!=env ||
	   !is_content_room_path(config,room_path) ||
	   !has_prefix(npc_path,npc_prefix) || !has_suffix(npc_path,".pike"))
		return;
	progress = player_progress(player,1);
	if(!ensure_current_chapter_counters(player,progress))
		return;
	chapter_index = claimed_chapter_count(progress);
	task_mode = mappingp(player["/tmp/illusion_chapter_autofight"]) ?
		(mapping)player["/tmp/illusion_chapter_autofight"] : ([]);
	if(sizeof(task_mode) &&
	   ((string)task_mode["illusion_id"]!=
		illusion_id ||
	    (string)task_mode["chapter_id"]!=
		(string)progress["chapter_counter_id"])){
		player->m_delete_foruser("/tmp/illusion_chapter_autofight");
		task_mode = ([]);
	}
	old_progress = copy_value(progress);
	task_credit = current_chapter_kill_credit(player,progress,npc_path,room_path);
	activity_day_added = record_story_activity_day(progress,time());
	previous_team_kills = (int)progress["team_kills"];
	boss_kill = (int)npc->_boss>0;
	progress["kills"] = (int)progress["kills"]+1;
	if((int)task_credit["kill"])
		progress["chapter_kills"] =
			(int)progress["chapter_kills"]+1;
	if((int)(team_count || 0)>1)
		progress["team_kills"] = (int)progress["team_kills"]+1;
	if(boss_kill)
		progress["boss_kills"] = (int)progress["boss_kills"]+1;
	if((int)task_credit["boss"])
		progress["chapter_boss_kills"] =
			(int)progress["chapter_boss_kills"]+1;
	// 难度精通记录真实任务击杀发生时的最低档，而不是领奖时的档位。
	// 玩家先用低难度打完再临时切高难度，不能伪造本章高难度完成。
	if((int)task_credit["kill"] || (int)task_credit["boss"]){
		mastery_level = PERSONAL_DIFFICULTYD->query_current_level(player);
		if(!intp(progress["chapter_mastery_difficulty"]) ||
		   (int)progress["chapter_mastery_difficulty"]<0 ||
		   mastery_level<(int)progress["chapter_mastery_difficulty"])
			progress["chapter_mastery_difficulty"] = mastery_level;
	}
	mapping kill_week = ranking_week_state(progress,time(),1);
	kill_week["kills"] = (int)kill_week["kills"]+1;
	if((int)(team_count || 0)>1)
		kill_week["team_kills"] = (int)kill_week["team_kills"]+1;
	if(boss_kill)
		kill_week["boss_kills"] = (int)kill_week["boss_kills"]+1;
	if(boss_kill && (int)task_credit["story"]){
		story_event = find_story_event("boss",npc_path,progress);
		if(sizeof(story_event) &&
		   (string)story_event["room"]==room_path &&
		   record_story_event(progress,story_event,time())){
			story_event_added = 1;
			story_message = (string)story_event["message"];
		}
	}
	// 破阵路线要求真正击败三名不同守关首领，重复刷同一名不计新印。
	if((string)progress["path"]=="hunter"){
		foreach((array)config["route_challenges"]["hunter_bosses"],
		   mapping boss)
			if((string)boss["path"]==npc_path){
				marks = mappingp(progress["route_marks"]) ?
					progress["route_marks"] : ([]);
				if(!(int)marks[(string)boss["id"]]){
					marks[(string)boss["id"]] = 1;
					route_mark_added = 1;
					kill_week["route_marks"] =
						(int)kill_week["route_marks"]+1;
				}
				progress["route_marks"] = marks;
				break;
		}
	}
	quest_drop = attempt_quest_item_drop(player,progress,npc_path,
		room_path);
	if((int)quest_drop["attempted"] && !(int)quest_drop["ok"]){
		restore_mapping_snapshot(progress,old_progress);
		tell_object(player,"§c【剧情道具】§r "+
			(string)quest_drop["message"]+"\n");
		werror("[ILLUSION_REALM] 剧情道具生成失败并已回滚: %s npc=%s room=%s\n",
			(string)player->query_name(),npc_path,room_path);
		return;
	}
	if((int)quest_drop["dropped"] && objectp(quest_drop["item"]))
		quest_item = (object)quest_drop["item"];
	update_ranking_snapshot(player,progress);
	guide = chapter_progress_guide(player,progress);
	if(sizeof(task_mode) &&
	   (string)task_mode["completion_kind"]=="chapter_kills")
		task_mode_finished =
			(int)progress["chapter_kills"]>=
			(int)task_mode["target_kills"];
	else
		task_mode_finished = sizeof(task_mode) &&
			(string)guide["kind"]!="hunt";
	checkpoint = is_illusion_progress_checkpoint(progress,boss_kill,
	   route_mark_added,previous_team_kills,activity_day_added,
	   story_event_added);
	if((int)quest_drop["attempted"])
		checkpoint = 1;
	// 章节目标数量很小，逐只保存才能保证重启或跨 Worker 前已经显示的
	// 进度不会回退；普通练级击杀仍沿用原有稀疏检查点，不增加写盘压力。
	if((int)task_credit["kill"] || (int)task_credit["boss"])
		checkpoint = 1;
	if(checkpoint){
		if(!player->save_with_result()){
			if(quest_item)
				destruct(quest_item);
			restore_mapping_snapshot(progress,old_progress);
			werror("[ILLUSION_REALM] 击杀进度检查点存档失败并已回滚: %s kills=%d\n",
				(string)player->query_name(),(int)progress["kills"]);
			return;
		}
		if((int)context["ranking_enabled"] &&
		   !persist_ranking_snapshot(player,progress,illusion_id))
			werror("[ILLUSION_RANKING] 击杀快照待后续补写: %s\n",
				(string)player->query_name());
		if(story_message!="")
			tell_object(player,"§p【剧情推进】§r"+story_message+"\n");
		if((int)task_credit["kill"]){
			mapping chapter_step = chapter_step_requirements(progress,
				chapter_index);
			experience_beat = chapter_experience_beat(chapter_index,
				(int)progress["chapter_kills"],
				(int)chapter_step["kills"]);
			if(experience_beat!="")
				tell_object(player,experience_beat+"\n");
		}
		if((int)quest_drop["attempted"]){
			mapping gate = (mapping)quest_drop["gate"];
			int count = (int)quest_drop["count"];
			int required = (int)gate["required"];
			if((int)quest_drop["dropped"])
				tell_object(player,"§y【剧情道具】§r 获得账号绑定【"+
					(string)gate["name"]+"】 "+(string)count+"/"+
					(string)required+
					((int)quest_drop["forced"] ? "（保底触发）" : "")+
					"。该物品不可交易、赠送、丢弃、拍卖或入库。\n");
			else
				tell_object(player,"§b【剧情道具】§r 本次未掉落【"+
					(string)gate["name"]+"】；保底进度 "+
					(string)(int)quest_drop["pity"]+"/"+
					(string)(int)gate["pity_kills"]+"。\n");
			safe_append_illusion_log(sprintf(
				"%d|quest_item_roll|illusion=%s|user=%s|gate=%s|roll=%d|rate_bp=%d|drop=%d|forced=%d|count=%d|required=%d|pity=%d\n",
				time(),illusion_id,(string)player->query_name(),
				(string)gate["id"],(int)quest_drop["roll"],
				(int)gate["drop_basis_points"],
				(int)quest_drop["dropped"],(int)quest_drop["forced"],
				count,required,(int)quest_drop["pity"]));
		}
	}
	if(checkpoint && task_mode_finished &&
	   functionp(player->query_autofight) &&
	   (string)player->query_autofight()=="enable"){
		AUTOFIGHTD->stop_autofight(player);
		disengage_completed_chapter_hunt(player,illusion_id);
		tell_object(player,"§y【章节狩猎完成】§r 已按你的选择停止本章挂机；普通持续挂机模式不会自动停止。\n");
		player["/tmp/illusion_chapter_return_pending"] = ([
			"illusion_id":illusion_id,
			"chapter_id":(string)task_mode["chapter_id"],
			"created_at":time(),
		]);
		AUTOFIGHTD->publish_server_autofight_final_view(player,
			"§y【章节狩猎完成】§r 已停止本章挂机。\n"+
			(string)guide["message"]+
			"[▶ 返回幻境任务并继续:illusion_realm]|[返回游戏:look]\n");
		call_out(return_completed_chapter_task_view,0,player,illusion_id,
			(string)task_mode["chapter_id"],0);
	}
	if((string)guide["message"]!="" &&
	   ((string)guide["kind"]=="hunt" || checkpoint))
		tell_object(player,(string)guide["message"]);
	// 九卷秘迹是明确标注的S1支线。主线击杀事务先完成，再把同一次
	// 真实NPC死亡交给支线计数；支线异常不得打断经验、掉落或主线结算。
	journey_err = catch{
		journey_result = ILLUSION_JOURNEYD->record_npc_kill(player,npc);
	};
	if(journey_err)
		werror("[ILLUSION_JOURNEY] 支线击杀记账异常: user=%s npc=%s error=%s\n",
			(string)player->query_name(),npc_path,describe_error(journey_err));
	else if((string)journey_result["message"]!="")
		tell_object(player,(string)journey_result["message"]+"\n");
	mixed hidden_kill_err = catch{
		mapping hidden_result = ILLUSION_HIDDEN_PROFESSIOND->
			record_npc_kill(player,npc);
		if((string)(hidden_result["message"] || "")!="")
			tell_object(player,(string)hidden_result["message"]+"\n");
	};
	if(hidden_kill_err)
		werror("[ILLUSION_HIDDEN] 击杀记账异常: user=%s npc=%s error=%s\n",
			(string)player->query_name(),npc_path,
			describe_error(hidden_kill_err));
	if((int)context["ranking_enabled"])
		invalidate_ranking_cache(illusion_id);
}

private string path_name(string path)
{
	if(path=="pioneer") return "寻星";
	if(path=="hunter") return "破阵";
	if(path=="companion") return "同心";
	return "未选择";
}

private mapping(string:mixed) choose_player_path_internal(object player,
	string path,int test_bypass_phase)
{
	mapping progress;
	mapping context=story_context(player);
	if(!sizeof(context) ||
	   search(({"pioneer","hunter","companion"}),path)==-1)
		return (["ok":0,"message":"幻境路线无效。"]) ;
	progress = player_progress(player,1);
	if((string)progress["path"]!="")
		return (["ok":0,"message":(string)context["illusion_id"]+
			"路线已经选择，不能重复改变。"]) ;
	progress["path"] = path;
	if(!player->save_with_result()){
		progress["path"] = "";
		return (["ok":0,"message":"路线保存失败，请稍后重试。"]) ;
	}
	return (["ok":1,"message":"已选择“"+path_name(path)+
		"”路线，本期不可更改。"]);
}

mapping(string:mixed) choose_player_path(object player,string path)
{
	return choose_player_path_internal(player,path,0);
}

mapping(string:mixed) choose_player_path_for_test(object player,string path)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	return choose_player_path_internal(player,path,1);
}

private int route_final_ready(mapping progress)
{
	mapping config=config_for_progress(progress);
	string path = (string)progress["path"];
	mapping marks = mappingp(progress["route_marks"]) ?
		progress["route_marks"] : ([]);
	mapping routes = config["route_challenges"];
	if(path=="pioneer"){
		foreach((array)routes["pioneer_secrets"],mapping secret)
			if(!(int)marks[(string)secret["id"]])
				return 0;
		return 1;
	}
	if(path=="hunter"){
		foreach((array)routes["hunter_bosses"],mapping boss)
			if(!(int)marks[(string)boss["id"]] &&
			   !((string)boss["id"]=="eclipse_priest" &&
			     (int)marks["newmoon_lord"]))
				return 0;
		return 1;
	}
	if(path=="companion")
		return (int)progress["team_kills"]>=
			(int)routes["companion_team_kills"];
	return 0;
}

private int route_target(mapping progress,string path)
{
	mapping config=config_for_progress(progress);
	mapping routes = config["route_challenges"];
	if(path=="pioneer")
		return sizeof((array)routes["pioneer_secrets"]);
	if(path=="hunter")
		return sizeof((array)routes["hunter_bosses"]);
	if(path=="companion")
		return (int)routes["companion_team_kills"];
	return 0;
}

int query_route_final_ready_for_test(mapping progress)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return route_final_ready(progress);
}

private mapping(string:mixed) discover_route_secret_internal(object player,
	int test_bypass_phase)
{
	mapping context=story_context(player);
	mapping config;
	string illusion_id;
	mapping progress;
	mapping old_progress;
	mapping marks;
	string room_path;
	mapping secret = ([]);
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前不能探寻"+
			(string)(context["illusion_id"] || "幻境")+"隐藏月印。"]);
	config=(mapping)context["config"];
	illusion_id=(string)context["illusion_id"];
	progress = player_progress(player,1);
	if((string)progress["path"]!="pioneer")
		return (["ok":0,"message":"只有选择寻星路线的人物能辨认隐藏月印。"]);
	room_path = normalized_destination_path(environment(player));
	foreach((array)config["route_challenges"]["pioneer_secrets"],
	   mapping candidate)
		if((string)candidate["path"]==room_path){
			secret = candidate;
			break;
		}
	if(!sizeof(secret))
		return (["ok":0,"message":"这里没有可辨认的隐藏月印。"]);
	marks = mappingp(progress["route_marks"]) ?
		progress["route_marks"] : ([]);
	if((int)marks[(string)secret["id"]])
		return (["ok":1,"already":1,"message":"这枚月印已经收入你的"+
			illusion_id+"历程。"]);
	old_progress = copy_value(progress);
	marks[(string)secret["id"]] = 1;
	progress["route_marks"] = marks;
	mapping secret_week = ranking_week_state(progress,time(),1);
	secret_week["route_marks"] = (int)secret_week["route_marks"]+1;
	update_ranking_snapshot(player,progress);
	if(!player->save_with_result()){
		player[ILLUSION_PROGRESS_ROOT+"/"+
			illusion_id] = old_progress;
		return (["ok":0,"message":"月印记录保存失败，请稍后重试。"]);
	}
	if((int)context["ranking_enabled"] &&
	   !persist_ranking_snapshot(player,progress,illusion_id))
		werror("[ILLUSION_RANKING] 月印快照待后续补写: %s\n",
			(string)player->query_name());
	if((int)context["ranking_enabled"])
		invalidate_ranking_cache(illusion_id);
	return (["ok":1,"already":0,"message":(string)secret["message"],
		"route_mark_count":sizeof(marks)]);
}

mapping(string:mixed) discover_route_secret(object player)
{
	return discover_route_secret_internal(player,0);
}

mapping(string:mixed) discover_route_secret_for_test(object player)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]);
	return discover_route_secret_internal(player,1);
}

private mapping(string:mixed) discover_story_event_internal(object player,
	int test_bypass_phase)
{
	mapping context=story_context(player);
	mapping config;
	string illusion_id;
	mapping progress;
	mapping old_progress;
	mapping event;
	mapping chapter;
	mapping step;
	mapping requirements;
	mapping quest_gate;
	string room_path;
	int chapter_index;
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前不能推进幻境故事。"]);
	config=(mapping)context["config"];
	illusion_id=(string)context["illusion_id"];
	progress = player_progress(player,1);
	if(!ensure_current_chapter_counters(player,progress))
		return (["ok":0,
			"message":"当前章节记录不完整，故事残响已安全停止推进。"]);
	room_path = normalized_destination_path(environment(player));
	event = find_story_event("echo",room_path,progress);
	if(!sizeof(event)){
		mapping collected = mappingp(progress["story_events"]) ?
			(mapping)progress["story_events"] : ([]);
		foreach((array)config["story_events"],mapping candidate)
			if((string)candidate["kind"]=="echo" &&
			   (string)candidate["path"]==room_path &&
			   (int)collected[(string)candidate["id"]])
				return (["ok":1,"already":1,
					"message":"这里已经读过的故事残响仍留在你的历程中。"]);
		return (["ok":0,
			"message":"这里的故事残响尚未轮到当前章节，或前一章尚未完成。"]);
	}
	chapter_index=claimed_chapter_count(progress);
	if(chapter_index<0 || chapter_index>=sizeof((array)config["chapters"]))
		return (["ok":0,"message":"当前章节边界异常，本次没有推进剧情。"]) ;
	chapter=(mapping)((array)config["chapters"])[chapter_index];
	step=chapter_step_requirements(progress,chapter_index);
	requirements=chapter_requirements(progress,chapter_index);
	quest_gate=quest_item_gate_status(player,progress,chapter);
	if((string)(chapter["story_event"] || "")!=(string)event["id"] ||
	   (int)player->query_level()<(int)requirements["min_level"] ||
	   (int)progress["chapter_kills"]<(int)step["kills"] ||
	   ((int)quest_gate["required"]>0 && !(int)quest_gate["ready"]))
		return (["ok":0,
			"message":"请先完成本章狩猎与卷末信物，再阅读这段关键剧情。"]) ;
	old_progress = copy_value(progress);
	record_story_activity_day(progress,time());
	if(!record_story_event(progress,event,time()))
		return (["ok":0,"message":"故事残响状态异常，本次没有改变进度。"]);
	update_ranking_snapshot(player,progress);
	if(!player->save_with_result()){
		player[ILLUSION_PROGRESS_ROOT+"/"+
			illusion_id] = old_progress;
		return (["ok":0,"message":"故事进度保存失败，请稍后重试。"]);
	}
	if((int)context["ranking_enabled"] &&
	   !persist_ranking_snapshot(player,progress,illusion_id))
		werror("[ILLUSION_RANKING] 故事残响快照待后续补写: %s\n",
			(string)player->query_name());
	if((int)context["ranking_enabled"])
		invalidate_ranking_cache(illusion_id);
	return (["ok":1,"already":0,"event_id":(string)event["id"],
		"title":(string)event["title"],
		"message":(string)event["message"]]);
}

mapping(string:mixed) discover_story_event(object player)
{
	return discover_story_event_internal(player,0);
}

mapping(string:mixed) discover_story_event_for_test(object player)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]);
	return discover_story_event_internal(player,1);
}

private mapping(string:int) chapter_requirements(mapping progress,int index)
{
	mapping config=config_for_progress(progress);
	int total = sizeof((array)(config["chapters"] || ({})));
	int ordinal = index+1;
	if(total<=0)
		return (["min_level":0,"kills":0,"boss_kills":0,"visits":0]);
	return ([
		"min_level":min((int)config["story_level_cap"],ordinal),
		"kills":max(1,ordinal*750/total),
		"boss_kills":ordinal*10/total,
		"visits":max(1,ordinal*36/total),
	]);
}

/**
 * 九幕循环不是额外数值层，而是把普通狩猎拆成有起、承、转、合的
 * 叙事战斗节奏。它只提供可复现的目标说明和阶段反馈，不改变任何
 * 职业公式、怪物属性、掉落概率或已有章节进度。
 */
private mapping(string:string) chapter_experience_identity(int index)
{
	switch(index%9){
	case 0:
		return (["id":"trace","title":"追迹·循月痕",
			"hint":"从第一处异常追到幕后线索，战斗进度分三幕回响。",
			"opening":"第一道月痕已经显形，真正的猎物仍藏在前方。",
			"middle":"零散足迹连成完整方向，伏线开始指向同一个名字。",
			"closing":"最后一道伪痕被斩断，本章线索已经完整。"]);
	case 1:
		return (["id":"breakout","title":"突围·破月阵",
			"hint":"逐层撕开包围，阶段反馈会标出阵势何时松动。",
			"opening":"外圈阵脚被逼退，包围第一次露出缺口。",
			"middle":"敌阵首尾不能相顾，退路已经从刀光中打开。",
			"closing":"最后一重月阵崩散，前路重新属于活着的人。"]);
	case 2:
		return (["id":"evidence","title":"搜证·辨真伪",
			"hint":"在敌人携带的残片中还原证词，而非只累计数字。",
			"opening":"第一枚残片落地，旧案出现了与名册不同的说法。",
			"middle":"两份证词互相印证，被涂去的真相逐渐复原。",
			"closing":"证据链已经闭合，再无人能用一句传言将它抹去。"]);
	case 3:
		return (["id":"escort","title":"守诺·护同行",
			"hint":"守住同行者留下的承诺，推进时会回响彼此的选择。",
			"opening":"第一轮追兵被挡下，身后的人终于敢继续前行。",
			"middle":"最危险的路段已经穿过，承诺没有被恐惧截断。",
			"closing":"所有同行者抵达约定之处，这一次没有人被留下。"]);
	case 4:
		return (["id":"counter","title":"反猎·照伏影",
			"hint":"识破埋伏并反向追索操纵者，三幕反馈标记局势逆转。",
			"opening":"伏兵提前现身，猎人与猎物的身份开始交换。",
			"middle":"暗处的号令暴露，所有伏线都在向源头收紧。",
			"closing":"最后一名伏影倒下，布阵者再无处隐藏。"]);
	case 5:
		return (["id":"endure","title":"守望·渡险关",
			"hint":"在持续压力下稳住阵脚，每一幕都确认险关状态。",
			"opening":"险关开始震动，但你的立足之处仍未后退半步。",
			"middle":"最猛烈的一轮已经过去，守势终于转为反攻。",
			"closing":"险关重归平静，你守住了故事继续发生的地方。"]);
	case 6:
		return (["id":"choice","title":"抉择·留人证",
			"hint":"清除逼迫众生沉默的阻力，让本章选择留下见证。",
			"opening":"第一个人放下恐惧，愿意说出亲眼见过的事。",
			"middle":"越来越多声音汇成证言，选择不再只由强者书写。",
			"closing":"本章见证已经留下，任何结局都不能假装它未发生。"]);
	case 7:
		return (["id":"reversal","title":"逆局·夺先机",
			"hint":"在卷末前夺回主动权，为信物与首领战清出道路。",
			"opening":"先机从敌人手中被夺回，卷末布局出现裂缝。",
			"middle":"关键通路已经控制，真正的守关者被迫现身。",
			"closing":"卷末战场已经肃清，信物与首领试炼近在眼前。"]);
	default:
		return (["id":"finale","title":"卷末·问长生",
			"hint":"完成狩猎、取得本卷信物，再迎战拥有独立机制的卷主。",
			"opening":"卷末第一声战鼓响起，散落的因果开始回收。",
			"middle":"通往卷主的道路已经过半，信物正在回应你的选择。",
			"closing":"卷末狩猎完成；下一步是信物验证与正式首领战。"]);
	}
}

private string chapter_experience_beat(int index,int done,int required)
{
	mapping identity;
	if(required<=0 || done<=0 || done>required)
		return "";
	identity = chapter_experience_identity(index);
	if(done==1)
		return "§b【"+(string)identity["title"]+"·起势】§r "+
			(string)identity["opening"];
	if(required>2 && done==(required+1)/2)
		return "§p【"+(string)identity["title"]+"·转折】§r "+
			(string)identity["middle"];
	if(done==required)
		return "§y【"+(string)identity["title"]+"·收束】§r "+
			(string)identity["closing"];
	return "";
}

mapping(string:string) query_chapter_experience_for_test(int chapter_number)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" ||
	   chapter_number<1 || chapter_number>81)
		return ([]);
	return chapter_experience_identity(chapter_number-1);
}

private mapping(string:int) chapter_step_requirements(mapping progress,
	int index)
{
	mapping current = chapter_requirements(progress,index);
	mapping previous = index>0 ? chapter_requirements(progress,index-1) :
		(["min_level":0,"kills":0,"boss_kills":0,"visits":0]);
	return ([
		"min_level":(int)current["min_level"],
		"kills":max(0,(int)current["kills"]-(int)previous["kills"]),
		"boss_kills":max(0,(int)current["boss_kills"]-
			(int)previous["boss_kills"]),
		"visits":max(0,(int)current["visits"]-(int)previous["visits"]),
	]);
}

private int reset_current_chapter_counters(mapping progress)
{
	mapping config=config_for_progress(progress);
	array chapters = (array)(config["chapters"] || ({}));
	int index = claimed_chapter_count(progress);
	string expected_id = index<sizeof(chapters) ?
		(string)chapters[index]["id"] : "complete";
	mapping step = index<sizeof(chapters) ?
		chapter_step_requirements(progress,index) :
		(["kills":0,"boss_kills":0,"visits":0]);
	mapping target = index<sizeof(chapters) ?
		chapter_exploration_target(progress,index) : ([]);
	mapping visit_rooms = mappingp(progress["chapter_visit_rooms"]) ?
		(mapping)progress["chapter_visit_rooms"] : ([]);
	int visits_valid = sizeof(visit_rooms)<=(int)step["visits"];
	foreach(indices(visit_rooms),string room_path)
		if(!sizeof(target) || room_path!=(string)target["room"] ||
		   (int)visit_rooms[room_path]!=1)
			visits_valid = 0;
	int valid = (int)progress["chapter_counter_version"]==2 &&
		(string)progress["chapter_counter_id"]==expected_id &&
		intp(progress["chapter_kills"]) &&
		(int)progress["chapter_kills"]>=0 &&
		(int)progress["chapter_kills"]<=(int)step["kills"] &&
		intp(progress["chapter_boss_kills"]) &&
		(int)progress["chapter_boss_kills"]>=0 &&
		(int)progress["chapter_boss_kills"]<=
			(int)step["boss_kills"] &&
		mappingp(progress["chapter_visit_rooms"]) && visits_valid;
	if(valid)
		return 0;
	progress["chapter_counter_version"] = 2;
	progress["chapter_counter_id"] = expected_id;
	progress["chapter_kills"] = 0;
	progress["chapter_boss_kills"] = 0;
	progress["chapter_visit_rooms"] = ([]);
	progress["chapter_mastery_difficulty"] = -1;
	return 1;
}

private int ensure_current_chapter_counters(object player,mapping progress)
{
	mapping old_progress;
	if(!player || !mappingp(progress))
		return 0;
	if(mappingp(progress["claims"]) &&
	   sizeof((mapping)progress["claims"])!=
		claimed_chapter_count(progress)){
		werror("[ILLUSION_REALM] 非连续章节领取记录已失败关闭: %s\n",
			(string)player->query_name());
		return 0;
	}
	old_progress = copy_value(progress);
	if(!reset_current_chapter_counters(progress))
		return 1;
	if(player->save_with_result()){
		safe_append_illusion_log(sprintf(
			"%d|chapter_counter_start|illusion=%s|user=%s|chapter=%s|kills=%d|bosses=%d\n",
			time(),(string)progress["content_id"],
			(string)player->query_name(),
			(string)progress["chapter_counter_id"],
			(int)progress["kills"],(int)progress["boss_kills"]));
		return 1;
	}
	player[ILLUSION_PROGRESS_ROOT+"/"+
		(string)progress["content_id"]] = old_progress;
	return 0;
}

/**
 * S1 is a one-month story realm, not a copy of Eternal-world levelling.
 * Completing each ordered chapter tops the character up to the next story
 * level, capped at the equipment baseline.  Existing monster experience is
 * preserved, so active grinding reduces the top-up rather than being lost.
 */
private mapping(string:int) grant_chapter_story_growth(object player,
	mapping progress,int chapter_number)
{
	mapping config=config_for_progress(progress);
	int before_level;
	int target_level;
	int added_exp;
	int guard;
	int growth_ok = 1;
	mixed old_newbie_auto_disable;
	mixed growth_error;
	if(!player || chapter_number<1)
		return (["ok":0]);
	before_level = (int)player->query_level();
	target_level = min((int)config["story_level_cap"],
		chapter_number+1);
	old_newbie_auto_disable =
		player["/tmp/newbie_tutorial/disable_auto"];
	player["/tmp/newbie_tutorial/disable_auto"] = 1;
	growth_error = catch{
		while((int)player->query_level()<target_level && guard<70){
			int need_exp = (int)player->query_levelUp_need_exp();
			int missing_exp = need_exp-(int)player->current_exp;
			int level_before = (int)player->query_level();
			if(missing_exp<0)
				missing_exp = 0;
			player->exp += missing_exp;
			player->current_exp += missing_exp;
			// 新手教程发奖不属于章节领取事务。这里暂时禁止升级钩子
			// 自动领奖，避免章节最终存档失败时留下无法回滚的额外物品。
			player->query_if_levelup();
			added_exp += missing_exp;
			guard++;
			if((int)player->query_level()<=level_before){
				growth_ok = 0;
				break;
			}
		}
	};
	if(old_newbie_auto_disable)
		player["/tmp/newbie_tutorial/disable_auto"] =
			old_newbie_auto_disable;
	else
		player->m_delete_foruser("/tmp/newbie_tutorial/disable_auto");
	if(growth_error)
		growth_ok = 0;
	return (["ok":growth_ok &&
		(int)player->query_level()>=target_level,
		"before_level":before_level,
		"after_level":(int)player->query_level(),
		"added_exp":added_exp]);
}

// 章节狩猎提示使用与S1挂机路线相同的六档怪物。这里只描述目标，
// 不改变怪物属性、掉落、刷新或自动战斗算法。
private mapping(string:mixed) story_hunt_target_for_level(mapping progress,
	int level)
{
	if(level<10)
		return (["kind":"hunt","name":"逐光月灵","location":"月露原",
			"room":"/gamelib/d/illusion_s1/moon_dew_field.pike",
			"rooms":({
				"/gamelib/d/illusion_s1/moon_dew_field.pike",
				"/gamelib/d/illusion_s1/silver_reed_bank.pike",
				"/gamelib/d/illusion_s1/starlight_slope.pike",
			}),
			"path":"/gamelib/clone/npc/illusion_s1/moon_wisp.pike"]);
	if(level<20)
		return (["kind":"hunt","name":"雾纹月狼","location":"雾竹坳",
			"room":"/gamelib/d/illusion_s1/mist_bamboo_glen.pike",
			"rooms":({
				"/gamelib/d/illusion_s1/mist_bamboo_glen.pike",
				"/gamelib/d/illusion_s1/cloud_pine_hollow.pike",
				"/gamelib/d/illusion_s1/moonshadow_wood.pike",
			}),
			"path":"/gamelib/clone/npc/illusion_s1/fog_wolf.pike"]);
	if(level<30)
		return (["kind":"hunt","name":"镜丝月蛛","location":"镜沙洲",
			"room":"/gamelib/d/illusion_s1/mirror_sandbar.pike",
			"rooms":({
				"/gamelib/d/illusion_s1/mirror_sandbar.pike",
				"/gamelib/d/illusion_s1/glasswater_bank.pike",
				"/gamelib/d/illusion_s1/moonwave_shoal.pike",
			}),
			"path":"/gamelib/clone/npc/illusion_s1/mirror_spider.pike"]);
	if(level<40)
		return (["kind":"hunt","name":"折星石卫","location":"星仪石林",
			"room":"/gamelib/d/illusion_s1/astral_stonewood.pike",
			"rooms":({
				"/gamelib/d/illusion_s1/broken_star_court.pike",
				"/gamelib/d/illusion_s1/astral_stonewood.pike",
				"/gamelib/d/illusion_s1/observatory_outfield.pike",
			}),
			"path":"/gamelib/clone/npc/illusion_s1/ruin_guard.pike"]);
	if(level<50)
		return (["kind":"hunt","name":"古城星魇","location":"古城广场",
			"room":"/gamelib/d/illusion_s1/old_city_square.pike",
			"rooms":({
				"/gamelib/d/illusion_s1/echo_battlement.pike",
				"/gamelib/d/illusion_s1/old_city_square.pike",
				"/gamelib/d/illusion_s1/stardust_lane.pike",
			}),
			"path":"/gamelib/clone/npc/illusion_s1/star_wraith.pike"]);
	return (["kind":"hunt","name":"渊花异兽","location":"深月谷",
		"room":"/gamelib/d/illusion_s1/deepmoon_valley.pike",
		"rooms":({
			"/gamelib/d/illusion_s1/abyss_flower_sea.pike",
			"/gamelib/d/illusion_s1/deepmoon_valley.pike",
			"/gamelib/d/illusion_s1/starfall_garden.pike",
		}),
		"path":"/gamelib/clone/npc/illusion_s1/abyss_beast.pike"]);
}

/**
 * 六档猎场中每档都有三个实际刷怪房。这里仅把章节既有击杀目标编排成
 * 可自动跟随的三段路线，不改怪物属性、击杀数量、经验、掉落或职业公式。
 *
 * 老人物当前章继续使用原有自由猎场；领取下一章时才写入版本开关，避免
 * 部署瞬间让正在挂机的人突然换房。新人物从第一章直接获得完整节奏。
 */
private string hunt_room_location(string room,string fallback)
{
	mapping(string:string) names = ([
		"/gamelib/d/illusion_s1/moon_dew_field.pike":"月露原",
		"/gamelib/d/illusion_s1/silver_reed_bank.pike":"银苇岸",
		"/gamelib/d/illusion_s1/starlight_slope.pike":"星辉坡",
		"/gamelib/d/illusion_s1/mist_bamboo_glen.pike":"雾竹坳",
		"/gamelib/d/illusion_s1/cloud_pine_hollow.pike":"云松谷",
		"/gamelib/d/illusion_s1/moonshadow_wood.pike":"月影林",
		"/gamelib/d/illusion_s1/mirror_sandbar.pike":"镜沙洲",
		"/gamelib/d/illusion_s1/glasswater_bank.pike":"琉水岸",
		"/gamelib/d/illusion_s1/moonwave_shoal.pike":"月潮滩",
		"/gamelib/d/illusion_s1/broken_star_court.pike":"碎星庭",
		"/gamelib/d/illusion_s1/astral_stonewood.pike":"星仪石林",
		"/gamelib/d/illusion_s1/observatory_outfield.pike":"观星外台",
		"/gamelib/d/illusion_s1/echo_battlement.pike":"回音城垣",
		"/gamelib/d/illusion_s1/old_city_square.pike":"古城广场",
		"/gamelib/d/illusion_s1/stardust_lane.pike":"星尘巷",
		"/gamelib/d/illusion_s1/abyss_flower_sea.pike":"渊花海",
		"/gamelib/d/illusion_s1/deepmoon_valley.pike":"深月谷",
		"/gamelib/d/illusion_s1/starfall_garden.pike":"坠星园",
	]);
	return (string)(names[room] || fallback);
}

private mapping(string:mixed) chapter_hunt_target(mapping progress,
	int index,int level)
{
	mapping target = copy_value(story_hunt_target_for_level(progress,level));
	mapping identity = chapter_experience_identity(index);
	mapping step = chapter_step_requirements(progress,index);
	array rooms = (array)(target["rooms"] || ({}));
	int selected;
	int stage;
	int structured;
	int required = max(1,(int)step["kills"]);
	if((int)progress["chapter_route_rhythm_version"]<1 ||
	   sizeof(rooms)!=3)
		return target;
	structured = search(({"trace","evidence","counter"}),
		(string)identity["id"])!=-1;
	if(structured){
		stage = min(2,(int)progress["chapter_kills"]*3/required);
		selected = (stage+index/9)%3;
		// 当前段优先进入指定猎场；另外两房保留为人满溢出节点。
		// 因此单人体验会真实换场，多人同时推进时仍有54人容量，
		// 不会为了叙事节奏把五十名挂机玩家挤回一个房间。
		target["rooms"] = ({rooms[selected],rooms[(selected+1)%3],
			rooms[(selected+2)%3]});
		target["rhythm_mode"] = "trail";
		target["rhythm_stage"] = stage+1;
		target["rhythm_stages"] = 3;
	}
	else{
		selected = (index+index/9)%3;
		target["rhythm_mode"] = "free";
		target["rhythm_stage"] = 1;
		target["rhythm_stages"] = 1;
	}
	target["room"] = rooms[selected];
	target["location"] = hunt_room_location(rooms[selected],
		(string)target["location"]);
	return target;
}

private mapping(string:mixed) quest_gate_hunt_target(mapping gate)
{
	return ([
		"kind":"hunt","name":(string)gate["source_name"],
		"location":(string)gate["source_location"],
		"room":(string)gate["source_room"],
		"rooms":copy_value((array)(gate["source_rooms"] || ({}))),
		"path":(string)gate["source_path"],
		"rhythm_mode":"gate","rhythm_stage":1,"rhythm_stages":1,
	]);
}

/**
 * 当前章节真实狩猎路线。普通持续挂机和“仅完成本章”共用目标房间与
 * 怪物等级；后者只额外携带停止标记，不能维护第二套寻路规则。
 */
mapping(string:mixed) query_current_chapter_autofight_route(object player)
{
	mapping context;
	mapping progress;
	mapping config;
	mapping chapter;
	mapping step;
	mapping hunt;
	mapping quest_gate;
	array chapters;
	array(string) paths = ({});
	string room_prefix = "/gamelib/d/";
	int index;
	int target_level;
	if(!player)
		return ([]);
	context = story_context(player);
	if(!sizeof(context) || (string)context["illusion_id"]!="S1")
		return ([]);
	config = (mapping)context["config"];
	if((string)context["mode"]=="echo" &&
	   !is_content_room_path(config,
		normalized_destination_path(environment(player))))
		return ([]);
	progress = player_progress(player,1);
	if(!ensure_current_chapter_counters(player,progress))
		return ([]);
	chapters = (array)(config["chapters"] || ({}));
	index = claimed_chapter_count(progress);
	if(index<0 || index>=sizeof(chapters))
		return ([]);
	chapter = (mapping)chapters[index];
	step = chapter_step_requirements(progress,index);
	quest_gate = quest_item_gate_status(player,progress,chapter);
	if(((int)step["kills"]<=0 ||
	    (int)progress["chapter_kills"]>=(int)step["kills"]) &&
	   ((int)quest_gate["required"]<=0 || (int)quest_gate["ready"]))
		return ([]);
	if((int)quest_gate["required"]>0 && !(int)quest_gate["ready"] &&
	   (int)progress["chapter_kills"]>=(int)step["kills"])
		hunt = quest_gate_hunt_target(quest_gate);
	else
		hunt = chapter_hunt_target(progress,index,(int)step["min_level"]);
	foreach((array)(hunt["rooms"] || ({})),string room){
		string path = room;
		if(!has_prefix(path,room_prefix) || !has_suffix(path,".pike"))
			return ([]);
		path = path[sizeof(room_prefix)..sizeof(path)-6];
		paths += ({path});
	}
	if(!sizeof(paths))
		return ([]);
	switch((string)hunt["path"]){
	case "/gamelib/clone/npc/illusion_s1/moon_wisp.pike":
		target_level = 1;
		break;
	case "/gamelib/clone/npc/illusion_s1/fog_wolf.pike":
		target_level = 10;
		break;
	case "/gamelib/clone/npc/illusion_s1/mirror_spider.pike":
		target_level = 20;
		break;
	case "/gamelib/clone/npc/illusion_s1/ruin_guard.pike":
		target_level = 30;
		break;
	case "/gamelib/clone/npc/illusion_s1/star_wraith.pike":
		target_level = 40;
		break;
	case "/gamelib/clone/npc/illusion_s1/abyss_beast.pike":
		// 深渊三房刷动态同级怪，章节狩猎窗口同样要跟人物等级走。
		target_level = 50;
		break;
	default:
		return ([]);
	}
	return ([
		"max":69,
		"level":target_level,
		"name":"第"+(string)(index+1)+"章·"+
			((int)quest_gate["required"]>0 && !(int)quest_gate["ready"] ?
			 "收集"+(string)quest_gate["name"] : (string)hunt["name"]),
		"path":paths[0],
		"paths":paths,
		"capacity":18,
		"total_capacity":sizeof(paths)*18,
		"target_min":target_level,
		"target_max":target_level==50 ? 999 : min(999,target_level+2),
		"disable_overflow":1,
		"illusion_id":"S1",
		"chapter_id":(string)chapter["id"],
		"chapter_target":1,
		"quest_item_target":(int)quest_gate["required"]>0 &&
			!(int)quest_gate["ready"],
	]);
}

// 三十六处探索门槛必须给玩家一个真正尚未到过的下一站，而不是
// 反复把人送回同一猎场。数组顺序也是剧情推荐游览顺序。
private array(mapping(string:string)) story_exploration_targets()
{
	return ({
		(["location":"S1月门营地","room":"/gamelib/d/illusion_s1/moon_gate.pike"]),
		(["location":"月露原","room":"/gamelib/d/illusion_s1/moon_dew_field.pike"]),
		(["location":"银苇岸","room":"/gamelib/d/illusion_s1/silver_reed_bank.pike"]),
		(["location":"星辉坡","room":"/gamelib/d/illusion_s1/starlight_slope.pike"]),
		(["location":"银痕小径","room":"/gamelib/d/illusion_s1/silver_path.pike"]),
		(["location":"雾语林","room":"/gamelib/d/illusion_s1/fog_forest.pike"]),
		(["location":"雾竹坳","room":"/gamelib/d/illusion_s1/mist_bamboo_glen.pike"]),
		(["location":"云松谷","room":"/gamelib/d/illusion_s1/cloud_pine_hollow.pike"]),
		(["location":"月影林","room":"/gamelib/d/illusion_s1/moonshadow_wood.pike"]),
		(["location":"雾林半药营","room":"/gamelib/d/illusion_s1/fog_oath_camp.pike"]),
		(["location":"倒月镜湖","room":"/gamelib/d/illusion_s1/mirror_lake.pike"]),
		(["location":"镜沙洲","room":"/gamelib/d/illusion_s1/mirror_sandbar.pike"]),
		(["location":"琉水岸","room":"/gamelib/d/illusion_s1/glasswater_bank.pike"]),
		(["location":"月潮滩","room":"/gamelib/d/illusion_s1/moonwave_shoal.pike"]),
		(["location":"折星台","room":"/gamelib/d/illusion_s1/broken_observatory.pike"]),
		(["location":"碎星庭","room":"/gamelib/d/illusion_s1/broken_star_court.pike"]),
		(["location":"星仪石林","room":"/gamelib/d/illusion_s1/astral_stonewood.pike"]),
		(["location":"观星外台","room":"/gamelib/d/illusion_s1/observatory_outfield.pike"]),
		(["location":"回声古城","room":"/gamelib/d/illusion_s1/echo_ruins.pike"]),
		(["location":"回音城垣","room":"/gamelib/d/illusion_s1/echo_battlement.pike"]),
		(["location":"古城广场","room":"/gamelib/d/illusion_s1/old_city_square.pike"]),
		(["location":"星尘巷","room":"/gamelib/d/illusion_s1/stardust_lane.pike"]),
		(["location":"渊花庭","room":"/gamelib/d/illusion_s1/abyss_garden.pike"]),
		(["location":"渊花海","room":"/gamelib/d/illusion_s1/abyss_flower_sea.pike"]),
		(["location":"深月谷","room":"/gamelib/d/illusion_s1/deepmoon_valley.pike"]),
		(["location":"坠星园","room":"/gamelib/d/illusion_s1/starfall_garden.pike"]),
		(["location":"南瞻尘城","room":"/gamelib/d/illusion_s1/nanzhan_mortal_city.pike"]),
		(["location":"南瞻生死祠","room":"/gamelib/d/illusion_s1/nanzhan_life_death_temple.pike"]),
		(["location":"西牛万法集","room":"/gamelib/d/illusion_s1/xiniu_scripture_market.pike"]),
		(["location":"西牛空经殿","room":"/gamelib/d/illusion_s1/xiniu_empty_temple.pike"]),
		(["location":"北俱不老荒原","room":"/gamelib/d/illusion_s1/beiju_longlife_waste.pike"]),
		(["location":"北俱断誓坡","room":"/gamelib/d/illusion_s1/beiju_broken_oath.pike"]),
		(["location":"北俱冻龄宫","room":"/gamelib/d/illusion_s1/beiju_frozen_palace.pike"]),
		(["location":"冻宫雪审殿","room":"/gamelib/d/illusion_s1/frozen_judgment_hall.pike"]),
		(["location":"东胜朝生港","room":"/gamelib/d/illusion_s1/dongsheng_morning_port.pike"]),
		(["location":"东胜扶桑坛","room":"/gamelib/d/illusion_s1/dongsheng_fusang_altar.pike"]),
	});
}

private mapping(string:string) chapter_exploration_target(mapping progress,
	int index)
{
	mapping step = chapter_step_requirements(progress,index);
	array(mapping(string:string)) targets = story_exploration_targets();
	int ordinal;
	if((int)step["visits"]<=0 || !sizeof(targets))
		return ([]);
	ordinal = (int)chapter_requirements(progress,index)["visits"]-1;
	if(ordinal<0 || ordinal>=sizeof(targets))
		return ([]);
	return targets[ordinal];
}

private mapping(string:int) current_chapter_kill_credit(object player,
	mapping progress,string npc_path,string room_path)
{
	mapping config=config_for_progress(progress);
	array chapters = (array)(config["chapters"] || ({}));
	int index = claimed_chapter_count(progress);
	mapping credit = (["kill":0,"boss":0,"story":0]);
	mapping chapter;
	mapping step;
	mapping events;
	mapping story_event = ([]);
	mapping hunt;
	mapping quest_gate;
	if(index<0 || index>=sizeof(chapters))
		return credit;
	chapter = (mapping)chapters[index];
	step = chapter_step_requirements(progress,index);
	events = mappingp(progress["story_events"]) ?
		(mapping)progress["story_events"] : ([]);
	if((string)(chapter["story_event"] || "")!="" &&
	   !(int)events[(string)chapter["story_event"]])
		foreach((array)config["story_events"],mapping candidate)
			if((string)candidate["id"]==(string)chapter["story_event"]){
				story_event = candidate;
				break;
			}
	hunt = chapter_hunt_target(progress,index,(int)step["min_level"]);
	// 每章先完成自己的狩猎铺垫。卷末信物和剧情首领不能让限章挂机
	// 把“刷信物”误当成“本章击杀”，也不能在高潮后再赶回普通猎场。
	if((int)progress["chapter_kills"]<(int)step["kills"]){
		if(npc_path==(string)hunt["path"] &&
		   arrayp(hunt["rooms"]) &&
		   search((array)hunt["rooms"],room_path)!=-1)
			credit["kill"] = 1;
		return credit;
	}
	quest_gate = quest_item_gate_status(player,progress,chapter);
	if((int)quest_gate["required"]>0 && !(int)quest_gate["ready"])
		return credit;
	// 服务端记账边界也验证顺序：即使玩家绕过任务页直达正确房间，
	// 未完成狩猎/信物时击杀卷末首领也不能提前写剧情或章节Boss进度。
	if(sizeof(story_event)){
		if((string)story_event["kind"]=="boss" &&
		   npc_path==(string)story_event["path"] &&
		   room_path==(string)story_event["room"]){
			credit["story"] = 1;
			// 剧情首领即使落在累计 Boss 曲线的零增量章，也必须能
			// 推进剧情；只有本章确实要求新增 Boss 时才增加章节计数。
			if((int)step["boss_kills"]>0)
				credit["boss"] = 1;
		}
		return credit;
	}
	if((int)progress["chapter_boss_kills"]<(int)step["boss_kills"] &&
	   npc_path=="/gamelib/clone/npc/illusion_s1/star_keeper.pike" &&
	   room_path=="/gamelib/d/illusion_s1/star_bridge.pike")
		credit["boss"] = 1;
	return credit;
}

private int current_chapter_visit_credit(object player,mapping progress,
	string room_path)
{
	mapping config=config_for_progress(progress);
	array chapters = (array)(config["chapters"] || ({}));
	int index = claimed_chapter_count(progress);
	mapping chapter;
	mapping step;
	mapping events;
	mapping target;
	mapping quest_gate;
	if(index<0 || index>=sizeof(chapters))
		return 0;
	chapter = (mapping)chapters[index];
	step = chapter_step_requirements(progress,index);
	if((int)step["visits"]<=0 ||
	   (int)progress["chapter_kills"]<(int)step["kills"] ||
	   (int)progress["chapter_boss_kills"]<(int)step["boss_kills"])
		return 0;
	if((string)(chapter["story_event"] || "")!=""){
		events = mappingp(progress["story_events"]) ?
			(mapping)progress["story_events"] : ([]);
		if(!(int)events[(string)chapter["story_event"]])
			return 0;
	}
	quest_gate = quest_item_gate_status(player,progress,chapter);
	if((int)quest_gate["required"]>0 && !(int)quest_gate["ready"])
		return 0;
	target = chapter_exploration_target(progress,index);
	return sizeof(target) && room_path==(string)target["room"];
}

private string story_event_target_room(mapping event)
{
	if((string)(event["kind"] || "")=="echo")
		return (string)(event["path"] || "");
	return (string)(event["room"] || "");
}

private string npc_command_name_from_path(string path)
{
	array(string) path_parts = path/"/";
	if(!sizeof(path_parts))
		return "";
	// object_name() strips only a clone suffix. Historical NPC ids therefore
	// keep the .pike suffix from basename(file_name(ob)).
	return path_parts[-1];
}

private mapping(string:mixed) chapter_next_target(mapping progress,
	mapping chapter,mapping requirements,mapping story_definition,
	int story_ready,int player_level,int chapter_index)
{
	mapping target;
	mapping quest_gate = mappingp(progress["chapter_quest_item_gate"]) ?
		(mapping)progress["chapter_quest_item_gate"] : ([]);
	// 普通狩猎是本章铺垫；先完成它，限章挂机才能以 chapter_kills
	// 精准停止。随后准备卷末信物，最后才进入剧情首领高潮。
	if((int)progress["kills"]<(int)requirements["kills"] ||
	   player_level<(int)requirements["min_level"])
		return chapter_hunt_target(progress,chapter_index,
			(int)requirements["min_level"]);
	if((int)quest_gate["required"]>0 && !(int)quest_gate["ready"]){
		target = quest_gate_hunt_target(quest_gate);
		target["combat_name"] = "";
		return target;
	}
	if(sizeof(story_definition) && !story_ready){
		string event_room = story_event_target_room(story_definition);
		target = ([
			"kind":(string)story_definition["kind"]=="boss" ?
				"story_boss" : "story_echo",
			"name":(string)story_definition["kind"]=="boss" ?
				(string)story_definition["monster"] :
				(string)story_definition["title"],
			"location":(string)story_definition["location"],
			"room":event_room,
			"combat_name":(string)story_definition["kind"]=="boss" ?
				npc_command_name_from_path(
					(string)story_definition["path"]) : "",
		]);
		return target;
	}
	if((int)progress["boss_kills"]<(int)requirements["boss_kills"])
		return (["kind":"boss","name":"断桥镇星使","location":"断星桥",
			"room":"/gamelib/d/illusion_s1/star_bridge.pike",
			"combat_name":"star_keeper.pike"]);
	if(progress_visit_count(progress)<(int)requirements["visits"]){
		mapping candidate = chapter_exploration_target(progress,chapter_index);
		if(sizeof(candidate))
			return (["kind":"explore","name":"探索"+
				(string)candidate["location"],
				"location":(string)candidate["location"],
				"room":(string)candidate["room"]]);
	}
	if((int)chapter["path_required"] && (string)progress["path"]=="")
		return (["kind":"choice","name":"完成三途择印",
			"location":"折星台","room":""]);
	if((int)chapter["route_final_required"] && !route_final_ready(progress))
		return (["kind":"route","name":"完成本期三途终章",
			"location":"按所选命途推进","room":""]);
	return (["kind":"ready","name":"本章目标已经完成",
		"location":"","room":""]);
}

private int chapter_story_event_ready(mapping progress,mapping chapter)
{
	string event_id = (string)(chapter["story_event"] || "");
	mapping events = mappingp(progress["story_events"]) ?
		(mapping)progress["story_events"] : ([]);
	return event_id=="" || (int)events[event_id]>0;
}

private mapping chapter_status(object player,mapping progress,
	mapping chapter,int index)
{
	mapping config=config_for_progress(progress);
	mapping claims = mappingp(progress["claims"]) ? progress["claims"] : ([]);
	mapping requirements = chapter_requirements(progress,index);
	mapping step_requirements = chapter_step_requirements(progress,index);
	mapping story_definition = ([]);
	mapping experience = chapter_experience_identity(index);
	mapping hunt_target;
	mapping target;
	mapping task_progress = copy_value(progress);
	mapping chapter_visit_rooms = mappingp(progress["chapter_visit_rooms"]) ?
		(mapping)progress["chapter_visit_rooms"] : ([]);
	mapping quest_gate = quest_item_gate_status(player,progress,chapter);
	int current_index = claimed_chapter_count(progress);
	int is_current = index==current_index;
	int claimed = (int)claims[(string)chapter["id"]]>0;
	int chapter_kills_done = claimed ? (int)step_requirements["kills"] :
		(is_current ? min((int)progress["chapter_kills"],
			(int)step_requirements["kills"]) : 0);
	int chapter_boss_kills_done = claimed ?
		(int)step_requirements["boss_kills"] :
		(is_current ? min((int)progress["chapter_boss_kills"],
			(int)step_requirements["boss_kills"]) : 0);
	int chapter_visits_done = claimed ? (int)step_requirements["visits"] :
		(is_current ? min(sizeof(chapter_visit_rooms),
			(int)step_requirements["visits"]) : 0);
	int previous_claimed = index==0 ||
		(int)claims[(string)((array)config["chapters"])[index-1]["id"]];
	int story_ready = chapter_story_event_ready(progress,chapter);
	if((string)(chapter["story_event"] || "")!="")
		foreach((array)config["story_events"],mapping candidate)
			if((string)candidate["id"]==
			   (string)chapter["story_event"]){
				story_definition = candidate;
				break;
			}
	task_progress["kills"] = chapter_kills_done;
	task_progress["boss_kills"] = chapter_boss_kills_done;
	task_progress["visited"] = chapter_visit_rooms;
	task_progress["chapter_quest_item_gate"] = quest_gate;
	int base_ready = is_current &&
		(int)player->query_level()>=(int)requirements["min_level"] &&
		chapter_kills_done>=(int)step_requirements["kills"] &&
		chapter_boss_kills_done>=(int)step_requirements["boss_kills"] &&
		chapter_visits_done>=(int)step_requirements["visits"] &&
		story_ready && (int)quest_gate["ready"];
	if((int)chapter["path_required"] && (string)progress["path"]=="")
		base_ready = 0;
	if((int)chapter["route_final_required"] &&
	   !route_final_ready(progress))
		base_ready = 0;
	target = chapter_next_target(task_progress,chapter,step_requirements,
		story_definition,story_ready,(int)player->query_level(),index);
	hunt_target = chapter_hunt_target(progress,index,
		(int)requirements["min_level"]);
	if((string)target["kind"]=="hunt" &&
	   (int)quest_gate["required"]>0 && !(int)quest_gate["ready"] &&
	   chapter_kills_done>=(int)step_requirements["kills"])
		hunt_target = target;
	return ([
		"id":(string)chapter["id"],
		"volume_title":(string)chapter["volume_title"],
		"volume_number":(int)chapter["volume_number"],
		"title":(string)chapter["title"],
		"experience_id":(string)experience["id"],
		"experience_title":(string)experience["title"],
		"experience_hint":(string)experience["hint"],
		"description":(string)chapter["intro"],
		"intro":(string)chapter["intro"],
		"outro":(string)chapter["outro"],
		"atlas":(string)chapter["atlas"],
		"image_cell":(int)chapter["image_cell"],
		"image":(string)chapter["image"],
		"active_days":(int)chapter["active_days"],
		"min_level":(int)requirements["min_level"],
		"kills":(int)requirements["kills"],
		"boss_kills":(int)requirements["boss_kills"],
		"visits":(int)requirements["visits"],
		"chapter_kills":(int)step_requirements["kills"],
		"chapter_kills_done":chapter_kills_done,
		"chapter_boss_kills":(int)step_requirements["boss_kills"],
		"chapter_boss_kills_done":chapter_boss_kills_done,
		"chapter_visits":(int)step_requirements["visits"],
		"chapter_visits_done":chapter_visits_done,
		"hunt_name":(string)hunt_target["name"],
		"hunt_location":(string)hunt_target["location"],
		"hunt_room":(string)hunt_target["room"],
		"hunt_rooms":arrayp(hunt_target["rooms"]) ?
			copy_value((array)hunt_target["rooms"]) : ({}),
		"hunt_rhythm_mode":(string)(hunt_target["rhythm_mode"] || "legacy"),
		"hunt_rhythm_stage":(int)(hunt_target["rhythm_stage"] || 1),
		"hunt_rhythm_stages":(int)(hunt_target["rhythm_stages"] || 1),
		"boss_name":sizeof(story_definition) &&
			(string)story_definition["kind"]=="boss" ?
			(string)story_definition["monster"] : "断桥镇星使",
		"boss_location":sizeof(story_definition) &&
			(string)story_definition["kind"]=="boss" ?
			(string)story_definition["location"] : "断星桥",
		"story_event":(string)(chapter["story_event"] || ""),
		"story_event_title":(string)(story_definition["title"] || ""),
		"story_event_location":(string)(story_definition["location"] || ""),
		"story_event_kind":(string)(story_definition["kind"] || ""),
		"story_ready":story_ready,
		"quest_item_id":(string)(quest_gate["id"] || ""),
		"quest_item_name":(string)(quest_gate["name"] || ""),
		"quest_item_count":(int)quest_gate["count"],
		"quest_item_required":(int)quest_gate["required"],
		"quest_item_ready":(int)quest_gate["ready"],
		"quest_item_substitute_ready":(int)quest_gate["substitute_ready"],
		"quest_item_drop_basis_points":
			(int)quest_gate["drop_basis_points"],
		"quest_item_drop_rate_text":
			(string)(quest_gate["drop_rate_text"] || ""),
		"quest_item_pity":(int)quest_gate["pity"],
		"quest_item_pity_kills":(int)quest_gate["pity_kills"],
		"quest_item_source_name":(string)(quest_gate["source_name"] || ""),
		"quest_item_source_location":
			(string)(quest_gate["source_location"] || ""),
		"target_kind":(string)target["kind"],
		"target_name":(string)target["name"],
		"target_location":(string)target["location"],
		"target_room":(string)target["room"],
		"target_rooms":arrayp(target["rooms"]) ?
			copy_value((array)target["rooms"]) : ({}),
		"target_combat_name":(string)(target["combat_name"] || ""),
		"reward_count":(int)chapter["reward_count"],
		"claimed":(int)claims[(string)chapter["id"]],
		"ready":base_ready && previous_claimed,
	]);
}

private mapping(string:mixed) chapter_progress_guide(object player,
	mapping progress)
{
	mapping config=config_for_progress(progress);
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	array chapters = (array)(config["chapters"] || ({}));
	int index = claimed_chapter_count(progress);
	mapping chapter;
	string kind;
	if(index<0 || index>=sizeof(chapters))
		return (["kind":"","message":""]);
	chapter = chapter_status(player,progress,(mapping)chapters[index],index);
	kind = (string)chapter["target_kind"];
	if((int)chapter["ready"] || kind=="ready")
		return (["kind":"ready","message":"§y【第"+(string)(index+1)+
			"章目标完成】§r\n[立即领取第"+(string)(index+1)+
			"章并进入下一章:illusion_realm claim "+
			(string)(index+1)+"]\n"]);
	if(kind=="hunt" && (int)chapter["quest_item_required"]>0 &&
	   !(int)chapter["quest_item_ready"])
		return (["kind":kind,"message":"§p【剧情道具卡点】§r 击败"+
			(string)chapter["quest_item_source_name"]+"收集【"+
			(string)chapter["quest_item_name"]+"】 "+
			(string)(int)chapter["quest_item_count"]+"/"+
			(string)(int)chapter["quest_item_required"]+"；掉率 "+
			(string)chapter["quest_item_drop_rate_text"]+"，保底 "+
			(string)(int)chapter["quest_item_pity"]+"/"+
			(string)(int)chapter["quest_item_pity_kills"]+"。\n"]);
	if(kind=="hunt")
		return (["kind":kind,"message":"§c【第"+(string)(index+1)+
			"章狩猎】§r "+(string)chapter["hunt_name"]+" "+
			(string)(int)chapter["chapter_kills_done"]+"/"+
			(string)(int)chapter["chapter_kills"]+"（还差"+
			(string)max(0,(int)chapter["chapter_kills"]-
				(int)chapter["chapter_kills_done"])+"只）"+
			((string)chapter["hunt_rhythm_mode"]=="trail" ?
			 "　当前追迹 "+(string)(int)chapter["hunt_rhythm_stage"]+"/"+
			 (string)(int)chapter["hunt_rhythm_stages"] : "")+"\n"]);
	return (["kind":kind,"message":"§y【战斗步骤完成】§r 下一步："+
		(string)chapter["target_name"]+
		((string)chapter["target_location"]!="" ? "　地点："+
			(string)chapter["target_location"] : "")+
		"\n[▶ 下一步：继续本章:illusion_realm next]\n"]);
}

private int story_all_chapters_claimed(mapping progress)
{
	mapping config=config_for_progress(progress);
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	array chapters = (array)(config["chapters"] || ({}));
	return sizeof(chapters)==81 && sizeof(claims)==sizeof(chapters) &&
		claimed_chapter_count(progress)==sizeof(chapters);
}

/** 分数奖励均为展示称号，不改变战斗或经济数值。 */
private string story_quiz_title(int score)
{
	if(score>=10)
		return "人间见证者";
	if(score>=9)
		return "月下解卷";
	if(score>=7)
		return "四洲知卷";
	if(score>=5)
		return "记得来路";
	return "初闻长生";
}

string query_story_quiz_title_for_test(int score)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || score<0 || score>10)
		return "";
	return story_quiz_title(score);
}

private int valid_story_quiz_progress(mixed raw)
{
	mapping state;
	array choices;
	string status;
	if(!mappingp(raw))
		return 0;
	state = (mapping)raw;
	if(sizeof(state)>16 || (int)state["version"]!=1 ||
	   !intp(state["attempts"]) || (int)state["attempts"]<1 ||
	   (int)state["attempts"]>100000 ||
	   !intp(state["current"]) || (int)state["current"]<0 ||
	   (int)state["current"]>10 ||
	   !intp(state["score"]) || (int)state["score"]<0 ||
	   (int)state["score"]>10 ||
	   !intp(state["last_score"]) || (int)state["last_score"]<0 ||
	   (int)state["last_score"]>10 ||
	   !intp(state["best_score"]) || (int)state["best_score"]<0 ||
	   (int)state["best_score"]>10 ||
	   !intp(state["started_at"]) || (int)state["started_at"]<1 ||
	   !intp(state["completed_at"]) || (int)state["completed_at"]<0 ||
	   !stringp(state["status"]) || !arrayp(state["choices"]))
		return 0;
	status = (string)state["status"];
	choices = (array)state["choices"];
	if(search(({"active","completed"}),status)==-1 ||
	   sizeof(choices)!=(int)state["current"] || sizeof(choices)>10 ||
	   (int)state["score"]>sizeof(choices) ||
	   (status=="active" && (int)state["current"]>=10) ||
	   (status=="completed" && (int)state["current"]!=10) ||
	   (status=="completed" &&
	    (int)state["best_score"]<(int)state["last_score"]) ||
	   (status=="completed" && (int)state["completed_at"]<1) ||
	   (status=="active" && (int)state["completed_at"]!=0))
		return 0;
	foreach(choices,mixed choice)
		if(!intp(choice) || (int)choice<1 || (int)choice>4)
			return 0;
	return 1;
}

private mapping(string:mixed) public_story_quiz_question(mapping progress,
	int index)
{
	mapping config=config_for_progress(progress);
	array quiz = (array)(config["story_quiz"] || ({}));
	mapping question;
	if(index<0 || index>=sizeof(quiz))
		return ([]);
	question = (mapping)quiz[index];
	return ([
		"id":(string)question["id"],
		"number":index+1,
		"total":sizeof(quiz),
		"question":(string)question["question"],
		"options":copy_value((array)question["options"]),
	]);
}

private mapping(string:mixed) story_quiz_public_view(mapping progress)
{
	mapping config=config_for_progress(progress);
	mapping result = ([
		"ok":1,"unlocked":story_all_chapters_claimed(progress),
		"intro":(string)config["quiz_intro"],
		"status":"locked","attempts":0,"best_score":0,
		"best_title":"","last_score":0,"question":([]),
		"perfect":0,"epilogue":"","route_epilogue":([]),
	]);
	mixed raw = progress["story_quiz"];
	if(!(int)result["unlocked"]){
		result["message"] = "完成九卷八十一章后，长生十问才会开启。";
		return result;
	}
	result["status"] = "ready";
	result["message"] = "长生十问已经开启，可随时开始或重新挑战。";
	mapping route_epilogues = mappingp(config["route_epilogues"]) ?
		(mapping)config["route_epilogues"] : ([]);
	mapping route_epilogue = mappingp(route_epilogues[
		(string)progress["path"]]) ?
		(mapping)route_epilogues[(string)progress["path"]] : ([]);
	if(sizeof(route_epilogue))
		result["route_epilogue"] = copy_value(route_epilogue);
	if(!raw)
		return result;
	if(!valid_story_quiz_progress(raw))
		return (["ok":0,"unlocked":1,"message":
			"长生十问存档校验失败，已停止写入以保护原档案。"]);
	mapping state = (mapping)raw;
	result["status"] = (string)state["status"];
	result["attempts"] = (int)state["attempts"];
	result["best_score"] = (int)state["best_score"];
	result["last_score"] = (int)state["last_score"];
	if((string)state["status"]=="completed" || (int)state["attempts"]>1)
		result["best_title"] = story_quiz_title((int)state["best_score"]);
	if((string)state["status"]=="active"){
		result["question"] = public_story_quiz_question(progress,
			(int)state["current"]);
		result["current_score"] = (int)state["score"];
		result["message"] = "长生十问正在作答。";
	}
	else
		result["message"] = "本轮十问已经完成，可重新挑战刷新最高分。";
	if((int)state["best_score"]==10){
		result["perfect"] = 1;
		result["epilogue"] = (string)config["quiz_epilogue"];
	}
	return result;
}

mapping(string:mixed) query_story_quiz(object player)
{
	if(!player || !sizeof(story_context(player)))
		return (["ok":0,"message":"当前没有可进行的幻境故事。"]);
	return story_quiz_public_view(player_progress(player,1));
}

private mapping(string:mixed) start_story_quiz_internal(object player,
	int test_bypass_phase)
{
	mapping progress;
	mapping old_progress;
	mapping old_state = ([]);
	mapping context=story_context(player);
	int attempts;
	int best_score;
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前不能开始长生十问。"]);
	progress = player_progress(player,1);
	if(!story_all_chapters_claimed(progress))
		return (["ok":0,"message":"请先完成九卷八十一章。"]);
	if(progress["story_quiz"]){
		if(!valid_story_quiz_progress(progress["story_quiz"]))
			return (["ok":0,"message":
				"长生十问存档校验失败，已停止写入以保护原档案。"]);
		old_state = (mapping)progress["story_quiz"];
		if((string)old_state["status"]=="active"){
			mapping active = story_quiz_public_view(progress);
			active["already"] = 1;
			active["message"] = "长生十问已经开始，已恢复到当前题目。";
			return active;
		}
		attempts = (int)old_state["attempts"];
		best_score = (int)old_state["best_score"];
	}
	old_progress = copy_value(progress);
	progress["story_quiz"] = ([
		"version":1,"status":"active","attempts":attempts+1,
		"current":0,"score":0,
		"last_score":sizeof(old_state) ? (int)old_state["last_score"] : 0,
		"best_score":best_score,"choices":({}),
		"started_at":time(),"completed_at":0,
	]);
	if(!save_story_quiz_player(player)){
		restore_mapping_snapshot(progress,old_progress);
		return (["ok":0,"message":"人物存档失败，本次十问未开始。"]);
	}
	safe_append_illusion_log(sprintf(
		"%d|story_quiz_start|illusion=%s|user=%s|attempt=%d\n",
		time(),(string)progress["content_id"],
		(string)player->query_name(),attempts+1));
	mapping result = story_quiz_public_view(progress);
	result["message"] = "长生十问开始。每题提交后立即锁定，本轮不能返回改答。";
	return result;
}

mapping(string:mixed) start_story_quiz(object player)
{
	return start_story_quiz_internal(player,0);
}

mapping(string:mixed) start_story_quiz_for_test(object player)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]);
	return start_story_quiz_internal(player,1);
}

private mapping(string:mixed) answer_story_quiz_internal(object player,
	int question_number,int choice,int test_bypass_phase)
{
	mapping progress;
	mapping old_progress;
	mapping state;
	mapping question;
	mapping result;
	mapping context=story_context(player);
	int correct;
	int completed;
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前不能提交长生十问。"]);
	progress = player_progress(player,1);
	if(!story_all_chapters_claimed(progress) ||
	   !valid_story_quiz_progress(progress["story_quiz"]))
		return (["ok":0,"message":"长生十问尚未开始或存档不可验证。"]);
	state = (mapping)progress["story_quiz"];
	if((string)state["status"]!="active")
		return (["ok":0,"message":"本轮十问已经结束，请重新开始。"]);
	if(question_number!=(int)state["current"]+1)
		return (["ok":0,"message":
			"题号已过期或重复提交，当前进度未改变。"]);
	if(choice<1 || choice>4)
		return (["ok":0,"message":"请选择一至四中的一个答案。"]);
	question = (mapping)((array)config_for_progress(progress)["story_quiz"])
		[question_number-1];
	correct = choice==(int)question["answer"];
	old_progress = copy_value(progress);
	state["choices"] = (array)state["choices"]+({choice});
	state["current"] = (int)state["current"]+1;
	if(correct)
		state["score"] = (int)state["score"]+1;
	if((int)state["current"]==10){
		completed = 1;
		state["status"] = "completed";
		state["last_score"] = (int)state["score"];
		state["best_score"] = max((int)state["best_score"],
			(int)state["score"]);
		state["completed_at"] = time();
	}
	if(!save_story_quiz_player(player)){
		restore_mapping_snapshot(progress,old_progress);
		return (["ok":0,"message":"人物存档失败，本题未计入，可重新提交。"]);
	}
	safe_append_illusion_log(sprintf(
		"%d|story_quiz_answer|illusion=%s|user=%s|question=%d|choice=%d|correct=%d|score=%d|completed=%d\n",
		time(),(string)progress["content_id"],
		(string)player->query_name(),question_number,choice,correct,
		(int)state["score"],completed));
	result = story_quiz_public_view(progress);
	result["correct"] = correct;
	result["explanation"] = (string)question["explanation"];
	result["answered_number"] = question_number;
	result["message"] = correct ? "回答正确。" : "这一题没有答对。";
	return result;
}

mapping(string:mixed) answer_story_quiz(object player,int question_number,
	int choice)
{
	return answer_story_quiz_internal(player,question_number,choice,0);
}

mapping(string:mixed) answer_story_quiz_for_test(object player,
	int question_number,int choice)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]);
	return answer_story_quiz_internal(player,question_number,choice,1);
}

mapping(string:mixed) query_player_progress(object player)
{
	mapping context=story_context(player);
	mapping config;
	mapping progress;
	mapping quiz_view;
	array chapter_rows = ({});
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前没有可进行的幻境故事。"]);
	config=(mapping)context["config"];
	progress = player_progress(player,1);
	if(!ensure_current_chapter_counters(player,progress))
		return (["ok":0,"message":"当前章节独立计数初始化失败，请稍后重试。"]) ;
	quiz_view = story_quiz_public_view(progress);
	foreach((array)config["chapters"];int index;mapping chapter)
		chapter_rows += ({chapter_status(player,progress,chapter,index)});
	return ([
		"ok":1,"mode":(string)context["mode"],
		"ranking_enabled":(int)context["ranking_enabled"],
		"illusion_id":(string)context["illusion_id"],
		"display_name":(string)config["display_name"],
		"level":(int)player->query_level(),
		"kills":(int)progress["kills"],
		"boss_kills":(int)progress["boss_kills"],
		"team_kills":(int)progress["team_kills"],
		"visits":progress_visit_count(progress),
		"active_days":story_active_day_count(progress),
		"story_event_count":story_event_count(progress),
		"chapter_total":sizeof((array)config["chapters"]),
		"chapter_claimed":claimed_chapter_count(progress),
		"story_title":(string)config["story_title"],
		"story_premise":(string)config["story_premise"],
		"quiz_unlocked":(int)quiz_view["unlocked"],
		"quiz_status":(string)quiz_view["status"],
		"quiz_best_score":(int)quiz_view["best_score"],
		"quiz_best_title":(string)quiz_view["best_title"],
		"route_mark_count":mappingp(progress["route_marks"]) ?
			sizeof((mapping)progress["route_marks"]) : 0,
		"path":(string)progress["path"],
		"path_name":path_name((string)progress["path"]),
		"route_target":route_target(progress,(string)progress["path"]),
		"pvp_honor":(int)progress["pvp_honor"],
		"pvp_wins":(int)progress["pvp_wins"],
		"ranking_week":ranking_week_index(progress,time()),
		"ranking_titles":arrayp(progress["ranking_titles"]) ?
			copy_value((array)progress["ranking_titles"]) : ({}),
		"chapters":chapter_rows,
	]);
}

private mapping(string:mixed) start_chapter_hunt_autofight_internal(
	object player,int test_bypass_phase)
{
	mapping progress;
	mapping chapter;
	array chapters;
	int chapter_number;
	string reason;
	string current_room;
	string completion_kind;
	array(string) target_rooms = ({});
	int in_target_room;
	mapping context=story_context(player);
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前不能启动幻境章节挂机。"]) ;
	progress = query_player_progress(player);
	if(!(int)progress["ok"] || !arrayp(progress["chapters"]))
		return (["ok":0,"message":"当前章节进度暂不可验证。"]) ;
	chapters = (array)progress["chapters"];
	chapter_number = (int)progress["chapter_claimed"]+1;
	if(chapter_number<1 || chapter_number>sizeof(chapters))
		return (["ok":0,"message":"八十一章已经全部完成。"]) ;
	chapter = (mapping)chapters[chapter_number-1];
	if((string)chapter["target_kind"]!="hunt")
		return (["ok":0,"message":"当前步骤不是狩猎小怪，未启动挂机。"]) ;
	current_room = normalized_destination_path(environment(player));
	if(arrayp(chapter["target_rooms"]))
		target_rooms = (array(string))chapter["target_rooms"];
	if(!sizeof(target_rooms) && (string)chapter["target_room"]!="")
		target_rooms = ({(string)chapter["target_room"]});
	foreach(target_rooms,string target_room)
		if(MAP_WORKERD->static_room_locations_match(current_room,target_room)){
			in_target_room = 1;
			break;
		}
	if(!in_target_room)
		return (["ok":0,"message":"请先点击“下一步”到达本章狩猎地点。"]) ;
	reason = AUTOFIGHTD->query_start_block_reason(player);
	if(reason!=""){
		AUTOFIGHTD->stop_autofight(player);
		return (["ok":0,"message":"无法启动本章挂机："+reason]);
	}
	AUTOFIGHTD->start_autofight(player);
	player->m_delete_foruser("/tmp/illusion_chapter_return_pending");
	completion_kind = (int)chapter["chapter_kills_done"]<
		(int)chapter["chapter_kills"] ? "chapter_kills" : "quest_item";
	player["/tmp/illusion_chapter_autofight"] = ([
		"illusion_id":(string)progress["illusion_id"],
		"chapter_id":(string)chapter["id"],
		"target_name":(string)chapter["target_name"],
		"completion_kind":completion_kind,
		"target_kills":(int)chapter["chapter_kills"],
		"started_at":time(),
	]);
	return (["ok":1,"message":"已启动“挂机至本章狩猎完成”：只计算"+
		(string)chapter["target_name"]+"，数量达标后自动停止；不会改变普通持续挂机设置。",
		"chapter_id":(string)chapter["id"]]);
}

mapping(string:mixed) start_chapter_hunt_autofight(object player)
{
	return start_chapter_hunt_autofight_internal(player,0);
}

mapping(string:mixed) start_chapter_hunt_autofight_for_test(object player)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	return start_chapter_hunt_autofight_internal(player,1);
}

private mapping(string:mixed) claim_chapter_reward_internal(object player,
	int chapter_number,int test_bypass_phase)
{
	mapping context=story_context(player);
	mapping config;
	string illusion_id;
	mapping progress;
	mapping old_progress;
	mapping chapter;
	mapping status;
	array(string) templates;
	array(object) granted = ({});
	array(string) names = ({});
	int reward_start;
	string profession_id;
	int old_level;
	int old_exp;
	int old_current_exp;
	int old_life;
	int old_mofa;
	int claimed_at;
	int chapter_started;
	int chapter_elapsed;
	int mastery_difficulty;
	mapping(string:int) growth;
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前不能领取"+
			(string)(context["illusion_id"] || "幻境")+"章节奖励。"]) ;
	config=(mapping)context["config"];
	illusion_id=(string)context["illusion_id"];
	if(chapter_number<1 ||
	   chapter_number>sizeof((array)config["chapters"]))
		return (["ok":0,"message":"章节编号无效。"]) ;
	progress = player_progress(player,1);
	if(!ensure_current_chapter_counters(player,progress))
		return (["ok":0,"message":"当前章节独立计数初始化失败，请稍后重试。"]) ;
	old_progress = copy_value(progress);
	old_level = (int)player->query_level();
	old_exp = (int)player->exp;
	old_current_exp = (int)player->current_exp;
	old_life = (int)player->get_cur_life();
	old_mofa = (int)player->get_cur_mofa();
	chapter = ((array)config["chapters"])[chapter_number-1];
	status = chapter_status(player,progress,chapter,chapter_number-1);
	if((int)status["claimed"])
		return (["ok":1,"already":1,"message":"该章节奖励已经领取。"]) ;
	if(!(int)status["ready"])
		return (["ok":0,"message":"章节目标尚未完成，或前一章尚未领取。"]) ;
	claimed_at=time();
	chapter_started=current_chapter_started_at(progress,chapter_number);
	chapter_elapsed=max(0,claimed_at-chapter_started);
	mastery_difficulty=intp(progress["chapter_mastery_difficulty"]) ?
		(int)progress["chapter_mastery_difficulty"] : -1;
	profession_id = (string)player->query_profeId();
	if((int)chapter["reward_count"]>0){
		templates = ITEMSD->query_newmoon_base_templates_for_profession(
			profession_id);
		if(sizeof(templates)!=10)
			return (["ok":0,"message":"本职业"+
				illusion_id+
				"套装模板校验失败，未发放奖励。"]) ;
	}
	for(int index=0;index<chapter_number-1;index++)
		reward_start += (int)((array)config["chapters"])[index]["reward_count"];
	for(int offset=0;offset<(int)chapter["reward_count"];offset++){
		object item;
		mixed err = catch{ item=clone(ITEM_PATH+templates[reward_start+offset]); };
		if(err || !item ||
		   ITEMSD->bind_newmoon_item_to_player(item,player,"choice")<1 ||
		   item->move(player)!=1 || environment(item)!=player){
			if(item)
				destruct(item);
			foreach(granted,object old_item)
				if(old_item) destruct(old_item);
			player[ILLUSION_PROGRESS_ROOT+"/"+
				illusion_id] = old_progress;
			return (["ok":0,"message":"奖励发放失败，背包与领取状态均未改变。"]) ;
		}
		granted += ({item});
		names += ({(string)item->query_name_cn()});
	}
	if(!mappingp(progress["claims"]))
		progress["claims"] = ([]);
	progress["claims"][(string)chapter["id"]] = claimed_at;
	// 每个 S1 难度必须在当前最高档亲自完成九个新章回。记录与
	// 章节奖励共用同一次人物原子保存，失败时 old_progress 会整体回滚。
	if(!mappingp(progress["difficulty_chapters"]))
		progress["difficulty_chapters"] = ([]);
	((mapping)progress["difficulty_chapters"])[(string)chapter["id"]] =
		mastery_difficulty;
	// 已在本章途中的旧人物不会被热更新强制换房；领取成功后，下一章
	// 才启用三段猎场节奏。该字段与奖励在同一人物原子存档中提交。
	progress["chapter_route_rhythm_version"] = 1;
	reset_current_chapter_counters(progress);
	// 下一章从本章领取提交时开始计时。它只写观测字段，不能影响任何
	// 游戏结算；人物保存失败时 old_progress 会连同该字段整体回滚。
	progress["chapter_started_at"] = claimed_at;
	mapping claim_week = ranking_week_state(progress,claimed_at,1);
	claim_week["chapter_claims"] = (int)claim_week["chapter_claims"]+1;
	claim_week["set_parts"] = min(10,(int)claim_week["set_parts"]+
		(int)chapter["reward_count"]);
	if(chapter_number==sizeof((array)config["chapters"]))
		claim_week["completed_at"] = claimed_at;
	growth = grant_chapter_story_growth(player,progress,chapter_number);
	if(!(int)growth["ok"]){
		foreach(granted,object item)
			if(item) destruct(item);
		player[ILLUSION_PROGRESS_ROOT+"/"+
			illusion_id] = old_progress;
		player->level = old_level;
		player->exp = old_exp;
		player->current_exp = old_current_exp;
		player->set_att_by_level();
		player->set_life(min(old_life,(int)player->query_life_max()));
		player->set_mofa(min(old_mofa,(int)player->query_mofa_max()));
		return (["ok":0,"message":"章节悟境结算失败，奖励与人物等级均未改变。"]) ;
	}
	update_ranking_snapshot(player,progress);
	if(!player->save_with_result()){
		foreach(granted,object item)
			if(item) destruct(item);
		player[ILLUSION_PROGRESS_ROOT+"/"+
			illusion_id] = old_progress;
		player->level = old_level;
		player->exp = old_exp;
		player->current_exp = old_current_exp;
		player->set_att_by_level();
		player->set_life(min(old_life,(int)player->query_life_max()));
		player->set_mofa(min(old_mofa,(int)player->query_mofa_max()));
		return (["ok":0,"message":"人物存档失败，奖励与领取状态已回滚。"]) ;
	}
	if(chapter_number==sizeof((array)config["chapters"])){
		mapping completion=([]);
		mixed completion_err=catch{
			completion=ACCOUNT_CHARACTERD->
				record_illusion_story_completion(player,illusion_id);
		};
		// 章节奖励和人物唯一档案在上方已经原子保存。账号索引
		// 是可在下次登录补写的派生凭证；它的异常不能穿透成空页，
		// 更不能让玩家误以为终章失败而重复点击。
		if(completion_err || !mappingp(completion) ||
		   !(int)completion["ok"])
			werror("[ILLUSION_HIDDEN] 八十一章已完成，账号凭证待登录补写: %s %s\n",
				(string)player->query_name(),completion_err ?
				describe_error(completion_err) :
				(string)(completion["message"] || "invalid completion result"));
	}
	safe_append_illusion_log(sprintf("%d|claim|illusion=%s|user=%s|chapter=%s|chapter_number=%d|elapsed_seconds=%d|mastery_difficulty=%d|items=%d|level_before=%d|level_after=%d|story_exp=%d\n",
		claimed_at,illusion_id,
		(string)player->query_name(),(string)chapter["id"],chapter_number,
		chapter_elapsed,mastery_difficulty,sizeof(granted),
		(int)growth["before_level"],(int)growth["after_level"],
		(int)growth["added_exp"]));
	if((int)context["ranking_enabled"] &&
	   !persist_ranking_snapshot(player,progress,illusion_id))
		werror("[ILLUSION_RANKING] 章节快照待后续补写: %s\n",
			(string)player->query_name());
	if((int)context["ranking_enabled"])
		invalidate_ranking_cache(illusion_id);
	return (["ok":1,"message":"【"+(string)chapter["title"]+
		"·过关】\n[imgurl picture:"+(string)chapter["image"]+"]\n"+
		(string)chapter["outro"]+
		((int)growth["after_level"]>(int)growth["before_level"] ?
		 "\n章回悟境：等级提升至 "+(string)growth["after_level"]+" 级。" : "")+
		(sizeof(names) ? "\n获得："+(names*"、") : ""),"items":names,
		"growth":growth]);
}

mapping(string:mixed) claim_chapter_reward(object player,int chapter_number)
{
	return claim_chapter_reward_internal(player,chapter_number,0);
}

mapping(string:mixed) claim_chapter_reward_for_test(object player,
	int chapter_number)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	return claim_chapter_reward_internal(player,chapter_number,1);
}

private string ranking_duration_text(int seconds)
{
	int days;
	int hours;
	int minutes;
	if(seconds<0)
		seconds = 0;
	days = seconds/86400;
	hours = (seconds%86400)/3600;
	minutes = (seconds%3600)/60;
	if(days>0)
		return sprintf("%d天%02d小时",days,hours);
	if(hours>0)
		return sprintf("%d小时%02d分",hours,minutes);
	return sprintf("%d分%02d秒",minutes,seconds%60);
}

private int valid_ranking_period(string period)
{
	int week;
	return period=="overall" ||
		(sscanf(period,"week:%d",week)==1 && week>=1 && week<=60 &&
		 period=="week:"+(string)week);
}

private string ranking_week_validation_error(mapping state)
{
	array(string) nonnegative_fields = ({
		"kills","boss_kills","team_kills","visits","route_marks",
		"story_events","active_days","chapter_claims","set_parts",
		"pvp_honor","pvp_wins","level","experience_latest",
	});
	if(!mappingp(state) || sizeof(state)>24)
		return "root";
	foreach(nonnegative_fields,string field)
		if(has_index(state,field) &&
		   (!intp(state[field]) || (int)state[field]<0 ||
		    (int)state[field]>2000000000))
			return "field:"+field;
	if(has_index(state,"experience_start") &&
	   (!intp(state["experience_start"]) ||
	    (int)state["experience_start"] < -1 ||
	    (int)state["experience_start"] > 2000000000))
		return "field:experience_start";
	if(has_index(state,"completed_at") &&
	   (!intp(state["completed_at"]) ||
	    (int)state["completed_at"]<0 ||
	    (int)state["completed_at"]>ILLUSION_TIMESTAMP_MAX))
		return "timestamp:completed_at";
	return "";
}

private string ranking_progress_validation_error(mapping progress)
{
	array(string) nonnegative_fields = ({
		"kills","boss_kills","team_kills",
		"visited_count","claims_count","route_marks_count",
		"active_days_count","story_events_count",
		"pvp_honor","pvp_wins","ranking_level",
		"ranking_experience_latest","set_parts",
		"community_points",
	});
	array(string) timestamp_fields = ({
		"joined_at","season_starts_at","completed_at",
	});
	if(!mappingp(progress) || sizeof(progress)>80)
		return "root";
	foreach(nonnegative_fields,string field)
		if(has_index(progress,field) &&
		   (!intp(progress[field]) || (int)progress[field]<0 ||
		    (int)progress[field]>2000000000))
			return "field:"+field;
	foreach(timestamp_fields,string field)
		if(has_index(progress,field) &&
		   (!intp(progress[field]) || (int)progress[field]<0 ||
		    (int)progress[field]>ILLUSION_TIMESTAMP_MAX))
			return "timestamp:"+field;
	if(has_index(progress,"claims_count") &&
	   (int)progress["claims_count"]>
	   sizeof((array)illusion_config["chapters"]))
		return "field:claims_count_range";
	if(has_index(progress,"ranking_experience_start") &&
	   (!intp(progress["ranking_experience_start"]) ||
	    (int)progress["ranking_experience_start"] < -1 ||
	    (int)progress["ranking_experience_start"] > 2000000000))
		return "field:ranking_experience_start";
	foreach(({({"visited",4096}),({"claims",128}),({"route_marks",64}),
		({"active_days",64}),({"story_events",128}),
		({"pvp_opponents",512}),({"ranking_reward_claims",400})}),
	   array spec)
		if(has_index(progress,(string)spec[0]) &&
		   (!mappingp(progress[(string)spec[0]]) ||
		    sizeof((mapping)progress[(string)spec[0]])>(int)spec[1]))
			return "mapping:"+(string)spec[0];
	if(has_index(progress,"ranking_titles") &&
	   (!arrayp(progress["ranking_titles"]) ||
	    sizeof((array)progress["ranking_titles"])>64))
		return "ranking_titles";
	if(mappingp(progress["ranking_weeks"])){
		mapping weeks = (mapping)progress["ranking_weeks"];
		if(sizeof(weeks)>60)
			return "ranking_weeks:size";
		foreach(indices(weeks),mixed week_key){
			int week;
			if(!stringp(week_key) ||
			   sscanf((string)week_key,"%d",week)!=1 || week<1 || week>60 ||
			   (string)week_key!=(string)week || !mappingp(weeks[week_key]) ||
			   ranking_week_validation_error((mapping)weeks[week_key])!="")
				return "ranking_weeks:key_or_state";
		}
	}
	else if(has_index(progress,"ranking_weeks"))
		return "ranking_weeks:type";
	return "";
}

private int valid_ranking_progress(mapping progress)
{
	return ranking_progress_validation_error(progress)=="";
}

private int valid_ranking_character_id(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>64)
		return 0;
	foreach(value;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='_' || one=='-')
			continue;
		return 0;
	}
	return 1;
}

private int compact_ranking_int(mapping progress,string field,int fallback)
{
	return has_index(progress,field) && intp(progress[field]) ?
		(int)progress[field] : (int)fallback;
}

private mapping compact_ranking_progress(mapping progress)
{
	return ([
		"joined_at":compact_ranking_int(progress,"joined_at",0),
		"season_starts_at":compact_ranking_int(progress,
			"season_starts_at",0),
		"kills":compact_ranking_int(progress,"kills",0),
		"boss_kills":compact_ranking_int(progress,"boss_kills",0),
		"team_kills":compact_ranking_int(progress,"team_kills",0),
		"visited_count":progress_visit_count(progress),
		// 只有从第一章开始连续领取的章节才是真实进度；未知键和越章键
		// 不能进入轻量快照并抬高排行榜分数。
		"claims_count":claimed_chapter_count(progress),
		"route_marks_count":mappingp(progress["route_marks"]) ?
			sizeof((mapping)progress["route_marks"]) : 0,
		"active_days_count":story_active_day_count(progress),
		"story_events_count":story_event_count(progress),
		"pvp_honor":compact_ranking_int(progress,"pvp_honor",0),
		"pvp_wins":compact_ranking_int(progress,"pvp_wins",0),
		"ranking_level":compact_ranking_int(progress,"ranking_level",0),
		"ranking_experience_start":
			compact_ranking_int(progress,"ranking_experience_start",-1),
		"ranking_experience_latest":
			compact_ranking_int(progress,"ranking_experience_latest",0),
		"set_parts":compact_ranking_int(progress,"set_parts",0),
		"completed_at":compact_ranking_int(progress,"completed_at",0),
		"community_points":compact_ranking_int(progress,
			"community_points",0),
		"ranking_weeks":mappingp(progress["ranking_weeks"]) ?
			copy_value((mapping)progress["ranking_weeks"]) : ([]),
	]);
}

private int persist_ranking_snapshot(object player,mapping progress,
	string illusion_id)
{
	string character_id;
	string directory;
	string path;
	string temp_path;
	string encoded;
	string name_cn;
	string profession_id;
	string profession_name;
	mapping compact;
	mapping snapshot;
	int ok;
	mixed err;
	if(!player || !valid_identifier(illusion_id) ||
	   !valid_ranking_progress(progress))
		return 0;
	character_id = (string)player->query_name();
	if(!valid_ranking_character_id(character_id))
		return 0;
	name_cn = functionp(player->query_name_cn) ?
		(string)player->query_name_cn(1) : character_id;
	if(name_cn=="" || sizeof(name_cn)>96)
		name_cn = character_id;
	profession_id = functionp(player->query_profeId) ?
		(string)player->query_profeId() : "";
	profession_name = (string)TASKD->
		query_growth_task_profession_name(profession_id);
	if(profession_name=="" || sizeof(profession_name)>32)
		profession_name = profession_id!="" ? profession_id : "未知职业";
	compact = compact_ranking_progress(progress);
	if(!valid_ranking_progress(compact))
		return 0;
	snapshot = ([
		"version":1,"illusion_id":illusion_id,
		"character_id":character_id,"name_cn":name_cn,
		"profession_id":profession_id,
		"profession_name":profession_name,
		"level":max(1,(int)compact["ranking_level"]),
		"illusion_progress":compact,"updated_at":time(),
	]);
	encoded = Standards.JSON.encode(snapshot);
	directory = ILLUSION_RANKING_DIR+"/"+illusion_id;
	path = directory+"/"+character_id+".json";
	temp_path = path+"."+
		String.string2hex(Crypto.Random.random_string(8))+".tmp";
	err = catch{
		Stdio.mkdirhier(directory);
		if(Stdio.write_file(temp_path,encoded)==sizeof(encoded) &&
		   Stdio.file_size(temp_path)==sizeof(encoded) &&
		   mv(temp_path,path) && Stdio.file_size(path)==sizeof(encoded))
			ok = 1;
	};
	if(err)
		werror("[ILLUSION_RANKING] 快照保存异常 user=%s error=%s\n",
			character_id,describe_error(err));
	if(!ok)
		rm(temp_path);
	return ok;
}

private mapping(string:mixed) query_ranking_snapshots(string illusion_id)
{
	mapping result = (["ok":0,"characters":({}),"corrupt":0,
		"truncated":0]);
	string directory = ILLUSION_RANKING_DIR+"/"+illusion_id;
	array candidates = ({});
	if(!valid_identifier(illusion_id))
		return result;
	foreach(get_dir(directory) || ({}),string filename){
		string character_id;
		string content;
		string invalid_reason = "";
		mixed decoded;
		mixed err;
		if(!has_suffix(filename,".json"))
			continue;
		character_id = filename[..sizeof(filename)-6];
		if(!valid_ranking_character_id(character_id)){
			result["corrupt"] = (int)result["corrupt"]+1;
			continue;
		}
		if(sizeof(candidates)>=5000){
			result["truncated"] = 1;
			continue;
		}
		content = Stdio.read_file(directory+"/"+filename) || "";
		err = catch { decoded=Standards.JSON.decode(content); };
		if(err)
			invalid_reason = "json_decode";
		else if(!mappingp(decoded))
			invalid_reason = "root_not_mapping";
		else if((int)decoded["version"]!=1)
			invalid_reason = "version";
		else if((string)decoded["illusion_id"]!=illusion_id)
			invalid_reason = "illusion_id";
		else if((string)decoded["character_id"]!=character_id)
			invalid_reason = "character_id";
		else if(!stringp(decoded["name_cn"]) ||
		   sizeof((string)decoded["name_cn"])>96)
			invalid_reason = "name_cn";
		else if(!stringp(decoded["profession_name"]) ||
		   sizeof((string)decoded["profession_name"])>32)
			invalid_reason = "profession_name";
		else if(!mappingp(decoded["illusion_progress"]))
			invalid_reason = "progress_type";
		else if(!valid_ranking_progress(
		   (mapping)decoded["illusion_progress"]))
			invalid_reason = "progress_"+
				ranking_progress_validation_error(
					(mapping)decoded["illusion_progress"]);
		if(invalid_reason!=""){
			mixed invalid_value = 0;
			if(has_prefix(invalid_reason,"progress_field:") &&
			   mappingp(decoded) &&
			   mappingp(decoded["illusion_progress"])){
				string invalid_field = invalid_reason[
					sizeof("progress_field:")..];
				invalid_value =
					((mapping)decoded["illusion_progress"])[invalid_field];
			}
			werror("[ILLUSION_RANKING] 拒绝损坏快照 file=%s reason=%s value=%O bytes=%d\n",
				filename,invalid_reason,invalid_value,sizeof(content));
			result["corrupt"] = (int)result["corrupt"]+1;
			continue;
		}
		candidates += ({([
			"id":character_id,"name_cn":(string)decoded["name_cn"],
			"profession_name":(string)decoded["profession_name"],
			"level":max(1,(int)decoded["level"]),
			"illusion_state":"snapshot",
			"illusion_progress":copy_value(
				(mapping)decoded["illusion_progress"]),
		])});
	}
	result["characters"] = candidates;
	result["ok"] = !(int)result["corrupt"] &&
		!(int)result["truncated"];
	return result;
}

/**
 * Journey subfeatures commit inside the same player .o file, then publish a
 * derived compact snapshot.  A snapshot failure never rolls back a durable
 * character save; the next successful checkpoint repairs the derived view.
 */
private int publish_journey_snapshot_internal(object player,int test_bypass)
{
	mapping context = story_context(player);
	mapping progress;
	string illusion_id;
	if(!player)
		return 0;
	if(test_bypass && getenv("XIAND_RUN_TESTUNIT")=="1" &&
	   has_prefix((string)player->query_name(),"__testunit_")){
		mapping all_progress = mappingp(player[ILLUSION_PROGRESS_ROOT]) ?
			(mapping)player[ILLUSION_PROGRESS_ROOT] : ([]);
		illusion_id = "S1";
		progress = mappingp(all_progress[illusion_id]) ?
			copy_value((mapping)all_progress[illusion_id]) : ([]);
	}
	else{
		if(!sizeof(context) || !(int)context["ranking_enabled"])
			return 0;
		illusion_id = (string)context["illusion_id"];
		progress = copy_value(player_progress(player,0));
	}
	if(!sizeof(progress) || !valid_ranking_progress(progress))
		return 0;
	update_ranking_snapshot(player,progress);
	if(!persist_ranking_snapshot(player,progress,illusion_id))
		return 0;
	invalidate_ranking_cache(illusion_id);
	return 1;
}

int publish_journey_snapshot(object player)
{
	return publish_journey_snapshot_internal(player,0);
}

int publish_journey_snapshot_for_test(object player)
{
	return publish_journey_snapshot_internal(player,1);
}

mapping(string:mixed) query_community_progress(string illusion_id)
{
	string cache_key = illusion_id+"|community|overall";
	mapping cached = ranking_cache[cache_key];
	mapping snapshots;
	int total;
	int contributors;
	if(!valid_identifier(illusion_id))
		return (["ok":0,"points":0,"contributors":0]);
	if(mappingp(cached) && time()-(int)cached["created_at"]<=
	   ILLUSION_RANKING_CACHE_TTL)
		return copy_value((mapping)cached["result"]);
	snapshots = query_ranking_snapshots(illusion_id);
	if(!(int)snapshots["ok"])
		return (["ok":0,"points":0,"contributors":0,
			"corrupt":(int)snapshots["corrupt"],
			"truncated":(int)snapshots["truncated"]]);
	foreach((array)snapshots["characters"],mapping profile){
		mapping progress = mappingp(profile["illusion_progress"]) ?
			(mapping)profile["illusion_progress"] : ([]);
		int points = (int)progress["community_points"];
		if(points<=0)
			continue;
		total += points;
		contributors++;
	}
	mapping result = (["ok":1,"illusion_id":illusion_id,
		"points":total,"contributors":contributors,"generated_at":time()]);
	ranking_cache[cache_key] = (["created_at":time(),
		"result":copy_value(result)]);
	return result;
}

private mapping(string:mixed) ranking_score_for_profile(string board,
	mapping profile,string period,string illusion_id)
{
	mapping progress = mappingp(profile["illusion_progress"]) ?
		(mapping)profile["illusion_progress"] : ([]);
	mapping source = progress;
	int score;
	int tie;
	int completed_at;
	int joined_at = (int)progress["joined_at"];
	int week_number;
	if(!sizeof(progress) || !valid_ranking_progress(progress) ||
	   !ranking_names[board] ||
	   !valid_ranking_period(period))
		return (["eligible":0]);
	if(mappingp(progress["claims"]) &&
	   sizeof((mapping)progress["claims"])!=
	   claimed_chapter_count(progress))
		return (["eligible":0]);
	if(period!="overall"){
		sscanf(period,"week:%d",week_number);
		mapping weeks = mappingp(progress["ranking_weeks"]) ?
			(mapping)progress["ranking_weeks"] : ([]);
		if(!mappingp(weeks[(string)week_number]))
			return (["eligible":0]);
		source = (mapping)weeks[(string)week_number];
	}
	switch(board){
	case "journey":
		if(period=="overall")
			score = (has_index(progress,"claims_count") ?
				(int)progress["claims_count"] :
				(mappingp(progress["claims"]) ?
					claimed_chapter_count(progress) : 0))*10000+
				(has_index(progress,"route_marks_count") ?
				(int)progress["route_marks_count"] :
				(mappingp(progress["route_marks"]) ?
				sizeof((mapping)progress["route_marks"]) : 0))*1000+
				(has_index(progress,"story_events_count") ?
					(int)progress["story_events_count"] :
					story_event_count(progress))*500+
				(has_index(progress,"active_days_count") ?
					(int)progress["active_days_count"] :
					story_active_day_count(progress))*250+
				(int)progress["boss_kills"]*100+
				(has_index(progress,"visited_count") ?
				(int)progress["visited_count"] :
				progress_visit_count(progress))*20+
				(int)progress["team_kills"]*10+(int)progress["kills"];
		else
			score = (int)source["chapter_claims"]*10000+
				(int)source["route_marks"]*1000+
				(int)source["story_events"]*500+
				(int)source["active_days"]*250+
				(int)source["boss_kills"]*100+
				(int)source["visits"]*20+
				(int)source["team_kills"]*10+(int)source["kills"];
		tie = period=="overall" ? (int)progress["ranking_level"] :
			(int)source["level"];
		break;
	case "level":
		score = period=="overall" ? (int)progress["ranking_level"] :
			(int)source["level"];
		if((string)profile["illusion_state"]=="active" &&
		   (period=="overall" || week_number==
		    ranking_week_index(progress,time())))
			score = max(score,(int)profile["level"]);
		tie = max(0,(int)progress["ranking_experience_latest"]-
			(int)progress["ranking_experience_start"]);
		break;
	case "experience":
		if(period=="overall"){
			int start = (int)progress["ranking_experience_start"];
			int latest = (int)progress["ranking_experience_latest"];
			if(start<0 && (string)profile["illusion_state"]=="active")
				start = 0;
			if((string)profile["illusion_state"]=="active")
				latest = max(latest,(int)profile["experience"]);
			score = max(0,latest-start);
			tie = (int)progress["ranking_level"];
		}
		else{
			int weekly_latest = (int)source["experience_latest"];
			if((string)profile["illusion_state"]=="active" &&
			   week_number==ranking_week_index(progress,time()))
				weekly_latest = max(weekly_latest,(int)profile["experience"]);
			score = max(0,weekly_latest-
				(int)source["experience_start"]);
			tie = (int)source["level"];
		}
		break;
	case "pk":
		score = period=="overall" ? (int)progress["pvp_honor"] :
			(int)source["pvp_honor"];
		tie = period=="overall" ? (int)progress["pvp_wins"] :
			(int)source["pvp_wins"];
		break;
	case "set":
		score = period=="overall" ? (int)progress["set_parts"] :
			(int)source["set_parts"];
		if(score<=0 && period=="overall" &&
		   illusion_id==(string)illusion_config["current_id"])
			score = claimed_set_parts(progress);
		completed_at = period=="overall" ? (int)progress["completed_at"] :
			(int)source["completed_at"];
		tie = completed_at>0 ? ILLUSION_TIMESTAMP_MAX-completed_at :
			(int)progress["ranking_level"];
		break;
	case "speed":
		completed_at = period=="overall" ? (int)progress["completed_at"] :
			(int)source["completed_at"];
		if(completed_at<=0 || joined_at<=0 || completed_at<joined_at)
			return (["eligible":0]);
		score = completed_at-joined_at;
		tie = period=="overall" ? (int)progress["ranking_level"] :
			(int)source["level"];
		break;
	}
	if(score<=0 && board!="level")
		return (["eligible":0]);
	return (["eligible":score>0,"score":score,"tie":tie]);
}

private int ranking_entry_before(mapping left,mapping right,string board)
{
	if((int)left["score"]!=(int)right["score"])
		return board=="speed" ?
			(int)left["score"]<(int)right["score"] :
			(int)left["score"]>(int)right["score"];
	if((int)left["tie"]!=(int)right["tie"])
		return (int)left["tie"]>(int)right["tie"];
	return (string)left["character_id"]<(string)right["character_id"];
}

private array(mapping(string:mixed)) insert_ranking_entry(
	array(mapping(string:mixed)) rows,mapping(string:mixed) entry,
	string board)
{
	array(mapping(string:mixed)) result = ({});
	int inserted;
	foreach(rows,mapping row){
		if(!inserted && ranking_entry_before(entry,row,board)){
			result += ({entry});
			inserted = 1;
		}
		result += ({row});
	}
	if(!inserted)
		result += ({entry});
	if(sizeof(result)>100)
		result = result[..99];
	return result;
}

mapping(string:mixed) query_illusion_leaderboard(string illusion_id,
	string board,string period,void|int requested_limit)
{
	int limit = min(50,max(1,(int)(requested_limit || 20)));
	string cache_key = illusion_id+"|"+board+"|"+period;
	mapping cached = ranking_cache[cache_key];
	mapping candidate_result;
	array(mapping(string:mixed)) rows = ({});
	if(!valid_identifier(illusion_id) || !ranking_names[board] ||
	   !valid_ranking_period(period))
		return (["ok":0,"message":"排行榜参数无效。","rows":({})]);
	if(mappingp(cached) && time()-(int)cached["created_at"]<=
	   ILLUSION_RANKING_CACHE_TTL){
		mapping cached_result = copy_value((mapping)cached["result"]);
		cached_result["rows"] = ((array)cached_result["rows"])[..limit-1];
		return cached_result;
	}
	candidate_result = query_ranking_snapshots(illusion_id);
	if(!(int)candidate_result["ok"])
		return (["ok":0,"message":"排行榜快照未能完整校验，已拒绝显示不完整榜单。",
			"rows":({}),"corrupt":(int)candidate_result["corrupt"],
			"truncated":(int)candidate_result["truncated"]]);
	foreach((array)candidate_result["characters"],mapping profile){
		if(sizeof((mapping)(profile["illusion_progress"] || ([]))) &&
		   !valid_ranking_progress((mapping)profile["illusion_progress"]))
			return (["ok":0,"message":"发现损坏的幻境历程，已拒绝显示可能错误的榜单。",
				"rows":({}),"character_id":(string)profile["id"]]);
		mapping scored = ranking_score_for_profile(board,profile,period,
			illusion_id);
		if(!(int)scored["eligible"])
			continue;
		mapping entry = ([
			"character_id":(string)profile["id"],
			"name_cn":(string)profile["name_cn"],
			"profession_name":(string)profile["profession_name"],
			"level":(int)profile["level"],
			"score":(int)scored["score"],"tie":(int)scored["tie"],
		]);
		if(board=="speed")
			entry["score_text"] = ranking_duration_text((int)entry["score"]);
		else if(board=="level")
			entry["score_text"] = "Lv"+(string)(int)entry["score"];
		else if(board=="set")
			entry["score_text"] = (string)(int)entry["score"]+"件";
		else if(board=="pk")
			entry["score_text"] = (string)(int)entry["score"]+"荣誉";
		else
			entry["score_text"] = (string)(int)entry["score"]+"点";
		rows = insert_ranking_entry(rows,entry,board);
	}
	for(int index=0;index<sizeof(rows);index++)
		rows[index]["rank"] = index+1;
	mapping result = ([
		"ok":1,"illusion_id":illusion_id,"board":board,
		"board_name":ranking_names[board],"period":period,
		"rows":rows,"generated_at":time(),
	]);
	ranking_cache[cache_key] = (["created_at":time(),
		"result":copy_value(result)]);
	result = copy_value(result);
	result["rows"] = ((array)result["rows"])[..limit-1];
	return result;
}

private int pvp_honor_points(int winner_level,int loser_level,
	int same_account,int prior_wins)
{
	int points;
	if(same_account || winner_level<1 || loser_level<1 || prior_wins<0 ||
	   winner_level-loser_level>max(10,loser_level/5))
		return 0;
	if(prior_wins==0) points = 100;
	else if(prior_wins==1) points = 50;
	else if(prior_wins==2) points = 20;
	else return 0;
	if(winner_level<loser_level)
		points += min(50,(loser_level-winner_level)*2);
	return points;
}

private int ranking_beijing_day_index(int timestamp)
{
	// 幻境活动与玩家规则均以北京时间展示，日防刷也必须在
	// 北京时间00:00重置，不能误用UTC日界线（北京时间08:00）。
	return (timestamp+8*3600)/86400;
}

mapping(string:mixed) record_pvp_victory(object winner,object loser)
{
	mapping winner_realm;
	mapping loser_realm;
	mapping progress;
	mapping old_progress;
	mapping opponents;
	string opponent_account;
	int today = ranking_beijing_day_index(time());
	int prior_wins;
	int points;
	if(!winner || !loser || !is_active_illusion_character(winner) ||
	   !is_active_illusion_character(loser))
		return (["ok":1,"points":0,"message":"非幻境论剑，不计幻境荣誉。"]);
	winner_realm = query_realm_for_player(winner);
	loser_realm = query_realm_for_player(loser);
	if((string)winner_realm["illusion_id"]!=
	   (string)loser_realm["illusion_id"] ||
	   (string)winner_realm["illusion_id"]!=
	   (string)illusion_config["current_id"])
		return (["ok":1,"points":0,"message":"双方不在同一期幻境，不计荣誉。"]);
	if((string)winner_realm["account_id"]==
	   (string)loser_realm["account_id"])
		return (["ok":1,"points":0,"message":"同一注册账号切磋不计论剑荣誉。"]);
	progress = player_progress(winner,1);
	old_progress = copy_value(progress);
	if((int)progress["pvp_day"]!=today){
		progress["pvp_day"] = today;
		progress["pvp_opponents"] = ([]);
	}
	opponents = mappingp(progress["pvp_opponents"]) ?
		(mapping)progress["pvp_opponents"] : ([]);
	opponent_account = (string)loser_realm["account_id"];
	prior_wins = (int)opponents[opponent_account];
	points = pvp_honor_points((int)winner->query_level(),
		(int)loser->query_level(),0,prior_wins);
	if(points<=0)
		return (["ok":1,"points":0,"message":prior_wins>=3 ?
			"今日对同一对手的前三次荣誉已经结算。" :
			"等级差距过大，本场不计论剑荣誉。"]);
	if(sizeof(opponents)>=512 && !has_index(opponents,opponent_account))
		return (["ok":0,"points":0,"message":"今日对手记录已达安全上限，本场不计荣誉。"]);
	opponents[opponent_account] = prior_wins+1;
	progress["pvp_opponents"] = opponents;
	progress["pvp_honor"] = (int)progress["pvp_honor"]+points;
	progress["pvp_wins"] = (int)progress["pvp_wins"]+1;
	mapping pvp_week = ranking_week_state(progress,time(),1);
	pvp_week["pvp_honor"] = (int)pvp_week["pvp_honor"]+points;
	pvp_week["pvp_wins"] = (int)pvp_week["pvp_wins"]+1;
	update_ranking_snapshot(winner,progress);
	if(!winner->save_with_result()){
		winner[ILLUSION_PROGRESS_ROOT+"/"+
			(string)illusion_config["current_id"]] = old_progress;
		return (["ok":0,"points":0,"message":"论剑荣誉保存失败，本场不计分。"]);
	}
	if(!persist_ranking_snapshot(winner,progress,
	   (string)illusion_config["current_id"]))
		werror("[ILLUSION_RANKING] 论剑快照待后续补写: %s\n",
			(string)winner->query_name());
	invalidate_ranking_cache((string)illusion_config["current_id"]);
	safe_append_illusion_log(sprintf("%d|pvp_honor|illusion=%s|winner=%s|loser=%s|points=%d|repeat=%d\n",
		time(),(string)illusion_config["current_id"],
		(string)winner->query_name(),(string)loser->query_name(),points,
		prior_wins));
	return (["ok":1,"points":points,"message":"本场获得"+
		(string)points+"点幻境论剑荣誉。"]);
}

mapping(string:mixed) claim_illusion_ranking_reward(object player,
	string board,string period)
{
	mapping status = query_public_status();
	string illusion_id = (string)status["illusion_id"];
	mapping progress;
	mapping old_progress;
	mapping leaderboard;
	mapping claims;
	array titles;
	string claim_key;
	string title;
	int week;
	int current_week;
	int rank;
	if(!player || !ranking_names[board] || !valid_ranking_period(period))
		return (["ok":0,"message":"排行榜奖励参数无效。"]);
	progress = player_progress_for_id(player,illusion_id,0);
	if(!sizeof(progress))
		return (["ok":0,"message":"当前人物没有本期幻境历程。"]);
	current_week = ranking_week_index(progress,time());
	if(period=="overall"){
		if((string)status["phase"]!="settling" &&
		   (string)status["phase"]!="closed")
			return (["ok":0,"message":"幻境总榜将在本期结束后结算。"]);
	}
	else{
		sscanf(period,"week:%d",week);
		if((string)status["phase"]=="active" && week>=current_week)
			return (["ok":0,"message":"本周榜尚未结算。"]);
		if(week>current_week)
			return (["ok":0,"message":"该周尚未开始。"]);
	}
	claim_key = period+"|"+board;
	claims = mappingp(progress["ranking_reward_claims"]) ?
		(mapping)progress["ranking_reward_claims"] : ([]);
	if(mappingp(claims[claim_key]))
		return (["ok":1,"already":1,"message":"该榜荣誉已经领取："+
			(string)claims[claim_key]["title"]]);
	leaderboard = query_illusion_leaderboard(illusion_id,board,period,10);
	if(!(int)leaderboard["ok"])
		return (["ok":0,"message":(string)leaderboard["message"]]);
	foreach((array)leaderboard["rows"],mapping row)
		if((string)row["character_id"]==(string)player->query_name()){
			rank = (int)row["rank"];
			break;
		}
	if(rank<1 || rank>10)
		return (["ok":0,"message":"当前人物不在该榜前十，暂无可领取荣誉。"]);
	title = illusion_id+"·"+(period=="overall" ? "终榜" :
		"周"+(string)week)+"·"+(rank==1 ? "魁首" :
		(rank<=3 ? "三甲" : "十强"))+"·"+(string)ranking_names[board];
	old_progress = copy_value(progress);
	claims[claim_key] = (["claimed_at":time(),"rank":rank,"title":title]);
	progress["ranking_reward_claims"] = claims;
	titles = arrayp(progress["ranking_titles"]) ?
		(array)progress["ranking_titles"] : ({});
	titles += ({title});
	if(sizeof(titles)>64)
		titles = titles[sizeof(titles)-64..];
	progress["ranking_titles"] = titles;
	if(!player->save_with_result()){
		player[ILLUSION_PROGRESS_ROOT+"/"+illusion_id] = old_progress;
		return (["ok":0,"message":"排行榜荣誉保存失败，本次仍可重试。"]);
	}
	safe_append_illusion_log(sprintf("%d|ranking_reward|illusion=%s|user=%s|board=%s|period=%s|rank=%d\n",
		time(),illusion_id,(string)player->query_name(),board,period,rank));
	return (["ok":1,"rank":rank,"title":title,
		"message":"已获得幻境荣誉称号："+title+"（仅展示收藏，不增加战斗属性）。"]);
}

mapping(string:mixed) query_ranking_score_for_test(string board,
	mapping profile,string period,string illusion_id)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return (["eligible":0]);
	return ranking_score_for_profile(board,profile,period,illusion_id);
}

int query_timestamp_valid_for_test(mixed value)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return 0;
	return intp(value) && (int)value>=0 &&
		(int)value<=ILLUSION_TIMESTAMP_MAX;
}

int query_ranking_progress_valid_for_test(mapping progress)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return 0;
	return valid_ranking_progress(progress);
}

int query_pvp_honor_points_for_test(int winner_level,int loser_level,
	int same_account,int prior_wins)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return pvp_honor_points(winner_level,loser_level,same_account,prior_wins);
}

int query_ranking_beijing_day_for_test(int timestamp)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return ranking_beijing_day_index(timestamp);
}

mapping(string:mixed) purchase_entitlement(object player)
{
	mapping status = query_public_status();
	mapping account_data;
	mapping grant;
	string account_id;
	int cost;
	int before_wallet;
	int before_physical;
	string request_id;
	string success_message;
	if(!player || !(int)status["ok"] || !(int)status["entitlement_open"])
		return (["ok":0,"message":"当前未开放幻境资格购买。"]) ;
	account_id = (string)player->query_account_owner();
	account_data = ACCOUNT_CHARACTERD->query_account_characters(account_id,
		(string)status["illusion_id"]);
	if(!(int)account_data["ok"]){
		return (["ok":0,
			"message":"账号索引暂不可验证，本次未扣除碎玉。"]) ;
	}
	if((int)account_data["illusion_entitled"]){
		return (["ok":1,"already":1,
			"message":"账号已登记"+
				(string)status["illusion_id"]+"赛季资格。"]) ;
	}
	cost = (int)status["entitlement_cost_suiyu"];
	before_wallet = ACCOUNT_WALLETD->query_balance(player);
	before_physical = YUSHID->query_physical_all_num(player);
	if(mappingp(player[ILLUSION_PAYMENT_ROOT]) &&
	   sizeof((mapping)player[ILLUSION_PAYMENT_ROOT])){
		return (["ok":0,
			"message":"上一笔幻境资格购买仍在恢复，请重新登录后再试。"]);
	}
	{
		object request_hash = Crypto.SHA256();
		request_hash->update(account_id+"|"+(string)player->query_name()+"|"+
			(string)time()+"|"+String.string2hex(
				Crypto.Random.random_string(16)));
		request_id = lower_case(String.string2hex(request_hash->digest()));
	}
	player[ILLUSION_PAYMENT_ROOT] = ([
		"version":1,"phase":"prepared","request_id":request_id,
		"account_id":account_id,
		"illusion_id":(string)illusion_config["current_id"],
		"cost":cost,"before_wallet":before_wallet,
		"before_physical":before_physical,"created_at":time(),
	]);
	if(!player->save_with_result()){
		player[ILLUSION_PAYMENT_ROOT] = ([]);
		return (["ok":0,"message":"购买凭据保存失败，本次未扣除碎玉。"]) ;
	}
	if(cost>0 && !YUSHID->pay_yushi(player,cost)){
		player[ILLUSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		return (["ok":0,"message":"碎玉不足或扣款失败，未解锁资格。"]) ;
	}
	player[ILLUSION_PAYMENT_ROOT]["phase"] = "charged";
	if(!player->save_with_result()){
		int refunded = YUSHID->rollback_yushi_payment(player,before_wallet,
			before_physical,"illusion_entitlement_charge_save_failed");
		if(refunded){
			player[ILLUSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":0,"message":refunded ?
			"扣款存档失败，碎玉已原路退回。" :
			"扣款存档与退款异常，请立即联系管理员。"]);
	}
	grant = ACCOUNT_CHARACTERD->grant_illusion_entitlement(account_id,
		"jade",request_id,(string)status["illusion_id"]);
	if(!(int)grant["ok"]){
		int refunded = cost<=0 || YUSHID->rollback_yushi_payment(player,
			before_wallet,before_physical,"illusion_entitlement_failed");
		if(refunded){
			player[ILLUSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":0,"message":refunded ?
			"资格写入失败，碎玉已原路退回。" :
			"资格写入及退款异常，请立即联系管理员。"]) ;
	}
	if((int)grant["already"]){
		// 账号可能在本次扣款期间由另一请求或管理员完成了解锁。
		// 本请求没有取得资格写入权，必须退回自己的这一笔扣款。
		int refunded = cost<=0 || YUSHID->rollback_yushi_payment(player,
			before_wallet,before_physical,
			"illusion_entitlement_duplicate_charge");
		if(refunded){
			player[ILLUSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":refunded,"already":refunded,
			"message":refunded ?
			"账号已登记"+(string)status["illusion_id"]+
				"赛季资格；本次重复扣款已原路退回。" :
			"检测到重复扣款但退款仍需重试，请重新登录或联系管理员。"]) ;
	}
	// 资格索引已经持久化。这里即使清理凭据失败，登录恢复也只会
	// 清凭据而不会退款，不能让已解锁账号重复获得碎玉。
	player[ILLUSION_PAYMENT_ROOT]["phase"] = "committed";
	player->save_with_result();
	player[ILLUSION_PAYMENT_ROOT] = ([]);
	int cleanup_saved = player->save_with_result();
	safe_append_illusion_log(sprintf("%d|entitlement|illusion=%s|account=%s|character=%s|cost=%d|request=%s|cleanup=%d\n",
		time(),(string)status["illusion_id"],account_id,
		(string)player->query_name(),cost,request_id,
		cleanup_saved));
	if(cost>0)
		success_message = "已支付"+(string)cost+"碎玉并登记"+
			(string)status["illusion_id"]+"赛季资格；人物栏位仅对本期生效。";
	else
		success_message = "已登记"+(string)status["illusion_id"]+
			"赛季资格；登记不扣费，本期每名人物均须按栏位规则支付100碎玉。";
	return (["ok":1,"already":0,"message":success_message]) ;
}

/**
 * The account centre has no live character object and therefore cannot use
 * the jade transaction flow.  It may activate an entitlement only while the
 * configured price is exactly zero.  A future paid season fails closed and
 * must continue through the character-bound payment credential above.
 */
mapping(string:mixed) activate_free_account_entitlement(string requested_id)
{
	mapping status = query_public_status();
	object request_hash;
	string request_id;
	if(!requested_id || !(int)status["ok"])
		return (["ok":0,"message":"幻境资格当前不可用。"]);
	if((int)status["entitlement_cost_suiyu"]!=0)
		return (["ok":0,
			"message":"当前资格不是免费项目，请进入人物内完成安全支付。"]);
	request_hash = Crypto.SHA256();
	request_hash->update(requested_id+"|account_center|"+(string)time()+
		"|"+String.string2hex(Crypto.Random.random_string(16)));
	request_id = lower_case(String.string2hex(request_hash->digest()));
	return ACCOUNT_CHARACTERD->grant_illusion_entitlement(requested_id,
		"account_center",request_id,(string)status["illusion_id"]);
}

private string account_expansion_reason(string illusion_id,string option)
{
	return ILLUSION_ACCOUNT_EXPANSION_REASON+illusion_id+":"+option;
}

/**
 * 人物中心扩容只消费账号共享充值余额。钱包扣款收据和账号栏位请求号
 * 使用同一 request_id；任何一步退出后，下次登录人物中心都会完成栏位
 * 写入或原路退款，不能形成扣款成功但栏位丢失的悬挂状态。
 */
mapping(string:mixed) reconcile_account_character_expansions(
	string requested_id)
{
	string account_id = ACCOUNT_CHARACTERD->
		query_account_id_for_character(requested_id);
	array(mapping(string:mixed)) receipts;
	mapping(string:mixed) summary = (["ok":1,"recovered":0,
		"refunded":0,"pending":0]);
	if(!account_id || account_id=="")
		return (["ok":0,"recovered":0,"refunded":0,"pending":0]);
	receipts = ACCOUNT_WALLETD->query_account_debit_requests(account_id,
		ILLUSION_ACCOUNT_EXPANSION_REASON);
	foreach(receipts,mapping receipt){
		string request_id = (string)(receipt["request_id"] || "");
		string reason = (string)(receipt["reason"] || "");
		string illusion_id = "";
		string option = "";
		int amount = (int)receipt["amount"];
		mapping grant = ([]);
		int parsed = sscanf(reason,ILLUSION_ACCOUNT_EXPANSION_REASON+"%s:%s",
			illusion_id,option);
		if(parsed==2 && valid_identifier(illusion_id) &&
		   search(({"one","all"}),option)!=-1 &&
		   valid_sha256_hex(request_id) && amount>0 && amount<=500 &&
		   amount%100==0)
			grant = ACCOUNT_CHARACTERD->grant_illusion_character_expansion(
				account_id,illusion_id,option,request_id,amount);
		if((int)grant["ok"] &&
		   (!(int)grant["already"] || (int)grant["same_request"])){
			if(ACCOUNT_WALLETD->forget_account_debit_recharge_once(
			   account_id,request_id)){
				summary["recovered"] = (int)summary["recovered"]+1;
				safe_append_illusion_log(sprintf("%d|account_character_expansion_recovery|account=%s|illusion=%s|option=%s|cost=%d|request=%s|result=committed\n",
					time(),account_id,illusion_id,option,amount,request_id));
			}
			else{
				summary["ok"] = 0;
				summary["pending"] = (int)summary["pending"]+1;
				werror("[ILLUSION_REALM] 人物中心扩容收据清理等待重试: %s %s\n",
					account_id,request_id);
			}
		}
		else if(ACCOUNT_WALLETD->rollback_account_debit_recharge_once(
		   account_id,request_id,"illusion_account_expansion_recovery")){
			summary["refunded"] = (int)summary["refunded"]+1;
			safe_append_illusion_log(sprintf("%d|account_character_expansion_recovery|account=%s|illusion=%s|option=%s|cost=%d|request=%s|result=refunded\n",
				time(),account_id,illusion_id,option,amount,request_id));
		}
		else{
			summary["ok"] = 0;
			summary["pending"] = (int)summary["pending"]+1;
			werror("[ILLUSION_REALM] 人物中心扩容恢复及退款等待重试: %s %s\n",
				account_id,request_id);
		}
	}
	return summary;
}

mapping(string:mixed) purchase_account_character_expansion(
	string requested_id,string option,string request_id)
{
	mapping status = query_public_status();
	string account_id = ACCOUNT_CHARACTERD->
		query_account_id_for_character(requested_id);
	mapping account_data;
	mapping debit;
	mapping grant;
	mapping expansion;
	array requests;
	string reason;
	int cost;
	int cleanup_ok;
	if(!account_id || account_id=="" || !(int)status["ok"] ||
	   !(int)status["entitlement_open"])
		return (["ok":0,"message":"当前未开放幻境人物栏位扩充。"]) ;
	if(search(({"one","all"}),option)==-1 ||
	   !valid_sha256_hex(request_id))
		return (["ok":0,"message":"幻境栏位扩充请求无效。"]) ;
	reconcile_account_character_expansions(account_id);
	account_data = ACCOUNT_CHARACTERD->query_account_characters(account_id,
		(string)status["illusion_id"]);
	if(!(int)account_data["ok"])
		return (["ok":0,"message":"账号索引暂不可验证，本次未扣除碎玉。"]) ;
	if(!(int)account_data["illusion_entitled"])
		return (["ok":0,"message":"请先登记"+
			(string)status["illusion_id"]+
			"赛季资格；登记不扣费，每个人物栏位100碎玉。"]) ;
	requests = arrayp(account_data["illusion_expansion_requests"]) ?
		(array)account_data["illusion_expansion_requests"] : ({});
	if(search(requests,request_id)!=-1)
		return (["ok":1,"already":1,
			"message":"本次栏位扩充已经完成，请继续创建人物。"]) ;
	cost = option=="one" ?
		(int)status["extra_character_slot_cost_suiyu"] :
		(int)status["multi_character_unlock_cost_suiyu"];
	if(cost<=0 || cost>500 || cost%100!=0)
		return (["ok":0,"message":"幻境栏位价格异常，本次未扣款。"]) ;
	reason = account_expansion_reason((string)status["illusion_id"],option);
	debit = ACCOUNT_WALLETD->debit_account_recharge_once(account_id,cost,
		reason,request_id);
	if(!(int)debit["ok"])
		return (["ok":0,"message":(string)(debit["message"] ||
			"账号共享充值余额扣款失败。")+
			" 人物中心不会消费任何人物背包玉石。"]) ;
	grant = ACCOUNT_CHARACTERD->grant_illusion_character_expansion(
		account_id,(string)status["illusion_id"],option,request_id,cost);
	if(!(int)grant["ok"] ||
	   ((int)grant["already"] && !(int)grant["same_request"])){
		int refunded = ACCOUNT_WALLETD->rollback_account_debit_recharge_once(
			account_id,request_id,"illusion_account_expansion_failed");
		return (["ok":0,"message":refunded ?
			"栏位状态已变化，本次共享余额已原路退回。" :
			"栏位写入及退款异常，请立即联系管理员。"]) ;
	}
	expansion = mappingp(grant["expansion"]) ?
		(mapping)grant["expansion"] : ([]);
	cleanup_ok = ACCOUNT_WALLETD->forget_account_debit_recharge_once(
		account_id,request_id);
	safe_append_illusion_log(sprintf("%d|account_character_expansion|account=%s|option=%s|cost=%d|spent=%d|slots=%d|multi=%d|request=%s|cleanup=%d\n",
		time(),account_id,option,cost,
		(int)expansion["expansion_spent_suiyu"],
		(int)expansion["character_slots"],
		(int)expansion["multi_character_unlocked"],request_id,cleanup_ok));
	return (["ok":1,"already":(int)debit["duplicate"],
		"message":(string)grant["message"]+" 已从账号共享充值余额支付"+
			cost+"碎玉，可直接继续创建职业。",
		"cleanup_pending":!cleanup_ok,
		"entitlement":copy_value(expansion)]);
}

mapping(string:mixed) purchase_character_expansion(object player,string option)
{
	mapping status = query_public_status();
	mapping account_data;
	mapping grant;
	mapping entitlement;
	string account_id;
	string request_id;
	int cost;
	int before_wallet;
	int before_physical;
	if(!player || !(int)status["ok"] || !(int)status["entitlement_open"])
		return (["ok":0,"message":"当前未开放幻境人物栏位扩充。"]) ;
	if(search(({"one","all"}),option)==-1)
		return (["ok":0,"message":"请选择购买1格或一次购买5格。"]) ;
	account_id = (string)player->query_account_owner();
	account_data = ACCOUNT_CHARACTERD->query_account_characters(account_id,
		(string)status["illusion_id"]);
	if(!(int)account_data["ok"])
		return (["ok":0,
			"message":"账号索引暂不可验证，本次未扣除碎玉。"]) ;
	if(!(int)account_data["illusion_entitled"])
		return (["ok":0,"message":"请先登记"+
			(string)status["illusion_id"]+
			"赛季资格；登记不扣费，每个人物栏位100碎玉。"]) ;
	cost = option=="one" ?
		(int)status["extra_character_slot_cost_suiyu"] :
		(int)status["multi_character_unlock_cost_suiyu"];
	if(cost<=0 || cost>500 || cost%100!=0)
		return (["ok":0,
			"message":"幻境栏位价格异常，本次未扣款。"]) ;
	if((mappingp(player[ILLUSION_PAYMENT_ROOT]) &&
	   sizeof((mapping)player[ILLUSION_PAYMENT_ROOT])) ||
	   (mappingp(player[ILLUSION_EXPANSION_PAYMENT_ROOT]) &&
	   sizeof((mapping)player[ILLUSION_EXPANSION_PAYMENT_ROOT])))
		return (["ok":0,
			"message":"上一笔幻境交易仍在恢复，请重新登录后再试。"]) ;
	before_wallet = ACCOUNT_WALLETD->query_balance(player);
	before_physical = YUSHID->query_physical_all_num(player);
	{
		object request_hash = Crypto.SHA256();
		request_hash->update(account_id+"|"+(string)player->query_name()+"|"+
			option+"|"+(string)time()+"|"+String.string2hex(
				Crypto.Random.random_string(16)));
		request_id = lower_case(String.string2hex(request_hash->digest()));
	}
	player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([
		"version":1,"phase":"prepared","request_id":request_id,
		"account_id":account_id,
		"illusion_id":(string)illusion_config["current_id"],
		"option":option,"cost":cost,"before_wallet":before_wallet,
		"before_physical":before_physical,"created_at":time(),
	]);
	if(!player->save_with_result()){
		player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
		return (["ok":0,"message":"扩容凭据保存失败，本次未扣除碎玉。"]) ;
	}
	if(!YUSHID->pay_yushi(player,cost)){
		player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		return (["ok":0,"message":"碎玉不足或扣款失败，幻境栏位未改变。"]) ;
	}
	player[ILLUSION_EXPANSION_PAYMENT_ROOT]["phase"] = "charged";
	if(!player->save_with_result()){
		int refunded = YUSHID->rollback_yushi_payment(player,before_wallet,
			before_physical,"illusion_expansion_charge_save_failed");
		if(refunded){
			player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":0,"message":refunded ?
			"扣款存档失败，碎玉已原路退回。" :
			"扣款存档与退款异常，请立即联系管理员。"]) ;
	}
	grant = ACCOUNT_CHARACTERD->grant_illusion_character_expansion(
		account_id,(string)status["illusion_id"],option,request_id,cost);
	if(!(int)grant["ok"] ||
	   ((int)grant["already"] && !(int)grant["same_request"])){
		int refunded = YUSHID->rollback_yushi_payment(player,before_wallet,
			before_physical,"illusion_expansion_failed");
		if(refunded){
			player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":0,"message":refunded ?
			"栏位状态已变化，本次碎玉已原路退回。" :
			"栏位写入及退款异常，请立即联系管理员。"]) ;
	}
	entitlement = mappingp(grant["expansion"]) ?
		(mapping)grant["expansion"] : ([]);
	player[ILLUSION_EXPANSION_PAYMENT_ROOT]["phase"] = "committed";
	player->save_with_result();
	player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
	int cleanup_saved = player->save_with_result();
	safe_append_illusion_log(sprintf("%d|character_expansion|account=%s|character=%s|option=%s|cost=%d|spent=%d|slots=%d|multi=%d|request=%s|cleanup=%d\n",
		time(),account_id,(string)player->query_name(),option,cost,
		(int)entitlement["expansion_spent_suiyu"],
		(int)entitlement["character_slots"],
		(int)entitlement["multi_character_unlocked"],request_id,
		cleanup_saved));
	return (["ok":1,"already":0,
		"message":(string)grant["message"]+" 本次支付"+cost+
			"碎玉，累计已计入"+
			(int)entitlement["expansion_spent_suiyu"]+"碎玉。",
		"entitlement":copy_value(entitlement)]);
}

private void reconcile_entitlement_purchase(object player)
{
	mapping payment;
	mapping account_data;
	int refunded;
	if(!player)
		return;
	payment = player[ILLUSION_PAYMENT_ROOT];
	if(!mappingp(payment) || !sizeof(payment))
		return;
	if((int)payment["version"]!=1 ||
	   (string)payment["account_id"]!=(string)player->query_account_owner() ||
	   search(({"prepared","charged","committed"}),
		(string)payment["phase"])==-1 ||
	   !valid_sha256_hex((string)payment["request_id"]) ||
	   !valid_identifier((string)payment["illusion_id"]) ||
	   (int)payment["cost"]<0 || (int)payment["cost"]>1000000 ||
	   (int)payment["created_at"]<=0 ||
	   (int)payment["created_at"]>time()+300 ||
	   (int)payment["before_wallet"]<0 ||
	   (int)payment["before_wallet"]>1000000000000 ||
	   (int)payment["before_physical"]<0){
		werror("[ILLUSION_REALM] 无效购买恢复凭据，已失败关闭: %s\n",
			(string)player->query_name());
		return;
	}
	account_data = ACCOUNT_CHARACTERD->query_account_characters(
		(string)player->query_account_owner(),
		(string)payment["illusion_id"]);
	if(!(int)account_data["ok"]){
		werror("[ILLUSION_REALM] 购买恢复等待账号索引修复: %s\n",
			(string)player->query_name());
		return;
	}
	if((int)account_data["illusion_entitled"] &&
	   mappingp(account_data["illusion_entitlement_cycle"]) &&
	   (string)account_data["illusion_entitlement_cycle"]["request_id"]==
		(string)payment["request_id"]){
		player[ILLUSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		return;
	}
	refunded = YUSHID->rollback_yushi_payment(player,
		(int)payment["before_wallet"],(int)payment["before_physical"],
		"illusion_entitlement_crash_recovery");
	if(refunded){
		player[ILLUSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		safe_append_illusion_log(sprintf("%d|entitlement_recovery|illusion=%s|account=%s|character=%s|result=refunded\n",
			time(),(string)payment["illusion_id"],
			(string)payment["account_id"],
			(string)player->query_name()));
	}
	else
		werror("[ILLUSION_REALM] 资格购买崩溃退款仍需重试: %s\n",
			(string)player->query_name());
}

private void reconcile_character_expansion_purchase(object player)
{
	mapping payment;
	mapping account_data;
	array requests;
	int refunded;
	if(!player)
		return;
	payment = player[ILLUSION_EXPANSION_PAYMENT_ROOT];
	if(!mappingp(payment) || !sizeof(payment))
		return;
	if((int)payment["version"]!=1 ||
	   (string)payment["account_id"]!=(string)player->query_account_owner() ||
	   search(({"prepared","charged","committed"}),
		(string)payment["phase"])==-1 ||
	   search(({"one","all"}),(string)payment["option"])==-1 ||
	   !valid_sha256_hex((string)payment["request_id"]) ||
	   !valid_identifier((string)payment["illusion_id"]) ||
	   (int)payment["cost"]<=0 || (int)payment["cost"]>500 ||
	   (int)payment["cost"]%100!=0 ||
	   (int)payment["created_at"]<=0 ||
	   (int)payment["created_at"]>time()+300 ||
	   (int)payment["before_wallet"]<0 ||
	   (int)payment["before_wallet"]>1000000000000 ||
	   (int)payment["before_physical"]<0){
		werror("[ILLUSION_REALM] 无效扩容恢复凭据，已失败关闭: %s\n",
			(string)player->query_name());
		return;
	}
	account_data = ACCOUNT_CHARACTERD->query_account_characters(
		(string)player->query_account_owner(),
		(string)payment["illusion_id"]);
	if(!(int)account_data["ok"]){
		werror("[ILLUSION_REALM] 扩容恢复等待账号索引修复: %s\n",
			(string)player->query_name());
		return;
	}
	requests = arrayp(account_data["illusion_expansion_requests"]) ?
		(array)account_data["illusion_expansion_requests"] : ({});
	if(search(requests,(string)payment["request_id"])!=-1){
		player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		return;
	}
	refunded = YUSHID->rollback_yushi_payment(player,
		(int)payment["before_wallet"],(int)payment["before_physical"],
		"illusion_expansion_crash_recovery");
	if(refunded){
		player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		safe_append_illusion_log(sprintf("%d|character_expansion_recovery|account=%s|character=%s|result=refunded\n",
			time(),(string)payment["account_id"],
			(string)player->query_name()));
	}
	else
		werror("[ILLUSION_REALM] 栏位扩容崩溃退款仍需重试: %s\n",
			(string)player->query_name());
}

private mapping(string:mixed) create_illusion_character_internal(
	string account_id,
	string race_id,string profession_id,string name_cn,string sex,
	string avatar_id,int test_bypass_phase)
{
	mapping status = query_public_status();
	mapping result;
	if(!config_valid || (!test_bypass_phase &&
	   (!(int)status["ok"] || !(int)status["creation_open"])))
		return (["ok":0,"message":(string)status["display_name"]+
			"当前不能创建人物。"]) ;
	result = ACCOUNT_CHARACTERD->create_character(account_id,race_id,
		profession_id,name_cn,sex,avatar_id,"illusion",
		(string)illusion_config["current_id"]);
	if((int)result["ok"]){
		result["realm_type"] = "illusion";
		result["illusion_id"] = (string)illusion_config["current_id"];
		result["message"] = (string)status["display_name"]+"人物创建成功。";
		safe_append_illusion_log(sprintf("%d|create|illusion=%s|account=%s|character=%s\n",
			time(),(string)illusion_config["current_id"],account_id,
			(string)result["character"]["id"]));
	}
	return result;
}

mapping(string:mixed) create_illusion_character(string account_id,
	string race_id,string profession_id,string name_cn,string sex,
	string avatar_id)
{
	return create_illusion_character_internal(account_id,race_id,
		profession_id,name_cn,sex,avatar_id,0);
}

mapping(string:mixed) create_illusion_character_for_test(string account_id,
	string race_id,string profession_id,string name_cn,string sex,
	string avatar_id)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !account_id ||
	   !has_prefix(account_id,"xd99testunitillusion"))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	return create_illusion_character_internal(account_id,race_id,
		profession_id,name_cn,sex,avatar_id,1);
}

void prepare_new_character(object player)
{
	mapping realm = query_realm_for_player(player);
	mapping progress;
	mapping old_progress;
	int needs_initial_snapshot;
	if(!player || !is_active_illusion_character(player) ||
	   (string)realm["illusion_id"]!=(string)illusion_config["current_id"])
		return;
	PERSONAL_DIFFICULTYD->refresh_player_scope(player);
	progress = player_progress(player,1);
	if(!ensure_current_chapter_counters(player,progress)){
		werror("[ILLUSION_REALM] 当前章节独立计数初始化失败: %s\n",
			(string)player->query_name());
		return;
	}
	old_progress = copy_value(progress);
	needs_initial_snapshot = !has_index(progress,"ranking_experience_start") ||
		(int)progress["ranking_experience_start"]<0;
	update_ranking_snapshot(player,progress);
	if(needs_initial_snapshot && !player->save_with_result()){
		player[ILLUSION_PROGRESS_ROOT+"/"+
			(string)illusion_config["current_id"]] = old_progress;
		werror("[ILLUSION_REALM] 初始排行榜快照保存失败并已回滚: %s\n",
			(string)player->query_name());
	}
	else if(!persist_ranking_snapshot(player,progress,
	   (string)illusion_config["current_id"]))
		werror("[ILLUSION_RANKING] 登录快照待后续补写: %s\n",
			(string)player->query_name());
	if(story_all_chapters_claimed(progress)){
		mapping completion=([]);
		mixed completion_err=catch{
			completion=ACCOUNT_CHARACTERD->
				record_illusion_story_completion(player,
					(string)illusion_config["current_id"]);
		};
		// 完成凭证是登录时的派生补写，不能把人物主档已可玩的登录流程
		// 变成失败。下次登录会再次幂等补写。
		if(completion_err || !mappingp(completion) || !(int)completion["ok"])
			werror("[ILLUSION_HIDDEN] 登录补写职业完成凭证失败: %s %s\n",
				(string)player->query_name(),completion_err ?
				describe_error(completion_err) :
				(string)(completion["message"] || "invalid completion result"));
	}
	if(!is_illusion_room_path((string)player->last_pos))
		player->last_pos = (string)illusion_config["entry_room"];
	if(!is_illusion_room_path((string)player->relife))
		player->relife = (string)illusion_config["entry_room"];
}

private int route_player(object player,string room_path)
{
	int moved;
	mixed err;
	if(!player || !valid_room_path(room_path) ||
	   Stdio.file_size(ROOT+room_path)<=0)
		return 0;
	player["/tmp/illusion_move_bypass"] = 1;
	// 传字符串让user::move先做Worker亲和性判断。若先在来源Worker
	// object-cast目标房间，会错误加载另一Worker拥有的房间与NPC。
	err = catch{ moved=player->move(ROOT+room_path); };
	player->m_delete_foruser("/tmp/illusion_move_bypass");
	return !err && moved;
}

mapping(string:mixed) enter_eternal_echo(object player,string illusion_id)
{
	mapping realm=query_realm_for_player(player);
	mapping config=content_config_for_id(illusion_id);
	string old_selected;
	if(!player || !(int)realm["ok"] || (int)realm["security_blocked"] ||
	   (string)realm["realm_type"]!="eternal")
		return (["ok":0,"message":"只有永恒服人物可以进入已关闭的幻境回响。"]);
	if(!content_cycle_closed(illusion_id) || !sizeof(config))
		return (["ok":0,"message":"该期幻境尚未结算，或内容归档不可验证。"]);
	if(functionp(player->query_in_combat) && player->query_in_combat())
		return (["ok":0,"message":"战斗中不能进入永恒回响。"]);
	if(functionp(player->query_autofight) &&
	   (string)player->query_autofight()=="enable")
		return (["ok":0,"message":"请先停止自动挂机再进入永恒回响。"]);
	old_selected=(string)(player["/plus/illusion_echo/selected_id"] || "");
	player["/plus/illusion_echo/selected_id"]=illusion_id;
	if(!player->save_with_result()){
		player["/plus/illusion_echo/selected_id"]=old_selected;
		return (["ok":0,"message":"回响选择保存失败，人物没有移动。"]);
	}
	if(!route_player(player,(string)config["entry_room"])){
		player["/plus/illusion_echo/selected_id"]=old_selected;
		player->save_with_result();
		return (["ok":0,"message":"进入回响失败，人物仍停留在原地。"]);
	}
	record_room_visit(player,environment(player));
	safe_append_illusion_log(sprintf(
		"%d|echo_enter|illusion=%s|user=%s\n",time(),illusion_id,
		(string)player->query_name()));
	return (["ok":1,"illusion_id":illusion_id,
		"message":"已进入【"+(string)config["display_name"]+
			"·永恒回响】；章回与套装均按原规则每个角色只结算一次。"]);
}

mapping(string:mixed) leave_eternal_echo(object player)
{
	mapping context=story_context(player);
	mapping realm=query_realm_for_player(player);
	mapping config;
	if(!player || !sizeof(context) || (string)context["mode"]!="echo" ||
	   (string)realm["realm_type"]!="eternal")
		return (["ok":0,"message":"当前不在永恒回响中。"]);
	config=(mapping)context["config"];
	if(functionp(player->query_in_combat) && player->query_in_combat())
		return (["ok":0,"message":"战斗中不能离开永恒回响。"]);
	if(functionp(player->query_autofight) &&
	   (string)player->query_autofight()=="enable")
		AUTOFIGHTD->stop_autofight(player);
	if(!route_player(player,(string)config["return_room"]))
		return (["ok":0,"message":"返回永恒主城失败，人物仍停留在原地。"]);
	return (["ok":1,"message":"已返回永恒服。"]);
}

private mapping(string:mixed) current_route_step(mapping progress)
{
	string path = (string)progress["path"];
	mapping marks = mappingp(progress["route_marks"]) ?
		(mapping)progress["route_marks"] : ([]);
	array(mapping(string:string)) targets = ({});
	if(path=="pioneer")
		targets = ({
			(["id":"mirror_moon","name":"观察倒月并取得水镜月印",
				"location":"倒月镜湖","room":"/gamelib/d/illusion_s1/mirror_lake.pike",
				"action":"explore"]),
			(["id":"hidden_core","name":"勘察星核并取得隐月星核",
				"location":"隐月环坑","room":"/gamelib/d/illusion_s1/hidden_crater.pike",
				"action":"explore"]),
			(["id":"returning_mark","name":"合印归真并取得归真月印",
				"location":"新月祭坛","room":"/gamelib/d/illusion_s1/newmoon_altar.pike",
				"action":"explore"]),
		});
	else if(path=="hunter")
		targets = ({
			(["id":"broken_star","name":"击败断桥镇星使",
				"location":"断星桥","room":"/gamelib/d/illusion_s1/star_bridge.pike",
				"action":"hunt","combat_name":"star_keeper.pike"]),
			(["id":"moon_guard","name":"击败月庭巡将",
				"location":"隐月环坑","room":"/gamelib/d/illusion_s1/hidden_crater.pike",
				"action":"hunt","combat_name":"moon_general.pike"]),
			(["id":"eclipse_priest","name":"击败无影司炉者",
				"location":"长生月炉","room":"/gamelib/d/illusion_s1/moon_immortality_furnace.pike",
				"action":"hunt","combat_name":"eclipse_priest.pike"]),
		});
	else if(path=="companion"){
		if((int)progress["team_kills"]<route_target(progress,path))
			return (["ok":1,"done":0,"id":"companion_team",
				"name":"与队友同房累计击杀"+
					(string)route_target(progress,path)+"只怪物",
				"location":"任意本期公共猎场","room":"","action":"team"]);
		return (["ok":1,"done":1]);
	}
	else
		return (["ok":0,"message":"尚未选择有效命途。"]);
	foreach(targets,mapping target)
		if(!(int)marks[(string)target["id"]] &&
		   !((string)target["id"]=="eclipse_priest" &&
		     (int)marks["newmoon_lord"])){
			mapping result = copy_value(target);
			result["ok"] = 1;
			result["done"] = 0;
			return result;
		}
	return (["ok":1,"done":1]);
}

mapping(string:mixed) query_route_step(object player)
{
	if(!player || !sizeof(story_context(player)))
		return (["ok":0,"message":"当前没有可进行的幻境命途。"]);
	return current_route_step(player_progress(player,1));
}

mapping(string:mixed) travel_to_route_target(object player)
{
	mapping context=story_context(player);
	mapping config;
	string illusion_id;
	mapping step;
	string room_path;
	string current_room;
	int moved;
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前不能使用命途终章直达。"]);
	config=(mapping)context["config"];
	illusion_id=(string)context["illusion_id"];
	step = current_route_step(player_progress(player,1));
	if(!(int)step["ok"] || (int)step["done"])
		return (["ok":(int)step["ok"],"done":(int)step["done"],
			"message":(int)step["done"] ? "命途终章目标已经全部完成。" :
				(string)step["message"]]);
	if((string)step["action"]=="team")
		return step+(["message":"请先组队，并与队友在同一期猎场打怪。"]);
	room_path = (string)step["room"];
	if(!is_content_room_path(config,room_path) || !valid_room_path(room_path) ||
	   Stdio.file_size(ROOT+room_path)<=0)
		return (["ok":0,"message":"命途目标地图校验失败，本次没有移动人物。"]);
	if(functionp(player->query_in_combat) && player->query_in_combat())
		return (["ok":0,"message":"战斗中不能切换命途目标，请结束战斗后重试。"]);
	if(functionp(player->query_autofight) &&
	   (string)player->query_autofight()=="enable")
		return (["ok":0,"message":"自动挂机仍在运行，请先停止后重试。"]);
	current_room = normalized_destination_path(environment(player));
	if(current_room==room_path)
		return step+(["already":1,"message":"你已经位于"+
			(string)step["location"]+"。下一步："+(string)step["name"]+"。"]);
	moved = route_player(player,room_path);
	if(!moved)
		return (["ok":0,"message":"前往"+(string)step["location"]+
			"失败，人物仍停留在原地。"]);
	safe_append_illusion_log(sprintf(
		"%d|route_travel|illusion=%s|user=%s|route=%s|target=%s|room=%s\n",
		time(),illusion_id,
		(string)player->query_name(),(string)player_progress(player,1)["path"],
		(string)step["id"],room_path));
	return step+(["message":"已经到达"+(string)step["location"]+
		"。下一步："+(string)step["name"]+"。"]);
}

/**
 * 数据驱动S1支线共用的安全传送入口。只接受当前内容配置内的静态房间，
 * 并复用 user::move() 的 Worker 亲和、租约和跨进程 handoff。
 */
mapping(string:mixed) travel_to_s1_feature_room(object player,
	string room_path,string feature_id)
{
	mapping context=story_context(player);
	mapping config;
	string current_room;
	if(!player || !sizeof(context) ||
	   (string)context["illusion_id"]!="S1")
		return (["ok":0,"message":"当前人物不能进入S1秘迹。"]) ;
	config=(mapping)context["config"];
	if(!feature_id || sizeof(feature_id)>96 || search(feature_id,"\n")!=-1 ||
	   !is_content_room_path(config,room_path) || !valid_room_path(room_path) ||
	   Stdio.file_size(ROOT+room_path)<=0)
		return (["ok":0,"message":"秘迹目标校验失败，人物没有移动。"]) ;
	if(functionp(player->query_in_combat) && player->query_in_combat())
		return (["ok":0,"message":"战斗中不能切换秘迹地点，请先结束战斗。"]) ;
	if(functionp(player->query_autofight) &&
	   (string)player->query_autofight()=="enable")
		AUTOFIGHTD->stop_autofight(player);
	current_room=normalized_destination_path(environment(player));
	if(current_room==room_path){
		record_room_visit(player,environment(player));
		return (["ok":1,"already":1,"message":"你已经位于秘迹目标地点。"]) ;
	}
	if(!route_player(player,room_path))
		return (["ok":0,"message":"前往秘迹失败，人物仍停留在原地。"]) ;
	safe_append_illusion_log(sprintf(
		"%d|feature_travel|illusion=S1|user=%s|feature=%s|room=%s\n",
		time(),(string)player->query_name(),feature_id,room_path));
	return (["ok":1,"message":"已经前往秘迹目标地点；到达不会自动完成观察或领取。"]) ;
}

mapping(string:mixed) travel_to_chapter_target(object player,
	int chapter_number)
{
	mapping context=story_context(player);
	mapping config;
	string illusion_id;
	mapping progress;
	mapping chapter;
	string target_room;
	string location;
	string target_name;
	string current_room;
	int current_number;
	int moved;
	if(!player || !sizeof(context))
		return (["ok":0,"message":"当前没有可直达的幻境章节。"]);
	config=(mapping)context["config"];
	illusion_id=(string)context["illusion_id"];
	progress = query_player_progress(player);
	if(!(int)progress["ok"] || !arrayp(progress["chapters"]))
		return (["ok":0,"message":"章节进度暂不可验证，本次没有移动人物。"]);
	current_number = (int)progress["chapter_claimed"]+1;
	if(chapter_number!=current_number || chapter_number<1 ||
	   chapter_number>sizeof((array)progress["chapters"]))
		return (["ok":0,"message":"只能直达当前正在进行的章节，不能越章或借旧章节传送。"]);
	chapter = ((array)progress["chapters"])[chapter_number-1];
	target_room = (string)chapter["target_room"];
	location = (string)chapter["target_location"];
	target_name = (string)chapter["target_name"];
	if(target_room=="" || !is_content_room_path(config,target_room) ||
	   !valid_room_path(target_room) || Stdio.file_size(ROOT+target_room)<=0)
		return (["ok":0,"message":"当前目标需要先完成等待、择印或命途条件，暂时没有可直达地点。"]);
	if(functionp(player->query_in_combat) && player->query_in_combat())
		return (["ok":0,"message":"战斗中不能使用章节直达，请先结束当前战斗。"]);
	if(functionp(player->query_autofight) &&
	   (string)player->query_autofight()=="enable")
		return (["ok":0,"message":"自动挂机运行中，请先停止挂机再前往章节目标。"]);
	current_room = normalized_destination_path(environment(player));
	if(current_room==target_room){
		// 跨 Worker 落地的旧版本可能已经把人物放进目标房间，
		// 却跳过了 user::move() 的到访回调。重复点击章节直达时
		// 必须按当前真实房间补记，不能让探索章节永久停在 0/1。
		record_room_visit(player,environment(player));
		return (["ok":1,"already":1,"message":"你已经位于"+location+
			"。当前目标："+target_name+"。"]);
	}
	moved = route_player(player,target_room);
	if(!moved)
		return (["ok":0,"message":"前往"+location+
			"失败，人物仍停留在原地，请稍后重试。"]);
	safe_append_illusion_log(sprintf(
		"%d|chapter_travel|illusion=%s|user=%s|chapter=%d|room=%s\n",
		time(),illusion_id,
		(string)player->query_name(),chapter_number,target_room));
	return (["ok":1,"message":"正在前往"+location+"。当前目标："+
		target_name+"；传送不会代替击杀、探索或剧情结算。"]);
}

private string settlement_receipt(object player,mapping realm)
{
	array(string) inventory = ({});
	object hash = Crypto.SHA256();
	foreach(all_inventory(player),object item)
		if(item)
			inventory += ({(file_name(item)/"#")[0]});
	sort(inventory);
	hash->update((string)player->query_name()+"|"+
		(string)realm["illusion_id"]+"|"+
		(string)(int)realm["illusion_joined_at"]+"|"+(inventory*"\n"));
	return lower_case(String.string2hex(hash->digest()));
}

/** Caller owns the account runtime mutex for the entire receipt/index change. */
private mapping(string:mixed) settle_player_locked(object player,
	void|int test_bypass_phase)
{
	mapping realm = query_realm_for_player(player);
	mapping public_status = query_public_status();
	mapping result;
	mapping progress;
	string return_room;
	string receipt;
	mapping settlement_config;
	int current_cycle;
	int prior_cycle_closed;
	array(string) post_commit_warnings=({});
	if(!player)
		return (["ok":0,"message":"幻境人物对象无效，未执行回归。"]) ;
	if(getenv("XIAND_RUN_TESTUNIT")=="1" &&
	   is_test_illusion_player(player) &&
	   (int)player["/tmp/illusion_settle_throw_for_test"])
		error("forced settlement exception for lock safety test\n");
	if(!(int)realm["ok"] || (int)realm["security_blocked"])
		return (["ok":0,"message":(string)(realm["message"] ||
			"世界归属暂不可验证，未执行回归。")]);
	if((string)realm["realm_type"]!="illusion" ||
	   (string)realm["illusion_state"]!="active")
		return (["ok":1,"already":1,"message":"当前人物无需回归。"]) ;
	current_cycle = (string)realm["illusion_id"]==
		(string)public_status["illusion_id"];
	prior_cycle_closed = search((array)public_status["closed_ids"],
		(string)realm["illusion_id"])!=-1;
	if(!test_bypass_phase && !prior_cycle_closed && (!current_cycle ||
	   ((string)public_status["phase"]!="settling" &&
	    (string)public_status["phase"]!="closed")))
		return (["ok":0,"message":(string)realm["illusion_id"]+
			"尚未进入回归结算。"]) ;
	settlement_config=content_config_for_id((string)realm["illusion_id"]);
	return_room = (string)(settlement_config["return_room"] ||
		illusion_config["return_room"]);
	receipt = settlement_receipt(player,realm);
	progress = player_progress_for_id(player,
		(string)realm["illusion_id"],1);
	update_ranking_snapshot(player,progress);
	progress["settlement_prepared_at"] = time();
	progress["settlement_receipt"] = receipt;
	player->last_pos = return_room;
	if(!player->save_with_result())
		return (["ok":0,"message":"回归前人物存档失败，未切换世界。"]) ;
	if(!persist_ranking_snapshot(player,progress,
	   (string)realm["illusion_id"]))
		werror("[ILLUSION_RANKING] 回归快照待后续补写: %s\n",
			(string)player->query_name());
	result = ACCOUNT_CHARACTERD->settle_illusion_character(
		(string)player->query_name(),(string)realm["illusion_id"],receipt);
	if(!(int)result["ok"])
		return result;
	// 从这里起账号索引已经原子提交，任何会话刷新、补存档、传送或
	// 审计日志异常都不能把“已成功回归”误报成失败并诱导玩家重复操作。
	mixed post_err=catch{
		if(getenv("XIAND_RUN_TESTUNIT")=="1" &&
		   is_test_illusion_player(player) &&
		   (int)player["/tmp/illusion_settle_post_commit_throw_for_test"])
			error("forced post-commit refresh exception for test\n");
		PERSONAL_DIFFICULTYD->refresh_player_scope(player);
	};
	if(post_err){
		post_commit_warnings+=({"difficulty_scope"});
		// 下次战斗查询会依据已经提交的账号索引重新证明作用域。
		player->m_delete_foruser("/tmp/personal_difficulty_scope");
	}
	progress["returned_at"] = time();
	int post_saved;
	post_err=catch{ post_saved=player->save_with_result(); };
	if(post_err || !post_saved)
		post_commit_warnings+=({"returned_at_save"});
	int post_routed;
	post_err=catch{ post_routed=route_player(player,return_room); };
	if(post_err || !post_routed)
		post_commit_warnings+=({"live_route"});
	post_err=catch{
		safe_append_illusion_log(sprintf(
			"%d|settle|illusion=%s|account=%s|character=%s|receipt=%s|warnings=%s\n",
			time(),(string)realm["illusion_id"],(string)realm["account_id"],
			(string)player->query_name(),receipt,post_commit_warnings*","));
	};
	if(post_err)
		werror("[ILLUSION_REALM] 回归已提交但审计日志补写失败: user=%s error=%s\n",
			(string)player->query_name(),describe_error(post_err));
	return (["ok":1,"message":(string)realm["illusion_id"]+
		"人物与可携装备已随唯一原档案安全回归永恒服。"+
		(sizeof(post_commit_warnings) ?
		 " 部分当前会话画面将在刷新或下次登录后补齐。" : ""),
		"receipt":receipt,"post_commit_degraded":
			sizeof(post_commit_warnings)>0,
		"post_commit_warnings":post_commit_warnings]);
}

/** 将底层存档/索引异常收敛为可重试结果，禁止异常穿透登录或自动结算。 */
private mapping(string:mixed) settle_player_locked_safely(object player,
	void|int test_bypass_phase)
{
	mapping result=([]);
	mixed settle_err=catch{
		result=settle_player_locked(player,test_bypass_phase);
	};
	if(settle_err || !mappingp(result)){
		// ACCOUNT_CHARACTERD 是回归是否提交的权威来源。若底层在原子
		// 提交之后才抛异常，不能误报失败并诱导重复结算；反查已经是
		// returned 的唯一原档案时，明确返回“成功但当前会话待刷新”。
		mapping authoritative=([]);
		mixed authoritative_err=catch{
			authoritative=query_realm_for_player(player);
		};
		if(!authoritative_err && mappingp(authoritative) &&
		   (int)authoritative["ok"] &&
		   (string)authoritative["realm_type"]=="eternal" &&
		   (string)authoritative["illusion_state"]=="returned"){
			return (["ok":1,"already":1,"post_commit_degraded":1,
				"post_commit_warnings":({"authoritative_recheck"}),
				"message":"回归已经由账号索引确认完成；当前画面将在刷新或下次登录后补齐。"]) ;
		}
		werror("[ILLUSION_REALM] 回归结算异常，下次重试将重查权威索引: user=%s error=%s\n",
			player && functionp(player->query_name) ?
			(string)player->query_name() : "",
			settle_err ? describe_error(settle_err) : "invalid result");
		return (["ok":0,"message":"回归结算暂时异常，人物档案与账号锁均已安全释放，请稍后重试。"]) ;
	}
	return result;
}

mapping(string:mixed) settle_player(object player)
{
	object account_key;
	mapping result=([]);
	mixed lock_err;
	if(!player || !functionp(player->query_name))
		return (["ok":0,"message":"幻境人物对象无效。"]);
	lock_err=catch{
		account_key = ACCOUNT_CHARACTERD->query_account_runtime_mutex(
			(string)player->query_name())->lock();
		result = settle_player_locked_safely(player);
	};
	if(account_key)
		destruct(account_key);
	if(lock_err)
		return (["ok":0,"message":"回归账号锁暂不可用，请稍后重试。"]) ;
	return result;
}

mapping(string:mixed) settle_player_for_test(object player)
{
	object account_key;
	mapping result=([]);
	mixed lock_err;
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	lock_err=catch{
		account_key = ACCOUNT_CHARACTERD->query_account_runtime_mutex(
			(string)player->query_name())->lock();
		result = settle_player_locked_safely(player,1);
	};
	if(account_key)
		destruct(account_key);
	if(lock_err)
		return (["ok":0,"message":"回归账号锁暂不可用，请稍后重试。"]) ;
	return result;
}

int reconcile_player_login(object player,void|int account_lock_held)
{
	mapping realm;
	mapping status;
	mapping result;
	string current_path;
	object account_key;
	int ready = 1;
	mixed reconcile_err;
	if(!player)
		return 0;
	reconcile_err=catch{
		if(!account_lock_held)
			account_key = ACCOUNT_CHARACTERD->query_account_runtime_mutex(
				(string)player->query_name())->lock();
		if(getenv("XIAND_RUN_TESTUNIT")=="1" &&
		   has_prefix((string)player->query_name(),"xd99testunit") &&
		   (int)player["/tmp/illusion_reconcile_throw_for_test"])
			error("forced login reconciliation exception for lock test\n");
		reconcile_entitlement_purchase(player);
		reconcile_character_expansion_purchase(player);
		realm = query_realm_for_player(player);
		if((int)realm["security_blocked"])
			ready = 0;
		status = query_public_status();
		current_path = normalized_destination_path(environment(player));
		if(ready && (string)realm["realm_type"]=="illusion" &&
		   (string)realm["illusion_state"]=="active"){
			if((string)realm["illusion_id"]!=
			   (string)status["illusion_id"]){
				if(search((array)status["closed_ids"],
				   (string)realm["illusion_id"])!=-1){
					result = settle_player_locked_safely(player);
					if(!(int)result["ok"])
						ready = 0;
				}
				else{
					werror("[ILLUSION_REALM] 未归档的旧幻境人物被冻结: %s %s\n",
						(string)player->query_name(),
						(string)realm["illusion_id"]);
					ready = 0;
				}
			}
			else if((string)status["phase"]=="active"){
				prepare_new_character(player);
				// 真登录稍后仍会按 last_pos 进入房间；这里不能抢先把合法
				// 的上次位置覆盖为营地。跨Worker到达本身不重复登录流程。
				if(is_illusion_room_path(current_path))
					record_room_visit(player,environment(player));
			}
			else if((string)status["phase"]=="settling" ||
			   (string)status["phase"]=="closed"){
				result = settle_player_locked_safely(player);
				if(!(int)result["ok"])
					ready = 0;
			}
		}
		else if(ready){
			string saved_content_id=content_id_for_room_path(
				normalized_destination_path((string)player->last_pos));
			if(saved_content_id!="" && !content_cycle_closed(saved_content_id)){
				mapping saved_config=content_config_for_id(saved_content_id);
				player->last_pos=(string)(saved_config["return_room"] ||
					illusion_config["return_room"]);
			}
		}
		if(ready)
			PERSONAL_DIFFICULTYD->refresh_player_scope(player);
	};
	if(account_key)
		destruct(account_key);
	if(reconcile_err){
		werror("[ILLUSION_REALM] 登录恢复异常，账号锁已释放并等待重试: user=%s error=%s\n",
			functionp(player->query_name) ? (string)player->query_name() : "",
			describe_error(reconcile_err));
		return 0;
	}
	return ready;
}

// 兼容旧方士调用；方士现已免费开放，与幻境资格无关。
int is_fangshi_unlocked(string account) { return account!=""; }
int unlock_fangshi(string account) { return account!="" ? 2 : 0; }
int can_create_fangshi(object player) { return player ? 0 : 1; }
int get_unlock_cost_jade_level() { return 0; }
string get_unlock_cost_desc() { return "免费"; }

protected void create()
{
	reload_config();
	load_runtime_state();
	call_out(lifecycle_automation_tick,2);
}
