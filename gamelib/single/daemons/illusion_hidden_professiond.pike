#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define STATE_PATH "/plus/illusion_realm/S1/zhaoming_trials"
#define TRIAL_LOG ROOT "/log/illusion_hidden_profession.log"
#define ILLUSION_TIMESTAMP_MAX 4102444800

private array(mapping(string:mixed)) volumes = ({
	(["title":"照雪问名","hunt_name":"逐光月灵","hunt_path":"/gamelib/clone/npc/illusion_s1/moon_wisp.pike","hunt_room":"/gamelib/d/illusion_s1/moon_dew_field.pike","hunt_rooms":({"/gamelib/d/illusion_s1/moon_dew_field.pike","/gamelib/d/illusion_s1/silver_reed_bank.pike","/gamelib/d/illusion_s1/starlight_slope.pike"}),"visit_name":"南瞻生死祠","visit_room":"/gamelib/d/illusion_s1/nanzhan_life_death_temple.pike","boss_name":"南瞻司寿使","boss_path":"/gamelib/clone/npc/illusion_s1/life_collector.pike"]),
	(["title":"雾誓同生","hunt_name":"雾纹月狼","hunt_path":"/gamelib/clone/npc/illusion_s1/fog_wolf.pike","hunt_room":"/gamelib/d/illusion_s1/mist_bamboo_glen.pike","hunt_rooms":({"/gamelib/d/illusion_s1/mist_bamboo_glen.pike","/gamelib/d/illusion_s1/cloud_pine_hollow.pike","/gamelib/d/illusion_s1/moonshadow_wood.pike"}),"visit_name":"雾林半药营","visit_room":"/gamelib/d/illusion_s1/fog_oath_camp.pike","boss_name":"雾誓守关者","boss_path":"/gamelib/clone/npc/illusion_s1/fog_trial_warden.pike"]),
	(["title":"空经见我","hunt_name":"镜丝月蛛","hunt_path":"/gamelib/clone/npc/illusion_s1/mirror_spider.pike","hunt_room":"/gamelib/d/illusion_s1/mirror_sandbar.pike","hunt_rooms":({"/gamelib/d/illusion_s1/mirror_sandbar.pike","/gamelib/d/illusion_s1/glasswater_bank.pike","/gamelib/d/illusion_s1/moonwave_shoal.pike"}),"visit_name":"西牛空经殿","visit_room":"/gamelib/d/illusion_s1/xiniu_empty_temple.pike","boss_name":"西牛空经尊者","boss_path":"/gamelib/clone/npc/illusion_s1/empty_sutra_abbot.pike"]),
	(["title":"碎镜照心","hunt_name":"折星石卫","hunt_path":"/gamelib/clone/npc/illusion_s1/ruin_guard.pike","hunt_room":"/gamelib/d/illusion_s1/astral_stonewood.pike","hunt_rooms":({"/gamelib/d/illusion_s1/broken_star_court.pike","/gamelib/d/illusion_s1/astral_stonewood.pike","/gamelib/d/illusion_s1/observatory_outfield.pike"}),"visit_name":"镜湖沉月渊","visit_room":"/gamelib/d/illusion_s1/mirror_depths.pike","boss_name":"沉月镜主","boss_path":"/gamelib/clone/npc/illusion_s1/mirror_weaver.pike"]),
	(["title":"不老有情","hunt_name":"古城星魇","hunt_path":"/gamelib/clone/npc/illusion_s1/star_wraith.pike","hunt_room":"/gamelib/d/illusion_s1/old_city_square.pike","hunt_rooms":({"/gamelib/d/illusion_s1/echo_battlement.pike","/gamelib/d/illusion_s1/old_city_square.pike","/gamelib/d/illusion_s1/stardust_lane.pike"}),"visit_name":"北俱冻龄宫","visit_room":"/gamelib/d/illusion_s1/beiju_frozen_palace.pike","boss_name":"北俱冻龄王","boss_path":"/gamelib/clone/npc/illusion_s1/frozen_age_king.pike"]),
	(["title":"雪审还名","hunt_name":"渊花异兽","hunt_path":"/gamelib/clone/npc/illusion_s1/abyss_beast.pike","hunt_room":"/gamelib/d/illusion_s1/deepmoon_valley.pike","hunt_rooms":({"/gamelib/d/illusion_s1/abyss_flower_sea.pike","/gamelib/d/illusion_s1/deepmoon_valley.pike","/gamelib/d/illusion_s1/starfall_garden.pike"}),"visit_name":"冻宫雪审殿","visit_room":"/gamelib/d/illusion_s1/frozen_judgment_hall.pike","boss_name":"冻宫雪审使","boss_path":"/gamelib/clone/npc/illusion_s1/frost_inquisitor.pike"]),
	(["title":"人间定命","hunt_name":"渊花异兽","hunt_path":"/gamelib/clone/npc/illusion_s1/abyss_beast.pike","hunt_room":"/gamelib/d/illusion_s1/deepmoon_valley.pike","hunt_rooms":({"/gamelib/d/illusion_s1/abyss_flower_sea.pike","/gamelib/d/illusion_s1/deepmoon_valley.pike","/gamelib/d/illusion_s1/starfall_garden.pike"}),"visit_name":"新月归真台","visit_room":"/gamelib/d/illusion_s1/newmoon_altar.pike","boss_name":"S1归真月主","boss_path":"/gamelib/clone/npc/illusion_s1/newmoon_lord.pike"]),
});

private array(string) reward_templates = ({
	"weapon/69zhaomingmingjian/69zhaomingmingjian",
	"armor/69zhaomingmingguan/69zhaomingmingguan",
	"armor/69zhaomingmingyi/69zhaomingmingyi",
	"armor/69zhaomingmingshou/69zhaomingmingshou",
	"armor/69zhaomingmingwan/69zhaomingmingwan",
	"armor/69zhaomingmingku/69zhaomingmingku",
	"armor/69zhaomingminglv/69zhaomingminglv",
	"jewelry/69zhaomingmingjie/69zhaomingmingjie",
	"jewelry/69zhaomingmingshuo/69zhaomingmingshuo",
	"jewelry/69zhaomingmingpei/69zhaomingmingpei",
});

private array(mapping(string:string)) volume_skills = ({
	(["id":"minghenjian","name":"命痕剑"]),
	(["id":"wushengyin","name":"无声印"]),
	(["id":"kongjingzhao","name":"空经照"]),
	(["id":"suijingyue","name":"碎镜月"]),
	(["id":"youqingxue","name":"有情血"]),
	(["id":"huanminghuo","name":"还命火"]),
	(["id":"rendingrenjian","name":"人定人间"]),
});

private string normalized_path(mixed value)
{
	string path="";
	if(objectp(value)) path=file_name(value);
	else if(stringp(value)) path=(string)value;
	if(has_prefix(path,ROOT)) path=path[sizeof(ROOT)..];
	if(search(path,"#")!=-1) path=(path/"#")[0];
	return path;
}

private int route_player(object player,string room_path)
{
	int moved;
	mixed err;
	if(!player || !has_prefix(room_path,"/gamelib/d/illusion_s1/") ||
	   search(room_path,"..")!=-1 || Stdio.file_size(ROOT+room_path)<=0)
		return 0;
	// 与S1主线使用同一跨Worker传送契约：先交给user::move判断房间亲和性，
	// 不能在来源Worker预加载另一节点拥有的房间对象。
	player["/tmp/illusion_move_bypass"] = 1;
	err=catch{ moved=player->move(ROOT+room_path); };
	player->m_delete_foruser("/tmp/illusion_move_bypass");
	return !err && moved;
}

private int eligible_player(object player)
{
	mapping realm=([]);
	mixed realm_err;
	if(!player || !functionp(player->query_profeId) ||
	   (string)player->query_profeId()!="zhaoming")
		return 0;
	// 账号索引异常时失败关闭到“不可进入”，不要让四十九难页面抛错或
	// 把未知归属误当成S1；人物唯一档案完全不写入。
	realm_err=catch{
		realm=ACCOUNT_CHARACTERD->query_character_realm(
			(string)player->query_name());
	};
	if(realm_err || !mappingp(realm))
		return 0;
	return (int)realm["ok"] && (string)realm["realm_type"]=="illusion" &&
		(string)realm["illusion_id"]=="S1" &&
		(string)realm["illusion_state"]=="active";
}

private mapping fresh_state()
{
	return (["version":1,"trial":1,"kills":0,"visited":0,
		"boss_kills":0,"claims":([]),"started_at":time(),
		"completed_at":0]);
}

private int valid_state(mixed raw)
{
	if(!mappingp(raw)) return 0;
	mapping state=(mapping)raw;
	mapping claims;
	int trial;
	if(sizeof(state)>10 || (int)state["version"]!=1 ||
	   !intp(state["trial"]) || !intp(state["kills"]) ||
	   !intp(state["visited"]) || !intp(state["boss_kills"]) ||
	   !intp(state["started_at"]) || !intp(state["completed_at"]) ||
	   !mappingp(state["claims"]))
		return 0;
	trial=(int)state["trial"];
	claims=(mapping)state["claims"];
	if((int)state["version"]==1 && trial>=1 &&
		(int)state["trial"]<=50 && (int)state["kills"]>=0 &&
		(int)state["kills"]<=1000 && (int)state["visited"]>=0 &&
		(int)state["visited"]<=1 && (int)state["boss_kills"]>=0 &&
		(int)state["boss_kills"]<=1 && (int)state["started_at"]>0 &&
		(int)state["started_at"]<=ILLUSION_TIMESTAMP_MAX &&
		(int)state["completed_at"]>=0 &&
		(int)state["completed_at"]<=ILLUSION_TIMESTAMP_MAX &&
		sizeof(claims)==trial-1 &&
		((trial==50) == ((int)state["completed_at"]>0)) &&
		(trial<50 || (!(int)state["kills"] && !(int)state["visited"] &&
		 !(int)state["boss_kills"])))
		for(int claimed=1;claimed<trial;claimed++){
			mixed timestamp=claims[(string)claimed];
			if(!intp(timestamp) || (int)timestamp<=0 ||
			   (int)timestamp>ILLUSION_TIMESTAMP_MAX)
				return 0;
		}
	else
		return 0;
	return 1;
}

private mapping player_state(object player,int create_if_missing)
{
	mixed raw=player ? player[STATE_PATH] : 0;
	if(valid_state(raw)) return (mapping)raw;
	if(raw || !player || !create_if_missing) return ([]);
	mapping state=fresh_state();
	player[STATE_PATH]=state;
	return state;
}

private mapping definition(int trial)
{
	if(trial<1 || trial>49) return ([]);
	int volume_index=(trial-1)/7;
	int step=(trial-1)%7+1;
	mapping volume=volumes[volume_index];
	mapping result=copy_value(volume);
	result["trial"]=trial; result["volume"]=volume_index+1;
	result["step"]=step; result["volume_title"]=(string)volume["title"];
	if(step<=5){
		result["kind"]="hunt";
		result["required"]=6+volume_index*3+step*2;
		result["target_name"]=(string)volume["hunt_name"];
		result["target_path"]=(string)volume["hunt_path"];
		result["target_room"]=(string)volume["hunt_room"];
	}
	else if(step==6){
		result["kind"]="visit"; result["required"]=1;
		result["target_name"]=(string)volume["visit_name"];
		result["target_room"]=(string)volume["visit_room"];
	}
	else{
		result["kind"]="boss"; result["required"]=1;
		result["target_name"]=(string)volume["boss_name"];
		result["target_path"]=(string)volume["boss_path"];
		result["target_room"]=(string)volume["visit_room"];
	}
	return result;
}

private int reward_index(int trial)
{
	if(trial==49) return 9;
	if(trial>=5 && trial<=45 && trial%5==0) return trial/5-1;
	return -1;
}

private mapping prerequisite(object player)
{
	mapping story=([]);
	mixed story_err;
	if(getenv("XIAND_RUN_TESTUNIT")=="1" && player &&
	   has_prefix((string)player->query_name(),"__testunit_zhaoming") &&
	   (int)player["/tmp/zhaoming_test_ready"])
		return (["ok":1,"message":""]);
	if(!eligible_player(player))
		return (["ok":0,"message":"只有本期S1照命人物可以进行四十九难。"]) ;
	story_err=catch{ story=SEASONALD->query_player_progress(player); };
	if(story_err || !mappingp(story))
		return (["ok":0,"message":"S1主线进度暂不可验证，本次不会写入四十九难档案。"]) ;
	if(!(int)story["ok"] || (int)story["chapter_claimed"]<81)
		return (["ok":0,"message":"请先由照命本人完成S1九卷八十一章。"]) ;
	if((int)player->query_level()<120)
		return (["ok":0,"message":"照命达到120级后，七卷四十九难才会开启。当前Lv"+
			(string)(int)player->query_level()+"/120。"]) ;
	return (["ok":1,"message":""]);
}

mapping(string:mixed) query_progress(object player)
{
	mapping gate=prerequisite(player);
	if(!(int)gate["ok"]) return gate+(["unlocked":0]);
	mapping state=player_state(player,1);
	if(!sizeof(state))
		return (["ok":0,"unlocked":1,"message":"四十九难存档不可验证，已停止写入以保护人物档案。"]) ;
	int trial=(int)state["trial"];
	if(trial==50)
		return (["ok":1,"unlocked":1,"completed":1,"trial":50,
			"message":"七卷四十九难已经全部完成，五命同辉十件套已完整授予。"]) ;
	mapping task=definition(trial);
	int done=(string)task["kind"]=="hunt" ? (int)state["kills"] :
		((string)task["kind"]=="visit" ? (int)state["visited"] :
		(int)state["boss_kills"]);
	return (["ok":1,"unlocked":1,"completed":0,"trial":trial,
		"volume":(int)task["volume"],"step":(int)task["step"],
		"volume_title":(string)task["volume_title"],
		"kind":(string)task["kind"],"target_name":(string)task["target_name"],
		"target_path":(string)task["target_path"],
		"target_room":(string)task["target_room"],
		"required":(int)task["required"],"done":min(done,(int)task["required"]),
		"ready":done>=(int)task["required"],
		"reward_index":reward_index(trial)]);
}

private void notify_ready(object player,int trial,string target_name)
{
	tell_object(player,"§y【照命·第"+(string)trial+"难完成】§r "+target_name+
		"目标已经达成。\n[领取并继续:illusion_hidden claim]|[查看四十九难:illusion_hidden]\n");
}

mapping(string:mixed) record_npc_kill(object player,object npc)
{
	mapping view=query_progress(player);
	object player_room=player ? environment(player) : 0;
	if(!(int)view["ok"] || (int)view["completed"] || (int)view["ready"] ||
	   search(({"hunt","boss"}),(string)view["kind"])==-1 || !npc ||
	   !player_room || environment(npc)!=player_room)
		return ([]);
	string credit_marker="/tmp/zhaoming_trial_credit/"+
		(string)player->query_name();
	if((int)npc[credit_marker])
		return (["ok":1,"duplicate":1]);
	string npc_path=normalized_path(npc);
	string room_path=normalized_path(player_room);
	if(npc_path!=(string)view["target_path"] ||
	   ((string)view["kind"]=="boss" &&
	    room_path!=(string)view["target_room"]))
		return ([]);
	if((string)view["kind"]=="hunt"){
		mapping task=definition((int)view["trial"]);
		if(search((array)task["hunt_rooms"],room_path)==-1)
			return ([]);
	}
	mapping state=player_state(player,0);
	mapping old_state=copy_value(state);
	if((string)view["kind"]=="hunt") state["kills"]=(int)state["kills"]+1;
	else state["boss_kills"]=(int)state["boss_kills"]+1;
	if(!player->save_with_result()){
		player[STATE_PATH]=old_state;
		return (["ok":0,"message":"照命试炼进度保存失败，本次击杀未计入。"]) ;
	}
	// 只有人物唯一档案成功提交后才封印本次死亡回调；存档失败仍允许
	// 这具 NPC 的权威死亡链重试，成功后则绝不重复推进。
	npc[credit_marker]=1;
	mapping after=query_progress(player);
	if((int)after["ready"]){
		notify_ready(player,(int)view["trial"],(string)view["target_name"]);
		if(mappingp(player["/tmp/zhaoming_trial_autofight"])){
			AUTOFIGHTD->stop_autofight(player);
			player->m_delete_foruser("/tmp/zhaoming_trial_autofight");
		}
	}
	return (["ok":1,"ready":(int)after["ready"]]);
}

mapping(string:mixed) record_room_visit(object player,object room)
{
	mapping view=query_progress(player);
	if(!(int)view["ok"] || (int)view["completed"] || (int)view["ready"] ||
	   (string)view["kind"]!="visit" || !room || !player ||
	   environment(player)!=room ||
	   normalized_path(room)!=(string)view["target_room"])
		return ([]);
	mapping state=player_state(player,0);
	mapping old_state=copy_value(state);
	state["visited"]=1;
	if(!player->save_with_result()){
		player[STATE_PATH]=old_state;
		return (["ok":0,"message":"照命试炼到访保存失败，本次探索未计入。"]) ;
	}
	notify_ready(player,(int)view["trial"],(string)view["target_name"]);
	return (["ok":1,"ready":1]);
}

mapping(string:mixed) claim(object player)
{
	mapping view=query_progress(player);
	if(!(int)view["ok"] || (int)view["completed"] || !(int)view["ready"])
		return (["ok":0,"message":(string)(view["message"] || "当前一难尚未完成。")]);
	mapping state=player_state(player,0);
	mapping old_state=copy_value(state);
	mapping old_skills=mappingp(player->skills) ? copy_value(player->skills) : ([]);
	object|zero reward=0;
	int index=reward_index((int)view["trial"]);
	string skill_name="";
	if(index>=0){
		mixed err=catch{ reward=clone(ITEM_PATH+reward_templates[index]); };
		if(err || !reward || ITEMSD->bind_newmoon_item_to_player(
		   reward,player,"choice")<1 || reward->move(player)!=1 ||
		   environment(reward)!=player){
			if(reward) destruct(reward);
			return (["ok":0,"message":"专属套装奖励发放失败，当前一难仍可重试领取。"]) ;
		}
	}
	if((int)view["trial"]%7==0){
		mapping skill=volume_skills[(int)view["trial"]/7-1];
		if(!mappingp(player->skills)) player->skills=([]);
		if(!player->skills[(string)skill["id"]])
			player->skills[(string)skill["id"]]=({1,0});
		skill_name=(string)skill["name"];
	}
	((mapping)state["claims"])[(string)(int)view["trial"]]=time();
	state["trial"]=(int)state["trial"]+1;
	state["kills"]=0; state["visited"]=0; state["boss_kills"]=0;
	if((int)state["trial"]==50) state["completed_at"]=time();
	if(!player->save_with_result()){
		if(reward) destruct(reward);
		player[STATE_PATH]=old_state;
		player->skills=old_skills;
		return (["ok":0,"message":"人物存档失败，试炼与奖励均未结算，可重试。"]) ;
	}
	// 到这里人物唯一档案已经成功提交；审计文件是附加记录，
	// 不能因磁盘瞬时异常让玩家收到空页并误以为奖励未结算。
	mixed log_err=catch{
		Stdio.append_file(TRIAL_LOG,sprintf(
			"%d|trial_claim|user=%s|trial=%d|reward=%s\n",
			time(),(string)player->query_name(),(int)view["trial"],
			reward ? (string)reward->query_name() : ""));
	};
	if(log_err)
		werror("[ILLUSION_HIDDEN] 试炼已提交但审计日志写入异常: user=%s trial=%d error=%s\n",
			(string)player->query_name(),(int)view["trial"],
			describe_error(log_err));
	return (["ok":1,"message":"第"+(string)(int)view["trial"]+"难已结算。"+
		(reward ? "获得："+(string)reward->query_name_cn()+"。" : "")+
		(skill_name!="" ? "领悟照命传承【"+skill_name+"】。" : ""),
		"reward":reward ? (string)reward->query_name_cn() : ""]);
}

mapping(string:mixed) navigate(object player)
{
	mapping view=query_progress(player);
	if(!(int)view["ok"] || (int)view["completed"] || (int)view["ready"])
		return (["ok":0,"message":"当前没有需要前往的试炼目标。"]) ;
	if(functionp(player->query_in_combat) && player->query_in_combat())
		return (["ok":0,"message":"请先结束战斗再前往试炼目标。"]) ;
	if(functionp(player->query_autofight) &&
	   (string)player->query_autofight()=="enable")
		return (["ok":0,"message":"请先停止自动挂机再前往试炼目标。"]) ;
	if(normalized_path(environment(player))==(string)view["target_room"]){
		record_room_visit(player,environment(player));
		return (["ok":1,"already":1,"message":"你已经位于"+
			(string)view["target_name"]+"所在区域。"]) ;
	}
	int moved=route_player(player,(string)view["target_room"]);
	if(moved)
		record_room_visit(player,environment(player));
	return moved ? (["ok":1,"message":"已前往"+
		(string)view["target_name"]+"所在区域。"]):
		(["ok":0,"message":"目标区域暂时无法到达，请稍后重试。"]) ;
}

mapping(string:mixed) start_hunt(object player)
{
	mapping view=query_progress(player);
	if(!(int)view["ok"] || (string)view["kind"]!="hunt" ||
	   (int)view["ready"])
		return (["ok":0,"message":"当前一难不是可挂机的狩猎目标。"]) ;
	player["/tmp/zhaoming_trial_autofight"]=([
		"trial":(int)view["trial"]
	]);
	AUTOFIGHTD->start_autofight(player);
	return (["ok":1,"message":"已开始挂机至第"+(string)(int)view["trial"]+
		"难狩猎完成；达标后自动停止并返回试炼提示。"]) ;
}

mapping(string:mixed) query_autofight_route(object player)
{
	if(!player || !mappingp(player["/tmp/zhaoming_trial_autofight"]))
		return ([]);
	mapping view=query_progress(player);
	if(!(int)view["ok"] || (string)view["kind"]!="hunt" ||
	   (int)view["ready"] ||
	   (int)((mapping)player["/tmp/zhaoming_trial_autofight"])["trial"]!=
		(int)view["trial"])
		return ([]);
	mapping task=definition((int)view["trial"]);
	array(string) paths=({});
	foreach((array)task["hunt_rooms"],string room)
		paths+=({room[sizeof("/gamelib/d/")..sizeof(room)-6]});
	return (["max":120,"level":min(69,(int)player->query_level()),
		"name":"照命第"+(string)(int)view["trial"]+"难·"+
			(string)view["target_name"],"path":paths[0],"paths":paths,
		"capacity":18,"total_capacity":sizeof(paths)*18,
		"target_min":1,"target_max":120]);
}

mapping(string:mixed) query_trial_definition_for_test(int trial)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1") return ([]);
	return definition(trial)+(["reward_index":reward_index(trial)]);
}

int query_timestamp_valid_for_test(mixed value)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return 0;
	return intp(value) && (int)value>=0 &&
		(int)value<=ILLUSION_TIMESTAMP_MAX;
}

int complete_current_target_for_test(object player)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !player ||
	   !has_prefix((string)player->query_name(),"__testunit_zhaoming") ||
	   !(int)player["/tmp/zhaoming_test_ready"])
		return 0;
	mapping view=query_progress(player);
	mapping state=player_state(player,0);
	if(!(int)view["ok"] || (int)view["completed"] || !sizeof(state))
		return 0;
	if((string)view["kind"]=="hunt")
		state["kills"]=(int)view["required"];
	else if((string)view["kind"]=="visit")
		state["visited"]=1;
	else
		state["boss_kills"]=1;
	return player->save_with_result();
}
