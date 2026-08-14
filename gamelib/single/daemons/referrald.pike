/**
 * 注册账号邀请码与捐赠返玉。
 *
 * 邀请关系只在首次注册成功后绑定，按注册账号去重且不可改绑。被邀请
 * 账号在注册后180天内的每笔真实共享充值，为直接邀请人产生到账仙玉
 * 价值10%的奖励。充值事件和奖励凭据均以请求号幂等，跨Worker重试不
 * 会重复发放；已经进入共享钱包的奖励永久有效。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define REFERRAL_VERSION 1
#define REFERRAL_REWARD_PERCENT 10
#define REFERRAL_REWARD_DAYS 180
#define REFERRAL_REWARD_SECONDS (REFERRAL_REWARD_DAYS*24*3600)
#define REFERRAL_SCROLL_FEE_STEP 300
#define REFERRAL_SCROLL_MAX 1024
#define REFERRAL_ROOT (DATA_ROOT+"referrals")

private Thread.Mutex referral_lock = Thread.Mutex();

private int valid_referral_userid(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>64 ||
	   search(value,"..")!=-1)
		return 0;
	foreach(value;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9'))
			continue;
		return 0;
	}
	return 1;
}

private int valid_referral_request_id(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	foreach(value;int index;int one){
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

private string relation_path(string invitee_account)
{
	return REFERRAL_ROOT+"/by_invitee/"+
		invitee_account[sizeof(invitee_account)-2..]+"/"+
		invitee_account+".json";
}

private string inviter_relation_path(string inviter_account,
	string invitee_account)
{
	return REFERRAL_ROOT+"/by_inviter/"+
		inviter_account[sizeof(inviter_account)-2..]+"/"+
		inviter_account+"/"+invitee_account+".json";
}

private string donation_path(string invitee_account,string request_id)
{
	return REFERRAL_ROOT+"/donations/"+
		invitee_account[sizeof(invitee_account)-2..]+"/"+
		invitee_account+"/"+request_id+".json";
}

private mapping(string:mixed)|zero decode_json_file(string path)
{
	string source;
	mixed decoded;
	mixed err;
	if(Stdio.file_size(path)<=0 || Stdio.file_size(path)>64*1024)
		return 0;
	source = Stdio.read_file(path);
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded))
		return 0;
	return (mapping(string:mixed))decoded;
}

private int write_immutable_json(string path,mapping(string:mixed) value)
{
	string encoded = Standards.JSON.encode(value);
	string temp_path = path+".tmp."+
		String.string2hex(Crypto.Random.random_string(8));
	int ok;
	mixed err;
	Stdio.mkdirhier(dirname(path));
	err = catch{
		if(Stdio.file_size(path)>0)
			ok=0;
		else if(Stdio.write_file(temp_path,encoded)>0 &&
		        Stdio.file_size(temp_path)==sizeof(encoded) &&
		        Stdio.file_size(path)<=0 && mv(temp_path,path))
			ok=Stdio.file_size(path)==sizeof(encoded);
	};
	if(err)
		werror("[REFERRALD] immutable write failed path=%s error=%s\n",
			path,describe_error(err));
	if(Stdio.file_size(temp_path)>=0)
		rm(temp_path);
	return ok;
}

private int valid_relation(mapping relation)
{
	return mappingp(relation) &&
		(int)relation["version"]==REFERRAL_VERSION &&
		valid_referral_userid((string)relation["inviter_account"]) &&
		valid_referral_userid((string)relation["invitee_account"]) &&
		(string)relation["inviter_account"]!=
			(string)relation["invitee_account"] &&
		intp(relation["created_at"]) && (int)relation["created_at"]>0;
}

private int same_relation(mapping left,mapping right)
{
	return valid_relation(left) && valid_relation(right) &&
		(string)left["inviter_account"]==
			(string)right["inviter_account"] &&
		(string)left["invitee_account"]==
			(string)right["invitee_account"] &&
		(int)left["created_at"]==(int)right["created_at"];
}

private int ensure_inviter_relation_index(mapping relation)
{
	string path;
	mapping(string:mixed)|zero indexed;
	if(!valid_relation(relation))
		return 0;
	path=inviter_relation_path((string)relation["inviter_account"],
		(string)relation["invitee_account"]);
	indexed=decode_json_file(path);
	if(indexed && same_relation(indexed,relation))
		return 1;
	// 不覆盖冲突或损坏的非空文件，留给管理员审计处理。
	if(Stdio.file_size(path)>0)
		return 0;
	write_immutable_json(path,relation);
	indexed=decode_json_file(path);
	return indexed && same_relation(indexed,relation);
}

mapping(string:mixed) query_relation(string invitee_account)
{
	mapping(string:mixed)|zero relation;
	invitee_account=String.trim_all_whites(invitee_account || "");
	if(!valid_referral_userid(invitee_account))
		return ([]);
	relation=decode_json_file(relation_path(invitee_account));
	if(!relation || !valid_relation(relation) ||
	   (string)relation["invitee_account"]!=invitee_account)
		return ([]);
	ensure_inviter_relation_index(relation);
	return copy_value(relation);
}

private string read_saved_userip(string character_id)
{
	string path;
	string source;
	if(!valid_referral_userid(character_id))
		return "";
	path=DATA_ROOT+"u/"+character_id[sizeof(character_id)-2..]+"/"+
		character_id+".o";
	source=Stdio.read_file(path);
	if(!source)
		return "";
	foreach(source/"\n",string line){
		string value;
		if(sscanf(line,"userip \"%s\"",value)==1){
			if(sizeof(value) && value[sizeof(value)-1]=='\"')
				value=value[..sizeof(value)-2];
			return String.trim_all_whites(value);
		}
	}
	return "";
}

private int account_has_registration_ip(string account_id,string client_ip)
{
	array(string) character_ids;
	if(client_ip=="" || client_ip=="unknown")
		return 0;
	character_ids = ACCOUNT_CHARACTERD->query_character_ids(account_id);
	// 无索引历史账号以账号ID本身作为唯一人物；即使账号索引正处于
	// 首次合成/缓存切换，也不能漏掉这份权威老档。
	if(search(character_ids,account_id)==-1)
		character_ids += ({account_id});
	foreach(character_ids,string character_id){
		// 注册邀请人可能仍在线且最新来源尚未完成下一次落盘；先读
		// 权威运行态，再兼容离线档案，避免同网络审计信号漏记。
		object online = find_player(character_id);
		if(online && functionp(online->query_userip) &&
		   (string)(online->query_userip() || "")==client_ip)
			return 1;
		if(read_saved_userip(character_id)==client_ip)
			return 1;
	}
	return 0;
}

int referral_reward_window_open(int created_at,void|int current_time)
{
	int now=current_time || time();
	return created_at>0 && now>=created_at &&
		now-created_at<REFERRAL_REWARD_SECONDS;
}

mapping(string:mixed) bind_registration(string invitee_character,
	string inviter_code,string client_ip)
{
	string invitee_account;
	string inviter_account;
	mapping validation;
	mapping relation;
	mapping existing;
	object key;
	validation=validate_registration_invite(invitee_character,
		inviter_code,client_ip);
	if(!(int)validation["ok"])
		return validation;
	invitee_account=(string)validation["invitee_account"];
	inviter_account=(string)validation["inviter_account"];
	key=referral_lock->lock();
	existing=query_relation(invitee_account);
	if(sizeof(existing)){
		if((string)existing["inviter_account"]==inviter_account)
			ensure_inviter_relation_index(existing);
		destruct(key);
		return (string)existing["inviter_account"]==inviter_account ?
			(["ok":1,"duplicate":1,"relation":existing]) :
			(["ok":0,"code":"already_bound",
				"message":"该账号已经绑定其他邀请人"]);
	}
	relation=(["version":REFERRAL_VERSION,
		"inviter_account":inviter_account,
		"invitee_account":invitee_account,"created_at":time(),
		"registration_network_match":
			(int)validation["registration_network_match"],
		"reward_percent":REFERRAL_REWARD_PERCENT,
		"reward_days":REFERRAL_REWARD_DAYS]);
	if(!write_immutable_json(relation_path(invitee_account),relation)){
		destruct(key);
		return (["ok":0,"code":"save_failed",
			"message":"邀请关系保存失败"]);
	}
	// 新关系必须同时拥有规范记录和统计索引，否则注册端回滚刚创建的
	// 人物档案，避免出现已经绑定却永远不计入邀请统计的半成功状态。
	if(!ensure_inviter_relation_index(relation)){
		rm(relation_path(invitee_account));
		destruct(key);
		return (["ok":0,"code":"index_save_failed",
			"message":"邀请关系索引保存失败"]);
	}
	destruct(key);
	Stdio.append_file(ROOT+"/log/referral_audit.log",
		time()+" action=bind inviter="+inviter_account+" invitee="+
		invitee_account+" reward_days="+REFERRAL_REWARD_DAYS+
		" registration_network_match="+
		(int)validation["registration_network_match"]+"\n");
	return (["ok":1,"duplicate":0,"relation":relation]);
}

mapping(string:mixed) validate_registration_invite(
	string invitee_character,string inviter_code,string client_ip)
{
	string invitee_account;
	string inviter_account;
	mapping existing;
	// 历史账号可能含大写字母且文件名严格区分大小写。邀请关系中的
	// 双方账号必须按精确ID解析，避免 LSQ 与 lsq 串号。
	invitee_character=String.trim_all_whites(invitee_character || "");
	inviter_code=String.trim_all_whites(inviter_code || "");
	client_ip=String.trim_all_whites(client_ip || "");
	if(!valid_referral_userid(invitee_character) ||
	   !valid_referral_userid(inviter_code))
		return (["ok":0,"code":"invalid_code",
			"message":"邀请码无效"]);
	invitee_account=ACCOUNT_CHARACTERD->query_account_id_for_character(
		invitee_character);
	inviter_account=ACCOUNT_CHARACTERD->query_account_id_for_character(
		inviter_code);
	if(!valid_referral_userid(invitee_account) ||
	   !valid_referral_userid(inviter_account) ||
	   !(int)ACCOUNT_CHARACTERD->query_account_characters(
		inviter_account)["ok"])
		return (["ok":0,"code":"inviter_missing",
			"message":"邀请人账号不存在"]);
	if(invitee_account==inviter_account)
		return (["ok":0,"code":"self_invite",
			"message":"同一注册账号不能互相邀请"]);
	existing=query_relation(invitee_account);
	if(sizeof(existing) &&
	   (string)existing["inviter_account"]!=inviter_account)
		return (["ok":0,"code":"already_bound",
			"message":"该账号已经绑定其他邀请人"]);
	// 共用家庭网络、网吧和反向代理都可能呈现同一IP，
	// 因此只作审计风险信号，不误伤真实邀请。防重奖仍依靠
	// 注册账号去重、关系不可改绑和真实充值凭据幂等。
	int network_match=!sizeof(existing) &&
		account_has_registration_ip(inviter_account,client_ip);
	return (["ok":1,"invitee_account":invitee_account,
		"inviter_account":inviter_account,"duplicate":sizeof(existing)>0,
		"registration_network_match":network_match]);
}

private mapping(string:mixed)|zero find_recharge_receipt(
	mapping wallet,string request_id)
{
	mapping receipt=mappingp(wallet["recharge_requests"]) ?
		((mapping)wallet["recharge_requests"])[request_id] : 0;
	if(mappingp(receipt))
		return receipt;
	foreach((array)(wallet["transactions"] || ({})),mapping transaction)
		if((string)transaction["type"]=="recharge" &&
		   (string)transaction["request_id"]==request_id)
			return (["amount":(int)transaction["amount"],
				"fee":(int)transaction["fee"],
				"created_at":(int)transaction["created_at"]]);
	return 0;
}

private int valid_donation_event(mapping event)
{
	return mappingp(event) && (int)event["version"]==REFERRAL_VERSION &&
		valid_referral_userid((string)event["inviter_account"]) &&
		valid_referral_userid((string)event["invitee_account"]) &&
		valid_referral_request_id((string)event["request_id"]) &&
		intp(event["recharge_amount"]) &&
		(int)event["recharge_amount"]>0 &&
		intp(event["reward_amount"]) &&
		(int)event["reward_amount"]==
			(int)event["recharge_amount"]*REFERRAL_REWARD_PERCENT/100 &&
		(int)event["reward_amount"]>0 &&
		intp(event["created_at"]) && (int)event["created_at"]>0;
}

mapping(string:mixed) record_recharge_from_wallet(string invitee_account,
	string request_id)
{
	mapping relation;
	mapping wallet;
	mapping receipt;
	mapping event;
	string path;
	invitee_account=String.trim_all_whites(invitee_account || "");
	request_id=lower_case(String.trim_all_whites(request_id || ""));
	if(!valid_referral_userid(invitee_account) ||
	   !valid_referral_request_id(request_id))
		return (["ok":0,"code":"invalid_request"]);
	relation=query_relation(invitee_account);
	if(!sizeof(relation))
		return (["ok":1,"recorded":0,"code":"not_referred"]);
	path=donation_path(invitee_account,request_id);
	event=decode_json_file(path);
	if(event && valid_donation_event(event))
	{
		mapping existing_credit=ACCOUNT_WALLETD->
			credit_account_referral_reward_once(
				(string)event["inviter_account"],invitee_account,
				request_id,(int)event["reward_amount"]);
		return (["ok":(int)existing_credit["ok"],"recorded":1,
			"duplicate":1,"credited":(int)existing_credit["ok"],
			"credit_duplicate":(int)existing_credit["duplicate"],
			"inviter_account":(string)event["inviter_account"],
			"reward_amount":(int)event["reward_amount"],
			"code":(int)existing_credit["ok"] ? "" : "credit_failed"]);
	}
	wallet=ACCOUNT_WALLETD->query_account_wallet(invitee_account);
	if(!(int)wallet["ok"])
		return (["ok":0,"code":"wallet_unavailable"]);
	receipt=find_recharge_receipt(wallet,request_id);
	if(!receipt || (int)receipt["amount"]<=0)
		return (["ok":0,"code":"recharge_not_found"]);
	if(!referral_reward_window_open((int)relation["created_at"],
	   (int)receipt["created_at"]))
		return (["ok":1,"recorded":0,"code":"reward_expired"]);
	int reward_amount=(int)receipt["amount"]*REFERRAL_REWARD_PERCENT/100;
	if(reward_amount<=0)
		return (["ok":1,"recorded":0,"code":"below_minimum"]);
	event=(["version":REFERRAL_VERSION,
		"inviter_account":(string)relation["inviter_account"],
		"invitee_account":invitee_account,"request_id":request_id,
		"recharge_amount":(int)receipt["amount"],
		"recharge_fee":(int)receipt["fee"],
		"reward_amount":reward_amount,
		"created_at":(int)receipt["created_at"] || time()]);
	if(!write_immutable_json(path,event))
		return (["ok":0,"code":"event_save_failed"]);
	Stdio.append_file(ROOT+"/log/referral_audit.log",
		time()+" action=accrue inviter="+
		(string)relation["inviter_account"]+" invitee="+
		invitee_account+" request="+request_id+" reward="+
		reward_amount+"\n");
	mapping credit=ACCOUNT_WALLETD->credit_account_referral_reward_once(
		(string)relation["inviter_account"],invitee_account,request_id,
		reward_amount);
	return (["ok":(int)credit["ok"],"recorded":1,"duplicate":0,
		"credited":(int)credit["ok"],
		"credit_duplicate":(int)credit["duplicate"],
		"inviter_account":(string)relation["inviter_account"],
		"reward_amount":reward_amount,
		"code":(int)credit["ok"] ? "" : "credit_failed"]);
}

mapping(string:mixed) validate_reward_event(string inviter_account,
	string invitee_account,string request_id,int reward_amount)
{
	mapping relation=query_relation(invitee_account);
	mapping event=decode_json_file(donation_path(invitee_account,request_id));
	if(!sizeof(relation) ||
	   (string)relation["inviter_account"]!=inviter_account ||
	   !event || !valid_donation_event(event) ||
	   (string)event["inviter_account"]!=inviter_account ||
	   (string)event["invitee_account"]!=invitee_account ||
	   (string)event["request_id"]!=request_id ||
	   (int)event["reward_amount"]!=reward_amount)
		return (["ok":0,"message":"邀请奖励凭据无效"]);
	return (["ok":1,"event":event]);
}

private array(mapping(string:mixed)) query_inviter_relations(
	string inviter_account)
{
	array(mapping(string:mixed)) result=({});
	string directory=REFERRAL_ROOT+"/by_inviter/"+
		inviter_account[sizeof(inviter_account)-2..]+"/"+
		inviter_account;
	foreach(get_dir(directory) || ({}),string filename){
		mapping relation;
		if(!has_suffix(filename,".json"))
			continue;
		relation=decode_json_file(directory+"/"+filename);
		if(!relation || !valid_relation(relation) ||
		   (string)relation["inviter_account"]!=inviter_account)
			continue;
		mapping canonical=query_relation((string)relation["invitee_account"]);
		if(sizeof(canonical) &&
		   (string)canonical["inviter_account"]==inviter_account)
			result+=({canonical});
	}
	return result;
}

private array(mapping(string:mixed)) query_donation_events(
	string invitee_account)
{
	array(mapping(string:mixed)) result=({});
	string directory=REFERRAL_ROOT+"/donations/"+
		invitee_account[sizeof(invitee_account)-2..]+"/"+
		invitee_account;
	foreach(get_dir(directory) || ({}),string filename){
		mapping event;
		if(!has_suffix(filename,".json"))
			continue;
		event=decode_json_file(directory+"/"+filename);
		if(event && valid_donation_event(event) &&
		   (string)event["invitee_account"]==invitee_account)
			result+=({event});
	}
	return result;
}

string referral_scroll_reward_id(string inviter_account,int milestone)
{
	object hash;
	if(!valid_referral_userid(inviter_account) || milestone<1 ||
	   milestone>REFERRAL_SCROLL_MAX)
		return "";
	hash=Crypto.SHA256();
	hash->update("xiand_referral_scroll_v1|"+inviter_account+"|"+
		milestone);
	return lower_case(String.string2hex(hash->digest()));
}

private int account_has_scroll_receipt(string account_id,string receipt_id)
{
	foreach(ACCOUNT_CHARACTERD->query_character_ids(account_id),
		string character_id){
		object online=find_player(character_id);
		if(online && functionp(online->has_referral_scroll_reward_receipt) &&
		   online->has_referral_scroll_reward_receipt(receipt_id))
			return 1;
		string path=DATA_ROOT+"u/"+
			character_id[sizeof(character_id)-2..]+"/"+
			character_id+".o";
		string source=Stdio.read_file(path);
		if(source && search(source,receipt_id)!=-1)
			return 1;
	}
	return 0;
}

private int inventory_scroll_amount(object player)
{
	int amount;
	foreach(all_inventory(player),object item)
		if(item && (string)item->query_name()==
		   "ancient_skill_choice_token")
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
}

private mapping(string:mixed) give_scroll_reward(object player,
	string account_id,int milestone)
{
	string receipt_id=referral_scroll_reward_id(account_id,milestone);
	object|zero token=0;
	int before_amount;
	if(receipt_id=="")
		return (["ok":0,"message":"卷轴里程碑无效"]);
	if(account_has_scroll_receipt(account_id,receipt_id))
		return (["ok":1,"duplicate":1]);
	before_amount=inventory_scroll_amount(player);
	mixed err=catch{
		token=clone(ROOT+"/gamelib/clone/item/other/"+
			"ancient_skill_choice_token");
		if(token)
			token->move(player);
	};
	if(err || inventory_scroll_amount(player)-before_amount!=1){
		if(token)
			destruct(token);
		return (["ok":0,"message":"背包暂时无法接收太古自选卷轴"]);
	}
	if(!player->record_referral_scroll_reward_receipt(receipt_id) ||
	   !player->save_with_result()){
		player->rollback_referral_scroll_reward_receipt(receipt_id);
		player->remove_combine_item_transaction(
			"ancient_skill_choice_token",1);
		return (["ok":0,"message":"卷轴与领取凭据未能同时保存"]);
	}
	Stdio.append_file(ROOT+"/log/referral_audit.log",
		time()+" action=scroll inviter="+account_id+" milestone="+
		milestone+" receipt="+receipt_id+"\n");
	return (["ok":1,"duplicate":0]);
}

mapping(string:mixed) settle_and_query(object player)
{
	string inviter_account;
	array(mapping(string:mixed)) relations;
	multiset(string) donors=(<>);
	int active_count;
	int total_reward;
	int pending_count;
	int settled_now;
	int eligible_recharge_fee;
	int eligible_scrolls;
	int delivered_scrolls;
	int new_scrolls;
	if(!player || !functionp(player->query_name))
		return (["ok":0,"message":"人物无效"]);
	inviter_account=ACCOUNT_CHARACTERD->query_account_id_for_character(
		(string)player->query_name());
	if(!valid_referral_userid(inviter_account))
		return (["ok":0,"message":"注册账号无效"]);
	relations=query_inviter_relations(inviter_account);
	foreach(relations,mapping relation){
		string invitee=(string)relation["invitee_account"];
		if(referral_reward_window_open((int)relation["created_at"]))
			active_count++;
		foreach(query_donation_events(invitee),mapping event){
			mapping credit;
			donors[invitee]=1;
			eligible_recharge_fee+=(int)event["recharge_fee"];
			credit=ACCOUNT_WALLETD->credit_referral_reward_once(player,
				invitee,(string)event["request_id"],
				(int)event["reward_amount"]);
			if(!(int)credit["ok"]){
				pending_count++;
				continue;
			}
			if(!(int)credit["duplicate"])
				settled_now+=(int)event["reward_amount"];
		}
	}
	eligible_scrolls=eligible_recharge_fee/REFERRAL_SCROLL_FEE_STEP;
	if(eligible_scrolls>REFERRAL_SCROLL_MAX)
		eligible_scrolls=REFERRAL_SCROLL_MAX;
	for(int milestone=1;milestone<=eligible_scrolls;milestone++){
		mapping scroll=give_scroll_reward(player,inviter_account,milestone);
		if(!(int)scroll["ok"]){
			pending_count++;
			continue;
		}
		delivered_scrolls++;
		if(!(int)scroll["duplicate"])
			new_scrolls++;
	}
	mapping wallet=ACCOUNT_WALLETD->query_wallet(player);
	if(mappingp(wallet["referral_requests"]))
		foreach(values((mapping)wallet["referral_requests"]),
			mapping receipt)
			total_reward+=(int)receipt["amount"];
	return (["ok":1,"inviter_account":inviter_account,
		"invite_count":sizeof(relations),"active_count":active_count,
		"donor_count":sizeof(donors),"total_reward":total_reward,
		"settled_now":settled_now,"pending_count":pending_count,
		"eligible_recharge_fee":eligible_recharge_fee,
		"scroll_step_fee":REFERRAL_SCROLL_FEE_STEP,
		"scroll_earned":eligible_scrolls,
		"scroll_delivered":delivered_scrolls,
		"new_scrolls":new_scrolls,
		"next_scroll_remaining":REFERRAL_SCROLL_FEE_STEP-
			(eligible_recharge_fee%REFERRAL_SCROLL_FEE_STEP),
		"reward_days":REFERRAL_REWARD_DAYS,
		"reward_percent":REFERRAL_REWARD_PERCENT]);
}

void remove_test_referrals(array(string) account_ids)
{
	foreach(account_ids,string account_id){
		if(search(account_id,"testunit")==-1 ||
		   !valid_referral_userid(account_id))
			continue;
		mapping relation=query_relation(account_id);
		if(sizeof(relation))
			rm(inviter_relation_path((string)relation["inviter_account"],
				account_id));
		rm(relation_path(account_id));
		string donation_dir=REFERRAL_ROOT+"/donations/"+
			account_id[sizeof(account_id)-2..]+"/"+account_id;
		foreach(get_dir(donation_dir) || ({}),string filename)
			rm(donation_dir+"/"+filename);
		string inviter_dir=REFERRAL_ROOT+"/by_inviter/"+
			account_id[sizeof(account_id)-2..]+"/"+account_id;
		foreach(get_dir(inviter_dir) || ({}),string filename)
			rm(inviter_dir+"/"+filename);
	}
}
