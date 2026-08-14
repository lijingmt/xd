#include <globals.h>
#include <command.h>
#include <wapmud2/include/wapmud2.h>
//城主被攻击需要调用这个程序里的通告模块
#define CITYD ((object)(ROOT "/gamelib/single/daemons/cityd"))
#define MANAGERD ((object)(ROOT "/gamelib/single/daemons/managed"))
#define SUMMOND ((object)(ROOT "/gamelib/single/daemons/summond.pike"))
#define PROFESSIONVIPD ((object)(ROOT "/gamelib/single/daemons/professionvipd.pike"))
#define LOGICALZONED ((object)(ROOT "/gamelib/single/daemons/logical_zoned.pike"))
#define PETD ((object)(ROOT "/gamelib/single/daemons/petd.pike"))
#define SPIRIT_COMPANIOND ((object)(ROOT "/gamelib/single/daemons/spirit_companiond.pike"))
#define DAILYGOALD ((object)(ROOT "/gamelib/single/daemons/daily_goald.pike"))
#define TIMED_EVENTD ((object)(ROOT "/gamelib/single/daemons/timed_eventd.pike"))
#define MAP_WORKERD ((object)(ROOT "/gamelib/single/daemons/map_workerd.pike"))
#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd.pike"))
#define ROOM_SKILL_EVENT_TTL 8
#define ROOM_SKILL_EVENT_MAX 6
#define PK_FAST_DECISION_TRIGGER_ROUNDS 90
#define PK_FAST_DECISION_SIMULATION_ROUNDS 1000
#define PK_FAST_DECISION_SCALE_MAX 16
private int tmp_heart_beat;
private int in_combat;
private mapping items;
//影射取种族职业类型表
protected mapping(string:int) profe_fight=([
		"jianxian":0,
		"yushi":1,
		"zhuxian":2,
		"kuangyao":3,
		"wuyao":4,
		"yinggui":5,
		"fangshi":6,
		"zhenyue":7,
		"tianxiang":6,
		"lingyi":6,
		"humanlike":6,
		"beast":7,
		"bird":8,
		"fish":9,
		"amphibian":10,
		"bugs":11
		]);

//技能仇恨加权映射表
private mapping(string:int) skills_hate=([
		"test":100,

		]);

//战斗描述//////////////////////////////////
//由liaocheng于07/1/11添加，用于战斗描述
protected mapping(string:array(string)) m_fight_desc=([
		"jian"  :({"一个直刺","一个横扫","一阵乱舞","一个斜砍"}),
		"dao"   :({"一个顺势斩","一顿猛砍","一个突进","一个单刀劈马"}),
		"qiang" :({"一个直刺","一个跟进","一个上挑","秋风扫落叶","一个回马枪"}),
		"gun"   :({"一个左横扫","当头一棒","施展群棍乱舞","一个直线突进"}),
		"bi"    :({"一个左刺","一个右刺","一个直刺","一个割首","一个断筋"}),
		"zhang" :({"一个猛击","一个横扫","迎面扑去","左右乱打"}),
		"chui"  :({"当头砸下","一个金刚抱拳","抡了过去","一计重压","一计震山敲虎"}),
		"fu"	:({"一个横扫","一顿狂砍","迎面砍下","使出一计破日月"}),
		"none"	:({"迎面一拳","一个左摆","一个直拳","呼呼带响"}),
		"beast" :({"疯狂撕咬","一个猛冲","一计爪击","发出刺耳吼叫"}),
		"bird"	:({"展翅扑打","一个俯冲","乱啄一气","乱抓一通"}),
		"fish"  :({"一个冲撞","一个尾部拍打","小咬一口"}),
		"amphibian"  :({"一个冲撞","一个尾部拍打","小咬一口"}),
		"bugs"  :({"一个冲撞","一个钉刺","小蜇一下","毒液喷射"})
		]);
//主要接口，由attack（）中的战斗描述代码调用
//在使用它之前，我们需要得到arg，即在_fight()中要添加相应的判断
string query_fight_desc(string arg) {  //arg 为上面影射表的index中的
	array(string) desc_tmp=m_fight_desc[arg];
	if(desc_tmp)
		return desc_tmp[random(sizeof(desc_tmp))];
	else
		return ("");
}
//获得arg的接口,对于人形生物我们返回need_weapon_type，在_fight()中再给出最终使用的武器类型
string query_fight_type() {
	string proId=this_object()->query_profeId();
	switch(profe_fight[proId]){
		case 0 .. 7:
			return("");
			break;
		default:
			return(proId);
			break;
	}
}
protected string fight_desc_arg_main="";//为空时表示不是人形，不为空时记录主手武器的所属类型
protected string fight_desc_arg_other="";//在fight_desc_arg_main为空时，记录副手武器的所属类型


// 战斗伤害////////////////////////////////
private int attack_weapon=0;
private int attack_huoyan_add=0;
private int attack_bingshuang_add=0;
private int attack_fengren_add=0;
private int attack_dusu_add=0;
private int defend = 0;
//////////////////////////////////////////

// 统一的伤害结算辅助接口。防御/抗性采用递减收益，避免高属性版本中
// 线性减伤直接把伤害压成1。穿透恢复为独立的无视防御伤害，但单次
// 最多取原始攻击的60%，防止BT装备上的极端旧数值绕过全部平衡规则。
int query_balanced_penetration_damage(int raw_attack,int penetration)
{
	int penetration_limit;
	if(raw_attack <= 0 || penetration <= 0)
		return 0;
	penetration_limit = raw_attack*60/100;
	if(penetration > penetration_limit)
		penetration = penetration_limit;
	return penetration;
}

int query_balanced_physical_damage(int raw_attack,int defend_power,
	int penetration)
{
	int result;
	if(raw_attack <= 0)
		return 1;
	if(defend_power < 0)
		defend_power = 0;
	result = raw_attack*raw_attack/(raw_attack+defend_power);
	result += query_balanced_penetration_damage(raw_attack,penetration);
	if(result < 1)
		result = 1;
	return result;
}

int query_balanced_magic_damage(int raw_attack,int magic_defend,
	int penetration)
{
	int result;
	if(raw_attack <= 0)
		return 1;
	if(magic_defend < 0)
		magic_defend = 0;
	result = raw_attack*400/(400+magic_defend);
	result += query_balanced_penetration_damage(raw_attack,penetration);
	if(result < 1)
		result = 1;
	return result;
}

// 稀有直伤对玩家和Boss保留单次生命百分比封顶；普通怪不封顶，避免
// 高等级玩家刷低级怪时反而被强制刮痧。
int query_rare_direct_damage(object skill,int damage,int target_life_max,
	int is_player,int is_boss)
{
	int cap_percent = 0;
	int damage_cap;
	if(damage<1)
		return damage;
	if(!skill || target_life_max<1)
		return damage;
	if(is_player && functionp(skill->query_rare_direct_pvp_cap_percent))
		cap_percent = skill->query_rare_direct_pvp_cap_percent();
	else if(is_boss && functionp(skill->query_rare_direct_boss_cap_percent))
		cap_percent = skill->query_rare_direct_boss_cap_percent();
	if(cap_percent<=0)
		return damage;
	damage_cap = target_life_max*cap_percent/100;
	if(damage_cap<1)
		damage_cap=1;
	return damage>damage_cap ? damage_cap : damage;
}

int query_rare_vital_floor(object skill,int skill_level,int life_max)
{
	int percent;
	if(!skill || life_max<=0 ||
	   !functionp(skill->query_rare_vital_percent))
		return 0;
	percent = skill->query_rare_vital_percent(skill_level);
	if(percent<=0)
		return 0;
	return life_max*percent/100;
}

int query_rare_control_floor(object skill,int skill_level,int current_value,
	int base_value)
{
	int percent;
	int scaled;
	if(base_value<0)
		base_value=0;
	if(!skill || current_value<=0 ||
	   !functionp(skill->query_rare_control_percent))
		return base_value;
	percent = skill->query_rare_control_percent(skill_level);
	scaled = current_value*percent/100;
	return scaled>base_value ? scaled : base_value;
}

// 旧大神DOT每跳最多为玩家0.4%、Boss 0.2%；太古传承分别为
// 0.55%和0.25%。普通怪每跳最多2%，但永不削弱技能原始固定值。
int query_rare_dot_damage(object skill,int skill_level,int base_damage,
	int offense,int target_life_max,int is_player,int is_boss)
{
	int percent;
	int result;
	int cap_basis_points = 200;
	int cap_damage;
	if(base_damage<1)
		base_damage=1;
	result=base_damage;
	if(!skill || offense<=0 ||
	   !functionp(skill->query_rare_dot_power_percent))
		return result;
	percent=skill->query_rare_dot_power_percent(skill_level);
	if(offense*percent/100>result)
		result=offense*percent/100;
	if(skill->skill_rare=="ancient"){
		if(is_player)
			cap_basis_points=55;
		else if(is_boss)
			cap_basis_points=25;
	}
	else if(skill->skill_rare=="mythic"){
		if(is_player)
			cap_basis_points=40;
		else if(is_boss)
			cap_basis_points=20;
	}
	else
		return base_damage;
	if(target_life_max>0){
		cap_damage=target_life_max*cap_basis_points/10000;
		if(cap_damage<base_damage)
			cap_damage=base_damage;
		if(result>cap_damage)
			result=cap_damage;
	}
	return result;
}

int query_physical_damage_after_percent_curse(int raw_attack,int reduction)
{
	if(raw_attack<1)
		return 1;
	if(reduction<0)
		reduction=0;
	if(reduction>60)
		reduction=60;
	return raw_attack*(100-reduction)/100;
}

private int query_rare_physical_offense(object caster)
{
	int result;
	int old_curse;
	int base_multiplier = 1;
	if(!caster)
		return 0;
	result=(caster->query_low_attack_desc()+
		caster->query_high_attack_desc())/2+
		caster->query_equip_add("attack_all");
	// 重复施放减攻时先还原同一诅咒槽的旧值，避免新快照基于已经
	// 被削弱的攻击继续缩水；双持描述会计算两份人物基础攻击。
	if(caster->query_debuff("curse",0)=="attack"){
		old_curse=(int)caster->query_debuff("curse",1);
		if(caster->query_equip_damage("base_main")>0 &&
		   caster->query_equip_damage("base_other")>0)
			base_multiplier=2;
		result += old_curse*base_multiplier;
	}
	if(result<1)
		result=1;
	return result;
}

private int query_rare_defense_snapshot(object target)
{
	int result;
	if(!target)
		return 0;
	result=target->query_defend_power();
	if(target->query_buff("buff",0)=="defend")
		result-=(int)target->query_buff("buff",1);
	if(target->query_debuff("curse",0)=="defend")
		result+=(int)target->query_debuff("curse",1);
	if(result<0)
		result=0;
	return result;
}

private int query_rare_magic_offense(object caster)
{
	int element;
	int current;
	int result;
	if(!caster)
		return 0;
	element=caster->query_equip_add("huo_mofa_attack");
	current=caster->query_equip_add("bing_mofa_attack");
	if(current>element)
		element=current;
	current=caster->query_equip_add("feng_mofa_attack");
	if(current>element)
		element=current;
	current=caster->query_equip_add("du_mofa_attack");
	if(current>element)
		element=current;
	result=element+caster->query_equip_add("mofa_all")+
		caster->query_think()*7/2;
	if(result<1)
		result=1;
	return result;
}

private int query_rare_dot_offense(object caster)
{
	if(!caster)
		return 0;
	if(search(({"jianxian","zhuxian","kuangyao","yinggui","zhenyue"}),
		caster->query_profeId())!=-1)
		return query_rare_physical_offense(caster);
	return query_rare_magic_offense(caster);
}

// 镇越的山河壁只作用于自己和同房间、同队、仍存活的玩家。
int apply_team_guard_to_group(object caster,int shield,int duration)
{
	int applied = 0;
	string team_id;
	object env;
	if(!caster || shield<=0 || duration<=0 || caster->get_cur_life()<=0)
		return 0;
	if(caster->apply_team_guard(shield,duration))
		applied++;
	team_id = caster->query_term();
	env = environment(caster);
	if(!env || team_id=="" || team_id=="noterm")
		return applied;
	foreach(all_inventory(env),object member){
		if(member==caster || !member->is("player") ||
		   member->query_term()!=team_id || member->get_cur_life()<=0 ||
		   !LOGICALZONED->can_action("team",caster,member))
			continue;
		if(member->apply_team_guard(shield,duration)){
			applied++;
			tell_object(member,caster->query_name_cn()+
				"展开山河壁，为你承受接下来的伤害。\n");
		}
	}
	return applied;
}

// 房间技能事件只是不落盘的UI快照。房间路径、Worker和玩家租约任一
// 发生变化都会使它失效，避免跨地图迁移后重放上一个房间的特效。
array(mapping(string:mixed)) query_room_skill_manifestations()
{
	array(mapping(string:mixed)) result = ({});
	mixed raw = this_object()["/tmp/combat/room_skill_events"];
	object env = environment(this_object());
	string room_path;
	string worker_id;
	int player_epoch;
	int now = time();
	if(!env || !arrayp(raw))
		return result;
	room_path = file_name(env);
	worker_id = MAP_WORKERD->query_local_worker_id();
	player_epoch = MAP_WORKERD->query_node_role()=="worker" ?
		MAP_WORKERD->query_local_player_epoch(this_object()->query_name()) : 0;
	foreach((array)raw,mixed candidate){
		mapping event;
		int event_at;
		if(!mappingp(candidate))
			continue;
		event = (mapping)candidate;
		event_at = (int)event["event_at"];
		if((string)event["id"]=="" || event_at<1 || event_at>now+1 ||
		   now-event_at>ROOM_SKILL_EVENT_TTL ||
		   (string)event["room_path"]!=room_path ||
		   (string)event["worker_id"]!=worker_id ||
		   (int)event["observer_epoch"]!=player_epoch)
			continue;
		result += ({copy_value(event)});
	}
	return result;
}

// 由房间所属Worker在施法时调用。入口再次校验同房、同逻辑区，
// 即使未来其他系统复用也不能伪造跨区技能表现。
int receive_room_skill_manifestation(mapping raw_event,object caster)
{
	object env = environment(this_object());
	array(mapping(string:mixed)) events;
	mapping(string:mixed) event;
	string room_path;
	string worker_id;
	int player_epoch;
	if(!mappingp(raw_event) || !caster || !env ||
	   environment(caster)!=env || caster==this_object() ||
	   !this_object()->is || !this_object()->is("player") ||
	   !caster->is || !caster->is("player") ||
	   !LOGICALZONED->is_visible(this_object(),caster))
		return 0;
	room_path = file_name(env);
	worker_id = MAP_WORKERD->query_local_worker_id();
	player_epoch = MAP_WORKERD->query_node_role()=="worker" ?
		MAP_WORKERD->query_local_player_epoch(this_object()->query_name()) : 0;
	if((string)raw_event["id"]=="" ||
	   sizeof((string)raw_event["id"])>192 ||
	   (int)raw_event["event_at"]<time()-1 ||
	   (int)raw_event["event_at"]>time()+1 ||
	   (string)raw_event["room_path"]!=room_path ||
	   (string)raw_event["worker_id"]!=worker_id ||
	   !stringp(raw_event["skill_name"]) ||
	   sizeof((string)raw_event["skill_name"])<1 ||
	   sizeof((string)raw_event["skill_name"])>120 ||
	   search((string)raw_event["skill_name"],"\n")!=-1 ||
	   sizeof((string)raw_event["target_name"])>120 ||
	   search((string)raw_event["target_name"],"\n")!=-1 ||
	   sizeof((string)raw_event["effect_desc"])>240 ||
	   search((string)raw_event["effect_desc"],"\n")!=-1 ||
	   (int)raw_event["skill_level"]<0 ||
	   (int)raw_event["skill_level"]>10000)
		return 0;
	event = ([
		"id":(string)raw_event["id"],
		"event_at":(int)raw_event["event_at"],
		"room_path":room_path,
		"worker_id":worker_id,
		"observer_epoch":player_epoch,
		"caster_userid":caster->query_name(),
		"caster_name":caster->query_name_cn(),
		"skill_name":(string)raw_event["skill_name"],
		"skill_level":(int)raw_event["skill_level"],
		"target_name":(string)raw_event["target_name"],
		"effect_desc":(string)raw_event["effect_desc"],
	]);
	events = query_room_skill_manifestations();
	foreach(events,mapping old_event)
		if((string)old_event["id"]==(string)event["id"])
			return 1;
	events += ({event});
	if(sizeof(events)>ROOM_SKILL_EVENT_MAX)
		events = events[sizeof(events)-ROOM_SKILL_EVENT_MAX..];
	this_object()["/tmp/combat/room_skill_events"] = events;
	return 1;
}

// 玩家成功施法后向同一逻辑区、同一房间的旁观玩家发送轻量事件。
// 结构化快照供Vue轮询，文案保留给旧JSP；两者都不参与战斗结算。
private void broadcast_room_skill_manifestation(object skill,object|zero target,
	int skill_level,string effect_desc)
{
	object caster = this_object();
	object env = environment(caster);
	string target_desc = "";
	string target_name = "";
	mapping(string:mixed) event;
	int event_seq;
	if(!caster || !skill || !env || !caster->is || !caster->is("player"))
		return;
	if(target && target!=caster && environment(target)==env &&
	   functionp(target->query_name_cn)){
		target_name = target->query_name_cn();
		target_desc = "，目标为"+target_name;
	}
	event_seq = (int)caster["/tmp/combat/room_skill_event_seq"]+1;
	caster["/tmp/combat/room_skill_event_seq"] = event_seq;
	event = ([
		"id":sprintf("%s-%d-%d-%d",caster->query_name(),time(),
			event_seq,random(1000000)),
		"event_at":time(),
		"room_path":file_name(env),
		"worker_id":MAP_WORKERD->query_local_worker_id(),
		"caster_userid":caster->query_name(),
		"caster_name":caster->query_name_cn(),
		"skill_name":skill->query_name_cn(),
		"skill_level":skill_level,
		"target_name":target_name,
		"effect_desc":effect_desc,
	]);
	catch {
		foreach(all_inventory(env),object observer){
			if(!observer || observer==caster || observer==target ||
			   !observer->is || !observer->is("player") ||
			   !LOGICALZONED->is_visible(observer,caster))
				continue;
			if(functionp(observer->receive_room_skill_manifestation))
				observer->receive_room_skill_manifestation(event,caster);
			tell_object(observer,"【战技显化】"+caster->query_name_cn()+
				"施放「"+skill->query_name_cn()+"」（等级"+skill_level+
				"）"+target_desc+
				(effect_desc!="" ? "，"+effect_desc : "")+"。\n");
		}
	};
}

// 韧性只削减暴击的额外 50% 部分，不能让暴击伤害低于普通伤害。
int query_balanced_critical_damage(int raw_attack,int renxing)
{
	int bonus_reduce_percent;
	int critical_bonus;
	if(raw_attack <= 0)
		return 1;
	if(renxing < 0)
		renxing = 0;
	bonus_reduce_percent = renxing/20;
	if(bonus_reduce_percent > 100)
		bonus_reduce_percent = 100;
	critical_bonus = raw_attack/2;
	return raw_attack+
		critical_bonus*(100-bonus_reduce_percent)/100;
}

// 闪避穿透以千分点保存：普攻最高 40%，主动物理技能最高 60%。
int query_balanced_dodge_penetration(int penetration,int is_skill_attack)
{
	int limit = is_skill_attack ? 600 : 400;
	if(penetration < 0)
		return 0;
	if(penetration > limit)
		return limit;
	return penetration;
}

// 血海裂伤使用万分点记录每个战斗节拍的最大生命伤害，Boss 每跳封顶
// 0.25%，完整持续时间最多约 3%，避免按 Boss 巨量生命无限放大。
int query_xuehai_dot_damage(int life_max,int basis_points,int is_boss)
{
	int result;
	if(life_max <= 0 || basis_points <= 0)
		return 1;
	if(is_boss && basis_points > 25)
		basis_points = 25;
	result = life_max*basis_points/10000;
	if(result < 1)
		result = 1;
	return result;
}

// 致残重伤按施法者自身最大生命成长。普通目标最多每跳损失1%，
// 玩家最多0.5%，Boss最多0.25%，避免高血量狂妖碾压低血量目标。
int query_kuangyao_wound_damage(int caster_life_max,int basis_points,
	int base_damage,int target_life_max,int is_player,int is_boss)
{
	int result;
	int scaled_damage;
	int limit_basis_points = 100;
	int limit_damage;
	if(base_damage < 1)
		base_damage = 1;
	result = base_damage;
	if(caster_life_max > 0 && basis_points > 0){
		scaled_damage = caster_life_max*basis_points/10000;
		if(scaled_damage > result)
			result = scaled_damage;
	}
	if(is_boss)
		limit_basis_points = 25;
	else if(is_player)
		limit_basis_points = 50;
	if(target_life_max > 0){
		limit_damage = target_life_max*limit_basis_points/10000;
		if(limit_damage < base_damage)
			limit_damage = base_damage;
		if(result > limit_damage)
			result = limit_damage;
	}
	if(result < 1)
		result = 1;
	return result;
}

// 统一计算人物主动持续伤害的每跳原始值。人物施法与灵宠拓印都读取
// 这个入口，确保血海裂伤、致残重伤及太古技能不会各自复制一份公式。
int query_active_dot_damage(object skill,int skill_level,object target)
{
	string name;
	int dot_damage;
	int is_boss;
	if(!skill || !target || !functionp(skill->query_performs_attack))
		return 0;
	if(skill_level<1)
		skill_level=1;
	name=(string)skill->query_name();
	dot_damage=(int)skill->query_performs_attack(skill_level);
	is_boss=target->is("npc") && target->_boss;
	if(name=="xuehailieshang")
		dot_damage=query_xuehai_dot_damage(target->query_life_max(),
			dot_damage,is_boss);
	else if(name=="zhicanzhongshang")
		dot_damage=query_kuangyao_wound_damage(
			this_object()->query_life_max(),
			(int)skill->query_performs_per(skill_level),dot_damage,
			target->query_life_max(),target->is("player"),is_boss);
	else if(functionp(skill->query_rare_dot_power_percent) &&
	   skill->query_rare_dot_power_percent(skill_level)>0)
		dot_damage=query_rare_dot_damage(skill,skill_level,dot_damage,
			query_rare_dot_offense(this_object()),target->query_life_max(),
			target->is("player"),is_boss);
	if(dot_damage<1)
		dot_damage=1;
	return dot_damage;
}

// 全游戏继续保留一个持续伤害槽，按“剩余总伤害”比较；等强技能可刷新，
// 弱技能不能延长或借用强技能快照，防止低级流血、队友毒伤覆盖强效果。
int query_dot_should_replace(string current_name,int current_damage,
	int current_time,string new_name,int new_damage,int new_time)
{
	if(new_name=="" || new_name=="none" ||
	   new_damage <= 0 || new_time <= 0)
		return 0;
	if(current_name=="" || current_name=="none" ||
	   current_damage <= 0 || current_time <= 0)
		return 1;
	return new_damage*new_time >= current_damage*current_time;
}

// 施法者对象只属于当前战斗进程。不能放入 dbase 的 /tmp：旧存档器会
// 序列化 data_tmp，可能把玩家/NPC对象引用写入人物档案。
private object|zero dot_source_runtime;
private string dot_source_runtime_name = "";
private int dot_nonlethal_runtime;

void set_dot_source_runtime(object|zero source,string name,
	void|int nonlethal)
{
	dot_source_runtime = source;
	dot_source_runtime_name = name || "";
	dot_nonlethal_runtime = nonlethal ? 1 : 0;
}

void clear_dot_source_runtime()
{
	dot_source_runtime = 0;
	dot_source_runtime_name = "";
	dot_nonlethal_runtime = 0;
}

int apply_nonstacking_dot(object target,string name,int damage,int duration,
	void|int nonlethal)
{
	string current_name;
	int current_damage;
	int current_time;
	if(!target)
		return 0;
	current_name = (string)target->query_debuff("dot",0);
	current_damage = (int)target->query_debuff("dot",1);
	current_time = (int)target->query_debuff("dot",2);
	if(!query_dot_should_replace(current_name,current_damage,current_time,
		name,damage,duration))
		return 0;
	target->set_debuff("dot",0,name);
	target->set_debuff("dot",1,damage);
	target->set_debuff("dot",2,duration);
	// 只保存当前成功覆盖者的私有运行时引用，用于每跳向真正施法者
	// 回报。名称必须与槽位一致，净化或下一次覆盖后不会串报。
	target->set_dot_source_runtime(this_object(),name,nonlethal);
	return 1;
}

private string query_dot_display_name(string name)
{
	object skill;
	if(!name || name=="" || name=="none")
		return "持续伤害";
	skill = MUD_SKILLSD[name];
	if(skill && functionp(skill->query_name_cn) && skill->query_name_cn()!="")
		return (string)skill->query_name_cn();
	return name;
}

/**
 * 结算一个持续伤害节拍。返回值供 TestUnit 和未来战斗状态接口核验；
 * 伤害、持续时间、山河壁吸收与死亡规则均沿用原逻辑，只补齐真实扣血
 * 的单一入口和施法者/受击者可见反馈。
 */
mapping(string:mixed) process_dot_tick()
{
	string dot_name = (string)this_object()->query_debuff("dot",0);
	int raw_damage = (int)this_object()->query_debuff("dot",1);
	int remaining = (int)this_object()->query_debuff("dot",2);
	mapping(string:mixed) result = ([
		"active":0,"name":dot_name,"display_name":"持续伤害",
		"raw_damage":raw_damage,"damage":0,"absorbed":0,
		"remaining":remaining,"defeated":0,"last_hit_guarded":0,
	]);
	object source;
	string source_name;
	string display_name;
	string damage_desc;
	int before_life;
	int post_guard_damage;
	int actual_damage;
	int after_life;
	if(dot_name=="" || dot_name=="none" || raw_damage<=0 || remaining<=0){
		if(dot_name!="none")
			this_object()->clean_debuff("dot");
		clear_dot_source_runtime();
		return result;
	}
	result["active"] = 1;
	display_name = query_dot_display_name(dot_name);
	result["display_name"] = display_name;
	source_name = dot_source_runtime_name;
	if(source_name==dot_name && objectp(dot_source_runtime))
		source = dot_source_runtime;
	before_life = this_object()->get_cur_life();
	post_guard_damage = this_object()->absorb_team_guard_damage(raw_damage);
	if(post_guard_damage<0)
		post_guard_damage = 0;
	actual_damage = post_guard_damage;
	if(actual_damage>before_life)
		actual_damage = before_life;
	// 灵宠协战不能代替主人完成最后一击，避免归属、掉落与PVP结算
	// 被后台持续伤害抢走；人物自身施放的持续伤害仍可正常击杀。
	if(dot_nonlethal_runtime && actual_damage>=before_life){
		actual_damage = before_life>1 ? before_life-1 : 0;
		result["last_hit_guarded"] = 1;
	}
	after_life = before_life-actual_damage;
	this_object()->set_life(after_life);
	remaining--;
	result["damage"] = actual_damage;
	// 过量致死伤害不是护盾吸收；这里只报告山河壁真正吞掉的部分。
	result["absorbed"] = raw_damage-post_guard_damage;
	result["remaining"] = remaining;
	if(remaining<=0){
		this_object()->clean_debuff("dot");
		clear_dot_source_runtime();
	}
	else
		this_object()->set_debuff("dot",2,remaining);

	if(actual_damage>0)
		damage_desc = "造成"+format_game_number(actual_damage)+"点持续伤害";
	else if(result["last_hit_guarded"])
		damage_desc = "本跳未结算，灵宠为主人保留最后一击";
	else
		damage_desc = "本跳"+format_game_number(raw_damage)+
			"点伤害被山河壁完全吸收";
	if(source && source!=this_object())
		tell_object(source,"【持续伤害】你的"+display_name+"对"+
			this_object()->query_name_cn()+damage_desc+"（剩余"+remaining+
			"个战斗节拍）。\n");
	if(this_object()->is("player"))
		tell_object(this_object(),"【持续伤害】"+display_name+"对你"+
			damage_desc+"（剩余"+remaining+"个战斗节拍）。\n");

	if(after_life<=0){
		result["defeated"] = 1;
		if(enemy && objectp(enemy))
			enemy->clean_targets(this_object());
		if(zero_type(find_call_out(dot_death)))
			call_out(dot_death,0);
	}
	return result;
}

private int killing;
private int autoPerforming;//自动释放技能第一次标示
object enemy;
private string action;//"escape"|"perform ..."
protected string accept_fight_msg="$N接受了$p的挑战。";
read_only(accept_fight_msg);
protected string deny_fight_msg="$N不愿意和$p过招。";
read_only(deny_fight_msg);
protected string success_msg="$N对$p拱手道：“承让了。”";
read_only(success_msg);
protected string surrender_msg="$N向$p大声求饶道：“别打了别打了，我投降了。”";
read_only(surrender_msg);
protected string killing_msg="$N看起来想杀了$p。";
read_only(killing_msg);
int query_killing(){
	return killing;
}
int query_in_combat(){
	return in_combat;
}
object query_enemy(){
	if(enemy)
		return enemy;
	return this_object()->get_target();
}

// 群攻在调用死亡回调前锁定本次合法施法者，避免多目标原有仇恨顺序
// 把任务、掉落、荣誉或自动复苏的击杀者记到其他参战者名下。
int set_aoe_defeat_credit(object attacker){
	if(!attacker || !objectp(attacker) ||
	   environment(attacker)!=environment(this_object()) ||
	   !LOGICALZONED->can_action("combat",attacker,this_object()) ||
	   !this_object()->if_in_targets(attacker))
		return 0;
	enemy = attacker;
	return 1;
}

// 玩家杀戮持续约三分钟后，以当前战斗快照推演最多一千轮。
// 推演只读取属性，不逐轮修改真实人物，最后仅执行一次正常死亡结算。
int query_pk_fast_decision_trigger_rounds(){
	return PK_FAST_DECISION_TRIGGER_ROUNDS;
}

int query_pk_fast_decision_rounds(){
	return PK_FAST_DECISION_SIMULATION_ROUNDS;
}

// 方士灵兽属于主人这一侧；普通NPC不会被误认成玩家PK参与者。
object query_pk_fast_target_owner(object target){
	object owner;
	if(!target || !objectp(target))
		return 0;
	if(target->is("player"))
		return target;
	owner = SUMMOND->query_combat_credit_owner(target);
	if(owner && owner!=target && owner->is("player"))
		return owner;
	return 0;
}

// 一侧的仇恨列表只能包含对手及对手的合法灵兽，第三名玩家、普通NPC、
// 第三方召唤物都会阻止快速决胜，避免把群战错误压成1v1。
int query_pk_fast_targets_belong_to(object who,object opponent){
	array(object) targets;
	if(!who || !opponent)
		return 0;
	targets = who->get_all_targets();
	if(!targets || sizeof(targets)<1)
		return 0;
	foreach(targets,object target){
		if(query_pk_fast_target_owner(target)!=opponent)
			return 0;
	}
	return 1;
}

// 快速决胜只读取灵医当前真实已学治疗，折算为保守的每轮可持续自疗。
// 折算同时受技能阶段、冷却、当前仙力、单次生命上限和减疗影响；不把
// 药契当成每轮都可重复消费，也不治疗不存在于1v1快照里的队友。
private int query_lingyi_pk_fast_heal(object who){
	array(string) names = ({"huichun","qingxin","lingyu","yulu",
		"ganlin","xuming","cixinpudu","huimingtianlu",
		"wanmuxinchun","liuhehuichun"});
	int best = 0;
	if(!who || who->query_profeId()!="lingyi" || !who->skills)
		return 0;
	foreach(names,string name){
		object|zero skill = 0;
		mixed load_err = 0;
		int learned_level;
		int usable_level = 0;
		int amount;
		int life_cap;
		int cooldown;
		int cast;
		int mana_casts;
		int by_cooldown;
		int by_mana;
		int sustainable;
		mapping(int:int) limits;
		mixed learned = who->skills[name];
		if(!arrayp(learned) || !sizeof(learned) || (int)learned[0]<=0)
			continue;
		load_err = catch {
			skill = (object)(ROOT+"/gamelib/single/skills/"+name);
		};
		if(load_err || !skill || skill->s_skill_type!="heal")
			continue;
		learned_level = (int)learned[0];
		limits = skill->query_performs_level_limit_all();
		if(!limits || !sizeof(limits))
			continue;
		for(int stage=sizeof(limits);stage>0;stage--){
			if(who->query_level()>=limits[stage]){
				usable_level = stage;
				break;
			}
		}
		if(usable_level<=0)
			continue;
		if(learned_level>usable_level)
			learned_level = usable_level;
		amount = skill->query_performs_attack(learned_level)+
			who->query_think()*skill->query_lingyi_think_scale();
		life_cap = who->query_life_max()*
			skill->query_lingyi_life_cap_percent()/100;
		if(life_cap>0 && amount>life_cap)
			amount = life_cap;
		if(who->query_debuff("curse",0)=="life"){
			int reduction = (int)who->query_debuff("curse",1);
			if(reduction<0)
				reduction = 0;
			if(reduction>90)
				reduction = 90;
			amount = amount*(100-reduction)/100;
		}
		if(amount<=0)
			continue;
		cooldown = skill->query_s_delayTime(learned_level);
		if(cooldown<1)
			cooldown = 1;
		if(who->f_skills && (int)who->f_skills[name]>cooldown)
			cooldown = (int)who->f_skills[name];
		cast = skill->query_performs_cast(learned_level);
		if(cast<1)
			cast = 1;
		mana_casts = who->get_cur_mofa()/cast;
		if(mana_casts<1)
			continue;
		by_cooldown = amount/cooldown;
		by_mana = amount*mana_casts/200;
		if(by_cooldown<1 || by_mana<1)
			continue;
		sustainable = by_cooldown<by_mana ? by_cooldown : by_mana;
		if(sustainable>best)
			best = sustainable;
	}
	return best;
}

mapping query_pk_fast_side_profile(object who){
	mapping profile = ([]);
	mapping summons = ([]);
	int life;
	int life_max;
	int physical_raw;
	int magic_raw;
	int summon_attack = 0;
	int summon_heal = 0;
	int profession_heal = 0;
	int shield = 0;
	int magic_rate;
	int magic_element = 0;

	if(!who)
		return profile;
	life = who->get_cur_life();
	life_max = who->query_life_max();
	if(life_max<1)
		life_max = 1;
	if(life<0)
		life = 0;
	if(life>life_max)
		life = life_max;

	if(who->query_buff("buff",0)=="absorb")
		shield += (int)who->query_buff("buff",1);
	if(who->query_buff("buff2",0)=="absorb")
		shield += (int)who->query_buff("buff2",1);
	if(who->query_buff("team_guard",0)=="absorb")
		shield += (int)who->query_buff("team_guard",1);
	if(shield<0)
		shield = 0;
	life += shield;
	life_max += shield;

	// 灵兽的存活、普攻与鹤灵治疗均计入方士这一侧的当前快照。
	if(who->query_profeId()=="fangshi")
		summons = SUMMOND->get_player_summons(who->query_name());
	if(who->query_profeId()=="lingyi")
		profession_heal = query_lingyi_pk_fast_heal(who);
	if(summons && sizeof(summons)){
		foreach(values(summons),object summon){
			if(!summon || summon->get_cur_life()<=0 ||
			   environment(summon)!=environment(who))
				continue;
			life += summon->get_cur_life();
			life_max += summon->query_life_max();
			summon_attack += (summon->query_low_attack_desc()+
				summon->query_high_attack_desc())/2;
			if(summon->query_summon_type()=="heling")
				summon_heal += (50+who->query_level()*5+
					summon->query_summon_skill_level()*20)/3;
		}
	}

	physical_raw = (who->query_low_attack_desc()+
		who->query_high_attack_desc())/2+
		who->query_equip_add("attack_all")+summon_attack;
	if(who->query_buff("buff",0)=="physical_attack_percent")
		physical_raw += physical_raw*
			(int)who->query_buff("buff",1)/100;
	if(who->query_debuff("curse",0)=="physical_damage_percent"){
		int reduce = (int)who->query_debuff("curse",1);
		physical_raw=query_physical_damage_after_percent_curse(
			physical_raw,reduce);
	}
	if(physical_raw<1)
		physical_raw = 1;

	magic_element = (int)who->query_equip_add("huo_mofa_attack");
	if((int)who->query_equip_add("bing_mofa_attack")>magic_element)
		magic_element = (int)who->query_equip_add("bing_mofa_attack");
	if((int)who->query_equip_add("feng_mofa_attack")>magic_element)
		magic_element = (int)who->query_equip_add("feng_mofa_attack");
	if((int)who->query_equip_add("du_mofa_attack")>magic_element)
		magic_element = (int)who->query_equip_add("du_mofa_attack");
	magic_rate = search(({"yushi","wuyao","fangshi","tianxiang","lingyi"}),
		who->query_profeId())!=-1 ? 7 : 5;
	magic_raw = who->query_think()*magic_rate/2+
		who->query_equip_add("mofa_all")+magic_element;
	if(who->query_buff("buff2",0)=="all_mofa_attack")
		magic_raw = magic_raw*3/2;
	if(magic_raw<1)
		magic_raw = 1;

	profile["life"] = life;
	profile["life_max"] = life_max;
	profile["physical_raw"] = physical_raw;
	profile["magic_raw"] = magic_raw;
	profile["summon_attack_raw"] = summon_attack;
	profile["magic_enabled"] = search(({"yushi","wuyao","fangshi","tianxiang","lingyi"}),
		who->query_profeId())!=-1;
	profile["heal"] = (int)who->query_equip_add("rase_life_add")+
		summon_heal+profession_heal;
	profile["profession_heal"] = profession_heal;
	profile["hit"] = (int)who->query_if_hitte();
	profile["dodge"] = (int)who->query_phy_dodge();
	profile["critical"] = (int)who->query_phy_baoji();
	profile["renxing"] = (int)who->query_equip_add("renxing");
	profile["physical_penetration"] =
		(int)who->query_equip_add("wulichuantou_add");
	profile["magic_penetration"] =
		(int)who->query_equip_add("mofachuantou_add");
	profile["pet_score"] = 0;
	return profile;
}

mapping query_pk_fast_damage_profile(object attacker,object target,
	mapping attacker_profile,mapping target_profile){
	mapping result = ([]);
	int physical_damage;
	int magic_damage;
	int summon_damage = 0;
	int magic_defend;
	int current_defend;
	int hit_chance;
	int critical_chance;

	physical_damage = query_balanced_physical_damage(
		attacker_profile["physical_raw"],target->query_defend_power(),
		attacker_profile["physical_penetration"]);
	magic_defend = (int)target->query_equip_add("huoyan_defend");
	current_defend = (int)target->query_equip_add("bingshuang_defend");
	if(current_defend<magic_defend)
		magic_defend = current_defend;
	current_defend = (int)target->query_equip_add("fengren_defend");
	if(current_defend<magic_defend)
		magic_defend = current_defend;
	current_defend = (int)target->query_equip_add("dusu_defend");
	if(current_defend<magic_defend)
		magic_defend = current_defend;
	magic_defend += (int)target->query_equip_add("all_mofa_defend");
	magic_damage = query_balanced_magic_damage(
		attacker_profile["magic_raw"],magic_defend,
		attacker_profile["magic_penetration"]);
	if(attacker_profile["summon_attack_raw"]>0)
		summon_damage = query_balanced_physical_damage(
			attacker_profile["summon_attack_raw"],
			target->query_defend_power(),0);

	if(attacker_profile["magic_enabled"] &&
	   magic_damage>physical_damage){
		result["damage"] = magic_damage+summon_damage;
		result["magic"] = 1;
		hit_chance = attacker_profile["hit"];
	}
	else{
		result["damage"] = physical_damage;
		result["magic"] = 0;
		hit_chance = attacker_profile["hit"]*
			(100-target_profile["dodge"])/100;
	}
	if(hit_chance<5)
		hit_chance = 5;
	if(hit_chance>99)
		hit_chance = 99;
	critical_chance = attacker_profile["critical"]-
		target_profile["renxing"]/40;
	if(critical_chance<0)
		critical_chance = 0;
	if(critical_chance>75)
		critical_chance = 75;
	result["hit"] = hit_chance;
	result["critical"] = critical_chance;
	return result;
}

int query_pk_fast_score(object who,mapping profile,int sim_life){
	int life_rate = 0;
	int score;
	if(profile["life_max"]>0)
		life_rate = sim_life*10000/profile["life_max"];
	score = life_rate*100+
		profile["effective_damage"]*8+
		who->query_defend_power()*3+profile["dodge"]*100+
		profile["heal"]*10+profile["pet_score"]+
		who->query_level()*100;
	return score;
}

mapping query_pk_fast_decision_simulation(object target){
	mapping result = ([]);
	object me = this_object();
	object winner;
	object loser;
	mapping me_profile;
	mapping target_profile;
	mapping me_damage;
	mapping target_damage;
	mapping me_pet;
	mapping target_pet;
	int me_life;
	int target_life;
	int used_rounds = 0;
	int used_scale = 1;
	int me_pet_triggers = 0;
	int target_pet_triggers = 0;
	int me_rate;
	int target_rate;
	int me_score;
	int target_score;

	if(!target || !target->is("player"))
		return result;
	me_profile = query_pk_fast_side_profile(me);
	target_profile = query_pk_fast_side_profile(target);
	me_damage = query_pk_fast_damage_profile(
		me,target,me_profile,target_profile);
	target_damage = query_pk_fast_damage_profile(
		target,me,target_profile,me_profile);
	me_pet = SPIRIT_COMPANIOND->query_pet_battle_source(me)=="personal" ?
		SPIRIT_COMPANIOND->query_spirit_companion_pk_fast_profile(me,target) :
		PETD->query_pet_pk_fast_profile(me,target);
	target_pet = SPIRIT_COMPANIOND->query_pet_battle_source(target)==
		"personal" ?
		SPIRIT_COMPANIOND->query_spirit_companion_pk_fast_profile(target,me) :
		PETD->query_pet_pk_fast_profile(target,me);
	if(me_pet["active"] && (me_pet["type"]=="mofa" ||
	   me_pet["secondary_type"]=="mofa"))
		me_profile["pet_score"] = (int)(me_pet["secondary_type"]=="mofa" ?
			me_pet["secondary_amount"] : me_pet["amount"])*
			(int)me_pet["remaining_uses"]*2;
	if(target_pet["active"] && (target_pet["type"]=="mofa" ||
	   target_pet["secondary_type"]=="mofa"))
		target_profile["pet_score"] = (int)(
			target_pet["secondary_type"]=="mofa" ?
			target_pet["secondary_amount"] : target_pet["amount"])*
			(int)target_pet["remaining_uses"]*2;
	me_profile["effective_damage"] = me_damage["damage"];
	target_profile["effective_damage"] = target_damage["damage"];
	me_life = me_profile["life"];
	target_life = target_profile["life"];

	for(int round=1;round<=PK_FAST_DECISION_SIMULATION_ROUNDS;round++){
		int me_round_damage = 0;
		int target_round_damage = 0;
		int me_pet_trigger = 0;
		int target_pet_trigger = 0;
		int scale = 1;
		if(round>800)
			scale = 16;
		else if(round>600)
			scale = 8;
		else if(round>400)
			scale = 4;
		else if(round>200)
			scale = 2;
		if(scale>PK_FAST_DECISION_SCALE_MAX)
			scale = PK_FAST_DECISION_SCALE_MAX;
		used_scale = scale;
		used_rounds = round;

		if((round*37+me_profile["physical_raw"])%100<
		   me_damage["hit"]){
			me_round_damage = me_damage["damage"]*scale;
			if((round*53+me_profile["magic_raw"])%100<
			   me_damage["critical"])
				me_round_damage = query_balanced_critical_damage(
					me_round_damage,target_profile["renxing"]);
		}
		if((round*37+target_profile["physical_raw"])%100<
		   target_damage["hit"]){
			target_round_damage = target_damage["damage"]*scale;
			if((round*53+target_profile["magic_raw"])%100<
			   target_damage["critical"])
				target_round_damage = query_balanced_critical_damage(
					target_round_damage,me_profile["renxing"]);
		}
		if(me_pet["active"] && (int)me_pet["remaining_uses"]>0){
			int first_round = (int)me_pet["charge_required"]-
				(int)me_pet["charge"];
			if(first_round<1)
				first_round = 1;
			if(round>=first_round &&
			   (round-first_round)%(int)me_pet["charge_required"]==0 &&
			   (round-first_round)/(int)me_pet["charge_required"]<
				(int)me_pet["remaining_uses"])
				me_pet_trigger = 1;
		}
		if(target_pet["active"] &&
		   (int)target_pet["remaining_uses"]>0){
			int first_round = (int)target_pet["charge_required"]-
				(int)target_pet["charge"];
			if(first_round<1)
				first_round = 1;
			if(round>=first_round &&
			   (round-first_round)%(int)target_pet["charge_required"]==0 &&
			   (round-first_round)/(int)target_pet["charge_required"]<
				(int)target_pet["remaining_uses"])
				target_pet_trigger = 1;
		}
		// 灵宠每场最多两次，不随快速推演的加速倍率重复放大。
		if(me_pet_trigger && me_pet["type"]=="damage")
			me_round_damage += (int)me_pet["amount"];
		if(target_pet_trigger && target_pet["type"]=="damage")
			target_round_damage += (int)target_pet["amount"];
		if(me_pet_trigger)
			me_pet_triggers++;
		if(target_pet_trigger)
			target_pet_triggers++;

		// 双方伤害同时结算，避免调用者固定获得先手优势。
		target_life -= me_round_damage;
		me_life -= target_round_damage;
		if(me_life<=0 || target_life<=0)
			break;
		me_life += me_profile["heal"];
		target_life += target_profile["heal"];
		if(me_pet_trigger && me_pet["type"]=="heal")
			me_life += (int)me_pet["amount"];
		if(me_pet_trigger && me_pet["secondary_type"]=="heal")
			me_life += (int)me_pet["secondary_amount"];
		if(target_pet_trigger && target_pet["type"]=="heal")
			target_life += (int)target_pet["amount"];
		if(target_pet_trigger && target_pet["secondary_type"]=="heal")
			target_life += (int)target_pet["secondary_amount"];
		if(me_life>me_profile["life_max"])
			me_life = me_profile["life_max"];
		if(target_life>target_profile["life_max"])
			target_life = target_profile["life_max"];
	}

	if(me_profile["life_max"]>0)
		me_rate = me_life*10000/me_profile["life_max"];
	if(target_profile["life_max"]>0)
		target_rate = target_life*10000/target_profile["life_max"];
	me_score = query_pk_fast_score(me,me_profile,me_life);
	target_score = query_pk_fast_score(target,target_profile,target_life);

	if(me_life>0 && target_life<=0){
		winner = me;
		loser = target;
	}
	else if(target_life>0 && me_life<=0){
		winner = target;
		loser = me;
	}
	else if(me_rate>target_rate){
		winner = me;
		loser = target;
	}
	else if(target_rate>me_rate){
		winner = target;
		loser = me;
	}
	else if(me_score>target_score){
		winner = me;
		loser = target;
	}
	else if(target_score>me_score){
		winner = target;
		loser = me;
	}
	else if(killing){
		// 完全同分时主动发起杀戮的一方承担风险，且与调用方向无关。
		winner = target;
		loser = me;
	}
	else if(target->query_killing()){
		winner = me;
		loser = target;
	}
	else{
		winner = me;
		loser = target;
	}

	result["winner"] = winner;
	result["loser"] = loser;
	result["me_life"] = me_life;
	result["target_life"] = target_life;
	result["me_rate"] = me_rate;
	result["target_rate"] = target_rate;
	result["me_score"] = me_score;
	result["target_score"] = target_score;
	result["rounds"] = used_rounds;
	result["scale"] = used_scale;
	result["me_pet_triggers"] = me_pet_triggers;
	result["target_pet_triggers"] = target_pet_triggers;
	return result;
}

int query_pk_fast_decision_ready(object target){
	object opponent;
	int opponent_killing;
	if(!in_combat || !target || !objectp(target) ||
	   !this_object()->is("player"))
		return 0;
	opponent = query_pk_fast_target_owner(target);
	if(!opponent || opponent==this_object() ||
	   !opponent->query_in_combat() ||
	   environment(opponent)!=environment(this_object()) ||
	   this_object()->get_cur_life()<=0 || opponent->get_cur_life()<=0)
		return 0;
	opponent_killing = opponent->query_killing();
	if(!killing && !opponent_killing)
		return 0;
	if(query_pk_fast_target_owner(opponent->query_enemy())!=this_object())
		return 0;
	if(!query_pk_fast_targets_belong_to(this_object(),opponent) ||
	   !query_pk_fast_targets_belong_to(opponent,this_object()))
		return 0;
	return 1;
}

int run_pk_fast_decision(){
	object opponent;
	object winner;
	object loser;
	mapping result;
	string msg;
	if(!query_pk_fast_decision_ready(enemy))
		return 0;
	opponent = query_pk_fast_target_owner(enemy);
	if(!opponent || this_object()["/tmp/pk_fast_decision/running"] ||
	   opponent["/tmp/pk_fast_decision/running"])
		return 0;
	this_object()["/tmp/pk_fast_decision/running"] = 1;
	opponent["/tmp/pk_fast_decision/running"] = 1;
	result = query_pk_fast_decision_simulation(opponent);
	winner = result["winner"];
	loser = result["loser"];
	if(!winner || !loser){
		this_object()->m_delete_foruser("/tmp/pk_fast_decision/running");
		opponent->m_delete_foruser("/tmp/pk_fast_decision/running");
		return 0;
	}
	msg = sprintf("【快速决胜】双方鏖战%d回合，天道按当前气血、攻防、命闪、暴韧、穿透、恢复与灵兽状态推演%d轮，判定%s胜出，%s气血衰竭。\n",
		PK_FAST_DECISION_TRIGGER_ROUNDS,result["rounds"],
		winner->query_name_cn(),loser->query_name_cn());
	tell_object(this_object(),msg);
	if(opponent && objectp(opponent))
		tell_object(opponent,msg);
	loser->set_life(0);
	loser->fight_die();
	// 已确认是严格双方战斗，败者死亡后立即结束胜者残留战斗态，
	// 不必再等下一次心跳清掉已消失的玩家或灵兽目标。
	if(winner && objectp(winner) && winner->query_in_combat())
		winner->_clean_fight();
	if(this_object() && objectp(this_object()))
		this_object()->m_delete_foruser("/tmp/pk_fast_decision/running");
	if(opponent && objectp(opponent))
		opponent->m_delete_foruser("/tmp/pk_fast_decision/running");
	return 1;
}

int check_pk_fast_decision(){
	object opponent;
	if(!query_pk_fast_decision_ready(enemy))
		return 0;
	opponent = query_pk_fast_target_owner(enemy);
	if(!opponent || this_object()->timeCount<
	   PK_FAST_DECISION_TRIGGER_ROUNDS ||
	   opponent->timeCount<PK_FAST_DECISION_TRIGGER_ROUNDS)
		return 0;
	return run_pk_fast_decision();
}

private void recover(){
	if(in_combat) return;
	//npc战斗以后自动恢复生命
	this_object()->life=this_object()->life_max;
}

// DOT 击杀的延迟死亡结算。DOT 在自身心跳里把血量减到 0 时，不能直接
// 调用 this_object()->fight_die()（后台报错）；通常由敌人心跳在下次
// 检测到 get_cur_life()<=0 时结算。但若敌人已离场（换区/下线/被清目标），
// 没人会触发死亡，留下零血怪。此函数由 call_out 在心跳外触发，作为兜底。
//
// 普通 NPC 的死亡流程会同步 remove()，因此已由其它攻击路径结算的对象
// 不可能再执行到这里。NPC 在 call_out 前被清掉战斗状态，恰恰是必须继续
// 结算的零血残留场景。玩家对象死亡后仍会留在游戏中，才需要保留脱战保护，
// 避免重复掉级、耐久和荣誉结算。
int resolve_deferred_zero_life(){
	object actor=this_object();
	if(!actor || actor->get_cur_life()>0)
		return 0;
	if(actor->is("npc")){
		if(!environment(actor))
			return 0;
	}
	else if(!actor->query_in_combat())
		return 0;
	actor->fight_die();
	return 1;
}
private void dot_death(){
	resolve_deferred_zero_life();
}
void _clean_fight(){
	//werror("\n----"+this_object()->query_name_cn()+"呼叫_clean_fight()开始----\n");
	in_combat=0;
	action=0;
	killing=0;
	this_object()->first_fight = 0;
	this_object()->timeCold = 0;
	this_object()->eat_timeCold = 0;
	this_object()->m_delete_foruser("/tmp/pk_fast_decision/running");
	if(this_object()->is("player"))
		PETD->reset_pet_combat_state(this_object());
	if(this_object()->is("player"))
		SPIRIT_COMPANIOND->reset_spirit_companion_combat_state(this_object());
	this_object()->clean_tianxiang_star_marks();
	this_object()->clean_lingyi_medicine_pacts();
	if(this_object()->is("npc")){
		this_object()->who_fight_npc = "";//重置首次攻击者
		this_object()->term_who_fight_npc = "";//重置首次攻击者队伍标示          
	}
	else 
		//还原杀戮标,示因为帮战要求，由liaocheng于08/08/30添加
		this_object()->kill_flag = 1;
	this_object()->reset_targets(); //重置仇恨列表
	if(tmp_heart_beat){
		set_heart_beat(0);
		tmp_heart_beat=0;
	}
	if(this_object()->is("npc")){
		if(zero_type(find_call_out(recover)))
			call_out(recover,2);
	}
	//初始化debuff映射表
	this_object()->set_debuff("dot",0,"none");
	this_object()->set_debuff("dot",1,0);
	this_object()->set_debuff("dot",2,0);
	clear_dot_source_runtime();
	this_object()->set_debuff("curse",0,"none");
	this_object()->set_debuff("curse",1,0);
	this_object()->set_debuff("curse",2,0);
	this_object()->set_debuff("curse2",0,"none");
	this_object()->set_debuff("curse2",1,0);
	this_object()->set_debuff("curse2",2,0);
	//初始化buff映射表
	this_object()->set_buff("buff",0,"none");
	this_object()->set_buff("buff",1,0);
	this_object()->set_buff("buff",2,0);
	this_object()->set_buff("buff2",0,"none");
	this_object()->set_buff("buff2",1,0);
	this_object()->set_buff("buff2",2,0);
	//werror("\n22222"+this_object()->query_name_cn()+"呼叫_clean_fight()结束222222\n");
}
//private void escape(void|int change){
void escape(void|int change){
	// 限时秘境没有普通逃跑出口；PVP逃离必须按认输结算，PVE使用撤离按钮。
	if(this_object()->is("player") &&
	   TIMED_EVENTD->block_event_escape(this_object()))
		return;
	if(this_object()->get_cur_life()>0&&enemy->get_cur_life()>0){
		if(this_object()->query_debuff("70_skill_curse",0) == "baofengfeixue"){
			tell_object(this_object(),"【妖】暴风飞雪效果，你无法逃跑。\n");
			return;
		}
		int succ = 40+(int)(this_object()->query_dex()/20);
		if(random(100)>=succ){
			tell_object(enemy,this_object()->query_name_cn()+"想逃跑，但是失败了。\n");
			tell_object(this_object(),"你逃跑失败了。\n");
			return;
		}
		tell_object(enemy,this_object()->query_name_cn()+"逃跑了。\n");
		tell_object(this_object(),"你逃跑了。\n");
		enemy->clean_targets(this_object());
		_clean_fight();
		object env=environment(this_object());
		if(env && sizeof(env->exits)){
			this_object()->command("leave "+indices(env->exits)[random(sizeof(env->exits))]);
		}
		else if(env && !this_object()->is("npc") &&
		   functionp(env->query_room_type) && env->query_room_type()=="fb"){
			tell_object(this_object(),"此处没有普通出口，幻境安全通道已开启。\n");
			this_object()->command("fb_leave");
		}
		return;
	}
	else{                                                                    
		if(!this_object()->is("npc"))
			tell_object(this_object(),"你已经死亡。\n");
		return;
	}
}
//技能升级系统20070206//////////////////////////////////
//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
//而且，防止超出技能等级上限而溢出
	void skills_level_check(string sname,void|int test_gain_roll){
		object skill;
		int skill_level;
		int required;
		int gain_roll;
		if(!sname || !this_object()->skills ||
		   !this_object()->skills[sname])
			return;
		skill = MUD_SKILLSD[sname];
		if(!skill)
			return;
		if(skill->boss_skill == 1)
			return;
		if(this_object()->is("player"))
			DAILYGOALD->record_skill(this_object());
		int cur_skills_level_limit = 10;
		if(skill->query_skill_level_max)
			cur_skills_level_limit =
				(int)skill->query_skill_level_max();
		skill_level = (int)this_object()->skills[sname][0];
		required = (int)skill->performs_shuliandu[skill_level];
		if(required<=0 || skill_level>=cur_skills_level_limit)
			return;
		if((int)this_object()->skills[sname][1]<required){
			//技能升级速度降低一半
			gain_roll = random(3)+1;
			if(search((string)this_object()->query_name(),"testunit")!=-1 &&
			   !zero_type(test_gain_roll))
				gain_roll = (int)test_gain_roll;
			if(gain_roll==2)
				this_object()->skills[sname][1]++;
		}
		// 本次成功施放刚好把熟练度推到100%时立即升级，不再要求
		// 再施放一次长CD技能；成长速度、门槛与等级上限均不改变。
		if((int)this_object()->skills[sname][1]>=required){
			this_object()->skills[sname][0] = skill_level+1;
			this_object()->skills[sname][1] = 0;
			tell_object(this_object(),"【技能精进】"+
				(string)skill->query_name_cn()+"提升至"+(skill_level+1)+
				"级。\n");
		}
	}
//技能升级系统20070206//////////////////////////////////
//技能释放接口20070131//////////////////////////////////
// 技能守护进程采用惰性注册。玩家存档里的技能在服务重启后未必已经被
// 商店或技能页加载，因此施法入口按受限技能名补载；同时必须先验证玩家
// 确实学过该技能，防止手工拼接 use_perform 命令越权施放全局已加载技能。
private object|zero query_learned_skill_object(string name){
	object|zero skill = 0;
	mixed load_err = 0;
	mixed learned = 0;
	if(!name || name == "" || sizeof(name) > 64 ||
	   search(name,"/") != -1 || search(name,"..") != -1 ||
	   !this_object()->skills)
		return 0;
	learned = this_object()->skills[name];
	if(!arrayp(learned) || !sizeof(learned) || (int)learned[0]<=0)
		return 0;
	skill = MUD_SKILLSD[name];
	if(!skill){
		load_err = catch {
			skill = (object)(ROOT+"/gamelib/single/skills/"+name);
		};
		if(load_err)
			skill = 0;
	}
	return skill;
}

private array(object) query_lingyi_heal_targets(int scope){
	array(object) candidates = ({});
	array(object) result = ({});
	object caster = this_object();
	object env = environment(caster);
	string team_id = caster->query_term();
	if(caster->get_cur_life()>0)
		candidates += ({caster});
	if(env && team_id!="" && team_id!="noterm"){
		foreach(all_inventory(env),object member){
			if(member==caster || !member->is("player") ||
			   member->query_term()!=team_id || member->get_cur_life()<=0 ||
			   !LOGICALZONED->can_action("team",caster,member))
				continue;
			candidates += ({member});
		}
	}
	if(!sizeof(candidates))
		return result;
	if(scope==2)
		return candidates;
	object target = candidates[0];
	foreach(candidates,object member){
		if(member->get_cur_life()*target->query_life_max() <
		   target->get_cur_life()*member->query_life_max())
			target = member;
	}
	return ({target});
}

private string clean_one_lingyi_debuff(object target){
	array(string) priority = ({"dot","curse","curse2","70_skill_curse"});
	foreach(priority,string kind){
		if(target->query_debuff(kind,0)!="none"){
			target->clean_debuff(kind);
			return kind;
		}
	}
	return "";
}

// 无相/太极净化严格按技能说明处理：持续伤害、治疗压制、控制、
// 70级诅咒，最后才清理普通属性诅咒；每次最多清理一项。
string clean_one_balanced_debuff(object target){
	if(!target)
		return "";
	if(target->query_debuff("dot",0)!="none"){
		target->clean_debuff("dot");
		return "dot";
	}
	if(target->query_debuff("curse",0)=="life"){
		target->clean_debuff("curse");
		return "heal_suppression";
	}
	if(target->query_debuff("curse2",0)!="none"){
		target->clean_debuff("curse2");
		return "control";
	}
	if(target->query_debuff("70_skill_curse",0)!="none"){
		target->clean_debuff("70_skill_curse");
		return "70_skill_curse";
	}
	if(target->query_debuff("curse",0)!="none"){
		target->clean_debuff("curse");
		return "curse";
	}
	return "";
}

private int is_balanced_profession_skill(object skill){
	string profe = this_object()->query_profeId();
	if(!skill || (profe!="wuxiang" && profe!="taiji"))
		return 0;
	return search(skill->skill_type,profe)!=-1;
}

private array(object) query_balanced_team_targets(){
	array(object) result = ({});
	object caster = this_object();
	object env = environment(caster);
	string team_id = caster->query_term();
	if(caster->get_cur_life()>0)
		result += ({caster});
	if(!env || team_id=="" || team_id=="noterm")
		return result;
	foreach(all_inventory(env),object member){
		if(!member || member==caster || !member->is("player") ||
		   member->query_term()!=team_id || member->get_cur_life()<=0 ||
		   !LOGICALZONED->can_action("team",caster,member))
			continue;
		result += ({member});
	}
	return result;
}

private int heal_balanced_target(object target,int amount){
	int before;
	int life_max;
	if(!target || amount<=0 || target->get_cur_life()<=0)
		return 0;
	before = target->get_cur_life();
	life_max = target->query_life_max();
	if(before>=life_max)
		return 0;
	if(target->query_debuff("curse",0)=="life"){
		int reduce = (int)target->query_debuff("curse",1);
		if(reduce<0)
			reduce = 0;
		if(reduce>90)
			reduce = 90;
		amount = amount*(100-reduce)/100;
	}
	if(amount<1)
		return 0;
	if(before+amount>life_max)
		amount = life_max-before;
	target->set_life(before+amount);
	return amount;
}

// 只应用效果，不扣仙力和冷却；统一施法入口会在确认至少一项效果成功后结算。
private int apply_balanced_support_skill(object skill,int skill_level){
	string kind;
	int amount;
	int duration;
	int benefited = 0;
	if(!is_balanced_profession_skill(skill) || skill_level<=0)
		return 0;
	kind = skill->s_skill_type;
	duration = skill->query_s_lasttime(skill_level);
	if(kind=="balanced_shield"){
		amount = skill->query_performs_attack(skill_level);
		if(amount<=0 || duration<=0 ||
		   (this_object()->query_buff("buff",0)=="absorb" &&
		   (int)this_object()->query_buff("buff",1)>=amount))
			return 0;
		this_object()->set_buff("buff",0,"absorb");
		this_object()->set_buff("buff",1,amount);
		this_object()->set_buff("buff",2,duration);
		return 1;
	}
	if(kind=="balanced_attr")
		return this_object()->apply_balanced_attr_percent(
			skill->query_performs_attack(skill_level),duration);
	if(kind=="balanced_heart")
		return this_object()->apply_balanced_heart_boost(10,duration);
	if(kind=="balanced_cleanse")
		return clean_one_balanced_debuff(this_object())!="";
	if(kind=="balanced_team_guard")
		return apply_team_guard_to_group(this_object(),
			skill->query_performs_attack(skill_level),duration);
	if(kind=="balanced_summon")
		return SUMMOND->summon_balanced_spirit(this_object()->query_name(),
			skill->query_name()) ? 1 : 0;
	if(kind=="balanced_self_heal"){
		int low = skill->query_performs_mofa_attack_low(skill_level);
		int high = skill->query_performs_mofa_attack_high(skill_level);
		if(high<low)
			high = low;
		amount = low+random(high-low+1);
		return heal_balanced_target(this_object(),amount)>0;
	}
	if(kind=="balanced_team_heal" || kind=="balanced_wuji"){
		if(kind=="balanced_team_heal"){
			int low = skill->query_performs_mofa_attack_low(skill_level);
			int high = skill->query_performs_mofa_attack_high(skill_level);
			if(high<low)
				high = low;
			amount = low+random(high-low+1);
		}
		else
			amount = skill->query_performs_attack(skill_level);
		foreach(query_balanced_team_targets(),object member){
			int healed = heal_balanced_target(member,amount);
			string cleaned = kind=="balanced_wuji" ?
				clean_one_balanced_debuff(member) : "";
			if(healed>0 || cleaned!=""){
				benefited++;
				if(member!=this_object())
					tell_object(member,this_object()->query_name_cn()+
						"施放"+skill->query_name_cn()+"，为你恢复"+
						format_game_number(healed)+"点生命"+
						(cleaned!="" ? "并净化一项负面状态" : "")+"。\n");
			}
		}
		return benefited;
	}
	return 0;
}

// 返回实际获得治疗或净化的目标数；没有有效收益时不消耗仙力与冷却。
private int apply_lingyi_heal(object skill,int skill_level){
	array(object) targets;
	int scope = skill->query_lingyi_heal_scope();
	int base_heal;
	int pacts = 0;
	int benefited = 0;
	int total_healed = 0;
	int has_missing_life = 0;
	if(this_object()->query_profeId()!="lingyi" ||
	   this_object()->get_cur_life()<=0 || scope<1 || scope>2)
		return 0;
	targets = query_lingyi_heal_targets(scope);
	foreach(targets,object target){
		if(target->get_cur_life()<target->query_life_max())
			has_missing_life = 1;
	}
	if(has_missing_life && skill->query_lingyi_pact_consume())
		pacts = this_object()->consume_lingyi_medicine_pacts();
	base_heal = skill->query_performs_attack(skill_level)+
		this_object()->query_think()*skill->query_lingyi_think_scale();
	if(pacts>0)
		base_heal = base_heal*(100+pacts*15)/100;
	foreach(targets,object target){
		int before = target->get_cur_life();
		int life_max = target->query_life_max();
		int amount = base_heal;
		int rare_floor = query_rare_vital_floor(skill,skill_level,life_max);
		int cap_percent = skill->query_lingyi_life_cap_percent();
		string cleaned = "";
		if(before<=0 || life_max<=0)
			continue;
		if(rare_floor>amount)
			amount=rare_floor;
		if(cap_percent>0 && amount>life_max*cap_percent/100)
			amount = life_max*cap_percent/100;
		if(target->query_debuff("curse",0)=="life"){
			int reduce = (int)target->query_debuff("curse",1);
			if(reduce<0)
				reduce = 0;
			if(reduce>90)
				reduce = 90;
			amount = amount*(100-reduce)/100;
		}
		if(amount<0)
			amount = 0;
		if(before+amount>life_max)
			amount = life_max-before;
		if(amount>0)
			target->set_life(before+amount);
		if(skill->query_lingyi_cleanse())
			cleaned = clean_one_lingyi_debuff(target);
		if(amount>0 || cleaned!=""){
			benefited++;
			total_healed += amount;
			if(target!=this_object()){
				tell_object(target,this_object()->query_name_cn()+"施放"+
					skill->query_name_cn()+"，为你恢复"+
					format_game_number(amount)+"点生命"+
					(cleaned!="" ? "并净化一项负面状态" : "")+"。\n");
			}
		}
	}
	if(total_healed>0 && skill->query_lingyi_pact_gain()>0){
		int current = this_object()->add_lingyi_medicine_pacts(
			skill->query_lingyi_pact_gain());
		tell_object(this_object(),"你凝成药契（"+current+
			"/3，20秒内有效）。\n");
	}
	if(benefited>0){
		tell_object(this_object(),"你施放"+skill->query_name_cn()+
			"，令"+benefited+"名目标获得救治，共恢复"+
			format_game_number(total_healed)+"点生命"+
			(pacts>0 ? "，并消耗"+pacts+"层药契" : "")+"。\n");
	}
	return benefited;
}

private int query_lingyi_usable_level(object skill,string name){
	mixed learned = this_object()->skills[name];
	int skill_level;
	mapping(int:int) limits = skill->query_performs_level_limit_all();
	int usable = 0;
	if(!arrayp(learned) || !sizeof(learned))
		return 0;
	skill_level = (int)learned[0];
	if(!limits || !sizeof(limits))
		return skill_level;
	for(int i=sizeof(limits);i>0;i--){
		if(this_object()->query_level()>=limits[i]){
			usable = i;
			break;
		}
	}
	if(usable>0 && skill_level>usable)
		skill_level = usable;
	return usable>0 ? skill_level : 0;
}

// 非战斗状态也允许灵医治疗；所有校验与战斗内施放保持一致。
int perform_support(string name){
	object|zero skill;
	int skill_level;
	int cast;
	int cold;
	int applied;
	if(this_object()->query_in_combat() ||
	   this_object()->query_profeId()!="lingyi")
		return 0;
	if(this_object()->get_cur_life()<=0){
		tell_object(this_object(),"你已失去意识，无法施放治疗技能。\n");
		return 0;
	}
	skill = query_learned_skill_object(name);
	if(!skill || skill->s_skill_type!="heal" ||
	   !functionp(skill->query_lingyi_heal_scope) ||
	   skill->query_lingyi_heal_scope()<=0){
		tell_object(this_object(),"该技能不能在非战斗状态施放。\n");
		return 0;
	}
	if(this_object()->query_debuff("curse2",0)=="shenzhishufu"){
		tell_object(this_object(),"【妖】神之束缚效果，你暂时无法使用技能。\n");
		return 0;
	}
	if(this_object()->timeCold!=0){
		tell_object(this_object(),"还有"+this_object()->timeCold+
			"秒法术公共冷却时间。\n");
		return 0;
	}
	skill_level = query_lingyi_usable_level(skill,name);
	if(skill_level<=0){
		tell_object(this_object(),"你的等级尚不足以施放该技能。\n");
		return 0;
	}
	cast = skill->query_performs_cast(skill_level);
	if(cast>this_object()->get_cur_mofa()){
		tell_object(this_object(),"你的仙力不够，无法施放"+
			skill->query_name_cn()+"。\n");
		return 0;
	}
	cold = (int)this_object()->f_skills[name];
	if(cold>1){
		tell_object(this_object(),"该技能还需要"+(cold-1)+
			"秒冷却时间。\n");
		return 0;
	}
	applied = apply_lingyi_heal(skill,skill_level);
	if(applied<=0){
		tell_object(this_object(),"当前没有需要治疗或净化的有效目标。\n");
		return 0;
	}
	this_object()->set_mofa(this_object()->get_cur_mofa()-cast);
	this_object()->timeCold = 2;
	this_object()->f_skills[name] = skill->query_s_delayTime(skill_level)+1;
	broadcast_room_skill_manifestation(skill,this_object(),skill_level,
		"治疗灵光在房间中绽放");
	skills_level_check(name);
	return 1;
}

private int is_lingyi_aoe_team_ally(object caster,object candidate){
	object side = candidate;
	object owner;
	string team_id;
	if(!caster || !candidate)
		return 0;
	owner = SUMMOND->query_combat_credit_owner(candidate);
	if(owner && owner!=candidate)
		side = owner;
	if(side==caster)
		return 1;
	team_id = caster->query_term();
	if(team_id=="" || team_id=="noterm" || !side->is("player"))
		return 0;
	return side->query_term()==team_id &&
		LOGICALZONED->can_action("team",caster,side);
}

private int has_lingyi_aoe_friend_entry(object owner,string target_name){
	if(!owner || !target_name || target_name=="" || !arrayp(owner->qqlist))
		return 0;
	foreach((array)owner->qqlist,mixed raw_friend)
		if(arrayp(raw_friend) && sizeof((array)raw_friend)>=1 &&
		   (string)raw_friend[0]==target_name)
			return 1;
	return 0;
}

// 好友和同注册账号角色始终受保护，且同时覆盖这些
// 玩家拥有的召唤物。阵营是独立的可配置攻击白名单。
private int is_lingyi_aoe_social_ally(object caster,object candidate){
	object side = candidate;
	object owner;
	if(!caster || !candidate)
		return 0;
	owner = SUMMOND->query_combat_credit_owner(candidate);
	if(owner && owner!=candidate)
		side = owner;
	if(!side || !side->is || !side->is("player"))
		return 0;
	if(side==caster)
		return 1;
	if(functionp(side->query_account_owner) &&
	   functionp(caster->query_account_owner) &&
	   (string)side->query_account_owner()!="" &&
	   side->query_account_owner()==caster->query_account_owner())
		return 1;
	return has_lingyi_aoe_friend_entry(caster,side->query_name()) ||
		has_lingyi_aoe_friend_entry(side,caster->query_name());
}

// 阵营选项只限制玩家及其召唤物；野怪仍遵循原有PVE目标规则。
private int is_lingyi_aoe_player_race_allowed(object caster,
	object candidate){
	object side = candidate;
	object owner;
	if(!caster || !candidate)
		return 0;
	owner = SUMMOND->query_combat_credit_owner(candidate);
	if(owner && owner!=candidate)
		side = owner;
	if(!side || !side->is || !side->is("player"))
		return 1;
	return PROFESSIONVIPD->query_lingyi_aoe_target_enabled(caster,
		side->query_raceId());
}

// PVP群攻只能扩展到已经和施法者或其同房队友交战的人物。普通“不是队友”
// 绝不构成伤害路人的授权。
private int is_lingyi_aoe_engaged_player(object caster,object target){
	object env = environment(caster);
	string team_id = caster->query_term();
	if(!caster || !target || !target->is("player") || !env)
		return 0;
	if(caster->if_in_targets(target) || target->if_in_targets(caster))
		return 1;
	if(team_id=="" || team_id=="noterm")
		return 0;
	foreach(all_inventory(env),object member){
		if(!member || !member->is("player") ||
		   member->query_term()!=team_id ||
		   !LOGICALZONED->can_action("team",caster,member))
			continue;
		if(member->if_in_targets(target) || target->if_in_targets(member))
			return 1;
	}
	return 0;
}

private array(object) query_lingyi_room_aoe_targets(){
	array(object) result = ({});
	object caster = this_object();
	object env = environment(caster);
	if(caster->query_profeId()!="lingyi" || !env ||
	   !caster->query_in_combat() || caster->get_cur_life()<=0)
		return result;
	foreach(all_inventory(env),object candidate){
		object owner;
		object side;
		if(!candidate || candidate==caster ||
		   (functionp(candidate->is) && candidate->is("item")) ||
		   !functionp(candidate->get_cur_life) ||
		   candidate->get_cur_life()<=0 ||
		   !LOGICALZONED->can_action("combat",caster,candidate) ||
		   is_lingyi_aoe_team_ally(caster,candidate))
			continue;
		if(functionp(candidate->can_be_attacked) &&
		   !candidate->can_be_attacked(caster))
			continue;
		owner = SUMMOND->query_combat_credit_owner(candidate);
		side = owner && owner!=candidate ? owner : candidate;
		if(is_lingyi_aoe_social_ally(caster,side))
			continue;
		if(!is_lingyi_aoe_player_race_allowed(caster,side))
			continue;
		// 玩家及玩家拥有的召唤物必须已参与这场战斗。
		if(side->is("player") &&
		   !is_lingyi_aoe_engaged_player(caster,side) &&
		   !caster->if_in_targets(candidate) &&
		   !candidate->if_in_targets(caster))
			continue;
		if(!side->is("player")){
			string npc_type;
			if(!candidate->is("npc"))
				continue;
			npc_type = candidate->query_npc_type();
			// 任务人物和城战公共NPC不是练级怪，不能被房间群攻误卷入。
			if(candidate->_tasknpc || npc_type=="city_keeper" ||
			   npc_type=="city_guarder" || npc_type=="city_lord")
				continue;
		}
		result += ({candidate});
	}
	return result;
}

// 无相/太极群攻需要覆盖同房间的普通战斗NPC，不能只从施法者
// 当前仇恨表取数（普通开战时该表通常只有一个目标）。玩家及其
// 召唤物则必须已参与当前战斗，并继续保护同队、好友和同账号角色。
private array(object) query_balanced_aoe_targets(){
	array(object) result = ({});
	object caster = this_object();
	object env = environment(caster);
	if(!env || !caster->query_in_combat() || caster->get_cur_life()<=0)
		return result;
	foreach(all_inventory(env),object candidate){
		object owner;
		object side;
		if(!candidate || candidate==caster ||
		   (functionp(candidate->is) && candidate->is("item")) ||
		   !functionp(candidate->get_cur_life) ||
		   candidate->get_cur_life()<=0 ||
		   !LOGICALZONED->can_action("combat",caster,candidate) ||
		   is_lingyi_aoe_team_ally(caster,candidate))
			continue;
		if(functionp(candidate->can_be_attacked) &&
		   !candidate->can_be_attacked(caster))
			continue;
		owner = SUMMOND->query_combat_credit_owner(candidate);
		side = owner && owner!=candidate ? owner : candidate;
		if(is_lingyi_aoe_social_ally(caster,side))
			continue;
		// 路人玩家与其召唤物不因“同房间”就被强制开战。
		if(side->is("player") &&
		   !is_lingyi_aoe_engaged_player(caster,side) &&
		   !caster->if_in_targets(candidate) &&
		   !candidate->if_in_targets(caster))
			continue;
		if(!side->is("player")){
			string npc_type;
			if(!candidate->is("npc"))
				continue;
			npc_type = candidate->query_npc_type();
			if(candidate->_tasknpc || npc_type=="city_keeper" ||
			   npc_type=="city_guarder" || npc_type=="city_lord")
				continue;
		}
		result += ({candidate});
	}
	return result;
}

// 返回实际纳入结算的目标数。命中、抗性、护盾、仇恨、决斗与死亡奖励仍走
// 现有服务端规则；每个目标的快照供战斗小窗展示十秒。
int perform_lingyi_room_aoe(object skill,int skill_level){
	array(object) targets;
	object caster = this_object();
	object env = environment(caster);
	int balanced;
	int target_limit;
	int raw_low;
	int raw_high;
	int raw_base;
	int penetration;
	int power_percent;
	if(!skill || skill_level<=0 || !env)
		return 0;
	balanced = skill->s_skill_type=="balanced_aoe" &&
		is_balanced_profession_skill(skill);
	if(!balanced && (!functionp(skill->query_lingyi_room_aoe) ||
	   !skill->query_lingyi_room_aoe() ||
	   caster->query_profeId()!="lingyi"))
		return 0;
	targets = balanced ? query_balanced_aoe_targets() :
		query_lingyi_room_aoe_targets();
	if(!sizeof(targets))
		return 0;
	// 有目标上限的职业群攻优先保留玩家当前锁定的主目标，再从已经通过
	// 队友/好友/同账号/任务NPC保护的合法候选中截取。未声明该接口的
	// 太极、灵医和旧群攻继续保持原有覆盖范围。
	if(balanced && functionp(skill->query_balanced_aoe_target_limit)){
		target_limit = skill->query_balanced_aoe_target_limit(skill_level);
		if(enemy && search(targets,enemy)!=-1)
			targets = ({enemy})+(targets-({enemy}));
		if(target_limit>0 && sizeof(targets)>target_limit)
			targets = targets[..target_limit-1];
	}
	raw_low = skill->query_performs_mofa_attack_low(skill_level);
	raw_high = skill->query_performs_mofa_attack_high(skill_level);
	if(raw_high<raw_low)
		raw_high = raw_low;
	raw_base = raw_low+random(raw_high-raw_low+1)+
		caster->query_equip_add(skill->s_skill_type)+
		caster->query_equip_add("mofa_all")+
		caster->query_think()*(balanced ? 5 : 7)/2;
	if(caster->query_buff("buff2",0)=="all_mofa_attack")
		raw_base = raw_base*3/2;
	penetration = caster->query_equip_add("mofachuantou_add");
	power_percent = skill->query_lingyi_aoe_power_percent();
	caster->begin_recent_aoe_battle_report(
		skill->query_name(),skill->query_name_cn());
	foreach(targets,object target){
		int hit = 0;
		int defeated = 0;
		int actual_damage = 0;
		int target_life;
		int target_life_max;
		int level_diff;
		int hit_rate;
		int raw_attack;
		int defend = 0;
		int damage;
		string absorb_desc = "";
		if(!target || environment(target)!=env ||
		   target->get_cur_life()<=0 ||
		   !LOGICALZONED->can_action("combat",caster,target) ||
		   is_lingyi_aoe_team_ally(caster,target) ||
		   is_lingyi_aoe_social_ally(caster,target) ||
		   (!balanced &&
		   !is_lingyi_aoe_player_race_allowed(caster,target)))
			continue;
		caster->_fight(target);
		target->_fight(caster);
		level_diff = target->query_level()-caster->query_level();
		if(level_diff<0)
			level_diff = 0;
		hit_rate = caster->query_if_hitte()-level_diff*5;
		if(hit_rate<30)
			hit_rate = 30;
		if(target->query_buff("70_skill_buff",0)=="bingci"){
			tell_object(target,"【仙】冰刺令你免疫了"+
				skill->query_name_cn()+"。\n");
			caster->record_recent_aoe_battle_target(target,0,0,0);
			continue;
		}
		if(random(100)>=hit_rate){
			tell_object(target,caster->query_name_cn()+"施放"+
				skill->query_name_cn()+"，但被你抵抗了。\n");
			caster->record_recent_aoe_battle_target(target,0,0,0);
			continue;
		}
		hit = 1;
		raw_attack = raw_base;
		if(caster->query_if_baoji(target))
			raw_attack = query_balanced_critical_damage(
				raw_attack,target->query_equip_add("renxing"));
		switch(skill->s_skill_type){
			case "huo_mofa_attack":
				defend = target->query_equip_add("huoyan_defend");
			break;
			case "bing_mofa_attack":
				defend = target->query_equip_add("bingshuang_defend");
			break;
			case "feng_mofa_attack":
				defend = target->query_equip_add("fengren_defend");
			break;
			case "du_mofa_attack":
				defend = target->query_equip_add("dusu_defend");
			break;
		}
		defend += target->query_equip_add("all_mofa_defend");
		damage = query_balanced_magic_damage(raw_attack,defend,penetration)*
			power_percent/100;
		if(damage<1)
			damage = 1;
		target_life = target->get_cur_life();
		target_life_max = target->query_life_max();
		if(target->is("player") && damage>target_life_max*8/100)
			damage = target_life_max*8/100;
		else if(target->is("npc") && target->_boss &&
		   damage>target_life_max*2/100)
			damage = target_life_max*2/100;
		if(damage<1)
			damage = 1;
		if(target->query_buff("buff",0)=="absorb"){
			int shield = (int)target->query_buff("buff",1);
			int absorbed = shield>=damage ? damage : shield;
			damage -= absorbed;
			shield -= absorbed;
			absorb_desc = "（护盾吸收"+
				format_game_number(absorbed)+"）";
			if(shield<=0)
				target->clean_buff("buff");
			else
				target->set_buff("buff",1,shield);
		}
		if(target->query_buff("buff2",0)=="absorb"){
			int shield = (int)target->query_buff("buff2",1);
			int absorbed = shield>=damage ? damage : shield;
			damage -= absorbed;
			shield -= absorbed;
			absorb_desc += "（护盾吸收"+
				format_game_number(absorbed)+"）";
			if(shield<=0)
				target->clean_buff("buff2");
			else
				target->set_buff("buff2",1,shield);
		}
		damage = target->absorb_team_guard_damage(damage);
		if(damage<0)
			damage = 0;
		actual_damage = damage>target_life ? target_life : damage;
		if(damage>=target_life){
			defeated = 1;
			target->set_life(0);
			target->set_aoe_defeat_credit(caster);
		}
		else
			target->set_life(target_life-damage);
		target->flush_targets(caster,damage>0 ? damage : 1);
		caster->flush_targets(target,damage>0 ? damage : 1);
		tell_object(target,caster->query_name_cn()+"施放"+
			skill->query_name_cn()+"，对你造成"+
			format_game_number(actual_damage)+
			"点伤害"+absorb_desc+"。\n");
		if(defeated){
			caster->clean_targets(target);
			if(target->query_raceId()==caster->query_raceId() &&
			   target->kill_flag==0 && caster->kill_flag==0){
				target->set_life(1);
				target->_clean_fight();
				caster->_clean_fight();
				caster->record_recent_aoe_battle_target(
					target,actual_damage,hit,1);
			}
			else if(target->is("player")){
				target->fight_die();
				// 百炼复苏会留在原房间且恢复正生命；不能误报为击败。
				int revived = target && environment(target)==env &&
					target->get_cur_life()>0;
				caster->record_recent_aoe_battle_target(
					target,actual_damage,hit,revived ? 0 : 1,revived);
			}
			else{
				// 普通NPC死亡流程可能直接析构，先保存战果快照。
				caster->record_recent_aoe_battle_target(
					target,actual_damage,hit,1);
				target->fight_die();
			}
		}
		else{
			caster->record_recent_aoe_battle_target(
				target,actual_damage,hit,0);
			target->reduce_fight_wear_armor(1);
		}
	}
	tell_object(caster,"你施放"+skill->query_name_cn()+
		(balanced ? "，群体攻势覆盖" : "，药雾覆盖")+
		sizeof(targets)+"名合法目标；战斗小窗将保留本次战果。\n");
	return sizeof(targets);
}

// 星痕只放大天象自己的爆发法术。普通PVE每层10%，玩家与Boss每层8%，
// 且无论异常数据如何都只计算三层。
int query_tianxiang_star_bonus_percent(object target,int marks){
	int per_mark = 10;
	if(marks<0)
		marks = 0;
	if(marks>3)
		marks = 3;
	if(target && (target->is("player") ||
	   (target->is("npc") && target->_boss)))
		per_mark = 8;
	return marks*per_mark;
}

void perform(string name,void|int flag){
	//怪死亡判断......
	if(!enemy || environment(this_object())!=environment(enemy) ||
	   enemy->get_cur_life()<=0){
		if(this_object()->in_combat)
			this_object()->_clean_fight();
		tell_object(this_object(),"当前没有有效的战斗目标，技能未施放。\n");
		return;
	}
	// 团队硬 Boss 门控（perform 路径）：防止已进入战斗的玩家在队伍人数
	// 不足时继续用技能打 Boss。与 _fight() 入口的门控配套。
	if(enemy->is && enemy->is("npc") &&
	   functionp(enemy->is_team_required_boss) &&
	   enemy->is_team_required_boss()){
		int min_size = 4;
		int alive_count = 0;
		if(functionp(enemy->query_team_required_min_size))
			min_size = (int)enemy->query_team_required_min_size();
		string tid = (string)this_object()->query_term();
		if(tid && tid!="noterm" && tid!=""){
			object room = environment(this_object());
			if(room){
				foreach(all_inventory(room),object ob){
					if(ob && ob->is && ob->is("player") &&
					   (string)ob->query_term()==tid &&
					   ob->get_cur_life()>0)
						alive_count++;
				}
			}
		}
		if(alive_count < min_size){
			tell_object(this_object(),
				"【试炼】"+enemy->query_name_cn()+
				"周围的结界排斥着你：硬 Boss 需 "+
				min_size+" 人以上队伍才能挑战。\n");
			this_object()->_clean_fight();
			return;
		}
	}
	if(enemy && environment(this_object())==environment(enemy)){
		if(enemy->first_fight == 0 || !enemy->in_combat){
			enemy->_fight(this_object());
			enemy->first_fight = 1;
		}
	}
	object|zero f_cur_skill;//当前使用技能对象
	string s = "";//面向自己的战斗描述
	string s1=""; //面向敌人的战斗描述
	if(name&&sizeof(name)){
		if(!this_object()->skills || !this_object()->skills[name] ||
		   (int)this_object()->skills[name][0] <= 0){
			tell_object(this_object(),"你尚未学会该技能。\n");
			return;
		}
		f_cur_skill = query_learned_skill_object(name);
		if(!f_cur_skill){
			tell_object(this_object(),"该技能暂时无法载入，请稍后再试。\n");
			return;
		}
	}
	else
	{
		string stmp = "你要施放什么技能？";
		tell_object(this_object(),stmp+"\n");
		return;
	}
	if(this_object()->query_debuff("curse2",0)=="shenzhishufu"){
		int time_left = this_object()->query_debuff("curse2",2);
		string stmp = "【妖】神之束缚效果，你暂时无法使用技能(还剩"+time_left+"s)\n";
		tell_object(this_object(),stmp+"\n");
		return;
	}
	if(this_object()->timeCold!=0 && !flag){
		string stmp = "还有"+this_object()->timeCold+"秒法术公共冷却时间\n";
		tell_object(this_object(),stmp);
		return;
	}
	if(f_cur_skill){
		int can_skill_level=0;//本字段记录 玩家可以使用的该技能的最高级别
		//首先判断技能使用的等级限制
		//mapping(int:int) lvLimit = f_cur_skill->query_performs_level_limit_all();
		//有时候很奇怪，这个方法找不到，所以要判断下这个方法，如果存在再执行，否则则返回0，不检查级别
		mapping(int:int) lvLimit = f_cur_skill->query_performs_level_limit_all?f_cur_skill->query_performs_level_limit_all():0;                                         
		if(lvLimit && sizeof(lvLimit))//该技能有等级限制
		{
			//第一种情况：技能有熟练度，使用得越多级别越高，这种技能只有一个等级限制
			if(sizeof(lvLimit) == 1){ //只有一个级别的技能
				if(this_object()->query_level()<lvLimit[1])
				{
					string stmp = "你尚未达到"+lvLimit[1]+"级，无法使用该技能。\n";
					tell_object(this_object(),stmp);
					return;
				}
			}
			else{//第二种情况；技能分为几个等级，每个等级对应的lv要求不同，某个级别不能使用，则自动判断其能否使用较低的级别，反复判断直到最低级别；
				for(int i=sizeof(lvLimit);i>0;i--)
				{
					if(this_object()->query_level()>=lvLimit[i])
					{
						can_skill_level = i;
						break;
					}
					else if(i == 1)//玩家连最低一级的要求都没有达到，则无法使用该技能。
					{
						string stmp = "你尚未达到"+lvLimit[1]+"级，无法使用该技能。\n";
						tell_object(this_object(),stmp);
						return;
					}
				}
			}
		}

		//判断有这种技能
		string mofa_type=f_cur_skill->s_skill_type; //得到魔法类型
		//再判断是否有足够的法力施放该技能
		int skill_level=(int)(this_object()->skills[name][0]);
		//werror("===========skill_level:"+skill_level+"\n");
		if(skill_level>can_skill_level&&can_skill_level>0)
			skill_level=can_skill_level;
		//werror("===========275 skill_level:"+skill_level+"\n");
		int s_cast = f_cur_skill->query_performs_cast(skill_level);
		if(s_cast<=this_object()->get_cur_mofa()){
			//有足够的法力
			int s_cold = this_object()->f_skills[name];//技能的冷却时间
			int s_cold_del = 0;//因技能而减少的冷却时间
			int s_cold_add = 0;//因技能而延长的冷却时间
			if(this_object()->query_buff("70_skill_buff",0)=="lieyanzhuoshao"||this_object()->query_buff("70_skill_buff",0)=="bingci"){
				s_cold_del = this_object()->query_buff("70_skill_buff",1);
				s_cold -= s_cold_del;
			}
			if(this_object()->query_debuff("70_skill_curse",0)=="cuidu"){
				s_cold_add = 1;
				s_cold += s_cold_add;
			}
			if(s_cold < 0)
				s_cold = 0;
			// 灵医房间群攻使用独立的合法目标收集，但资源、冷却与熟练度
			// 仍由统一施法入口结算。没有合法目标时不扣任何资源。
			if((functionp(f_cur_skill->query_lingyi_room_aoe) &&
			   f_cur_skill->query_lingyi_room_aoe()) ||
			   mofa_type=="balanced_aoe"){
				if(s_cold>1){
					tell_object(this_object(),"该技能还需要"+(s_cold-1)+
						"秒冷却时间,无法使用。\n");
					return;
				}
				int affected = perform_lingyi_room_aoe(
					f_cur_skill,skill_level);
				if(affected<=0){
					tell_object(this_object(),
						"当前房间没有可由该群体技能攻击的合法目标。\n");
					return;
				}
				this_object()->set_mofa(
					this_object()->get_cur_mofa()-s_cast);
				this_object()->timeCold = 2;
				this_object()->f_skills[name] =
					f_cur_skill->query_s_delayTime(skill_level)+1;
				broadcast_room_skill_manifestation(f_cur_skill,0,skill_level,
					"群体法术覆盖了战场");
				skills_level_check(f_cur_skill->query_name());
				return;
			}
			// 无相/太极辅助技能采用明确白名单，不再落入“未知类型即法术攻击”
			// 的旧兜底。只有真实产生效果后才结算法力、公共冷却和技能冷却。
			if(search(({"balanced_shield","balanced_attr",
			   "balanced_heart","balanced_cleanse","balanced_team_guard",
			   "balanced_summon","balanced_self_heal",
			   "balanced_team_heal","balanced_wuji"}),mofa_type)!=-1){
				if(s_cold>1){
					tell_object(this_object(),"该技能还需要"+(s_cold-1)+
						"秒冷却时间,无法使用。\n");
					return;
				}
				int benefited = apply_balanced_support_skill(
					f_cur_skill,skill_level);
				if(benefited<=0){
					tell_object(this_object(),
						"当前没有可由该技能产生有效收益的目标。\n");
					return;
				}
				this_object()->set_mofa(
					this_object()->get_cur_mofa()-s_cast);
				this_object()->timeCold = 2;
				this_object()->f_skills[name] =
					f_cur_skill->query_s_delayTime(skill_level)+1;
				broadcast_room_skill_manifestation(f_cur_skill,0,skill_level,
					"阴阳灵光改变了战局");
				if(enemy && functionp(enemy->flush_targets))
					enemy->flush_targets(this_object(),10*benefited);
				tell_object(this_object(),"你施放了"+
					f_cur_skill->query_name_cn()+"(等级"+skill_level+
					")，令"+benefited+"个目标获得效果。\n");
				skills_level_check(f_cur_skill->query_name());
				return;
			}
			// 混元是两段物理连击；每段使用一半技能面板值并各自判定暴击，
			// 总面板不被重复放大。第二段不重复增加熟练度。
			if(mofa_type=="balanced_combo"){
				if(s_cold>1){
					tell_object(this_object(),"该技能还需要"+(s_cold-1)+
						"秒冷却时间,无法使用。\n");
					return;
				}
				mapping items = this_object()->query_equip();
				if(!items["single_main_weapon"] &&
				   !items["double_main_weapon"]){
					tell_object(this_object(),
						"该技能需要装备主手武器才能施放。\n");
					return;
				}
				int combo_damage =
					f_cur_skill->query_performs_attack(skill_level)/2;
				if(combo_damage<1)
					combo_damage = 1;
				string weapon_slot = this_object()->weapon_type=="double_main" ?
					"double_main" : "single_main";
				string combo_name = f_cur_skill->query_name_cn()+
					"(等级"+skill_level+")";
				this_object()->set_mofa(
					this_object()->get_cur_mofa()-s_cast);
				this_object()->timeCold = 2;
				this_object()->f_skills[name] =
					f_cur_skill->query_s_delayTime(skill_level)+1;
				broadcast_room_skill_manifestation(f_cur_skill,enemy,skill_level,
					"两道混元劲接连迸发");
				attack(combo_damage,0,weapon_slot,combo_name,
					f_cur_skill->query_name(),skill_level);
				if(enemy && environment(enemy)==environment(this_object()) &&
				   enemy->get_cur_life()>0)
					attack(combo_damage,0,weapon_slot,combo_name);
				return;
			}
			//首先判断是否是各职业有特殊效果技能，由liaocheng于08/01/16添加
			if(mofa_type == "spec"){
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//更新该技能冷却时间,没在表里的则是添加
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					if(name == "xinhunzhuanhua" || name == "xinhunzhuanhua2"){
						//剑仙的心魂转化
						int life_tmp;
						if(name == "xinhunzhuanhua")
							life_tmp = this_object()->get_cur_mofa()*3+this_object()->get_cur_life();
						else if(name == "xinhunzhuanhua2")
							life_tmp = this_object()->get_cur_mofa()*7/2+this_object()->get_cur_life();
						if(life_tmp > this_object()->life_max)
							life_tmp = this_object()->life_max;
						this_object()->set_mofa(0);
						this_object()->set_life(life_tmp);
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
						s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
						tell_object(this_object(),s);
						tell_object(enemy,s1);
						//产生仇恨值
						int hate=(int)(100*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);
					}

					else if(name == "fashukuangchao" || name == "shishabenneng" || name == "fashukuangchao2" || name == "shishabenneng2"){
						//羽士的法术狂潮，诛仙的嗜血本能
						//记录buff的类型
						this_object()->set_buff("buff2",0,f_cur_skill->s_curse_type);
						//记录buff的值
						int tmp_int=f_cur_skill->query_performs_attack(skill_level);
						if(name == "shishabenneng"){
							tmp_int=this_object()->life_max*2/5;
							this_object()->f_skills = ([]);
							this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
						}
						else if(name == "shishabenneng2"){
							tmp_int=this_object()->life_max*1/2;
							this_object()->f_skills = ([]);
							this_object()->f_skills[name] = f_cur_skill->s_delayTime+1;
						}
						this_object()->set_buff("buff2",1,tmp_int);
						//记录buff的持续时间
						this_object()->set_buff("buff2",2,f_cur_skill->query_s_lasttime(skill_level));

						//产生仇恨值,buff的仇恨暂时定为10
						int hate=(int)(10*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "你施放了"+f_cur_skill->query_name_cn()+ "(等级"+skill_level+")";
						s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

					}
					else if(name == "xueranjiangshan" || name == "xueranjiangshan2"){
						//狂妖的血染江山
						//先看是否有主手武器，没有就不能攻击
						mapping items = this_object()->query_equip();//[string:object]
						if(!items["single_main_weapon"]&&!items["double_main_weapon"])
						{
							s += "该技能需要装备主手武器才能施放。";
							tell_object(this_object(),s+"\n");
							return;
						}
						//等级压制
						int difflevel = enemy->query_level()-this_object()->query_level();
						if(difflevel<0)
							difflevel=0;
						int myhitte= this_object()->query_if_hitte();
						int h = (int)(myhitte-difflevel*5);
						if(h<30)
							h=30;
						if(random(100)<h){
							//命中啦 ~
							int s_phy_damage;
							int life_left;
							if(name == "xueranjiangshan"){
								s_phy_damage = this_object()->get_cur_life()*3/5;
								life_left = this_object()->get_cur_life()/2;
							}
							else if(name == "xueranjiangshan2"){
								s_phy_damage = this_object()->get_cur_life()*65/100;
								life_left = this_object()->get_cur_life()*55/100;
							}
							string s_name_cn = f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
							this_object()->set_life(life_left);
							if(this_object()->weapon_type=="double_main")
								attack(s_phy_damage,0,"double_main",s_name_cn,f_cur_skill->query_name());
							else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
								attack(s_phy_damage,0,"single_main",s_name_cn,f_cur_skill->query_name());
						}
						else{
							//未命中	
							s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但未命中对方。";
							s1 += this_object()->query_name_cn()+"施放"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但未击中你。"; 
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");
						}
					}
					else if(name == "shenzhishufu" || name == "shenzhishufu2"){
						//巫妖的神之束缚
						//等级压制
						int difflevel = enemy->query_level()-this_object()->query_level();          
						if(difflevel<0)
							difflevel=0;
						int myhitte= this_object()->query_if_hitte();
						int h = (int)(myhitte-difflevel*5);
						if(h<30)
							h=30;
						if(random(100)<h){ //命中啦~
							//记录诅咒的类型
							enemy->set_debuff("curse2",0,f_cur_skill->s_curse_type);
							//记录诅咒的值
							enemy->set_debuff("curse2",1,f_cur_skill->query_performs_attack(skill_level));
							//记录诅咒的持续时间
							enemy->set_debuff("curse2",2,f_cur_skill->query_s_lasttime(skill_level));

							//产生仇恨值,curse的仇恨暂时定为20
							int hate=(int)(20*skills_hate["test"]/100);
							enemy->flush_targets(this_object(),hate);

							s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
							s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");

							//战斗中击中对方，减攻击者武器磨损
							this_object()->reduce_fight_wield_weapon(1);
							//战斗中被攻击者击中，减防具磨损
							enemy->reduce_fight_wear_armor(1);
						}
						else { //未命中
							s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但被对方抵抗了。";
							s1 += this_object()->query_name_cn()+"对你施放"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但被你抵抗了";
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");
						}
					}
					else if(name == "jinchanmeiying" || name == "jinchanmeiying2"){
						//影鬼的金蝉魅影
						array(object) enemys = this_object()->get_all_targets();
						s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
						if(enemys && sizeof(enemys)){
							for(int i=0;i<sizeof(enemys);i++){
								object target = enemys[i];
								tell_object(target,s1+"\n");
								target->clean_targets(this_object());
							}
						}
						this_object()->_clean_fight();
						this_object()->f_skills = ([]);
						this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
						this_object()->hind = 1;
						if(name == "jinchanmeiying2"){
							this_object()->set_buff("spec_attack_buff",0,f_cur_skill->s_curse_type);
							int tmp_int=f_cur_skill->query_performs_attack(1);
							this_object()->set_buff("spec_attack_buff",1,tmp_int);
							this_object()->set_buff("spec_attack_buff",2,f_cur_skill->s_lasttime);
						}
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
						tell_object(this_object(),s+"\n");
						this_object()->command("look");
					}
					broadcast_room_skill_manifestation(f_cur_skill,enemy,
						skill_level,"战技气息扩散开来");
					return;
				}
				else{
					//该使用过的技能未冷却,提示并返回
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			//70级的各职业特殊技能
			else if(mofa_type == "70_spec"){
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//更新该技能冷却时间,没在表里的则是添加
					if(name == "fanzhuanyiji")
						this_object()->f_skills = ([]);
					this_object()->f_skills[name] = f_cur_skill->s_delayTime+1;
					this_object()->set_buff("70_skill_buff",0,name);
					this_object()->set_buff("70_skill_buff",1,f_cur_skill->effect_value);
					this_object()->set_buff("70_skill_buff",2,f_cur_skill->s_lasttime);
					if(name == "baofengfeixue" || name == "cuidu"){
						enemy->set_debuff("70_skill_curse",0,name);
						this_object()->set_debuff("70_skill_curse",1,f_cur_skill->effect_value);
						enemy->set_debuff("70_skill_curse",2,f_cur_skill->s_lasttime);
					}
					s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
					s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
					tell_object(this_object(),s);
					tell_object(enemy,s1);
					//产生仇恨值
					int hate=(int)(100*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);
					broadcast_room_skill_manifestation(f_cur_skill,enemy,
						skill_level,"秘术改变了战局");
					return;
				}
				else{
					//该使用过的技能未冷却,提示并返回
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			//判断是物理还是法术技能
			/*   法术攻击技能     */
			else if(mofa_type!="phy"&&mofa_type!="dot"&&mofa_type!="curse"&&
				mofa_type!="buff"&&mofa_type!="heal"&&
				mofa_type!="taunt"&&mofa_type!="team_guard"){
				//诛仙70技能的法术免疫效果
				if(enemy->query_buff("70_skill_buff",0)=="bingci"){
					string stmp = "【仙】冰刺效果，对法术伤害免疫(还余"+enemy->query_buff("70_skill_buff",2)+"s)\n";
					tell_object(this_object(),stmp);
					stmp = "【仙】冰刺效果，你免疫了对方的一次法术攻击(还余"+enemy->query_buff("70_skill_buff",2)+"s)\n";
					tell_object(enemy,stmp);
					return;
				}
				//判定该技能冷却时间的判定
				//得到释放技能表，看有无记录，如果有，看冷却时间到了没有
				int mofa_a_low=0; //法术攻击的下限
				int mofa_a_high=0; //法术攻击的上限
				int mofa_a=0; //取得法术攻击的随即值
				int mofa_defend=0; //敌人的魔法抗性
				int fact_mofa_a=0; //最终的法术伤害
				int mofachuantou_add=0;//魔法穿透值
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//更新该技能冷却时间,没在表里的则是添加
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					broadcast_room_skill_manifestation(f_cur_skill,enemy,
						skill_level,"法术光华掠过战场");
					//法术伤害计算公式，还有减免公式
					//等级压制
					int difflevel = enemy->query_level()-this_object()->query_level();
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<h){
						//命中啦 ~
						//得到法术技能的伤害随即值
						mofa_a_low = f_cur_skill->query_performs_mofa_attack_low(skill_level);	
						mofa_a_high = f_cur_skill->query_performs_mofa_attack_high(skill_level);
						mofa_a = random(mofa_a_high-mofa_a_low+1)+mofa_a_low;
						//再加上装备属性带来的法术伤害提升
						//智力也会提高法伤由liaocheng于07/4/16添加
						//职业调整 caijie 08/12/03
						if(this_object()->query_profeId()=="yushi"||this_object()->query_profeId()=="wuyao"||this_object()->query_profeId()=="fangshi"||this_object()->query_profeId()=="tianxiang"||this_object()->query_profeId()=="lingyi"){
							mofa_a += this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think()*7/2);
						}
						else
							mofa_a +=this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think()*5/2);
						if(this_object()->query_buff("buff2",0)=="all_mofa_attack"){
							mofa_a = mofa_a*3/2;
						}
						//计算出相对应的敌人的魔法抗性
						switch(mofa_type) {
							case "huo_mofa_attack":
								mofa_defend = enemy->query_equip_add("huoyan_defend");
							break;
							case "bing_mofa_attack":
								mofa_defend = enemy->query_equip_add("bingshuang_defend");
							break;
							case "feng_mofa_attack":
								//巫妖70技能的风刃法术加成效果
								if(this_object()->query_buff("70_skill_buff",0)=="baofengfeixue")
									mofa_a += mofa_a/2;
								mofa_defend = enemy->query_equip_add("fengren_defend");
							break;
							case "du_mofa_attack":
								mofa_defend = enemy->query_equip_add("dusu_defend");
							break;
							default :
							mofa_defend = 0;
							break;
						}
						mofa_defend += enemy->query_equip_add("all_mofa_defend");
						//计算装备所有的魔法穿透值
						mofachuantou_add=this_object()->query_equip_add("mofachuantou_add");
						//判断暴击
						int b = this_object()->query_if_baoji(enemy);
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						s1+=this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						if(b){
							//暴击啦 ~
							mofa_a=query_balanced_critical_damage(mofa_a,
								enemy->query_equip_add("renxing"));
							s += "，产生了暴击效果！";
							s1 += "，产生了暴击效果！";

						}
						int consumed_star_marks = 0;
						if(this_object()->query_profeId()=="tianxiang" &&
						   f_cur_skill->query_star_mark_consume()){
							consumed_star_marks =
								this_object()->consume_tianxiang_star_marks();
							if(consumed_star_marks>0){
								mofa_a = mofa_a*(100+
									query_tianxiang_star_bonus_percent(
										enemy,consumed_star_marks))/100;
								s += "，引动"+consumed_star_marks+"层星痕";
								s1 += "，引动"+consumed_star_marks+"层星痕";
							}
						}
						int rare_power_percent = 100;
						if(functionp(f_cur_skill->query_rare_power_percent))
							rare_power_percent=
								f_cur_skill->query_rare_power_percent(skill_level);
						if(this_object()->is("player") && rare_power_percent>100)
							mofa_a=mofa_a*rare_power_percent/100;
						//抗性和穿透统一在递减收益公式中结算。
						fact_mofa_a=query_balanced_magic_damage(mofa_a,
							mofa_defend,mofachuantou_add);
						fact_mofa_a=query_rare_direct_damage(f_cur_skill,
							fact_mofa_a,enemy->query_life_max(),
							enemy->is("player"),enemy->is("npc") && enemy->_boss);

						//在这儿加入buff的魔法盾吸收伤害liaocheng 07/4/9
						int attack_fact = fact_mofa_a;
						string absorb_desc = "";
						if(enemy->query_buff("buff",0)=="absorb"){
							if((int)enemy->query_buff("buff",1) >= attack_fact){
								int remain = (int)enemy->query_buff("buff",1) - attack_fact;
								attack_fact= 0;
								absorb_desc = "(被吸收)";
								if(remain <= 0)
									enemy->clean_buff("buff");
								else
									enemy->set_buff("buff",1,remain);
							}
							else{
								attack_fact -= (int)enemy->query_buff("buff",1);
								absorb_desc = "("+format_game_number(
									(int)enemy->query_buff("buff",1))+"点被吸收)";
								enemy->clean_buff("buff");
							}
						}
						if(enemy->query_buff("buff2",0)=="absorb"){
							if((int)enemy->query_buff("buff2",1) >= attack_fact){
								int remain = (int)enemy->query_buff("buff2",1) - attack_fact;
								attack_fact= 0;
								absorb_desc = "(被吸收)";
								if(remain <= 0)
									enemy->clean_buff("buff2");
								else
									enemy->set_buff("buff2",1,remain);
							}
							else{
								attack_fact -= (int)enemy->query_buff("buff2",1);
								absorb_desc = "("+format_game_number(
									(int)enemy->query_buff("buff2",1))+"点被吸收)";
								enemy->clean_buff("buff2");
							}
						}
						//如果魔法穿透大于零，则要在前端提示给玩家
						string chuantou_desc = "";
						if(mofachuantou_add>0){
							chuantou_desc = "【"+
								format_game_number(mofachuantou_add)+
								" 点法术穿透】";
						}
						string damage_desc =
							format_game_number(fact_mofa_a);
						s += "造成了 "+damage_desc+" 点伤害！"+
							absorb_desc+chuantou_desc+"\n";
						s1 += "造成了 "+damage_desc+" 点伤害！"+
							absorb_desc+chuantou_desc+"\n";
						tell_object(this_object(),s);
						tell_object(enemy,s1);
						if(this_object()->query_profeId()=="tianxiang" &&
						   f_cur_skill->query_star_mark_gain()>0){
							int star_marks = this_object()->add_tianxiang_star_marks(
								f_cur_skill->query_star_mark_gain());
							tell_object(this_object(),"你凝聚了星痕（"+
								star_marks+"/3，15秒内有效）。\n");
						}

						//产生仇恨值
						int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());	
						//生命减取 
						attack_fact = enemy->absorb_team_guard_damage(attack_fact);
						int life_damage = enemy->get_cur_life()-attack_fact;
						if(life_damage<=0){
							//敌人死亡，则把敌人从仇恨列表中清除
							this_object()->clean_targets(enemy);
							//在这里加入死亡处理,killing判断是杀戮还是决斗
							if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
								enemy->set_life(1);
								tell_object(this_object(),"你在决斗中战胜了 "+enemy->query_name_cn()+" ！\n");
								tell_object(enemy,this_object()->query_name_cn()+"在决斗中战胜了你！\n");
								enemy->_clean_fight();
								_clean_fight();
								enemy=0;
							}
							else{
								enemy->fight_die();
								enemy=0;
							}
							return;
						}
						enemy->set_life(life_damage);
						//if(this_object()->is("player")){
						//战斗中击中对方，减攻击者武器磨损
						this_object()->reduce_fight_wield_weapon(1);
						//战斗中被攻击者击中，减防具磨损
						enemy->reduce_fight_wear_armor(1);
						//}
					}
					else{
						//未命中	
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但被对方抵抗了。";
						s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+"，但被你抵抗了";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());	
					}
					return;
				}
				else{
					//该使用过的技能未冷却,提示并返回
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*   物理攻击技能     */
			else if(f_cur_skill->s_skill_type=="phy"){
				//werror("===========skill_level:"+skill_level+"\n");
				string s_name_cn=f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
				//先看是否有主手武器，没有就不能攻击
				mapping items = this_object()->query_equip();//[string:object]
				if(!items["single_main_weapon"]&&!items["double_main_weapon"])
				{
					s += "该技能需要装备主手武器才能施放。";
					tell_object(this_object(),s+"\n");
					return;
				}
				//判定该技能冷却时间的判定
				//判断冷却时间
				int s_phy_damage = f_cur_skill->query_performs_attack(skill_level);
				int s_weapon_add = f_cur_skill->query_performs_per(skill_level);
				if(s_cold <= 1){
					//该技不在表中或者冷却，
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					broadcast_room_skill_manifestation(f_cur_skill,enemy,
						skill_level,"兵刃气劲撕开战场");
					//物理技能攻击走attack流程，熟练度提高也在那里进行计算
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					//等级压制
					int difflevel = enemy->query_level()-this_object()->query_level();
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<h){
						//命中啦 ~
						if(this_object()->weapon_type=="double_main")
							attack(s_phy_damage,s_weapon_add,"double_main",s_name_cn,
								f_cur_skill->query_name(),skill_level);
						else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
							attack(s_phy_damage,s_weapon_add,"single_main",s_name_cn,
								f_cur_skill->query_name(),skill_level);
					}
					else{
						//未命中	
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但未命中对方。";
						s1 += this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但未击中你。"; 
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());	
					}
					return;
				}
				else{
					//该使用过的技能未冷却,提示并返回
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*    施放的是dot技能    */
			else if(f_cur_skill->s_skill_type=="dot"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					broadcast_room_skill_manifestation(f_cur_skill,enemy,
						skill_level,"持续伤害印记浮现");
					//等级压制
					int difflevel = enemy->query_level()-this_object()->query_level();          
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<h){ //命中啦~
						int dot_damage=query_active_dot_damage(f_cur_skill,
							skill_level,enemy);
						int dot_applied = apply_nonstacking_dot(enemy,name,dot_damage,
							f_cur_skill->query_s_lasttime(skill_level));
						// 血海裂伤过去只在目标后续心跳才结算首跳，施放当拍仅显示
						// 动画，玩家会看到技能命中却完全不掉血。命中后立即结算
						// 第一跳；process_dot_tick() 同时把剩余节拍减一，因此总跳数
						// 和原伤害公式保持不变。
						if(dot_applied && name=="xuehailieshang")
							enemy->process_dot_tick();

						//产生仇恨值,dot的仇恨暂时定为20
						int hate=(int)(20*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						if(!dot_applied){
							s += "，但目标身上已有更强的持续伤害，未被覆盖。";
							s1 += "，但你身上已有更强的持续伤害，未被覆盖。";
						}
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

						//if(this_object()->is("player")){
						//战斗中击中对方，减攻击者武器磨损
						this_object()->reduce_fight_wield_weapon(1);
						//战斗中被攻击者击中，减防具磨损
						enemy->reduce_fight_wear_armor(1);
						//}
					}
					else { //未命中
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但被对方抵抗了。";
						s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但被你抵抗了";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());
						return;
					}
				}
				else {
					//技能还未冷却
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*      施放的是诅咒技能     */
			else if(f_cur_skill->s_skill_type=="curse"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					broadcast_room_skill_manifestation(f_cur_skill,enemy,
						skill_level,"诅咒法印笼罩目标");
					//等级压制
					int difflevel = enemy->query_level()-this_object()->query_level();          
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<h){ //命中啦~
						int curse_value =
							f_cur_skill->query_performs_attack(skill_level);
						if(f_cur_skill->s_curse_type=="defend")
							curse_value=query_rare_control_floor(f_cur_skill,
								skill_level,query_rare_defense_snapshot(enemy),
								curse_value);
						else if(f_cur_skill->s_curse_type=="attack")
							curse_value=query_rare_control_floor(f_cur_skill,
								skill_level,query_rare_physical_offense(enemy),
								curse_value);
						else if(f_cur_skill->s_curse_type=="hitte_percent" &&
						   functionp(f_cur_skill->query_rare_control_percent))
							curse_value=f_cur_skill->query_rare_control_percent(
								skill_level);
						//记录诅咒的类型
						enemy->set_debuff("curse",0,f_cur_skill->s_curse_type);
						//记录诅咒的值
						enemy->set_debuff("curse",1,curse_value);
						//记录诅咒的持续时间
						enemy->set_debuff("curse",2,f_cur_skill->query_s_lasttime(skill_level));

						//产生仇恨值,curse的仇恨暂时定为20
						int hate=(int)(20*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());

						//战斗中击中对方，减攻击者武器磨损
						this_object()->reduce_fight_wield_weapon(1);
						//战斗中被攻击者击中，减防具磨损
						enemy->reduce_fight_wear_armor(1);
					}
					else { //未命中
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但被对方抵抗了。";
						s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但被你抵抗了";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());
						return;
					}
				}
				else {
					//未冷却
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*    施放的是治疗技能    */
			else if(f_cur_skill->s_skill_type=="heal"){
				if(s_cold <= 1){
					if(this_object()->query_profeId()=="lingyi" &&
					   functionp(f_cur_skill->query_lingyi_heal_scope) &&
					   f_cur_skill->query_lingyi_heal_scope()>0){
						int applied = apply_lingyi_heal(f_cur_skill,skill_level);
						if(applied<=0){
							tell_object(this_object(),"当前没有需要治疗或净化的有效目标。\n");
							return;
						}
						this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
						this_object()->timeCold = 2;
						this_object()->f_skills[name] =
							f_cur_skill->query_s_delayTime(skill_level)+1;
						broadcast_room_skill_manifestation(f_cur_skill,0,
							skill_level,"群体治疗灵光在房间中绽放");
						if(enemy)
							enemy->flush_targets(this_object(),10*applied);
						skills_level_check(f_cur_skill->query_name());
						return;
					}
					int life_before = this_object()->get_cur_life();
					int life_limit = this_object()->query_life_max();
					int base_heal_amount =
						f_cur_skill->query_performs_attack(skill_level);
					int heal_amount = base_heal_amount;
					int rare_self_heal = query_rare_vital_floor(f_cur_skill,
						skill_level,life_limit);
					if(rare_self_heal>heal_amount)
						heal_amount=rare_self_heal;
					if(this_object()->query_debuff("curse",0)=="life"){
						int heal_reduce = this_object()->query_debuff("curse",1);
						if(heal_reduce < 0)
							heal_reduce = 0;
						if(heal_reduce > 90)
							heal_reduce = 90;
						heal_amount = heal_amount*(100-heal_reduce)/100;
					}
					int life_after = life_before+heal_amount;
					if(life_after > life_limit)
						life_after = life_limit;

					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] =
						f_cur_skill->query_s_delayTime(skill_level)+1;
					broadcast_room_skill_manifestation(f_cur_skill,this_object(),
						skill_level,"治疗灵光环绕施法者");
					this_object()->set_life(life_after);
					// 自疗产生仇恨：以 5:1 比例把治疗量计入当前敌人的仇恨表，
					// 让自我治疗者（如方士/无相/太极）在团队 PVE 中需要关注
					// 仇恨控制；对单人 PVE 无影响（自己就是唯一目标）。
					// 灵医群疗已有 10:1 在 apply_lingyi_heal 路径处理，这里
					// 不重复加。
					if(enemy && functionp(enemy->flush_targets)){
						int healed_amount = life_after - life_before;
						if(healed_amount>0)
							catch { enemy->flush_targets(this_object(),
								healed_amount/5); };
					}

					if(name=="linglianpu" || name=="wanlingchaosheng"){
						string team_id = this_object()->query_term();
						object env = environment(this_object());
						if(env && team_id!="" && team_id!="noterm"){
							foreach(all_inventory(env), object member){
								if(member==this_object() || !member->is("player") ||
								   member->query_term()!=team_id ||
								   !LOGICALZONED->can_action(
									"team",this_object(),member))
									continue;

								int member_life = member->get_cur_life();
								if(member_life <= 0)
									continue;
								int member_limit = member->query_life_max();
								int member_heal = base_heal_amount;
								int rare_member_heal = query_rare_vital_floor(
									f_cur_skill,skill_level,member_limit);
								if(rare_member_heal>member_heal)
									member_heal=rare_member_heal;
								if(member->query_debuff("curse",0)=="life"){
									int member_reduce =
										member->query_debuff("curse",1);
									if(member_reduce < 0)
										member_reduce = 0;
									if(member_reduce > 90)
										member_reduce = 90;
									member_heal =
										member_heal*(100-member_reduce)/100;
								}
								if(member_life+member_heal > member_limit)
									member->set_life(member_limit);
								else
									member->set_life(member_life+member_heal);
								tell_object(member,this_object()->query_name_cn()+
									"施放"+f_cur_skill->query_name_cn()+
									"，为你恢复了生命。\n");
							}
						}
					}

					int hate=(int)(10*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);
					s += "你施放了"+f_cur_skill->query_name_cn()+
						"(等级"+skill_level+")，恢复了"+
						format_game_number(life_after-life_before)+"点生命。";
					s1 += this_object()->query_name_cn()+"施放了"+
						f_cur_skill->query_name_cn()+"(等级"+
						skill_level+")。";
					tell_object(this_object(),s+"\n");
					tell_object(enemy,s1+"\n");
					skills_level_check(f_cur_skill->query_name());
					return;
				}
				else {
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*    镇越强制仇恨    */
			else if(f_cur_skill->s_skill_type=="taunt"){
				if(s_cold<=1){
					int forced = enemy->force_target(this_object(),
						f_cur_skill->query_performs_attack(skill_level)+
						this_object()->query_level()*10);
					if(!forced){
						tell_object(this_object(),"当前目标无法被震吼锁定。\n");
						return;
					}
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] =
						f_cur_skill->query_s_delayTime(skill_level)+1;
					broadcast_room_skill_manifestation(f_cur_skill,enemy,
						skill_level,"震势强制牵引目标仇恨");
					tell_object(this_object(),"你施放了"+
						f_cur_skill->query_name_cn()+"(等级"+skill_level+
						")，强制吸引了"+enemy->query_name_cn()+"的仇恨。\n");
					tell_object(this_object(),
						PROFESSIONVIPD->query_combat_style_effect(
							this_object(),"taunt"));
					tell_object(enemy,this_object()->query_name_cn()+
						"以震山之势锁定了你的攻势。\n");
					skills_level_check(f_cur_skill->query_name());
					return;
				}
				tell_object(this_object(),"该技能还需要"+(s_cold-1)+
					"秒冷却时间,无法使用。\n");
				return;
			}
			/*    镇越同房间队伍护盾    */
			else if(f_cur_skill->s_skill_type=="team_guard"){
				if(s_cold<=1){
					int shield = f_cur_skill->query_performs_attack(skill_level)+
						this_object()->query_str()*2;
					int rare_shield = query_rare_vital_floor(f_cur_skill,
						skill_level,this_object()->query_life_max());
					if(rare_shield>shield)
						shield=rare_shield;
					int guarded = apply_team_guard_to_group(this_object(),shield,
						f_cur_skill->query_s_lasttime(skill_level));
					if(guarded<=0){
						tell_object(this_object(),"当前没有可以获得山河壁的存活目标。\n");
						return;
					}
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] =
						f_cur_skill->query_s_delayTime(skill_level)+1;
					broadcast_room_skill_manifestation(f_cur_skill,0,
						skill_level,"守御屏障笼罩队伍");
					enemy->flush_targets(this_object(),10+shield/10);
					tell_object(this_object(),"你施放了"+
						f_cur_skill->query_name_cn()+"(等级"+skill_level+
						")，为"+guarded+"名同队成员展开了"+
						format_game_number(shield)+
						"点山河壁。\n");
					tell_object(this_object(),
						PROFESSIONVIPD->query_combat_style_effect(
							this_object(),"guard"));
					tell_object(enemy,this_object()->query_name_cn()+
						"展开山河壁护住了队伍。\n");
					skills_level_check(f_cur_skill->query_name());
					return;
				}
				tell_object(this_object(),"该技能还需要"+(s_cold-1)+
					"秒冷却时间,无法使用。\n");
				return;
			}
			/*    施放的增益魔法    */
			else if(f_cur_skill->s_skill_type=="buff"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					broadcast_room_skill_manifestation(f_cur_skill,this_object(),
						skill_level,"增益灵光凝聚成形");

					//记录buff的类型
					this_object()->set_buff("buff",0,f_cur_skill->s_curse_type);
					//记录buff的值
					int tmp_int=f_cur_skill->query_performs_attack(skill_level);
					if(f_cur_skill->s_curse_type == "absorb"){
						if(this_object()->query_profeId()=="zhenyue")
							tmp_int += (int)(this_object()->query_str()*3);
						else if(this_object()->query_profeId()=="wuyao"||this_object()->query_profeId()=="yushi"||this_object()->query_profeId()=="fangshi"||this_object()->query_profeId()=="tianxiang"||this_object()->query_profeId()=="lingyi"){
							tmp_int += (int)(this_object()->query_think()*3);
						}
						else
							tmp_int += (int)(this_object()->query_think()*3/2);
						int rare_shield = query_rare_vital_floor(f_cur_skill,
							skill_level,this_object()->query_life_max());
						if(rare_shield>tmp_int)
							tmp_int=rare_shield;
					}
					else if(f_cur_skill->s_curse_type == "defend")
						tmp_int=query_rare_control_floor(f_cur_skill,skill_level,
							query_rare_defense_snapshot(this_object()),tmp_int);
					this_object()->set_buff("buff",1,tmp_int);
					//记录buff的持续时间
					this_object()->set_buff("buff",2,f_cur_skill->query_s_lasttime(skill_level));

					//产生仇恨值,buff的仇恨暂时定为10
					int hate=(int)(10*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);

					s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
					s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
					tell_object(this_object(),s+"\n");
					tell_object(enemy,s1+"\n");
					//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
					//这里排除了狂妖的冲动技能
					if(f_cur_skill->query_name() != "chongdong")
						skills_level_check(f_cur_skill->query_name());
					return;
				}
				else {
					//未冷却
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
		}
		else {
			//无足够的法力
			s += "你的仙力不够，无法施放"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")。";
			tell_object(this_object(),s+"\n");
			return;
		}
	}
	else {
		//没有这种技能
		string stmp = "你要施放什么技能？";
		tell_object(this_object(),stmp+"\n");
		return;
	}
}

//boss技能释放
void boss_perform(string name){
	//怪死亡判断......
	if(enemy==0)
		return;
	object|zero f_cur_skill;//当前使用技能对象
	string s = "";//面向自己的战斗描述
	string s1=""; //面向敌人的战斗描述
	f_cur_skill = MUD_SKILLSD[name];
	if(f_cur_skill){
		//首先判断有这种技能
		//再判断是否有足够的法力施放该技能
		string mofa_type=f_cur_skill->s_skill_type; //得到魔法类型
		//有足够的法力
		//判断是物理还是法术技能
		/*   法术攻击技能     */
		if(mofa_type!="phy"&&mofa_type!="dot"&&mofa_type!="curse"&&mofa_type!="buff"){
			int mofa_a_low=0; //法术攻击的下限
			int mofa_a_high=0; //法术攻击的上限
			int mofa_a=0; //取得法术攻击的随即值
			int mofa_defend=0; //敌人的魔法抗性
			int fact_mofa_a=0; //最终的法术伤害
			int mofachuantou_add=this_object()->query_equip_add("mofachuantou_add");
			int myhitte= this_object()->query_if_hitte();
			//命中啦 ~
			//得到法术技能的伤害随即值
			mofa_a_low = f_cur_skill->query_performs_mofa_attack_low();	
			mofa_a_high = f_cur_skill->query_performs_mofa_attack_high();
			mofa_a = random(mofa_a_high-mofa_a_low+1)+mofa_a_low;
			//再加上装备属性带来的法术伤害提升
			//智力也会提高法伤由liaocheng于07/4/16添加
			mofa_a +=this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think());
			if(f_cur_skill->is_aoe){
				array(object) enemys;
				//是aoe魔法
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						if(enemys[i]){
							if(myhitte<0)
								myhitte=0;
							if(random(100)<myhitte){
								int target_mofa_a = mofa_a;
								//计算出相对应的敌人的魔法抗性
								switch(mofa_type) {
									case "huo_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("huoyan_defend");
									break;
									case "bing_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("bingshuang_defend");
									break;
									case "feng_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("fengren_defend");
									break;
									case "du_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("dusu_defend");
									break;
									default :
									mofa_defend = 0;
									break;
								}
								mofa_defend += enemys[i]->query_equip_add("all_mofa_defend");
								//判断暴击
								int b = this_object()->query_if_baoji(enemys[i]);
								s1+=this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn();
								if(b){
									//暴击啦 ~
									target_mofa_a=query_balanced_critical_damage(
										target_mofa_a,
										enemys[i]->query_equip_add("renxing"));
									s1 += "，产生了暴击效果！";

								}
								fact_mofa_a=query_balanced_magic_damage(
									target_mofa_a,mofa_defend,mofachuantou_add);

								//在这儿加入buff的魔法盾吸收伤害liaocheng 07/4/9
								int	attack_fact = fact_mofa_a;

								// 跨区管理员测试账号一击必杀。
								if(MANAGERD->is_cross_zone_admin(this_object()->query_name())){
									attack_fact = enemys[i]->get_cur_life() * 2;  // 确保一击必杀
								}

								string absorb_desc = "";
								if(enemys[i]->query_buff("buff",0)=="absorb"){
									if((int)enemys[i]->query_buff("buff",1) >= attack_fact){
										int remain = (int)enemys[i]->query_buff("buff",1) - attack_fact;
										attack_fact= 0;
										absorb_desc = "(被吸收)";
										if(remain <= 0)
											enemys[i]->clean_buff("buff");
										else
											enemys[i]->set_buff("buff",1,remain);
									}
									else{
										attack_fact -= (int)enemys[i]->query_buff("buff",1);
										absorb_desc = "("+format_game_number(
											(int)enemys[i]->query_buff("buff",1))+
											"点被吸收)";
										enemys[i]->clean_buff("buff");
									}
								}
								if(enemys[i]->query_buff("buff2",0)=="absorb"){
									if((int)enemys[i]->query_buff("buff2",1) >= attack_fact){
										int remain = (int)enemys[i]->query_buff("buff2",1) - attack_fact;
										attack_fact= 0;
										absorb_desc = "(被吸收)";
										if(remain <= 0)
											enemys[i]->clean_buff("buff2");
										else
											enemys[i]->set_buff("buff2",1,remain);
									}
									else{
										attack_fact -= (int)enemys[i]->query_buff("buff2",1);
										absorb_desc = "("+format_game_number(
											(int)enemys[i]->query_buff("buff2",1))+
											"点被吸收)";
										enemys[i]->clean_buff("buff2");
									}
								}
								s1 += "对你造成了 "+
									format_game_number(fact_mofa_a)+
									" 点伤害！"+absorb_desc+"\n";
								tell_object(enemys[i],s1);

								//产生仇恨值
								int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
								enemys[i]->flush_targets(this_object(),hate);

								//生命减取 
								attack_fact = enemys[i]->absorb_team_guard_damage(attack_fact);
								int life_damage = enemys[i]->get_cur_life()-attack_fact;
								if(life_damage<=0){
									//敌人死亡，则把敌人从仇恨列表中清除
									this_object()->clean_targets(enemys[i]);
									enemys[i]->fight_die();
								}
								else{
									enemys[i]->set_life(life_damage);
									enemys[i]->reduce_fight_wear_armor(1);
								}
							}
							else{
								//未命中
								s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
								tell_object(enemys[i],s1+"\n");
							}
						}
					}
				}
				return;
			}
			//不是aoe，则走原来的路线
			if(myhitte<0)
				myhitte=0;
			if(random(100)<myhitte){
				switch(mofa_type) {
					case "huo_mofa_attack":
						mofa_defend = enemy->query_equip_add("huoyan_defend");
					break;
					case "bing_mofa_attack":
						mofa_defend = enemy->query_equip_add("bingshuang_defend");
					break;
					case "feng_mofa_attack":
						mofa_defend = enemy->query_equip_add("fengren_defend");
					break;
					case "du_mofa_attack":
						mofa_defend = enemy->query_equip_add("dusu_defend");
					break;
					default:
					mofa_defend = 0;
					break;
				}
				mofa_defend += enemy->query_equip_add("all_mofa_defend");
				//判断暴击
				int b = this_object()->query_if_baoji(enemy);
				s1+=this_object()->query_name_cn()+"对你施放"+f_cur_skill->query_name_cn();
				if(b){
					//暴击啦 ~
					mofa_a=query_balanced_critical_damage(mofa_a,
						enemy->query_equip_add("renxing"));
					s1 += "，产生了暴击效果！";

				}
				fact_mofa_a=query_balanced_magic_damage(mofa_a,
					mofa_defend,mofachuantou_add);

				//在这儿加入buff的魔法盾吸收伤害liaocheng 07/4/9
				int	attack_fact = fact_mofa_a;

				// 跨区管理员测试账号一击必杀。
				if(MANAGERD->is_cross_zone_admin(this_object()->query_name())){
					attack_fact = enemy->get_cur_life() * 2;  // 确保一击必杀
				}

				string absorb_desc = "";
				if(enemy->query_buff("buff",0)=="absorb"){
					if((int)enemy->query_buff("buff",1) >= attack_fact){
						int remain = (int)enemy->query_buff("buff",1) - attack_fact;
						attack_fact= 0;
						absorb_desc = "(被吸收)";
						if(remain <= 0)
							enemy->clean_buff("buff");
						else
							enemy->set_buff("buff",1,remain);
					}
					else{
						attack_fact -= (int)enemy->query_buff("buff",1);
						absorb_desc = "("+format_game_number(
							(int)enemy->query_buff("buff",1))+"点被吸收)";
						enemy->clean_buff("buff");
					}
				}
				if(enemy->query_buff("buff2",0)=="absorb"){
					if((int)enemy->query_buff("buff2",1) >= attack_fact){
						int remain = (int)enemy->query_buff("buff2",1) - attack_fact;
						attack_fact= 0;
						absorb_desc = "(被吸收)";
						if(remain <= 0)
							enemy->clean_buff("buff2");
						else
							enemy->set_buff("buff2",1,remain);
					}
					else{
						attack_fact -= (int)enemy->query_buff("buff2",1);
						absorb_desc = "("+format_game_number(
							(int)enemy->query_buff("buff2",1))+"点被吸收)";
						enemy->clean_buff("buff2");
					}
				}
				s1 += "造成了 "+format_game_number(fact_mofa_a)+
					" 点伤害！"+absorb_desc+"\n";
				tell_object(enemy,s1);

				//产生仇恨值
				int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
				enemy->flush_targets(this_object(),hate);

				//生命减取 
				attack_fact = enemy->absorb_team_guard_damage(attack_fact);
				int life_damage = enemy->get_cur_life()-attack_fact;
				if(life_damage<=0){
					//敌人死亡，则把敌人从仇恨列表中清除
					this_object()->clean_targets(enemy);
					//在这里加入死亡处理,killing判断是杀戮还是决斗
					if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
						enemy->set_life(1);
						tell_object(this_object(),"你在决斗中战胜了 "+enemy->query_name_cn()+" ！\n");
						tell_object(enemy,this_object()->query_name_cn()+"在决斗中战胜了你！\n");
						enemy->_clean_fight();
						_clean_fight();
						enemy=0;
					}
					else{
						enemy->fight_die();
						enemy=0;
					}
					return;
				}
				enemy->set_life(life_damage);
				//战斗中被攻击者击中，减防具磨损
				enemy->reduce_fight_wear_armor(1);
			}
			else{
				//未命中	
				s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
				tell_object(enemy,s1+"\n");
			}
			return;
		}
		//   --- 物理攻击技能 ---    
		else if(f_cur_skill->s_skill_type=="phy"){
			string s_name_cn=f_cur_skill->query_name_cn();
			//判断冷却时间
			int s_phy_damage = f_cur_skill->query_performs_attack();
			int s_weapon_add = f_cur_skill->query_performs_per();
			//该技不在表中或者冷却，
			//物理技能攻击走attack流程，熟练度提高也在那里进行计算
			//等级压制
			int myhitte= this_object()->query_if_hitte();
			if(myhitte<0)
				myhitte=0;
			if(random(100)<myhitte){
				//命中啦 ~
				//if(this_object()->weapon_type=="double_main")
				attack(s_phy_damage,s_weapon_add,"double_main",s_name_cn,f_cur_skill->query_name());
				//else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
				//	attack(s_phy_damage,s_weapon_add,"single_main",s_name_cn,f_cur_skill->query_name());

			}
			else{
				//未命中	
				s1 += this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn()+"，但未击中你。"; 
				tell_object(enemy,s1+"\n");
			}
			return;
		}
		//  ---  施放的是dot技能 ---
		else if(f_cur_skill->s_skill_type=="dot"){
			if(f_cur_skill->is_aoe){
				//是aoe魔法
				array(object) enemys;
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						int myhitte= this_object()->query_if_hitte();
						if(myhitte<0)
							myhitte=0;
						if(random(100)<myhitte){   //命中啦~
							int dot_applied = apply_nonstacking_dot(enemys[i],name,
								f_cur_skill->query_performs_attack(),
								f_cur_skill->query_s_lasttime());

							//产生仇恨值,dot的仇恨暂时定为20
							int hate=(int)(20*skills_hate["test"]/100);
							enemys[i]->flush_targets(this_object(),hate);
							s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn();
							if(!dot_applied)
								s1 += "，但已有更强的持续伤害，未被覆盖。";
							tell_object(enemys[i],s1+"\n");

							//战斗中被攻击者击中，减防具磨损
							enemys[i]->reduce_fight_wear_armor(1);
						}
						else { //未命中
							s1 += this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
							tell_object(enemys[i],s1+"\n");
						}
					}
				}
				return;
			}
			//单一路线
			int myhitte= this_object()->query_if_hitte();
			if(myhitte<0)
				myhitte=0;
			if(random(100)<myhitte){   //命中啦~
				int dot_applied = apply_nonstacking_dot(enemy,name,
					f_cur_skill->query_performs_attack(),
					f_cur_skill->query_s_lasttime());

				//产生仇恨值,dot的仇恨暂时定为20
				int hate=(int)(20*skills_hate["test"]/100);
				enemy->flush_targets(this_object(),hate);

				s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn();
				if(!dot_applied)
					s1 += "，但已有更强的持续伤害，未被覆盖。";
				tell_object(enemy,s1+"\n");

				//战斗中被攻击者击中，减防具磨损
				enemy->reduce_fight_wear_armor(1);
			}
			else { //未命中
				s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
				tell_object(enemy,s1+"\n");
				return;
			}
		}
		//    ---  施放的是诅咒技能  ---
		else if(f_cur_skill->s_skill_type=="curse"){
			if(f_cur_skill->is_aoe){
				//是aoe魔法
				array(object) enemys;
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						int myhitte= this_object()->query_if_hitte();
						if(myhitte<0)
							myhitte=0;
						if(random(100)<myhitte){ //命中啦~
							//记录诅咒的类型
							enemys[i]->set_debuff("curse",0,f_cur_skill->s_curse_type);
							//记录诅咒的值
							enemys[i]->set_debuff("curse",1,f_cur_skill->query_performs_attack());
							//记录诅咒的持续时间
							enemys[i]->set_debuff("curse",2,f_cur_skill->query_s_lasttime());

							//产生仇恨值,curse的仇恨暂时定为20
							int hate=(int)(20*skills_hate["test"]/100);
							enemys[i]->flush_targets(this_object(),hate);

							s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn();
							tell_object(enemys[i],s1+"\n");

							//战斗中被攻击者击中，减防具磨损
							enemys[i]->reduce_fight_wear_armor(1);
						}
						else { //未命中
							s1 += this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
							tell_object(enemys[i],s1+"\n");
						}
					}
					return;
				}
				//单一路线
				int myhitte= this_object()->query_if_hitte();
				if(myhitte<0)
					myhitte=0;
				if(random(100)<myhitte){ //命中啦~
					//记录诅咒的类型
					enemy->set_debuff("curse",0,f_cur_skill->s_curse_type);
					//记录诅咒的值
					enemy->set_debuff("curse",1,f_cur_skill->query_performs_attack());
					//记录诅咒的持续时间
					enemy->set_debuff("curse",2,f_cur_skill->query_s_lasttime());

					//产生仇恨值,curse的仇恨暂时定为20
					int hate=(int)(20*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);

					s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn();
					tell_object(enemy,s1+"\n");
					//战斗中被攻击者击中，减防具磨损
					enemy->reduce_fight_wear_armor(1);
				}
				else { //未命中
					s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
					tell_object(enemy,s1+"\n");
				}
			}
			return;
		}
		//  ---  施放的增益魔法 ---
		else if(f_cur_skill->s_skill_type=="buff"){
			//记录buff的类型
			this_object()->set_buff("buff",0,f_cur_skill->s_curse_type);
			//记录buff的值
			this_object()->set_buff("buff",1,f_cur_skill->query_performs_attack());
			//记录buff的持续时间
			this_object()->set_buff("buff",2,f_cur_skill->query_s_lasttime());

			//产生仇恨值,buff的仇恨暂时定为10
			int hate=(int)(10*skills_hate["test"]/100);
			enemy->flush_targets(this_object(),hate);

			s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn();
			tell_object(enemy,s1+"\n");
			return;
		}
	}
	else {
		//没有这种技能
		werror("-----error boss_perform the skill "+name+" is not exist------\n");
		return;
	}
}


//战斗核心算法,普通攻击或者施放物理攻击技能时调用的接口
private void attack(int skill_add,int skill_add_per,string type,
	string skill_name_cn,void|string name_skill,void|int rare_skill_level){
	if(enemy==0){
		return;
	}
	// team_required Boss 门控：first_target 队伍同房存活人数不足时，
	// Boss reset_targets + _clean_fight 离场，防止单人硬吃硬 Boss。
	if(functionp(this_object()->is_team_required_boss) &&
	   this_object()->is_team_required_boss()){
		int min_size = 4;
		int alive = 0;
		if(functionp(this_object()->query_team_required_min_size))
			min_size = (int)this_object()->query_team_required_min_size();
		if(functionp(this_object()->count_first_target_team_in_room))
			alive = (int)this_object()->count_first_target_team_in_room();
		if(alive < min_size){
			object gate_room = environment(this_object());
			string gate_msg = "【试炼】"+this_object()->query_name_cn()+
				"环视四周，未见足额挑战者，化作流光隐去。"+
				"（硬 Boss 需 "+min_size+" 人以上队伍挑战）\n";
			if(gate_room){
				foreach(all_inventory(gate_room),object ob){
					if(ob && ob->is && ob->is("player") &&
					   functionp(ob->receive))
						catch { ob->receive(gate_msg); };
				}
			}
			Stdio.append_file(ROOT+"/log/team_pve_gate.log",
				ctime(time())[0..sizeof(ctime(time()))-2]+
				" "+this_object()->query_name()+
				" disengaged: alive="+alive+"/"+min_size+"\n");
			this_object()->reset_targets();
			this_object()->_clean_fight();
			return;
		}
	}
	object|zero rare_skill = 0;
	string fight_action_desc="";
	//本次攻击成功后的最终伤害值
	int attack_a = 0;
	//如果有魔法盾buff，则为吸收后的伤害
	int attack_fact = 0;

	int self=this_object()->query_base_damage(); //得到自身攻击力
	int add=0; //得到附加武器伤害
	int add_per=0; //得到增加武器伤害百分比
	int h;
	//首先判断攻击者的命中计算：攻击者的命中率+装备的附加命中+技能的命中(可能是100%命中技能)
	if(skill_name_cn!=""){
		h=100; //物理技能攻击，在perform()里已经作了等级压制，这里不需走普攻的命中判断
	}
	else{
		int hitte_a = this_object()->query_if_hitte();//mudlib/inherit/feature/char.pike中接口
		int difflevel = enemy->query_level()-this_object()->query_level(); 
		if(difflevel<0)
			difflevel=0;
		h = (int)(hitte_a-difflevel*5);
		if(this_object()->is_both_weapons) //双武器命中的惩罚
			h -= 10;
		if(h<30)
			h=30;
	}
	//只有攻击者命中了，才需要进行下一步计算	
	if(random(100)<h){
		//闪避计算：计算被攻击者的闪避率+装备的闪避	
		int dodge_e = enemy->query_if_dodge();
		//只有被攻击者未能闪避，才需要进行下一步计算
		int dodgechuantou_add=query_balanced_dodge_penetration(
			this_object()->query_equip_add("dodgechuantou_add"),
			skill_name_cn!="");
		//当被闪避掉以后，则判断是否无视闪避，计算闪避穿透的值，如果随机到几率 则重置闪避
		string dodgechuantou_desc="";
		if(dodge_e==1 && dodgechuantou_add>0 && random(1000)<dodgechuantou_add){//这里的闪避穿透是千分之几的基点
			dodge_e=0;//虽然躲掉了，但又被拉回来了，因为无视闪避生效。
			dodgechuantou_desc="\n(闪避穿透生效，无视对方闪避技能，你的攻击命中 【"+enemy->query_name_cn()+"】)\n";
		}
		if(dodge_e==0){

			//在这里添加武器的魔法伤害附加
			//
			///////////////////////////////

			//if(this_object()->is("player")){	
			//战斗中击中对方，减攻击者武器磨损
			this_object()->reduce_fight_wield_weapon(1);
			//战斗中被攻击者击中，减防具磨损
			enemy->reduce_fight_wear_armor(1);
			//}
			////////////////攻击者伤害计算//////////////////////////////////////
			//1.玩家的物理伤害(玩家伤害上下限之间的一个随机数值)
			if(type=="double_main" || type=="single_main") { //玩家装备的是主手武器
				//得到附加武器伤害
				add=this_object()->main_attack_attri_add+skill_add+
					this_object()->query_equip_add("attack_all");
				//得到增加武器伤害百分比
				//add_per=add+(add*this_object()->main_attack_attri_add_per*10)/100+skill_add_per; 
				add_per=this_object()->main_attack_attri_add_per*10+skill_add_per;//正确的公式
				attack_weapon = this_object()->query_main_equiped_attack();//mudlib/inherit/feature/attack.pike中定义的接口

				//描述
				if(fight_desc_arg_main=="beast"||fight_desc_arg_main=="bird"||fight_desc_arg_main=="fish"||fight_desc_arg_main=="amphibian"||fight_desc_arg_main=="bugs")
					fight_action_desc=query_fight_desc(fight_desc_arg_main);
				else {
					if(skill_name_cn=="")
						fight_action_desc=this_object()->cur_main_weapon_name+"，"+query_fight_desc(fight_desc_arg_main);
					else
						fight_action_desc=this_object()->cur_main_weapon_name;
				}
			}

			else if(type=="other") {
				//得到附加武器伤害
				add=this_object()->other_attack_attri_add+skill_add+
					this_object()->query_equip_add("attack_all");
				//得到增加武器伤害百分比
				//add_per=add+(add*this_object()->other_attack_attri_add_per*10)/100+skill_add_per; 
				add_per=this_object()->other_attack_attri_add_per*10+skill_add_per;//正确的公式	
				attack_weapon = this_object()->query_other_equiped_attack();
				if(skill_name_cn=="")
					fight_action_desc = this_object()->cur_other_weapon_name+"，"+query_fight_desc(fight_desc_arg_other);
				else 
					fight_action_desc=this_object()->cur_main_weapon_name;
			}

			//得到未暴击前的总攻击伤害,尽量避免不必要的浮点运算
			int total_attack=0;
			if(add_per) 
				total_attack = attack_weapon+(int)(attack_weapon*add_per/100)+add+self;
			else 
				total_attack = attack_weapon+add+self;
			//修罗狂意按总物理攻击百分比成长，避免固定值在高属性版本失效。
			if(this_object()->query_buff("buff",0)=="physical_attack_percent")
				total_attack += total_attack*
					(int)this_object()->query_buff("buff",1)/100;
			if(name_skill && rare_skill_level && this_object()->is("player")){
				rare_skill=MUD_SKILLSD[name_skill];
				if(rare_skill && functionp(rare_skill->query_rare_power_percent)){
					int rare_power_percent =
						rare_skill->query_rare_power_percent(rare_skill_level);
					if(rare_power_percent>100)
						total_attack=total_attack*rare_power_percent/100;
				}
			}
			if(this_object()->query_debuff("curse",0)==
			   "physical_damage_percent"){
				int damage_reduce =
					(int)this_object()->query_debuff("curse",1);
				total_attack=query_physical_damage_after_percent_curse(
					total_attack,damage_reduce);
			}

			//npc攻击力调整，除以3
			if(this_object()->is("npc")){
				total_attack = total_attack/3;
			}
			//3.计算是否有暴击，如果有，计算加成暴击率之后的攻击值=所有攻击值总和*暴击/100	
			int baoji_a = this_object()->query_if_baoji(enemy);//返回一个整数值，为%的分子形式提供
			if(baoji_a==1){
				total_attack = query_balanced_critical_damage(total_attack,
					enemy->query_equip_add("renxing"));
			}
			////////////////加上被攻击者防御计算得到最终物理伤害值attack_a/////////////////////
			defend = enemy->query_defend_power();
			//物理穿透作为有上限的无视防御伤害，由统一公式结算。
			int wulichuantou_add=this_object()->query_equip_add("wulichuantou_add");
			int wulichuantou_damage = query_balanced_penetration_damage(
				total_attack,wulichuantou_add);
			attack_a = query_balanced_physical_damage(total_attack,
				defend,wulichuantou_add);
			if(name_skill && skill_name_cn != "" && name_skill != "xueranjiangshan" && name_skill != "xueranjiangshan2"){
				attack_a = attack_a*3/2;//为了玩家能够接受，技能攻击加强1.5倍
				wulichuantou_damage = wulichuantou_damage*3/2;
			}
			//技能的伤害百分比buff在这儿添加，由liaocheng于080827添加
			int per_tmp;
			if(this_object()->query_buff("spec_attack_buff",0) != "none"){
				per_tmp = this_object()->query_buff("spec_attack_buff",1);
			}
			if(this_object()->query_buff("70_skill_buff",0) == "lieshanmengji"){
				per_tmp += this_object()->query_buff("70_skill_buff",1);
			}
			if(per_tmp)
				attack_a += total_attack*per_tmp/100;
			//减少伤害的技能在这儿添加
			if(enemy->query_buff("70_skill_buff") == "baofengfeixue")
				attack_a = attack_a*70/100;
			//剑仙70级技能伤害反弹
			string reflect_desc = "";
			if(enemy->query_buff("70_skill_buff",0) == "fanzhuanyiji"){
				int attack_reflect = attack_a*30/100;
				attack_a = attack_a - attack_reflect;
				attack_reflect = this_object()->absorb_team_guard_damage(
					attack_reflect);
				int life_left = this_object()->get_cur_life()-attack_reflect;
				if(life_left<0)
					life_left = 0;
				this_object()->set_life(life_left);
				reflect_desc = "("+
					format_game_number(attack_reflect)+"被反弹)";
			}
			//再在这儿加入武器附加的魔法伤害(如+3火焰伤害)
			attack_huoyan_add = get_attack_mofa_add("huoyan_defend",this_object()->huo_add,enemy);
			attack_bingshuang_add = get_attack_mofa_add("bingshuang_defend",this_object()->bing_add,enemy);
			attack_fengren_add = get_attack_mofa_add("fengren_defend",this_object()->feng_add,enemy);
			attack_dusu_add = get_attack_mofa_add("dusu_defend",this_object()->du_add,enemy);
			//影鬼70级毒素伤害提高的效果
			if(this_object()->query_buff("70_skill_buff",0)=="cuidu")
				attack_dusu_add += attack_dusu_add/2;

			attack_a += attack_huoyan_add+attack_bingshuang_add+attack_fengren_add+attack_dusu_add;
			if(rare_skill)
				attack_a=query_rare_direct_damage(rare_skill,attack_a,
					enemy->query_life_max(),enemy->is("player"),
					enemy->is("npc") && enemy->_boss);
			//现在的attack_a就是最终的伤害值
			if (attack_a<=0)
				attack_a=random(5);

			//在这儿加入buff的魔法盾吸收伤害liaocheng 07/4/9
			attack_fact = attack_a;

			// 跨区管理员测试账号一击必杀。
			if(MANAGERD->is_cross_zone_admin(this_object()->query_name())){
				attack_fact = enemy->get_cur_life() * 2;  // 确保一击必杀
			}
			string absorb_desc = "";
			if(enemy->query_buff("buff",0)=="absorb"){
				if((int)enemy->query_buff("buff",1) >= attack_fact){
					int remain = (int)enemy->query_buff("buff",1) - attack_fact;
					attack_fact = 0;
					absorb_desc = "(被吸收)";
					if(remain <= 0)
						enemy->clean_buff("buff");
					else
						enemy->set_buff("buff",1,remain);
				}
				else{
					attack_fact -= (int)enemy->query_buff("buff",1);
					absorb_desc = "("+format_game_number(
						(int)enemy->query_buff("buff",1))+"点被吸收)";
					enemy->clean_buff("buff");
				}
			}
			if(enemy->query_buff("buff2",0)=="absorb"){
				if((int)enemy->query_buff("buff2",1) >= attack_fact){
					int remain = (int)enemy->query_buff("buff2",1) - attack_fact;
					attack_fact = 0;
					absorb_desc = "(被吸收)";
					if(remain <= 0)
						enemy->clean_buff("buff2");
					else
						enemy->set_buff("buff2",1,remain);
				}
				else{
					attack_fact -= (int)enemy->query_buff("buff2",1);
					absorb_desc = "("+format_game_number(
						(int)enemy->query_buff("buff2",1))+"点被吸收)";
					enemy->clean_buff("buff2");
				}
			}
			//如果物理穿透大于零，则要在前端提示给玩家
			string chuantou_desc = "";
			if(wulichuantou_damage>0){
				chuantou_desc = "【物理穿透计入基础伤害 "+
					format_game_number(wulichuantou_damage)+"】";
			}
			// 山河壁也必须在播报最终伤害前结算。旧顺序先显示
			// attack_a、后扣护盾，容易让玩家看到“有伤害”但气血不变。
			attack_fact = enemy->absorb_team_guard_damage(attack_fact);
			string attack_fact_desc = format_game_number(attack_fact);
			//在这里产生威胁值
			int hate=(int)(attack_fact*skills_hate["test"]/100);
			if(name_skill && MUD_SKILLSD[name_skill] &&
			   functionp(MUD_SKILLSD[name_skill]->query_hate_multiplier))
				hate = hate*MUD_SKILLSD[name_skill]->query_hate_multiplier()/100;
			enemy->flush_targets(this_object(),hate);
			if(!enemy->in_combat)
				enemy->_fight(this_object());
			////////////////////////战斗描述///////////////////////////////////////////////
			if(baoji_a==1) {
				if(skill_name_cn==""){
					tell_object(this_object(),"你紧握"+fight_action_desc+"，产生暴击效果，对"+enemy->query_name_cn()+"造成了"+attack_fact_desc+"点实际伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"，对你的攻击产生暴击效果，造成了"+attack_fact_desc+"点实际伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
				}
				else {
					tell_object(this_object(),"你紧握"+fight_action_desc+"施展"+skill_name_cn+"，产生暴击效果，对"+enemy->query_name_cn()+"造成了"+attack_fact_desc+"点实际伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"施展"+skill_name_cn+"，对你的攻击产生暴击效果，造成了"+attack_fact_desc+"点实际伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
					skills_level_check(name_skill);
				}
			}
			else {
				if(skill_name_cn==""){
					tell_object(this_object(),"你紧握"+fight_action_desc+"，对"+enemy->query_name_cn()+"造成了"+attack_fact_desc+"点实际伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"，对你造成了"+attack_fact_desc+"点实际伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//tell_object(enemy,this_object()->query_name_cn()+"紧握"+fight_action_desc+"，对你造成了"+attack_a+"点伤害"+absorb_desc+"\n");
				}
				else {
					tell_object(this_object(),"你紧握"+fight_action_desc+"施展"+skill_name_cn+"，对"+enemy->query_name_cn()+"造成了"+attack_fact_desc+"点实际伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+"施展"+skill_name_cn+"，对你造成了"+attack_fact_desc+"点实际伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
					if(name_skill != "xueranjiangshan")
						skills_level_check(name_skill);
				}
			}
			int life_damage = enemy->get_cur_life()-attack_fact;
			if(life_damage<=0){
				//敌人死亡，则把敌人从仇恨列表中清除
				this_object()->clean_targets(enemy);
				//在这里加入死亡处理,killing判断是杀戮还是决斗
				if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
					enemy->set_life(1);
					tell_object(this_object(),"你在决斗中战胜了 "+enemy->query_name_cn()+" ！\n");
					tell_object(enemy,this_object()->query_name_cn()+"在决斗中战胜了你！\n");
					enemy->_clean_fight();
					_clean_fight();
				}
				else
					enemy->fight_die();
				enemy=0;
				return;
			}
			enemy->set_life(life_damage);
		}
		//攻击者命中对方，但被对方闪避了
		else{
			if(skill_name_cn==""){
				tell_object(this_object(),"你的这次攻击被对方闪避了过去!\n");
				tell_object(enemy,"你躲闪开了"+this_object()->query_name_cn()+"的这次攻击.\n");
			}
			else {
				tell_object(this_object(),"你的"+skill_name_cn+"被对方闪避了过去!\n");
				tell_object(enemy,"你躲闪开了"+this_object()->query_name_cn()+"的"+skill_name_cn+".\n");
			}
		}
	}
	//攻击者本次攻击没有命中
	else{
		if(skill_name_cn==""){
			tell_object(this_object(),"你的攻击没有击中对方!\n");
			tell_object(enemy,this_object()->query_name_cn()+"没有击中你。\n");
		}
		else {
			tell_object(this_object(),"你的"+skill_name_cn+"没有击中对方!\n");
			tell_object(enemy,this_object()->query_name_cn()+"的"+skill_name_cn+"没有击中你.\n");
		}
	}
}
private void heart_beat_action(){
	// 配置热分区后必须在死亡结算和任何伤害前切断跨区旧目标。
	if(enemy && !LOGICALZONED->can_action("combat",this_object(),enemy)){
		if(this_object()->if_in_targets(enemy))
			this_object()->clean_targets(enemy);
		_clean_fight();
		return;
	}
	//在这儿也添加死亡处理过程，是为了处理由于dot而死亡的情况，dot是在自己的心跳中减去自己的血，
	//要是血减为零了，则表示自己死亡，但不能在自己的心跳中通过语句this_object()->fight_die()来处
	//理死亡，这样后台会报错。因此只有在敌人每次心跳时检查自己的血量，然后敌人调用
	//enemy->fight_die()来完成自己的死亡处理
	if(enemy&&enemy->get_cur_life()<=0&&enemy->in_combat){
		if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
			enemy->set_life(1);
			tell_object(this_object(),"你在决斗中战胜了 "+enemy->query_name_cn()+" ！\n");
			tell_object(enemy,this_object()->query_name_cn()+"在决斗中战胜了你！\n");
			enemy->_clean_fight();
			_clean_fight();
			enemy=0;
		}
		else{
			enemy->fight_die();
			enemy = 0;
		}
		return;
	}
	//自己死亡后将不作出任何动作，等待死亡处理
	//if(enemy&&this_object()->get_cur_life()<=0)
	//	return;

	enemy=this_object()->get_target(); //这句位置不对，要琢磨下
	if(enemy==0){
		//这个地方必须作处理，否则会出现在战斗状态下无法退出的问题。。。。
		_clean_fight();
		return;
	}
	else if(!LOGICALZONED->can_action("combat",this_object(),enemy)){
		if(this_object()->if_in_targets(enemy))
			this_object()->clean_targets(enemy);
		_clean_fight();
		return;
	}
	else if(environment(this_object())!=environment(enemy)){
		if(this_object()->if_in_targets(enemy))
			this_object()->clean_targets(enemy);
		if(this_object()->if_targets_null())
			_clean_fight();
		return;
	}
	else{
		this_object()->timeCount++;
		// 共享宠物与本命灵伴共用唯一战斗位，不能叠加协战。
		if(this_object()->is("player")){
			if(SPIRIT_COMPANIOND->query_pet_battle_source(
			   this_object())=="personal")
				SPIRIT_COMPANIOND->perform_spirit_companion_combat_assist(
					this_object(),enemy);
			else{
				PETD->perform_pet_combat_assist(this_object(),enemy);
				PETD->perform_pet_basic_assist(this_object(),enemy);
			}
			// 灵医百草助手常态化：未挂机时也按 PVE 上下文自动施法。
			// 挂机模式下 flushview 周期已处理，函数内部会跳过避免重复。
			PROFESSIONVIPD->try_lingyi_active_combat_assist(this_object());
		}
		if(check_pk_fast_decision())
			return;
		if(this_object()->timeCold>0)
			this_object()->timeCold--;
		if(this_object()->eat_timeCold>0)
			this_object()->eat_timeCold--;
		
		//精力每次心跳+3点（心跳间隔在efuns中为2秒一次，这样也就是2秒加3点精力值，上限100）	
		//貌似这里的心跳，战斗状态才触发，不能在这里设定
		//if(!this_object()->is("npc"))
		//	this_object()->set_jingli(this_object()->query_jingli()+3);
		
		//一般技能冷却时间
		if(this_object()->get_cur_life()>0&&this_object()->get_cur_life()<this_object()->life_max)
			this_object()->set_life(this_object()->get_cur_life()+this_object()->rase_life);
		if(this_object()->get_cur_mofa()>0&&this_object()->get_cur_mofa()<this_object()->mofa_max)
			this_object()->set_mofa(this_object()->get_cur_mofa()+this_object()->rase_mofa);
		if(this_object()->f_skills&&sizeof(this_object()->f_skills)){
			foreach(indices(this_object()->f_skills),string index){
				if(index&&sizeof(index)){
					this_object()->f_skills[index]--;
					if(this_object()->f_skills[index]<1)
						this_object()->f_skills[index]=1;
				}
			}
		}
		/////////////////////////////////////////////////////////
		//
		//在这儿可以读取自己身上的debuff映射表，来影响自身的状态
		//
		/////////////////////////////////////////////////////////
		// 持续伤害统一走可测试的单跳结算，并把真实扣血/护盾吸收反馈给
		// 施法者和玩家目标；死亡仍由心跳外的既有兜底完成。
		if(this_object()->query_debuff("dot",0)!="none"){
			mapping dot_tick = process_dot_tick();
			if(dot_tick["defeated"])
				return;
		}
		//如果身上有诅咒状态
		if(this_object()->query_debuff("curse",0)!="none"){
			int curse_time=this_object()->query_debuff("curse",2)-1;
			if(curse_time<=0){
				this_object()->clean_debuff("curse");
			}
			else
				this_object()->set_debuff("curse",2,curse_time);
		}
		if(this_object()->query_debuff("curse2",0)!="none"){
			int curse_time=this_object()->query_debuff("curse2",2)-1;
			if(curse_time<=0){
				this_object()->clean_debuff("curse2");
			}
			else
				this_object()->set_debuff("curse2",2,curse_time);
		}
		//如果身上有buff状态
		if(this_object()->query_buff("buff",0)!="none"){
			int buff_time=this_object()->query_buff("buff",2)-1;
			if(buff_time<=0)
				this_object()->clean_buff("buff");
			else
				this_object()->set_buff("buff",2,buff_time);
		}
		if(this_object()->query_buff("buff2",0)!="none"){
			int buff_time=this_object()->query_buff("buff2",2)-1;
			if(buff_time<=0)
				this_object()->clean_buff("buff2");
			else
				this_object()->set_buff("buff2",2,buff_time);
		}

		//在这里处理增益和降速诅咒的影响
		this_object()->attack_speed_main=this_object()->raw_attack_speed_main;	
		this_object()->attack_speed_other=this_object()->raw_attack_speed_other;
		if(this_object()->query_buff("buff",0)=="speed"){
			this_object()->attack_speed_main-=this_object()->query_buff("buff",1);
			this_object()->attack_speed_other-=this_object()->query_buff("buff",1);
			if(this_object()->attack_speed_main<=0)
				this_object()->attack_speed_main = 1;
			if(this_object()->attack_speed_other<=0)
				this_object()->attack_speed_other = 1;
		}
		if(this_object()->query_debuff("curse",0)=="speed"){
			this_object()->attack_speed_main+=this_object()->query_debuff("curse",1);
			this_object()->attack_speed_other+=this_object()->query_debuff("curse",1);
		}
		///////////////////////////////////////////////////////////////////////
		//               end
		///////////////////////////////////////////////////////////////////////
	}
	if(!in_combat)
		return;
	// enemy 可能在心跳间隙被析构（DOT call_out fight_die、他人抢杀、
	// cleanup 等），此时 in_combat 还是 1 但 enemy 已经是 0。
	// 使用一次性局部快照，避免守卫之后全局 enemy 又被异步清空。
	object action_enemy=enemy;
	// 没有 NULL 守卫会让目标字段访问抛 "Indexing the NULL value"，
	// 整个 heart_beat_action 中断，怪物既不死玩家也不出手 —— 玩家看
	// 到的就是"零血怪"和"挂不了级"。
	if(!action_enemy || !objectp(action_enemy)){
		_clean_fight();
		return;
	}
	string cmd,arg;
	if(action&&sscanf(action,"%s %s",cmd,arg)==0)
		cmd=action;
	if(!present(action_enemy,environment(this_object()),0,this_object())){
		if(this_object()->if_in_targets(action_enemy))
			this_object()->clean_targets(action_enemy);
	}
	else if(cmd=="escape"){ 
		escape();
	}
	else if(cmd=="perform"){
		perform(arg);
	}
	//	else if(cmd=="surrender"){
	//		surrender(arg);
	//	}
	else{
		//boss技能攻击，liaocheng于07/6/18添加
		if(this_object()->_boss){
			foreach(indices(this_object()->boss_skills),string time_str){
				array(string) tmp_arr = time_str/"/";
				int first_time = (int)tmp_arr[0];
				int s_time = (int)tmp_arr[1];
				if(this_object()->timeCount==first_time || this_object()->timeCount%s_time == 0){
					boss_perform(this_object()->boss_skills[time_str]);
				}
			}
		}
		//////////////////////////////////////

		// 玩家自动连招每个战斗心跳最多施放一次，并按优先1→2→3选择
		// 首个满足原有冷却、法力、等级和武器条件的技能。NPC/Boss继续
		// 使用历史单技能节奏，避免改变任何怪物战斗数值共识。
		if(this_object()->is && this_object()->is("player")){
			string ready_skill=AUTOFIGHTD->query_ready_auto_skill(
				this_object());
			if(ready_skill!="")
				perform(ready_skill);
		}
		else if(this_object()->skills_enable!="" &&
		   this_object()->skills_enable_colddown!=0){
			if(autoPerforming==1){
				autoPerforming = 0;
				perform(this_object()->skills_enable);
			}
			else if((this_object()->timeCount%
			   this_object()->skills_enable_colddown)==0)
				perform(this_object()->skills_enable);
		}
		//双手都拿武器
		if(this_object()->weapon_type=="both"){
			//判定时间
			if((this_object()->timeCount%this_object()->attack_speed_main)==0&&(this_object()->timeCount%this_object()->attack_speed_other)==0){
				attack(0,0,"single_main","");
				if(enemy!=0)
					attack(0,0,"other","");
			}
			else if((this_object()->timeCount==1)||((this_object()->timeCount%this_object()->attack_speed_main)==0)){
				attack(0,0,"single_main","");
			}
			else if((this_object()->timeCount%this_object()->attack_speed_other)==0){
				attack(0,0,"other","");
			}
		}
		else if(this_object()->weapon_type=="double_main"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_main==0){
				attack(0,0,"double_main","");
			}
		}
		else if(this_object()->weapon_type=="single_main"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_main==0){
				attack(0,0,"single_main","");
			}
		}
		else if(this_object()->weapon_type=="other"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_other==0){
				attack(0,0,"other","");
			}
		}
		else if(this_object()->weapon_type=="none"){
			attack(0,0,"single_main","");
		}
		if(enemy && environment(this_object())==environment(enemy))
			if(enemy->first_fight == 0 || !enemy->in_combat){
				enemy->_fight(this_object());
				enemy->first_fight = 1;
			}
	}
	set_action("attack");
}

void set_action(string _action){
	action=_action;
}

int _fight(object _enemy){
	if(!_enemy || !LOGICALZONED->can_action("combat",this_object(),_enemy)){
		if(this_object()->is("player"))
			tell_object(this_object(),"逻辑分区隔离中，不能与该目标交战。\n");
		return 0;
	}
	// 团队硬 Boss 门控：玩家攻击 Boss 前，检查 Boss 是否要求最低队伍人数。
	// 不足时拒绝进入战斗，防止单人把 Boss 当沙袋刷。
	if(_enemy->is("npc") &&
	   functionp(_enemy->is_team_required_boss) &&
	   _enemy->is_team_required_boss()){
		int min_size = 4;
		int alive = 0;
		if(functionp(_enemy->query_team_required_min_size))
			min_size = (int)_enemy->query_team_required_min_size();
		// 计算当前玩家的队伍在同房存活人数
		string tid = (string)this_object()->query_term();
		if(tid && tid!="noterm" && tid!=""){
			object room = environment(this_object());
			if(room){
				foreach(all_inventory(room),object ob){
					if(ob && ob->is && ob->is("player") &&
					   (string)ob->query_term()==tid &&
					   ob->get_cur_life()>0)
						alive++;
				}
			}
		}
		if(alive < min_size){
			if(this_object()->is("player"))
				tell_object(this_object(),
					"【试炼】"+_enemy->query_name_cn()+
					"周围的结界排斥着你：硬 Boss 需 "+
					min_size+" 人以上队伍才能挑战。\n");
			return 0;
		}
	}
	if(this_object()->hind == 1) 
		this_object()->hind = 0;
	if(this_object()->query_buff("spec",0) == "hind"){
		this_object()->clean_buff("spec");
		m_delete(this_object()["/danyao"],"spec");
	}
	if(!in_combat){ //如果自己在非战斗状态，则是刚开始战斗，需要得到战斗快照
		this_object()->sucide = 0;
		enemy=_enemy;
		if(this_object()->is("npc")){
			//如果是城主,受到攻击会发出通告
			if(this_object()->query_npc_type()=="city_lord"){
				object env = environment(this_object());
				string city_name = env->query_belong_to();
				string city_name_cn = "";
				if(city_name=="xiqicheng")
					city_name_cn = "西岐城";
				else if(city_name=="chaogecheng")
					city_name_cn = "朝歌城";
				string notice = "战况！"+city_name_cn+"，"+this_object()->query_name_cn()+"遭到了攻击！\n";
				CITYD->notice_update(notice);
			}		
			//组队记录
			// enemy 可能在 kill() 链路中被析构；召唤物还会攻击
			// 没有 query_term() 接口的普通 NPC。对象和可选接口都要校验。
			if(enemy && objectp(enemy)){
				object combat_credit =
					SUMMOND->query_combat_credit_owner(enemy);
				if(!combat_credit)
					combat_credit=enemy;
				this_object()->term_who_fight_npc =
					functionp(combat_credit->query_term) ?
					combat_credit->query_term() : "";
				//谁先开始的攻击，掉落物品属于谁
				this_object()->who_fight_npc = combat_credit->query_name();
			}
		}
		//敌人的仇恨列表中加入自己
		this_object()->flush_targets(enemy,1); //初始仇恨值为1
		in_combat=1;
		action="attack";
		//初始化战斗快照
		//当前战斗玩家装备武器的类型,速度
		this_object()->timeCount=0;//战斗时间计数
		this_object()->timeCold=0; //法术公共冷却时间
		this_object()->eat_timeCold=0; //法术公共冷却时间
		this_object()->rase_life=this_object()->query_equip_add("rase_life_add"); //战斗生命回复
		this_object()->rase_mofa=this_object()->query_equip_add("rase_mofa_add"); //战斗魔法回复
		this_object()->is_both_weapons = 0;  //是否为双武器
		this_object()->cur_main_weapon_name ="";//主手武器名
		this_object()->cur_other_weapon_name = "";//副手武器名
		this_object()->weapon_type = "";//武器类型,主,副,双手
		this_object()->attack_speed_main = 0;//主手速度
		this_object()->attack_speed_other = 0;//副手速度
		this_object()->raw_attack_speed_main = 0;//主手速度
		this_object()->raw_attack_speed_other = 0;//副手速度
		this_object()->main_attack_attri_add=0; //主手武器附加的武器伤害 
		this_object()->main_attack_attri_add_per=0; //主手武器增加的武器伤害百分比
		this_object()->other_attack_attri_add=0; //副手.. 
		this_object()->other_attack_attri_add_per=0; //副手..
		//主手附加魔法伤害初始化
		this_object()->huo_add=this_object()->query_equip_add("attack_huoyan");
		this_object()->bing_add=this_object()->query_equip_add("attack_bingshuang");
		this_object()->feng_add=this_object()->query_equip_add("attack_fengren");
		this_object()->du_add=this_object()->query_equip_add("attack_dusu");
		this_object()->spec_add=0;//this_object()->query_equip_add("attack_spec");

		//技能战斗快照20070131////////////////////////////
		//([skill_name:skill_limit_time])
		//this_object()->f_skills = ([]);
		//初始化debuff映射表
		/*
		   this_object()->set_debuff("dot",0,"none");
		   this_object()->set_debuff("dot",1,0);
		   this_object()->set_debuff("dot",2,0);
		   this_object()->set_debuff("curse",0,"none");
		   this_object()->set_debuff("curse",1,0);
		   this_object()->set_debuff("curse",2,0);
		//初始化buff映射表
		this_object()->set_buff("buff",0,"none");
		this_object()->set_buff("buff",1,0);
		this_object()->set_buff("buff",2,0);
		 */
		//描述
		fight_desc_arg_main=query_fight_type();
		items = this_object()->query_equip();//[string:object]
		if(items["single_main_weapon"]&&items["single_other_weapon"]){
			this_object()->is_both_weapons = 1;
			this_object()->weapon_type = "both";//这里的weapon_type是指武器的装备情况
			//获得武器的攻速
			this_object()->raw_attack_speed_main = items["single_main_weapon"]->query_speed_power();	
			this_object()->raw_attack_speed_other = items["single_other_weapon"]->query_speed_power();	
			//获得武器的名字
			this_object()->cur_main_weapon_name = items["single_main_weapon"]->query_name_cn();
			this_object()->cur_other_weapon_name = items["single_other_weapon"]->query_name_cn();
			//获得武器的伤害附加(附加属性)
			//伤害附加
			this_object()->set_attack_attri_add("main",items["single_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add("other",items["single_other_weapon"]->query_attack_add());
			//伤害百分比附加
			this_object()->set_attack_attri_add_per("main",items["single_main_weapon"]->query_weapon_attack_add());
			this_object()->set_attack_attri_add_per("other",items["single_other_weapon"]->query_weapon_attack_add());

			//获得武器所属大类：jian，dao，qiang等等
			if(fight_desc_arg_main=="") {
				fight_desc_arg_main = items["single_main_weapon"]->query_item_weapon_type();
				fight_desc_arg_other = items["single_other_weapon"]->query_item_weapon_type();
			}
		}
		else if(items["double_main_weapon"]){
			this_object()->weapon_type = "double_main";
			this_object()->raw_attack_speed_main = items["double_main_weapon"]->query_speed_power();
			this_object()->cur_main_weapon_name = items["double_main_weapon"]->query_name_cn();
			//主手双手伤害附加
			this_object()->set_attack_attri_add("main",items["double_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("main",items["double_main_weapon"]->query_weapon_attack_add());

			//描述
			if(fight_desc_arg_main=="")
				fight_desc_arg_main = items["double_main_weapon"]->query_item_weapon_type();
		}
		else if(items["single_main_weapon"]){
			this_object()->weapon_type = "single_main";
			this_object()->raw_attack_speed_main = items["single_main_weapon"]->query_speed_power();
			this_object()->cur_main_weapon_name = items["single_main_weapon"]->query_name_cn();
			//主手单手武器伤害附加
			this_object()->set_attack_attri_add("main",items["single_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("main",items["single_main_weapon"]->query_weapon_attack_add());

			if(fight_desc_arg_main=="")
				fight_desc_arg_main = items["single_main_weapon"]->query_item_weapon_type();
		}
		else if(items["single_other_weapon"]){
			this_object()->weapon_type = "other";
			this_object()->raw_attack_speed_other = items["single_other_weapon"]->query_speed_power();
			this_object()->cur_other_weapon_name = items["single_other_weapon"]->query_name_cn();
			//副手伤害附加
			this_object()->set_attack_attri_add("other",items["single_other_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("other",items["single_other_weapon"]->query_weapon_attack_add());

			//描述
			if(fight_desc_arg_main=="")
				fight_desc_arg_other = items["single_other_weapon"]->query_item_weapon_type();
		}
		else{
			this_object()->weapon_type = "none";
			this_object()->raw_attack_speed_main = 1; 
			this_object()->cur_main_weapon_name = "抡起拳头";
			if(fight_desc_arg_main=="")
				fight_desc_arg_main = "none";
		}
		//自动释放的技能
		object|zero sk;
		if(this_object()->skills_enable&&sizeof(this_object()->skills_enable)){
			sk = query_learned_skill_object(this_object()->skills_enable);
			if(sk){
				autoPerforming = 1;
				this_object()->skills_enable_colddown =
					sk->query_s_delayTime()+1;
			}
			else{
				autoPerforming = 0;
				this_object()->skills_enable = "";
			}
		}
	}
	else{ //已处于战斗状态了，则把对方加入到自己的仇恨列表中 
		this_object()->flush_targets(_enemy,1);
	}
	//开始战斗心跳
	if(query_heart_beat()==0){
		set_heart_beat(1);
		tmp_heart_beat=1;
	}
	return 1;
}

//由liaocheng于 07/1/30添加
//this_object()->用于设置char.pike中战斗快照的各种魔法附加伤害
int get_attack_mofa_add(string type,int attack,object enemy){
	int tmp1,tmp2,result;
	if(attack){
		if((tmp1=enemy->query_equip_add(type))||(tmp2=enemy->query_equip_add("all_mofa_defend"))){
			result = attack-(int)(attack*(tmp1+tmp2)/400);
			if(result<0)
				result=0;
			return result;
		}
		else 
			return attack;
	}
	else return 0;
}

int kill(string|object _enemy,int count){
	object ob=present(_enemy,environment(this_object()),count,this_object());
	if(ob){
		if(!in_combat)//{
			killing=1;
		_fight(ob);
		if(ob->first_fight == 1)
			ob->_fight(this_object());
		//ob->kill_notify(this_object());
		return 1;
		//}
		//else
		//	return 0;
	}
}
int fight(string|object _enemy,int count,int flag){
	object ob=present(_enemy,environment(this_object()),count,this_object());
	if(ob){
		if(ob->in_combat){
			tell_object(this_object(),"你要切磋的人正在战斗中，请稍候再试。\n[返回:look]\n");
			return 0;
		}
		if(flag){
			//接受挑战者执行
			tell_object(ob,this_object()->query_name_cn()+"接受了你的挑战。\n");
			//设置决斗标示，因为帮战要求，由liaocheng于08/08/30添加 
			ob->kill_flag = 0;
			this_object()->kill_flag = 0;

			_fight(ob);
			ob->_fight(this_object());
			return 1;
		}
		else{
			//挑战发起者执行
			tell_object(this_object(),"你向"+ob->query_name_cn()+"发起了决斗邀请，请在原地等待对方的同意。\n[返回:look]\n");
			tell_object(ob,this_object()->query_name_cn()+"想和你决斗，如果愿意接受请接受挑战。[接受挑战:fight "+this_object()->query_name()+" "+count+" 1]\n[返回:look]\n");
		}

	}
	else
		tell_object(this_object(),"你要切磋的人不在当前场景，请跟他处于同一场景进行切磋。\n[返回:look]\n");
	return 0;
}
//固定显示当前攻击者和被攻击者生命法力状况
	string query_cur_life(){
		if(enemy==0)
			return "";
		string s = "";
		if(in_combat&&enemy!=0){
			//这里的生命显示
			s += "生命:"+format_game_number(this_object()->get_cur_life())+
				" | 法力:"+format_game_number(this_object()->get_cur_mofa())+"\n";
			//s += "生命:"+(this_object()->get_cur_life()==0?1:this_object()->get_cur_life())+" | 法力:"+this_object()->get_cur_mofa()+"\n";
			s += "--------\n";
			//s += "对方生命:"+(enemy->get_cur_life()==0?1:enemy->get_cur_life())+" | 对方目标:"+enemy->get_target_name()+"\n";
			s += "对方生命:"+format_game_number(enemy->get_cur_life())+
				" | 对方目标:"+enemy->get_target_name()+"\n";
			s += "--------\n";
		}
		return s;
	}
string query_fighting_msg(){
	string s = this_object()->drain_catch_tell(0,6);
	if(enemy==0){
		s+= "战斗结束了。\n[返回:look]\n";
	}
	return s;
}
string query_status(){
	string s = "";
	string more = "\n";
	string buff_line = "";
	string buff_kind;
	array(string) buff_kinds = ({
		"attri_base","attri_attack","attri_defend","attri_vice",
		"attri_luck","attri_honer","attri_exp",
		"te_base","te_attack","te_defend","te_vice",
		"te_luck","te_honer","te_exp",
	});
	if(this_object()->red_flag && environment(this_object())->query_room_type()=="city")
		more = "(可杀戮)\n";
	if(this_object()->in_combat && enemy){
		string enemy_name = "目标识别中";
		if(functionp(enemy->query_name_cn) && enemy->query_name_cn()!="")
			enemy_name = enemy->query_name_cn();
		s += "交战中（"+enemy_name+"）";
	}
	else
		s += "游荡中";
	// 显示当前激活的丹药/特药 buff 名称和剩余时间，让玩家在战斗小窗里直接看到生效中的特效。
	foreach(buff_kinds, string kind){
		string buff_name = "";
		int remain_min;
		if(this_object()->query_buff(kind,0) == "none")
			continue;
		remain_min = (int)this_object()->query_buff(kind,2);
		if(remain_min <= 0)
			continue;
		if(has_prefix(kind,"te_")){
			mixed te = this_object()["/teyao/"+kind];
			if(arrayp(te) && sizeof(te) >= 4)
				buff_name = (string)te[3];
		}
		else{
			buff_name = (string)this_object()["/danyao/"+kind];
		}
		if(buff_name == "")
			continue;
		if(buff_line != "")
			buff_line += " ";
		buff_line += buff_name+"("+remain_min+"分钟)";
	}
	if(buff_line != "")
		s += "\n特效："+buff_line;
	return s+more;
}
/*	void attack_notify(object who){
	if(enemy==0)
	_fight(who);
	else if(who!=enemy)
	if(random(100)<50) enemy=who;
	}
	void kill_notify(object who){
	if(enemy==0)
	_fight(who);
	killing=1;
//tell_object(enemy,MUD_EMOTED->filter(killing_msg+"\n",this_object(),enemy,enemy));
}
 */
private string initer=(this_object()->add_heart_beat(heart_beat_action,1),"");
