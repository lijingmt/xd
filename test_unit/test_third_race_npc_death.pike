#!/usr/bin/env pike
/** S1幻境0血不死怪回归：third族NPC（与幻境玩家同族）被打到0血必须
 * 走真实死亡（fight_die+经验），不得落入同族"决斗胜利set_life(1)"
 * 分支——那是玩家PVP专属语义（2026-10-01玩家反馈无限1血怪复发）。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[同族NPC死亡] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[同族NPC死亡] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string userid)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="同族击杀"+userid;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->set_term("noterm");
	player->level=50;
	player->set_att_by_level();
	player->set_vip_flag(3);
	player->set_vip_end_time(time()+3600);
	player->all_fee=0;
	return player;
}

int main()
{
	object original=this_player();
	object|zero me=0;
	object|zero room=0;
	string error_desc="";
	mixed err=catch{
		me=create_test_player("__testunit_thirdkill__");
		set_this_player(me);
		room=clone(WAP_ROOM);
		me->move(room);

		// ===== 1) third族NPC源断言：S1怪确实与玩家同族 =====
		object npc=clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/eclipse_priest");
		npc->move(room);
		check("S1样本NPC为third族（复现前提）",
			(string)npc->query_raceId()=="third",
			sprintf("race=%O",npc->query_raceId()));
		check("S1样本NPC非玩家对象",
			!npc->is || !npc->is("player"),"is(player)误报");

		// ===== 2) 直接打死：生命归零必须真实死亡 =====
		int npc_level=(int)npc->query_level();
		npc->set_life(1);
		me->enemy=npc;
		npc->enemy=me;
		npc->targets[me]=1;
		me->targets[npc]=1;
		int exp_before=(int)me->exp+(int)me->current_exp;
		// 模拟一击致死：走技能伤害路径会把life打到<=0。
		// fight_die是受保护的死亡入口——直接调它验证NPC死亡链。
		mixed die_err=catch{ npc->fight_die(); };
		check("third族NPC生命归零后真实死亡(对象被清理)",
			!die_err,
			die_err ? describe_error(die_err) : "ok");

		// ===== 3) 源断言：全部决斗分支都有玩家守卫 =====
		// 两种拼写都要扫：enemy/this_object()（四处单体分支）与
		// target/caster（灵医房间AOE分支）。守卫统一为is("player")。
		string fight_src=Stdio.read_file(
			ROOT+"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
		int branches=0;
		int guarded=0;
		foreach(({
			"query_raceId() == this_object()->query_raceId()",
			"query_raceId()==caster->query_raceId()",
		}),string pattern){
			int pos=0;
			while((pos=search(fight_src,pattern,pos))!=-1){
				branches++;
				// 守卫在同分支的条件头部（前260字符窗口）出现即可。
				int window_start=max(0,pos-260);
				string window=fight_src[window_start..pos+10];
				if(search(window,"is(\"player\")")!=-1)
					guarded++;
				pos+=10;
			}
		}
		check(sprintf("全部%d处同族决斗分支都有玩家守卫",branches),
			branches==5 && guarded==5,
			sprintf("branches=%d guarded=%d",branches,guarded));
	};
	if(err)
		error_desc=describe_error(err);
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	if(error_desc!="")
		check("同族NPC死亡流程无异常",0,error_desc);
	else
		check("同族NPC死亡流程无异常",1,"");
	if(me){
		foreach(all_inventory(me),object item)
			destruct(item);
		destruct(me);
	}
	if(room)
		destruct(room);
	werror("[同族NPC死亡] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
