#include <command.h>
#include <gamelib/include/gamelib.h>
#define FUNCTIONROOM_PATH ROOT "/gamelib/d/home/template/function/"
int main(string arg)
{
	object me = this_player();
	string s = "";
	int yushi = 0;
	int money = 0;
	string f_room_name = "";
	sscanf(arg,"%s %d %d",f_room_name,yushi,money);
	if(!HOMED->if_have_home(me->query_name()))
	{
		s += "�㻹û�еز��������װ�����������в�ͨ\n";
	}
	else
	{
		int rt = HOMED->sell_function_room(f_room_name,yushi,money);
		if(rt){
			s += "��õ���:\n";
			s += YUSHID->get_yushi_for_desc(yushi);
			if(money){
				s += "��"+money+"��\n";
			}
		}
		else{
			s += "����ʧ�ܡ�\n";
		}
	}
	s += "\n[����:home_functionroom_remind home_base]\n";
	s += "[������Ϸ:look]\n"; 
	write(s);
	return 1;
}
