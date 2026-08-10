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

int main()
{
	werror("\n========== 十职业太古隐藏技能测试 ==========\n");
	test_catalog_and_weights();
	test_all_programs_compile();
	test_drop_probability_contract();
	test_binding_and_legacy_compatibility();
	test_drop_and_visual_wiring();
	werror("太古传承：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
