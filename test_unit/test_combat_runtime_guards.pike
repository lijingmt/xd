#!/usr/bin/env pike
/** 生产战斗心跳 NULL 栈和灵兽重复开战回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

int failures=0;

void check(string name,int valid,string detail)
{
	if(valid)
		werror("[战斗运行保护] ✓ %s\n",name);
	else{
		failures++;
		werror("[战斗运行保护] ✗ %s: %s\n",name,detail);
	}
}

void test_summon_repeated_focus()
{
	foreach(({"huling","heling","guiling"}),string type){
		object room=clone(WAP_ROOM);
		object summon=clone(ROOT+"/gamelib/clone/npc/summon/"+type);
		object target=clone(ROOT+
			"/gamelib/clone/npc/kunlunshan/qinyuan5");
		int first_result=0;
		int second_result=0;
		int hate_before=0;
		int hate_after=0;
		mixed err=catch {
			summon->move(room);
			target->move(room);
			target->first_fight=1;
			first_result=summon->focus_summon_target(target);
			hate_before=(int)target->targets[summon];
			second_result=summon->focus_summon_target(target);
			hate_after=(int)target->targets[summon];
		};
		check(type+" 对同一普通怪连续聚焦不重复开战",
			!err && first_result==1 && second_result==0 &&
			summon && summon->query_enemy()==target &&
			hate_before>0 && hate_after==hate_before,
			err ? describe_error(err) :
				sprintf("first=%d second=%d hate=%d/%d",
					first_result,second_result,hate_before,hate_after));
		if(summon)
			destruct(summon);
		if(target)
			destruct(target);
		if(room)
			destruct(room);
	}
}

void test_heartbeat_enemy_snapshot_contract()
{
	string source=Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike");
	string compact=replace(source || "","\t","");
	compact=replace(compact," ","");
	check("战斗心跳不再直接索引可异步清空的 enemy->name",
		source && search(source,"object action_enemy=enemy;")!=-1 &&
		search(source,"present(action_enemy,environment(this_object())")!=-1 &&
		search(source,"present(enemy->name,environment(this_object())")==-1,
		"目标存在性检查仍直接读取全局 enemy 字段");
	check("死亡回调前先清空全局目标且回调后不再访问攻击者成员",
		sizeof(compact/("objectdefeated_enemy=enemy;\n"+
			"enemy=0;\ndefeated_enemy->fight_die();"))-1==4,
		"仍有死亡路径在 fight_die 回调之后写入全局 enemy");
}

int main()
{
	string user_source=Stdio.read_file(ROOT+"/gamelib/clone/user.pike") || "";
	string fight_source=Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
	check("跨Worker退休人物先停心跳且所有战斗入口拒绝继续结算",
		search(user_source,"void prepare_worker_retirement()")!=-1 &&
		search(user_source,"worker_retirement_started=1;")!=-1 &&
		search(user_source,"set_heart_beat(0);")!=-1 &&
		search(user_source,"prepare_worker_retirement();")<
			search(user_source,"destruct(this_object());") &&
		search(fight_source,"query_worker_retirement_started")!=-1,
		"源人物析构时心跳仍可能继续施放技能或访问已析构对象");
	werror("\n========== 战斗运行保护测试 ==========\n");
	test_summon_repeated_focus();
	test_heartbeat_enemy_snapshot_contract();
	werror("战斗运行保护测试：失败 %d\n",failures);
	return failures ? 1 : 0;
}
