/**
 * Evidence-gated, one-time recovery of historically minted physical jade.
 *
 * This daemon never infers guilt from a balance or activity level. Historical
 * conversion logs must prove the exact amount minted by the old 2 -> 20 split
 * bug. On login the player's live personal holdings and all_fee allowance are
 * checked, then the case is permanently closed exactly once. The old approved
 * manifest remains a rollback-compatible input, but is no longer required.
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
#define RECOVERY_COMPENSATION_VIP_LEVEL 4
#define RECOVERY_COMPENSATION_SECONDS 2592000
#define RECOVERY_AUTO_CUTOFF_MONTH 202608
#define RECOVERY_AUTO_CUTOFF_DATE "2026-08-01"
#define RECOVERY_AUTO_LOG_FILE_MAX_SIZE (8*1024*1024)
#define RECOVERY_AUTO_LOG_TOTAL_MAX_SIZE (64*1024*1024)
#define RECOVERY_AUTO_REG_FILE_MAX_SIZE (4*1024*1024)
#define RECOVERY_AUTO_MAX_EVENTS 200000

private Thread.Mutex manifest_lock=Thread.Mutex();
private mapping(string:mixed) cached_manifest=([]);
private int cached_manifest_mtime=-1;
private int cached_manifest_checked_at;
private mapping(string:mixed)|zero test_manifest_override;
private Thread.Mutex auto_evidence_lock=Thread.Mutex();
private mapping(string:mixed) auto_evidence_index=([]);
private int auto_evidence_loaded;
private mapping(string:mixed)|zero test_auto_evidence_override;

protected void create()
{
	call_out(warm_auto_evidence,1);
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

private int safe_regular_file(string path,int max_size)
{
	Stdio.Stat stat;
	if(!path || max_size<=0)
		return 0;
	// file_stat(path,1) does not follow symlinks. Recovery evidence must never
	// be redirected outside the mounted audit-log tree.
	stat=file_stat(path,1);
	return stat && stat->isreg && stat->size>0 && stat->size<=max_size;
}

private int valid_log_month_name(string name)
{
	int year;
	int month;
	if(!name || sscanf(name,"yushi_change-%d-%d.log",year,month)!=2 ||
	   year<2000 || year>2200 || month<1 || month>12 ||
	   name!=sprintf("yushi_change-%04d-%02d.log",year,month))
		return 0;
	return year*100+month;
}

private void register_creation_user(mapping(string:int) registered,
	string userid)
{
	if(valid_userid(userid))
		registered[userid]=1;
}

private void scan_compact_registration_files(mapping(string:int) registered)
{
	string root=ROOT+"/gamelib/data/uniq_user";
	array(string) names=get_dir(root) || ({});
	foreach(names,string name){
		int day;
		string path;
		string source;
		if(sscanf(name,"xd.%d.txt",day)!=1 || day<20000101 ||
		   day>=20260801 || name!=sprintf("xd.%08d.txt",day))
			continue;
		path=root+"/"+name;
		if(!safe_regular_file(path,RECOVERY_AUTO_REG_FILE_MAX_SIZE))
			continue;
		source=Stdio.read_file(path);
		if(!source)
			continue;
		foreach(source/"\n",string raw)
			register_creation_user(registered,
				String.trim_all_whites(raw));
	}
}

private void scan_runtime_registration_files(mapping(string:int) registered)
{
	string root=ROOT+"/log/stat/reg";
	array(string) names=get_dir(root) || ({});
	foreach(names,string name){
		int year;
		int month;
		int day;
		string suffix;
		string prefix;
		string path;
		string source;
		// Pike counts the suppressed %*s conversion in sscanf's result.
		if(sscanf(name,"%*s_reg_%d-%d-%d.log",year,month,day)!=4 ||
		   year<2000 || year>2200 || month<1 || month>12 || day<1 ||
		   day>31 || year*10000+month*100+day>=20260801)
			continue;
		suffix=sprintf("_reg_%04d-%02d-%02d.log",year,month,day);
		if(!has_suffix(name,suffix) || sizeof(name)<=sizeof(suffix) ||
		   !valid_iso_date(sprintf("%04d-%02d-%02d",year,month,day)))
			continue;
		prefix=name[..sizeof(name)-sizeof(suffix)-1];
		if(!valid_userid(prefix))
			continue;
		path=root+"/"+name;
		if(!safe_regular_file(path,RECOVERY_AUTO_REG_FILE_MAX_SIZE))
			continue;
		source=Stdio.read_file(path);
		if(!source)
			continue;
		foreach(source/"\n",string line){
			array(string) fields=line/"][";
			if(sizeof(fields)>=3)
				register_creation_user(registered,fields[1]);
		}
	}
}

private string legacy_conversion_userid(string line)
{
	int marker;
	int opening=-1;
	string userid;
	if(!line || (marker=search(line,") 打算打碎"))<=0)
		return "";
	for(int index=marker-1;index>=0;index--)
		if(line[index]=='('){
			opening=index;
			break;
		}
	if(opening<0 || opening+1>=marker)
		return "";
	userid=line[opening+1..marker-1];
	return valid_userid(userid) ? userid : "";
}

private mapping(string:string) structured_conversion_fields(string line)
{
	mapping(string:string) fields=([]);
	if(!line || search(line,"event=yushi_conversion")==-1)
		return fields;
	foreach(line/"\t",string part){
		int separator=search(part,"=");
		if(separator>0 && separator<sizeof(part)-1)
			fields[part[..separator-1]]=String.trim_all_whites(
				part[separator+1..]);
	}
	return fields;
}

private void add_auto_evidence(mapping(string:mapping(string:mixed)) rows,
	string userid,int amount,string route,string fingerprint,int event_month)
{
	mapping(string:mixed) row;
	if(!valid_userid(userid) || amount<=0 ||
	   amount>1000000000000 || !valid_hex(fingerprint,64))
		return;
	row=rows[userid];
	if(!row){
		row=(["userid":userid,"exact_minted_suiyu":0,"event_count":0,
			"routes":([]),"fingerprints":({}),
			"creation_proven_by_event":0]);
		rows[userid]=row;
	}
	if((int)row["exact_minted_suiyu"]>1000000000000-amount)
		return;
	row["exact_minted_suiyu"]=(int)row["exact_minted_suiyu"]+amount;
	row["event_count"]=(int)row["event_count"]+1;
	((mapping)row["routes"])[route]=(int)((mapping)row["routes"])[route]+1;
	row["fingerprints"]+=({fingerprint});
	if(event_month>0 && event_month<RECOVERY_AUTO_CUTOFF_MONTH)
		row["creation_proven_by_event"]=1;
}

private int count_exact_legacy_mints(string file_name,int line_number,
	string line,string userid,int event_month,
	mapping(string:mapping(string:mixed)) rows)
{
	array(array(mixed)) patterns=({
		({"将(2)xianyuanyu打碎获得(20)suiyu",10}),
		({"将(2)linglongyu打碎获得(20)xianyuanyu",100}),
		({"将(2)biluanyu打碎获得(20)linglongyu",1000}),
		({"将(2)xuantianbaoyu打碎获得(20)biluanyu",10000}),
	});
	int found=0;
	foreach(patterns,array(mixed) one){
		string pattern=(string)one[0];
		int start=0;
		int position;
		while((position=search(line,pattern,start))!=-1){
			string fingerprint=recovery_digest(file_name+"\0"+
				(string)line_number+"\0"+(string)position+"\0"+line);
			add_auto_evidence(rows,userid,(int)one[1],
				"legacy_split_remainder_bug",fingerprint,event_month);
			found++;
			start=position+sizeof(pattern);
		}
	}
	return found;
}

private int scan_structured_exact_mint(string file_name,int line_number,
	string line,int event_month,mapping(string:mapping(string:mixed)) rows)
{
	mapping(string:string) fields=structured_conversion_fields(line);
	string userid=(string)fields["player"];
	string status=(string)fields["status"];
	int source_value;
	int target_value;
	if(!sizeof(fields) || !valid_userid(userid) ||
	   (status!="success" && status!="partial") ||
	   sscanf((string)fields["source_value"],"%d",source_value)!=1 ||
	   sscanf((string)fields["target_value"],"%d",target_value)!=1 ||
	   source_value<0 || target_value<=source_value ||
	   target_value-source_value>1000000000000)
		return 0;
	string fingerprint=recovery_digest(file_name+"\0"+
		(string)line_number+"\0"+line);
	add_auto_evidence(rows,userid,target_value-source_value,
		"structured_conversion",fingerprint,event_month);
	return 1;
}

private mapping(string:mixed) build_auto_evidence_index()
{
	string log_root=ROOT+"/log/fee_log";
	array(string) names=sort(get_dir(log_root) || ({}));
	mapping(string:int) registered=([]);
	mapping(string:mapping(string:mixed)) rows=([]);
	mapping(string:mixed) accounts=([]);
	int total_size=0;
	int total_events=0;
	scan_compact_registration_files(registered);
	scan_runtime_registration_files(registered);
	foreach(names,string name){
		int event_month=valid_log_month_name(name);
		string path;
		Stdio.Stat stat;
		string source;
		int line_number=0;
		if(!event_month)
			continue;
		path=log_root+"/"+name;
		stat=file_stat(path,1);
		if(!stat || !stat->isreg || stat->size<=0 ||
		   stat->size>RECOVERY_AUTO_LOG_FILE_MAX_SIZE ||
		   total_size>RECOVERY_AUTO_LOG_TOTAL_MAX_SIZE-stat->size){
			werror("[JADE_RECOVERY] skipped unsafe evidence file=%s\n",name);
			continue;
		}
		total_size+=stat->size;
		source=Stdio.read_file(path);
		if(!source || sizeof(source)!=stat->size)
			continue;
		foreach(source/"\n",string line){
			string userid;
			line_number++;
			if(total_events>=RECOVERY_AUTO_MAX_EVENTS)
				break;
			if(search(line,"event=yushi_conversion")!=-1){
				total_events+=scan_structured_exact_mint(name,
					line_number,line,event_month,rows);
				continue;
			}
			userid=legacy_conversion_userid(line);
			if(userid!="")
				total_events+=count_exact_legacy_mints(name,line_number,
					line,userid,event_month,rows);
		}
		if(total_events>=RECOVERY_AUTO_MAX_EVENTS){
			werror("[JADE_RECOVERY] exact evidence event limit reached; "
				"remaining logs were skipped safely\n");
			break;
		}
	}
	foreach(rows;string userid;mapping(string:mixed) row){
		array(string) fingerprints=(array(string))row["fingerprints"];
		if(!registered[userid] && !(int)row["creation_proven_by_event"])
			continue;
		sort(fingerprints);
		string evidence_sha256=recovery_digest(fingerprints*"\n");
		accounts[userid]=(["userid":userid,
			"exact_minted_suiyu":(int)row["exact_minted_suiyu"],
			"event_count":(int)row["event_count"],
			"routes":copy_value(row["routes"]),
			"evidence_sha256":evidence_sha256,
			"registered_before_cutoff":1]);
	}
	return (["schema_version":1,"created_before":RECOVERY_AUTO_CUTOFF_DATE,
		"generated_at":time(),"accounts":accounts,
		"scanned_bytes":total_size,"exact_event_count":total_events]);
}

private mapping(string:mixed) load_auto_evidence_index()
{
	object key=auto_evidence_lock->lock();
	mapping(string:mixed) result=([]);
	if(test_auto_evidence_override)
		result=test_auto_evidence_override;
	else if(auto_evidence_loaded)
		result=auto_evidence_index;
	else{
		mixed err=catch{ auto_evidence_index=build_auto_evidence_index(); };
		auto_evidence_loaded=1;
		if(err){
			auto_evidence_index=([]);
			werror("[JADE_RECOVERY] automatic evidence scan failed safely: %s\n",
				describe_error(err));
		}
		else
			werror("[JADE_RECOVERY] automatic evidence ready accounts=%d "
				"events=%d bytes=%d\n",
				mappingp(auto_evidence_index["accounts"]) ?
					sizeof((mapping)auto_evidence_index["accounts"]) : 0,
				(int)auto_evidence_index["exact_event_count"],
				(int)auto_evidence_index["scanned_bytes"]);
		result=auto_evidence_index;
	}
	destruct(key);
	return result;
}

void warm_auto_evidence()
{
	// Read-only startup warmup keeps the first player login off the 5 MB
	// historical scan path. Any failure is already caught and logged inside.
	load_auto_evidence_index();
}

private mapping(string:mixed) automatic_evidence_row(string userid)
{
	mapping(string:mixed) index=load_auto_evidence_index();
	mapping accounts;
	mapping(string:mixed) row;
	if(!mappingp(index) || (int)index["schema_version"]!=1 ||
	   index["created_before"]!=RECOVERY_AUTO_CUTOFF_DATE ||
	   !mappingp(index["accounts"]))
		return ([]);
	accounts=(mapping)index["accounts"];
	if(!mappingp(accounts[userid]))
		return ([]);
	row=(mapping(string:mixed))accounts[userid];
	if(row["userid"]!=userid || !(int)row["registered_before_cutoff"] ||
	   (int)row["exact_minted_suiyu"]<=0 ||
	   (int)row["exact_minted_suiyu"]>1000000000000 ||
	   (int)row["event_count"]<=0 ||
	   (int)row["event_count"]>RECOVERY_AUTO_MAX_EVENTS ||
	   !valid_hex((string)row["evidence_sha256"],64))
		return ([]);
	return row;
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

private void append_compensation_log(string userid,string case_id,
	int confiscated,int vip_level,int vip_end,int mail_delivered)
{
	mixed err=catch{
		Stdio.append_file(RECOVERY_LOG,sprintf(
			"%d\tstatus=vip_compensation_granted\tuserid=%s\tcase_id=%s"
			"\tconfiscated=%d\tvip_level=%d\tvip_end=%d"
			"\tvip_seconds=%d\tmail_delivered=%d\n",
			time(),userid,case_id,confiscated,vip_level,vip_end,
			RECOVERY_COMPENSATION_SECONDS,mail_delivered));
	};
	if(err)
		werror("[JADE_RECOVERY] compensation audit append failed: %s\n",
			describe_error(err));
}

private int deliver_compensation_notice(object player)
{
	mapping(string:mixed) receipt;
	string body;
	int delivered=0;
	mixed err;
	if(!player || !mappingp(player[RECOVERY_RECEIPT]))
		return 0;
	receipt=(mapping(string:mixed))player[RECOVERY_RECEIPT];
	if(!(int)receipt["compensation_notice_pending"])
		return 1;
	body="系统依据已复核的历史异常记录，一次性回收了"+
		YUSHID->get_yushi_for_desc((int)receipt["confiscated"])+
		"。作为本次一次性处置补偿，已为你发放30天VIP"+
		(string)((int)receipt["compensation_vip_level"])+
		"会员；若你原有有效VIP高于4级，等级保持不降并顺延30天。"+
		"本案已结案，以后充值和正常获得的玉石不会继续扣除。";
	err=catch{
		delivered=player->recieve_mail("CHAT","仙道系统",
			player->query_name(),player->query_name_cn(),
			"异常玉石一次性回收补偿",body);
	};
	if(err || !delivered)
		return 0;
	receipt["compensation_notice_pending"]=0;
	receipt["compensation_notice_delivered_at"]=time();
	player[RECOVERY_RECEIPT]=receipt;
	if(!functionp(player->save_with_result) || !player->save_with_result())
		return 0;
	return 1;
}

// 兼容已经由旧版本完成扣除、但当时尚无VIP补偿字段的永久回执。
// 回执本身是成功扣除后与人物档案一起原子保存的凭据；这里只补偿，
// 不再读取过期快照、不再接触任何玉石。
private int ensure_closed_recovery_compensation(object player)
{
	mapping(string:mixed) receipt;
	mapping(string:mixed) original_receipt;
	mapping before_vip_history;
	int confiscated;
	int before_vip_flag;
	int before_vip_end;
	int compensation_vip_level;
	int compensation_vip_end;
	int saved=0;
	if(!player || !mappingp(player[RECOVERY_RECEIPT]))
		return 0;
	receipt=(mapping(string:mixed))player[RECOVERY_RECEIPT];
	confiscated=(int)receipt["confiscated"];
	if(confiscated<1)
		return 1;
	if((int)receipt["compensation_vip_seconds"]==
	   RECOVERY_COMPENSATION_SECONDS)
		return deliver_compensation_notice(player);
	original_receipt=copy_value(receipt);
	before_vip_flag=(int)player->query_vip_flag();
	before_vip_end=(int)player->query_vip_end_time();
	before_vip_history=mappingp(player->vip_history) ?
		copy_value(player->vip_history) : ([]);
	int active_vip_level=before_vip_end>time() ? before_vip_flag : 0;
	compensation_vip_level=max(RECOVERY_COMPENSATION_VIP_LEVEL,
		active_vip_level);
	if(compensation_vip_level>VIP_MAX_LEVEL)
		compensation_vip_level=VIP_MAX_LEVEL;
	compensation_vip_end=(active_vip_level>0 ? before_vip_end : time())+
		RECOVERY_COMPENSATION_SECONDS;
	mixed err=catch{
		player->set_vip_flag(compensation_vip_level);
		player->set_vip_end_time(compensation_vip_end);
		player->add_vip_history(compensation_vip_end,
			compensation_vip_level);
		receipt["compensation_vip_level"]=compensation_vip_level;
		receipt["compensation_vip_end"]=compensation_vip_end;
		receipt["compensation_vip_seconds"]=
			RECOVERY_COMPENSATION_SECONDS;
		receipt["compensation_notice_pending"]=1;
		receipt["compensation_migrated_at"]=time();
		player[RECOVERY_RECEIPT]=receipt;
		saved=functionp(player->save_with_result) &&
			player->save_with_result();
	};
	if(err || !saved){
		player->set_vip_flag(before_vip_flag);
		player->set_vip_end_time(before_vip_end);
		player->vip_history=copy_value(before_vip_history);
		player[RECOVERY_RECEIPT]=original_receipt;
		return 0;
	}
	if(PROFESSIONVIPD->is_supported_profession(player->query_profeId()))
		PROFESSIONVIPD->record_membership_state(player);
	int mail_delivered=deliver_compensation_notice(player);
	append_compensation_log((string)player->query_name(),
		(string)receipt["case_id"],confiscated,compensation_vip_level,
		compensation_vip_end,mail_delivered);
	catch{ tell_object(player,
		"历史异常玉石回收案件已补发30天VIP"+
		(string)compensation_vip_level+"会员；"+
		(mail_delivered ? "详细说明已发送至邮箱。\n" :
			"邮箱暂不可用，系统会在后续登录时重试发送。\n")); };
	return 1;
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

/**
 * Return jade that this exact character placed in the account warehouse.
 * A negative result means the shared record could not be proved healthy and
 * automatic recovery must defer without claiming or touching the player.
 */
private int query_shared_source_yushi(object player,string userid)
{
	mapping(string:mixed) storage;
	int total=0;
	if(!player || !valid_userid(userid))
		return -1;
	storage=ACCOUNT_STORAGED->query_storage(player);
	if(!(int)storage["ok"] || !arrayp(storage["items"]))
		return -1;
	foreach((array)storage["items"],mixed raw_item){
		mapping item;
		array data;
		if(!mappingp(raw_item))
			return -1;
		item=(mapping)raw_item;
		if((string)item["source_character"]!=userid)
			continue;
		if(!arrayp(item["data"]))
			return -1;
		data=(array)item["data"];
		int level=personal_storage_yushi_level(data);
		if(level){
			int value=(int)data[6]*YUSHID->get_yushi_value(level);
			if(value<0 || total>1000000000000-value)
				return -1;
			total+=value;
		}
	}
	return total;
}

private mapping(string:mixed) automatic_live_entry(object player,
	string userid)
{
	mapping(string:mixed) evidence=automatic_evidence_row(userid);
	int exact_minted;
	int before_physical;
	int before_storage;
	int before_shared;
	int before_wallet;
	int all_fee;
	int fee_allowance;
	int unexplained;
	int proven;
	string evidence_sha256;
	if(!sizeof(evidence))
		return ([]);
	exact_minted=(int)evidence["exact_minted_suiyu"];
	before_physical=YUSHID->query_physical_all_num(player);
	before_storage=query_personal_storage_yushi(player);
	before_shared=query_shared_source_yushi(player,userid);
	before_wallet=ACCOUNT_WALLETD->query_balance(player);
	all_fee=ACCOUNT_WALLETD->query_total_recharge_fee(player);
	if(before_shared<0)
		return (["deferred_code":"shared_storage_unavailable"]);
	if(before_physical<0 || before_storage<0 || before_wallet<0 || all_fee<0 ||
	   before_physical>1000000000000 ||
	   before_storage>1000000000000 || before_wallet>1000000000000 ||
	   all_fee>1000000000000)
		return (["deferred_code":"live_financial_state_invalid"]);
	// Shared storage needs its own account-file transaction. Never substitute
	// another character's or newly reloaded personal jade for that ambiguity.
	if(before_shared>0){
		append_recovery_log(userid,
			"jade-auto-deferred-shared-storage",
			"shared_storage_deferred",min(exact_minted,
				RECOVERY_MAX_SUIYU),before_physical,before_storage,0,
			before_physical,before_storage,
			(string)evidence["evidence_sha256"]);
		return (["deferred_code":"shared_storage_jade"]);
	}
	fee_allowance=all_fee*10;
	unexplained=max(0,before_physical+before_storage-fee_allowance);
	proven=min(exact_minted,unexplained);
	proven=min(proven,before_physical+before_storage);
	proven=min(proven,RECOVERY_MAX_SUIYU);
	evidence_sha256=(string)evidence["evidence_sha256"];
	return (["userid":userid,
		"case_id":"jade-auto-"+
			recovery_digest(userid+"|"+evidence_sha256)[..31],
		"proven_suiyu":proven,
		"evidence_sha256":evidence_sha256,
		"captured_physical_suiyu":before_physical,
		"captured_personal_storage_suiyu":before_storage,
		"captured_wallet_suiyu":before_wallet,
		"all_fee":all_fee,
		"source_mode":"automatic_login_evidence",
		"exact_minted_suiyu":exact_minted,
		"event_count":(int)evidence["event_count"]]);
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
	int before_vip_flag;
	int before_vip_end;
	int snapshot_matched;
	int compensation_vip_level;
	int compensation_vip_end;
	mapping before_vip_history;
	mixed debit_err;
	mixed compensation_err;
	mixed save_err;
	array before_storage_rows=player && arrayp(player->packaged_items) ?
		copy_value(player->packaged_items) : ({});
	mapping debit=([]);
	if(mappingp(player[RECOVERY_RECEIPT])){
		ensure_closed_recovery_compensation(player);
		return (["ok":1,"code":"already_closed","confiscated":0]);
	}
	before_physical=YUSHID->query_physical_all_num(player);
	before_storage=query_personal_storage_yushi(player);
	before_wallet=ACCOUNT_WALLETD->query_balance(player);
	before_all_fee=ACCOUNT_WALLETD->query_total_recharge_fee(player);
	before_vip_flag=(int)player->query_vip_flag();
	before_vip_end=(int)player->query_vip_end_time();
	before_vip_history=mappingp(player->vip_history) ?
		copy_value(player->vip_history) : ([]);
	// Approved-manifest entries use a short snapshot window. Automatic login
	// entries capture these same values immediately before this transaction.
	// In both modes any intervening mutation closes with zero rather than
	// touching a possibly new asset.
	snapshot_matched=before_physical==captured_physical &&
		before_storage==captured_storage &&
		before_wallet==captured_wallet && before_all_fee==captured_all_fee;
	confiscated=snapshot_matched ? proven : 0;
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
	compensation_err=catch{
		if(confiscated>0){
			int active_vip_level=before_vip_end>time() ? before_vip_flag : 0;
			compensation_vip_level=max(RECOVERY_COMPENSATION_VIP_LEVEL,
				active_vip_level);
			if(compensation_vip_level>VIP_MAX_LEVEL)
				compensation_vip_level=VIP_MAX_LEVEL;
			compensation_vip_end=(active_vip_level>0 ?
				before_vip_end : time())+RECOVERY_COMPENSATION_SECONDS;
			player->set_vip_flag(compensation_vip_level);
			player->set_vip_end_time(compensation_vip_end);
			player->add_vip_history(compensation_vip_end,
				compensation_vip_level);
		}
	};
	if(compensation_err){
		player->set_vip_flag(before_vip_flag);
		player->set_vip_end_time(before_vip_end);
		player->vip_history=copy_value(before_vip_history);
		int restored=rollback_exact(player,before_wallet,before_physical,
			before_storage_rows,"illicit_jade_recovery_compensation_failed");
		append_recovery_log((string)player->query_name(),case_id,
			restored ? "compensation_failed_rolled_back" :
				"critical_compensation_rollback_failed",
			proven,before_physical,before_storage,0,
			YUSHID->query_physical_all_num(player),
			query_personal_storage_yushi(player),evidence_sha256);
		return (["ok":0,"code":"compensation_failed","confiscated":0]);
	}
	mapping receipt=(["schema_version":2,"case_id":case_id,
		"proven_suiyu":proven,"confiscated":confiscated,
		"before_physical":before_physical,"after_physical":after_physical,
		"before_personal_storage":before_storage,
		"after_personal_storage":after_storage,
		"evidence_sha256":evidence_sha256,"closed_at":time(),
		"policy":RECOVERY_POLICY,
		"source_mode":(string)(entry["source_mode"] ||
			"approved_manifest"),
		"compensation_vip_level":compensation_vip_level,
		"compensation_vip_end":compensation_vip_end,
		"compensation_vip_seconds":confiscated>0 ?
			RECOVERY_COMPENSATION_SECONDS : 0,
		"compensation_notice_pending":confiscated>0 ? 1 : 0,
		"status":confiscated>0 ? "matched_snapshot_closed" :
			(snapshot_matched ? "no_recoverable_balance_closed" :
				"snapshot_changed_closed")]);
	save_err=catch{
		player[RECOVERY_RECEIPT]=receipt;
		saved=functionp(player->save_with_result) && player->save_with_result();
	};
	if(save_err || !saved){
		int restored=confiscated==0;
		mixed rollback_err=catch{
			player->m_delete_foruser(RECOVERY_RECEIPT);
			player->set_vip_flag(before_vip_flag);
			player->set_vip_end_time(before_vip_end);
			player->vip_history=copy_value(before_vip_history);
			if(confiscated>0)
				restored=rollback_exact(player,before_wallet,before_physical,
					before_storage_rows,
					"illicit_jade_recovery_save_failed");
		};
		if(rollback_err || !restored){
			// Fail closed in memory. If a later autosave succeeds, this receipt
			// prevents a second deduction; if no save can succeed, the disk still
			// contains the untouched pre-operation state.
			// 若玉石回滚失败，必须同时保留已承诺的VIP补偿，不能出现只扣
			// 玉却因回滚分支把会员撤掉的二次伤害。
			if(confiscated>0){
				mixed compensation_restore_err=catch{
					player->set_vip_flag(compensation_vip_level);
					player->set_vip_end_time(compensation_vip_end);
					player->add_vip_history(compensation_vip_end,
						compensation_vip_level);
				};
				if(compensation_restore_err)
					werror("[JADE_RECOVERY] CRITICAL VIP compensation restore failed "
						"userid=%s case=%s\n",
						(string)player->query_name(),case_id);
			}
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
		confiscated>0 ? "closed" : (snapshot_matched ?
			"no_recoverable_balance_closed" : "snapshot_changed_closed"),
		proven,
		before_physical,before_storage,confiscated,after_physical,
		after_storage,evidence_sha256);
	if(confiscated>0){
		if(PROFESSIONVIPD->is_supported_profession(player->query_profeId()))
			PROFESSIONVIPD->record_membership_state(player);
		int mail_delivered=deliver_compensation_notice(player);
		append_compensation_log((string)player->query_name(),case_id,
			confiscated,compensation_vip_level,compensation_vip_end,
			mail_delivered);
		catch{ tell_object(player,
			"系统依据已复核的历史异常记录，一次性回收了"+
			YUSHID->get_yushi_for_desc(confiscated)+
			"，并补偿30天VIP"+(string)compensation_vip_level+
			"会员（到期时间"+
			TIMESD->get_user_year_to_second(compensation_vip_end)+
			"）。"+(mail_delivered ? "详细说明已发送至邮箱；" :
				"邮箱暂不可用，系统会在后续登录时重试发送；")+
			"本次处置已经结案，以后充值和"+
			"正常获得的玉石不会继续扣除。\n"); };
	}
	return (["ok":1,"code":"closed","confiscated":confiscated,
		"proven_suiyu":proven,
		"compensation_vip_level":compensation_vip_level,
		"compensation_vip_end":compensation_vip_end]);
}

mapping(string:mixed) apply_if_listed(object player)
{
	return apply_on_login(player);
}

mapping(string:mixed) apply_on_login(object player)
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
	claim_path=user_claim_path(userid);
	if(mappingp(player[RECOVERY_RECEIPT])){
		// 永久人物回执比短期审计快照更持久。旧版本已成功扣除的人物
		// 即使清单过期，也只补发一次会员与通知，绝不再次扣玉。
		Stdio.mkdirhier(RECOVERY_CLAIM_ROOT);
		mkdir(claim_path);
		ensure_closed_recovery_compensation(player);
		return (["ok":1,"code":"already_closed","confiscated":0]);
	}
	// Preserve a currently deployed approved manifest as a rollback-compatible
	// exact snapshot. When absent, login derives the case from machine evidence
	// and current values without an operator-maintained candidate list.
	entry=approved_entry(load_manifest(),userid);
	if(!sizeof(entry))
		entry=automatic_live_entry(player,userid);
	if(!sizeof(entry))
		return (["ok":1,"code":"no_exact_evidence","confiscated":0]);
	if(stringp(entry["deferred_code"]) &&
	   sizeof((string)entry["deferred_code"]))
		return (["ok":1,"code":"deferred_"+
			(string)entry["deferred_code"],"confiscated":0]);
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

/** TestUnit-only automatic evidence index. Production ids are denied. */
int test_set_auto_evidence(mapping(string:mixed) evidence)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !mappingp(evidence) ||
	   !mappingp(evidence["accounts"]))
		return 0;
	foreach((mapping)evidence["accounts"];mixed raw_userid;mixed ignored){
		if(!stringp(raw_userid) ||
		   search((string)raw_userid,"testunit")==-1)
			return 0;
	}
	foreach((mapping)evidence["accounts"];mixed raw_userid;mixed ignored)
		rm(user_claim_path((string)raw_userid));
	object key=auto_evidence_lock->lock();
	test_auto_evidence_override=evidence;
	destruct(key);
	return 1;
}

void test_clear_auto_evidence()
{
	object key=auto_evidence_lock->lock();
	if(getenv("XIAND_RUN_TESTUNIT")=="1" && test_auto_evidence_override &&
	   mappingp(test_auto_evidence_override["accounts"]))
		foreach((mapping)test_auto_evidence_override["accounts"];
		   mixed raw_userid;mixed ignored)
			if(stringp(raw_userid) &&
			   search((string)raw_userid,"testunit")!=-1)
				rm(user_claim_path((string)raw_userid));
	test_auto_evidence_override=0;
	destruct(key);
}

int test_clear_user_claim(string userid)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !valid_userid(userid) ||
	   search(userid,"testunit")==-1)
		return 0;
	return rm(user_claim_path(userid));
}

mapping(string:mixed) test_build_auto_evidence_index()
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return ([]);
	return build_auto_evidence_index();
}

mapping(string:mixed) test_parse_auto_evidence(string userid,
	array(string) lines,int event_month)
{
	mapping(string:mapping(string:mixed)) rows=([]);
	if(getenv("XIAND_RUN_TESTUNIT")!="1" ||
	   search(userid,"testunit")==-1 || !valid_userid(userid) ||
	   event_month<200001 || event_month>220012)
		return ([]);
	for(int index=0;index<sizeof(lines);index++){
		string line=lines[index];
		if(search(line,"event=yushi_conversion")!=-1)
			scan_structured_exact_mint("testunit.log",index+1,line,
				event_month,rows);
		else{
			string parsed_userid=legacy_conversion_userid(line);
			if(parsed_userid!="")
				count_exact_legacy_mints("testunit.log",index+1,line,
					parsed_userid,event_month,rows);
		}
	}
	return rows[userid] || ([]);
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
