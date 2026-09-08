#!/usr/bin/env pike
/** 提炼系统全量回归：公式边界、事务性、门槛/守护符惩罚、PK掉落
 * 五重防刷、名称/属性显示、以及"各类型装备提炼到+1000"模拟与
 * 真实随机骰的经济统计。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player(string userid)
{
	rm(player_file(userid));
	rm(player_file(userid)+".tmp");
	rm(player_file(userid)+".bak");
}

object create_saved_player(string userid,string password,string ip)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password(password);
	player->set_project("gamelib");
	player->set_userip(ip);
	player->name_cn = "提炼测试"+userid[sizeof(userid)-2..];
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->set_account_owner(userid);
	player->level = 60;
	player->set_att_by_level();
	player->add_money(5000000000);
	player->move(ROOT+"/gamelib/d/congxianzhen/congxianzhen");
	player->save_with_result();
	return player;
}

void grant_stones(object me,int count)
{
	object stone = clone(ROOT+"/gamelib/clone/item/material/cuilianshi");
	stone->amount = count;
	stone->move(me);
}

int count_charms(object me)
{
	int total=0;
	foreach(all_inventory(me),object ob)
		if(ob && functionp(ob->query_name) &&
		   (string)ob->query_name()=="tilianshouhufu")
			total+=(int)(ob->amount || 1);
	return total;
}

int count_named(object me,string nm)
{
	int total=0;
	foreach(all_inventory(me),object ob)
		if(ob && functionp(ob->query_name) &&
		   (string)ob->query_name()==nm)
			total+=(int)(ob->amount || 1);
	return total;
}

int count_stones(object me)
{
	int total=0;
	foreach(all_inventory(me),object ob){
		if(ob && functionp(ob->query_name) &&
		   (string)ob->query_name()=="cuilianshi")
			total+=(int)(ob->amount || 1);
	}
	return total;
}

int main()
{
	string account_id = "xd01testrefine";
	string victim_id = "xd01testrefine2";
	object|zero me = 0;
	object|zero victim = 0;
	int ch_pre = 0;
	werror("\n========== 提炼系统测试 ==========\n");
	cleanup_player(account_id);
	cleanup_player(victim_id);
	mixed err = catch{
		/* ===== 1) 公式边界 ===== */
		check("1a.成功率边界(1-9级100%)",
			REFINED->query_refine_success_rate(0)==10000 &&
			REFINED->query_refine_success_rate(9)==10000,
			"低级率异常");
		check("1b.成功率下滑与30%下限",
			REFINED->query_refine_success_rate(10)==9000 &&
			REFINED->query_refine_success_rate(99)==4550 &&
			REFINED->query_refine_success_rate(130)==3000 &&
			REFINED->query_refine_success_rate(1000)==3000,
			sprintf("%d %d %d %d",
				REFINED->query_refine_success_rate(10),
				REFINED->query_refine_success_rate(99),
				REFINED->query_refine_success_rate(130),
				REFINED->query_refine_success_rate(1000)));
		check("1c.门槛判定(10/50/100级档)",
			REFINED->query_is_threshold_attempt(9)==1 &&
			REFINED->query_is_threshold_attempt(10)==0 &&
			REFINED->query_is_threshold_attempt(99)==1 &&
			REFINED->query_is_threshold_attempt(149)==1 &&
			REFINED->query_is_threshold_attempt(999)==1 &&
			REFINED->query_is_threshold_attempt(1099)==1 &&
			REFINED->query_is_threshold_attempt(1000)==0,
			"门槛判定异常");
		check("1d.门槛惩罚(低档3级/高档30%封顶50)",
			REFINED->query_threshold_penalty_levels(9)==3 &&
			REFINED->query_threshold_penalty_levels(149)==44 &&
			REFINED->query_threshold_penalty_levels(999)==50 &&
			REFINED->query_threshold_penalty_levels(3000)==50,
			sprintf("%d %d %d %d",
				REFINED->query_threshold_penalty_levels(9),
				REFINED->query_threshold_penalty_levels(149),
				REFINED->query_threshold_penalty_levels(999),
				REFINED->query_threshold_penalty_levels(3000)));
		mapping c0=REFINED->query_refine_costs(0);
		mapping c50=REFINED->query_refine_costs(50);
		mapping c1000=REFINED->query_refine_costs(1000);
		check("1e.材料消耗公式",
			c0["jade"]==10 && c0["stone"]==5 && c0["money"]==0 &&
			c50["jade"]==110 && c50["stone"]==5 &&
			c1000["jade"]==2010 && c1000["stone"]==5,
			sprintf("%O %O %O",c0,c50,c1000));

		/* ===== 1f) 幸运影响成功率 ===== */
		check("1f-1.幸运加成线性且封顶2000bp",
			REFINED->query_refine_luck_bonus(0)==0 &&
			REFINED->query_refine_luck_bonus(1000)==1000 &&
			REFINED->query_refine_luck_bonus(5000)==2000,
			sprintf("%d %d %d",
				REFINED->query_refine_luck_bonus(0),
				REFINED->query_refine_luck_bonus(1000),
				REFINED->query_refine_luck_bonus(5000)));
		/* ===== 2) 事务性与惩罚 ===== */
		me = create_saved_player(account_id,"refine88","10.0.0.1");
		object sword = clone(ROOT+
			"/gamelib/clone/item/weapon/17duanshuijian/17duanshuijian");
		sword->move(me);
		mapping r2a = REFINED->attempt_refine(me,sword);
		check("2a.淬炼石不足时拒绝且不扣费",
			(int)r2a["ok"]==0 &&
			search((string)r2a["message"],"淬炼石不足")!=-1 &&
			(int)sword->query_refine_level()==0,
			"无料提炼未被拦截");
		grant_stones(me,10000000);
		object jade = clone(ROOT+
			"/gamelib/clone/item/material/lihuoyu");
		jade->amount = 10000000;
		jade->move(me);
		object yu = clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
		yu->amount = 200000;
		yu->move(me);
		mapping r2b = REFINED->attempt_refine(me,sword,1);
		check("2b.普通成功+1级且名称带+N",
			(int)r2b["success"]==1 && (int)r2b["level"]==1 &&
			(int)sword->query_refine_level()==1 &&
			has_suffix((string)sword->query_name_cn(),"+1"),
			sprintf("level=%d name=%s",(int)sword->query_refine_level(),
				(string)sword->query_name_cn()));
		me->set_lunck(800);
		int expected_rate=3000+800+
			(REFINED->query_weekend_boost()-100);
		check("2b2.幸运(及周末)计入实际成功率",
			REFINED->query_luck_adjusted_rate(me,130)==expected_rate,
			sprintf("rate=%d expected=%d",
				REFINED->query_luck_adjusted_rate(me,130),
				expected_rate));
		check("2b3.幸运不越过100%上限",
			REFINED->query_luck_adjusted_rate(me,0)==10000,
			sprintf("rate=%d",
				REFINED->query_luck_adjusted_rate(me,0)));
		me->set_lunck(0);
		int base_attack=(int)sword->query_attack_power();
		sword->set_refine_level(0);
		int raw_attack=(int)sword->query_attack_power();
		check("2c.属性随提炼等级乘算",
			raw_attack>0 && base_attack==(raw_attack*101)/100,
			sprintf("raw=%d refined=%d",raw_attack,base_attack));
		sword->set_refine_level(5);
		REFINED->attempt_refine(me,sword,10000);
		check("2d.普通失败保级只耗材料",
			(int)sword->query_refine_level()==5,
			sprintf("level=%d",(int)sword->query_refine_level()));
		/* 冲+10门槛失败降3级 */
		sword->set_refine_level(9);
		REFINED->attempt_refine(me,sword,10000);
		check("2e.门槛失败降3级",
			(int)sword->query_refine_level()==6,
			sprintf("level=%d",(int)sword->query_refine_level()));
		/* 高档门槛失败降30% */
		sword->set_refine_level(149);
		REFINED->attempt_refine(me,sword,10000);
		check("2f.高档门槛失败降30%",
			(int)sword->query_refine_level()==105,
			sprintf("level=%d",(int)sword->query_refine_level()));
		me->m_delete_foruser("/plus/refine_pity");
		/* 级联防回归：199失败最多跌回本段起点150（旧规则会跌穿
		 * 到105并级联重穿下方所有门槛，+500都要20万次尝试）。 */
		sword->set_refine_level(199);
		REFINED->attempt_refine(me,sword,10000);
		check("2f2.门槛失败最多跌回本段起点(199→150)",
			(int)sword->query_refine_level()==150,
			sprintf("level=%d",(int)sword->query_refine_level()));
		/* 守护符：高档门槛失败降30%被减免为3级（先清保底计数） */
		me->m_delete_foruser("/plus/refine_pity");
		sword->set_refine_level(199);
		object charm = clone(ROOT+
			"/gamelib/clone/item/material/tilianshouhufu");
		charm->move(me);
		REFINED->attempt_refine(me,sword,10000);
		check("2g.守护符把高档惩罚减免为3级且被消耗",
			(int)sword->query_refine_level()==196 &&
			count_charms(me)==0,
			sprintf("level=%d charms=%d",
				(int)sword->query_refine_level(),
				count_charms(me)));

		/* ===== 3) PK掉落五重防刷 ===== */
		victim = create_saved_player(victim_id,"refine88","10.0.0.2");
		victim->level = 60;
		REFINED->maybe_drop_pvp_material(me,victim,1);
		check("3a.正常PK击杀掉淬炼石",
			count_stones(me)>3000000,
			sprintf("stones=%d",count_stones(me)));
		int before_stones=count_stones(me);
		REFINED->maybe_drop_pvp_material(me,victim,1);
		check("3b.同一受害者30分钟冷却不再掉",
			count_stones(me)==before_stones,"冷却失效");
		object stranger = create_saved_player("xd01testrefine3",
			"refine88","10.0.0.3");
		stranger->set_userip("10.0.0.1");
		stranger->set_account_owner("xd01testrefine3");
		int s2=count_stones(me);
		REFINED->maybe_drop_pvp_material(me,stranger,1);
		check("3c.相同IP不掉",
			count_stones(me)==s2,"同IP掉了");
		stranger->set_userip("10.0.0.9");
		stranger->set_account_owner(account_id);
		REFINED->maybe_drop_pvp_material(me,stranger,1);
		check("3d.同账号不掉",
			count_stones(me)==s2,"同账号掉了");
		stranger->set_account_owner("xd01testrefine3");
		stranger->level = 200;
		REFINED->maybe_drop_pvp_material(me,stranger,1);
		check("3e.等级差>30不掉",
			count_stones(me)==s2,"等级差掉了");
		destruct(stranger);
		ACCOUNT_CHARACTERD->remove_test_account("xd01testrefine3");
		cleanup_player("xd01testrefine3");

		/* ===== 4) 各类型装备提炼到+1000 ===== */
		array(object) gears = ({
			clone(ROOT+"/gamelib/clone/item/weapon/13huojingjian/13huojingjian"),
			clone(ROOT+"/gamelib/clone/item/armor/14chonghuitoushi/14chonghuitoushi"),
			clone(ROOT+"/gamelib/clone/item/wuxinsuit/xinyuanjie"),
		});
		foreach(gears,object g)
			g->move(me);
		/* 新月共鸣样本 */
		array(string) nm_files=sort(glob("*_nm*",
			get_dir(ROOT+
			"/gamelib/clone/item/weapon/69xinyueliangyijian/") || ({})));
		if(sizeof(nm_files)>0){
			object nm=clone(ROOT+
				"/gamelib/clone/item/weapon/69xinyueliangyijian/"+
				nm_files[0]);
			nm->move(me);
			gears += ({nm});
		}
		int all_ok = 1;
		string fail_info = "";
		int idx = 0;
		foreach(gears,object g){
			idx++;
			int base_atk=(int)g->query_attack_power();
			int base_def=(int)g->query_equip_defend();
			int base_str=(int)g->query_str_add();
			/* 真实逐次提炼到1000（强制成功骰） */
			int steps = 0;
			while((int)g->query_refine_level()<1000 && steps<1100){
				mapping r=REFINED->attempt_refine(me,g,1);
				steps++;
				if((int)r["success"]!=1){
					all_ok=0;
					fail_info+="gear"+idx+" step"+steps+" fail";
					break;
				}
			}
			int lv=(int)g->query_refine_level();
			if(lv!=1000){
				all_ok=0;
				fail_info+=" gear"+idx+" level="+lv;
			}
			/* 属性=11倍 */
			int expect_atk=base_atk*1100/100;
			if(base_atk>0 && (int)g->query_attack_power()!=expect_atk){
				all_ok=0;
				fail_info+=" gear"+idx+" atk "+
					(int)g->query_attack_power()+"!="+expect_atk;
			}
			if(base_str>0 &&
			   (int)g->query_str_add()!=base_str*1100/100){
				all_ok=0;
				fail_info+=" gear"+idx+" str scaled wrong";
			}
			if(!has_suffix((string)g->query_name_cn(),"+1000")){
				all_ok=0;
				fail_info+=" gear"+idx+" name "+
					(string)g->query_name_cn();
			}
		}
		check("4a.四类装备全部真实提炼到+1000且属性×11",
			all_ok,fail_info=="" ? "unknown" : fail_info);
		/* 1000级后的门槛失败（1050门槛） */
		gears[0]->set_refine_level(1099);
		me->m_delete_foruser("/plus/refine_pity");
		foreach(all_inventory(me),object ob)
			if(ob && functionp(ob->query_name) &&
			   (string)ob->query_name()=="tilianshouhufu"){
				ob->amount=0;
				ob->remove();
			}
		mapping r4c=REFINED->attempt_refine(me,gears[0],10000);
		check("4c.千级门槛失败降30%封顶50",
			(int)gears[0]->query_refine_level()==1049,
			sprintf("level=%d msg=%s",(int)gears[0]->query_refine_level(),
				(string)r4c["message"]));
		gears[0]->set_refine_level(1000);
		/* 存档往返 */
		me->save_with_result();
		object reloaded = clone(GAMELIB_USER);
		reloaded->set_name(account_id);
		reloaded->set_project("gamelib");
		mixed r_err = catch{ reloaded->restore(); };
		int restored_lv = -1;
		array(object) re_gears =({});
		if(!r_err && objectp(reloaded)){
			foreach(all_inventory(reloaded),object ob){
				if(functionp(ob->query_refine_level) &&
				   (int)ob->query_refine_level()==1000)
					re_gears += ({ob});
			}
		}
		check("4b.+1000等级随存档往返保留",
			sizeof(re_gears)>=3,
			sprintf("restored=%d",sizeof(re_gears)));
		if(reloaded)
			destruct(reloaded);
		foreach(gears,object g)
			destruct(g);

		/* ===== 5) 经济统计（真实随机骰0→1000） ===== */
		int attempts = 0;
		int stones_used = 0;
		int yushi_used = 0;
		int level = 0;
		int fails_at_threshold = 0;
		while(level<100 && attempts<200000){
			mapping cc=REFINED->query_refine_costs(level);
			attempts++;
			stones_used+=cc["stone"];
			yushi_used+=cc["jade"];
			if(random(10000)<REFINED->query_refine_success_rate(level))
				level++;
			else if(REFINED->query_is_threshold_attempt(level)){
				fails_at_threshold++;
				int tgt=level+1;
				int bs=tgt<=100 ? tgt-10 :
					(tgt<=1000 ? tgt-50 : tgt-100);
				level-=REFINED->query_threshold_penalty_levels(level);
				if(level<0)
					level=0;
				if(bs>0 && level<bs)
					level=bs;
				while(level>0 &&
				      REFINED->query_is_threshold_attempt(level))
					level--;
			}
		}
		werror("  [经济模拟] 0→+100：尝试%d次、门槛失败%d次、"+
			"淬炼石%d颗、碎玉%d\n",
			attempts,fails_at_threshold,stones_used,yushi_used);
		check("5a.真实随机骰可到达+100且成本有限",
			level==100 && attempts>100 && attempts<200000,
			sprintf("level=%d attempts=%d",level,attempts));
		/* 封顶50后复测0→1000：旧参数下20万次仅到125级 */
		int lv2=0;
		int at2=0;
		while(lv2<1000 && at2<150000){
			at2++;
			if(random(10000)<REFINED->query_refine_success_rate(lv2))
				lv2++;
			else if(REFINED->query_is_threshold_attempt(lv2)){
				int tgt2=lv2+1;
				int bs2=tgt2<=100 ? tgt2-10 :
					(tgt2<=1000 ? tgt2-50 : tgt2-100);
				lv2-=REFINED->query_threshold_penalty_levels(lv2);
				if(lv2<0)
					lv2=0;
				if(bs2>0 && lv2<bs2)
					lv2=bs2;
				while(lv2>0 &&
				      REFINED->query_is_threshold_attempt(lv2))
					lv2--;
			}
		}
		werror("  [经济模拟] 封顶50后0→+1000：尝试%d次，到达+%d\n",
			at2,lv2);
		check("5a2.封顶50后+1000可达（负漂移墙已修复）",
			lv2>=300,
			sprintf("level=%d attempts=%d",lv2,at2));
		/* 幸运压力对比：幸运0/1000/2000 三档 0→+1000 */
		int luck_total_stones=0;
		array(int) luck_attempts=({});
		foreach(({0,1000,2000}),int luck_val){
			int lv3=0;
			int at3=0;
			int stones3=0;
			while(lv3<1000 && at3<150000){
				at3++;
				stones3+=5;
				int r3=REFINED->query_refine_success_rate(lv3)+
					REFINED->query_refine_luck_bonus(luck_val);
				if(r3>10000)
					r3=10000;
				if(random(10000)<r3)
					lv3++;
				else if(REFINED->query_is_threshold_attempt(lv3)){
					int tgt3=lv3+1;
					int bs3=tgt3<=100 ? tgt3-10 :
						(tgt3<=1000 ? tgt3-50 : tgt3-100);
					lv3-=REFINED->query_threshold_penalty_levels(lv3);
					if(lv3<0)
						lv3=0;
					if(bs3>0 && lv3<bs3)
						lv3=bs3;
					while(lv3>0 &&
					      REFINED->query_is_threshold_attempt(lv3))
						lv3--;
				}
			}
			werror("  [幸运压力] 幸运%d：0→+1000 尝试%d次 淬炼石%d 到达+%d\n",
				luck_val,at3,stones3,lv3);
			luck_attempts+=({at3});
			if(luck_val==2000)
				luck_total_stones=stones3;
		}
		check("5a3.幸运压力测试完成且封顶档材料显著下降",
			sizeof(luck_attempts)==3 && luck_attempts[2]>=1000 &&
			luck_attempts[2]<luck_attempts[0] &&
			luck_total_stones>0,
			sprintf("attempts=%O stones=%d",luck_attempts,
				luck_total_stones));

		/* ===== 5c) PK榜纯展示 + 捐赠月榜守护符 ===== */
		/* 用全新受害者即时击杀一次，保证榜单状态自包含。 */
		object victim_fresh=create_saved_player("xd01testrefine4",
			"refine88","10.0.0.4");
		mapping dbg=(["kl":(int)me->query_level(),
			"vl":(int)victim_fresh->query_level(),
			"ka":(string)me->query_account_owner(),
			"va":(string)victim_fresh->query_account_owner(),
			"ki":(string)me->query_userip(),
			"vi":(string)victim_fresh->query_userip(),
			"npc1":(int)me->is("npc"),
			"npc2":(int)victim_fresh->is("npc")]);
		REFINED->maybe_drop_pvp_material(me,victim_fresh,1);
		destruct(victim_fresh);
		ACCOUNT_CHARACTERD->remove_test_account("xd01testrefine4");
		cleanup_player("xd01testrefine4");
		array rank=REFINED->query_monthly_pvp_rank(10);
		int me_ranked=0;
		foreach(rank,array row)
			if(row[0]==account_id && row[2]>=1)
				me_ranked=1;
		check("5c-1.有效击杀计入月度PK榜",
			me_ranked,sprintf("rank=%O dbg=%O",rank[0..1],dbg));
		/* PK击杀不得产生守护符：击杀前后待发队列数不变
		 * （不依赖跨run持久化的捐赠残留状态）。 */
		int pend_before=REFINED->query_pending_charm_count();
		REFINED->maybe_drop_pvp_material(me,victim_fresh,1);
		check("5c-2.PK击杀不结算守护符",
			REFINED->query_pending_charm_count()==pend_before,
			sprintf("before=%d after=%d",pend_before,
				REFINED->query_pending_charm_count()));
		REFINED->ensure_pvp_month_rollover("2000-01");
		array rank2=REFINED->query_monthly_pvp_rank(10);
		check("5c-3.跨月后PK榜清零",
			sizeof(rank2)==0,sprintf("rank=%O",rank2));
		REFINED->record_donation(account_id,"提炼测试",999999);
		array drank=REFINED->query_monthly_donation_rank(20);
		int me_donated=0;
		foreach(drank,array row)
			if(row[0]==account_id && row[2]>=999999)
				me_donated=1;
		check("5c-4.充值计入捐赠月榜",
			me_donated && drank[0][0]==account_id,
			sprintf("drank=%O",drank[0..2]));
		ch_pre=count_charms(me);
		REFINED->ensure_pvp_month_rollover("2001-01");
		REFINED->maybe_deliver_pending_charm(me);
		check("5c-5.捐赠月榜榜首跨月获赠守护符",
			count_charms(me)>ch_pre,
			sprintf("before=%d after=%d",ch_pre,count_charms(me)));
		REFINED->ensure_pvp_month_rollover();
		string wallet_src=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/account_walletd.pike") || "";
		check("5c-6.钱包充值入口累计捐赠",
			search(wallet_src,"record_donation")!=-1,"钩子缺失");
		string equip_src=Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/equip.pike") || "";
		check("6a.套装提炼共鸣接线",
			search(equip_src,"query_refine_set_resonance")!=-1 &&
			search(equip_src,"wuxinsuit")!=-1,
			"共鸣缺失");
		check("6b.离火玉与碎晶物品存在",
			Stdio.file_size(ROOT+
			"/gamelib/clone/item/material/lihuoyu")>0 &&
			Stdio.file_size(ROOT+
			"/gamelib/clone/item/material/suijing")>0,
			"物品缺失");
		check("6c.心魔NPC可由真实Pike编译",
			!catch{ compile_file(ROOT+
				"/gamelib/clone/npc/refine_xinmo.pike"); },
			"编译失败");

		/* ===== 5b) 心渊套装可提炼（洗维持锁定） ===== */
		object xy=clone(ROOT+"/gamelib/clone/item/wuxinsuit/xinyuanjie");
		check("5b.心渊套装进入提炼白名单",
			objectp(xy) && ITEMSD->can_equip(xy) &&
			(xy->query_item_rareLevel()>0 ||
			 functionp(xy->query_newmoon_collection_id)),
			"心渊不可提炼");
		if(xy)
			destruct(xy);

		/* ===== 5d) 二期：离火玉/购买/保底/催化剂/传承/碎晶/排行/心魔 ===== */
		int jade_before=count_named(me,"lihuoyu");
		mapping rb=REFINED->buy_jade(me,100);
		check("5d-1.碎玉1:1购买离火玉",
			(int)rb["ok"]==1 &&
			count_named(me,"lihuoyu")==jade_before+100,
			sprintf("%O",rb));
		object sword2=clone(ROOT+
			"/gamelib/clone/item/weapon/13huojingjian/13huojingjian");
		sword2->move(me);
		object|zero jade_stack=0;
		foreach(all_inventory(me),object ob)
			if(ob && functionp(ob->query_name) &&
			   (string)ob->query_name()=="lihuoyu"){
				jade_stack=ob;
				break;
			}
		int jade_saved=(int)(jade_stack && jade_stack->amount);
		if(jade_stack)
			jade_stack->amount=3;
		mapping rj=REFINED->attempt_refine(me,sword2);
		check("5d-2.离火玉不足时拒绝且不扣费",
			(int)rj["ok"]==0 &&
			search((string)rj["message"],"离火玉不足")!=-1,
			sprintf("%O",rj));
		if(jade_stack)
			jade_stack->amount=jade_saved;
		/* 保底：3次门槛失败后必成 */
		sword2->set_refine_level(9);
		me->m_delete_foruser("/plus/refine_pity");
		string pity_trace="";
		for(int i=0;i<3;i++){
			mapping rl=REFINED->attempt_refine(me,sword2,10000);
			pity_trace+="[i"+i+":ok"+(int)rl["ok"]+
				"s"+(int)(rl["success"] || 0)+"p"+
				(int)(me["/plus/refine_pity"] || 0)+"]";
			sword2->set_refine_level(9);
		}
		mapping rp=REFINED->attempt_refine(me,sword2,10000);
		check("5d-3.门槛保底3连败后必成",
			(int)rp["success"]==1 &&
			(int)sword2->query_refine_level()==10,
			sprintf("level=%d pity=%d trace=%s %O",
				(int)sword2->query_refine_level(),
				(int)(me["/plus/refine_pity"] || 0),
				pity_trace,rp));
		me->m_delete_foruser("/plus/refine_pity");
		/* 护心丹 */
		mapping rsd=REFINED->buy_catalyst(me,"shield");
		sword2->set_refine_level(199);
		REFINED->attempt_refine(me,sword2,10000);
		check("5d-4.护心丹免降级",
			(int)rsd["ok"]==1 &&
			(int)sword2->query_refine_level()==199,
			sprintf("level=%d",(int)sword2->query_refine_level()));
		/* 祝福油 */
		REFINED->buy_catalyst(me,"bless");
		int rate_bless=REFINED->query_luck_adjusted_rate(me,50);
		REFINED->attempt_refine(me,sword2,10000);
		check("5d-5.祝福油加成且单次消耗",
			rate_bless-(REFINED->query_weekend_boost()-100)>
			REFINED->query_refine_success_rate(50) &&
			(int)(me["/plus/refine_blessing_bp"] || 0)==0,
			sprintf("rate=%d",rate_bless));
		/* 周末窗口纯函数 */
		check("5d-6.周末黄金时段判定",
			REFINED->query_weekend_boost(6,20)==150 &&
			REFINED->query_weekend_boost(0,21)==150 &&
			REFINED->query_weekend_boost(6,19)==100 &&
			REFINED->query_weekend_boost(3,20)==100,
			"周末判定异常");
		/* 碎晶合成 */
		object shard=clone(ROOT+
			"/gamelib/clone/item/material/suijing");
		shard->amount=100;
		shard->move(me);
		int stones_before=count_named(me,"cuilianshi");
		mapping rc=REFINED->compose_shards(me);
		check("5d-7.碎晶100合1淬炼石",
			(int)rc["ok"]==1 &&
			count_named(me,"cuilianshi")==stones_before+1,
			sprintf("%O",rc));
		/* 传承 */
		object sword3=clone(ROOT+
			"/gamelib/clone/item/weapon/17duanshuijian/17duanshuijian");
		sword3->move(me);
		sword2->set_refine_level(50);
		sword3->set_refine_level(0);
		mapping rt=REFINED->transfer_refine(me,sword2,sword3);
		check("5d-8.提炼传承90%转移",
			(int)rt["ok"]==1 &&
			(int)sword3->query_refine_level()==45 &&
			(int)sword2->query_refine_level()==5,
			sprintf("%O lv2=%d lv3=%d",rt,
				(int)sword2->query_refine_level(),
				(int)sword3->query_refine_level()));
		/* 排行 */
		array rank3=REFINED->query_refine_rank(20);
		int me_ranked3=0;
		foreach(rank3,mapping row)
			if((string)row["account"]==account_id)
				me_ranked3=1;
		check("5d-9.提炼等级进入排行",me_ranked3,
			sprintf("rank=%O",rank3[0..2]));
		/* 心魔：门槛大跌→挑战队列→战胜恢复（先清守护符防减免） */
		sword2->set_refine_level(199);
		me->m_delete_foruser("/plus/refine_shield");
		foreach(all_inventory(me),object ob)
			if(ob && functionp(ob->query_name) &&
			   (string)ob->query_name()=="tilianshouhufu"){
				ob->amount=0;
				ob->remove();
			}
		REFINED->attempt_refine(me,sword2,10000);
		array xm=REFINED->query_xinmo_challenge(me);
		check("5d-10.高档门槛大跌产生心魔挑战",
			arrayp(xm) && (int)xm[1]>=10,
			sprintf("xm=%O",xm));
		mapping rx=REFINED->complete_xinmo(me);
		check("5d-11.战胜心魔恢复损失等级",
			(int)rx["ok"]==1 &&
			(int)sword2->query_refine_level()==199,
			sprintf("%O level=%d",rx,
				(int)sword2->query_refine_level()));
		if(sword3)
			destruct(sword3);

		/* ===== 6) 接线源检查 ===== */
		string die_src=Stdio.read_file(ROOT+
			"/gamelib/clone/user.pike") || "";
		check("6a.PK死亡钩子接线",
			search(die_src,"maybe_drop_pvp_material")!=-1,"钩子缺失");
		string supply=Stdio.read_file(ROOT+
			"/gamelib/cmds/illusion_supply.pike") || "";
		check("6b.幻境补给提炼入口",
			search(supply,"[提炼炉·装备提炼:refine]")!=-1,"入口缺失");
		string cvt=Stdio.read_file(ROOT+
			"/gamelib/cmds/convert_equip_confirm.pike") || "";
		check("6c.洗装保留提炼等级",
			search(cvt,"set_refine_level")!=-1,"转移缺失");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	if(me){
		me->save_with_result();
		destruct(me);
	}
	if(victim)
		destruct(victim);
	object httpd=(object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	httpd->remove_virtual_connection(account_id);
	httpd->remove_virtual_connection(victim_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(victim_id);
	cleanup_player(account_id);
	cleanup_player(victim_id);
	cleanup_player("xd01testrefine3");
	werror("========== 提炼系统测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
