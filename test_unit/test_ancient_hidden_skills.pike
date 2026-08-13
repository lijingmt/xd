#!/usr/bin/env pike
/** 十职业太古隐藏技能、绑定、掉率和房间视觉事件回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[太古传承 %d] %s\n",test_results["total"],name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

object create_test_player(string name,string account_owner)
{
	object player = clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn = "太古绑定测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_account_owner(account_owner);
	return player;
}

object create_combat_test_player(string name,string race,string profession)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "太古实战测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->level = 190;
	player->set_att_by_level();
	player->set_base_life(50000);
	player->flush_life();
	player->set_life(player->query_life_max());
	player->set_mofa(player->query_mofa_max());
	player->set_base_hitte(100000);
	return player;
}

void test_catalog_and_weights()
{
	test_start("十职业各7个独立技能且高品阶权重严格递减");
	object daemon = ANCIENT_SKILLD;
	array(string) ids = daemon->query_all_skill_ids();
	array(int) weights = daemon->query_tier_drop_weights();
	array(string) tier_colors = ({"§3","§4","§5","§b","§C","§6","§E"});
	mapping(string:int) professions = ([]);
	array(string) failures = ({});
	foreach(ids,string id){
		mapping config = daemon->query_skill_config(id);
		professions[(string)config["profession"]]++;
		if((string)config["id"]!=id || (int)config["tier"]<1 ||
		   (int)config["tier"]>7 || daemon->query_colored_name(id)=="" ||
		   !has_prefix(daemon->query_colored_name(id),
			tier_colors[(int)config["tier"]-1]) ||
		   !has_suffix(daemon->query_colored_name(id),"§r"))
			failures += ({id});
	}
	if(sizeof(ids)!=70 || sizeof(professions)!=10 ||
	   sizeof(daemon->query_profession_skill_ids("jianxian"))!=7 ||
	   sizeof(daemon->query_profession_skill_ids("not_a_profession"))!=0 ||
	   daemon->query_profession_name("jianxian")!="剑仙")
		failures += ({"数量不是70/10"});
	foreach(indices(professions),string profession)
		if(professions[profession]!=7)
			failures += ({profession+"不是7个"});
	if(sizeof(weights)!=7)
		failures += ({"权重档不是7档"});
	else
		for(int i=1;i<sizeof(weights);i++)
			if(weights[i]>=weights[i-1])
				failures += ({"品阶权重未严格递减"});
	if(!sizeof(failures))
		test_pass();
	else
		test_fail(failures*" | ");
}

void test_all_programs_compile()
{
	test_start("70个技能与70本技能书全部编译并具有五阶成长");
	array(string) failures = ({});
	foreach(ANCIENT_SKILLD->query_all_skill_ids(),string id){
		object|zero book = 0;
		mixed err = catch {
			object skill = (object)(ROOT+"/gamelib/single/skills/"+id);
			book = clone(ROOT+"/gamelib/clone/item/book/"+id);
			mapping limits = skill->query_performs_level_limit_all();
			mapping config = ANCIENT_SKILLD->query_skill_config(id);
			if(!skill || !book || skill->query_name()!=id ||
			   skill->skill_rare!="ancient" || sizeof(limits)!=5 ||
			   (int)limits[1]!=90 || (int)limits[5]!=190 ||
			   book->skill_bname!=id || book->level_limit!=90 ||
			   book->profe_read_limit!=(string)config["profession"])
				failures += ({id+"属性不完整"});
		};
		if(err)
			failures += ({id+":"+describe_error(err)});
		if(book)
			destruct(book);
	}
	if(!sizeof(failures))
		test_pass();
	else
		test_fail(failures*" | ");
}

void test_all_ancient_skills_strengthened()
{
	test_start("70个太古技能按直伤、持续、治疗护盾、控制与嘲讽全系增强");
	array(string) failures = ({});
	foreach(ANCIENT_SKILLD->query_all_skill_ids(),string id){
		object skill = (object)(ROOT+"/gamelib/single/skills/"+id);
		mapping config = ANCIENT_SKILLD->query_skill_config(id);
		string type = (string)config["type"];
		int tier = (int)config["tier"];
		int old_delay = 65+tier*5;
		int strengthened = 0;
		if(!skill){
			failures += ({id+"无法加载"});
			continue;
		}
		if(skill->query_s_delayTime(5)>old_delay)
			failures += ({id+"冷却反向增加"});
		if(type=="dot")
			strengthened = skill->query_rare_dot_power_percent(5)==
				14+(tier+1)/2;
		else if(type=="curse"){
			strengthened = skill->query_rare_control_percent(5)==47+tier;
			if(id=="shuraqianlie"){
				if(skill->s_curse_type!="defend")
					failures += ({id+"未撕裂防御"});
			}
			else if(skill->s_curse_type!="hitte_percent" ||
			   skill->query_performs_attack(5)!=47+tier ||
			   search(skill->query_performs_desc(5),"最终命中率")==-1)
				failures += ({id+"仍使用无效的固定命中减值"});
		}
		else if(type=="buff" || type=="team_guard" || type=="heal")
			strengthened = skill->query_rare_vital_percent(5)==
				20+(tier+1)/2;
		else if(type=="taunt")
			strengthened = skill->query_performs_attack(5)>
				900+5*450+tier*120;
		else
			strengthened = skill->query_rare_power_percent(5)==195+tier*3;
		if(!strengthened)
			failures += ({id+"未命中对应增强公式"});
	}
	if(!sizeof(failures))
		test_pass();
	else
		test_fail(failures*" | ");
}

void test_drop_probability_contract()
{
	test_start("神技/太古低掉率、等级门槛及加权边界均由服务端决定");
	object items = ITEMSD;
	int mythic_rate = items->query_hidden_skill_drop_rate();
	int mythic_denominator = items->query_hidden_skill_drop_denominator();
	int ancient_weight = items->query_ancient_skill_total_weight();
	int ancient_denominator = items->query_ancient_skill_drop_denominator();
	int ratio_times_100 = mythic_rate*ancient_denominator*100/
		(mythic_denominator*ancient_weight);
	int valid = items->query_hidden_skill_book_count()==37 &&
		mythic_rate==37 && mythic_denominator==10000000 &&
		items->query_ancient_skill_book_count()==70 &&
		items->query_ancient_skill_min_level()==90 &&
		ancient_weight==390 && ancient_denominator==1250000000 &&
		!items->can_drop_ancient_skill_book(89,1) &&
		items->can_drop_ancient_skill_book(90,1) &&
		items->can_drop_ancient_skill_book(90,ancient_weight) &&
		!items->can_drop_ancient_skill_book(90,ancient_weight+1) &&
		ratio_times_100>=1100 && ratio_times_100<=1300 &&
		ANCIENT_SKILLD->query_weighted_book(1)!="" &&
		ANCIENT_SKILLD->query_weighted_book(ancient_weight)!="" &&
		ANCIENT_SKILLD->query_weighted_book(ancient_weight+1)=="";
	if(valid)
		test_pass();
	else
		test_fail(sprintf("mythic=%d/%d ancient=%d/%d ratioX100=%d",
			mythic_rate,mythic_denominator,ancient_weight,
			ancient_denominator,ratio_times_100));
}

void test_binding_and_legacy_compatibility()
{
	test_start("新书账号绑定不可流转，旧隐藏书交易规则保持不变");
	object first = create_test_player(
		"__testunit_ancient_char_a__","__testunit_ancient_account_a__");
	object same_account = create_test_player(
		"__testunit_ancient_char_b__","__testunit_ancient_account_a__");
	object other_account = create_test_player(
		"__testunit_ancient_char_c__","__testunit_ancient_account_b__");
	object book = clone(ROOT+"/gamelib/clone/item/book/taixujianhen");
	object old_book = clone(ROOT+"/gamelib/clone/item/book/xuehailieshang");
	int valid = book->query_bind_account_on_pickup()==1 &&
		book->bind_to_account(first)==1 &&
		book->query_account_bind_owner()=="__testunit_ancient_account_a__" &&
		book->bind_to_account(same_account)==1 &&
		book->bind_to_account(other_account)==0 &&
		book->query_item_canDrop()==0 && book->query_item_canGet()==1 &&
		book->query_item_canTrade()==0 && book->query_item_canSend()==0 &&
		book->query_item_canStorage()==0 && old_book->query_item_canTrade()==1 &&
		old_book->query_item_canSend()==1 && old_book->query_item_canStorage()==1;
	if(valid)
		test_pass();
	else
		test_fail("绑定所有权或新旧流转标志不符合契约");
	destruct(book);
	destruct(old_book);
	destruct(first);
	destruct(same_account);
	destruct(other_account);
}

void test_drop_and_visual_wiring()
{
	test_start("队伍/单人掉落、拾取绑定及人物宠物房间UI事件完整接线");
	string npc = Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike");
	string get = Stdio.read_file(ROOT+"/gamelib/cmds/get.pike");
	string fight = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike");
	string pet = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_pet_mod/assist.pike");
	string summon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/summond.pike");
	string app = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string html = Stdio.read_file(ROOT+"/vue_source/index.html");
	int valid = npc && get && fight && pet && summon && app && html &&
		sizeof(npc/"get_ancient_skill_book")-1>=2 &&
		search(get,"bind_to_account")!=-1 &&
		search(fight,"【战技显化】")!=-1 &&
		search(fight,"query_room_skill_manifestations")!=-1 &&
		search(fight,"observer_epoch")!=-1 &&
		search(fight,"is_visible(observer,caster)")!=-1 &&
		search(pet,"【灵宠显化】")!=-1 &&
		search(pet,"is_visible(observer,player)")!=-1 &&
		search(summon,"is_visible(ob,actor)")!=-1 &&
		search(app,"parseRoomPetManifestation")!=-1 &&
		search(app,"'ancient': 'skill-ancient-awakening'")!=-1 &&
		search(html,"room-skill-manifestation-stage")!=-1 &&
		search(html,"room-pet-manifestation")!=-1;
	if(valid)
		test_pass();
	else
		test_fail("掉落、绑定、广播或Vue表现链路缺失");
}

void test_shura_qianlie_scaled_armor_rend()
{
	test_start("狂妖五档修罗千裂按目标当前防御成长并真实生效");
	object skill = (object)(ROOT+
		"/gamelib/single/skills/shuraqianlie");
	object caster = create_combat_test_player(
		"__testunit_shura_caster__","monst","kuangyao");
	object target = create_combat_test_player(
		"__testunit_shura_target__","third","zhenyue");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int before_defense = 0;
	int curse_value = 0;
	int attempt = 0;
	int valid = !!skill && !!caster && !!target && !!room;
	if(valid){
		target->set_base_defend(1000000);
		caster->move(room);
		target->move(room);
		caster->skills["shuraqianlie"] = ({5,0});
		caster->_fight(target);
		before_defense = target->query_defend_power();
		for(attempt=0;attempt<5 &&
		   target->query_debuff("curse",0)!="defend";attempt++){
			caster->perform("shuraqianlie",1);
			if(target->query_debuff("curse",0)!="defend"){
				caster->f_skills["shuraqianlie"] = 0;
				caster->timeCold = 0;
				caster->set_mofa(caster->query_mofa_max());
			}
		}
		curse_value = (int)target->query_debuff("curse",1);
		valid = skill->s_curse_type=="defend" &&
			skill->query_performs_attack(5)==680 &&
			skill->query_rare_control_percent(5)==52 &&
			search(skill->query_performs_desc(5),"撕裂目标防御")!=-1 &&
			search(skill->query_performs_desc(5),"当前属性52%")!=-1 &&
			curse_value>=before_defense*52/100 &&
			target->query_defend_power()==before_defense-curse_value &&
			target->query_debuff("curse",2)==12;
		caster->_clean_fight();
		target->_clean_fight();
	}
	if(valid)
		test_pass();
	else
		test_fail(sprintf("type=%s base=%d before=%d curse=%d after=%d",
			skill ? skill->s_curse_type : "missing",
			skill ? skill->query_performs_attack(5) : 0,before_defense,
			curse_value,target ? target->query_defend_power() : 0));
	if(caster) destruct(caster);
	if(target) destruct(target);
}

void test_ancient_hit_curse_after_cap()
{
	test_start("太古命中诅咒在99封顶后按百分比压制并真实生效");
	object skill = (object)(ROOT+
		"/gamelib/single/skills/longhunpozhen");
	object caster = create_combat_test_player(
		"__testunit_ancient_curse_caster__","human","zhuxian");
	object target = create_combat_test_player(
		"__testunit_ancient_curse_target__","third","zhenyue");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int attempt = 0;
	int valid = !!skill && !!caster && !!target && !!room;
	if(valid){
		target->set_base_hitte(100000);
		caster->move(room);
		target->move(room);
		caster->skills["longhunpozhen"] = ({5,0});
		caster->_fight(target);
		for(attempt=0;attempt<5 &&
		   target->query_debuff("curse",0)!="hitte_percent";attempt++){
			caster->perform("longhunpozhen",1);
			if(target->query_debuff("curse",0)!="hitte_percent"){
				caster->f_skills["longhunpozhen"] = 0;
				caster->timeCold = 0;
				caster->set_mofa(caster->query_mofa_max());
			}
		}
		valid = skill->query_rare_control_percent(5)==49 &&
			target->query_debuff("curse",0)=="hitte_percent" &&
			target->query_debuff("curse",1)==49 &&
			target->query_debuff("curse",2)==12 &&
			target->query_if_hitte()==50;
		caster->_clean_fight();
		target->_clean_fight();
	}
	if(valid)
		test_pass();
	else
		test_fail(sprintf("type=%s value=%d hit=%d",
			target ? (string)target->query_debuff("curse",0) : "missing",
			target ? (int)target->query_debuff("curse",1) : 0,
			target ? target->query_if_hitte() : 0));
	if(caster) destruct(caster);
	if(target) destruct(target);
}

void test_room_skill_manifestation_snapshot()
{
	test_start("同房战技事件可轮询、去重、限界且不跨房间");
	object caster = create_test_player(
		"__testunit_skill_caster__","__testunit_skill_account_a__");
	object observer = create_test_player(
		"__testunit_skill_observer__","__testunit_skill_account_b__");
	object outsider = create_test_player(
		"__testunit_skill_outsider__","__testunit_skill_account_c__");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object away = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhen");
	object map_worker = (object)(ROOT+
		"/gamelib/single/daemons/map_workerd.pike");
	array(mapping(string:mixed)) events = ({});
	int accepted = 0;
	int rejected = 0;
	int valid = 0;
	mixed err = catch {
		caster->move(room);
		observer->move(room);
		outsider->move(away);
		for(int index=1;index<=8;index++){
			mapping event = ([
				"id":"skill-event-"+(string)index,
				"event_at":time(),
				"room_path":file_name(room),
				"worker_id":map_worker->query_local_worker_id(),
				"caster_userid":caster->query_name(),
				"caster_name":caster->query_name_cn(),
				"skill_name":"鸿蒙一剑",
				"skill_level":index,
				"target_name":"妖狼",
				"effect_desc":"战技气息扩散开来",
			]);
			accepted += observer->receive_room_skill_manifestation(
				event,caster);
			if(index==1)
				accepted += observer->receive_room_skill_manifestation(
					event,caster);
		}
		mapping outsider_event = ([
			"id":"outsider-event","event_at":time(),
			"room_path":file_name(room),
			"worker_id":map_worker->query_local_worker_id(),
		]);
		rejected = outsider->receive_room_skill_manifestation(
			outsider_event,caster);
		mapping invalid_event = ([
			"id":"invalid-event","event_at":time(),
			"room_path":file_name(room),
			"worker_id":map_worker->query_local_worker_id(),
			"skill_name":"伪造\n技能","skill_level":1,
		]);
		rejected += observer->receive_room_skill_manifestation(
			invalid_event,caster);
		events = observer->query_room_skill_manifestations();
		valid = accepted==9 && rejected==0 && sizeof(events)==6 &&
			(string)events[0]["id"]=="skill-event-3" &&
			(string)events[-1]["id"]=="skill-event-8";
		observer->move(away);
		valid = valid &&
			!sizeof(observer->query_room_skill_manifestations());
	};
	if(!err && valid)
		test_pass();
	else
		test_fail("room snapshot err="+(err ? describe_error(err) : "")+
			" accepted="+(string)accepted+" rejected="+(string)rejected+
			" events="+(string)sizeof(events));
	if(caster) destruct(caster);
	if(observer) destruct(observer);
	if(outsider) destruct(outsider);
}

int main()
{
	werror("\n========== 十职业太古隐藏技能测试 ==========\n");
	test_catalog_and_weights();
	test_all_programs_compile();
	test_all_ancient_skills_strengthened();
	test_drop_probability_contract();
	test_binding_and_legacy_compatibility();
	test_drop_and_visual_wiring();
	test_shura_qianlie_scaled_armor_rend();
	test_ancient_hit_curse_after_cap();
	test_room_skill_manifestation_snapshot();
	werror("太古传承：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
