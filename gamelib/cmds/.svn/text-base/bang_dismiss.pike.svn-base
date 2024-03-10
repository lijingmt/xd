#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "解散帮派:\n(在这里，要解散帮派你必须是帮主)\n";
	string bang_name = BANGD->query_bang_name(me->bangid);
	if(me->bangid == 0){
		s += "你未加入任何帮派\n";
		s += "[返回游戏:look]\n";
	}
	else{
		if(arg && sizeof(arg)){
			string now = ctime(time());
			BANGD->dismiss_bang(me);
			s += "你解散了自己的帮派\n";
			s += "[返回游戏:look]\n";
			Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+"):解散了帮派<"+bang_name+">\n");
		}
		else{
			if(me->bangid == 0){
				s += "你还未加入任何帮派\n";
				s += "[返回游戏:look]\n";
			}
			else if(BANGD->query_level(me->query_name(),me->bangid) != 6){
				s += "你必须是帮主\n";
				s += "[返回游戏:look]\n";
			}
			else{
				s += "你确定要解散帮派<"+bang_name+">？\n";
				s += "[确定:bang_dismiss 1] [再考虑下:look]\n";
			}
		}
	}
	write(s);
	return 1;
}
