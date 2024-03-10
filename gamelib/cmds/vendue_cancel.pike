#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int sale_id=0;
	sscanf(arg,"%d",sale_id);
	object me = this_player();
	object env=environment(me);
	string s = "";
	if(env){
		if(!AUCTIOND->reset_sale_info(this_player(),sale_id,0,4))
			s += "没有找到此拍卖的纪录\n";
		else
			s += "你取消了此拍卖\n";
	}
	s += "[返回:look]\n";
	write(s);
	return 1;
}
