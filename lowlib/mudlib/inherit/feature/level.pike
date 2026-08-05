#include <globals.h>
#include <mudlib/include/mudlib.h>
#include <gamelib/include/gamelib.h>
//等级
int level;
//等级提示
private int levelFlag=0;
//经验
int exp;
//当前升级所需要的经验，完成了多少
int current_exp;

int query_levelFlag(){
	return levelFlag;
}
//上次等级需要经验值
int query_last_exp(){
	int l_level = query_level();//level-1;
	if(l_level<=0)
		l_level = 1;
	if(l_level==1)
		return 0;
	else
		l_level = l_level - 1;
	float a = (float)l_level;
	float tmp = a/10.00;
	float need = 0.00;
	if(l_level<=10)
		need = a*a*100;
	else
		need = a*a*100*tmp;
	//升级需要经验值翻倍
	int rst = (int)need*2;
	return rst;
	//return (level+1)*(level+1)*(level+1)*100 - level*level*level*100; 
}
//升级所需经验 1-10级:LV*LV*100 10-60级:LV*LV*100*（LV/10）
int query_need_exp(){
	int b_level = query_level();//当前等级
	int t_level = b_level+1;
	if(t_level<=0)
		t_level = 1;
	int rst=0;
	if(b_level>=1&&b_level<9){
		rst = t_level*t_level*100*2;
	}
	else if(b_level==9){
		rst = t_level*t_level*100*2+b_level*b_level*100;
	}
	else if((b_level>=10&&b_level<19)||(b_level>=20&&b_level<29)){
		//rst = t_level*t_level*100*2*(int)(t_level/9);
		rst = t_level*t_level*100*2;//新算法，29级前调简单点，新手入门快
	}
	else if(b_level==19||b_level==29){
		rst = t_level*t_level*100*2*(int)(t_level/9)+b_level*9*100;
	}
	else if((b_level>=30&&b_level<39)||(b_level>=40&&b_level<49)||(b_level>=50&&b_level<59)||(b_level>=60&&b_level<69)){
		rst = t_level*t_level*100*2*(int)(t_level/8.5);
	}
	else if(b_level==39||b_level==49||b_level==59){
		rst = t_level*t_level*100*2*(int)(t_level/8.5)+t_level*20*100;
	}
	else if(b_level>=69 && b_level<99){
		rst = t_level*t_level*100*2*(int)(t_level/8.5)+t_level*t_level*100;
	}else if(b_level>=99){//大于100级则三次方的指数曲线
		rst = t_level*t_level*100*2*(int)(t_level/8.5)+t_level*t_level*t_level*50;
	}
	return rst;
	//return (level+1)*(level+1)*(level+1)*100 - level*level*level*100; 
}
void query_if_levelup(){
	check_level();
}
private void check_level(){
	int level_next = query_need_exp(); 
	int level_limit = VIPD->query_player_level_limit(this_object());
	//int level_last = query_last_exp();
	//werror("\n**************升级计算判断开始*****************\n");
	//werror("\n    当前等级="+query_level()+"        \n");
	//werror("\n    当前总经验="+exp+"        \n");
	//werror("\n    当前显示的经验="+current_exp+"        \n");
	//werror("\n    上一级需要经验="+level_last+"        \n");
	//werror("\n    下一级需要经验="+level_next+"        \n");
	if(level>MAX_LEVEL){
		level = MAX_LEVEL;
		this_object()->set_att_by_level();
		current_exp = 0;
		levelFlag = 0;
		return;
	}
	if(level>=level_limit){
		current_exp = 0;
		levelFlag = 0;
		return;
	}
	if(current_exp>=level_next){
		//werror("\n    升级了！！     \n");
		int tmp = current_exp-level_next;
		//werror("\n    升级后剩余经验="+tmp+"       \n");
		levelFlag = 1;
		if(level==0)
			level = 1;
		level++;

		//每升5级，将会对推荐者进行一次积分加成
		//由liaocheng于07/08/15添加，用于人推人系统
		/*
		if(level <=50 && level%5 == 0){
			mixed err = catch{
				MUD_PRESENTD->flush_mark(this_object());
			};
			if(err)
				;
		}
		*/
		this_object()->set_att_by_level();
		if(functionp(this_object()->query_project) &&
		   this_object()->query_project()=="gamelib"){
			object newbie_daemon =
				(object)(ROOT+
					"/gamelib/single/daemons/newbied");
			if(newbie_daemon &&
			   functionp(newbie_daemon->try_auto_complete))
				newbie_daemon->try_auto_complete(
					this_object());
		}
		//升级后重置当前等级升级到下一级需要的经验为0
		current_exp = tmp;
	}
	else
		levelFlag = 0;
}

//根据玩家升级或降级的后的等级设置玩家的基本属性
void set_att_by_level(){
	int level_now = level - 1;
	//如果升级，根据六个职业不同的基本属性增加一定的值
	if(this_object()->query_profeId()=="jianxian"){//剑仙
		this_object()->set_str(12+(int)(level_now*2.5));
		this_object()->set_dex(6+(int)(level_now*1.5));
		this_object()->set_think(2+(int)(level_now*0.5));
	}
	if(this_object()->query_profeId()=="yushi"){//羽士
		this_object()->set_str(8+level_now);
		this_object()->set_dex(2+(int)(level_now*0.5));
		this_object()->set_think(12+(int)(level_now*3));
	}
	if(this_object()->query_profeId()=="zhuxian"){//诛仙
		this_object()->set_str(10+(int)(level_now*1.5));
		this_object()->set_dex(12+(int)(level_now*2));
		this_object()->set_think(4+level_now);
	}
	if(this_object()->query_profeId()=="kuangyao"){//狂妖
		this_object()->set_str(14+(int)(level_now*3));
		this_object()->set_dex(2+level_now);
		this_object()->set_think(2+(int)(level_now*0.5));
	}
	if(this_object()->query_profeId()=="wuyao"){//巫妖
		this_object()->set_str(8+(int)(level_now*1.5));
		this_object()->set_dex(2+(int)(level_now*0.5));
		this_object()->set_think(10+(int)(level_now*2.5));
	}
	if(this_object()->query_profeId()=="yinggui"){//影鬼
		this_object()->set_str(10+level_now);
		this_object()->set_dex(14+(int)(level_now*2.5));
		this_object()->set_think(3+level_now);
	}
	if(this_object()->query_profeId()=="fangshi"){//方士 - 中立职业，召唤师
		this_object()->set_str(10+(int)(level_now*1.5));
		this_object()->set_dex(5+(int)(level_now*0.8));
		this_object()->set_think(12+(int)(level_now*2));
	}
	if(this_object()->query_profeId()=="zhenyue"){//镇越 - 中立职业，团队坦克
		this_object()->set_str(14+(int)(level_now*2.7));
		this_object()->set_dex(3+(int)(level_now*0.6));
		this_object()->set_think(5+(int)(level_now*0.8));
	}
	if(this_object()->query_profeId()=="tianxiang"){//天象 - 中立职业，星痕法师
		this_object()->set_str(7+(int)(level_now*0.8));
		this_object()->set_dex(5+(int)(level_now*0.8));
		this_object()->set_think(13+(int)(level_now*2.8));
	}
	if(this_object()->query_profeId()=="lingyi"){//灵医 - 中立职业，团队治疗
		this_object()->set_str(6+(int)(level_now*0.7));
		this_object()->set_dex(6+(int)(level_now*0.7));
		this_object()->set_think(14+(int)(level_now*2.5));
	}
	if(this_object()->query_profeId()=="wuxiang"){//无相 - 隐藏全职业，三系对称成长
		// 85% 专精均值：力量/敏捷/智力三系对称，每级 +1.5；保留 8 点起步
		this_object()->set_str(8+(int)(level_now*1.5));
		this_object()->set_dex(8+(int)(level_now*1.5));
		this_object()->set_think(8+(int)(level_now*1.5));
	}
	//升级重置生命和魔法
	this_object()->set_life(this_object()->query_life_max());
	this_object()->set_mofa(this_object()->query_mofa_max());
}

//计算被杀后应该损失的经验
int killed_exp(object enemy){
	int level_next = query_need_exp();
	//被怪杀死
	int drop_exp = 0;//损失的经验
	object me = this_object();
	//被怪杀死损失的经验计算
	if(enemy->is("npc")){
		drop_exp = level_next*20/100;
		//记录被怪杀死的次数
		if(!me->get_once_day["killed_by_npc"]){
			me->get_once_day["killed_by_npc"] = 1;
		}
		else {
			me->get_once_day["killed_by_npc"]++;
		}
		//根据被怪击杀的次数计算损失的经验
		int killed_num = me->get_once_day["killed_by_npc"];
		if(killed_num ==1)
			drop_exp = drop_exp*100/100;
		else if (killed_num==2){
			drop_exp = drop_exp*75/100;
		}
		else if(killed_num==3){
			drop_exp = drop_exp*50/100;
		}
		else if(killed_num==4){
			drop_exp = drop_exp*25/100;
		}
		else {
			drop_exp = drop_exp*5/100;
		}
	}
	//被玩家杀死损失的检验计算
	else{
		//被对方阵营玩家杀死
		if(enemy->query_raceId()!=me->query_raceId()){
			 //drop_exp = level_next*10/100;
			 drop_exp = level_next*2/1000;
		}
		//被本方阵营玩家所杀
		else if(enemy->query_raceId()==me->query_raceId()){
			//drop_exp = level_next*5/100;
			drop_exp = level_next*1/1000;
		}
		//以下是处理在同一天被同一玩家所杀的情况
		if(!me->get_once_day["killed_by_player"]){
			me->get_once_day["killed_by_player"] = ([]);
		}
		if(!me->get_once_day["killed_by_player"][enemy->query_name()]){
			me->get_once_day["killed_by_player"][enemy->query_name()]=1;
		}
		else{
			me->get_once_day["killed_by_player"][enemy->query_name()]++;
		}
		int killed_num = me->get_once_day["killed_by_player"][enemy->query_name()];
		if(killed_num ==1)
			drop_exp = drop_exp*100/100;
		else if (killed_num==2){
			drop_exp = drop_exp*75/100;
		}
		else if(killed_num==3){
			drop_exp = drop_exp*50/100;
		}
		else {
			drop_exp = 0;
		}
	}
	return drop_exp;
}
//玩家失去经验后的处理调用接口，如：掉级、属性的改变等等
int del_exp(int drop_exp){
	//如果现有的经验比要失去的多则直接扣除
	if(current_exp>=drop_exp){
		current_exp -= drop_exp;
		return 2;
	}
	//现有经验比要是去的少则自动掉级，以下是自动掉级处理
	else{
		//失去经验自动掉级. 例如玩家达到2级, 升级需要3000经验, 已经获得了200经验, 则被杀后失去300经验, 直接掉到1级1900经验处.
		if(!level||level<=1){
			current_exp = 0;
			return 0;
		}
		level --;
		int need_exp = query_need_exp(); 
		int tmp = need_exp + current_exp;
		current_exp = tmp - drop_exp;
		this_object()->set_att_by_level();
		return 1;
	}
	return 0;
}

int query_level(){
	return level==0?1:level;
}
string query_level_cn(){
	return "等级："+MUD_CHINESED[query_level()]+"级";
}
int query_exp(){
	return exp;
}
int query_levelUp_need_exp(){
	int need_exp = query_need_exp(); 
	return need_exp; 
}
string query_levelUp_need_exp_cn(){
	int need_exp = query_need_exp();
	return "距离升级还需要 "+need_exp+" 点经验";
}

/** 根据累计捐赠金额返回打怪经验总倍数。 */
int query_donation_exp_multiplier_for_fee(int total_fee)
{
	if(total_fee>=12800)
		return 50;
	if(total_fee>=6400)
		return 40;
	if(total_fee>=3200)
		return 30;
	if(total_fee>=1600)
		return 20;
	if(total_fee>=1400)
		return 10;
	if(total_fee>=1200)
		return 8;
	if(total_fee>=1000)
		return 6;
	if(total_fee>=800)
		return 5;
	if(total_fee>=600)
		return 4;
	if(total_fee>=400)
		return 3;
	if(total_fee>=200)
		return 2;
	return 1;
}

int query_donation_exp_multiplier()
{
	object me = this_object();
	return query_donation_exp_multiplier_for_fee((int)me->all_fee);
}

/**
 * 统一计算打怪经验：药品先加成，活动按历史规则额外增加N倍，
 * 捐赠经验倍数再作用于上述完整总额。
 * 此函数不修改玩家数据，可供真实奖励和 TestUnit 共用。
 */
mapping(string:int) calculate_kill_exp_reward(int base_exp,int buff_percent,
	int event_bonus_multiplier,int donation_multiplier)
{
	mapping(string:int) reward = ([
		"base_exp":0,
		"buff_bonus":0,
		"event_bonus":0,
		"donation_bonus":0,
		"donation_multiplier":1,
		"stacked_exp":0,
	]);
	int after_buff;
	int after_event;
	if(base_exp<=0)
		return reward;
	if(buff_percent<0)
		buff_percent = 0;
	if(event_bonus_multiplier<0)
		event_bonus_multiplier = 0;
	if(donation_multiplier<1)
		donation_multiplier = 1;
	if(donation_multiplier>50)
		donation_multiplier = 50;
	reward["base_exp"] = base_exp;
	reward["buff_bonus"] = base_exp*buff_percent/100;
	after_buff = base_exp+reward["buff_bonus"];
	// 历史配置中的“2倍活动”表示额外增加2份，即总计3份。
	reward["event_bonus"] = after_buff*event_bonus_multiplier;
	after_event = after_buff+reward["event_bonus"];
	reward["donation_multiplier"] = donation_multiplier;
	reward["donation_bonus"] = after_event*(donation_multiplier-1);
	reward["stacked_exp"] = after_event+reward["donation_bonus"];
	return reward;
}

/**
 * 添加经验值（HTTP API 用户自动获得 50% 加成，可配置开关）
 * @param base_exp 基础经验值
 * @return 实际获得的经验值（含加成）
 */
int add_exp_with_bonus(int base_exp)
{
	object me = this_object();
	int final_exp = base_exp;
	if(me->query_level()>=VIPD->query_player_level_limit(me))
		return 0;

	// 检查 HTTP API 经验加成是否启用
	if(me->is_http_api_user && base_exp > 0) {
		// 动态检查加成开关
		int bonus_enabled = 1;
		int bonus_rate = 150;  // 默认 1.5倍

		object http_api_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
		if(http_api_daemon && functionp(http_api_daemon->query_exp_bonus_enabled)) {
			bonus_enabled = http_api_daemon->query_exp_bonus_enabled();
			bonus_rate = http_api_daemon->query_exp_bonus_rate();
		}

		if(bonus_enabled) {
			final_exp = base_exp * bonus_rate / 100;
		}
	}

	me->exp += final_exp;
	me->current_exp += final_exp;
	return final_exp;
}

/** 计算并发放统一的打怪经验，返回每一层加成明细。 */
mapping(string:int) add_kill_exp_with_bonus(int base_exp,int buff_percent,
	int event_bonus_multiplier)
{
	mapping(string:int) reward = calculate_kill_exp_reward(base_exp,
		buff_percent,event_bonus_multiplier,query_donation_exp_multiplier());
	int actual_exp = add_exp_with_bonus(reward["stacked_exp"]);
	reward["actual_exp"] = actual_exp;
	reward["interface_bonus"] = actual_exp-reward["stacked_exp"];
	return reward;
}

//private string initer=(this_object()->add_heart_beat(check_level,5),"");
