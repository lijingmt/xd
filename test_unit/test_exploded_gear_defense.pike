#!/usr/bin/env pike
/** 爆炸装三层防御回归：生成上限、炼化钳制、登录直接回收+一次性补偿。 */

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
	int overpowered_level=0;
	int no_downgrade_clamp=0;
	int ceiling_removed=0;
	int ceiling_kept_legit=0;
	int ceiling_jade_unchanged=0;
	int jade_ceiling_before=0;
	int jade_ceiling_after=0;
	int legacy_class=0;
	int legit_class=-1;
	int legit_attack=-1;
	int extreme_worn=0;
	int reequipped_ok=0;
	array(string) legit_diag=({});
	int intlegal_class=0;
	int envelope_legacy_flagged=0;
	int envelope_legal_kept=0;
	object|zero got_item=0;
	int file_class_ok=0;
	int deposit_refused=0;
	int withdraw_recalled=0;
	int warehouse_purged=0;
	int login_purge_ok=0;
	int shared_purged=0;
	int shared_purge_ok=0;
	int wash_floor_ok=0;
	int life_full=0;
	int life_default=0;
	int removed_ok=0;
	int compensation_once=0;
	int corrected=0;
	int second_pass=0;
	int jade_before=0;
	int jade_after_first=0;
	int jade_after_second=0;
	mixed err=catch{
		set_this_player(player);
		// 第二层：低阶底版按超高目标等级生成，单条属性必须被钳制。
		object overpowered=ITEMSD->get_convert_item(
			"weapon/1duanmugun/1duanmugun",3,1,400);
		overpowered_level=overpowered ?
			(int)overpowered->query_item_canLevel() : 0;
		mapping(string:int) query_ceilings=([
			"str_add":2*32500,"dex_add":2*32500,"think_add":2*32500,
			"attack_add":5*32500,"weapon_attack_add":2*32500,
			"life_add":20*32500,"mofa_add":40*32500,
		]);
		foreach(indices(query_ceilings),string attr){
			mixed reader=overpowered ? overpowered["query_"+attr] : 0;
			if(functionp(reader)){
				int value=(int)call_function(reader);
				if(value>query_ceilings[attr]){
					worst=value;
					worst_attr=attr;
				}
			}
		}
		generated_capped=overpowered && worst==0;
		// 第一层契约：重掷必须保持装备当前等级（400级洗出400级），
		// 且数值仍被第二层钳制；不允许再出现降级到底版档位的钳制。
		conversion_clamped=overpowered &&
			overpowered_level==400 && worst==0;
		if(overpowered)
			destruct(overpowered);
		string convert_source=Stdio.read_file(ROOT+
			"/gamelib/cmds/convert_equip_confirm.pike") || "";
		no_downgrade_clamp=search(convert_source,
			"reroll_target=base_tier")== -1;
		// 第三层：登录回收——构造爆炸装，矫正后应被直接销毁。
		object exploded=ITEMSD->get_convert_item(
			"weapon/1duanmugun/1duanmugun",3,1,1);
		exploded->set_attack_add(999999);
		exploded->move(player);
		jade_before=YUSHID->query_all_num(player);
		corrected=player->normalize_exploded_equipment();
		removed_ok=corrected>=1 && !objectp(exploded);
		jade_after_first=YUSHID->query_all_num(player);
		// 幂等：第二次矫正无装备可删，返回0且不再发补偿。
		object normal=ITEMSD->get_convert_item(
			"weapon/1duanmugun/1duanmugun",1,1,1);
		normal->move(player);
		second_pass=player->normalize_exploded_equipment();
		jade_after_second=YUSHID->query_all_num(player);
		compensation_once=second_pass==0 &&
			jade_after_first>jade_before &&
			jade_after_second==jade_after_first &&
			objectp(normal);
		if(normal)
			destruct(normal);
		// 千级上限报警回收：超上限10倍的装备替换为正常同款、不补碎玉；
		// 真实包络内的合法装备（攻击12≤包络15）必须保留。
		object extreme=ITEMSD->get_convert_item(
			"weapon/1duanmugun/1duanmugun",3,1,1);
		extreme->set_attack_add(9999999);
		extreme->move(player);
		object legit=ITEMSD->get_convert_item(
			"weapon/1duanmugun/1duanmugun",3,1,1);
		legit->set_attack_add(12);
		legit->move(player);
		// 回收前穿上爆炸件：替换件必须自动穿回原槽位，玩家不能
		// 在回收后面对满地脱下的装备（休息/战斗循环被打断）。
		extreme_worn=(int)player->wield(extreme);
		legit_class=(int)ITEMSD->query_abnormal_gear_class(legit);
		legit_attack=(int)legit["attack_add"];
		if(legit_class>=1){
			mapping(string:int) diag_caps=ITEMSD->
				query_base_attribute_caps(
				"weapon/1duanmugun/1duanmugun");
			foreach(sort(indices(diag_caps)),string diag_attr){
				mixed diag_raw=legit[diag_attr];
				if(intp(diag_raw) && diag_raw>0)
					legit_diag+=({diag_attr+"="+diag_raw+
						"(limit"+diag_caps[diag_attr]/100000+
						")"});
			}
		}
		jade_ceiling_before=YUSHID->query_all_num(player);
		player->recall_abnormal_ceiling_gear();
		jade_ceiling_after=YUSHID->query_all_num(player);
		// 持久化替换验证：旧装备被移除，替换件已实际进入背包
		// （存在除保留的legit之外的新装备），合法装备原样保留。
		int replacement_seen=0;
		foreach(all_inventory(player),object inv){
			if(inv && inv!=legit &&
			   functionp(inv->query_item_rareLevel)){
				replacement_seen=1;
				break;
			}
		}
		ceiling_removed=!objectp(extreme) && replacement_seen;
		object|zero reequipped=0;
		foreach(all_inventory(player),object inv)
			if(inv && inv!=legit && functionp(inv->query_item_rareLevel) &&
			   (int)inv["equiped"])
				reequipped=inv;
		reequipped_ok=!extreme_worn || objectp(reequipped);
		ceiling_kept_legit=objectp(legit) &&
			player->normalize_exploded_equipment()==0 &&
			objectp(legit);
		if(legit){
			legit_class=(int)ITEMSD->query_abnormal_gear_class(legit);
			legit_attack=(int)legit["attack_add"];
		}
		ceiling_jade_unchanged=jade_ceiling_after==jade_ceiling_before;
		if(legit)
			destruct(legit);
		// 真实包络收紧：旧双重缩放时代(×level/25)的存量装备（天仙境
		// 280级力量12260/闪避穿透301/命中20）超出真实生成包络3倍，
		// tier≥65底版不再整档豁免；包络内的合法极值不受影响。
		{
			string forge70_dir=ROOT+"/gamelib/clone/item/weapon/"+
				"70baokukuangjian/";
			string forge70_base=Stdio.read_file(forge70_dir+
				"70baokukuangjian") || "";
			string forge_legacy=forge70_base[
				0..sizeof(forge70_base)-3]+
				"set_item_canLevel(280);set_str_add(12260);"+
				"set_dodgechuantou_add(301);set_hitte_add(20);"+
				"\n}\n";
			string forge_legal=forge70_base[
				0..sizeof(forge70_base)-3]+
				"set_item_canLevel(280);set_str_add(880);\n}\n";
			Stdio.write_file(forge70_dir+"zztestunitlegacy",
				forge_legacy);
			Stdio.write_file(forge70_dir+"zztestunitlegal70",
				forge_legal);
			legacy_class=ITEMSD->query_abnormal_gear_class_by_file(
				"weapon/70baokukuangjian/zztestunitlegacy");
			intlegal_class=ITEMSD->
				query_abnormal_gear_class_by_file(
				"weapon/70baokukuangjian/zztestunitlegal70");
			rm(forge70_dir+"zztestunitlegacy");
			rm(forge70_dir+"zztestunitlegal70");
			envelope_legacy_flagged=legacy_class==1;
			envelope_legal_kept=intlegal_class==0;
		}
		// 洗炼保底：资源型重掷走[70%,100%]差额采样，底版25@280级
		// 最低rate=(25+178)/25×2.7≈21.9。任何被rate放大的单条属性
		// 都不得低于底版1点×最低rate(≈21)。逐条检查而非只看三条
		// 里的最大值，避免随机全掷出底数1时的偶发误报。
		{
			int wash_min=2147483647;
			mapping(string:int) wash_caps=ITEMSD->
				query_base_attribute_caps(
				"weapon/1duanmugun/1duanmugun");
			for(int wash_i=0;wash_i<25;wash_i++){
				object washed=ITEMSD->get_convert_item(
					"weapon/1duanmugun/1duanmugun",3,1,280);
				if(washed){
					foreach(sort(indices(wash_caps)),string attr){
						if(search(({"hitte_add","doub_add",
						   "dodge_add"}),attr)!=-1)
							continue;
						mixed reader=washed["query_"+attr];
						if(functionp(reader)){
							int v=(int)call_function(reader);
							if(v>0 && v<wash_min)
								wash_min=v;
						}
					}
					destruct(washed);
				}
			}
			wash_floor_ok=wash_min>=20 && wash_min<2147483647;
		}
		// 仓库彻底回收：伪造异常装备文件（爆炸级2600/千级999999），
		// 验证文件分类、存入拒绝、取出回收、角色仓库登录清洗与
		// 共享仓库过滤五条防线。
		string forge_dir=ROOT+
			"/gamelib/clone/item/weapon/1duanmugun/";
		string forge_base=Stdio.read_file(forge_dir+"1duanmugun") ||
			"";
		string forge_boom=forge_base[0..sizeof(forge_base)-3]+
			"set_attack_add(5000);\n}\n";
		string forge_ceiling=forge_base[0..sizeof(forge_base)-3]+
			"set_attack_add(9999999);\n}\n";
		Stdio.write_file(forge_dir+"zztestunitboom5000",forge_boom);
		Stdio.write_file(forge_dir+"zztestunitboom999999",
			forge_ceiling);
		file_class_ok=
			ITEMSD->query_abnormal_gear_class_by_file(
				"weapon/1duanmugun/zztestunitboom5000")==1 &&
			ITEMSD->query_abnormal_gear_class_by_file(
				"weapon/1duanmugun/zztestunitboom999999")==2 &&
			ITEMSD->query_abnormal_gear_class_by_file(
				"weapon/1duanmugun/1duanmugun")==0;
		object bad=clone(ITEM_PATH+"weapon/1duanmugun/1duanmugun");
		bad->set_attack_add(5000);
		player->packaged_items=({});
		deposit_refused=player->packaged(bad,100)!=0 &&
			sizeof(player->packaged_items)==0;
		destruct(bad);
		player->packaged_items=({({"zzboom","异常测试装备","短木棍",
			"weapon/1duanmugun/zztestunitboom5000",0,0,0})});
		got_item=player->repackaged("zzboom");
		withdraw_recalled=!got_item &&
			sizeof(player->packaged_items)==0;
		player->packaged_items=({({"zzboom2","异常测试装备","短木棍",
			"weapon/1duanmugun/zztestunitboom999999",0,0,0}),
			({"zzok","正常装备","短木棍",
			"weapon/1duanmugun/1duanmugun",0,0,0})});
		warehouse_purged=player->recall_abnormal_warehouse_gear();
		login_purge_ok=warehouse_purged==1 &&
			sizeof(player->packaged_items)==1 &&
			(string)player->packaged_items[0][0]=="zzok";
		player->packaged_items=({});
		mapping shared_record=(["items":({
			(["id":"ab","data":({"zzshared","异常装备","短木棍",
				"weapon/1duanmugun/zztestunitboom5000",0,0,0,
				"ab"})]),
			(["id":"cd","data":({"zzsharedok","正常装备","短木棍",
				"weapon/1duanmugun/1duanmugun",0,0,0,
				"cd"})]),
		}),"pending":({})]);
		shared_purged=ACCOUNT_STORAGED->
			test_filter_abnormal_shared_items(
			shared_record,"testunitaccount");
		shared_purge_ok=shared_purged==1 &&
			sizeof((array)shared_record["items"])==1 &&
			(string)((array)shared_record["items"])[0]["id"]=="cd";
		rm(forge_dir+"zztestunitboom5000");
		rm(forge_dir+"zztestunitboom999999");
	};
	if(err)
		error_desc=describe_error(err);
	check("第二层：低阶底版超高等级生成的属性被钳回合法上限",
		!err && generated_capped,
		error_desc!="" ? error_desc :
			sprintf("worst=%s=%d",worst_attr,worst));
	check("第一层：洗炼重掷保持装备当前等级",
		!err && conversion_clamped && no_downgrade_clamp,
		sprintf("level=%d downgrade_clamp=%d",overpowered_level,
			no_downgrade_clamp));
	check("第三层：登录回收直接销毁爆炸装备",
		!err && removed_ok,
		error_desc!="" ? error_desc :
			sprintf("corrected=%d",corrected));
	check("补偿一次性发放：首回收到碎玉，二次不再发",
		!err && compensation_once,
		sprintf("second=%d jade %d→%d→%d",second_pass,
			jade_before,jade_after_first,jade_after_second));
	check("千级上限：超上限装备被钳回合法数值",
		!err && ceiling_removed,
		"异常装备未被矫正");
	check("千级上限：包络内合法装备不被误删",
		!err && ceiling_kept_legit,
		sprintf("合法装备被误删 class=%d attack=%d attrs=%s",
			legit_class,legit_attack,legit_diag*","));
	check("回收替换件自动穿回原槽位",
		!err && reequipped_ok && ceiling_removed,
		sprintf("worn=%d replaced=%d",reequipped_ok,ceiling_removed));
	check("千级上限：回收不发放碎玉",
		!err && ceiling_jade_unchanged,
		sprintf("jade %d→%d",jade_ceiling_before,jade_ceiling_after));
	check("真实包络：旧双重缩放存量(tier≥65底版)被判爆炸装",
		!err && envelope_legacy_flagged,
		sprintf("legacy_class=%d",legacy_class));
	check("真实包络：包络内合法极值装备不受影响",
		!err && envelope_legal_kept,
		sprintf("legal_class=%d",intlegal_class));
	check("仓库分类：文件级判定爆炸/千级/正常三档",
		!err && file_class_ok,
		"按物品文件克隆分类失败");
	check("仓库存入：异常装备被拒绝入库",
		!err && deposit_refused,
		"异常装备混入了角色仓库");
	check("仓库取出：取出异常装备时直接回收",
		!err && withdraw_recalled,
		sprintf("got=%d remain=%d",!!got_item,
			sizeof(player->packaged_items || ({}))));
	check("仓库登录清洗：只删异常条目并保留正常装备",
		!err && login_purge_ok,
		sprintf("purged=%d",warehouse_purged));
	check("共享仓库过滤：异常条目被删除、正常条目保留",
		!err && shared_purge_ok,
		sprintf("purged=%d",shared_purged));
	check("洗炼保底：每条重掷属性不低于底版下限×最低增长率",
		!err && wash_floor_ok,
		"洗炼出现低于底版1点×最低rate(约21)的属性");
	// 怪物默认血量：无配置文件时按原血量2%出生。
	Stdio.write_file(DATA_ROOT+"balance_transition.json",
		Standards.JSON.encode((["life_percent":100,
			"attack_percent":100,"version":1])));
	object npc_full=clone(ROOT+"/gamelib/clone/npc/kunlunshan/qinyuan1");
	npc_full->setup_npc();
	life_full=npc_full->get_cur_life();
	// 副本怪走同一setup路径，也必须吃全局过渡系数。
	object fb_full=clone(ROOT+"/gamelib/clone/npc/bawangbao/shihushou50");
	int fb_life_full=fb_full->get_cur_life();
	destruct(fb_full);
	rm(DATA_ROOT+"balance_transition.json");
	object npc_default=clone(ROOT+
		"/gamelib/clone/npc/kunlunshan/qinyuan1");
	npc_default->setup_npc();
	life_default=npc_default->get_cur_life();
	destruct(npc_full);
	destruct(npc_default);
	check("怪物默认血量：无配置文件时为原血量的2%",
		life_full>0 && life_default==life_full*2/100,
		sprintf("full=%d default=%d",life_full,life_default));
	object fb_default=clone(ROOT+
		"/gamelib/clone/npc/bawangbao/shihushou50");
	int fb_life_default=fb_default->get_cur_life();
	destruct(fb_default);
	check("副本怪同样应用全局血量过渡系数",
		fb_life_full>0 && fb_life_default==fb_life_full*2/100,
		sprintf("full=%d default=%d",fb_life_full,fb_life_default));
	// 怪物联动：守护进程默认与热调边界。
	rm(DATA_ROOT+"balance_transition.json");
	object balance=(object)(ROOT+
		"/gamelib/single/daemons/balance_transitiond.pike");
	mapping fresh=balance->query_status();
	mapping tuned=balance->set_percents(60,80,"testunit");
	mapping bad=balance->set_percents(5,80,"testunit");
	mapping after_tune=balance->query_status();
	check("怪物过渡系数：热调生效且越界拒绝",
		(int)tuned["ok"] && !(int)bad["ok"] &&
		(int)after_tune["life_percent"]==60 &&
		(int)after_tune["attack_percent"]==80,
		sprintf("fresh=%O tuned=%O bad=%O after=%O",
			fresh,tuned,bad,after_tune));
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
