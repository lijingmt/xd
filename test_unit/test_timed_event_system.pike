#!/usr/bin/env pike
/** 天衡绝境与九曜镇渊的配置、原创规则、运行时边界回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int ok,void|string detail)
{
	results["total"]++;
	if(ok){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,detail || "条件不满足");
	}
}

object create_player(string user_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(user_id);
	player->name_cn = "活动测试员";
	player->sid = "5dwap";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("zhenyue");
	player->setup_player("third","zhenyue");
	player->level = 60;
	player->set_att_by_level();
	player->flush_life();
	return player;
}

void test_runtime_compile()
{
	array(string) files = ({
		"/gamelib/single/daemons/timed_eventd.pike",
		"/gamelib/d/timed_event/event_room.pike",
		"/gamelib/clone/npc/timed_event/yuanling.pike",
		"/gamelib/cmds/timed_event.pike",
	});
	int ok = 1;
	string details = "";
	foreach(files,string file){
		mixed err = catch{ compile_file(ROOT+file); };
		if(err){
			ok = 0;
			details += file+":"+describe_error(err);
		}
	}
	check("守护进程、房间、首领与命令均由真实Pike运行时编译",ok,details);
}

void test_token_exchange_shop()
{
	object player = create_player("__testunit_timed_shop__");
	mapping state = ([
		"tianheng_tokens":20,
		"jiuyao_tokens":150,
		"last_entry":([]),
		"claims":([]),
		"badges":([]),
	]);
	string page;
	string insufficient;
	string gold_result;
	string item_result;
	string badge_result;
	string duplicate_badge;
	int money_before;
	int badge_balance;
	object|zero material = 0;
	player["/plus/timed_event"] = state;
	player->set_account(0);
	page = TIMED_EVENTD->handle_command(player,"shop","");
	check("令牌商店同时展示补给、锻造材料和永久徽记",
		search(page,"天衡传音符")!=-1 &&
		search(page,"天衡免战符")!=-1 &&
		search(page,"绑定紫水晶")!=-1 &&
		search(page,"九曜镇渊徽记")!=-1,"商店目录不完整");
	insufficient = TIMED_EVENTD->handle_command(
		player,"exchange","th_jingang");
	check("令牌不足时不发物品也不扣余额",
		search(insufficient,"不足")!=-1 &&
		(int)state["tianheng_tokens"]==20,
		sprintf("balance=%d",(int)state["tianheng_tokens"]));
	money_before = player->query_account();
	gold_result = TIMED_EVENTD->handle_command(
		player,"exchange","th_gold");
	check("金币补给即时到账并只扣一枚天衡令",
		search(gold_result,"兑换成功")!=-1 &&
		player->query_account()==money_before+1000000 &&
		(int)state["tianheng_tokens"]==19,"金币或令牌数错误");
	item_result = TIMED_EVENTD->handle_command(
		player,"exchange","th_xuanhuang");
	foreach(all_inventory(player),object one){
		if(one && functionp(one->query_name) &&
		   one->query_name()=="xuanhuangshi"){
			material = one;
			break;
		}
	}
	check("兑换锻造材料进入包袱且强制人物绑定",
		search(item_result,"兑换成功")!=-1 && material &&
		material->query_item_canDrop()==0 &&
		material->query_item_canTrade()==0 &&
		material->query_item_canSend()==0 &&
		material->query_item_canStorage()==1 &&
		(int)state["tianheng_tokens"]==7,
		"材料未到账、未绑定或扣费错误");
	badge_result = TIMED_EVENTD->handle_command(
		player,"exchange","jy_badge");
	badge_balance = (int)state["jiuyao_tokens"];
	duplicate_badge = TIMED_EVENTD->handle_command(
		player,"exchange","jy_badge");
	check("永久徽记只能兑换一次且重复操作不扣令牌",
		search(badge_result,"兑换成功")!=-1 &&
		(int)state["badges"]["jiuyao_guardian"]==1 &&
		badge_balance==50 &&
		(int)state["jiuyao_tokens"]==badge_balance &&
		search(duplicate_badge,"不能重复兑换")!=-1,
		sprintf("first=%O duplicate=%O balance=%d badges=%O",
			badge_result,duplicate_badge,
			(int)state["jiuyao_tokens"],state["badges"]));
	if(material)
		destruct(material);
	if(player)
		destruct(player);
}

void test_schedule_and_timezone()
{
	int now = time();
	mapping local_now = gmtime(now+8*3600);
	int current_seconds = (int)local_now["hour"]*3600+
		(int)local_now["min"]*60+(int)local_now["sec"];
	int day_start = now-current_seconds;
	mapping signup = TIMED_EVENTD->query_schedule_for_test(
		"tianheng",day_start+20*3600+5*60);
	mapping battle = TIMED_EVENTD->query_schedule_for_test(
		"tianheng",day_start+20*3600+15*60);
	mapping closed = TIMED_EVENTD->query_schedule_for_test(
		"tianheng",day_start+19*3600);
	check("中国时区20:00集结十分钟并在随后进入战斗",
		(string)signup["phase"]=="signup" &&
		(int)signup["remaining"]==300 &&
		(string)battle["phase"]=="battle" &&
		(string)closed["phase"]=="closed",
		sprintf("signup=%O battle=%O closed=%O",signup,battle,closed));
}

void test_original_game_rules()
{
	array(string) center = TIMED_EVENTD->query_adjacent_nodes_for_test("4");
	array(string) corner = TIMED_EVENTD->query_adjacent_nodes_for_test("0");
	check("九曜九宫中心四向、角落两向且没有越界",
		sizeof(center)==4 && search(center,"1")!=-1 &&
		search(center,"3")!=-1 && search(center,"5")!=-1 &&
		search(center,"7")!=-1 && sizeof(corner)==2,
		sprintf("center=%O corner=%O",center,corner));
	check("封脉人数随存活规模变化且单人场可完成",
		TIMED_EVENTD->query_seal_requirement_for_test(1)==1 &&
		TIMED_EVENTD->query_seal_requirement_for_test(3)==1 &&
		TIMED_EVENTD->query_seal_requirement_for_test(4)==2,"");
	check("天衡淘汰名次由淘汰后存活数唯一决定",
		TIMED_EVENTD->query_pvp_rank_for_test(8,2)==3 &&
		TIMED_EVENTD->query_pvp_rank_for_test(8,1)==2 &&
		TIMED_EVENTD->query_pvp_rank_for_test(8,0)==1,"");
	string sources = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_timed_event_mod/view.pike")+
		Stdio.read_file(ROOT+
		"/gamelib/single/daemons/timed_eventd.pike");
	check("玩法名称与文案未沿用玩家提案原名",
		search(sources,"诸神战场")==-1 && search(sources,"修罗地狱")==-1 &&
		search(sources,"天衡绝境")!=-1 && search(sources,"九曜镇渊")!=-1,"");
}

void test_room_teleport_guard_and_npc()
{
	object player = create_player("__testunit_timed_event_guard__");
	object normal = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object room = clone(ROOT+"/gamelib/d/timed_event/event_room.pike");
	object npc = clone(ROOT+"/gamelib/clone/npc/timed_event/yuanling.pike");
	int entered = 0;
	int escaped = 0;
	string error_desc = "";
	mixed err = catch{
		room->configure_timed_event_room("tianheng","test|session",
			"stage","pvp_stage","测试镜域","测试。\n");
		player["/tmp/timed_event_move_bypass"] = 1;
		entered = player->move(room);
		player->m_delete_foruser("/tmp/timed_event_move_bypass");
		escaped = player->move(normal);
		npc->configure_timed_event_npc("test|session","boss",
			"测试巡渊主",60,1,500000,1000);
	};
	if(err)
		error_desc = describe_error(err);
	check("活动房间阻止普通飞行传送离开",
		!err && entered==1 && escaped==0 && environment(player)==room,error_desc);
	player["/tmp/timed_event_move_bypass"] = 1;
	player->move(normal);
	player->m_delete_foruser("/tmp/timed_event_move_bypass");
	int direct_entry = player->move(room);
	check("外部玩家不能猜测路径直飞活动基础房间",
		direct_entry==0 && environment(player)==normal,"");
	check("动态活动首领具备会话身份、等级与正数气血",
		!err && npc->is_timed_event_npc() &&
		npc->query_timed_event_role()=="boss" &&
		npc->query_level()==60 && npc->query_life_max()>0,error_desc);
	if(player) destruct(player);
	if(npc) destruct(npc);
	if(room) destruct(room);
}

void test_wiring_and_public_status()
{
	string user_source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	string npc_source = Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string renderer = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	mapping status = TIMED_EVENTD->query_player_status(0);
	check("死亡、存档、登录恢复和HTTP状态链完整接线",
		search(user_source,"handle_player_defeat")!=-1 &&
		search(user_source,"is_event_room(env)")!=-1 &&
		search(npc_source,"handle_event_npc_death")!=-1 &&
		search(init_source,"restore_player(me)")!=-1 &&
		search(renderer,"query_player_status(player)")!=-1,"");
	check("空玩家状态查询纯读取且返回稳定关闭状态",
		mappingp(status) && (int)status["active"]==0 &&
		(string)status["phase"]=="closed",sprintf("%O",status));
}

void test_real_pvp_flow()
{
	object normal = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object first = create_player("__testunit_timed_pvp_a__");
	object second = create_player("__testunit_timed_pvp_b__");
	string session_key = "";
	int paired = 0;
	int settled = 0;
	string error_desc = "";
	mixed err = catch{
		first->move(normal);
		second->move(normal);
		session_key = TIMED_EVENTD->begin_session_for_test(
			"tianheng",({first,second}));
		TIMED_EVENTD->handle_command(first,"move","north");
		TIMED_EVENTD->handle_command(second,"move","south");
		second->set_action("escape");
		second->escape();
		paired = session_key!="" && environment(first)==environment(second) &&
			first->query_in_combat() && second->query_in_combat();
		settled = TIMED_EVENTD->handle_player_defeat(second,first) &&
			environment(first)==normal && environment(second)==normal &&
			!(int)TIMED_EVENTD->query_player_status(first)["active"];
	};
	if(err)
		error_desc = describe_error(err)+" "+describe_backtrace(err);
	check("天衡真实流程完成候场、随机镜域交战与一次死亡结算",
		!err && paired && settled,error_desc);
	if(session_key!="")
		TIMED_EVENTD->cleanup_session_for_test(session_key);
	if(first) destruct(first);
	if(second) destruct(second);
}

void test_real_pve_flow()
{
	object normal = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object player = create_player("__testunit_timed_pve__");
	object|zero boss = 0;
	string session_key = "";
	int reached_boss = 0;
	int settled = 0;
	string error_desc = "";
	mixed err = catch{
		player->move(normal);
		session_key = TIMED_EVENTD->begin_session_for_test(
			"jiuyao",({player}));
		TIMED_EVENTD->handle_command(player,"move","north");
		TIMED_EVENTD->handle_command(player,"move","west");
		foreach(all_inventory(environment(player)),object one)
			if(one && functionp(one->query_timed_event_role) &&
			   one->query_timed_event_role()=="boss")
				boss = one;
		reached_boss = boss && environment(boss)==environment(player);
		if(boss)
			settled = TIMED_EVENTD->handle_event_npc_death(boss,player) &&
				environment(player)==normal &&
				!(int)TIMED_EVENTD->query_player_status(player)["active"];
	};
	if(err)
		error_desc = describe_error(err)+" "+describe_backtrace(err);
	check("九曜真实流程完成九宫移动、巡游首领发现与胜利结算",
		!err && reached_boss && settled,error_desc);
	if(session_key!="")
		TIMED_EVENTD->cleanup_session_for_test(session_key);
	if(player) destruct(player);
}

int main()
{
	werror("\n========== 每日限时原创玩法测试 ==========\n");
	test_runtime_compile();
	test_schedule_and_timezone();
	test_token_exchange_shop();
	test_original_game_rules();
	test_room_teleport_guard_and_npc();
	test_wiring_and_public_status();
	test_real_pvp_flow();
	test_real_pve_flow();
	werror("限时玩法测试完成: 总计%d, 通过%d, 失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
