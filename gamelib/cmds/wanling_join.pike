#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	mapping result;
	if(!arg || arg=="")
		result = (["message":"请选择一条有效的万灵裂隙招募。"]);
	else
		result = PETD->join_rift_recruit(me,arg);
	write((string)result["message"]+"\n"+
		"[前往万灵台集合:wanling_rift gather]|[查看队伍:my_term]|"+
		"[返回游戏:look]\n");
	return 1;
}
