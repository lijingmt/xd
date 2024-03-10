#include <command.h>
#include <gamelib/include/gamelib.h>
//复数物品分组
int main(string arg)
{
	object me = this_player();
	string s = "";
	string name = "";
	int count = 0;
	sscanf(arg,"%s %d",name,count);
	object ob = present(name,me,count);
	if(ob){
		if(ob->amount>1){
			s += "该组物品的数量为"+ob->amount+"\n";
			s += "请输入您要取出的数量\n";
			s += "输入的数字只能为1～"+ob->amount+"之间的整数\n";
			s += "[int no:...]\n";
			s += "[submit 确定:item_ungroup_confirm "+name+" "+count+" ...]\n";
			s += "[放弃:look]\n";
		}
		else{
			s += "你只有"+ob->query_short()+",不能再分了\n";
		}
	}
	else{
		s += "你包里没有这样的物品\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
