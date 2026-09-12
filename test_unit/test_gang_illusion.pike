#!/usr/bin/env pike
/** 建议7批D-4回归：帮派幻境 开窗进入→妖影击杀→周结算。 */

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

object create_player(string userid,string race_id,string profession_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = "帮派幻境测试"+userid;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

int count_items(object player,string item_name)
{
	int count = 0;
	foreach(all_inventory(player),object item)
		if(item->query_name()==item_name)
			count += (int)(item->amount>0 ? item->amount : 1);
	return count;
}

int find_window_ts()
{
	int t = time();
	// 10分钟步进扫一周：窗口宽30分钟，1小时步进可能跨过。
	for(int i=0;i<1200;i++){
		t += 600;
		if(BANGPAI_EXTD->bangpai_illusion_in_window(t))
			return t;
	}
	return 0;
}

int main()
{
	object original_player = this_player();
	object|zero member_a = 0;
	object|zero member_b = 0;
	object|zero outsider = 0;
	string error_desc = "";
	mixed err = catch {
		int window_ts = find_window_ts();
		check("能找到一个周六20:30-21:00的窗口时刻",window_ts>0,
			"200小时内找不到幻境窗口");
		if(!window_ts)
			error("no window\n");
		member_a = create_player("__testunit_illu_a__","human","jianxian");
		member_b = create_player("__testunit_illu_b__","monst","kuangyao");
		outsider = create_player("__testunit_illu_out__","human","jianxian");
		member_a->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		member_b->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		outsider->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		BANGPAI_EXTD->set_state_file_for_test(1);
		BANGPAI_EXTD->set_bang_gate_for_test(1);
		member_a->bangid = 13;
		member_b->bangid = 13;
		outsider->bangid = 8;
		set_this_player(member_a);

		// 未达4级被拒。
		BANGPAI_EXTD->set_illusion_clock_for_test(window_ts);
		mapping locked = BANGPAI_EXTD->enter_bang_illusion(member_a);
		check("帮派等级不足4级时幻境保持关闭",
			!(int)locked["ok"] &&
			search((string)locked["message"],"4级")!=-1,
			sprintf("result=%O",locked));

		// 捐献到4级后开放。
		member_a->set_account(600000);
		BANGPAI_EXTD->donate(member_a,600000);
		check("捐献后帮派达4级并解锁幻境",
			BANGPAI_EXTD->query_gang_illusion_unlocked(13),
			"等级不足");

		// 不在门房时先被路由，再到门房二次进入副本。
		mapping first = BANGPAI_EXTD->enter_bang_illusion(member_a);
		check("不在门房时返回路由指令而非直接进入",
			(string)first["message"]=="move_gate",
			sprintf("result=%O",first));
		member_a->move((object)(
			ROOT+"/gamelib/d/bangpai/illusion_gate"));
		mapping second = BANGPAI_EXTD->enter_bang_illusion(member_a);
		object room = BANGPAI_EXTD->query_bang_illusion_room(13);
		check("门房二次进入后抵达本帮幻境副本且刷出首波妖影",
			(int)second["ok"] && objectp(room) &&
			environment(member_a)==room &&
			sizeof(filter(all_inventory(room),
				lambda(object ob){
					return ob && functionp(ob->is_bangpai_shade) &&
						(int)ob->is_bangpai_shade();
				}))>=8,
			sprintf("ok=%d room=%O",	(int)second["ok"],room));

		// 跨阵营成员与门外汉的攻击门禁。
		member_b->move((object)(
			ROOT+"/gamelib/d/bangpai/illusion_gate"));
		BANGPAI_EXTD->enter_bang_illusion(member_b);
		check("跨阵营成员同样可进入并攻击，外人被拒",
			environment(member_b)==room &&
			sizeof(filter(all_inventory(room),
				lambda(object ob){
					return ob && functionp(ob->is_bangpai_shade) &&
						(int)ob->is_bangpai_shade() &&
						ob->can_be_attacked(member_b);
				}))>0 &&
			!sizeof(filter(all_inventory(room),
				lambda(object ob){
					return ob && functionp(ob->is_bangpai_shade) &&
						(int)ob->is_bangpai_shade() &&
						ob->can_be_attacked(outsider);
				})),
			"门禁判定错误");

		// 击杀记账：真实fight_die路径 + 外人击杀不计。
		object|zero shade_one = 0;
		foreach(all_inventory(room),object ob)
			if(ob && functionp(ob->is_bangpai_shade) &&
			   (int)ob->is_bangpai_shade()){
				shade_one = ob;
				break;
			}
		shade_one->enemy = member_a;
		mixed die_err = catch{ shade_one->fight_die(); };
		check("妖影经fight_die被记入个人击杀且自毁",
			!die_err && !objectp(shade_one),
			die_err ? describe_error(die_err) : "妖影未自毁");
		object|zero shade_two = 0;
		object|zero shade_three = 0;
		foreach(all_inventory(room),object ob){
			if(ob && functionp(ob->query_bangpai_shade_bangid)){
				if(!shade_two)
					shade_two = ob;
				else if(!shade_three)
					shade_three = ob;
			}
			if(shade_two && shade_three)
				break;
		}
		for(int i=0;i<11;i++)
			BANGPAI_EXTD->handle_bang_illusion_npc_death(
				shade_two,member_b);
		shade_three->enemy = outsider;
		shade_three->fight_die();
		string kill_page = BANGPAI_EXTD->query_bang_illusion_page(
			member_a);
		check("个人击杀正确累计且外人击杀不计",
			search(kill_page,"__testunit_illu_a__")!=-1 &&
			search(kill_page,"__testunit_illu_b__")!=-1 &&
			search(kill_page,"1只")!=-1 &&
			search(kill_page,"11只")!=-1 &&
			search(kill_page,"__testunit_illu_out__")<0,
			"战绩页未正确显示个人击杀："+kill_page);

		// 窗口结束：时钟推进后惰性结算。
		int contrib_before = BANGPAI_EXTD->query_contribution(member_a);
		BANGPAI_EXTD->set_illusion_clock_for_test(window_ts+7200);
		mapping settle = BANGPAI_EXTD->bangpai_illusion_settle(13);
		check("周结算发放帮贡与淬炼石（个人击杀口径）",
			(int)settle["ok"] && (int)settle["total_kills"]==12 &&
			BANGPAI_EXTD->query_contribution(member_a)-
				contrib_before==2 &&
			count_items(member_b,"cuilianshi")==1,
			sprintf("settle=%O contrib+%d stones_b=%d",
				settle,
				BANGPAI_EXTD->query_contribution(member_a)-
					contrib_before,
				count_items(member_b,"cuilianshi")));

		// 同周不重复结算。
		mapping resettle = BANGPAI_EXTD->bangpai_illusion_settle(13);
		check("同一自然周不重复结算",
			!(int)resettle["ok"],
			sprintf("resettle=%O",resettle));

		// 窗口外进入被拒。
		BANGPAI_EXTD->set_illusion_clock_for_test(window_ts+7*86400+3600);
		mapping closed = BANGPAI_EXTD->enter_bang_illusion(member_a);
		check("窗口外进入被拒绝",
			!(int)closed["ok"],
			sprintf("result=%O",closed));

		BANGPAI_EXTD->set_illusion_clock_for_test(0);
		BANGPAI_EXTD->set_state_file_for_test(0);
		BANGPAI_EXTD->set_bang_gate_for_test(0);
		rm(DATA_ROOT+"bangpai/ext_state.json.test");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("帮派幻境流程无异常",0,error_desc);
	else
		check("帮派幻境流程无异常",1,"");
	destroy_player(member_a);
	destroy_player(member_b);
	destroy_player(outsider);
	werror("[帮派幻境] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
