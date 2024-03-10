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
		//食物是复数物品，一次只能吃一个，饮料业一样
		if(ob->eat_flag==1){
			string obname = ob->query_name_cn();
			int tmp = ob->eat();
			//write("食用状态="+tmp+"\n");
			switch(tmp){
				case 0:
					s += "你的等级不够，不能食用 "+obname+" 。\n";	
				break;
				case 1:
					s += "你食用了 "+obname+" 。\n";	
				break;
				case 2:
					s += "你的职业不能食用该物品。\n";
				break;
				case 3:
					s += "你的阵营不能食用该物品。\n";
				break;
				case 4:
					s += "你要食用什么物品？\n";
				break;
				case 5:
					s += "你现在的状态不能食用该物品。\n";
				break;
				case 11://补血
					s += "你已经到达生命上限，不用食用该物品。\n";
				break;
				case 22://补蓝
					s += "你已经到达法力上限，不用食用该物品。\n";
				break;
			}
		}
		else if(ob&&ob->eat_flag==0){
			s += "该物品已经食用过了。\n";
		}
	}
	else{
		s += "没有物品可以食用。\n";
	}
	write(s);
	write("[返回:inventory]\n");
	write("[返回游戏:look]\n");
	return 1;
}
