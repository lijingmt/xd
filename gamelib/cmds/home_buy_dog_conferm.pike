#include <command.h>
#include <gamelib/include/gamelib.h>

//���򹷵���ָ��

int main(string arg)
{
	object me = this_player();
	string s = "";
	string name = "";
	int need_money = 0;
	string c_log = "";
	string id = me->query_name();
	if(!HOMED->if_have_home(id)){
		s += "����û�мң�û��Ҫ�˷�Ǯ������Ź�,֪����Ǯ�࣬��Ҳû��Ҫ��ô�˷��\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	object door = HOMED->query_room_by_masterId(id,"door");
	object main = HOMED->query_room_by_masterId(id,"main");
	if(HOMED->is_have_dog(door)==1||HOMED->is_have_dog(main)==1){
		s += "����һ�Ҳ��ݶ�����������Ҵ��ߣ�����ذ�\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(HOMED->is_have_dog(door)==2||HOMED->is_have_dog(main)==2){
		s += "�������ǹ���������������û�����ˣ�������ʹ����������Ҳ�ð���һ����Ҳ����������������\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	sscanf(arg,"%s %d",name,need_money);
	int result = BUYD->do_trade(me,need_money,0);
	switch(result){
		case 0:
			s += "�����ϵ���ʯ������\n";
			break;
		case 1:
			s += "�����ϵĽ�Ǯ������\n";
			break;
		case 2..3:
			object dog = clone(NPC_PATH+name);
			HOMED->save_dog("1,"+name+","+dog->query_base_life()+",100,100,100,"+(string)(time()-3*3600),id);
			dog->set_feed_time(time()-3*3600);
			dog->move(main);
			int cost_reb = need_money;
			c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_dog][����Ȯ]["+ name +"][1]["+cost_reb+"][0]\n";
			s += "��Ҫ�Ļ���Ȯ�Ѿ��͵�����ˣ��ؼҿ�����\n";
			break;
		default:
			s += "ϵͳ�����ˣ���͹���Ա��ϵ��\n";

	}
	if(c_log != "")                                                                           
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
