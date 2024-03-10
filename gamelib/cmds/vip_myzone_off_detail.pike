#include <command.h>
#include <gamelib/include/gamelib.h>
//列出打折物品的具体信息

int main(string arg)
{
	object me = this_player();
	string goods_name = "";//物品文件名
	int lv = 0;//需要的会员等级
	int price = 0;//该等级下本物品的价格
	string s = "";
	sscanf(arg,"%s %d %d",goods_name,lv,price);
	array(string) tmp = ({});
	string type = "baoshi";                         //默认的物品类型
	tmp = goods_name/"/";                           //得到文件所在目录，也就是物品的分类
	if(tmp)                                  
	{
		type=tmp[0];
	}
	object goods;
	mixed err = catch{
		goods = (object)(ITEM_PATH + goods_name);
	};
	if(!err && goods){
		goods ->set_toVip(1);
		s += goods->query_name_cn()+"：\n";
		s += goods->query_picture_url()+"\n ";
		s += goods->query_desc()+"\n";
		s += "--------\n";
		s += VIPD->get_vip_name(lv)+"购买，享受"+ VIPD->get_vip_off(lv) +"折优惠,仅需"+YUSHID->get_yushi_for_desc(price)+"\n\n";
		s += "[确定购买:vip_myzone_off_confirm " + goods_name + " "+ lv +" "+ price +"]\n";
	}
	else
		s += "这东西好像已经卖光了，改天再来吧！\n";
	s += "[返回:vip_myzone_off_list "+ type +" "+ lv +"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
