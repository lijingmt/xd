#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	mapping now_time = localtime(time());
	int day = now_time["mday"];
	int month = now_time["mon"]+1;
	Stdio.append_file(ROOT+"/log/push/"+month+"_"+day+"_user_push_info.log",me->query_name()+"|"+me->user_mid+"|"+me->user_mkey+"\n");
	s += "��ѡ��ע����Ϸ����\n";
	s += "[url "+GAME_NAME_CN+"(����):http://"+GAME_URL+"/"+GAME_NAME+"/regnew.jsp]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
