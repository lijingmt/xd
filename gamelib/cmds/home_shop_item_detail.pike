#include <command.h>
#include <gamelib/include/gamelib.h>
#define INFANCY_PATH ROOT "/gamelib/clone/item/home/infancy/"

//列出infancy的具体信息

int main(string|zero arg)
{
	object me = this_player();
	string infancyName = "";
	int yushi = 0;
	int money = 0;
	int flag = 0;
	string s = "";
	if(!arg || sscanf(arg,"%s %d %d %d",infancyName,yushi,money,flag)!=4 ||
	   flag<0 || flag>2){
		write("商品参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) offer=HOMED->query_infancy_offer(infancyName);
	if(!(int)offer["ok"]){
		write("该商品已经下架。\n[返回游戏:look]\n");
		return 1;
	}
	yushi=(int)offer["yushi"];
	money=(int)offer["money"];
	if((flag==1 && yushi<=0) || (flag==2 && money<=0)){
		write("该支付方式不可用。\n[返回游戏:look]\n");
		return 1;
	}
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
			if(yushi>0)
				s += "[玉石购买:home_shop_item_detail "+infancyName+" "+yushi+" 0 1](需要"+yushi_desc+")\n";
			if(money>0)
				s += "[黄金购买:home_shop_item_detail "+infancyName+" 0 "+money+" 2](需要"+money+"金)\n";
			s += "\n\n";
		}
		else {
			if(flag==1){
				money=0;
				s += "需要："+ yushi_desc +"\n";
			}
			else if(flag==2){
				yushi=0;
				s += "需要："+money+"金\n";
			}
			s += "需要家园等级:"+ infancy->query_homeLevel_limit()+"\n";
			if(HOMED->if_have_home(me->query_name()))
				s += "你当前家园等级是:"+ HOMED->get_home_level(me->query_name())+"\n";
			else
				s += "你现在并没有家园\n";
			s += "\n\n";
			int have_yushi=YUSHID->query_all_num(me);
			int affordable=yushi>0 ? have_yushi/yushi :
				(money>0 ? me->query_account()/(money*100) : 0);
			int capacity=SHOP_BATCHD->query_capacity(me,infancy,0);
			int quick_max=min(affordable,capacity);
			quick_max=min(quick_max,SHOP_BATCHD->query_hard_max());
			if(quick_max>0){
				foreach(({1,5,10,20,50,100}),int quick)
					if(quick<=quick_max)
						s += "[买"+quick+"个:home_shop_item_confirm "+
							infancyName+" "+yushi+" "+money+" "+quick+"] ";
				s += "\n";
			}
			s += "购买数量(1-100)：[int no:...]\n";
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
