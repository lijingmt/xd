#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

private mapping(string:mapping(string:string)) skill_catalog=([
	"jianxian":(["skill":"newmoon_jianxian","name_cn":"【套装】月痕归鞘"]),
	"yushi":(["skill":"newmoon_yushi","name_cn":"【套装】星垂九野"]),
	"zhuxian":(["skill":"newmoon_zhuxian","name_cn":"【套装】逐月无痕"]),
	"kuangyao":(["skill":"newmoon_kuangyao","name_cn":"【套装】血月战吼"]),
	"wuyao":(["skill":"newmoon_wuyao","name_cn":"【套装】幽月蚀心"]),
	"yinggui":(["skill":"newmoon_yinggui","name_cn":"【套装】月影绝行"]),
	"fangshi":(["skill":"newmoon_fangshi","name_cn":"【套装】万象月轮"]),
	"zhenyue":(["skill":"newmoon_zhenyue","name_cn":"【套装】山河月障"]),
	"tianxiang":(["skill":"newmoon_tianxiang","name_cn":"【套装】周天月陨"]),
	"lingyi":(["skill":"newmoon_lingyi","name_cn":"【套装】长生月华"]),
	"wuxiang":(["skill":"newmoon_wuxiang","name_cn":"【套装】混元月变"]),
	"taiji":(["skill":"newmoon_taiji","name_cn":"【套装】两仪归一"]),
	"zhaoming":(["skill":"newmoon_zhaoming","name_cn":"【套装】五命同辉"]),
]);

private mapping(int:string) rank_names=([
	1:"新月",2:"曜星",3:"天穹",4:"太虚",5:"太初",6:"寰极",
]);

mapping(string:mapping(string:string)) query_skill_catalog()
{
	return copy_value(skill_catalog);
}

int is_set_skill_name(string name)
{
	if(!name || name=="" || sizeof(name)>64 || search(name,"/")!=-1 ||
	   search(name,"..")!=-1)
		return 0;
	foreach(values(skill_catalog),mapping config)
		if((string)config["skill"]==name)
			return 1;
	return 0;
}

private object|zero query_active_set_piece(object player)
{
	mapping equipped;
	array(object) counted=({});
	if(!player || !functionp(player->is) || !player->is("player") ||
	   !functionp(player->query_equip) ||
	   !functionp(player->query_profeId))
		return 0;
	equipped=player->query_equip();
	if(!mappingp(equipped))
		return 0;
	foreach(values(equipped),mixed candidate){
		object item;
		if(!objectp(candidate))
			continue;
		item=(object)candidate;
		if(search(counted,item)!=-1)
			continue;
		counted+=({item});
		if(environment(item)!=player || !item->equiped ||
		   !functionp(item->query_newmoon_resonance_active) ||
		   !functionp(item->query_newmoon_set_piece_count) ||
		   !functionp(item->query_newmoon_collection_rank) ||
		   !functionp(item->query_newmoon_resonance_profession) ||
		   !item->query_newmoon_resonance_active() ||
		   item->query_newmoon_set_piece_count()!=10 ||
		   item->query_newmoon_resonance_profession()!=
			player->query_profeId())
			continue;
		return item;
	}
	return 0;
}

mapping(string:mixed) query_active_set_skill(object player)
{
	object|zero piece=query_active_set_piece(player);
	mapping config;
	int rank;
	string profession;
	if(!piece)
		return ([]);
	profession=(string)player->query_profeId();
	config=skill_catalog[profession];
	if(!config)
		return ([]);
	rank=(int)piece->query_newmoon_collection_rank();
	if(rank<1 || rank>6)
		return ([]);
	return ([
		"skill":(string)config["skill"],
		"name_cn":(string)config["name_cn"],
		"profession":profession,
		"rank":rank,
		"collection":rank_names[rank],
		"piece":piece,
	]);
}

string query_active_skill_name(object player)
{
	mapping active=query_active_set_skill(player);
	return sizeof(active) ? (string)(active["skill"] || "") : "";
}

int query_active_skill_level(object player,string name)
{
	mapping active;
	if(!is_set_skill_name(name))
		return 0;
	active=query_active_set_skill(player);
	if(!sizeof(active) || (string)active["skill"]!=name)
		return 0;
	return (int)active["rank"];
}

object|zero query_active_skill_object(object player,string name)
{
	object|zero skill=0;
	mixed load_err=0;
	if(query_active_skill_level(player,name)<=0)
		return 0;
	skill=MUD_SKILLSD[name];
	if(!skill){
		load_err=catch {
			skill=(object)(ROOT+"/gamelib/single/skills/"+name);
		};
		if(load_err)
			skill=0;
	}
	if(!skill || !functionp(skill->query_newmoon_set_skill) ||
	   !skill->query_newmoon_set_skill())
		return 0;
	return skill;
}

string query_active_skill_summary(object player)
{
	mapping active=query_active_set_skill(player);
	if(!sizeof(active))
		return "";
	return (string)active["name_cn"]+"（"+
		(string)active["collection"]+"·"+
		(string)active["rank"]+"阶）";
}
