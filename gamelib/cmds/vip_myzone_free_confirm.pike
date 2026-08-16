#include <command.h>
#include <gamelib/include/gamelib.h>
//确认领取某种宝石

#define VIP_FREE_BATCH_MAX 100

int parse_vip_free_count(string|zero value)
{
	int count;
	if(!value || value=="")
		return 0;
	if(sscanf(value,"no=%d",count)!=1 && sscanf(value,"%d",count)!=1)
		return -1;
	return count;
}

int main(string|zero arg)
{
	object me = this_player();
	string goods_path= "";
	int lv = 0;
	int requested_count = 0;
	int receive_count = 1;
	int count_supplied = 0;
	string re = "";
	array(string) args=arg ? (arg/" ")-({""}) : ({});
	if(sizeof(args)>=3){
		count_supplied=1;
		requested_count=parse_vip_free_count(args[2]);
	}
	if(sizeof(args)<2 || sizeof(args)>3 ||
	   sscanf(args[1],"%d",lv)!=1 || (goods_path=args[0])=="" ||
	   !VIPD->is_free_good(goods_path,lv)){
		write("该物品不在会员免费目录中。\n"+
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
	// 无数量的历史书签保持原语义：部分老免费药一次默认领取5颗。
	receive_count=count_supplied ? requested_count : max(1,(int)goods->amount);
	if(receive_count<1 || receive_count>VIP_FREE_BATCH_MAX ||
	   (receive_count>1 && !goods->is("combine_item"))){
		destruct(goods);
		write("领取数量必须在1到100之间，非叠加物品仍只能单件领取。\n"+
			"[返回:vip_myzone_free_detail "+goods_path+" "+lv+"]\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	int result = VIPD->if_can_get_freely(me,goods,lv);//判断该玩家是否能获得该物品
	if(result==4 && VIPD->query_free_good_remaining(me,goods,lv)>=
	   receive_count && SHOP_BATCHD->query_capacity(me,goods,1)>=receive_count)
	{
		destruct(goods);
		goods=0;
		mapping delivery=SHOP_BATCHD->deliver(me,goods_path,
			receive_count,1);
		int delivery_saved=(int)delivery["ok"] && me->save_with_result();
		if(!delivery_saved){
			int rollback_ok=(int)delivery["ok"] ?
				SHOP_BATCHD->rollback(me,delivery) :
				(int)delivery["rollback_ok"];
			int rollback_saved=me->save_with_result();
			if(!rollback_ok || !rollback_saved)
				re += "免费物品发放异常，请立即联系管理员。\n";
			else
				re += "免费物品发放失败，背包已经恢复。\n";
		}
		else{
			string s_log = me->query_name_cn()+"("+me->query_name()+
				")获得免费物品"+goods_namecn+"("+goods_name+")×"+
				receive_count+"\n";
			mixed log_err=catch{
				Stdio.append_file(ROOT+"/log/get_vip_free_item.log",
					MUD_TIMESD->get_mysql_timedesc()+":"+s_log);
			};
			if(log_err)
				werror("[VIP_AUDIT] append failed: %s\n",
					describe_error(log_err));
			re += "恭喜，你获得了"+goods_namecn+" × "+receive_count+"。\n";
		}
	}
	else if(result==4){
		if(VIPD->query_free_good_remaining(me,goods,lv)<receive_count)
			result=3;
		else
			result=2;
	}
	if(goods)
		destruct(goods);
	if(result!=4)
		re += VIPD->if_can_get_freely_desc(result,lv,goods_namecn);

	re += "[继续领取:vip_myzone_free_list "+ type +" "+ lv +"]\n";
	re += "[返回游戏:look]\n";
	write(re);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
