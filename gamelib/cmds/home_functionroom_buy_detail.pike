#include <command.h>
#include <gamelib/include/gamelib.h>
#define FUNCTIONROOM_PATH ROOT "/gamelib/d/home/template/function/"
int main(string arg)
{
	object me = this_player();
	string roomName = arg;
	int yushi = 0;
	int money = 0;
	string s = "";
	//sscanf(arg,"%s %d %d",roomName,yushi,money);
	object room;
	/*
	if(HOMED->if_can_buy_functionroom(me->query_name())){
		s += "您所拥有的功能房间数量已达到上限，不能再添加别的功能房间\n";
		s += "\n[返回:popview]\n";
		write(s);
		return 1;
	}
	*/
	mixed err = catch{
		room = (object)(FUNCTIONROOM_PATH + roomName);
	};
	if(!err && room){
		yushi = room->query_priceYushi();
		money = room->query_priceMoney();
		s += room->query_name_cn()+"\n";
		s += room->query_picture_url()+"\n";
		s += room->query_desc();
		string yushi_desc = YUSHID->get_yushi_for_desc(yushi);
		s += "--------\n";
		s += "需要："+ yushi_desc;
		if(money)
		s += "和" + money +"金";
		s += "\n需要家园等级:"+room->query_level_limit()+"级\n";

		s += "\n\n\n";
		s += "[确定添加:home_functionroom_buy_confirm "+ roomName+" "+ yushi +" "+money+"]\n";
	}
	else
		s += "该房间还没有修建完成，改天再来吧！\n";
	s += "[返回:home_functionroom_buy_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
