#!/usr/bin/env pike
/** S1新月回响确定性支线、剧情凭证、月忆兽与旧破阵路线兼容测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);
object|zero player;
string userid="__testunit_illusion_journey__";

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){ results["passed"]++; werror("  ✓ %s\n",name); }
	else{ results["failed"]++; werror("  ✗ %s: %s\n",name,reason); }
}

string user_file()
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup()
{
	if(player) catch(destruct(player));
	player=0;
	string path=user_file();
	rm(path); rm(path+".bak"); rm(path+".tmp"); rm(path+".bak.tmp");
}

object create_player()
{
	cleanup();
	object one=clone(GAMELIB_USER);
	one->set_name(userid);
	one->set_password("testunit88");
	one->set_project("gamelib");
	one->set_userip("testunit");
	one->set_account_owner("xd99illusionjourney");
	one->name_cn="回响测试";
	one->set_raceId("human");
	one->set_profeId("jianxian");
	one->setup_player("human","jianxian");
	one->level=69;
	one->set_att_by_level();
	one->set_term("noterm");
	one["/plus/illusion_realm/S1"] = ([
		"version":1,"content_id":"S1","claims":([]),
		"story_events":(["life_collector":time()]),
		"quest_item_pity":(["mortal_lifespan_thread":9]),
	]);
	one->save_with_result();
	player=one;
	return one;
}

int move_for_test(object one,string room_path)
{
	object room=(object)(ROOT+room_path);
	int moved;
	mixed err;
	one["/tmp/illusion_move_bypass"]=1;
	err=catch{ moved=one->move(room); };
	one->m_delete_foruser("/tmp/illusion_move_bypass");
	return !err && moved && environment(one)==room;
}

int main()
{
	object daemon=ILLUSION_JOURNEYD;
	mapping config;
	mixed err=catch{
		mapping status=daemon->query_config_status();
		config=daemon->query_catalog_for_test();
		check("升级配置严格包含九支线、九秘术、五月忆兽",
			(int)status["ok"] && (int)status["quests"]==9 &&
			(int)status["secrets"]==9 && (int)status["species"]==5 &&
			sizeof((array)config["companion_memories"])==9,
			sprintf("status=%O",status));

		int deterministic=1;
		mapping(string:int) gates=([]);
		foreach((array)config["side_quests"];int index;mapping quest){
			deterministic=deterministic && (int)quest["volume"]==index+1 &&
				(int)quest["unlock_claimed"]==index*9 &&
				sizeof((array)quest["acts"])==4 &&
				!gates[(string)quest["gate_id"]];
			gates[(string)quest["gate_id"]]=1;
		}
		string daemon_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/illusion_journeyd.pike") || "";
			check("九卷均为四幕确定性秘迹且没有概率或付费加速",
			deterministic && sizeof(gates)==9 &&
			search(daemon_source,"random(")==-1 &&
			search(daemon_source,"drop_basis_points")==-1 &&
				search(daemon_source,"wallet")==-1,
				"秘迹出现重复凭证、随机门槛或付费捷径");

			mapping story=(mapping)Standards.JSON.decode(Stdio.read_file(ROOT+
				"/gamelib/etc/illusion_s1_story.json"));
			int links_ok=1;
			foreach((array)config["side_quests"];int index;mapping quest){
				mapping volume=(mapping)((array)story["volumes"])[index];
				mapping finale=(mapping)((array)volume["chapters"])[-1];
				mapping story_gate=(mapping)finale["quest_item_gate"];
				links_ok=links_ok &&
					(string)finale["id"]=="S1-C"+(string)((index+1)*9) &&
					(string)finale["story_event"]==(string)quest["final_event"] &&
					(string)story_gate["id"]==(string)quest["gate_id"];
			}
			check("九个秘迹凭证与九个真实卷末剧情一一对应",
				links_ok,"支线卷号、剧情事件或主线门槛错配");

		object one=create_player();
		mapping first=(mapping)((array)config["side_quests"])[0];
		int acts_ok=1;
		foreach((array)first["acts"],mapping act){
			acts_ok=acts_ok && move_for_test(one,(string)act["room"]);
			mapping advanced=daemon->advance_current_quest(one);
			acts_ok=acts_ok && (int)advanced["ok"];
		}
		mapping progress=(mapping)one["/plus/illusion_realm/S1"];
		mapping journey=(mapping)progress["newmoon_journey"];
		mapping qstate=(mapping)((mapping)journey["side_quests"])[
			"ink_without_name"];
		check("第一卷四幕按真实房间推进并一次性写入秘术与剧情凭证",
			acts_ok && (int)qstate["act"]==4 &&
			(int)((mapping)journey["secrets"])["hidden_name_trace"]>0 &&
			(int)((mapping)journey["gate_substitutions"])[
				"mortal_lifespan_thread"]>0,
			sprintf("journey=%O",journey));

			mapping chapter9=(mapping)((array)((mapping)
				((array)story["volumes"])[0])["chapters"])[8];
			mapping gate=SEASONALD->query_quest_item_gate_status_for_test(
				one,progress,chapter9);
			check("确定性凭证满足卷末门槛但保留原实体数量与保底进度",
			(int)gate["ready"] && (int)gate["substitute_ready"] &&
				(int)gate["count"]==0 && (int)gate["pity"]==9,
				sprintf("gate=%O",gate));

			mapping forged=copy_value(journey);
			((mapping)forged["side_quests"])["ink_without_name"]=([]);
			progress["newmoon_journey"]=forged;
			one["/plus/illusion_realm/S1"]=progress;
			mapping forged_gate=SEASONALD->query_quest_item_gate_status_for_test(
				one,progress,chapter9);
			check("孤立伪造替代字段不能绕过四幕支线和卷末剧情",
				!(int)forged_gate["ready"] &&
				!(int)forged_gate["substitute_ready"],
				sprintf("forged_gate=%O",forged_gate));
			progress["newmoon_journey"]=journey;
			one["/plus/illusion_realm/S1"]=progress;

		mapping chosen=daemon->choose_starter_companion(one,"ink_tail");
		mapping duplicate=daemon->choose_starter_companion(one,"mirror_fin");
		mapping memory=daemon->claim_companion_memory(one,"care");
		journey=(mapping)((mapping)one["/plus/illusion_realm/S1"])[
			"newmoon_journey"];
		mapping companion=(mapping)journey["companion"];
			check("月忆兽唯一ID、不可覆盖与第一卷记忆事务均成立",
			(int)chosen["ok"] && !(int)duplicate["ok"] &&
			(int)memory["ok"] &&
			sizeof((string)((mapping)((mapping)companion["pets"])[
				"ink_tail"])["id"])==64 &&
			(int)((mapping)companion["traits"])["care"]==1 &&
			(int)((mapping)companion["memories"])["1"]["claimed_at"]>0,
				sprintf("companion=%O",companion));

			int saved=one->save_with_result();
			destruct(one);
			player=0;
			one=clone(GAMELIB_USER);
			one->set_name(userid);
			one->set_project("gamelib");
			int restored=one->restore();
			player=one;
			mapping restored_progress=mappingp(one[
				"/plus/illusion_realm/S1"]) ?
				(mapping)one["/plus/illusion_realm/S1"] : ([]);
			mapping restored_journey=mappingp(restored_progress[
				"newmoon_journey"]) ?
				(mapping)restored_progress["newmoon_journey"] : ([]);
			mapping restored_companion=mappingp(restored_journey[
				"companion"]) ? (mapping)restored_journey["companion"] : ([]);
			check("重启式存档重载后秘迹、凭证、月忆兽和性格均不丢失",
				saved && restored &&
				daemon->query_gate_substitution_ready(one,
					"mortal_lifespan_thread") &&
				(int)((mapping)restored_journey["gate_substitutions"])[
					"mortal_lifespan_thread"]>0 &&
				sizeof((mapping)restored_companion["memories"])==1 &&
				(int)((mapping)restored_companion["traits"])["care"]==1,
				sprintf("saved=%d restored=%d journey=%O",saved,restored,
					restored_journey));

		check("新系统不污染普通技能、共享宠物或本命灵伴存储",
			search(daemon_source,"player->set_skill")==-1 &&
			search(daemon_source,"player[\"/pet_battle/source\"]")==-1 &&
			search(daemon_source,"PETD->")==-1 &&
			search(daemon_source,"SPIRIT_COMPANIOND->")==-1,
			"新月回响越界写入现有技能或宠物系统");

		mapping hunter=(["content_id":"S1","path":"hunter",
			"route_marks":(["broken_star":1,"moon_guard":1,
				"eclipse_priest":1])]);
		mapping legacy=copy_value(hunter);
		legacy["route_marks"]=(["broken_star":1,"moon_guard":1,
			"newmoon_lord":1]);
		mapping realm_raw=(mapping)Standards.JSON.decode(Stdio.read_file(ROOT+
			"/gamelib/etc/illusion_realm.json"));
		mapping routes=(mapping)realm_raw["route_challenges"];
		array hunter_bosses=(array)routes["hunter_bosses"];
		check("破阵新流程不预杀终章月主且旧月主印继续兼容",
			SEASONALD->query_route_final_ready_for_test(hunter)==1 &&
			SEASONALD->query_route_final_ready_for_test(legacy)==1 &&
			(string)((mapping)hunter_bosses[2])["id"]=="eclipse_priest",
			"第72章仍依赖归真月主或旧印被回退");

		string thread_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/thread_manager.pike") || "";
		mixed compile_err=catch{
			compile_file(ROOT+"/gamelib/cmds/illusion_journey.pike");
		};
		check("新命令进入世界核心队列且命令文件可编译",
			search(thread_source,"\"illusion_journey\"")!=-1 &&
			!compile_err,
			compile_err ? describe_error(compile_err) : "核心队列缺失");
	};
	check("新月回响完整测试未发生运行异常",!err,
		err ? describe_error(err)+" "+describe_backtrace(err) : "");
	cleanup();
	werror("新月回响测试：%d/%d通过\n",results["passed"],results["total"]);
	return results["failed"] ? 1 : 0;
}
