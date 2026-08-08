#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = room path, e.g., "/gamelib/d/congxianzhen/congxianzhenguangchang"
//用于设置玩家复活点
int main(string|zero arg)
{
	object me=this_player();
	object env;
	string current_path;
	string links = "";
	mixed err;

	if(!me || !arg || String.trim_all_whites(arg)==""){
		write("请指定房间路径。\n");
		return 1;
	}
	if(me->query_in_combat()){
		write("战斗中不能设置复活点。\n[返回游戏:look]\n");
		return 1;
	}
	arg = String.trim_all_whites(arg);
	env = environment(me);
	if(!env){
		write("当前场景无效，不能设置复活点。\n[返回游戏:look]\n");
		return 1;
	}
	current_path = file_name(env)-ROOT;
	if(arg!=current_path || !me->is_valid_relife_path(current_path)){
		write("该地点不能设置为复活点。\n[返回游戏:look]\n");
		return 1;
	}
	if(me->relife==current_path){
		write("这里已经是你的复活点。\n[返回游戏:look]\n");
		return 1;
	}
	// 房间必须在当前玩家上下文真实展示这条链接，不能只靠客户端传路径。
	err=catch {
		links = env->query_links();
	};
	if(err || !links ||
	   search(links,"[设置复活点:set_relife "+current_path+"]")==-1){
		write("该地点不能设置为复活点。\n[返回游戏:look]\n");
		return 1;
	}

	me->relife = current_path;
	string s = "你已经成功将该房间设置成为复活点，请返回。\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
