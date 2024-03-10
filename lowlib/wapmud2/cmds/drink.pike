#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	string s = "";
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,this_player(),count);
	if(ob){
		if(ob->eat_flag==1){
			string obname = ob->query_name_cn();
			int tmp = ob->drink();
			switch(tmp){
				case 0:
					s += "你的等级不够，不能饮用 "+obname+" 。\n";	
				break;
				case 1:
					s += "你饮用了 "+obname+" 。\n";	
				break;
				case 2:
					s += "你的职业不能饮用该物品。\n";
				break;
				case 3:
					s += "你的阵营不能饮用该物品。\n";
				break;
				case 4:
					s += "你要饮用什么物品？\n";
				break;
				case 5:
					s += "你现在的状态不能饮用该物品。\n";
				break;
				case 11:
					s += "你已经到达生命上限，不用饮用该物品。\n";
				break;
				case 22:
					s += "你已经到达法力上限，不用饮用该物品。\n";
				break;
			}
		}
		else if(ob&&ob->eat_flag==0){
			s += "该物品已经饮用过了。\n";
		}
	}
	else{
		s += "没有物品可以饮用。\n";
	}
	write(s);
	write("[返回:inventory]\n");
	write("[返回游戏:look]\n");
	return 1;
}
