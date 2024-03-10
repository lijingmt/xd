#include <command.h>
#include <gamelib/include/gamelib.h>
//会员折扣商品目录
int main(string arg)
{
	object me = this_player();
	string item_name = "";
	string item_type = "";
	int item_cost = 0;
	sscanf(arg,"%s %s %d",item_name,item_type,item_cost);

	string s = "*** 会员优惠 ***\n";
	mapping(int:int) vip_off_list = VIPD->get_vip_off_map();
	mapping(int:string) vip_list = VIPD->get_vip_name_map();
	for(int i=1;i<=sizeof(vip_off_list);i++)
	{
		s += vip_list[i]+ "("+ vip_off_list[i]+"折)\n";
	}
	int vip_level = me->query_vip_flag();
	string vip_name = vip_list[vip_level];
	item_cost = item_cost* vip_off_list[vip_level]/10;
	if(vip_level)
	{
		s += "尊敬的"+ me->query_name_cn()+",你现在是"+vip_name+",你执行本操作只需花费"+ YUSHID->get_yushi_for_desc(item_cost)+"\n";
		s += "[确认:convert_equip_confirm " + item_name+" "+item_type+" "+ item_cost+ " 2 1]\n";
		s += "[返回:convert_equip_detail " + item_name +" 0]\n";	
	}
	else
	{
		s +="你还不是我们的会员，赶快加入到会员的大家庭中，享受尊贵的会员特权吧\n\n";                               
		s += "[申请入会:vip_service_app_list]\n";
		s += "[返回:convert_equip_detail " + item_name +" 0]\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
