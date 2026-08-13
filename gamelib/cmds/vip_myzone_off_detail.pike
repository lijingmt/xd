#include <command.h>
#include <gamelib/include/gamelib.h>
//列出打折物品的具体信息

int main(string|zero arg)
{
	object me = this_player();
	string goods_name = "";//物品文件名
	int lv = 0;//需要的会员等级
	int requested_price = 0;//仅为兼容旧链接；实际价格由服务端目录计算
	string s = "";
	if(!arg || sscanf(arg,"%s %d %d",goods_name,lv,requested_price)!=3 ||
	   !VIPD->is_off_good(goods_name,lv)){
		write("该物品不在会员折扣目录中。\n"+
			"[返回:vip_myzone]\n[返回游戏:look]\n");
		return 1;
	}
	int price=VIPD->query_off_good_price(goods_name,lv);
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
		s += VIPD->get_vip_name(lv)+"购买，享受"+ VIPD->get_vip_off(lv) +"折优惠,单价仅需"+YUSHID->get_yushi_for_desc(price)+"\n\n";
		if(goods->is("combine_item")){
			int remaining = VIPD->query_off_good_remaining(me,goods,lv);
			int affordable = price>0 ? YUSHID->query_all_num(me)/price : 0;
			int capacity = SHOP_BATCHD->query_capacity(me,goods,1);
			int quick_max = min(remaining,affordable);
			quick_max = min(quick_max,capacity);
			quick_max = min(quick_max,SHOP_BATCHD->query_hard_max());
			s += "本次可购买1-100个；同类会员商品随身剩余额度："+
				remaining+"个。\n";
			if(quick_max>0){
				foreach(({1,5,10,20,50,100}),int quick)
					if(quick<=quick_max)
						s += "[买"+quick+"个:vip_myzone_off_confirm "+
							goods_name+" "+lv+" "+price+" "+quick+"] ";
				if(search(({1,5,10,20,50,100}),quick_max)==-1)
					s += "[按余额/背包买满"+quick_max+"个:"+
						"vip_myzone_off_confirm "+goods_name+" "+lv+" "+
						price+" "+quick_max+"]";
				s += "\n";
			}
			s += "自定义数量：[int no:...]\n";
			s += "[submit 确定购买:vip_myzone_off_confirm "+goods_name+
				" "+lv+" "+price+" ...]\n";
		}
		else
			s += "[确定购买:vip_myzone_off_confirm "+goods_name+" "+
				lv+" "+price+"]\n";
	}
	else
		s += "这东西好像已经卖光了，改天再来吧！\n";
	s += "[返回:vip_myzone_off_list "+ type +" "+ lv +"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
