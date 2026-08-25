#include <command.h>
#include <gamelib/include/gamelib.h>
#define HONER ROOT "/gamelib/clone/item/honer/"
// 顶级荣誉装备：按玩家当前等级动态生成一件定制品质装备。
// 低于70级发放固定【仙】/【妖】套装部件；70级以上用动态
// 装备生成器按人物等级实时生成，属性随等级增长。

private mapping(string:array(string)) fixed_top_cache=([]);

private array(string) query_fixed_top_paths(string catalog_race,string slot)
{
	string cache_key=catalog_race+"|"+slot;
	array(string) cached;
	array(string) matched=({});
	string prefix;
	if(arrayp(fixed_top_cache[cache_key]) &&
	   sizeof(fixed_top_cache[cache_key]))
		return fixed_top_cache[cache_key];
	if(catalog_race=="human")
		prefix="70xianpo";
	else if(catalog_race=="monst")
		prefix="70yaohun";
	else
		return ({});
	foreach(get_dir(HONER) || ({}),string one){
		object item;
		mixed err;
		string type;
		if(!has_prefix(one,prefix))
			continue;
		err=catch{ item=clone(HONER+one); };
		if(err || !item){
			if(item)
				destruct(item);
			continue;
		}
		type=(string)item->query_item_type();
		destruct(item);
		if(slot=="weapon" &&
		   (type=="single_weapon" || type=="double_weapon"))
			matched+=({one});
		else if(slot=="armor" && type=="armor")
			matched+=({one});
		else if(slot=="decorate" && type=="jewelry")
			matched+=({one});
	}
	sort(matched);
	if(sizeof(matched))
		fixed_top_cache[cache_key]=matched;
	return matched;
}

string query_catalog_race(string player_race,string room_race)
{
	if(room_race!="human" && room_race!="monst")
		return "";
	if(player_race=="third" || player_race==room_race)
		return room_race;
	return "";
}

string query_honer_name(string race_id)
{
	if(race_id=="human")
		return "仙气";
	if(race_id=="monst")
		return "妖气";
	if(race_id=="third")
		return "灵气";
	return "荣誉值";
}

// 动态装备兑换价格：等级越高越贵，品质固定5阶。
private int query_dynamic_cost(int player_level)
{
	// 70级≈100万（与固定套装对齐），每高10级+50万
	return 1000000+(player_level-70)*50000;
}

private string query_dynamic_template(string catalog_race,string slot,
	int player_level)
{
	string prefix;
	if(catalog_race=="human")
		prefix=slot;
	else if(catalog_race=="monst")
		prefix=slot;
	else
		return "";
	if(search(({"weapon","armor","decorate"}),prefix)==-1)
		return "";
	return ITEMSD->query_equip_template_path(player_level,prefix);
}

int main(string|zero arg)
{
	object me=this_player();
	string out="";
	string slot=arg ? arg : "";
	object env;
	string catalog_race;
	object item;
	int need_honer;
	int player_level;
	int use_dynamic;
	string template_path;
	if(!me)
		return 1;
	env=environment(me);
	catalog_race=query_catalog_race((string)me->query_raceId(),
		env ? (string)env->room_race : "");
	if(catalog_race==""){
		write("这里没有适合你的荣誉兑换。\n[返回游戏:look]\n");
		return 1;
	}
	player_level=(int)me->query_level();
	use_dynamic=player_level>70;
	if(slot==""){
		out="【顶级荣誉装备】";
		if(use_dynamic){
			int cost=query_dynamic_cost(player_level);
			out+="按人物等级"+player_level+"动态生成一件5阶品质装备。\n";
			out+="价格："+cost+"（等级越高越贵）。\n";
		}
		else{
			out+="按部位随机发放一件70级"+
				(catalog_race=="human" ? "【仙】仙魄" : "【妖】妖魂")+
				"固定属性套装部件。\n";
			out+="价格与常规荣誉目录相同（以兑换时标示为准）。\n";
		}
		out+="[兑换武器:honer_buy_top weapon]|[兑换防具:honer_buy_top armor]|"+
			"[兑换饰品:honer_buy_top decorate]\n";
		out+="[返回游戏:look]\n";
		write(out);
		return 1;
	}
	if(search(({"weapon","armor","decorate"}),slot)==-1){
		write("装备类型无效。\n[返回:honer_buy_top]\n[返回游戏:look]\n");
		return 1;
	}
	if(me->in_combat){
		write("战斗中不能兑换荣誉装备。\n[返回游戏:look]\n");
		return 1;
	}
	if(use_dynamic){
		template_path=query_dynamic_template(catalog_race,slot,
			player_level);
		if(template_path==""){
			write("暂无可兑换的动态装备模板，请稍后再试。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		need_honer=query_dynamic_cost(player_level);
		if((int)me->honerpt<need_honer){
			write("你的"+query_honer_name((string)me->query_raceId())+
				"不足"+need_honer+"。\n[返回:honer_buy_top]\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		item=ITEMSD->get_convert_item(template_path,5,73,player_level);
		if(!item){
			write("装备生成失败，本次没有扣费。\n[返回游戏:look]\n");
			return 1;
		}
		if(functionp(item->set_item_from))
			item->set_item_from("honer");
	}
	else{
		array(string) candidates=query_fixed_top_paths(catalog_race,slot);
		if(!sizeof(candidates)){
			write("暂无可兑换的固定套装部件，请稍后再试。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		mixed load_err=catch{
			item=clone(HONER+candidates[random(sizeof(candidates))]);
		};
		if(load_err || !item || (string)item->query_item_from()!="honer" ||
		   (int)item->query_need_honer()<=0){
			if(item)
				destruct(item);
			write("装备生成失败，本次没有扣费。\n[返回游戏:look]\n");
			return 1;
		}
		need_honer=(int)item->query_need_honer();
		if((int)me->honerpt<need_honer){
			destruct(item);
			write("你的"+query_honer_name((string)me->query_raceId())+
				"不足"+need_honer+"。\n[返回:honer_buy_top]\n"+
				"[返回游戏:look]\n");
			return 1;
		}
	}
	item->move(me);
	if(!item || environment(item)!=me){
		if(item)
			destruct(item);
		write("背包空间不足，本次没有扣费。\n[返回游戏:look]\n");
		return 1;
	}
	me->honerpt-=need_honer;
	if(!me->save_with_result()){
		me->honerpt+=need_honer;
		destruct(item);
		me->save_with_result();
		write("存档失败，兑换已回滚。\n[返回游戏:look]\n");
		return 1;
	}
	write("兑换成功："+(string)item->query_name_cn()+
		"已放入你的背包。\n"+
		"[继续兑换:honer_buy_top]\n[返回游戏:look]\n");
	return 1;
}
