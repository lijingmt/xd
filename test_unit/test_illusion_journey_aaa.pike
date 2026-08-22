#!/usr/bin/env pike
/** S1 AAA Rev4：九卷试炼、三命途、契印边界、事务与重载测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=([]);
array(object) players=({});

void check(string name,int valid,string reason)
{
	results["total"]=(int)results["total"]+1;
	if(valid){
		results["passed"]=(int)results["passed"]+1;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]=(int)results["failed"]+1;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string user_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_user(string userid)
{
	string path=user_file(userid);
	rm(path); rm(path+".bak"); rm(path+".tmp"); rm(path+".bak.tmp");
	rm(DATA_ROOT+"illusion_realm/rankings/S1/"+userid+".json");
}

object create_player(string suffix,string path)
{
	string userid="__testunit_journey_aaa_"+suffix+"__";
	cleanup_user(userid);
	object one=clone(GAMELIB_USER);
	one->set_name(userid);
	one->set_password("testunit88");
	one->set_project("gamelib");
	one->set_userip("testunit");
	one->set_account_owner("xd99journeyaaa"+suffix);
	one->name_cn="新月验收";
	one->set_raceId("human");
	one->set_profeId("jianxian");
	one->setup_player("human","jianxian");
	one->level=250;
	one->set_att_by_level();
	one->set_term("noterm");
	mapping claims=([]);
	mapping events=([]);
	for(int chapter=1;chapter<=81;chapter++)
		claims["S1-C"+(string)chapter]=time();
	foreach((array)ILLUSION_JOURNEYD->query_catalog_for_test()["side_quests"],
	   mapping quest)
		events[(string)quest["final_event"]]=time();
	one["/plus/illusion_realm/S1"] = ([
		"version":1,"content_id":"S1","path":path,"claims":claims,
		"story_events":events,"season_starts_at":time()-15*86400,
		"kills":0,
	]);
	PERSONAL_DIFFICULTYD->set_scope_for_test(one,"S1");
	one->save_with_result();
	players+=({one});
	return one;
}

int move_for_test(object player,string room_path)
{
	object room=(object)(ROOT+room_path);
	int moved;
	mixed err;
	player["/tmp/illusion_move_bypass"]=1;
	err=catch{ moved=player->move(room); };
	player->m_delete_foruser("/tmp/illusion_move_bypass");
	return !err && moved && environment(player)==room;
}

int kill_target(object player,mapping target,int count)
{
	int ok=move_for_test(player,(string)target["room"]);
	for(int index=0;index<count;index++){
		object npc=clone(ROOT+(string)target["target_path"]);
		npc->move(environment(player));
		mapping credited=ILLUSION_JOURNEYD->record_npc_kill_for_test(
			player,npc);
		ok=ok && (int)credited["ok"] && (int)credited["credited"];
		destruct(npc);
	}
	return ok;
}

int complete_route(object player)
{
	int ok=1;
	for(int attempt=0;attempt<6;attempt++){
		mapping view=ILLUSION_JOURNEYD->query_journey_for_test(player);
		mapping route=(mapping)view["route_arc"];
		if((int)route["completed"])
			break;
		mapping target=(mapping)route["current"];
		ok=ok && (int)view["ok"] && (int)target["unlocked"] &&
			kill_target(player,target,(int)target["required_kills"]);
	}
	return ok && (int)((mapping)ILLUSION_JOURNEYD->
		query_journey_for_test(player)["route_arc"])["completed"];
}

int main()
{
	mapping config;
	mixed err=catch{
		config=ILLUSION_JOURNEYD->query_catalog_for_test();
		check("Rev4静态契约为九套三阶段、三命途十八段、六契印三槽",
			(int)config["feature_revision"]==4 &&
			sizeof((array)config["signature_trials"])==9 &&
			sizeof((array)config["pact_catalog"])==6 &&
			sizeof((array)config["loot_focus_catalog"])==10 &&
			sizeof((array)config["pact_slots"])==3 &&
			sizeof((array)((mapping)config["route_arcs"])[
				"pioneer"]["stages"])==6 &&
			sizeof((array)((mapping)config["route_arcs"])[
				"hunter"]["stages"])==6 &&
			sizeof((array)((mapping)config["route_arcs"])[
				"companion"]["stages"])==6,
			sprintf("keys=%O",indices(config)));

		mapping(string:int) experience_counts = ([]);
		int experience_ok = 1;
		for(int chapter_number=1;chapter_number<=81;chapter_number++){
			mapping experience = SEASONALD->
				query_chapter_experience_for_test(chapter_number);
			string experience_id = (string)experience["id"];
			experience_ok = experience_ok && experience_id!="" &&
				sizeof((string)experience["title"])>=4 &&
				sizeof((string)experience["hint"])>=8 &&
				sizeof((string)experience["opening"])>=8 &&
				sizeof((string)experience["middle"])>=8 &&
				sizeof((string)experience["closing"])>=8;
			experience_counts[experience_id] =
				(int)experience_counts[experience_id]+1;
		}
		foreach(indices(experience_counts),string experience_id)
			experience_ok = experience_ok &&
				(int)experience_counts[experience_id]==9;
		check("八十一章覆盖九种节奏且每种各九章、三幕反馈完整",
			experience_ok && sizeof(experience_counts)==9,
			sprintf("counts=%O",experience_counts));

		object pioneer=create_player("pioneer","pioneer");
		int trials_ok=1;
		foreach((array)config["signature_trials"],mapping trial){
			mapping ritual=(mapping)((array)trial["stages"])[0];
			trials_ok=move_for_test(pioneer,(string)ritual["room"]) &&
				trials_ok;
			mapping ritual_result=ILLUSION_JOURNEYD->
				perform_signature_ritual(pioneer);
			trials_ok=trials_ok && (int)ritual_result["ok"];
			for(int stage=1;stage<3;stage++){
				mapping target=(mapping)((array)trial["stages"])[stage];
				trials_ok=kill_target(pioneer,target,
					(int)target["required_kills"]) && trials_ok;
			}
		}
		mapping pioneer_view=ILLUSION_JOURNEYD->
			query_journey_for_test(pioneer);
		check("九卷二十七阶段按仪式、追猎、卷主顺序全部真实完成",
			trials_ok && (int)((mapping)pioneer_view["signatures"])[
				"completed"]==9,
			sprintf("signatures=%O",pioneer_view["signatures"]));
		int pioneer_route_ok=complete_route(pioneer);
		pioneer_view=ILLUSION_JOURNEYD->query_journey_for_test(pioneer);
		check("寻月命途中途目标按六段真实击杀完成且不是终章单点检查",
			pioneer_route_ok &&
			(int)((mapping)pioneer_view["route_arc"])["completed"],
			sprintf("route=%O",pioneer_view["route_arc"]));

		object hunter=create_player("hunter","hunter");
		object companion=create_player("companion","companion");
		mapping legacy_modifiers;
		mixed legacy_modifier_err=catch{
			legacy_modifiers=ILLUSION_JOURNEYD->
				query_pact_combat_modifiers(hunter);
		};
		check("Rev4前无契印字段的S1人物战斗保持中性且不会中断",
			!legacy_modifier_err && mappingp(legacy_modifiers) &&
			(int)legacy_modifiers["outgoing_percent"]==100 &&
			(int)legacy_modifiers["incoming_percent"]==100,
			legacy_modifier_err ? describe_error(legacy_modifier_err) :
			 sprintf("modifiers=%O",legacy_modifiers));
		object legacy_npc=clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/abyss_beast.pike");
		int legacy_outgoing;
		int legacy_incoming;
		mixed legacy_damage_err=catch{
			legacy_outgoing=PERSONAL_DIFFICULTYD->scale_pve_damage(
				hunter,legacy_npc,10000);
			legacy_incoming=PERSONAL_DIFFICULTYD->scale_pve_damage(
				legacy_npc,hunter,10000);
		};
		// 基础档承伤现为10%（平衡重建后），测试期望同步更新。
		check("旧档在真实双向PVE伤害入口保持可战斗且基础输出不变",
			!legacy_damage_err && legacy_outgoing==10000 &&
			legacy_incoming==1000,
			legacy_damage_err ? describe_error(legacy_damage_err) :
			 sprintf("out=%d in=%d",legacy_outgoing,legacy_incoming));
		destruct(legacy_npc);
		int hunter_ok=complete_route(hunter);
		int companion_ok=complete_route(companion);
		check("逐影与同行命途各六段均可独立完成",
			hunter_ok && companion_ok,
			sprintf("hunter=%O companion=%O",
				ILLUSION_JOURNEYD->query_journey_for_test(hunter)["route_arc"],
				ILLUSION_JOURNEYD->query_journey_for_test(companion)["route_arc"]));

		mapping pact1=ILLUSION_JOURNEYD->toggle_pact(pioneer,"dawn_edge");
		mapping pact2=ILLUSION_JOURNEYD->toggle_pact(pioneer,"mortal_guard");
		mapping pact3=ILLUSION_JOURNEYD->toggle_pact(pioneer,"mirror_truth");
		mapping pact4=ILLUSION_JOURNEYD->toggle_pact(pioneer,"oath_burning");
		mapping modifiers=ILLUSION_JOURNEYD->
			query_pact_combat_modifiers(pioneer);
		check("三槽契印按风险叠加、第四枚被拒绝且倍率有界",
			(int)pact1["ok"] && (int)pact2["ok"] && (int)pact3["ok"] &&
			!(int)pact4["ok"] &&
			(int)modifiers["outgoing_percent"]==105 &&
			(int)modifiers["incoming_percent"]==106,
			sprintf("pacts=%O/%O/%O/%O modifiers=%O",pact1,pact2,pact3,
				pact4,modifiers));

		int focus_ok=1;
		foreach((array)config["loot_focus_catalog"],mapping row){
			mapping selected=ILLUSION_JOURNEYD->set_loot_focus(pioneer,
				(string)row["id"]);
			array templates=ITEMSD->query_newmoon_drop_templates_for_player(
				pioneer);
			object sample=sizeof(templates)==1 ?
				clone(ITEM_PATH+(string)templates[0]) : 0;
			focus_ok=focus_ok && (int)selected["ok"] &&
				sizeof(templates)==1 && sample &&
				(string)sample->query_item_kind()==(string)row["id"] &&
				(string)sample->query_newmoon_resonance_profession()=="jianxian";
			if(sample)
				destruct(sample);
		}
		check("十个套装部位均把合法掉落缩小到本职业唯一模板",
			focus_ok &&
			sizeof(ITEMSD->query_newmoon_drop_templates_for_player(0))==120,
			"某部位未精确命中本职业模板，或无玩家的公共掉落被改写");
		mapping focus_before=copy_value((mapping)pioneer[
			"/plus/illusion_realm/S1"]);
		ILLUSION_JOURNEYD->force_next_save_failure_for_test(pioneer);
		mapping focus_failed=ILLUSION_JOURNEYD->set_loot_focus(pioneer,"all");
		check("套装定向保存失败完整回滚且不会吞掉原选择",
			!(int)focus_failed["ok"] && equal(focus_before,(mapping)pioneer[
				"/plus/illusion_realm/S1"]) &&
			ILLUSION_JOURNEYD->query_newmoon_drop_focus(pioneer)==
				"jewelry_bangle",
			sprintf("failed=%O",focus_failed));

		object npc=clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/nameless_ink_wraith.pike");
		object pvp=create_player("pvp","pioneer");
		int outgoing=PERSONAL_DIFFICULTYD->scale_pve_damage(
			pioneer,npc,10000);
		int incoming=PERSONAL_DIFFICULTYD->scale_pve_damage(
			npc,pioneer,10000);
		int pvp_damage=PERSONAL_DIFFICULTYD->scale_pve_damage(
			pioneer,pvp,10000);
		// 基础档输出1000%×契印105%；承伤10%×契印106%=10.6%。
		check("契印只作用S1 PVE且玩家互斗保持零影响",
			outgoing==10500 && incoming==1060 && pvp_damage==10000,
			sprintf("out=%d in=%d pvp=%d",outgoing,incoming,pvp_damage));
		destruct(npc);

		mapping pact_state=(mapping)((mapping)pioneer[
			"/plus/illusion_realm/S1"])["newmoon_journey"];
		mapping pact_saved=(mapping)pact_state["pacts"];
		string pact_signature=((array)pact_saved["active"])*"|"+":"+
			(string)(int)pact_saved["changed_at"];
		pioneer["/tmp/illusion_journey_pact_combat"] = ([
			"signature":pact_signature,"outgoing_percent":999,
			"incoming_percent":1,
		]);
		mapping cache_checked=ILLUSION_JOURNEYD->
			query_pact_combat_modifiers(pioneer);
		check("伪造或损坏的战斗缓存越界值会重算而非进入伤害公式",
			(int)cache_checked["outgoing_percent"]==105 &&
			(int)cache_checked["incoming_percent"]==106,
			sprintf("modifiers=%O",cache_checked));

		mapping companion_raw=(mapping)companion[
			"/plus/illusion_realm/S1"];
		mapping companion_journey=(mapping)companion_raw["newmoon_journey"];
		mapping route_backup=copy_value((mapping)companion_journey["route_arc"]);
		((mapping)companion_journey["route_arc"])["path"]="hunter";
		mapping mismatch=ILLUSION_JOURNEYD->query_journey_for_test(companion);
		companion_journey["route_arc"] = route_backup;
		check("命途档案与人物选择不一致时失败关闭且不自动覆盖",
			!(int)mismatch["ok"] && (int)mismatch["security_blocked"] &&
			(string)((mapping)companion_journey["route_arc"])["path"]==
				"companion",
			sprintf("mismatch=%O",mismatch));

		mapping before=copy_value((mapping)pioneer[
			"/plus/illusion_realm/S1"]);
		ILLUSION_JOURNEYD->force_next_save_failure_for_test(pioneer);
		mapping failed=ILLUSION_JOURNEYD->toggle_pact(pioneer,"dawn_edge");
		mapping after=(mapping)pioneer["/plus/illusion_realm/S1"];
		check("契印保存失败完整回滚且不会制造模糊成功",
			!(int)failed["ok"] && equal(before,after) &&
			(int)ILLUSION_JOURNEYD->query_pact_combat_modifiers(pioneer)[
				"outgoing_percent"]==105,
			sprintf("failed=%O",failed));

		int saved=pioneer->save_with_result();
		string pioneer_id=(string)pioneer->query_name();
		destruct(pioneer);
		players-=({pioneer});
		object restored=clone(GAMELIB_USER);
		restored->set_name(pioneer_id);
		restored->set_project("gamelib");
		int loaded=restored->restore();
		players+=({restored});
		PERSONAL_DIFFICULTYD->set_scope_for_test(restored,"S1");
		mapping restored_view=ILLUSION_JOURNEYD->
			query_journey_for_test(restored);
		check("重启式重载保留九试炼、命途与契印且所有者校验通过",
			saved && loaded && (int)restored_view["ok"] &&
			(int)((mapping)restored_view["signatures"])["completed"]==9 &&
			(int)((mapping)restored_view["route_arc"])["completed"] &&
			sizeof((array)((mapping)restored_view["pacts"])["active"])==3 &&
			(string)((mapping)restored_view["loot_focus"])["kind"]==
				"jewelry_bangle",
			sprintf("saved=%d loaded=%d view=%O",saved,loaded,restored_view));
	};
	check("AAA Rev4测试未发生运行异常",!err,
		err ? describe_error(err)+" "+describe_backtrace(err) : "");
	foreach(players,object player){
		string userid=(string)player->query_name();
		if(player->query_in_combat())
			player->_clean_fight();
		destruct(player);
		cleanup_user(userid);
	}
	werror("S1 AAA Rev4：%d/%d通过\n",(int)results["passed"],
		(int)results["total"]);
	return (int)results["failed"] ? 1 : 0;
}
