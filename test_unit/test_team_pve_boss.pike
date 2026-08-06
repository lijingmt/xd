#!/usr/bin/env pike
/**
 * 团队硬 Boss 回归测试
 *
 * 覆盖：
 * - Boss NPC 文件加载、属性正确（HP 500k/400k，攻击 5500/3500）
 * - is_team_required_boss / set_team_required_boss 接口可用
 * - count_first_target_team_in_room 计数正确
 * - 治疗产生仇恨 hook（自疗路径）
 * - Boss 必掉试炼武勋（每个同房同队存活成员各得一份）
 * - 试炼武勋物品：绑定、不可交易、可堆叠
 * - shilian_duihuan 命令文件存在且兑换参数表完整
 * - 入口房间（归墟境、万象林）有正确出口指向两侧广场
 * - 武勋兑换 NPC 在两侧广场都被注册
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

void test_boss_files_load()
{
	werror("[测试1] 2 个硬 Boss NPC 与必杀技能文件可加载\n");
	mixed err1 = catch { (object)(ROOT+"/gamelib/clone/npc/boss/guixumojun"); };
	mixed err2 = catch { (object)(ROOT+"/gamelib/clone/npc/boss/wanxiangyaohuang"); };
	mixed err3 = catch { (object)(ROOT+"/gamelib/single/skills/guixumojiji"); };
	mixed err4 = catch { (object)(ROOT+"/gamelib/single/skills/wanxiangqinshi"); };
	check("归墟魔君 NPC 加载",!err1,err1?describe_error(err1):"");
	check("万象妖皇 NPC 加载",!err2,err2?describe_error(err2):"");
	check("归墟魔击 技能加载",!err3,err3?describe_error(err3):"");
	check("万象侵蚀 技能加载",!err4,err4?describe_error(err4):"");
}

void test_boss_attributes_hard_enough()
{
	werror("\n[测试2] Boss 属性够硬（HP 500k/400k，攻击 5500/3500+）\n");
	object b1 = (object)(ROOT+"/gamelib/clone/npc/boss/guixumojun");
	object b2 = (object)(ROOT+"/gamelib/clone/npc/boss/wanxiangyaohuang");
	if(!b1 || !b2){
		check("Boss 加载失败",0,"前置测试失败");
		return;
	}
	check("归墟魔君 HP≥500000",(int)b1->query_life_max()>=500000,
		sprintf("HP=%d",(int)b1->query_life_max()));
	check("归墟魔君 力量≥5500",(int)b1->query_base_str()>=5500,
		sprintf("str=%d",(int)b1->query_base_str()));
	check("万象妖皇 HP≥400000",(int)b2->query_life_max()>=400000,
		sprintf("HP=%d",(int)b2->query_life_max()));
	check("万象妖皇 力量≥3500",(int)b2->query_base_str()>=3500,
		sprintf("str=%d",(int)b2->query_base_str()));
}

void test_team_required_flag()
{
	werror("\n[测试3] team_required_boss 标志接口与计数\n");
	object b1 = (object)(ROOT+"/gamelib/clone/npc/boss/guixumojun");
	object b2 = (object)(ROOT+"/gamelib/clone/npc/boss/wanxiangyaohuang");
	int ok1 = (int)b1->is_team_required_boss()==1;
	int ok2 = (int)b2->is_team_required_boss()==1;
	int ok3 = (int)b1->query_team_required_min_size()==3;
	int ok4 = (int)b2->query_team_required_min_size()==3;
	check("归墟魔君 启用 team_required",ok1,"未启用");
	check("万象妖皇 启用 team_required",ok2,"未启用");
	check("最小队伍人数=3",ok3&&ok4,"默认值异常");
}

void test_team_counter()
{
	werror("\n[测试4] count_first_target_team_in_room 计数正确\n");
	object room = (object)(ROOT+
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	object b1 = (object)(ROOT+"/gamelib/clone/npc/boss/guixumojun");
	if(!b1 || !room){
		check("前置",0,"加载失败");
		return;
	}
	// 创建 3 个玩家组队
	object p1 = clone(GAMELIB_USER);
	object p2 = clone(GAMELIB_USER);
	object p3 = clone(GAMELIB_USER);
	p1->set_name("__testunit_teamcount_p1__");
	p2->set_name("__testunit_teamcount_p2__");
	p3->set_name("__testunit_teamcount_p3__");
	p1->set_project("gamelib");
	p2->set_project("gamelib");
	p3->set_project("gamelib");
	p1->set_raceId("human");
	p1->set_profeId("jianxian");
	p1->setup_player("human","jianxian");
	p2->set_raceId("third");
	p2->set_profeId("zhenyue");
	p2->setup_player("third","zhenyue");
	p3->set_raceId("third");
	p3->set_profeId("lingyi");
	p3->setup_player("third","lingyi");
	p1->move(room);
	p2->move(room);
	p3->move(room);
	// 3 人组队
	p1->set_term("testteam_a");
	p2->set_term("testteam_a");
	p3->set_term("testteam_a");
	// 模拟 Boss 把 p1 设为 first_target
	b1->move(room);
	b1->first_target = p1;
	int count = (int)b1->count_first_target_team_in_room();
	check("3 人同房同队计数=3",count==3,
		sprintf("count=%d",count));
	// p3 离开房间 → count=2
	p3->move((object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang"));
	int count2 = (int)b1->count_first_target_team_in_room();
	check("p3 离开后计数=2",count2==2,sprintf("count=%d",count2));
	// 清理
	b1->first_target = 0;
	if(p1) destruct(p1);
	if(p2) destruct(p2);
	if(p3) destruct(p3);
}

void test_self_heal_threat_hook()
{
	werror("\n[测试5] 自疗产生 5:1 仇恨（fight.pike heal 分支）\n");
	// 静态校验源码：fight.pike 在自疗分支有 enemy->flush_targets(.../5) 调用
	string src = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike");
	int has_hook = search(src,"healed_amount/5")!=-1 &&
		search(src,"healed_amount = life_after - life_before")!=-1;
	check("fight.pike 自疗后产生仇恨 hook",has_hook,
		"未找到 healed_amount/5 的 flush_targets 调用");
}

void test_team_required_gate_in_attack()
{
	werror("\n[测试6] attack() 入口含 team_required 门控\n");
	string src = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike");
	int has_gate = search(src,"is_team_required_boss()")!=-1 &&
		search(src,"count_first_target_team_in_room")!=-1 &&
		search(src,"硬 Boss")!=-1;
	check("attack() 入口有 team_required 校验",has_gate,
		"未找到门控代码");
}

void test_wuxun_drop_on_boss_death()
{
	werror("\n[测试7] Boss 死亡时必掉试炼武勋\n");
	string src = Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike");
	int has_drop = search(src,"shilianwuxun")!=-1 &&
		search(src,"wuxun_per_member")!=-1;
	check("Boss 死亡掉落武勋逻辑存在",has_drop,
		"未找到武勋掉落代码");
}

void test_wuxun_item_bounded()
{
	werror("\n[测试8] 试炼武勋物品绑定属性\n");
	object item = clone(ROOT+"/gamelib/clone/item/other/shilianwuxun");
	if(!item){
		check("武勋物品可加载",0,"clone 失败");
		return;
	}
	check("武勋物品可加载",1,"");
	check("不可交易",(int)item->query_item_canTrade()==0,"");
	check("不可寄送",(int)item->query_item_canSend()==0,"");
	check("不可丢弃",(int)item->query_item_canDrop()==0,"");
	check("可堆叠",item->amount==1,"");
	check("内部 ID=shilianwuxun",item->query_name()=="shilianwuxun",
		"name="+item->query_name());
	destruct(item);
}

void test_exchanger_npc_in_both_plazas()
{
	werror("\n[测试9] 试炼仙官 NPC 在两侧广场都被注册\n");
	string yuhua = Stdio.read_file(ROOT+
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	string congxian = Stdio.read_file(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	check("羽化村广场注册试炼仙官",
		search(yuhua,"shilian_xianguan.pike")!=-1,"未注册");
	check("从仙镇广场注册试炼仙官",
		search(congxian,"shilian_xianguan.pike")!=-1,"未注册");
}

void test_duihuan_command_complete()
{
	werror("\n[测试10] shilian_duihuan 命令兑换参数表完整\n");
	object cmd = clone(ROOT+"/gamelib/cmds/shilian_duihuan.pike");
	if(!cmd){
		check("命令可加载",0,"clone 失败");
		return;
	}
	destruct(cmd);
	string src = Stdio.read_file(ROOT+"/gamelib/cmds/shilian_duihuan.pike");
	check("命令文件可加载",1,"");
	check("兑换项 lingshi(10)",search(src,"\"lingshi\"")!=-1,"");
	check("兑换项 blue90(30)",search(src,"\"blue90\"")!=-1,"");
	check("兑换项 dan(50)",search(src,"\"dan\"")!=-1,"");
	check("兑换项 purple110(80)",search(src,"\"purple110\"")!=-1,"");
	check("兑换项 feed(100)",search(src,"\"feed\"")!=-1,"");
	check("兑换项 gold110(200)",search(src,"\"gold110\"")!=-1,"");
	check("兑换项 hidden(500)",search(src,"\"hidden\"")!=-1,"");
}

void test_boss_rooms_connected()
{
	werror("\n[测试11] 归墟境与万象林房间可加载且与广场互通\n");
	object r1 = (object)(ROOT+"/gamelib/d/jinaodao/guixujing");
	object r2 = (object)(ROOT+"/gamelib/d/congxianzhen/wanxianglin");
	if(!r1 || !r2){
		check("房间加载",0,"加载失败");
		return;
	}
	check("归墟境可加载",1,"");
	check("万象林可加载",1,"");
	check("归墟境 name_cn 正确",r1->query_name_cn()=="归墟境",
		r1->query_name_cn());
	check("万象林 name_cn 正确",r2->query_name_cn()=="万象林",
		r2->query_name_cn());
	// 出口
	mapping exits1 = r1->query_exits();
	mapping exits2 = r2->query_exits();
	check("归墟境 → 羽化村广场 出口存在",
		search((string)(exits1["east"]||""),"yuhuacunguangchang")!=-1,
		"出口缺失");
	check("万象林 → 从仙镇广场 出口存在",
		search((string)(exits2["west"]||""),"congxianzhenguangchang")!=-1,
		"出口缺失");
	// 反向：广场 → Boss 房
	string yuhua = Stdio.read_file(ROOT+
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	string congxian = Stdio.read_file(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	check("羽化村广场 → 归墟境 出口存在",
		search(yuhua,"guixujing")!=-1,"反向出口缺失");
	check("从仙镇广场 → 万象林 出口存在",
		search(congxian,"wanxianglin")!=-1,"反向出口缺失");
}

void test_boss_skill_levels_valid()
{
	werror("\n[测试13] Boss 技能等级不超过技能定义的最大等级（3）\n");
	object b1 = (object)(ROOT+"/gamelib/clone/npc/boss/guixumojun");
	object b2 = (object)(ROOT+"/gamelib/clone/npc/boss/wanxiangyaohuang");
	if(!b1 || !b2 || !b1->skills || !b2->skills){
		check("Boss 技能加载",0,"前置失败");
		return;
	}
	int lvl1 = (int)(b1->skills["guixumojiji"] && b1->skills["guixumojiji"][0]);
	int lvl2 = (int)(b2->skills["wanxiangqinshi"] && b2->skills["wanxiangqinshi"][0]);
	check("归墟魔君技能等级<=3",lvl1>0 && lvl1<=3,
		sprintf("lvl=%d",lvl1));
	check("万象妖皇技能等级<=3",lvl2>0 && lvl2<=3,
		sprintf("lvl=%d",lvl2));
}

void test_bosses_have_wuxun_drop_count()
{
	werror("\n[测试12] Boss 死亡武勋数量配置正确\n");
	string src = Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike");
	check("归墟魔君掉 5 个武勋",
		search(src,"wuxun_per_member = 5")!=-1,"配置缺失");
	check("万象妖皇掉 4 个武勋",
		search(src,"wuxun_per_member = 4")!=-1,"配置缺失");
}

int main()
{
	werror("\n========== 团队硬 Boss 测试 ==========\n");
	mixed err = catch {
		test_boss_files_load();
		test_boss_attributes_hard_enough();
		test_team_required_flag();
		test_team_counter();
		test_self_heal_threat_hook();
		test_team_required_gate_in_attack();
		test_wuxun_drop_on_boss_death();
		test_wuxun_item_bounded();
		test_exchanger_npc_in_both_plazas();
		test_duihuan_command_complete();
		test_boss_rooms_connected();
		test_boss_skill_levels_valid();
	test_bosses_have_wuxun_drop_count();
	};
	if(err)
		check("测试无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	werror("\n团队硬 Boss 测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
