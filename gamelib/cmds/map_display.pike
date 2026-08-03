#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	object env = environment(me);
	if(!arg){
		NEWBIED->record_action(me,"map");
		s += "您现在身处"+env->query_name_cn()+"\n";
		s += "\n";
		s += env->query_picture_url();
		s += MAPD->query_map(env);
		s += MAPD->get_all_kinds_map();
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	int fee;
	string block;
	string sub_map;
	sscanf(arg,"%s %d",block,fee);
	if(block=="jiuxiaojiejing" &&
	   me->query_level()<ENDGAME_MAP_MIN_LEVEL &&
	   !MANAGERD->is_cross_zone_admin(me->query_name())){
		s += "九霄界境需要达到"+ENDGAME_MAP_MIN_LEVEL+
			"级后才能展开地图，未扣除飞行费用。\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	sub_map = MAPD->get_sub_map_list(block);
	if(sub_map==""){
		s += "该区域是队伍独立幻境，不能从地图直接飞入，未扣除飞行费用。\n";
		s += "请与队员前往幻境入口进入。\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(me->pay_money(fee)==0){
		s += "你身上的钱不够支付飞行费用，请返回。\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	s += "你已经花费了此次飞行费用："+MUD_MONEYD->query_store_money_cn(fee)+"\n";
	s += sub_map;
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
