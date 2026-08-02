#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	mapping result = PETD->start_pet_hunt(me);
	string s = "【今日灵宠寻迹】\n\n"+(string)result["message"]+"\n";
	if(result["ok"])
		s += "进度："+(int)result["progress"]+"/3。击杀必须来自真实NPC死亡结算，反复点击本页不会增加进度。\n";
	s += "[寻找适合等级的怪物:map_display]|[开启智能挂机:autofight open]\n";
	s += "[返回今日修行:daily_cultivation]|[返回万灵谱:pet]\n";
	write(s);
	return 1;
}
