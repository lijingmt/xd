#!/usr/bin/env pike
/** S1九卷首领预警、应对、失误边界与非S1隔离。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

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

object create_player(void|string suffix)
{
	object player=clone(GAMELIB_USER);
	string tag=suffix || "player";
	player->set_name("__testunit_illusion_boss_"+tag+"__");
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->set_account_owner("xd99illusionboss"+tag);
	player->name_cn="首领机制测试";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=120;
	player->set_att_by_level();
	player["/tmp/illusion_boss_test_s1"]=1;
	return player;
}

int move_for_test(object value,object room)
{
	if(!value || !room)
		return 0;
	value["/tmp/illusion_move_bypass"]=1;
	int moved=value->move(room);
	value->m_delete_foruser("/tmp/illusion_move_bypass");
	return moved && environment(value)==room;
}

int main()
{
	array catalog=ILLUSION_BOSSD->query_catalog_for_test();
	mapping(string:int) ids=([]);
	int catalog_ok=sizeof(catalog)==9;
	foreach(catalog,mapping row){
		catalog_ok=catalog_ok && (string)row["id"]!="" &&
			!ids[(string)row["id"]] && (int)row["cadence"]>=6 &&
			(int)row["power_bp"]>=100 && (int)row["power_bp"]<=700 &&
			has_prefix((string)row["path"],
				"/gamelib/clone/npc/illusion_s1/");
		ids[(string)row["id"]]=1;
	}
	check("九卷首领各有唯一机制且伤害/回能边界保守",catalog_ok,
		sprintf("catalog=%O",catalog));
	string boss_source=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/illusion_bossd.pike") || "";
	string command_source=Stdio.read_file(ROOT+
		"/gamelib/cmds/illusion_boss.pike") || "";
	check("赛季进度异常只关闭首领附加机制且主动应对不会空响应",
		search(boss_source,"progress_err=catch")!=-1 &&
		search(boss_source,"progress_err || !mappingp(progress)")!=-1 &&
		search(command_source,"answer_err=catch")!=-1 &&
		search(command_source,"!mappingp(result)")!=-1,
		"首领资格仍可能把赛季进度异常抛给战斗或命令入口");

	object player=create_player();
	object room=(object)(ROOT+"/gamelib/d/illusion_s1/nanzhan_life_death_temple.pike");
	mapping life_profile=([]);
	foreach(catalog,mapping row)
		if((string)row["id"]=="life_threads"){
			life_profile=row;
			break;
		}
	object boss=clone(ROOT+(string)life_profile["path"]);
	int moved=move_for_test(player,room) && move_for_test(boss,room);
	boss->timeCount=2;
	ILLUSION_BOSSD->tick(boss,player);
	mapping pending=ILLUSION_BOSSD->query_pending_for_test(boss);
	mapping answered=ILLUSION_BOSSD->answer(player,(string)pending["profile"],
		(string)life_profile["action"],(string)pending["nonce"]);
	int before=player->get_cur_life();
	boss->timeCount=4;
	ILLUSION_BOSSD->tick(boss,player);
	check("真实同房预警使用nonce应对且成功不会扣血",moved &&
		sizeof(pending)>0 && (int)answered["ok"] &&
		player->get_cur_life()==before &&
		!sizeof(ILLUSION_BOSSD->query_pending_for_test(boss)),
		sprintf("pending=%O answered=%O life=%d/%d",pending,answered,
			player->get_cur_life(),before));

	boss->timeCount=10;
	ILLUSION_BOSSD->tick(boss,player);
	// cadence=8: 10%8==2, deliberately do not answer.
	before=player->get_cur_life();
	boss->timeCount=12;
	ILLUSION_BOSSD->tick(boss,player);
	int lost=before-player->get_cur_life();
	check("机制失误按最大生命比例且永不直接完成最后一击",
		lost>0 && lost<=player->query_life_max()*7/100 &&
		player->get_cur_life()>=1,
		sprintf("lost=%d life=%d max=%d",lost,player->get_cur_life(),
			player->query_life_max()));

	player->m_delete_foruser("/tmp/illusion_boss_test_s1");
	boss->timeCount=18;
	ILLUSION_BOSSD->tick(boss,player);
	check("非S1人物完全不生成首领机制状态",
		!sizeof(ILLUSION_BOSSD->query_pending_for_test(boss)),
		sprintf("pending=%O",ILLUSION_BOSSD->query_pending_for_test(boss)));

	// Boss脱战会把timeCount归零。同一玩家立即重打时也不能把上一场
	// 尚未应对的预警带入新战斗，更不能在旧resolve_tick突然扣血。
	player["/tmp/illusion_boss_test_s1"]=1;
	boss->timeCount=26;
	ILLUSION_BOSSD->tick(boss,player);
	mapping old_fight_pending=ILLUSION_BOSSD->query_pending_for_test(boss);
	before=player->get_cur_life();
	boss->timeCount=1;
	ILLUSION_BOSSD->tick(boss,player);
	check("首领脱战计时归零会清除上一场未结算预警",
		sizeof(old_fight_pending)>0 &&
		!sizeof(ILLUSION_BOSSD->query_pending_for_test(boss)) &&
		player->get_cur_life()==before,
		sprintf("old=%O current=%O life=%d/%d",old_fight_pending,
			ILLUSION_BOSSD->query_pending_for_test(boss),
			player->get_cur_life(),before));

	// 两只同类首领分别预警两个玩家时，第二名玩家的 nonce 不能被
	// 房间列表里第一只同名首领截断。
	player["/tmp/illusion_boss_test_s1"]=1;
	object player_two=create_player("player_two");
	object boss_two=clone(ROOT+(string)life_profile["path"]);
	int duplicate_ok=move_for_test(player_two,room) &&
		move_for_test(boss_two,room);
	array(object) same_bosses=({});
	foreach(all_inventory(room,player_two),object candidate)
		if(candidate==boss || candidate==boss_two)
			same_bosses+=({candidate});
	if(sizeof(same_bosses)==2){
		same_bosses[0]->timeCount=26;
		same_bosses[1]->timeCount=26;
		ILLUSION_BOSSD->tick(same_bosses[0],player);
		ILLUSION_BOSSD->tick(same_bosses[1],player_two);
		mapping second_pending=ILLUSION_BOSSD->
			query_pending_for_test(same_bosses[1]);
		mapping second_answer=ILLUSION_BOSSD->answer(player_two,
			(string)second_pending["profile"],
			(string)life_profile["action"],
			(string)second_pending["nonce"]);
		duplicate_ok=duplicate_ok && (int)second_answer["ok"];
	}
	else
		duplicate_ok=0;
	check("同房两只同类首领的预警按玩家与nonce精确匹配",
		duplicate_ok,sprintf("bosses=%d",sizeof(same_bosses)));

	// 同一玩家也可能被两只同模板首领同时围攻；两个预警必须生成不同
	// nonce，且回答第二只不能被房间列表中的第一只提前截断。
	object player_three=create_player("player_three");
	object boss_three_a=clone(ROOT+(string)life_profile["path"]);
	object boss_three_b=clone(ROOT+(string)life_profile["path"]);
	int same_target_ok=move_for_test(player_three,room) &&
		move_for_test(boss_three_a,room) && move_for_test(boss_three_b,room);
	boss_three_a->timeCount=2;
	boss_three_b->timeCount=2;
	ILLUSION_BOSSD->tick(boss_three_a,player_three);
	ILLUSION_BOSSD->tick(boss_three_b,player_three);
	mapping pending_three_a=ILLUSION_BOSSD->query_pending_for_test(boss_three_a);
	mapping pending_three_b=ILLUSION_BOSSD->query_pending_for_test(boss_three_b);
	mapping answer_three_b=ILLUSION_BOSSD->answer(player_three,
		(string)pending_three_b["profile"],(string)life_profile["action"],
		(string)pending_three_b["nonce"]);
	same_target_ok=same_target_ok && sizeof(pending_three_a)>0 &&
		sizeof(pending_three_b)>0 &&
		(string)pending_three_a["nonce"]!=(string)pending_three_b["nonce"] &&
		(int)answer_three_b["ok"] &&
		(string)ILLUSION_BOSSD->query_pending_for_test(boss_three_a)["answer"]=="" &&
		(string)ILLUSION_BOSSD->query_pending_for_test(boss_three_b)["answer"]==
			(string)life_profile["action"];
	check("同一玩家同秒面对两只同类首领时预警互不串线",
		same_target_ok,sprintf("a=%O b=%O answer=%O",pending_three_a,
			pending_three_b,answer_three_b));

	{
	// 组队中 Boss 可能切换最高仇恨对象。已经发给甲的预警必须继续对甲
	// 结算，不能因为下一心跳 action_enemy 变成乙而被静默清除或误伤乙。
	object player_four=create_player("player_four");
	object player_five=create_player("player_five");
	object boss_four=clone(ROOT+(string)life_profile["path"]);
	int switched_target_ok=move_for_test(player_four,room) &&
		move_for_test(player_five,room) && move_for_test(boss_four,room);
	boss_four->timeCount=2;
	ILLUSION_BOSSD->tick(boss_four,player_four);
	mapping switched_pending=ILLUSION_BOSSD->query_pending_for_test(boss_four);
	int four_before=player_four->get_cur_life();
	int five_before=player_five->get_cur_life();
	boss_four->timeCount=3;
	ILLUSION_BOSSD->tick(boss_four,player_five);
	switched_target_ok=switched_target_ok &&
		sizeof(ILLUSION_BOSSD->query_pending_for_test(boss_four))>0;
	boss_four->timeCount=4;
	ILLUSION_BOSSD->tick(boss_four,player_five);
	switched_target_ok=switched_target_ok && sizeof(switched_pending)>0 &&
		player_four->get_cur_life()<four_before &&
		player_five->get_cur_life()==five_before &&
		!sizeof(ILLUSION_BOSSD->query_pending_for_test(boss_four));
	check("组队首领切换仇恨目标不会吞掉或转移原玩家预警",
		switched_target_ok,sprintf("pending=%O life_four=%d/%d life_five=%d/%d",
			switched_pending,player_four->get_cur_life(),four_before,
			player_five->get_cur_life(),five_before));

	// 本拍 action_enemy 也可能是宠物/召唤物，甚至在对象销毁交界点暂时
	// 为空。已有预警仍应寻找原玩家并完成结算，不能永久卡在 Boss 身上。
	object boss_five=clone(ROOT+(string)life_profile["path"]);
	int invalid_target_ok=move_for_test(boss_five,room);
	boss_five->timeCount=2;
	ILLUSION_BOSSD->tick(boss_five,player_four);
	mapping invalid_pending=ILLUSION_BOSSD->query_pending_for_test(boss_five);
	four_before=player_four->get_cur_life();
	boss_five->timeCount=4;
	ILLUSION_BOSSD->tick(boss_five,0);
	invalid_target_ok=invalid_target_ok && sizeof(invalid_pending)>0 &&
		player_four->get_cur_life()<four_before &&
		!sizeof(ILLUSION_BOSSD->query_pending_for_test(boss_five));
	check("首领仇恨临时切到宠物或空对象仍结算原玩家预警",
		invalid_target_ok,sprintf("pending=%O life=%d/%d",invalid_pending,
			player_four->get_cur_life(),four_before));
	if(boss_five)
		destruct(boss_five);
	if(boss_four)
		destruct(boss_four);
	if(player_four)
		destruct(player_four);
	if(player_five)
		destruct(player_five);
	}

	if(boss_three_a)
		destruct(boss_three_a);
	if(boss_three_b)
		destruct(boss_three_b);
	if(player_three)
		destruct(player_three);

	if(boss_two)
		destruct(boss_two);
	if(player_two)
		destruct(player_two);
	if(boss)
		destruct(boss);
	if(player)
		destruct(player);
	werror("S1首领机制：%d/%d通过\n",(int)results["passed"],
		(int)results["total"]);
	return (int)results["failed"] ? 1 : 0;
}
