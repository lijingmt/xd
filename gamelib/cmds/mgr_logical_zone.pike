#include <command.h>
#include <gamelib/include/gamelib.h>

private int admin_allowed(object me)
{
	return me && MANAGERD->checkpower(me->query_name())=="admin";
}

private string decode_admin_input(string value)
{
	if(!value)
		return "";
	value = replace(value,(["%20":" ","%2C":",","%2c":","]));
	return String.trim_all_whites(value);
}

private string result_text(mapping result)
{
	if(result && (int)result["ok"])
		return "§2成功：§r"+(string)result["message"]+"\n";
	return "§1失败：§r"+(string)(result && result["message"] || "未知错误")+"\n";
}

private mapping(string:mixed)|zero find_admin_zone(object me,string zone_id)
{
	array(mapping(string:mixed)) zones =
		LOGICALZONED->admin_query_partitions(me->query_name());
	foreach(zones,mapping(string:mixed) zone)
		if((string)zone["zone_id"]==zone_id)
			return zone;
	return 0;
}

private string overview(object me)
{
	array(mapping(string:mixed)) zones =
		LOGICALZONED->admin_query_partitions(me->query_name());
	mapping status = LOGICALZONED->query_status();
	string s = "=== 逻辑新区管理 ===\n";
	s += "配置代数："+(string)status["generation"]+
		"，区数："+(string)status["zone_count"]+
		"，健康："+(status["last_error"]=="" ? "正常" : "异常")+"\n";
	if(status["last_error"]!="")
		s += "最近错误："+(string)status["last_error"]+"\n";
	s += "\n";
	foreach(zones,mapping(string:mixed) zone){
		s += "["+(string)zone["name"]+"("+(string)zone["zone_id"]+
			"):mgr_logical_zone view "+(string)zone["zone_id"]+"] ";
		s += "rev="+(string)zone["revision"]+
			" enabled="+(string)zone["enabled"]+
			" reg="+(string)zone["registration_open"]+
			" login="+(string)zone["login_open"]+
			" isolation="+(string)zone["isolation"]+
			" cluster="+(string)zone["cluster"]+"\n";
	}
	s += "\n[新增新区:mgr_logical_zone create]\n";
	s += "[合并多个区:mgr_logical_zone merge]\n";
	s += "[刷新:mgr_logical_zone]\n[返回管理主界面:game_deal]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	string action = "";
	string zone_id = "";
	string value = "";
	string zone_name = "";
	string cluster = "";
	string zone_csv = "";
	int sort_order;
	mapping result;
	mapping(string:mixed)|zero target_zone;
	if(!admin_allowed(me)){
		write("权限不足。\n[返回游戏:look]\n");
		return 1;
	}
	arg = decode_admin_input(arg || "");
	if(arg==""){
		write(overview(me));
		return 1;
	}

	if(arg=="create"){
		write("新增新区默认独立，并关闭登录和注册。\n");
		write("请输入：四位区号 区名 排序，例如 xd06 仙道六区 6\n");
		write("[mgr_logical_zone create_exec ...]\n");
		write("[返回:mgr_logical_zone]\n");
		return 1;
	}
	if(sscanf(arg,"create_exec %s %s %d",zone_id,zone_name,sort_order)==3){
		result = LOGICALZONED->admin_create_zone(
			me->query_name(),lower_case(zone_id),zone_name,sort_order);
		write(result_text(result)+"[返回:mgr_logical_zone]\n");
		return 1;
	}

	if(sscanf(arg,"view %s",zone_id)==1){
		mapping(string:mixed)|zero zone = find_admin_zone(me,zone_id);
		if(!zone){
			write("逻辑区不存在。\n[返回:mgr_logical_zone]\n");
			return 1;
		}
		string s = "=== "+(string)zone["name"]+"("+zone_id+") ===\n";
		s += "revision="+(string)zone["revision"]+"\n";
		s += "enabled="+(string)zone["enabled"]+
			" registration_open="+(string)zone["registration_open"]+
			" login_open="+(string)zone["login_open"]+"\n";
		s += "isolation="+(string)zone["isolation"]+
			" cluster="+(string)zone["cluster"]+
			" open_at="+(string)zone["open_at"]+"\n";
		s += "备注："+(string)zone["notes"]+"\n\n";
		s += "[开放登录和注册:mgr_logical_zone open "+zone_id+"]\n";
		s += "[关闭登录和注册:mgr_logical_zone close "+zone_id+"]\n";
		s += "[下架并停区:mgr_logical_zone disable "+zone_id+"]\n";
		if((int)zone["isolation"])
			s += "[恢复合区("+(string)zone["cluster"]+"):mgr_logical_zone unisolate "+zone_id+"]\n";
		else
			s += "[设为独立隔离:mgr_logical_zone isolate "+zone_id+"]\n";
		s += "[回滚上一版:mgr_logical_zone rollback "+zone_id+"]\n";
		s += "[修改区名:mgr_logical_zone input name "+zone_id+"]\n";
		s += "[修改备注:mgr_logical_zone input notes "+zone_id+"]\n";
		s += "[设置定时开放时间:mgr_logical_zone input open_at "+zone_id+"]\n";
		s += "[返回:mgr_logical_zone]\n";
		write(s);
		return 1;
	}

	if(sscanf(arg,"input %s %s",action,zone_id)==2){
		if(action!="name" && action!="notes" && action!="open_at"){
			write("不支持的修改字段。\n[返回:mgr_logical_zone]\n");
			return 1;
		}
		me["/tmp/logical_zone_field"] = action;
		me["/tmp/logical_zone_id"] = zone_id;
		write("请输入新值：\n[mgr_logical_zone input_exec ...]\n");
		write("[取消:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(has_prefix(arg,"input_exec ")){
		action = (string)me["/tmp/logical_zone_field"];
		zone_id = (string)me["/tmp/logical_zone_id"];
		value = arg[11..];
		me["/tmp/logical_zone_field"] = 0;
		me["/tmp/logical_zone_id"] = 0;
		if(action=="open_at"){
			int open_at;
			if(sscanf(value,"%d",open_at)!=1 || open_at<0){
				write("开放时间必须是非负 Unix 时间戳。\n[返回:mgr_logical_zone]\n");
				return 1;
			}
			result = LOGICALZONED->admin_set_zone_field(
				me->query_name(),zone_id,action,open_at);
		}
		else
			result = LOGICALZONED->admin_set_zone_field(
				me->query_name(),zone_id,action,value);
		write(result_text(result)+"[返回:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}

	if(sscanf(arg,"open %s",zone_id)==1){
		write("确认开放 "+zone_id+" 的登录和注册？\n");
		write("[确认:mgr_logical_zone open_confirm "+zone_id+"] ");
		write("[取消:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"open_confirm %s",zone_id)==1){
		result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"enabled",1);
		if((int)result["ok"])
			result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"login_open",1);
		if((int)result["ok"])
			result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"registration_open",1);
		write(result_text(result)+"[返回:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"close %s",zone_id)==1){
		result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"registration_open",0);
		if((int)result["ok"])
			result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"login_open",0);
		write(result_text(result)+"[返回:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"disable %s",zone_id)==1){
		write("确认关闭注册和登录，并从区列表下架 "+zone_id+"？\n");
		write("[确认:mgr_logical_zone disable_confirm "+zone_id+"] ");
		write("[取消:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"disable_confirm %s",zone_id)==1){
		result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"registration_open",0);
		if((int)result["ok"])
			result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"login_open",0);
		if((int)result["ok"])
			result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"enabled",0);
		write(result_text(result)+"[返回:mgr_logical_zone]\n");
		return 1;
	}
	if(sscanf(arg,"isolate %s",zone_id)==1){
		target_zone = find_admin_zone(me,zone_id);
		if(!target_zone){
			write("逻辑区不存在。\n[返回:mgr_logical_zone]\n");
			return 1;
		}
		if((int)target_zone["isolation"]){
			write(zone_id+" 已经是独立隔离状态。\n[返回:mgr_logical_zone view "+zone_id+"]\n");
			return 1;
		}
		write("确认把 "+zone_id+" 从合区设为独立隔离？\n");
		write("[确认隔离:mgr_logical_zone isolate_confirm "+zone_id+"] ");
		write("[取消:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"isolate_confirm %s",zone_id)==1){
		result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"isolation",1);
		write(result_text(result)+"[返回:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"unisolate %s",zone_id)==1){
		target_zone = find_admin_zone(me,zone_id);
		if(!target_zone){
			write("逻辑区不存在。\n[返回:mgr_logical_zone]\n");
			return 1;
		}
		if(!(int)target_zone["isolation"]){
			write(zone_id+" 已经处于合区状态。\n[返回:mgr_logical_zone view "+zone_id+"]\n");
			return 1;
		}
		write("确认恢复 "+zone_id+" 到 "+(string)target_zone["cluster"]+" 合区？\n");
		write("[确认恢复合区:mgr_logical_zone unisolate_confirm "+zone_id+"] ");
		write("[取消:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"unisolate_confirm %s",zone_id)==1){
		result = LOGICALZONED->admin_set_zone_field(me->query_name(),zone_id,"isolation",0);
		write(result_text(result)+"[返回:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"rollback %s",zone_id)==1){
		write("确认把 "+zone_id+" 的内容回滚到后台上一版？revision 会继续递增。\n");
		write("[确认:mgr_logical_zone rollback_confirm "+zone_id+"] ");
		write("[取消:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}
	if(sscanf(arg,"rollback_confirm %s",zone_id)==1){
		result = LOGICALZONED->admin_rollback_zone(me->query_name(),zone_id);
		write(result_text(result)+"[返回:mgr_logical_zone view "+zone_id+"]\n");
		return 1;
	}

	if(arg=="merge"){
		write("请输入：cluster 区号列表，例如 season_2026_08 xd06,xd07\n");
		write("[mgr_logical_zone merge_prepare ...]\n[返回:mgr_logical_zone]\n");
		return 1;
	}
	if(sscanf(arg,"merge_prepare %s %s",cluster,zone_csv)==2){
		me["/tmp/logical_zone_merge_cluster"] = cluster;
		me["/tmp/logical_zone_merge_zones"] = zone_csv;
		write("将先隔离目标区，再统一 cluster，最后解除隔离。\n");
		write("cluster="+cluster+"，区号="+zone_csv+"\n");
		write("[确认合区:mgr_logical_zone merge_confirm] [取消:mgr_logical_zone]\n");
		return 1;
	}
	if(arg=="merge_confirm"){
		cluster = (string)me["/tmp/logical_zone_merge_cluster"];
		zone_csv = (string)me["/tmp/logical_zone_merge_zones"];
		array(string) zones = zone_csv/","-({""});
		me["/tmp/logical_zone_merge_cluster"] = 0;
		me["/tmp/logical_zone_merge_zones"] = 0;
		if(sizeof(zones)<2){
			write("合区至少需要两个区。\n[返回:mgr_logical_zone]\n");
			return 1;
		}
		result = (["ok":1,"message":"合区完成"]);
		foreach(zones,string one_zone)
			if((int)result["ok"])
				result = LOGICALZONED->admin_set_zone_field(
					me->query_name(),one_zone,"isolation",1);
		foreach(zones,string one_zone)
			if((int)result["ok"])
				result = LOGICALZONED->admin_set_zone_field(
					me->query_name(),one_zone,"cluster",cluster);
		foreach(zones,string one_zone)
			if((int)result["ok"])
				result = LOGICALZONED->admin_set_zone_field(
					me->query_name(),one_zone,"isolation",0);
		write(result_text(result)+"[返回:mgr_logical_zone]\n");
		return 1;
	}

	write("未知管理操作。\n[返回:mgr_logical_zone]\n");
	return 1;
}
