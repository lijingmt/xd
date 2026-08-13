#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

#define NO_LEVEL_RECYCLE_NOTICE "/plus/no_level_equipment_recycle_notice"
#define NO_LEVEL_RECYCLE_TOTAL "/plus/no_level_equipment_recycle_total"
#define NO_LEVEL_RECYCLE_LOG ROOT "/log/no_level_equipment_recycle.log"
#define NO_LEVEL_RECYCLE_REWARD ROOT "/gamelib/clone/item/yushi/suiyu"
#define NO_LEVEL_RECYCLE_TOKEN ROOT "/gamelib/clone/item/other/ancient_skill_choice_token"

protected void create()
{
}

private string safe_recycle_log_field(string|zero value)
{
	string result = value || "";
	result = replace(result,"\r"," ");
	result = replace(result,"\n"," ");
	result = replace(result,"|","/");
	if(sizeof(result)>160)
		result = result[..159];
	return result;
}

/**
 * Legacy no-level equipment is encoded explicitly as item_canLevel=-1.
 * Requiring both the equipment inheritance and a negative requirement keeps
 * ordinary items (including items whose unrelated level fields are zero) out
 * of this migration.
 */
private int is_recyclable_no_level_equipment(object|zero item)
{
	int recyclable = 0;
	mixed err;
	if(!item)
		return 0;
	err = catch {
		recyclable = item->is("equip") &&
			functionp(item->query_item_canLevel) &&
			(int)item->query_item_canLevel()<0;
	};
	return !err && recyclable;
}

private object|zero load_personal_warehouse_item(mixed raw_entry)
{
	string relative_path;
	object|zero item;
	mixed err;
	if(!arrayp(raw_entry) || sizeof((array)raw_entry)<4 ||
	   !stringp(((array)raw_entry)[3]))
		return 0;
	relative_path = (string)((array)raw_entry)[3];
	if(relative_path=="" || search(relative_path,"..")!=-1 ||
	   has_prefix(relative_path,"/") || search(relative_path,"\\")!=-1)
		return 0;
	err = catch { item = clone(ITEM_PATH+relative_path); };
	if(err)
		return 0;
	return item;
}

private void detach_recycled_equipment(object player,object item)
{
	string item_kind = "";
	if(!player || !item || !item->equiped)
		return;
	if(functionp(item->query_item_kind))
		item_kind = (string)item->query_item_kind();
	if(item_kind=="double_main_weapon" ||
	   item_kind=="single_main_weapon" ||
	   item_kind=="single_other_weapon")
		player->unwield(item);
	else
		player->unwear(item);
}

private array(object) prepare_recycle_rewards(object player,int count)
{
	array(object) rewards = ({});
	int remaining = count;
	while(remaining>0){
		object|zero reward;
		int one_amount;
		mixed err = catch { reward = clone(NO_LEVEL_RECYCLE_REWARD); };
		if(err || !reward){
			foreach(rewards,object prepared)
				if(prepared)
					destruct(prepared);
			return ({});
		}
		one_amount = reward->max_count>0 ? reward->max_count : 30;
		if(one_amount>remaining)
			one_amount = remaining;
		reward->amount = one_amount;
		if(!reward->move(player)){
			destruct(reward);
			foreach(rewards,object prepared)
				if(prepared)
					destruct(prepared);
			return ({});
		}
		rewards += ({reward});
		remaining -= one_amount;
	}
	return rewards;
}

private void resize_recycle_rewards(array(object) rewards,int count)
{
	int remaining = count;
	foreach(rewards,object reward){
		int one_amount;
		if(!reward)
			continue;
		if(remaining<=0){
			destruct(reward);
			continue;
		}
		one_amount = reward->max_count>0 ? reward->max_count : 30;
		if(one_amount>remaining)
			one_amount = remaining;
		reward->amount = one_amount;
		remaining -= one_amount;
	}
}

private array(object) prepare_recycle_tokens(object player,int count)
{
	array(object) rewards = ({});
	int remaining = count;
	while(remaining>0){
		object|zero reward;
		int one_amount;
		mixed err = catch { reward = clone(NO_LEVEL_RECYCLE_TOKEN); };
		if(err || !reward){
			foreach(rewards,object prepared)
				if(prepared)
					destruct(prepared);
			return ({});
		}
		one_amount = reward->max_count>0 ? reward->max_count : 999;
		if(one_amount>remaining)
			one_amount = remaining;
		reward->amount = one_amount;
		if(!reward->move(player)){
			destruct(reward);
			foreach(rewards,object prepared)
				if(prepared)
					destruct(prepared);
			return ({});
		}
		rewards += ({reward});
		remaining -= one_amount;
	}
	return rewards;
}

private void rollback_recycle_rewards(array(object) rewards)
{
	foreach(rewards,object reward)
		if(reward)
			destruct(reward);
}

private int deliver_no_level_recycle_mail(object player)
{
	mapping notice;
	string body;
	int delivered = 0;
	mixed err;
	if(!player)
		return 0;
	notice = player[NO_LEVEL_RECYCLE_NOTICE];
	if(!mappingp(notice) || (int)notice["count"]<1)
		return 1;
	body = "系统共回收了你"+(string)((int)notice["count"])+
		"件历史无等级装备，并按每件1块发放了"+
		(string)((int)notice["reward"])+
		"块【玉】碎玉到背包。只处理穿戴等级明确为-1的装备，"+
		"普通道具、任务品、材料、药品和宝箱均未处理。";
	if((int)notice["ancient_tokens"]>0)
		body += "本次累计达到10件里程碑，另发放"+
			(string)((int)notice["ancient_tokens"])+
			"枚【太古传承择卷】，可在背包中指定一本当前职业的太古技能书。";
	body += "当前累计余数为"+
		(string)((int)player[NO_LEVEL_RECYCLE_TOTAL]%10)+"/10。";
	err = catch {
		delivered = player->recieve_mail("CHAT","系统通知",
			player->query_name(),player->query_name_cn(),
			"历史无等级装备回收",body);
	};
	if(!err && delivered){
		player->m_delete_foruser(NO_LEVEL_RECYCLE_NOTICE);
		return 1;
	}
	return 0;
}

/**
 * Recycle legacy -1 equipment from the live inventory (including equipped
 * slots) and the character's personal warehouse. Rewards are materialized
 * first, then resized to the exact number of objects actually removed, so a
 * failed candidate cannot over-credit the player. All state lives in the same
 * atomic character archive.
 */
mapping(string:mixed) recycle_no_level_equipment(object player,
	int|void skip_persist)
{
	array(object) inventory_candidates = ({});
	array(int) warehouse_candidates = ({});
	array(object) rewards;
	array(object) token_rewards = ({});
	array(string) audit_items = ({});
	array updated_warehouse = ({});
	int candidate_count;
	int removed_count;
	int inventory_removed;
	int warehouse_removed;
	int previous_total;
	int maximum_tokens;
	int ancient_tokens;
	int persisted = 0;
	if(!player)
		return (["count":0,"reward":0]);

	foreach(all_inventory(player),object item)
		if(is_recyclable_no_level_equipment(item))
			inventory_candidates += ({item});

	if(arrayp(player->packaged_items)){
		for(int index=0;index<sizeof(player->packaged_items);index++){
			object|zero stored = load_personal_warehouse_item(
				player->packaged_items[index]);
			if(stored){
				if(is_recyclable_no_level_equipment(stored))
					warehouse_candidates += ({index});
				destruct(stored);
			}
		}
	}
	candidate_count = sizeof(inventory_candidates)+
		sizeof(warehouse_candidates);
	if(candidate_count<1){
		deliver_no_level_recycle_mail(player);
		return (["count":0,"reward":0]);
	}

	rewards = prepare_recycle_rewards(player,candidate_count);
	if(!sizeof(rewards)){
		Stdio.append_file(NO_LEVEL_RECYCLE_LOG,
			(string)time()+"|reward_prepare_failed|"+
			safe_recycle_log_field(player->query_name())+"|candidates="+
			(string)candidate_count+"\n");
		return (["count":0,"reward":0,"error":"reward_prepare_failed"]);
	}
	previous_total = (int)player[NO_LEVEL_RECYCLE_TOTAL];
	if(previous_total<0)
		previous_total = 0;
	maximum_tokens = (previous_total+candidate_count)/10-
		previous_total/10;
	if(maximum_tokens>0){
		token_rewards = prepare_recycle_tokens(player,maximum_tokens);
		if(!sizeof(token_rewards)){
			rollback_recycle_rewards(rewards);
			Stdio.append_file(NO_LEVEL_RECYCLE_LOG,
				(string)time()+"|token_prepare_failed|"+
				safe_recycle_log_field(player->query_name())+"|candidates="+
				(string)candidate_count+"\n");
			return (["count":0,"reward":0,
				"error":"token_prepare_failed"]);
		}
	}

	foreach(inventory_candidates,object item){
		string detail;
		mixed remove_err;
		if(!item)
			continue;
		detail = safe_recycle_log_field((string)item->query_name_cn())+
			"("+safe_recycle_log_field((string)item->query_name())+")";
		detach_recycled_equipment(player,item);
		remove_err = catch { item->remove(); };
		if(!remove_err && !objectp(item)){
			inventory_removed++;
			audit_items += ({"inventory:"+detail});
		}
	}

	if(arrayp(player->packaged_items)){
		multiset(int) remove_indexes = (multiset(int))warehouse_candidates;
		for(int index=0;index<sizeof(player->packaged_items);index++){
			mixed entry = player->packaged_items[index];
			if(remove_indexes[index]){
				string detail = arrayp(entry) && sizeof((array)entry)>1 ?
					safe_recycle_log_field((string)((array)entry)[1]) :
					"unknown";
				warehouse_removed++;
				audit_items += ({"warehouse:"+detail});
				continue;
			}
			updated_warehouse += ({entry});
		}
		player->packaged_items = updated_warehouse;
	}

	removed_count = inventory_removed+warehouse_removed;
	resize_recycle_rewards(rewards,removed_count);
	ancient_tokens = (previous_total+removed_count)/10-previous_total/10;
	resize_recycle_rewards(token_rewards,ancient_tokens);
	if(removed_count>0){
		mapping pending = player[NO_LEVEL_RECYCLE_NOTICE];
		if(!mappingp(pending))
			pending = (["count":0,"reward":0]);
		pending["count"] = (int)pending["count"]+removed_count;
		pending["reward"] = (int)pending["reward"]+removed_count;
		pending["ancient_tokens"] = (int)pending["ancient_tokens"]+
			ancient_tokens;
		pending["updated_at"] = time();
		player[NO_LEVEL_RECYCLE_NOTICE] = pending;
		player[NO_LEVEL_RECYCLE_TOTAL] = previous_total+removed_count;
		Stdio.append_file(NO_LEVEL_RECYCLE_LOG,
			(string)time()+"|recycled|"+
			safe_recycle_log_field(player->query_name())+"|inventory="+
			(string)inventory_removed+"|warehouse="+
			(string)warehouse_removed+"|reward="+
			(string)removed_count+"|ancient_tokens="+
			(string)ancient_tokens+"|total="+
			(string)((int)player[NO_LEVEL_RECYCLE_TOTAL])+"|items="+
			(audit_items*",")+"\n");
		tell_object(player,"系统已回收你"+(string)removed_count+
			"件历史无等级装备，并发放"+(string)removed_count+
			"块【玉】碎玉。"+(ancient_tokens>0 ?
			("另获"+(string)ancient_tokens+"枚【太古传承择卷】。") :
			"")+"详情已发送至邮箱。\n");
	}
	deliver_no_level_recycle_mail(player);
	if(removed_count>0 && !skip_persist &&
	   functionp(player->save_with_result)){
		mixed save_err = catch { persisted=player->save_with_result(); };
		if(save_err || !persisted)
			Stdio.append_file(NO_LEVEL_RECYCLE_LOG,
				(string)time()+"|post_recycle_save_failed|"+
				safe_recycle_log_field(player->query_name())+"|count="+
				(string)removed_count+"\n");
	}
	return (["count":removed_count,"reward":removed_count,
		"ancient_tokens":ancient_tokens,
		"recycle_total":previous_total+removed_count,
		"next_token_progress":(previous_total+removed_count)%10,
		"inventory":inventory_removed,"warehouse":warehouse_removed,
		"persisted":persisted]);
}

void do_remove(object me)
{
}
void do_login(object me)
{
	check_daily(me);
	// 默认关闭且只匹配管理员批准的证据白名单；每个人物最多结案一次。
	mixed jade_recovery_err=catch{ JADE_RECOVERYD->apply_if_listed(me); };
	if(jade_recovery_err)
		werror("[JADE_RECOVERY] login hook failed safely userid=%s error=%s\n",
			me && functionp(me->query_name) ? (string)me->query_name() :
				"unknown",describe_error(jade_recovery_err));
	recycle_no_level_equipment(me);
	// 采纳奖励支持离线审核，玩家下次登录时自动补发且有领取凭据防重。
	FEEDBACKD->deliver_pending_rewards(me);
}
void check_daily(object me)
{
	mapping now_time = localtime(time());
	int day = now_time["mday"];
	int month = now_time["mon"]+1;
	//更新日信息
	if((int)me["/plus/daily/day"]!=day || (int)me["/plus/daily/mon"]!=month){
		//记录每次登录，该用户级别信息，金钱信息，荣誉信息(包括杀人数)
		if(me->query_raceId()=="human"){
			Stdio.append_file(ROOT+"/log/pk/human_"+month+"_"+day+"_user_day_info.log",me->query_profeId()+"|"+me->query_name_cn()+"("+me->query_name()+"):level="+me->query_level()+"|money="+me->query_account()+"|hlevel="+me->honerlv+"|killcount="+me->killcount+"\n");
		}
		if(me->query_raceId()=="monst"){
			Stdio.append_file(ROOT+"/log/pk/monst_"+month+"_"+day+"_user_day_info.log",me->query_profeId()+"|"+me->query_name_cn()+"("+me->query_name()+"):level="+me->query_level()+"|money="+me->query_account()+"|hlevel="+me->honerlv+"|killcount="+me->killcount+"\n");
		}
		if(me->query_raceId()=="third"){
			Stdio.append_file(ROOT+"/log/pk/third_"+month+"_"+day+"_user_day_info.log",me->query_profeId()+"|"+me->query_name_cn()+"("+me->query_name()+"):level="+me->query_level()+"|money="+me->query_account()+"|hlevel="+me->honerlv+"|killcount="+me->killcount+"\n");
		}
		//////////////////得到多长时间没上线,作为乘数,乘以每天需要剪去的荣誉值
		int tmp;
		int monthdiff = month - me["/plus/daily/mon"];
		if( monthdiff == 0 ){//本月的情况
			tmp = day - (int)me["/plus/daily/day"]; 
			if(tmp<=0)
				tmp = 1;
		}
		else if(monthdiff == 1){//差一个月的情况
			tmp = 30 - (int)me["/plus/daily/day"] + day;	
			if(tmp<=0)
				tmp = 1;
		}
		else if((int)me["/plus/daily/mon"]-month==11){//上年12月到今年1月
			tmp = 30 - (int)me["/plus/daily/day"] + day;	
			if(tmp<=0)
				tmp = 1;
		}
		else//其他情况
			tmp = 60;
		me->m_delete_foruser("/plus/daily");
		//////////////////得到多长时间没上线,作为乘数,乘以每天需要剪去的荣誉值
		me["/plus/daily/day"]=day;
		me["/plus/daily/mon"]=month;
		//更新荣誉值存储敌人映射表
		me["/plus/daily/honer_map"]=([]);
		//重置领取赠送物品的标志位
		me->get_gift = 0;
		//重置每天一次领取记录
		me->get_once_day=([]);
		//每次登录需要更新荣誉值
		//荣誉值会随着时间的推移而降低，玩家的荣誉值每天会减少
		//玩家荣誉级别*20
		if(me->honerpt>0){
			me->honerpt = (int)(pow(0.99,tmp)*me->honerpt);
			if(me->honerpt<=0)
				me->honerpt=0;
			//刷新该玩家荣誉表现
			me->honerlv = WAP_HONERD->flush_honer_level(me->honerpt,me->honerlv);
		}
		//轮回值绝对值每天以2点速度减少.
		if(me->lunhuipt){
			if(me->lunhuipt>=2){
				me->lunhuipt -= 2;
			}
			else if(me->lunhuipt<=-2){
				me->lunhuipt += 2;
			}
			else{
				me->lunhuipt = 0;
			}
		}

		//更新每日随机奖励限次20次
		if(me["/plus/random_award"]<=50)
			me["/plus/random_award"]=50;

		//自动打怪普通玩家8小时，VIP每级增加2小时，VIP8最高24小时。
		AUTOFIGHTD->reset_daily_time(me);
		if(functionp(me->set_autofight))
			me->set_autofight("disable");
		
		//写入日登陆用户信息的统计，包括写入数据库和写入log 
		//由liaocheng于07/08/13添加
		USER_COUNTD->entry_record(me);
	}
}
