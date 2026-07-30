#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	string name = "";
	int requested_yushi = 0;
	if(!arg || sscanf(arg,"%s %d",name,requested_yushi) != 2 ||
	   !BUYD->can_buy_high_level_book(me,name)){
		s += "这本书不在你本职业今日可购买的目录中。\n";
		s += "[返回:yushi_buy_hlbook_list]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	int yushi = BUYD->query_high_level_book_price(name);
	s += BUYD->item_view(name,yushi,0);
	if(BUYD->query_book_num(name))
		s += "\n[确认购买:yushi_buy_hlbook_confirm "+name+" "+yushi+"]\n";
	else
		s += "\n此书已售罄\n";
	s += "[返回:yushi_buy_hlbook_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
