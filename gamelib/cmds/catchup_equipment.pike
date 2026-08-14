#include <command.h>
#include <gamelib/include/gamelib.h>

private string query_menu(object me)
{
	mapping(string:mapping(string:mixed)) config=
		NEWBIED->query_catchup_equipments();
	array(string) order=({"zhuixingjia","zhuixingjie","zhuixingpei"});
	string s="【追赶装备】\n\n";
	s += "面向30～89级回归与新进人物；每件每个角色只可领取一次。\n";
	s += "领取的是未激活装备，单件绑定激活需100碎玉（约10元等值）。\n";
	s += "激活后不可交易、赠送、丢弃、拍卖、入仓、熔解或熔炼；PVP不提供属性，90级起自动卸下。\n\n";
	foreach(order,string item_id){
		mapping item_config=config[item_id];
		array(object) owned=({});
		foreach(all_inventory(me),object item)
			if(item && item->query_name()==item_id &&
			   functionp(item->query_catchup_equipment) &&
			   item->query_catchup_equipment())
				owned+=({item});
		s += item_config["name"]+"（"+item_config["slot"]+"）：";
		if(sizeof(owned)){
			object item=owned[0];
			if(item->query_catchup_activated())
				s += "已激活并绑定\n";
			else
				s += "未激活 [支付100碎玉激活:catchup_equipment activate "+
					item_id+" 0]\n";
			s += "[查看属性:inv_other "+me->query_name()+" "+item_id+" 0]\n";
		}
		else if(NEWBIED->query_catchup_equipment_claimed(me,item_id))
			s += "已经领取（当前不在随身背包，请联系管理员核查）\n";
		else
			s += "[免费领取未激活装备:catchup_equipment claim "+item_id+"]\n";
	}
	s += "\n[返回新手补给商店:newbie_shop]\n[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me=this_player();
	string action="";
	string item_id="";
	int count=0;
	string s="";
	if(!me)
		return 1;
	if(me->query_level()<NEWBIED->query_catchup_equipment_min_level() ||
	   me->query_level()>NEWBIED->query_catchup_equipment_max_level()){
		write("追赶装备只面向30～89级人物，未发生任何扣款。\n"+
			"[返回新手补给商店:newbie_shop]\n[返回游戏:look]\n");
		return 1;
	}
	if(!arg || sscanf(arg,"%s %s %d",action,item_id,count)<2){
		me->write_view(WAP_VIEWD["/emote"],0,0,query_menu(me));
		return 1;
	}
	if(action=="claim"){
		mapping result=NEWBIED->grant_catchup_equipment(me,item_id);
		if((int)result["ok"])
			s += "领取成功："+result["name"]+"已放入背包。激活前不能装备。\n";
		else if(result["code"]=="claimed")
			s += "这件追赶装备已经领取过，每个角色每件只能领取一次。\n";
		else if(result["code"]=="inventory_full")
			s += "背包已满，领取没有生效，请整理后重试。\n";
		else
			s += "领取失败，没有生成装备，也没有发生扣款。\n";
	}
	else if(action=="activate"){
		object item;
		int price;
		int before_wallet;
		int before_physical;
		if(count<0 || count>999){
			s += "装备序号无效，没有发生扣款。\n";
		}
		else
			item=present(item_id,me,count);
		if(s=="" && (!item || !functionp(item->query_catchup_equipment) ||
		   !item->query_catchup_equipment()))
			s += "背包中没有这件可激活的追赶装备。\n";
		else if(s=="" && item->query_catchup_activated())
			s += "这件追赶装备已经激活，不会重复扣款。\n";
		else if(s=="" && item->query_catchup_owner()!="")
			s += "装备绑定状态异常，已拒绝激活和扣款。\n";
		else if(s==""){
			price=(int)item->query_catchup_activation_price();
			if(price!=100)
				s += "装备激活价格校验失败，没有发生扣款。\n";
			else if(!YUSHID->have_enough_yushi(me,price))
				s += "玉石不足：需要100碎玉，当前可用"+
					YUSHID->query_all_num(me)+"碎玉。\n";
			else{
				before_wallet=ACCOUNT_WALLETD->query_balance(me);
				before_physical=YUSHID->query_physical_all_num(me);
				if(!YUSHID->pay_yushi(me,price))
				s += "玉石扣除失败，装备没有激活，请稍后重试。\n";
				else if(!item->activate_catchup_equipment(me) ||
				   !functionp(me->save_with_result) ||
				   !me->save_with_result()){
					if(item->query_catchup_activated())
						item->rollback_catchup_activation(me);
					if(!YUSHID->rollback_yushi_payment(me,before_wallet,
					   before_physical,"catchup_activation_save_failed"))
						werror("[CATCHUP_EQUIPMENT] 激活事务回滚失败: %s %s\n",
							me->query_name(),item_id);
					s += "激活存档失败，系统已撤销本次激活与扣款，请稍后重试。\n";
				}
				else{
				s += "激活成功："+item->query_name_cn()+
					"已绑定本角色，消耗100碎玉。\n";
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/catchup_equipment.log",
					now[0..sizeof(now)-2]+"|player="+me->query_name()+
					"|item="+item_id+"|price="+price+"|status=activated\n");
				}
			}
		}
	}
	else
		s += "追赶装备操作无效，没有发生扣款。\n";
	s += "\n[返回追赶装备:catchup_equipment]\n[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
