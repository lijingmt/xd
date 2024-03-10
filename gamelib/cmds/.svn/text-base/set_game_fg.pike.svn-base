#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令用于设置玩家的game_fg字段，要是第一次登录，则要进行合区的初始化
int main(string arg)
{
	object me = this_player();
	if(arg!="null"){
		if(!me->game_fg){
			me->bangid = 0;
			me->qqlist=({});
			me->groupList=([]);
			me->inbox=({});
			me->msg_history = "";
			me->game_fg = arg;
			me["/plus/blacklist"] = ([]);
			me["/tmp/blacklist"] = ([]);
			me["/plus/chatblock"] = ({});
			if(me->name_cn){
				if(NAMESD->is_name_regged(me->name_cn))
					me->name_cn = 0;
				else
					NAMESD->reg_name(me->name_cn);
			}
		}
	}
	return 1;
}
