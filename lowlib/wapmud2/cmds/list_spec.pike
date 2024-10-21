#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	s +="[1碎玉刷新:list_spec 1 1][1万金币刷新:list_spec 2 1000000]\n";
	int count = 0;
	int rarelevel = 1;//碎玉是1，越大越好
	int need_amount = 1;//需要碎玉
	object me = this_player();
	if(arg){
		sscanf(arg,"%d %d",count, need_amount);
		if(count == 2){
			int fee = need_amount;
			if(me->pay_money(fee)==0){
				s+="您的金币不够"+MUD_MONEYD->query_store_money_cn(fee)+"，请返回。\n";
			}else{
				//s +=MUD_MONEYD->query_store_money_cn(fee)+"付款成功\n";
				s += environment(this_player())->view_goods_spec_list();
			}
		}else if(count == 1){
			string need_yushi = YUSHID->get_yushi_name(rarelevel);
			string need_yushicn = YUSHID->get_yushi_namecn(rarelevel);
			//获得玩家身上此种玉石的个数
			int have_num = YUSHID->query_yushi_num(me,rarelevel);
				//计算到玩家能够购买此传音符的最大个数
			int can_num = have_num/need_amount;
			//每购买一个，就扣除一个所消耗的玉石数
			if(can_num){
				me->remove_combine_item(need_yushi,need_amount);
				//s += "交易成功，随机神秘商店货架已满\n";
				s += environment(this_player())->view_goods_spec_list();
			}else{
				s +="您的"+need_yushicn+"不够购买，刷新失败， 请联系客服捐赠获取\n";
			}
		}
		
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);

	return 1;
	
}
