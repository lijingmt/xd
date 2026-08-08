#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令获得霸王徽记，用于测试目的
int main(string|zero arg)
{
	string s = "这里的东西只属于霸者\n";
	object me=this_player();
	if(!me || MANAGERD->checkpower(me->query_name())!="admin"){
		write("该调试命令仅限管理员使用。\n[返回游戏:look]\n");
		return 1;
	}
	object item;
	mixed err = catch{
		item = clone(ITEM_PATH+"chr_xx");
	};
	if(!err && item){
		item->amount = 20;
		tell_object(me,"你获得了"+item->query_short()+"!\n");
		item->move_player(me->query_name());
	}
	me->command("look");
	return 1;
}
