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
}
//每次调用reconnect将会传回密码字段进行验证
int reconnect(string _passwd){
	return ::reconnect(_passwd);
}
void remove(){
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
