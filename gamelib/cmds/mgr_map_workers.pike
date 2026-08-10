#include <command.h>
#include <gamelib/include/gamelib.h>

private int admin_allowed(object me)
{
	return me && MANAGERD->checkpower(me->query_name())=="admin";
}

private string result_text(mapping result)
{
	if(mappingp(result) && (int)result["ok"])
		return "§2成功：§r"+(string)result["message"]+"\n";
	return "§1失败：§r"+(string)(mappingp(result) ?
		result["message"] : "未知错误")+"\n";
}

private string overview()
{
	mapping config = MAP_WORKERD->query_cluster_config();
	mapping status = MAP_WORKERD->query_status();
	array nodes = status["nodes"] || ({});
	array placements = status["placements"] || ({});
	int runtime_controls = (string)status["node_role"]=="gateway";
	mapping(string:int) placement_counts = ([]);
	mapping(string:int) placement_weights = ([]);
	string s = "=== 地图 Worker 试运行管理 ===\n";
	s += "期望状态："+((int)config["enabled"] ? "开启" : "关闭")+
		"，worker 数："+(string)config["worker_count"]+
		"，单 worker 容量："+(string)config["worker_capacity"]+"\n";
	s += "流量模式："+((string)config["traffic_mode"]=="active" ?
		"active（仅隔离测试机）" : "shadow（不接玩家流量）")+"\n";
	s += "分配策略：负载感知一致性哈希 + 粘性租约\n";
	s += "试运行安全边界：跨节点私聊、队伍同步和世界广播已通过"+
		"5-worker 重启验收；同房间赠送/交易使用双账号事务，"+
		"跨房间或跨 Worker 仍失败关闭，"+
		"active 仍仅用于隔离试运行。\n";
	s += "运行模式："+(string)status["mode"]+
		"，当前节点角色："+(string)status["node_role"]+
		"，地图目录："+(string)status["catalog_size"]+
		"，分配代数："+(string)status["placement_generation"]+"\n";
	s += "人物租约："+(string)status["player_leases"]+
		"，迁移事务："+(string)status["handoffs"]+
		"，控制面持久化："+
		((int)status["persist_healthy"] ? "正常" : "异常")+"\n\n";

	foreach(placements,mapping placement){
		string worker_id = (string)placement["worker_id"];
		placement_counts[worker_id]++;
		placement_weights[worker_id] += (int)placement["weight"];
	}
	if(sizeof(nodes)==0)
		s += "当前没有已注册 worker；配置需由试运行编排器 apply 后生效。\n";
	else{
		s += "--- 节点状态 ---\n";
		foreach(nodes,mapping node){
			string worker_id = (string)node["worker_id"];
			s += worker_id+" | "+
				((int)node["healthy"] ? "健康" : "失联")+
				((int)node["draining"] ? "/排空" : "/接收")+
				" | 玩家="+(string)node["active_players"]+
				" 房间="+(string)node["active_rooms"]+
				" 排队="+(string)node["pending_commands"]+
				" 心跳周期="+(string)node["heartbeat_ms"]+"ms"+
				" | 地图区="+(string)placement_counts[worker_id]+
				" 权重="+(string)placement_weights[worker_id]+"\n";
			if(runtime_controls){
				if((int)node["draining"])
					s += "[恢复接收:mgr_map_workers resume "+worker_id+"]\n";
				else
					s += "[安全排空:mgr_map_workers drain "+worker_id+"]\n";
			}
		}
	}

	s += "\n--- 配置 ---\n";
	if((int)config["enabled"])
		s += "[关闭 worker 模式:mgr_map_workers toggle 0]\n";
	else
		s += "[开启 worker 模式:mgr_map_workers toggle 1]\n";
	s += "[修改 worker 数:mgr_map_workers count_input]\n";
	s += "[修改单 worker 容量:mgr_map_workers capacity_input]\n";
	if((string)config["traffic_mode"]=="shadow")
		s += "[切换到隔离机active试运行:mgr_map_workers mode active]\n";
	else
		s += "[切回shadow模式:mgr_map_workers mode shadow]\n";
	if(runtime_controls)
		s += "[仅重均衡空闲地图:mgr_map_workers rebalance]\n";
	else
		s += "运行期排空/重均衡只能由持有内部令牌的协调器编排器执行。\n";
	s += "[刷新:mgr_map_workers]\n[返回管理主界面:game_deal]\n";
	s += "\n说明：开关保存的是期望状态，不会从游戏主线程直接启动或杀死进程；"+
		"由试运行编排器安全 apply，原单进程启动方式始终可回退。\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	mapping config;
	mapping result;
	string action = "";
	string worker_id = "";
	int value;
	if(!admin_allowed(me)){
		write("权限不足。\n[返回游戏:look]\n");
		return 1;
	}
	arg = String.trim_all_whites(arg || "");
	if(arg==""){
		write(overview());
		return 1;
	}
	config = MAP_WORKERD->query_cluster_config();
	if((has_prefix(arg,"drain ") || has_prefix(arg,"resume ") ||
	   has_prefix(arg,"rebalance")) &&
	   MAP_WORKERD->query_node_role()!="gateway"){
		write("当前管理页只保存期望配置；运行期操作请使用协调器编排器。\n"+
			"[返回:mgr_map_workers]\n");
		return 1;
	}

	if(sscanf(arg,"toggle %d confirm",value)==1){
		result = MAP_WORKERD->admin_set_cluster_config(me->query_name(),
			value,(int)config["worker_count"],(int)config["worker_capacity"]);
		write(result_text(result)+"[返回:mgr_map_workers]\n");
		return 1;
	}
	if(sscanf(arg,"toggle %d",value)==1 && (value==0 || value==1)){
		write("确认"+(value ? "开启" : "关闭")+
			"地图 worker 期望状态？当前连接不会在游戏线程内被强制中断。\n");
		write("[确认:mgr_map_workers toggle "+value+" confirm] ");
		write("[取消:mgr_map_workers]\n");
		return 1;
	}
	if(arg=="mode shadow confirm" || arg=="mode active confirm"){
		string mode = search(arg,"active")!=-1 ? "active" : "shadow";
		result = MAP_WORKERD->admin_set_cluster_config(me->query_name(),
			(int)config["enabled"],(int)config["worker_count"],
			(int)config["worker_capacity"],mode);
		write(result_text(result)+"[返回:mgr_map_workers]\n");
		return 1;
	}
	if(arg=="mode shadow" || arg=="mode active"){
		string mode = search(arg,"active")!=-1 ? "active" : "shadow";
		if(mode=="active")
			write("active 会让真实请求进入多个世界进程，只能用于隔离测试机；"+
				"跨节点私聊、队伍和世界广播已通过重启验收，"+
				"同房间赠送/交易已启用双账号事务，跨节点请求仍拒绝；"+
				"编排器仍要求环境变量二次确认。\n");
		write("确认切换为 "+mode+" 模式？\n");
		write("[确认:mgr_map_workers mode "+mode+" confirm] ");
		write("[取消:mgr_map_workers]\n");
		return 1;
	}

	if(arg=="count_input"){
		write("请输入 worker 数量（1-16，建议从3开始）：\n");
		write("[string:mgr_map_workers count_set ...]\n");
		write("[取消:mgr_map_workers]\n");
		return 1;
	}
	if(sscanf(arg,"count_set %d confirm",value)==1){
		result = MAP_WORKERD->admin_set_cluster_config(me->query_name(),
			(int)config["enabled"],value,(int)config["worker_capacity"]);
		write(result_text(result)+"[返回:mgr_map_workers]\n");
		return 1;
	}
	if(sscanf(arg,"count_set %d",value)==1){
		if(value<1 || value>16){
			write("worker 数必须为1至16。\n[返回:mgr_map_workers]\n");
			return 1;
		}
		write("确认把 worker 数从"+(string)config["worker_count"]+
			"改为"+value+"？扩缩容只会渐进迁移空闲地图。\n");
		write("[确认:mgr_map_workers count_set "+value+" confirm] ");
		write("[取消:mgr_map_workers]\n");
		return 1;
	}

	if(arg=="capacity_input"){
		write("请输入单 worker 容量权重（10-10000，默认100）：\n");
		write("[string:mgr_map_workers capacity_set ...]\n");
		write("[取消:mgr_map_workers]\n");
		return 1;
	}
	if(sscanf(arg,"capacity_set %d confirm",value)==1){
		result = MAP_WORKERD->admin_set_cluster_config(me->query_name(),
			(int)config["enabled"],(int)config["worker_count"],value);
		write(result_text(result)+"[返回:mgr_map_workers]\n");
		return 1;
	}
	if(sscanf(arg,"capacity_set %d",value)==1){
		if(value<10 || value>10000){
			write("容量权重必须为10至10000。\n[返回:mgr_map_workers]\n");
			return 1;
		}
		write("确认把容量权重改为"+value+"？\n");
		write("[确认:mgr_map_workers capacity_set "+value+" confirm] ");
		write("[取消:mgr_map_workers]\n");
		return 1;
	}

	if(sscanf(arg,"%s %s confirm",action,worker_id)==2 &&
	   (action=="drain" || action=="resume")){
		result = MAP_WORKERD->admin_set_worker_draining(me->query_name(),
			worker_id,action=="drain");
		write(result_text(result)+"[返回:mgr_map_workers]\n");
		return 1;
	}
	if(sscanf(arg,"%s %s",action,worker_id)==2 &&
	   (action=="drain" || action=="resume")){
		write("确认"+(action=="drain" ? "安全排空 " : "恢复接收 ")+
			worker_id+"？正在战斗的玩家不会被强搬。\n");
		write("[确认:mgr_map_workers "+action+" "+worker_id+" confirm] ");
		write("[取消:mgr_map_workers]\n");
		return 1;
	}

	if(arg=="rebalance confirm"){
		result = MAP_WORKERD->rebalance_idle_affinities(me->query_name());
		write(result_text(result));
		if((int)result["ok"])
			write("迁移="+(string)result["moved"]+
				"，不变="+(string)result["unchanged"]+
				"，活跃跳过="+(string)result["skipped_active"]+"\n");
		write("[返回:mgr_map_workers]\n");
		return 1;
	}
	if(arg=="rebalance"){
		write("确认只重分配没有活跃人物租约的地图？\n");
		write("[确认:mgr_map_workers rebalance confirm] ");
		write("[取消:mgr_map_workers]\n");
		return 1;
	}

	write("未知操作。\n[返回:mgr_map_workers]\n");
	return 1;
}
