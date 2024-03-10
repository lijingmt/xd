#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	int level = 0;
	if(!me->bangid){
		s = "你未加入任何帮派\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		int be = BANGD->quit_bang(me->query_name(),me->bangid);
		//set_bang_root()返回 1：退出成功
		//                    0：失败
		//                    2：是帮主，要转交权限后才能退出
		//					  3：你没在帮派里
		if(be == 1){
			string content = me->query_name_cn()+"退出了帮派\n";
			BANGD->bang_notice(me->bangid,content);
			me->bangid = 0;
			s +="你退出了帮派<"+bang_name+">\n";
			s += "[返回游戏:look]\n";
		}
		else if(be == 2){
			s += "你是帮主，请转交帮主一职后再退出帮会\n";
			s +="[返回:my_bang]\n";
			s +="[返回游戏:look]\n";
		}
		else if(be == 0){
			me->bangid = 0;
			s += "你已不在任何帮派了\n";
			s +="[返回:my_bang]\n";
			s +="[返回游戏:look]\n";
		}
		else if(be == 3){
			if(me->bangid != 0)
				me->bangid =0;
			s += "你并没有在这个帮派里\n";
			s +="[返回游戏:look]\n";
		}
	}
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
