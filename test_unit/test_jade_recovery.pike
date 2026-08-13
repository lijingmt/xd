#!/usr/bin/env pike
/** Evidence allowlist and one-time physical-jade recovery regression tests. */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[异常玉石回收] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[异常玉石回收] ✗ %s: %s\n",name,detail);
	}
}

void cleanup_test_player_file(string userid)
{
	if(search(userid,"testunit")==-1 || sizeof(userid)<2)
		return;
	string path=DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+
		userid+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_test_player(string userid)
{
	JADE_RECOVERYD->test_clear_manifest();
	cleanup_test_player_file(userid);
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="异常玉石回收测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	return player;
}

void give_test_jade(object player,int amount)
{
	object jade=clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	jade->amount=amount;
	jade->move(player);
}

void give_test_storage_jade(object player,string name,int amount)
{
	int level=0;
	for(int one=1;one<=5;one++)
		if(YUSHID->get_yushi_name(one)==name)
			level=one;
	player->packaged_items+=({({name,YUSHID->get_yushi_namecn(level),
		"("+(string)amount+")块"+YUSHID->get_yushi_namecn(level),
		"yushi/"+name,0,0,amount,
		"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"})});
}

mapping(string:mixed) approved_manifest(string userid,int amount,int captured,
	void|int captured_storage)
{
	string evidence=
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
	int captured_at=time();
	return (["schema_version":2,"enabled":1,"state":"approved",
		"policy":"one_time_current_physical_only_no_future_debt",
		"created_before":"2026-08-01","accounts":([
			userid:(["userid":userid,
				"case_id":"jade-testunit-case-0001",
				"proven_suiyu":amount,
				"registered_on":"2026-06-01",
				"evidence_sha256":evidence,
				"balance_snapshot_sha256":evidence,
				"balance_captured_at":captured_at,
				"snapshot_expires_at":captured_at+3600,
				"captured_physical_suiyu":captured,
				"captured_personal_storage_suiyu":captured_storage,
				"captured_shared_source_suiyu":0,
				"captured_wallet_suiyu":0,
				"all_fee":0,"fee_allowance_suiyu":0,
				"legal_non_all_fee_suiyu":0,
				"legal_ledger_complete":1,
				"unexplained_remaining_suiyu":captured+captured_storage,
				"exact_minted_suiyu":amount,
				"approved":1])
		])]);
}

void destroy_test_player(object|zero player)
{
	JADE_RECOVERYD->test_clear_manifest();
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	string userid=(string)player->query_name();
	destruct(player);
	cleanup_test_player_file(userid);
}

void test_exact_one_time_recovery()
{
	string userid="xd99testunitjaderecovery";
	object player=create_test_player(userid);
	give_test_jade(player,15);
	int installed=JADE_RECOVERYD->test_set_manifest(
		approved_manifest(userid,10,15));
	mapping first=JADE_RECOVERYD->apply_if_listed(player);
	mapping receipt=player["/plus/illicit_jade_recovery_once"];
	int after_first=YUSHID->query_physical_all_num(player);
	give_test_jade(player,7);
	mapping second=JADE_RECOVERYD->apply_if_listed(player);
	int after_second=YUSHID->query_physical_all_num(player);
	check("白名单人物只按证据上限扣除一次",
		installed && first["code"]=="closed" &&
		(int)first["confiscated"]==10 && after_first==5 &&
		mappingp(receipt) && (int)receipt["confiscated"]==10,
		"首次扣除数量或结案凭据不正确");
	check("结案后新获得的玉石不再追扣",
		second["code"]=="already_closed" && after_second==12,
		"同一人物被重复执行或未来玉石被追扣");
	destroy_test_player(player);
}

void test_current_balance_caps_recovery()
{
	string userid="xd99testunitjadepartial";
	object player=create_test_player(userid);
	give_test_jade(player,3);
	// 离线审计已把历史证据10裁剪为快照中仍可证明存在的3。
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,3,3));
	mapping first=JADE_RECOVERYD->apply_if_listed(player);
	give_test_jade(player,5);
	mapping second=JADE_RECOVERYD->apply_if_listed(player);
	check("余额不足时只扣现有物理玉并一次性结案",
		first["code"]=="closed" && (int)first["confiscated"]==3 &&
		second["code"]=="already_closed" &&
		YUSHID->query_physical_all_num(player)==5,
		"形成了欠款、重复执行或触碰了后续所得");
	destroy_test_player(player);
}

void test_nonlisted_and_unapproved_are_ignored()
{
	string userid="xd99testunitjadeignored";
	object player=create_test_player(userid);
	give_test_jade(player,9);
	mapping manifest=approved_manifest("xd99testunitjadeother",9,9);
	JADE_RECOVERYD->test_set_manifest(manifest);
	mapping missing=JADE_RECOVERYD->apply_if_listed(player);
	manifest=approved_manifest(userid,9,9);
	manifest["enabled"]=0;
	JADE_RECOVERYD->test_set_manifest(manifest);
	mapping disabled=JADE_RECOVERYD->apply_if_listed(player);
	check("非白名单和未启用清单绝不进入扣除逻辑",
		missing["code"]=="not_listed" && disabled["code"]=="not_listed" &&
		YUSHID->query_physical_all_num(player)==9 &&
		!mappingp(player["/plus/illicit_jade_recovery_once"]),
		"未批准人物的物理玉或存档被修改");
	destroy_test_player(player);
}

void test_creation_cutoff_and_manifest_validation()
{
	string userid="xd99testunitjadevalidation";
	object player=create_test_player(userid);
	give_test_jade(player,8);
	mapping manifest=approved_manifest(userid,8,8);
	manifest["accounts"][userid]["registered_on"]="2026-08-01";
	JADE_RECOVERYD->test_set_manifest(manifest);
	mapping cutoff=JADE_RECOVERYD->apply_if_listed(player);
	manifest=approved_manifest(userid,8,8);
	manifest["accounts"][userid]["evidence_sha256"]="bad";
	JADE_RECOVERYD->test_set_manifest(manifest);
	mapping bad_hash=JADE_RECOVERYD->apply_if_listed(player);
	manifest=approved_manifest(userid,8,8);
	manifest["accounts"][userid]["snapshot_expires_at"]=time()-1;
	JADE_RECOVERYD->test_set_manifest(manifest);
	mapping expired=JADE_RECOVERYD->apply_if_listed(player);
	manifest=approved_manifest(userid,8,8);
	manifest["accounts"][userid]["fee_allowance_suiyu"]=10;
	JADE_RECOVERYD->test_set_manifest(manifest);
	mapping inconsistent_fee=JADE_RECOVERYD->apply_if_listed(player);
	int production_override=JADE_RECOVERYD->test_set_manifest(
		approved_manifest("xd01productionuser",8,8));
	check("注册日期门槛和证据摘要均为强制条件",
		cutoff["code"]=="not_listed" && bad_hash["code"]=="not_listed" &&
		expired["code"]=="not_listed" &&
		inconsistent_fee["code"]=="not_listed" &&
		YUSHID->query_physical_all_num(player)==8,
		"创建日期、快照时效或财务证据校验可以被绕过");
	check("TestUnit内存入口拒绝任何生产账号",
		!production_override && getenv("XIAND_RUN_TESTUNIT")=="1",
		"测试入口环境隔离失效或可注入生产人物");
	destroy_test_player(player);
}

void test_persisted_receipt_survives_restore()
{
	string userid="xd99testunitjadepersisted";
	object player=create_test_player(userid);
	give_test_jade(player,6);
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,4,6));
	mapping first=JADE_RECOVERYD->apply_if_listed(player);
	give_test_jade(player,5);
	int saved=player->save_with_result();
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_project("gamelib");
	int restored=player->restore();
	mapping second=JADE_RECOVERYD->apply_if_listed(player);
	check("一次性结案凭据随人物存档恢复",
		first["code"]=="closed" && saved && restored &&
		second["code"]=="already_closed" &&
		YUSHID->query_physical_all_num(player)==7,
		"重登后重复扣除或结案凭据未持久化");
	destroy_test_player(player);
}

void test_snapshot_change_closes_without_touching_new_jade()
{
	string userid="xd99testunitjadesnapshot";
	object player=create_test_player(userid);
	give_test_jade(player,10);
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,10,10));
	// A reward/transfer/recharge between audit and login makes provenance
	// ambiguous. The case must close with no deduction and no future retry.
	give_test_jade(player,1);
	mapping first=JADE_RECOVERYD->apply_if_listed(player);
	give_test_jade(player,5);
	mapping second=JADE_RECOVERYD->apply_if_listed(player);
	check("审计快照变化时零扣除结案且以后不追缴",
		first["code"]=="closed" && (int)first["confiscated"]==0 &&
		second["code"]=="already_closed" &&
		YUSHID->query_physical_all_num(player)==16,
		"快照后的合法玉被扣除或案件被重复执行");
	destroy_test_player(player);
}

void test_personal_storage_jade_is_included_and_reversible()
{
	string userid="xd99testunitjadestorage";
	object player=create_test_player(userid);
	give_test_jade(player,3);
	give_test_storage_jade(player,"suiyu",20);
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,15,3,20));
	mapping result=JADE_RECOVERYD->apply_if_listed(player);
	check("人物仓库中的异常玉纳入同一事务并保留正确数量显示",
		result["code"]=="closed" && (int)result["confiscated"]==15 &&
		YUSHID->query_physical_all_num(player)==3 &&
		JADE_RECOVERYD->query_personal_storage_yushi(player)==5 &&
		search((string)player->packaged_items[0][2],"(5)块")!=-1,
		"只扣了背包、仓库价值错误或仓库显示数量没有同步");
	destroy_test_player(player);
}

void test_personal_storage_large_jade_can_make_exact_change()
{
	string userid="xd99testunitjadechange";
	object player=create_test_player(userid);
	give_test_storage_jade(player,"xianyuanyu",1);
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,3,0,10));
	mapping result=JADE_RECOVERYD->apply_if_listed(player);
	check("人物仓库高面额玉可精确找零且不触碰共享充值钱包",
		result["code"]=="closed" && (int)result["confiscated"]==3 &&
		YUSHID->query_physical_all_num(player)==7 &&
		JADE_RECOVERYD->query_personal_storage_yushi(player)==0 &&
		ACCOUNT_WALLETD->query_balance(player)==0,
		"高面额仓库玉被多扣、少扣或错误使用了充值钱包");
	destroy_test_player(player);
}

void test_personal_storage_snapshot_change_is_not_confiscated()
{
	string userid="xd99testunitjadestoragedrift";
	object player=create_test_player(userid);
	give_test_storage_jade(player,"suiyu",10);
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,10,0,10));
	give_test_storage_jade(player,"suiyu",1);
	mapping result=JADE_RECOVERYD->apply_if_listed(player);
	check("人物仓库快照变化时零扣除结案且不追缴新玉",
		result["code"]=="closed" && (int)result["confiscated"]==0 &&
		JADE_RECOVERYD->query_personal_storage_yushi(player)==11,
		"快照以后存入人物仓库的合法玉被误扣");
	destroy_test_player(player);
}

void test_login_hook_is_fail_open()
{
	string source=Stdio.read_file(ROOT+"/gamelib/single/daemons/userd.pike");
	check("登录钩子异常不会阻断正常登录",
		source && search(source,
			"jade_recovery_err=catch{ JADE_RECOVERYD->apply_if_listed(me); }")!=-1 &&
		search(source,"login hook failed safely")!=-1,
		"一次性审计守护异常可能中断玩家登录");
}

void test_stale_second_worker_object_cannot_repeat_recovery()
{
	string userid="xd99testunitjadestaleobject";
	object first=create_test_player(userid);
	object stale=clone(GAMELIB_USER);
	stale->set_name(userid);
	stale->name_cn="异常玉石旧Worker对象";
	stale->set_project("gamelib");
	// A stale object belongs to another Worker process. Calling setup() twice
	// with the same userid in this one-process TestUnit would correctly replace
	// the first live login, which is not the cross-process state being tested.
	// Keep this clone detached from the local living/login registry instead.
	stale->set_raceId("third");
	stale->set_profeId("fangshi");
	stale->setup_player("third","fangshi");
	give_test_jade(first,10);
	give_test_jade(stale,10);
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,10,10));
	mapping committed=JADE_RECOVERYD->apply_if_listed(first);
	mapping duplicate=JADE_RECOVERYD->apply_if_listed(stale);
	check("共享永久claim阻止旧Worker对象二次回收",
		committed["code"]=="closed" &&
		duplicate["code"]=="already_claimed" &&
		YUSHID->query_physical_all_num(first)==0 &&
		YUSHID->query_physical_all_num(stale)==10,
		"串行文件锁释放后旧人物对象仍可重复扣除");
	destroy_test_player(first);
	destroy_test_player(stale);
}

int main()
{
	werror("\n========== 异常玉石一次性回收测试 ==========\n");
	test_exact_one_time_recovery();
	test_current_balance_caps_recovery();
	test_nonlisted_and_unapproved_are_ignored();
	test_creation_cutoff_and_manifest_validation();
	test_persisted_receipt_survives_restore();
	test_snapshot_change_closes_without_touching_new_jade();
	test_personal_storage_jade_is_included_and_reversible();
	test_personal_storage_large_jade_can_make_exact_change();
	test_personal_storage_snapshot_change_is_not_confiscated();
	test_login_hook_is_fail_open();
	test_stale_second_worker_object_cannot_repeat_recovery();
	werror("异常玉石回收测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
