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
	check("战斗心跳不再直接索引可异步清空的 enemy->name",
		source && search(source,"object action_enemy=enemy;")!=-1 &&
		search(source,"present(action_enemy,environment(this_object())")!=-1 &&
		search(source,"present(enemy->name,environment(this_object())")==-1,
		"目标存在性检查仍直接读取全局 enemy 字段");
}

int main()
{
	werror("\n========== 战斗运行保护测试 ==========\n");
	test_summon_repeated_focus();
	test_heartbeat_enemy_snapshot_contract();
	werror("战斗运行保护测试：失败 %d\n",failures);
	return failures ? 1 : 0;
}
