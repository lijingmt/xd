#include <command.h>
#include <gamelib/include/gamelib.h>
// 世界地图玩家分布：返回全服在线玩家的房间坐标清单（与传送列表
// 同一快照源，无新增信息暴露）。输出机器可解析的一行式文本，由
// Vue地图解析成玩家图标与名字标注。
#define MAP_PLAYERS_HTTPD ((object)(ROOT "/gamelib/single/daemons/http_api_daemon.pike"))

int main(string|zero arg)
{
	object me=this_player();
	mapping status;
	array(string) rows=({});
	if(!me)
		return 1;
	status=MAP_PLAYERS_HTTPD->query_map_worker_cluster_online_users();
	if(!(int)status["ok"] || !arrayp(status["users"])){
		write("MAPPLAYERS|syncing\n");
		return 1;
	}
	foreach((array)status["users"],mixed raw){
		mapping user;
		string userid;
		string name_cn;
		string room_path;
		if(!mappingp(raw))
			continue;
		user=(mapping)raw;
		userid=String.trim_all_whites((string)(user["userid"] || ""));
		name_cn=(string)(user["name_cn"] || "");
		room_path=(string)(user["room_path"] || "");
		if(userid=="" || name_cn=="" || room_path=="")
			continue;
		// 归一化成世界地图节点ID：/gamelib/d/前缀与.pike后缀剥离。
		if(has_prefix(room_path,"/gamelib/d/"))
			room_path=room_path[sizeof("/gamelib/d/")..];
		if(has_suffix(room_path,".pike"))
			room_path=room_path[..sizeof(room_path)-6];
		if(search(room_path,"#")!=-1)
			room_path=(room_path/"#")[0];
		rows+=({name_cn+"@"+room_path});
	}
	write("MAPPLAYERS|"+(rows*",")+"\n");
	return 1;
}
