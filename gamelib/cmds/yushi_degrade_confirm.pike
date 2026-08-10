#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"

private void rollback_targets(array(object) targets)
{
	foreach(targets,object target)
		if(target)
			destruct(target);
}

private array(object) create_split_targets(string yushi_name,int count)
{
	array(object) targets=({});
	while(count>0){
		object target;
		mixed err=catch{ target=clone(YUSHI_PATH+yushi_name); };
		if(err || !target){
			rollback_targets(targets);
			return ({});
		}
		int max_count=(int)target->max_count;
		if(max_count<=0){
			destruct(target);
			rollback_targets(targets);
			return ({});
		}
		target->amount=count>max_count ? max_count : count;
		count-=(int)target->amount;
		targets+=({target});
	}
	return targets;
}

int main(string|zero arg)
{
	string s="";
	string yushi_name="";
	string s_num="";
	int num=0;
	int rarelevel=0;
	object me=this_player();
	int account_before=(int)me->query_account();
	string audit_status="rejected";
	string audit_reason="unknown";
	int source_actual=0;
	int target_actual=0;
	int fee=0;
	if(!arg || sscanf(arg,"%s %d %s",yushi_name,rarelevel,s_num)!=3 ||
	   sscanf(s_num,"no=%d",num)!=1 || rarelevel<1 || rarelevel>4 ||
	   yushi_name!=YUSHID->get_yushi_name(rarelevel)){
		YUSHID->append_conversion_audit(me,"split","rejected",
			"invalid_parameters",0,0,0,0,0,0,0,account_before);
		write("打碎参数无效，本次没有扣除或发放玉石。\n"+
			"[返回:yushi_myzone.pike]\n[返回游戏:look]\n");
		return 1;
	}
	int can_num=YUSHID->query_degrade_num(me,rarelevel);
	string need_namecn=YUSHID->get_yushi_namecn(rarelevel+1);
	string need_yushi=YUSHID->get_yushi_name(rarelevel+1);
	if(num<=0 || num>5){
		s+="输入有误，请重新输入,你的输入必须是1到5之间的数字\n";
		audit_reason="invalid_count";
	}
	else if(can_num<num){
		s+="打碎失败！你当前只有"+can_num+"块"+need_namecn+
			"，本次输入了"+num+"块\n";
		audit_reason="insufficient_material";
	}
	else if(me->query_account()<num*1000){
		s+="打碎失败！你已无法支付所需费用\n";
		audit_reason="insufficient_fee";
	}
	else{
		array(object) targets=create_split_targets(yushi_name,num*10);
		if(!sizeof(targets)){
			s+="打碎失败！目标玉石暂时无法生成\n";
			audit_reason="clone_failed";
		}
		else{
			mapping(string:mixed) removal=
				me->remove_combine_item_transaction(need_yushi,num);
			if(!(int)removal["ok"]){
				rollback_targets(targets);
				s+="打碎失败！玉石状态已经变化\n";
				audit_reason="remove_mismatch";
			}
			else{
				int moved_ok=1;
				foreach(targets,object target){
					if(me->if_over_load(target) || target->move(me)!=1 ||
					   environment(target)!=me){
						moved_ok=0;
						break;
					}
				}
				if(!moved_ok){
					rollback_targets(targets);
					me->rollback_combine_item_transaction(removal);
					s+="打碎失败！背包空间不足，原玉石没有扣除\n";
					audit_reason="inventory_full";
				}
				else{
					me->del_account(num*1000);
					if(!functionp(me->save_with_result) ||
					   !me->save_with_result()){
						me->add_account(num*1000);
						rollback_targets(targets);
						me->rollback_combine_item_transaction(removal);
						s+="打碎失败！人物存档失败，玉石和手续费已经回滚\n";
						audit_reason="save_failed";
					}
					else{
						s+="打碎成功！你获得了"+
							YUSHID->get_yushi_namecn(rarelevel)+"x"+
							(string)(num*10)+"\n";
						source_actual=num;
						target_actual=num*10;
						fee=num*1000;
						audit_status="success";
						audit_reason="ok";
					}
				}
			}
		}
	}
	YUSHID->append_conversion_audit(me,"split",audit_status,audit_reason,
		rarelevel+1,num>0 ? num : 0,source_actual,rarelevel,
		num>0 ? num*10 : 0,target_actual,fee,account_before);
	s+="\n[返回:yushi_myzone.pike]\n[返回游戏:look]\n";
	write(s);
	return 1;
}
