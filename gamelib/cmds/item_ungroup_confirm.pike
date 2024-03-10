#include <command.h>
#include <gamelib/include/gamelib.h>
//复数物品分组
int main(string arg)
{
	object me = this_player();
	string s = "";
	string num_s = "";
	string name = "";
	int count = 0;
	int num = 0;
	//[item_ungroup_confirm linglongyu 0  no=1]
	sscanf(arg,"%s %d %s",name,count,num_s);
	werror("----num_s=["+num_s+"]\n");
	sscanf(num_s,"no=%d",num);
	werror("----num=["+num+"]\n");
	object ob = present(name,me,count);
	if(ob){
		if(num>=1 && num<ob->amount){
			me->remove_combine_item(ob->query_name(),num);
			string file_path = file_name(ob);
			object ob_new = clone((file_path/"#")[0]);
			ob_new->amount = num;
			ob_new->move(me);
			s += "您已经成功将该物品分组\n";
		}
		else{
			s += "输入的数字不正确\n";
		}
	}
	else{
		s += "你包里没有这样的物品\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
