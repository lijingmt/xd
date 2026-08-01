#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	string content = "";
	if(me->bangid == 0){
		s += "浣犳病鏈夊湪浠讳綍甯淳閲孿n";
	}
	else if(!BANGD->bang_allows_user(me->bangid,me->query_name())){
		s = "该帮派当前属于其他逻辑区，隔离期间不可管理。\n";
	}
	else{
		s = BANGD->query_bang_apply(me->bangid,me->query_name());
		if(s=="")
			s = "娌℃湁鏂扮殑鍏ュ府鐢宠\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
