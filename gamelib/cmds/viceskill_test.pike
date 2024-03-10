#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name flag
int main(string arg)
{
	string s = "";
	object me=this_player();
	object ob;
	ob = clone(ITEM_PATH_KUANG+"tongkuangshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"xinkuangshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"tiekuangshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"yinkuangshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"jinkuangshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"bojin");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"taijin");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"wujin");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"fantie");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"yuntie");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"jianjing");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"xuantieshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"bingshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"huoshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"fengshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"xuanhuangshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"maoyanshi");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"xiehupo");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"yufeicui");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"jinggangzuan");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	ob = clone(ITEM_PATH_KUANG+"zishuijing");
	if(ob){
		ob->amount = 20;
		ob->move_player(me->query_name());
	}
	me->command("look");
	return 1;
}
