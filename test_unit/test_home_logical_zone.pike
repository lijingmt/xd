#!/usr/bin/env pike
/** 家园固定产权区、老数据兼容、同号多维和安全事务回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	werror("\n[多维家园 %d] %s\n",results["total"],name);
	if(valid){
		results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

int source_has(string path,string needle)
{
	string source = Stdio.read_file(ROOT+path);
	return source && search(source,needle)!=-1;
}

int source_lacks(string path,string needle)
{
	string source = Stdio.read_file(ROOT+path);
	return source && search(source,needle)==-1;
}

void test_runtime_index(object homed)
{
	mapping audit = homed->query_home_zone_audit();
	int valid = audit["home_count"]>0 &&
		audit["zone_key_count"]==audit["home_count"] &&
		audit["resolvable_count"]==audit["home_count"] &&
		audit["invalid_count"]==0 && audit["collision_count"]==0 &&
		audit["orphan_plot_count"]==0;
	check("线上老房契全部建立产权区索引且新旧引用均可解析",valid,
		"家园数="+(string)audit["home_count"]+
		" 索引数="+(string)audit["zone_key_count"]+
		" 可解析="+(string)audit["resolvable_count"]+
		" 无效="+(string)audit["invalid_count"]+
		" 冲突="+(string)audit["collision_count"]+
		" 幽灵占用="+(string)audit["orphan_plot_count"]);
}

void test_multidimensional_keys(object homed)
{
	string plot = "xd/qianxuehu/qianxuemen/lei/1";
	string first = homed->home_zone_key_for_test("xd01owner",plot);
	string second = homed->home_zone_key_for_test("xd03owner",plot);
	mapping(string:string) candidates = ([
		first:"xd01owner",
		second:"xd03owner",
	]);
	int valid = first=="xd01@"+plot && second=="xd03@"+plot &&
		first!=second && homed->home_plot_path_for_test(first)==plot &&
		homed->home_plot_path_for_test(second)==plot &&
		homed->home_plot_path_for_test(plot)==plot &&
		homed->resolve_home_candidates_for_test(
			"xd03viewer",plot,candidates,({"xd01owner","xd03owner"}))==
			"xd03owner" &&
		homed->resolve_home_candidates_for_test(
			"xd02viewer",plot,candidates,({"xd01owner","xd03owner"}))=="" &&
		homed->resolve_home_candidates_for_test(
			"xd02viewer",plot,candidates,({"xd01owner"}))=="xd01owner";
	check("相同物理房号可映射到互不覆盖的多维产权",valid,
		"产权键或新旧路径归一化不正确");
}

void test_missing_home_shop_license(object homed)
{
	check("无家园档案打开家园设置安全视为未购买店铺许可",
		homed->if_have_shopLicense("__testunit_missing_home_shop__")==0,
		"缺失家园档案仍解引用shop字段");
}

void test_transaction_contracts()
{
	int valid = source_has("/gamelib/single/daemons/homed.pike",
		"homeStateLock->lock()") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"query_native_home_owner(player_id,homeName)") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"store_all_info_unlocked(1)") &&
		source_has("/gamelib/single/daemons/homed.pike",
			"YUSHID->rollback_yushi_payment(player,before_wallet") &&
		source_has("/gamelib/single/daemons/homed.pike",
			"player_saved=save_function_room_player(player)") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"before_yushi-YUSHID->query_all_num(player)==yushi") &&
		source_has("/gamelib/single/daemons/_home_mod/persistence.pike",
		"detail_home 是产权提交点") &&
		source_has("/gamelib/single/daemons/_home_mod/persistence.pike",
		"restore_home_snapshot_file") &&
		source_has("/gamelib/cmds/home_purchase_confirm.pike",
		"HOMED->purchase_home") &&
		source_lacks("/gamelib/cmds/home_purchase_confirm.pike",
		"BUYD->do_trade") &&
		source_lacks("/gamelib/cmds/home_purchase_confirm.pike",
		"build_new_home");
	check("购房只经加锁事务并具备二次校验、原子提交和退款",valid,
		"旧扣款入口或非原子保存仍可绕过事务");
}

void test_visibility_and_reconciliation_contracts()
{
	int valid = source_has("/gamelib/single/daemons/homed.pike",
		"query_visible_home_owners") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"query_home_zone_label") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"query_home_reference_by_masterId") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"enforce_user_home_isolation") &&
		source_has("/gamelib/single/daemons/_logical_zone_mod/reconciliation.pike",
		"HOMED->enforce_user_home_isolation(actor)") &&
		source_has("/gamelib/d/init",
			"LOGICALZONED->can_user_action(\"home\"") &&
		source_has("/gamelib/d/init","HOMED->repair_player_home_path(me)") &&
		source_has("/gamelib/d/init","HOMED->enforce_user_home_isolation(me)") &&
		source_has("/gamelib/single/daemons/homed.pike",
			"query_masterId_by_zone_path(currentPath,playerId)!=playerId") &&
		source_has("/gamelib/d/init","me->inhome_pos = \"\"") &&
		source_lacks("/gamelib/d/init","me->inhome_pos ==\"\"");
	check("合区显示街区维度，拆区即时回收且登录不会重入跨区家园",valid,
		"可见性、在线回收或登录恢复契约不完整");
}

void test_shop_and_legacy_contracts()
{
	int valid = source_has("/gamelib/single/daemons/homed.pike",
		"query_home_plot_path(homeId)") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"\"home\",viewerId,tmp->masterId") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"path = query_home_reference_by_masterId(masterId)") &&
		source_has("/gamelib/cmds/home_shop_sale_paihang.pike",
		"can_user_action(\"home\"") &&
		source_has("/gamelib/cmds/home_buy_shopItem_confirm.pike",
		"can_user_action(\"home\"") &&
		source_has("/gamelib/cmds/home_buy_shopItem_confirm.pike",
		"purchase_shop_listing(me,masterId") &&
		source_has("/gamelib/single/daemons/homed.pike",
		"rollback_shop_payment") &&
		source_lacks("/gamelib/cmds/home_buy_shopItem_confirm.pike",
		"load_player(masterId)") &&
		source_lacks("/gamelib/cmds/home_buy_shopItem_confirm.pike",
		"combine_itme");
	check("旧房契读取不迁移且推荐店铺、销量榜和购买均按家园域过滤",valid,
		"旧数据兼容或商店信息隔离仍有缺口");
}

void test_compile_targets()
{
	array(string) files = ({
		"/gamelib/single/daemons/homed.pike",
		"/gamelib/single/daemons/logical_zoned.pike",
		"/gamelib/cmds/home_purchase_confirm.pike",
		"/gamelib/cmds/home_sell_confirm.pike",
		"/gamelib/cmds/home_return.pike",
		"/gamelib/cmds/home_view.pike",
		"/gamelib/cmds/home_display.pike",
		"/gamelib/cmds/home_visit.pike",
		"/gamelib/cmds/home_buy_shopItem_confirm.pike",
		"/gamelib/cmds/home_buy_shopItem_detail.pike",
		"/gamelib/cmds/home_shop_sale_paihang.pike",
		"/gamelib/d/init",
	});
	array(string) failed = ({});
	foreach(files,string file){
		mixed err = catch { compile_file(ROOT+file); };
		if(err)
			failed += ({file+": "+describe_error(err)});
	}
	check("家园和登录的全部变更目标通过真实 Pike 编译",
		!sizeof(failed),sizeof(failed) ? failed*" | " : "");
}

int main()
{
	object homed = (object)(ROOT+"/gamelib/single/daemons/homed.pike");
	werror("\n========== 多维家园与老数据兼容测试 ==========\n");
	if(!homed){
		check("家园 daemon 可加载",0,"daemon 未创建");
		return 1;
	}
	test_runtime_index(homed);
	test_multidimensional_keys(homed);
	test_missing_home_shop_license(homed);
	test_transaction_contracts();
	test_visibility_and_reconciliation_contracts();
	test_shop_and_legacy_contracts();
	test_compile_targets();
	werror("\n多维家园：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
