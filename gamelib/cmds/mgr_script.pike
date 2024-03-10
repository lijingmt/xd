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
		string stmp = "需要管理员权限才可以进入管理房间\n";
		stmp += "[返回游戏:look]\n";
		write(stmp);
		return 1;
	}
	s += "====在线更新脚本====\n";
	if(!arg || arg==""){
		s += "输入脚本全路径\n";
		s += "[string:mgr_script ...]\n";
		s += "[返回管理主界面:game_deal]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	mixed err=catch{
		me->command("wiz_update "+arg);
	};
	if(!err){
		s += arg+"\n更新成功，请返回\n";
	}
	else{
		s += arg+"\n更新失败，请返回\n";
	}
	s += "[返回:mgr_script]\n";
	s += "[返回管理主界面:game_deal]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}

