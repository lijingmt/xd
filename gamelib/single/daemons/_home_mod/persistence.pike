/** 家园三份关联数据的分阶段原子保存与失败回滚。 */

#ifndef HOME_ATOMIC_PERSISTENCE_PIKE
#define HOME_ATOMIC_PERSISTENCE_PIKE

private int stage_home_snapshot_file(string path,string content)
{
	string temp_path = path+".tmp";
	rm(temp_path);
	if(!content || content=="")
		return 0;
	if(Stdio.write_file(temp_path,content)!=sizeof(content)){
		rm(temp_path);
		return 0;
	}
	return Stdio.file_size(temp_path)==sizeof(content);
}

private int backup_home_snapshot_file(string path)
{
	string backup_path = path+".bak";
	int live_size = Stdio.file_size(path);
	if(live_size<=0)
		return 0;
	if(!Stdio.cp(path,backup_path))
		return 0;
	return Stdio.file_size(backup_path)==live_size;
}

private int restore_home_snapshot_file(string path)
{
	string backup_path = path+".bak";
	string restore_path = path+".restore.tmp";
	int backup_size = Stdio.file_size(backup_path);
	rm(restore_path);
	if(backup_size<=0 || !Stdio.cp(backup_path,restore_path))
		return 0;
	if(Stdio.file_size(restore_path)!=backup_size || !mv(restore_path,path)){
		rm(restore_path);
		return 0;
	}
	return Stdio.file_size(path)==backup_size;
}

private void cleanup_home_snapshot_temps()
{
	rm(ROOT+HOME_INFO+".tmp");
	rm(ROOT+ROOM_MAP+".tmp");
	rm(ROOT+SHOPRCM_MAP+".tmp");
}

private int atomic_write_home_snapshot(string home_info,string room_map,
	string shop_map)
{
	string home_path = ROOT+HOME_INFO;
	string room_path = ROOT+ROOM_MAP;
	string shop_path = ROOT+SHOPRCM_MAP;
	int room_moved = 0;
	int shop_moved = 0;
	int home_moved = 0;
	int restored = 1;
	if(!stage_home_snapshot_file(home_path,home_info) ||
	   !stage_home_snapshot_file(room_path,room_map) ||
	   !stage_home_snapshot_file(shop_path,shop_map)){
		cleanup_home_snapshot_temps();
		werror("[HOMED-SAVE] 临时快照写入失败，保留旧数据\n");
		return 0;
	}
	if(!backup_home_snapshot_file(home_path) ||
	   !backup_home_snapshot_file(room_path) ||
	   !backup_home_snapshot_file(shop_path)){
		cleanup_home_snapshot_temps();
		werror("[HOMED-SAVE] 快照备份失败，保留旧数据\n");
		return 0;
	}
	if(mv(room_path+".tmp",room_path))
		room_moved = 1;
	if(room_moved && mv(shop_path+".tmp",shop_path))
		shop_moved = 1;
	// detail_home 是产权提交点，最后替换。
	if(room_moved && shop_moved && mv(home_path+".tmp",home_path))
		home_moved = 1;
	if(home_moved &&
	   Stdio.file_size(home_path)==sizeof(home_info) &&
	   Stdio.file_size(room_path)==sizeof(room_map) &&
	   Stdio.file_size(shop_path)==sizeof(shop_map)){
		cleanup_home_snapshot_temps();
		return 1;
	}
	if(room_moved && !restore_home_snapshot_file(room_path))
		restored = 0;
	if(shop_moved && !restore_home_snapshot_file(shop_path))
		restored = 0;
	if(home_moved && !restore_home_snapshot_file(home_path))
		restored = 0;
	cleanup_home_snapshot_temps();
	if(!restored)
		werror("[HOMED-SAVE] 快照提交失败且回滚不完整，请立即检查家园数据\n");
	else
		werror("[HOMED-SAVE] 快照提交失败，已恢复上一版\n");
	return 0;
}

#endif
