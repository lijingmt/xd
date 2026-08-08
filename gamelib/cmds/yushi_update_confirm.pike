#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"

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
	   sscanf(s_num,"no=%d",num)!=1 || rarelevel<2 || rarelevel>5 ||
	   yushi_name!=YUSHID->get_yushi_name(rarelevel)){
		YUSHID->append_conversion_audit(me,"combine","rejected",
			"invalid_parameters",0,0,0,0,0,0,0,account_before);
		write("合成参数无效，本次没有扣除或发放玉石。\n"+
			"[返回:yushi_myzone.pike]\n[返回游戏:look]\n");
		return 1;
	}
	int can_num=YUSHID->query_update_num(me,rarelevel);
	string yushi_namecn=YUSHID->get_yushi_namecn(rarelevel);
	if(num<=0 || num>20){
		s+="输入有误，请重新输入,你的输入必须是一个1到20之间的数字\n";
		audit_reason="invalid_count";
	}
	else if(can_num<num){
		s+="合成失败！你没有足够的材料来合成所指定数目的"+
			yushi_namecn+"\n";
		audit_reason="insufficient_material";
	}
	else if(me->query_account()<num*1000){
		s+="合成失败！你已无法支付合成所需的费用\n";
		audit_reason="insufficient_fee";
	}
	else{
		object new_yushi;
		mixed err=catch{ new_yushi=clone(YUSHI_PATH+yushi_name); };
		if(err || !new_yushi){
			s+="合成失败！目标玉石暂时无法生成\n";
			audit_reason="clone_failed";
		}
		else{
			string need_yushi=YUSHID->get_yushi_name(rarelevel-1);
			mapping(string:mixed) removal=
				me->remove_combine_item_transaction(need_yushi,num*10);
			if(!(int)removal["ok"]){
				destruct(new_yushi);
				s+="合成失败！材料状态已经变化\n";
				audit_reason="remove_mismatch";
			}
			else{
				new_yushi->amount=num;
				if(me->if_over_load(new_yushi) ||
				   new_yushi->move(me)!=1 || environment(new_yushi)!=me){
					if(new_yushi)
						destruct(new_yushi);
					me->rollback_combine_item_transaction(removal);
					s+="合成失败！背包空间不足，材料没有扣除\n";
					audit_reason="inventory_full";
				}
				else{
					me->del_account(num*1000);
					if(!functionp(me->save_with_result) ||
					   !me->save_with_result()){
						me->add_account(num*1000);
						destruct(new_yushi);
						me->rollback_combine_item_transaction(removal);
						s+="合成失败！人物存档失败，材料和手续费已经回滚\n";
						audit_reason="save_failed";
					}
					else{
						s+="合成成功！你获得了"+new_yushi->query_short()+"\n";
						source_actual=num*10;
						target_actual=num;
						fee=num*1000;
						audit_status="success";
						audit_reason="ok";
					}
				}
			}
		}
	}
	YUSHID->append_conversion_audit(me,"combine",audit_status,audit_reason,
		rarelevel-1,num>0 ? num*10 : 0,source_actual,rarelevel,
		num>0 ? num : 0,target_actual,fee,account_before);
	s+="\n[返回:yushi_myzone.pike]\n[返回游戏:look]\n";
	write(s);
	return 1;
}
