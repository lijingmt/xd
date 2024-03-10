#include <command.h>
#include <gamelib/include/gamelib.h>
//列出玉石可购买药品的目录
int main(string arg)
{
	object me = this_player();
	string type = arg;
	string s = "你想购买些什么药品：\n";
	//获得玩家身上个稀有度玉石的个数
	int have_1 = YUSHID->query_yushi_num(me,1);
	int have_2 = YUSHID->query_yushi_num(me,2);
	int have_3 = YUSHID->query_yushi_num(me,3);
	int have_4 = YUSHID->query_yushi_num(me,4);
	int have_5 = YUSHID->query_yushi_num(me,5);
	int have_money = me->query_account();
	have_money = have_money/100;
	if(type == "exp"){
		s += "仙丹|[仙酒:yushi_buy_teyao_list honer]|[仙露:yushi_buy_teyao_list luck]|[仙散:yushi_buy_teyao_list san]\n";
		s += "--------\n";
		s += "[【特】分神丹:yushi_buy_teyao_detail fenshendan 1 1 exp 0 0](x"+(have_1/1)+")\n";
		s += "[【特】化神丹:yushi_buy_teyao_detail huashendan 1 5 exp 0 0](x"+(have_1/5)+")\n";
		s += "[【特】幻神丹:yushi_buy_teyao_detail huanshendan 2 1 exp 0 0](x"+(have_2/1)+")\n";
		//主要是给30级以下的玩家使用,每天每种只能购买一颗。药品不可交易赠送 由caijie添加于2008/06/10
		s += "--------\n";
		s += "以下特药只供30级以下的玩家购买\n";
		s += "[ 莹芷丸:yushi_buy_teyao_detail yingzhiwan 1 5 exp 5 1](x"+min(have_1/5,have_money/5)+")\n";
		s += "[ 凝力丸:yushi_buy_teyao_detail ningliwan 1 5 exp 5 1](x"+min(have_1/5,have_money/5)+")\n";
		s += "[ 灵土丸:yushi_buy_teyao_detail lingtuwan 1 5 exp 5 1](x"+min(have_1/5,have_money/5)+")\n";
		s += "[ 固气丹:yushi_buy_teyao_detail guqidan 1 5 exp 5 1](x"+min(have_1/5,have_money/5)+")\n";
		//s += "[ 衡醒丸:yushi_buy_teyao_detail hengxingwan 2 2 exp 20 1](x"+min(have_1/5,have_money/5)+")\n";
		//end
	}
	else if(type == "honer"){
		s += "[仙丹:yushi_buy_teyao_list exp]|仙酒|[仙露:yushi_buy_teyao_list luck]|[仙散:yushi_buy_teyao_list san]\n";
		s += "--------\n";
		s += "[【特】怒火酒:yushi_buy_teyao_detail nuhuojiu 1 2 honer 0 0](x"+(have_1/2)+")\n";
		s += "[【特】烈焰酒:yushi_buy_teyao_detail lieyanjiu 2 1 honer 0 0](x"+(have_2/1)+")\n";
		s += "[【特】天火酒:yushi_buy_teyao_detail tianhuojiu 2 2 honer 0 0](x"+(have_2/2)+")\n";
	}
	else if(type == "luck"){
		s += "[仙丹:yushi_buy_teyao_list exp]|[仙酒:yushi_buy_teyao_list honer]|仙露|[仙散:yushi_buy_teyao_list san]\n";
		s += "--------\n";
		s += "[【特】留香露:yushi_buy_teyao_detail liuxianglu 1 2 luck 0 0](x"+(have_1/2)+")\n";
		s += "[【特】仙女露:yushi_buy_teyao_detail xiannvlu 2 1 luck 0 0](x"+(have_2/1)+")\n";
		s += "[【特】神女露:yushi_buy_teyao_detail shennvlu 2 2 luck 0 0](x"+(have_2/2)+")\n";
		s += "[金玉露:yushi_buy_teyao_detail jinyulu 2 7 luck 0 0](x"+(have_2/7)+")\n";
		//s += "[芬芳露:yushi_buy_teyao_detail fenfanglu 2 7 luck 0 0](x"+(have_2/7)+")\n";
		s += "[火宁露:yushi_buy_teyao_detail huoninglu 1 8 luck 0 0](x"+(have_1/8)+")\n";
		s += "[风息露:yushi_buy_teyao_detail fengxilu 1 8 luck 0 0](x"+(have_1/8)+")\n";
		//主要是给30级以下的玩家使用,每天每种只能购买一颗。药品不可交易赠送 由caijie添加于2008/06/10
		//s += "--------\n";
		//s += "以下特药只供30级以下的玩家购买\n";
		//s += "[归虚露:yushi_buy_teyao_detail guixulu 2 1 luck 10 1](x"+min(have_2/1,have_money/10)+")\n";
		//s += "[草宁汁:yushi_buy_teyao_detail caoningzhi 1 15 luck 15 1](x"+min(have_1/15,have_money/15)+")\n";
		//s += "[沁心露:yushi_buy_teyao_detail qinxinlu 2 3 luck 30 1](x"+min(have_2/3,have_money/30)+")\n";
		//end
	}
	else if(type == "san"){
		s += "[仙丹:yushi_buy_teyao_list exp]|[仙酒:yushi_buy_teyao_list honer]|[仙露:yushi_buy_teyao_list luck]|仙散\n";
		s += "--------\n";
		s += "[冰融散:yushi_buy_teyao_detail bingrongsan 1 8 san 0 0](x"+(have_1/8)+")\n";
		s += "[毒消散:yushi_buy_teyao_detail duxiaosan 1 8 san 0 0](x"+(have_1/8)+")\n";
		s += "[五味散:yushi_buy_teyao_detail wuweisan 2 4 san 0 0](x"+(have_2/4)+")\n";
	}
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
