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
	rm(DATA_ROOT+"illusion_realm/rankings/S1/"+userid+".json");
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
		"quest_item_pity":(["mortal_lifespan_thread":6]),
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
			(int)status["feature_revision"]==3 &&
			sizeof((array)config["companion_memories"])==9 &&
			sizeof((array)config["wander_events"])==3 &&
			sizeof((array)config["echo_rotations"])==3,
			sprintf("status=%O",status));

		int deterministic=1;
		mapping(string:int) gates=([]);
		foreach((array)config["side_quests"];int index;mapping quest){
			deterministic=deterministic && (int)quest["volume"]==index+1 &&
				(int)quest["unlock_claimed"]==index*9 &&
				sizeof((array)quest["acts"])==4 &&
				!gates[(string)quest["gate_id"]];
			foreach((array)quest["acts"];int act_index;mapping act)
				deterministic=deterministic &&
					Stdio.file_size(ROOT+(string)act["target_path"])>0 &&
					(int)act["required_kills"]==
						(({3,4,5,1}))[act_index];
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
		int hunt_started;
		int hunt_stopped;
		mapping hunt_result=([]);
		foreach((array)first["acts"];int act_index;mapping act){
			acts_ok=move_for_test(one,(string)act["room"]) && acts_ok;
			if(act_index<3){
				mapping early=daemon->advance_current_quest(one);
				acts_ok=acts_ok && !(int)early["ok"];
				if(act_index==0){
					one["/tmp/illusion_journey_autofight"] = ([
						"illusion_id":"S1",
						"quest_id":(string)first["id"],"act":0,
						"target_path":(string)act["target_path"],
						"target_room":(string)act["room"],
						"target_kills":(int)act["required_kills"],
						"created_at":time(),
					]);
					AUTOFIGHTD->start_journey_autofight(one);
					hunt_result=(["ok":1,"mode":"test_fixture"]);
					hunt_started=
						(string)one->query_autofight()=="enable" &&
						mappingp(one["/tmp/illusion_journey_autofight"]);
				}
				for(int kill_index=0;
				    kill_index<(int)act["required_kills"];kill_index++){
					object target=clone(ROOT+(string)act["target_path"]);
					target->move(environment(one));
					mapping credited=daemon->record_npc_kill(one,target);
					acts_ok=acts_ok && (int)credited["credited"] &&
						(int)credited["kills"]==kill_index+1;
					destruct(target);
				}
				if(act_index==0)
					hunt_stopped=(string)one->query_autofight()=="disable" &&
						!mappingp(one["/tmp/illusion_journey_autofight"]);
			}
				mapping advanced=daemon->advance_current_quest(one);
				acts_ok=acts_ok && (int)advanced["ok"];
			}
			check("支线限定挂机可启动且完成后自动停止",
				hunt_started && hunt_stopped,
				sprintf("start=%d stop=%d result=%O autofight=%s marker=%O",
					hunt_started,hunt_stopped,hunt_result,
					(string)one->query_autofight(),
					one["/tmp/illusion_journey_autofight"]));
		mapping progress=(mapping)one["/plus/illusion_realm/S1"];
		mapping journey=(mapping)progress["newmoon_journey"];
		mapping qstate=(mapping)((mapping)journey["side_quests"])[
			"ink_without_name"];
		check("第一卷前三幕真实击杀、卷末首领事件后才写入秘术与剧情凭证",
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
				(int)gate["count"]==0 && (int)gate["pity"]==6,
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

			mapping all_progress=copy_value(restored_progress);
			mapping all_claims=mappingp(all_progress["claims"]) ?
				(mapping)all_progress["claims"] : ([]);
			mapping all_events=mappingp(all_progress["story_events"]) ?
				(mapping)all_progress["story_events"] : ([]);
			for(int chapter=1;chapter<=81;chapter++)
				all_claims["S1-C"+(string)chapter]=time();
			foreach((array)config["side_quests"],mapping quest)
				all_events[(string)quest["final_event"]]=time();
			all_progress["claims"]=all_claims;
			all_progress["story_events"]=all_events;
			one["/plus/illusion_realm/S1"]=all_progress;
			int all_acts_ok=one->save_with_result();
			foreach((array)config["side_quests"];int quest_index;mapping quest){
				if(quest_index==0)
					continue;
				foreach((array)quest["acts"];int act_index;mapping act){
					all_acts_ok=move_for_test(one,(string)act["room"]) &&
						all_acts_ok;
					if(act_index<3)
						for(int kill_index=0;
						    kill_index<(int)act["required_kills"];
						    kill_index++){
							object target=clone(ROOT+(string)act["target_path"]);
							target->move(environment(one));
							mapping credited=daemon->record_npc_kill(one,target);
							all_acts_ok=all_acts_ok &&
								(int)credited["credited"] &&
								(int)credited["kills"]==kill_index+1;
							destruct(target);
						}
					mapping advanced=daemon->advance_current_quest(one);
					all_acts_ok=all_acts_ok && (int)advanced["ok"];
				}
			}
			mapping final_progress=mappingp(one[
				"/plus/illusion_realm/S1"]) ?
				(mapping)one["/plus/illusion_realm/S1"] : ([]);
			mapping final_journey=mappingp(final_progress[
				"newmoon_journey"]) ?
				(mapping)final_progress["newmoon_journey"] : ([]);
			mapping final_quests=mappingp(final_journey["side_quests"]) ?
				(mapping)final_journey["side_quests"] : ([]);
			int all_completed=1;
			foreach((array)config["side_quests"],mapping quest)
				all_completed=all_completed &&
					mappingp(final_quests[(string)quest["id"]]) &&
					(int)((mapping)final_quests[
						(string)quest["id"]])["act"]==4;
			check("九卷三十六幕均可按3/4/5只支线怪与真实卷末首领顺序通关",
				all_acts_ok && all_completed && sizeof(final_quests)==9,
				sprintf("all_acts_ok=%d final_quests=%O",all_acts_ok,
					final_quests));

			mapping before_overlay=copy_value((mapping)one[
				"/plus/illusion_realm/S1"]);
			mapping legacy_journey=copy_value((mapping)before_overlay[
				"newmoon_journey"]);
			m_delete(legacy_journey,"encounter");
			m_delete(legacy_journey,"echo");
			m_delete(legacy_journey,"community_points");
			before_overlay["newmoon_journey"]=legacy_journey;
			one["/plus/illusion_realm/S1"]=before_overlay;
			mapping legacy_view=daemon->query_journey_for_test(one);
			check("revision-2旧S1档案缺少新增字段时只读归一且仍可继续",
				(int)legacy_view["ok"] && mappingp(legacy_view["encounter"]) &&
				mappingp(legacy_view["echo"]) &&
				(int)((mapping)legacy_view["resonance"])["tier"]>=0,
				sprintf("legacy_view=%O",legacy_view));

			mapping overlay_progress=(mapping)one["/plus/illusion_realm/S1"];
			overlay_progress["kills"]=18;
			one["/plus/illusion_realm/S1"]=overlay_progress;
			mapping expected_event=(mapping)((array)config["wander_events"])[0];
			move_for_test(one,(string)expected_event["room"]);
			object activation_probe=clone(ROOT+(string)expected_event["target_path"]);
			activation_probe->move(environment(one));
			mapping activated=daemon->record_npc_kill_for_test(one,activation_probe);
			destruct(activation_probe);
			mapping encounter_view=daemon->query_journey_for_test(one);
			mapping encounter=(mapping)encounter_view["encounter"];
			mapping active_event=(mapping)encounter["active"];
			int encounter_ok=(int)activated["activated"] &&
				(string)active_event["id"]==(string)expected_event["id"];
			move_for_test(one,"/gamelib/d/illusion_s1/moon_dew_field.pike");
			object wrong_room_target=clone(ROOT+(string)active_event["target_path"]);
			wrong_room_target->move(environment(one));
			mapping wrong_room_credit=daemon->record_npc_kill_for_test(one,
				wrong_room_target);
			destruct(wrong_room_target);
			encounter_ok=encounter_ok && !(int)wrong_room_credit["credited"] &&
				move_for_test(one,(string)active_event["room"]);
			for(int event_kill=0;event_kill<3;event_kill++){
				object event_target=clone(ROOT+(string)active_event["target_path"]);
				event_target->move(environment(one));
				if(event_kill==0){
					int failure_primed=daemon->force_next_save_failure_for_test(one);
					mapping failed_credit=daemon->record_npc_kill_for_test(one,
						event_target);
					mapping after_failure=daemon->query_journey_for_test(one);
					encounter_ok=encounter_ok && failure_primed &&
						!(int)failed_credit["ok"] &&
						(int)((mapping)after_failure["encounter"])["kills"]==0;
				}
				mapping credit=daemon->record_npc_kill_for_test(one,event_target);
				encounter_ok=encounter_ok && (int)credit["credited"];
				if(event_kill==0){
					mapping duplicate=daemon->record_npc_kill_for_test(one,
						event_target);
					encounter_ok=encounter_ok && !(int)duplicate["credited"] &&
						(int)duplicate["duplicate"];
				}
				destruct(event_target);
			}
			encounter_view=daemon->query_journey_for_test(one);
			encounter=(mapping)encounter_view["encounter"];
			check("月下偶遇按真实击杀触发、三杀完成、定距续期且不阻塞主线",
				encounter_ok && (int)encounter["completed"]==1 &&
				!sizeof((mapping)encounter["active"]) &&
				(int)encounter["remaining_kills"]==40 &&
				(int)((mapping)encounter_view["community"])["target"]==5000,
				sprintf("activated=%O encounter=%O",activated,encounter));

			mapping echo=(mapping)encounter_view["echo"];
			int echo_ok=(int)echo["available"] && !(int)echo["completed"];
			for(int echo_stage=0;echo_stage<3;echo_stage++){
				mapping target=(mapping)echo["target"];
				echo_ok=echo_ok && sizeof(target)>0 &&
					move_for_test(one,(string)target["room"]);
				object echo_boss=clone(ROOT+(string)target["target_path"]);
				echo_boss->move(environment(one));
				mapping echo_credit=daemon->record_npc_kill_for_test(one,echo_boss);
				echo_ok=echo_ok && (int)echo_credit["credited"];
				destruct(echo_boss);
				echo=(mapping)daemon->query_journey_for_test(one)["echo"];
			}
			mapping overlay_state=(mapping)((mapping)one[
				"/plus/illusion_realm/S1"])["newmoon_journey"];
			check("八十一章后月蚀回廊每周轮换三场且重复读取不能重发贡献",
				echo_ok && (int)echo["completed"] && (int)echo["stage"]==3 &&
				(int)overlay_state["community_points"]==102,
				sprintf("echo=%O state=%O",echo,overlay_state));

			int snapshot_published=SEASONALD->
				publish_journey_snapshot_for_test(one);
			mapping community=SEASONALD->query_community_progress("S1");
			check("同心筑月通过跨Worker排行快照聚合且无第二份人物档案",
				snapshot_published && (int)community["ok"] &&
				(int)community["points"]>=(int)overlay_state["community_points"] &&
				search(daemon_source,"newmoon_journey")!=-1 &&
				search(daemon_source,"NEWMOON_SET_SKILLD->query_active_set_skill")!=-1,
				sprintf("community=%O",community));

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
		string command_source=Stdio.read_file(ROOT+
			"/gamelib/cmds/illusion_journey.pike") || "";
		string seasonal_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/seasonal_chard.pike") || "";
		mixed compile_err=catch{
			compile_file(ROOT+"/gamelib/cmds/illusion_journey.pike");
		};
		check("新命令进入世界核心队列且命令文件可编译",
			search(thread_source,"\"illusion_journey\"")!=-1 &&
			!compile_err,
			compile_err ? describe_error(compile_err) : "核心队列缺失");
		check("九卷内容明确标注新月支线且不再用到场点击代替战斗",
			search(command_source,"【新月支线·九卷秘迹】")!=-1 &&
			search(command_source,"【当前支线任务·")!=-1 &&
			search(command_source,"观察并记录这一幕")==-1 &&
			search(command_source,"支线挂机至本幕完成")!=-1,
			"支线标签、战斗入口或旧观察按钮仍有遗漏");
		check("S1真实NPC死亡只在主线安全结算后转交支线记账",
			search(seasonal_source,
				"ILLUSION_JOURNEYD->record_npc_kill(player,npc)")!=-1 &&
			search(seasonal_source,"journey_err = catch")!=-1,
			"支线击杀未接入权威NPC死亡回调或未隔离异常");
		string autofight_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/autofightd.pike") || "";
		check("支线挂机按精确NPC与房间优先选怪且禁止普通寻路离场",
			search(autofight_source,"is_journey_autofight_target")!=-1 &&
			search(autofight_source,
				"mappingp(me[\"/tmp/illusion_journey_autofight\"])")!=-1 &&
			search(autofight_source,"target_room")!=-1,
			"支线限定挂机可能误选普通怪或离开目标房间");
	};
	check("新月回响完整测试未发生运行异常",!err,
		err ? describe_error(err)+" "+describe_backtrace(err) : "");
	cleanup();
	werror("新月回响测试：%d/%d通过\n",results["passed"],results["total"]);
	return results["failed"] ? 1 : 0;
}
