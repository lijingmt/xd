#include <globals.h>
#include <command.h>
#include <gamelib/include/gamelib.h>
#define in_edit(x) 0
#define in_input(x) 0

/** Driver login placeholders have no canonical archive and are not players. */
private int shutdown_safe_ephemeral_login(object player)
{
	string userid;
	string path;
	if(!player || !functionp(player->query_name))
		return 0;
	userid = lower_case((string)player->query_name());
	if(!has_prefix(userid,"logintmp") || sizeof(userid)<2)
		return 0;
	path = DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
	return Stdio.file_size(path)<=0 && Stdio.file_size(path+".bak")<=0 &&
		Stdio.file_size(path+".tmp")<=0;
}

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
	int worker_shutdown = MAP_WORKERD->query_node_role()=="worker";

	// Rolling upgrade compatibility: an already-running pre-barrier worker does
	// not expose the new method. New worker processes always require the fence.
	if(worker_shutdown &&
	   functionp(MAP_WORKERD->local_shutdown_save_fence_valid) &&
	   !MAP_WORKERD->local_shutdown_save_fence_valid()){
		Stdio.append_file(ROOT+"/log/shutdown.log",stmp+
			"shutdown_safe ABORTED: worker has no coordinator shutdown fence.\n");
		write("地图 worker 尚未完成协调器停流，已拒绝关服。\n");
		return 1;
	}

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
	if(worker_shutdown){
		foreach(MAP_WORKERD->query_local_player_userids(),string userid){
			object|zero local_player = 0;
			if(http_api_daemon &&
			   functionp(http_api_daemon->get_player_from_connection))
				local_player = http_api_daemon->
					get_player_from_connection(userid,0);
			if(!local_player)
				local_player = find_player(userid);
			if(local_player && search(list,local_player)==-1)
				list += ({local_player});
		}
	}

	foreach(list,object player){
		if(shutdown_safe_ephemeral_login(player)){
			stmp += "ephemeral login placeholder skipped.\n";
			continue;
		}
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
				save_ok = player->save_with_result(0,worker_shutdown ? 1 : 0);
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
