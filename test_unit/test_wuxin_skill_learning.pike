#!/usr/bin/env pike
/** 无极/无心技能学习链路回归：技能书×2职业、CSV条目、教师NPC、
 * 购买导航、书的职业限制。 */

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

int main()
{
	werror("\n========== 无极/无心技能学习链路测试 ==========\n");
	mixed err = catch{
		array(string) suffixes = ({"quan","jue","yi","dun","hou","jian",
			"yan","jing","bi","huan","tian","yu","lin","ji","mie",
			"guixu","hunyuan","wuji","guizhen"});
		/* 1) 技能书文件：两职业各19本，skill_bname正确 */
		int wuxin_books = 0;
		int wuji_books = 0;
		int bname_ok = 0;
		foreach(suffixes,string suf){
			string p1 = ROOT+"/gamelib/clone/item/book/wuxin"+suf;
			string p2 = ROOT+"/gamelib/clone/item/book/wuji"+suf;
			string s1 = Stdio.read_file(p1) || "";
			string s2 = Stdio.read_file(p2) || "";
			if(s1!="") wuxin_books++;
			if(s2!="") wuji_books++;
			if(search(s1,"skill_bname=\"wuxin"+suf+"\"")!=-1 &&
			   search(s2,"skill_bname=\"wuji"+suf+"\"")!=-1)
				bname_ok++;
		}
		check("无心19本技能书全部存在",wuxin_books==19,
			sprintf("count=%d",wuxin_books));
		check("无极19本技能书全部存在",wuji_books==19,
			sprintf("count=%d",wuji_books));
		check("38本书skill_bname与技能名一致",bname_ok==19,
			sprintf("ok=%d",bname_ok));

		/* 2) CSV 购买清单条目 */
		string csv = Stdio.read_file(ROOT+
			"/gamelib/data/can_buy_book_list.csv") || "";
		int wuxin_csv = sizeof(glob("book,book/wuxin*",csv/"\n"));
		int wuji_csv = sizeof(glob("book,book/wuji*",csv/"\n"));
		check("CSV含无心19本书",wuxin_csv==19,
			sprintf("count=%d",wuxin_csv));
		check("CSV含无极19本书",wuji_csv==19,
			sprintf("count=%d",wuji_csv));

		/* 3) 职业限制字段 */
		string sample = Stdio.read_file(ROOT+
			"/gamelib/clone/item/book/wuxinjue") || "";
		check("无心书职业限制=无心",
			search(sample,"profe_read_limit=\"无心\"")!=-1,
			"限制字段缺失");

		/* 4) 教师 NPC 存在且链接正确 */
		string wuji_npc = Stdio.read_file(ROOT+
			"/gamelib/clone/npc/wuji_teacher.pike") || "";
		string wuxin_npc = Stdio.read_file(ROOT+
			"/gamelib/clone/npc/wuxin_teacher.pike") || "";
		check("无极教师NPC存在",
			wuji_npc!="" && search(wuji_npc,"buy_items book wuji")!=-1,
			"NPC缺失");
		check("无心教师NPC存在",
			wuxin_npc!="" && search(wuxin_npc,"buy_items book wuxin")!=-1,
			"NPC缺失");

		/* 5) 教师放置在两大广场 */
		string sq1 = Stdio.read_file(ROOT+
			"/gamelib/d/congxianzhen/congxianzhenguangchang") || "";
		string sq2 = Stdio.read_file(ROOT+
			"/gamelib/d/jinaodao/yuhuacunguangchang") || "";
		check("两广场均放置无心教师",
			search(sq1,"wuxin_teacher")!=-1 &&
			search(sq2,"wuxin_teacher")!=-1,
			"放置缺失");
		check("两广场均放置无极教师",
			search(sq1,"wuji_teacher")!=-1 &&
			search(sq2,"wuji_teacher")!=-1,
			"放置缺失");

		/* 6) 购买导航含两职业入口 */
		string buy_src = Stdio.read_file(ROOT+
			"/gamelib/cmds/buy_items.pike") || "";
		check("购买导航含无极/无心入口",
			search(buy_src,"无极:buy_items")!= -1 &&
			search(buy_src,"无心:buy_items")!= -1,
			"导航缺失");

		/* 7) 书对象克隆验证（读后即毁，不污染技能索引） */
		object book = clone(ROOT+"/gamelib/clone/item/book/wuxinjue");
		check("无心诀书可克隆",
			objectp(book) && functionp(book->read),
			"克隆失败");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	werror("========== 技能学习链路测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
