#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_NPC;
void fight_die()
{
	object env = environment(this_object());
	//werror("============ name of the room type is "+env->query_room_type()+"==============");
	//设置刷新起始时间 
	env->flush_items(this_object());

	string npc_type = this_object()->query_npc_type();
	if(npc_type=="city_keeper"||npc_type=="city_guarder"||npc_type=="city_lord"){
	//攻城中的npc死亡处理，获得荣誉
	//由liaocheng于107/07/30添加
		array(object) killers = this_object()->get_all_targets();
		if(killers == 0)
			return;
		string h_type = "仙气";
		if(this_object()->query_raceId()=="human")
			h_type = "妖气";
		int honer_get = 0;
		object suipian;
		if(npc_type=="city_keeper"){
			honer_get = 100;
			if(this_object()->query_level()==73){
				int ran = random(100);
				if(ran<2){
					suipian = clone(ITEM_PATH+"bossdrop/bingfusuipian");
				}
			}
		}
		else if(npc_type=="city_guarder"){
			honer_get = 50;
			if(this_object()->query_level()==73){
				int ran = random(100);
				if(ran<2){
					suipian = clone(ITEM_PATH+"bossdrop/bingfusuipian");
				}
			}
		}
		else{
			honer_get = 150;
			if(this_object()->query_level()==73){
				suipian = clone(ITEM_PATH+"bossdrop/bingfusuipian");
				suipian->amount = 2;
			}
		}
		foreach(killers,object killer){
			if(killer && objectp(killer)){
				//加入特药的荣誉加成，由liaocheng于07/11/21添加                 
				//int te_honer = (int)killer->query_buff("te_honer",1);           
				int te_honer = (int)killer->query_buff("te_honer",1)+(int)killer->query_buff("attri_honer",1);           
				int honer_get_tmp = honer_get;
				if(te_honer){
					honer_get_tmp = honer_get+honer_get*te_honer/100; 
				}
				string s_tell = this_object()->query_name_cn()+"被杀死\n你获得了"+honer_get_tmp+"点"+h_type+"。\n";
				if(suipian){
					s_tell += "掉落了 "+suipian->query_short()+" ！\n";
				}
				killer->honerpt+=honer_get_tmp;
				killer->honerlv = WAP_HONERD->flush_honer_level(killer->honerpt,killer->honerlv);
				tell_object(killer,s_tell);
			}
		}
		if(suipian){
			suipian->move(environment(this_object()));
			call_out(suipian->remove,5*60,1);
		}
		//城战情况通告
		if(env){
			string city_name = env->query_belong_to();
			string city_name_cn = "";
			string race = "monst";
			string race_cn = "妖魔";
			//city_name_cn = CITYD->query_city_namecn(city_name);
			if(city_name=="xiqicheng")
				city_name_cn = "西岐城";
			else if(city_name=="chaogecheng")
				city_name_cn = "朝歌城";
			else if(city_name=="tianyecheng")
				city_name_cn = "天野城";
			else if(city_name=="klshuanjing")
				city_name_cn = "玉虚宫幻境";
			else if(city_name=="jadhuanjing")
				city_name_cn = "金鳌岛幻境";
			if(CITYD->query_captured(city_name)=="monst"){
				race = "human";
				race_cn = "人类";
			}
			string notice = "";
			if(this_object()->query_npc_type()=="city_keeper"){
				notice = "战况！"+city_name_cn+"，"+env->query_name_cn()+"被"+race_cn+"攻破！\n";
			}
			else if(this_object()->query_npc_type()=="city_lord"){
				notice = "战况！"+city_name_cn+"被"+race_cn+"占领！\n";
				if((city_name=="chaogecheng"&&race=="human")||(city_name=="xiqicheng"&&race=="monst")||(city_name=="klshuanjing"&&race=="monst")||(city_name=="jadhuanjing"&&race=="human")){
					notice += "3日内若未被夺回，城池将自动归还\n";          
					CITYD->set_giveback_time(city_name); 
					CITYD->give_back_city(city_name,race);
				}
				//本方阵营夺回，则取消自动归还 
				else{
					CITYD->clean_giveback_time(city_name);
				}
				CITYD->capture_city(city_name,race,notice);
				return;
			}
			else if(this_object()->query_npc_type()=="city_guarder"){
				notice = "战况！"+city_name_cn+"，"+env->query_name_cn()+"遭到"+race_cn+"的攻击！\n";
			}
			CITYD->notice_update(notice);
		}
		_clean_fight();
		if(this_object()->is_npc())
			this_object()->remove();
		return;
	}

	//正常的死亡路程
	string term_who = "";
	string t_w = "";	
	//判断是否团队杀死怪物 2007/3/20 add by calvin/////////////////////////
	int term_flag = 0;
	term_who += this_object()->term_who_fight_npc;
	TERMD->flush_term(term_who); 
	//判断团队是否还在内存中
	if(TERMD->query_termId(term_who))
		term_flag = 1;
	else
		term_flag = 0;
	if(term_flag){
		//获得团队内存mapping指针
		mapping(string:array) map_term = ([]);
		map_term = (mapping)TERMD->query_term_m(term_who);
		//如果队伍已经解散，直接返回，给玩家个提示，下面的流程就不走了
		if(map_term&&sizeof(map_term))
			;
		else{
			//fight_die_single();//团队突然解散，谁也不给	
			return;
		}
		//是团队杀死怪物,按照公式分配金钱，经验，物品/////////////////////////

		//先团队公告，杀死了某怪物
		if(enemy&&!enemy->is("npc"))
			t_w+=enemy->query_name_cn()+" 杀死了"+this_object()->query_name_cn()+"\n"; 
		else
			t_w += "杀死了"+this_object()->query_name_cn()+"\n";
		//如果是大boss，可以给大boss随即添一些死掉时候说的话，更有戏剧性

		//1.经验分配///////////////////////////////////////////////
		//首先得到根据队伍人数得到的经验值加成
		int exp_gain = 0;
		int npclevel = this_object()->query_level();//npc等级
		//首先，得到该挂掉的npc所应该获得的固定经验值
		//杀死npc得到的经验>=10：(100+(npcLevel-9)*5)    
		//如果是1-9级的怪：(20+(npcLevel-1)*10)
		int npc_exp = 0;//npc本身掉落的经验值
		if(npclevel<10)
			npc_exp = 20+(npclevel-1)*15;
		else
			npc_exp = 100+(npclevel-9)*5;
		if(npc_exp<=0)
			npc_exp = 1;
		exp_gain = npc_exp;
		if(exp_gain>0){
			if(map_term&&sizeof(map_term)){
				int t_count = 0;//sizeof(map_term);
				foreach(indices(map_term),string uid){
					object termer = find_player(uid);
					if(termer){
						//判断是否一个房间，一个房间可以分配
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							t_count++;
					}
				}
				if(t_count<=0)
					t_count = 1;
				//得到真正经验值，应该和房间队员人数挂钩
				switch(t_count){
					case 2:
						exp_gain = exp_gain*6/5;
						break;
					case 3:
						exp_gain = exp_gain*7/5;
						break;
					case 4:
						exp_gain = exp_gain*8/5;
						break;
					case 5:
						exp_gain = exp_gain*2;
						break;
				}
				//每个人应得到初始经验值为 经验值/队伍人数
				int fact_exp = exp_gain/t_count;
				if(fact_exp<=0)
					fact_exp = 1;
				foreach(indices(map_term),string uid){
					int flag = 0;
					object termer = find_player(uid);
					int last_exp = 0;
					if(termer){
						//判断是否一个房间，一个房间可以分配
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							flag = 1;
						if(flag){

							//根据玩家等级获得计算后的应得经验值
							//如果玩家等级大于该npc等级的获得计算
							int diff = termer->query_level() - npclevel;
							if(diff>=0){
								if(diff>=10)
									diff = 10;
								last_exp = fact_exp - fact_exp*diff/10;
							}
							//如果玩家等级低于该npc等级，需要计算等级差
							else{
								//怪高于玩家等级的情况
								int diff1 = npclevel - termer->query_level();
								//怪比玩家高3级，也是直接获得均分的经验值
								if(diff1<=3)
									last_exp = fact_exp;
								else if(diff1<=4)//怪高4级，获得70%
									last_exp = fact_exp*7/10;
								else if(diff1<=5)//怪高5级，获得40%	
									last_exp = fact_exp*4/10;
								else if(diff1<=6)//怪高6级，获得10%	
									last_exp = fact_exp/10;
								else//怪高过玩家6级以上
									last_exp = random(10)+1;//不能一点不得经验，随即给10点经验
							}
							//这里添加经验特药的加成，由liaocheng于07/11/21添加
							//int te_eff = (int)termer->query_buff("te_exp",1);
							int te_eff = (int)termer->query_buff("te_exp",1)+(int)termer->query_buff("attri_exp",1);
							if(te_eff){
								last_exp = last_exp+last_exp*te_eff/100;
							}
							///////////////////////////////////////////////////////////////////////////////////////
							exp_gain = last_exp;
							//大于20级，必须付费
							
							int melevel = termer->query_level();//player等级
							/*
							if(melevel>=21){
								if(termer->all_fee>=20)
									;
								else{
									string tipsvip = "";
									tipsvip += "等级超过20级，累计捐赠20元，才可以继续获得经验值\n";
									tell_object(termer,tipsvip);
									exp_gain = 0;
								}
							}*/
							if(melevel>=120){
								string tipsvip = "";
								tipsvip += "您的等级已经满级了，获取经验为0，赶紧去做其他任务吧\n";
								tell_object(termer,tipsvip);
								exp_gain = 0;								
							}
							int szx=0;                                                                                                                  
							string bs_tips = "";
							int extra_dh=0;
							
							if(termer->all_fee>=200){
								szx = termer->all_fee;
								if(szx>=200 && szx<400){
									extra_dh += exp_gain*2;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：2倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=400 && szx<600){
									extra_dh += exp_gain*3;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：3倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=600 && szx<800){
									extra_dh += exp_gain*4;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：4倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=800 && szx<1000){
									extra_dh += exp_gain*5;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：5倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=1000 && szx<1200){
									extra_dh += exp_gain*6;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：6倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=1200 && szx<1400){
									extra_dh += exp_gain*8;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：8倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=1400 && szx<1600){
									extra_dh += exp_gain*10;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：10倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=1600 && szx<3200){
									extra_dh += exp_gain*20;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：20倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=3200 && szx<6400){
									extra_dh += exp_gain*30;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：30倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=6400 && szx<12800){
									extra_dh += exp_gain*40;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：40倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
								if(szx>=12800){
									extra_dh += exp_gain*50;
									bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：50倍，额外获得 "+extra_dh+" 点经验值</font>";	
								}
							}
							extra_dh += exp_gain*2;
							bs_tips += "<font style=\"color:DARKORANGE\">五一节经验双倍活动，经验倍速开启：2倍，额外获得 "+extra_dh+" 点经验值</font>";	
							if(exp_gain>0){
								exp_gain += extra_dh;
								termer->exp += exp_gain;
								termer->current_exp += exp_gain;
								string t = "";
								if(bs_tips&&sizeof(bs_tips))
									t + "你得到了 "+exp_gain+" 点经验。\n（"+bs_tips+")\n";
								else
									t + "你得到了 "+exp_gain+" 点经验。\n";
								termer->query_if_levelup();
								if(termer->query_levelFlag())
									t += "你的等级提升到了 "+termer->query_level()+" 级！\n";	
								tell_object(termer,t);
							}
							///////////////////////////////////////////////////////////////////////////////////////
							/*	
							termer->exp += last_exp;
							termer->current_exp += last_exp;
							string strt = "得到了 "+last_exp+" 点经验。\n";
							termer->query_if_levelup();
							if(termer->query_levelFlag())
								strt += "你的等级提升到了 "+termer->query_level()+" 级！\n";	
							tell_object(termer,strt);
							*/	
						}
					}
				}
			}
		}

		//2.金钱分配///////////////////////////////////////////
		if(random(100)<=80){
			int m_low = this_object()->query_level()*10-(int)(this_object()->query_level());
			int m_high = this_object()->query_level()*10+(int)(this_object()->query_level());
			int g_m = m_low + random(m_high-m_low+1);
			//金钱掉落数量不变，然后平均分配给每个打怪的队员
			if(map_term&&sizeof(map_term)){
				//如果只有一个人打，就把钱给那个打怪的队员了
				//1.先得到当前打这个怪的队员人数
				int t_count = 0;//sizeof(map_term);
				foreach(indices(map_term),string uid){
					object termer = find_player(uid);
					if(termer){
						//判断是否一个房间，一个房间可以分配
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							t_count++;
					}
				}
				if(t_count<=0)
					t_count = 1;
				//钱太多，调整为原来的一半，20070322 by calvin
				//又修改为除以5
				int t_money = (g_m/t_count)/5;
				if(t_money<=0)
					t_money = 1;
				//给钱给房间的队员	
				foreach(indices(map_term),string uid){
					int flag = 0;
					object termer = find_player(uid);
					if(termer){
						//判断是否一个房间，一个房间可以分配
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							flag = 1;
					}
					if(flag){//玩家在同一房间中
						termer->add_account(t_money);
						tell_object(termer,"你分到了 "+MUD_MONEYD->query_other_money_cn(t_money)+" ！\n");
					}
				}
			}
		}

		//3.物品分配，设置为队伍拾取
		int pro_add = 0;
		if(this_object()->_boss){
			//boss掉落////////////////////////////////////////////////////////
			//玩家100%获取的boss特殊物品，如霸王魔窟boss的霸王徽记
			//由liaocheng于07/12/11添加
			string get_specitem = BOSSDROPD->get_bossdrop_specitem(this_object()->query_name());
			if(get_specitem != ""){
				object specitem_ob;				
				foreach(indices(map_term),string uid){
					object termer = find_player(uid);
					if(termer){						
						if(environment(this_object())->query_name() == (environment(termer))->query_name()){
							mixed err = catch{
								specitem_ob = clone(ITEM_PATH+get_specitem);
							};
							if(!err && specitem_ob){
								tell_object(termer,"你获得了"+specitem_ob->query_short()+"\n");
								specitem_ob->move_player(termer->query_name());
							}
							else
								Stdio.append_file(ROOT+"/log/bossdrop_error.log",ITEM_PATH+get_specitem+"\n");
						}
					}
				}
			}
			//掉落装备
			int count = this_object()->_boss;
			for(int i = 0;i<count;i++){
			//string drop_item = BOSSDROPD->get_bossdrop_item(this_object()->query_name());
			//获取当前boss的可掉落物品的文件名字，这里我修改了一下，增加了一个level，就是原始文件是50级，但boss被动态刷新成70级，则生成的装备就是70
			string drop_item = BOSSDROPD->get_bossdrop_item_level(this_object()->query_name(),this_object()->query_level());
			if(drop_item ==""){
				//如果没有获得搞等级的动态装备，则直接掉落置顶的非动态的装备
				drop_item = BOSSDROPD->get_bossdrop_item(this_object()->query_name());
			}
			if(drop_item != ""){
				object item_ob;
				mixed catchResult = catch {
					item_ob = clone(ITEM_PATH+drop_item);
				};
				if(catchResult){
					item_ob = 0;
					Stdio.append_file(ROOT+"/log/bossdrop_error.log",ITEM_PATH+drop_item+"\n");
				}
				if(item_ob){
					TERMD->add_termItems(term_who,item_ob);
					t_w += "掉落了 "+item_ob->query_name_cn()+",已放入队伍仓库!\n";	
				}
			}
			}
			//记录野外boss死亡时间 add by caijie 0805221
			if(this_object()->_boss == 3) YWBOSS_FLUSHD->get_boss_die_time(this_object()->query_name());
			//掉落材料配方等其他物品
			if(random(100)<10){
				string drop_other = BOSSDROPD->get_bossdrop_other(this_object()->query_name());
				if(drop_other != ""){
					object other_ob;
					mixed catchResult = catch {
						other_ob = clone(ITEM_PATH+drop_other);
					};
					if(catchResult){
						other_ob = 0;
						Stdio.append_file(ROOT+"/log/bossdrop_error.log",ITEM_PATH+drop_other+"\n");
					}
					if(other_ob){
						TERMD->add_termItems(term_who,other_ob);
						t_w += "掉落了 "+other_ob->query_name_cn()+",已放入队伍仓库!\n";	
					}
				}
			}
			//团队杀怪时，这里需要注意团队内队员的任务状态的处理
			//是否此怪与杀戮任务有联系,于2007/3/14由liaocheng添加
			//团队杀怪碰到任务时候，如果是简单任务，只掉落一次
			//如果是精英或者boss任务，需要每个有这个任务标示的人
			//都能得到一个任务物品
			if(map_term&&sizeof(map_term)){
				foreach(indices(map_term),string uid){
					int flag = 0;
					object termer = find_player(uid);
					if(termer){
						//判断是否一个房间，一个房间可以分配
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							flag = 1;
					}
					if(flag){ //玩家在同一房间中
						//是否此怪与杀戮任务有联系,于2007/3/14由liaocheng添加
						//没有接口判断每个人的一般任务是否相同，所以，暂时这里
						//就给每个有任务的人掉落任务物品
						TASKD->if_in_killTask(termer,this_object()->query_name_cn());
						object ob_task = TASKD->if_in_findTask(termer,this_object()->query_name_cn());
						if(ob_task){
							t_w += termer->query_name_cn()+" 得到了 "+ob_task->query_short()+" ！\n";
							if(ob_task->is("combine_item"))
								ob_task->move_player(termer->query_name());
							else
								ob_task->move(termer);
						}
					}
				}
			}
		}
		////////////////////////////////////////////////////////////////////////
		else{
			//新副业织布，制皮材料的掉落
			//由liaocheng于07/10/17添加
			if(VICEDROPD->can_vicedrop(this_object()->query_name())==1){
				//100%掉落普通材料
				string normal_name = VICEDROPD->get_vicedrop_item(this_object()->query_name());
				object normal_ob;
				if(normal_name != ""){
					mixed err = catch{
						normal_ob = clone(ITEM_PATH+"material/"+normal_name);
					};
					if(!normal_ob || err){
						normal_ob = 0;
					}
					if(normal_ob){
						normal_ob->amount = VICEDROPD->get_drop_nums();
						normal_ob->item_whoCanGet = term_who;
						normal_ob->item_TimewhoCanGet = time();
						t_w += "掉落了 "+normal_ob->query_short()+" ！\n";
						call_out(normal_ob->remove,5*60,1);
						normal_ob->move(environment(this_object()));
					}
				}
				//有一定几率掉落特殊材料
				int vice_prob = 100;
				if(random(10000)<vice_prob){
					string spec_name = VICEDROPD->get_vicedrop_spec(this_object()->query_name());
					object spec_ob;
					if(spec_name != ""){
						mixed err = catch{
							spec_ob = clone(ITEM_PATH+"material/"+spec_name);
						};
						if(!spec_ob || err){
							spec_ob = 0;
						}
						if(spec_ob){
							spec_ob->item_whoCanGet = term_who;
							spec_ob->item_TimewhoCanGet = time();
							t_w += "掉落了 "+spec_ob->query_short()+" ！\n";
							call_out(spec_ob->remove,5*60,1);
							spec_ob->move(environment(this_object()));
						}
					}
				}
				VICEFLUSHD->set_flush_num(this_object()->query_name());

			}
			///////////////////////////////////////////////////////////////////////
			//掉落普通装备
			if(this_object()->_meritocrat)
				pro_add = 100;   //精英加成50 luck

			//evan added 2008-04-24
			string room_type = env->query_room_type();
			if(room_type && room_type == "rookie")
				pro_add = 3000;  //新手村的怪，有一定的幸运加成  
			//end of evan add 2008-04-24
			
			object ob = ITEMSD->get_item(this_object()->query_level(), 0, pro_add);
			//掉落特殊物品
			object ob_spec = ITEMSD->get_spec_item(this_object()->query_level(), 0, pro_add);
			//掉落宝石 added by caijie 080807
			object ob_shi = ITEMSD->get_worlddrop_item(this_object()->query_level(),1);
			//节日特殊掉落
			//由liaocheng于07/09/24添加
			object ob_holiday_spec = ITEMSD->get_spec_item_for_holiday(this_object()->query_level());
			if(ob && environment(this_object())){
				//加入掉装保护属性字段
				//这里需要将团队拾取标示加上
				//Stdio.append_file(ROOT+"/log/item_drop.log",now[0..sizeof(now)-2]+":team:"+ob->query_name_cn()+"("+ob->query_name()+")\n");
				ob->item_whoCanGet = term_who;
				ob->item_TimewhoCanGet = time();
				t_w += "掉落了 "+ob->query_short()+" ！\n";
				call_out(ob->remove,5*60,1);
				ob->move(environment(this_object()));
			}
			if(ob_spec&& environment(this_object())){
				//Stdio.append_file(ROOT+"/log/item_spec_drop.log",now[0..sizeof(now)-2]+":team:"+ob_spec->query_name_cn()+"("+ob_spec->query_name()+")\n");
				ob_spec->item_whoCanGet = term_who;
				ob_spec->item_TimewhoCanGet = time();
				t_w += "掉落了 "+ob_spec->query_short()+" ！\n";
				call_out(ob_spec->remove,5*60,1);
				ob_spec->move(environment(this_object()));
			}
			if(ob_holiday_spec&& environment(this_object())){
				ob_holiday_spec->item_whoCanGet = term_who;
				ob_holiday_spec->item_TimewhoCanGet = time();
				t_w += "掉落了 "+ob_holiday_spec->query_short()+" ！\n";
				call_out(ob_holiday_spec->remove,5*60,1);
				ob_holiday_spec->move(environment(this_object()));
			}
			if(ob_shi&& environment(this_object())){
				ob_shi->item_whoCanGet = term_who;
				ob_shi->item_TimewhoCanGet = time();
				t_w += "掉落了 "+ob_shi->query_short()+" ！\n";
				call_out(ob_shi->remove,5*60,1);
				ob_shi->move(environment(this_object()));
			}
			////比较麻烦的地方////////////////////////////////////////
			//团队杀怪时，这里需要注意团队内队员的任务状态的处理
			//是否此怪与杀戮任务有联系,于2007/3/14由liaocheng添加
			//团队杀怪碰到任务时候，如果是简单任务，只掉落一次
			//如果是精英或者boss任务，需要每个有这个任务标示的人
			//都能得到一个任务物品
			if(map_term&&sizeof(map_term)){
				foreach(indices(map_term),string uid){
					int flag = 0;
					object termer = find_player(uid);
					if(termer){
						//判断是否一个房间，一个房间可以分配
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							flag = 1;
					}
					if(flag){ //玩家在同一房间中
						//是否此怪与杀戮任务有联系,于2007/3/14由liaocheng添加
						//没有接口判断每个人的一般任务是否相同，所以，暂时这里
						//就给每个有任务的人掉落任务物品
						TASKD->if_in_killTask(termer,this_object()->query_name_cn());
						object ob_task = TASKD->if_in_findTask(termer,this_object()->query_name_cn());
						if(ob_task && environment(termer)){
							t_w += termer->query_name_cn()+" 得到了 "+ob_task->query_short()+" ！\n";
							if(ob_task->is("combine_item"))
								ob_task->move_player(termer->query_name());
							else
								ob_task->move(termer);
						}
					}
				}
			}
		}
		//团队公告掉落物品
		TERMD->term_tell(term_who,t_w);
		//怪死亡处理
		_clean_fight();
		if(this_object()->is_npc())
			this_object()->remove();
	}
	else
		fight_die_single(env);//非团队杀死怪的处理接口	
}
//个人杀死怪的判断接口
void fight_die_single(object env)
{
	int npcflag = 0;
	if(enemy&&!enemy->is("npc")){
		tell_object(enemy,"你杀死了"+this_object()->query_name_cn()+"\n");
		npcflag = 1;
	}
	//记录野外boss死亡时间 add by caijie 0805221
	if(this_object()->_boss == 3) YWBOSS_FLUSHD->get_boss_die_time(this_object()->query_name());

	//必须是首先攻击者
	int flag = 0;
	object first = find_player(this_object()->who_fight_npc);
	if(first)
		if(this_object()->if_in_targets(first))
			flag = 1;
	//必须是首先攻击者

	if(flag&&npcflag){
		TASKD->if_in_killTask(first,this_object()->query_name_cn());
		//不是团队杀死怪物，是个人杀死/////////////////////////
		int npclevel = this_object()->query_level();//npc等级
		int melevel = first->query_level();//player等级
		//首先，得到该挂掉的npc所应该获得的固定经验值
		//杀死npc得到的经验>=10：(100+(npcLevel-9)*5)    
		//如果是1-9级的怪：(20+(npcLevel-1)*10)
		int exp_gain = 0;
		int npc_exp = 0;//npc本身掉落的经验值
		if(npclevel<10)
			npc_exp = 20+(npclevel-1)*15;
		else
			npc_exp = 100+(npclevel-9)*5;
		//经验值获得算法
		//1.如果我的等级小于等于怪物等级10，经验 = 怪物应该掉落的固定经验
		//2.如果我的等级大于怪物等级：公式如下
		// 怪物经验-怪物经验*(我的级别-怪的级别:大于10就等于10)/10
		//第一种，我的等级小于怪物等级
		if(melevel<npclevel){
			//如果玩家等级低于该npc等级，需要计算等级差
			int last_exp = 0;
			int diff1 = npclevel - melevel;
			//怪比玩家高3级，也是直接获得均分的经验值
			if(diff1<=3)
				last_exp = npc_exp;
			else if(diff1<=4)//怪高4级，获得70%
				last_exp = npc_exp*7/10;
			else if(diff1<=5)//怪高5级，获得40%	
				last_exp = npc_exp*4/10;
			else if(diff1<=6)//怪高6级，获得10%	
				last_exp = npc_exp/10;
			else//怪高过玩家6级以上
				last_exp = random(10);//不能一点不得经验，随即给10点经验
			exp_gain = last_exp;
		}
		else{//玩家高于怪的等级
			int diff = melevel - npclevel;
			if(diff>=10)
				diff = 10;
			int tem_exp = npc_exp - npc_exp*diff/10;
			exp_gain = tem_exp;
		}
		///////////////////////////////////////////////////////////////////////////////////////
		//大于20级，必须付费 目前支持20-100级 等到200级以后得玩家再加
		/*
		if(melevel>=21 && melevel<30){
			if(first->all_fee>=20)
				;
			else{
				string tipsvip = "";
				tipsvip += "等级超过20级，累计捐赠20元，才可以继续获得经验值\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=30 && melevel<50){
			if(first->all_fee>=50)
				;
			else{
				string tipsvip = "";
				tipsvip += "等级超过30级，累计捐赠50元，才可以继续获得经验值\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=50 && melevel<60){
			if(first->all_fee>=100)
				;
			else{
				string tipsvip = "";
				tipsvip += "等级超过50级，累计捐赠100元，才可以继续获得经验值\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=60 && melevel<100){
			if(first->all_fee>=200)
				;
			else{
				string tipsvip = "";
				tipsvip += "等级超过60级，累计捐赠200元，才可以继续获得经验值\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=100  && melevel<120){
			if(first->all_fee>=500)
				;
			else{
				string tipsvip = "";
				tipsvip += "等级超过100级，累计捐赠500元，才可以继续获得经验值\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}
		else
		if(melevel>=120 && melevel<150){
			//等级超过120级封顶，以后有需要再扩充。
			if(first->all_fee>=5000)
				;
			else{
				string tipsvip = "";
				tipsvip += "等级超过120级，累计捐赠5000元，才可以继续获得经验值\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=150 && melevel<200){
			if(first->all_fee>=8000)
				;
			else{
				string tipsvip = "";
				tipsvip += "等级超过150级，累计捐赠8000元，才可以继续获得经验值\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}			
		}else
		if(melevel>=200){
			if(first->all_fee>=16000)
				;
			else{
				string tipsvip = "";
				tipsvip += "等级超过200级，累计捐赠16000元，请联系客服，才可以继续获得经验值\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}			
		}*/
		int szx=0;                                                                                                                  
		string bs_tips = "";
		int extra_dh=0;
		if(first->all_fee>=200){
			szx = first->all_fee;
			if(szx>=200 && szx<400){
				extra_dh += exp_gain*2;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：2倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=400 && szx<600){
				extra_dh += exp_gain*3;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：3倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=600 && szx<800){
				extra_dh += exp_gain*4;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：4倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=800 && szx<1000){
				extra_dh += exp_gain*5;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：5倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=1000 && szx<1200){
				extra_dh += exp_gain*6;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：6倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=1200 && szx<1400){
				extra_dh += exp_gain*8;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：8倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=1400 && szx<1600){
				extra_dh += exp_gain*10;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：10倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=1600 && szx<3200){
				extra_dh += exp_gain*20;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：20倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=3200 && szx<6400){
				extra_dh += exp_gain*30;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：30倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=6400 && szx<12800){
				extra_dh += exp_gain*40;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：40倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
			if(szx>=12800){
				extra_dh += exp_gain*50;
				bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：50倍，额外获得 "+extra_dh+" 点经验值</font>";	
			}
		}
		extra_dh += exp_gain*2;
		bs_tips += "<br><font style=\"color:DARKORANGE\">五一节经验双倍活动，经验倍速开启：2倍，额外获得 "+extra_dh+" 点经验值</font>";	
		if(exp_gain>0){
			//这里添加经验特药的加成，由liaocheng于07/11/21添加
			//int te_eff = (int)first->query_buff("te_exp",1);
			int te_eff = (int)first->query_buff("te_exp",1)+(int)first->query_buff("attri_exp",1);
			if(te_eff){
				exp_gain = exp_gain+exp_gain*te_eff/100;
			}
			exp_gain += extra_dh;
			first->exp += exp_gain;
			first->current_exp += exp_gain;
			string t = "";
			if(bs_tips&&sizeof(bs_tips))
				t += "你得到了 "+exp_gain+" 点经验。\n（"+bs_tips+")\n";
			else
				t += "你得到了 "+exp_gain+" 点经验。\n";
			first->query_if_levelup();
			if(first->query_levelFlag())
				t += "你的等级提升到了 "+first->query_level()+" 级！\n";	
			tell_object(first,t);
		}
		///////////////////////////////////////////////////////////////////////////////////////
		//直接这个地方掉落物品算法
		//新副业织布，制皮材料的掉落
		//由liaocheng于07/10/17添加
		if(VICEDROPD->can_vicedrop(this_object()->query_name())==1){
			//100%掉落普通材料
			string t = "";
			string normal_name = VICEDROPD->get_vicedrop_item(this_object()->query_name());
			object normal_ob;
			if(normal_name != ""){
				mixed err = catch{
					normal_ob = clone(ITEM_PATH+"material/"+normal_name);
				};
				if(!normal_ob || err){
					normal_ob = 0;
				}
				if(normal_ob){
					normal_ob->amount = VICEDROPD->get_drop_nums();
					normal_ob->item_whoCanGet = first->query_name();;
					normal_ob->item_TimewhoCanGet = time();
					t += "掉落了 "+normal_ob->query_short()+" ！\n";
					call_out(normal_ob->remove,5*60,1);
					normal_ob->move(environment(this_object()));
				}
			}
			//有一定几率掉落特殊材料
			int vice_prob = 100;
			if(random(10000)<vice_prob){
				string spec_name = VICEDROPD->get_vicedrop_spec(this_object()->query_name());
				object spec_ob;
				if(spec_name != ""){
					mixed err = catch{
						spec_ob = clone(ITEM_PATH+"material/"+spec_name);
					};
					if(!spec_ob || err){
						spec_ob = 0;
					}
					if(spec_ob){
						spec_ob->item_whoCanGet = first->query_name();
						spec_ob->item_TimewhoCanGet = time();
						t += "掉落了 "+spec_ob->query_short()+" ！\n";
						call_out(spec_ob->remove,5*60,1);
						spec_ob->move(environment(this_object()));
					}
				}
			}
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);

			VICEFLUSHD->set_flush_num(this_object()->query_name());
		}
		///////////////////////////////////////////////////////////////////////
		//掉落普通装备
		//boss怪和精英怪掉落有加成
		int pro_add = 0;
		if(this_object()->_boss) 
			pro_add = 300;    //boss加成300 luck
		else if(this_object()->_meritocrat)
			pro_add = 50;   //精英加成50 luck

		//evan added 2008-04-24
		string room_type = env->query_room_type();
		if(room_type && room_type == "rookie")
			pro_add = 3000; //新手村的怪，都有一定的幸运加成。
		//end of evan added 2008-04-24
		object ob = ITEMSD->get_item(this_object()->query_level(), first->query_level(), first->query_lunck()+pro_add);
		//掉落特殊物品
		object ob_spec = ITEMSD->get_spec_item(this_object()->query_level(), first->query_level(), first->query_lunck()+pro_add);
		//掉落宝石 caijie 080807
		object ob_shi = ITEMSD->get_worlddrop_item(this_object()->query_level(),first->query_level());
		//end cai 080807

		//节日特殊掉落
		//由liaocheng于07/09/24添加
		object ob_holiday_spec = ITEMSD->get_spec_item_for_holiday(this_object()->query_level());
		//掉落任务物品,2007/3/14由liaocheng添加
		object ob_task = TASKD->if_in_findTask(first,this_object()->query_name_cn());
		if(ob && environment(this_object())){
			//Stdio.append_file(ROOT+"/log/item_drop.log",now[0..sizeof(now)-2]+":"+first->query_name_cn()+"("+first->query_name()+"):"+ob->query_name_cn()+"("+ob->query_name()+")\n");
			string t = "";
			//加入掉装保护属性字段
			//用于掉装保护 2007-0302 by calvin
			ob->item_whoCanGet = first->query_name();
			ob->item_TimewhoCanGet = time();
			t += "掉落了 "+ob->query_short()+" ！\n";	
			//t += "物品掉落标示="+ob->item_whoCanGet+"\n";
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);
			call_out(ob->remove,5*60,1);
			ob->move(environment(this_object()));
		}
		if(ob_shi && environment(this_object())){
			//Stdio.append_file(ROOT+"/log/item_drop.log",now[0..sizeof(now)-2]+":"+first->query_name_cn()+"("+first->query_name()+"):"+ob->query_name_cn()+"("+ob->query_name()+")\n");
			string t = "";
			//加入掉装保护属性字段
			//用于掉装保护 2007-0302 by calvin
			ob_shi->item_whoCanGet = first->query_name();
			ob_shi->item_TimewhoCanGet = time();
			t += "掉落了 "+ob_shi->query_short()+" ！\n";	
			//t += "物品掉落标示="+ob->item_whoCanGet+"\n";
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);
			call_out(ob_shi->remove,5*60,1);
			ob_shi->move(environment(this_object()));
		}
		if(ob_spec&& environment(this_object())){
			//Stdio.append_file(ROOT+"/log/item_spec_drop.log",now[0..sizeof(now)-2]+":"+first->query_name_cn()+"("+first->query_name()+"):"+ob_spec->query_name_cn()+"("+ob_spec->query_name()+")\n");
			string t = "";
			//加入掉装保护属性字段
			//用于掉装保护 2007-0302 by calvin
			ob_spec->item_whoCanGet = first->query_name();
			ob_spec->item_TimewhoCanGet = time();
			t += "掉落了 "+ob_spec->query_short()+" ！\n";
			//t += "物品掉落标示="+ob_spec->item_whoCanGet+"\n";
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);
			call_out(ob_spec->remove,5*60,1);
			ob_spec->move(environment(this_object()));
		}
		if(ob_holiday_spec&& environment(this_object())){
			string t = "";
			ob_holiday_spec->item_whoCanGet = first->query_name();
			ob_holiday_spec->item_TimewhoCanGet = time();
			t += "掉落了 "+ob_holiday_spec->query_short()+" ！\n";
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);
			call_out(ob_holiday_spec->remove,5*60,1);
			ob_holiday_spec->move(environment(this_object()));
		}
		if(ob_task && environment(this_object())){
			string t = "";
			//加入掉装保护属性字段
			//用于掉装保护 2007-0302 by calvin
			//ob_task->item_whoCanGet = first->query_name();
			//ob_task->item_TimewhoCanGet = time();
			t += " 你得到了 "+ob_task->query_short()+" ！\n";
			//foreach(indices(this_object()->targets),object who)	
			//	tell_object(who,t);
			tell_object(first,t);
			//call_out(ob_task->remove,5*60,1);
			//ob_task->move(environment(this_object()));
			if(ob_task->is("combine_item"))
				ob_task->move_player(first->query_name());
			else
				ob_task->move(first);
		}
		if(random(100)<=80){
			int m_low = this_object()->query_level()*10-(int)(this_object()->query_level());
			int m_high = this_object()->query_level()*10+(int)(this_object()->query_level());
			int g_m = m_low + random(m_high-m_low+1);
			//钱太多，调整为原来的一半，20070322 by calvin
			//又调整为除以5
			g_m = g_m/5;
			if(g_m<=0)
				g_m = 1;
			int flag = 0;
			first->add_account(g_m);
			tell_object(first,"你得到了 "+MUD_MONEYD->query_other_money_cn(g_m)+" ！\n");
		}
		//怪物死亡处理
		_clean_fight();
		if(this_object()->is_npc())
			this_object()->remove();
	}
	else{
		_clean_fight();
		if(this_object()->is_npc())
			this_object()->remove();
	}
}
string query_words(){
	return ::query_words();
}
string query_npc_links(void|int count)
{
	string out="";
	if(this_object()->query_raceId()=="human"){
		//该npc是人类阵营
		if(this_player()->query_raceId()=="human")
			out += "[对话:ask_npc "+this_object()->query_name()+" "+count+"]\n";
		else{
			out += "[杀戮:kill "+this_object()->query_name()+" "+count+"]\n";
			//需要判定是否精英/boss类--修正：精英太多，允许快速战斗，但_boss不允许
			if(this_object()->_boss)
				;
			else
				out += "[快速攻击:kill_quick "+this_object()->query_name()+" "+count+"]\n";
		}
		if(this_object()->query_name()=="daodezhenjun400"){
			out += "[学习采矿:viceskill_learn caikuang 0]\n";
			out += "[学习采药:viceskill_learn caiyao 0]\n";
			out += "[学习锻造:viceskill_learn duanzao 0]\n";
			out += "[学习炼丹:viceskill_learn liandan 0]\n";
			out += "[学习裁缝:viceskill_learn caifeng 0]\n";
			out += "[学习制甲:viceskill_learn zhijia 0]\n";
		}
	}
	else if(this_object()->query_raceId()=="monst"){
		//该npc是妖魔阵营
		if(this_player()->query_raceId()=="monst")
			out += "[对话:ask_npc "+this_object()->query_name()+" "+count+"]\n";
		else{
			out += "[杀戮:kill "+this_object()->query_name()+" "+count+"]\n";
			//需要判定是否精英/boss类--修正：精英太多，允许快速战斗，但_boss不允许
			if(this_object()->_boss)
				;
			else
				out += "[快速攻击:kill_quick "+this_object()->query_name()+" "+count+"]\n";
		}
		if(this_object()->query_name()=="zhaogongming400"){
			out += "[学习采矿:viceskill_learn caikuang 0]\n";
			out += "[学习采药:viceskill_learn caiyao 0]\n";
			out += "[学习锻造:viceskill_learn duanzao 0]\n";
			out += "[学习炼丹:viceskill_learn liandan 0]\n";
			out += "[学习裁缝:viceskill_learn caifeng 0]\n";
			out += "[学习制甲:viceskill_learn zhijia 0]\n";
		}
	}
	else if(this_object()->query_raceId()=="third"){
		//该npc是中立阵营
		out += "[对话:ask_npc "+this_object()->query_name()+" "+count+"] ";
		out += "[杀戮:kill "+this_object()->query_name()+" "+count+"]\n";
		//需要判定是否精英/boss类--修正：精英太多，允许快速战斗，但_boss不允许
		if(this_object()->_boss)
			;
		else
			out += "[快速攻击:kill_quick "+this_object()->query_name()+" "+count+"]\n";
		
		//if(this_object()->query_name()=="yuebingshangren100")
		//	out += "[我想看看你的月饼:yuebing_list]\n";
		switch(this_object()->query_name()){
			case "qxhdiqishang400":
				out += "[购买地皮:home_purchase_slot_list qianxuehu]\n";
				out += "[变卖地皮:home_sell_remind]\n";
				out += "[申请店铺许可:home_apply_shopLicense sijiaxiaodian 200]\n";
			break;
			case "ykfdiqishang400":
				out += "[购买地皮:home_purchase_slot_list yukunfeng]\n";
				out += "[变卖地皮:home_sell_remind]\n";
				out += "[申请店铺许可:home_apply_shopLicense sijiaxiaodian 200]\n";
			break;
			case "lycydiqishang400":
				out += "[购买地皮:home_purchase_slot_list lengyuecaoyuan]\n";
				out += "[变卖地皮:home_sell_remind]\n";
				out += "[申请店铺许可:home_apply_shopLicense sijiaxiaodian 200]\n";
			break;
			case "lxddiqishang400":
				out += "[购买地皮:home_purchase_slot_list lingxidi]\n";
				out += "[变卖地皮:home_sell_remind]\n";
				out += "[申请店铺许可:home_apply_shopLicense sijiaxiaodian 200]\n";
			break;

			case "qxhzahuoshang400":
				out += "[购买物品:home_shop_item_list plant]\n";
				out += "[其它杂货:home_buy_else_list plant]\n";
			break;
			case "ykfzahuoshang400":
				out += "[购买物品:home_shop_item_list plant]\n";
				out += "[其它杂货:home_buy_else_list plant]\n";
			break;
			case "lycyzahuoshang400":
				out += "[购买物品:home_shop_item_list plant]\n";
				out += "[其它杂货:home_buy_else_list plant]\n";
			break;
			case "lxdzahuoshang400":
				out += "[购买物品:home_shop_item_list plant]\n";
				out += "[其它杂货:home_buy_else_list plant]\n";
			break;

		}
		if(this_object()->query_profeId()=="dog"&&HOMED->is_master(environment(this_player())->homeId)){
			out += "[喂养:home_dog_feed]\n";
		}
	}
	return out;
}
