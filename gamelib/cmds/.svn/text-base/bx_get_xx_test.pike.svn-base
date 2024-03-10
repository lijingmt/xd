#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令获得霸王徽记，用于测试目的
int main(string arg)
{
	string s = "这里的东西只属于霸者\n";
	object me=this_player();
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
