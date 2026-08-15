/**
 * 逻辑分区隔离策略。
 * isolation=1 使用独立 zone 组；isolation=0 使用 cluster 组，因此合区/拆区可逆。
 */

#ifndef LOGICAL_ZONE_POLICY_PIKE
#define LOGICAL_ZONE_POLICY_PIKE

private mapping(string:mixed)|zero query_zone_snapshot_entry(string zone_id)
{
	// logical_zones 只会整表替换，发布后绝不原地修改；热点读取无需争抢 mutex。
	mapping(string:mapping(string:mixed)) snapshot = logical_zones;
	return snapshot[zone_id];
}

private string group_from_zone(mapping(string:mixed)|zero zone,string zone_id)
{
	// 未配置或已关闭的合法区号失败关闭，绝不意外落入老区共享组。
	if(!zone || !(int)zone["enabled"])
		return "zone:"+zone_id;
	if((int)zone["isolation"])
		return "zone:"+zone_id;
	return "cluster:"+(string)zone["cluster"];
}

/** 纯策略测试入口，不修改线上配置。 */
string query_group_for_test(mapping(string:mixed) zone,string zone_id)
{
	zone_id = normalize_zone_id(zone_id);
	if(zone_id=="")
		return "";
	return group_from_zone(zone,zone_id);
}

string query_user_group(string user_id)
{
	string illusion_group = SEASONALD->query_character_group(user_id);
	if(illusion_group!="")
		return illusion_group;
	string zone_id = query_user_zone_id(user_id);
	if(zone_id=="")
		return "legacy:main";
	return group_from_zone(query_zone_snapshot_entry(zone_id),zone_id);
}

int registration_allowed(string zone_id)
{
	mapping(string:mixed)|zero zone;
	zone_id = normalize_zone_id(zone_id);
	if(zone_id=="")
		return 0;
	zone = query_zone_snapshot_entry(zone_id);
	if(!zone || !(int)zone["enabled"] || !(int)zone["registration_open"])
		return 0;
	return (int)zone["open_at"]<=0 || (int)zone["open_at"]<=time();
}

int login_allowed(string user_id)
{
	string zone_id = query_user_zone_id(user_id);
	mapping(string:mixed)|zero zone;
	if(zone_id=="")
		return 1;
	zone = query_zone_snapshot_entry(zone_id);
	if(!zone)
		return 0;
	return (int)zone["enabled"] && (int)zone["login_open"] &&
		((int)zone["open_at"]<=0 || (int)zone["open_at"]<=time());
}

array(mapping(string:mixed)) query_public_partitions()
{
	array(mapping(string:mixed)) result = ({});
	mapping(string:mapping(string:mixed)) snapshot = logical_zones;
	array(string) zone_ids;
	zone_ids = indices(snapshot);
	for(int i=0;i<sizeof(zone_ids);i++){
		mapping(string:mixed) zone = snapshot[zone_ids[i]];
		if((int)zone["enabled"] &&
		   ((int)zone["open_at"]<=0 || (int)zone["open_at"]<=time()))
			result += ({([
				"value":zone_ids[i],
				"label":(string)zone["name"],
				"login_open":(int)zone["login_open"],
				"registration_open":(int)zone["registration_open"],
				"sort":(int)zone["sort"],
			])});
	}
	// 新区优先展示：sort 最大的区排最前，同 sort 时区号大的排最前。
	for(int left=0;left<sizeof(result);left++)
		for(int right=left+1;right<sizeof(result);right++)
			if((int)result[right]["sort"]>(int)result[left]["sort"] ||
			   ((int)result[right]["sort"]==(int)result[left]["sort"] &&
			    (string)result[right]["value"]>(string)result[left]["value"])){
				mapping(string:mixed) swap = result[left];
				result[left] = result[right];
				result[right] = swap;
			}
	return result;
}

#endif
