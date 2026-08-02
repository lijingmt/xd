#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//管理看门狗
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	s += "家园守宅犬（旧家园系统）\n\n";
	s += "说明：守宅犬继续使用原家园数据，不属于账号万灵谱，也不会占用协战伙伴。\n\n";
	s += "[埋葬:home_dog_bury]\n";
	s += "[复活:home_dog_resurrected]\n\n";
	s += "[返回:look]\n";
	write(s);
	return 1;
}
