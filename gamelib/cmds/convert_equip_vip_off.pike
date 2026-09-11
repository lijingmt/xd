#include <command.h>
#include <gamelib/include/gamelib.h>
//会员折扣商品目录
int main(string|zero arg)
{
	object me = this_player();
	string item_name = "";
	string item_type = "";
	int item_cost = 0;
	int forward_flag = 2;//可选批量增加：6/7/8 = ×3/×5/×10
	if(!arg || sscanf(arg,"%s %s %d %d",item_name,item_type,item_cost,
		forward_flag)<3 || (forward_flag!=2 && forward_flag<6) ||
		forward_flag>8){
		write("炼化参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	object item;
	foreach(all_inventory(me),object candidate)
		if(candidate && candidate->query_name()==item_name &&
		   ITEMSD->can_equip(candidate)){
			item=candidate;
			break;
		}
	if(!item || (string)item->query_item_type()!=item_type){
		write("你身上没有这件装备。\n[返回游戏:look]\n");
		return 1;
	}
	item_cost=ITEMSD->query_convert_equip_yushi_cost(item);

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
		s += "尊敬的"+ me->query_name_cn()+",你现在是"+vip_name+
			(forward_flag>=6 ? "，批量增加每次" : "，你执行本操作")+
			"只需花费"+ YUSHID->get_yushi_for_desc(item_cost)+
			(forward_flag>=6 ? "（按实际尝试次数结算）" : "")+"\n";
		s += "[确认:convert_equip_confirm " + item_name+" "+item_type+" "+ item_cost+ " "+forward_flag+" 1]\n";
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
