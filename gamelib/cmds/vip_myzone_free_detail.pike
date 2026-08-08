#include <command.h>
#include <gamelib/include/gamelib.h>
//列出领取宝石的具体信息

int main(string|zero arg)
{
	object me = this_player();
	string goods_name = "";
	int lv = 0;
	string s = "";
	if(!arg || sscanf(arg,"%s %d",goods_name,lv)!=2 ||
	   !VIPD->is_free_good(goods_name,lv)){
		write("该物品不在会员免费目录中。\n"+
			"[返回:vip_myzone]\n[返回游戏:look]\n");
		return 1;
	}
	array(string) tmp = ({});
	string type = "baoshi";                        //默认的物品类型
	tmp = goods_name/"/";                          //得到文件所在目录，也就是物品的分类
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
		s += "需要："+VIPD->get_vip_name(lv)+"\n";
		s += "[确定领取:vip_myzone_free_confirm " + goods_name + " "+ lv +"]\n";
	}
	else
		s += "这东西好像已经被领光了，改天再来吧！\n";
	s += "[返回:vip_myzone_free_list "+ type+" "+ lv +"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
