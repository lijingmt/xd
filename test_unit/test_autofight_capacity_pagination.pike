#!/usr/bin/env pike
/** 挂机容量分流、压力刷新与不可变分页快照回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[挂机容量] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[挂机容量] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string userid)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="挂机容量测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level=41;
	player->set_att_by_level();
	return player;
}

void destroy_test_room(object|zero room,object|zero player)
{
	if(!room)
		return;
	if(player && environment(player)==room)
		player->move(ROOT+"/gamelib/d/kunlunshan/wuge");
	array(object) all=all_inventory(room);
	for(int i=0;i<sizeof(all);i++)
		if(all[i] && all[i]!=player)
			destruct(all[i]);
	destruct(room);
}

void destroy_test_player(object|zero player)
{
	if(!player)
		return;
	array(object) all=all_inventory(player);
	for(int i=0;i<sizeof(all);i++)
		if(all[i])
			destruct(all[i]);
	destruct(player);
}

void test_pagination_snapshot(object player)
{
	object explorer=(object)(ROOT+"/lowlib/wapmud2/cmds/_explorer.pike");
	mapping spliter=player->query_spliter();
	string first_text=sprintf("第一页标记-%07000d-末页标记",1);
	spliter["header"]="快照头\n";
	spliter["text"]=first_text;
	spliter["footer"]="快照尾\n";
	string snapshot_id=player->cache_view_page_snapshot();
	spliter["text"]="挂机后来覆盖的新画面";
	mapping snapshot=player->query_view_page_snapshot(snapshot_id);
	mapping second_page=explorer->load_bytes("_snapshot/"+snapshot_id,
		6000,6000);
	check("挂机刷新后分页仍读取原始不可变快照",
		snapshot && (string)snapshot["text"]==first_text &&
		second_page && search((string)second_page["text"],"末页标记")!=-1,
		"spliter 覆盖后旧页面内容发生漂移");
	for(int i=0;i<6;i++){
		spliter["text"]="分页快照"+(string)i+sprintf("-%06100d",i);
		player->cache_view_page_snapshot();
	}
	mapping status=player->query_view_page_snapshot_status();
	check("多标签页分页快照保留且受总内存上限约束",
		player->query_view_page_snapshot(snapshot_id) &&
		(int)status["entries"]<=16 && (int)status["limit"]==16 &&
		(int)status["ttl_seconds"]==30*60 &&
		(int)status["max_bytes"]==512*1024 &&
		(int)status["total_bytes"]<=(int)status["total_bytes_limit"] &&
		(int)status["total_bytes_limit"]==2*1024*1024,
		sprintf("status=%O",status));
}

void test_command_token_diagnostics()
{
	object httpd=HTTP_APID;
	string userid="xd01testunitcapacitytoken";
	mapping before=httpd->query_hidden_command_status();
	string token=httpd->hide_command(userid,"_explorer _player/spliter 6000 0");
	string wrong=httpd->unhide_command("xd01wrongaccount",token);
	string missing=httpd->unhide_command(userid,
		"c_000000000000000000000000000000000000000000000000");
	mapping after=httpd->query_hidden_command_status();
	check("隐藏命令异常只累计匿名分类计数",
		wrong=="look" && missing=="look" &&
		(int)after["wrong_user"]==(int)before["wrong_user"]+1 &&
		(int)after["missing"]==(int)before["missing"]+1 &&
		(int)after["rejected"]==(int)before["rejected"]+2,
		sprintf("before=%O after=%O",before,after));
	httpd->clear_hidden_commands(userid);
}

void test_route_pool_integrity(object player)
{
	object daemon=AUTOFIGHTD;
	array(string) races=({"human","monst","third"});
	array(int) levels=({});
	array(string) failures=({});
	for(int level=1;level<=70;level++)
		levels+=({level});
	// 生产反馈覆盖97/101级混合大小写老账号，显式锁住两个等级路线。
	levels+=({97,99,101,500,989,990,999});
	for(int i=0;i<sizeof(races);i++){
		for(int j=0;j<sizeof(levels);j++){
			player->set_raceId(races[i]);
			player->level=levels[j];
			mapping route=daemon->query_training_route(player);
			array(string) paths=(array(string))route["paths"];
			if(!paths || sizeof(paths)<3 || sizeof(paths)>6 ||
			   search(paths,(string)route["path"])==-1){
				failures+=({races[i]+":"+(string)levels[j]+":pool"});
				continue;
			}
			for(int k=0;k<sizeof(paths);k++)
				if(!Stdio.exist(ROOT+"/gamelib/d/"+paths[k]))
					failures+=({races[i]+":"+(string)levels[j]+":"+paths[k]});
		}
	}
	check("全等级三阵营均有3至6个真实练级房间",
		!sizeof(failures),failures*" | ");
}

void test_low_level_monst_routes(object player)
{
	object daemon=AUTOFIGHTD;
	array(int) levels=({1,3,6,9,11,14});
	array(string) failures=({});
	for(int i=0;i<sizeof(levels);i++){
		object|zero room=0;
		player->set_raceId("monst");
		player->level=levels[i];
		player->set_att_by_level();
		mapping route=daemon->query_training_route(player);
		mixed err=catch{
			room=clone(ROOT+"/gamelib/d/"+(string)route["path"]);
			player->move(room);
			daemon->initialize_player(player);
			player["/plus/autofight_smart_route"]=1;
			object target=daemon->query_target(player);
			mapping window=daemon->query_target_level_window(player);
			if(!target || target->query_level()<(int)window["minimum"] ||
			   target->query_level()>(int)window["maximum"])
				failures+=({sprintf("level=%d path=%s target=%O window=%O",
					levels[i],(string)route["path"],target,window)});
		};
		if(err)
			failures+=({sprintf("level=%d error=%s",levels[i],
				describe_error(err))});
		destroy_test_room(room,player);
	}
	check("魔族1至16级推荐房不再高出安全攻击等级",
		!sizeof(failures),failures*" | ");
}

void test_balancing_and_no_target_reroute(object player)
{
	object daemon=AUTOFIGHTD;
	object room;
	string error_desc="";
	int valid=0;
	mixed err=catch{
		player->set_raceId("third");
		player->level=41;
		player->set_att_by_level();
		mapping route=daemon->query_training_route(player);
		room=clone(ROOT+"/gamelib/d/"+(string)route["path"]);
		player->move(room);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"]=1;
		mapping balanced=daemon->query_balanced_training_route(player,1);
		array(object) all=all_inventory(room);
		for(int i=0;i<sizeof(all);i++)
			if(all[i]!=player)
				destruct(all[i]);
		daemon->clear_no_target(player);
		daemon->record_no_target(player);
		daemon->record_no_target(player);
		int early=daemon->should_route_to_training_area(player,
			(["visible":0]));
		daemon->record_no_target(player);
		int ready=daemon->should_route_to_training_area(player,
			(["visible":0]));
		valid=(string)balanced["path"]!=(string)route["path"] &&
			(int)balanced["pool_size"]>=3 && !early && ready;
	};
	if(err)
		error_desc=describe_error(err);
	check("连续三轮无怪才改道且避开当前房间",
		!err && valid,error_desc);
	destroy_test_room(room,player);
}

void test_pressure_refresh_policy(object player)
{
	object room=clone(ROOT+"/gamelib/d/waihai/lingyicheng");
	mapping one=room->query_autofight_pressure_policy(1,0);
	mapping two=room->query_autofight_pressure_policy(2,0);
	mapping three=room->query_autofight_pressure_policy(3,0);
	mapping four=room->query_autofight_pressure_policy(4,0);
	mapping overflow=room->query_autofight_pressure_policy(1,1);
	mapping slots=room->query_autofight_spawn_status();
	string source=Stdio.read_file(ROOT+"/lowlib/mudlib/inherit/room.pike");
	check("人数越多普通怪补位从90秒缩短到60秒",
		!(int)one["enabled"] &&
		(int)two["refresh_seconds"]==90 && (int)two["budget"]==1 &&
		(int)three["refresh_seconds"]==75 && (int)three["budget"]==2 &&
		(int)four["refresh_seconds"]==60 && (int)four["budget"]==3 &&
		(int)overflow["enabled"] &&
		(int)slots["normal_slots"]>0,
		sprintf("one=%O two=%O three=%O four=%O overflow=%O slots=%O",
			one,two,three,four,overflow,slots));
	check("压力补位排除Boss精英任务召唤且不扩容槽位",
		source && search(source,"ob->_boss || ob->_tasknpc || ob->_meritocrat")!=-1 &&
		search(source,"functionp(ob->query_summon_type)")!=-1 &&
		search(source,"if(!one || sizeof(one)<5 || one[1]")!=-1,
		"普通怪分类或原槽位上限守卫缺失");
	destroy_test_room(room,player);
}

void test_overflow_limits()
{
	mapping status=AUTOFIGHTD->query_autofight_overflow_status();
	check("临时挂机房有数量上限和10分钟空闲回收",
		(int)status["global_limit"]==64 &&
		(int)status["per_pool_limit"]==8 &&
		(int)status["idle_seconds"]==10*60,
		sprintf("status=%O",status));
}

void test_server_scheduler_resilience()
{
	string source=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	mapping status=AUTOFIGHTD->query_autofight_performance_status();
	check("超过128名挂机用户时同一秒分片推进完整轮次",
		source && search(source,"server_autofight_cycle_remaining")!=-1 &&
		search(source,"call_out(run_server_autofight_tick,"+
			"queue_backoff ? 1 : 0)")!=-1 &&
		search(source,"server_autofight_cursor--")!=-1 &&
		search(source,"server_autofight_cycle_remaining++")!=-1 &&
		(int)status["server_scan_budget"]==128,
		"调度器仍会推迟128名后的玩家或在队列满时固定饿死尾部玩家");
	check("挂机世界命令超时后用独立请求号自愈且拒绝迟到回调",
		source && search(source,"server_autofight_inflight_started")!=-1 &&
		search(source,"next_server_autofight_request_id")!=-1 &&
		search(source,"server_autofight_inflight[userid]==request_id")!=-1 &&
		(int)status["server_inflight_timeout_seconds"]==30,
		"在途命令丢失后可能永久停止挂机或迟到回调覆盖新请求");
}

int main()
{
	object|zero original_player=this_player();
	object player=create_test_player("xd01testunitcapacity");
	werror("\n========== 挂机容量与分页快照测试 ==========\n");
	set_this_player(player);
	mixed err=catch{
		test_pagination_snapshot(player);
		test_command_token_diagnostics();
		test_route_pool_integrity(player);
		test_low_level_monst_routes(player);
		test_balancing_and_no_target_reroute(player);
		test_pressure_refresh_policy(player);
		test_overflow_limits();
		test_server_scheduler_resilience();
	};
	if(err)
		check("测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	destroy_test_player(player);
	werror("挂机容量测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
