#include <globals.h>
#include <command.h>
#define in_edit(x) 0
#define in_input(x) 0

int main(string arg)
{
	//if(this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan")
	//	return 1;
	string now=ctime(time());
	string stmp = ""+now[0..sizeof(now)-2]+"\n";
	array(object) list;
	int j;
	for (list = users(1), j = 0; j < sizeof(list); j++) {
		if(list[j]["command"]){
			list[j]->command("save");
			stmp += ""+list[j]->name_cn+"("+list[j]->name+")save ok.\n";
			list[j]->command("quit");
		}
	}
	Stdio.append_file(ROOT+"/log/shutdown.log",stmp+"\nsave all users ok,shutdown!.\n");
	shutdown(0);
	return 1;
}
