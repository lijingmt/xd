#include <command.h>
#include <gamelib/include/gamelib.h>
// 月度PK排行榜：榜首每月获赠提炼守护符一张（门槛失败降级减免为3级）。

int main(string|zero arg)
{
	string s;
	array rows;
	object me=this_player();
	if(!me)
		return 1;
	s="【月度PK排行榜】统计有效击杀（同账号/同IP/等级差>30/半小时内"+
		"重复击杀不计）。\n";
	rows=REFINED->query_monthly_pvp_rank(10);
	if(sizeof(rows)==0)
		s+="本月还没有人生效击杀，去厮杀吧！\n";
	else{
		for(int i=0;i<sizeof(rows);i++)
			s+=sprintf("第%d名 %s(%s) 击杀%d\n",
				i+1,rows[i][1],rows[i][0],rows[i][2]);
		s+="守护符每月发给捐赠（充值）月榜榜首，PK榜为荣誉展示。\n";
	}
	s+="[提炼装备:refine]|[返回游戏:look]\n";
	write(s);
	return 1;
}
