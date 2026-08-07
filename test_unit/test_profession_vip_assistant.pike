#!/usr/bin/env pike
/** 方士/镇越/天象/灵医职业助手的权限、PVE、公平性、支付与接线回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void test_start(string name){ test_results["total"]++; werror("\n[职业助手 %d] %s\n",test_results["total"],name); }
void test_pass(){ test_results["passed"]++; werror("  ✓ 通过\n"); }
void test_fail(string reason){ test_results["failed"]++; werror("  ✗ 失败: %s\n",reason); }

object create_player(string name,string profe,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "职业助手测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId(profe);
	player->setup_player("third",profe);
	player->level = level;
	player->set_att_by_level();
	player->flush_life();
	player->set_mofa(player->query_mofa_max());
	return player;
}

void set_active_vip(object player,int level)
{
	player->set_vip_flag(level);
	player->set_vip_end_time(level > 0 ? time()+3600 : 0);
}

void give_test_yushi(object player,string yushi_name,int amount)
{
	object yushi = clone(ROOT+"/gamelib/clone/item/yushi/"+yushi_name);
	if(yushi){
		yushi->amount = amount;
		yushi->move_player(player->query_name());
	}
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	SUMMOND->dismiss_all(player->query_name());
	if(player->query_in_combat())
		player->_clean_fight();
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_runtime_compile_and_wiring()
{
	test_start("守护进程、命令、挂机、HTTP和Vue接线可运行时编译");
	array(string) paths = ({
		"/gamelib/single/daemons/professionvipd.pike",
		"/gamelib/cmds/profession_assistant.pike",
		"/gamelib/single/daemons/autofightd.pike",
		"/lowlib/wapmud2/cmds/flushview.pike",
	});
	int failed = 0;
	string error_desc = "";
	foreach(paths,string path){
		mixed err = catch {
			program compiled = (program)(ROOT+path);
			if(!compiled) failed++;
		};
		if(err){ failed++; error_desc += path+":"+describe_error(err); }
	}
	string thread_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	string api_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	string vue_source = Stdio.read_file(ROOT+"/vue_source/index.html");
	string css_source = Stdio.read_file(ROOT+"/vue_source/css/app.css");
	if(failed==0 && thread_source && api_source && vue_source && css_source &&
	   search(thread_source,"\"profession_assistant\"")!=-1 &&
	   search(api_source,"PROFESSIONVIPD->query_status(player)")!=-1 &&
	   search(vue_source,"playerStats.profession_assistant.title }} · 职业助手")!=-1 &&
	   search(css_source,"profession-style-fangshi-3")!=-1 &&
	   search(css_source,"profession-style-zhenyue-3")!=-1 &&
	   search(css_source,"profession-style-tianxiang-3")!=-1 &&
	   search(css_source,"profession-style-lingyi-3")!=-1 &&
	   search(css_source,"prefers-reduced-motion")!=-1)
		test_pass();
	else
		test_fail("编译或跨层接线失败: "+error_desc);
}

void test_trial_and_core_fairness()
{
	test_start("3天试用不授予通用VIP且不改变任何人物战斗数值");
	object player = create_player("__testunit_profession_trial__","fangshi",40);
	int str_before = player->query_str();
	int life_before = player->query_life_max();
	mapping result = ([]);
	string error_desc = "";
	mixed err = catch {
		result = PROFESSIONVIPD->claim_trial(player);
	};
	if(err) error_desc = describe_error(err);
	if(!err && result["success"]==1 &&
	   PROFESSIONVIPD->query_effective_level(player)==2 &&
	   VIPD->query_active_vip_level(player)==0 &&
	   player->query_str()==str_before &&
	   player->query_life_max()==life_before &&
	   PROFESSIONVIPD->claim_trial(player)["reason"]=="claimed")
		test_pass();
	else test_fail("试用隔离或数值公平性错误: "+error_desc);
	destroy_player(player);
}

void test_trial_preserved_for_active_member()
{
	test_start("已有黄金会员时不会浪费一次性试用资格");
	object player = create_player("__testunit_profession_trial_keep__","zhenyue",40);
	set_active_vip(player,2);
	mapping result = PROFESSIONVIPD->claim_trial(player);
	if(result["success"]==0 && result["reason"]=="active_vip" &&
	   (int)player["/plus/profession_vip/trial_claimed"]==0)
		test_pass();
	else test_fail("有效会员误消耗了职业助手试用");
	destroy_player(player);
}

void test_slots_expiry_and_persistence()
{
	test_start("策略槽保存、配置保留和VIP取消后仍可执行");
	object player = create_player("__testunit_profession_slots__","zhenyue",60);
	set_active_vip(player,2);
	PROFESSIONVIPD->initialize_player(player);
	int save2 = PROFESSIONVIPD->save_strategy_slot(player,2,"team");
	string slot2 = PROFESSIONVIPD->query_strategy_slot(player,2);
	PROFESSIONVIPD->set_auto_enabled(player,1);
	player->set_vip_end_time(time()-1);
	int expired_auto = PROFESSIONVIPD->query_auto_enabled(player);
	if(save2==1 && slot2=="team" &&
	   PROFESSIONVIPD->query_strategy_slot(player,2)=="team" &&
	   expired_auto==1)
		test_pass();
	else test_fail("槽位档位、过期暂停或配置持久化错误");
	destroy_player(player);
}

void test_fangshi_auto_replenish()
{
	test_start("方士黄金助手仅补召已学灵兽并服从原人物召唤上限");
	object player = create_player("__testunit_profession_summon__","fangshi",60);
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	string error_desc = "";
	int success = 0;
	mixed err = catch {
		player->skills["huling"] = ({2,0});
		player->skills["heling"] = ({2,0});
		player->move(room);
		set_active_vip(player,2);
		PROFESSIONVIPD->initialize_player(player);
		PROFESSIONVIPD->set_auto_enabled(player,1);
		if(PROFESSIONVIPD->try_out_of_combat_support(player)["success"]) success++;
		if(PROFESSIONVIPD->try_out_of_combat_support(player)["success"]) success++;
		if(PROFESSIONVIPD->try_out_of_combat_support(player)["success"]) success++;
	};
	if(err) error_desc = describe_error(err);
	mapping summons = SUMMOND->get_player_summons(player->query_name());
	if(!err && success==2 && sizeof(summons)==2 && summons["huling"] &&
	   summons["heling"] && !summons["guiling"] &&
	   SUMMOND->get_max_summons(player->query_name())==3)
		test_pass();
	else test_fail(sprintf("成功=%d 召唤=%d: %s",success,sizeof(summons),error_desc));
	destroy_player(player);
	if(room) destruct(room);
}

void test_fangshi_resonance_pve_only()
{
	test_start("方士自动共鸣只处理PVE救援，PVP永不自动接管");
	object player = create_player("__testunit_profession_resonance__","fangshi",60);
	object pvp = create_player("__testunit_profession_resonance_pvp__","zhenyue",60);
	object npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	mapping pve_result = ([]);
	mapping pvp_result = ([]);
	string error_desc = "";
	mixed err = catch {
		player->skills["heling"] = ({2,0});
		player->move(room); pvp->move(room); npc->move(room);
		SUMMOND->summon_creature(player->query_name(),"heling",0,0);
		set_active_vip(player,3);
		PROFESSIONVIPD->initialize_player(player);
		PROFESSIONVIPD->set_resonance_enabled(player,1);
		player->set_life(player->query_life_max()/3);
		player->_fight(npc);
		pve_result = PROFESSIONVIPD->try_fangshi_resonance(player);
		player->_clean_fight();
		player["/plus/fangshi/resonance_until"] = 0;
		player->set_life(player->query_life_max()/3);
		player->_fight(pvp);
		pvp_result = PROFESSIONVIPD->try_fangshi_resonance(player);
	};
	if(err) error_desc = describe_error(err);
	if(!err && pve_result["success"]==1 &&
	   pvp_result["success"]==0 && pvp_result["reason"]=="pve_only")
		test_pass();
	else test_fail("PVE/PVP隔离错误: "+error_desc);
	destroy_player(player); destroy_player(pvp);
	if(npc) destruct(npc);
	if(room) destruct(room);
}

void test_zhenyue_tier_and_pvp_boundaries()
{
	test_start("镇越免费、黄金、白金与PVP候选技能边界正确");
	object tank = create_player("__testunit_profession_tank__","zhenyue",80);
	object mate = create_player("__testunit_profession_tank_mate__","fangshi",80);
	object pvp = create_player("__testunit_profession_tank_pvp__","fangshi",80);
	object npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	array(string) free_names = ({}), vip2_names = ({}), vip3_names = ({}), pvp_names = ({});
	string error_desc = "";
	mixed err = catch {
		tank->skills["dizhenhou"] = ({4,0});
		tank->skills["shanhebi"] = ({4,0});
		tank->move(room); mate->move(room); pvp->move(room); npc->move(room);
		tank->set_term("__testunit_profession_team__");
		mate->set_term("__testunit_profession_team__");
		tank->_fight(npc); npc->force_target(mate,1000);
		free_names = PROFESSIONVIPD->query_zhenyue_context_candidates(tank);
		set_active_vip(tank,2); PROFESSIONVIPD->initialize_player(tank);
		PROFESSIONVIPD->set_auto_enabled(tank,1);
		vip2_names = PROFESSIONVIPD->query_zhenyue_context_candidates(tank);
		set_active_vip(tank,3); PROFESSIONVIPD->set_strategy(tank,"team");
		vip3_names = PROFESSIONVIPD->query_zhenyue_context_candidates(tank);
		tank->_clean_fight(); tank->_fight(pvp);
		pvp_names = PROFESSIONVIPD->query_zhenyue_context_candidates(tank);
	};
	if(err) error_desc = describe_error(err);
	if(!err && sizeof(free_names)==0 && search(vip2_names,"dizhenhou")!=-1 &&
	   search(vip2_names,"shanhebi")==-1 &&
	   search(vip3_names,"shanhebi")!=-1 && sizeof(pvp_names)==0)
		test_pass();
	else test_fail("镇越档位或PVP边界错误: "+error_desc);
	destroy_player(tank); destroy_player(mate); destroy_player(pvp);
	if(npc) destruct(npc);
	if(room) destruct(room);
}

void test_tianxiang_tier_and_pvp_boundaries()
{
	test_start("天象星痕策略只在有效白金PVE执行且不改战斗数值");
	object mage = create_player("__testunit_profession_mage__","tianxiang",80);
	object pvp = create_player("__testunit_profession_mage_pvp__","fangshi",80);
	object npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	array(string) free_names = ({});
	array(string) pve_names = ({});
	array(string) pvp_names = ({});
	int think_before = mage->query_think();
	int life_before = mage->query_life_max();
	string error_desc = "";
	mixed err = catch {
		mage->skills["xingmang"] = ({1,0});
		mage->skills["xingluo"] = ({1,0});
		mage->move(room); pvp->move(room); npc->move(room);
		mage->_fight(npc);
		mage->add_tianxiang_star_marks(2);
		free_names = PROFESSIONVIPD->query_tianxiang_context_candidates(mage);
		set_active_vip(mage,3);
		PROFESSIONVIPD->initialize_player(mage);
		PROFESSIONVIPD->set_auto_enabled(mage,1);
		PROFESSIONVIPD->set_strategy(mage,"burst");
		pve_names = PROFESSIONVIPD->query_tianxiang_context_candidates(mage);
		mage->_clean_fight(); mage->_fight(pvp);
		pvp_names = PROFESSIONVIPD->query_tianxiang_context_candidates(mage);
	};
	if(err) error_desc = describe_error(err);
	if(!err && sizeof(free_names)==0 && search(pve_names,"xingluo")!=-1 &&
	   sizeof(pvp_names)==0 && mage->query_think()==think_before &&
	   mage->query_life_max()==life_before)
		test_pass();
	else
		test_fail("天象档位、PVE/PVP或数值边界错误: "+error_desc);
	destroy_player(mage); destroy_player(pvp);
	if(npc) destruct(npc);
	if(room) destruct(room);
}

void test_style_purchase_is_cosmetic()
{
	test_start("永久外观按服务端价格扣款且不改变战斗属性");
	object player = create_player("__testunit_profession_style__","fangshi",80);
	give_test_yushi(player,"biluanyu",1);
	int before_yushi = YUSHID->query_all_num(player);
	int before_str = player->query_str();
	int before_life = player->query_life_max();
	mapping result = PROFESSIONVIPD->buy_style(player,"lingguang");
	if(result["success"]==1 && before_yushi-YUSHID->query_all_num(player)==60 &&
	   PROFESSIONVIPD->owns_style(player,"lingguang") &&
	   PROFESSIONVIPD->query_selected_style(player)=="lingguang" &&
	   player->query_str()==before_str && player->query_life_max()==before_life &&
	   PROFESSIONVIPD->buy_style(player,"lingguang")["reason"]=="owned")
		test_pass();
	else test_fail("外观支付、幂等或属性隔离错误");
	destroy_player(player);
}

void test_growth_pass_level_claims()
{
	test_start("成长外观册一次扣款、按20/50/80级领取且不可重复");
	object player = create_player("__testunit_profession_pass__","zhenyue",19);
	give_test_yushi(player,"biluanyu",1);
	int before = YUSHID->query_all_num(player);
	mapping buy = PROFESSIONVIPD->buy_growth_pass(player);
	mapping low = PROFESSIONVIPD->claim_pass_style(player,1);
	player->level = 80;
	mapping one = PROFESSIONVIPD->claim_pass_style(player,1);
	mapping two = PROFESSIONVIPD->claim_pass_style(player,2);
	mapping three = PROFESSIONVIPD->claim_pass_style(player,3);
	mapping duplicate = PROFESSIONVIPD->claim_pass_style(player,3);
	if(buy["success"]==1 && before-YUSHID->query_all_num(player)==240 &&
	   low["reason"]=="level" && one["success"]==1 && two["success"]==1 &&
	   three["success"]==1 && duplicate["reason"]=="claimed" &&
	   YUSHID->query_all_num(player)==before-240)
		test_pass();
	else test_fail("外观册扣费、等级门槛或幂等错误");
	destroy_player(player);
}

void test_monitor_throttle_and_expiry_notice()
{
	test_start("监控一分钟防刷、到期摘要一次提示且兼容旧存档迁移");
	object player = create_player("__testunit_profession_notice__","fangshi",60);
	object legacy = create_player("__testunit_profession_notice_legacy__","zhenyue",60);
	set_active_vip(player,1);
	PROFESSIONVIPD->initialize_player(player);
	string first = PROFESSIONVIPD->query_monitor_notice(player);
	string second = PROFESSIONVIPD->query_monitor_notice(player);
	player->set_vip_end_time(time()-1);
	string expiry = PROFESSIONVIPD->query_expiry_notice(player);
	PROFESSIONVIPD->acknowledge_expiry(player);
	string acknowledged = PROFESSIONVIPD->query_expiry_notice(player);
	legacy->set_vip_flag(4);
	legacy->set_vip_end_time(time()-60);
	PROFESSIONVIPD->record_raw_membership_snapshot(legacy);
	VIPD->get_vip_state(legacy);
	PROFESSIONVIPD->initialize_player(legacy);
	string legacy_expiry = PROFESSIONVIPD->query_expiry_notice(legacy);
	if(first!="" && second=="" && expiry!="" && acknowledged=="" &&
	   legacy->query_vip_flag()==0 && legacy_expiry!="")
		test_pass();
	else test_fail("监控节流或到期摘要错误");
	destroy_player(player);
	destroy_player(legacy);
}

void test_lingyi_aoe_target_configuration()
{
	test_start("灵医群攻阵营白名单免费、持久且拒绝非法参数");
	object healer = create_player("__testunit_lingyi_aoe_config__",
		"lingyi",50);
	object outsider = create_player("__testunit_lingyi_aoe_config_wrong__",
		"fangshi",50);
	mapping(string:int) defaults =
		PROFESSIONVIPD->query_lingyi_aoe_target_races(healer);
	int changed = PROFESSIONVIPD->set_lingyi_aoe_target_enabled(
		healer,"third",1);
	int disabled = PROFESSIONVIPD->set_lingyi_aoe_target_enabled(
		healer,"human",0);
	mapping(string:int) current =
		PROFESSIONVIPD->query_lingyi_aoe_target_races(healer);
	int invalid = PROFESSIONVIPD->set_lingyi_aoe_target_enabled(
		healer,"unknown",1);
	int wrong_profession = PROFESSIONVIPD->set_lingyi_aoe_target_enabled(
		outsider,"third",1);
	if(defaults["human"]==1 && defaults["monst"]==1 &&
	   defaults["third"]==0 && changed==1 && disabled==1 &&
	   current["human"]==0 && current["monst"]==1 &&
	   current["third"]==1 && invalid==0 && wrong_profession==0 &&
	   PROFESSIONVIPD->query_effective_level(healer)==0)
		test_pass();
	else
		test_fail("阵营默认值、切换、职业边界或免费性错误");
	destroy_player(healer);
	destroy_player(outsider);
}

int main()
{
	werror("\n========== 新职业会员助手测试 ==========\n");
	test_runtime_compile_and_wiring();
	test_trial_and_core_fairness();
	test_trial_preserved_for_active_member();
	test_slots_expiry_and_persistence();
	test_fangshi_auto_replenish();
	test_fangshi_resonance_pve_only();
	test_zhenyue_tier_and_pvp_boundaries();
	test_tianxiang_tier_and_pvp_boundaries();
	test_style_purchase_is_cosmetic();
	test_growth_pass_level_claims();
	test_monitor_throttle_and_expiry_notice();
	test_lingyi_aoe_target_configuration();
	werror("\n职业助手测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
