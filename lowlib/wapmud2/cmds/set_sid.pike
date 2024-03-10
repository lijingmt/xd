#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string now=ctime(time());
	object me = this_player();
	string s;
	if(arg!="null"){
		me->sid=arg;
		if(arg=="tmp"){
			//这里可以添加登陆的一些限制
		}
	}
	else{
		write(me->query_LOGIN_MSG());
		s = now[0..sizeof(now)-2]+":"+me->name_cn+"("+me->name+")"+" set_sid=null login denny\n";
		Stdio.append_file(ROOT+"/log/set_sid.log",s);
		destruct(me);
	}
	return 1;
}
