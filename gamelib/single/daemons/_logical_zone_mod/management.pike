/** 管理后台配置服务：权限校验、规范化序列化、备份、原子替换和失败回滚。 */

#ifndef LOGICAL_ZONE_MANAGEMENT_PIKE
#define LOGICAL_ZONE_MANAGEMENT_PIKE

private mapping(string:mixed) admin_zone_result(int ok,string message)
{
	return (["ok":ok,"message":message]);
}

private int logical_zone_admin_allowed(string operator_id)
{
	return operator_id && MANAGERD->checkpower(operator_id)=="admin";
}

private string serialize_zone_config(mapping(string:mixed) zone)
{
	return "schema_version="+(string)zone["schema_version"]+"\n"+
		"revision="+(string)zone["revision"]+"\n"+
		"zone_id="+(string)zone["zone_id"]+"\n"+
		"name="+(string)zone["name"]+"\n"+
		"enabled="+(string)zone["enabled"]+"\n"+
		"registration_open="+(string)zone["registration_open"]+"\n"+
		"login_open="+(string)zone["login_open"]+"\n"+
		"isolation="+(string)zone["isolation"]+"\n"+
		"cluster="+(string)zone["cluster"]+"\n"+
		"sort="+(string)zone["sort"]+"\n"+
		"open_at="+(string)zone["open_at"]+"\n"+
		"notes="+(string)zone["notes"]+"\n";
}

private void log_zone_admin_action(string operator_id,string action,
	string zone_id,int revision)
{
	string now = ctime(time());
	Stdio.append_file(ROOT+"/log/logical_zone_admin.log",
		now[0..sizeof(now)-2]+"|operator="+operator_id+"|action="+action+
		"|zone="+zone_id+"|revision="+(string)revision+"\n");
}

private mapping(string:mixed) write_admin_zone_config(string operator_id,
	mapping(string:mixed) candidate,string action,int create_only)
{
	string zone_id = normalize_zone_id((string)candidate["zone_id"]);
	string config_path;
	string temp_path;
	string backup_path;
	string source;
	mapping(string:mixed) parsed;
	object admin_key;
	int had_live;
	int live_size;
	int rollback_ok;
	string live_source;
	mapping(string:mixed) live_parsed;
	int ok = 0;
	mixed err;
	if(!logical_zone_admin_allowed(operator_id))
		return admin_zone_result(0,"管理员权限不足");
	if(zone_id=="")
		return admin_zone_result(0,"区号必须是两位小写字母加两位数字");
	candidate["zone_id"] = zone_id;
	source = serialize_zone_config(candidate);
	parsed = parse_zone_config(source,zone_id,"admin.conf");
	if(!(int)parsed["ok"])
		return admin_zone_result(0,"配置校验失败："+(string)parsed["error"]);
	if(sizeof(source)>LOGICAL_ZONE_MAX_CONFIG_SIZE)
		return admin_zone_result(0,"配置超过大小上限");

	admin_key = logical_zone_admin_lock->lock();
	config_path = LOGICAL_ZONE_DIR+"/"+zone_id+".conf";
	temp_path = LOGICAL_ZONE_DIR+"/."+zone_id+".admin.tmp";
	backup_path = config_path+".bak";
	had_live = Stdio.file_size(config_path)>0;
	if(create_only && had_live){
		destruct(admin_key);
		return admin_zone_result(0,"该逻辑区配置已经存在");
	}
	if(had_live && !create_only){
		live_source = Stdio.read_file(config_path);
		live_parsed = parse_zone_config(live_source,zone_id,"live.conf");
		if(!(int)live_parsed["ok"] ||
		   (int)candidate["revision"]!=
		   (int)live_parsed["config"]["revision"]+1){
			destruct(admin_key);
			return admin_zone_result(0,"配置已被其他管理员更新，请刷新后重试");
		}
	}
	err = catch{
		rm(temp_path);
		if(Stdio.write_file(temp_path,source)==sizeof(source)){
			if(had_live){
				live_size = Stdio.file_size(config_path);
				if(Stdio.cp(config_path,backup_path) &&
				   Stdio.file_size(backup_path)==live_size &&
				   mv(temp_path,config_path))
					ok = 1;
			}
			else if(mv(temp_path,config_path))
				ok = 1;
		}
	};
	if(err || !ok){
		rm(temp_path);
		destruct(admin_key);
		return admin_zone_result(0,"配置原子写入失败");
	}
	if(!reload_zone_configs(1)){
		if(had_live && Stdio.file_size(backup_path)>0){
			if(Stdio.cp(backup_path,temp_path) &&
			   Stdio.file_size(temp_path)==Stdio.file_size(backup_path) &&
			   mv(temp_path,config_path))
				rollback_ok = 1;
		}
		else{
			rm(config_path);
			rollback_ok = Stdio.file_size(config_path)<=0;
		}
		destruct(admin_key);
		reload_zone_configs(1);
		if(!rollback_ok){
			werror("[LOGICALZONED] 管理后台配置回滚失败: %s\n",zone_id);
			return admin_zone_result(0,"完整快照失败且文件回滚失败，请立即检查服务端日志");
		}
		return admin_zone_result(0,"完整快照校验失败，已自动恢复上一版");
	}
	log_zone_admin_action(operator_id,action,zone_id,(int)candidate["revision"]);
	destruct(admin_key);
	return admin_zone_result(1,"操作成功，配置已热加载");
}

array(mapping(string:mixed)) admin_query_partitions(string operator_id)
{
	array(mapping(string:mixed)) result = ({});
	mapping(string:mapping(string:mixed)) snapshot = logical_zones;
	array(string) zone_ids;
	if(!logical_zone_admin_allowed(operator_id))
		return result;
	zone_ids = indices(snapshot);
	sort(zone_ids);
	foreach(zone_ids,string zone_id)
		result += ({copy_value(snapshot[zone_id])});
	return result;
}

mapping(string:mixed) admin_create_zone(string operator_id,string zone_id,
	string zone_name,int sort_order)
{
	mapping(string:mixed) candidate;
	zone_id = normalize_zone_id(zone_id);
	if(zone_id=="" || !zone_name || trim_zone_value(zone_name)=="" ||
	   sort_order<0)
		return admin_zone_result(0,"新区参数不合法");
	candidate = ([
		"schema_version":LOGICAL_ZONE_CONFIG_SCHEMA,
		"revision":1,
		"zone_id":zone_id,
		"name":trim_zone_value(zone_name),
		"enabled":1,
		"registration_open":0,
		"login_open":0,
		"isolation":1,
		"cluster":LOGICAL_ZONE_DEFAULT_CLUSTER,
		"sort":sort_order,
		"open_at":0,
		"notes":"由管理后台安全创建，待验证后开放",
	]);
	return write_admin_zone_config(operator_id,candidate,"create",1);
}

mapping(string:mixed) admin_set_zone_field(string operator_id,string zone_id,
	string field,mixed value)
{
	mapping(string:mixed)|zero current;
	mapping(string:mixed) candidate;
	mapping(string:int) accepted = ([
		"name":1,"enabled":1,"registration_open":1,"login_open":1,
		"isolation":1,"cluster":1,"sort":1,"open_at":1,"notes":1,
	]);
	zone_id = normalize_zone_id(zone_id);
	field = lower_case(trim_zone_value(field));
	if(!logical_zone_admin_allowed(operator_id))
		return admin_zone_result(0,"管理员权限不足");
	if(zone_id=="" || !accepted[field])
		return admin_zone_result(0,"区号或字段不合法");
	current = query_zone_snapshot_entry(zone_id);
	if(!current)
		return admin_zone_result(0,"逻辑区不存在");
	candidate = copy_value(current);
	candidate[field] = value;
	candidate["revision"] = (int)candidate["revision"]+1;
	candidate["source"] = "admin";
	return write_admin_zone_config(operator_id,candidate,"set_"+field,0);
}

mapping(string:mixed) admin_rollback_zone(string operator_id,string zone_id)
{
	string backup_source;
	mapping(string:mixed) parsed;
	mapping(string:mixed)|zero current;
	mapping(string:mixed) candidate;
	if(!logical_zone_admin_allowed(operator_id))
		return admin_zone_result(0,"管理员权限不足");
	zone_id = normalize_zone_id(zone_id);
	if(zone_id=="")
		return admin_zone_result(0,"区号不合法");
	backup_source = Stdio.read_file(
		LOGICAL_ZONE_DIR+"/"+zone_id+".conf.bak");
	if(!backup_source)
		return admin_zone_result(0,"没有可回滚的后台备份");
	parsed = parse_zone_config(backup_source,zone_id,"rollback.conf");
	if(!(int)parsed["ok"])
		return admin_zone_result(0,"备份配置校验失败");
	current = query_zone_snapshot_entry(zone_id);
	if(!current)
		return admin_zone_result(0,"当前逻辑区不存在");
	candidate = copy_value(parsed["config"]);
	// 回滚内容但不倒退审计序号，避免旧页面绕过 revision 冲突检查。
	candidate["revision"] = (int)current["revision"]+1;
	candidate["notes"] = "后台回滚："+(string)candidate["notes"];
	return write_admin_zone_config(operator_id,candidate,"rollback",0);
}

#endif
