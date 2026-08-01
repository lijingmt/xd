#include <command.h>
#include <gamelib/include/gamelib.h>

#define PAGE_SIZE 8

void discard_offline_feedback_player(object player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		item->remove();
	destruct(player);
}

string reward_status_desc(mapping(string:mixed) one)
{
	if(one["status"]!="adopted")
		return "无奖励";
	if(one["reward_status"]=="delivered")
		return (int)one["reward_amount"]+"碎玉（已发放）";
	return (int)one["reward_amount"]+"碎玉（待发放）";
}

mapping(string:mixed) adopt_and_reward(object operator,int id)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"采纳失败。",
		"delivered":0,
		"pending":0,
		"already":0,
	]);
	mapping(string:mixed) review;
	mapping(string:mixed) record;
	mapping(string:mixed) delivery;
	object player;
	int offline = 0;

	if(!operator || MANAGERD->checkpower(operator->query_name())!="admin"){
		result["message"] = "需要管理员权限。";
		return result;
	}
	review = FEEDBACKD->review_feedback(operator,id,"adopt");
	record = FEEDBACKD->query_admin_feedback_detail(operator,id);
	if(!review["ok"] && !review["already"]){
		result["message"] = review["message"];
		return result;
	}
	if(!sizeof(record) || record["status"]!="adopted"){
		result["message"] = review["message"];
		return result;
	}
	player = find_player((string)record["user_id"]);
	if(!player){
		player = operator->load_player((string)record["user_id"]);
		offline = 1;
	}
	if(!player){
		result["ok"] = 1;
		result["pending"] = 1;
		result["already"] = (int)review["already"];
		result["message"] = "意见已采纳；玩家档案暂时无法载入，奖励将在登录时补发。";
		return result;
	}
	delivery = FEEDBACKD->deliver_pending_rewards(player);
	result["ok"] = 1;
	result["already"] = (int)review["already"];
	result["delivered"] = (int)delivery["delivered"];
	result["pending"] = (int)delivery["failed"];
	if((int)delivery["delivered"]>0)
		result["message"] = "意见已采纳，"+(int)delivery["amount"]+
			"碎玉已发放并写入玩家档案。";
	else if((int)delivery["failed"]>0)
		result["message"] = "意见已采纳，奖励暂未写入，将在玩家登录时自动补发。";
	else
		result["message"] = "该意见已经采纳，奖励此前已发放，没有重复奖励。";
	if(offline)
		discard_offline_feedback_player(player);
	return result;
}

mapping(string:mixed) reject_feedback(object operator,int id)
{
	if(!operator || MANAGERD->checkpower(operator->query_name())!="admin")
		return (["ok":0,"message":"需要管理员权限。"]) ;
	return FEEDBACKD->review_feedback(operator,id,"reject");
}

string detail_page(object me,int id)
{
	mapping(string:mixed) one =
		FEEDBACKD->query_admin_feedback_detail(me,id);
	string s = "====意见反馈详情====\n";
	if(!sizeof(one))
		return s+"意见编号不存在。\n";
	s += "编号："+FEEDBACKD->feedback_id_desc(id)+"\n";
	s += "玩家："+one["user_name"]+"（"+one["user_id"]+"）\n";
	s += "时间："+FEEDBACKD->feedback_time_desc(
		(int)one["submitted_at"])+"\n";
	s += "状态："+FEEDBACKD->feedback_status_desc(
		(string)one["status"])+"\n";
	s += "内容：\n"+one["content"]+"\n";
	if(one["status"]!="pending"){
		s += "审核人："+one["reviewed_by"]+"\n";
		s += "审核时间："+FEEDBACKD->feedback_time_desc(
			(int)one["reviewed_at"])+"\n";
	}
	s += "奖励："+reward_status_desc(one)+"\n";
	if(one["status"]=="pending"){
		s += "\n[确认采纳:mgr_feedback adopt "+id+"]\n";
		s += "[标记未采纳:mgr_feedback reject "+id+"]\n";
	}
	else if(one["status"]=="adopted" &&
		one["reward_status"]!="delivered")
		s += "\n[重试发放奖励:mgr_feedback adopt "+id+" confirm]\n";
	return s;
}

string list_page(object me,string status,int page)
{
	array(mapping(string:mixed)) records;
	int count;
	int total_pages;
	string s = "====意见反馈管理====\n";
	if(status!="pending" && status!="adopted" &&
	   status!="rejected" && status!="all")
		status = "pending";
	if(page<1)
		page = 1;
	count = FEEDBACKD->query_admin_feedback_count(me,status);
	total_pages = count ? (count+PAGE_SIZE-1)/PAGE_SIZE : 1;
	if(page>total_pages)
		page = total_pages;
	records = FEEDBACKD->query_admin_feedback(me,status,page,PAGE_SIZE);
	s += "[待审核:mgr_feedback list pending 1]|";
	s += "[已采纳:mgr_feedback list adopted 1]|";
	s += "[未采纳:mgr_feedback list rejected 1]|";
	s += "[全部:mgr_feedback list all 1]\n";
	s += "共"+count+"条，第"+page+"/"+total_pages+"页。\n\n";
	if(!sizeof(records))
		s += "当前没有符合条件的反馈。\n";
	foreach(records,mapping(string:mixed) one){
		s += "["+FEEDBACKD->feedback_id_desc((int)one["id"])+
			":mgr_feedback view "+(int)one["id"]+"] ";
		s += FEEDBACKD->feedback_status_desc((string)one["status"])+" ";
		s += one["user_name"]+"（"+one["user_id"]+"）\n";
		s += "  "+one["content"]+"\n";
	}
	if(page>1)
		s += "[上一页:mgr_feedback list "+status+" "+(page-1)+"] ";
	if(page<total_pages)
		s += "[下一页:mgr_feedback list "+status+" "+(page+1)+"]";
	if(page>1 || page<total_pages)
		s += "\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	string status = "";
	string confirm = "";
	int id = 0;
	int page = 1;

	if(!me || MANAGERD->checkpower(me->query_name())!="admin"){
		write("需要管理员权限才可以查看或审核玩家反馈。\n[返回游戏:look]\n");
		return 1;
	}
	if(!arg || arg=="")
		s = list_page(me,"pending",1);
	else if(sscanf(arg,"list %s %d",status,page)==2)
		s = list_page(me,status,page);
	else if(sscanf(arg,"view %d",id)==1)
		s = detail_page(me,id);
	else if(sscanf(arg,"adopt %d %s",id,confirm)==2 &&
		confirm=="confirm"){
		mapping(string:mixed) result = adopt_and_reward(me,id);
		s = "====采纳意见====\n"+result["message"]+"\n";
		s += detail_page(me,id);
	}
	else if(sscanf(arg,"reject %d %s",id,confirm)==2 &&
		confirm=="confirm"){
		mapping(string:mixed) result = reject_feedback(me,id);
		s = "====反馈审核====\n"+result["message"]+"\n";
		s += detail_page(me,id);
	}
	else if(sscanf(arg,"adopt %d",id)==1){
		s = detail_page(me,id);
		s += "\n采纳后将固定奖励玩家"+
			FEEDBACKD->query_reward_amount()+"碎玉。\n";
		s += "[最终确认采纳:mgr_feedback adopt "+id+" confirm]\n";
	}
	else if(sscanf(arg,"reject %d",id)==1){
		s = detail_page(me,id);
		s += "\n未采纳不会发放奖励。\n";
		s += "[最终确认未采纳:mgr_feedback reject "+id+" confirm]\n";
	}
	else
		s = "参数错误。\n";
	s += "[返回待审核列表:mgr_feedback]\n";
	s += "[返回管理主界面:game_deal]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
