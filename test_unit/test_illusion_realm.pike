#!/usr/bin/env pike
/** 新月幻境·S1资格、隔离、任务奖励与原档案回归回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player(string userid)
{
	if(!userid || search(userid,"testunitillusion")==-1)
		return;
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

void cleanup_ranking_snapshot(string userid)
{
	if(!userid || search(userid,"testunitillusion")==-1)
		return;
	string path = DATA_ROOT+"illusion_realm/rankings/S1/"+userid+".json";
	rm(path);
	foreach(get_dir(dirname(path)) || ({}),string filename)
		if(has_prefix(filename,userid+".json.") &&
		   has_suffix(filename,".tmp"))
			rm(dirname(path)+"/"+filename);
}

object create_root(string account_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(account_id);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "S1测试账号";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->save_with_result();
	return player;
}

int count_newmoon_items(object player)
{
	int count;
	foreach(all_inventory(player),object item)
		if(item && functionp(item->query_newmoon_collection_id) &&
		   (string)item->query_newmoon_collection_id()=="newmoon")
			count++;
	return count;
}

int all_newmoon_bound_to(object player,string account_id)
{
	int count;
	foreach(all_inventory(player),object item){
		if(!item || !functionp(item->query_newmoon_collection_id) ||
		   (string)item->query_newmoon_collection_id()!="newmoon")
			continue;
		count++;
		if(!functionp(item->query_newmoon_account_bind_owner) ||
		   (string)item->query_newmoon_account_bind_owner()!=account_id)
			return 0;
	}
	return count==10;
}

int bootstrap_character(object player,string race_id,string profession_id)
{
	object login_room = (object)(ROOT+"/gamelib/d/init");
	object|zero original_player = this_player();
	int result;
	mixed err = catch{
		set_this_player(player);
		result = login_room->choice_profe(race_id+"/"+profession_id);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	return !err && result &&
		(string)player->query_raceId()==race_id &&
		(string)player->query_profeId()==profession_id;
}

int main()
{
	string account_id = "xd99testunitillusion";
	string center_account_id = "xd98testunitillusioncenter";
	string child_id = "";
	string second_id = "";
	string third_id = "";
	string fourth_id = "";
	object|zero root = 0;
	object|zero center_root = 0;
	object|zero child = 0;
	object|zero restored = 0;
	array(string) cleanup_ids = ({account_id});
	werror("\n========== 新月幻境·S1测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(center_account_id);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(center_account_id);
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	cleanup_player(account_id);
	cleanup_player(center_account_id);
	mixed err = catch{
		mapping public_status = SEASONALD->query_public_status();
		check("首期稳定编号与展示名固定为S1",
			(string)public_status["illusion_id"]=="S1" &&
			(string)public_status["display_name"]=="新月幻境·S1" &&
			(int)public_status["duration_days"]==30 &&
			(int)public_status["entitlement_cost_suiyu"]==0 &&
			(int)public_status["extra_character_slot_cost_suiyu"]==100 &&
			(int)public_status["multi_character_unlock_cost_suiyu"]==500,
			sprintf("status=%O",public_status));
		string story_json_source = Stdio.read_file(ROOT+
			"/gamelib/etc/illusion_s1_story.json") || "";
		mapping story_config = Standards.JSON.decode(story_json_source);
		array story_volumes = (array)story_config["volumes"];
		array story_chapters = ({});
		multiset(string) story_titles = (<>);
		multiset(string) story_atlases = (<>);
		multiset(string) story_images = (<>);
		multiset(string) story_image_digests = (<>);
		multiset(string) story_intros = (<>);
		multiset(string) story_outros = (<>);
		int story_rewards;
		int story_text_valid = 1;
		int story_novel_structure_valid = 1;
		int story_chapter_number;
		int story_chapter_images_valid = 1;
		foreach(story_volumes,mapping volume){
			story_atlases[(string)volume["atlas"]] = 1;
			foreach((array)volume["chapters"],mapping chapter){
				string chapter_image;
				string chapter_source;
				object chapter_hash;
				story_chapter_number++;
				story_chapters += ({chapter});
				story_titles[(string)chapter["title"]] = 1;
				story_intros[(string)chapter["intro"]] = 1;
				story_outros[(string)chapter["outro"]] = 1;
				story_rewards += (int)chapter["reward_count"];
				array(string) intro_lines = (string)chapter["intro"]/"\n";
				array(string) outro_lines = (string)chapter["outro"]/"\n";
				if(sizeof((string)chapter["intro"])<20 ||
				   sizeof((string)chapter["outro"])<20 ||
				   (int)chapter["active_days"]<1 ||
				   (int)chapter["active_days"]>7)
					story_text_valid = 0;
				if(sizeof(intro_lines)!=5 || sizeof(outro_lines)!=3 ||
				   sizeof((string)chapter["intro"])<180 ||
				   sizeof((string)chapter["outro"])<96)
					story_novel_structure_valid = 0;
				foreach(intro_lines,string line)
					if(sizeof(String.trim_all_whites(line))<24)
						story_novel_structure_valid = 0;
				foreach(outro_lines,string line)
					if(sizeof(String.trim_all_whites(line))<24)
						story_novel_structure_valid = 0;
				chapter_image = sprintf(
					"/xd/images/illusion_s1/story/chapters/chapter_%03d.png",
					story_chapter_number);
				story_images[chapter_image] = 1;
				chapter_source = Stdio.read_file(ROOT+"/images/"+
					chapter_image[sizeof("/xd/images/")..]);
				if(!chapter_source || sizeof(chapter_source)<200000)
					story_chapter_images_valid = 0;
				else{
					chapter_hash = Crypto.SHA256();
					chapter_hash->update(chapter_source);
					story_image_digests[lower_case(String.string2hex(
						chapter_hash->digest()))] = 1;
				}
			}
		}
		int story_images_valid = sizeof(story_atlases)==9;
		foreach(indices(story_atlases),string atlas)
			if(!has_prefix(atlas,"/xd/images/illusion_s1/story/volume_") ||
			   !has_suffix(atlas,".png") ||
			   Stdio.file_size(ROOT+"/images/"+
				atlas[sizeof("/xd/images/")..])<1024*1024)
				story_images_valid = 0;
		check("原创长篇故事固定为九卷八十一章、活跃日元数据与十件奖励",
			(int)story_config["version"]==2 &&
			sizeof(story_volumes)==9 && sizeof(story_chapters)==81 &&
			sizeof(story_titles)==81 && story_rewards==10 &&
			story_text_valid && (int)story_chapters[-1]["active_days"]==7,
			sprintf("volumes=%d chapters=%d titles=%d rewards=%d",
				sizeof(story_volumes),sizeof(story_chapters),
				sizeof(story_titles),story_rewards));
		check("八十一章均为人工五段章前正文与三段过关回响且互不重复",
			story_novel_structure_valid && sizeof(story_intros)==81 &&
			sizeof(story_outros)==81 &&
			search(story_json_source,"【行旅推进】")==-1 &&
			search(story_json_source,"【本章悬念】")==-1,
			sprintf("structure=%d intros=%d outros=%d",
				story_novel_structure_valid,sizeof(story_intros),
				sizeof(story_outros)));
		array story_quiz = (array)story_config["quiz"];
		int story_quiz_valid = sizeof(story_quiz)==10;
		foreach(story_quiz;int quiz_index;mapping question){
			multiset(string) options = (<>);
			if((string)question["id"]!="S1-Q"+(string)(quiz_index+1) ||
			   !arrayp(question["options"]) ||
			   sizeof((array)question["options"])!=4 ||
			   (int)question["answer"]<1 || (int)question["answer"]>4 ||
			   sizeof((string)question["question"])<12 ||
			   sizeof((string)question["explanation"])<12)
				story_quiz_valid = 0;
			foreach((array)question["options"],string option)
				options[option] = 1;
			if(sizeof(options)!=4)
				story_quiz_valid = 0;
		}
		check("终章十问题库、四项选择、答案与满分后记配置完整",
			story_quiz_valid &&
			sizeof((string)story_config["quiz_intro"]/"\n")==3 &&
			sizeof((string)story_config["quiz_epilogue"] / "\n")==5 &&
			SEASONALD->query_story_quiz_title_for_test(0)=="初闻长生" &&
			SEASONALD->query_story_quiz_title_for_test(5)=="记得来路" &&
			SEASONALD->query_story_quiz_title_for_test(7)=="四洲知卷" &&
			SEASONALD->query_story_quiz_title_for_test(9)=="月下解卷" &&
			SEASONALD->query_story_quiz_title_for_test(10)=="人间见证者",
			sprintf("quiz=%d valid=%d",sizeof(story_quiz),story_quiz_valid));
		check("九卷原创3x3故事图集完整且每卷不是占位小图",
			story_images_valid,sprintf("atlases=%O",story_atlases));
		check("八十一章各有唯一且非占位的独立AI剧情插画",
			story_chapter_images_valid && sizeof(story_images)==81 &&
			sizeof(story_image_digests)==81,
			sprintf("images=%d digests=%d valid=%d",sizeof(story_images),
				sizeof(story_image_digests),story_chapter_images_valid));
		check("故事配置未写入现有游戏动漫小说品牌名",
			search(story_json_source,"暗黑")==-1 &&
			search(story_json_source,"暴雪")==-1 &&
			search(story_json_source,"金庸")==-1 &&
			search(story_json_source,"西游记")==-1 &&
			search(story_json_source,"火影")==-1 &&
			search(story_json_source,"海贼")==-1 &&
			search(story_json_source,"原神")==-1 &&
			search(story_json_source,"大反派")==-1,
			"原创故事中出现了需要重新审核的现有品牌或作品名");
		string character_center_source = Stdio.read_file(ROOT+
			"/vue_source/index.html") || "";
		string observatory_source = Stdio.read_file(ROOT+
			"/gamelib/d/illusion_s1/broken_observatory.pike") || "";
		check("人物中心和地图引导均使用八十一章正式进度",
			search(character_center_source,"八十一章主线可获十件新月套装")!=-1 &&
			search(character_center_source,"赛季结束时原档案自动回归永恒服")!=-1 &&
			search(character_center_source,"完成七章")==-1 &&
			search(observatory_source,"第二十三章前必须作出选择")!=-1 &&
			search(observatory_source,"第三章前必须作出选择")==-1,
			"旧七章或第三章提示仍会误导玩家");
		mapping lifecycle_state = ([
			"phase":"active","starts_at":1000,"ends_at":2000,
		]);
		check("只有到期的进行中赛季会自动结算并自动关闭",
			SEASONALD->query_automatic_action_for_test(
				lifecycle_state,1999)=="" &&
			SEASONALD->query_automatic_action_for_test(
				lifecycle_state,2000)=="auto_settle" &&
			SEASONALD->query_automatic_action_for_test(
				(["phase":"settling"]),2000)=="auto_close" &&
			SEASONALD->query_automatic_action_for_test(
				(["phase":"closed"]),2000)=="" &&
			SEASONALD->query_automatic_action_for_test(
				(["phase":"registration","starts_at":1000,
					"ends_at":2000]),2000)=="",
			"自动开启或关闭后自动续期没有保持禁用");
		check("管理员可缩短或延长当前结束时间但不能改到开始之前",
			SEASONALD->query_end_time_valid_for_test(
				lifecycle_state,"active",1500)==1 &&
			SEASONALD->query_end_time_valid_for_test(
				lifecycle_state,"active",1000)==0 &&
			SEASONALD->query_end_time_valid_for_test(
				lifecycle_state,"closed",1500)==0 &&
			SEASONALD->query_end_time_valid_for_test(
				lifecycle_state,"active",1000+367*86400)==0,
			"结束时间边界校验错误");
		string login_source = Stdio.read_file(ROOT+
			"/lowlib/system/inherit/user.pike") || "";
		string entrance_source = Stdio.read_file(ROOT+
			"/gamelib/d/init") || "";
		int season_login_pos = search(login_source,
			"seasonal_chard->reconcile_player_login");
		int storage_login_pos = search(login_source,
			"account_storaged->reconcile_player_login");
		check("登录先完成赛季回归再恢复永久服共享资产",
			season_login_pos!=-1 && storage_login_pos!=-1 &&
			season_login_pos<storage_login_pos,
			sprintf("season=%d storage=%d",season_login_pos,
				storage_login_pos));
		string season_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/seasonal_chard.pike") || "";
		string player_command_source = Stdio.read_file(ROOT+
			"/gamelib/cmds/illusion_realm.pike") || "";
		string travel_command_source = Stdio.read_file(ROOT+
			"/gamelib/cmds/qge74hye.pike") || "";
		string account_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/account_characterd.pike") || "";
		string command_hook_source = Stdio.read_file(ROOT+
			"/lowlib/system/inherit/feature/cmds.pike") || "";
		check("在线自动结算获取账号锁且登录路径复用已持有锁",
			search(season_source,
				"query_account_runtime_mutex(\n\t\t(string)player->query_name())->lock()")!=-1 &&
			search(season_source,"settle_player_locked(player)")!=-1 &&
			search(login_source,
				"reconcile_player_login(this_object(),1)")!=-1,
			"结算可能与共享仓库写并发，或登录路径重复获取非递归账号锁");
		check("登录启动命令不再重复执行赛季对账",
			search(entrance_source,
				"SEASONALD->reconcile_player_login")==-1 &&
			search(login_source,
				"seasonal_chard->\n\t\t\t\treconcile_player_login(this_object())")==-1,
			"setup已在账号锁内对账，start或setup仍存在第二次无标记调用");
		check("玩家回归入口只提示自动流程且不会重复获取账号锁",
			search(player_command_source,"SEASONALD->settle_player(me)")==-1 &&
			search(player_command_source,"系统自动安全回归")!=-1,
			"HTTP命令已持有账号锁时手工回归可能触发递归锁异常");
		check("八十一章统一使用傻瓜式下一步、直达打怪和战后进度提示",
			search(player_command_source,"parts[0]==\"next\"")!=-1 &&
			search(player_command_source,
				"▶ 下一步：开始自动打怪:autofight start")!=-1 &&
			search(player_command_source,"chapter_next_link(chapter)")!=-1 &&
			search(player_command_source,"guided_route_help(me,progress)")!=-1 &&
			search(player_command_source,"illusion_realm route next")!=-1 &&
			search(season_source,"travel_to_route_target")!=-1 &&
			search(season_source,"章目标完成")!=-1 &&
			search(season_source,"章狩猎")!=-1 &&
			search(season_source,"本轮打怪已经完成，自动挂机已暂停")!=-1 &&
			search(season_source,"等待下一个北京时间修行日")==-1,
			"章节仍需玩家手工找地图、找挂机入口、找领取按钮或等待跨日");
		check("终章十问有开始、逐题提交、重试和满分后记入口且题面不返回答案",
			search(player_command_source,"parts[0]==\"quiz\"")!=-1 &&
			search(player_command_source,
				"illusion_realm quiz answer ")!=-1 &&
			search(player_command_source,
				"[重新挑战十问:illusion_realm quiz start]")!=-1 &&
			search(player_command_source,"满分后记·山门雪霁")!=-1 &&
			search(season_source,"public_story_quiz_question")!=-1 &&
			search(season_source,
				"\"options\":copy_value((array)question[\"options\"])")!=-1,
			"长生十问命令链不完整或公开题面可能携带服务端答案");
		check("幻境资格购买不重复获取非递归账号锁",
			search(player_command_source,
				"purchase_entitlement(me)")!=-1 &&
			search(season_source,
				"purchase_entitlement(object player)")!=-1 &&
			search(season_source,"purchase_entitlement(object player,\n")==-1,
			"Web购买可能在已持有的账号锁上再次加锁");
		check("S1资格免费激活且玩家界面明确按赛季区分",
			search(player_command_source,"人物资格当前免费永久激活")!=-1 &&
			search(player_command_source,"仅限本赛季")!=-1 &&
			search(player_command_source,"[免费激活:illusion_realm activate]")!=-1 &&
			search(player_command_source,"100碎玉增加本期1格")!=-1 &&
			search(player_command_source,"补足本期累计500碎玉")!=-1 &&
			search(account_source,"season_expansions")!=-1 &&
			search(account_source,"season_entitlements")!=-1,
			"免费配置仍被显示为0碎玉购买或付费门槛");
		string account_api_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/account_characters.pike") || "";
		string http_api_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/http_api_daemon.pike") || "";
		check("人物中心免费激活只接受POST账号令牌且付费配置失败关闭",
			search(account_api_source,
				"handle_api_account_illusion_activate")!=-1 &&
			search(account_api_source,"req->request_type!=\"POST\"")!=-1 &&
			search(account_api_source,
				"account_id = query_account_session(token)")!=-1 &&
			search(http_api_source,
				"case \"/api/account/illusion/activate\"")!=-1 &&
			search(season_source,
				"status[\"entitlement_cost_suiyu\"]!=0")!=-1,
			"账号中心入口可能绕过认证、使用GET或误处理付费资格");
		check("人物创建入口扩容使用POST账号令牌与独立幂等请求号",
			search(account_api_source,
				"handle_api_account_illusion_expand")!=-1 &&
			search(account_api_source,
				"purchase_account_character_expansion")!=-1 &&
			search(account_api_source,
				"params[\"request_id\"]")!=-1 &&
			search(http_api_source,
				"case \"/api/account/illusion/expand\"")!=-1 &&
			search(season_source,
				"debit_account_recharge_once")!=-1 &&
			search(season_source,
				"reconcile_account_character_expansions")!=-1,
			"创建页扩容可能绕过账号令牌、重复扣款或缺少中断恢复");
		mapping story_segment = HTTP_APID->parse_bracket_content(
			"storyimg 5:/xd/images/illusion_s1/story/volume_01.png","","");
		mapping chapter_story_segment = HTTP_APID->parse_bracket_content(
			"storypic 81:/xd/images/illusion_s1/story/chapters/chapter_081.png","","");
		mapping chapter_three_segment = HTTP_APID->parse_bracket_content(
			"storypic 3:/xd/images/illusion_s1/story/chapters/chapter_003.png","","");
		mapping bad_story_segment = HTTP_APID->parse_bracket_content(
			"storypic 81:/xd/images/illusion_s1/story/chapters/chapter_080.png","","");
		mapping compatible_chapter_segment = HTTP_APID->parse_bracket_content(
			"imgurl picture:/xd/images/illusion_s1/story/chapters/chapter_009.png","","");
		string html_renderer_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/html_renderer.pike") || "";
		string html6_source = Stdio.read_file(ROOT+
			"/lowlib/system/filter/html6.pike") || "";
		string html6_dark_source = Stdio.read_file(ROOT+
			"/lowlib/system/filter/html6_dark.pike") || "";
		string html5_source = Stdio.read_file(ROOT+
			"/lowlib/system/filter/html5.pike") || "";
		string html6_compat_source = Stdio.read_file(ROOT+
			"/lowlib/system/filter/html6 copy.pike") || "";
		check("章节插画和旧图集均严格绑定编号并拒绝错配路径",
			(string)story_segment["type"]=="story-image" &&
			(int)story_segment["cell"]==5 &&
			(string)story_segment["src"]==
				"/images/illusion_s1/story/volume_01.png" &&
			(string)chapter_story_segment["type"]=="story-image" &&
			(int)chapter_story_segment["full"]==1 &&
			(int)chapter_story_segment["chapter"]==81 &&
			(string)chapter_story_segment["src"]==
				"/images/illusion_s1/story/chapters/chapter_081.png" &&
			(string)chapter_three_segment["type"]=="story-image" &&
			(int)chapter_three_segment["full"]==1 &&
			(int)chapter_three_segment["chapter"]==3 &&
			(string)chapter_three_segment["src"]==
				"/images/illusion_s1/story/chapters/chapter_003.png" &&
			(string)bad_story_segment["type"]!="story-image",
			sprintf("atlas=%O chapter3=%O chapter81=%O invalid=%O",
				story_segment,chapter_three_segment,chapter_story_segment,
				bad_story_segment));
		check("Vue、旧JSP明暗主题、兼容副本与旧HTML5都能显示独立章节插画",
			search(html_renderer_source,"storyimg %d")!=-1 &&
			search(html_renderer_source,"storypic %d")!=-1 &&
			search(html_renderer_source,"background-size:300%% 300%%")!=-1 &&
			search(html6_source,"storypic %d")!=-1 &&
			search(html6_dark_source,"storypic %d")!=-1 &&
			search(html5_source,"storypic %d")!=-1 &&
			search(html6_compat_source,"storypic %d")!=-1,
			"某个旧界面仍会把剧情图片误渲染成命令按钮");
		check("旧JSP四套过滤器均限制章节图宽高且不裁切手机画面",
			search(html6_source,"max-height:72vh")!=-1 &&
			search(html6_source,"max-height:72svh")!=-1 &&
			search(html6_source,"object-fit:contain")!=-1 &&
			search(html6_dark_source,"max-height:72vh")!=-1 &&
			search(html6_dark_source,"max-height:72svh")!=-1 &&
			search(html6_dark_source,"object-fit:contain")!=-1 &&
			search(html5_source,"max-height:72vh")!=-1 &&
			search(html5_source,"max-height:72svh")!=-1 &&
			search(html5_source,"object-fit:contain")!=-1 &&
			search(html6_compat_source,"max-height:72vh")!=-1 &&
			search(html6_compat_source,"max-height:72svh")!=-1 &&
			search(html6_compat_source,"object-fit:contain")!=-1,
			"旧书签在横屏手机或iPad分屏仍可能显示超尺寸剧情图");
		check("当前任务、章节回看与过关剧情统一使用旧客户端兼容图片协议",
			(string)compatible_chapter_segment["type"]=="image" &&
			(string)compatible_chapter_segment["src"]==
				"/images/illusion_s1/story/chapters/chapter_009.png" &&
			search(player_command_source,"[imgurl picture:")!=-1 &&
			search(season_source,"[imgurl picture:")!=-1 &&
			search(player_command_source,"[storypic ")==-1 &&
			search(season_source,"[storypic ")==-1,
			sprintf("segment=%O",compatible_chapter_segment));
		check("关闭后保留有界窗口接住最后一批跨worker到达",
			search(season_source,"closed_reconcile_until = time()+180")!=-1 &&
			search(season_source,"time()<=closed_reconcile_until")!=-1 &&
			search(season_source,"time()+60")!=-1,
			"结算关闭竞态可能漏掉已接受但稍后才到达目标worker的人物");
		check("赛季家园在统一命令层拦截且旧书签不能绕过",
			search(command_hook_source,"search(verb,\"home_\")==0")!=-1 &&
			search(command_hook_source,
				"is_active_illusion_character(this_object())")!=-1,
			"仅限制地图移动会让远程家园商店命令跨世界搬运资产");
		check("S1登录入口例外只允许尚未进入真实世界的恢复对象",
			search(season_source,
				"target==\"/gamelib/d/init\"")!=-1 &&
			search(season_source,
				"!has_prefix(current,\"/gamelib/d/\")")!=-1,
			"登录入口可能仍被赛季边界拦截，或可被在线人物用于越界");
		check("幻境人物越界失败页保留返回游戏入口",
			search(season_source,
				"幻境人物暂不能离开新月幻境")!=-1 &&
			search(travel_command_source,
				"目的地暂时无法到达。\\n[返回游戏:look]\\n")!=-1,
			"越界被拦截后玩家可能卡在无操作的失败页");
		mapping same_cycle_rollover = SEASONALD->preview_cycle_rollover();
		check("S1未关闭且配置编号未变化时拒绝误换期",
			!(int)same_cycle_rollover["ok"] &&
			(string)same_cycle_rollover["new_id"]=="S1",
			sprintf("rollover=%O",same_cycle_rollover));

		array(string) room_paths = ({
			"/gamelib/d/illusion_s1/moon_gate.pike",
			"/gamelib/d/illusion_s1/nanzhan_mortal_city.pike",
			"/gamelib/d/illusion_s1/nanzhan_life_death_temple.pike",
			"/gamelib/d/illusion_s1/silver_path.pike",
			"/gamelib/d/illusion_s1/fog_forest.pike",
			"/gamelib/d/illusion_s1/fog_oath_camp.pike",
			"/gamelib/d/illusion_s1/mirror_lake.pike",
			"/gamelib/d/illusion_s1/xiniu_scripture_market.pike",
			"/gamelib/d/illusion_s1/broken_observatory.pike",
			"/gamelib/d/illusion_s1/echo_ruins.pike",
			"/gamelib/d/illusion_s1/xiniu_empty_temple.pike",
			"/gamelib/d/illusion_s1/mirror_depths.pike",
			"/gamelib/d/illusion_s1/star_bridge.pike",
			"/gamelib/d/illusion_s1/beiju_longlife_waste.pike",
			"/gamelib/d/illusion_s1/beiju_broken_oath.pike",
			"/gamelib/d/illusion_s1/abyss_garden.pike",
			"/gamelib/d/illusion_s1/moon_palace.pike",
			"/gamelib/d/illusion_s1/beiju_frozen_palace.pike",
			"/gamelib/d/illusion_s1/frozen_judgment_hall.pike",
			"/gamelib/d/illusion_s1/dongsheng_morning_port.pike",
			"/gamelib/d/illusion_s1/dongsheng_fusang_altar.pike",
			"/gamelib/d/illusion_s1/moon_immortality_furnace.pike",
			"/gamelib/d/illusion_s1/true_name_hall.pike",
			"/gamelib/d/illusion_s1/newmoon_altar.pike",
			"/gamelib/d/illusion_s1/hidden_crater.pike",
		});
		array(string) neutral_room_paths = ({
			"/gamelib/d/illusion_s1/moon_dew_field.pike",
			"/gamelib/d/illusion_s1/silver_reed_bank.pike",
			"/gamelib/d/illusion_s1/starlight_slope.pike",
			"/gamelib/d/illusion_s1/mist_bamboo_glen.pike",
			"/gamelib/d/illusion_s1/cloud_pine_hollow.pike",
			"/gamelib/d/illusion_s1/moonshadow_wood.pike",
			"/gamelib/d/illusion_s1/mirror_sandbar.pike",
			"/gamelib/d/illusion_s1/glasswater_bank.pike",
			"/gamelib/d/illusion_s1/moonwave_shoal.pike",
			"/gamelib/d/illusion_s1/broken_star_court.pike",
			"/gamelib/d/illusion_s1/astral_stonewood.pike",
			"/gamelib/d/illusion_s1/observatory_outfield.pike",
			"/gamelib/d/illusion_s1/echo_battlement.pike",
			"/gamelib/d/illusion_s1/old_city_square.pike",
			"/gamelib/d/illusion_s1/stardust_lane.pike",
			"/gamelib/d/illusion_s1/abyss_flower_sea.pike",
			"/gamelib/d/illusion_s1/deepmoon_valley.pike",
			"/gamelib/d/illusion_s1/starfall_garden.pike",
		});
		array(string) story_room_paths = room_paths+({});
		room_paths += neutral_room_paths;
		int rooms_compile = 1;
		mapping(string:int) affinities = ([]);
		foreach(room_paths,string room_path){
			program room_program;
			mixed room_err = catch{
				room_program=(program)(ROOT+room_path);
			};
			string one_affinity = MAP_WORKERD->query_affinity_key(room_path);
			if(room_err || !room_program || one_affinity=="")
				rooms_compile = 0;
			affinities[one_affinity]++;
		}
		check("S1剧情与中立猎场全部可编译并按七组使用多worker",
			rooms_compile && sizeof(affinities)==7 &&
			(int)affinities["illusion_s1:hub"]==2 &&
			(int)affinities["illusion_s1:silver"]==6 &&
			(int)affinities["illusion_s1:ruins"]==7 &&
			(int)affinities["illusion_s1:depths"]==10 &&
			(int)affinities["illusion_s1:hunt_a"]==6 &&
			(int)affinities["illusion_s1:hunt_b"]==6 &&
			(int)affinities["illusion_s1:hunt_c"]==6,
			sprintf("地图编译失败或affinity分组错误：%O",affinities));
		mapping(string:int) story_reached = ([]);
		array(string) story_queue = ({story_room_paths[0]});
		while(sizeof(story_queue)){
			string current_room = story_queue[0];
			story_queue = story_queue[1..];
			if((int)story_reached[current_room])
				continue;
			story_reached[current_room] = 1;
			object current_room_object = (object)(ROOT+current_room);
			foreach(values((mapping)current_room_object->exits),mixed raw_exit){
				string next_room = (string)raw_exit;
				if(has_prefix(next_room,ROOT))
					next_room = next_room[sizeof(ROOT)..];
				if(search(story_room_paths,next_room)!=-1 &&
				   !(int)story_reached[next_room])
					story_queue += ({next_room});
			}
		}
		check("二十五个主线地点均能从新月门真实步行抵达",
			sizeof(story_room_paths)==25 && sizeof(story_reached)==25,
			sprintf("reachable=%d/%d missing=%O",sizeof(story_reached),
				sizeof(story_room_paths),story_room_paths-indices(story_reached)));
		mapping hub_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:hub");
		mapping silver_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:silver");
		mapping ruins_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:ruins");
		mapping depths_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:depths");
		mapping hunt_a_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:hunt_a");
		mapping hunt_b_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:hunt_b");
		mapping hunt_c_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:hunt_c");
		check("S1七个亲和组进入冷启动目录并使用真实房间权重",
			(int)hub_weight["ok"] && (int)hub_weight["static_weight"]==2 &&
			(int)silver_weight["ok"] &&
				(int)silver_weight["static_weight"]==6 &&
			(int)ruins_weight["ok"] &&
				(int)ruins_weight["static_weight"]==7 &&
			(int)depths_weight["ok"] &&
				(int)depths_weight["static_weight"]==10 &&
			(int)hunt_a_weight["static_weight"]==6 &&
			(int)hunt_b_weight["static_weight"]==6 &&
			(int)hunt_c_weight["static_weight"]==6,
			sprintf("hub=%O silver=%O ruins=%O depths=%O a=%O b=%O c=%O",
				hub_weight,silver_weight,ruins_weight,depths_weight,
				hunt_a_weight,hunt_b_weight,hunt_c_weight));
		int neutral_population_ok = 1;
		object pressure_player = clone(GAMELIB_USER);
		pressure_player->set_name("xd99testunitillusionpressure");
		pressure_player->set_project("gamelib");
		pressure_player->set_raceId("human");
		pressure_player->set_profeId("jianxian");
		pressure_player->setup_player("human","jianxian");
		foreach(({neutral_room_paths[0],neutral_room_paths[1],
		   neutral_room_paths[2]}),string neutral_path){
			object neutral_room = (object)(ROOT+neutral_path);
			mapping spawn_status = neutral_room->query_autofight_spawn_status();
			mapping idle_pressure = neutral_room->
				query_autofight_pressure_policy(1,0);
			mapping pressure = neutral_room->query_autofight_pressure_policy(18,0);
			int pressure_spawned = neutral_room->
				refresh_autofight_normal_npcs(pressure_player,18,0);
			mapping filled_status = neutral_room->query_autofight_spawn_status();
			if((int)spawn_status["normal_slots"]!=20 ||
			   (int)spawn_status["alive_normal"]!=4 ||
			   (int)spawn_status["training_capacity"]!=18 ||
			   (int)spawn_status["training_slots"]!=20 ||
			   (int)spawn_status["initial_population"]!=4 ||
			   (int)spawn_status["pressure_check_seconds"]!=3 ||
			   (int)idle_pressure["target_population"]!=4 ||
			   !(int)pressure["enabled"] ||
			   (int)pressure["refresh_seconds"]!=5 ||
			   (int)pressure["budget"]!=20 ||
			   (int)pressure["target_population"]!=20 ||
			   pressure_spawned!=16 ||
			   (int)filled_status["alive_normal"]!=20)
				neutral_population_ok = 0;
		}
		check("中立猎场按4只起步、玩家数加2补到20只且容量18人",
			neutral_population_ok,
			"中立猎场容量、普通怪槽位或补位上限未按配置生效");
		destruct(pressure_player);
		check("S1同房间路由确定且不同章节不会错误合并",
			MAP_WORKERD->query_affinity_key(
				"/gamelib/d/illusion_s1/nanzhan_mortal_city.pike")==
				MAP_WORKERD->query_affinity_key(
					ROOT+"/gamelib/d/illusion_s1/nanzhan_mortal_city.pike#987") &&
			MAP_WORKERD->query_affinity_key(
				"/gamelib/d/illusion_s1/nanzhan_mortal_city.pike")!=
				MAP_WORKERD->query_affinity_key(
					"/gamelib/d/illusion_s1/fog_forest.pike") &&
			MAP_WORKERD->query_affinity_key(
				"/gamelib/d/illusion_s1/fog_forest.pike")!=
				MAP_WORKERD->query_affinity_key(
					"/gamelib/d/illusion_s1/echo_ruins.pike") &&
			MAP_WORKERD->query_affinity_key(
				"/gamelib/d/illusion_s1/echo_ruins.pike")!=
				MAP_WORKERD->query_affinity_key(
					"/gamelib/d/illusion_s1/true_name_hall.pike"),
			"相同共享房间可能分裂，或各野外章节仍挤在同一worker");
		object player_command;
		object manager_command;
		mixed command_error = catch{
			player_command = (object)(ROOT+
				"/gamelib/cmds/illusion_realm.pike");
			manager_command = (object)(ROOT+
				"/gamelib/cmds/mgr_illusion_realm.pike");
		};
		check("玩家与管理员幻境命令均可在真实MUD环境加载",
			!command_error && player_command!=0 && manager_command!=0,
			command_error ? describe_error(command_error) : "命令对象为空");
		string fight_source = Stdio.read_file(ROOT+
			"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
		check("四条真实决斗胜利路径均旁路记录幻境论剑且不改伤害公式",
			sizeof(fight_source/
				"record_illusion_duel_victory(this_object(),enemy);")-1==4 &&
			search(fight_source,
				"SEASONALD->record_pvp_victory(winner,loser)")!=-1,
			"决斗死亡分支存在漏记或重复记分");
		check("排行榜命令提供六榜、领奖入口与防刷规则说明",
			search(player_command_source,"征途")!=-1 &&
			search(player_command_source,"experience")!=-1 &&
			search(player_command_source,"论剑")!=-1 &&
			search(player_command_source,"新月套装")!=-1 &&
			search(player_command_source,"极速")!=-1 &&
			search(player_command_source,"rank claim")!=-1 &&
			search(player_command_source,"100/50/20")!=-1,
			"排行榜入口、类别或防刷告知不完整");
		check("排行榜只扫描轻量原子快照而不遍历完整人物档案",
			search(season_source,"ILLUSION_RANKING_DIR")!=-1 &&
			search(season_source,"persist_ranking_snapshot")!=-1 &&
			search(season_source,"query_ranking_snapshots")!=-1 &&
			search(season_source,"compact_ranking_int")!=-1 &&
			search(season_source,
				"query_illusion_ranking_candidates")==-1 &&
			search(account_source,
				"query_illusion_ranking_candidates")==-1,
			"查榜仍可能同步读取大体积user .o、或旧档缺字段写成null");
		check("论剑荣誉执行同账号、重复对手和等级碾压三层防刷",
			SEASONALD->query_pvp_honor_points_for_test(100,100,0,0)==100 &&
			SEASONALD->query_pvp_honor_points_for_test(100,100,0,1)==50 &&
			SEASONALD->query_pvp_honor_points_for_test(100,100,0,2)==20 &&
			SEASONALD->query_pvp_honor_points_for_test(100,100,0,3)==0 &&
			SEASONALD->query_pvp_honor_points_for_test(100,100,1,0)==0 &&
			SEASONALD->query_pvp_honor_points_for_test(130,100,0,0)==0 &&
			SEASONALD->query_pvp_honor_points_for_test(80,100,0,0)==140,
			"论剑积分递减、同账号或等级差边界错误");
		check("论剑日防刷在北京时间零点而非早八点重置",
			SEASONALD->query_ranking_beijing_day_for_test(57599)==0 &&
			SEASONALD->query_ranking_beijing_day_for_test(57600)==1,
			"论剑重复对手次数仍可能使用UTC日界线");
		mapping rank_profile = ([
			"id":"xd99testunitillusionrank","level":88,
			"illusion_state":"active","experience":999,
			"illusion_progress":([
				"joined_at":100,"kills":50,"boss_kills":2,
				"team_kills":4,"visited":(["a":1,"b":1,"c":1]),
				"claims":(["c1":100,"c2":200]),
				"route_marks":(["r1":1,"r2":1,"r3":1]),
				"ranking_level":88,"ranking_experience_start":100,
				"ranking_experience_latest":900,"set_parts":5,
				"completed_at":500,
				"ranking_weeks":(["1":([
					"experience_start":100,"experience_latest":450,
					"level":80,
				])]),
			]),
		]);
		mapping journey_score = SEASONALD->query_ranking_score_for_test(
			"journey",rank_profile,"overall","S1");
		mapping experience_score = SEASONALD->query_ranking_score_for_test(
			"experience",rank_profile,"week:1","S1");
		mapping speed_score = SEASONALD->query_ranking_score_for_test(
			"speed",rank_profile,"overall","S1");
		check("征途、周经验与速通榜使用赛季冻结快照而非永恒服当前值",
			(int)journey_score["eligible"] &&
			(int)journey_score["score"]==23350 &&
			(int)experience_score["score"]==350 &&
			(int)speed_score["score"]==400,
			sprintf("journey=%O exp=%O speed=%O",journey_score,
				experience_score,speed_score));

		root = create_root(account_id);
		center_root = create_root(center_account_id);
		mapping center_activation = SEASONALD->
			activate_free_account_entitlement(center_account_id);
		mapping center_activation_again = SEASONALD->
			activate_free_account_entitlement(center_account_id);
		mapping center_account = ACCOUNT_CHARACTERD->
			query_account_characters(center_account_id,"S1");
		mapping center_account_s2_before = ACCOUNT_CHARACTERD->
			query_account_characters(center_account_id,"S2");
		check("人物中心可免费永久激活S1且重复点击幂等",
			(int)center_activation["ok"] &&
			!(int)center_activation["already"] &&
			(int)center_activation_again["ok"] &&
			(int)center_activation_again["already"] &&
			(int)center_account["illusion_entitled"] &&
			(string)center_account["illusion_entitlement_cycle"]["source"]==
				"account_center" &&
			search((string)center_activation["message"],"S1人物资格")!=-1,
			sprintf("first=%O second=%O account=%O",
				center_activation,center_activation_again,center_account));
		mapping center_wallet_credit = ACCOUNT_WALLETD->credit_recharge_once(
			center_root,10,"testunitadmin",
			ACCOUNT_WALLETD->new_recharge_request_id());
		string center_recovery_request = "9"*64;
		mapping center_pending_debit = ACCOUNT_WALLETD->
			debit_account_recharge_once(center_account_id,100,
				"illusion_character_expansion:S1:one",
				center_recovery_request);
		mapping center_recovery = SEASONALD->
			reconcile_account_character_expansions(center_account_id);
		mapping center_after_recovery = ACCOUNT_CHARACTERD->
			query_account_characters(center_account_id,"S1");
		mapping center_wallet_after = ACCOUNT_WALLETD->
			query_account_wallet(center_account_id);
		check("人物中心扣款后中断可自动补写S1栏位并清理幂等收据",
			(int)center_wallet_credit["ok"] &&
			(int)center_pending_debit["ok"] &&
			(int)center_recovery["ok"] &&
			(int)center_recovery["recovered"]==1 &&
			(int)center_after_recovery["illusion_character_slots"]==2 &&
			(int)center_after_recovery[
				"illusion_expansion_spent_suiyu"]==100 &&
			(int)center_wallet_after["balance"]==0 &&
			sizeof((mapping)center_wallet_after["debit_requests"])==0,
			sprintf("credit=%O debit=%O recovery=%O account=%O wallet=%O",
				center_wallet_credit,center_pending_debit,center_recovery,
				center_after_recovery,center_wallet_after));
		check("S1永久资格不会自动穿透到S2",
			!(int)center_account_s2_before["illusion_entitled"] &&
			(string)center_account_s2_before["illusion_entitlement_id"]=="S2",
			sprintf("s2=%O",center_account_s2_before));
		mapping center_s2_grant = ACCOUNT_CHARACTERD->
			grant_illusion_entitlement(center_account_id,"test","e"*64,"S2");
		mapping center_account_s1_after = ACCOUNT_CHARACTERD->
			query_account_characters(center_account_id,"S1");
		mapping center_account_s2_after = ACCOUNT_CHARACTERD->
			query_account_characters(center_account_id,"S2");
		check("S1与S2资格可分别永久记录且互不覆盖",
			(int)center_s2_grant["ok"] &&
			!(int)center_s2_grant["already"] &&
			(int)center_account_s1_after["illusion_entitled"] &&
			(int)center_account_s2_after["illusion_entitled"] &&
			(string)center_account_s1_after[
				"illusion_entitlement_cycle"]["source"]=="account_center" &&
			(string)center_account_s2_after[
				"illusion_entitlement_cycle"]["source"]=="test",
			sprintf("grant=%O s1=%O s2=%O",center_s2_grant,
				center_account_s1_after,center_account_s2_after));
		mapping denied = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","jianxian","","","","illusion","S1");
		check("未永久解锁账号不能伪造S1人物创建",
			!(int)denied["ok"] &&
			search((string)denied["message"],"尚未永久解锁")!=-1,
			sprintf("denied=%O",denied));

		YUSHID->give_yushi(root,1000);
		int payment_before = YUSHID->query_physical_all_num(root);
		YUSHID->pay_yushi(root,5);
		root["/plus/illusion_entitlement_purchase"] = ([
			"version":1,"phase":"charged","request_id":"a"*64,
			"account_id":account_id,"illusion_id":"S1","cost":5,
			"before_wallet":0,"before_physical":payment_before,
			"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("购买中断且资格未写入时登录自动原路退回碎玉",
			YUSHID->query_physical_all_num(root)==payment_before &&
			!sizeof((mapping)root["/plus/illusion_entitlement_purchase"]),
			"崩溃购买凭据未退款或未清理");

		string entitlement_request = "c"*64;
		mapping entitlement = ACCOUNT_CHARACTERD->grant_illusion_entitlement(
			account_id,"test",entitlement_request,"S1");
		mapping entitlement_again = ACCOUNT_CHARACTERD->
			grant_illusion_entitlement(account_id,"test",entitlement_request,"S1");
		check("S1永久资格幂等写入账号索引",
			(int)entitlement["ok"] && !(int)entitlement["already"] &&
			(int)entitlement_again["ok"] &&
			(int)entitlement_again["already"] &&
			(int)entitlement["entitlement"]["character_slots"]==1 &&
			!(int)entitlement["entitlement"]["multi_character_unlocked"],
			sprintf("first=%O second=%O",entitlement,entitlement_again));

		int matched_before = YUSHID->query_physical_all_num(root);
		YUSHID->pay_yushi(root,2);
		root["/plus/illusion_entitlement_purchase"] = ([
			"version":1,"phase":"charged",
			"request_id":entitlement_request,
			"account_id":account_id,"illusion_id":"S1","cost":2,
			"before_wallet":0,"before_physical":matched_before,
			"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("资格请求号吻合时登录只清凭据而不错误退款",
			YUSHID->query_physical_all_num(root)==matched_before-2 &&
			!sizeof((mapping)root["/plus/illusion_entitlement_purchase"]),
			"已成功解锁的扣款被错误退回");

		int duplicate_before = YUSHID->query_physical_all_num(root);
		YUSHID->pay_yushi(root,2);
		root["/plus/illusion_entitlement_purchase"] = ([
			"version":1,"phase":"charged","request_id":"d"*64,
			"account_id":account_id,"illusion_id":"S1","cost":2,
			"before_wallet":0,"before_physical":duplicate_before,
			"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("资格请求号不吻合时重复扣款会原路退回",
			YUSHID->query_physical_all_num(root)==duplicate_before &&
			!sizeof((mapping)root["/plus/illusion_entitlement_purchase"]),
			"并发或管理员解锁后的第二笔扣款未退回");

		mapping created = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","jianxian","","","","illusion","S1");
		if((int)created["ok"]){
			child_id = (string)created["character"]["id"];
			cleanup_ids += ({child_id});
		}
		check("S1人物继续使用账号下唯一普通user档案",
			(int)created["ok"] && child_id!="" &&
			Stdio.file_size(player_file(child_id))>0,
			(string)(created["message"] || "创建失败"));

		child = clone(GAMELIB_USER);
		child->set_name(child_id);
		child->set_project("gamelib");
		child->restore();
		child->name_cn = "S1新月行者";
		int first_bootstrapped = bootstrap_character(child,"human","jianxian");
		child->level = 69;
		child->set_att_by_level();
		SEASONALD->prepare_new_character(child);
		child->last_pos = "/gamelib/d/illusion_s1/silver_path.pike";
		SEASONALD->prepare_new_character(child);
		check("S1首个人物走真实职业初始化并保留合法上次位置",
			first_bootstrapped && (string)child->last_pos==
				"/gamelib/d/illusion_s1/silver_path.pike" &&
			(string)child->relife==
			"/gamelib/d/illusion_s1/moon_gate.pike",
			sprintf("last=%s relife=%s",(string)child->last_pos,
				(string)child->relife));
		mapping fresh_story_progress = SEASONALD->query_player_progress(child);
		mapping fresh_first_chapter = (mapping)((array)
			fresh_story_progress["chapters"])[0];
		mapping fresh_last_chapter = (mapping)((array)
			fresh_story_progress["chapters"])[80];
		mapping locked_quiz = SEASONALD->query_story_quiz(child);
		mapping locked_quiz_start = SEASONALD->start_story_quiz_for_test(child);
		int five_line_story_chapters;
		foreach((array)fresh_story_progress["chapters"],mapping story_chapter){
			array(string) story_lines = (string)story_chapter["intro"]/"\n";
			int valid_lines = sizeof(story_lines)==5;
			foreach(story_lines,string story_line)
				if(sizeof(String.trim_all_whites(story_line))<12)
					valid_lines = 0;
			if(valid_lines)
				five_line_story_chapters++;
		}
		check("章节运行态返回独立插画、精确怪名地点和本章增量计数",
			(string)fresh_first_chapter["image"]==
				"/xd/images/illusion_s1/story/chapters/chapter_001.png" &&
			(string)fresh_last_chapter["image"]==
				"/xd/images/illusion_s1/story/chapters/chapter_081.png" &&
			(string)fresh_first_chapter["hunt_name"]=="逐光月灵" &&
			(string)fresh_first_chapter["hunt_location"]=="月露原" &&
			(int)fresh_first_chapter["chapter_kills"]>0 &&
			(int)fresh_first_chapter["chapter_kills_done"]==0 &&
			(string)fresh_first_chapter["target_kind"]=="hunt" &&
			(string)fresh_first_chapter["target_room"]==
				"/gamelib/d/illusion_s1/moon_dew_field.pike",
			sprintf("first=%O last=%O",fresh_first_chapter,
				fresh_last_chapter));
		check("八十一章运行态均展开为五段厚叙事且没有空白短行",
			five_line_story_chapters==81,
			sprintf("five_line_chapters=%d",five_line_story_chapters));
		check("未完成八十一章不能越权开启长生十问",
			(int)locked_quiz["ok"] && !(int)locked_quiz["unlocked"] &&
			!(int)locked_quiz_start["ok"],
			sprintf("query=%O start=%O",locked_quiz,locked_quiz_start));
		object chapter_gate = (object)(ROOT+
			"/gamelib/d/illusion_s1/moon_gate.pike");
		child["/tmp/illusion_move_bypass"] = 1;
		child->move(chapter_gate);
		child->m_delete_foruser("/tmp/illusion_move_bypass");
		mapping future_travel = SEASONALD->travel_to_chapter_target(child,2);
		child->set_autofight("enable");
		mapping afk_travel = SEASONALD->travel_to_chapter_target(child,1);
		child->set_autofight("disable");
		mapping chapter_travel = SEASONALD->travel_to_chapter_target(child,1);
		mapping chapter_travel_again = SEASONALD->travel_to_chapter_target(
			child,1);
		check("章节直达拒绝越章和挂机中移动并通过普通move安全到目标房",
			!(int)future_travel["ok"] && !(int)afk_travel["ok"] &&
			(int)chapter_travel["ok"] &&
			MAP_WORKERD->static_room_locations_match(
				file_name(environment(child)),
				"/gamelib/d/illusion_s1/moon_dew_field.pike") &&
			(int)chapter_travel_again["ok"] &&
			(int)chapter_travel_again["already"],
			sprintf("future=%O afk=%O travel=%O again=%O room=%s",
				future_travel,afk_travel,chapter_travel,
				chapter_travel_again,file_name(environment(child))));
		mapping(string:string) expected_afk_routes = ([
			"1":"illusion_s1/moon_dew_field|1",
			"10":"illusion_s1/mist_bamboo_glen|10",
			"20":"illusion_s1/mirror_sandbar|20",
			"30":"illusion_s1/broken_star_court|30",
			"40":"illusion_s1/echo_battlement|40",
			"50":"illusion_s1/abyss_flower_sea|50",
			"69":"illusion_s1/abyss_flower_sea|50",
		]);
		int s1_afk_routes_ok = 1;
		foreach(indices(expected_afk_routes),string level_text){
			child->level = (int)level_text;
			mapping route = AUTOFIGHTD->query_training_route(child);
			mapping window = AUTOFIGHTD->query_target_level_window(child);
			array(string) expected = expected_afk_routes[level_text]/"|";
			array(string) route_paths = (array(string))route["paths"];
			multiset(string) route_affinities = (<>);
			foreach(route_paths,string route_path)
				route_affinities[MAP_WORKERD->query_affinity_key(
					"/gamelib/d/"+route_path+".pike")] = 1;
			if((string)route["path"]!=expected[0] ||
			   (int)route["level"]!=(int)expected[1] ||
			   sizeof(route_paths)!=3 || sizeof(route_affinities)!=3 ||
			   (int)route["capacity"]!=18 ||
			   (int)route["total_capacity"]<50 ||
			   (int)route["disable_overflow"]!=1 ||
			   (int)window["minimum"]!=(int)expected[1] ||
			   (int)window["maximum"]!=(int)expected[1])
				s1_afk_routes_ok = 0;
		}
		check("S1挂机每级三张中立图可容纳50人且不创建隔离分流房",
			s1_afk_routes_ok &&
			AUTOFIGHTD->query_rest_room(child)=="illusion_s1/moon_gate",
			"S1挂机路线、攻击等级或休息营地仍可能落入永恒服");
		child->level = 69;
		child->set_att_by_level();
		child->last_pos =
			"/gamelib/d/illusion_s1/removed_room.pike";
		child->relife =
			"/gamelib/d/illusion_s1/removed_bedroom.pike";
		object login_room = (object)(ROOT+"/gamelib/d/init");
		login_room->repair_invalid_login_positions(child,1);
		check("S1失效登录房间与复活点回退本期营地而非永恒主城",
			(string)child->last_pos==
				"/gamelib/d/illusion_s1/moon_gate.pike" &&
			(string)child->relife==
				"/gamelib/d/illusion_s1/moon_gate.pike",
			sprintf("last=%s relife=%s",(string)child->last_pos,
				(string)child->relife));
		mapping visited = ([]);
		for(int index=0;index<36;index++)
			visited["/gamelib/d/illusion_s1/test_"+(string)index+".pike"] = 1;
		mapping active_days = ([]);
		for(int day=0;day<7;day++)
			active_days[(string)(20000+day)] = time()+day*86400;
		mapping story_event_marks = ([]);
		mapping story_source = Standards.JSON.decode(Stdio.read_file(ROOT+
			"/gamelib/etc/illusion_realm.json"));
		foreach((array)story_source["story_events"],mapping story_event)
			story_event_marks[(string)story_event["id"]] = time();
		child["/plus/illusion_realm/S1"] = ([
			"version":1,"joined_at":time(),"kills":750,"boss_kills":10,
			"team_kills":50,"visited":visited,"active_days":active_days,
			"story_events":story_event_marks,"path":"hunter",
			"route_marks":([]),"claims":([]),
		]);
		mapping hunter_first_step = SEASONALD->query_route_step(child);
		mapping hunter_first_travel =
			SEASONALD->travel_to_route_target(child);
		check("破阵傻瓜引导从当前未完成首领开始并直达断星桥",
			(int)hunter_first_step["ok"] &&
			(string)hunter_first_step["id"]=="broken_star" &&
			(string)hunter_first_step["room"]==
				"/gamelib/d/illusion_s1/star_bridge.pike" &&
			(int)hunter_first_travel["ok"] &&
			(string)hunter_first_travel["action"]=="hunt",
			sprintf("step=%O travel=%O",hunter_first_step,
				hunter_first_travel));
		object battle_room = (object)(ROOT+
			"/gamelib/d/illusion_s1/star_bridge.pike");
		child["/tmp/illusion_move_bypass"] = 1;
		child->move(battle_room);
		child->m_delete_foruser("/tmp/illusion_move_bypass");
		foreach(({"star_keeper","moon_general","newmoon_lord"}),
		   string boss_name){
			object boss = clone(ROOT+
				"/gamelib/clone/npc/illusion_s1/"+boss_name+".pike");
			boss->move(battle_room);
			SEASONALD->record_npc_kill(child,boss,1);
			destruct(boss);
		}
		mapping hunter_progress =
			child["/plus/illusion_realm/S1"];
		mapping hunter_done_step = SEASONALD->query_route_step(child);
		check("破阵路线按真实NPC文件识别三名不同首领",
			mappingp(hunter_progress["route_marks"]) &&
			sizeof((mapping)hunter_progress["route_marks"])==3 &&
			(int)hunter_done_step["done"],
			sprintf("marks=%O",hunter_progress["route_marks"]));
		hunter_progress["path"] = "pioneer";
		hunter_progress["route_marks"] = ([]);
		mapping pioneer_first_step = SEASONALD->query_route_step(child);
		mapping pioneer_first_travel =
			SEASONALD->travel_to_route_target(child);
		check("寻星傻瓜引导从首枚月印开始并直达倒月镜湖",
			(int)pioneer_first_step["ok"] &&
			(string)pioneer_first_step["id"]=="mirror_moon" &&
			(int)pioneer_first_travel["ok"] &&
			(string)pioneer_first_travel["action"]=="explore",
			sprintf("step=%O travel=%O",pioneer_first_step,
				pioneer_first_travel));
		mapping last_secret = ([]);
		foreach(({"mirror_lake","hidden_crater","newmoon_altar"}),
		   string room_name){
			object secret_room = (object)(ROOT+
				"/gamelib/d/illusion_s1/"+room_name+".pike");
			child["/tmp/illusion_move_bypass"] = 1;
			child->move(secret_room);
			child->m_delete_foruser("/tmp/illusion_move_bypass");
			last_secret = SEASONALD->discover_route_secret_for_test(child);
		}
		mapping duplicate_secret =
			SEASONALD->discover_route_secret_for_test(child);
		check("寻星路线从三个真实房间取得三枚幂等隐藏月印",
			(int)last_secret["ok"] &&
			sizeof((mapping)hunter_progress["route_marks"])==3 &&
			(int)duplicate_secret["ok"] &&
			(int)duplicate_secret["already"],
			sprintf("last=%O duplicate=%O marks=%O",last_secret,
				duplicate_secret,hunter_progress["route_marks"]));
		hunter_progress["path"] = "companion";
		hunter_progress["team_kills"] = 0;
		mapping companion_step = SEASONALD->query_route_step(child);
		mapping companion_travel = SEASONALD->travel_to_route_target(child);
		check("同心傻瓜引导不乱传送且直接进入组队协作步骤",
			(int)companion_step["ok"] &&
			(string)companion_step["action"]=="team" &&
			(string)companion_step["room"]=="" &&
			(int)companion_travel["ok"] &&
			(string)companion_travel["action"]=="team",
			sprintf("step=%O travel=%O",companion_step,
				companion_travel));
		hunter_progress["path"] = "hunter";
		hunter_progress["team_kills"] = 50;
		hunter_progress["route_marks"] = ([
			"broken_star":1,"moon_guard":1,"newmoon_lord":1,
		]);
		child->save_with_result();
		mapping second_blocked = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","yushi","","","","illusion","S1");
		check("每期首名免费但第二名必须先扩充当期栏位",
			!(int)second_blocked["ok"] &&
			search((string)second_blocked["message"],"栏位已用完")!=-1,
			sprintf("second=%O",second_blocked));
		mapping expansion_wallet_credit = ACCOUNT_WALLETD->credit_recharge_once(
			root,50,"testunitadmin",
			ACCOUNT_WALLETD->new_recharge_request_id());
		string one_slot_request = "e"*64;
		mapping one_slot = SEASONALD->purchase_account_character_expansion(
			account_id,"one",one_slot_request);
		mapping one_slot_again = SEASONALD->
			purchase_account_character_expansion(account_id,"one",
				one_slot_request);
		mapping one_slot_account = ACCOUNT_CHARACTERD->
			query_account_characters(account_id,"S1");
		mapping one_slot_wallet = ACCOUNT_WALLETD->query_account_wallet(
			account_id);
		check("创建职业入口支付100碎玉增加S1一格且重试不重复扣款",
			(int)expansion_wallet_credit["ok"] &&
			(int)one_slot["ok"] && !(int)one_slot["already"] &&
			(int)one_slot_again["ok"] && (int)one_slot_again["already"] &&
			(int)one_slot_account["illusion_character_slots"]==2 &&
			(int)one_slot_account["illusion_expansion_spent_suiyu"]==100 &&
			(int)one_slot_wallet["balance"]==400 &&
			sizeof((mapping)one_slot_wallet["debit_requests"])==0,
			sprintf("credit=%O first=%O again=%O account=%O wallet=%O",
				expansion_wallet_credit,one_slot,one_slot_again,
				one_slot_account,one_slot_wallet));
		int expansion_matched_before = YUSHID->query_physical_all_num(root);
		root["/plus/illusion_character_expansion_purchase"] = ([
			"version":1,"phase":"charged","request_id":one_slot_request,
			"account_id":account_id,"illusion_id":"S1","option":"one",
			"cost":100,"before_wallet":0,
			"before_physical":expansion_matched_before+100,"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("扩容请求已写入账号索引时重启恢复只清凭据不误退款",
			YUSHID->query_physical_all_num(root)==expansion_matched_before &&
			!sizeof((mapping)root[
				"/plus/illusion_character_expansion_purchase"]),
			"已提交扩容被错误退款或恢复凭据未清理");
		int expansion_unmatched_before = YUSHID->query_physical_all_num(root);
		YUSHID->pay_yushi(root,100);
		root["/plus/illusion_character_expansion_purchase"] = ([
			"version":1,"phase":"charged","request_id":"1"*64,
			"account_id":account_id,"illusion_id":"S1","option":"one",
			"cost":100,"before_wallet":0,
			"before_physical":expansion_unmatched_before,"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("扩容扣款未写入账号索引时重启自动原路退款",
			YUSHID->query_physical_all_num(root)==
				expansion_unmatched_before &&
			!sizeof((mapping)root[
				"/plus/illusion_character_expansion_purchase"]),
			"未提交扩容没有退款或恢复凭据未清理");
		mapping second_created = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","yushi","","","","illusion","S1");
		if((int)second_created["ok"]){
			second_id = (string)second_created["character"]["id"];
			cleanup_ids += ({second_id});
		}
		mapping second_realm = second_id!="" ?
			ACCOUNT_CHARACTERD->query_character_realm(second_id) : ([]);
		check("扩充后允许同一期创建第二个独立人物但仍占账号总栏位",
			(int)second_created["ok"] && second_id!="" &&
			second_id!=child_id &&
			(string)second_realm["realm_type"]=="illusion" &&
			(string)second_realm["illusion_id"]=="S1" &&
			(int)ACCOUNT_CHARACTERD->query_character_limit()==30,
			sprintf("second=%O realm=%O",second_created,second_realm));
		object second_player = clone(GAMELIB_USER);
		second_player->set_name(second_id);
		second_player->set_project("gamelib");
		second_player->restore();
		second_player->name_cn = "S1御使行者";
		int second_bootstrapped = bootstrap_character(second_player,
			"human","yushi");
		second_player->level = 69;
		second_player->set_att_by_level();
		int second_saved = second_player->save_with_result();
		destruct(second_player);
		check("S1第二个人物扩栏后走真实职业初始化并可独立保存",
			second_bootstrapped && second_saved,
			sprintf("bootstrap=%d saved=%d",second_bootstrapped,second_saved));
		mapping third_blocked = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","zhuxian","","","","illusion","S1");
		mapping wrong_remaining = ACCOUNT_CHARACTERD->
			grant_illusion_character_expansion(account_id,"S1","all",
				"f"*64,500);
		string all_slot_request = "f"*64;
		mapping all_slots = SEASONALD->purchase_account_character_expansion(
			account_id,"all",all_slot_request);
		mapping all_slots_again = SEASONALD->
			purchase_account_character_expansion(account_id,"all",
				all_slot_request);
		mapping all_slots_account = ACCOUNT_CHARACTERD->
			query_account_characters(account_id,"S1");
		mapping all_slots_wallet = ACCOUNT_WALLETD->query_account_wallet(
			account_id);
		check("S1此前100碎玉全额抵扣且只需补400解锁本期多人物",
			!(int)third_blocked["ok"] && !(int)wrong_remaining["ok"] &&
			(int)wrong_remaining["expected_cost_suiyu"]==400 &&
			(int)all_slots["ok"] && !(int)all_slots["already"] &&
			(int)all_slots_again["ok"] && (int)all_slots_again["already"] &&
			(int)all_slots_account["illusion_multi_character_unlocked"]==1 &&
			(int)all_slots_account["illusion_expansion_spent_suiyu"]==500 &&
			(int)all_slots_wallet["balance"]==0 &&
			sizeof((mapping)all_slots_wallet["debit_requests"])==0,
			sprintf("blocked=%O wrong=%O all=%O again=%O account=%O wallet=%O",
				third_blocked,wrong_remaining,all_slots,all_slots_again,
				all_slots_account,all_slots_wallet));
		mapping third_created = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","zhuxian","","","","illusion","S1");
		if((int)third_created["ok"]){
			third_id = (string)third_created["character"]["id"];
			cleanup_ids += ({third_id});
		}
		check("S1多人物解锁后仍由账号30人物总上限约束",
			(int)third_created["ok"] && third_id!="" &&
			(int)ACCOUNT_CHARACTERD->query_character_limit()==30,
			sprintf("third=%O",third_created));
		int third_bootstrapped;
		int third_saved;
		if(third_id!=""){
			object third_player = clone(GAMELIB_USER);
			third_player->set_name(third_id);
			third_player->set_project("gamelib");
			third_player->restore();
			third_player->name_cn = "S1诛仙行者";
			third_bootstrapped = bootstrap_character(third_player,
				"human","zhuxian");
			third_saved = third_player->save_with_result();
			destruct(third_player);
		}

		mapping fourth_created = ACCOUNT_CHARACTERD->create_character(account_id,
			"monst","kuangyao","","","","illusion","S1");
		if((int)fourth_created["ok"]){
			fourth_id = (string)fourth_created["character"]["id"];
			cleanup_ids += ({fourth_id});
		}
		int fourth_bootstrapped;
		int fourth_saved;
		if(fourth_id!=""){
			object fourth_player = clone(GAMELIB_USER);
			fourth_player->set_name(fourth_id);
			fourth_player->set_project("gamelib");
			int fourth_restored = fourth_player->restore();
			fourth_player->name_cn = "S1狂妖行者";
			fourth_bootstrapped = fourth_restored &&
				bootstrap_character(fourth_player,"monst","kuangyao");
			fourth_saved = fourth_bootstrapped &&
				fourth_player->save_with_result();
			destruct(fourth_player);
		}
		check("S1第一至第四个人物均为唯一档案并完成真实职业初始化",
			third_bootstrapped && third_saved &&
			(int)fourth_created["ok"] && fourth_id!="" &&
			fourth_id!=child_id && fourth_id!=second_id &&
			fourth_id!=third_id && fourth_bootstrapped && fourth_saved &&
			Stdio.file_size(player_file(child_id))>0 &&
			Stdio.file_size(player_file(second_id))>0 &&
			Stdio.file_size(player_file(third_id))>0 &&
			Stdio.file_size(player_file(fourth_id))>0,
			sprintf("ids=%O bootstrap=%O saved=%O fourth=%O",
				({child_id,second_id,third_id,fourth_id}),
				({first_bootstrapped,second_bootstrapped,
					third_bootstrapped,fourth_bootstrapped}),
				({second_saved,third_saved,fourth_saved}),fourth_created));

		mapping s2_before = ACCOUNT_CHARACTERD->query_account_characters(
			account_id,"S2");
		mapping s2_slot_before_entitlement = ACCOUNT_CHARACTERD->
			grant_illusion_character_expansion(account_id,"S2","one",
				"2"*64,100);
		mapping s2_entitlement = ACCOUNT_CHARACTERD->
			grant_illusion_entitlement(account_id,"test","3"*64,"S2");
		mapping s2_slot = ACCOUNT_CHARACTERD->
			grant_illusion_character_expansion(account_id,"S2","one",
				"4"*64,100);
		mapping s1_after_s2 = ACCOUNT_CHARACTERD->query_account_characters(
			account_id,"S1");
		mapping s2_after = ACCOUNT_CHARACTERD->query_account_characters(
			account_id,"S2");
		check("新赛季需独立激活资格且付费栏位按赛季严格隔离",
			!(int)s2_before["illusion_entitled"] &&
			(int)s2_before["illusion_character_slots"]==1 &&
			!(int)s2_before["illusion_multi_character_unlocked"] &&
			(int)s2_before["illusion_expansion_spent_suiyu"]==0 &&
			!(int)s2_slot_before_entitlement["ok"] &&
			search((string)s2_slot_before_entitlement["message"],
				"尚未激活S2")!=-1 &&
			(int)s2_entitlement["ok"] &&
			!(int)s2_entitlement["already"] &&
			(int)s2_slot["ok"] &&
			(int)s2_after["illusion_entitled"] &&
			(int)s2_after["illusion_character_slots"]==2 &&
			(int)s2_after["illusion_expansion_spent_suiyu"]==100 &&
			(int)s1_after_s2["illusion_character_slots"]==6 &&
			(int)s1_after_s2["illusion_multi_character_unlocked"] &&
			(int)s1_after_s2["illusion_expansion_spent_suiyu"]==500,
			sprintf("before=%O denied=%O entitlement=%O grant=%O s1=%O s2=%O",
				s2_before,s2_slot_before_entitlement,s2_entitlement,
				s2_slot,s1_after_s2,s2_after));

		mapping realm = ACCOUNT_CHARACTERD->query_character_realm(child_id);
		check("S1身份由账号索引判定并形成独立互动组",
			(string)realm["realm_type"]=="illusion" &&
			(string)realm["illusion_id"]=="S1" &&
			SEASONALD->query_character_group(child_id)=="illusion:S1" &&
			LOGICALZONED->query_user_group(child_id)=="illusion:S1",
			sprintf("realm=%O group=%s",realm,
				LOGICALZONED->query_user_group(child_id)));
		mapping active_realm = ([
			"realm_type":"illusion","illusion_state":"active",
			"illusion_id":"S1",
		]);
		check("S1进行中只允许区内移动且结算时冻结全部移动",
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/congxianzhen/congxianzhenguangchang",
				"active")==2 &&
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/illusion_s1/silver_path.pike","active")==0 &&
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/illusion_s1/silver_path.pike","settling")==1,
			"移动边界或结算冻结策略不符合预期");
		check("S1家园房间路径始终按跨世界移动拒绝",
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/home/template/main","active")==2 &&
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/ninggedian/ninggedian","active")==2,
			"赛季人物可能从旧链接进入永恒家园或家园城区");
		check("换期后尚未登录回归的旧周期人物不能误入新周期",
			SEASONALD->query_move_policy_for_test(
				(["realm_type":"illusion","illusion_state":"active",
					"illusion_id":"S0"]),
				"/gamelib/d/illusion_s1/moon_gate.pike","active")==1,
			"旧周期人物被新配置当作当前人物");
		check("永恒人物不能通过旧书签或传送闯入S1",
			SEASONALD->query_move_policy_for_test(
				(["realm_type":"eternal","illusion_state":""]),
				"/gamelib/d/illusion_s1/moon_gate.pike","active")==3,
			"永恒人物进入S1未失败关闭");
		check("账号世界索引异常时所有移动与共享资产都失败关闭",
			SEASONALD->query_move_policy_for_test(
				(["realm_type":"unavailable","security_blocked":1]),
				"/gamelib/d/congxianzhen/congxianzhenguangchang",
				"active")==4,
			"损坏索引被错误当作普通永恒人物");
		mapping storage = ACCOUNT_STORAGED->query_storage(child);
		check("S1人物不能导入共享仓库或共享宠物",
			!(int)storage["ok"] &&
			SPIRIT_COMPANIOND->query_pet_battle_source(child)=="personal",
			sprintf("storage=%O source=%s",storage,
				SPIRIT_COMPANIOND->query_pet_battle_source(child)));

		mapping vip_wallet_credit = ACCOUNT_WALLETD->credit_recharge_once(
			root,480,"testunitadmin",
			ACCOUNT_WALLETD->new_recharge_request_id());
		object vip_app_command = (object)(ROOT+
			"/gamelib/cmds/vip_service_app_confirm.pike");
		object|zero vip_original_player = this_player();
		mixed vip_err = catch{
			set_this_player(child);
			vip_app_command->main("1");
		};
		if(vip_original_player)
			set_this_player(vip_original_player);
		else
			set_this_player(this_object());
		int vip_payment_saved = child->save_with_result();
		int vip_payment_finalized = YUSHID->
			complete_wallet_payment_player_save(child);
		if(vip_payment_finalized)
			vip_payment_saved = child->save_with_result() &&
				vip_payment_saved;
		mapping vip_wallet_after = ACCOUNT_WALLETD->query_account_wallet(
			account_id);
		check("S1账号充值余额全场通用且可直接开通VIP",
			(int)vip_wallet_credit["ok"] && !vip_err &&
			(int)child->query_vip_flag()==1 &&
			(int)child->query_vip_end_time()>time() && vip_payment_saved &&
			vip_payment_finalized &&
			ACCOUNT_WALLETD->query_balance(child)==4700 &&
			YUSHID->query_all_num(child)>=4700 &&
			(int)vip_wallet_after["balance"]==4700 &&
			!sizeof((mapping)(child[
				"/plus/yushi_wallet_payment"] || ([]))),
			sprintf("credit=%O err=%O vip=%d end=%d saved=%d "
				"finalized=%d balance=%d all=%d wallet=%O",
				vip_wallet_credit,vip_err,
				(int)child->query_vip_flag(),
				(int)child->query_vip_end_time(),vip_payment_saved,
				vip_payment_finalized,
				ACCOUNT_WALLETD->query_balance(child),
				YUSHID->query_all_num(child),
				vip_wallet_after));

		mapping progress = SEASONALD->query_player_progress(child);
		check("三路线与八十一章目标在满条件时按顺序可领取",
			(int)progress["ok"] &&
			sizeof((array)progress["chapters"])==81 &&
			(int)progress["story_event_count"]==25 &&
			(int)progress["chapters"][0]["ready"] &&
			(string)progress["path"]=="hunter" &&
			(int)progress["route_mark_count"]==3 &&
			SEASONALD->query_route_final_ready_for_test(
				(["path":"pioneer","route_marks":([
					"mirror_moon":1,"hidden_core":1,"returning_mark":1,
				])]))==1 &&
			SEASONALD->query_route_final_ready_for_test(
				(["path":"hunter","route_marks":([
					"broken_star":1,"moon_guard":1,"newmoon_lord":1,
				])]))==1 &&
			SEASONALD->query_route_final_ready_for_test(
				(["path":"companion","team_kills":50]))==1 &&
			SEASONALD->query_route_final_ready_for_test(
				(["path":"pioneer","route_marks":([
					"fake_a":1,"fake_b":1,"fake_c":1,
				])]))==0,
			sprintf("progress=%O",progress));

		int claims_ok = 1;
		for(int chapter=1;chapter<=81;chapter++){
			mapping claim = SEASONALD->claim_chapter_reward_for_test(
				child,chapter);
			if(!(int)claim["ok"] || (int)claim["already"])
				claims_ok = 0;
		}
		int before_duplicate = count_newmoon_items(child);
		mapping duplicate_claim = SEASONALD->claim_chapter_reward_for_test(
			child,81);
		check("八十一章正好发十件账号绑定套装且重复领取不会克隆",
			claims_ok && before_duplicate==10 &&
			all_newmoon_bound_to(child,account_id) &&
			(int)duplicate_claim["ok"] && (int)duplicate_claim["already"] &&
			count_newmoon_items(child)==10,
			sprintf("claims=%d items=%d duplicate=%O",claims_ok,
				count_newmoon_items(child),duplicate_claim));
		int quiz_start_failure_armed = SEASONALD->
			force_next_story_quiz_save_failure_for_test(child);
		mapping quiz_failed_start = SEASONALD->
			start_story_quiz_for_test(child);
		mapping quiz_after_failed_start = SEASONALD->query_story_quiz(child);
		check("十问开始写盘失败会回滚且不误增挑战次数",
			quiz_start_failure_armed && !(int)quiz_failed_start["ok"] &&
			(string)quiz_after_failed_start["status"]=="ready" &&
			(int)quiz_after_failed_start["attempts"]==0,
			sprintf("failed=%O after=%O",quiz_failed_start,
				quiz_after_failed_start));
		mapping quiz_started = SEASONALD->start_story_quiz_for_test(child);
		mapping quiz_started_again = SEASONALD->
			start_story_quiz_for_test(child);
		mapping quiz_first_question = (mapping)quiz_started["question"];
		int quiz_answer_private = !has_index(quiz_first_question,"answer") &&
			!has_index(quiz_first_question,"explanation");
		int quiz_answer_failure_armed = SEASONALD->
			force_next_story_quiz_save_failure_for_test(child);
		mapping quiz_failed_answer = SEASONALD->answer_story_quiz_for_test(
			child,1,(int)((array)story_config["quiz"])[0]["answer"]);
		mapping quiz_after_failed_answer = SEASONALD->query_story_quiz(child);
		check("十问答题写盘失败会回滚且同一题可以安全重提",
			quiz_answer_failure_armed && !(int)quiz_failed_answer["ok"] &&
			(string)quiz_after_failed_answer["status"]=="active" &&
			(int)((mapping)quiz_after_failed_answer["question"])["number"]==1 &&
			(int)quiz_after_failed_answer["current_score"]==0,
			sprintf("failed=%O after=%O",quiz_failed_answer,
				quiz_after_failed_answer));
		mapping quiz_first_answer = SEASONALD->answer_story_quiz_for_test(
			child,1,(int)((array)story_config["quiz"])[0]["answer"]);
		mapping quiz_replayed = SEASONALD->answer_story_quiz_for_test(
			child,1,(int)((array)story_config["quiz"])[0]["answer"]);
		int quiz_perfect_answers_ok = (int)quiz_first_answer["ok"] &&
			(int)quiz_first_answer["correct"] && !(int)quiz_replayed["ok"];
		for(int question=2;question<=10;question++){
			mapping answered = SEASONALD->answer_story_quiz_for_test(
				child,question,(int)((array)story_config["quiz"])
					[question-1]["answer"]);
			if(!(int)answered["ok"] || !(int)answered["correct"])
				quiz_perfect_answers_ok = 0;
		}
		mapping quiz_perfect = SEASONALD->query_story_quiz(child);
		check("十问题面不泄露答案、重复题号不推进且满分解锁后记",
			(int)quiz_started["ok"] &&
			(string)quiz_started["status"]=="active" &&
			(int)quiz_started["attempts"]==1 &&
			(int)quiz_started_again["already"] &&
			(int)quiz_started_again["attempts"]==1 &&
			quiz_answer_private && quiz_perfect_answers_ok &&
			(string)quiz_perfect["status"]=="completed" &&
			(int)quiz_perfect["last_score"]==10 &&
			(int)quiz_perfect["best_score"]==10 &&
			(string)quiz_perfect["best_title"]=="人间见证者" &&
			(int)quiz_perfect["perfect"] &&
			sizeof((string)quiz_perfect["epilogue"])>100,
			sprintf("start=%O again=%O replay=%O perfect=%O",
				quiz_started,quiz_started_again,quiz_replayed,quiz_perfect));
		mapping quiz_retry = SEASONALD->start_story_quiz_for_test(child);
		int quiz_retry_ok = (int)quiz_retry["ok"] &&
			(int)quiz_retry["attempts"]==2 &&
			(string)quiz_retry["best_title"]=="人间见证者";
		for(int question=1;question<=10;question++){
			int answer = (int)((array)story_config["quiz"])
				[question-1]["answer"];
			mapping answered = SEASONALD->answer_story_quiz_for_test(
				child,question,answer%4+1);
			if(!(int)answered["ok"] || (int)answered["correct"])
				quiz_retry_ok = 0;
		}
		mapping quiz_after_retry = SEASONALD->query_story_quiz(child);
		check("十问可重试但低分不覆盖最高分或重复发放数值奖励",
			quiz_retry_ok && (int)quiz_after_retry["attempts"]==2 &&
			(int)quiz_after_retry["last_score"]==0 &&
			(int)quiz_after_retry["best_score"]==10 &&
			(string)quiz_after_retry["best_title"]=="人间见证者" &&
			count_newmoon_items(child)==10,
			sprintf("retry=%O after=%O items=%d",quiz_retry,
				quiz_after_retry,count_newmoon_items(child)));
		mapping live_set_board = SEASONALD->query_illusion_leaderboard(
			"S1","set","overall",20);
		mapping child_set_row = ([]);
		if((int)live_set_board["ok"])
			foreach((array)live_set_board["rows"],mapping row)
				if((string)row["character_id"]==child_id){
					child_set_row = row;
					break;
				}
		check("轻量原子快照可派生S1套装榜且不暴露注册账号标识",
			(int)live_set_board["ok"] && sizeof(child_set_row) &&
			(int)child_set_row["score"]==10 &&
			!has_index(child_set_row,"account_id"),
			sprintf("board=%O child=%O",live_set_board,child_set_row));
		// 十问故障注入会用深拷贝恢复整个历程；后续测试必须重新取得
		// 人物档案里的现行 mapping，不能继续修改回滚前的旧引用。
		hunter_progress = child["/plus/illusion_realm/S1"];
		hunter_progress["season_starts_at"] = time()-8*86400;
		if(!mappingp(hunter_progress["ranking_weeks"]))
			hunter_progress["ranking_weeks"] = ([]);
		hunter_progress["ranking_weeks"]["1"] = ([
			"set_parts":10,"level":69,"completed_at":time()-7*86400,
			"experience_start":0,"experience_latest":1,
		]);
		child->save_with_result();
		mapping weekly_title = SEASONALD->claim_illusion_ranking_reward(
			child,"set","week:1");
		mapping weekly_title_again = SEASONALD->
			claim_illusion_ranking_reward(child,"set","week:1");
		check("已结束周榜前十荣誉领取持久化且重复领取幂等",
			(int)weekly_title["ok"] && (int)weekly_title["rank"]>=1 &&
			(int)weekly_title["rank"]<=10 &&
			search((string)weekly_title["title"],"S1·周1")!=-1 &&
			(int)weekly_title_again["ok"] &&
			(int)weekly_title_again["already"] &&
			sizeof((array)hunter_progress["ranking_titles"])==1,
			sprintf("first=%O again=%O",weekly_title,weekly_title_again));

		object receipt_hash = Crypto.SHA256();
		receipt_hash->update("S1-test-receipt");
		string receipt = lower_case(String.string2hex(
			receipt_hash->digest()));
		mapping settled = ACCOUNT_CHARACTERD->settle_illusion_character(
			child_id,"S1",receipt);
		mapping settled_again = ACCOUNT_CHARACTERD->settle_illusion_character(
			child_id,"S1",receipt);
		mapping wrong_receipt = ACCOUNT_CHARACTERD->settle_illusion_character(
			child_id,"S1","b"*64);
		child->save_with_result();
		destruct(child);
		child = 0;
		restored = clone(GAMELIB_USER);
		restored->set_name(child_id);
		restored->set_project("gamelib");
		int restored_ok = restored->restore();
		mapping returned_realm = ACCOUNT_CHARACTERD->query_character_realm(
			child_id);
		check("回归只切换账号索引，同一原档案与十件装备完整保留",
			(int)settled["ok"] && !(int)settled["already"] &&
			(int)settled_again["ok"] && (int)settled_again["already"] &&
			!(int)wrong_receipt["ok"] &&
			restored_ok && count_newmoon_items(restored)==10 &&
			(string)returned_realm["realm_type"]=="eternal" &&
			(string)returned_realm["illusion_state"]=="returned" &&
			SEASONALD->query_character_group(child_id)=="",
			sprintf("settled=%O wrong=%O returned=%O items=%d",settled,
				wrong_receipt,
				returned_realm,count_newmoon_items(restored)));
	};
	if(err)
		check("S1完整测试没有运行异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(root) destruct(root);
	if(center_root) destruct(center_root);
	if(child) destruct(child);
	if(restored) destruct(restored);
	array(string) known = ACCOUNT_CHARACTERD->query_character_ids(account_id);
	foreach(known,string character_id)
		if(search(character_id,"testunitillusion")!=-1 &&
		   search(cleanup_ids,character_id)==-1)
			cleanup_ids += ({character_id});
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(center_account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(center_account_id);
	cleanup_player(center_account_id);
	foreach(cleanup_ids,string character_id)
		cleanup_ranking_snapshot(character_id);
	foreach(cleanup_ids,string character_id)
		cleanup_player(character_id);
	werror("新月幻境·S1：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
