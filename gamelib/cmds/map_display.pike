#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	object me=this_player();
	object env = environment(me);
	if(!arg){
		s += "��������"+env->query_name_cn()+"\n";
		s += "\n";
		s += env->query_picture_url();
		s += MAPD->query_map(env);
		s += MAPD->get_all_kinds_map();
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	int fee;
	string block;
	sscanf(arg,"%s %d",block,fee);
	if(me->pay_money(fee)==0){
		s += "�����ϵ�Ǯ����֧�����з��ã��뷵�ء�\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	s += "���Ѿ������˴˴η��з��ã�"+MUD_MONEYD->query_store_money_cn(fee)+"\n";
	s +=MAPD->get_sub_map_list(block);
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
