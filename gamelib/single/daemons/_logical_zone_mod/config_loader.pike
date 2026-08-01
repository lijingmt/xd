/**
 * 逻辑分区配置加载器。
 * 只负责解析、校验和构建候选快照，不直接修改正在使用的状态。
 */

#ifndef LOGICAL_ZONE_CONFIG_LOADER_PIKE
#define LOGICAL_ZONE_CONFIG_LOADER_PIKE

private int unsigned_integer_value(string value)
{
	int i;
	if(!value || value=="")
		return 0;
	for(i=0;i<sizeof(value);i++)
		if(value[i]<'0' || value[i]>'9')
			return 0;
	return 1;
}

private int valid_cluster_id(string value)
{
	if(!value || value=="" || sizeof(value)>32)
		return 0;
	for(int i=0;i<sizeof(value);i++)
		if(!((value[i]>='a' && value[i]<='z') ||
		     (value[i]>='0' && value[i]<='9') ||
		     value[i]=='_' || value[i]=='-'))
			return 0;
	return 1;
}

private mapping(string:mixed) default_zone(string zone_id,int number)
{
	return ([
		"schema_version":LOGICAL_ZONE_CONFIG_SCHEMA,
		"revision":0,
		"zone_id":zone_id,
		"name":"原"+(string)number+"区",
		"enabled":1,
		"registration_open":1,
		"login_open":1,
		"isolation":0,
		"cluster":LOGICAL_ZONE_DEFAULT_CLUSTER,
		"sort":number,
		"open_at":0,
		"notes":"physical default",
		"source":"physical",
	]);
}

private mapping(string:mixed) query_physical_defaults()
{
	mapping(string:mapping(string:mixed)) result = ([]);
	string area = getenv("GAME_AREA") || GAME_AREA;
	int start_area = 1;
	int end_area = 1;
	int parsed;
	int i;
	if(!area || area=="")
		area = "xd01";
	area = lower_case(trim_zone_value(area));
	parsed = sscanf(area,"xd%d-%d",start_area,end_area);
	if(parsed!=2){
		parsed = sscanf(area,"xd%d",start_area);
		if(parsed!=1)
			start_area = 1;
		end_area = start_area;
	}
	if(start_area<1 || end_area<start_area || end_area>99){
		start_area = 1;
		end_area = 1;
	}
	for(i=start_area;i<=end_area;i++){
		string zone_id = "xd"+sprintf("%02d",i);
		result[zone_id] = default_zone(zone_id,i);
	}
	return (["zones":result,"area":area]);
}

private mapping(string:mixed) config_error(string message)
{
	return (["ok":0,"error":message]);
}

private mapping(string:mixed) parse_zone_config(string source,
	string expected_zone_id,string source_name)
{
	mapping(string:mixed) parsed = ([]);
	mapping(string:int) accepted = ([
		"schema_version":1,"revision":1,"zone_id":1,"name":1,
		"enabled":1,"registration_open":1,"login_open":1,
		"isolation":1,"cluster":1,"sort":1,"open_at":1,"notes":1,
	]);
	array(string) lines;
	int i;
	if(!source)
		return config_error(source_name+" 内容为空");
	lines = source/"\n";
	for(i=0;i<sizeof(lines);i++){
		string line = trim_zone_value(lines[i]);
		string key;
		string value;
		int separator;
		if(line=="" || line[0]=='#')
			continue;
		separator = search(line,"=");
		if(separator<=0)
			return config_error(source_name+":"+(string)(i+1)+
				" 缺少 key=value");
		key = line[..separator-1];
		value = line[separator+1..];
		key = lower_case(trim_zone_value(key));
		value = trim_zone_value(value);
		if(!accepted[key] || has_index(parsed,key))
			return config_error(source_name+":"+(string)(i+1)+
				" 未知或重复字段 "+key);
		parsed[key] = value;
	}
	foreach(({"schema_version","revision","zone_id","name","enabled",
		"registration_open","login_open","isolation","cluster"}),
		string required_name)
		if(!has_index(parsed,required_name))
			return config_error(source_name+" 缺少必填字段 "+required_name);
	if(!parsed["zone_id"] || normalize_zone_id((string)parsed["zone_id"])!=
	   expected_zone_id)
		return config_error(source_name+" 的 zone_id 必须与文件名一致");
	if(!parsed["name"] || trim_zone_value((string)parsed["name"])=="")
		return config_error(source_name+" 缺少 name");
	if((parsed["schema_version"] &&
	    !unsigned_integer_value((string)parsed["schema_version"])) ||
	   (parsed["revision"] &&
	    !unsigned_integer_value((string)parsed["revision"])) ||
	   (parsed["sort"] && !unsigned_integer_value((string)parsed["sort"])) ||
	   (parsed["open_at"] &&
	    !unsigned_integer_value((string)parsed["open_at"])))
		return config_error(source_name+" 包含非法非负整数");
	foreach(({"enabled","registration_open","login_open","isolation"}),
		string switch_name){
		if(parsed[switch_name] && parsed[switch_name]!="0" &&
		   parsed[switch_name]!="1")
			return config_error(source_name+" 的 "+switch_name+
				" 只能是 0 或 1");
	}
	parsed["schema_version"] =
		(int)((string)(parsed["schema_version"] || "1"));
	if((int)parsed["schema_version"]!=LOGICAL_ZONE_CONFIG_SCHEMA)
		return config_error(source_name+" 使用了不支持的 schema_version");
	parsed["revision"] = (int)((string)(parsed["revision"] || "0"));
	parsed["zone_id"] = expected_zone_id;
	parsed["name"] = trim_zone_value((string)parsed["name"]);
	parsed["cluster"] = lower_case(trim_zone_value((string)parsed["cluster"]));
	parsed["enabled"] = (int)((string)(parsed["enabled"] || "1"));
	parsed["registration_open"] =
		(int)((string)(parsed["registration_open"] || "1"));
	parsed["login_open"] = (int)((string)(parsed["login_open"] || "1"));
	parsed["isolation"] = (int)((string)(parsed["isolation"] || "1"));
	parsed["sort"] = (int)((string)(parsed["sort"] || "999"));
	parsed["open_at"] = (int)((string)(parsed["open_at"] || "0"));
	parsed["notes"] = trim_zone_value((string)(parsed["notes"] || ""));
	parsed["source"] = source_name;
	if(!valid_cluster_id((string)parsed["cluster"]))
		return config_error(source_name+
			" 的 cluster 只能包含小写字母、数字、下划线或连字符");
	if(sizeof((string)parsed["name"])>64 || sizeof((string)parsed["notes"])>256)
		return config_error(source_name+" 的名称或备注过长");
	return (["ok":1,"config":parsed,"error":""]);
}

/** 纯解析测试入口，不影响线上快照。 */
mapping(string:mixed) parse_config_for_test(string source,
	string expected_zone_id)
{
	expected_zone_id = normalize_zone_id(expected_zone_id);
	if(expected_zone_id=="")
		return config_error("测试区号不合法");
	return parse_zone_config(source,expected_zone_id,"test.conf");
}

private mapping(string:mixed) build_zone_snapshot()
{
	mapping(string:mixed) physical = query_physical_defaults();
	mapping(string:mapping(string:mixed)) snapshot = physical["zones"];
	array(string)|zero files = get_dir(LOGICAL_ZONE_DIR);
	array(string) configs = ({});
	string signature = "physical="+(string)physical["area"]+"\n";
	int i;
	if(files)
		for(i=0;i<sizeof(files);i++)
			if(has_suffix(files[i],".conf"))
				configs += ({files[i]});
	sort(configs);
	if(sizeof(configs)>LOGICAL_ZONE_MAX_CONFIG_FILES)
		return config_error("逻辑区配置文件超过上限 "+
			(string)LOGICAL_ZONE_MAX_CONFIG_FILES);
	for(i=0;i<sizeof(configs);i++){
		string file_name = configs[i];
		string file_path = LOGICAL_ZONE_DIR+"/"+file_name;
		string zone_id = normalize_zone_id(
			file_name[0..sizeof(file_name)-6]);
		string source;
		Stdio.Stat stat;
		mapping(string:mixed) parsed;
		if(zone_id=="")
			return config_error(file_name+" 不是合法的四位区号文件名");
		stat = file_stat(file_path);
		if(!stat || !stat->isreg)
			return config_error(file_name+" 不是普通配置文件");
		if(stat->size>LOGICAL_ZONE_MAX_CONFIG_SIZE)
			return config_error(file_name+" 超过单文件大小上限 "+
				(string)LOGICAL_ZONE_MAX_CONFIG_SIZE+" 字节");
		source = Stdio.read_file(file_path);
		if(!source)
			return config_error("无法读取 "+file_name);
		signature += file_name+"\n"+source+"\n";
		parsed = parse_zone_config(source,zone_id,file_name);
		if(!(int)parsed["ok"])
			return parsed;
		snapshot[zone_id] = parsed["config"];
	}
	return ([
		"ok":1,
		"snapshot":snapshot,
		"signature":signature,
		"error":"",
	]);
}

#endif
