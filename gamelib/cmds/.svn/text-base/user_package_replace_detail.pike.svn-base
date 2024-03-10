#include <command.h>
#include <gamelib/include/gamelib.h>
//背包替换，只能用小的替换大的
int main(string arg)
{
	object me = this_player();
	string s="";
	string tmp_s = "";
	string s_log = "";
	string type = "";//类型，背包或仓库
	int pac_size1 = 0;//替换前的背包大小
	int pac_size2 = 0;//替换后的背包大小
	int need_yushi = 0;//所需要的玉石
	int flag = 0;//购买标志，0：查看  1：确定购买  2:放弃购买
	sscanf(arg,"%s %d %d %d",type,pac_size1,pac_size2,need_yushi);
	if(type=="beibao") tmp_s += "背包";
	if(type=="cangku") tmp_s += "仓库";
	s += "请输入您要替换的"+tmp_s+"个数，每个"+tmp_s+"只能替换1个新的"+tmp_s+"，替换成功后会扣除此"+tmp_s+"的差价：\n";
	s += "[int no:...]\n";
	s += "[submit 确定:user_package_replace_confirm "+arg+" ...]";
	s += "[我只替换一个"+pac_size1+"格"+tmp_s+":user_package_replace_confirm "+arg+" no=1]\n";
	s += "[返回:user_package_buy_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
