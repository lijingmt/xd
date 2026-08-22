#!/usr/bin/env pike
/** 爆炸装三层防御回归：生成上限、炼化钳制、登录矫正与补偿。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[爆炸装防御] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[爆炸装防御] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string userid)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="爆炸装防御测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=101;
	player->set_att_by_level();
	return player;
}

void destroy_test_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
}

int main()
{
	object player=create_test_player("xd01testunitboomgear");
	object|zero original=this_player();
	string error_desc="";
	int worst=0;
	string worst_attr="";
	int generated_capped=0;
	int conversion_clamped=0;
	int restore_corrected=0;
	int compensation_paid=0;
	int compensation_once=0;
	int corrected=0;
	int after=0;
	int str_after=0;
	int jade_mid=0;
	mixed err=catch{
		set_this_player(player);
		// 第二层：低阶底版按超高目标等级生成，单条属性必须被钳制。
		object overpowered=ITEMSD->get_convert_item(
			"weapon/1duanmugun/1duanmugun",3,1,400);
		foreach(({"str_add","dex_add","think_add","attack_add",
			"weapon_attack_add","life_add","mofa_add"}),string attr){
			mixed reader=overpowered ? overpowered["query_"+attr] : 0;
			if(functionp(reader)){
				int value=(int)call_function(reader);
				if(value>worst){
					worst=value;
					worst_attr=attr;
				}
			}
		}
		generated_capped=overpowered && worst>0 && worst<=5*500;
		if(overpowered)
			destruct(overpowered);
		// 第一层：炼化命令对低阶底版按底版档位重掷（源码契约）。
		string convert_source=Stdio.read_file(ROOT+
			"/gamelib/cmds/convert_equip_confirm.pike") || "";
		conversion_clamped=search(convert_source,
			"if(base_tier<65 && reroll_target>base_tier)")!=-1 &&
			search(convert_source,"reroll_target=base_tier;")!=-1;
		// 第三层：登录矫正——手工构造一件爆炸装再触发矫正。
		object exploded=ITEMSD->get_convert_item(
			"weapon/1duanmugun/1duanmugun",3,1,1);
		exploded->set_attack_add(999999);
		exploded->move(player);
		int jade_before=YUSHID->query_all_num(player);
		corrected=player->normalize_exploded_equipment();
		after=(int)call_function(exploded["query_attack_add"]);
		restore_corrected=corrected>=1 && after<=5*500;
		compensation_paid=(int)player["/plus/exploded_gear_compensated"]==1 &&
			YUSHID->query_all_num(player)>jade_before;
		// 幂等：第二次矫正继续钳数值但不再发补偿。
		exploded->set_str_add(888888);
		jade_mid=YUSHID->query_all_num(player);
		player->normalize_exploded_equipment();
		str_after=(int)call_function(exploded["query_str_add"]);
		compensation_once=str_after<=2*500 &&
			YUSHID->query_all_num(player)==jade_mid;
		destruct(exploded);
	};
	if(err)
		error_desc=describe_error(err);
	check("第二层：低阶底版超高等级生成的属性被钳回合法上限",
		!err && generated_capped,
		error_desc!="" ? error_desc :
			sprintf("worst=%s=%d",worst_attr,worst));
	check("第一层：炼化对低阶底版按底版档位重掷",
		!err && conversion_clamped,
		"炼化钳制缺失");
	check("第三层：登录矫正爆炸属性并发放补偿",
		!err && restore_corrected && compensation_paid,
		error_desc!="" ? error_desc :
			sprintf("corrected=%d after=%d paid=%d",
				corrected,after,compensation_paid));
	check("矫正幂等：再次矫正钳数值但不重复发补偿",
		!err && compensation_once,
		sprintf("str_after=%d jade %d->%d",str_after,jade_mid,
			YUSHID->query_all_num(player)));
	// 怪物联动：守护进程默认与热调边界。
	rm(DATA_ROOT+"balance_transition.json");
	object balance=(object)(ROOT+
		"/gamelib/single/daemons/balance_transitiond.pike");
	mapping fresh=balance->query_status();
	mapping tuned=balance->set_percents(60,80,"testunit");
	mapping bad=balance->set_percents(5,80,"testunit");
	mapping after_tune=balance->query_status();
	check("怪物过渡系数：默认100、热调生效且越界拒绝",
		(int)fresh["life_percent"]==100 &&
		(int)fresh["attack_percent"]==100 &&
		(int)tuned["ok"] && !(int)bad["ok"] &&
		(int)after_tune["life_percent"]==60 &&
		(int)after_tune["attack_percent"]==80,
		sprintf("fresh=%O tuned=%O bad=%O after=%O",
			fresh,tuned,bad,after_tune));
	// 不用rm收尾：同进程守护进程有30秒TTL缓存，显式回置100/100
	// 才能让同一轮后续测试立刻拿到中性系数。
	balance->set_percents(100,100,"testunit-cleanup");
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	destroy_test_player(player);
	werror("爆炸装防御：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
