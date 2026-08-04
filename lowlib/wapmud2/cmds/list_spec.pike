#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	s +="[10碎玉刷新（装备和技能）:list_spec 1][30碎玉刷新（仅技能）:list_spec 2]\n每次刷新只能购买一件物品；技能货架只能使用玉石刷新。\n";
	int type = 0;
	int rarelevel = 1;//碎玉是1，越大越好
	int need_amount = 0;//需要碎玉，费用只由服务端类型决定
	object me = this_player();
	if(arg){
		sscanf(arg,"%d",type);
		if(type == 1 || type == 2){//混合货架10碎玉；技能货架30碎玉
			need_amount = type==2 ? 30 : 10;
			string need_yushicn = YUSHID->get_yushi_namecn(rarelevel);
			//购买时按玉石总价值自动兑换
			if(YUSHID->pay_yushi(me,need_amount)){
				//s += "交易成功，随机神秘商店货架已满\n";
				s += environment(this_player())->view_goods_spec_list(
					type==1 ? 1 : 0);
			}else{
				s +="您的"+need_yushicn+"总价值不足"+need_amount+
					"，刷新失败。\n";
			}
		}
		else
			s += "刷新类型无效，未扣除金币或玉石。\n";
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);

	return 1;
	
}
