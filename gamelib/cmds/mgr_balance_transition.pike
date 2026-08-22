#include <command.h>
#include <gamelib/include/gamelib.h>
// 平衡过渡期怪物强度在线热调：生命% 攻击% [原因]。
// 例：mgr_balance_transition 50 70 回收过渡
//     mgr_balance_transition 100 100 过渡结束
int main(string|zero arg)
{
	object me=this_player();
	array(string) parts=arg ? (arg/" ")-({""}) : ({});
	mapping status;
	int life_percent;
	int attack_percent;
	string reason;
	if(!me)
		return 1;
	if(!MANAGERD->is_cross_zone_admin((string)me->query_name())){
		write("只有管理员可以调整全局怪物强度。\n[返回游戏:look]\n");
		return 1;
	}
	status=BALANCE_TRANSITIOND->query_status();
	if(!sizeof(parts)){
		write("【平衡过渡期·全局怪物强度】\n"+
			"当前：生命"+(int)status["life_percent"]+"%、攻击"+
			(int)status["attack_percent"]+"%"+
			((int)status["persisted"] ? "（持久配置）" : "（过渡默认）")+
			"\n用法：mgr_balance_transition 生命% 攻击% [原因]\n"+
			"范围10-200；调整后30秒内全服生效；战斗公式不变。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts)<2 ||
	   sscanf(parts[0],"%d",life_percent)!=1 ||
	   sscanf(parts[1],"%d",attack_percent)!=1){
		write("参数无效。用法：mgr_balance_transition 生命% 攻击% [原因]\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	reason=sizeof(parts)>2 ? parts[2] : "";
	mapping result=BALANCE_TRANSITIOND->set_percents(life_percent,
		attack_percent,reason);
	write((string)result["message"]+"\n[返回游戏:look]\n");
	return 1;
}
