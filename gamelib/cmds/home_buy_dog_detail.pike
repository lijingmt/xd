#include <command.h>
#include <gamelib/include/gamelib.h>

//���򹷵���ָ��

int main(string arg)
{
	object me = this_player();
	string s = "";
	string name = "";
	int need_money = 0;
	string my_name = me->query_name();
	if(!HOMED->if_have_home(my_name)){
		s += "����û�мң�û��Ҫ�˷�Ǯ������Ź�,֪����Ǯ�࣬��Ҳû��Ҫ��ô�˷��\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	object room = HOMED->query_room_by_masterId(my_name,"main");
	if(HOMED->is_have_dog(room)==1){
		s += "����һ�Ҳ��ݶ�����������Ҵ��ߣ�����ذ�\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(HOMED->is_have_dog(room)==2){
		s += "�������ǹ���������������û�����ˣ�������ʹ����������Ҳ�ð���һ����Ҳ����������������\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	sscanf(arg,"%s %d",name,need_money);
	object dog = (object)(NPC_PATH+name);
	s += dog->query_name_cn()+"\n";
	s += dog->query_picture_url()+"\n";
	s += dog->query_desc()+"\n";
	s += "������"+dog->query_life_max()+"\n������"+dog->query_str()+"\n������"+dog->query_think()+"\n���ݣ�"+dog->query_dex()+"\n";
	s += "��Ҫ"+YUSHID->get_yushi_for_desc(need_money)+"\n";
	s += "\n\n[����:home_buy_dog_conferm "+name+" "+need_money+"]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
