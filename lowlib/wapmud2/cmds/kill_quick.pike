#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
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
		s +="<div style=\"color:Orange\">"+tmp+"</div>";//name_cn=query_rare_level()+name_cn;</p>\n";
	}
	else{
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
	}
	//////1000元免精力//////
	int szx=me->all_fee;                                                                                                                  

	string name=arg;
	int count;
	int flag = 1;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count,this_player());
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你要攻击什么东西？\n");
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
				s +="<div style=\"color:Orange\">"+stmp+"</div>\n";//name_cn=query_rare_level()+name_cn;</p>\n";
				s += "累计捐赠1000元，解锁0精力快速攻击功能！!\n，捐赠请加qq 1811117272。\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
		}
		if(ob->is("npc")&&ob->_boss){
			string stmp2 ="boss级别的怪物，无法实行快速攻击。";
			s +="<div style=\"color:Orange\">"+stmp2+"</div>\n";//name_cn=query_rare_level()+name_cn;</p>\n";
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
		//int add_jl = 0;
		//if(ob->is("npc")&&ob->_meritocrat)
		//	add_jl = 3;//精英耗费更多精力快速战斗
		int add_jl = me->query_level()/10;
		int rdc = random(add_jl)+1;//根据等级加大装备消耗
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
		int ob_defend = ob->query_defend_power();
		//战斗开始，直到双方任何一方生命为0结束
		while(me->get_cur_life()>0&&ob->get_cur_life()>0){
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
			ob->set_life(ob->get_cur_life()-dmg_ob);
			int dmg_me = tmp_ob_atk + random(ob->level) - tmp_me_def;	
			if(dmg_me<=0)
				dmg_me = random(ob->level);
			me->set_life(me->get_cur_life()-dmg_me);
		}
		//得到结果，调用双方的fight _die
		if(me->get_cur_life()<=0){ //玩家死亡
			s += "战斗失败！\n";	
			ob->life=this_object()->life_max;//怪物回满血
			ob->who_fight_npc = "";//首次攻击者
			ob->term_who_fight_npc = "";//首次攻击者队伍标示          
			ob->reset_targets(); //重置仇恨列表
			ob->enemy=0;
			me->fight_die();
			me->enemy=0;
		}
		else if(ob->get_cur_life()<=0){ //怪物死亡
			s += "战斗胜利！\n";	
			ob->fight_die();
			if(ob){
				ob->reset_targets(); //重置仇恨列表
				ob->who_fight_npc = "";//首次攻击者
				ob->term_who_fight_npc = "";//首次攻击者队伍标示          
				ob->enemy=0;
			}
			s+="──────────\n";
			if(me->get_cur_life()<me->life_max*3/10)
				s += "<font style=\"color:red\">生命 "+me->get_cur_life()+"/"+me->life_max+"</font>\n";
			else if(me->get_cur_life()<me->life_max*6/10)
				s += "<font style=\"color:Orange\">生命 "+me->get_cur_life()+"/"+me->life_max+"</font>\n";
			else
				s += "<font style=\"color:Orange\">生命 "+me->get_cur_life()+"/"+me->life_max+"</font>\n";
			s += "法力 "+me->get_cur_mofa()+"/"+me->mofa_max+"\n";
			s += "精力 "+me->query_jingli()+"\n"; 
			s+="──────────\n";
		}
		if(me->query_jingli()>10)
			s += "[继续:kill_quick "+arg+"]\n";
		s += "[返回:look]\n";
		write(s);
		return 1;
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你要攻击什么？\n");
	return 1;
}
