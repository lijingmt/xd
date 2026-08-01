#!/usr/bin/env pike
/** 同进程逻辑分区的配置、策略、隔离边界和可逆操作回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	werror("\n[逻辑分区 %d] %s\n",results["total"],name);
	if(valid){
		results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

string valid_config(string zone_id,string isolation,string cluster)
{
	return "schema_version=1\nrevision=7\nzone_id="+zone_id+
		"\nname=测试区\nenabled=1\nregistration_open=1\n"+
		"login_open=1\nisolation="+isolation+"\ncluster="+cluster+
		"\nsort=7\nopen_at=0\nnotes=unit test\n";
}

void test_config_schema(object daemon)
{
	mapping parsed = daemon->parse_config_for_test(
		valid_config("xd06","1","main"),"xd06");
	mapping config = parsed["config"] || ([]);
	int valid = parsed["ok"]==1 && config["zone_id"]=="xd06" &&
		config["schema_version"]==1 && config["revision"]==7 &&
		config["isolation"]==1 && config["cluster"]=="main";
	check("版本化配置可完整解析",valid,"配置字段、类型或默认值错误");

	mapping mismatch = daemon->parse_config_for_test(
		valid_config("xd07","1","main"),"xd06");
	mapping duplicate = daemon->parse_config_for_test(
		valid_config("xd06","1","main")+"enabled=0\n","xd06");
	mapping bad_switch = daemon->parse_config_for_test(
		replace(valid_config("xd06","1","main"),
			"isolation=1","isolation=2"),"xd06");
	mapping bad_schema = daemon->parse_config_for_test(
		replace(valid_config("xd06","1","main"),
			"schema_version=1","schema_version=2"),"xd06");
	mapping bad_cluster = daemon->parse_config_for_test(
		replace(valid_config("xd06","1","main"),
			"cluster=main","cluster=bad cluster"),"xd06");
	mapping notes_equals = daemon->parse_config_for_test(
		replace(valid_config("xd06","1","main"),
			"notes=unit test","notes=rollback=revision6"),"xd06");
	mapping missing_required = daemon->parse_config_for_test(
		"zone_id=xd06\nname=漏字段区\n","xd06");
	check("错配、重复、非法开关/版本/cluster拒绝且备注支持等号",
		!mismatch["ok"] && !duplicate["ok"] &&
		!bad_switch["ok"] && !bad_schema["ok"] &&
		!bad_cluster["ok"] && notes_equals["ok"] &&
		!missing_required["ok"],
		"非法配置可能进入候选快照");
}

void test_deployment_seed_configs(object daemon)
{
	mapping(string:int) expected_isolation = ([
		"xd01":0,"xd02":0,"xd03":1,
	]);
	int valid = 1;
	foreach(indices(expected_isolation),string zone_id){
		string source = Stdio.read_file(ROOT+
			"/deploy/logical_zones/"+zone_id+".conf");
		mapping parsed = daemon->parse_config_for_test(source || "",zone_id);
		mapping config = parsed["config"] || ([]);
		if(!parsed["ok"] || config["zone_id"]!=zone_id ||
		   config["isolation"]!=expected_isolation[zone_id] ||
		   config["cluster"]!="main")
			valid = 0;
	}
	check("首装一区、二区合区且三区隔离的种子配置可解析",valid,
		"生产首次部署种子缺失、非法或隔离关系错误");
}

void test_reversible_policy(object daemon)
{
	mapping isolated_a = daemon->parse_config_for_test(
		valid_config("xd06","1","main"),"xd06")["config"];
	mapping isolated_b = daemon->parse_config_for_test(
		valid_config("xd07","1","main"),"xd07")["config"];
	mapping merged_a = daemon->parse_config_for_test(
		valid_config("xd06","0","season_one"),"xd06")["config"];
	mapping merged_b = daemon->parse_config_for_test(
		valid_config("xd07","0","season_one"),"xd07")["config"];
	string isolated_group_a = daemon->query_group_for_test(isolated_a,"xd06");
	string isolated_group_b = daemon->query_group_for_test(isolated_b,"xd07");
	string merged_group_a = daemon->query_group_for_test(merged_a,"xd06");
	string merged_group_b = daemon->query_group_for_test(merged_b,"xd07");
	check("独立区、在线合区和恢复隔离只切换策略组",
		isolated_group_a=="zone:xd06" &&
		isolated_group_b=="zone:xd07" &&
		isolated_group_a!=isolated_group_b &&
		merged_group_a=="cluster:season_one" &&
		merged_group_a==merged_group_b &&
		daemon->query_group_for_test(isolated_a,"xd06")==isolated_group_a,
		"隔离/合并策略不可逆或依赖账号迁移");
}

void test_runtime_fail_closed(object daemon)
{
	array partitions = daemon->query_public_partitions();
	mapping status = daemon->query_status();
	int valid = sizeof(partitions)>=1 && status["generation"]>=1 &&
		daemon->registration_allowed("xd99")==0 &&
		daemon->login_allowed("xd99testunit")==0 &&
		daemon->can_user_interact("xd98one","xd99two")==0 &&
		daemon->can_user_interact("xd98one","xd98two")==1 &&
		daemon->can_user_interact("xd98one","xd99jinghaha")==0 &&
		daemon->can_user_interact("xd98mumu215","xd99two")==1 &&
		daemon->can_user_interact("","xd98two")==0 &&
		daemon->can_user_action("unknown","xd98one","xd98two")==0 &&
		daemon->can_user_action("chat","xd98one","xd99jinghaha")==1 &&
		has_value(daemon->query_capabilities(),"combat");
	check("未知区号失败关闭且同区身份稳定",valid,
		"伪造区号可能注册、登录或跨区交互");
}

int source_has(string path,string needle)
{
	string source = Stdio.read_file(ROOT+path);
	return source && search(source,needle)!=-1;
}

void test_visual_and_combat_boundaries()
{
	int valid = source_has("/lowlib/efuns.pike","zoned->is_visible") &&
		source_has("/lowlib/system/inherit/user.pike",
			"all_inventory(ob,this_object())") &&
		source_has("/lowlib/wapmud2/inherit/feature/fight.pike",
			"LOGICALZONED->can_action(\"combat\"") &&
		source_has("/gamelib/single/daemons/http_api_daemon.pike",
			"all_inventory(room,player)") &&
		source_has("/gamelib/cmds/whoa.pike",
			"LOGICALZONED->can_interact(me,all_users[j])");
	check("房间、HTTP战斗窗、攻击和在线列表均执行视觉隔离",valid,
		"玩家或战斗目标仍可能从旧显示入口泄漏");
}

object create_zone_test_player(string user_id)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(user_id);
	player->name_cn = user_id;
	player->set_project("gamelib");
	if(!player->setup("testunit-only")){
		destruct(player);
		return 0;
	}
	return player;
}

void test_runtime_visual_isolation(object daemon)
{
	object first = create_zone_test_player("xd98zoneviewer");
	object second = create_zone_test_player("xd99zonetarget");
	object same_zone = create_zone_test_player("xd98zonefriend");
	object admin = create_zone_test_player("xd99jinghaha");
	int valid = first && second && same_zone && admin &&
		environment(first) && environment(first)==environment(second) &&
		environment(first)==environment(same_zone) &&
		member_array(second,all_inventory(environment(first),first))==-1 &&
		member_array(same_zone,all_inventory(environment(first),first))!=-1 &&
		visible(second,first)==0 && visible(same_zone,first)==1 &&
		daemon->can_interact(first,second)==0 &&
		daemon->can_interact(first,admin)==0 &&
		daemon->can_interact(admin,first)==1;
	check("同一真实房间内跨区玩家实际不可见且管理员旁路具有方向",valid,
		"运行时对象过滤与纯策略不一致");
	if(first) destruct(first);
	if(second) destruct(second);
	if(same_zone) destruct(same_zone);
	if(admin) destruct(admin);
}

void test_drop_zone_ownership(object daemon)
{
	object first = create_zone_test_player("xd98dropowner");
	object second = create_zone_test_player("xd99dropviewer");
	object item;
	int valid = 0;
	mixed err = catch{
		item = clone(ITEM_PATH+"other/liujinshi");
	};
	if(!err && first && second && item && environment(first)){
		item->set_item_logical_zone_owner(first->query_name());
		item->item_whoCanGet = first->query_name();
		item->move(environment(first));
		valid = daemon->can_action("drop",first,item)==1 &&
			daemon->can_action("drop",second,item)==0;
		item->item_whoCanGet = "1";
		valid = valid && daemon->can_action("drop",second,item)==0;
	}
	check("掉落保护过期后仍永久保持逻辑区归属",valid,
		"item_whoCanGet 变为通用值后可能跨区拾取");
	if(item) destruct(item);
	if(first) destruct(first);
	if(second) destruct(second);
}

void test_public_and_admin_management_contracts(object daemon)
{
	mapping public_status = daemon->query_public_status();
	array partitions = daemon->query_public_partitions();
	mapping first = sizeof(partitions) ? partitions[0] : ([]);
	mapping denied = daemon->admin_create_zone(
		"xd98ordinary","xd97","未授权测试区",97);
	int valid = !has_index(public_status,"last_error") &&
		!has_index(first,"cluster") && !has_index(first,"revision") &&
		!denied["ok"] &&
		source_has("/gamelib/d/manager_room","mgr_logical_zone") &&
		source_has("/gamelib/cmds/game_deal.pike",
			"[逻辑新区管理:mgr_logical_zone]") &&
		source_has("/gamelib/cmds/mgr_logical_zone.pike",
			"MANAGERD->checkpower") &&
		source_has("/gamelib/cmds/mgr_logical_zone.pike",
			"[恢复合区(") &&
		source_has("/gamelib/cmds/mgr_logical_zone.pike",
			"unisolate_confirm") &&
		source_has("/gamelib/single/daemons/_logical_zone_mod/management.pike",
			"mv(temp_path,config_path)") &&
		source_has("/gamelib/single/daemons/_logical_zone_mod/management.pike",
			"已自动恢复上一版") &&
		source_has("/gamelib/single/daemons/_logical_zone_mod/management.pike",
			"admin_rollback_zone");
	check("公开接口最小披露且管理后台使用鉴权、原子写入和自动回滚",valid,
		"管理面权限、信息披露或原子落盘契约不完整");
}

void test_social_and_economy_boundaries()
{
	array(string) files = ({
		"/gamelib/cmds/tell.pike",
		"/gamelib/cmds/trade.pike",
		"/gamelib/cmds/mailbox_mail.pike",
		"/gamelib/single/daemons/auctiond.pike",
		"/gamelib/single/daemons/termd.pike",
		"/lowlib/wapmud2/single/bangd.pike",
		"/gamelib/single/daemons/paihangd.pike",
		"/gamelib/single/daemons/chatroomd.pike",
		"/lowlib/mudlib/single/presentd.pike",
	});
	int valid = 1;
	foreach(files,string file)
		if(!source_has(file,"LOGICALZONED->"))
			valid = 0;
	valid = valid && source_has("/gamelib/single/daemons/termd.pike",
		"can_read_term(tid,viewer_id)") &&
		source_has("/gamelib/single/daemons/termd.pike",
			"index<0 || index>=sizeof(tmp)") &&
		source_has("/gamelib/cmds/fb_assign_confirm.pike",
			"get_term_power(termid,me->query_name())");
	check("私聊、交易、邮件、拍卖、组队、帮派、排行和聊天均有策略门",valid,
		"存在未接入统一策略的跨玩家功能");
}

void test_registration_and_deployment_contracts()
{
	int valid = source_has("/lowlib/system/cmds/login_regnew.pike",
			"registration_allowed(game_fg)") &&
		source_has("/lowlib/system/cmds/login_regnew_p.pike",
			"registration_allowed(game_fg)") &&
		source_has("/lowlib/system/cmds/login_check.pike","login_allowed") &&
		source_has("/restart-docker.sh","logical_zones") &&
		source_has("/restart-docker.sh","XIAND_LOGICAL_ZONE_SEED_DIR") &&
		source_has("/restart-docker.sh","$PROJECT_ROOT/deploy/logical_zones") &&
		source_has("/restart-docker.sh","[ \"$existing\" -eq 0 ]") &&
		source_has("/restart-docker.sh","prepare_logical_zone_directory") &&
		source_has("/restart-docker.sh",
			"verify_logical_zone_runtime_in_container") &&
		source_has("/restart-docker.sh","$PROJECT_ROOT/gamelib/etc") &&
		source_has("/rebuild-image.sh","validate_logical_zone_build_context") &&
		source_has("/rebuild-image.sh","verify_logical_zone_image") &&
		source_has("/.dockerignore",
			"gamelib/etc/logical_zones/xd*.conf") &&
		source_has("/docker/docker-compose.yml",
			"/etc:/app/xiand/gamelib/etc") &&
		source_has("/docker/Dockerfile.all","/app/xiand-bootstrap/etc") &&
		source_has("/docker/Dockerfile.all",
			"LOGICAL_ZONE_IMAGE_SEED_DIR") &&
		source_has("/docker/Dockerfile.all","ZONE_CONFIG_FOUND") &&
		Stdio.exist(ROOT+"/deploy/logical_zones/xd01.conf") &&
		Stdio.exist(ROOT+"/deploy/logical_zones/xd02.conf") &&
		Stdio.exist(ROOT+"/deploy/logical_zones/xd03.conf") &&
		!source_has("/restart-docker.sh",
			"chmod -R 777 \"/usr/local/games/allxd/xd$area_num/etc\"") &&
		source_has("/lowlib/system/cmds/login_fee.pike",
			"XIAND_MAINTENANCE_TOKEN") &&
		source_has("/gamelib/single/daemons/logical_zoned.pike",
			"snapshot = built[\"snapshot\"]") &&
		source_has("/gamelib/single/daemons/logical_zoned.pike",
			"signature==logical_zone_signature");
	check("注册登录受控，构建不夹带配置且部署持久化热配置",valid,
		"旧入口可绕过、镜像可能漏包或部署会覆盖线上配置");
}

void test_modular_structure()
{
	array(string) modules = ({"config.pike","identity.pike",
		"config_loader.pike","policy.pike","capabilities.pike",
		"management.pike","reconciliation.pike"});
	int valid = 1;
	foreach(modules,string module)
		if(!Stdio.exist(ROOT+
			"/gamelib/single/daemons/_logical_zone_mod/"+module))
			valid = 0;
	string facade = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/logical_zoned.pike");
	string policy = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_logical_zone_mod/policy.pike");
	valid = valid && facade && sizeof(facade/"\n")<130 && policy &&
		search(policy,"snapshot = logical_zones")!=-1 &&
		search(policy,"logical_zone_lock->lock()") == -1;
	check("门面、配置、身份、策略和关系清理模块职责分离",valid,
		"核心重新退化成难维护的单体 daemon");
}

void test_lazy_command_compilation()
{
	array(string) files = ({
		"/gamelib/cmds/bang_accept.pike",
		"/gamelib/cmds/bang_apply_in.pike",
		"/gamelib/cmds/bang_be_root.pike",
		"/gamelib/cmds/bang_view_apply.pike",
		"/gamelib/cmds/bang_view_members.pike",
		"/gamelib/cmds/bang_view_player.pike",
		"/gamelib/cmds/blacklist.pike",
		"/gamelib/cmds/bz_top_list.pike",
		"/gamelib/cmds/bz_view_banginfo.pike",
		"/gamelib/cmds/chatroom_blocklist.pike",
		"/gamelib/cmds/chatroom_char.pike",
		"/gamelib/cmds/fb_assign_confirm.pike",
		"/gamelib/cmds/fb_items_assign.pike",
		"/gamelib/cmds/fb_term_cangku.pike",
		"/gamelib/cmds/follow_you.pike",
		"/gamelib/cmds/home_buy_shopItem_confirm.pike",
		"/gamelib/cmds/home_buy_shopItem_detail.pike",
		"/gamelib/cmds/home_display.pike",
		"/gamelib/cmds/home_knock_door.pike",
		"/gamelib/cmds/home_knock_door_conferm.pike",
		"/gamelib/cmds/home_shop_sale_paihang.pike",
		"/gamelib/cmds/home_view.pike",
		"/gamelib/cmds/home_visit.pike",
		"/gamelib/cmds/look_top.pike",
		"/gamelib/cmds/mail_send_confirm.pike",
		"/gamelib/cmds/mailbox_mail.pike",
		"/gamelib/cmds/mgr_logical_zone.pike",
		"/gamelib/cmds/my_bang.pike",
		"/gamelib/cmds/paihang_list.pike",
		"/gamelib/cmds/paihang_mark_toplist.pike",
		"/gamelib/cmds/present_set.pike",
		"/gamelib/cmds/present_view.pike",
		"/gamelib/cmds/qqlist.pike",
		"/gamelib/cmds/qqlist_user.pike",
		"/gamelib/cmds/sendother.pike",
		"/gamelib/cmds/sendother_daoju.pike",
		"/gamelib/cmds/sendother_daoju_to.pike",
		"/gamelib/cmds/sendother_ok.pike",
		"/gamelib/cmds/sendother_to.pike",
		"/gamelib/cmds/spec_yujian_to.pike",
		"/gamelib/cmds/spec_yujianshu.pike",
		"/gamelib/cmds/spy_add.pike",
		"/gamelib/cmds/spy_add_confirm.pike",
		"/gamelib/cmds/spy_del.pike",
		"/gamelib/cmds/spy_start.pike",
		"/gamelib/cmds/spy_start_confirm.pike",
		"/gamelib/cmds/tell.pike",
		"/gamelib/cmds/term_assist.pike",
		"/gamelib/cmds/term_changeleader.pike",
		"/gamelib/cmds/term_kick.pike",
		"/gamelib/cmds/term_ok.pike",
		"/gamelib/cmds/trade.pike",
		"/gamelib/cmds/trade_daoju.pike",
		"/gamelib/cmds/ui_char.pike",
		"/gamelib/cmds/ui_chat.pike",
		"/gamelib/cmds/vendue_buy_now.pike",
		"/gamelib/cmds/vendue_goods_info.pike",
		"/gamelib/cmds/vendue_goods_list.pike",
		"/gamelib/cmds/vendue_maunl_comp.pike",
		"/gamelib/cmds/vendue_vie_buy.pike",
		"/gamelib/cmds/view_equip.pike",
		"/gamelib/cmds/whoa.pike",
		"/lowlib/system/cmds/login.pike",
		"/lowlib/system/cmds/login_band.pike",
		"/lowlib/system/cmds/login_check.pike",
		"/lowlib/system/cmds/login_check5.pike",
		"/lowlib/system/cmds/login_check_intro.pike",
		"/lowlib/system/cmds/login_check_p.pike",
		"/lowlib/system/cmds/login_entrycheck_p.pike",
		"/lowlib/system/cmds/login_fee.pike",
		"/lowlib/system/cmds/login_fee_xd.pike",
		"/lowlib/system/cmds/login_monst.pike",
		"/lowlib/system/cmds/login_intro.pike",
		"/lowlib/system/cmds/login_regnew.pike",
		"/lowlib/system/cmds/login_regnew_p.pike",
		"/lowlib/system/cmds/who.pike",
		"/lowlib/mudlib/single/presentd.pike",
		"/lowlib/wapmud2/cmds/inv_other.pike",
		"/lowlib/wapmud2/cmds/leave.pike",
	});
	array(string) failed = ({});
	foreach(files,string file){
		mixed err = catch { compile_file(ROOT+file); };
		if(err)
			failed += ({file+": "+describe_error(err)});
	}
	check("所有延迟加载的隔离命令可在真实 Pike 运行时编译",
		!sizeof(failed),sizeof(failed) ? failed*" | " : "");
}

int main()
{
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/logical_zoned.pike");
	werror("\n========== 同进程逻辑分区测试 ==========\n");
	if(!daemon){
		check("逻辑分区 daemon 可加载",0,"daemon 未创建");
		return 1;
	}
	test_config_schema(daemon);
	test_deployment_seed_configs(daemon);
	test_reversible_policy(daemon);
	test_runtime_fail_closed(daemon);
	test_visual_and_combat_boundaries();
	test_runtime_visual_isolation(daemon);
	test_drop_zone_ownership(daemon);
	test_social_and_economy_boundaries();
	test_public_and_admin_management_contracts(daemon);
	test_registration_and_deployment_contracts();
	test_modular_structure();
	test_lazy_command_compilation();
	werror("\n逻辑分区：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
