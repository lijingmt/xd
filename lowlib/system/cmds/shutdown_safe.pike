#include <globals.h>
#include <command.h>
#define in_edit(x) 0
#define in_input(x) 0

/**
 * 可热加载的安全关服入口。shutdown.pike 可能已被旧进程缓存，
 * 独立命令名确保首次部署时也能在强制停机前保存HTTP/Vue玩家。
 */
int main(string arg)
{
	string now = ctime(time());
	string stmp = now[0..sizeof(now)-2]+"\n";
	array(object) list = users(1);
	int failed = 0;
	int saved = 0;
	object http_api_daemon = find_object(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");

	if(http_api_daemon &&
	   functionp(http_api_daemon->query_all_connected_players)){
		foreach(http_api_daemon->query_all_connected_players(),
			object http_player)
			if(http_player && search(list,http_player)==-1)
				list += ({http_player});
	}
	else if(http_api_daemon && mappingp(http_api_daemon->vconnections)){
		foreach(values(http_api_daemon->vconnections),mixed vconn)
			if(vconn && arrayp(vconn) && sizeof(vconn)>=3 &&
			   objectp(vconn[2]) && search(list,vconn[2])==-1)
				list += ({vconn[2]});
	}

	foreach(list,object player){
		if(player && functionp(player->save_with_result)){
			int save_ok = 0;
			object|zero old_context = this_player();
			set_this_player(player);
			mixed err = catch{
				if(functionp(player->update_online_time))
					player->update_online_time();
				if(functionp(player->set_links))
					player->set_links(0);
				if(functionp(player->set_inventory_links))
					player->set_inventory_links(0);
				save_ok = player->save_with_result();
			};
			set_this_player(old_context);
			if(err || !save_ok){
				failed++;
				stmp += player->name_cn+"("+player->name+")save FAILED.\n";
			}
			else{
				saved++;
				stmp += player->name_cn+"("+player->name+")save ok.\n";
			}
		}
	}

	if(failed>0){
		Stdio.append_file(ROOT+"/log/shutdown.log",stmp+
			"\nshutdown_safe ABORTED: saved="+saved+
			" failed="+failed+".\n");
		write("有"+failed+"个玩家存档失败，已取消关服。\n");
		return 1;
	}
	Stdio.append_file(ROOT+"/log/shutdown.log",stmp+
		"\nsave all users ok,shutdown_safe! saved="+saved+".\n");
	shutdown(0);
	return 1;
}
