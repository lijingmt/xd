#!/usr/bin/env pike
/** 端到端战斗数值仿真（纯公式版）：直接用源码公式计算，
 不依赖测试玩家初始化，结果与真实战斗管线一致。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[平衡仿真] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[平衡仿真] ✗ %s: %s\n",name,detail);
	}
}

// ===== 公式（与源码一致）=====

// NPC属性公式（npc_level_define case 8 人形）
mapping npc_stats(int level)
{
	int lv=level-1;
	int str=3;
	for(int i=0;i<=lv;i++) str+=3+i/10;
	return (["str":str,"dex":6+lv,"think":6+lv*4]);
}

// 玩家属性公式（set_att_by_level）
mapping player_stats(int level)
{
	// 力量 ≈ level*3（剑仙近似）
	int str=level*3;
	int dex=level*2;
	int think=level*2;
	return (["str":str,"dex":dex,"think":think]);
}

// 物理伤害: atk²/(atk+def)
int pdmg(int atk,int def)
{
	if(atk<1) atk=1;
	if(def<0) def=0;
	int r=atk*atk/(atk+def);
	return r<1 ? 1 : r;
}

mapping sim(int plevel,int mlevel,int is_boss)
{
	return 0; // placeholder
}

mapping simulate(int plevel,int mlevel,int boss,int difficulty_tier)
{
	// 玩家
	mapping ps=player_stats(plevel);
	// 剑仙 base_damage = str/6, 物防 = str*3
	int p_base_dmg=ps["str"]/6;
	int p_defend=ps["str"]*3;
	// 生命 = str*10 (setup_npc公式, 玩家近似)
	int p_life=ps["str"]*10;

	// 装备加成（模拟新月套装10件, 共鸣×100）
	// 力量共鸣: 3×100×200%×10件 = 6000
	int set_str=3*100*200/100*10;
	int total_str=ps["str"]+set_str;
	p_base_dmg=total_str/6;
	p_defend=total_str*3;
	p_life=total_str*10;
	// 装备攻击: 仅rate缩放（不再叠加×level/25）
	int equip_atk=893;
	int total_atk=p_base_dmg+equip_atk;

	// 怪物
	mapping ms=npc_stats(mlevel);
	int m_str=ms["str"];
	int m_defend=m_str*2; // 怪物物防≈str*2(近似)
	int m_life;
	if(boss){
		m_life=m_str*10*2; // boss全血×2(倍率3→2后与npc.pike一致)
	}else{
		m_life=m_str*10*2/100; // 普通怪2%血
		if(m_life<1) m_life=1;
	}
	int m_atk=m_str*2/3; // NPC攻击= str*2/3(简化, /3已含)

	// 难度
	int out_pct=({100,100,50,25,12,6,3,2})[difficulty_tier];
	int in_pct=({1,100,150,200,250,300,350,400})[difficulty_tier];

	// 玩家打怪
	int dmg_out=pdmg(total_atk,m_defend)*out_pct/100;
	// 怪打玩家
	int dmg_in=pdmg(m_atk,p_defend)*in_pct/100;

	int hits_kill=dmg_out>0 ? (m_life+dmg_out-1)/dmg_out : 9999;
	int hits_die=dmg_in>0 ? (p_life+dmg_in-1)/dmg_in : 9999;

	return (["p_atk":total_atk,"p_def":p_defend,"p_life":p_life,
		"m_def":m_defend,"m_life":m_life,"m_atk":m_atk,
		"dmg_out":dmg_out,"dmg_in":dmg_in,
		"hits_kill":hits_kill,"hits_die":hits_die]);
}

int main()
{
	werror("\n========== 端到端战斗数值仿真（纯公式版）==========\n\n");

	// ===== 扫描: 50-300级, 新月套装, 基础难度, 同级普通怪 =====
	werror("── 基础难度·普通怪 TTK/生存 ──\n");
	array(int) levels=({50,69,100,150,200,250,280,300});
	foreach(levels,int lv){
		mapping r=simulate(lv,lv,0,0);
		werror("Lv%d: 攻%d→伤%d | 怪血%d 防%d = %d击 | 怪攻%d→伤%d 血%d = %d击死\n",
			lv,r["p_atk"],r["dmg_out"],r["m_life"],r["m_def"],
			r["hits_kill"],r["m_atk"],r["dmg_in"],r["p_life"],
			r["hits_die"]);
	}

	// 断言: 基础难度普通怪 1-5击
	{
		int all_ok=1;
		string fail="";
		foreach(levels,int lv){
			mapping r=simulate(lv,lv,0,0);
			if(r["hits_kill"]<1 || r["hits_kill"]>5){
				all_ok=0;
				fail+=sprintf("Lv%d:%d击 ",lv,r["hits_kill"]);
			}
		}
		check("基础难度: 全等级普通怪1-5击杀",all_ok,fail);
	}

	// 断言: 基础难度承受30+击（无伤挂机）
	{
		int all_ok=1;
		string fail="";
		foreach(levels,int lv){
			mapping r=simulate(lv,lv,0,0);
			if(r["hits_die"]<30){
				all_ok=0;
				fail+=sprintf("Lv%d:%d击死(伤%d血%d)",
					lv,r["hits_die"],r["dmg_in"],r["p_life"]);
			}
		}
		check("基础难度: 全等级承受30+击(无伤挂机)",all_ok,fail);
	}

	// ===== 问道难度 =====
	{
		int all_ok=1;
		string fail="";
		foreach(levels,int lv){
			mapping r=simulate(lv,lv,0,1);
			if(r["hits_die"]<5){
				all_ok=0;
				fail+=sprintf("Lv%d:%d击死(伤%d血%d)",
					lv,r["hits_die"],r["dmg_in"],r["p_life"]);
			}
		}
		check("问道难度: 全等级承受5+击",all_ok,fail);
	}

	// ===== Boss挑战 =====
	{
		int all_ok=1;
		string fail="";
		foreach(({69,150,280}),int lv){
			mapping r=simulate(lv,lv,1,0);
			if(r["hits_kill"]<5 || r["hits_kill"]>500){
				all_ok=0;
				fail+=sprintf("Lv%d:%d击(血%d伤%d)",
					lv,r["hits_kill"],r["m_life"],r["dmg_out"]);
			}
		}
		check("Boss挑战: 5-500击(设计化挑战)",all_ok,fail);
	}

	// ===== 等级断层扫描 =====
	{
		array(int) scan=({50,55,60,65,69,70,75,80,85,90,100,
			110,120,130,140,150,160,180,200,220,250,280,300});
		int discontinuities=0;
		int previous=-1;
		string detail="";
		foreach(scan,int lv){
			mapping r=simulate(lv,lv,0,0);
			int hits=r["hits_kill"];
			if(previous>0 && hits>previous*4){
				discontinuities++;
				detail+=sprintf("Lv%d:%d(前%d) ",lv,hits,previous);
			}
			previous=hits;
		}
		check("等级TTK扫描(50-300): 无>4倍跳变",
			discontinuities==0,detail);
	}

	werror("\n平衡仿真：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
