#!/usr/bin/env pike
/**
 * 物理/法术平衡与跨区管理员边界测试。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[战斗平衡 %d] %s\n",test_results["total"],name);
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

object create_test_player(string name)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "战斗平衡测试角色";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("monst");
	player->set_profeId("kuangyao");
	player->setup_player("monst","kuangyao");
	player->level = 100;
	player->set_att_by_level();
	player->set_base_life(50000);
	player->flush_life();
	player->set_life(player->query_life_max());
	player->set_mofa(player->query_mofa_max());
	player->set_base_hitte(100000);
	return player;
}

void destroy_test_player(object|zero player)
{
	if(player)
		destruct(player);
}

void cleanup_test_player_file(string userid)
{
	string path = DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+
		userid+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

void test_diminishing_damage_formulas()
{
	test_start("物理法术递减减伤且穿透提供等量无视防御伤害");
	object player = create_test_player("__testunit_combat_formula__");
	int valid = player &&
		player->query_balanced_physical_damage(10000,0,0)==10000 &&
		player->query_balanced_physical_damage(10000,10000,0)==5000 &&
		player->query_balanced_physical_damage(10000,10000,3000)==8000 &&
		player->query_balanced_physical_damage(10000,10000,999999)==11000 &&
		player->query_balanced_physical_damage(10000,1000000,0)==99 &&
		player->query_balanced_physical_damage(10000,1000000,999999)==6099 &&
		player->query_balanced_magic_damage(10000,0,0)==10000 &&
		player->query_balanced_magic_damage(10000,400,0)==5000 &&
		player->query_balanced_magic_damage(10000,400,3000)==8000 &&
		player->query_balanced_magic_damage(10000,400,999999)==11000 &&
		player->query_balanced_magic_damage(10000,40000,0)==99 &&
		player->query_balanced_magic_damage(10000,40000,999999)==6099 &&
		player->query_balanced_penetration_damage(10000,3000)==3000 &&
		player->query_balanced_penetration_damage(10000,999999)==6000 &&
		player->query_balanced_physical_damage(0,-1,-1)==1 &&
		player->query_balanced_magic_damage(0,-1,-1)==1;
	if(valid)
		test_pass();
	else
		test_fail("递减防御、无视防御穿透或60%攻击封顶不符合预期");
	destroy_test_player(player);
}

void test_damage_formula_properties()
{
	test_start("伤害公式在高属性极值下保持单调且不越界");
	object player = create_test_player("__testunit_combat_properties__");
	array(int) raw_values = ({1,10,100,10000,1000000,1000000000});
	array(int) defend_values = ({0,1,400,10000,1000000,1000000000});
	int valid = player != 0;
	int previous_physical;
	int previous_magic;
	int current_physical;
	int current_magic;
	int penetrated_physical;
	int penetrated_magic;
	int i;
	int j;
	for(i=0;i<sizeof(raw_values);i++){
		previous_physical = raw_values[i]+1;
		previous_magic = raw_values[i]+1;
		for(j=0;j<sizeof(defend_values);j++){
			current_physical = player->query_balanced_physical_damage(
				raw_values[i],defend_values[j],0);
			current_magic = player->query_balanced_magic_damage(
				raw_values[i],defend_values[j],0);
			penetrated_physical = player->query_balanced_physical_damage(
				raw_values[i],defend_values[j],1000000000);
			penetrated_magic = player->query_balanced_magic_damage(
				raw_values[i],defend_values[j],1000000000);
			valid = valid && current_physical>=1 &&
				current_physical<=previous_physical &&
				current_magic>=1 && current_magic<=previous_magic &&
				penetrated_physical>=current_physical &&
				penetrated_physical<=raw_values[i]+
					raw_values[i]*60/100 &&
				penetrated_magic>=current_magic &&
				penetrated_magic<=raw_values[i]+
					raw_values[i]*60/100;
			previous_physical = current_physical;
			previous_magic = current_magic;
		}
	}
	if(valid)
		test_pass();
	else
		test_fail("防御单调性、穿透增益或十亿级属性边界错误");
	destroy_test_player(player);
}

void test_critical_and_dodge_caps()
{
	test_start("韧性不会让暴击弱于普攻且闪避穿透分档封顶");
	object player = create_test_player("__testunit_combat_caps__");
	int valid = player &&
		player->query_balanced_critical_damage(10000,0)==15000 &&
		player->query_balanced_critical_damage(10000,1000)==12500 &&
		player->query_balanced_critical_damage(10000,2000)==10000 &&
		player->query_balanced_critical_damage(10000,999999)==10000 &&
		player->query_balanced_dodge_penetration(-1,0)==0 &&
		player->query_balanced_dodge_penetration(9999,0)==400 &&
		player->query_balanced_dodge_penetration(9999,1)==600 &&
		player->query_balanced_dodge_penetration(350,1)==350;
	if(valid)
		test_pass();
	else
		test_fail("暴击韧性或40%/60%闪避穿透边界错误");
	destroy_test_player(player);
}

void test_zero_probability_boundaries()
{
	test_start("0%闪避和0%暴击不会因随机数为零而误触发");
	object player = create_test_player("__testunit_zero_probability__");
	int wrong_dodge = 0;
	int wrong_critical = 0;
	int i;
	player->set_debuff("curse",0,"dodge");
	player->set_debuff("curse",1,1000000);
	player->set_debuff("curse",2,10);
	for(i=0;i<500;i++){
		if(player->query_if_dodge())
			wrong_dodge++;
	}
	player->clean_debuff("curse");
	player->set_debuff("curse",0,"doub");
	player->set_debuff("curse",1,1000000);
	player->set_debuff("curse",2,10);
	for(i=0;i<500;i++){
		if(player->query_if_baoji())
			wrong_critical++;
	}
	if(wrong_dodge==0 && wrong_critical==0 &&
	   player->query_if_hitte()==99)
		test_pass();
	else
		test_fail(sprintf("零概率误触发：闪避%d次，暴击%d次",
			wrong_dodge,wrong_critical));
	destroy_test_player(player);
}

void test_xuehai_percentage_limits()
{
	test_start("血海裂伤增强至9%-12%且Boss完整持续最多约3%");
	object player = create_test_player("__testunit_xuehai_formula__");
	object skill = (object)(ROOT+"/gamelib/single/skills/xuehailieshang");
	int valid = player && skill &&
		skill->query_performs_attack(1)==75 &&
		skill->query_performs_attack(5)==100 &&
		player->query_xuehai_dot_damage(58000000,75,0)==435000 &&
		player->query_xuehai_dot_damage(58000000,100,0)==580000 &&
		player->query_xuehai_dot_damage(58000000,100,1)==145000 &&
		player->query_xuehai_dot_damage(0,100,0)==1;
	if(valid)
		test_pass();
	else
		test_fail("玩家9%-12%或Boss 3%持续伤害边界错误");
	destroy_test_player(player);
}

void test_kuangyao_wound_and_dot_priority()
{
	test_start("致残重伤按自身生命成长且弱持续伤害不能覆盖强效果");
	object player = create_test_player("__testunit_wound_formula__");
	object target = create_test_player("__testunit_wound_target__");
	object skill = (object)(ROOT+
		"/gamelib/single/skills/zhicanzhongshang");
	int valid = player && target && skill &&
		skill->query_performs_attack(1)==100 &&
		skill->query_performs_attack(10)==300 &&
		skill->query_performs_per(1)==20 &&
		skill->query_performs_per(10)==50 &&
		player->query_kuangyao_wound_damage(
			58000000,20,100,58000000,0,0)==116000 &&
		player->query_kuangyao_wound_damage(
			58000000,50,300,58000000,1,0)==290000 &&
		player->query_kuangyao_wound_damage(
			58000000,50,300,10000000,1,0)==50000 &&
		player->query_kuangyao_wound_damage(
			58000000,50,300,58000000,0,1)==145000 &&
		player->query_kuangyao_wound_damage(
			7000,20,100,58000000,0,0)==100;
	if(valid){
		valid = player->apply_nonstacking_dot(
			target,"xuehailieshang",1000,12)==1 &&
			player->apply_nonstacking_dot(
				target,"zhicanzhongshang",500,10)==0 &&
			target->query_debuff("dot",0)=="xuehailieshang" &&
			target->query_debuff("dot",1)==1000 &&
			target->query_debuff("dot",2)==12 &&
			player->apply_nonstacking_dot(
				target,"xuehailieshang",900,12)==0 &&
			target->query_debuff("dot",1)==1000 &&
			player->apply_nonstacking_dot(
				target,"xuehailieshang",1000,12)==1;
	}
	if(valid){
		target->set_debuff("dot",2,1);
		valid = player->apply_nonstacking_dot(
			target,"zhicanzhongshang",500,10)==1 &&
			target->query_debuff("dot",0)=="zhicanzhongshang" &&
			target->query_debuff("dot",1)==500 &&
			target->query_debuff("dot",2)==10 &&
			player->apply_nonstacking_dot(target,"none",0,0)==0;
	}
	if(valid)
		test_pass();
	else
		test_fail("生命成长、玩家/Boss上限或持续伤害覆盖优先级错误");
	destroy_test_player(player);
	destroy_test_player(target);
}

void test_formula_wiring_contract()
{
	test_start("物理法术所有主结算入口使用统一公式和正确毒抗");
	string source = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike");
	int valid = source &&
		sizeof(source/"this_object()->query_equip_add(\"attack_all\")")>=3 &&
		search(source,"s_phy_damage += this_object()->query_equip_add(\"attack_all\")")==-1 &&
		search(source,"s_weapon_add += this_object()->query_equip_add(\"attack_all\")")==-1 &&
		sizeof(source/"query_balanced_magic_damage(")>=4 &&
		sizeof(source/"query_balanced_critical_damage(")>=4 &&
		search(source,"query_equip_add(\"du_defend\")")==-1 &&
		search(source,"enemys[i]->reduce_fight_wear_armor(1)")!=-1 &&
		search(source,"random(100)<=h")==-1 &&
		search(source,"random(100)<=myhitte")==-1 &&
		search(source,"(object)MUD_SKILLSD")==-1 &&
		search(source,"result<0")!=-1;
	if(valid)
		test_pass();
	else
		test_fail("仍有旧法术/穿透/毒抗/attack_all结算路径");
}

void test_stacked_absorb_shields()
{
	test_start("两层吸收盾按剩余伤害顺序结算且不重复消耗");
	object|zero caster = 0;
	object|zero target = 0;
	object|zero weapon = 0;
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		object skill = (object)(ROOT+
			"/gamelib/single/skills/xuemoshijie");
		caster = create_test_player("__testunit_absorb_caster__");
		target = create_test_player("__testunit_absorb_target__");
		caster->move(room);
		target->move(room);
		weapon = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		weapon->move(caster);
		caster->wear(weapon);
		caster->skills["xuemoshijie"] = ({1,0});
		// 将闪避降为0；主动技能仍保留设计上的1%失手，所以若本次
		// 恰好失手就重置冷却后重试，避免双盾用例被随机命中污染。
		target->set_debuff("curse",0,"dodge");
		target->set_debuff("curse",1,1000000);
		target->set_debuff("curse",2,10);
		target->set_buff("buff",0,"absorb");
		target->set_buff("buff",1,1000000000);
		target->set_buff("buff",2,12);
		target->set_buff("buff2",0,"absorb");
		target->set_buff("buff2",1,1000000000);
		target->set_buff("buff2",2,12);
		int life_before = target->get_cur_life();
		caster->_fight(target);
		for(int attempt=0;attempt<5 &&
		   target->query_buff("buff",1)==1000000000;attempt++){
			caster->timeCold = 0;
			caster->f_skills["xuemoshijie"] = 0;
			caster->set_mofa(caster->query_mofa_max());
			caster->perform("xuemoshijie",1);
		}
		valid = skill && target->get_cur_life()==life_before &&
			target->query_buff("buff",1)<1000000000 &&
			target->query_buff("buff2",1)==1000000000;
	};
	if(err)
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("双盾仍重复消费或伤害泄漏: life="+
			(target ? target->get_cur_life() : 0)+
			" shield1="+(target ? target->query_buff("buff",1) : 0)+
			" shield2="+(target ? target->query_buff("buff2",1) : 0)+
			" "+error_desc);
	if(caster)
		caster->_clean_fight();
	if(target)
		target->_clean_fight();
	if(weapon)
		destruct(weapon);
	destroy_test_player(caster);
	destroy_test_player(target);
}

void test_physical_penetration_reaches_real_life_damage()
{
	test_start("物理穿透从装备属性进入真实技能扣血而非仅面板显示");
	object|zero plain = 0;
	object|zero pierced = 0;
	object|zero plain_target = 0;
	object|zero pierced_target = 0;
	object|zero plain_weapon = 0;
	object|zero pierced_weapon = 0;
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	string error_desc = "";
	string shielded_message = "";
	int plain_damage = 0;
	int pierced_damage = 0;
	int shielded_damage = 0;
	int valid = 0;
	mixed err = catch {
		plain = create_test_player("__testunit_penetration_plain__");
		pierced = create_test_player("__testunit_penetration_pierced__");
		plain_target = create_test_player("__testunit_penetration_target_a__");
		pierced_target = create_test_player("__testunit_penetration_target_b__");
		plain->set_profeId("yinggui");
		pierced->set_profeId("yinggui");
		plain->setup_player("monst","yinggui");
		pierced->setup_player("monst","yinggui");
		plain->set_att_by_level();
		pierced->set_att_by_level();
		plain->move(room);
		pierced->move(room);
		plain_target->move(room);
		pierced_target->move(room);
		plain_weapon = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		pierced_weapon = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		plain_weapon->set_attack_power(10000);
		plain_weapon->set_attack_power_limit(10000);
		pierced_weapon->set_attack_power(10000);
		pierced_weapon->set_attack_power_limit(10000);
		pierced_weapon->set_wulichuantou_add(6000);
		plain_weapon->move(plain);
		pierced_weapon->move(pierced);
		plain->wield(plain_weapon);
		pierced->wield(pierced_weapon);
		plain->skills["fuji"] = ({1,0});
		pierced->skills["fuji"] = ({1,0});
		plain->set_debuff("curse",0,"doub");
		plain->set_debuff("curse",1,1000000);
		plain->set_debuff("curse",2,10);
		pierced->set_debuff("curse",0,"doub");
		pierced->set_debuff("curse",1,1000000);
		pierced->set_debuff("curse",2,10);
		plain_target->set_base_dodge(-1000000);
		pierced_target->set_base_dodge(-1000000);
		plain_target->set_base_defend(50000);
		pierced_target->set_base_defend(50000);
		plain_target->set_base_life(1000000000);
		pierced_target->set_base_life(1000000000);
		plain_target->flush_life();
		pierced_target->flush_life();
		plain->set_mofa(plain->query_mofa_max());
		pierced->set_mofa(pierced->query_mofa_max());
		int plain_life = plain_target->get_cur_life();
		int pierced_life = pierced_target->get_cur_life();
		plain->_fight(plain_target);
		pierced->_fight(pierced_target);
		plain->perform("fuji",1);
		pierced->perform("fuji",1);
		plain_damage = plain_life-plain_target->get_cur_life();
		pierced_damage = pierced_life-pierced_target->get_cur_life();
		// 山河壁吸收后，战斗正文必须显示实际扣血0；穿透数字只标注
		// 已计入基础伤害，不能再让玩家误认为护盾外还应额外扣血。
		pierced->drain_catch_tell(0,10);
		pierced->timeCold = 0;
		pierced->f_skills["fuji"] = 0;
		pierced->set_mofa(pierced->query_mofa_max());
		pierced_target->apply_team_guard(1000000000,12);
		pierced_life = pierced_target->get_cur_life();
		pierced->perform("fuji",1);
		shielded_damage = pierced_life-pierced_target->get_cur_life();
		shielded_message = pierced->drain_catch_tell(0,10);
		valid = plain->query_equip_add("wulichuantou_add")==0 &&
			pierced->query_equip_add("wulichuantou_add")==6000 &&
			plain_damage>0 && pierced_damage-plain_damage==9000 &&
			shielded_damage==0 &&
			search(shielded_message,"0点实际伤害")!=-1 &&
			search(shielded_message,
				"物理穿透计入基础伤害 9000")!=-1;
	};
	if(err)
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("物理穿透真实扣血或护盾后显示错误: 普通="+
			plain_damage+" 穿透="+pierced_damage+" 护盾后="+
			shielded_damage+" 文本="+shielded_message+" "+error_desc);
	if(plain)
		plain->_clean_fight();
	if(pierced)
		pierced->_clean_fight();
	if(plain_target)
		plain_target->_clean_fight();
	if(pierced_target)
		pierced_target->_clean_fight();
	if(plain_weapon)
		destruct(plain_weapon);
	if(pierced_weapon)
		destruct(pierced_weapon);
	destroy_test_player(plain);
	destroy_test_player(pierced);
	destroy_test_player(plain_target);
	destroy_test_player(pierced_target);
}

void test_missing_skill_safety()
{
	test_start("失效技能和陈旧自动技能不会中断战斗循环");
	object|zero caster = 0;
	object|zero target = 0;
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		caster = create_test_player("__testunit_missing_skill_caster__");
		target = create_test_player("__testunit_missing_skill_target__");
		caster->move(room);
		target->move(room);
		caster->skills_enable = "__removed_skill__";
		caster->_fight(target);
		caster->perform("__removed_skill__",1);
		valid = caster->skills_enable=="" && caster->in_combat;
	};
	if(err)
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("未知技能处理仍会抛错或残留自动技能: "+error_desc);
	if(caster)
		caster->_clean_fight();
	if(target)
		target->_clean_fight();
	destroy_test_player(caster);
	destroy_test_player(target);
}

void test_cross_zone_admin_security()
{
	test_start("jinghaha与mumu215跨区可管理且相似后缀不能越权");
	object manager = (object)(ROOT+
		"/gamelib/single/daemons/managed.pike");
	string child_id = "xd99jinghahac2a1b2c3d4";
	string forged_child_id = "xd99jinghahac2f1e2d3c4";
	object|zero child = 0;
	object|zero forged_child = 0;
	int child_saved = 0;
	int forged_child_saved = 0;
	cleanup_test_player_file(child_id);
	cleanup_test_player_file(forged_child_id);
	child = create_test_player(child_id);
	forged_child = create_test_player(forged_child_id);
	if(child){
		child->set_account_owner("xd99jinghaha");
		child_saved = child->save_with_result();
	}
	if(forged_child){
		forged_child->set_account_owner("xd99evilowner");
		forged_child_saved = forged_child->save_with_result();
	}
	destroy_test_player(child);
	destroy_test_player(forged_child);
	int valid = manager &&
		manager->is_cross_zone_admin("jinghaha")==1 &&
		manager->is_cross_zone_admin("mumu215")==1 &&
		manager->is_cross_zone_admin("xd01jinghaha")==1 &&
		manager->is_cross_zone_admin("tx02jinghaha")==1 &&
		manager->is_cross_zone_admin("XD99mumu215")==1 &&
		manager->is_cross_zone_admin("xd01mumu215")==1 &&
		manager->is_cross_zone_admin("tx99jinghaha")==1 &&
		manager->checkpower("tx37mumu215")=="admin" &&
		manager->is_cross_zone_admin("xd00jinghaha")==0 &&
		manager->is_cross_zone_admin("xd1jinghaha")==0 &&
		manager->is_cross_zone_admin("xd100jinghaha")==0 &&
		manager->is_cross_zone_admin("abc01jinghaha")==0 &&
		manager->is_cross_zone_admin("zz01jinghaha")==0 &&
		manager->is_cross_zone_admin("xd01eviljinghaha")==0 &&
		manager->is_cross_zone_admin("xd01jinghaha119")==0 &&
		manager->is_cross_zone_admin("1234mumu215")==0 &&
		manager->checkpower("xd01eviljinghaha")=="nopower" &&
		manager->checkpower("zz01mumu215")=="nopower" &&
		child_saved && forged_child_saved &&
		manager->is_cross_zone_admin(child_id)==1 &&
		manager->checkpower(child_id)=="admin" &&
		manager->is_cross_zone_admin(forged_child_id)==0 &&
		manager->checkpower(forged_child_id)=="nopower";
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/managed.pike");
	valid = valid && source &&
		search(source,"if(tmp2&&sizeof(tmp2))")!=-1 &&
		search(source,"Stdio.write_file(CHAT_PATH,tmp2)")!=-1;
	if(valid)
		test_pass();
	else
		test_fail("跨区管理员识别或防后缀越权边界错误");
	cleanup_test_player_file(child_id);
	cleanup_test_player_file(forged_child_id);
}

int main()
{
	werror("\n========== 物理/法术平衡测试 ==========\n");
	test_diminishing_damage_formulas();
	test_damage_formula_properties();
	test_critical_and_dodge_caps();
	test_zero_probability_boundaries();
	test_xuehai_percentage_limits();
	test_kuangyao_wound_and_dot_priority();
	test_formula_wiring_contract();
	test_stacked_absorb_shields();
	test_physical_penetration_reaches_real_life_damage();
	test_missing_skill_safety();
	test_cross_zone_admin_security();
	werror("\n战斗平衡测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
