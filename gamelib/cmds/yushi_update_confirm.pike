#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/" 
//最终合成玉石所调用的指令
//arg = yushi_name rarelevel num
int main(string|zero arg)
{
	string s = "";
	string yushi_name = "";
	string s_num = "";
	int num = 0;
	int rarelevel = 0;
	object me = this_player();
	int account_before=(int)me->query_account();
	if(!arg || sscanf(arg,"%s %d %s",yushi_name,rarelevel,s_num)!=3 ||
	   sscanf(s_num,"no=%d",num)!=1 || rarelevel<2 || rarelevel>5 ||
	   yushi_name!=YUSHID->get_yushi_name(rarelevel)){
		YUSHID->append_conversion_audit(me,"combine","rejected",
			"invalid_parameters",0,0,0,0,0,0,0,account_before);
		write("合成参数无效，本次没有扣除或发放玉石。\n"+
			"[返回:yushi_myzone.pike]\n[返回游戏:look]\n");
		return 1;
	}
	int can_num = YUSHID->query_update_num(me,rarelevel);
	string yushi_namecn = YUSHID->get_yushi_namecn(rarelevel);
	string audit_status="rejected";
	string audit_reason="unknown";
	int source_actual=0;
	int target_actual=0;
	int fee=0;
	if(num <= 0 || num > 20){
		s += "输入有误，请重新输入,你的输入必须是一个1到20之间的数字\n";
		audit_reason="invalid_count";
	}
	else if(can_num <= 0){
		s += "合成失败！你没有足够的材料\n";
		audit_reason="insufficient_material";
	}
	else if(num > can_num){
		s += "合成失败！你没有足够的材料来合成你所指定数目的"+yushi_namecn+"\n";
		audit_reason="insufficient_material";
	}
	else{
		//扣减玩家对应材料
		string need_yushi = YUSHID->get_yushi_name(rarelevel-1);
		if(me->if_over_easy_load()){
			s += "你的随身物品已满，已无法再装下更多\n";
			audit_reason="inventory_full";
		}
		else if(me->query_account()<num*1000){
			s += "合成失败！你已无法支付合成所需的费用\n";
			audit_reason="insufficient_fee";
		}
		else{
			object new_yushi;
			mixed err=catch{
				new_yushi = clone(YUSHI_PATH+
					YUSHID->get_yushi_name(rarelevel));
			};
			if(err || !new_yushi){
				s += "合成失败！目标玉石暂时无法生成\n";
				audit_reason="clone_failed";
			}
			else{
				int need_num = me->remove_combine_item(need_yushi,num*10);
				if(need_num == num*10){
					new_yushi->amount = num;
					me->del_account(num*1000);
					s += "合成成功！你获得了"+new_yushi->query_short()+"\n";
					new_yushi->move_player(me->query_name());
					source_actual=num*10;
					target_actual=num;
					fee=num*1000;
					audit_status="success";
					audit_reason="ok";
				}
				else{
					destruct(new_yushi);
					s += "材料扣除有误！！\n";
					audit_reason="remove_mismatch";
				}
			}
		}
	}
	YUSHID->append_conversion_audit(me,"combine",audit_status,audit_reason,
		rarelevel-1,num>0 ? num*10 : 0,source_actual,rarelevel,
		num>0 ? num : 0,target_actual,fee,account_before);
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
