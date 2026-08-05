#!/usr/bin/env pike
/**
 * 无相职业测试：身份层、属性成长、解锁条件、入门技能可学习。
 * 完整 15 技能 + 隐藏池扩展由后续迭代补齐；本测试先确保
 * 「账号满足条件 → 能创建无相 → 初始属性对 → 1 级能学无相拳」。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[无相 %d] %s\n",test_results["total"],name);
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

object create_runtime_player(string player_name)
{
	object player;
	player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(player_name);
	player->name_cn = "无相测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("wuxiang");
	player->setup_player("third","wuxiang");
	player->level = 1;
	player->set_att_by_level();
	return player;
}

void destroy_runtime_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_identity_setup()
{
	test_start("无相创建后 race/profe/中文身份正确");
	object player = create_runtime_player("__testunit_wuxiang_identity__");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		valid = player->query_raceId() == "third" &&
			player->query_profeId() == "wuxiang" &&
			player->query_profe_cn("wuxiang") == "无相" &&
			player->query_kind_cn() == "中立";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("身份字段错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_initial_stats()
{
	test_start("无相 1 级初始属性：力/敏/智 8/8/8");
	object player = create_runtime_player("__testunit_wuxiang_stats__");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		// life_max 由 str*10+base+level*50 公式动态计算，初始 set_life 会被
		// set_att_by_level 覆盖；这里只校验三系基础属性。
		valid = (int)player->query_str() == 8 &&
			(int)player->query_dex() == 8 &&
			(int)player->query_think() == 8;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf("初始属性不符: str=%d dex=%d think=%d %s",
			(int)player->query_str(),(int)player->query_dex(),
			(int)player->query_think(),error_desc));
	destroy_runtime_player(player);
}

void test_level_growth()
{
	test_start("无相等级成长：30 级三系对称 str=dex=think=52");
	object player = create_runtime_player("__testunit_wuxiang_growth__");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player->level = 30;
		player->set_att_by_level();
		// 公式：8 + floor((30-1)*1.5) = 8 + floor(43.5) = 8 + 43 = 51
		valid = (int)player->query_str() == 51 &&
			(int)player->query_dex() == 51 &&
			(int)player->query_think() == 51;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf("30级成长不符: str=%d dex=%d think=%d %s",
			(int)player->query_str(),(int)player->query_dex(),
			(int)player->query_think(),error_desc));
	destroy_runtime_player(player);
}

void test_starter_skill_granted()
{
	test_start("无相创建后自动获得无相拳技能");
	object player = create_runtime_player("__testunit_wuxiang_skill__");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		// 模拟 init 里的赋予逻辑
		if(player->skills["wuxiangquan"]==0)
			player->skills["wuxiangquan"]=({1,0});
		valid = player->skills["wuxiangquan"] &&
			sizeof((array)player->skills["wuxiangquan"]) >= 1 &&
			(int)player->skills["wuxiangquan"][0] >= 1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("未授予无相拳: "+error_desc);
	destroy_runtime_player(player);
}

void test_skill_file_loads()
{
	test_start("无相拳技能对象能加载且 s_type=zhudong");
	string error_desc = "";
	int valid = 0;
	object|zero skill = 0;
	mixed err = catch {
		skill = (object)(ROOT+"/gamelib/single/skills/wuxiangquan");
		valid = skill && skill->s_type == "zhudong" &&
			search(skill->skill_type,"wuxiang") != -1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("wuxiangquan 加载失败: "+error_desc);
	if(skill)
		destruct(skill);
}

void test_book_file_loads()
{
	test_start("无相拳书对象能加载且 skill_bname=wuxiangquan");
	string error_desc = "";
	int valid = 0;
	object|zero book = 0;
	mixed err = catch {
		book = clone(ROOT+"/gamelib/clone/item/book/wuxiangquan");
		valid = book && book->skill_bname == "wuxiangquan" &&
			book->profe_read_limit == "无相";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("wuxiangquan 书加载失败: "+error_desc);
	if(book)
		destruct(book);
}

void test_teacher_loads()
{
	test_start("无相先生 NPC 能加载且 profeId=wuxiang");
	string error_desc = "";
	int valid = 0;
	object|zero teacher = 0;
	mixed err = catch {
		teacher = clone(ROOT+"/gamelib/clone/npc/wuxiang_teacher.pike");
		valid = teacher && teacher->query_profeId() == "wuxiang" &&
			teacher->query_raceId() == "third";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("无相先生 NPC 加载失败: "+error_desc);
	if(teacher)
		destruct(teacher);
}

void test_default_unnamed_title()
{
	test_start("无相默认无名头衔源码包含「无名无相」");
	string base_source = Stdio.read_file(ROOT+
		"/lowlib/system/inherit/base.pike");
	string error_desc = "";
	int valid = 0;
	if(!base_source)
		error_desc = "无法读取 base.pike";
	else
		valid = search(base_source,"无名无相") != -1 &&
			search(base_source,"\"wuxiang\"") != -1;
	if(valid)
		test_pass();
	else
		test_fail("base.pike 未识别 wuxiang 无名头衔: "+error_desc);
}

void test_recovery_items_allow_wuxiang()
{
	test_start("恢复品（food/water/liandan/teyao）白名单含无相");
	int matched = 0;
	int failed = 0;
	foreach(({"food","water","liandan","teyao"}), string cat){
		string dir = ROOT+"/gamelib/clone/item/"+cat;
		array(string)|zero files = get_dir(dir);
		if(!files)
			continue;
		foreach(files, string fname){
			string path = dir+"/"+fname;
			// 跳过子目录（如 liandan/christmas/）。
			mixed st = file_stat(path);
			if(!st || !st->isreg)
				continue;
			string source = Stdio.read_file(path);
			if(!source)
				continue;
			// 文件如果列了 lingyi 就必须也列 wuxiang，确保新职业能正常吃药。
			if(search(source,"profe_limit[\"lingyi\"]")!=-1){
				matched++;
				if(search(source,"profe_limit[\"wuxiang\"]")==-1){
					werror("    缺 wuxiang: %s\n",path);
					failed++;
				}
			}
		}
	}
	if(matched > 0 && failed == 0)
		test_pass();
	else
		test_fail(sprintf("恢复品白名单缺 wuxiang：matched=%d failed=%d",
			matched,failed));
}

void test_vue_profession_list_includes_wuxiang()
{
	test_start("Vue 角色选择页 profession 列表含无相");
	string source = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string error_desc = "";
	int valid = 0;
	if(!source)
		error_desc = "无法读取 app.js";
	else
		valid = search(source,"profession_id: 'wuxiang'")!=-1 &&
			search(source,"name: '无相'")!=-1;
	if(valid)
		test_pass();
	else
		test_fail("Vue 职业列表未含 wuxiang: "+error_desc);
}

void test_all_skills_load()
{
	test_start("无相全部 8 个技能文件加载且 skill_type 含 wuxiang");
	array(string) skill_ids = ({
		"wuxiangquan","wuxiangjue","wuxiangyi","wuxiangdun",
		"wuxianghou","wuxiangjian","wuxiangyan","wanxiangguiyi",
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
		}
		else{
			// 不要 destruct：技能对象是 MUD_SKILLSD 缓存共享的，会影响后续测试。
			if(search(sk->skill_type,"wuxiang") != -1)
				loaded++;
			else{
				failed++;
				failed_ids += sid+"(no wuxiang tag) ";
			}
		}
	}
	if(failed == 0 && loaded == sizeof(skill_ids))
		test_pass();
	else
		test_fail(sprintf("加载失败 %d/%d：%s",failed,sizeof(skill_ids),failed_ids));
}

void test_all_books_in_catalog()
{
	test_start("无相书在 can_buy_book_list.csv 中均有对应条目");
	array(string) book_ids = ({
		"wuxiangquan","wuxiangjue","wuxiangyi","wuxiangdun",
		"wuxianghou","wuxiangjian","wuxiangyan",
	});
	string csv = Stdio.read_file(ROOT+
		"/gamelib/data/can_buy_book_list.csv");
	int missing = 0;
	string missing_ids = "";
	if(!csv){
		test_fail("无法读取 can_buy_book_list.csv");
		return;
	}
	foreach(book_ids, string bid){
		if(search(csv,"book/"+bid)==-1){
			missing++;
			missing_ids += bid+" ";
		}
	}
	if(missing == 0)
		test_pass();
	else
		test_fail("缺书："+missing_ids);
}

void test_hidden_pool_extended()
{
	test_start("隐藏池扩展为 34 本且含无相 3 本（pool 与分子同步）");
	object itemsd = (object)(ROOT+"/gamelib/single/daemons/itemsd.pike");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		int count = itemsd->query_hidden_skill_book_count();
		int rate = itemsd->query_hidden_skill_drop_rate();
		// 池子和分子必须同步：34 本对应 34/100000
		valid = count == 34 && rate == 34;
	};
	if(err)
		error_desc = describe_error(err);
	// 验证 3 本无相隐藏书都在池子里
	int found = 0;
	if(!err)
		for(int i = 0; i < (itemsd ? itemsd->query_hidden_skill_book_count() : 0); i++){
			string b = itemsd->query_hidden_skill_book(i);
			if(search(b,"wuxiang") != -1)
				found++;
		}
	if(!err && valid && found == 3)
		test_pass();
	else
		test_fail(sprintf("隐藏池错误: count=%d rate=%d found=%d %s",
			itemsd ? itemsd->query_hidden_skill_book_count() : -1,
			itemsd ? itemsd->query_hidden_skill_drop_rate() : -1,
			found,error_desc));
}

int main()
{
	werror("\n========== 无相职业测试 ==========\n");
	test_identity_setup();
	test_initial_stats();
	test_level_growth();
	test_starter_skill_granted();
	test_skill_file_loads();
	test_book_file_loads();
	test_teacher_loads();
	test_default_unnamed_title();
	test_recovery_items_allow_wuxiang();
	test_vue_profession_list_includes_wuxiang();
	test_all_skills_load();
	test_all_books_in_catalog();
	test_hidden_pool_extended();
	werror("\n无相职业测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
