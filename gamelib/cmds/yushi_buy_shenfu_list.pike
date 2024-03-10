#include <command.h>
#include <gamelib/include/gamelib.h>

//购买神符入口调用指令

int main(string arg)
{
	object me = this_player();
	string s = "您想购买什么神符\n";
	mapping(string:int) time = localtime(time());
	int hour = time["hour"];
	/*
	if(hour>=18&&hour<=20)
		s += "[千里传音符超低价限时促销:yushi_buy_bc_detail qianlichuanyinfu 2 2](剩余"+BROADCASTD->query_num("qianlichuanyingfu")+"张)\n";
	else 
	*/
	s += "[千里传音符(国庆促销):yushi_buy_bc_detail qianlichuanyinfu 2 1](剩余"+BROADCASTD->query_num("qianlichuanyingfu")+"张)\n";
	s += "[免战符:yushi_buy_bc_detail mianzhanfu 1 5]\n";
	s += "\n";
	s += "[返回:yushi_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
