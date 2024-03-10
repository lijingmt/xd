#include <command.h>
#include <gamelib/include/gamelib.h>
//合成具体玉石调用的指令
//arg = yushi_name rarelevel
int main(string arg)
{
	string s = "";
	string yushi_name = "";
	int rarelevel = 0;
	sscanf(arg,"%s %d",yushi_name,rarelevel);
	object me = this_player();
	int can_num = YUSHID->query_update_num(me,rarelevel);
	string yushi_namecn = YUSHID->get_yushi_namecn(rarelevel);
	string need_namecn = YUSHID->get_yushi_namecn(rarelevel-1);
	if(can_num>0){
		s += "每10块"+need_namecn+"合成1块"+yushi_namecn+"\n（目前你最多能合成"+can_num+"块）\n";
		s += "每合成1块收取10金费用\n";
		s += "输入你想合成的块数：\n";
		s += "[int no:...]块\n";
		s += "[submit 确定:yushi_update_confirm "+yushi_name+" "+rarelevel+" ...]\n";
	}
	else
		s += "材料不够，你无法再合成"+yushi_namecn+"\n";
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
