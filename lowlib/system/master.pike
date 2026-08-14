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
protected void create(){
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
	string node_role = lower_case(getenv("XIAND_NODE_ROLE") || "standalone");
	int map_worker_node = node_role=="gateway" || node_role=="worker";
	werror("[MASTER] get_dir() returned %d files\n", sizeof(files));
	foreach(files,string s){
		string full_path = ROOT+"/gamelib/single/daemons/"+s;
		// A map worker must not eagerly start another copy of every global
		// scheduler (auction, ranking, boss, cron, etc.).  The small allow-list
		// also contains room-affinity schedulers: they wait for the assignment
		// snapshot and mutate only rooms owned by this worker.
		// Standalone startup remains byte-for-byte compatible.
		array(string) node_daemons = node_role=="worker" ?
			({"map_workerd.pike","http_api_daemon.pike","roomLeveld.pike",
			  "kuangd.pike","caoyaod.pike","timed_eventd.pike",
			  "jade_recoveryd.pike"}) :
			({"map_workerd.pike","http_api_daemon.pike"});
		if(map_worker_node && !has_value(node_daemons,s)){
			werror("[MASTER] Map-worker node skipping eager daemon: %s\n",s);
			continue;
		}
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
