#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"

// 最终打碎玉石所调用的指令
// arg = yushi_name rarelevel num
int main(string|zero arg)
{
	string s="";
	string yushi_name="";
	string s_num="";
	int num=0;
	int rarelevel=0;
	object me=this_player();
	int account_before=(int)me->query_account();
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
	string audit_status="rejected";
	string audit_reason="unknown";
	int source_actual=0;
	int target_actual=0;
	int fee=0;

	if(num<=0 || num>5){
		s += "输入有误，请重新输入,你的输入必须是1到5之间的数字\n";
		audit_reason="invalid_count";
	}
	else if(can_num<=0){
		s += "打碎失败！你没有足够的"+need_namecn+"\n";
		audit_reason="insufficient_material";
	}
	else if(num>can_num){
		s += "打碎失败！你没有你所指定数目的"+need_namecn+"\n";
		audit_reason="insufficient_material";
	}
	else{
		int full_groups=num*10/30;
		int remainder=(num*10)%30;

		// 每3块高一级玉石打碎为30块低一级玉石，手续费3000。
		for(int k=1;k<=full_groups;k++){
			object new_yushi;
			mixed err=catch{
				new_yushi=clone(YUSHI_PATH+
					YUSHID->get_yushi_name(rarelevel));
			};
			if(err || !new_yushi){
				s += "打碎失败！目标玉石暂时无法生成\n";
				if(audit_reason=="unknown") audit_reason="clone_failed";
				break;
			}
			new_yushi->amount=30;
			if(me->if_over_load(new_yushi)){
				s += "打碎失败！你的随身物品已满\n";
				if(audit_reason=="unknown") audit_reason="inventory_full";
				destruct(new_yushi);
				break;
			}
			if(me->query_account()<3000){
				s += "打碎失败！你已无法支付所需费用\n";
				if(audit_reason=="unknown") audit_reason="insufficient_fee";
				destruct(new_yushi);
				break;
			}
			int removed=me->remove_combine_item(need_yushi,3);
			source_actual+=removed;
			if(removed!=3){
				destruct(new_yushi);
				s += "打碎失败！玉石扣除异常，请稍后重试\n";
				if(audit_reason=="unknown") audit_reason="remove_mismatch";
				break;
			}
			me->del_account(3000);
			fee+=3000;
			target_actual+=30;
			s += "打碎成功！你获得了"+new_yushi->query_short()+"\n";
			new_yushi->move_player(me->query_name());
		}

		// 剩余1或2块分别打碎为10或20块，手续费1000或2000。
		if(remainder>0){
			int need_count=remainder>10 ? 2 : 1;
			int money=need_count*1000;
			object new_yushi;
			mixed err=catch{
				new_yushi=clone(YUSHI_PATH+
					YUSHID->get_yushi_name(rarelevel));
			};
			if(err || !new_yushi){
				s += "打碎失败！目标玉石暂时无法生成\n";
				if(audit_reason=="unknown") audit_reason="clone_failed";
			}
			else{
				new_yushi->amount=remainder;
				if(me->if_over_load(new_yushi)){
					s += "打碎失败！你的随身物品已满\n";
					if(audit_reason=="unknown")
						audit_reason="inventory_full";
					destruct(new_yushi);
				}
				else if(me->query_account()<money){
					s += "打碎失败！你已无法支付所需费用\n";
					if(audit_reason=="unknown")
						audit_reason="insufficient_fee";
					destruct(new_yushi);
				}
				else{
					int removed=me->remove_combine_item(
						need_yushi,need_count);
					source_actual+=removed;
					if(removed!=need_count){
						destruct(new_yushi);
						s += "打碎失败！玉石扣除异常，请稍后重试\n";
						if(audit_reason=="unknown")
							audit_reason="remove_mismatch";
					}
					else{
						me->del_account(money);
						fee+=money;
						target_actual+=remainder;
						s += "打碎成功！你获得了"+
							new_yushi->query_short()+"\n";
						new_yushi->move_player(me->query_name());
					}
				}
			}
		}

		if(source_actual==num && target_actual==num*10){
			audit_status="success";
			audit_reason="ok";
		}
		else if(source_actual>0 || target_actual>0){
			audit_status="partial";
			if(audit_reason=="unknown") audit_reason="incomplete";
		}
	}

	YUSHID->append_conversion_audit(me,"split",audit_status,audit_reason,
		rarelevel+1,num>0 ? num : 0,source_actual,rarelevel,
		num>0 ? num*10 : 0,target_actual,fee,account_before);
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
