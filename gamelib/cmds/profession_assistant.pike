#include <command.h>
#include <gamelib/include/gamelib.h>

private string format_duration(int seconds)
{
	int days;
	int hours;
	if(seconds <= 0)
		return "0小时";
	days = seconds/86400;
	hours = (seconds%86400)/3600;
	if(days > 0)
		return days+"天"+hours+"小时";
	return hours+"小时";
}

private string bool_desc(int value)
{
	return value ? "已开启" : "已关闭";
}

private string summon_name(string summon_type)
{
	if(summon_type == "huling") return "虎灵";
	if(summon_type == "heling") return "鹤灵";
	if(summon_type == "guiling") return "龟灵";
	return "灵兽";
}

private string fail_reason(mapping result)
{
	string reason = (string)result["reason"];
	if(reason == "claimed") return "该奖励已经领取。";
	if(reason == "active_vip") return "你已有黄金或更高会员，试用资格已为以后保留。";
	if(reason == "vip") return "当前职业助手等级不足。";
	if(reason == "disabled") return "对应自动化开关尚未开启。";
	if(reason == "combat") return "战斗中不能自动补召；手动技能仍可正常使用。";
	if(reason == "full") return "当前灵兽数量已达到人物等级对应上限。";
	if(reason == "no_learned_summon") return "没有可补召的已学灵兽技能。";
	if(reason == "level") return "人物等级尚未达到领取或购买条件。";
	if(reason == "owned") return "已经永久拥有，无需重复购买。";
	if(reason == "yushi") return "仙玉不足，本次没有扣除。";
	return "操作条件不满足，本次没有产生消耗。";
}

private string strategy_links(object me)
{
	string profe = me->query_profeId();
	int include_auto = PROFESSIONVIPD->query_effective_level(me) >= 4;
	string s = "";
	foreach(PROFESSIONVIPD->query_valid_strategies(profe,include_auto),
	   string strategy){
		string name = PROFESSIONVIPD->query_strategy_name(profe,strategy);
		if(PROFESSIONVIPD->query_strategy(me) == strategy)
			s += "✓ "+name+"（当前）\n";
		else
			s += "[切换为"+name+":profession_assistant strategy "+
				strategy+"]\n";
	}
	return s;
}

private string render_slots(object me)
{
	string s = "【职业助手·策略槽】\n\n";
	int limit = PROFESSIONVIPD->query_slot_limit_for_level(
		PROFESSIONVIPD->query_effective_level(me));
	s += "当前可用"+limit+"个槽位；会员过期或降档后配置会保留，只暂停超出档位的槽位。\n\n";
	for(int i=1;i<=4;i++){
		string strategy = PROFESSIONVIPD->query_strategy_slot(me,i);
		string name = PROFESSIONVIPD->query_strategy_name(
			me->query_profeId(),strategy);
		if(i <= limit)
			s += "槽位"+i+"："+name+
				" [使用:profession_assistant slot use "+i+"]\n";
		else
			s += "槽位"+i+"："+name+"（当前档位未开放，配置保留）\n";
	}
	s += "\n将当前策略保存到：";
	for(int i=1;i<=limit;i++)
		s += "[槽"+i+":profession_assistant slot save "+i+"] ";
	s += "\n\n[返回职业助手:profession_assistant]\n[返回游戏:look]\n";
	return s;
}

private string render_styles(object me)
{
	string profe = me->query_profeId();
	string selected = PROFESSIONVIPD->query_selected_style(me);
	string s = "【职业成长·纯外观】\n\n";
	s += "所有外观只改变头像光效、灵兽称号或职业施法文字，不增加任何属性。\n";
	s += "可单独永久购买，也可购买成长外观册后按20/50/80级领取。\n\n";
	foreach(PROFESSIONVIPD->query_style_ids(profe),string style){
		mapping info = PROFESSIONVIPD->query_style_info(profe,style);
		string line = (string)info["name"]+"（"+(int)info["level"]+"级）";
		if(selected == style)
			s += "✓ "+line+"（已装备）\n";
		else if(PROFESSIONVIPD->owns_style(me,style))
			s += "[装备"+line+":profession_assistant style equip "+style+"]\n";
		else
			s += "[查看"+line+":profession_assistant style detail "+style+"]\n";
	}
	s += "\n[职业成长外观册:profession_assistant pass]\n";
	s += "[返回职业助手:profession_assistant]\n[返回游戏:look]\n";
	return s;
}

private string render_pass(object me)
{
	string s = "【职业成长外观册】\n\n";
	s += "免费成长称号："+PROFESSIONVIPD->query_growth_title(me)+"。\n";
	s += "称号只由人物等级解锁，所有玩家免费，不增加属性。\n\n";
	s += "外观册价格："+YUSHID->get_yushi_for_desc(240)+
		"，永久生效；达到20/50/80级可领取本职业三套纯外观。\n";
	if((int)me["/plus/profession_vip/pass"] != 1)
		s += "[查看并确认购买:profession_assistant pass detail]\n";
	else{
		s += "你已永久拥有职业成长外观册。\n";
		for(int tier=1;tier<=3;tier++){
			string style = PROFESSIONVIPD->query_pass_style_for_tier(
				me->query_profeId(),tier);
			mapping info = PROFESSIONVIPD->query_style_info(
				me->query_profeId(),style);
			if(PROFESSIONVIPD->owns_style(me,style))
				s += "✓ "+(string)info["name"]+"已领取\n";
			else
				s += "[领取"+(string)info["name"]+":profession_assistant pass claim "+tier+"]（"+(int)info["level"]+"级）\n";
		}
	}
	s += "\n[返回外观:profession_assistant styles]\n";
	s += "[返回职业助手:profession_assistant]\n[返回游戏:look]\n";
	return s;
}

private string render_lingyi_aoe_targets(object me)
{
	mapping(string:int) targets =
		PROFESSIONVIPD->query_lingyi_aoe_target_races(me);
	mapping(string:string) labels = ([
		"human":"仙阵营",
		"monst":"妖阵营",
		"third":"中立阵营",
	]);
	string s = "【药雾天罗·阵营目标】\n\n";
	s += "此设置只筛选已参战的玩家及其召唤物；普通野怪仍按正常战斗规则命中。\n";
	s += "队友、好友、同账号角色和未参战路人永久保护，不受下列开关影响。\n\n";
	foreach(({"human","monst","third"}),string race_id){
		int enabled = (int)targets[race_id];
		s += (enabled ? "✓ " : "○ ")+(string)labels[race_id]+
			"："+(enabled ? "可攻击" : "不攻击")+" "+
			"[切换为"+(enabled ? "不攻击" : "可攻击")+
			":profession_assistant aoe_target "+race_id+" "+
			(enabled ? "0" : "1")+"]\n";
	}
	s += "\n配置保存在当前角色档案，下次施放立即生效。\n";
	s += "\n[返回职业助手:profession_assistant]\n[返回游戏:look]\n";
	return s;
}

private string render_panel(object me)
{
	string profe = me->query_profeId();
	string s = "【"+PROFESSIONVIPD->query_assistant_name(profe)+"】\n\n";
	int level = PROFESSIONVIPD->query_effective_level(me);
	mapping stats = PROFESSIONVIPD->query_month_stats(me);
	string expiry = PROFESSIONVIPD->query_expiry_notice(me);
	s += "公平规则：全部职业技能、手动召唤、手动治疗/守御、装备与掉落永久免费；会员只节省重复操作时间。\n\n";
	s += "成长称号："+PROFESSIONVIPD->query_growth_title(me)+"\n";
	s += "助手档位："+PROFESSIONVIPD->query_assistant_level_label(level)+"\n";
	if(PROFESSIONVIPD->query_trial_seconds_left(me) > 0)
		s += "黄金级试用剩余："+format_duration(
			PROFESSIONVIPD->query_trial_seconds_left(me))+"\n";
	if(expiry != ""){
		s += "\n【到期提醒】"+expiry+"\n";
		s += "[知道了:profession_assistant expiry_ack]\n";
	}
	if(level <= 0 && !(int)me["/plus/profession_vip/trial_claimed"])
		s += "[领取3天黄金级职业助手试用:profession_assistant trial]\n";
	else if(level <= 0)
		s += "当前自动化暂停，全部配置均已保留。\n";
	s += "\n当前策略："+PROFESSIONVIPD->query_strategy_name(
		profe,PROFESSIONVIPD->query_strategy(me))+"\n";
	s += strategy_links(me);
	s += "\n监控提醒："+bool_desc(PROFESSIONVIPD->query_monitor_enabled(me));
	if(level >= 1)
		s += " [切换:profession_assistant monitor "+
			(PROFESSIONVIPD->query_monitor_enabled(me) ? "0" : "1")+"]";
	s += "\n自动执行："+bool_desc(PROFESSIONVIPD->query_auto_enabled(me));
	if(level >= 2)
		s += " [切换:profession_assistant auto "+
			(PROFESSIONVIPD->query_auto_enabled(me) ? "0" : "1")+"]";
	s += "\n";
	if(profe == "fangshi"){
		s += "自动共鸣："+bool_desc(PROFESSIONVIPD->query_resonance_enabled(me));
		if(level >= 3)
			s += " [切换:profession_assistant resonance "+
				(PROFESSIONVIPD->query_resonance_enabled(me) ? "0" : "1")+"]";
		s += "\n";
		if(level >= 1)
			s += "[一键补齐已学灵兽:profession_assistant replenish]\n";
		s += "[手动召唤与共鸣（永久免费）:summon]\n";
	}
	else if(profe == "zhenyue"){
		if(level >= 1)
			s += "[查看当前守御建议:profession_assistant recommend]\n";
		s += "[查看技能（手动施放永久免费）:myskills]\n";
	}
	else if(profe == "tianxiang"){
		if(level >= 1)
			s += "[查看当前星痕建议:profession_assistant recommend]\n";
		s += "[查看技能（手动施放永久免费）:myskills]\n";
	}
	else if(profe == "lingyi"){
		if(level >= 1)
			s += "[查看当前救治建议:profession_assistant recommend]\n";
		s += "[群攻阵营目标设置:profession_assistant aoe_targets]\n";
		s += "[查看技能与药契（手动治疗永久免费）:myskills]\n";
	}
	s += "\n[策略配置槽:profession_assistant slots]\n";
	s += "[职业成长外观:profession_assistant styles]\n";
	s += "\n本月记录：执行"+(int)stats["action"]+
		"次、提醒"+(int)stats["warning"]+"次、召唤"+
		(int)stats["summon"]+"次、共鸣"+(int)stats["resonance"]+
		"次、仇恨"+(int)stats["taunt"]+"次、守御"+
		(int)stats["guard"]+"次。\n";
	if(level < 4){
		if(VIPD->query_active_vip_level(me) > 0)
			s += "[升级会员解锁更多自动化:vip_service_upgrade_list]\n";
		else
			s += "[开通会员解锁更多自动化:vip_service_app_list]\n";
	}
	else
		s += "[续费保持职业助手:vip_service_extend_detail]\n";
	if(!YUSHID->have_enough_yushi(me,
	   VIPD->query_level_limit_next_cost(me)))
		s += "[仙玉不足？捐赠获取:add_szx_fee]\n";
	s += "[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	array(string) parts;
	string s = "";
	if(!me)
		return 0;
	if(!PROFESSIONVIPD->is_supported_profession(me->query_profeId())){
		write("当前职业暂未配置专属助手；基础挂机和全部职业功能仍可正常使用。\n[返回游戏:look]\n");
		return 1;
	}
	PROFESSIONVIPD->initialize_player(me);
	if(!arg || arg == "" || arg == "open"){
		write(render_panel(me));
		return 1;
	}
	parts = arg/" ";
	if(parts[0] == "trial"){
		mapping result = PROFESSIONVIPD->claim_trial(me);
		if(result["success"])
			s += "3天黄金级职业助手试用已开启；这不会改变你的通用VIP、等级上限或战斗属性。\n";
		else
			s += fail_reason(result)+"\n";
	}
	else if(parts[0] == "expiry_ack"){
		PROFESSIONVIPD->acknowledge_expiry(me);
		s += "到期提醒已确认，配置继续保留。\n";
	}
	else if(parts[0] == "strategy" && sizeof(parts) >= 2){
		if(PROFESSIONVIPD->set_strategy(me,parts[1]))
			s += "职业策略已切换为"+
				PROFESSIONVIPD->query_strategy_name(me->query_profeId(),parts[1])+"。\n";
		else
			s += "当前档位不能使用该策略，配置未改变。\n";
	}
	else if(parts[0] == "monitor" && sizeof(parts) >= 2){
		if(PROFESSIONVIPD->set_monitor_enabled(me,(int)parts[1]))
			s += "监控提醒设置已保存。\n";
		else s += "水晶级职业助手才可调整监控提醒。\n";
	}
	else if(parts[0] == "auto" && sizeof(parts) >= 2){
		if(PROFESSIONVIPD->set_auto_enabled(me,(int)parts[1]))
			s += "自动执行设置已保存；仅在PVE挂机中生效。\n";
		else s += "黄金级职业助手才可开启自动执行。\n";
	}
	else if(parts[0] == "resonance" && sizeof(parts) >= 2){
		if(PROFESSIONVIPD->set_resonance_enabled(me,(int)parts[1]))
			s += "自动灵契共鸣设置已保存；仅在PVE救援需要时触发。\n";
		else s += "白金级方士职业助手才可开启自动共鸣。\n";
	}
	else if(parts[0] == "aoe_targets" && me->query_profeId()=="lingyi"){
		write(render_lingyi_aoe_targets(me));
		return 1;
	}
	else if(parts[0] == "aoe_target" && sizeof(parts) >= 3 &&
	   me->query_profeId()=="lingyi"){
		if(PROFESSIONVIPD->set_lingyi_aoe_target_enabled(me,
		   parts[1],(int)parts[2])){
			me->save();
			write(render_lingyi_aoe_targets(me));
			return 1;
		}
		s += "阵营目标参数无效，配置未改变。\n";
	}
	else if(parts[0] == "slots"){
		write(render_slots(me));
		return 1;
	}
	else if(parts[0] == "slot" && sizeof(parts) >= 3){
		int slot = (int)parts[2];
		if(parts[1] == "use"){
			if(PROFESSIONVIPD->use_strategy_slot(me,slot))
				s += "已载入槽位"+slot+"。\n";
			else s += "当前档位不能使用这个槽位。\n";
		}
		else if(parts[1] == "save"){
			if(PROFESSIONVIPD->save_strategy_slot(me,slot,
			   PROFESSIONVIPD->query_strategy(me)))
				s += "当前策略已保存到槽位"+slot+"。\n";
			else s += "当前档位不能保存这个槽位。\n";
		}
	}
	else if(parts[0] == "replenish"){
		mapping result = PROFESSIONVIPD->replenish_fangshi(me,0);
		if(result["success"])
			s += "职业助手已补召"+summon_name((string)result["summon"])+"。\n";
		else s += fail_reason(result)+"\n";
	}
	else if(parts[0] == "recommend"){
		string skill = "";
		if(me->query_profeId()=="tianxiang")
			skill = PROFESSIONVIPD->query_tianxiang_manual_recommendation(me);
		else if(me->query_profeId()=="lingyi")
			skill = PROFESSIONVIPD->query_lingyi_manual_recommendation(me);
		else
			skill = PROFESSIONVIPD->query_zhenyue_manual_recommendation(me);
		if(skill == "")
			s += "当前没有已学且适合展示的职业技能，请先查看技能学习路线。\n";
		else{
			object|zero skill_ob = MUD_SKILLSD[skill];
			string skill_cn = skill_ob ? skill_ob->query_name_cn() : skill;
			s += "当前建议："+skill_cn+"。建议只做提示，手动施放仍按原技能消耗和冷却。\n";
			s += "[施放"+skill_cn+":use_perform "+skill+"]\n";
		}
	}
	else if(parts[0] == "styles"){
		write(render_styles(me));
		return 1;
	}
	else if(parts[0] == "style" && sizeof(parts) >= 3){
		string action = parts[1];
		string style = parts[2];
		mapping info = PROFESSIONVIPD->query_style_info(me->query_profeId(),style);
		if(!sizeof(info))
			s += "外观编号无效，本次没有扣除。\n";
		else if(action == "detail"){
			me["/tmp/profession_vip/pending_style"] = style;
			me["/tmp/profession_vip/pending_style_time"] = time();
			s += "【"+(string)info["name"]+"】\n";
			s += "需要人物"+(int)info["level"]+"级，永久价格"+
				YUSHID->get_yushi_for_desc((int)info["cost"])+"。\n";
			s += "确认：仅购买纯外观，不含属性、召唤数量或技能加成。\n";
			s += "[确认购买:profession_assistant style buy "+style+"]\n";
			write(s+"[返回外观:profession_assistant styles]\n");
			return 1;
		}
		else if(action == "buy"){
			if((string)me["/tmp/profession_vip/pending_style"] != style ||
			   time()-(int)me["/tmp/profession_vip/pending_style_time"] > 120)
				s += "购买确认已失效，请重新查看外观详情。\n";
			else{
				me["/tmp/profession_vip/pending_style"] = "";
				mapping result = PROFESSIONVIPD->buy_style(me,style);
				if(result["success"])
					s += "已永久获得并装备"+(string)info["name"]+"。\n";
				else s += fail_reason(result)+"\n";
			}
		}
		else if(action == "equip"){
			if(PROFESSIONVIPD->equip_style(me,style))
				s += "已装备"+(string)info["name"]+"。\n";
			else s += "你尚未永久拥有该外观。\n";
		}
	}
	else if(parts[0] == "pass"){
		if(sizeof(parts) == 1){
			write(render_pass(me));
			return 1;
		}
		if(parts[1] == "detail"){
			me["/tmp/profession_vip/pending_pass_time"] = time();
			s += "职业成长外观册永久价格"+
				YUSHID->get_yushi_for_desc(240)+"。\n";
			s += "内含20/50/80级三套本职业纯外观，不增加任何战斗属性。\n";
			s += "[确认购买:profession_assistant pass buy]\n";
			write(s+"[返回外观册:profession_assistant pass]\n");
			return 1;
		}
		if(parts[1] == "buy"){
			if(time()-(int)me["/tmp/profession_vip/pending_pass_time"] > 120 ||
			   !(int)me["/tmp/profession_vip/pending_pass_time"])
				s += "购买确认已失效，请重新查看外观册详情。\n";
			else{
				me["/tmp/profession_vip/pending_pass_time"] = 0;
				mapping result = PROFESSIONVIPD->buy_growth_pass(me);
				if(result["success"])
					s += "已永久获得职业成长外观册。\n";
				else s += fail_reason(result)+"\n";
			}
		}
		else if(parts[1] == "claim" && sizeof(parts) >= 3){
			mapping result = PROFESSIONVIPD->claim_pass_style(me,(int)parts[2]);
			if(result["success"]){
				mapping info = PROFESSIONVIPD->query_style_info(
					me->query_profeId(),(string)result["style"]);
				s += "已领取并装备"+(string)info["name"]+"。\n";
			}
			else s += fail_reason(result)+"\n";
		}
	}
	else
		s += "未知职业助手操作。\n";
	write(s+"[返回职业助手:profession_assistant]\n[返回游戏:look]\n");
	return 1;
}
