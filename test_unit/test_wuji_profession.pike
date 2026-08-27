#!/usr/bin/env pike
/** 无极职业回归：技能编译、群杀群奶类型、解锁条件、装备白名单。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[无极职业] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[无极职业] ✗ %s: %s\n",name,detail);
	}
}

int main()
{
	werror("\n========== 无极职业测试 ==========\n");

	// 1. 所有19个技能文件可编译
	{
		array(string) skills=({"quan","jue","yi","dun","hou","jian","yan",
			"tian","jing","bi","huan","yu","lin","ji","mie",
			"guixu","hunyuan","wuji","guizhen"});
		int all_compile=1;
		string fail="";
		foreach(skills,string suffix){
			mixed err=catch{
				compile_file(ROOT+"/gamelib/single/skills/wuji"+suffix);
			};
			if(err){
				all_compile=0;
				fail+=suffix+" ";
			}
		}
		check("全部19个无极技能文件可由真实运行时编译",
			all_compile,fail+"编译失败");
	}

	// 2. 无极拳数值正确（太极15→无极20，约30%加强）
	{
		string wuji_src=Stdio.read_file(ROOT+
			"/gamelib/single/skills/wujiquan") || "";
		string taiji_src=Stdio.read_file(ROOT+
			"/gamelib/single/skills/taijiquan") || "";
		int wuji_has=search(wuji_src,"performs_attack[1]=20")!=-1;
		int taiji_has=search(taiji_src,"performs_attack[1]=15")!=-1;
		check("无极拳攻击力比太极拳强约30%（15→20）",
			wuji_has && taiji_has,
			sprintf("wuji=%d taiji=%d",wuji_has,taiji_has));
	}

	// 3. 群杀技能类型正确
	{
		int aoe_ok=1;
		foreach(({"tian","yan"}),string suffix){
			object skill=(object)(ROOT+"/gamelib/single/skills/wuji"+suffix);
			if(!skill || skill->s_skill_type!="balanced_aoe")
				aoe_ok=0;
		}
		object mie=(object)(ROOT+"/gamelib/single/skills/wujimie");
		if(!mie || mie->s_skill_type!="all_mofa_attack")
			aoe_ok=0;
		check("群杀技能（天雷/焰=AOE、灭=全系）类型正确",
			aoe_ok,"至少一个群杀技能类型错误");
	}

	// 4. 群奶技能类型正确
	{
		int heal_ok=1;
		foreach(({"yu","lin"}),string suffix){
			object skill=(object)(ROOT+"/gamelib/single/skills/wuji"+suffix);
			if(!skill || skill->s_skill_type!="balanced_team_heal")
				heal_ok=0;
		}
		check("群奶技能（雨/灵泉）类型为团队治疗",
			heal_ok,"至少一个群奶技能类型错误");
	}

	// 5. 职业注册
	{
		string ac_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/account_characterd.pike") || "";
		check("无极职业已注册为中立隐藏职业",
			search(ac_source,"\"wuji\":\"无极\"")!=-1 &&
			search(ac_source,"\"zhaoming\",\"wuji\"")!=-1,
			"职业注册缺失");
	}

	// 6. 解锁条件接线
	{
		string ac_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/account_characterd.pike") || "";
		check("无极解锁条件：照命300级+10000碎玉",
			search(ac_source,"WUJI_REQUIRED_LEVEL 300")!=-1 &&
			search(ac_source,"WUJI_CREATION_COST 10000")!=-1 &&
			search(ac_source,"query_wuji_unlocked_from_summary")!=-1,
			"解锁条件接线缺失");
	}

	// 7. 装备白名单
	{
		string eq_source=Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/equip.pike") || "";
		check("无极已进装备职业白名单",
			search(eq_source,"search(item_profeLimit")!=-1,
			"装备白名单缺无极");
	}

	// 8. 攻击速度表
	{
		string atk_source=Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/attack.pike") || "";
		check("无极已进攻击速度表",
			search(atk_source,"wuji")!=-1,
			"攻击速度表缺无极");
	}

	werror("无极职业：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
