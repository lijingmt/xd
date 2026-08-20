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
		write("当前幻境不再按日期自动结束。只有管理员显式关闭开关，才会进入现有安全结算流程。\n"+
			"[返回幻境管理:mgr_illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=3 && parts[0]=="endtime_apply"){
		write("旧的日期关闭确认已经停用，没有修改当前赛季状态。\n"+
			"[返回幻境管理:mgr_illusion_realm]\n");
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
	s += "运行方式：管理员保持开启，显式关闭后才结算　"+
		(string)status["illusion_id"]+"赛季资格登记费用："+
		(string)(int)status["entitlement_cost_suiyu"]+
		"碎玉　人物栏位：每名100碎玉，5格500碎玉\n";
	s += "配置编号固定："+(string)status["illusion_id"]+"\n";
	s += "开始时间："+time_text((int)status["starts_at"])+"\n";
	if((string)status["phase"]=="settling" ||
	   (string)status["phase"]=="closed")
		s += "管理员关闭时间："+time_text((int)status["ends_at"])+"\n";
	mapping population = ACCOUNT_CHARACTERD->query_illusion_population(
		(string)status["illusion_id"]);
	s += "本期人物：进行中 "+(string)(int)population["active"]+
		"，已回归 "+(string)(int)population["returned"]+
		"，索引异常 "+(string)(int)population["corrupt_indexes"]+"\n";
	if((string)status["phase"]=="draft")
		s += "[开放"+(string)status["illusion_id"]+
			"赛季资格登记（人物栏位另付费）:mgr_illusion_realm preview open_registration]\n";
	else if((string)status["phase"]=="registration")
		s += "[正式开启"+(string)status["illusion_id"]+
			"（持续到管理员关闭）:mgr_illusion_realm preview start]\n";
	else if((string)status["phase"]=="active")
		s += "当前开关：开启。不会按日期自动结束；关闭需要二次确认。\n"+
			"[关闭本期并开始安全结算:mgr_illusion_realm preview settle]\n";
	else if((string)status["phase"]=="settling")
		s += "系统正在自动回归在线人物并关闭本期，无需人工操作。\n";
	else if((string)status["phase"]=="closed")
		s += "编辑下一期配置并完整重启后，使用：\n"+
			"[预览建立下一期草稿:mgr_illusion_realm rollover]\n";
	else if((string)status["phase"]=="disabled")
		s += "若刚替换为下一期配置，请核对旧周期归档并执行：\n"+
			"[预览建立下一期草稿:mgr_illusion_realm rollover]\n";
	s += "\n新赛季必须在新人物、任务与装备开发验收后人工开启；本期只有管理员关闭开关后才结算。\n";
	s += "每次人工修改均需预览后二次确认，写入共享状态并记录管理员与修订号。\n";
	s += "[返回管理主界面:game_deal]\n";
	write(s);
	return 1;
}
