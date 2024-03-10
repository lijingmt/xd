#include <command.h>
#include <gamelib/include/gamelib.h>
#define INFANCY_PATH ROOT "/gamelib/clone/item/home/infancy/"

//列出infancy的具体信息

int main(string arg)
{
	object me = this_player();
	string infancyName = "";
	int yushi = 0;
	int money = 0;
	int flag = 0;
	string s = "";
	sscanf(arg,"%s %d %d %d",infancyName,yushi,money,flag);
	object infancy;
	mixed err = catch{
		infancy = (object)(INFANCY_PATH + infancyName);
	};
	if(!err && infancy){
		s += infancy->query_name_cn()+"：\n";
		s += infancy->query_picture_url()+"\n" + infancy->query_desc()+"\n";
		s += infancy->query_harvest_desc() +"\n";
		string yushi_desc = YUSHID->get_yushi_for_desc(yushi);
		s += "--------\n";
		//s += "需要："+ yushi_desc +" 和 "+ money +"金\n";
		if(flag==0){
			s += "[玉石购买:home_shop_item_detail "+infancyName+" "+yushi+" 0 1](需要"+yushi_desc+")\n";
			s += "[黄金购买:home_shop_item_detail "+infancyName+" 0 "+money+" 2](需要"+money+"金)\n";
			s += "\n\n";
		}
		else {
			if(flag==1)
				s += "需要："+ yushi_desc +"\n";
			else if(flag==2)
				s += "需要："+money+"金\n";
			s += "需要家园等级:"+ infancy->query_homeLevel_limit()+"\n";
			if(HOMED->if_have_home(me->query_name()))
				s += "你当前家园等级是:"+ HOMED->get_home_level(me->query_name())+"\n";
			else
				s += "你现在并没有家园\n";
			s += "\n\n";
			s += "[int no:...]\n";
			s += "[submit 确定购买:home_shop_item_confirm "+ infancyName+" "+ yushi +" "+money+" ...]\n";
		}
	}
	else
		s += "这东西好像已经卖光了，改天再来吧！\n";
	s += "[返回:home_shop_item_list plant]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
