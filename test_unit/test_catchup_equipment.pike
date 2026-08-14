#!/usr/bin/env pike
/** 追赶装备领取、付费激活、绑定、PVE边界与防流通回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void cleanup_player_files(string name)
{
	if(!name || !has_prefix(name,"__testunit_catchup_equipment_"))
		return;
	string path=DATA_ROOT+"u/"+name[sizeof(name)-2..]+"/"+name+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

object create_player(string name,int level)
{
	// setup() 会恢复同名真实档案。每轮必须先清理精确的 TestUnit
	// 夹具，否则第二次重启会把上轮已激活装备误当成新领取对象。
	cleanup_player_files(name);
	object player=clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn="追赶装备测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=level;
	player->set_att_by_level();
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	string name=(string)player->query_name();
	if(player->query_in_combat())
		player->_clean_fight();
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
	cleanup_player_files(name);
}

int main()
{
	array(string) paths=({
		"/gamelib/clone/item/catchup/zhuixingjia",
		"/gamelib/clone/item/catchup/zhuixingjie",
		"/gamelib/clone/item/catchup/zhuixingpei",
		"/gamelib/cmds/catchup_equipment.pike",
		"/gamelib/cmds/newbie_shop.pike",
		"/gamelib/single/daemons/newbied.pike",
		"/gamelib/cmds/viceskill_rongjie_confirm.pike",
		"/gamelib/cmds/viceskill_ronglian_confirm.pike",
		"/gamelib/cmds/convert_equip_list.pike",
		"/gamelib/cmds/convert_equip_detail.pike",
		"/gamelib/cmds/convert_equip_reset.pike",
		"/gamelib/cmds/equip_xiangqian_detail.pike",
		"/gamelib/cmds/equip_xiangqian_confirm.pike",
		"/gamelib/cmds/equip_xiangqian_change.pike",
		"/lowlib/mudlib/inherit/feature/level.pike",
	});
	int compiled=1;
	string error_desc="";
	foreach(paths,string path){
		mixed compile_err=catch {
			if(!(program)(ROOT+path))
				compiled=0;
		};
		if(compile_err){
			compiled=0;
			error_desc+=path+": "+describe_error(compile_err);
		}
	}
	check("三件装备、商店、激活与防套利入口均可运行时编译",
		compiled,error_desc);

	object low=create_player("__testunit_catchup_equipment_29__",29);
	object eligible=create_player("__testunit_catchup_equipment_50__",50);
	object high=create_player("__testunit_catchup_equipment_90__",90);
	object opponent=create_player("__testunit_catchup_equipment_pvp__",50);
	object mixed_npc=clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room=clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero original=this_player();
	mixed err=catch {
		mapping low_result=NEWBIED->grant_catchup_equipment(
			low,"zhuixingjia");
		mapping high_result=NEWBIED->grant_catchup_equipment(
			high,"zhuixingjia");
		check("30级以下与90级以上均不能领取",
			!(int)low_result["ok"] && low_result["code"]=="level" &&
			!(int)high_result["ok"] && high_result["code"]=="level",
			"领取等级边界失效");

		foreach(({"zhuixingjia","zhuixingjie","zhuixingpei"}),
			string item_id){
			mapping granted=NEWBIED->grant_catchup_equipment(
				eligible,item_id);
			mapping repeated=NEWBIED->grant_catchup_equipment(
				eligible,item_id);
			check(item_id+"每角色只可领取一次",
				(int)granted["ok"] && !(int)repeated["ok"] &&
				repeated["code"]=="claimed",
				"重复领取未被拒绝");
		}
		object armor=present("zhuixingjia",eligible,0);
		object ring=present("zhuixingjie",eligible,0);
		object charm=present("zhuixingpei",eligible,0);
		check("未激活装备不能通过底层wear绕过",
			armor && eligible->wear(armor)==0 && !armor->equiped,
			"底层装备接口接受未激活物品");
		check("三件装备不可流通且激活价固定100碎玉",
			armor && ring && charm &&
			!armor->query_item_canDrop() && !armor->query_item_canTrade() &&
			!armor->query_item_canSend() && !armor->query_item_canStorage() &&
			armor->query_catchup_activation_price()==100 &&
			ring->query_catchup_activation_price()==100 &&
			charm->query_catchup_activation_price()==100,
			"绑定或价格属性不完整");

		YUSHID->give_yushi(eligible,300);
		object command=(object)(ROOT+"/gamelib/cmds/catchup_equipment.pike");
		set_this_player(eligible);
		command->main("activate zhuixingjia 0");
		command->main("activate zhuixingjie 0");
		command->main("activate zhuixingpei 0");
		int after_first=YUSHID->query_all_num(eligible);
		command->main("activate zhuixingjia 0");
		check("三件各扣100碎玉且重复激活绝不二次扣款",
			after_first==0 && YUSHID->query_all_num(eligible)==0 &&
			armor->query_catchup_owner()==eligible->query_name() &&
			armor->query_catchup_activated(),
			"激活扣款或幂等绑定错误");

		string saved=pikenv_save_object(armor,1);
		object restored=clone(ROOT+
			"/gamelib/clone/item/catchup/zhuixingjia");
		pikenv_restore_object(restored,saved);
		check("激活与角色绑定状态随装备实例持久化",
			restored->query_catchup_activated() &&
			restored->query_catchup_owner()==eligible->query_name(),
			"装备重建后激活状态丢失");
		destruct(restored);
		check("追赶装备明确拒绝炼化、镶嵌与激活事务绕过",
			search(Stdio.read_file(ROOT+
				"/gamelib/cmds/convert_equip_list.pike") || "",
				"query_catchup_equipment")!=-1 &&
			search(Stdio.read_file(ROOT+
				"/gamelib/cmds/equip_xiangqian_confirm.pike") || "",
				"query_catchup_equipment")!=-1 &&
			functionp(armor->rollback_catchup_activation),
			"某个装备改造入口或事务回滚能力缺失");

		armor->move(eligible);
		ring->move(eligible);
		charm->move(eligible);
		eligible->wear(armor);
		eligible->wear(ring);
		eligible->wear(charm);
		int pve_all=ring->query_all_add();
		eligible->move(room);
		opponent->move(room);
		eligible->fight(opponent,0,1);
		int pvp_all=ring->query_all_add();
		eligible->_clean_fight();
		opponent->_clean_fight();
		mixed_npc->move(room);
		eligible->_fight(opponent);
		eligible->_fight(mixed_npc);
		int mixed_all=ring->query_all_add();
		eligible->_clean_fight();
		opponent->_clean_fight();
		check("追赶属性只在PVE生效，纯PVP及怪物为主目标的混战均归零",
			pve_all==20 && pvp_all==0 && mixed_all==0,
			sprintf("pve=%d pvp=%d mixed=%d",pve_all,pvp_all,mixed_all));

		string rongjie=RONGJIED->query_can_rongjie(eligible);
		eligible->ronglian_list=([]);
		string ronglian=RONGLIAND->query_can_ronglian(
			eligible,"armor",1);
		check("追赶装备不进入熔解或熔炼候选列表",
			search(rongjie,"zhuixing")==-1 &&
			search(ronglian,"zhuixing")==-1,
			"防分解套利列表仍暴露追赶装备");

		eligible->level=90;
		int removed=eligible->enforce_catchup_equipment_limits();
		check("达到90级立即卸下且不能从底层重新穿戴",
			removed==3 && !armor->equiped && !ring->equiped &&
			!charm->equiped && eligible->wear(armor)==0,
			"超过追赶期仍可保留装备属性");
		string level_source=Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/level.pike") || "";
		check("追赶装备等级保护只在真实升级时扫描",
			search(level_source,"int before_level=query_level()")!=-1 &&
			search(level_source,"query_level()!=before_level")!=-1,
			"每次获得经验仍会无条件扫描装备栏");
	};
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	if(err)
		check("追赶装备运行时流程无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	destroy_player(low);
	destroy_player(eligible);
	destroy_player(high);
	destroy_player(opponent);
	if(mixed_npc)
		destruct(mixed_npc);
	if(room)
		destruct(room);
	werror("追赶装备测试：%d通过/%d失败\n",
		results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
