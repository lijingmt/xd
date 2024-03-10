#include <command.h>
#include <gamelib/include/gamelib.h>
/*
   申请入会选择页面
auther: evan
2008.07.16
 */
int main(string arg)
{
	object me = this_player();
	string s = "***会员升级***\n\n";
	string cost_des = "";//费用描述
	s += VIPD->get_vip_state_des_withoutlink(me);
	int level = me->query_vip_flag();
	if(level)//是会员
	{
		if(level!=4){
			s += "请注意：升级并不会延长你的会员期限\n\n";
			s += "\n请选择你要升级的会员类别:\n";
			mapping vip_name = VIPD->get_vip_name_map();
			mapping vip_cost = VIPD->get_vip_cost_map();
			int num = sizeof(vip_name);
			int num2 = sizeof(vip_cost);
			int state = VIPD->get_vip_state(me);
			int cost = 0;
			if(num>num2) num=num2;
			for(int i=level+1;i<=num;i++)
			{
				cost = vip_cost[i]-vip_cost[level];
				if(state==2||state==3)
				{
					cost=cost*6/10;
				}
				cost_des = YUSHID->get_yushi_for_desc(cost*10);
				s += "   ["+vip_name[i]+"(" +cost_des +"):vip_service_upgrade_detail "+(string)i+"]\n";
			}
		}
		else
		{
			s += "你已经是最高级的会员了，请期待我们开放更高特权的等级吧！\n";
		}
	}
	else//不是会员
	{
		s += "[申请:vip_service_app_list.pike ]\n\n";
	}
	s += "\n[返回:vip_service_list.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
