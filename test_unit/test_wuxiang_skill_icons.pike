#!/usr/bin/env pike
/**
 * 无相技能图标与基础图标设施回归测试
 *
 * 覆盖：
 * - pic_flag 默认值与老账号迁移：新账号默认带 skill=open
 * - picture.pike 的 query_picture_url 对 skill 类型开放
 * - skill.pike 的 is("skill") 派发与基类 is_X() 兼容
 * - view_performs 命中的技能对象可正确返回 imgurl
 * - 16 个无相技能 picture 字段已设置
 * - 16 个无相技能图标文件存在于 images/ 与 web/images/（png + gif）
 * - 3 个大神传承书封面存在
 * - pic_switch_list / pic_switch_confirm 已支持 skill 类别
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

object create_test_player()
{
	object player = clone(GAMELIB_USER);
	player->set_name("xd99testunitwuxiangskill");
	player->set_password("testunit99");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "无相测试";
	player->set_raceId("third");
	player->set_profeId("wuxiang");
	player->setup_player("third","wuxiang");
	return player;
}

void test_pic_flag_skill_default()
{
	werror("[测试1] pic_flag 默身带 skill=open\n");
	object player = create_test_player();
	// 模拟 init.pike 的迁移：老账号 pic_flag 不存时补鼠 skill
	if(!player->pic_flag)
		player->pic_flag = ([]);
	if(!player->pic_flag["skill"])
		player->pic_flag["skill"] = "open";
	check("pic_flag[skill] 被补为 open",
		player->pic_flag["skill"]=="open",
		"补鼠后仍非 open");
	check("skill 与 scene/item/character/decrate 互不干扰",
		player->pic_flag["skill"]=="open",
		"被其他开关误覆盖");
	destruct(player);
}

void test_skill_is_dispatch()
{
	werror("[测试2] skill 对象的 is(\"skill\") 派发\n");
	object|zero skill = 0;
	mixed err = catch {
		skill = (object)(ROOT+"/gamelib/single/skills/wuxiangji");
	};
	check("无相击 技能对象可加载",
		!err && objectp(skill),
		err ? describe_error(err) : "加载失败");
	if(err || !skill)
		return;
	check("is(\"skill\") 返回 1",
		skill->is("skill")==1,
		"is(skill)返回值="+skill->is("skill"));
	check("is(\"room\")/其他不存在类型返回 0",
		skill->is("room")==0 && skill->is("item")==0,
		"基类 is 派发被破坏");
}

void test_picture_url_for_skill()
{
	werror("[测试3] 技能的 query_picture_url 返回 imgurl\n");
	object player = create_test_player();
	if(!player->pic_flag)
		player->pic_flag = ([]);
	player->pic_flag["skill"] = "open";
	set_this_player(player);
	object|zero skill = (object)(ROOT+"/gamelib/single/skills/wuxiangji");
	check("picture 字段已设为 wuxiangji_logo",
		skill->query_picture()=="wuxiangji_logo",
		"picture="+skill->query_picture());
	string url = skill->query_picture_url();
	check("query_picture_url 返回带 wuxiangji_logo.gif 的 imgurl",
		search(url,"wuxiangji_logo.gif")!=-1 &&
		search(url,"[imgurl picture:")!=-1,
		"url="+url);
	// 关闭 skill 开关后不应再输出
	player->pic_flag["skill"] = "close";
	string url_closed = skill->query_picture_url();
	check("关闭 skill 开关后不返回 imgurl",
		url_closed=="" || search(url_closed,"[imgurl")==-1,
		"关闭后仍返回:"+url_closed);
	set_this_player(this_object());
	destruct(player);
}

void test_skill_files_picture_set()
{
	werror("[测试4] 16 个无相技能 picture 字段已设置\n");
	array(string) skills = ({
		"wuxiangbi","wuxiangdun","wuxiangguixu","wuxianghou","wuxianghuan",
		"wuxianghunyuan","wuxiangji","wuxiangjian","wuxiangjing","wuxiangjue",
		"wuxiangmie","wuxiangquan","wuxiangwuji","wuxiangyan","wuxiangyi",
		"wuxiangyu"
	});
	int all_set = 1;
	string missing = "";
	foreach(skills,string s){
		string path = ROOT+"/gamelib/single/skills/"+s;
		string content = Stdio.read_file(path);
		if(!content || search(content,"picture=\""+s+"_logo\"")==-1){
			all_set = 0;
			missing += s+" ";
		}
	}
	check("16个无相技能均设了 picture=<id>_logo",
		all_set, "缺失:"+missing);
}

void test_skill_icon_files_exist()
{
	werror("[测试5] 技能图标文件在 images/ 与 web/images/ 均存在（png+gif）\n");
	array(string) skills = ({
		"wuxiangbi","wuxiangdun","wuxiangguixu","wuxianghou","wuxianghuan",
		"wuxianghunyuan","wuxiangji","wuxiangjian","wuxiangjing","wuxiangjue",
		"wuxiangmie","wuxiangquan","wuxiangwuji","wuxiangyan","wuxiangyi",
		"wuxiangyu"
	});
	int all_present = 1;
	string missing = "";
	foreach(skills,string s){
		foreach(({"images","web/images"}),string dir){
			foreach(({"png","gif"}),string ext){
				string p = ROOT+"/"+dir+"/"+s+"_logo."+ext;
				if(Stdio.file_size(p)<=0){
					all_present = 0;
					missing += dir+"/"+s+"_logo."+ext+" ";
				}
			}
		}
	}
	check("16个技能在 images/、web/images/ 均有 png+gif",
		all_present, "缺失:"+missing);
}

void test_book_covers_exist()
{
	werror("[测试6] 3 个大神传承书封面存在\n");
	array(string) books = ({"wuxiangguixu","wuxianghunyuan","wuxiangwuji"});
	int all_present = 1;
	string missing = "";
	foreach(books,string b){
		foreach(({"images","web/images"}),string dir){
			foreach(({"png","gif"}),string ext){
				string p = ROOT+"/"+dir+"/"+b+"."+ext;
				if(Stdio.file_size(p)<=0){
					all_present = 0;
					missing += dir+"/"+b+"."+ext+" ";
				}
			}
		}
	}
	check("3个书尚在 images/、web/images/ 均有 png+gif",
		all_present, "缺失:"+missing);
}

void test_pic_switch_ui()
{
	werror("[测试7] pic_switch_list/确认 已支持 skill 类别\n");
	string list_src = Stdio.read_file(ROOT+"/gamelib/cmds/pic_switch_list.pike");
	string conf_src = Stdio.read_file(ROOT+"/gamelib/cmds/pic_switch_confirm.pike");
	string pic_src = Stdio.read_file(ROOT+"/lowlib/wapmud2/inherit/feature/picture.pike");
	string skill_src = Stdio.read_file(ROOT+"/lowlib/wapmud2/inherit/skill.pike");
	string init_src = Stdio.read_file(ROOT+"/gamelib/d/init");

	check("pic_switch_list 含技能图标开关词条",
		search(list_src,"技能图标")!=-1 &&
		search(list_src,"pic_switch_confirm skill")!=-1,
		"pic_switch_list 未加入 skill 切换");
	check("pic_switch_confirm all 中含 skill",
		search(conf_src,"flagTmp[\"skill\"]")!=-1,
		"pic_switch_confirm all 未同步 skill");
	check("picture.pike 支持 skill 类型的 imgurl",
		search(pic_src,"flags[\"skill\"]==\"open\"&&ob->is(\"skill\")")!=-1,
		"picture.pike 未加入 skill 分支");
	check("skill.pike 实现 is_skill()",
		search(skill_src,"int is_skill()")!=-1,
		"skill.pike 未实现 is_skill()");
	check("init.pike 购物默认 skill=open 并迁移老账号",
		search(init_src,"me->pic_flag[\"skill\"] = \"open\"")!=-1,
		"init.pike 未补鼠 skill 默认值");
}

void test_view_performs_returns_icon()
{
	werror("[测试8] view_performs 输出含技能图标\n");
	object player = create_test_player();
	if(!player->pic_flag)
		player->pic_flag = ([]);
	player->pic_flag["skill"] = "open";
	// 手动给 player 装上无相击（跳过读书）
	player->skills = player->skills || ([]);
	object skill = (object)(ROOT+"/gamelib/single/skills/wuxiangji");
	// 写入最小 skill 记录：[等级, 熟练度]
	player->skills["wuxiangji"] = ({1, 0});
	set_this_player(player);
	string out = player->view_performs("wuxiangji");
	check("view_performs 返回串中含 wuxiangji_logo.gif",
		stringp(out) && search(out,"wuxiangji_logo.gif")!=-1,
		"未返回含图标："+(out||""));
	set_this_player(this_object());
	destruct(player);
}

int main()
{
	werror("\n========== 无相技能图标与基础设施测试 ==========\n");
	mixed err = catch {
		test_pic_flag_skill_default();
		test_skill_is_dispatch();
		test_picture_url_for_skill();
		test_skill_files_picture_set();
		test_skill_icon_files_exist();
		test_book_covers_exist();
		test_pic_switch_ui();
		test_view_performs_returns_icon();
	};
	if(err)
		check("测试运行无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	werror("\n无相技能图标：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
