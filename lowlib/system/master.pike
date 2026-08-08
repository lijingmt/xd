#include <globals.h>
program connect()
{
	//werror("--------- system/master.pike is begin called ------------\n");
	program login_ob;
	mixed err;
	err = catch{
		login_ob = (program)(LOW_LOGIN_OB);
	};
	if (err) {
		werror("It looks like someone is working on the player object.\n");
		master()->handle_error(err);
		destruct(this_object());
	}
	//werror("--------- system/master.pike is end called ------------\n");
	return login_ob;
}
array hosts_list;
protected protected void create(){
	// Load hosts list
	hosts_list=filter(Stdio.read_file(SROOT+"/etc/hosts_list")/"\n",`!=,"");

	// Load daemons from gamelib/single/daemons/
	werror("========================================\n");
	werror("[MASTER] Loading daemons from: "+ROOT+"/gamelib/single/daemons/\n");
	call_out(load_daemons, 2);
}

void load_daemons()
{
	array files = get_dir(ROOT+"/gamelib/single/daemons");
	werror("[MASTER] get_dir() returned %d files\n", sizeof(files));
	foreach(files,string s){
		string full_path = ROOT+"/gamelib/single/daemons/"+s;
		// 只加载文件，跳过目录
		if(Stdio.is_dir(full_path)) {
			werror("[MASTER] Skipping directory: %s\n", s);
			continue;
		}
		mixed err = catch{
			werror("[MASTER] Loading daemon: %s\n", s);
			object ob=(object)(ROOT+"/gamelib/single/daemons/"+s);
			werror("[MASTER]   Loaded: %s -> %O\n", s, ob);
		};
		if(err) {
			werror("[MASTER] ERROR loading %s: %O\n", s, err);
		}
	}
	werror("[MASTER] All daemons loaded\n");
	werror("========================================\n");
}
string ip;
int port;
