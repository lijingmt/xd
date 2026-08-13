#include <command.h>
#include <gamelib/include/gamelib.h>
//打碎具体玉石调用的指令
//arg =      yushi_name               rarelevel
//       打碎后得到的玉石文件名     得到的玉石的稀有度
int main(string|zero arg)
{
	string s = "";
	string yushi_name = "";
	int rarelevel = 0;
	sscanf(arg,"%s %d",yushi_name,rarelevel);
	object me = this_player();
	int can_num = YUSHID->query_degrade_num(me,rarelevel);
	int max_num = can_num>5 ? 5 : can_num;
	string yushi_namecn = YUSHID->get_yushi_namecn(rarelevel);
	string need_namecn = YUSHID->get_yushi_namecn(rarelevel+1);
	if(can_num>0){
		s += "每1块"+need_namecn+"可以打碎成10块"+yushi_namecn+"\n(目前你有"+can_num+"块"+need_namecn+")\n";
		s += "每打碎1块收取10金费用\n";
		s += "本次可输入1至"+max_num+"块：\n";
		s += "[int no:...]块\n";
		s += "[submit 确定:yushi_degrade_confirm "+yushi_name+" "+rarelevel+" ...]\n";
		s += "[快捷拆1块:yushi_degrade_confirm "+yushi_name+" "+
			rarelevel+" no=1]";
		if(max_num>1)
			s += "|[按本次上限拆"+max_num+"块:yushi_degrade_confirm "+
				yushi_name+" "+rarelevel+" no="+max_num+"]";
		s += "\n";
	}
	else
		s += "你已经没有"+need_namecn+"可供打碎!\n";
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
