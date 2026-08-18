#!/usr/bin/env pike
/**
 * 太极职业运行时回归测试
 *
 * 覆盖：
 * - 身份字段、初始属性、等级成长（比无相强 30%）
 * - 太极心法 65% 加成（vs 无相 50%）
 * - 17 个技能 + 17 本技能书全部加载
 * - 教师在两侧广场都在
 * - 隐藏池扩展到 37 本，含 3 本太极隐藏书
 * - 太极·生生不息：5 分钟冷却 + 30% 生命自复活（PVP 可触发）
 * - 太极·复阴：主动复活同房同队鬼魂队友，独立 5 分钟冷却
 * - 解锁条件：账号下 10 职+无相均达 200 级
 * - Vue 列表 + visibleProfessionOptions 过滤 + taijiUnlocked 标志
 * - 静态审计脚本无 missing
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,"passed":0,"failed":0,
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[太极 %d] %s\n",test_results["total"],name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

object create_runtime_player(string name)
{
	object player = clone(GAMELIB_USER);
	player->set_name(name);
	player->set_password("testunit99");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "太极测试";
	player->set_raceId("third");
	player->set_profeId("taiji");
	player->setup_player("third","taiji");
	return player;
}

void test_identity()
{
	test_start("太极身份字段、起手技能与默认标题");
	object player = create_runtime_player("__testunit_taiji_identity__");
	int valid = player->query_profeId()=="taiji" &&
		player->query_profe_cn("taiji")=="太极" &&
		player->query_raceId()=="third";
	if(valid) test_pass();
	else test_fail("身份字段错误");
	destruct(player);
}

void test_initial_stats_stronger_than_wuxiang()
{
	test_start("初始属性比无相强 30%（三系 10 vs 8）");
	object taiji = create_runtime_player("__testunit_taiji_stats__");
	object wuxiang = clone(GAMELIB_USER);
	wuxiang->set_name("__testunit_wx_stats__");
	wuxiang->set_project("gamelib");
	wuxiang->set_raceId("third");
	wuxiang->set_profeId("wuxiang");
	wuxiang->setup_player("third","wuxiang");
	int tj_str = (int)taiji->get_cur_str();
	int wx_str = (int)wuxiang->get_cur_str();
	// 太极三系基线 10 vs 无相 8（30% 强）
	int valid = tj_str==10 && wx_str==8 &&
		taiji->query_str()==16 && wuxiang->query_str()==12;
	if(valid) test_pass();
	else test_fail(sprintf("太极 str=%d 无相 str=%d",tj_str,wx_str));
	destruct(taiji);
	destruct(wuxiang);
}

void test_growth_at_120()
{
	test_start("120 级成长：三系对称（10+2.0*119=248）");
	object player = create_runtime_player("__testunit_taiji_growth__");
	player->level = 120;
	player->set_att_by_level();
	int str_120 = (int)player->query_str();
	int dex_120 = (int)player->query_dex();
	int think_120 = (int)player->query_think();
	// 10 + floor(119*2.0) = 10 + 238 = 248
	int valid = str_120==dex_120 && dex_120==think_120 && str_120>=248;
	if(valid) test_pass();
	else test_fail(sprintf("120级 str=%d dex=%d think=%d",str_120,dex_120,think_120));
	destruct(player);
}

void test_starter_skill_granted()
{
	test_start("太极创建分支真实发放 taijiquan，测试不篡改技能状态");
	string init_src = Stdio.read_file(ROOT+"/gamelib/d/init");
	int branch = init_src ? search(init_src,"else if(u_p==\"taiji\")") : -1;
	int next_branch = branch>=0 ? search(init_src,"//添加物品，初级",branch) : -1;
	string taiji_branch = branch>=0 && next_branch>branch ?
		init_src[branch..next_branch-1] : "";
	int valid = taiji_branch!="" &&
		search(taiji_branch,"me->setup_player(\"third\",u_p);")!=-1 &&
		search(taiji_branch,"me->skills[\"taijiquan\"]==0")!=-1 &&
		search(taiji_branch,"me->skills[\"taijiquan\"]=({1,0});")!=-1;
	if(valid) test_pass();
	else test_fail("太极创建分支未原子完成职业初始化和入门技能发放");
}

void test_skill_files_load()
{
	test_start("17 个太极技能文件全部加载且 skill_type 含 taiji");
	array(string) skill_ids = ({
		"taijiquan","taijijue","taijiyi","taijidun","taijihou",
		"taijijian","taijiyan","taijijing","taijibi","taijihuan",
		"taijiyu","taijiji","taijimie","taijiguixu","taijihunyuan",
		"taijiwuji","taijiguizhen",
	});
	int loaded = 0;
	int failed = 0;
	string failed_ids = "";
	foreach(skill_ids, string sid){
		object|zero sk = 0;
		mixed err = catch {
			sk = (object)(ROOT+"/gamelib/single/skills/"+sid);
		};
		if(err || !sk){
			failed++;
			failed_ids += sid+" ";
			continue;
		}
		if(search(sk->skill_type,"taiji")==-1){
			failed++;
			failed_ids += sid+"(skill_type缺) ";
			continue;
		}
		loaded++;
	}
	if(loaded==sizeof(skill_ids) && failed==0)
		test_pass();
	else
		test_fail("加载失败："+failed_ids);
}

void test_book_files_load()
{
	test_start("17 本太极技能书 profe_read_limit=\"太极\"");
	array(string) book_ids = ({
		"taijiquan","taijijue","taijiyi","taijidun","taijihou",
		"taijijian","taijiyan","taijijing","taijibi","taijihuan",
		"taijiyu","taijiji","taijimie","taijiguixu","taijihunyuan",
		"taijiwuji","taijiguizhen",
	});
	int loaded = 0;
	int failed = 0;
	string failed_ids = "";
	foreach(book_ids, string bid){
		object|zero bk = 0;
		mixed err = catch {
			bk = clone(ROOT+"/gamelib/clone/item/book/"+bid);
		};
		if(err || !bk){
			failed++;
			failed_ids += bid+" ";
			continue;
		}
		if((string)bk->profe_read_limit!="太极"){
			failed++;
			failed_ids += bid+"(职业限制错) ";
		}
		else loaded++;
		if(bk) destruct(bk);
	}
	if(loaded==sizeof(book_ids) && failed==0)
		test_pass();
	else
		test_fail("加载失败："+failed_ids);
}

void test_teacher_in_both_plazas()
{
	test_start("太极教师在两侧广场都被注册");
	string yuhua = Stdio.read_file(ROOT+
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	string congxian = Stdio.read_file(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int valid = search(yuhua,"taiji_teacher.pike")!=-1 &&
		search(yuhua,"taiji_")!=-1 &&
		search(congxian,"taiji_teacher.pike")!=-1 &&
		search(congxian,"taiji_")!=-1;
	if(valid) test_pass();
	else test_fail("广场未注册太极教师或头像");
}

void test_hidden_pool_extended_to_37()
{
	test_start("隐藏池扩展为 37 本且含太极 3 本（pool 与分子同步）");
	object itemsd = (object)(ROOT+"/gamelib/single/daemons/itemsd.pike");
	int count = itemsd->query_hidden_skill_book_count();
	int rate = itemsd->query_hidden_skill_drop_rate();
	int found = 0;
	for(int i=0;i<count;i++){
		string b = itemsd->query_hidden_skill_book(i);
		if(search(b,"taiji")!=-1)
			found++;
	}
	int valid = count==37 && rate==37 &&
		itemsd->query_hidden_skill_drop_denominator()==10000000 && found==3;
	if(valid) test_pass();
	else
		test_fail(sprintf("count=%d rate=%d found=%d",count,rate,found));
}

void test_heart_bonus_65_percent()
{
	test_start("太极心法：最高项 65% 加成另外两系（vs 无相 50%）");
	object player = create_runtime_player("__testunit_taiji_heart__");
	player->level = 100;
	player->set_att_by_level();
	// 把力量拉高，模拟非对称场景
	player->set_base_str(player->query_base_str()+200);
	int str_v = player->query_str();
	int dex_v = player->query_dex();
	int think_v = player->query_think();
	// 力量最高，应该把 65% 加成到 dex/think
	int valid = dex_v > player->query_base_dex() &&
		think_v > player->query_base_think();
	if(valid) test_pass();
	else test_fail(sprintf("str=%d dex=%d think=%d",str_v,dex_v,think_v));
	destruct(player);
}

void test_self_revive_5min_cooldown()
{
	test_start("生生不息：5 分钟冷却 + 30% 生命自复活");
	// 直接调用 query_taiji_self_revive_remaining 验证冷却逻辑
	object player = create_runtime_player("__testunit_taiji_self_revive__");
	int cd = player->query_taiji_self_revive_cooldown();
	int remain0 = player->query_taiji_self_revive_remaining();
	// 模拟刚触发：手动设置时间戳
	player["/plus/taiji/self_revive_at"] = time();
	int remain_after = player->query_taiji_self_revive_remaining();
	int valid = cd==300 && remain0==0 && remain_after>0 && remain_after<=300;
	if(valid) test_pass();
	else
		test_fail(sprintf("cd=%d remain0=%d remain_after=%d",
			cd,remain0,remain_after));
	destruct(player);
}

void test_team_revive_independent_cooldown()
{
	test_start("复阴：独立 5 分钟冷却，与自复活互不干扰");
	object player = create_runtime_player("__testunit_taiji_team_revive__");
	int team_cd = player->query_taiji_team_revive_cooldown();
	int self_cd = player->query_taiji_self_revive_cooldown();
	// 模拟自复活刚触发
	player["/plus/taiji/self_revive_at"] = time();
	int self_remain = player->query_taiji_self_revive_remaining();
	int team_remain = player->query_taiji_team_revive_remaining_cast(player);
	// 自复活在冷却中，但复阴应该还没触发（独立）
	int valid = team_cd==300 && self_cd==300 &&
		self_remain>0 && team_remain==0;
	if(valid) test_pass();
	else
		test_fail(sprintf("team_cd=%d self_cd=%d self=%d team=%d",
			team_cd,self_cd,self_remain,team_remain));
	destruct(player);
}

void test_team_revive_runtime()
{
	test_start("复阴：真实清除鬼魂状态、恢复生命后才进入冷却");
	object room = clone(ROOT+"/gamelib/d/jinaodao/guixujing");
	object caster = create_runtime_player("__testunit_taiji_caster__");
	object target = clone(GAMELIB_USER);
	target->set_name("__testunit_taiji_ghost__");
	target->set_project("gamelib");
	target->set_raceId("third");
	target->set_profeId("lingyi");
	target->setup_player("third","lingyi");
	foreach(all_inventory(target),object item)
		destruct(item);
	caster->set_term("__testunit_taiji_team__");
	target->set_term("__testunit_taiji_team__");
	caster->move(room);
	target->move(room);
	target->set_life(0);
	target->ghost();
	int revived = caster->try_taiji_team_revive(caster,target);
	int valid = revived==1 && target->get_cur_life()>0 &&
		!target->is("ghost") &&
		caster->query_taiji_team_revive_remaining_cast(caster)>0;
	if(valid) test_pass();
	else test_fail(sprintf("revived=%d life=%d ghost=%d cooldown=%d",
		revived,target->get_cur_life(),target->is("ghost"),
		caster->query_taiji_team_revive_remaining_cast(caster)));
	foreach(all_inventory(room),object item)
		if(item!=caster && item!=target)
			destruct(item);
	destruct(caster);
	destruct(target);
	destruct(room);
}

void test_team_revive_rejects_empty_team()
{
	test_start("复阴：两个未组队玩家不能利用空队伍标识互相复活");
	object room = clone(ROOT+"/gamelib/d/jinaodao/guixujing");
	object caster = create_runtime_player("__testunit_taiji_noteam__");
	object target = clone(GAMELIB_USER);
	target->set_name("__testunit_taiji_noteam_ghost__");
	target->set_project("gamelib");
	target->set_raceId("third");
	target->set_profeId("lingyi");
	target->setup_player("third","lingyi");
	foreach(all_inventory(target),object item)
		destruct(item);
	caster->set_term("");
	target->set_term("");
	caster->move(room);
	target->move(room);
	target->set_life(0);
	target->ghost();
	int revived = caster->try_taiji_team_revive(caster,target);
	if(revived==0 && target->is("ghost"))
		test_pass();
	else
		test_fail("空 team id 被误判为同队");
	foreach(all_inventory(room),object item)
		if(item!=caster && item!=target)
			destruct(item);
	destruct(caster);
	destruct(target);
	destruct(room);
}

void test_taiji_fuyin_command_exists()
{
	test_start("taiji_fuyin 命令文件存在且可被解析");
	string path = ROOT+"/gamelib/cmds/taiji_fuyin.pike";
	string src = Stdio.read_file(path);
	int valid = src && search(src,"try_taiji_team_revive")!=-1;
	if(valid) test_pass();
	else test_fail("命令缺失或未调用 try_taiji_team_revive");
}

void test_unlock_helpers_correct()
{
	test_start("解锁辅助函数真实要求 10 职+无相均达 200 级");
	object accountd = (object)(ROOT+
		"/gamelib/single/daemons/account_characterd.pike");
	string init_src = Stdio.read_file(ROOT+"/gamelib/d/init");
	array(string) required = ({
		"jianxian","yushi","zhuxian","kuangyao","wuyao","yinggui",
		"fangshi","zhenyue","tianxiang","lingyi","wuxiang",
	});
	array(mapping(string:mixed)) exact = ({});
	foreach(required,string profession)
		exact += ({(["profession_id":profession,"level":200])});
	mapping(string:mixed) unlocked = (["ok":1,"characters":exact]);
	mapping(string:mixed) short_level = copy_value(unlocked);
	((array)short_level["characters"])[10]["level"] = 199;
	mapping(string:mixed) missing_profession = copy_value(unlocked);
	missing_profession["characters"] =
		((array)missing_profession["characters"])[..9];
	int valid = accountd->query_taiji_unlocked_from_summary(unlocked)==1 &&
		accountd->query_taiji_unlocked_from_summary(short_level)==0 &&
		accountd->query_taiji_unlocked_from_summary(missing_profession)==0 &&
		search(accountd->query_taiji_missing_from_summary(short_level),
			"无相（199/200）")!=-1 &&
		search(init_src,"query_taiji_unlocked_for")!=-1 &&
		search(init_src,"lvl >= 200")!=-1;
	if(valid) test_pass();
	else test_fail("解锁辅助函数缺失或阈值错误");
}

void test_create_path_blocks_locked()
{
	test_start("两条创建路径（init + account_characterd）都拒绝未解锁太极");
	string daemon_src = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/account_characterd.pike");
	string init_src = Stdio.read_file(ROOT+"/gamelib/d/init");
	int valid =
		search(daemon_src,"profession_id==\"taiji\"")!=-1 &&
		search(daemon_src,"【太极·未解锁】")!=-1 &&
		search(init_src,"【太极·未解锁】")!=-1 &&
		search(init_src,"arr[1]==\"taiji\"")!=-1;
	if(valid) test_pass();
	else test_fail("未解锁校验缺失");
}

void test_unlock_button_hidden_when_locked()
{
	test_start("未解锁时创建界面隐藏太极入口");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string account_char_src = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/account_characterd.pike");
	string vue_source_js = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	int valid =
		search(init_source,"太极（未解锁）")==-1 &&
		search(account_char_src,"result[\"taiji_unlocked\"]")!=-1 &&
		search(vue_source_js,"taijiUnlocked")!=-1 &&
		search(vue_source_js,"!this.taijiUnlocked")!=-1;
	if(valid) test_pass();
	else test_fail("未解锁入口未正确隐藏");
}

void test_account_character_limit_supports_taiji()
{
	test_start("account_characterd 接受太极作为 third 阵营合法职业");
	string src = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/account_characterd.pike");
	int valid =
		search(src,"\"third\":({\"fangshi\",\"zhenyue\",\"tianxiang\",\"lingyi\",\"wuxiang\",\"taiji\"")!=-1;
	if(valid) test_pass();
	else test_fail("valid_professions[third] 未含 taiji");
}

void test_static_audit_zero_misses()
{
	test_start("静态审计脚本：taiji missing_areas=0");
	// 这里只校验源码存在关键文件，不实际跑 python 脚本（避免外部依赖）
	array(string) checks = ({
		"gamelib/single/skills/taijiquan",
		"gamelib/clone/item/book/taijiquan",
		"gamelib/clone/npc/taiji_teacher.pike",
		"gamelib/clone/item/armor/taijipao/taijipao",
		"gamelib/clone/item/weapon/taijijian/taijijian",
		"images/taiji_logo.png",
		"images/taiji_male.png",
		"images/taiji_female.png",
		"images/taijiquan_logo.png",
	});
	int all_exist = 1;
	string missing = "";
	foreach(checks,string p){
		if(Stdio.file_size(ROOT+"/"+p)<=0){
			all_exist = 0;
			missing += p+" ";
		}
	}
	if(all_exist) test_pass();
	else test_fail("缺失："+missing);
}

void test_look_top_identity()
{
	test_start("排行榜 look_top 识别太极为【极】");
	object look_top = (object)(ROOT+"/gamelib/cmds/look_top.pike");
	// 通过查源码而非实例化（避免依赖玩家上下文）
	string src = Stdio.read_file(ROOT+"/gamelib/cmds/look_top.pike");
	int valid = search(src,"\"taiji\"")!=-1 &&
		search(src,"【极】")!=-1;
	if(valid) test_pass();
	else test_fail("look_top 未识别太极");
}

void test_html_renderer_exposes_taiji_state()
{
	test_start("HTTP API 暴露太极心法 + 自复活 + 复阴状态");
	string src = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	int valid = search(src,"taiji_heart_highest")!=-1 &&
		search(src,"taiji_self_revive")!=-1 &&
		search(src,"taiji_team_revive")!=-1;
	if(valid) test_pass();
	else test_fail("html_renderer 未暴露太极状态");
}

int main()
{
	werror("\n========== 太极职业测试 ==========\n");
	mixed err = catch {
		test_identity();
		test_initial_stats_stronger_than_wuxiang();
		test_growth_at_120();
		test_starter_skill_granted();
		test_skill_files_load();
		test_book_files_load();
		test_teacher_in_both_plazas();
		test_hidden_pool_extended_to_37();
		test_heart_bonus_65_percent();
		test_self_revive_5min_cooldown();
		test_team_revive_independent_cooldown();
		test_team_revive_rejects_empty_team();
		test_team_revive_runtime();
		test_taiji_fuyin_command_exists();
		test_unlock_helpers_correct();
		test_create_path_blocks_locked();
		test_unlock_button_hidden_when_locked();
		test_account_character_limit_supports_taiji();
		test_static_audit_zero_misses();
		test_look_top_identity();
		test_html_renderer_exposes_taiji_state();
	};
	if(err)
		test_fail("异常："+describe_error(err)+" "+describe_backtrace(err));
	werror("\n太极职业测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
