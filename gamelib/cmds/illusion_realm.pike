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
	mapping current = ([]);
	int current_number;
	s += "路线："+(string)progress["path_name"]+"　等级："+
		(string)(int)progress["level"]+"\n";
	s += "探索："+(string)(int)progress["visits"]+
		"处　击杀："+(string)(int)progress["kills"]+
		"　首领："+(string)(int)progress["boss_kills"]+
		"　同队击杀："+(string)(int)progress["team_kills"]+"\n";
	s += "故事历程："+(string)(int)progress["chapter_claimed"]+"/"+
		(string)(int)progress["chapter_total"]+"章　修行日："+
		(string)(int)progress["active_days"]+"/7　剧情印记："+
		(string)(int)progress["story_event_count"]+"\n";
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
		s += "【三途择印】第二十三章前选择一次，本期不可更改：\n";
		s += "[寻星·重探索:illusion_realm path pioneer] ";
		s += "[破阵·重狩猎:illusion_realm path hunter] ";
		s += "[同心·重协作:illusion_realm path companion]\n";
	}
	s += "论剑荣誉："+(string)(int)progress["pvp_honor"]+
		"　胜场："+(string)(int)progress["pvp_wins"]+"\n";
	if(arrayp(progress["ranking_titles"]) &&
	   sizeof((array)progress["ranking_titles"]))
		s += "最新幻境荣誉："+
			(string)((array)progress["ranking_titles"])[-1]+"\n";
	foreach((array)progress["chapters"];int index;mapping chapter)
		if(!(int)chapter["claimed"]){
			current = chapter;
			current_number = index+1;
			break;
		}
	if(sizeof(current)){
		string mark = (int)current["ready"] ? "可完成" : "进行中";
		s += "\n"+(string)current["volume_title"]+"\n";
		s += "【第"+(string)current_number+"章·"+
			(string)current["title"]+"】"+mark+"\n";
		s += "[storyimg "+(string)(int)current["image_cell"]+":"+
			(string)current["atlas"]+"]\n";
		s += (string)current["intro"]+"\n";
		s += "目标：修行"+(string)(int)progress["active_days"]+"/"+
			(string)(int)current["active_days"]+"日 / Lv"+
			(string)(int)progress["level"]+"/"+
			(string)(int)current["min_level"]+" / 击杀"+
			(string)(int)progress["kills"]+"/"+
			(string)(int)current["kills"]+" / 首领"+
			(string)(int)progress["boss_kills"]+"/"+
			(string)(int)current["boss_kills"]+" / 探索"+
			(string)(int)progress["visits"]+"/"+
			(string)(int)current["visits"];
		if((string)current["story_event"]!="" &&
		   !(int)current["story_ready"]){
			s += " / 关键剧情【"+
				(string)current["story_event_title"]+"】（地点："+
				(string)current["story_event_location"]+"）尚未触发";
			if((string)current["story_event_kind"]=="echo")
				s += "（到剧情地点阅读残响）";
			else if((string)current["story_event_kind"]=="boss")
				s += "（击败本章剧情首领）";
		}
		s += "\n";
		if((int)current["reward_count"]>0)
			s += "本章过关额外获得本职业新月套装"+
				(string)(int)current["reward_count"]+"件。\n";
		if((int)current["ready"])
			s += "[完成本章并阅读回响:illusion_realm claim "+
				(string)current_number+"]\n";
	}
	else
		s += "\n八十一章已经全部完成；完整故事与十件套装均已写入本人物原档案。\n";
	s += "[查看九卷故事目录:illusion_realm story]\n";
	return s;
}

private string story_volume_view(mapping progress,int volume_number)
{
	string s;
	int start;
	array chapters = (array)progress["chapters"];
	if(volume_number<1 || volume_number>9)
		return "故事卷号无效。\n[返回故事目录:illusion_realm story]\n";
	start = (volume_number-1)*9;
	s = "【"+(string)chapters[start]["volume_title"]+"】\n";
	for(int offset=0;offset<9;offset++){
		mapping chapter = chapters[start+offset];
		int chapter_number = start+offset+1;
		string mark = (int)chapter["claimed"] ? "已完成" :
			((int)chapter["ready"] ? "可完成" :
			 (chapter_number==(int)progress["chapter_claimed"]+1 ?
			  "进行中" : "未开启"));
		s += "[第"+(string)chapter_number+"章·"+
			(string)chapter["title"]+":illusion_realm story chapter "+
			(string)chapter_number+"]　"+mark+"\n";
	}
	s += "[上一卷:illusion_realm story volume "+
		(string)max(1,volume_number-1)+"]|[下一卷:illusion_realm story volume "+
		(string)min(9,volume_number+1)+"]\n";
	s += "[返回故事目录:illusion_realm story]\n";
	return s;
}

private string story_chapter_view(mapping progress,int chapter_number)
{
	array chapters = (array)progress["chapters"];
	mapping chapter;
	string s;
	int available = (int)progress["chapter_claimed"]+1;
	if(chapter_number<1 || chapter_number>sizeof(chapters))
		return "故事章号无效。\n[返回故事目录:illusion_realm story]\n";
	chapter = chapters[chapter_number-1];
	if(chapter_number>available)
		return "后续故事尚未开启，请先完成第"+(string)available+
			"章。\n[返回当前历程:illusion_realm]\n";
	s = (string)chapter["volume_title"]+"\n";
	s += "【第"+(string)chapter_number+"章·"+
		(string)chapter["title"]+"】\n";
	s += "[storyimg "+(string)(int)chapter["image_cell"]+":"+
		(string)chapter["atlas"]+"]\n";
	s += (string)chapter["intro"]+"\n";
	if((int)chapter["claimed"])
		s += "\n【过关回响】\n"+(string)chapter["outro"]+"\n";
	else{
		s += "\n目标：修行"+(string)(int)progress["active_days"]+"/"+
			(string)(int)chapter["active_days"]+"日 / Lv"+
			(string)(int)progress["level"]+"/"+
			(string)(int)chapter["min_level"]+" / 击杀"+
			(string)(int)progress["kills"]+"/"+
			(string)(int)chapter["kills"]+" / 首领"+
			(string)(int)progress["boss_kills"]+"/"+
			(string)(int)chapter["boss_kills"]+" / 探索"+
			(string)(int)progress["visits"]+"/"+
			(string)(int)chapter["visits"]+"\n";
		if((string)chapter["story_event"]!="" &&
		   !(int)chapter["story_ready"])
			s += "关键剧情：【"+
				(string)chapter["story_event_title"]+"】（地点："+
				(string)chapter["story_event_location"]+"）"+
				((string)chapter["story_event_kind"]=="boss" ?
				 "，请击败本章剧情首领。\n" :
				 "，请到剧情地点阅读残响。\n");
		if((int)chapter["ready"])
			s += "[完成本章并阅读回响:illusion_realm claim "+
				(string)chapter_number+"]\n";
	}
	s += "[返回本卷:illusion_realm story volume "+
		(string)(int)chapter["volume_number"]+"]|[返回当前历程:illusion_realm]\n";
	return s;
}

private string story_index_view(mapping progress)
{
	string s = "【"+(string)progress["story_title"]+"·九卷八十一章】\n";
	array chapters = (array)progress["chapters"];
	s += (string)progress["story_premise"]+"\n";
	for(int volume=1;volume<=9;volume++){
		int completed;
		int start = (volume-1)*9;
		for(int offset=0;offset<9;offset++)
			if((int)chapters[start+offset]["claimed"])
				completed++;
		s += "["+(string)chapters[start]["volume_title"]+
			":illusion_realm story volume "+(string)volume+"] "+
			(string)completed+"/9\n";
	}
	s += "\n最快也需七个不同北京时间修行日；章节必须按顺序完成，不能跳章。\n";
	s += "[返回当前历程:illusion_realm]\n";
	return s;
}

private string ranking_menu(mapping status)
{
	int starts_at = (int)status["starts_at"];
	int current_week = starts_at>0 ?
		min(60,max(1,1+(time()-starts_at)/(7*86400))) : 1;
	string period = "week:"+(string)current_week;
	string s = "【"+(string)status["illusion_id"]+"幻境排行榜】\n";
	array(mapping(string:string)) boards = ({
		(["id":"journey","name":"征途"]),(["id":"level","name":"境界"]),
		(["id":"experience","name":"经验"]),(["id":"pk","name":"论剑"]),
		(["id":"set","name":"套装"]),(["id":"speed","name":"极速"]),
	});
	foreach(boards,mapping board){
		s += "["+(string)board["name"]+"总榜:illusion_realm rank "+
			(string)board["id"]+" overall] ";
		s += "[本周:illusion_realm rank "+(string)board["id"]+" "+
			period+"]\n";
	}
	s += "\n周榜结束后前十可领取荣誉称号；总榜在本期结束后结算。\n";
	s += "同注册账号切磋不计分；同一对手每日仅前三次按100/50/20递减；等级碾压不计分。\n";
	s += "称号仅用于展示收藏，不增加永久战斗属性。\n";
	s += "[返回幻境区:illusion_realm]\n";
	return s;
}

private string ranking_view(mapping status,string board,string period)
{
	mapping result = SEASONALD->query_illusion_leaderboard(
		(string)status["illusion_id"],board,period,20);
	string s;
	if(!(int)result["ok"])
		return (string)result["message"]+"\n[返回排行榜:illusion_realm rank]\n";
	s = "【"+(string)result["board_name"]+"·"+
		(period=="overall" ? "总榜" : "第"+period[5..]+"周")+"】\n";
	if(!sizeof((array)result["rows"]))
		s += "尚无符合条件的榜单记录。\n";
	foreach((array)result["rows"],mapping row)
		s += (string)(int)row["rank"]+". "+(string)row["name_cn"]+
			"（"+(string)row["profession_name"]+"） "+
			(string)row["score_text"]+"\n";
	s += "\n[领取本榜前十荣誉:illusion_realm rank claim "+board+" "+
		period+"]\n[返回排行榜:illusion_realm rank]\n";
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
	if(sizeof(parts)>=1 && parts[0]=="rank"){
		if(sizeof(parts)>=4 && parts[1]=="claim"){
			mapping reward = SEASONALD->claim_illusion_ranking_reward(
				me,parts[2],parts[3]);
			write((string)reward["message"]+
				"\n[返回排行榜:illusion_realm rank]\n");
			return 1;
		}
		if(sizeof(parts)>=2){
			string period = sizeof(parts)>=3 ? parts[2] : "overall";
			write(ranking_view(status,parts[1],period));
			return 1;
		}
		write(ranking_menu(status));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="story"){
		mapping progress = SEASONALD->query_player_progress(me);
		if(!(int)progress["ok"]){
			write((string)progress["message"]+"\n[返回游戏:look]\n");
			return 1;
		}
		if(sizeof(parts)>=3 && parts[1]=="chapter")
			write(story_chapter_view(progress,(int)parts[2]));
		else if(sizeof(parts)>=3 && parts[1]=="volume")
			write(story_volume_view(progress,(int)parts[2]));
		else
			write(story_index_view(progress));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="activate"){
		if(sizeof(parts)<2 || parts[1]!="confirm"){
			write(((int)status["entitlement_cost_suiyu"]>0 ?
				"永久解锁"+(string)status["illusion_id"]+"人物资格需要"+
				(string)(int)status["entitlement_cost_suiyu"]+"枚碎玉。" :
				(string)status["illusion_id"]+"人物资格当前免费永久激活。")+
				"资格属于注册账号且仅限本赛季；本期首名人物免费，额外栏位仅对本期生效。\n"+
				"[确认永久激活:illusion_realm activate confirm]\n"+
				"[取消:illusion_realm]\n");
			return 1;
		}
		// HTTP commands are serialized by their account runtime mutex; legacy
		// socket commands run on the main event thread. The daemon's entitlement
		// index write is atomic and resolves cross-character purchase races.
		mapping result = SEASONALD->purchase_entitlement(me);
		write((string)result["message"]+"\n[返回幻境区:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="expand"){
		mapping expansion_account = ACCOUNT_CHARACTERD->
			query_account_characters((string)me->query_account_owner(),
				(string)status["illusion_id"]);
		int spent = (int)expansion_account[
			"illusion_expansion_spent_suiyu"];
		int slots = (int)(expansion_account["illusion_character_slots"] || 1);
		int remaining = max(0,500-spent);
		if(!(int)expansion_account["ok"]){
			write("账号栏位状态暂不可验证，本次不会扣除碎玉。\n"+
				"[返回幻境区:illusion_realm]\n");
			return 1;
		}
		if(!(int)expansion_account["illusion_entitled"]){
			write("请先免费激活"+(string)status["illusion_id"]+
				"人物资格。\n"+
				"[免费激活:illusion_realm activate]|"+
				"[返回幻境区:illusion_realm]\n");
			return 1;
		}
		if((int)expansion_account["illusion_multi_character_unlocked"]){
			write("本期已解锁幻境多人物；只受账号总计30个人物与隐藏职业数量限制。\n"+
				"[返回幻境区:illusion_realm]\n");
			return 1;
		}
		if(sizeof(parts)<2 || search(({"one","all"}),parts[1])==-1){
			write("【幻境人物栏位】\n当前赛季栏位："+(string)slots+
				"个　累计已计入："+(string)spent+"碎玉\n"+
				"[100碎玉增加本期1格:illusion_realm expand one]|"+
				"[补"+(string)remaining+
				"碎玉解锁本期多人物:illusion_realm expand all]\n"+
				"也可补足本期累计500碎玉解锁多人物；本期此前逐格扩充的花费全额抵扣。\n"+
				"[返回幻境区:illusion_realm]\n");
			return 1;
		}
		string option = parts[1];
		int cost = option=="one" ? 100 : remaining;
		if(sizeof(parts)<3 || parts[2]!="confirm"){
			write((option=="one" ?
				"确认支付100碎玉，增加1个本期幻境人物栏位？" :
				"确认补足"+(string)cost+
				"碎玉，解锁本期幻境多人物？")+"\n"+
				"[确认支付:illusion_realm expand "+option+" confirm]|"+
				"[取消:illusion_realm expand]\n");
			return 1;
		}
		mapping expansion = SEASONALD->purchase_character_expansion(me,option);
		write((string)expansion["message"]+
			"\n[查看栏位:illusion_realm expand]|"+
			"[返回幻境区:illusion_realm]\n");
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
	if(sizeof(parts)>=1 && parts[0]=="witness"){
		mapping result = SEASONALD->discover_story_event(me);
		write((string)result["message"]+"\n[返回"+
			(string)status["illusion_id"]+"历程:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="return"){
		write("幻境到期后由系统自动安全回归，无需重复点击；保存失败会自动重试。\n"+
			"[返回幻境区:illusion_realm]\n");
		return 1;
	}
	s += "【"+(string)status["display_name"]+"】\n";
	s += "阶段："+(string)status["phase_name"]+"\n";
	s += "开始："+time_text((int)status["starts_at"])+"\n";
	s += "回归结算："+time_text((int)status["ends_at"])+"\n";
	if(!(int)status["ok"])
		s += "配置或运行状态校验失败，功能已安全关闭。\n";
	account_data = ACCOUNT_CHARACTERD->query_account_characters(
		(string)me->query_account_owner(),(string)status["illusion_id"]);
	if((int)account_data["illusion_entitled"]){
		s += (string)status["illusion_id"]+"永久人物资格：已解锁\n";
		if((int)account_data["illusion_multi_character_unlocked"])
			s += "人物栏位：本期已解锁多人物（账号总上限30）\n";
		else
			s += "人物栏位：本期"+
				(string)(int)(account_data["illusion_character_slots"] || 1)+
				"格　累计"+
				(string)(int)account_data["illusion_expansion_spent_suiyu"]+
				"/500碎玉　[选择扩充方式:illusion_realm expand]\n";
	}
	else if((int)status["entitlement_open"])
		s += (string)status["illusion_id"]+
			"永久人物资格：未解锁　[免费激活:illusion_realm activate]\n";
	else
		s += (string)status["illusion_id"]+
			"永久人物资格：当前未开放激活\n";
	if(SEASONALD->is_active_illusion_character(me)){
		mapping progress = SEASONALD->query_player_progress(me);
		if((int)progress["ok"])
			s += "\n"+progress_view(me,progress);
		if((string)status["phase"]=="settling" ||
		   (string)status["phase"]=="closed")
			s += "\n系统正在自动安全回归；保存失败会自动重试。\n";
	}
	else if((int)status["creation_open"] &&
	   (int)account_data["illusion_entitled"])
		s += "请回到账号人物中心，选择“"+
			(string)status["display_name"]+"”创建本期人物。\n";
	s += "\n【回归规则】人物始终只有一份原档案；已领取套装随原档案回归，不复制背包。\n";
	s += "【家园规则】幻境人物本期不开放家园；回归永恒服后恢复普通家园玩法。\n";
	s += "[幻境排行榜:illusion_realm rank]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
