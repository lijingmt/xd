#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	string item_id = arg || "";
	int page = 0;
	mapping result;
	if(arg && sscanf(arg,"%s %d",item_id,page)!=2){
		item_id = arg;
		page = 0;
	}
	if(page<0)
		page = 0;
	if(!item_id || sizeof(item_id)!=64){
		s += "物品参数已过期，请在刷新后的列表中重新选择。\n";
	}
	else{
		result = ACCOUNT_STORAGED->transfer_to_shared(me,item_id);
		s += (string)(result["message"] || "转移失败。")+"\n";
	}
	tell_object(me,s);
	me->command("account_storage put "+page);
	return 1;
}
