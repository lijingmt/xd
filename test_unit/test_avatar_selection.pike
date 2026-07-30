#!/usr/bin/env pike
/**
 * 人物头像选择回归测试
 *
 * 覆盖：
 * - 方士缺少 sex 字段时仍能打开头像列表
 * - 人类、中立、妖魔的头像目录与数量
 * - set_pic_ok 与 user_pic 不一致时自动恢复
 * - 非法头像参数不能写入人物档案
 * - 羽化村、从仙镇两侧广场行为一致
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total": 0,
	"passed": 0,
	"failed": 0,
]);

void test_start(string test_name)
{
	test_results["total"]++;
	werror("\n[头像选择测试 %d] %s\n",
		test_results["total"], test_name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n", reason);
}

object create_test_player(string raceId, string sex)
{
	object player = clone(GAMELIB_USER);
	player->set_name("");
	player->name_cn = "测试方士";
	player->sid = "testunit";
	player->set_project("gamelib");
	player->set_raceId(raceId);
	if(raceId=="third")
		player->set_profeId("fangshi");
	else if(raceId=="human")
		player->set_profeId("jianxian");
	else
		player->set_profeId("kuangyao");
	player->setup_player(raceId,player->query_profeId());
	if(sex && sex!="")
		player->sex = sex;
	return player;
}

void destroy_test_player(object|zero player)
{
	if(player)
		destruct(player);
}

string query_player_output(object player)
{
	mapping spliter = player->query_spliter();
	if(spliter && spliter["text"])
		return spliter["text"];
	return "";
}

void test_catalogs()
{
	test_start("头像目录按阵营和性别生成");
	object yuhua = (object)(ROOT +
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	object congxian = (object)(ROOT +
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero fangshi = 0;
	object|zero female = 0;
	object|zero monst = 0;
	array(string) yuhua_choices = ({});
	array(string) congxian_choices = ({});
	array(string) female_choices = ({});
	array(string) monst_choices = ({});
	int same_choices = 1;
	string error_desc = "";
	mixed err = catch {
		fangshi = create_test_player("third","");
		female = create_test_player("third","female");
		monst = create_test_player("monst","female");
		yuhua_choices = yuhua->query_pic_choices(fangshi);
		congxian_choices = congxian->query_pic_choices(fangshi);
		female_choices = yuhua->query_pic_choices(female);
		monst_choices = yuhua->query_pic_choices(monst);
	};
	if(err)
		error_desc = describe_error(err);
	if(sizeof(yuhua_choices)!=sizeof(congxian_choices))
		same_choices = 0;
	else{
		for(int i=0;i<sizeof(yuhua_choices);i++){
			if(yuhua_choices[i]!=congxian_choices[i])
				same_choices = 0;
		}
	}

	if(!err &&
	   sizeof(yuhua_choices)==11 &&
	   yuhua_choices[0]=="h_male1" &&
	   yuhua_choices[-1]=="h_male11" &&
	   same_choices==1 &&
	   sizeof(female_choices)==12 &&
	   female_choices[0]=="h_female1" &&
	   female_choices[-1]=="h_female12" &&
	   sizeof(monst_choices)==11 &&
	   monst_choices[0]=="m_female1" &&
	   monst_choices[-1]=="m_female11")
		test_pass();
	else
		test_fail("头像目录错误或两侧广场不一致: "+error_desc);

	destroy_test_player(fangshi);
	destroy_test_player(female);
	destroy_test_player(monst);
}

void test_missing_sex_runtime()
{
	test_start("缺少 sex 的方士可打开羽化村头像列表");
	object room = (object)(ROOT +
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	object|zero player = 0;
	object|zero original_player = this_player();
	int result = 0;
	string output = "";
	string error_desc = "";
	mixed err = catch {
		player = create_test_player("third","");
		player->move(room);
		set_this_player(player);
		result = room->set_pic();
		output = query_player_output(player);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		werror("[头像选择测试] 缺少 sex 回溯: %s\n",
			describe_backtrace(err));
	if(err)
		error_desc = describe_error(err);

	if(!err && result==1 &&
	   search(output,"请选择你的头像")!=-1 &&
	   search(output,"set_pic h_male1")!=-1 &&
	   search(output,"set_pic h_male11")!=-1)
		test_pass();
	else
		test_fail("头像列表未正常打开: "+error_desc);

	destroy_test_player(player);
}

void test_state_recovery_and_validation()
{
	test_start("头像状态恢复与非法参数拦截");
	object room = (object)(ROOT +
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	object|zero player = 0;
	object|zero original_player = this_player();
	string links_before = "";
	string links_after = "";
	string invalid_output = "";
	string error_desc = "";
	mixed err = catch {
		player = create_test_player("third","male");
		player->move(room);
		player->set_pic_ok = 1;
		player->user_pic = "";
		set_this_player(player);
		links_before = room->query_links();
		room->set_pic("h_male99");
		invalid_output = query_player_output(player);
		room->set_pic("h_male11");
		links_after = room->query_links();
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		werror("[头像选择测试] 状态恢复回溯: %s\n",
			describe_backtrace(err));
	if(err)
		error_desc = describe_error(err);

	if(!err && player &&
	   search(links_before,"[选择头像:set_pic]")!=-1 &&
	   search(invalid_output,"头像选择无效")!=-1 &&
	   player->user_pic=="h_male11" &&
	   player->set_pic_ok==1 &&
	   search(links_after,"set_pic")==-1)
		test_pass();
	else
		test_fail("头像状态恢复或参数校验失败: "+error_desc);

	destroy_test_player(player);
}

void test_existing_picture_recovery()
{
	test_start("已有头像但旧标记缺失时不再显示空按钮");
	object room = (object)(ROOT +
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero player = 0;
	object|zero original_player = this_player();
	string links = "";
	string output = "";
	string error_desc = "";
	mixed err = catch {
		player = create_test_player("human","male");
		player->move(room);
		player->user_pic = "h_male1";
		player->set_pic_ok = 0;
		set_this_player(player);
		links = room->query_links();
		room->set_pic();
		output = query_player_output(player);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		werror("[头像选择测试] 旧标记恢复回溯: %s\n",
			describe_backtrace(err));
	if(err)
		error_desc = describe_error(err);

	if(!err && player &&
	   search(links,"set_pic")==-1 &&
	   player->user_pic=="h_male1" &&
	   player->set_pic_ok==1 &&
	   search(output,"已经选择了头像")!=-1)
		test_pass();
	else
		test_fail("旧头像状态未正确恢复: "+error_desc);

	destroy_test_player(player);
}

int main()
{
	werror("\n========================================\n");
	werror("人物头像选择回归测试\n");
	werror("========================================\n");

	test_catalogs();
	test_missing_sex_runtime();
	test_state_recovery_and_validation();
	test_existing_picture_recovery();

	werror("\n头像选择测试完成: 总计 %d, 通过 %d, 失败 %d\n",
		test_results["total"],
		test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
