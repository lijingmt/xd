#include <command.h>
#include <gamelib/include/gamelib.h>
//阵营转换调用指令
int main(string arg)
{
	object me = this_player();
	string s = "";
	string tmp_s = "";
	//仙转魔
	if(me->query_raceId()=="human"){
		tmp_s = "小于负50(不包括负50)";
	}
	//魔转仙
	else if(me->query_raceId()=="monst"){
		tmp_s = "大于50(不包括50)";
	}
	s += "必须满足以下两个条件才能转换阵营\n";
	s += "1、轮回值必须"+tmp_s+"\n";
	s += "2、需要1个轮回符印\n";
	s += "\n";
	s += "转换阵营后, 您的所有社会关系(好友, 帮派等)将全部消失.\n";
	s += "\n";
	s += "确定转换阵营吗？\n";
	s += "[确定:race_change_confirm]\n";
	s += "[再考虑考虑:look]\n";
	s += "\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
