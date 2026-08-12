#!/usr/bin/env pike
/** 登录回收历史无等级装备并补偿碎玉的安全回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[无等级装备回收] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[无等级装备回收] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string name)
{
	object player = clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn = "无等级回收测试玩家";
	player->set_project("gamelib");
	player->set_account_owner(name);
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level = 20;
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

int count_named_items(object player,string name)
{
	int count;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==name)
			count += item->is("combine_item") ? item->amount : 1;
	return count;
}

void test_exact_equipment_filter_and_reward()
{
	object player = create_test_player("xd01testunitnolevelrecycle");
	object daemon = (object)(ROOT+"/gamelib/single/daemons/userd.pike");
	object no_level = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object zero_level = clone(ROOT+
		"/gamelib/clone/item/armor/38fengxianzhongxue/38fengxianzhongxue");
	object food = clone(ROOT+"/gamelib/clone/item/food/ganliang");
	object chest = clone(ROOT+"/gamelib/clone/item/baoxiang/chr_bx_1");
	object existing_jade = clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	mapping first;
	mapping second;
	no_level->set_item_canLevel(-1);
	zero_level->set_item_canLevel(0);
	no_level->move(player);
	zero_level->move(player);
	food->move(player);
	chest->move(player);
	existing_jade->amount = 5;
	existing_jade->move(player);
	player->wield(no_level);
	first = daemon->recycle_no_level_equipment(player,1);
	int mail_count = arrayp(player->inbox) ? sizeof(player->inbox) : 0;
	int jade_count = count_named_items(player,"suiyu");
	check("只回收is_equip且穿戴等级小于0的装备",
		(int)first["count"]==1 && !objectp(no_level) &&
		objectp(zero_level) && environment(zero_level)==player &&
		zero_level->query_item_canLevel()==0,
		sprintf("count=%d zero=%O",(int)first["count"],zero_level));
	check("普通食物、宝箱和已有碎玉完全保留",
		objectp(food) && environment(food)==player &&
		objectp(chest) && environment(chest)==player && jade_count==6,
		sprintf("food=%O chest=%O jade=%d",food,chest,jade_count));
	check("穿戴映射同步解除且补偿数量严格一件一块",
		!player->query_equip()["single_main_weapon"] &&
		(int)first["reward"]==1 && jade_count==6,
		sprintf("equip=%O reward=%d",player->query_equip(),
			(int)first["reward"]));
	check("登录提示对应的系统邮件写明数量和过滤范围",
		mail_count==1 && search((string)player->inbox[0][4],
			"无等级装备回收")!=-1 &&
		search((string)player->inbox[0][5],"1件")!=-1 &&
		search((string)player->inbox[0][5],"普通道具")!=-1,
		mail_count ? sprintf("mail=%O",player->inbox[0]) : "no mail");
	second = daemon->recycle_no_level_equipment(player,1);
	check("重复登录不会重复回收、发奖或发信",
		(int)second["count"]==0 &&
		count_named_items(player,"suiyu")==jade_count &&
		(arrayp(player->inbox) ? sizeof(player->inbox) : 0)==mail_count,
		sprintf("second=%O jade=%d mails=%d",second,
			count_named_items(player,"suiyu"),
			arrayp(player->inbox) ? sizeof(player->inbox) : 0));
	destroy_test_player(player);
}

void test_full_mailbox_defers_notice_without_repeating_reward()
{
	object player = create_test_player("xd01testunitnolevelmail");
	object daemon = (object)(ROOT+"/gamelib/single/daemons/userd.pike");
	object no_level = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	no_level->set_item_canLevel(-1);
	no_level->move(player);
	for(int index=0;index<13;index++)
		player->recieve_mail("CHAT","测试系统",player->query_name(),
			player->query_name_cn(),"占位邮件","占位");
	mapping first = daemon->recycle_no_level_equipment(player,1);
	int jade_count = count_named_items(player,"suiyu");
	check("邮箱满时先保留待发通知且奖励仍只发一次",
		(int)first["count"]==1 && jade_count==1 &&
		mappingp(player["/plus/no_level_equipment_recycle_notice"]),
		sprintf("first=%O jade=%d pending=%O",first,jade_count,
			player["/plus/no_level_equipment_recycle_notice"]));
	player->delete_mail(0);
	player->delete_mail(0);
	mapping retry = daemon->recycle_no_level_equipment(player,1);
	check("邮箱腾出空间后自动补发通知但不重复给碎玉",
		(int)retry["count"]==0 &&
		count_named_items(player,"suiyu")==jade_count &&
		!player["/plus/no_level_equipment_recycle_notice"] &&
		search((string)player->inbox[0][4],"无等级装备回收")!=-1,
		sprintf("retry=%O jade=%d pending=%O",retry,
			count_named_items(player,"suiyu"),
			player["/plus/no_level_equipment_recycle_notice"]));
	destroy_test_player(player);
}

void test_ten_item_milestone_and_profession_choice()
{
	object player = create_test_player("xd01testunitancientchoice");
	object daemon = (object)(ROOT+"/gamelib/single/daemons/userd.pike");
	for(int index=0;index<10;index++){
		object no_level = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		no_level->set_item_canLevel(-1);
		no_level->move(player);
	}
	mapping recycled = daemon->recycle_no_level_equipment(player,1);
	object token = present("ancient_skill_choice_token",player);
	check("累计回收10件严格发放一枚不可流转的太古择卷",
		(int)recycled["count"]==10 &&
		(int)recycled["ancient_tokens"]==1 &&
		(int)recycled["recycle_total"]==10 &&
		(int)recycled["next_token_progress"]==0 && token &&
		(int)token->amount==1 && token->query_item_canDrop()==0 &&
		token->query_item_canTrade()==0 && token->query_item_canSend()==0 &&
		token->query_item_canStorage()==0,
		sprintf("recycled=%O token=%O",recycled,token));
	object command = (object)(ROOT+
		"/gamelib/cmds/ancient_skill_choice.pike");
	set_this_player(player);
	command->main("taigushanyin");
	check("伪造其他职业技能ID不会消耗择卷或生成技能书",
		present("ancient_skill_choice_token",player)==token &&
		!present("taigushanyin",player),
		"token="+sprintf("%O",present("ancient_skill_choice_token",player)));
	command->main("taixujianhen");
	object book = present("taixujianhen",player);
	check("本职业合法选择生成账号绑定原版技能书后才消耗择卷",
		!present("ancient_skill_choice_token",player) && book &&
		book->query_account_bind_owner()==player->query_account_owner() &&
		book->profe_read_limit=="jianxian" && book->level_limit==90,
		sprintf("token=%O book=%O",present(
			"ancient_skill_choice_token",player),book));
	object extra = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	extra->set_item_canLevel(-1);
	extra->move(player);
	mapping next = daemon->recycle_no_level_equipment(player,1);
	check("十件后的余数跨登录累计且不会提前再发择卷",
		(int)next["count"]==1 && (int)next["recycle_total"]==11 &&
		(int)next["next_token_progress"]==1 &&
		(int)next["ancient_tokens"]==0 &&
		!present("ancient_skill_choice_token",player),
		sprintf("next=%O",next));
	destroy_test_player(player);
}

void test_login_hook_covers_direct_resume_clients()
{
	string user_source=Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	string entrance_source=Stdio.read_file(ROOT+"/gamelib/d/init");
	string warehouse_source=Stdio.read_file(
		ROOT+"/gamelib/cmds/user_repackage.pike");
	check("Vue、JSP真正登录执行回收且Worker地图迁移不会重复回收",
		user_source && search(user_source,"int setup(string password)")!=-1 &&
		search(user_source,"run_login_migrations_once()")!=-1 &&
		search(user_source,
			"int pending_worker_arrival = query_pending_worker_arrival()")!=-1 &&
		search(user_source,
			"if(ready && query_profeId() && !pending_worker_arrival)")!=-1 &&
		search(user_source,
			"MAP_WORKERD->query_local_player_arrival(query_name())")!=-1 &&
		entrance_source &&
		search(entrance_source,"me->run_login_migrations_once()")!=-1,
		"真正登录/新人选职缺少回收，或跨Worker移动再次回收已穿装备");
	check("在线后才从老仓库取出的负等级装备立即复查",
		warehouse_source &&
		search(warehouse_source,"environment(ob)==me && ob->is(\"equip\")")!=-1 &&
		search(warehouse_source,"(int)ob->query_item_canLevel()<0")!=-1 &&
		search(warehouse_source,
			"USERD->recycle_no_level_equipment(me)")!=-1,
		"仓库取出后的精确回收钩子缺失");
}

int main()
{
	object|zero original_player = this_player();
	mixed err = catch {
		test_exact_equipment_filter_and_reward();
		test_full_mailbox_defers_notice_without_repeating_reward();
		test_ten_item_milestone_and_profession_choice();
		test_login_hook_covers_direct_resume_clients();
	};
	if(err)
		check("测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	werror("无等级装备回收测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
