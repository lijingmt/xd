#include <globals.h>
program connect()
{
	//werror("--------- system/master.pike is begin called ------------\n");
	program login_ob;
	mixed err;
	err = catch(login_ob = (program)(LOW_LOGIN_OB));
	if (err) {
		werror("It looks like someone is working on the player object.\n");
		master()->handle_error(err);
		destruct(this_object());
	}
	//werror("--------- system/master.pike is end called ------------\n");
	return login_ob;
}
array hosts_list;
void create(){
	hosts_list=filter(Stdio.read_file(SROOT+"/etc/hosts_list")/"\n",`!=,"");
}
string ip;
int port;
