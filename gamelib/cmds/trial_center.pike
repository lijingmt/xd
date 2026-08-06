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
	s += "【团队硬 Boss】需 3 人以上队伍挑战，伤害极高。\n";
	s += "坦克（镇越）拉仇恨、灵医持续治疗、输出在安全位攻击。\n\n";
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
	s += "[灵石(10武勋):shilian_duihuan 10 lingshi]\n";
	s += "[蓝装(30武勋):shilian_duihuan 30 blue90]\n";
	s += "[经验丹(50武勋):shilian_duihuan 50 dan]\n";
	s += "[紫装(80武勋):shilian_duihuan 80 purple110]\n";
	s += "[金装(200武勋):shilian_duihuan 200 gold110]\n";
	s += "[隐藏书(500武勋):shilian_duihuan 500 hidden]\n";
	s += "\n[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
