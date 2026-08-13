#include <command.h>
#include <gamelib/include/gamelib.h>
//确认购买打折物品

#define VIP_OFF_BATCH_MAX 100

int parse_vip_off_purchase_count(string|zero value)
{
	int count=1;
	if(!value || value=="")
		return count;
	if(sscanf(value,"no=%d",count)!=1 && sscanf(value,"%d",count)!=1)
		return 0;
	return count;
}

int main(string|zero arg)
{
	object me = this_player();
	string goods_path= "";
	int lv = 0;
	int requested_price = 0;
	int buy_count = 1;
	string re = "";
	array(string) args = arg ? (arg/" ")-({""}) : ({});
	if(sizeof(args)>=4)
		buy_count=parse_vip_off_purchase_count(args[3]);
	if(sizeof(args)<3 || sizeof(args)>4 ||
	   sscanf(args[1],"%d",lv)!=1 ||
	   sscanf(args[2],"%d",requested_price)!=1 ||
	   (goods_path=args[0])=="" ||
	   !VIPD->is_off_good(goods_path,lv)){
		write("该物品不在会员折扣目录中。\n"+
			"[返回:vip_myzone]\n[返回游戏:look]\n");
		return 1;
	}
	int price=VIPD->query_off_good_price(goods_path,lv);
	if(price<0){
		write("会员商品价格异常，请联系管理员。\n"+
			"[返回:vip_myzone]\n[返回游戏:look]\n");
		return 1;
	}
	array(string) tmp = ({});
	string type = "baoshi";                        //默认的物品类型
	tmp = goods_path/"/";                          //得到文件所在目录，也就是物品的分类
	if(tmp)                                  
	{
		type=tmp[0];
	}
	object goods;
	mixed err=catch{
		goods=clone(ITEM_PATH+goods_path);
	};
	if(err || !goods){
		write("物品生成失败，请稍后再试。\n"+
			"[返回:vip_myzone]\n[返回游戏:look]\n");
		return 1;
	}
	string goods_name = goods->query_name();
	goods->set_toVip(1);	
	string goods_namecn = goods->query_name_cn();
	if(buy_count<1 || buy_count>VIP_OFF_BATCH_MAX ||
	   (buy_count>1 && !goods->is("combine_item"))){
		destruct(goods);
		write("购买数量必须在1到100之间，非叠加商品仍只能单件购买。\n"+
			"[返回:vip_myzone_off_detail "+goods_path+" "+lv+" "+
			price+"]\n[返回游戏:look]\n");
		return 1;
	}
	int result = VIPD->if_can_get_offly(me,goods,lv);//判断该玩家是否能获得该物品
	if(result ==4 && VIPD->query_off_good_remaining(me,goods,lv)>=buy_count)
	{
		int total_price=price*buy_count;
		int before_wallet=ACCOUNT_WALLETD->query_balance(me);
		int before_physical=YUSHID->query_physical_all_num(me);
		if(SHOP_BATCHD->query_capacity(me,goods,1)<buy_count)
			re += "你的包裹已经满了！\n";
		else if(!YUSHID->pay_yushi(me,total_price))
			re += "你身上的玉石不够！\n";
		else{
			destruct(goods);
			goods=0;
			mapping delivery=SHOP_BATCHD->deliver(me,goods_path,
				buy_count,1);
			int delivery_saved=(int)delivery["ok"] &&
				me->save_with_result();
			if(!delivery_saved){
				int inventory_rollback=(int)delivery["ok"] ?
					SHOP_BATCHD->rollback(me,delivery) :
					(int)delivery["rollback_ok"];
				int payment_rollback=YUSHID->rollback_yushi_payment(me,
					before_wallet,before_physical,
					"vip_off_delivery_failed");
				int rollback_saved=me->save_with_result();
				if(!inventory_rollback || !payment_rollback ||
				   !rollback_saved)
					re += "商品发放和退款异常，请立即联系管理员。\n";
				else
					re += "商品发放失败，费用已全部退回。\n";
			}
			else{
				string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+
					"["+GAME_NAME_S+"]["+me->query_name()+"][vip_off]["+
					goods_name+"]["+goods_namecn+"]["+buy_count+"]["+
					total_price+"][0]\n";
				mixed log_err=catch{
					Stdio.append_file(ROOT+"/log/stat/consume/"+
						GAME_NAME_S+"_consume_"+
						MUD_TIMESD->get_year_month_day()+".log",c_log);
				};
				if(log_err)
					werror("[VIP_AUDIT] append failed: %s\n",
							describe_error(log_err));
				re += "购买成功，你获得了"+goods_namecn+" × "+
					buy_count+"，共花费"+
					YUSHID->get_yushi_for_desc(total_price)+"。\n";
			}
		}
	}
	else
	{
		if(result==4)
			result=3;
		re += VIPD->if_can_get_offly_desc(result,lv,goods_namecn);
	}
	if(goods)
		destruct(goods);

	re += "[继续购买:vip_myzone_off_list "+ type +" "+ lv +"]\n";
	re += "[返回游戏:look]\n";
	write(re);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
