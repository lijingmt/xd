#include <command.h>
#include <gamelib/include/gamelib.h>
#ifndef ITEM_PATH
#define ITEM_PATH ROOT "/gamelib/clone/item/other/"
#endif
private mapping(string:array(int)) shenfu_catalog = ([
	"qianlichuanyinfu":({2,1}),
	"mianzhanfu":({1,5}),
]);
//实现玉石购买千里音符
//arg =   name       yushi_rareLevel    need_amount       buy_num
//     宝石文件名    所需玉石的稀有度   玉石的个数  购买的个数

int main(string|zero arg)
{
	object me = this_player();
	string bc_name = "";
	int rarelevel = 0;
	int need_amount = 0;
	int buy_num = 0;
	string s_buy_num = "";
	string s = "";
	string s_log = "";
	string c_log = "";//统计使用的日志 evan added 2008.07.10
	if(!arg || sscanf(arg,"%s %d %d %s",bc_name,rarelevel,
	   need_amount,s_buy_num)!=4 || sscanf(s_buy_num,"no=%d",buy_num)!=1 ||
	   !shenfu_catalog[bc_name]){
		write("商品参数无效，本次没有扣除或发放物品。\n"+
			"[返回:yushi_buy_shenfu_list]\n[返回游戏:look]\n");
		return 1;
	}
	array(int) product=shenfu_catalog[bc_name];
	rarelevel=product[0];
	need_amount=product[1];
	object bc;
	string need_yushi = YUSHID->get_yushi_name(rarelevel);
	int yushi_value = YUSHID->get_yushi_value(rarelevel);
	//按总价值换算玩家拥有的指定面额数量
	int have_num = 0;
	if(yushi_value > 0)
		have_num = YUSHID->query_all_num(me)/yushi_value;
	//计算到玩家能够购买此传音符的最大个数
	int can_num = 0;
	if(need_amount > 0)
		can_num = have_num/need_amount;
	/*
	if(need_money>0){
		need_money = need_money*100;
		int have_money = me->query_account();
		int m_can_num = have_money/need_money;
		can_num = min(can_num,m_can_num);
	}
	//end
	*/
	//必要的判断
	int res_num = BROADCASTD->query_num(bc_name);
	int batch_max=bc_name=="qianlichuanyinfu" ?
		SHOP_BATCHD->query_hard_max() : 3;
	if(buy_num<1 || buy_num>batch_max)
		s += "输入有误！购买个数必须在1到"+batch_max+"之间\n";
	else if(bc_name=="mianzhanfu" && me->query_raceId()!="monst")
		s += "只有妖魔才有权利购买免战符\n";
	else if(bc_name=="qianlichuanyinfu" && buy_num>res_num)
		s += "输入有误！千里传音符只剩下"+res_num+"张了，购买个数必须在1到"+res_num+"之间\n";
	else if(can_num<=0 || can_num<buy_num)
		s += "身上玉石不够，你无法购买指定数目的神符\n";
	else{
		mixed err;
		err=catch{
			bc = clone(ROOT+"/gamelib/clone/item/other/"+bc_name);
		};
		if(!err && bc){
			if(SHOP_BATCHD->query_capacity(me,bc,0)<buy_num){
				s += "你的随身物品已满，无法再装下更多\n";
				destruct(bc);
			}
			else{
				int stock_reserved=bc_name!="qianlichuanyinfu" ||
					BROADCASTD->reserve_bc_num(bc_name,buy_num);
				if(!stock_reserved){
					s += "千里传音符刚被其他玩家买走，请刷新余量后再试\n";
					destruct(bc);
					write(s+"[返回:yushi_buy_shenfu_list]\n"+
						"[返回游戏:look]\n");
					return 1;
				}
				int cost_reb = need_amount*buy_num*yushi_value;
				int before_wallet=ACCOUNT_WALLETD->query_balance(me);
				int before_physical=YUSHID->query_physical_all_num(me);
				if(!YUSHID->pay_yushi(me,cost_reb)){
					s += "玉石扣除失败，请稍后再试\n";
					if(bc_name=="qianlichuanyinfu")
						BROADCASTD->release_bc_num(bc_name,buy_num);
					destruct(bc);
				}
				else{
					string bc_namecn = bc->query_name_cn();
					destruct(bc);
					bc=0;
					mapping delivery=SHOP_BATCHD->deliver(me,
						"other/"+bc_name,buy_num,0);
					int delivery_saved=(int)delivery["ok"] &&
						me->save_with_result();
					if(!delivery_saved){
						int inventory_rollback=(int)delivery["ok"] ?
							SHOP_BATCHD->rollback(me,delivery) :
							(int)delivery["rollback_ok"];
						int payment_rollback=YUSHID->rollback_yushi_payment(
							me,before_wallet,before_physical,
							"shenfu_delivery_failed");
						int rollback_saved=me->save_with_result();
						int stock_rollback=bc_name!="qianlichuanyinfu" ||
							BROADCASTD->release_bc_num(bc_name,buy_num);
						if(!inventory_rollback || !payment_rollback ||
						   !rollback_saved || !stock_rollback)
							s += "神符发放和退款异常，请立即联系客服\n";
						else
							s += "神符发放失败，费用已退回\n";
						write(s+"[返回:yushi_buy_shenfu_list]\n"+
							"[返回游戏:look]\n");
						return 1;
					}
					s += "交易成功，你获得了"+bc_namecn+" × "+
						buy_num+"\n";
					string consume_time = MUD_TIMESD->get_mysql_timedesc();
					string cost = ""+(need_amount*buy_num)+"|"+need_yushi;
					//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','chaunyinfu','"+cost+"','"+bc_name+"',"+buy_num+",'"+bc_namecn+"',"+cost_reb+");\n";
					if(bc_name=="qianlichuanyinfu")
						c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][chuanyinfu]["+bc_name+"]["+bc_namecn+"]["+buy_num+"]["+cost_reb+"][0]\n";
					else
						c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][mianzhanfu]["+bc_name+"]["+bc_namecn+"]["+buy_num+"]["+cost_reb+"][0]\n";
				}
			}
		}
		else{
			s += "交易失败，无法得到千里传音符，请联系游戏版主，我们将尽快为你解决\n";
		}
		/*
		if(s_log != ""){
			string now=ctime(time());
			Stdio.append_file(ROOT+"/log/fee_log/yushi_use-"+MUD_TIMESD->get_year_month_day()+".log",s_log);
		}
		*/
		if(c_log != ""){                                                                           
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
		}
	}
	s += "[继续购买:yushi_buy_bc_detail "+bc_name+" "+rarelevel+" "+need_amount+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
