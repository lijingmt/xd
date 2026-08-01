/**
 * 玩家意见反馈守护进程。
 *
 * 流程：玩家提交 -> 管理员采纳/不采纳 -> 采纳后发放固定玉石奖励。
 * 审核状态与玩家档案中的领取凭据共同保证奖励幂等。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define FEEDBACK_DIR DATA_ROOT "feedback"
#define FEEDBACK_FILE FEEDBACK_DIR "/feedbacks.o"
#define FEEDBACK_REWARD 100
#define FEEDBACK_MIN_LENGTH 4
#define FEEDBACK_MAX_LENGTH 300
#define FEEDBACK_COOLDOWN 60
#define FEEDBACK_MAX_PENDING 3

mapping(string:mapping(string:mixed)) feedback_records = ([]);
int next_feedback_id = 1;

private Thread.Mutex feedback_lock = Thread.Mutex();

string feedback_id_desc(int id)
{
	return sprintf("FB%06d",id);
}

private string trim_feedback_whites(string value)
{
	int start = 0;
	int finish;
	if(!value || value=="")
		return "";
	finish = sizeof(value)-1;
	while(start<=finish &&
		(value[start]==' ' || value[start]=='\t' ||
		 value[start]=='\r' || value[start]=='\n'))
		start++;
	while(finish>=start &&
		(value[finish]==' ' || value[finish]=='\t' ||
		 value[finish]=='\r' || value[finish]=='\n'))
		finish--;
	if(start>finish)
		return "";
	return value[start..finish];
}

string feedback_time_desc(int timestamp)
{
	string desc;
	if(timestamp<=0)
		return "--";
	desc = ctime(timestamp);
	return trim_feedback_whites(desc);
}

string feedback_status_desc(string status)
{
	if(status=="adopted")
		return "已采纳";
	if(status=="rejected")
		return "未采纳";
	return "待审核";
}

int query_reward_amount()
{
	return FEEDBACK_REWARD;
}

private string normalize_feedback(string content)
{
	if(!content)
		return "";
	content = trim_feedback_whites(content);
	// 防止玩家文本伪造游戏按钮、颜色控制符或HTML标签。
	content = replace(content,([
		"[":"【",
		"]":"】",
		"<":"＜",
		">":"＞",
		"|":"｜",
		"§":"",
		"\t":" ",
		"\r":" ",
		"\n":" ",
	]));
	return trim_feedback_whites(content);
}

private int feedback_character_count(string content)
{
	int count = 0;
	if(!content)
		return 0;
	for(int i=0;i<sizeof(content);i++){
		int current = content[i];
		// 兼容Pike宽字符和仍以UTF-8字节保存的旧连接输入。
		if(current>255 || (current&0xc0)!=0x80)
			count++;
	}
	return count;
}

private int valid_saved_data()
{
	return mappingp(feedback_records) && next_feedback_id>0;
}

private int restore_feedback_file(string filepath)
{
	string source = Stdio.read_file(filepath);
	if(!source || search(source,"feedback_records ")==-1 ||
	   search(source,"next_feedback_id ")==-1)
		return 0;
	if(!restore_object(filepath,1))
		return 0;
	return valid_saved_data();
}

private void load_feedback_data()
{
	feedback_records = ([]);
	next_feedback_id = 1;
	if(Stdio.file_size(FEEDBACK_FILE)>0 &&
	   restore_feedback_file(FEEDBACK_FILE))
		return;
	if(Stdio.file_size(FEEDBACK_FILE+".bak")>0 &&
	   restore_feedback_file(FEEDBACK_FILE+".bak")){
		werror("[FEEDBACKD] 主存档无效，已从备份恢复。\n");
		return;
	}
	feedback_records = ([]);
	next_feedback_id = 1;
}

private int save_feedback_data()
{
	string temp_file = FEEDBACK_FILE+".tmp";
	string backup_temp = FEEDBACK_FILE+".bak.tmp";
	int live_size;
	int temp_size;
	int backup_size;
	int ok = 0;
	mixed err;

	mkdir(FEEDBACK_DIR);
	err = catch{
		rm(temp_file);
		rm(backup_temp);
		if(save_object(temp_file)>0){
			temp_size = Stdio.file_size(temp_file);
			if(temp_size>0){
				live_size = Stdio.file_size(FEEDBACK_FILE);
				if(live_size>0){
					Stdio.cp(FEEDBACK_FILE,backup_temp);
					backup_size = Stdio.file_size(backup_temp);
					if(backup_size==live_size &&
					   mv(backup_temp,FEEDBACK_FILE+".bak") &&
					   mv(temp_file,FEEDBACK_FILE))
						ok = Stdio.file_size(FEEDBACK_FILE)>0;
				}
				else if(mv(temp_file,FEEDBACK_FILE))
					ok = Stdio.file_size(FEEDBACK_FILE)>0;
			}
		}
	};
	if(err)
		werror("[FEEDBACKD] 保存异常: %s\n",describe_error(err));
	if(!ok){
		rm(temp_file);
		rm(backup_temp);
		werror("[FEEDBACKD] 意见反馈存档失败。\n");
	}
	return ok;
}

protected void create()
{
	load_feedback_data();
}

mapping(string:mixed) submit_feedback(object player,string content)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"提交失败。",
		"id":0,
	]);
	object lock_key;
	string userid;
	string username;
	string normalized;
	int pending_count = 0;
	int latest_time = 0;
	int id;
	string key;
	int character_count;

	if(!player){
		result["message"] = "玩家状态无效。";
		return result;
	}
	userid = player->query_name();
	username = normalize_feedback(player->query_name_cn());
	if(!userid || userid==""){
		result["message"] = "游客不能提交意见，请先注册账号。";
		return result;
	}
	normalized = normalize_feedback(content);
	character_count = feedback_character_count(normalized);
	if(character_count<FEEDBACK_MIN_LENGTH){
		result["message"] = "意见至少需要"+FEEDBACK_MIN_LENGTH+"个字符。";
		return result;
	}
	if(character_count>FEEDBACK_MAX_LENGTH || sizeof(normalized)>1200){
		result["message"] = "意见不能超过"+FEEDBACK_MAX_LENGTH+"个字符。";
		return result;
	}

	lock_key = feedback_lock->lock();
	foreach(values(feedback_records),mapping(string:mixed) one){
		if(one["user_id"]!=userid)
			continue;
		if(one["status"]=="pending")
			pending_count++;
		if((int)one["submitted_at"]>latest_time)
			latest_time = (int)one["submitted_at"];
		if(one["content"]==normalized && one["status"]=="pending"){
			result["message"] = "相同内容已经在审核中，请勿重复提交。";
			return result;
		}
	}
	if(pending_count>=FEEDBACK_MAX_PENDING){
		result["message"] = "你已有"+FEEDBACK_MAX_PENDING+
			"条意见等待审核，请在处理后再提交。";
		return result;
	}
	if(latest_time>0 && time()-latest_time<FEEDBACK_COOLDOWN){
		result["message"] = "提交过于频繁，请稍后再试。";
		return result;
	}

	id = next_feedback_id++;
	key = (string)id;
	feedback_records[key] = ([
		"id":id,
		"user_id":userid,
		"user_name":username || userid,
		"content":normalized,
		"submitted_at":time(),
		"status":"pending",
		"reviewed_by":"",
		"reviewed_at":0,
		"reward_amount":0,
		"reward_status":"none",
		"rewarded_at":0,
	]);
	if(!save_feedback_data()){
		m_delete(feedback_records,key);
		next_feedback_id--;
		result["message"] = "反馈系统暂时无法写入，请稍后重试。";
		return result;
	}
	result["ok"] = 1;
	result["id"] = id;
	result["message"] = "意见已提交，感谢你帮助完善仙道。";
	return result;
}

array(mapping(string:mixed)) query_player_feedback(object player,int limit)
{
	array(mapping(string:mixed)) result = ({});
	array(int) ids = ({});
	object lock_key;
	string userid;
	if(!player)
		return result;
	userid = player->query_name();
	if(limit<1)
		limit = 5;
	if(limit>20)
		limit = 20;
	lock_key = feedback_lock->lock();
	foreach(feedback_records;string key;mapping(string:mixed) one){
		if(one["user_id"]==userid)
			ids += ({(int)key});
	}
	foreach(reverse(sort(ids)),int id){
		result += ({copy_value(feedback_records[(string)id])});
		if(sizeof(result)>=limit)
			break;
	}
	return result;
}

array(mapping(string:mixed)) query_admin_feedback(object admin,
	string status,int page,int page_size)
{
	array(mapping(string:mixed)) result = ({});
	array(int) ids = ({});
	object lock_key;
	int start;
	if(!admin || MANAGERD->checkpower(admin->query_name())!="admin")
		return result;
	if(page<1)
		page = 1;
	if(page_size<1 || page_size>30)
		page_size = 10;
	start = (page-1)*page_size;
	lock_key = feedback_lock->lock();
	foreach(feedback_records;string key;mapping(string:mixed) one){
		if(status=="all" || one["status"]==status)
			ids += ({(int)key});
	}
	ids = reverse(sort(ids));
	for(int i=start;i<sizeof(ids) && sizeof(result)<page_size;i++)
		result += ({copy_value(feedback_records[(string)ids[i]])});
	return result;
}

int query_admin_feedback_count(object admin,string status)
{
	object lock_key;
	int count = 0;
	if(!admin || MANAGERD->checkpower(admin->query_name())!="admin")
		return 0;
	lock_key = feedback_lock->lock();
	foreach(values(feedback_records),mapping(string:mixed) one){
		if(status=="all" || one["status"]==status)
			count++;
	}
	return count;
}

mapping(string:mixed) query_admin_feedback_detail(object admin,int id)
{
	object lock_key;
	mapping(string:mixed) one;
	if(!admin || MANAGERD->checkpower(admin->query_name())!="admin")
		return ([]);
	lock_key = feedback_lock->lock();
	one = feedback_records[(string)id];
	return one ? copy_value(one) : ([]);
}

mapping(string:mixed) review_feedback(object admin,int id,string action)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"already":0,
		"message":"审核失败。",
	]);
	object lock_key;
	string key = (string)id;
	mapping(string:mixed) one;
	mapping(string:mixed) old_one;

	if(!admin || MANAGERD->checkpower(admin->query_name())!="admin"){
		result["message"] = "需要管理员权限。";
		return result;
	}
	if(action!="adopt" && action!="reject"){
		result["message"] = "审核动作无效。";
		return result;
	}
	lock_key = feedback_lock->lock();
	one = feedback_records[key];
	if(!one){
		result["message"] = "意见编号不存在。";
		return result;
	}
	if(one["status"]!="pending"){
		result["already"] = 1;
		result["message"] = "该意见已经审核，未重复变更状态。";
		return result;
	}
	old_one = copy_value(one);
	one["status"] = action=="adopt" ? "adopted" : "rejected";
	one["reviewed_by"] = admin->query_name();
	one["reviewed_at"] = time();
	if(action=="adopt"){
		one["reward_amount"] = FEEDBACK_REWARD;
		one["reward_status"] = "pending";
	}
	if(!save_feedback_data()){
		feedback_records[key] = old_one;
		result["message"] = "审核结果写入失败，请稍后重试。";
		return result;
	}
	Stdio.append_file(ROOT+"/log/feedback_review.log",
		feedback_time_desc(time())+" admin="+admin->query_name()+
		" feedback="+feedback_id_desc(id)+" action="+action+
		" user="+one["user_id"]+" reward="+
		(int)one["reward_amount"]+"\n");
	result["ok"] = 1;
	result["message"] = action=="adopt" ?
		"意见已采纳，奖励进入发放流程。" : "意见已标记为未采纳。";
	return result;
}

private array(object) create_yushi_reward(object player,int amount)
{
	array(object) created = ({});
	for(int rare=1;rare<=5;rare++){
		int count = amount%10;
		amount = amount/10;
		if(count>0){
			object item = clone(ITEM_PATH+"yushi/"+
				YUSHID->get_yushi_name(rare));
			if(!item)
				return created;
			item->amount = count;
			if(item->move(player))
				created += ({item});
			else if(environment(item)==player)
				created += ({item});
			else
				destruct(item);
		}
		if(amount<=0)
			break;
	}
	return created;
}

mapping(string:mixed) deliver_pending_rewards(object player)
{
	mapping(string:mixed) result = ([
		"delivered":0,
		"already":0,
		"failed":0,
		"amount":0,
	]);
	object lock_key;
	string userid;
	mapping claimed;
	mixed claimed_value;
	int daemon_changed = 0;
	if(!player)
		return result;
	userid = player->query_name();
	if(!userid || userid=="")
		return result;
	lock_key = feedback_lock->lock();
	claimed_value = player["/feedback/reward_claimed"];
	if(mappingp(claimed_value))
		claimed = (mapping)claimed_value;
	else
		claimed = ([]);

	foreach(feedback_records;string key;mapping(string:mixed) one){
		if(one["user_id"]!=userid || one["status"]!="adopted" ||
		   one["reward_status"]=="delivered")
			continue;
		if(claimed[key]){
			one["reward_status"] = "delivered";
			one["rewarded_at"] = (int)claimed[key];
			result["already"]++;
			daemon_changed = 1;
			continue;
		}
		int reward = (int)one["reward_amount"];
		int before_value = YUSHID->query_all_num(player);
		array(object) created = create_yushi_reward(player,reward);
		int after_value = YUSHID->query_all_num(player);
		if(reward<=0 || !sizeof(created) ||
		   after_value-before_value!=reward){
			foreach(created,object item)
				if(item)
					destruct(item);
			result["failed"]++;
			continue;
		}
		claimed[key] = time();
		player["/feedback/reward_claimed"] = claimed;
		if(!player->save_with_result()){
			m_delete(claimed,key);
			player["/feedback/reward_claimed"] = claimed;
			foreach(created,object item)
				if(item)
					destruct(item);
			result["failed"]++;
			continue;
		}
		one["reward_status"] = "delivered";
		one["rewarded_at"] = (int)claimed[key];
		result["delivered"]++;
		result["amount"] += reward;
		daemon_changed = 1;
	}
	if(daemon_changed && !save_feedback_data())
		werror("[FEEDBACKD] 奖励已写入玩家档案，但反馈状态回写失败。\n");
	if((int)result["amount"]>0){
		mixed tell_err = catch{
			tell_object(player,"你被采纳的游戏意见已发放奖励："+
				YUSHID->get_yushi_for_desc((int)result["amount"])+"。\n");
		};
	}
	return result;
}

int remove_test_feedback(int id)
{
	object lock_key = feedback_lock->lock();
	string key = (string)id;
	mapping(string:mixed) one = feedback_records[key];
	int save_ok;
	if(!one || !has_prefix((string)one["user_id"],"__testunit_feedback_"))
		return 0;
	m_delete(feedback_records,key);
	if(id==next_feedback_id-1){
		while(next_feedback_id>1 &&
			!feedback_records[(string)(next_feedback_id-1)])
			next_feedback_id--;
	}
	save_ok = save_feedback_data();
	// 整套测试清空后再保存一次，让备份也不残留测试记录。
	if(save_ok && !sizeof(feedback_records))
		save_ok = save_feedback_data();
	return save_ok;
}
