#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg){
	object me = this_player();
	string s = "";
	string powers = MANAGERD->checkpower(me->name);
	if(powers=="admin")
		;
	else
	{
		string stmp = "��Ҫ����ԱȨ�޲ſ��Խ��������\n";
		stmp += "[������Ϸ:look]\n";
		write(stmp);
		return 1;
	}
	s += "====���߸��½ű�====\n";
	if(!arg || arg==""){
		s += "����ű�ȫ·��\n";
		s += "[string:mgr_script ...]\n";
		s += "[���ع���������:game_deal]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	mixed err=catch{
		me->command("wiz_update "+arg);
	};
	if(!err){
		s += arg+"\n���³ɹ����뷵��\n";
	}
	else{
		s += arg+"\n����ʧ�ܣ��뷵��\n";
	}
	s += "[����:mgr_script]\n";
	s += "[���ع���������:game_deal]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}

