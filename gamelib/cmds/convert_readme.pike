#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//玉石玩家操作接口
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "炼化装备系统说明：\n";
	s += "1.玩家可以在碧游宫炼器房（妖魔）,玉虚宫万宝炉（人类）的七彩八卦炉通过消耗一定的玉石和金钱来炼化【优良】以上的装备\n";
	s += "2.炼化有两个功能选择：转化属性 和 增加属性\n";
	s += "转化属性：将随机改变装备的属性，属性个数不会变化\n";
	s += "增加属性：在随机改变装备属性的同时将有一定几率为装备增加一个属性,几率将随着物品等级提高而降低\n";
	s += "3.每件物品的转化是有次数限制的，最多只能转化10次，增加属性不消耗转化的次数\n";
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}
