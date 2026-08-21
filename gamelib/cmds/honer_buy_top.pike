#include <command.h>
#include <gamelib/include/gamelib.h>
// 顶级荣誉装备：消耗大量仙气/妖气/灵气，按人物等级兑换一件定制品质
// 的动态装备（品质固定低于玉石赌装最高档）。扣费、生成与存档同事务。

#define HONER_TOP_COST 3000
#define HONER_TOP_QUALITY 5

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

int main(string|zero arg)
{
	object me=this_player();
	string out="";
	string slot=arg ? arg : "";
	object env;
	string catalog_race;
	string template_path;
	object item;
	int item_level;
	if(!me)
		return 1;
	env=environment(me);
	catalog_race=query_catalog_race((string)me->query_raceId(),
		env ? (string)env->room_race : "");
	if(catalog_race==""){
		write("这里没有适合你的荣誉兑换。\n[返回游戏:look]\n");
		return 1;
	}
	if(slot==""){
		out="【顶级荣誉装备】按人物等级定制一件"+
			HONER_TOP_QUALITY+"阶品质装备（低于玉石赌装最高档）。\n";
		out+="每种需要"+query_honer_name((string)me->query_raceId())+
			"："+HONER_TOP_COST+"。\n";
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
	if((int)me->honerpt<HONER_TOP_COST){
		write("你的"+query_honer_name((string)me->query_raceId())+
			"不足"+HONER_TOP_COST+"。\n[返回:honer_buy_top]\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	item_level=min((int)me->query_level(),120);
	template_path=ITEMSD->query_equip_template_path(item_level,slot);
	if(template_path==""){
		write("暂无可兑换的装备模板，请稍后再试。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	item=ITEMSD->get_convert_item(template_path,HONER_TOP_QUALITY,73,
		item_level);
	if(!item){
		write("装备生成失败，本次没有扣除"+query_honer_name(
			(string)me->query_raceId())+"。\n[返回游戏:look]\n");
		return 1;
	}
	if(functionp(item->set_item_from))
		item->set_item_from("honer");
	item->move(me);
	if(!item || environment(item)!=me){
		if(item)
			destruct(item);
		write("背包空间不足，本次没有扣除荣誉。\n[返回游戏:look]\n");
		return 1;
	}
	me->honerpt-=HONER_TOP_COST;
	if(!me->save_with_result()){
		me->honerpt+=HONER_TOP_COST;
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
