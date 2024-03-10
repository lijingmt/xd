#include <command.h>
#include <gamelib/include/gamelib.h>

//仙道会员店入口

int main(string arg){
	object me = this_player();
	string s = "仙道会员店\n\n";
	s += "[会员服务:vip_service_list]\n";
	s += "[会员欢购场:vip_myzone]\n";
	s += "\n";
	s += "[返回仙玉妙坊:yushi_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
