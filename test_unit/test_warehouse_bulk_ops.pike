#!/usr/bin/env pike
/** 仓库批量三件套回归：角色仓库套装清理/全部取出/批量卖装。
 * 玩家反馈2026-09-30：仓库爆了、卖着费劲、角色仓只能一件件取。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[仓库批量] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[仓库批量] ✗ %s: %s\n",name,detail);
	}
}

string test_account_id="xd99testunitwhbulk";
string test_char_id="__testunit_whbulk_c1__";

void cleanup_test_account()
{
	ACCOUNT_STORAGED->remove_test_storage(test_account_id);
	ACCOUNT_CHARACTERD->remove_test_account(test_account_id);
	string dir=DATA_ROOT+"accounts/"+
		test_account_id[sizeof(test_account_id)-2..];
	foreach(({test_char_id+".o",test_char_id+".o.bak",
		test_char_id+".o.bak.tmp"}),string suffix)
		rm(DATA_ROOT+"u/"+test_char_id[ sizeof(test_char_id)-2 ..]+
			"/"+suffix);
	rm(dir+"/"+test_account_id+".storage.json");
	rm(dir+"/"+test_account_id+".storage.json.bak");
}

object create_test_player(string name)
{
	object player=clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->set_password("testunit88");
	player->name_cn=name;
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=30;
	player->set_att_by_level();
	player->set_term("noterm");
	player->set_vip_flag(3);
	player->set_vip_end_time(time()+3600);
	// initialized+config_version必须先钉住：autofightd的初始化块和
	// 版本迁移(<3)都会把卖装模式重置为off。
	player["/plus/autofight_initialized"]=1;
	player["/plus/autofight_config_version"]=99;
	player["/plus/autofight_auto_sell_mode"]="normal";
	player["/plus/autofight_sell_armor"]=1;
	player["/plus/autofight_sell_level_gap"]=0;
	player->save_with_result();
	return player;
}

int warehouse_count(object player,string base_name)
{
	int n=0;
	foreach(player->packaged_items || ({}),array row)
		if(arrayp(row) && sizeof(row)>=4 && (string)row[0]==base_name)
			n++;
	return n;
}

int backpack_count(object player,string base_name)
{
	int n=0;
	foreach(all_inventory(player),object ob)
		if((string)ob->query_name()==base_name)
			n++;
	return n;
}

int main()
{
	object original=this_player();
	object|zero me=0;
	object cleanup=(object)(ROOT+"/gamelib/cmds/set_equipment_cleanup.pike");
	object browser=(object)(ROOT+"/gamelib/cmds/personal_storage.pike");
	object batch=(object)(ROOT+"/gamelib/cmds/personal_storage_batch.pike");
	object sell_cmd=(object)(ROOT+
		"/gamelib/cmds/personal_storage_sell.pike");
	string set_base="69xinyuetianfengjian";
	string junk_base="10lupimao";
	mixed err=catch{
		cleanup_test_account();
		// 旧账号模式：人物名=账号id并存档，账号档案由legacy路径建立，
		// 与test_account_shared_storage同构。
		me=create_test_player(test_account_id);
		set_this_player(me);
		mapping created=ACCOUNT_CHARACTERD->create_character(
			test_account_id,"human","jianxian");
		check("测试账号人物档案建立（共享仓ID分配前置）",
			mappingp(created) && (int)created["ok"],
			sprintf("created=%O",
				mappingp(created) ? created["message"] : created));
		mapping storage_probe=ACCOUNT_STORAGED->query_storage(me);
		check("角色仓永久ID分配生效（共享仓读取成功）",
			(int)storage_probe["ok"]==1,
			sprintf("probe=%O",(string)storage_probe["message"]));

		// ===== 1) 角色仓库套装清理 =====
		for(int i=0;i<3;i++){
			object ob=clone(ROOT+"/gamelib/clone/item/weapon/"+
				set_base+"/"+set_base);
			if(ob) ob->move(me);
		}
		// 白装护甲混入仓库：套装清理不应误伤。
		object shield=clone(ROOT+"/gamelib/clone/item/armor/"+
			junk_base+"/"+junk_base);
		if(shield) shield->move(me);
		foreach(all_inventory(me),object ob){
			me->packaged(ob,me->query_cangku_size());
			destruct(ob);
		}
		ACCOUNT_STORAGED->query_storage(me);//分配角色仓永久ID
		check("仓库初始：套装3件+白装1件",
			warehouse_count(me,set_base)==3 &&
			warehouse_count(me,junk_base)==1,
			sprintf("set=%d junk=%d",
				warehouse_count(me,set_base),
				warehouse_count(me,junk_base)));
		int money_before=(int)me->query_account();
		mapping pre_state=cleanup->query_cangku_set_state(me);
		check("评估快照发现3件套装行（排障断言）",
			(int)pre_state["set_rows"]==3,
			sprintf("set_rows=%O dups=%O groups=%O",
				pre_state["set_rows"],
				sizeof((array)pre_state["duplicates"]),
				sizeof(indices((mapping)pre_state["groups"]))));
		cleanup->main("cangku");//预览不崩溃
		mapping done=cleanup->perform_cangku_set_cleanup(me);
		check("仓库套装清理销毁2件重复并付银两",
			(int)done["count"]==2 && (int)done["money"]>0,
			sprintf("done=%O",done));
		check("每组保留1件回仓且白装不受影响",
			warehouse_count(me,set_base)==1 &&
			warehouse_count(me,junk_base)==1,
			sprintf("set=%d junk=%d",
				warehouse_count(me,set_base),
				warehouse_count(me,junk_base)));
		check("银两入账与清理结果一致",
			(int)me->query_account()==
				money_before+(int)done["money"],
			sprintf("%d -> %d expect +%d",money_before,
				(int)me->query_account(),(int)done["money"]));

		// ===== 2) 全部取出（takeall） =====
		for(int i=0;i<3;i++){
			object ob=clone(ROOT+"/gamelib/clone/item/armor/"+
				junk_base+"/"+junk_base);
			if(ob) ob->move(me);
		}
		foreach(all_inventory(me),object ob)
			if((string)ob->query_name()==junk_base){
				me->packaged(ob,me->query_cangku_size());
				destruct(ob);
			}
		ACCOUNT_STORAGED->query_storage(me);
		check("取出前仓库白装4件",
			warehouse_count(me,junk_base)==4,
			sprintf("junk=%d",warehouse_count(me,junk_base)));
		array(mapping) rows=browser->query_personal_rows(me,"all","");
		array(string) tokens=({});
		for(int i=0;i<sizeof(rows) && i<8;i++)
			tokens+=({(string)rows[i]["token"]});
		string token=browser->personal_storage_batch_token(
			"take","all","",tokens);
		batch->main("takeall 0 "+token);
		check("全部取出后仓库清空且背包拿到全部",
			warehouse_count(me,junk_base)==0 &&
			backpack_count(me,junk_base)==4,
			sprintf("wh=%d bag=%d",warehouse_count(me,junk_base),
				backpack_count(me,junk_base)));

		// ===== 3) 仓库批量卖装 =====
		foreach(all_inventory(me),object ob)
			if((string)ob->query_name()==junk_base){
				me->packaged(ob,me->query_cangku_size());
				destruct(ob);
			}
		ACCOUNT_STORAGED->query_storage(me);
		mapping preview=sell_cmd->query_storage_sell_state(me);
		// 排障：背包实物件的拒绝原因直读。
		string dbg="";
		foreach(all_inventory(me),object ob2)
			if((string)ob2->query_name()==junk_base){
				dbg=AUTOFIGHTD->query_auto_sell_reject_reason(me,ob2);
				break;
			}
		check("卖装预览评估4件可卖白装",
			sizeof((array)preview["candidates"])==4,
			sprintf("cand=%d reject=%s",
				sizeof((array)preview["candidates"]),dbg));
		sell_cmd->main("");//预览页不崩溃
		money_before=(int)me->query_account();
		mapping sold=sell_cmd->perform_storage_sell(me);
		check("批量卖装卖出4件并付银两",
			(int)sold["count"]==4 && (int)sold["money"]>0 &&
			(int)me->query_account()==
				money_before+(int)sold["money"],
			sprintf("sold=%O %d->%d",sold,money_before,
				(int)me->query_account()));
		check("卖装后仓库与背包均无该白装",
			warehouse_count(me,junk_base)==0 &&
			backpack_count(me,junk_base)==0,
			sprintf("wh=%d bag=%d",warehouse_count(me,junk_base),
				backpack_count(me,junk_base)));
	};
	if(err)
		check("仓库批量流程无异常",0,describe_error(err));
	else
		check("仓库批量流程无异常",1,"");
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	if(me){
		foreach(all_inventory(me),object item)
			destruct(item);
		destruct(me);
	}
	cleanup_test_account();
	werror("[仓库批量] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
