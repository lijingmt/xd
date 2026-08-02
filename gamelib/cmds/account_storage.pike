#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	mapping result = ACCOUNT_STORAGED->query_storage(me);
	string mode = arg || "shared";
	string s = "§g账号共享宝库§r\n";
	if(!result["ok"]){
		s += (string)(result["message"] || "共享宝库暂不可用。")+"\n";
		s += "[返回人物仓库:user_repackage]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	s += "同一注册账号下的人物可以主动转移物品；人物仓库保持独立。\n";
	s += "转移采用唯一物品编号和持久化中转事务，重复点击不会复制装备。\n\n";
	s += "[共享宝库:account_storage shared] ";
	s += "[当前人物仓库:account_storage personal]\n\n";
	if(mode=="personal"){
		array personal = result["personal_items"];
		s += "当前人物仓库（"+result["personal_used"]+"/"+
			result["personal_capacity"]+"）\n";
		if(!sizeof(personal))
			s += "当前人物仓库没有可转移物品。\n";
		for(int i=0;i<sizeof(personal);i++){
			if(!arrayp(personal[i]) || sizeof(personal[i])<8)
				continue;
			s += personal[i][2]+"\n";
			s += "[转入共享宝库:account_storage_deposit "+
				personal[i][7]+"]\n";
		}
	}
	else{
		array shared = result["items"];
		s += "共享宝库（"+result["used"]+"/"+
			result["capacity"]+"）\n";
		if(!sizeof(shared))
			s += "共享宝库当前没有物品。\n";
		for(int i=0;i<sizeof(shared);i++){
			mapping item = shared[i];
			array data = item["data"];
			if(!arrayp(data) || sizeof(data)<8)
				continue;
			s += data[2]+"\n";
			s += "[转入当前人物仓库:account_storage_withdraw "+
				item["id"]+"]\n";
		}
	}
	s += "\n[原人物仓库存入:user_package]\n";
	s += "[原人物仓库取出:user_repackage]\n";
	s += "[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
