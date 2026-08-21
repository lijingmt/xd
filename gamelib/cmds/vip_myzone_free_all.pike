#include <command.h>
#include <gamelib/include/gamelib.h>
// 一键领取当前会员档位下本分类的全部免费物品；逐件沿用单领的
// 数量默认值、每日余量、背包容量、发放回滚与审计规则。

#define VIP_FREE_BATCH_MAX 100

int main(string|zero arg)
{
	object me = this_player();
	string sub = arg ? arg : "";
	int lv;
	array(string) paths;
	array(mapping) deliveries = ({});
	array(string) claimed_names = ({});
	int claimed = 0;
	int skipped = 0;
	string re = "";
	if(!me)
		return 1;
	lv = VIPD->query_active_vip_level(me);
	if(lv < 1 || !VIPD->get_vip_name(lv)){
		write("你当前没有生效的会员档位。\n"+
			"[返回:vip_myzone]\n[返回游戏:look]\n");
		return 1;
	}
	paths = VIPD->query_free_goods_paths(lv,sub);
	if(!sizeof(paths)){
		write("该分类当前没有可领取的免费物品。\n"+
			"[返回:vip_myzone_free_list "+sub+" "+lv+"]\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	foreach(paths,string goods_path){
		object goods;
		int receive_count;
		int remaining;
		mixed err=catch{
			goods=clone(ITEM_PATH+goods_path);
		};
		if(err || !goods){
			skipped++;
			continue;
		}
		goods->set_toVip(1);
		// 与单件领取相同的默认数量：老书签无数量时至少1件。
		receive_count=max(1,(int)goods->amount);
		if(receive_count>VIP_FREE_BATCH_MAX)
			receive_count=VIP_FREE_BATCH_MAX;
		remaining=VIPD->query_free_good_remaining(me,goods,lv);
		if(remaining<1){
			skipped++;
			destruct(goods);
			continue;
		}
		if(receive_count>remaining)
			receive_count=remaining;
		if(SHOP_BATCHD->query_capacity(me,goods,1)<receive_count){
			skipped++;
			destruct(goods);
			continue;
		}
		mapping delivery=SHOP_BATCHD->deliver(me,goods_path,
			receive_count,1);
		if((int)delivery["ok"]){
			deliveries+=({delivery});
			claimed_names+=({(string)goods->query_name_cn()+
				"×"+receive_count});
			claimed++;
		}
		else
			skipped++;
		destruct(goods);
	}
	if(sizeof(deliveries) && !me->save_with_result()){
		for(int index=sizeof(deliveries)-1;index>=0;index--)
			SHOP_BATCHD->rollback(me,deliveries[index]);
		me->save_with_result();
		write("一键领取发放异常，背包已经恢复，请立即联系管理员。\n"+
			"[返回:vip_myzone_free_list "+sub+" "+lv+"]\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	if(claimed){
		mixed log_err=catch{
			Stdio.append_file(ROOT+"/log/get_vip_free_item.log",
				MUD_TIMESD->get_mysql_timedesc()+":"+
				me->query_name_cn()+"("+me->query_name()+
				")一键获得免费物品"+(claimed_names*"、")+"\n");
		};
		if(log_err)
			werror("[VIP_AUDIT] append failed: %s\n",
				describe_error(log_err));
		re="一键领取完成："+claimed_names*"、"+"\n";
	}
	else
		re="本分类今日没有可领取的免费物品。\n";
	if(skipped>0)
		re+="另有"+skipped+"项因每日上限、背包容量或生成失败跳过。\n";
	re+="[返回:vip_myzone_free_list "+sub+" "+lv+"]\n"+
		"[返回:vip_myzone]\n[返回游戏:look]\n";
	write(re);
	return 1;
}
