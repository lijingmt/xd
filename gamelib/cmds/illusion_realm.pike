#include <command.h>
#include <gamelib/include/gamelib.h>

private string time_text(int value)
{
	if(value<=0)
		return "未确定";
	string text = ctime(value);
	return text[0..sizeof(text)-2];
}

private string progress_view(object me,mapping progress)
{
	string s = "";
	s += "路线："+(string)progress["path_name"]+"　等级："+
		(string)(int)progress["level"]+"\n";
	s += "探索："+(string)(int)progress["visits"]+
		"处　击杀："+(string)(int)progress["kills"]+
		"　首领："+(string)(int)progress["boss_kills"]+
		"　同队击杀："+(string)(int)progress["team_kills"]+"\n";
	if((string)progress["path"]=="pioneer")
		s += "寻星终章：隐藏月印 "+
			(string)(int)progress["route_mark_count"]+"/"+
			(string)(int)progress["route_target"]+"\n";
	else if((string)progress["path"]=="hunter")
		s += "破阵终章：不同守关首领 "+
			(string)(int)progress["route_mark_count"]+"/"+
			(string)(int)progress["route_target"]+"\n";
	else if((string)progress["path"]=="companion")
		s += "同心终章：同队击杀 "+
			(string)(int)progress["team_kills"]+"/"+
			(string)(int)progress["route_target"]+"\n";
	if((string)progress["path"]==""){
		s += "【三途择印】第三章前选择一次，本期不可更改：\n";
		s += "[寻星·重探索:illusion_realm path pioneer] ";
		s += "[破阵·重狩猎:illusion_realm path hunter] ";
		s += "[同心·重协作:illusion_realm path companion]\n";
	}
	foreach((array)progress["chapters"];int index;mapping chapter){
		string mark = (int)chapter["claimed"] ? "已领取" :
			((int)chapter["ready"] ? "可领取" : "进行中");
		s += "\n【"+(string)chapter["title"]+"】"+mark+"\n";
		s += (string)chapter["description"]+"\n";
		s += "目标：Lv"+(string)(int)chapter["min_level"]+
			" / 击杀"+(string)(int)chapter["kills"]+
			" / 首领"+(string)(int)chapter["boss_kills"]+
			" / 探索"+(string)(int)chapter["visits"]+
			"；奖励本职业新月套装"+
			(string)(int)chapter["reward_count"]+"件\n";
		if((int)chapter["ready"] && !(int)chapter["claimed"])
			s += "[领取本章奖励:illusion_realm claim "+
				(string)(index+1)+"]\n";
	}
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	mapping status = SEASONALD->query_public_status();
	mapping account_data;
	string s = "";
	array(string) parts = arg ? String.trim_all_whites(arg)/" " : ({});
	if(!me){
		write("人物会话不存在。\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="activate"){
		if(sizeof(parts)<2 || parts[1]!="confirm"){
			write("永久解锁幻境人物资格需要"+
				(string)(int)status["entitlement_cost_suiyu"]+
				"枚碎玉。资格属于注册账号，今后每一期都可新建一名幻境人物。\n"+
				"[确认永久解锁:illusion_realm activate confirm]\n"+
				"[取消:illusion_realm]\n");
			return 1;
		}
		mapping result = SEASONALD->purchase_entitlement(me);
		write((string)result["message"]+"\n[返回幻境区:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=2 && parts[0]=="path"){
		mapping result = SEASONALD->choose_player_path(me,parts[1]);
		write((string)result["message"]+"\n[返回"+
			(string)status["illusion_id"]+"历程:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=2 && parts[0]=="claim"){
		mapping result = SEASONALD->claim_chapter_reward(me,(int)parts[1]);
		write((string)result["message"]+"\n[返回"+
			(string)status["illusion_id"]+"历程:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="explore"){
		mapping result = SEASONALD->discover_route_secret(me);
		write((string)result["message"]+"\n[返回"+
			(string)status["illusion_id"]+"历程:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="return"){
		if(sizeof(parts)<2 || parts[1]!="confirm"){
			write("只有进入回归结算后才能执行。人物与背包不会复制，系统会把这一份原档案安全切换到永恒服。\n"+
				"[确认安全回归:illusion_realm return confirm]\n"+
				"[取消:illusion_realm]\n");
			return 1;
		}
		mapping result = SEASONALD->settle_player(me);
		write((string)result["message"]+"\n[返回游戏:look]\n");
		return 1;
	}
	s += "【"+(string)status["display_name"]+"】\n";
	s += "阶段："+(string)status["phase_name"]+"\n";
	s += "开始："+time_text((int)status["starts_at"])+"\n";
	s += "回归结算："+time_text((int)status["ends_at"])+"\n";
	if(!(int)status["ok"])
		s += "配置或运行状态校验失败，功能已安全关闭。\n";
	account_data = ACCOUNT_CHARACTERD->query_account_characters(
		(string)me->query_account_owner());
	if((int)account_data["illusion_entitled"])
		s += "永久资格：已解锁\n";
	else if((int)status["entitlement_open"])
		s += "永久资格：未解锁　[查看并购买:illusion_realm activate]\n";
	else
		s += "永久资格：当前未开放购买\n";
	if(SEASONALD->is_active_illusion_character(me)){
		mapping progress = SEASONALD->query_player_progress(me);
		if((int)progress["ok"])
			s += "\n"+progress_view(me,progress);
		if((string)status["phase"]=="settling" ||
		   (string)status["phase"]=="closed")
			s += "\n["+(string)status["illusion_id"]+
				"人物安全回归:illusion_realm return]\n";
	}
	else if((int)status["creation_open"] &&
	   (int)account_data["illusion_entitled"])
		s += "请回到账号人物中心，选择“"+
			(string)status["display_name"]+"”创建本期人物。\n";
	s += "\n【回归规则】人物始终只有一份原档案；已领取套装随原档案回归，不复制背包。\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
