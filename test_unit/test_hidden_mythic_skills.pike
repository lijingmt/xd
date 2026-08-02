#!/usr/bin/env pike
/**
 * 十职业隐藏大神传承运行时测试。
 *
 * 覆盖：
 * - 70级怪物门槛、总掉率与三十一本等概率池
 * - 秘籍不进入商店，技能与书籍可运行时加载
 * - 80级与职业限制、背包学习入口、真实读书
 * - 十职业的爆发、群疗、增益、DOT、控制与守护
 * - 长冷却、短持续、高法力的平衡边界
 * - 鹤灵不复活主人、灵治进阶后的新手指引
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

mapping(string:array(string)) hidden_skills = ([
	"jianxian":({
		"wanjianguizong",
		"taiqingjianyu",
		"pozhenjianyi",
	}),
	"fangshi":({
		"taixulingyun",
		"wanlingchaosheng",
		"sixiangfengjin",
	}),
	"yushi":({
		"jiutianleiyin",
		"taiyixuanguang",
		"bingpochanshen",
	}),
	"zhuxian":({
		"zhutianwujie",
		"tianshajianyi",
		"wuyingfenghou",
	}),
	"kuangyao":({
		"xuemoshijie",
		"shurakuangyi",
		"xuehailieshang",
	}),
	"wuyao":({
		"huangquanwudu",
		"wanxiangshihun",
		"jiuyouduzhang",
	}),
	"yinggui":({
		"wuyingjuemie",
		"jiuyouguibu",
		"liudaozhangmu",
	}),
	"zhenyue":({
		"wanshanchaogong",
		"buzhouzhenji",
		"tiandichengbi",
	}),
	"tianxiang":({
		"xinghezhuiluo",
		"zhoutianjingzhi",
		"wanxiangxingbi",
	}),
	"lingyi":({
		"cixinpudu",
		"huimingtianlu",
		"wanmuxinchun",
		"liuhehuichun",
	}),
]);

mapping(string:string) profession_cn = ([
	"jianxian":"剑仙",
	"fangshi":"方士",
	"yushi":"羽士",
	"zhuxian":"诛仙",
	"kuangyao":"狂妖",
	"wuyao":"巫妖",
	"yinggui":"影鬼",
	"zhenyue":"镇越",
	"tianxiang":"天象",
	"lingyi":"灵医",
]);

mapping(string:string) profession_race = ([
	"jianxian":"human",
	"fangshi":"third",
	"yushi":"human",
	"zhuxian":"human",
	"kuangyao":"monst",
	"wuyao":"monst",
	"yinggui":"monst",
	"zhenyue":"third",
	"tianxiang":"third",
	"lingyi":"third",
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[隐藏大神传承 %d] %s\n",test_results["total"],name);
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

object create_player(string player_name,string race_id,
	string profession_id,int player_level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;

	player->set_name(player_name);
	player->name_cn = "隐藏传承测试角色";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	player->level = player_level;
	player->set_att_by_level();
	player->set_base_life(50000);
	player->flush_life();
	player->set_life(player->query_life_max());
	player->set_mofa(player->query_mofa_max());
	player->set_base_hitte(100000);
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	SUMMOND->player_logout(player->query_name());
	destruct(player);
}

void test_drop_contract_runtime()
{
	test_start("三十一本秘籍单本等概率且仅70级以上怪物掉落");
	string csv =
		Stdio.read_file(ROOT+"/gamelib/data/can_buy_book_list.csv");
	string npc_source =
		Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike");
	string team_drop_source = "";
	array(string) actual = ({});
	array(string) expected = ({});
	int hidden_in_store = 0;
	int failed = 0;
	int team_hidden_call = -1;
	int team_hidden_handler = -1;
	int team_boss_branch = -1;

	foreach(sort(indices(hidden_skills)),string profession_id){
		foreach(hidden_skills[profession_id],string skill_name){
			expected += ({"book/"+skill_name});
			if(csv && search(csv,"book/"+skill_name) != -1)
				hidden_in_store++;
		}
	}
	for(int i=0;i<ITEMSD->query_hidden_skill_book_count();i++)
		actual += ({ITEMSD->query_hidden_skill_book(i)});

	foreach(expected,string book_path){
		if(search(actual,book_path)==-1)
			failed++;
	}
	if(ITEMSD->query_hidden_skill_book_count()!=31 ||
	   ITEMSD->query_hidden_skill_min_level()!=70 ||
	   ITEMSD->query_hidden_skill_drop_rate()!=31 ||
	   ITEMSD->can_drop_hidden_skill_book(69,1)!=0 ||
	   ITEMSD->can_drop_hidden_skill_book(70,0)!=0 ||
	   ITEMSD->can_drop_hidden_skill_book(70,1)!=1 ||
	   ITEMSD->can_drop_hidden_skill_book(70,30)!=1 ||
	   ITEMSD->can_drop_hidden_skill_book(70,31)!=1 ||
	   ITEMSD->can_drop_hidden_skill_book(70,32)!=0)
		failed++;

	if(npc_source){
		int team_start =
			search(npc_source,"//3.物品分配，设置为队伍拾取");
		int team_boss = search(npc_source,
			"if(this_object()->_boss)",team_start);
		int team_end = search(npc_source,
			"//团队公告掉落物品",team_boss);
		if(team_start!=-1 && team_boss!=-1 && team_end!=-1)
			team_drop_source = npc_source[team_start..team_end];
	}
	if(team_drop_source){
		team_hidden_call =
			search(team_drop_source,"get_hidden_skill_book");
		team_hidden_handler =
			search(team_drop_source,"if(ob_hidden&&");
		team_boss_branch =
			search(team_drop_source,"if(this_object()->_boss)");
	}
	if(!npc_source ||
	   sizeof(npc_source/"get_hidden_skill_book")!=3 ||
	   sizeof(npc_source/"log_hidden_skill_drop")!=4 ||
	   search(npc_source,"/log/hidden_skill_drop.log")==-1 ||
	   !team_drop_source ||
	   team_hidden_call==-1 ||
	   team_hidden_handler==-1 ||
	   team_boss_branch==-1 ||
	   team_hidden_call>team_boss_branch ||
	   team_hidden_handler>team_boss_branch ||
	   hidden_in_store!=0)
		failed++;

	if(failed==0)
		test_pass();
	else
		test_fail(sprintf(
			"掉落池、边界或隐藏商店约束失败=%d, 商店泄露=%d",
			failed,hidden_in_store));
}

void test_dynamic_monster_eligibility_runtime()
{
	test_start("70级动态怪使用实际等级参与隐藏秘籍掉落");
	object|zero player = 0;
	object|zero npc = 0;
	object|zero original_player = this_player();
	int npc_level = 0;
	string room_source =
		Stdio.read_file(ROOT+"/lowlib/mudlib/inherit/room.pike");
	string fbd_source =
		Stdio.read_file(ROOT+"/gamelib/single/daemons/fbd.pike");
	string error_desc = "";

	mixed err = catch {
		player = create_player(
			"__testunit_mythic_dynamic__","third","fangshi",70);
		set_this_player(player);
		npc = MUD_ROOMD->get_npc_level(
			"/gamelib/clone/npc/bishuitan/50bishuijingbing",70);
		if(npc)
			npc_level = npc->query_level();
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && player && npc &&
	   npc_level>=70 && npc_level<=72 &&
	   ITEMSD->can_drop_hidden_skill_book(npc_level,1)==1 &&
	   room_source &&
	   search(room_source,"dongtai_npc_start_level=70")!=-1 &&
	   search(room_source,"fb_status == 0")!=-1 &&
	   fbd_source &&
	   search(fbd_source,
		"search(fb_id,\"posanzhidi\") != -1")!=-1)
		test_pass();
	else
		test_fail(sprintf(
			"动态怪等级=%d 或动态范围不符: %s",
			npc_level,error_desc));

	if(npc)
		destruct(npc);
	destroy_player(player);
}

void test_skill_and_book_config_runtime()
{
	test_start("三十一项技能与秘籍完整加载且均为五段大神传承");
	int checked = 0;
	int failed = 0;

	foreach(sort(indices(hidden_skills)),string profession_id){
		foreach(hidden_skills[profession_id],string skill_name){
			object|zero skill = 0;
			object|zero book = 0;
			mixed err = catch {
				skill = (object)(ROOT+
					"/gamelib/single/skills/"+skill_name);
				book = clone(ROOT+
					"/gamelib/clone/item/book/"+skill_name);
			};
			checked++;
			if(err || !skill || !book ||
			   skill->skill_rare!="mythic" ||
			   skill->query_skill_level_max()!=5 ||
			   search(skill->skill_type,profession_id)==-1 ||
			   book->skill_bname!=skill_name ||
			   book->level_limit!=80 ||
			   book->profe_read_limit!=profession_cn[profession_id] ||
			   book->query_item_canDrop()!=1 ||
			   book->query_item_canGet()!=1 ||
			   book->query_item_canTrade()!=1 ||
			   book->query_item_canSend()!=1 ||
			   book->query_item_canStorage()!=1)
				failed++;
			else{
				for(int level=1;level<=5;level++){
					if(skill->query_performs_level_limit(level)!=
					   60+level*20 ||
					   skill->query_performs_cast(level)<=0 ||
					   skill->query_performs_desc(level)=="")
						failed++;
				}
			}
			if(book)
				destruct(book);
		}
	}

	if(checked==31 && failed==0)
		test_pass();
	else
		test_fail(sprintf("加载=%d, 配置失败=%d",checked,failed));
}

void test_real_book_learning()
{
	test_start("80级职业限制、背包学习入口与三十一本真实学习");
	object|zero low_fangshi = 0;
	object|zero original_player = this_player();
	mapping(string:object) players = ([]);
	int learned = 0;
	int low_rejected = 0;
	int profession_rejected = 0;
	int duplicate_preserved = 0;
	int failed = 0;
	string error_desc = "";

	mixed err = catch {
		foreach(sort(indices(hidden_skills)),string profession_id){
			players[profession_id] = create_player(
				"__testunit_mythic_learn_"+profession_id+"__",
				profession_race[profession_id],profession_id,80);
		}
		low_fangshi = create_player(
			"__testunit_mythic_learn_low__","third","fangshi",79);

		foreach(sort(indices(hidden_skills)),string profession_id){
			foreach(hidden_skills[profession_id],string skill_name){
				object low_book = clone(ROOT+
					"/gamelib/clone/item/book/"+skill_name);
				set_this_player(low_fangshi);
				if(!low_book || low_book->read()!=4 ||
				   low_book->read_flag!=1)
					failed++;
				else
					low_rejected++;
				if(low_book)
					destruct(low_book);

				object wrong_player = players["fangshi"];
				if(profession_id=="fangshi")
					wrong_player = players["yushi"];
				object wrong_book = clone(ROOT+
					"/gamelib/clone/item/book/"+skill_name);
				set_this_player(wrong_player);
				if(!wrong_book || wrong_book->read()!=3 ||
				   wrong_book->read_flag!=1)
					failed++;
				else
					profession_rejected++;
				if(wrong_book)
					destruct(wrong_book);

				object book = clone(ROOT+
					"/gamelib/clone/item/book/"+skill_name);
				set_this_player(players[profession_id]);
				string links = book ?
					book->query_inventory_links(1) : "";
				if(!book ||
				   search(links,"[学习:read ")==-1 ||
				   book->read()!=1 ||
				   !players[profession_id]->skills[skill_name])
					failed++;
				else
					learned++;

				object duplicate_book = clone(ROOT+
					"/gamelib/clone/item/book/"+skill_name);
				if(!duplicate_book || duplicate_book->read()!=2 ||
				   duplicate_book->read_flag!=1 ||
				   !players[profession_id]->skills[skill_name])
					failed++;
				else
					duplicate_preserved++;
				if(duplicate_book)
					destruct(duplicate_book);
			}
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && learned==31 && low_rejected==31 &&
	   profession_rejected==31 && duplicate_preserved==31 && failed==0)
		test_pass();
	else
		test_fail(sprintf(
			"学习=%d, 低等级拒绝=%d, 跨职业拒绝=%d, 重复保留=%d, 失败=%d: %s",
			learned,low_rejected,profession_rejected,
			duplicate_preserved,failed,error_desc));

	foreach(values(players),object player)
		destroy_player(player);
	destroy_player(low_fangshi);
}

void test_damage_profession_burst_runtime()
{
	test_start("九个伤害职业大神爆发真实命中并进入长冷却");
	mapping(string:string) burst_skills = ([
		"jianxian":"wanjianguizong",
		"fangshi":"taixulingyun",
		"yushi":"jiutianleiyin",
		"zhuxian":"zhutianwujie",
		"kuangyao":"xuemoshijie",
		"wuyao":"huangquanwudu",
		"yinggui":"wuyingjuemie",
		"zhenyue":"buzhouzhenji",
		"tianxiang":"xinghezhuiluo",
	]);
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int checked = 0;
	int failed = 0;
	string error_desc = "";

	foreach(sort(indices(burst_skills)),string profession_id){
		object|zero caster = 0;
		object|zero enemy = 0;
		object|zero weapon = 0;
		mixed err = catch {
			string skill_name = burst_skills[profession_id];
			caster = create_player(
				"__testunit_mythic_burst_"+profession_id+"__",
				profession_race[profession_id],profession_id,100);
			enemy = create_player(
				"__testunit_mythic_target_"+profession_id+"__",
				"third","fangshi",100);
			caster->move(room);
			enemy->move(room);
			if(search(({"jianxian","zhuxian","kuangyao","yinggui","zhenyue"}),
			   profession_id)!=-1){
				weapon = clone(ROOT+
					"/gamelib/clone/item/weapon/1taomujian/1taomujian");
				weapon->move(caster);
				caster->wear(weapon);
				if(!weapon->equiped)
					failed++;
			}
			caster->skills[skill_name] = ({1,0});
			if(profession_id=="tianxiang")
				caster->add_tianxiang_star_marks(3);
			// 本用例只验证技能伤害、耗蓝与冷却；关闭目标闪避，
			// 避免正常闪避概率把功能回归误报成随机失败。
			enemy->set_debuff("curse",0,"dodge");
			enemy->set_debuff("curse",1,1000000);
			enemy->set_debuff("curse",2,10);
			int life_before = enemy->get_cur_life();
			int mofa_before = caster->get_cur_mofa();
			int performed = 0;
			caster->_fight(enemy);
			// 引擎对物理与法术命中率都硬封顶为 99%。最多重试
			// 五次，每次都重置冷却与法力，避免把正常的 1% 未命中
			// 误报为回归，同时仍以真实扣血、耗蓝与长冷却为通过条件。
			for(int attempt=0;attempt<5;attempt++){
				life_before = enemy->get_cur_life();
				mofa_before = caster->get_cur_mofa();
				caster->perform(skill_name,1);
				if(enemy->get_cur_life()<life_before){
					performed = 1;
					break;
				}
				caster->f_skills[skill_name] = 0;
				caster->timeCold = 0;
				caster->set_mofa(caster->query_mofa_max());
			}
			if(!performed ||
			   caster->get_cur_mofa()>=mofa_before ||
			   caster->f_skills[skill_name]!=61 ||
			   (profession_id=="tianxiang" &&
			    caster->query_tianxiang_star_marks()!=0)){
				failed++;
				error_desc += sprintf(
					"%s首次施放失败(life=%d/%d,mofa=%d/%d,cold=%d); ",
					profession_id,enemy->get_cur_life(),life_before,
					caster->get_cur_mofa(),mofa_before,
					(int)caster->f_skills[skill_name]);
			}
			else{
				int life_after = enemy->get_cur_life();
				int mofa_after = caster->get_cur_mofa();
				caster->perform(skill_name,1);
				if(enemy->get_cur_life()!=life_after ||
				   caster->get_cur_mofa()!=mofa_after ||
				   caster->f_skills[skill_name]!=61){
					failed++;
					error_desc += profession_id+"冷却拦截失败; ";
				}
				else
					checked++;
			}
		};
		if(err){
			failed++;
			error_desc += describe_error(err);
		}
		if(caster)
			caster->_clean_fight();
		destroy_player(caster);
		destroy_player(enemy);
	}

	if(checked==9 && failed==0)
		test_pass();
	else
		test_fail(sprintf(
			"真实爆发=%d, 失败=%d: %s",checked,failed,error_desc));
}

void test_physical_mythic_weapon_gate()
{
	test_start("五个物理职业大神爆发缺少主手武器时不会误扣法力");
	mapping(string:string) physical_skills = ([
		"jianxian":"wanjianguizong",
		"zhuxian":"zhutianwujie",
		"kuangyao":"xuemoshijie",
		"yinggui":"wuyingjuemie",
		"zhenyue":"buzhouzhenji",
	]);
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int checked = 0;
	int failed = 0;
	string error_desc = "";

	foreach(sort(indices(physical_skills)),string profession_id){
		object|zero caster = 0;
		object|zero enemy = 0;
		mixed err = catch {
			string skill_name = physical_skills[profession_id];
			caster = create_player(
				"__testunit_mythic_unarmed_"+profession_id+"__",
				profession_race[profession_id],profession_id,100);
			enemy = create_player(
				"__testunit_mythic_unarmed_target_"+profession_id+"__",
				"third","fangshi",100);
			caster->move(room);
			enemy->move(room);
			caster->skills[skill_name] = ({1,0});
			int life_before = enemy->get_cur_life();
			int mofa_before = caster->get_cur_mofa();
			caster->_fight(enemy);
			caster->perform(skill_name,1);
			if(enemy->get_cur_life()!=life_before ||
			   caster->get_cur_mofa()!=mofa_before ||
			   caster->f_skills[skill_name])
				failed++;
			else
				checked++;
		};
		if(err){
			failed++;
			error_desc += describe_error(err);
		}
		if(caster)
			caster->_clean_fight();
		destroy_player(caster);
		destroy_player(enemy);
	}

	if(checked==5 && failed==0)
		test_pass();
	else
		test_fail(sprintf(
			"武器门槛=%d, 失败=%d: %s",checked,failed,error_desc));
}

void test_utility_and_control_runtime()
{
	test_start("九个伤害职业增益、持续伤害、控制与守护均真实生效");
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int failed = 0;
	string error_desc = "";

	mapping(string:array(string)) cases = ([
		"taiqingjianyu":({"human","jianxian","buff","defend","1800"}),
		"pozhenjianyi":({"human","jianxian","curse","defend","1200"}),
		"taiyixuanguang":({"human","yushi","buff","absorb","4500"}),
		"sixiangfengjin":({"third","fangshi","curse","attack","1200"}),
		"bingpochanshen":({"human","yushi","curse","speed","2"}),
		"tianshajianyi":({"human","zhuxian","buff","doub","12"}),
		"wuyingfenghou":({"human","zhuxian","dot","wuyingfenghou","400"}),
		"shurakuangyi":({"monst","kuangyao","buff","physical_attack_percent","20"}),
		"xuehailieshang":({"monst","kuangyao","dot","xuehailieshang","75"}),
		"wanxiangshihun":({"monst","wuyao","dot","wanxiangshihun","400"}),
		"jiuyouduzhang":({"monst","wuyao","curse","life","30"}),
		"jiuyouguibu":({"monst","yinggui","buff","dodge","12"}),
		"liudaozhangmu":({"monst","yinggui","curse","hitte","400"}),
		"zhoutianjingzhi":({"third","tianxiang","curse","hitte","18"}),
		"wanxiangxingbi":({"third","tianxiang","buff","absorb","3800"}),
	]);

	foreach(sort(indices(cases)),string skill_name){
		array(string) info = cases[skill_name];
		object|zero caster = 0;
		object|zero enemy = 0;
		mixed err = catch {
			caster = create_player(
				"__testunit_mythic_utility_"+skill_name+"__",
				info[0],info[1],100);
			enemy = create_player(
				"__testunit_mythic_utility_target_"+skill_name+"__",
				"third","fangshi",100);
			caster->move(room);
			enemy->move(room);
			caster->skills[skill_name] = ({1,0});
			// 主动技能命中率最高为99%，即使测试角色属性很高仍保留1%
			// 正常抵抗概率；给施法者补命中并在确认抵抗时有限重试。
			caster->set_buff("attri_vice",0,"hitte");
			caster->set_buff("attri_vice",1,1000000);
			caster->set_buff("attri_vice",2,10);
			int derived_before = 0;
			if(skill_name=="taiqingjianyu")
				derived_before = caster->query_defend_power();
			else if(skill_name=="pozhenjianyi")
				derived_before = enemy->query_defend_power();
			else if(skill_name=="shurakuangyi")
				derived_before = caster->query_base_damage();
			else if(skill_name=="liudaozhangmu")
				derived_before = enemy->query_if_hitte();
			caster->_fight(enemy);
			for(int attempt=0;attempt<5;attempt++){
				caster->perform(skill_name,1);
				object current_target = info[2]=="buff" ? caster : enemy;
				mixed current_type = info[2]=="buff" ?
					current_target->query_buff(info[2],0) :
					current_target->query_debuff(info[2],0);
				if(current_type==info[3] || info[2]=="buff")
					break;
				caster->f_skills[skill_name] = 0;
				caster->timeCold = 0;
				caster->set_mofa(caster->query_mofa_max());
			}

			object effect_target =
				info[2]=="buff" ? caster : enemy;
			mixed effect_type = info[2]=="buff" ?
				effect_target->query_buff(info[2],0) :
				effect_target->query_debuff(info[2],0);
			mixed effect_value = info[2]=="buff" ?
				effect_target->query_buff(info[2],1) :
				effect_target->query_debuff(info[2],1);
			int expected_effect = (int)info[4];
			if(skill_name=="xuehailieshang")
				expected_effect = caster->query_xuehai_dot_damage(
					enemy->query_life_max(),(int)info[4],0);
			if(effect_type!=info[3] ||
			   ((skill_name=="taiyixuanguang" ||
			     skill_name=="wanxiangxingbi") &&
			    effect_value<(int)info[4]) ||
			   (skill_name!="taiyixuanguang" &&
			    skill_name!="wanxiangxingbi" &&
			    effect_value!=expected_effect)){
				failed++;
				error_desc += sprintf("%s效果=%O/%O 期望=%s/%d; ",
					skill_name,effect_type,effect_value,info[3],expected_effect);
			}
			if(skill_name=="taiqingjianyu" &&
			   caster->query_defend_power()!=derived_before+1800){
				failed++;
				error_desc += skill_name+"衍生防御错误; ";
			}
			else if(skill_name=="pozhenjianyi"){
				int expected_defend = derived_before-1200;
				if(expected_defend<0)
					expected_defend=0;
				if(enemy->query_defend_power()!=expected_defend){
					failed++;
					error_desc += skill_name+"衍生破防错误; ";
				}
			}
			else if(skill_name=="shurakuangyi" &&
			   caster->query_base_damage()!=derived_before){
				failed++;
				error_desc += skill_name+"错误改写基础攻击; ";
			}
			else if(skill_name=="liudaozhangmu"){
				int expected_hitte = derived_before-400;
				if(expected_hitte<0)
					expected_hitte=0;
				if(enemy->query_if_hitte()!=expected_hitte){
					failed++;
					error_desc += skill_name+"衍生命中错误; ";
				}
			}
		};
		if(err){
			failed++;
			error_desc += describe_error(err);
		}
		if(caster)
			caster->_clean_fight();
		destroy_player(caster);
		destroy_player(enemy);
	}

	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("控制或辅助效果失败=%d: %s",
			failed,error_desc));
}

void test_mythic_group_heal_runtime()
{
	test_start("万灵朝生治疗存活同房队友并跳过死者和外人");
	object|zero caster = 0;
	object|zero member = 0;
	object|zero dead_member = 0;
	object|zero outsider = 0;
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int failed = 0;
	string error_desc = "";

	mixed err = catch {
		caster = create_player(
			"__testunit_mythic_heal_caster__","third","fangshi",100);
		member = create_player(
			"__testunit_mythic_heal_member__","third","fangshi",100);
		dead_member = create_player(
			"__testunit_mythic_heal_dead__","third","fangshi",100);
		outsider = create_player(
			"__testunit_mythic_heal_outsider__","human","yushi",100);
		caster->move(room);
		member->move(room);
		dead_member->move(room);
		outsider->move(room);
		caster->set_term("__testunit_mythic_heal_team__");
		member->set_term("__testunit_mythic_heal_team__");
		dead_member->set_term("__testunit_mythic_heal_team__");
		outsider->set_term("__testunit_mythic_heal_outsider_team__");
		caster->set_life(100);
		member->set_life(100);
		dead_member->set_life(0);
		outsider->set_life(100);
		member->set_debuff("curse",0,"life");
		member->set_debuff("curse",1,50);
		member->set_debuff("curse",2,10);
		caster->skills["wanlingchaosheng"] = ({1,0});
		caster->_fight(outsider);
		caster->perform("wanlingchaosheng",1);

		if(caster->get_cur_life()!=3600 ||
		   member->get_cur_life()!=1850 ||
		   dead_member->get_cur_life()!=0 ||
		   outsider->get_cur_life()!=100 ||
		   caster->f_skills["wanlingchaosheng"]!=91)
			failed++;
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && failed==0)
		test_pass();
	else
		test_fail("群体治疗边界失败: "+error_desc);

	if(caster)
		caster->_clean_fight();
	destroy_player(caster);
	destroy_player(member);
	destroy_player(dead_member);
	destroy_player(outsider);
}

void test_balance_envelope()
{
	test_start("大神技能保持五段成长、长冷却且各职业裸装法力可施放");
	int failed = 0;
	int resource_checks = 0;
	foreach(sort(indices(hidden_skills)),string profession_id){
		foreach(hidden_skills[profession_id],string skill_name){
			object skill = (object)(ROOT+
				"/gamelib/single/skills/"+skill_name);
			if(skill->query_s_delayTime(1)<60 ||
			   skill->query_performs_cast(1)<300 ||
			   skill->query_performs_level_limit(1)!=80)
				failed++;
			if((skill->s_skill_type=="curse" ||
			    skill->s_skill_type=="dot") &&
			   skill->query_s_lasttime(1)>12)
				failed++;
		}
		for(int level=1;level<=5;level++){
			int required_level = 60+level*20;
			object player = create_player(
				"__testunit_mythic_resource_"+profession_id+"_"+
				(string)level+"__",profession_race[profession_id],
				profession_id,required_level);
			int mofa_max = player->query_mofa_max();
			foreach(hidden_skills[profession_id],string skill_name){
				object skill = (object)(ROOT+
					"/gamelib/single/skills/"+skill_name);
				resource_checks++;
				if(skill->query_performs_cast(level)>mofa_max)
					failed++;
			}
			destroy_player(player);
		}
	}

	if(resource_checks==155 && failed==0)
		test_pass();
	else
		test_fail(sprintf(
			"资源检查=%d, 发现%d项平衡边界越界",
			resource_checks,failed));
}

void test_crane_and_guide_regressions()
{
	test_start("鹤灵不复活主人且灵治进阶不会误导重复购买");
	object|zero player = 0;
	object|zero crane = 0;
	object|zero guide = 0;
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int dead_life = -1;
	int living_life = -1;
	int reduced_life = -1;
	string guide_text = "";
	string error_desc = "";

	mixed err = catch {
		player = create_player(
			"__testunit_mythic_crane_master__","third","fangshi",100);
		crane = clone(ROOT+"/gamelib/clone/npc/summon/heling.pike");
		guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
		player->move(room);
		crane->set_master(player->query_name());
		crane->move(room);
		player->set_life(0);
		crane->heal_master();
		dead_life = player->get_cur_life();
		player->set_life(100);
		crane->heal_master();
		living_life = player->get_cur_life();
		player->set_life(100);
		player->set_debuff("curse",0,"life");
		player->set_debuff("curse",1,50);
		player->set_debuff("curse",2,10);
		crane->heal_master();
		reduced_life = player->get_cur_life();
		player->skills["lingzhi_mystic"] = ({1,0});
		m_delete(player->skills,"lingzhi");
		guide_text = guide->query_fangshi_growth_guide(player);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && dead_life==0 && living_life==650 &&
	   reduced_life==375 &&
	   search(guide_text,"√ “灵治”治疗自己")!=-1 &&
	   search(guide_text,"可以购买并学习“灵治”")==-1)
		test_pass();
	else
		test_fail(sprintf(
			"鹤灵生命=%d/%d/%d 或指引误判: %s",
			dead_life,living_life,reduced_life,error_desc));

	if(crane)
		destruct(crane);
	destroy_player(player);
}

void print_summary()
{
	werror("\n========================================\n");
	werror("隐藏大神传承测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	werror("========================================\n");
}

void run_tests()
{
	test_drop_contract_runtime();
	test_dynamic_monster_eligibility_runtime();
	test_skill_and_book_config_runtime();
	test_real_book_learning();
	test_damage_profession_burst_runtime();
	test_physical_mythic_weapon_gate();
	test_utility_and_control_runtime();
	test_mythic_group_heal_runtime();
	test_balance_envelope();
	test_crane_and_guide_regressions();
	print_summary();
}

int main()
{
	run_tests();
	return test_results["failed"]==0 ? 0 : 1;
}
