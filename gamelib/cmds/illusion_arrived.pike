#include <command.h>
#include <gamelib/include/gamelib.h>

/** 跨 Worker 幻境任务到达后的幂等续跑命令。 */
int main(string|zero arg)
{
	object me = this_player();
	object handler = (object)(ROOT+"/gamelib/cmds/illusion_realm.pike");
	if(!me || !handler || !functionp(handler->query_arrival_resume_view)){
		write("幻境任务暂时无法续接。\n[返回游戏:look]\n");
		return 1;
	}
	write((string)handler->query_arrival_resume_view(me));
	return 1;
}
