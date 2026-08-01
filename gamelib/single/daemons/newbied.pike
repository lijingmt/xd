#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

#define GUIDE_VERSION 2
#define GUIDE_TOTAL 20
#define GUIDE_ROOT "/plus/newbie_tutorial"
#define GUIDE_POPUP_QUEUE "/tmp/newbie_tutorial/completion_queue"
#define GUIDE_DISABLE_AUTO "/tmp/newbie_tutorial/disable_auto"
#define GUIDE_REWARD_ERROR_STEP "/tmp/newbie_tutorial/reward_error_step"
#define NEWBIE_SUPPLY_ROOT "/plus/newbie_supply"
#define NEWBIE_SUPPLY_MAX_LEVEL 30
#define NEWBIE_RED_PATH ROOT+"/gamelib/clone/item/food/xinshouhongyao"
#define NEWBIE_BLUE_PATH ROOT+"/gamelib/clone/item/water/xinshoulanyao"
#define NEWBIE_RED_ID "xinshouhongyao"
#define NEWBIE_BLUE_ID "xinshoulanyao"

mapping(string:mapping(string:mixed)) profession_config = ([
	"jianxian":([
		"name":"剑仙",
		"starter":"qieyunzhan",
		"starter_cn":"切云斩",
		"level":9,
		"book":"book/liejiajianfeng",
		"book_cn":"【诅】裂甲剑风",
		"skill":"liejiajianfeng",
		"practice":"active",
		"practice_cn":"施放裂甲剑风，削弱敌人的防御",
	]),
	"yushi":([
		"name":"羽士",
		"starter":"yinghuozhou",
		"starter_cn":"萤火咒",
		"level":9,
		"book":"book/ningxinjue",
		"book_cn":"【仙】凝心决",
		"skill":"ningxinjue",
		"practice":"active",
		"practice_cn":"施放凝心决，建立吸收伤害的护盾",
	]),
	"zhuxian":([
		"name":"诛仙",
		"starter":"suixinjue",
		"starter_cn":"随心诀",
		"level":9,
		"book":"book/piaohubuding",
		"book_cn":"【仙】飘忽不定",
		"skill":"piaohubuding",
		"practice":"active",
		"practice_cn":"施放飘忽不定，降低敌人的命中",
	]),
	"kuangyao":([
		"name":"狂妖",
		"starter":"silie",
		"starter_cn":"撕裂",
		"level":9,
		"book":"book/shixiekuangbao1",
		"book_cn":"【妖】嗜血狂暴一级",
		"skill":"shixiekuangbao",
		"practice":"passive",
		"practice_cn":"带着嗜血狂暴击败一名敌人，验证被动暴击成长",
	]),
	"wuyao":([
		"name":"巫妖",
		"starter":"wudushu",
		"starter_cn":"巫毒术",
		"level":9,
		"book":"book/yaoshujiejie",
		"book_cn":"【妖】妖术结界",
		"skill":"yaoshujiejie",
		"practice":"active",
		"practice_cn":"施放妖术结界，建立法力护盾",
	]),
	"yinggui":([
		"name":"影鬼",
		"starter":"fuji",
		"starter_cn":"伏击",
		"level":9,
		"book":"book/guizong1",
		"book_cn":"【妖】鬼踪一级",
		"skill":"guizong",
		"practice":"passive",
		"practice_cn":"带着鬼踪击败一名敌人，验证被动闪避成长",
	]),
	"fangshi":([
		"name":"方士",
		"starter":"lingdanshu",
		"starter_cn":"灵弹术",
		"level":2,
		"book":"book/lingren",
		"book_cn":"【方】灵刃",
		"skill":"lingren",
		"practice":"summon",
		"practice_cn":"升到10级，学习虎灵并真正召唤一只虎灵",
	]),
	"zhenyue":([
		"name":"镇岳",
		"starter":"yueji",
		"starter_cn":"岳击",
		"level":5,
		"book":"book/zhenyan",
		"book_cn":"【岳】镇岩诀",
		"skill":"zhenyan",
		"practice":"active",
		"practice_cn":"施放镇岩诀，建立第一层稳定守势",
	]),
]);

mapping(string:mixed) query_profession_config(object player)
{
	string profession;

	if(!player)
		return ([]);
	profession = player->query_profeId();
	if(!profession_config[profession])
		return ([]);
	return copy_value(profession_config[profession]);
}

int query_newbie_supply_max_level()
{
	return NEWBIE_SUPPLY_MAX_LEVEL;
}

mapping(string:int) query_newbie_supply_policy(object player)
{
	mapping(string:int) policy = ([
		"limit":0,
		"red":0,
		"blue":0,
	]);
	int level;
	if(!player)
		return policy;
	level = player->query_level();
	if(level<=10){
		policy["limit"] = 3;
		policy["red"] = 15;
		policy["blue"] = 12;
	}
	else if(level<=20){
		policy["limit"] = 2;
		policy["red"] = 12;
		policy["blue"] = 10;
	}
	else if(level<=NEWBIE_SUPPLY_MAX_LEVEL){
		policy["limit"] = 1;
		policy["red"] = 8;
		policy["blue"] = 6;
	}
	return policy;
}

int query_newbie_supply_amount(object player,string item_name)
{
	int amount = 0;
	if(!player)
		return 0;
	foreach(all_inventory(player),object item){
		if(item && item->query_name()==item_name)
			amount += (int)item->amount;
	}
	return amount;
}

private int grant_newbie_supply_item(object player,string path,
	string item_name,int amount)
{
	object|zero item;
	int before;
	int after;
	mixed err;
	if(!player || amount<=0)
		return 0;
	before = query_newbie_supply_amount(player,item_name);
	err = catch {
		item = clone(path);
	};
	if(err || !item)
		return 0;
	item->amount = amount;
	item->move_player(player->query_name());
	after = query_newbie_supply_amount(player,item_name);
	if(after<=before && item)
		destruct(item);
	if(after-before>amount)
		return amount;
	if(after>before)
		return after-before;
	return 0;
}

mapping(string:int) grant_newbie_supplies(object player,int red,int blue)
{
	mapping(string:int) result = ([
		"red":0,
		"blue":0,
	]);
	if(!player)
		return result;
	result["red"] = grant_newbie_supply_item(player,NEWBIE_RED_PATH,
		NEWBIE_RED_ID,red);
	result["blue"] = grant_newbie_supply_item(player,NEWBIE_BLUE_PATH,
		NEWBIE_BLUE_ID,blue);
	if(result["red"]>0)
		player["/plus/autofight_food"] = NEWBIE_RED_ID;
	if(result["blue"]>0)
		player["/plus/autofight_water"] = NEWBIE_BLUE_ID;
	return result;
}

mapping(string:int) grant_starter_supplies(object player)
{
	mapping(string:int) result = ([
		"code":0,
		"red":0,
		"blue":0,
	]);
	mapping(string:int) granted;
	if(!player || player->query_level()>NEWBIE_SUPPLY_MAX_LEVEL)
		return result;
	if((int)player[NEWBIE_SUPPLY_ROOT+"/starter_granted"]){
		result["code"] = 2;
		return result;
	}
	granted = grant_newbie_supplies(player,20,15);
	result["red"] = granted["red"];
	result["blue"] = granted["blue"];
	if(result["red"]>0 || result["blue"]>0){
		player[NEWBIE_SUPPLY_ROOT+"/starter_granted"] = time();
		result["code"] = 1;
	}
	return result;
}

mapping(string:int) claim_newbie_supplies(object player)
{
	mapping(string:int) result = ([
		"code":0,
		"red":0,
		"blue":0,
		"used":0,
		"limit":0,
	]);
	mapping(string:int) policy;
	mapping(string:int) granted;
	int current_hour;
	int saved_hour;
	int used;
	if(!player)
		return result;
	policy = query_newbie_supply_policy(player);
	result["limit"] = policy["limit"];
	if(policy["limit"]<=0){
		result["code"] = 2;
		return result;
	}
	current_hour = time()/3600;
	saved_hour = (int)player[NEWBIE_SUPPLY_ROOT+"/hour"];
	used = (int)player[NEWBIE_SUPPLY_ROOT+"/count"];
	if(saved_hour!=current_hour){
		used = 0;
		player[NEWBIE_SUPPLY_ROOT+"/hour"] = current_hour;
		player[NEWBIE_SUPPLY_ROOT+"/count"] = 0;
	}
	result["used"] = used;
	if(used>=policy["limit"]){
		result["code"] = 3;
		return result;
	}
	granted = grant_newbie_supplies(player,policy["red"],policy["blue"]);
	result["red"] = granted["red"];
	result["blue"] = granted["blue"];
	if(result["red"]<=0 && result["blue"]<=0){
		result["code"] = 4;
		return result;
	}
	used++;
	player[NEWBIE_SUPPLY_ROOT+"/count"] = used;
	result["used"] = used;
	result["code"] = 1;
	return result;
}

void initialize_newbie_guide(object player)
{
	if(!player)
		return;
	if(!mappingp(player[GUIDE_ROOT+"/done"]))
		player[GUIDE_ROOT+"/done"] = ([]);
	if(!mappingp(player[GUIDE_ROOT+"/claimed"]))
		player[GUIDE_ROOT+"/claimed"] = ([]);
	if((int)player[GUIDE_ROOT+"/step"]<1)
		player[GUIDE_ROOT+"/step"] = 1;
	if((int)player[GUIDE_ROOT+"/step"]>GUIDE_TOTAL+1)
		player[GUIDE_ROOT+"/step"] = GUIDE_TOTAL+1;
	player[GUIDE_ROOT+"/version"] = GUIDE_VERSION;
}

int query_step(object player)
{
	initialize_newbie_guide(player);
	if(!player)
		return 0;
	return (int)player[GUIDE_ROOT+"/step"];
}

int query_total_steps()
{
	return GUIDE_TOTAL;
}

int query_action_done(object player,string key)
{
	mapping done;

	if(!player || !key || key=="")
		return 0;
	initialize_newbie_guide(player);
	done = player[GUIDE_ROOT+"/done"];
	return done[key] ? 1 : 0;
}

void record_action(object player,string key)
{
	mapping done;

	if(!player || !key || key=="")
		return;
	initialize_newbie_guide(player);
	done = player[GUIDE_ROOT+"/done"];
	if(!done[key])
		done[key] = time();
	try_auto_complete(player);
}

void record_book_shop(object player,string profession)
{
	if(!player || profession!=player->query_profeId())
		return;
	record_action(player,"profession_shop");
}

void record_book_purchase(object player,string item_name)
{
	mapping config = query_profession_config(player);

	if(!sizeof(config) || item_name!=config["book"])
		return;
	record_action(player,"profession_book_bought");
}

void record_book_read(object player)
{
	mapping config = query_profession_config(player);
	string skill;

	if(!sizeof(config))
		return;
	skill = config["skill"];
	if(player->skills && player->skills[skill])
		record_action(player,"profession_book_read");
}

void record_perform(object player,string skill)
{
	mapping config = query_profession_config(player);

	if(!sizeof(config) || !player->skills || !player->skills[skill])
		return;
	if(skill==config["starter"])
		record_action(player,"starter_perform");
	if(config["practice"]=="active" && skill==config["skill"])
		record_action(player,"profession_practice");
}

void record_kill(object player)
{
	mapping config = query_profession_config(player);
	int kills;

	if(!player)
		return;
	initialize_newbie_guide(player);
	if(query_step(player)>GUIDE_TOTAL)
		return;
	kills = (int)player[GUIDE_ROOT+"/kills"];
	if(kills<3)
		player[GUIDE_ROOT+"/kills"] = kills+1;
	if(sizeof(config) && config["practice"]=="passive" &&
	   player->skills && player->skills[config["skill"]])
		record_action(player,"profession_practice");
	try_auto_complete(player);
}

void record_summon(object player,string summon_type)
{
	if(!player || player->query_profeId()!="fangshi" ||
	   summon_type!="huling")
		return;
	record_action(player,"profession_practice");
}

int query_equipped_count(object player)
{
	mapping equipped;
	int count = 0;

	if(!player)
		return 0;
	equipped = player->query_equip();
	if(!mappingp(equipped))
		return 0;
	foreach(values(equipped),object item){
		if(item)
			count++;
	}
	return count;
}

string query_step_progress(object player,int step)
{
	mapping config = query_profession_config(player);
	mapping growth;
	int kills;

	switch(step){
		case 3:
			return "当前已穿"+query_equipped_count(player)+"件，至少需要4件。";
		case 7:
			growth = TASKD->query_growth_task_state(player);
			if(mappingp(growth) && sizeof(growth))
				return "已领取"+growth["level"]+"级"+
					player->query_profe_cn(growth["profession"])+"历练。";
			return "尚未领取本级职业历练。";
		case 10:
			kills = (int)player[GUIDE_ROOT+"/kills"];
			if(kills>3)
				kills = 3;
			return "新手实战击败敌人："+kills+"/3。";
		case 17:
			return "当前等级："+player->query_level()+"/"+config["level"]+"。";
		case 20:
			if(config["practice"]=="summon")
				return "当前等级："+player->query_level()+"/10；还需学习虎灵并成功召唤。";
			return config["practice_cn"];
	}
	return "";
}

int query_step_ready(object player,int step)
{
	mapping config = query_profession_config(player);
	mapping growth;

	if(!player || !sizeof(config))
		return 0;
	switch(step){
		case 1:
			return query_action_done(player,"status");
		case 2:
			return query_action_done(player,"inventory");
		case 3:
			return query_action_done(player,"auto_equip") &&
				query_equipped_count(player)>=4;
		case 4:
			return query_action_done(player,"skills");
		case 5:
			return query_action_done(player,"map");
		case 6:
			return query_action_done(player,"tasks");
		case 7:
			growth = TASKD->query_growth_task_state(player);
			return (mappingp(growth) && sizeof(growth) &&
				growth["profession"]==player->query_profeId()) ||
				TASKD->query_growth_task_done(
					player,player->query_level());
		case 8:
			return query_action_done(player,"task_guide") ||
				TASKD->query_growth_task_done(
					player,player->query_level());
		case 9:
			return query_action_done(player,"starter_perform");
		case 10:
			return (int)player[GUIDE_ROOT+"/kills"]>=3;
		case 11:
			return query_action_done(player,"eat");
		case 12:
			return query_action_done(player,"top");
		case 13:
			return query_action_done(player,"mailbox");
		case 14:
			return query_action_done(player,"chat");
		case 15:
			return query_action_done(player,"team");
		case 16:
			return query_action_done(player,"profession_shop");
		case 17:
			return player->query_level()>=(int)config["level"];
		case 18:
			return query_action_done(player,"profession_book_bought");
		case 19:
			return query_action_done(player,"profession_book_read") &&
				player->skills && player->skills[config["skill"]];
		case 20:
			if(config["practice"]=="summon")
				return player->query_level()>=10 &&
					player->skills && player->skills["huling"] &&
					query_action_done(player,"profession_practice");
			return query_action_done(player,"profession_practice");
	}
	return 0;
}

mapping(string:mixed) query_step_state(object player)
{
	mapping config = query_profession_config(player);
	mapping state = ([
		"step":0,
		"total":GUIDE_TOTAL,
		"title":"",
		"desc":"",
		"action_label":"",
		"action_command":"",
		"progress":"",
		"ready":0,
		"complete":0,
	]);
	int step;

	if(!player || !sizeof(config))
		return state;
	step = query_step(player);
	state["step"] = step;
	if(step>GUIDE_TOTAL){
		state["complete"] = 1;
		state["title"] = config["name"]+"新手课程已毕业";
		return state;
	}

	switch(step){
		case 1:
			state["title"] = "认识人物状态";
			state["desc"] = "查看等级、生命、法力、职业和当前经验。";
			state["action_label"] = "打开人物状态";
			state["action_command"] = "myhp";
			break;
		case 2:
			state["title"] = "认识背包";
			state["desc"] = "查看初始装备和以后打怪得到的物品；完成后会得到3份干粮。";
			state["action_label"] = "打开物品";
			state["action_command"] = "inventory";
			break;
		case 3:
			state["title"] = "亲手使用穿装助手";
			state["desc"] = "助手只填空位，不会覆盖已有装备；需要真实执行且至少穿好4件。";
			state["action_label"] = "一键穿装";
			state["action_command"] = "auto_equip";
			break;
		case 4:
			state["title"] = "认识"+config["name"]+"技能";
			state["desc"] = "找到初始技能“"+config["starter_cn"]+"”，后面会在战斗中实际施放。";
			state["action_label"] = "查看技能";
			state["action_command"] = "myskills";
			break;
		case 5:
			state["title"] = "认识世界地图";
			state["desc"] = "地图用于寻找适合等级的练级区、主城与系统入口。";
			state["action_label"] = "查看地图";
			state["action_command"] = "map_display";
			break;
		case 6:
			state["title"] = "认识任务列表";
			state["desc"] = "主线、职业任务和每级历练都会汇总在这里。";
			state["action_label"] = "查看任务";
			state["action_command"] = "mytasks";
			break;
		case 7:
			state["title"] = "领取本级职业历练";
			state["desc"] = "八职业每一级都有历练；领取后击败等级接近自己的怪物。";
			state["action_label"] = "领取历练";
			state["action_command"] = "growth_task accept";
			break;
		case 8:
			state["title"] = "使用安全任务引导";
			state["desc"] = "服务器会核验任务目标，并直接带你到目标地图；战斗和副本中不能使用。";
			state["action_label"] = "前往历练目标";
			state["action_command"] = "task_guide growth";
			break;
		case 9:
			state["title"] = "施放"+config["starter_cn"];
			state["desc"] = "点击当前地图中的怪物进入战斗，再从技能页实际施放一次。";
			state["action_label"] = "打开技能";
			state["action_command"] = "myskills";
			break;
		case 10:
			state["title"] = "完成三次实战";
			state["desc"] = "亲手击败3名敌人，熟悉经验、金钱、任务进度和装备掉落。";
			state["action_label"] = "返回战斗";
			state["action_command"] = "look";
			break;
		case 11:
			state["title"] = "受伤后使用干粮";
			state["desc"] = "战斗受伤后，在物品页食用前面奖励的干粮；生命已满时不会消耗也不算完成。";
			state["action_label"] = "打开物品";
			state["action_command"] = "inventory";
			break;
		case 12:
			state["title"] = "查看排行榜";
			state["desc"] = "了解等级、财富与职业成长的长期目标。";
			state["action_label"] = "查看排行榜";
			state["action_command"] = "look_top";
			break;
		case 13:
			state["title"] = "查看收件箱";
			state["desc"] = "任务、帮派和玩家消息可能通过邮件送达。";
			state["action_label"] = "打开收件箱";
			state["action_command"] = "mailbox";
			break;
		case 14:
			state["title"] = "认识阵营聊天";
			if(player->query_raceId()=="third")
				state["desc"] = "打开聊天频道；中立职业可同时查看仙、妖消息，并使用两边公共生活入口。";
			else
				state["desc"] = "打开本阵营聊天频道，认识同阵营玩家并留意组队消息。";
			state["action_label"] = "打开聊天";
			state["action_command"] = "chatroom_list";
			break;
		case 15:
			state["title"] = "认识七星阵队伍";
			if(player->query_profeId()=="fangshi")
				state["desc"] = "队伍用于协作打怪和进入副本；灵莲铺与鹤灵共鸣会照顾同房间队友。";
			else if(player->query_profeId()=="zhenyue")
				state["desc"] = "队伍用于协作打怪和进入副本；震吼稳住仇恨，山河壁只保护同房间存活队友。";
			else
				state["desc"] = "队伍用于协作打怪、共享战利品并进入需要多人配合的副本。";
			state["action_label"] = "打开队伍";
			state["action_command"] = "my_term";
			break;
		case 16:
			state["title"] = "找到"+config["name"]+"技能书";
			state["desc"] = "打开本职业书店；只能按人物职业学习，不能跨职业读书。";
			state["action_label"] = "打开职业书店";
			state["action_command"] = "buy_items book "+player->query_profeId();
			break;
		case 17:
			state["title"] = "达到首本技能书等级";
			state["desc"] = config["name"]+"首本课程是"+config["level"]+"级“"+
				config["book_cn"]+"”。达到等级后会发放恰好够买首本书的金钱和碎玉。";
			state["action_label"] = "继续每级历练";
			state["action_command"] = "growth_task";
			break;
		case 18:
			state["title"] = "购买"+config["book_cn"];
			state["desc"] = "必须真实购买指定职业书；查看商品或购买别的书不能完成。";
			state["action_label"] = "前往购买";
			state["action_command"] = "buy_items book "+player->query_profeId();
			break;
		case 19:
			state["title"] = "阅读并学会"+config["book_cn"];
			state["desc"] = "书买进背包后还没有学会，必须在物品页点击阅读；成功学习才完成。";
			state["action_label"] = "打开物品读书";
			state["action_command"] = "inventory";
			break;
		case 20:
			state["title"] = config["name"]+"职业实战";
			state["desc"] = config["practice_cn"]+"。";
			if(config["practice"]=="summon"){
				state["desc"] += " 本步会在上一关后发放购买虎灵所需的150金和10碎玉。";
				state["action_label"] = "方士技能书";
				state["action_command"] = "buy_items book fangshi";
			}
			else if(config["practice"]=="passive"){
				state["action_label"] = "寻找敌人实战";
				state["action_command"] = "look";
			}
			else{
				state["action_label"] = "打开技能实战";
				state["action_command"] = "myskills";
			}
			break;
	}
	state["progress"] = query_step_progress(player,step);
	state["ready"] = query_step_ready(player,step);
	return state;
}

object|zero grant_dry_ration(object player)
{
	object|zero ration;
	mixed err = catch {
		ration = clone(ROOT+"/gamelib/clone/item/food/ganliang");
	};
	if(err || !ration)
		return 0;
	ration->amount = 3;
	if(!ration->move(player)){
		destruct(ration);
		return 0;
	}
	return ration;
}

object|zero grant_jade(object player,int amount)
{
	object|zero jade;
	mixed err = catch {
		jade = clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	};
	if(err || !jade)
		return 0;
	jade->amount = amount;
	if(!jade->move(player)){
		destruct(jade);
		return 0;
	}
	return jade;
}

mapping(string:mixed) grant_step_reward(object player,int step)
{
	mapping result = ([
		"success":1,
		"desc":"",
	]);
	mapping config = query_profession_config(player);
	mapping claimed;
	int money = 100;
	int jade = 0;

	initialize_newbie_guide(player);
	claimed = player[GUIDE_ROOT+"/claimed"];
	if(claimed[step]){
		result["desc"] = "本步奖励已经领取过。";
		return result;
	}

	if(step==2){
		object ration = grant_dry_ration(player);
		if(!ration){
			result["success"] = 0;
			result["desc"] = "背包暂时无法接收干粮，请整理后重试。";
			return result;
		}
		result["desc"] = "得到3份干粮。";
	}
	else if(step==17){
		object jade_item;
		money = 5000;
		jade = 5;
		if(config["practice"]=="summon"){
			money = 4000;
			jade = 3;
		}
		jade_item = grant_jade(player,jade);
		if(!jade_item){
			result["success"] = 0;
			result["desc"] = "背包暂时无法接收碎玉，请整理后重试。";
			return result;
		}
		player->add_money(money);
		result["desc"] = "得到"+money/100+"金和"+jade+
			"碎玉，请留给首本职业技能书。";
	}
	else if(step==19 && config["practice"]=="summon"){
		object jade_item = grant_jade(player,10);
		if(!jade_item){
			result["success"] = 0;
			result["desc"] = "背包暂时无法接收碎玉，请整理后重试。";
			return result;
		}
		money = 15000;
		jade = 10;
		player->add_money(money);
		result["desc"] = "得到150金和10碎玉，请留给10级虎灵技能书。";
	}
	else{
		if(step==20)
			money = 1000;
		player->add_money(money);
		result["desc"] = "得到"+money/100+"金。";
	}
	claimed[step] = time();
	return result;
}

mapping(string:mixed) claim_current_step(object player)
{
	mapping result = ([
		"code":0,
		"step":0,
		"next_step":0,
		"title":"",
		"reward":"",
	]);
	mapping state;
	mapping reward;
	int step;

	if(!player)
		return result;
	state = query_step_state(player);
	step = state["step"];
	result["step"] = step;
	result["title"] = state["title"];
	if(state["complete"]){
		result["code"] = 3;
		result["next_step"] = step;
		return result;
	}
	if(!state["ready"]){
		result["code"] = 1;
		result["next_step"] = step;
		return result;
	}
	reward = grant_step_reward(player,step);
	if(!reward["success"]){
		result["code"] = 4;
		result["reward"] = reward["desc"];
		result["next_step"] = step;
		return result;
	}
	player[GUIDE_ROOT+"/step"] = step+1;
	result["code"] = 2;
	result["next_step"] = step+1;
	result["reward"] = reward["desc"];
	return result;
}

mapping(string:mixed) build_completion_notice(
	object player,mapping claim)
{
	mapping notice = copy_value(claim);
	mapping next_state = query_step_state(player);

	notice["total"] = GUIDE_TOTAL;
	notice["complete"] = next_state["complete"] ? 1 : 0;
	notice["next_title"] = next_state["title"];
	notice["next_desc"] = next_state["desc"];
	notice["next_action_label"] = next_state["action_label"];
	notice["next_action_command"] = next_state["action_command"];
	if(notice["complete"]){
		notice["next_action_label"] = "查看职业成长路线";
		notice["next_action_command"] = "newbie_guide roadmap";
	}
	else if(!notice["next_action_label"] ||
		notice["next_action_label"]==""){
		notice["next_action_label"] = "查看下一步";
		notice["next_action_command"] = "newbie_guide";
	}
	return notice;
}

void queue_completion_notice(object player,mapping notice)
{
	array queue;

	if(!player || !notice || !player->is_http_api_user)
		return;
	queue = player[GUIDE_POPUP_QUEUE];
	if(!arrayp(queue))
		queue = ({});
	queue += ({copy_value(notice)});
	player[GUIDE_POPUP_QUEUE] = queue;
}

void tell_completion_notice(object player,mapping notice)
{
	string result = "";

	if(!player || !notice)
		return;
	if(notice["code"]==4){
		result += "\n【新手任务奖励待领取】\n";
		result += notice["title"]+"\n";
		result += notice["reward"]+"\n";
		result += "[整理背包:inventory]|"+
			"[重新领取:newbie_guide check]\n";
		tell_object(player,result);
		return;
	}
	result += "\n【新手任务完成 "+notice["step"]+"/"+
		notice["total"]+"】\n";
	result += notice["title"]+"\n";
	if(notice["reward"] && notice["reward"]!="")
		result += notice["reward"]+"\n";
	if(notice["complete"])
		result += "恭喜，你已经完成全部新手课程！\n";
	else
		result += "下一步："+notice["next_title"]+"\n";
	result += "["+notice["next_action_label"]+":"+
		notice["next_action_command"]+"]\n";
	tell_object(player,result);
}

mapping(string:mixed) claim_with_notice(object player)
{
	mapping claim;
	mapping notice;

	if(!player)
		return (["code":0]);
	claim = claim_current_step(player);
	if(claim["code"]!=2 && claim["code"]!=4)
		return claim;
	if(claim["code"]==4 &&
	   (int)player[GUIDE_REWARD_ERROR_STEP]==claim["step"])
		return claim;
	if(claim["code"]==4)
		player[GUIDE_REWARD_ERROR_STEP] = claim["step"];
	else
		player[GUIDE_REWARD_ERROR_STEP] = 0;
	notice = build_completion_notice(player,claim);
	queue_completion_notice(player,notice);
	tell_completion_notice(player,notice);
	return claim;
}

int try_auto_complete(object player)
{
	mapping claim;

	if(!player || player[GUIDE_DISABLE_AUTO])
		return 0;
	claim = claim_with_notice(player);
	return claim["code"];
}

array(mapping) consume_completion_notices(object player)
{
	array queue;

	if(!player)
		return ({});
	queue = player[GUIDE_POPUP_QUEUE];
	player[GUIDE_POPUP_QUEUE] = 0;
	if(!arrayp(queue))
		return ({});
	return copy_value(queue);
}
