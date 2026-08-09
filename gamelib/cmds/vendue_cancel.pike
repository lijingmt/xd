#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	int sale_id=0;
	if(!arg || sscanf(arg,"%d",sale_id)!=1 || sale_id<=0){
		write("取消拍卖参数无效。\n[返回:look]\n");
		return 1;
	}
	object me = this_player();
	object env=environment(me);
	string s = "";
	if(env){
		if(!AUCTIOND->reset_sale_info(me,sale_id,0,4))
			s += "没有找到此拍卖的记录\n";
		else
			s += "你取消了此拍卖\n";
	}
	s += "[返回:look]\n";
	write(s);
	return 1;
}
