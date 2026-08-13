/**
 * Evidence-gated, one-time recovery of historically minted physical jade.
 *
 * This daemon never infers guilt from a balance or activity level. It only
 * accepts an explicitly approved runtime manifest produced by the offline
 * audit tool. Shared recharge balance and future jade are never touched.
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define RECOVERY_MANIFEST DATA_ROOT "security/illicit_jade_recovery.json"
#define RECOVERY_CLAIM_ROOT DATA_ROOT "security/illicit_jade_recovery_claims"
#define RECOVERY_LOG ROOT "/log/illicit_jade_recovery.log"
#define RECOVERY_RECEIPT "/plus/illicit_jade_recovery_once"
#define RECOVERY_POLICY "one_time_current_physical_only_no_future_debt"
#define RECOVERY_MAX_SUIYU 20000000
#define RECOVERY_MANIFEST_MAX_SIZE 1048576
#define RECOVERY_CACHE_SECONDS 5

private Thread.Mutex manifest_lock=Thread.Mutex();
private mapping(string:mixed) cached_manifest=([]);
private int cached_manifest_mtime=-1;
private int cached_manifest_checked_at;
private mapping(string:mixed)|zero test_manifest_override;

protected void create()
{
}

private int valid_userid(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>64 ||
	   search(value,"..")!=-1)
		return 0;
	foreach(value;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='_')
			continue;
		return 0;
	}
	return 1;
}

private int valid_hex(string value,int length)
{
	if(!value || sizeof(value)!=length)
		return 0;
	for(int index=0;index<sizeof(value);index++){
		int one=value[index];
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

private int valid_case_id(string value)
{
	if(!value || sizeof(value)<16 || sizeof(value)>80)
		return 0;
	for(int index=0;index<sizeof(value);index++){
		int one=value[index];
		if((one>='a' && one<='z') || (one>='0' && one<='9') ||
		   one=='-' || one=='_')
			continue;
		return 0;
	}
	return 1;
}

private int valid_iso_date(string value)
{
	int year;
	int month;
	int day;
	array(int) days=({31,28,31,30,31,30,31,31,30,31,30,31});
	if(!value || sizeof(value)!=10 || value[4]!='-' || value[7]!='-' ||
	   sscanf(value,"%d-%d-%d",year,month,day)!=3 ||
	   year<2000 || year>2200 || month<1 || month>12)
		return 0;
	if(!(year%400) || (!(year%4) && year%100))
		days[1]=29;
	return day>=1 && day<=days[month-1];
}

private string recovery_digest(string value)
{
	object hash=Crypto.SHA256();
	hash->update(value || "");
	return lower_case(String.string2hex(hash->digest()));
}

private mapping(string:mixed) decode_manifest(string source)
{
	mixed decoded;
	mixed err;
	if(!source || source=="" || sizeof(source)>RECOVERY_MANIFEST_MAX_SIZE)
		return ([]);
	err=catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded))
		return ([]);
	return (mapping(string:mixed))decoded;
}

private mapping(string:mixed) load_manifest()
{
	object key=manifest_lock->lock();
	mapping(string:mixed) result=([]);
	if(test_manifest_override){
		result=test_manifest_override;
		destruct(key);
		return result;
	}
	Stdio.Stat stat=file_stat(RECOVERY_MANIFEST);
	int modified=stat && stat->isreg ? stat->mtime : -1;
	if(time()-cached_manifest_checked_at<RECOVERY_CACHE_SECONDS &&
	   modified==cached_manifest_mtime){
		result=cached_manifest;
		destruct(key);
		return result;
	}
	cached_manifest_checked_at=time();
	cached_manifest_mtime=modified;
	cached_manifest=([]);
	if(stat && stat->isreg && stat->size>0 &&
	   stat->size<=RECOVERY_MANIFEST_MAX_SIZE)
		cached_manifest=decode_manifest(Stdio.read_file(RECOVERY_MANIFEST));
	result=cached_manifest;
	destruct(key);
	return result;
}

private mapping(string:mixed) approved_entry(mapping(string:mixed) manifest,
	string userid)
{
	if(!mappingp(manifest) || (int)manifest["schema_version"]!=2 ||
	   !(int)manifest["enabled"] || manifest["state"]!="approved" ||
	   manifest["policy"]!=RECOVERY_POLICY ||
	   !valid_iso_date((string)manifest["created_before"]) ||
	   !mappingp(manifest["accounts"]))
		return ([]);
	mapping accounts=(mapping)manifest["accounts"];
	if(!mappingp(accounts[userid]))
		return ([]);
	mapping(string:mixed) entry=(mapping(string:mixed))accounts[userid];
	int captured=(int)entry["captured_physical_suiyu"];
	int captured_storage=(int)entry["captured_personal_storage_suiyu"];
	int captured_shared=(int)entry["captured_shared_source_suiyu"];
	int captured_wallet=(int)entry["captured_wallet_suiyu"];
	int all_fee=(int)entry["all_fee"];
	int fee_allowance=(int)entry["fee_allowance_suiyu"];
	int legal_non_all_fee=(int)entry["legal_non_all_fee_suiyu"];
	int unexplained=(int)entry["unexplained_remaining_suiyu"];
	int exact_minted=(int)entry["exact_minted_suiyu"];
	int captured_at=(int)entry["balance_captured_at"];
	int expires_at=(int)entry["snapshot_expires_at"];
	if(!(int)entry["approved"] || entry["userid"]!=userid ||
	   !valid_userid(userid) || !valid_case_id((string)entry["case_id"]) ||
	   !valid_hex((string)entry["evidence_sha256"],64) ||
	   !valid_hex((string)entry["balance_snapshot_sha256"],64) ||
	   !valid_iso_date((string)entry["registered_on"]) ||
	   (string)entry["registered_on"]>=(string)manifest["created_before"] ||
	   captured<0 || captured_storage<0 || captured_shared!=0 ||
	   captured>1000000000000 || all_fee<0 || all_fee>1000000000000 ||
	   captured_storage>1000000000000 ||
	   captured_wallet<0 || captured_wallet>1000000000000 ||
	   fee_allowance!=all_fee*10 || legal_non_all_fee<0 ||
	   legal_non_all_fee>1000000000000 ||
	   exact_minted<0 || exact_minted>1000000000000 ||
	   unexplained!=max(0,captured+captured_storage-fee_allowance-
		legal_non_all_fee) ||
	   captured_at<=0 || expires_at<=captured_at ||
	   expires_at-captured_at>86400 || time()>expires_at ||
	   (int)entry["proven_suiyu"]<1 ||
	   (int)entry["proven_suiyu"]>RECOVERY_MAX_SUIYU ||
	   (int)entry["proven_suiyu"]>unexplained ||
	   (int)entry["proven_suiyu"]>captured+captured_storage ||
	   (exact_minted<(int)entry["proven_suiyu"] &&
		entry["legal_ledger_complete"]!=1))
		return ([]);
	return entry;
}

private string user_claim_path(string userid)
{
	return RECOVERY_CLAIM_ROOT+"/"+recovery_digest(userid);
}

/**
 * A permanent, user-level claim is intentionally acquired before mutation.
 * Across Workers it is both a mutex and a lifetime once-only fence. If the
 * process dies after claiming, the case is forgiven instead of ever risking a
 * second deduction from a stale player object.
 */
private int acquire_user_claim(string claim_path)
{
	Stdio.mkdirhier(RECOVERY_CLAIM_ROOT);
	return mkdir(claim_path);
}

private void append_recovery_log(string userid,string case_id,string status,
	int proven,int before_physical,int before_storage,int confiscated,
	int after_physical,int after_storage,string evidence_sha256)
{
	mixed err=catch{
		Stdio.append_file(RECOVERY_LOG,sprintf(
			"%d\tstatus=%s\tuserid=%s\tcase_id=%s\tproven_suiyu=%d"
			"\tbefore_physical=%d\tbefore_personal_storage=%d"
			"\tconfiscated=%d\tafter_physical=%d"
			"\tafter_personal_storage=%d"
			"\tevidence_sha256=%s\tpolicy=%s\n",
			time(),status,userid,case_id,proven,before_physical,
			before_storage,confiscated,after_physical,after_storage,
			evidence_sha256,RECOVERY_POLICY));
	};
	if(err)
		werror("[JADE_RECOVERY] audit append failed: %s\n",
			describe_error(err));
}

private int personal_storage_yushi_level(array row)
{
	if(!arrayp(row) || sizeof(row)<7 || !stringp(row[3]) ||
	   !intp(row[6]) || (int)row[6]<0)
		return 0;
	for(int level=1;level<=5;level++)
		if((string)row[3]=="yushi/"+YUSHID->get_yushi_name(level))
			return level;
	return 0;
}

private int personal_storage_yushi_rows(array rows)
{
	int total=0;
	if(!arrayp(rows))
		return 0;
	foreach(rows,array row){
		int level=personal_storage_yushi_level(row);
		if(level)
			total+=(int)row[6]*YUSHID->get_yushi_value(level);
	}
	return total;
}

int query_personal_storage_yushi(object player)
{
	if(!player || !arrayp(player->packaged_items))
		return 0;
	return personal_storage_yushi_rows((array)player->packaged_items);
}

private int personal_storage_yushi_units(object player,int level)
{
	int total=0;
	if(!player || !arrayp(player->packaged_items) || level<1 || level>5)
		return 0;
	foreach((array)player->packaged_items,array row)
		if(personal_storage_yushi_level(row)==level)
			total+=(int)row[6];
	return total;
}

private int remove_personal_storage_yushi_units(object player,int level,
	int requested)
{
	array updated=({});
	int removed=0;
	if(!player || !arrayp(player->packaged_items) || requested<=0)
		return 0;
	foreach((array)player->packaged_items,array original){
		array row=copy_value(original);
		if(removed<requested && personal_storage_yushi_level(row)==level){
			int take=min(requested-removed,(int)row[6]);
			row[6]=(int)row[6]-take;
			if((int)row[6]>0)
				row[2]="("+(string)(int)row[6]+")块"+(string)row[1];
			removed+=take;
		}
		if(!personal_storage_yushi_level(row) || (int)row[6]>0)
			updated+=({row});
	}
	player->packaged_items=updated;
	return removed;
}

private int restore_personal_yushi_value(object player,int before_physical,
	array before_storage)
{
	int current;
	int adjusted=1;
	if(!player || !arrayp(before_storage))
		return 0;
	player->packaged_items=copy_value(before_storage);
	current=YUSHID->query_physical_all_num(player);
	if(current>before_physical)
		adjusted=YUSHID->pay_yushi(player,current-before_physical);
	else if(current<before_physical)
		adjusted=YUSHID->give_yushi(player,before_physical-current);
	return adjusted &&
		YUSHID->query_physical_all_num(player)==before_physical;
}

private mapping(string:mixed) debit_personal_yushi(object player,int amount,
	int before_physical,array before_storage)
{
	int storage_direct=0;
	int remaining=amount;
	int before_total=before_physical+query_personal_storage_yushi(player);
	if(amount<0 || amount>before_total)
		return (["ok":0,"code":"amount_out_of_range"]);
	for(int level=5;level>=1 && remaining>0;level--){
		int value=YUSHID->get_yushi_value(level);
		int units=min(personal_storage_yushi_units(player,level),
			remaining/value);
		if(units>0){
			int removed=remove_personal_storage_yushi_units(player,level,units);
			storage_direct+=removed*value;
			remaining-=removed*value;
		}
	}
	if(YUSHID->query_physical_all_num(player)<remaining){
		int moved=0;
		for(int level=1;level<=5 && !moved;level++){
			int value=YUSHID->get_yushi_value(level);
			if(personal_storage_yushi_units(player,level)<=0 ||
			   YUSHID->query_physical_all_num(player)+value<remaining)
				continue;
			if(remove_personal_storage_yushi_units(player,level,1)!=1)
				break;
			int physical_before_move=YUSHID->query_physical_all_num(player);
			object jade=clone(ROOT+"/gamelib/clone/item/yushi/"+
				YUSHID->get_yushi_name(level));
			if(jade){
				jade->amount=1;
				jade->move(player);
			}
			moved=YUSHID->query_physical_all_num(player)==
				physical_before_move+value;
			if(jade && environment(jade)!=player)
				destruct(jade);
		}
		if(!moved){
			restore_personal_yushi_value(player,before_physical,before_storage);
			return (["ok":0,"code":"storage_change_failed"]);
		}
	}
	if(remaining>0 && !YUSHID->pay_yushi(player,remaining)){
		restore_personal_yushi_value(player,before_physical,before_storage);
		return (["ok":0,"code":"physical_debit_failed"]);
	}
	int after_physical=YUSHID->query_physical_all_num(player);
	int after_storage=query_personal_storage_yushi(player);
	if(after_physical+after_storage!=before_total-amount){
		restore_personal_yushi_value(player,before_physical,before_storage);
		return (["ok":0,"code":"debit_invariant_failed"]);
	}
	return (["ok":1,"storage_direct":storage_direct,
		"physical_payment":remaining,"after_physical":after_physical,
		"after_storage":after_storage]);
}

/** Restore the exact pre-operation balance; shared recharge must not move. */
private int rollback_exact(object player,int before_wallet,
	int before_physical,array before_storage,string reason)
{
	int rolled_back;
	int physical_now=-1;
	int storage_now=-1;
	int wallet_now=-1;
	mixed err=catch{
		rolled_back=restore_personal_yushi_value(player,before_physical,
			before_storage);
		physical_now=YUSHID->query_physical_all_num(player);
		storage_now=query_personal_storage_yushi(player);
		wallet_now=ACCOUNT_WALLETD->query_balance(player);
	};
	return !err && rolled_back && physical_now==before_physical &&
		storage_now==personal_storage_yushi_rows(before_storage) &&
		wallet_now==before_wallet;
}

private mapping(string:mixed) perform_recovery(object player,
	mapping(string:mixed) entry)
{
	string case_id=(string)entry["case_id"];
	string evidence_sha256=(string)entry["evidence_sha256"];
	int proven=(int)entry["proven_suiyu"];
	int captured_physical=(int)entry["captured_physical_suiyu"];
	int captured_storage=(int)entry["captured_personal_storage_suiyu"];
	int captured_wallet=(int)entry["captured_wallet_suiyu"];
	int captured_all_fee=(int)entry["all_fee"];
	int before_all_fee;
	int before_physical;
	int before_storage;
	int before_wallet;
	int confiscated;
	int after_physical;
	int after_storage;
	int after_wallet;
	int paid;
	int saved;
	mixed debit_err;
	mixed save_err;
	array before_storage_rows=player && arrayp(player->packaged_items) ?
		copy_value(player->packaged_items) : ({});
	mapping debit=([]);
	if(mappingp(player[RECOVERY_RECEIPT]))
		return (["ok":1,"code":"already_closed","confiscated":0]);
	before_physical=YUSHID->query_physical_all_num(player);
	before_storage=query_personal_storage_yushi(player);
	before_wallet=ACCOUNT_WALLETD->query_balance(player);
	before_all_fee=ACCOUNT_WALLETD->query_total_recharge_fee(player);
	// The snapshot is a one-hour one-time evidence window. Any intervening
	// spend, reward, transfer or recharge makes old and new jade impossible to
	// distinguish, so close with zero rather than touching a possibly new asset.
	confiscated=before_physical==captured_physical &&
		before_storage==captured_storage &&
		before_wallet==captured_wallet && before_all_fee==captured_all_fee ?
		proven : 0;
	debit_err=catch{
		debit=confiscated>0 ? debit_personal_yushi(player,confiscated,
			before_physical,before_storage_rows) : (["ok":1]);
		paid=(int)debit["ok"];
		after_physical=YUSHID->query_physical_all_num(player);
		after_storage=query_personal_storage_yushi(player);
		after_wallet=ACCOUNT_WALLETD->query_balance(player);
	};
	if(debit_err || !paid ||
	   after_physical+after_storage!=
		before_physical+before_storage-confiscated ||
	   after_wallet!=before_wallet){
		int restored=confiscated==0 ||
			rollback_exact(player,before_wallet,before_physical,
				before_storage_rows,"illicit_jade_recovery_debit_failed");
		append_recovery_log((string)player->query_name(),case_id,
			restored ? "debit_failed_rolled_back" :
				"critical_debit_rollback_failed",
			proven,before_physical,before_storage,0,
			YUSHID->query_physical_all_num(player),
			query_personal_storage_yushi(player),evidence_sha256);
		if(!restored)
			werror("[JADE_RECOVERY] CRITICAL debit rollback failed "
				"userid=%s case=%s\n",(string)player->query_name(),case_id);
		return (["ok":0,"code":"physical_debit_failed",
			"confiscated":0]);
	}
	mapping receipt=(["schema_version":2,"case_id":case_id,
		"proven_suiyu":proven,"confiscated":confiscated,
		"before_physical":before_physical,"after_physical":after_physical,
		"before_personal_storage":before_storage,
		"after_personal_storage":after_storage,
		"evidence_sha256":evidence_sha256,"closed_at":time(),
		"policy":RECOVERY_POLICY,
		"status":confiscated>0 ?
			"matched_snapshot_closed" : "snapshot_changed_closed"]);
	save_err=catch{
		player[RECOVERY_RECEIPT]=receipt;
		saved=functionp(player->save_with_result) && player->save_with_result();
	};
	if(save_err || !saved){
		int restored=confiscated==0;
		mixed rollback_err=catch{
			player->m_delete_foruser(RECOVERY_RECEIPT);
			if(confiscated>0)
				restored=rollback_exact(player,before_wallet,before_physical,
					before_storage_rows,
					"illicit_jade_recovery_save_failed");
		};
		if(rollback_err || !restored){
			// Fail closed in memory. If a later autosave succeeds, this receipt
			// prevents a second deduction; if no save can succeed, the disk still
			// contains the untouched pre-operation state.
			receipt["status"]="rollback_failed_closed";
			player[RECOVERY_RECEIPT]=receipt;
			catch{ player->save_with_result(); };
			append_recovery_log((string)player->query_name(),case_id,
				"critical_rollback_failed",proven,before_physical,
				before_storage,confiscated,
				YUSHID->query_physical_all_num(player),
				query_personal_storage_yushi(player),
				evidence_sha256);
			werror("[JADE_RECOVERY] CRITICAL save rollback failed "
				"userid=%s case=%s\n",
				(string)player->query_name(),case_id);
			return (["ok":0,"code":"critical_rollback_failed",
				"confiscated":confiscated]);
		}
		append_recovery_log((string)player->query_name(),case_id,
			"save_failed_rolled_back",proven,before_physical,
			before_storage,0,YUSHID->query_physical_all_num(player),
			query_personal_storage_yushi(player),evidence_sha256);
		return (["ok":0,"code":"save_failed","confiscated":0]);
	}
	append_recovery_log((string)player->query_name(),case_id,
		confiscated>0 ? "closed" :
			"snapshot_changed_closed",
		proven,
		before_physical,before_storage,confiscated,after_physical,
		after_storage,evidence_sha256);
	if(confiscated>0)
		catch{ tell_object(player,
			"系统依据已复核的历史异常记录，一次性回收了"+
			YUSHID->get_yushi_for_desc(confiscated)+
			"。本次处置已经结案，以后充值和获得的玉石不会继续扣除。\n"); };
	return (["ok":1,"code":"closed","confiscated":confiscated,
		"proven_suiyu":proven]);
}

mapping(string:mixed) apply_if_listed(object player)
{
	string userid;
	mapping(string:mixed) entry;
	mapping(string:mixed) result=([]);
	string claim_path;
	mixed operation_err;
	if(!player || !functionp(player->query_name))
		return (["ok":0,"code":"invalid_player"]);
	userid=(string)player->query_name();
	if(!valid_userid(userid))
		return (["ok":0,"code":"invalid_userid"]);
	entry=approved_entry(load_manifest(),userid);
	if(!sizeof(entry))
		return (["ok":1,"code":"not_listed","confiscated":0]);
	claim_path=user_claim_path(userid);
	if(mappingp(player[RECOVERY_RECEIPT])){
		// Repair a missing shared fence from the durable player receipt before
		// any stale Worker object can enter this user-level case.
		Stdio.mkdirhier(RECOVERY_CLAIM_ROOT);
		mkdir(claim_path);
		return (["ok":1,"code":"already_closed","confiscated":0]);
	}
	if(!acquire_user_claim(claim_path))
		return (["ok":1,"code":"already_claimed","confiscated":0]);
	operation_err=catch{ result=perform_recovery(player,entry); };
	if(operation_err){
		werror("[JADE_RECOVERY] operation failed userid=%s case=%s error=%s\n",
			userid,(string)entry["case_id"],describe_error(operation_err));
		return (["ok":0,"code":"exception","confiscated":0]);
	}
	return result;
}

/** TestUnit-only in-memory manifest. Production ids are deliberately denied. */
int test_set_manifest(mapping(string:mixed) manifest)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" ||
	   !mappingp(manifest) || !mappingp(manifest["accounts"]))
		return 0;
	foreach((mapping)manifest["accounts"];mixed raw_userid;mixed ignored){
		if(!stringp(raw_userid) || search((string)raw_userid,"testunit")==-1)
			return 0;
	}
	// Test ids are isolated from production and may be reused by a later full
	// restart. Production claims are permanent and never enter this path.
	foreach((mapping)manifest["accounts"];mixed raw_userid;mixed ignored)
		rm(user_claim_path((string)raw_userid));
	object key=manifest_lock->lock();
	test_manifest_override=manifest;
	destruct(key);
	return 1;
}

void test_clear_manifest()
{
	object key=manifest_lock->lock();
	if(getenv("XIAND_RUN_TESTUNIT")=="1" && test_manifest_override &&
	   mappingp(test_manifest_override["accounts"]))
		foreach((mapping)test_manifest_override["accounts"];
		   mixed raw_userid;mixed ignored)
			if(stringp(raw_userid) &&
			   search((string)raw_userid,"testunit")!=-1)
				rm(user_claim_path((string)raw_userid));
	test_manifest_override=0;
	destruct(key);
}
