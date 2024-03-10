#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s="每次可购买藏宝箱扩充位置10格，花费100金。\n";
	if(!arg){
		if(me->packageLevel>90)
			s += "你已经达到藏宝箱的空间上限，无法再进行购买扩充了。\n";
		else{
			s += "你确定要花费100金将你的藏宝箱位置再扩充10格么？\n";		
			s += "[确定购买:user_package_buy yes]\n";
			s += "[我再考虑一下:user_package_buy no]\n";
		}
	}
	else{
		if(arg=="yes"){
			if(me->packageLevel>90)
				s += "你已经达到藏宝箱的空间上限，无法再进行购买扩充了。\n";
			else{
				if(me->pay_money(10000)==0)
					s += "你身上的钱不够支付费用，请返回。\n";
				else{
					s += "购买成功！\n你花费"+MUD_MONEYD->query_store_money_cn(10000)+"\n";
					s += "你的藏宝箱位置已经扩充10格。\n";		
					me->packageLevel = me->packageLevel+10;
					me->command("save");
				}
			}
		}
		else if(arg=="no"){
			s += "好，你想好了再来吧。\n";
		}
	}
	s += "[返回:look]\n";
	write(s);
	return 1;
}
