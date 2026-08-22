#include <command.h>
#include <gamelib/include/gamelib.h>

private string format_time(int seconds)
{
	int hours=max(0,seconds)/3600;
	int minutes=(max(0,seconds)%3600)/60;
	return hours+"小时"+minutes+"分钟";
}

private string tier_label(int level,mapping tier)
{
	string name=(string)tier["name"];
	if(level>=7)
		return "§6"+name+"§r";
	if(level>=6)
		return "§m"+name+"§r";
	if(level>=4)
		return "§b"+name+"§r";
	if(level>=2)
		return "§g"+name+"§r";
	return name;
}

private void show_status(object player,string notice)
{
	mapping status=PERSONAL_DIFFICULTYD->query_status(player);
	mapping current=status["current"];
	mapping progress=status["progress"];
	array(mapping(string:mixed)) catalog=PERSONAL_DIFFICULTYD->query_catalog();
	string out="【个人挑战难度】\n";
	if(notice && notice!="")
		out+=notice+"\n\n";
	out+="进度归属："+(string)status["scope_name"]+"（与其他世界独立）\n";
	out+="当前："+tier_label((int)status["current_level"],current)+
		"；已解锁至："+
		tier_label((int)status["unlocked_level"],
			catalog[(int)status["unlocked_level"]])+"\n";
	out+="规则：所有难度仍在同一地图、同一房间和同一Worker相遇；只调整你本人对NPC的攻防风险、个人掉落和挂机额度，PVP不变。\n";
	out+="PVE伤害：造成"+(int)current["outgoing_percent"]+"％；承受"+
		(int)current["incoming_percent"]+"％；打怪经验"+
		(int)current["exp_percent"]+"％；套装稀有池"+
		(int)current["set_drop_percent"]+"％；稀有掉率"+
		(int)current["rare_drop_percent"]+"％。\n";
	out+="当前VIP难度挂机额度："+
		format_time(AUTOFIGHTD->query_daily_seconds_for(player))+"；今日剩余："+
		format_time(AUTOFIGHTD->query_time_left(player))+"。\n\n";
	if(!(int)progress["maxed"]){
		if((string)progress["mode"]=="season_mastery")
			out+="下一破界试炼【"+(string)progress["next_name"]+
				"】：必须在当前最高【"+(string)progress["mastery_name"]+
				"】难度亲自完成新章回 "+
				(int)progress["mastery_chapters"]+"/"+
				(int)progress["mastery_required"]+
				"（本期总进度 "+(int)progress["chapters"]+"/81）。\n";
		else
			out+="下一破界试炼【"+(string)progress["next_name"]+"】：等级 "+
				(int)progress["level"]+"/"+(int)progress["min_level"]+
				"，合格击杀 "+format_game_number((int)progress["kills"])+
				"/"+format_game_number((int)progress["kills_required"])+
				"，首领 "+format_game_number((int)progress["bosses"])+
				"/"+format_game_number((int)progress["bosses_required"])+"。\n";
		if((int)progress["complete"])
			out+="[完成破界并永久解锁:personal_difficulty unlock]\n";
	}
	else
		out+="你已完成全部七重破界试炼。\n";
	out+="\n切换难度（只能在主城/幻境入口、脱战且停止挂机后操作）：\n";
	for(int level=0;level<sizeof(catalog);level++){
		mapping tier=catalog[level];
		// 按钮文本不加色码，防止 § 字符干扰部分客户端的链接解析。
		string label=(string)tier["name"];
		string prefix=level==(int)status["current_level"] ? "✓ " : "";
		if(level<=(int)status["unlocked_level"])
			out+=prefix+"["+label+"：经验"+
				(int)tier["exp_percent"]+"％ 稀有"+
				(int)tier["rare_drop_percent"]+"％ 挂机上限"+
				(int)tier["afk_cap_hours"]+"小时:personal_difficulty switch "+
				level+"]\n";
		else
			out+=tier_label(level,tier)+"（LV"+
				(int)tier["min_level"]+"解锁）\n";
	}
	out+="\n[挂机设置:autofight open]|[返回设置:game_detail]|[返回游戏:look]\n";
	write(out);
}

int main(string|zero arg)
{
	object player=this_player();
	array(string) parts;
	if(!player)
		return 0;
	if(!arg || arg=="" || arg=="open"){
		show_status(player,"");
		return 1;
	}
	parts=arg/" ";
	if(parts[0]=="unlock"){
		mapping result=PERSONAL_DIFFICULTYD->claim_next_tier(player);
		show_status(player,(string)result["message"]);
		return 1;
	}
	if(sizeof(parts)==2 && parts[0]=="switch"){
		int target=(int)parts[1];
		if(parts[1]!=(string)target){
			show_status(player,"无效的难度编号，设置没有改变。");
			return 1;
		}
		mapping result=PERSONAL_DIFFICULTYD->switch_tier(player,target);
		if((int)result["ok"] && !(int)result["already"])
			AUTOFIGHTD->sync_daily_limit(player);
		show_status(player,(string)result["message"]);
		return 1;
	}
	show_status(player,"无效的难度操作，设置没有改变。");
	return 1;
}
