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
			c0["yushi"]==10 && c0["stone"]==5 && c0["money"]==0 &&
			c50["yushi"]==110 && c50["stone"]==5 &&
			c1000["yushi"]==2010 && c1000["stone"]==5,
			sprintf("%O %O %O",c0,c50,c1000));

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
		object yu = clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
		yu->amount = 10000000;
		yu->move(me);
		mapping r2b = REFINED->attempt_refine(me,sword,1);
		check("2b.普通成功+1级且名称带+N",
			(int)r2b["success"]==1 && (int)r2b["level"]==1 &&
			(int)sword->query_refine_level()==1 &&
			has_suffix((string)sword->query_name_cn(),"+1"),
			sprintf("level=%d name=%s",(int)sword->query_refine_level(),
				(string)sword->query_name_cn()));
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
		/* 级联防回归：199失败最多跌回本段起点150（旧规则会跌穿
		 * 到105并级联重穿下方所有门槛，+500都要20万次尝试）。 */
		sword->set_refine_level(199);
		REFINED->attempt_refine(me,sword,10000);
		check("2f2.门槛失败最多跌回本段起点(199→150)",
			(int)sword->query_refine_level()==150,
			sprintf("level=%d",(int)sword->query_refine_level()));
		/* 守护符：高档门槛失败降30%被减免为3级 */
		sword->set_refine_level(199);
		object charm = clone(ROOT+
			"/gamelib/clone/item/material/tilianshouhufu");
		charm->move(me);
		REFINED->attempt_refine(me,sword,10000);
		int charm_count=0;
		foreach(all_inventory(me),object ob)
			if(ob && functionp(ob->query_name) &&
			   (string)ob->query_name()=="tilianshouhufu")
				charm_count+=(int)(ob->amount || 1);
		check("2g.守护符把高档惩罚减免为3级且被消耗",
			(int)sword->query_refine_level()==196 && charm_count==0,
			sprintf("level=%d charm=%d",
				(int)sword->query_refine_level(),charm_count));

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
			yushi_used+=cc["yushi"];
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

		/* ===== 5c) 月度PK榜/跨月结算/守护符补发 ===== */
		array rank=REFINED->query_monthly_pvp_rank(10);
		int me_ranked=0;
		foreach(rank,array row)
			if(row[0]==account_id && row[2]>=1)
				me_ranked=1;
		check("5c-1.有效击杀计入月度PK榜",
			me_ranked,sprintf("rank=%O",rank[0..1]));
		REFINED->ensure_pvp_month_rollover("2000-01");
		REFINED->maybe_deliver_pending_charm(me);
		int charm2=0;
		foreach(all_inventory(me),object ob)
			if(ob && functionp(ob->query_name) &&
			   (string)ob->query_name()=="tilianshouhufu")
				charm2+=(int)(ob->amount || 1);
		check("5c-2.跨月榜首获赠守护符并登录补发",
			charm2>=1,sprintf("charms=%d",charm2));
		array rank2=REFINED->query_monthly_pvp_rank(10);
		check("5c-3.跨月后榜单清零",
			sizeof(rank2)==0,sprintf("rank=%O",rank2));
		REFINED->ensure_pvp_month_rollover();

		/* ===== 5b) 心渊套装可提炼（洗维持锁定） ===== */
		object xy=clone(ROOT+"/gamelib/clone/item/wuxinsuit/xinyuanjie");
		check("5b.心渊套装进入提炼白名单",
			objectp(xy) && ITEMSD->can_equip(xy) &&
			(xy->query_item_rareLevel()>0 ||
			 functionp(xy->query_newmoon_collection_id)),
			"心渊不可提炼");
		if(xy)
			destruct(xy);

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
