#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))

#define AUTOFIGHT_DAILY_SECONDS (8*60*60)
#define AUTOFIGHT_VIP_BONUS_SECONDS (2*60*60)
#define AUTOFIGHT_MAX_VIP_LEVEL 4
#define AUTOFIGHT_ROUTE_COOLDOWN 8
#define AUTOFIGHT_ROAM_NO_TARGET_TICKS 3
#define AUTOFIGHT_ROAM_BACKTRACK_TICKS 6
#define AUTOFIGHT_LOOT_RETRY_SECONDS 30
#define AUTOFIGHT_CONFIG_VERSION 8
#define AUTOFIGHT_CLEANUP_NAME_LIMIT 20
#define AUTOFIGHT_SCAN_MAX_OBJECTS 128

private array(string) auto_buff_kinds = ({
	"attri_base",
	"attri_attack",
	"attri_defend",
	"attri_vice",
	"attri_luck",
	"attri_honer",
	"attri_exp",
	// 商城特药（每日次数受 query_max_yao() 限制），玩家显式开启挂机嗑药时一并代吃。
	"te_base",
	"te_attack",
	"te_defend",
	"te_vice",
	"te_luck",
	"te_honer",
	"te_exp",
});

private int autofight_scan_count;
private int autofight_scan_deferred_objects;

private array(mapping(string:mixed)) smart_training_routes = ({
	([
		"max":2,
		"level":1,
		"name":"初入仙途",
		"human":"congxianzhen/shangshanlu",
		"monst":"jinaodao/chucuntulu",
		"third":"congxianzhen/shangshanlu",
	]),
	([
		"max":5,
		"level":3,
		"name":"村外试炼",
		"human":"congxianzhen/xiaoshouxueyiceng",
		"monst":"jinaodao/qianshakeng",
		"third":"huanyecun/huanyecun",
	]),
	([
		"max":8,
		"level":6,
		"name":"营地试炼",
		"human":"kunlunshan/piaohuaxi",
		"monst":"jinaodao/wanmuyuan",
		"third":"liehuoying/liehuonan",
	]),
	([
		"max":10,
		"level":9,
		"name":"迷雾试炼",
		"human":"kunlunshan/pubudongxuesanceng",
		"monst":"jinaodao/xiangshudongsiceng",
		"third":"mihuandao/nongwusenlin",
	]),
	([
		"max":13,
		"level":11,
		"name":"初阶修行",
		"human":"kunlunshan/xiuxian",
		"monst":"jinaodao/fenghouzhen",
		"third":"kunlunshan/xiuxian",
	]),
	([
		"max":16,
		"level":14,
		"name":"炼体修行",
		"human":"kunlunshan/lianshen",
		"monst":"jinaodao/hongshazhen",
		"third":"kunlunshan/lianshen",
	]),
	([
		"max":19,
		"level":17,
		"name":"洞府修行",
		"human":"shierxianjing/taoyuantongjiuceng",
		"monst":"wugongdong/xieduhe",
		"third":"shierxianjing/taoyuantongjiuceng",
	]),
	([
		"max":22,
		"level":20,
		"name":"灵境修行",
		"human":"shierxianjing/taoyuantongshijiuceng",
		"monst":"wugongdong/rongchongfang",
		"third":"shierxianjing/taoyuantongshijiuceng",
	]),
	([
		"max":25,
		"level":23,
		"name":"深洞修行",
		"human":"shierxianjing/magudongshisanceng",
		"monst":"wugongdong/wugongshenyuan",
		"third":"shierxianjing/magudongshisanceng",
	]),
	([
		"max":28,
		"level":26,
		"name":"水阁修行",
		"human":"plshuige/qingyuntai",
		"monst":"plshuige/liexiandao",
		"third":"liangjinghu/yinhuxuanqiao",
	]),
	([
		"max":31,
		"level":29,
		"name":"云海修行",
		"human":"plshuige/mianyunti",
		"monst":"plshuige/yunpulu",
		"third":"liangjinghu/huayaotingyuan15",
	]),
	([
		"max":34,
		"level":32,
		"name":"城外历练",
		"human":"xiqiwaicheng/nanchengqiangjiao",
		"monst":"chaogewaicheng/chaogedongnanlou",
		"third":"muye/xicezhanhao",
	]),
	([
		"max":37,
		"level":35,
		"name":"牧野历练",
		"human":"xiqiwaicheng/huanhuashuitai",
		"monst":"chaogewaicheng/eluanshihetan",
		"third":"muye/guzhandao",
	]),
	([
		"max":40,
		"level":38,
		"name":"战场历练",
		"human":"muye/poyaozhen9",
		"monst":"muye/fuluying9",
		"third":"muye/hexiyandong10",
	]),
	([
		"max":43,
		"level":41,
		"name":"外海历练",
		"human":"waihai/lingyicheng",
		"monst":"waihai/lingyicheng",
		"third":"waihai/lingyicheng",
	]),
	([
		"max":46,
		"level":44,
		"name":"外海深修",
		"human":"waihai/qianhaiguanmucong",
		"monst":"waihai/qianhaiguanmucong",
		"third":"waihai/qianhaiguanmucong",
	]),
	([
		"max":49,
		"level":47,
		"name":"三界进阶",
		"human":"yandigu/xiaoshilu",
		"monst":"fuxishan/fuxidongrukou",
		"third":"huangyuan/yingxielu",
	]),
	([
		"max":52,
		"level":50,
		"name":"流光平原历练",
		"human":"liuguangpingyuan/liuguangchalu",
		"monst":"liuguangpingyuan/liuguangchalu",
		"third":"liuguangpingyuan/liuguangchalu",
	]),
	([
		"max":54,
		"level":53,
		"name":"蓬莱云石历练",
		"human":"plxianjing/dangyunshijie",
		"monst":"plxianjing/dangyunshijie",
		"third":"plxianjing/dangyunshijie",
	]),
	([
		"max":58,
		"level":55,
		"name":"冰幻云台历练",
		"human":"plxianjing/binghuanyuntai",
		"monst":"plxianjing/binghuanyuntai",
		"third":"plxianjing/binghuanyuntai",
	]),
	([
		"max":61,
		"level":60,
		"name":"云野平原历练",
		"human":"penglaihuanjing/yunyepingyuan",
		"monst":"penglaihuanjing/yunyepingyuan",
		"third":"penglaihuanjing/yunyepingyuan",
	]),
	([
		"max":63,
		"level":62,
		"name":"秋霜石路历练",
		"human":"penglaihuanjing/qiushuangshilu",
		"monst":"penglaihuanjing/qiushuangshilu",
		"third":"penglaihuanjing/qiushuangshilu",
	]),
	([
		"max":65,
		"level":64,
		"name":"烈火池塘历练",
		"human":"penglaihuanjing/liehuochitang",
		"monst":"penglaihuanjing/liehuochitang",
		"third":"penglaihuanjing/liehuochitang",
	]),
	([
		"max":67,
		"level":66,
		"name":"昆仑幻境历练",
		"human":"klshuanjingwaicheng/heiheyuan",
		"monst":"klshuanjingwaicheng/heiheyuan",
		"third":"klshuanjingwaicheng/heiheyuan",
	]),
	([
		"max":69,
		"level":68,
		"name":"幻境深处历练",
		"human":"klshuanjingwaicheng/heishandong",
		"monst":"klshuanjingwaicheng/heishandong",
		"third":"klshuanjingwaicheng/heishandong",
	]),
});

// 练级路线是启动后只读的配置快照。查询时返回副本，调用者不能改写
// 守护进程内缓存。
private mapping(string:mapping(int:mapping(string:mixed)))
	training_route_cache = ([]);

private void build_training_route_cache()
{
	mapping(string:mapping(int:mapping(string:mixed))) next_cache = ([
		"human":([]),
		"monst":([]),
		"third":([]),
	]);
	foreach(({"human","monst","third"}),string race){
		for(int level=1;level<70;level++){
			foreach(smart_training_routes,mapping(string:mixed) one){
				if(level>(int)one["max"])
					continue;
				mapping(string:mixed) route = copy_value(one);
				string path = (string)one[race];
				if(path=="")
					path = (string)one["third"];
				if(path=="")
					path = (string)one["human"];
				route["path"] = path;
				// 50级后多数路线随玩家等级提升，但不能把地图真实的
				// 最低怪物等级向下覆盖。典型边界是59级进入60级云野：
				// 推荐等级必须保持60，否则安全窗口会把整张图过滤掉。
				if(level>=50 && level>(int)route["level"])
					route["level"] = level;
				next_cache[race][level] = route;
				break;
			}
		}
	}
	training_route_cache = next_cache;
}

protected void create()
{
	build_training_route_cache();
}

mapping query_training_route_cache_status()
{
	return ([
		"mode":"immutable_snapshot",
		"human":sizeof(training_route_cache["human"] || ([])),
		"monst":sizeof(training_route_cache["monst"] || ([])),
		"third":sizeof(training_route_cache["third"] || ([])),
	]);
}

mapping query_autofight_performance_status()
{
	return ([
		"scan_count":autofight_scan_count,
		"scan_object_budget":AUTOFIGHT_SCAN_MAX_OBJECTS,
		"deferred_objects":autofight_scan_deferred_objects,
	]);
}

private array(object) query_bounded_scan_slice(object me,
	array(object) all,string cursor_key)
{
	array(object) result = ({});
	object env;
	string room_key;
	string room_identity;
	int total;
	int start;
	int count;
	if(!me || !all)
		return result;
	env = environment(me);
	room_key = cursor_key+"_room";
	room_identity = env ? file_name(env) : "";
	if((string)me[room_key]!=room_identity){
		me[cursor_key] = 0;
		me[room_key] = room_identity;
	}
	total = sizeof(all);
	start = (int)me[cursor_key];
	if(start<0 || start>=total)
		start = 0;
	count = total-start;
	if(count>AUTOFIGHT_SCAN_MAX_OBJECTS)
		count = AUTOFIGHT_SCAN_MAX_OBJECTS;
	if(count>0)
		result = all[start..start+count-1];
	if(start+count>=total)
		me[cursor_key] = 0;
	else{
		me[cursor_key] = start+count;
		autofight_scan_deferred_objects += total-start-count;
	}
	return result;
}

private void reset_scan_state(object me)
{
	if(!me)
		return;
	foreach(({"/tmp/autofight_scan_cursor",
		"/tmp/autofight_gather_scan_cursor",
		"/tmp/autofight_loot_scan_cursor"}),string key){
		me[key] = 0;
		me[key+"_room"] = "";
	}
	me["/tmp/autofight_scan_visible_total"] = 0;
}

void initialize_player(object me)
{
	int config_version;
	int daily_limit;
	if(!me)
		return;
	if(!(int)me["/plus/autofight_initialized"]){
		daily_limit = query_daily_seconds_for(me);
		me["/plus/autofight_initialized"] = 1;
		me["/plus/autofight_daily_limit"] = daily_limit;
		me["/plus/autofight_time_left"] = daily_limit;
		if(me->query_level()<=NEWBIED->query_newbie_supply_max_level()){
			me["/plus/autofight_hp_percent"] = 70;
			me["/plus/autofight_mana_percent"] = 50;
		}
		else{
			me["/plus/autofight_hp_percent"] = 50;
			me["/plus/autofight_mana_percent"] = 30;
		}
		me["/plus/autofight_loot"] = 1;
		me["/plus/autofight_roam"] = 0;
		me["/plus/autofight_smart_route"] = 1;
		me["/plus/autofight_auto_rest"] = 1;
		me["/plus/autofight_food"] = "auto";
		me["/plus/autofight_water"] = "auto";
		me["/plus/autofight_auto_sell_mode"] = "off";
		me["/plus/autofight_sell_weapon"] = 1;
		me["/plus/autofight_sell_armor"] = 1;
		me["/plus/autofight_sell_accessory"] = 1;
		me["/plus/autofight_sell_level_gap"] = 5;
		me["/plus/autofight_gather_mode"] = "off";
		me["/plus/autofight_material_keep"] = -1;
		me["/plus/autofight_destroy_non_equipment"] = 0;
		me["/plus/autofight_store_non_equipment"] = 0;
		me["/plus/autofight_cleanup_herb"] = 1;
		me["/plus/autofight_cleanup_mine"] = 1;
		me["/plus/autofight_cleanup_misc"] = 0;
		me["/plus/autofight_cleanup_keep"] = 100;
		me["/plus/autofight_cleanup_trigger"] = 70;
		me["/plus/autofight_cleanup_protect_names"] = "";
		me["/plus/autofight_cleanup_force_names"] = "";
		me["/plus/autofight_skill_mode"] = "smart";
		me["/plus/autofight_buff"] = 0;
	}
	else
		sync_daily_limit(me);
	config_version =
		(int)me["/plus/autofight_config_version"];
	if(config_version < 2){
		me["/plus/autofight_smart_route"] = 1;
		me["/plus/autofight_auto_rest"] = 1;
	}
	if(config_version < 3){
		me["/plus/autofight_auto_sell_mode"] = "off";
		me["/plus/autofight_sell_weapon"] = 1;
		me["/plus/autofight_sell_armor"] = 1;
		me["/plus/autofight_sell_accessory"] = 1;
		me["/plus/autofight_sell_level_gap"] = 5;
	}
	if(config_version < 4){
		me["/plus/autofight_gather_mode"] = "off";
		me["/plus/autofight_material_keep"] = -1;
	}
	if(config_version < 5)
		me["/plus/autofight_destroy_non_equipment"] = 0;
	if(config_version < 6){
		me["/plus/autofight_store_non_equipment"] = 0;
		me["/plus/autofight_cleanup_herb"] = 1;
		me["/plus/autofight_cleanup_mine"] = 1;
		me["/plus/autofight_cleanup_misc"] = 0;
		me["/plus/autofight_cleanup_keep"] = 100;
		me["/plus/autofight_cleanup_trigger"] = 70;
		me["/plus/autofight_cleanup_protect_names"] = "";
		me["/plus/autofight_cleanup_force_names"] = "";
	}
	if(config_version < 7)
		me["/plus/autofight_skill_mode"] = "smart";
	if(config_version < 8)
		me["/plus/autofight_buff"] = 0;
	if(config_version < AUTOFIGHT_CONFIG_VERSION)
		me["/plus/autofight_config_version"] =
			AUTOFIGHT_CONFIG_VERSION;
}

int query_daily_seconds()
{
	return AUTOFIGHT_DAILY_SECONDS;
}

int query_vip_level(object me)
{
	int vip_level;
	if(!me)
		return 0;
	// 会员标志和到期时间必须同时有效，防止过期存档继续获得挂机额度。
	vip_level = VIPD->query_active_vip_level(me);
	if(vip_level < 0)
		vip_level = 0;
	if(vip_level > AUTOFIGHT_MAX_VIP_LEVEL)
		vip_level = AUTOFIGHT_MAX_VIP_LEVEL;
	return vip_level;
}

string query_vip_label(int vip_level)
{
	string vip_name;
	if(vip_level <= 0)
		return "普通玩家";
	if(vip_level > AUTOFIGHT_MAX_VIP_LEVEL)
		vip_level = AUTOFIGHT_MAX_VIP_LEVEL;
	vip_name = VIPD->get_vip_name(vip_level);
	if(!vip_name || vip_name == "")
		return "VIP"+vip_level;
	return "VIP"+vip_level+"（"+vip_name+"）";
}

int query_daily_seconds_for(object me)
{
	return AUTOFIGHT_DAILY_SECONDS+
		query_vip_level(me)*AUTOFIGHT_VIP_BONUS_SECONDS;
}

int can_upgrade_daily_time(object me)
{
	return query_vip_level(me) < AUTOFIGHT_MAX_VIP_LEVEL;
}

string query_quota_exhausted_message(object me)
{
	int vip_level;
	int daily_hours;
	vip_level = query_vip_level(me);
	daily_hours = query_daily_seconds_for(me)/3600;
	if(vip_level < AUTOFIGHT_MAX_VIP_LEVEL)
		return sprintf("今天的%d小时自动挂机时间已经用完；升级至%s可将每日额度提高到%d小时",
			daily_hours,query_vip_label(vip_level+1),daily_hours+2);
	return sprintf("今天的%d小时自动挂机时间已经用完；你已是%s，当前为最高额度，请明日登录后再使用",
		daily_hours,query_vip_label(vip_level));
}

int is_quota_exhausted_reason(object me,string reason)
{
	if(!me || !reason || reason == "")
		return 0;
	return query_time_left(me) <= 0 &&
		reason == query_quota_exhausted_message(me);
}

void sync_daily_limit(object me)
{
	int daily_limit;
	int previous_limit;
	int time_left;
	if(!me)
		return;
	daily_limit = query_daily_seconds_for(me);
	previous_limit = (int)me["/plus/autofight_daily_limit"];
	if(previous_limit <= 0)
		previous_limit = AUTOFIGHT_DAILY_SECONDS;
	time_left = (int)me["/plus/autofight_time_left"];
	if(previous_limit != daily_limit)
		time_left += daily_limit-previous_limit;
	if(time_left < 0)
		time_left = 0;
	if(time_left > daily_limit)
		time_left = daily_limit;
	me["/plus/autofight_daily_limit"] = daily_limit;
	me["/plus/autofight_time_left"] = time_left;
}

void reset_daily_time(object me)
{
	int daily_limit;
	if(!me)
		return;
	daily_limit = query_daily_seconds_for(me);
	me["/plus/autofight_initialized"] = 1;
	me["/plus/autofight_daily_limit"] = daily_limit;
	me["/plus/autofight_time_left"] = daily_limit;
	me["/tmp/autofight_last_charge"] = 0;
}

int query_time_left(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_time_left"];
}

int query_hp_percent(object me)
{
	int percent;
	if(!me)
		return 50;
	initialize_player(me);
	percent = (int)me["/plus/autofight_hp_percent"];
	if(percent != 30 && percent != 50 && percent != 70)
		percent = 50;
	return percent;
}

int query_mana_percent(object me)
{
	int percent;
	if(!me)
		return 30;
	initialize_player(me);
	percent = (int)me["/plus/autofight_mana_percent"];
	if(percent != 0 && percent != 30 && percent != 50)
		percent = 30;
	return percent;
}

string query_auto_skill_mode(object me)
{
	string mode;
	if(!me)
		return "off";
	initialize_player(me);
	mode = (string)me["/plus/autofight_skill_mode"];
	if(mode != "smart" && mode != "manual" && mode != "off")
		mode = "smart";
	return mode;
}

string query_auto_skill_mode_cn(object me)
{
	string mode;
	mode = query_auto_skill_mode(me);
	if(mode == "smart")
		return "智能推荐";
	if(mode == "manual")
		return "手动指定";
	return "关闭";
}

// 技能守护进程采用惰性注册。重启后，老人物已学技能可能尚未被任何
// 商店或页面加载；自动挂机必须按受限文件名补载，不能依赖测试顺序。
object|zero query_auto_skill_object(string name)
{
	object|zero skill = 0;
	mixed err = 0;
	if(!name || name == "" || search(name,"/") != -1 ||
	   search(name,"..") != -1)
		return 0;
	skill = MUD_SKILLSD[name];
	if(!skill){
		err = catch {
			skill = (object)(ROOT+"/gamelib/single/skills/"+name);
		};
		if(err)
			skill = 0;
	}
	return skill;
}

private int query_auto_skill_usable_level(object me,string name)
{
	object|zero skill;
	mapping(int:int) limits;
	array(int) levels;
	int learned_level;
	int usable_level;
	if(!me || !name || name == "" || !me->skills ||
	   !me->skills[name])
		return 0;
	skill = query_auto_skill_object(name);
	if(!skill || skill->s_type != "zhudong")
		return 0;
	learned_level = (int)me->skills[name][0];
	if(learned_level <= 0)
		return 0;
	limits = skill->query_performs_level_limit_all ?
		skill->query_performs_level_limit_all() : 0;
	if(!limits || !sizeof(limits))
		return learned_level;
	if(sizeof(limits) == 1){
		if(me->query_level() < (int)limits[1])
			return 0;
		return learned_level;
	}
	levels = sort(indices(limits));
	usable_level = 0;
	for(int i = 0;i < sizeof(levels);i++){
		if(me->query_level() >= (int)limits[levels[i]])
			usable_level = levels[i];
	}
	if(usable_level > learned_level)
		usable_level = learned_level;
	return usable_level;
}

private int query_auto_attack_skill_priority(object skill)
{
	string skill_type;
	if(!skill || skill->s_type != "zhudong")
		return 0;
	skill_type = (string)skill->s_skill_type;
	if(skill_type == "phy" || skill_type == "huo_mofa_attack" ||
	   skill_type == "bing_mofa_attack" ||
	   skill_type == "feng_mofa_attack" ||
	   skill_type == "du_mofa_attack")
		return 3;
	if(skill_type == "dot")
		return 2;
	if(skill_type == "curse")
		return 1;
	return 0;
}

string query_recommended_auto_skill(object me)
{
	mapping learned;
	array(string) names;
	object|zero skill;
	string best_name;
	string name;
	int usable_level;
	int priority;
	int power;
	int magic_low;
	int magic_high;
	int cast;
	int score;
	int best_score;
	if(!me || !me->skills || !sizeof(me->skills))
		return "";
	learned = me->skills;
	names = sort(indices(learned));
	best_name = "";
	best_score = -1;
	for(int i = 0;i < sizeof(names);i++){
		name = names[i];
		skill = query_auto_skill_object(name);
		priority = query_auto_attack_skill_priority(skill);
		if(priority <= 0)
			continue;
		usable_level = query_auto_skill_usable_level(me,name);
		if(usable_level <= 0)
			continue;
		cast = skill->query_performs_cast(usable_level);
		if(cast > me->query_mofa_max())
			continue;
		power = skill->query_performs_attack(usable_level);
		if(skill->s_skill_type == "huo_mofa_attack" ||
		   skill->s_skill_type == "bing_mofa_attack" ||
		   skill->s_skill_type == "feng_mofa_attack" ||
		   skill->s_skill_type == "du_mofa_attack"){
			magic_low = skill->query_performs_mofa_attack_low(usable_level);
			magic_high = skill->query_performs_mofa_attack_high(usable_level);
			power = (magic_low+magic_high)/2;
		}
		score = priority*100000000+usable_level*100000+power;
		if(score > best_score){
			best_score = score;
			best_name = name;
		}
	}
	return best_name;
}

int set_auto_skill_mode(object me,string mode)
{
	if(!me || (mode != "smart" && mode != "off"))
		return 0;
	me["/plus/autofight_skill_mode"] = mode;
	me->skills_enable = "";
	me->skills_enable_colddown = 0;
	if(mode == "smart")
		ensure_auto_skill(me);
	return 1;
}

int set_selected_auto_skill(object me,string name)
{
	object|zero skill;
	if(!me || !name || name == "" || !me->skills ||
	   !me->skills[name])
		return 0;
	skill = query_auto_skill_object(name);
	if(!skill || skill->s_type != "zhudong")
		return 0;
	me["/plus/autofight_skill_mode"] = "manual";
	me->skills_enable = name;
	me->skills_enable_colddown = skill->query_s_delayTime()+1;
	return 1;
}

string ensure_auto_skill(object me)
{
	object|zero skill;
	string mode;
	string name;
	if(!me)
		return "";
	mode = query_auto_skill_mode(me);
	if(mode == "off")
		return "";
	name = (string)me->skills_enable;
	if(name != "" && me->skills && me->skills[name] &&
	   query_auto_skill_usable_level(me,name) > 0){
		skill = query_auto_skill_object(name);
		if(skill && skill->s_type == "zhudong")
			return name;
	}
	me->skills_enable = "";
	me->skills_enable_colddown = 0;
	if(mode != "smart")
		return "";
	name = query_recommended_auto_skill(me);
	if(name == "")
		return "";
	skill = query_auto_skill_object(name);
	if(!skill)
		return "";
	me->skills_enable = name;
	me->skills_enable_colddown = skill->query_s_delayTime()+1;
	return name;
}

string query_auto_skill_unready_reason(object me,string name)
{
	object|zero skill;
	int usable_level;
	int cast;
	if(!me || !name || name == "" || !me->skills ||
	   !me->skills[name])
		return "not_learned";
	skill = query_auto_skill_object(name);
	if(!skill)
		return "missing_skill";
	usable_level = query_auto_skill_usable_level(me,name);
	if(usable_level <= 0)
		return "level_locked";
	if(me->timeCold != 0)
		return "global_cooldown";
	if(me->f_skills && (int)me->f_skills[name] > 1)
		return "skill_cooldown";
	cast = skill->query_performs_cast(usable_level);
	if(cast > me->get_cur_mofa())
		return "insufficient_mana";
	return "";
}

private int query_context_skill_ready(object me,string name)
{
	return query_auto_skill_unready_reason(me,name) == "";
}

// 镇越智能挂机并非只挑最高伤害：失去仇恨时先震吼，护盾耗尽后
// 再保护同房间队伍，两个条件都不满足才回到常规高仇恨攻击。
string query_ready_zhenyue_context_skill(object me)
{
	array(string) names;
	if(!me || me->query_profeId() != "zhenyue" ||
	   !me->query_in_combat())
		return "";
	// 只由职业助手守护进程决定上下文优先级；守护进程同时校验
	// 有效档位、开关和PVE目标，PVP永远不会自动接管。
	names = PROFESSIONVIPD->query_zhenyue_context_candidates(me);
	foreach(names,string name)
		if(query_context_skill_ready(me,name))
			return name;
	return "";
}

// 天象智能挂机遵循真实星痕状态：低血量先补星壁，二至三层时按
// 策略引爆，否则轮换已学且已冷却的生成技能；职业助手不修改数值。
string query_ready_tianxiang_context_skill(object me)
{
	array(string) names;
	if(!me || me->query_profeId() != "tianxiang" ||
	   !me->query_in_combat())
		return "";
	names = PROFESSIONVIPD->query_tianxiang_context_candidates(me);
	foreach(names,string name)
		if(query_context_skill_ready(me,name))
			return name;
	return "";
}

// 灵医智能挂机仅在职业助手已授权的PVE战斗中插入治疗；目标、上限、
// 净化和药契仍由战斗引擎统一结算，助手不能改变任何技能数值。
string query_ready_lingyi_context_skill(object me)
{
	array(string) names;
	if(!me || me->query_profeId()!="lingyi" || !me->query_in_combat())
		return "";
	names = PROFESSIONVIPD->query_lingyi_context_candidates(me);
	foreach(names,string name)
		if(query_context_skill_ready(me,name))
			return name;
	return "";
}

string query_ready_auto_skill(object me)
{
	object|zero skill;
	mapping items;
	string name;
	string context_name;
	int usable_level;
	int cast;
	if(!me || !me->query_in_combat())
		return "";
	if(query_auto_skill_mode(me) == "smart"){
		if(me->query_profeId()=="tianxiang")
			context_name = query_ready_tianxiang_context_skill(me);
		else if(me->query_profeId()=="lingyi")
			context_name = query_ready_lingyi_context_skill(me);
		else
			context_name = query_ready_zhenyue_context_skill(me);
		if(context_name != "")
			return context_name;
	}
	name = ensure_auto_skill(me);
	if(name == "")
		return "";
	skill = query_auto_skill_object(name);
	usable_level = query_auto_skill_usable_level(me,name);
	if(!skill || usable_level <= 0 || me->timeCold != 0)
		return "";
	if(me->f_skills && (int)me->f_skills[name] > 1)
		return "";
	cast = skill->query_performs_cast(usable_level);
	if(cast > me->get_cur_mofa())
		return "";
	if(skill->s_skill_type == "phy"){
		items = me->query_equip();
		if(!items || (!items["single_main_weapon"] &&
		   !items["double_main_weapon"]))
			return "";
	}
	return name;
}

int query_loot_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_loot"] == 1;
}

int query_roam_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_roam"] == 1;
}

int query_smart_route_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_smart_route"] == 1;
}

int query_auto_rest_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_auto_rest"] == 1;
}

int query_auto_buff_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_buff"] == 1;
}

// 选择某 kind 槽位下一次会被自动服用的丹药。返回 0 表示该槽位本轮不会触发：
// 可能因为槽位已有 buff、背包无候选丹药、等级超限、或 te_* 已达每日上限。
// 调用方负责缓存名称：吃下后 amount 归零，物品对象会被销毁。
private object|zero select_best_buff_danyao(object me, string kind)
{
	object|zero best;
	int best_value;
	int best_duration;
	mapping teyao_map;
	if(me->query_buff(kind, 0) != "none")
		return 0;
	if(has_prefix(kind,"te_")){
		teyao_map = me["/plus/daily/teyao_map"];
		if(mappingp(teyao_map) &&
		   (int)teyao_map[kind] >= (int)me->query_max_yao())
			return 0;
	}
	foreach(all_inventory(me), object item){
		int max_level;
		int value;
		int duration;
		if(!item || item->amount <= 0)
			continue;
		if(!functionp(item->query_danyao_kind))
			continue;
		if(item->query_danyao_kind() != kind)
			continue;
		max_level = (int)item->query_danyao_max_level();
		if(max_level > 0 && me->query_level() > max_level)
			continue;
		value = (int)item->query_effect_value();
		duration = (int)item->query_danyao_timedelay();
		if(!best || value > best_value ||
		   (value == best_value && duration > best_duration)){
			best = item;
			best_value = value;
			best_duration = duration;
		}
	}
	return best;
}

// 预览开关开启后、下一次脱战 tick 会自动服用的丹药。用于 autofight open 设置页展示，
// 让玩家在勾选开关时就能看到接下来哪些丹药会被消耗、对应什么属性。
array(mapping(string:mixed)) query_auto_buff_preview(object me)
{
	array(mapping(string:mixed)) preview = ({});
	mapping(string:string) kind_labels = ([
		"attri_base":"力量/敏捷/悟性",
		"attri_attack":"伤害",
		"attri_defend":"防御/生命",
		"attri_vice":"副属性",
		"attri_luck":"幸运",
		"attri_honer":"荣誉",
		"attri_exp":"经验",
		"te_base":"力量/敏捷/悟性（特）",
		"te_attack":"伤害（特）",
		"te_defend":"防御/生命（特）",
		"te_vice":"副属性（特）",
		"te_luck":"幸运（特）",
		"te_honer":"荣誉（特）",
		"te_exp":"经验（特）",
	]);
	if(!me)
		return preview;
	initialize_player(me);
	if((int)me["/plus/autofight_buff"] != 1)
		return preview;
	foreach(auto_buff_kinds, string kind){
		object|zero best = select_best_buff_danyao(me, kind);
		if(!best)
			continue;
		preview += ({
			([
				"kind":kind,
				"kind_cn":kind_labels[kind] || kind,
				"name_cn":best->query_name_cn(),
				"value":(int)best->query_effect_value(),
				"duration":(int)best->query_danyao_timedelay(),
			]),
		});
	}
	return preview;
}

mapping(string:mixed) perform_auto_buff(object me)
{
	mapping(string:mixed) result;
	result = (["eaten":({})]);
	if(!me)
		return result;
	initialize_player(me);
	if((int)me["/plus/autofight_buff"] != 1)
		return result;
	// 覆盖 attri_* 与 te_* 共十四类 buff 丹药；spec 因 sucide 会自杀，永远不自动吃。
	// 已有同类 buff 不覆盖；等级超限的追赶药跳过；te_* 每日次数到达上限后跳过。
	foreach(auto_buff_kinds, string kind){
		object|zero best;
		int count_index;
		string best_name;
		string best_name_cn;
		best = select_best_buff_danyao(me, kind);
		if(!best)
			continue;
		// 吃药前缓存名称：amount 减到 0 时物品会被销毁，之后再访问会报错。
		best_name = best->query_name();
		best_name_cn = best->query_name_cn();
		// present(name, me, n) 是 0-indexed：第一件同名物品传 0。
		count_index = query_object_count(best, me);
		// flag=1 强制覆盖现有 buff 的确认提示，跳过交互。
		me->command("viceskill_eat_danyao "+best_name+" "+
			count_index+" 1 0");
		if(me->query_buff(kind, 0) != "none")
			result["eaten"] += ({ best_name_cn });
	}
	return result;
}

int query_auto_destroy_non_equipment_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return query_vip_level(me) >= 1 &&
		(int)me["/plus/autofight_destroy_non_equipment"] == 1;
}

int query_auto_store_non_equipment_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return query_vip_level(me) >= 1 &&
		(int)me["/plus/autofight_store_non_equipment"] == 1;
}

int query_auto_cleanup_trigger_percent(object me)
{
	int vip_level;
	int trigger;
	if(!me)
		return 100;
	initialize_player(me);
	vip_level = query_vip_level(me);
	if(vip_level >= 4){
		trigger = (int)me["/plus/autofight_cleanup_trigger"];
		if(trigger == 70 || trigger == 80 || trigger == 90)
			return trigger;
		return 70;
	}
	if(vip_level == 3)
		return 80;
	if(vip_level == 2)
		return 85;
	if(vip_level == 1)
		return 90;
	return 100;
}

int query_auto_cleanup_keep(object me)
{
	int keep;
	if(!me || query_vip_level(me) < 3)
		return 0;
	initialize_player(me);
	keep = (int)me["/plus/autofight_cleanup_keep"];
	if(keep != 0 && keep != 50 && keep != 100 && keep != 300)
		return 100;
	return keep;
}

int query_auto_cleanup_category_enabled(object me,string category)
{
	int vip_level;
	if(!me)
		return 0;
	initialize_player(me);
	vip_level = query_vip_level(me);
	if(vip_level < 1)
		return 0;
	if(vip_level == 1)
		return category == "herb" || category == "mine";
	if(category == "herb")
		return (int)me["/plus/autofight_cleanup_herb"] == 1;
	if(category == "mine")
		return (int)me["/plus/autofight_cleanup_mine"] == 1;
	if(category == "misc")
		return (int)me["/plus/autofight_cleanup_misc"] == 1;
	return 0;
}

private array(string) query_auto_cleanup_names(object me,string key)
{
	string raw;
	array(string) names;
	if(!me)
		return ({});
	raw = (string)me[key];
	if(!raw || raw == "")
		return ({});
	names = raw/","-({""});
	return names;
}

array(string) query_auto_cleanup_protect_names(object me)
{
	return query_auto_cleanup_names(me,
		"/plus/autofight_cleanup_protect_names");
}

array(string) query_auto_cleanup_force_names(object me)
{
	return query_auto_cleanup_names(me,
		"/plus/autofight_cleanup_force_names");
}

string query_auto_cleanup_name_mode(object me,string item_name)
{
	if(!me || !item_name)
		return "normal";
	if(search(query_auto_cleanup_protect_names(me),item_name) != -1)
		return "protect";
	if(search(query_auto_cleanup_force_names(me),item_name) != -1)
		return "force";
	return "normal";
}

int set_auto_cleanup_name_mode(object me,string item_name,string mode)
{
	array(string) protect_names;
	array(string) force_names;
	if(!me || !item_name || item_name == "" ||
	   search(item_name,",") != -1 || search(item_name," ") != -1)
		return 0;
	if(mode != "normal" && mode != "protect" && mode != "force")
		return 0;
	protect_names = query_auto_cleanup_protect_names(me)-({item_name});
	force_names = query_auto_cleanup_force_names(me)-({item_name});
	if(mode == "protect"){
		if(sizeof(protect_names) >= AUTOFIGHT_CLEANUP_NAME_LIMIT)
			return 0;
		protect_names += ({item_name});
	}
	else if(mode == "force"){
		if(sizeof(force_names) >= AUTOFIGHT_CLEANUP_NAME_LIMIT)
			return 0;
		force_names += ({item_name});
	}
	me["/plus/autofight_cleanup_protect_names"] = protect_names*",";
	me["/plus/autofight_cleanup_force_names"] = force_names*",";
	return 1;
}

string query_gather_mode(object me)
{
	string mode;
	array(string) valid_modes = ({"off","mine","herb","both"});
	if(!me)
		return "off";
	initialize_player(me);
	mode = (string)me["/plus/autofight_gather_mode"];
	if(search(valid_modes,mode) == -1)
		return "off";
	return mode;
}

string query_gather_mode_cn(string mode)
{
	if(mode == "mine")
		return "自动采矿";
	if(mode == "herb")
		return "自动采药";
	if(mode == "both")
		return "采药和采矿";
	return "关闭";
}

int query_material_keep(object me)
{
	int keep;
	if(!me)
		return -1;
	initialize_player(me);
	keep = (int)me["/plus/autofight_material_keep"];
	if(keep != -1 && keep != 0 && keep != 100 &&
	   keep != 300 && keep != 500)
		return -1;
	return keep;
}

object|zero query_gather_source(object me)
{
	object env;
	string mode;
	array(object) all;
	if(!me || me->in_combat)
		return 0;
	mode = query_gather_mode(me);
	if(mode == "off")
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = query_bounded_scan_slice(me,all_inventory(env,me),
		"/tmp/autofight_gather_scan_cursor");
	foreach(all,object source){
		string source_type;
		string skill_name;
		mixed skill;
		int need_level;
		if(!source || !functionp(source->query_source_type))
			continue;
		source_type = source->query_source_type();
		if(source_type == "kuang"){
			if(mode != "mine" && mode != "both")
				continue;
			skill_name = "caikuang";
			need_level = KUANGD->query_need_level(source->query_name());
		}
		else if(source_type == "caoyao"){
			if(mode != "herb" && mode != "both")
				continue;
			skill_name = "caiyao";
			need_level = CAOYAOD->query_need_level(source->query_name());
		}
		else
			continue;
		skill = me->vice_skills[skill_name];
		if(!arrayp(skill) || !sizeof(skill))
			continue;
		if(need_level >= 0 && (int)skill[0] >= need_level)
			return source;
	}
	return 0;
}

string query_auto_sell_mode(object me)
{
	string mode;
	array(string) valid_modes = ({
		"off","normal","excellent","refined","huanhua",
	});
	if(!me)
		return "off";
	initialize_player(me);
	mode = (string)me["/plus/autofight_auto_sell_mode"];
	if(search(valid_modes,mode) == -1)
		return "off";
	return mode;
}

string query_auto_sell_mode_cn(string mode)
{
	if(mode == "normal")
		return "仅普通白装";
	if(mode == "excellent")
		return "普通及优良装备";
	if(mode == "refined")
		return "普通、优良及精制装备";
	if(mode == "huanhua")
		return "普通至幻化装备（高风险）";
	return "关闭";
}

int query_auto_sell_mode_requirement(string mode)
{
	if(mode == "normal")
		return 1;
	if(mode == "excellent")
		return 2;
	if(mode == "refined")
		return 3;
	if(mode == "huanhua")
		return 4;
	return 0;
}

int query_auto_sell_quality_limit(string mode)
{
	if(mode == "excellent")
		return 2;
	if(mode == "refined")
		return 4;
	if(mode == "huanhua")
		return 7;
	return 0;
}

int query_auto_sell_enabled(object me)
{
	string mode;
	int requirement;
	int vip_level;
	if(!me)
		return 0;
	mode = query_auto_sell_mode(me);
	requirement = query_auto_sell_mode_requirement(mode);
	vip_level = query_vip_level(me);
	return requirement > 0 && vip_level >= requirement &&
		vip_level >= query_auto_sell_gap_requirement(
			query_auto_sell_level_gap(me));
}

int query_auto_sell_trigger_percent(object me)
{
	int vip_level = query_vip_level(me);
	if(vip_level >= 4)
		return 70;
	if(vip_level == 3)
		return 80;
	if(vip_level == 2)
		return 90;
	return 100;
}

int query_auto_sell_batch_size(object me)
{
	if(!me)
		return 0;
	// 保留这个查询接口给旧页面使用，但自动出售不再人为切成1/2/4/8件。
	// 背包容量天然限定了单次工作量，符合规则的低级装备应一次清完，
	// 避免清了8件就返回战斗、下一次拾取时又被满包卡住。
	return sizeof(query_auto_sell_candidates(me));
}

int query_auto_sell_level_gap(object me)
{
	int gap;
	if(!me)
		return 5;
	initialize_player(me);
	gap = (int)me["/plus/autofight_sell_level_gap"];
	if(gap != 0 && gap != 3 && gap != 5)
		return 5;
	return gap;
}

int query_auto_sell_gap_requirement(int gap)
{
	if(gap == 0)
		return 3;
	if(gap == 3)
		return 2;
	return 1;
}

int query_backpack_percent(object me)
{
	int maximum;
	int count;
	if(!me)
		return 0;
	maximum = me->query_beibao_size();
	if(maximum <= 0)
		return 0;
	count = sizeof(all_inventory(me));
	return count*100/maximum;
}

private int is_auto_sell_equipment_type(object item)
{
	string item_type;
	if(!item)
		return 0;
	item_type = item->query_item_type();
	return item_type == "weapon" ||
		item_type == "single_weapon" ||
		item_type == "double_weapon" ||
		item_type == "armor" ||
		item_type == "jewelry" ||
		item_type == "decorate";
}

private int is_auto_sell_category_enabled(object me,object item)
{
	string item_type;
	if(!me || !item)
		return 0;
	item_type = item->query_item_type();
	if(item_type == "weapon" ||
	   item_type == "single_weapon" ||
	   item_type == "double_weapon")
		return (int)me["/plus/autofight_sell_weapon"] == 1;
	if(item_type == "armor")
		return (int)me["/plus/autofight_sell_armor"] == 1;
	if(item_type == "jewelry" || item_type == "decorate")
		return (int)me["/plus/autofight_sell_accessory"] == 1;
	return 0;
}

private int has_auto_sell_protected_gem(object item)
{
	array(string) colors = ({"blue","red","yellow"});
	if(!item || !functionp(item->query_baoshi))
		return 0;
	foreach(colors,string color){
		array(object) gems = item->query_baoshi(color);
		if(gems && sizeof(gems))
			return 1;
	}
	return 0;
}

private int has_auto_sell_protected_filename(object item)
{
	string path;
	if(!item)
		return 1;
	path = (file_name(item)/"#")[0];
	if(search(path,"/duanzao/") != -1 ||
	   search(path,"/suit_") != -1 ||
	   search(path,"Xa") != -1 ||
	   search(path,"Xl") != -1 ||
	   search(path,"Xh") != -1 ||
	   search(path,"Xf") != -1)
		return 1;
	return 0;
}

string query_auto_sell_reject_reason(object me,object item)
{
	string mode;
	string item_from;
	int level_gap;
	int item_level;
	if(!me || !item || environment(item) != me)
		return "not_in_backpack";
	if(!item->is("item") || !item->is("equip") ||
	   !is_auto_sell_equipment_type(item))
		return "not_equipment";
	if(!query_auto_sell_enabled(me))
		return "disabled";
	if(item->equiped)
		return "equipped";
	if(item->query_item_task() == 1)
		return "task_item";
	if(item->query_item_canTrade() != 1)
		return "not_tradeable";
	if(item->query_item_canDrop() != 1 ||
	   item->query_item_canStorage() != 1)
		return "restricted";
	if(item->query_item_only() == 1)
		return "unique";
	if(item->item_playerDesc && item->item_playerDesc != "")
		return "player_marked";
	item_from = item->query_item_from();
	if(item_from && item_from != "")
		return "special_source";
	if(has_auto_sell_protected_filename(item))
		return "forged_or_fused";
	if(functionp(item->query_convert_count) &&
	   item->query_convert_count() > 0)
		return "converted";
	if(has_auto_sell_protected_gem(item))
		return "socketed";
	// 空觉及以上始终是硬保护线，即使未来增加更高VIP档也不能越过。
	if(item->query_item_rareLevel() >= 8)
		return "rare";
	mode = query_auto_sell_mode(me);
	if(item->query_item_rareLevel() >
	   query_auto_sell_quality_limit(mode))
		return "quality";
	if(!is_auto_sell_category_enabled(me,item))
		return "category";
	item_level = item->query_item_canLevel();
	if(item_level < 0)
		return "no_level_requirement";
	level_gap = query_auto_sell_level_gap(me);
	// gap=0表示完全关闭等级差过滤，高于人物等级的装备也继续按品质、
	// 类别和永久保护规则处理；不能把0误解为“至少低0级”。
	if(level_gap>0 && item_level > me->query_level()-level_gap)
		return "recent_level";
	return "";
}

array(object) query_auto_sell_candidates(object me)
{
	array(object) candidates = ({});
	if(!me || !query_auto_sell_enabled(me))
		return candidates;
	foreach(all_inventory(me),object item){
		if(query_auto_sell_reject_reason(me,item) == "")
			candidates += ({item});
	}
	return candidates;
}

int should_auto_sell(object me)
{
	if(!me || !query_auto_sell_enabled(me))
		return 0;
	if(query_backpack_percent(me) <
	   query_auto_sell_trigger_percent(me))
		return 0;
	return sizeof(query_auto_sell_candidates(me)) > 0;
}

int query_auto_sell_value(object item)
{
	int money_num;
	if(!item || !is_auto_sell_equipment_type(item))
		return 0;
	money_num = (int)item->query_item_canLevel()*50/4;
	if(money_num <= 0)
		money_num = 1;
	return money_num;
}

mapping(string:mixed) perform_auto_sell(object me)
{
	mapping(string:mixed) result = ([
		"count":0,
		"money":0,
		"names":({}),
	]);
	array(object) candidates;
	if(!me || !query_auto_sell_enabled(me) || me->in_combat)
		return result;
	candidates = query_auto_sell_candidates(me);
	// 候选列表是单次只读快照；逐件出售前仍重新校验永久保护规则，
	// 即使处理中物品状态发生变化，也不会误卖受保护装备。
	for(int i = 0;i < sizeof(candidates);i++){
		object item = candidates[i];
		string item_name;
		string item_path;
		string now;
		int money_num;
		if(query_auto_sell_reject_reason(me,item) != "")
			continue;
		item_name = item->query_name_cn();
		item_path = (file_name(item)/"#")[0];
		money_num = query_auto_sell_value(item);
		me->add_money(money_num);
		result["count"] = (int)result["count"]+1;
		result["money"] = (int)result["money"]+money_num;
		result["names"] += ({item_name});
		now = ctime(time());
		ASYNC_IOD->append_log(ROOT+"/log/autofight_sell.log",
			now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
			me->query_name()+") "+query_vip_label(query_vip_level(me))+
			" 自动出售 "+item_name+" "+item_path+" 得到"+
			money_num+"\n");
		item->remove();
	}
	return result;
}

private int is_auto_sell_material(object me,object item)
{
	string material_type;
	int keep;
	if(!me || !item || environment(item) != me)
		return 0;
	keep = query_material_keep(me);
	if(keep < 0 || !item->is("combine_item"))
		return 0;
	material_type = item->query_for_material();
	if(material_type != "duanzao" && material_type != "liandan")
		return 0;
	if(item->query_item_canTrade() != 1 || item->value <= 0)
		return 0;
	return item->amount > keep;
}

int consolidate_gathered_materials(object me)
{
	mapping(string:object) first_items = ([]);
	int removed = 0;
	if(!me)
		return 0;
	foreach(all_inventory(me),object item){
		string material_type;
		string key;
		object first;
		if(!item || !item->is("combine_item"))
			continue;
		material_type = item->query_for_material();
		if(material_type != "duanzao" && material_type != "liandan")
			continue;
		key = item->query_name()+"#"+item->query_toVip();
		first = first_items[key];
		item->max_count = 9999;
		if(!first){
			first_items[key] = item;
			continue;
		}
		int available = 9999-first->amount;
		if(available <= 0){
			first_items[key] = item;
			continue;
		}
		if(item->amount <= available){
			first->amount += item->amount;
			item->remove();
			removed++;
		}
		else{
			first->amount = 9999;
			item->amount -= available;
			first_items[key] = item;
		}
	}
	return removed;
}

object|zero query_auto_sell_material(object me)
{
	if(!me || query_material_keep(me) < 0)
		return 0;
	foreach(all_inventory(me),object item){
		if(is_auto_sell_material(me,item))
			return item;
	}
	return 0;
}

int should_auto_sell_material(object me)
{
	if(!me || me->in_combat)
		return 0;
	return query_auto_sell_material(me) ? 1 : 0;
}

mapping(string:mixed) perform_auto_sell_material(object me)
{
	mapping(string:mixed) result = ([
		"count":0,
		"money":0,
		"name":"",
	]);
	object|zero item;
	int keep;
	int sell_amount;
	int money_num;
	string item_name;
	string item_path;
	string now;
	if(!me || me->in_combat)
		return result;
	item = query_auto_sell_material(me);
	if(!item)
		return result;
	keep = query_material_keep(me);
	sell_amount = item->amount-keep;
	if(sell_amount <= 0)
		return result;
	item_name = item->query_name_cn();
	item_path = (file_name(item)/"#")[0];
	money_num = item->value*sell_amount;
	if(money_num <= 0)
		money_num = sell_amount;
	me->add_money(money_num);
	result["count"] = sell_amount;
	result["money"] = money_num;
	result["name"] = item_name;
	item->amount = keep;
	if(item->amount <= 0)
		item->remove();
	now = ctime(time());
	ASYNC_IOD->append_log(ROOT+"/log/autofight_material_sell.log",
		now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
		me->query_name()+") 自动出售采集原料 "+item_name+" "+
		item_path+" 数量"+sell_amount+" 得到"+money_num+"\n");
	return result;
}

int query_non_equipment_destroy_item_amount(object item)
{
	if(!item)
		return 0;
	if(item->is("combine_item") && item->amount > 0)
		return item->amount;
	return 1;
}

string query_non_equipment_destroy_reject_reason(object me,object item)
{
	string item_type;
	string item_from;
	array(string) protected_types = ({
		"book","box","danyao","food","water","yushi",
	});
	if(!me || !item || environment(item) != me)
		return "not_in_backpack";
	if(!item->is("item"))
		return "not_item";
	item_type = item->query_item_type();
	if(item->is("equip") || is_auto_sell_equipment_type(item))
		return "equipment";
	if(search(protected_types,item_type) != -1)
		return "protected_type";
	if(item->query_item_task() == 1)
		return "task_item";
	if(item->query_item_canDrop() != 1)
		return "not_droppable";
	if(item->query_item_canTrade() != 1 ||
	   item->query_item_canStorage() != 1)
		return "restricted";
	if(item->query_toVip())
		return "vip_item";
	if(item->query_item_only() == 1)
		return "unique";
	if(item->item_playerDesc && item->item_playerDesc != "")
		return "player_marked";
	item_from = item->query_item_from();
	if(item_from && item_from != "")
		return "special_source";
	if(sizeof(all_inventory(item)) > 0)
		return "container";
	return "";
}

string query_auto_cleanup_category(object item)
{
	string material_type;
	if(!item)
		return "misc";
	if(item->is("combine_item")){
		material_type = item->query_for_material();
		if(material_type == "liandan")
			return "herb";
		if(material_type == "duanzao")
			return "mine";
	}
	return "misc";
}

int query_auto_cleanup_process_amount(object me,object item)
{
	int amount;
	int keep;
	string material_type;
	if(!me || !item)
		return 0;
	amount = query_non_equipment_destroy_item_amount(item);
	if(query_vip_level(me) < 3 || !item->is("combine_item"))
		return amount;
	material_type = item->query_for_material();
	if(material_type == "")
		return amount;
	keep = query_auto_cleanup_keep(me);
	if(amount <= keep)
		return 0;
	return amount-keep;
}

string query_auto_cleanup_reject_reason(object me,object item)
{
	string reason;
	string item_name;
	string category;
	reason = query_non_equipment_destroy_reject_reason(me,item);
	if(reason != "")
		return reason;
	if(query_vip_level(me) < 1)
		return "vip_required";
	item_name = item->query_name();
	if(query_auto_cleanup_name_mode(me,item_name) == "protect")
		return "protected_list";
	if(query_auto_cleanup_process_amount(me,item) <= 0)
		return "keep_amount";
	if(query_auto_cleanup_name_mode(me,item_name) == "force")
		return "";
	category = query_auto_cleanup_category(item);
	if(!query_auto_cleanup_category_enabled(me,category))
		return "category_disabled";
	return "";
}

array(object) query_auto_cleanup_candidates(object me)
{
	array(object) candidates = ({});
	if(!me || query_vip_level(me) < 1)
		return candidates;
	foreach(all_inventory(me),object item){
		if(query_auto_cleanup_reject_reason(me,item) == "")
			candidates += ({item});
	}
	return candidates;
}

array(object) query_non_equipment_destroy_candidates(object me)
{
	array(object) candidates = ({});
	if(!me)
		return candidates;
	foreach(all_inventory(me),object item){
		if(query_non_equipment_destroy_reject_reason(me,item) == "")
			candidates += ({item});
	}
	return candidates;
}

mapping(string:mixed) query_non_equipment_destroy_preview(object me)
{
	mapping(string:int) grouped = ([]);
	mapping(string:mixed) result = ([
		"object_count":0,
		"item_count":0,
		"names":({}),
	]);
	array(object) candidates;
	if(!me)
		return result;
	candidates = query_non_equipment_destroy_candidates(me);
	foreach(candidates,object item){
		string item_name = item->query_name_cn();
		int amount = query_non_equipment_destroy_item_amount(item);
		result["object_count"] = (int)result["object_count"]+1;
		result["item_count"] = (int)result["item_count"]+amount;
		grouped[item_name] = (int)grouped[item_name]+amount;
	}
	foreach(grouped;string item_name;int amount)
		result["names"] += ({item_name+"×"+amount});
	return result;
}

int should_auto_destroy_non_equipment(object me)
{
	if(!me || me->in_combat ||
	   !query_auto_destroy_non_equipment_enabled(me))
		return 0;
	if(query_backpack_percent(me) < query_auto_cleanup_trigger_percent(me))
		return 0;
	return sizeof(query_auto_cleanup_candidates(me)) > 0;
}

mapping(string:mixed) perform_non_equipment_destroy(object me,string source)
{
	mapping(string:mixed) result = ([
		"object_count":0,
		"item_count":0,
		"names":({}),
		"reason":"",
	]);
	array(object) candidates;
	int auto_mode;
	if(!me)
		return result;
	if(me->in_combat){
		result["reason"] = "in_combat";
		return result;
	}
	auto_mode = source == "autofight" ? 1 : 0;
	if(!auto_mode)
		source = "manual";
	if(auto_mode){
		if(!query_auto_destroy_non_equipment_enabled(me)){
			result["reason"] = "vip_required";
			return result;
		}
		candidates = query_auto_cleanup_candidates(me);
	}
	else
		candidates = query_non_equipment_destroy_candidates(me);
	foreach(candidates,object item){
		string item_name;
		string item_path;
		string now;
		int amount;
		if(auto_mode){
			if(query_auto_cleanup_reject_reason(me,item) != "")
				continue;
		}
		else if(query_non_equipment_destroy_reject_reason(me,item) != "")
			continue;
		item_name = item->query_name_cn();
		item_path = (file_name(item)/"#")[0];
		if(auto_mode)
			amount = query_auto_cleanup_process_amount(me,item);
		else
			amount = query_non_equipment_destroy_item_amount(item);
		if(amount <= 0)
			continue;
		result["object_count"] = (int)result["object_count"]+1;
		result["item_count"] = (int)result["item_count"]+amount;
		result["names"] += ({item_name+"×"+amount});
		now = ctime(time());
		ASYNC_IOD->append_log(ROOT+"/log/non_equipment_destroy.log",
			now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
			me->query_name()+") "+source+" 销毁 "+item_name+" "+
			item_path+" 数量"+amount+"\n");
		if(auto_mode && item->is("combine_item") &&
		   amount < item->amount)
			item->amount -= amount;
		else
			item->remove();
	}
	return result;
}

int query_auto_store_batch_size(object me)
{
	int vip_level;
	vip_level = query_vip_level(me);
	if(vip_level >= 4)
		return 8;
	if(vip_level == 3)
		return 4;
	if(vip_level == 2)
		return 2;
	return 1;
}

int query_auto_storage_free_slots(object me)
{
	int maximum;
	int used;
	if(!me)
		return 0;
	maximum = me->query_cangku_size();
	used = me->packaged_items ? sizeof(me->packaged_items) : 0;
	if(maximum <= used)
		return 0;
	return maximum-used;
}

int should_auto_store_non_equipment(object me)
{
	if(!me || me->in_combat ||
	   !query_auto_store_non_equipment_enabled(me))
		return 0;
	if(query_auto_storage_free_slots(me) <= 0)
		return 0;
	if(query_backpack_percent(me) < query_auto_cleanup_trigger_percent(me))
		return 0;
	return sizeof(query_auto_cleanup_candidates(me)) > 0;
}

mapping(string:mixed) perform_auto_store_non_equipment(object me)
{
	mapping(string:mixed) result = ([
		"object_count":0,
		"item_count":0,
		"names":({}),
		"reason":"",
	]);
	array(object) candidates;
	int batch_size;
	int maximum;
	if(!me || me->in_combat)
		return result;
	if(!query_auto_store_non_equipment_enabled(me)){
		result["reason"] = "vip_required";
		return result;
	}
	if(query_auto_storage_free_slots(me) <= 0){
		result["reason"] = "warehouse_full";
		return result;
	}
	candidates = query_auto_cleanup_candidates(me);
	batch_size = query_auto_store_batch_size(me);
	maximum = me->query_cangku_size();
	for(int i = 0;i < sizeof(candidates) &&
	   (int)result["object_count"] < batch_size;i++){
		object item;
		object storage_item;
		string item_name;
		string item_path;
		string now;
		int amount;
		int package_error;
		item = candidates[i];
		if(query_auto_cleanup_reject_reason(me,item) != "")
			continue;
		if(query_auto_storage_free_slots(me) <= 0){
			result["reason"] = "warehouse_full";
			break;
		}
		item_name = item->query_name_cn();
		item_path = (file_name(item)/"#")[0];
		amount = query_auto_cleanup_process_amount(me,item);
		if(amount <= 0)
			continue;
		storage_item = item;
		if(item->is("combine_item") && amount < item->amount){
			storage_item = clone(item_path);
			storage_item->amount = amount;
		}
		package_error = me->packaged(storage_item,maximum);
		if(package_error){
			if(storage_item != item)
				storage_item->remove();
			result["reason"] = "warehouse_full";
			break;
		}
		if(storage_item != item){
			item->amount -= amount;
			storage_item->remove();
		}
		else
			item->remove();
		result["object_count"] = (int)result["object_count"]+1;
		result["item_count"] = (int)result["item_count"]+amount;
		result["names"] += ({item_name+"×"+amount});
		now = ctime(time());
		ASYNC_IOD->append_log(ROOT+"/log/autofight_storage.log",
			now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
			me->query_name()+") 自动存仓 "+item_name+" "+item_path+
			" 数量"+amount+"\n");
	}
	return result;
}

void start_autofight(object me)
{
	if(!me)
		return;
	initialize_player(me);
	me["/tmp/autofight_last_charge"] = time();
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/tmp/autofight_previous_room"] = "";
	me["/tmp/autofight_failed_loot"] = 0;
	me["/tmp/autofight_failed_loot_room"] = 0;
	me["/tmp/autofight_failed_loot_retry"] = 0;
	reset_scan_state(me);
	ensure_auto_skill(me);
	me->set_autofight("enable");
}

void stop_autofight(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_last_charge"] = 0;
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/tmp/autofight_previous_room"] = "";
	me["/tmp/autofight_resting"] = 0;
	me["/tmp/autofight_failed_loot"] = 0;
	me["/tmp/autofight_failed_loot_room"] = 0;
	me["/tmp/autofight_failed_loot_retry"] = 0;
	reset_scan_state(me);
	me->set_autofight("disable");
}

int charge_time(object me)
{
	int now;
	int last;
	int elapsed;
	int left;
	if(!me)
		return 0;
	initialize_player(me);
	now = time();
	last = (int)me["/tmp/autofight_last_charge"];
	if(last <= 0 || last > now){
		me["/tmp/autofight_last_charge"] = now;
		return query_time_left(me);
	}
	elapsed = now-last;
	if(elapsed <= 0)
		return query_time_left(me);
	// 如果距上次扣费超过 60 秒，说明玩家离线/浏览器休眠/网络断开，
	// 这段时间没有实际挂机（没杀怪没涨经验），不应消耗每日时间。
	if(elapsed > 60){
		me["/tmp/autofight_last_charge"] = now;
		return query_time_left(me);
	}
	left = query_time_left(me)-elapsed;
	if(left < 0)
		left = 0;
	me["/plus/autofight_time_left"] = left;
	me["/tmp/autofight_last_charge"] = now;
	return left;
}

string query_start_block_reason(object me)
{
	object env;
	if(!me)
		return "玩家对象不存在";
	initialize_player(me);
	if(me->is("npc"))
		return "NPC不能开启自动挂机";
	env = environment(me);
	if(!env)
		return "你当前不在有效地图中";
	if(me->is("ghost") || me->get_cur_life() <= 0)
		return "死亡或灵魂状态不能开启自动挂机";
	if((int)me["/plus/random_rcd"] > 0)
		return "请先完成当前的安全验证";
	if(query_time_left(me) <= 0)
		return query_quota_exhausted_message(me);
	consolidate_gathered_materials(me);
	if(query_loot_enabled(me) && me->if_over_easy_load()){
		if(query_auto_store_non_equipment_enabled(me) &&
		   query_auto_storage_free_slots(me) > 0 &&
		   sizeof(query_auto_cleanup_candidates(me)))
			return "";
		if(query_auto_destroy_non_equipment_enabled(me) &&
		   sizeof(query_auto_cleanup_candidates(me)))
			return "";
		if(query_auto_sell_material(me))
			return "";
		if(query_auto_sell_enabled(me) &&
		   sizeof(query_auto_sell_candidates(me)))
			return "";
		if(query_auto_sell_mode(me) != "off")
			return "背包已满，智能清包没有找到符合当前规则的装备";
		return "背包已满，请整理背包后再开启";
	}
	return "";
}

string query_runtime_block_reason(object me)
{
	return query_start_block_reason(me);
}

int should_recover_life(object me)
{
	int life;
	int life_max;
	int percent;
	if(!me)
		return 0;
	life = me->get_cur_life();
	life_max = me->query_life_max();
	percent = query_hp_percent(me);
	if(life <= 0 || life_max <= 0)
		return 0;
	return life*100 < life_max*percent;
}

int should_recover_mana(object me)
{
	int mana;
	int mana_max;
	int percent;
	if(!me)
		return 0;
	mana = me->get_cur_mofa();
	mana_max = me->query_mofa_max();
	percent = query_mana_percent(me);
	if(percent <= 0 || mana_max <= 0)
		return 0;
	return mana*100 < mana_max*percent;
}

mapping(string:mixed) query_training_route(object me)
{
	mapping(string:mixed) route;
	string race;
	string path;
	int level;
	if(!me)
		return ([]);
	level = me->query_level();
	race = me->query_raceId();
	if(level>=ENDGAME_MAP_MIN_LEVEL){
		return ([
			"max":MAX_LEVEL,
			"level":level>MAX_LEVEL ? MAX_LEVEL : level,
			"name":"九霄界境巅峰历练",
			"path":"jiuxiaojiejing/jiuxiaotianmen",
		]);
	}
	if(level>=70){
		path = "plxianjing/chilingxiaolu";
		if(race=="monst")
			path = "plxianjing/chiyuxiaolu";
		else if(race=="third")
			path = "penglaihuanjing/qiushuangxiaojing";
		return ([
			"max":MAX_LEVEL,
			"level":level>MAX_LEVEL ? MAX_LEVEL : level,
			"name":"动态同级历练",
			"path":path,
		]);
	}
	if(level<1)
		level = 1;
	if(!training_route_cache[race])
		race = "third";
	route = training_route_cache[race][level];
	if(route)
		return copy_value(route);
	return ([]);
}

string query_current_room_path(object me)
{
	object env;
	string path;
	string prefix;
	if(!me)
		return "";
	env = environment(me);
	if(!env)
		return "";
	path = (file_name(env)/"#")[0];
	prefix = ROOT+"/gamelib/d/";
	if(has_prefix(path,prefix))
		return path[sizeof(prefix)..];
	return path;
}

int can_auto_leave_current_room(object me)
{
	object env;
	string room_type;
	if(!me)
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	room_type = env->query_room_type();
	if(room_type=="fb" || room_type=="home" ||
	   room_type=="city" || room_type=="town")
		return 0;
	return 1;
}

string query_rest_room(object me)
{
	if(!me)
		return "";
	if(me->query_raceId()=="monst")
		return "jinaodao/yuhuacunguangchang";
	return "congxianzhen/congxianzhenguangchang";
}

int query_is_resting(object me)
{
	if(!me)
		return 0;
	return (int)me["/tmp/autofight_resting"] == 1;
}

int begin_auto_rest(object me)
{
	if(!me || !query_auto_rest_enabled(me) ||
	   !can_auto_leave_current_room(me))
		return 0;
	me["/tmp/autofight_resting"] = 1;
	me["/tmp/autofight_rest_started"] = time();
	return 1;
}

void finish_auto_rest(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_resting"] = 0;
	me["/tmp/autofight_rest_started"] = 0;
}

int query_route_ready(object me)
{
	int last;
	if(!me)
		return 0;
	last = (int)me["/tmp/autofight_last_route_time"];
	return last<=0 || time()-last>=AUTOFIGHT_ROUTE_COOLDOWN;
}

void record_route(object me,string path)
{
	if(!me)
		return;
	me["/tmp/autofight_last_route_time"] = time();
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/tmp/autofight_previous_room"] = "";
	me["/plus/autofight_last_route"] = path;
}

private int is_same_area(string current_path, string destination)
{
	array(string) current_parts;
	array(string) destination_parts;
	if(!current_path || !destination)
		return 0;
	current_path = (current_path/"#")[0];
	current_parts = current_path/"/";
	destination_parts = destination/"/";
	if(sizeof(current_parts) < 2 || sizeof(destination_parts) < 2)
		return 0;
	return current_parts[sizeof(current_parts)-2] ==
		destination_parts[sizeof(destination_parts)-2];
}

int should_route_to_training_area(object me,void|mapping target_snapshot)
{
	mapping(string:mixed) route;
	string current;
	string destination;
	if(!me || !query_smart_route_enabled(me) ||
	   !can_auto_leave_current_room(me) || !query_route_ready(me))
		return 0;
	route = query_training_route(me);
	destination = (string)route["path"];
	if(destination=="")
		return 0;
	current = query_current_room_path(me);
	if(current==destination)
		return 0;
	// 同一区域也可能相差十几层。当前房间明明有怪却全部超出
	// 安全等级时，直接回到精确推荐层，避免在相邻楼层间随机游走。
	// 真正的空图仍交给区域巡游，保留原有刷新与防抖行为。
	if(is_same_area(current,destination)){
		if(target_snapshot && (int)target_snapshot["visible"]>0)
			return 1;
		if(!target_snapshot && query_visible_monster_count(me)>0 &&
		   !query_target(me))
			return 1;
		return 0;
	}
	return 1;
}

int record_no_target(object me)
{
	int ticks;
	if(!me)
		return 0;
	ticks = (int)me["/tmp/autofight_no_target_ticks"]+1;
	me["/tmp/autofight_no_target_ticks"] = ticks;
	return ticks;
}

void clear_no_target(object me)
{
	if(me)
		me["/tmp/autofight_no_target_ticks"] = 0;
}

void record_roam(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_previous_room"] =
		query_current_room_path(me);
	me["/tmp/autofight_no_target_ticks"] = 0;
}

mapping(string:int) query_target_level_window(object me)
{
	mapping(string:mixed) route;
	int me_level;
	int minimum_level;
	int maximum_level;
	int route_level;
	if(!me)
		return (["minimum":1,"maximum":1]);
	me_level = me->query_level();
	maximum_level = me_level+2;
	minimum_level = 1;
	if(query_smart_route_enabled(me)){
		maximum_level = me_level;
		route = query_training_route(me);
		route_level = (int)route["level"];
		// 59级的固定路线位于60级怪区。只接受推荐路线恰好高1级的
		// 边界，不把智能挂机普遍放宽成可随意越级攻击。
		if(route_level == me_level+1)
			maximum_level = route_level;
		minimum_level = me_level-4;
		if(minimum_level<1)
			minimum_level = 1;
	}
	return ([
		"minimum":minimum_level,
		"maximum":maximum_level,
	]);
}

//“可见怪物”必须是挂机真正可以考虑攻击的野怪单位。
//方士三灵虽然继承 NPC，但它们是玩家随从；若计入可见怪数，
//只剩三灵的空图就会被误判为“有怪但不安全”并阻断换图。
private int is_visible_autofight_monster(object me,object ob)
{
	if(!me || !ob || ob==me)
		return 0;
	if(!ob->is("character") || !ob->is("npc"))
		return 0;
	if(ob->hind!=0 || ob->get_cur_life()<=0)
		return 0;
	if(functionp(ob->query_summon_type))
		return 0;
	if(functionp(ob->can_be_attacked) && !ob->can_be_attacked(me))
		return 0;
	if(!LOGICALZONED->can_action("combat",me,ob))
		return 0;
	return 1;
}

int query_visible_monster_count(object me)
{
	object env;
	array(object) all;
	int count;
	if(!me)
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = all_inventory(env);
	count = 0;
	foreach(all,object ob){
		if(is_visible_autofight_monster(me,ob))
			count++;
	}
	return count;
}

private int is_valid_target(object me, object ob)
{
	mapping(string:int) level_window;
	string npc_type;
	string me_race;
	string npc_race;
	int npc_level;
	int minimum_level;
	int maximum_level;
	if(!is_visible_autofight_monster(me,ob))
		return 0;
	if(ob->_boss || ob->_tasknpc)
		return 0;
	npc_type = ob->query_npc_type();
	if(npc_type == "city_keeper" || npc_type == "city_guarder" ||
	   npc_type == "city_lord")
		return 0;
	me_race = me->query_raceId();
	npc_race = ob->query_raceId();
	if(me_race != "third" && me_race == npc_race)
		return 0;
	npc_level = ob->query_level();
	level_window = query_target_level_window(me);
	minimum_level = level_window["minimum"];
	maximum_level = level_window["maximum"];
	if(npc_level > maximum_level || npc_level < minimum_level)
		return 0;
	return 1;
}

object|zero query_target(object me)
{
	mapping snapshot = query_target_snapshot(me);
	return snapshot["target"];
}

mapping query_target_snapshot(object me)
{
	object env;
	object|zero best;
	array(object) all;
	int best_level;
	int visible;
	int total;
	int start;
	int scan_count;
	int visible_total;
	string room_identity;
	if(!me)
		return (["target":0,"visible":0,"scanned":0,"total":0,
			"deferred":0,"cycle_complete":1]);
	env = environment(me);
	if(!env || env->is("peaceful"))
		return (["target":0,"visible":0,"scanned":0,"total":0,
			"deferred":0,"cycle_complete":1]);
	if(me->query_level()<70)
		MUD_ROOMD->restore_low_level_room_npcs(me);
	all = all_inventory(env);
	total = sizeof(all);
	room_identity = file_name(env);
	if((string)me["/tmp/autofight_scan_cursor_room"]!=room_identity){
		me["/tmp/autofight_scan_cursor"] = 0;
		me["/tmp/autofight_scan_cursor_room"] = room_identity;
		me["/tmp/autofight_scan_visible_total"] = 0;
	}
	start = (int)me["/tmp/autofight_scan_cursor"];
	if(start<0 || start>=total)
		start = 0;
	if(start==0)
		me["/tmp/autofight_scan_visible_total"] = 0;
	scan_count = total-start;
	if(scan_count>AUTOFIGHT_SCAN_MAX_OBJECTS)
		scan_count = AUTOFIGHT_SCAN_MAX_OBJECTS;
	autofight_scan_count++;
	if(total>start+scan_count)
		autofight_scan_deferred_objects += total-start-scan_count;
	best_level = -1;
	for(int offset=0;offset<scan_count;offset++){
		object ob = all[start+offset];
		int npc_level;
		if(is_visible_autofight_monster(me,ob))
			visible++;
		if(!is_valid_target(me,ob))
			continue;
		npc_level = ob->query_level();
		if(npc_level > best_level){
			best = ob;
			best_level = npc_level;
		}
	}
	visible_total = (int)me["/tmp/autofight_scan_visible_total"]+visible;
	me["/tmp/autofight_scan_visible_total"] = visible_total;
	if(start+scan_count>=total)
		me["/tmp/autofight_scan_cursor"] = 0;
	else
		me["/tmp/autofight_scan_cursor"] = start+scan_count;
	return ([
		"target":best,
		"visible":visible_total,
		"scanned":scan_count,
		"total":total,
		"deferred":total-start-scan_count,
		"cycle_complete":start+scan_count>=total,
	]);
}

private int can_loot_item(object me, object ob)
{
	string owner;
	string name_cn;
	int protect_time;
	if(!me || !ob)
		return 0;
	if(!ob->is("item") || ob->is("npc"))
		return 0;
	// 矿脉和药株是采集源，不是普通掉落。熟练度不足时采集入口会
	// 跳过它们，拾取入口也必须跳过，避免把“原矿/原药株”捡进背包。
	if(functionp(ob->query_source_type))
		return 0;
	if(functionp(ob->query_item_canGet) && ob->query_item_canGet() != 1)
		return 0;
	if(ob->query_name() == "corpse")
		return 0;
	name_cn = ob->query_name_cn();
	if(name_cn && (search(name_cn,"尸体") != -1 ||
	   search(name_cn,"骸骨") != -1))
		return 0;
	owner = ob->item_whoCanGet;
	protect_time = (int)ob->item_TimewhoCanGet;
	if(owner && owner != "" && owner != "1" &&
	   owner != me->query_name() && owner != me->query_term()){
		if(time()-protect_time < 120)
			return 0;
	}
	return 1;
}

void clear_failed_loot(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_failed_loot"] = 0;
	me["/tmp/autofight_failed_loot_room"] = 0;
	me["/tmp/autofight_failed_loot_retry"] = 0;
}

void record_failed_loot(object me,object item)
{
	if(!me || !item)
		return;
	me["/tmp/autofight_failed_loot"] = item;
	me["/tmp/autofight_failed_loot_room"] = environment(me);
	me["/tmp/autofight_failed_loot_retry"] =
		time()+AUTOFIGHT_LOOT_RETRY_SECONDS;
}

int query_loot_temporarily_suppressed(object me,object item)
{
	object|zero failed;
	object|zero failed_room;
	if(!me || !item)
		return 0;
	failed = me["/tmp/autofight_failed_loot"];
	failed_room = me["/tmp/autofight_failed_loot_room"];
	if(!failed || failed_room!=environment(me) ||
	   environment(failed)!=environment(me) ||
	   (int)me["/tmp/autofight_failed_loot_retry"]<=time()){
		clear_failed_loot(me);
		return 0;
	}
	return failed==item;
}

object|zero query_loot_item(object me)
{
	object env;
	array(object) all;
	if(!me || !query_loot_enabled(me))
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = query_bounded_scan_slice(me,all_inventory(env,me),
		"/tmp/autofight_loot_scan_cursor");
	foreach(all,object ob){
		if(can_loot_item(me,ob) &&
		   !query_loot_temporarily_suppressed(me,ob) &&
		   !me->if_over_load(ob))
			return ob;
	}
	return 0;
}

private int is_matching_recovery_item(object me,object item,string kind)
{
	mapping supply;
	if(!me || !item || item->amount <= 0 || item->eat_flag != 1)
		return 0;
	if(me->query_level() < item->level_limit)
		return 0;
	if(!item->race_limit[me->query_raceId()] ||
	   !sizeof(item->race_limit[me->query_raceId()]))
		return 0;
	if(!item->profe_limit[me->query_profeId()] ||
	   !sizeof(item->profe_limit[me->query_profeId()]))
		return 0;
	supply = item->add_supplay;
	if(!supply || !sizeof(supply))
		return 0;
	if(kind == "life")
		return functionp(item->eat) && (int)supply["life_supply"] > 0;
	if(kind == "mana")
		return functionp(item->drink) && (int)supply["mofa_supply"] > 0;
	return 0;
}

object|zero query_recovery_item(object me, string kind)
{
	string setting;
	array(object) all;
	if(!me)
		return 0;
	initialize_player(me);
	if(kind == "life")
		setting = (string)me["/plus/autofight_food"];
	else
		setting = (string)me["/plus/autofight_water"];
	all = all_inventory(me);
	foreach(all,object item){
		if(setting != "auto" && setting != "" &&
		   item->query_name() != setting)
			continue;
		if(is_matching_recovery_item(me,item,kind))
			return item;
	}
	if(setting != "auto" && setting != ""){
		foreach(all,object item){
			if(is_matching_recovery_item(me,item,kind))
				return item;
		}
	}
	return 0;
}

object|zero query_recovery_item_with_newbie_supply(object me,string kind)
{
	object|zero item;
	mapping result;
	if(!me)
		return 0;
	item = query_recovery_item(me,kind);
	if(item)
		return item;
	if(me->query_level()>NEWBIED->query_newbie_supply_max_level())
		return 0;
	result = NEWBIED->claim_newbie_supplies(me);
	if(result["code"]!=1)
		return 0;
	return query_recovery_item(me,kind);
}

int query_object_count(object ob, object env)
{
	array(object) all;
	int count;
	if(!ob || !env)
		return 0;
	all = all_inventory(env);
	count = 0;
	foreach(all,object item){
		if(item == ob)
			return count;
		if(item->query_name() == ob->query_name())
			count++;
	}
	return 0;
}

string query_safe_exit(object me)
{
	object env;
	array(string) exits;
	array(string) safe_exits;
	string current_path;
	string previous_room;
	string room_prefix;
	// 区域巡游是手动模式；智能寻路也应在推荐练级区空图时
	// 自动换到相邻地图，避免默认设置下永久等待刷新。
	if(!me || (!query_roam_enabled(me) &&
	   !query_smart_route_enabled(me)))
		return "";
	if((int)me["/tmp/autofight_no_target_ticks"] <
	   AUTOFIGHT_ROAM_NO_TARGET_TICKS)
		return "";
	if(!can_auto_leave_current_room(me))
		return "";
	env = environment(me);
	if(!env || !env->exits || !sizeof(env->exits))
		return "";
	current_path = file_name(env);
	previous_room = (string)me["/tmp/autofight_previous_room"];
	room_prefix = ROOT+"/gamelib/d/";
	exits = indices(env->exits);
	safe_exits = ({});
	foreach(exits,string direction){
		string destination;
		string destination_path;
		destination = (string)env->exits[direction];
		if(!destination || destination == "")
			continue;
		if(env->closed_exits[direction])
			continue;
		if(env->hidden_exits[direction])
			continue;
		if(env->guarded_exits[direction])
			continue;
		destination_path = (destination/"#")[0];
		if(has_prefix(destination_path,room_prefix))
			destination_path =
				destination_path[sizeof(room_prefix)..];
		if(previous_room && destination_path == previous_room &&
		   (int)me["/tmp/autofight_no_target_ticks"] <
		   AUTOFIGHT_ROAM_BACKTRACK_TICKS)
			continue;
		if(is_same_area(current_path,destination))
			safe_exits += ({direction});
	}
	if(!sizeof(safe_exits))
		return "";
	return safe_exits[random(sizeof(safe_exits))];
}
