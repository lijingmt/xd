#include <command.h>
#include <gamelib/include/gamelib.h>
//查看玩家家园的基本信息
int main(string arg)
{
	string s = "";
	object me = this_player();
	object room = HOMED->query_home_by_path(arg);
	if(room){
		s += "【家园名称】 "+room->query_customName()+"\n";
		s += "【主人寄语】 "+room->query_customDesc()+"\n";
		s += "【家园等级】 "+room->query_homeLv()+"\n";
		s += "【所在位置】 "+HOMED->query_home_pos(room->query_masterId())+"\n";
		s += "\n[返回:look]\n";
	}
	else{
		s += "他家的地契有些问题，房屋已经暂时被官府查封了！\n";
		s += "\n[确定:look]\n";
	}
	write(s);
	return 1;
}
