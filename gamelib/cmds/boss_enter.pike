#include <command.h>
#include <gamelib/include/gamelib.h>

// 团队硬 Boss 专用传送命令（无冷却）：boss_enter <room_path>
// 仅限传送至 guixujing 或 wanxianglin。
int main(string|zero arg)
{
	object me = this_player();
	if(!me)
		return 0;
	if(!arg || arg==""){
		write("用法：boss_enter guixujing 或 boss_enter wanxianglin\n");
		return 1;
	}
	if(me->in_combat){
		write("战斗中无法传送。\n");
		return 1;
	}
	string dest = "";
	if(arg=="guixujing")
		dest = ROOT+"/gamelib/d/jinaodao/guixujing";
	else if(arg=="wanxianglin")
		dest = ROOT+"/gamelib/d/congxianzhen/wanxianglin";
	else{
		write("无效的目的地。\n");
		return 1;
	}
	object room;
	mixed err = catch { room = (object)dest; };
	if(err || !room){
		write("目的地暂时无法到达。\n");
		return 1;
	}
	me->move(room);
	me->reset_view();
	me->command("look");
	return 1;
}
