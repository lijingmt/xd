#include <mudlib.h>
inherit LOW_USER;
inherit LOW_F_DBASE;
inherit LOW_F_SAVE;
inherit MUD_F_HEARTBEAT;
inherit MUD_F_CHAR;//生物角色继承属性
inherit MUD_F_LEVEL;//玩家或者npc升级算法
inherit MUD_F_ATTACK;//战斗属性计算
//将物品重新载入身上
int restore(){
	int succ=::restore();
	if(succ){
		//用户重载之后，随身物品虽然得到了，但是必须重新设置到身体上
		foreach(all_inventory(),object ob){
			if(ob->is("equip")){
				if(ob->equiped){
					ob->equiped=0;
					if(ob->query_item_type()=="weapon"){
						wield(ob);
					}
					else{
						wear(ob);
					}
				}
			}
		}
	}
	return succ;
}
//密码设置在这一层，通过login_check.pike验证之后进行设置
//每次login.pike验证成功也会在这里设置调用
int setup(string _passwd){
	restore();
	return ::setup(_passwd);
}
void setup_player(string rid, string pid){
	//阵营和职业必须在登陆注册时选定
	gameage = 14;
	unit = "位";
	can_speak = 1;
	can_kill = 1;
	can_fight = 1;
	can_get_skin = 0;
	can_cut = 1;
	attitude = "peaceful";
	disabled_login = 0;
	disabled_post = 0;
	disabled_action = 0;
	if(rid&&rid=="human"){
		if(pid&&pid=="jianxian"){
			kind_cn = "人类";
			unit = "位";
			this_object()->set_life(120);
			this_object()->set_mofa(20);
			this_object()->set_str(12);
			this_object()->set_dex(6);
			this_object()->set_think(2);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="yushi"){
			kind_cn = "人类";
			unit = "位";
			this_object()->set_life(80);
			this_object()->set_mofa(120);
			this_object()->set_str(8);
			this_object()->set_dex(2);
			this_object()->set_think(12);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="zhuxian"){
			kind_cn = "人类";
			unit = "位";
			this_object()->set_life(100);
			this_object()->set_mofa(40);
			this_object()->set_str(10);
			this_object()->set_dex(12);
			this_object()->set_think(4);
			this_object()->set_lunck(0);
		}
	}
	else if(rid&&rid=="monst"){
		if(pid&&pid=="kuangyao"){
			kind_cn = "妖魔";
			unit = "位";
			this_object()->set_life(140);
			this_object()->set_mofa(20);
			this_object()->set_str(14);
			this_object()->set_dex(2);
			this_object()->set_think(2);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="wuyao"){
			kind_cn = "妖魔";
			unit = "位";
			this_object()->set_life(80);
			this_object()->set_mofa(100);
			this_object()->set_str(8);
			this_object()->set_dex(2);
			this_object()->set_think(10);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="yinggui"){
			kind_cn = "妖魔";
			unit = "位";
			this_object()->set_life(100);
			this_object()->set_mofa(30);
			this_object()->set_str(10);
			this_object()->set_dex(14);
			this_object()->set_think(3);
			this_object()->set_lunck(0);
		}
	}
	else if(rid&&rid=="third"){
		if(pid&&pid=="fangshi"){
			kind_cn = "中立";
			unit = "位";
			this_object()->set_life(100);
			this_object()->set_mofa(50);
			this_object()->set_str(10);
			this_object()->set_dex(8);
			this_object()->set_think(8);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="zhenyue"){
			kind_cn = "中立";
			unit = "位";
			this_object()->set_life(160);
			this_object()->set_mofa(40);
			this_object()->set_str(14);
			this_object()->set_dex(3);
			this_object()->set_think(5);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="tianxiang"){
			kind_cn = "中立";
			unit = "位";
			this_object()->set_life(90);
			this_object()->set_mofa(110);
			this_object()->set_str(7);
			this_object()->set_dex(5);
			this_object()->set_think(13);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="lingyi"){
			kind_cn = "中立";
			unit = "位";
			this_object()->set_life(110);
			this_object()->set_mofa(140);
			this_object()->set_str(6);
			this_object()->set_dex(6);
			this_object()->set_think(14);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="zhaoming"){
			// S1 隐藏职业“照命”：五条职业历程汇于一身，但不覆盖
			// 既有十二职业的核心数值公式。以均衡攻防和较高生存为特色。
			kind_cn = "中立";
			unit = "位";
			this_object()->set_life(145);
			this_object()->set_mofa(115);
			this_object()->set_str(11);
			this_object()->set_dex(11);
			this_object()->set_think(11);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="wuxiang"){
			// 无相：隐藏全职业。85% 专精均值，三系对称成长；解锁条件见 gamelib/d/init。
			// 「无相心法」被动让最高属性的一半继续贡献其他属性，但不参与装备/技能前置。
			object|zero wx_pao;
			object|zero wx_jian;
			kind_cn = "中立";
			unit = "位";
			this_object()->set_life(120);
			this_object()->set_mofa(80);
			this_object()->set_str(8);
			this_object()->set_dex(8);
			this_object()->set_think(8);
			this_object()->set_lunck(0);
			// 初始装备：无相袍 + 无相剑。平庸属性，1 级可穿。
			// 不在 setup 阶段直接 wear/wield，避免装备限制异常中断 setup。
			// 物品 move 到背包即可，玩家用 auto_equip 后续穿。
			catch { wx_pao = new(ROOT+"/gamelib/clone/item/armor/wuxiangpao/wuxiangpao"); };
			if(wx_pao)
				catch { wx_pao->move(this_object()); };
			catch { wx_jian = new(ROOT+"/gamelib/clone/item/weapon/wuxiangjian/wuxiangjian"); };
			if(wx_jian)
				catch { wx_jian->move(this_object()); };
		}
		else if(pid&&pid=="taiji"){
			// 太极：无相之上的最高隐藏职业。比无相综合实力强 30%。
			// 「太极心法」被动让最高项的 65% 加成另外两系（vs 无相 50%）；
			// 「太极生生不息」被动复活：致命伤恢复 30% 生命，5 分钟冷却，PVP 可触发；
			// 「太极复阴」主动复活同房同队鬼魂队友：恢复 50% 生命，独立 5 分钟冷却。
			object|zero tj_pao;
			object|zero tj_jian;
			kind_cn = "中立";
			unit = "位";
			// 30% > 无相：life 156/mofa 104/三系各 10（向下取整）。
			this_object()->set_life(156);
			this_object()->set_mofa(104);
			this_object()->set_str(10);
			this_object()->set_dex(10);
			this_object()->set_think(10);
			this_object()->set_lunck(0);
			// 初始装备：太极袍 + 太极剑。平庸属性，1 级可穿，可销毁/可丢弃/可交易。
			catch { tj_pao = new(ROOT+"/gamelib/clone/item/armor/taijipao/taijipao"); };
			if(tj_pao)
				catch { tj_pao->move(this_object()); };
			catch { tj_jian = new(ROOT+"/gamelib/clone/item/weapon/taijijian/taijijian"); };
			if(tj_jian)
				catch { tj_jian->move(this_object()); };
		}
		else if(pid&&pid=="wuji"){
			// 无极：太极之上的终极隐藏职业（照命300+碎玉资格解锁）。
			// 此前 setup_player 缺失该分支导致无极建角后无基础三维。
			kind_cn = "中立";
			unit = "位";
			// 30% > 太极(156/104/10)：life 202/mofa 135/三系各 13。
			this_object()->set_life(202);
			this_object()->set_mofa(135);
			this_object()->set_str(13);
			this_object()->set_dex(13);
			this_object()->set_think(13);
			this_object()->set_lunck(0);
		}
		else if(pid&&pid=="wuxin"){
			// 无心：无极之上的账号终极隐藏职业（无极全难度通关+2万碎玉）。
			// 「无心诀」被动：最高属性 85% 加成另外两系；技能对怪物伤害
			// 翻倍（PVP 回落至无极水准，见 fight.pike wuxin_pvp_adjust）。
			kind_cn = "中立";
			unit = "位";
			// 沿用隐藏链 +30% 惯例 > 无极(202/135/13)：life 262/mofa 175/三系 16。
			this_object()->set_life(262);
			this_object()->set_mofa(175);
			this_object()->set_str(16);
			this_object()->set_dex(16);
			this_object()->set_think(16);
			this_object()->set_lunck(0);
		}
	}
}
//每次调用reconnect将会传回密码字段进行验证
int reconnect(string _passwd){
	return ::reconnect(_passwd);
}

// 山河壁只在施放时所在战场成立，换房不能把队伍临时护盾带走。
int move(mixed dest){
	if(environment(this_object()) && environment(this_object())!=(object)dest &&
	   this_object()->query_buff("team_guard",0)!="none")
		this_object()->clean_buff("team_guard");
	if(environment(this_object()) && environment(this_object())!=(object)dest)
		this_object()->clean_tianxiang_star_marks();
	if(environment(this_object()) && environment(this_object())!=(object)dest)
		this_object()->clean_lingyi_medicine_pacts();
	if(environment(this_object()) && environment(this_object())!=(object)dest)
		this_object()->clear_recent_aoe_battle_report();
	return ::move(dest);
}
void remove(){
	this_object()->clean_buff("team_guard");
	this_object()->clean_tianxiang_star_marks();
	this_object()->clean_lingyi_medicine_pacts();
	this_object()->clear_recent_aoe_battle_report();
	this_object()->update_online_time();
	if(this_object()->sid != "5dwap")
		save();
	foreach(all_inventory(),object ob)
		ob->remove();
	::remove();
}
int is_player(){
	return 1;
}

//为玩家提供了一个1s的心跳，由liaocheng于08/01/20添加                                                             
private void user_heart_beat()
{
	if(this_object()->query_buff("team_guard",0)!="none"){
		// 底层心跳每2秒触发一次；护盾持续值按玩家看到的秒数保存。
		int guard_time = this_object()->query_buff("team_guard",2)-2;
		if(guard_time<=0)
			this_object()->clean_buff("team_guard");
		else
			this_object()->set_buff("team_guard",2,guard_time);
	}
	//将技能的冷却由fight.pike移到这儿，由liaocheng于08/01/08添加
	if(this_object()->f_skills&&sizeof(this_object()->f_skills)){
		foreach(indices(this_object()->f_skills),string index){
			if(index&&sizeof(index)){
				this_object()->f_skills[index]--;
				if(this_object()->f_skills[index]<1)
					m_delete(this_object()->f_skills,index);
			}
		}
	}
	//精力每次心跳+3点（心跳间隔在efuns中为2秒一次，这样也就是2秒加3点精力值，上限100）	
	this_object()->set_jingli(this_object()->query_jingli()+2);
	//if(!this_object()->is("npc"))
	//	this_object()->set_jingli(this_object()->query_jingli()+2);
	
	//技能持续时间
	if(this_object()->query_buff("spec_attack_buff",0) != "none"){
		int time_remain = this_object()->query_buff("spec_attack_buff",2);
		time_remain--;
		if(time_remain <= 0)
			this_object()->clean_buff("spec_attack_buff");
		else
			this_object()->set_buff("spec_attack_buff",2,time_remain);
	}
	if(this_object()->query_buff("70_skill_buff",0) != "none"){
		int time_remain = this_object()->query_buff("70_skill_buff",2);
		time_remain--;
		if(time_remain <= 0){
			//羽士的70技在结束时需要施放三种技能
			if(this_object()->query_buff("70_skill_buff",0) == "lieyanzhuoshao"){
				if(this_object()->in_combat){
					this_object()->perform("yanlongzhou",1);
					this_object()->perform("jiguangshu",1);
					this_object()->perform("bingxuefengbao",1);
				}
			}
			this_object()->clean_buff("70_skill_buff");
		}
		else{
			this_object()->set_buff("70_skill_buff",2,time_remain);
			//剑仙的持续减防御
			if(this_object()->query_buff("70_skill_buff",0) == "fanzhuanyiji"){
				int effect = this_object()->query_buff("70_skill_buff",1);
				effect += 400;
				this_object()->set_buff("70_skill_buff",1,effect);
			}
			//狂妖的70级技能持续效果
			if(this_object()->query_buff("70_skill_buff",0) == "lieshanmengji"){
				int effect = this_object()->query_buff("70_skill_buff",1);
				effect += 3;
				this_object()->set_buff("70_skill_buff",1,effect);
				int life_left = this_object()->get_cur_life();
				life_left -= 200;
				if(life_left < 0)
					life_left = 0;
				this_object()->set_life(life_left);
			}
		}
	}
	//70级的debuff计时
	if(this_object()->query_debuff("70_skill_curse",0) != "none"){
		int time_remain = this_object()->query_debuff("70_skill_curse",2);
		time_remain--;
		if(time_remain <= 0){
			this_object()->clean_debuff("70_skill_curse");
		}
		else{
			this_object()->set_debuff("70_skill_curse",2,time_remain);
		}
	}
}
private string initer=(this_object()->add_heart_beat(user_heart_beat,1),"");
