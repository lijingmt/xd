/**
 * 家园固定产权区索引。
 *
 * 旧 homeId/home_path 保持不变；产权唯一键由主人账号区号和旧地块路径组合。
 * 新家园使用“区号@旧路径”作为稳定引用，合区只影响可见性，不迁移产权。
 */

#ifndef HOME_LOGICAL_ZONE_PIKE
#define HOME_LOGICAL_ZONE_PIKE

private string home_zone_id_for_owner(string owner_id)
{
	string zone_id = LOGICALZONED->query_user_zone_id(owner_id);
	if(zone_id=="")
		return "legacy";
	return zone_id;
}

string query_home_plot_path(string home_ref)
{
	string zone_id = "";
	string plot_path = "";
	if(!home_ref || home_ref=="")
		return "";
	if(sscanf(home_ref,"%s@%s",zone_id,plot_path)==2 &&
	   plot_path!="" &&
	   (zone_id=="legacy" || LOGICALZONED->normalize_zone_id(zone_id)!=""))
		return plot_path;
	return home_ref;
}

private string home_zone_key(string zone_id,string home_ref)
{
	string plot_path = query_home_plot_path(home_ref);
	if(zone_id=="" || plot_path=="")
		return "";
	return zone_id+"@"+plot_path;
}

string query_home_reference_by_masterId(string master_id)
{
	home he = homeDetail[master_id];
	if(!he)
		return "";
	return home_zone_key(home_zone_id_for_owner(master_id),he->homeId);
}

private void sync_legacy_home_map_plot(string plot_path)
{
	homeList hl = homeMap[plot_path];
	array(string) owners = homePlotOwners[plot_path] || ({});
	string selected = "";
	if(!hl)
		return;
	if(sizeof(owners)){
		owners = sort(owners);
		selected = owners[0];
		for(int i=0;i<sizeof(owners);i++){
			home he = homeDetail[owners[i]];
			if(he && he->homeId==plot_path){
				selected = owners[i];
				break;
			}
		}
		hl->isUsed = 1;
		hl->masterId = selected;
	}
	else{
		hl->isUsed = 0;
		hl->masterId = "";
	}
	homeMap[plot_path] = hl;
}

private int add_home_zone_index(home he)
{
	string master_id;
	string zone_id;
	string plot_path;
	string zone_key;
	array(string) owners;
	if(!he || !he->masterId || he->masterId=="")
		return 0;
	master_id = he->masterId;
	zone_id = home_zone_id_for_owner(master_id);
	plot_path = query_home_plot_path(he->homeId);
	zone_key = home_zone_key(zone_id,plot_path);
	if(zone_key=="" || !homeMap[plot_path])
		return 0;
	if(homeZoneOwners[zone_key] && homeZoneOwners[zone_key]!=master_id)
		return 0;
	homeZoneOwners[zone_key] = master_id;
	owners = homePlotOwners[plot_path] || ({});
	if(search(owners,master_id)==-1)
		owners += ({master_id});
	homePlotOwners[plot_path] = owners;
	masterMap[he->homeId] = master_id;
	masterMap[zone_key] = master_id;
	sync_legacy_home_map_plot(plot_path);
	return 1;
}

private void remove_home_zone_index(string master_id,string home_ref)
{
	string plot_path = query_home_plot_path(home_ref);
	string zone_key = home_zone_key(
		home_zone_id_for_owner(master_id),plot_path);
	array(string) owners = homePlotOwners[plot_path] || ({});
	if(homeZoneOwners[zone_key]==master_id)
		m_delete(homeZoneOwners,zone_key);
	owners -= ({master_id});
	if(sizeof(owners))
		homePlotOwners[plot_path] = owners;
	else
		m_delete(homePlotOwners,plot_path);
	if(masterMap[home_ref]==master_id)
		m_delete(masterMap,home_ref);
	if(masterMap[zone_key]==master_id)
		m_delete(masterMap,zone_key);
	sync_legacy_home_map_plot(plot_path);
}

private void rebuild_home_zone_index()
{
	array(string) masters = sort(indices(homeDetail));
	homeZoneOwners = ([]);
	homePlotOwners = ([]);
	masterMap = ([]);
	homeZoneIndexErrors = 0;
	// detail_home 是产权提交点：先清空 map_home 的派生占用状态，
	// 可自动修复“进程在三文件提交中途退出”留下的幽灵占用。
	foreach(indices(homeMap),string plot_path){
		homeList hl = homeMap[plot_path];
		if(hl){
			hl->isUsed = 0;
			hl->masterId = "";
			homeMap[plot_path] = hl;
		}
	}
	for(int i=0;i<sizeof(masters);i++){
		home he = homeDetail[masters[i]];
		if(!add_home_zone_index(he)){
			homeZoneIndexErrors++;
			werror("[HOMED-ZONE] 无法建立产权索引: master=%s home=%s\n",
				masters[i],he ? he->homeId : "");
		}
	}
	werror("[HOMED-ZONE] 产权索引完成: homes=%d plots=%d errors=%d\n",
		sizeof(homeZoneOwners),sizeof(homePlotOwners),homeZoneIndexErrors);
}

private string select_home_owner_from_candidates(string viewer_id,
	string plot_path,mapping(string:string) zone_owners,
	array(string) owners)
{
	string zone_key;
	if(viewer_id && viewer_id!=""){
		zone_key = home_zone_key(home_zone_id_for_owner(viewer_id),plot_path);
		if(zone_owners[zone_key])
			return zone_owners[zone_key];
	}
	if(sizeof(owners)==1)
		return owners[0];
	return "";
}

string query_masterId_by_zone_path(string path,string viewer_id)
{
	string zone_id = "";
	string plot_path = "";
	string zone_key = "";
	array(string) owners;
	if(!path || path=="")
		return "";
	if(sscanf(path,"%s@%s",zone_id,plot_path)==2 &&
	   plot_path!="" &&
	   (zone_id=="legacy" || LOGICALZONED->normalize_zone_id(zone_id)!="")){
		zone_key = home_zone_key(zone_id,plot_path);
		return homeZoneOwners[zone_key] || "";
	}
	plot_path = query_home_plot_path(path);
	owners = homePlotOwners[plot_path] || ({});
	return select_home_owner_from_candidates(
		viewer_id,plot_path,homeZoneOwners,owners);
}

string query_native_home_owner(string viewer_id,string plot_path)
{
	string zone_key = home_zone_key(
		home_zone_id_for_owner(viewer_id),plot_path);
	return homeZoneOwners[zone_key] || "";
}

array(string) query_visible_home_owners(string viewer_id,string plot_path)
{
	array(string) result = ({});
	array(string) owners = homePlotOwners[plot_path] || ({});
	owners = sort(owners);
	for(int i=0;i<sizeof(owners);i++)
		if(LOGICALZONED->can_user_action("home",viewer_id,owners[i]))
			result += ({owners[i]});
	return result;
}

string query_home_zone_label(string master_id)
{
	string zone_id = home_zone_id_for_owner(master_id);
	if(zone_id=="legacy")
		return "老区街区";
	return upper_case(zone_id)+"街区";
}

mapping(string:mixed) query_home_zone_audit()
{
	int legacy_count = 0;
	int invalid_count = 0;
	int resolvable_count = 0;
	int multi_owner_plot_count = 0;
	int orphan_plot_count = 0;
	array(string) masters = indices(homeDetail);
	for(int i=0;i<sizeof(masters);i++){
		home he = homeDetail[masters[i]];
		if(he && search(he->homeId,"@")==-1)
			legacy_count++;
		if(!he || !homeMap[query_home_plot_path(he->homeId)])
			invalid_count++;
		if(he &&
		   query_masterId_by_zone_path(he->homeId,masters[i])==masters[i] &&
		   query_masterId_by_zone_path(
			query_home_reference_by_masterId(masters[i]),masters[i])==masters[i])
			resolvable_count++;
	}
	foreach(indices(homePlotOwners),string plot_path)
		if(sizeof(homePlotOwners[plot_path])>1)
			multi_owner_plot_count++;
	foreach(indices(homeMap),string plot_path){
		homeList hl = homeMap[plot_path];
		if(hl && hl->isUsed && !sizeof(homePlotOwners[plot_path] || ({})))
			orphan_plot_count++;
	}
	return ([
		"home_count":sizeof(homeDetail),
		"zone_key_count":sizeof(homeZoneOwners),
		"plot_count":sizeof(homePlotOwners),
		"legacy_count":legacy_count,
		"invalid_count":invalid_count,
		"collision_count":homeZoneIndexErrors,
		"resolvable_count":resolvable_count,
		"multi_owner_plot_count":multi_owner_plot_count,
		"orphan_plot_count":orphan_plot_count,
	]);
}

string home_plot_path_for_test(string home_ref)
{
	return query_home_plot_path(home_ref);
}

string home_zone_key_for_test(string owner_id,string home_ref)
{
	return home_zone_key(home_zone_id_for_owner(owner_id),home_ref);
}

string resolve_home_candidates_for_test(string viewer_id,string plot_path,
	mapping(string:string) zone_owners,array(string) owners)
{
	return select_home_owner_from_candidates(
		viewer_id,plot_path,zone_owners,owners);
}

#endif
