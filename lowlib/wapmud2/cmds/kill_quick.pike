#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

// 快速战斗在当前 Worker 内同步推演；必须有硬上限，否则极端高血
// 低伤组合可以用单个 HTTP 请求占住进程数十万乃至数亿轮。
// 上限以内不改任何原公式；未决出胜负时不发放击杀奖励。
// 4096轮在真实Pike进程中可占用单个Worker约7秒，仍足以形成并发DoS。
// 正常快速战斗通常在几十轮内结束；512只收紧病态僵局的同步预算。
#define QUICK_BATTLE_MAX_ROUNDS 512

/**
 * S1 的部分房间怪由逻辑区刷新器托管：它们能出现在玩家的可见列表中，
 * 但旧 present(id) 在刷新交界点可能无法用字符串 id 再次命中对象。
 * 兜底只扫描当前房间、只接受玩家实际可见且内部名称完全相同的对象，
 * 后续仍会执行 NPC、阵营、和平房和生命状态等全部原有校验。
 */
private object|zero query_visible_quick_target(object player,string name,
	int count)
{
	object room=environment(player);
	object|zero target;
	if(!room || name=="" || count<0)
		return 0;
	target=present(name,room,count,player);
	if(target)
		return target;
	foreach(all_inventory(room,player),object candidate){
		// 仍要求对象主动承认这个 id；绝不能借兜底攻击故意隐藏
		// id 的剧情 NPC、召唤物或其他不可由名字选中的对象。
		if(!functionp(candidate->query_name) ||
		   !functionp(candidate->id) || !candidate->id(name) ||
		   (string)candidate->query_name()!=name)
			continue;
		if(count==0)
			return candidate;
		count--;
	}
	return 0;
}

int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!me)
		return 0;
	if(!environment(me)){
		write("你当前不在有效地图中，请重新进入游戏。\n");
		return 1;
	}
	if(!arg || arg==""){
		me->write_view(WAP_VIEWD["/emote"],0,0,"你要攻击什么东西？\n");
		return 1;
	}
	/////////////////////////////////////////////////////////////////////////
	//每次需要隔1秒，不能连续刷
	if(me["/tmp/qkill"]==0)
		me["/tmp/qkill"] = (System.Time()->usec_full)/1000;//time();
	else{
		if( ((System.Time()->usec_full)/1000 - me["/tmp/qkill"]) < 900 ){
			string s_not = "为了不影响游戏效率，每次快速战斗需要间隔1秒。\n";
			s_not += "[返回游戏:look]\n";
			write(s_not);
			return 1;
		}
		else{
			me["/tmp/qkill"] = (System.Time()->usec_full)/1000;
		}
	}
	if(me->query_level()<=10){
		string tmp ="您现在处于新手阶段，10级以下可以免费体验快速攻击功能。\n";
		s +="§6"+tmp+"§r";//name_cn=query_rare_level()+name_cn;</p>\n";
	}
	else{
		if(VIP_KILL_LIMIT){
		/* 100级钻石会员 61-100 白金会员 50-61 黄金 40-50 水晶*/	
		if(me->query_level()>=10 && me->query_level()<50){
			if(!me->query_vip_flag()){
				string tipsvip = "";
				tipsvip += "等级超过40级，需要水晶会员级别及以上级别，才可以继续进行相关游戏功能\n";
				tell_object(me,tipsvip);
				return 1;
			}
			else{
				if(me->query_vip_flag()>=1)
					;
				else{
					string tipsvip2 = "";
					tipsvip2 += "等级超过40级，需要水晶会员级别及以上级别，才可以继续进行相关游戏功能\n";
					tell_object(me,tipsvip2);
					return 1;
				}
			}
		}else 
		if(me->query_level()>=50 && me->query_level()<61){
			if(!me->query_vip_flag()){
				string tipsvip = "";
				tipsvip += "等级超过50级，需要黄金会员级别及以上级别，才可以继续进行相关游戏功能\n";
				tell_object(me,tipsvip);
				return 1;
			}
			else{
				if(me->query_vip_flag()>=2)
					;
				else{
					string tipsvip2 = "";
					tipsvip2 += "等级超过50级，需要黄金会员级别及以上级别，才可以继续进行相关游戏功能\n";
					tell_object(me,tipsvip2);
					return 1;
				}
			}
		}else if(me->query_level()>=61 && me->query_level()<100){
			if(!me->query_vip_flag()){
				string tipsvip = "";
				tipsvip += "等级超过60级，需要白金会员级别及以上级别，才可以继续进行相关游戏功能\n";
				tell_object(me,tipsvip);
				return 1;
			}
			else{
				if(me->query_vip_flag()>=3)
					;
				else{
					string tipsvip2 = "";
					tipsvip2 += "等级超过60级，需要白金会员级别及以上级别，才可以继续进行相关游戏功能\n";
					tell_object(me,tipsvip2);
					return 1;
				}
			}
		}else if(me->query_level()>=100){
			if(!me->query_vip_flag()){
				string tipsvip = "";
				tipsvip += "等级超过100级，需要钻石会员级别及以上级别，才可以继续进行相关游戏功能\n";
				tell_object(me,tipsvip);
				return 1;
			}
			else{
				if(me->query_vip_flag()>=4)
					;
				else{
					string tipsvip2 = "";
					tipsvip2 += "等级超过100级，需要钻石会员级别及以上级别，才可以继续进行相关游戏功能\n";
					tell_object(me,tipsvip2);
					return 1;
				}
			}
		}
		} // VIP_KILL_LIMIT
	}
	//////1000元免精力//////
	int szx=me->all_fee;                                                                                                                  

	string name=arg;
	int count;
	int flag = 1;
	sscanf(arg,"%s %d",name,count);
	object ob=query_visible_quick_target(me,name,count);
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你要攻击什么东西？\n");
		return 1;
	}
	// 快速攻击只模拟 PVE。玩家 PK 必须进入真实战斗链，不能绕过
	// PK、队伍、跨 Worker 归属以及技能结算规则。
	if(!ob->is("npc")){
		me->write_view(WAP_VIEWD["/emote"],0,0,
			"快速攻击只能用于怪物；玩家对战请使用杀戮。\n");
		return 1;
	}
	if(functionp(ob->can_be_attacked) && !ob->can_be_attacked(me)){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,
			"你不能攻击自己的召唤灵兽或同阵营灵兽！\n");
		return 1;
	}
	if(environment(this_player())->is("peaceful")){
		this_player()->write_view(WAP_VIEWD["/fight_peaceful"]);
		return 1;
	}
	if(flag){
		//object me = this_player();
		//string s = "";
		//s += "当前精力："+me->query_jingli()+"\n";
		if(me->query_jingli()<=10){
			if(szx<1000){ //////1000元免精力//////
				string stmp ="精力不足，无法快速战斗，请返回。";
				s +="§6"+stmp+"§r\n";//name_cn=query_rare_level()+name_cn;</p>\n";
				s += "累计捐赠1000元，解锁0精力快速攻击功能！!\n，捐赠请加qq 1811117272。\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
		}
		if(me->get_cur_life()<=0){
			me->write_view(WAP_VIEWD["/emote"],0,0,
				"你当前生命不足，无法开始战斗，请先休息恢复。\n");
			return 1;
		}
		if(ob->get_cur_life()<=0 || ob->query_life_max()<=0){
			me->write_view(WAP_VIEWD["/emote"],0,0,
				"这个目标已经倒下，请刷新场景后再试。\n");
			return 1;
		}
		if(ob->is("npc")&&ob->_boss){
			string stmp2 ="boss级别的怪物，无法实行快速攻击。";
			s +="§6"+stmp2+"§r\n";//name_cn=query_rare_level()+name_cn;</p>\n";
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
		//int add_jl = 0;
		//if(ob->is("npc")&&ob->_meritocrat)
		//	add_jl = 3;//精英耗费更多精力快速战斗
		int add_jl = me->query_level()/10;
		int rdc_bound = add_jl;
		if(rdc_bound<1)
			rdc_bound = 1;
		int rdc = random(rdc_bound)+1;//根据等级加大装备消耗
		me->enemy=ob;
		//npc战斗系列标示，供fight _die调用
		ob->flush_targets(me,1); //初始仇恨值为1
		ob->who_fight_npc = me->query_name();//首次攻击者
		ob->term_who_fight_npc = me->query_term();//首次攻击者队伍标示          
		ob->enemy=me;
		//不调用战斗核心，模拟战斗过程
		//玩家的
		int me_attack = me->query_base_damage()+me->query_equip_damage("base_attack_main")+me->query_equip_damage("base_attack_other");
		int me_defend = me->query_defend_power();
		//怪物的
		int ob_attack = ob->query_base_damage();
		int ob_defend = me->query_effective_physical_defense(me,ob);
		int ob_level = ob->query_level();
		// random() 的上界必须为正；正常属性的既有公式与随机区间不变。
		if(me_attack<1)
			me_attack = 1;
		if(me_defend<1)
			me_defend = 1;
		if(ob_attack<1)
			ob_attack = 1;
		if(ob_defend<1)
			ob_defend = 1;
		if(ob_level<1)
			ob_level = 1;
		//战斗开始，直到双方任何一方生命为0结束
		int quick_battle_rounds;
		while(me->get_cur_life()>0 && ob->get_cur_life()>0 &&
		   quick_battle_rounds<QUICK_BATTLE_MAX_ROUNDS){
			quick_battle_rounds++;
			if(szx<1000){
				me->set_jingli(me->query_jingli()-10-add_jl-rdc);
				if(me->query_jingli()<=0)
					me->set_jingli(0);
			}
			me->reduce_fight_wield_weapon(1);
			me->reduce_fight_wear_armor(1);
			int tmp_me_atk = random(me_attack);
			int tmp_me_def = random(me_defend);
			int tmp_ob_atk = random(ob_attack);
			int tmp_ob_def = random(ob_defend);
			int dmg_ob = tmp_me_atk - tmp_ob_def;
			if(dmg_ob<=0)
				dmg_ob = 1;
			dmg_ob=PERSONAL_DIFFICULTYD->scale_pve_damage(me,ob,dmg_ob);
			ob->set_life(ob->get_cur_life()-dmg_ob);
			int dmg_me = tmp_ob_atk + random(ob_level) - tmp_me_def;
			if(dmg_me<=0)
				dmg_me = random(ob_level);
			dmg_me=PERSONAL_DIFFICULTYD->scale_pve_damage(ob,me,dmg_me);
			me->set_life(me->get_cur_life()-dmg_me);
		}
		int unresolved=me->get_cur_life()>0 && ob->get_cur_life()>0;
		//得到结果，调用双方的fight _die
		if(unresolved){
			// 不猜测超长战斗的胜负，也不让已经进行的模拟落入
			// 普通心跳重复结算。怪物恢复、双方脱离临时仇恨；
			// 玩家已承受的生命/精力/耐久消耗不回滚，避免变成免费试伤。
			s += "【快速战斗】双方在"+
				(string)QUICK_BATTLE_MAX_ROUNDS+
				"轮内未分胜负，已安全中止。请提升属性或使用普通战斗。\n";
			ob->set_life(ob->query_life_max());
			ob->reset_targets();
			ob->enemy=0;
			ob->_clean_fight();
			me->enemy=0;
		}
		else if(me->get_cur_life()<=0){ //玩家死亡
			s += "【快速战斗】战斗失败！\n";
			ob->set_life(ob->query_life_max());//怪物回满血
			ob->who_fight_npc = "";//首次攻击者
			ob->term_who_fight_npc = "";//首次攻击者队伍标示          
			ob->reset_targets(); //重置仇恨列表
			ob->enemy=0;
			me->fight_die();
			// 跨 Worker 复活会由网关用目标端安全页面替换源端响应。
			// 在唯一玩家档案中暂存一次结果，让目标 Worker 输出结果页。
			mapping redirect = MAP_WORKERD->query_local_move_redirect(
				me->query_name());
			if(MAP_WORKERD->query_node_role()=="worker" &&
			   (int)redirect["ok"] &&
			   functionp(me->stage_worker_quick_battle_notice))
				me->stage_worker_quick_battle_notice(
					"【快速战斗】战斗失败！你已回到复活点，请先休息恢复生命。\n");
			me->enemy=0;
		}
		else if(ob->get_cur_life()<=0){ //怪物死亡
			s += "【快速战斗】战斗胜利！\n";
			ob->fight_die();
			if(ob){
				ob->reset_targets(); //重置仇恨列表
				ob->who_fight_npc = "";//首次攻击者
				ob->term_who_fight_npc = "";//首次攻击者队伍标示          
				ob->enemy=0;
			}
			s+="──────────\n";
			if(me->get_cur_life()<me->life_max*3/10)
				s += "§1生命 "+
					format_game_number(me->get_cur_life())+"/"+
					format_game_number(me->life_max)+"§r\n";
			else if(me->get_cur_life()<me->life_max*6/10)
				s += "§6生命 "+
					format_game_number(me->get_cur_life())+"/"+
					format_game_number(me->life_max)+"§r\n";
			else
				s += "§6生命 "+
					format_game_number(me->get_cur_life())+"/"+
					format_game_number(me->life_max)+"§r\n";
			s += "法力 "+format_game_number(me->get_cur_mofa())+"/"+
				format_game_number(me->mofa_max)+"\n";
			s += "精力 "+me->query_jingli()+"\n"; 
			s+="──────────\n";
		}
		if(!unresolved && me->query_jingli()>10)
			s += "[继续:kill_quick "+arg+"]\n";
		s += "[返回:look]\n";
		// 快速战斗必须生成独立结果视图。直接 write() 会把奖励异步输出、
		// 房间刷新或跨 Worker 到达页混在同一个响应里；同名怪较多时，
		// 玩家会只看到 westeastnorth 与怪物列表，误以为点击无效。
		// 使用既有 emote 视图保存完整战果，同时保留继续和返回按钮。
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你要攻击什么？\n");
	return 1;
}
