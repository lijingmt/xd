/** 十职业太古隐藏传承：70个独立ID、统一成长和严格递减掉落权重。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

private array(string) profession_order = ({
	"jianxian","yushi","zhuxian","kuangyao","wuyao",
	"yinggui","fangshi","zhenyue","tianxiang","lingyi",
});

private mapping(string:string) profession_names = ([
	"jianxian":"剑仙","yushi":"羽士","zhuxian":"诛仙",
	"kuangyao":"狂妖","wuyao":"巫妖","yinggui":"影鬼",
	"fangshi":"方士","zhenyue":"镇越","tianxiang":"天象",
	"lingyi":"灵医",
]);

// 每项为“稳定技能ID|中文名”。寰极技能使用 huanji 前缀；旧鸿蒙前缀
// 只在下方兼容映射中接受，用于登录迁移和已存档技能书恢复。
private mapping(string:array(string)) profession_skills = ([
	"jianxian":({"taixujianhen|太虚剑痕","xinghejiandian|星河剑典","wanjianchaoxi|万剑潮汐","tiangangjianjie|天罡剑界","wuxiangjianxin|无相剑心","jiuxiaojianjie|九霄剑劫","huanjiyijian|寰极一剑"}),
	"yushi":({"tianhuanglingyu|天凰灵羽","jiutianfenglei|九天风雷","bingheyuemian|冰河月冕","liuguangxianyin|流光仙音","cangmingyufeng|苍冥御风","taixushenlei|太虚神雷","wanxiangtianguang|万象天光"}),
	"zhuxian":({"zhutianjianyu|诛天剑狱","longhunpozhen|龙魂破阵","tianluofengmo|天罗封魔","shenxiaojianming|神霄剑鸣","qixingzhuxie|七星诛邪","wanfazhanmie|万法斩灭","hunyuanjiandao|混元剑道"}),
	"kuangyao":({"huangguyaomai|荒古妖脉","xueyuekuangchao|血月狂潮","tianshaxuezhou|天煞血咒","wanhuangzhennu|万荒震怒","shuraqianlie|修罗千裂","miezhanmoqu|灭战魔躯","hundunkaimo|混沌开魔"}),
	"wuyao":({"xuanyinminghuo|玄阴冥火","jiuyouxiefeng|九幽邪风","huangquanzhoujie|黄泉咒界","wanshidupo|万蚀毒魄","tianmoguiyin|天魔鬼印","xueyuelunzhuan|血月轮转","hunyuanmiejie|混元灭界"}),
	"yinggui":({"wujianyingxi|无间影袭","mingyezhuiming|冥夜追命","qiankunhuanying|乾坤幻影","jiuyousuohun|九幽锁魂","wuyingtiansha|无影天煞","luanshimingzhan|乱世冥斩","taixujueying|太虚绝影"}),
	"fangshi":({"taigulingzhen|太古灵阵","shanhaifuzhao|山海符诏","yinyanglingyu|阴阳灵域","jiuxiaoleifa|九霄雷法","wanlingguizhen|万灵归真","hunyuandaoyin|混元道印","huanjifaling|寰极法灵"}),
	"zhenyue":({"taigushanyin|太古山印","wuyuezhenjie|五岳镇界","tianqingdimai|天擎地脉","wanshanzhenshi|万山镇世","buzhoushouyu|不周守御","hunyuandibi|混元地壁","huanjiyuezhen|寰极岳阵"}),
	"tianxiang":({"zhouxingtiantu|周星天图","ziyaoxingyu|紫曜星雨","tiangangxingzhen|天罡星阵","yinyuehanchao|银月寒潮","jiuxiaoxinglei|九霄星雷","wanxiangxingjie|万象星界","huanjitianguang|寰极天光"}),
	"lingyi":({"qingdiyaodian|青帝药典","jiuzhuanhuichun|九转回春","yaowanglingyu|药王灵域","wanhuajinglu|万华净露","shengshengbuxi|生生不息","cihangtianguang|慈航天光","huanjihuisheng|寰极回生"}),
]);

private mapping(string:string) legacy_skill_ids = ([
	"hongmengyijian":"huanjiyijian",
	"hongmengfaling":"huanjifaling",
	"hongmengyuezhen":"huanjiyuezhen",
	"hongmengtianguang":"huanjitianguang",
	"hongmenghuisheng":"huanjihuisheng",
]);

string query_canonical_skill_id(string|zero skill_id)
{
	if(!skill_id || skill_id=="")
		return "";
	return legacy_skill_ids[skill_id] || skill_id;
}

mapping(string:string) query_legacy_skill_id_migrations()
{
	return copy_value(legacy_skill_ids);
}

private mapping(string:array(string)) profession_types = ([
	"jianxian":({"phy","phy","buff","phy","dot","phy","phy"}),
	"yushi":({"feng_mofa_attack","huo_mofa_attack","bing_mofa_attack","buff","feng_mofa_attack","huo_mofa_attack","bing_mofa_attack"}),
	"zhuxian":({"phy","curse","phy","buff","dot","phy","phy"}),
	"kuangyao":({"dot","phy","buff","dot","curse","phy","phy"}),
	"wuyao":({"du_mofa_attack","feng_mofa_attack","curse","dot","buff","bing_mofa_attack","du_mofa_attack"}),
	"yinggui":({"phy","dot","curse","buff","phy","phy","phy"}),
	"fangshi":({"feng_mofa_attack","du_mofa_attack","buff","huo_mofa_attack","bing_mofa_attack","curse","feng_mofa_attack"}),
	"zhenyue":({"taunt","phy","buff","team_guard","curse","buff","phy"}),
	"tianxiang":({"feng_mofa_attack","huo_mofa_attack","buff","bing_mofa_attack","huo_mofa_attack","curse","feng_mofa_attack"}),
	"lingyi":({"heal","heal","buff","bing_mofa_attack","heal","heal","heal"}),
]);

// 品阶越高权重越低；390/1250000000约为神技池37/10000000的1/12。
private array(int) tier_drop_weights = ({12,9,7,5,3,2,1});
private int drop_denominator = 1250000000;
private int minimum_npc_level = 90;

private array(string) split_entry(string entry)
{
	array(string) parts = entry/"|";
	return sizeof(parts)==2 ? parts : ({"",""});
}

mapping(string:mixed) query_skill_config(string|zero skill_id)
{
	if(!skill_id || skill_id=="")
		return ([]);
	skill_id=query_canonical_skill_id(skill_id);
	foreach(profession_order,string profession){
		array(string) entries = profession_skills[profession];
		for(int i=0;i<sizeof(entries);i++){
			array(string) parts = split_entry(entries[i]);
			if(parts[0]==skill_id)
				return ([
					"id":parts[0],"name_cn":parts[1],
					"profession":profession,
					"profession_cn":profession_names[profession],
					"type":profession_types[profession][i],
					"tier":i+1,"weight":tier_drop_weights[i],
				]);
		}
	}
	return ([]);
}

string query_colored_name(string skill_id)
{
	mapping config = query_skill_config(skill_id);
	array(string) colors = ({"§3","§4","§5","§b","§C","§6","§E"});
	int tier = (int)config["tier"];
	if(!sizeof(config) || tier<1 || tier>7)
		return "";
	return colors[tier-1]+"【太古·"+tier+"】"+
		(string)config["name_cn"]+"§r";
}

array(string) query_all_skill_ids()
{
	array(string) result = ({});
	foreach(profession_order,string profession)
		foreach(profession_skills[profession],string entry)
			result += ({split_entry(entry)[0]});
	return result;
}

array(string) query_profession_skill_ids(string|zero profession)
{
	array(string) result = ({});
	if(!profession || !profession_skills[profession])
		return result;
	foreach(profession_skills[profession],string entry)
		result += ({split_entry(entry)[0]});
	return result;
}

string query_profession_name(string|zero profession)
{
	if(!profession || !profession_names[profession])
		return "";
	return profession_names[profession];
}

int query_total_drop_weight()
{
	int one_profession = 0;
	foreach(tier_drop_weights,int weight)
		one_profession += weight;
	return one_profession*sizeof(profession_order);
}

int query_drop_denominator(){ return drop_denominator; }
int query_minimum_npc_level(){ return minimum_npc_level; }
array(int) query_tier_drop_weights(){ return tier_drop_weights+({}); }

string query_weighted_book(int roll)
{
	if(roll<1 || roll>query_total_drop_weight())
		return "";
	foreach(profession_order,string profession){
		array(string) entries = profession_skills[profession];
		for(int i=0;i<sizeof(entries);i++){
			if(roll<=tier_drop_weights[i])
				return "book/"+split_entry(entries[i])[0];
			roll -= tier_drop_weights[i];
		}
	}
	return "";
}

/**
 * 一次性兼容旧太古七阶前缀。迁移人物技能、冷却、快捷栏和挂机队列，
 * 不触碰技能等级数值，也不清空已有冷却。
 */
int migrate_player_skill_ids(object player)
{
	int changes = 0;
	if(!player)
		return 0;
	foreach(indices(legacy_skill_ids),string old_id){
		string new_id = legacy_skill_ids[old_id];
		if(mappingp(player->skills) && has_index(player->skills,old_id)){
			mixed old_raw = player->skills[old_id];
			if(arrayp(old_raw) && sizeof((array)old_raw)){
				array old_value = (array)old_raw;
				mixed new_raw = player->skills[new_id];
				array new_value = arrayp(new_raw) ? (array)new_raw : ({});
				if(!sizeof(new_value) ||
				   (int)old_value[0]>(int)new_value[0] ||
				   ((int)old_value[0]==(int)new_value[0] &&
				   sizeof(old_value)>1 &&
				   (sizeof(new_value)<2 ||
				   (int)old_value[1]>(int)new_value[1])))
					player->skills[new_id]=copy_value(old_value);
			}
			// 即使旧键异常，也要删除已废弃 ID；异常值不能成为绕过
			// canonical 技能目录的第二份状态。
			m_delete(player->skills,old_id);
			changes++;
		}
		if(mappingp(player->f_skills) &&
		   has_index(player->f_skills,old_id)){
			int old_cold = (int)player->f_skills[old_id];
			if(old_cold>(int)player->f_skills[new_id])
				player->f_skills[new_id]=old_cold;
			m_delete(player->f_skills,old_id);
			changes++;
		}
		if((string)(player->skills_enable || "")==old_id){
			player->skills_enable=new_id;
			changes++;
		}
		if(arrayp(player->toolbar_key)){
			foreach(player->toolbar_key,mixed slot){
				if(!mappingp(slot) || !has_index(slot,old_id))
					continue;
				if(!has_index(slot,new_id))
					slot[new_id]=slot[old_id];
				m_delete(slot,old_id);
				changes++;
			}
		}
	}
	mixed stored = player["/plus/autofight_skill_queue"];
	if(arrayp(stored)){
		array queue = copy_value(stored);
		for(int i=0;i<sizeof(queue);i++){
			string canonical = query_canonical_skill_id(
				stringp(queue[i]) ? (string)queue[i] : "");
			if(stringp(queue[i]) && canonical!=(string)queue[i]){
				queue[i]=canonical;
				changes++;
			}
		}
		player["/plus/autofight_skill_queue"]=queue;
	}
	return changes;
}
