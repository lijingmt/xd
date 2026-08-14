#!/usr/bin/env pike
/** Automatic login evidence and one-time physical-jade recovery tests. */

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
	JADE_RECOVERYD->test_clear_auto_evidence();
	JADE_RECOVERYD->test_clear_user_claim(userid);
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

mapping(string:mixed) automatic_evidence(string userid,int exact_minted,
	void|int event_count,void|int registered)
{
	string evidence=
		"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
	if(!event_count)
		event_count=1;
	if(zero_type(registered))
		registered=1;
	return (["schema_version":1,"created_before":"2026-08-01",
		"generated_at":time(),"accounts":([
			userid:(["userid":userid,
				"exact_minted_suiyu":exact_minted,
				"event_count":event_count,
				"routes":(["legacy_split_remainder_bug":event_count]),
				"evidence_sha256":evidence,
				"registered_before_cutoff":registered])
		])]);
}

void destroy_test_player(object|zero player)
{
	JADE_RECOVERYD->test_clear_manifest();
	JADE_RECOVERYD->test_clear_auto_evidence();
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	string userid=(string)player->query_name();
	destruct(player);
	JADE_RECOVERYD->test_clear_user_claim(userid);
	cleanup_test_player_file(userid);
}

void test_automatic_login_exact_evidence_recovery()
{
	string userid="xd99testunitjadeautomatic";
	object player=create_test_player(userid);
	give_test_jade(player,25);
	int installed=JADE_RECOVERYD->test_set_auto_evidence(
		automatic_evidence(userid,20));
	mapping first=JADE_RECOVERYD->apply_on_login(player);
	mapping receipt=player["/plus/illicit_jade_recovery_once"];
	give_test_jade(player,7);
	mapping second=JADE_RECOVERYD->apply_on_login(player);
	check("登录自动证据无需候选清单即可一次性回收",
		installed && first["code"]=="closed" &&
		(int)first["confiscated"]==20 &&
		YUSHID->query_physical_all_num(player)==12 &&
		mappingp(receipt) &&
		receipt["source_mode"]=="automatic_login_evidence" &&
		second["code"]=="already_closed",
		sprintf("仍依赖清单、扣除数量错误或永久结案失效 "
			"installed=%d first=%O second=%O jade=%d receipt=%O",
			installed,first,second,YUSHID->query_physical_all_num(player),
			receipt));
	destroy_test_player(player);
}

void test_automatic_login_fee_allowance_and_spent_forgiveness()
{
	string userid="xd99testunitjadeallowance";
	object player=create_test_player(userid);
	player->set_all_fee(2);
	give_test_jade(player,25);
	JADE_RECOVERYD->test_set_auto_evidence(automatic_evidence(userid,40));
	mapping result=JADE_RECOVERYD->apply_on_login(player);
	mapping receipt=player["/plus/illicit_jade_recovery_once"];
	check("all_fee按十倍保护合法玉且已消费异常额不形成未来欠款",
		result["code"]=="closed" && (int)result["confiscated"]==5 &&
		YUSHID->query_physical_all_num(player)==20 &&
		(int)receipt["proven_suiyu"]==5,
		"合法充值额度被扣、精确证据未按现存差额裁剪或形成欠款");
	destroy_test_player(player);
}

void test_automatic_login_closes_zero_without_future_debt()
{
	string userid="xd99testunitjadezeroclose";
	object player=create_test_player(userid);
	player->set_all_fee(10);
	give_test_jade(player,30);
	JADE_RECOVERYD->test_set_auto_evidence(automatic_evidence(userid,20));
	mapping first=JADE_RECOVERYD->apply_on_login(player);
	mapping receipt=player["/plus/illicit_jade_recovery_once"];
	give_test_jade(player,11);
	mapping second=JADE_RECOVERYD->apply_on_login(player);
	check("证据对应玉已消费时零扣除结案且以后正常所得不追缴",
		first["code"]=="closed" && (int)first["confiscated"]==0 &&
		mappingp(receipt) &&
		receipt["status"]=="no_recoverable_balance_closed" &&
		second["code"]=="already_closed" &&
		YUSHID->query_physical_all_num(player)==41,
		"已消费金额被记成债务或后续合法玉被扣");
	destroy_test_player(player);
}

void test_auto_evidence_parser_only_accepts_exact_mints()
{
	string userid="xd99testunitjadeparser";
	array(string) lines=({
		"Fri Jul 31 12:00:00 2026:玩家("+userid+
			") 打算打碎(1)xianyuanyu,结果为: 将(1)xianyuanyu打碎获得(10)suiyu,",
		"Fri Jul 31 12:00:01 2026:玩家("+userid+
			") 打算打碎(5)xianyuanyu,结果为: 将(2)xianyuanyu打碎获得(20)suiyu, 将(2)xianyuanyu打碎获得(20)suiyu, 将(1)xianyuanyu打碎获得(10)suiyu,",
		"1\tevent=yushi_conversion\tplayer="+userid+
			"\tstatus=success\tsource_value=10\ttarget_value=14",
		"2\tevent=yushi_conversion\tplayer="+userid+
			"\tstatus=failed\tsource_value=10\ttarget_value=99",
	});
	mapping row=JADE_RECOVERYD->test_parse_auto_evidence(userid,lines,
		202607);
	check("自动扫描只累计2转20与成功结构化正增发的精确数量",
		(int)row["exact_minted_suiyu"]==24 &&
		(int)row["event_count"]==3 &&
		(int)row["creation_proven_by_event"]==1,
		"正常1转10、失败事件被误判或同一行多个漏洞段漏算");
}

void test_auto_evidence_validation_fails_closed()
{
	string userid="xd99testunitjadeinvalidauto";
	object player=create_test_player(userid);
	give_test_jade(player,9);
	mapping evidence=automatic_evidence(userid,9,1,0);
	JADE_RECOVERYD->test_set_auto_evidence(evidence);
	mapping cutoff=JADE_RECOVERYD->apply_on_login(player);
	evidence=automatic_evidence(userid,9);
	evidence["accounts"][userid]["evidence_sha256"]="bad";
	JADE_RECOVERYD->test_set_auto_evidence(evidence);
	mapping digest=JADE_RECOVERYD->apply_on_login(player);
	int production_override=JADE_RECOVERYD->test_set_auto_evidence(
		automatic_evidence("xd01productionuser",9));
	check("自动证据强制注册截止、摘要格式并拒绝测试注入生产账号",
		cutoff["code"]=="no_exact_evidence" &&
		digest["code"]=="no_exact_evidence" && !production_override &&
		YUSHID->query_physical_all_num(player)==9 &&
		!mappingp(player["/plus/illicit_jade_recovery_once"]),
		"截止条件、证据完整性或TestUnit生产隔离被绕过");
	destroy_test_player(player);
}

void test_automatic_recovery_defers_shared_source_jade()
{
	string userid="xd99testunitjadeshared";
	ACCOUNT_STORAGED->remove_test_storage(userid);
	object player=create_test_player(userid);
	give_test_storage_jade(player,"suiyu",12);
	string item_id=(string)player->packaged_items[0][7];
	mapping moved=ACCOUNT_STORAGED->transfer_to_shared(player,item_id);
	JADE_RECOVERYD->test_set_auto_evidence(automatic_evidence(userid,12));
	mapping result=JADE_RECOVERYD->apply_on_login(player);
	mapping storage=ACCOUNT_STORAGED->query_storage(player);
	check("共享仓库含本人来源玉时延后且不抢占永久结案",
		(int)moved["ok"] && result["code"]==
			"deferred_shared_storage_jade" &&
		(int)storage["ok"] && sizeof((array)storage["items"])==1 &&
		!mappingp(player["/plus/illicit_jade_recovery_once"]),
		"共享仓库事务被盲扣、删除或错误永久结案");
	ACCOUNT_STORAGED->remove_test_storage(userid);
	destroy_test_player(player);
}

void test_automatic_recovery_runtime_cap()
{
	string userid="xd99testunitjadecap";
	object player=create_test_player(userid);
	give_test_jade(player,20000009);
	JADE_RECOVERYD->test_set_auto_evidence(
		automatic_evidence(userid,20000009));
	mapping result=JADE_RECOVERYD->apply_on_login(player);
	check("自动回收仍受单人两千万碎玉硬上限保护",
		result["code"]=="closed" &&
		(int)result["confiscated"]==20000000 &&
		YUSHID->query_physical_all_num(player)==9,
		"单次扣除突破安全上限或上限计算错误");
	destroy_test_player(player);
}

void test_production_log_scanner_is_bounded_and_well_formed()
{
	mapping index=JADE_RECOVERYD->test_build_auto_evidence_index();
	mapping accounts=mappingp(index["accounts"]) ?
		(mapping)index["accounts"] : ([]);
	int exact_total=0;
	int valid= index["schema_version"]==1 &&
		index["created_before"]=="2026-08-01" &&
		(int)index["scanned_bytes"]>=0 &&
		(int)index["scanned_bytes"]<=64*1024*1024 &&
		(int)index["exact_event_count"]>=0 &&
		(int)index["exact_event_count"]<=200000;
	foreach(accounts;string userid;mapping row){
		exact_total+=(int)row["exact_minted_suiyu"];
		if(userid!=(string)row["userid"] ||
		   (int)row["exact_minted_suiyu"]<=0 ||
		   (int)row["event_count"]<=0 ||
		   sizeof((string)row["evidence_sha256"])!=64)
			valid=0;
	}
	werror("[异常玉石回收] 自动证据扫描 accounts=%d events=%d "
		"exact_suiyu=%d bytes=%d\n",
		sizeof(accounts),(int)index["exact_event_count"],
		exact_total,(int)index["scanned_bytes"]);
	check("真实日志扫描在文件、总量和事件上限内产生完整索引",
		valid,"真实日志索引结构异常或超出安全边界");
}

void test_exact_one_time_recovery()
{
	string userid="xd99testunitjaderecovery";
	object player=create_test_player(userid);
	int started_at=time();
	give_test_jade(player,15);
	int installed=JADE_RECOVERYD->test_set_manifest(
		approved_manifest(userid,10,15));
	mapping first=JADE_RECOVERYD->apply_if_listed(player);
	mapping receipt=player["/plus/illicit_jade_recovery_once"];
	int after_first=YUSHID->query_physical_all_num(player);
	int vip_end_after_first=player->query_vip_end_time();
	int mail_count_after_first=arrayp(player->inbox) ?
		sizeof(player->inbox) : 0;
	give_test_jade(player,7);
	mapping second=JADE_RECOVERYD->apply_if_listed(player);
	int after_second=YUSHID->query_physical_all_num(player);
	check("白名单人物只按证据上限扣除一次",
		installed && first["code"]=="closed" &&
		(int)first["confiscated"]==10 && after_first==5 &&
		mappingp(receipt) && (int)receipt["confiscated"]==10,
		"首次扣除数量或结案凭据不正确");
	check("实际扣玉后一次性补偿30天VIP4并发送系统邮件",
		player->query_vip_flag()==4 &&
		vip_end_after_first>=started_at+2592000 &&
		vip_end_after_first<=time()+2592005 &&
		(int)receipt["compensation_vip_level"]==4 &&
		(int)receipt["compensation_vip_seconds"]==2592000 &&
		!(int)receipt["compensation_notice_pending"] &&
		mail_count_after_first==1 &&
		search((string)player->inbox[0][4],"异常玉石一次性回收补偿")!=-1 &&
		search((string)player->inbox[0][5],"30天VIP4")!=-1,
		"VIP4期限、回执或系统邮件缺失");
	check("结案后新获得的玉石不再追扣",
		second["code"]=="already_closed" && after_second==12 &&
		player->query_vip_end_time()==vip_end_after_first &&
		(arrayp(player->inbox) ? sizeof(player->inbox) : 0)==
			mail_count_after_first,
		"同一人物被重复执行或未来玉石被追扣");
	destroy_test_player(player);
}

void test_existing_higher_vip_is_extended_without_downgrade()
{
	string userid="xd99testunitjadehighvip";
	object player=create_test_player(userid);
	int old_end=time()+86400;
	player->set_vip_flag(6);
	player->set_vip_end_time(old_end);
	player->add_vip_history(old_end,6);
	give_test_jade(player,5);
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,5,5));
	mapping result=JADE_RECOVERYD->apply_if_listed(player);
	check("已有高阶VIP保持原等级并在原到期日顺延30天",
		result["code"]=="closed" && (int)result["confiscated"]==5 &&
		player->query_vip_flag()==6 &&
		player->query_vip_end_time()==old_end+2592000 &&
		(int)result["compensation_vip_level"]==6,
		"高阶VIP被降级、未顺延或重复从当前时间计算");
	destroy_test_player(player);
}

void test_expired_vip_does_not_extend_stale_end_time()
{
	string userid="xd99testunitjadeexpiredvip";
	object player=create_test_player(userid);
	player->set_vip_flag(8);
	player->set_vip_end_time(time()-86400);
	give_test_jade(player,4);
	int started_at=time();
	JADE_RECOVERYD->test_set_manifest(approved_manifest(userid,4,4));
	mapping result=JADE_RECOVERYD->apply_if_listed(player);
	check("已过期高阶VIP按VIP4补30天且不复活旧等级或旧期限",
		result["code"]=="closed" && (int)result["confiscated"]==4 &&
		player->query_vip_flag()==4 &&
		player->query_vip_end_time()>=started_at+2592000 &&
		player->query_vip_end_time()<=time()+2592005,
		"过期VIP被错误复活或补偿期限继承了失效时间");
	destroy_test_player(player);
}

void test_legacy_closed_receipt_gets_compensation_only()
{
	string userid="xd99testunitjadelegacyreceipt";
	object player=create_test_player(userid);
	give_test_jade(player,9);
	player["/plus/illicit_jade_recovery_once"] = ([
		"schema_version":2,
		"case_id":"jade-testunit-legacy-0001",
		"confiscated":7,
		"closed_at":time()-3600,
		"status":"matched_snapshot_closed",
	]);
	int before_jade=YUSHID->query_physical_all_num(player);
	mapping first=JADE_RECOVERYD->apply_if_listed(player);
	int first_end=player->query_vip_end_time();
	int first_mails=arrayp(player->inbox) ? sizeof(player->inbox) : 0;
	mapping second=JADE_RECOVERYD->apply_if_listed(player);
	mapping receipt=player["/plus/illicit_jade_recovery_once"];
	check("旧版已扣玉回执无需有效快照也会补VIP和邮件且不再扣玉",
		first["code"]=="already_closed" &&
		second["code"]=="already_closed" &&
		YUSHID->query_physical_all_num(player)==before_jade &&
		player->query_vip_flag()==4 &&
		(int)receipt["compensation_vip_seconds"]==2592000 &&
		first_mails==1 &&
		(arrayp(player->inbox) ? sizeof(player->inbox) : 0)==first_mails &&
		player->query_vip_end_time()==first_end,
		"旧回执被重复扣玉、漏发补偿或重复补发");
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
	check("无精确证据和未启用旧清单绝不进入扣除逻辑",
		missing["code"]=="no_exact_evidence" &&
		disabled["code"]=="no_exact_evidence" &&
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
		cutoff["code"]=="no_exact_evidence" &&
		bad_hash["code"]=="no_exact_evidence" &&
		expired["code"]=="no_exact_evidence" &&
		inconsistent_fee["code"]=="no_exact_evidence" &&
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
		YUSHID->query_physical_all_num(player)==16 &&
		player->query_vip_flag()==0 &&
		(!arrayp(player->inbox) || !sizeof(player->inbox)),
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
	string master_source=Stdio.read_file(ROOT+"/gamelib/master.pike");
	string system_master_source=Stdio.read_file(ROOT+"/lowlib/system/master.pike");
	check("登录钩子异常不会阻断正常登录",
		source && search(source,
			"jade_recovery_err=catch{ JADE_RECOVERYD->apply_on_login(me); }")!=-1 &&
		search(source,"login hook failed safely")!=-1 && master_source &&
		search(master_source,"\"jade_recoveryd.pike\"")!=-1 &&
		system_master_source &&
		search(system_master_source,"\"jade_recoveryd.pike\"")!=-1,
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
	test_automatic_login_exact_evidence_recovery();
	test_automatic_login_fee_allowance_and_spent_forgiveness();
	test_automatic_login_closes_zero_without_future_debt();
	test_auto_evidence_parser_only_accepts_exact_mints();
	test_auto_evidence_validation_fails_closed();
	test_automatic_recovery_defers_shared_source_jade();
	test_automatic_recovery_runtime_cap();
	test_production_log_scanner_is_bounded_and_well_formed();
	test_exact_one_time_recovery();
	test_existing_higher_vip_is_extended_without_downgrade();
	test_expired_vip_does_not_extend_stale_end_time();
	test_legacy_closed_receipt_gets_compensation_only();
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
