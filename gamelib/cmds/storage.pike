#include <command.h>
#include <gamelib/include/gamelib.h>
// 统一仓库中心：一个入口同时呈现角色仓库与账号共享仓库的存量与
// 全部操作，两套体系不再需要回到武阁切换。

int main(string|zero arg)
{
	object me=this_player();
	string s="";
	int pac_size;
	int stored_count;
	mapping shared;
	if(!me)
		return 1;
	pac_size=me->query_cangku_size();
	stored_count=sizeof((array)(me->packaged_items || ({})));
	shared=ACCOUNT_STORAGED->query_storage(me);
	s="§g【仓库中心】§r\n\n";
	s+="角色仓库（仅当前人物）："+
		(string)me->state_packaged(pac_size)+"\n";
	s+="[存入物品:user_package]|[取出物品:user_repackage]|"+
		"[扩充容量:user_package_buy_list]\n\n";
	if((int)shared["ok"]){
		array items=arrayp(shared["items"]) ? (array)shared["items"] : ({});
		s+="账号共享仓库（全账号人物共用）：已存放"+
			sizeof(items)+"件\n";
	}
	else
		s+="账号共享仓库（全账号人物共用）："+
			(string)(shared["message"] || "暂不可用")+"\n";
	s+="[进入共享仓库:account_storage]\n\n";
	s+="[前往武阁:go_warehouse]|[返回游戏:look]\n";
	write(s);
	return 1;
}
