#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string s = "§g账号共享宝库§r\n";
	mapping result;
	if(!arg || sizeof(arg)!=64){
		s += "物品转移参数无效，请刷新仓库后重试。\n";
	}
	else{
		result = ACCOUNT_STORAGED->transfer_to_personal(me,arg);
		s += (string)(result["message"] || "转移失败。")+"\n";
	}
	s += "[查看共享宝库:account_storage shared]\n";
	s += "[查看当前人物仓库:account_storage personal]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
