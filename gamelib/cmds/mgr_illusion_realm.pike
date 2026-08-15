#include <command.h>
#include <gamelib/include/gamelib.h>

private int admin_allowed(object me)
{
	return me && MANAGERD->checkpower(me->query_name())=="admin";
}

private string time_text(int at_time)
{
	mapping now_time;
	if(at_time<=0)
		return "未设置";
	now_time = localtime(at_time);
	return sprintf("%04d-%02d-%02d %02d:%02d",
		(int)now_time["year"]+1900,(int)now_time["mon"]+1,
		(int)now_time["mday"],(int)now_time["hour"],
		(int)now_time["min"]);
}

private int parse_end_time(string value)
{
	int year;
	int month;
	int day;
	int hour;
	int minute;
	int result;
	mapping verified;
	if(!value || value=="")
		return 0;
	value = replace(value,(["%3A":":","%3a":":","%20":"",
		" ":""]));
	if(sscanf(value,"%d-%d-%d_%d:%d",year,month,day,hour,minute)!=5 ||
	   year<2020 || year>2100 || month<1 || month>12 || day<1 || day>31 ||
	   hour<0 || hour>23 || minute<0 || minute>59)
		return 0;
	result = mktime(0,minute,hour,day,month-1,year-1900);
	if(result<=0)
		return 0;
	verified = localtime(result);
	if((int)verified["year"]+1900!=year ||
	   (int)verified["mon"]+1!=month ||
	   (int)verified["mday"]!=day ||
	   (int)verified["hour"]!=hour ||
	   (int)verified["min"]!=minute)
		return 0;
	return result;
}

int main(string|zero arg)
{
	object me = this_player();
	mapping status;
	array(string) parts;
	string s = "";
	if(!admin_allowed(me)){
		write("需要管理员权限才可以维护幻境生命周期。\n[返回游戏:look]\n");
		return 1;
	}
	parts = arg ? String.trim_all_whites(arg)/" " : ({});
	if(sizeof(parts)>=1 && parts[0]=="endtime"){
		int ends_at;
		mapping preview;
		if(sizeof(parts)<2){
			write("请输入服务器本地结束时间，格式：YYYY-MM-DD_HH:MM\n"+
				"[mgr_illusion_realm endtime ...]\n"+
				"[返回幻境管理:mgr_illusion_realm]\n");
			return 1;
		}
		ends_at = parse_end_time(parts[1]);
		if(ends_at<=0){
			write("结束时间格式或日期无效，请使用例如 2026-11-13_20:00。\n"+
				"[重新输入:mgr_illusion_realm endtime]\n"+
				"[返回幻境管理:mgr_illusion_realm]\n");
			return 1;
		}
		preview = SEASONALD->preview_end_time(ends_at);
		if(!(int)preview["ok"])
			write("当前不是进行中的赛季，或结束时间超出合法范围。\n");
		else
			write("新结束时间："+time_text(ends_at)+
				"（服务器本地时间）\n到点后系统将自动结算全部在线人物并关闭本期；离线人物下次登录自动回归。\n"+
				"[确认修改结束时间:mgr_illusion_realm endtime_apply "+
				(string)ends_at+" "+(string)preview["confirmation"]+"]\n");
		write("[返回幻境管理:mgr_illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=3 && parts[0]=="endtime_apply"){
		int ends_at = (int)parts[1];
		mapping result = SEASONALD->apply_end_time(ends_at,parts[2],
			(string)me->query_name());
		write((string)result["message"]+
			"\n[返回幻境管理:mgr_illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="rollover"){
		if(sizeof(parts)>=3 && parts[1]=="apply"){
			mapping result = SEASONALD->apply_cycle_rollover(parts[2],
				(string)me->query_name());
			write((string)result["message"]+
				"\n[返回幻境管理:mgr_illusion_realm]\n");
		}
		else{
			mapping preview = SEASONALD->preview_cycle_rollover();
			mapping population = preview["population"] || ([]);
			write((string)preview["message"]+"\n旧周期："+
				(string)preview["old_id"]+"　新配置："+
				(string)preview["new_id"]+"\n旧周期尚未登录回归："+
				(string)(int)population["active"]+" 人；已回归："+
				(string)(int)population["returned"]+" 人\n");
			if((int)preview["ok"])
				write("[确认建立新周期草稿:mgr_illusion_realm rollover apply "+
					(string)preview["confirmation"]+"]\n");
			write("[返回幻境管理:mgr_illusion_realm]\n");
		}
		return 1;
	}
	if(sizeof(parts)>=2 && parts[0]=="preview"){
		mapping preview = SEASONALD->preview_lifecycle_transition(parts[1]);
		if(!(int)preview["ok"])
			write("当前阶段不允许该操作，请返回查看最新状态。\n");
		else
			write("即将执行："+parts[1]+"。该操作使用修订号确认，过期会自动拒绝。\n"+
				"[最终确认:mgr_illusion_realm apply "+parts[1]+" "+
				(string)preview["confirmation"]+"]\n");
		write("[返回幻境管理:mgr_illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=3 && parts[0]=="apply"){
		mapping result = SEASONALD->apply_lifecycle_transition(parts[1],
			parts[2],(string)me->query_name());
		write((string)result["message"]+"\n[返回幻境管理:mgr_illusion_realm]\n");
		return 1;
	}
	status = SEASONALD->query_public_status();
	s += "===="+(string)status["display_name"]+"生命周期管理====\n";
	s += "状态："+(string)status["phase_name"]+"（"+
		(string)status["phase"]+"）　修订："+
		(string)(int)status["revision"]+"\n";
	s += "周期："+(string)(int)status["duration_days"]+
		"天　"+(string)status["illusion_id"]+"永久人物资格价格："+
		(string)(int)status["entitlement_cost_suiyu"]+"碎玉\n";
	s += "配置编号固定："+(string)status["illusion_id"]+"\n";
	s += "开始时间："+time_text((int)status["starts_at"])+
		"　结束时间："+time_text((int)status["ends_at"])+"\n";
	mapping population = ACCOUNT_CHARACTERD->query_illusion_population(
		(string)status["illusion_id"]);
	s += "本期人物：进行中 "+(string)(int)population["active"]+
		"，已回归 "+(string)(int)population["returned"]+
		"，索引异常 "+(string)(int)population["corrupt_indexes"]+"\n";
	if((string)status["phase"]=="draft")
		s += "[开放"+(string)status["illusion_id"]+
			"永久人物资格登记:mgr_illusion_realm preview open_registration]\n";
	else if((string)status["phase"]=="registration")
		s += "[正式开启"+(string)status["illusion_id"]+"并开始"+
			(string)(int)status["duration_days"]+
			"天计时:mgr_illusion_realm preview start]\n";
	else if((string)status["phase"]=="active")
		s += "系统会在结束时间自动结算并关闭；可修改结束时间或立即提前结束：\n"+
			"[修改结束时间:mgr_illusion_realm endtime]\n"+
			"[立即结束（需再次确认）:mgr_illusion_realm endtime "+
			sprintf("%04d-%02d-%02d_%02d:%02d",
				(int)localtime(time())["year"]+1900,
				(int)localtime(time())["mon"]+1,
				(int)localtime(time())["mday"],
				(int)localtime(time())["hour"],
				(int)localtime(time())["min"])+"]\n";
	else if((string)status["phase"]=="settling")
		s += "系统正在自动回归在线人物并关闭本期，无需人工操作。\n";
	else if((string)status["phase"]=="closed")
		s += "编辑下一期配置并完整重启后，使用：\n"+
			"[预览建立下一期草稿:mgr_illusion_realm rollover]\n";
	else if((string)status["phase"]=="disabled")
		s += "若刚替换为下一期配置，请核对旧周期归档并执行：\n"+
			"[预览建立下一期草稿:mgr_illusion_realm rollover]\n";
	s += "\n新赛季必须在新人物、任务与装备开发验收后人工开启；结束时间到达后自动结算关闭。\n";
	s += "每次人工修改均需预览后二次确认，写入共享状态并记录管理员与修订号。\n";
	s += "[返回管理主界面:game_deal]\n";
	write(s);
	return 1;
}
