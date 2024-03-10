#include <command.h>
#include <gamelib/include/gamelib.h>
//列出玉石可购买药品的目录
int main(string arg)
{
	object me = this_player();
	string type = arg;
	string s = "你想购买些什么宝石：\n";
	//获得玩家身上个稀有度玉石的个数
	int have_1 = YUSHID->query_yushi_num(me,1);
	int have_2 = YUSHID->query_yushi_num(me,2);
	int have_3 = YUSHID->query_yushi_num(me,3);
	int have_4 = YUSHID->query_yushi_num(me,4);
	int have_5 = YUSHID->query_yushi_num(me,5);
	int have_money = me->query_account();
	have_money = have_money/100;
	if(type == "ronglian"){
		s += "熔炼|[炼化:yushi_buy_baoshi_list lianhua]\n";
		s += "--------\n";
		s += "[【橄榄石】:yushi_buy_baoshi_detail ganlanshi 2 1 ronglian 0 0](x"+(have_2/1)+")\n";
		s += "[【绿松石】:yushi_buy_baoshi_detail lvsongshi 2 3 ronglian 0 0](x"+(have_2/3)+")\n";
		s += "[【尖晶石】:yushi_buy_baoshi_detail jianjingshi 2 5 ronglian 0 0](x"+(have_2/5)+")\n";
		s += "[【青金石】:yushi_buy_baoshi_detail qingjinshi 2 10 ronglian 0 0](x"+(have_2/10)+")\n";
	}
	else if(type == "lianhua"){
		s += "[熔炼:yushi_buy_baoshi_list ronglian]|炼化\n";
		s += "--------\n";
		s += "[【冰蓝玉石】:yushi_buy_baoshi_detail binglanyushi 2 3 lianhua 0 0](x"+(have_2/3)+")\n";
		s += "[【紫晶玉石】:yushi_buy_baoshi_detail zijinyushi 2 5 lianhua 0 0](x"+(have_2/5)+")\n";
		s += "[【琥珀石】:yushi_buy_baoshi_detail huposhi 2 1 lianhua 0 0](x"+(have_2/1)+")\n";
		s += "[【翠晶石】:yushi_buy_baoshi_detail cuijinshi 2 3 lianhua 0 0](x"+(have_2/3)+")\n";
	}else
	{
		s +="我这里的货太抢手，压箱底的都卖光了，改天再来吧！\n";
	}
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
