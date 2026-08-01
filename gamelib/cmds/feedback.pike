#include <command.h>
#include <gamelib/include/gamelib.h>

string feedback_status_line(mapping(string:mixed) one)
{
	string line = FEEDBACKD->feedback_id_desc((int)one["id"])+" "+
		FEEDBACKD->feedback_status_desc((string)one["status"]);
	if(one["status"]=="adopted"){
		line += "，奖励"+(int)one["reward_amount"]+"碎玉";
		if(one["reward_status"]=="delivered")
			line += "（已发放）";
		else
			line += "（待发放）";
	}
	return line;
}

int main(string|zero arg)
{
	object me = this_player();
	string s = "====意见反馈====\n";
	string content = "";
	mapping(string:mixed) delivery;
	if(!me){
		write("玩家状态无效。\n");
		return 1;
	}
	delivery = FEEDBACKD->deliver_pending_rewards(me);
	if((int)delivery["amount"]>0)
		s += "已补发采纳奖励："+(int)delivery["amount"]+"碎玉。\n";

	if(arg && sscanf(arg,"submit %s",content)==1){
		mapping(string:mixed) result = FEEDBACKD->submit_feedback(me,content);
		s += result["message"]+"\n";
		if(result["ok"]){
			s += "反馈编号："+
				FEEDBACKD->feedback_id_desc((int)result["id"])+"\n";
			s += "若意见被采纳，系统会自动发放"+
				FEEDBACKD->query_reward_amount()+"碎玉。\n";
		}
	}
	else if(arg=="input"){
		s += "请写下具体问题、触发步骤或改进建议（4至300字）：\n";
		s += "[string:feedback submit ...]\n";
		s += "为便于定位，建议写明职业、等级、地图和操作过程。\n";
	}
	else if(arg && arg!="status")
		s += "参数错误，请返回重试。\n";

	array(mapping(string:mixed)) records =
		FEEDBACKD->query_player_feedback(me,5);
	if(sizeof(records)){
		s += "\n最近反馈：\n";
		foreach(records,mapping(string:mixed) one){
			s += feedback_status_line(one)+"\n";
			s += "  "+one["content"]+"\n";
		}
	}
	else
		s += "\n你还没有提交过意见。\n";
	s += "\n[提交新意见:feedback input]\n";
	s += "[刷新审核状态:feedback status]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
