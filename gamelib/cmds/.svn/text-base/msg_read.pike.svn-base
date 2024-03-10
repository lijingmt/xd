#include <command.h>
#include <gamelib/include/gamelib.h>

/******************************************************************
*查看公告
*author caijie
*2008/07/16
*arg = id 公告在内存中的索引号
*或者
*arg =  type(player or admin) more(old or    new)
*            玩家     管理员       历史公告  最新公告
*****************************************************************/

int main(string arg)
{
	object me = this_object();
	string s = "";
	string type = "";	//区分是否是管理员
	string more = "";	//区分新公告与历史公告判断
	if(sscanf(arg,"%s %s",type,more)!=2){
		int id = (int)arg;	
		s += MSGD->get_old_msg("type",id);
		s += "\n";
		s += "[返回:popview]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(more=="old"){
		s += MSGD->get_old_msg(type);
	}
	else{
		s += MSGD->get_new_msg();
		if(!sizeof(s)){
			s += "目前没有公告\n";
		}
		else {
			s += "-----------\n";
			s += "[查看历史公告:msg_read player old]\n";
		}
	}
	s += "\n";
	s += "[返回:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
