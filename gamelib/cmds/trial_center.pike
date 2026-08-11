#include <command.h>
#include <gamelib/include/gamelib.h>

// 试炼中心：团队硬 Boss 入口 + 武勋兑换的统一入口页面。
// 广场只放一个 [试炼中心:trial_center] 链接，点击进入此页面。

int main(string|zero arg)
{
	object me = this_player();
	if(!me)
		return 0;
	string s = "";
	s += "═══ 试炼中心 ═══\n\n";
	s += "【团队硬 Boss】归墟魔君需 4 人，万象妖皇最低 2 人。\n";
	s += "万象妖皇按有效同房队员数使用现有组队经验池：2/3/4/5 人为 120%/140%/160%/200%。\n";
	s += "坦克（镇越）拉仇恨、灵医持续治疗、输出在安全位攻击。\n\n";
	s += "90级以上的 Boss 有极低概率直接掉落账号绑定的太古传承。\n";
	s += "注意：500武勋兑换的是太极/无相神技，不是太古传承。\n\n";
	s += "[⚔ 归墟境（归墟魔君）:boss_enter guixujing]\n";
	s += "[⚔ 万象林（万象妖皇）:boss_enter wanxianglin]\n";
	s += "\n";
	// 显示当前武勋数量
	int wuxun = 0;
	foreach(all_inventory(me),object item){
		if(item && item->query_name()=="shilianwuxun")
			wuxun += (int)item->amount;
	}
	s += "——试炼兑换——（当前武勋："+wuxun+"）\n";
	s += "[金币×10000(10武勋):shilian_duihuan 1 lingshi]\n";
	s += "[90级蓝装(30武勋):shilian_duihuan 1 blue90]\n";
	s += "[化神丹×5(50武勋):shilian_duihuan 1 dan]\n";
	s += "[110级紫装(80武勋):shilian_duihuan 1 purple110]\n";
	s += "[饲料金币(100武勋):shilian_duihuan 1 feed]\n";
	s += "[110级金装(200武勋):shilian_duihuan 1 gold110]\n";
	s += "[太极/无相神技书(500武勋):shilian_duihuan 1 hidden]\n";
	s += "\n[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
