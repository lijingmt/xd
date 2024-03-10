#include <command.h>
#include <gamelib/include/gamelib.h>

//购买狗调用指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	string name = "";
	int need_money = 0;
	string c_log = "";
	string id = me->query_name();
	if(!HOMED->if_have_home(id)){
		s += "您还没有家，没必要浪费钱买个看门狗,知道您钱多，但也没必要这么浪费嘛～\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	object door = HOMED->query_room_by_masterId(id,"door");
	object main = HOMED->query_room_by_masterId(id,"main");
	if(HOMED->is_have_dog(door)==1||HOMED->is_have_dog(main)==1){
		s += "汪～一家不容二狗，休想把我带走，您请回吧\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(HOMED->is_have_dog(door)==2||HOMED->is_have_dog(main)==2){
		s += "汪～我们狗狗真可怜，死后就没人理了，您不想使它复活至少也得安葬一下嘛，我不想跟你这样的主人\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	sscanf(arg,"%s %d",name,need_money);
	int result = BUYD->do_trade(me,need_money,0);
	switch(result){
		case 0:
			s += "你身上的玉石不够！\n";
			break;
		case 1:
			s += "你身上的金钱不够！\n";
			break;
		case 2..3:
			object dog = clone(NPC_PATH+name);
			HOMED->save_dog("1,"+name+","+dog->query_base_life()+",100,100,100,"+(string)(time()-3*3600),id);
			dog->set_feed_time(time()-3*3600);
			dog->move(main);
			int cost_reb = need_money;
			c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_dog][火云犬]["+ name +"][1]["+cost_reb+"][0]\n";
			s += "您要的火云犬已经送到你家了，回家看看吧\n";
			break;
		default:
			s += "系统犯晕了，请和管理员联系。\n";

	}
	if(c_log != "")                                                                           
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
