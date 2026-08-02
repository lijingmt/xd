#include <command.h>
#include <gamelib/include/gamelib.h>

string query_warehouse_path(string race_id)
{
	if(race_id=="monst")
		return "jinaodao/wuge";
	if(race_id=="human" || race_id=="third")
		return "kunlunshan/wuge";
	return "";
}

int main(string|zero arg)
{
	object me = this_player();
	object env;
	string path;
	if(!me)
		return 0;
	if(me->in_combat){
		write("战斗中无法前往武阁，请结束战斗后再试。\n"+
			"[继续战斗:attack]\n");
		return 1;
	}
	env = environment(me);
	if(env && env->query_room_type()=="fb"){
		write("副本中无法前往武阁，请先正常离开副本。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	path = query_warehouse_path(me->query_raceId());
	if(path==""){
		write("当前人物阵营暂时无法使用武阁。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	tell_object(me,"正在前往武阁，抵达后可使用藏宝箱存取物品。\n");
	me->command("qge74hye "+path);
	return 1;
}
