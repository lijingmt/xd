#include <globals.h>
#include <command.h>
#include <wapmud2/include/wapmud2.h>
//城主被攻击需要调用这个程序里的通告模块
#define CITYD ((object)(ROOT "/gamelib/single/daemons/cityd"))
private int tmp_heart_beat;
private int in_combat;
private mapping items;
//影射取种族职业类型表
static mapping(string:int) profe_fight=([
		"jianxian":0,
		"yushi":1,
		"zhuxian":2,
		"kuangyao":3,
		"wuyao":4,
		"yinggui":5,
		"humanlike":6,
		"beast":7,
		"bird":8,
		"fish":9,
		"amphibian":10,
		"bugs":11
		]);

//技能仇恨加权映射表
private mapping(string:int) skills_hate=([
		"test":100,

		]);

//战斗描述//////////////////////////////////
//由liaocheng于07/1/11添加，用于战斗描述
static mapping(string:array(string)) m_fight_desc=([
		"jian"  :({"一个直刺","一个横扫","一阵乱舞","一个斜砍"}),
		"dao"   :({"一个顺势斩","一顿猛砍","一个突进","一个单刀劈马"}),
		"qiang" :({"一个直刺","一个跟进","一个上挑","秋风扫落叶","一个回马枪"}),
		"gun"   :({"一个左横扫","当头一棒","施展群棍乱舞","一个直线突进"}),
		"bi"    :({"一个左刺","一个右刺","一个直刺","一个割首","一个断筋"}),
		"zhang" :({"一个猛击","一个横扫","迎面扑去","左右乱打"}),
		"chui"  :({"当头砸下","一个金刚抱拳","抡了过去","一计重压","一计震山敲虎"}),
		"fu"	:({"一个横扫","一顿狂砍","迎面砍下","使出一计破日月"}),
		"none"	:({"迎面一拳","一个左摆","一个直拳","呼呼带响"}),
		"beast" :({"疯狂撕咬","一个猛冲","一计爪击","发出刺耳吼叫"}),
		"bird"	:({"展翅扑打","一个俯冲","乱啄一气","乱抓一通"}),
		"fish"  :({"一个冲撞","一个尾部拍打","小咬一口"}),
		"amphibian"  :({"一个冲撞","一个尾部拍打","小咬一口"}),
		"bugs"  :({"一个冲撞","一个钉刺","小蜇一下","毒液喷射"})
		]);
//主要接口，由attack（）中的战斗描述代码调用
//在使用它之前，我们需要得到arg，即在_fight()中要添加相应的判断
string query_fight_desc(string arg) {  //arg 为上面影射表的index中的
	array(string) desc_tmp=m_fight_desc[arg];
	if(desc_tmp)
		return desc_tmp[random(sizeof(desc_tmp))];
	else
		return ("");
}
//获得arg的接口,对于人形生物我们返回need_weapon_type，在_fight()中再给出最终使用的武器类型
string query_fight_type() {
	string proId=this_object()->query_profeId();
	switch(profe_fight[proId]){
		case 0 .. 6:
			return("");
			break;
		default:
			return(proId);
			break;
	}
}
static string fight_desc_arg_main="";//为空时表示不是人形，不为空时记录主手武器的所属类型
static string fight_desc_arg_other="";//在fight_desc_arg_main为空时，记录副手武器的所属类型


// 战斗伤害////////////////////////////////
private int attack_weapon=0;
private int attack_huoyan_add=0;
private int attack_bingshuang_add=0;
private int attack_fengren_add=0;
private int attack_dusu_add=0;
private int defend = 0;
//////////////////////////////////////////

private int killing;
private int autoPerforming;//自动释放技能第一次标示
object enemy;
private string action;//"escape"|"perform ..."
static string accept_fight_msg="$N接受了$p的挑战。";
read_only(accept_fight_msg);
static string deny_fight_msg="$N不愿意和$p过招。";
read_only(deny_fight_msg);
static string success_msg="$N对$p拱手道：“承让了。”";
read_only(success_msg);
static string surrender_msg="$N向$p大声求饶道：“别打了别打了，我投降了。”";
read_only(surrender_msg);
static string killing_msg="$N看起来想杀了$p。";
read_only(killing_msg);
int query_killing(){
	return killing;
}
int query_in_combat(){
	return in_combat;
}
private void recover(){
	if(in_combat) return;
	//npc战斗以后自动恢复生命
	this_object()->life=this_object()->life_max;
}
void _clean_fight(){
	//werror("\n----"+this_object()->query_name_cn()+"呼叫_clean_fight()开始----\n");
	in_combat=0;
	action=0;
	killing=0;
	this_object()->first_fight = 0;
	this_object()->timeCold = 0;
	this_object()->eat_timeCold = 0;
	if(this_object()->is("npc")){
		this_object()->who_fight_npc = "";//重置首次攻击者
		this_object()->term_who_fight_npc = "";//重置首次攻击者队伍标示          
	}
	else 
		//还原杀戮标,示因为帮战要求，由liaocheng于08/08/30添加
		this_object()->kill_flag = 1;
	this_object()->reset_targets(); //重置仇恨列表
	if(tmp_heart_beat){
		set_heart_beat(0);
		tmp_heart_beat=0;
	}
	if(this_object()->is("npc")){
		if(zero_type(find_call_out(recover)))
			call_out(recover,2);
	}
	//初始化debuff映射表
	this_object()->set_debuff("dot",0,"none");
	this_object()->set_debuff("dot",1,0);
	this_object()->set_debuff("dot",2,0);
	this_object()->set_debuff("curse",0,"none");
	this_object()->set_debuff("curse",1,0);
	this_object()->set_debuff("curse",2,0);
	this_object()->set_debuff("curse2",0,"none");
	this_object()->set_debuff("curse2",1,0);
	this_object()->set_debuff("curse2",2,0);
	//初始化buff映射表
	this_object()->set_buff("buff",0,"none");
	this_object()->set_buff("buff",1,0);
	this_object()->set_buff("buff",2,0);
	this_object()->set_buff("buff2",0,"none");
	this_object()->set_buff("buff2",1,0);
	this_object()->set_buff("buff2",2,0);
	//werror("\n22222"+this_object()->query_name_cn()+"呼叫_clean_fight()结束222222\n");
}
//private void escape(void|int change){
void escape(void|int change){
	if(this_object()->get_cur_life()>0&&enemy->get_cur_life()>0){
		if(this_object()->query_debuff("70_skill_curse",0) == "baofengfeixue"){
			tell_object(this_object(),"【妖】暴风飞雪效果，你无法逃跑。\n");
			return;
		}
		int succ = 40+(int)(this_object()->query_dex()/20);
		if(random(100)>=succ){
			tell_object(enemy,this_object()->query_name_cn()+"想逃跑，但是失败了。\n");
			tell_object(this_object(),"你逃跑失败了。\n");
			return;
		}
		tell_object(enemy,this_object()->query_name_cn()+"逃跑了。\n");
		tell_object(this_object(),"你逃跑了。\n");
		enemy->clean_targets(this_object());
		_clean_fight();
		object env=environment(this_object());
		if(sizeof(env->exits)){
			this_object()->command("leave "+indices(env->exits)[random(sizeof(env->exits))]);
		}
		return;
	}
	else{                                                                    
		if(!this_object()->is("npc"))
			tell_object(this_object(),"你已经死亡。\n");
		return;
	}
}
//技能升级系统20070206//////////////////////////////////
//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
//而且，防止超出技能等级上限而溢出
	void skills_level_check(string sname){
		if(MUD_SKILLSD[sname]->boss_skill == 1)
			return;
		int cur_skills_level_limit = 10;
		//当前该用户该技能等级的熟练度大于该技能本身该等级的熟练度，则升级该用户的该技能等级
		if( this_object()->skills[sname][1]>=MUD_SKILLSD[sname]->performs_shuliandu[this_object()->skills[sname][0]] ){
			//当前技能等级设定上限为10级
			if(this_object()->skills[sname][0]<cur_skills_level_limit){
				this_object()->skills[sname][0]++;
				this_object()->skills[sname][1] = 0;
			}
		}
		else{
			//技能升级速度降低一半
			int tmp = random(3)+1;
			if(tmp==2)
				this_object()->skills[sname][1]++;
		}
	}
//技能升级系统20070206//////////////////////////////////
//技能释放接口20070131//////////////////////////////////
void perform(string name,void|int flag){
	//怪死亡判断......
	if(enemy==0)
		return;
	if(enemy && environment(this_object())==environment(enemy)){
		if(enemy->first_fight == 0 || !enemy->in_combat){
			enemy->_fight(this_object());
			enemy->first_fight = 1;
		}
	}
	object f_cur_skill;//当前使用技能对象
	string s = "";//面向自己的战斗描述
	string s1=""; //面向敌人的战斗描述
	if(name&&sizeof(name))
		f_cur_skill = (object)MUD_SKILLSD[name];
	else
	{
		string stmp = "你要施放什么技能？";
		tell_object(this_object(),stmp+"\n");
		return;
	}
	if(this_object()->query_debuff("curse2",0)=="shenzhishufu"){
		int time_left = this_object()->query_debuff("curse2",2);
		string stmp = "【妖】神之束缚效果，你暂时无法使用技能(还剩"+time_left+"s)\n";
		tell_object(this_object(),stmp+"\n");
		return;
	}
	if(this_object()->timeCold!=0 && !flag){
		string stmp = "还有"+this_object()->timeCold+"秒法术公共冷却时间\n";
		tell_object(this_object(),stmp);
		return;
	}
	if(f_cur_skill){
		int can_skill_level=0;//本字段记录 玩家可以使用的该技能的最高级别
		//首先判断技能使用的等级限制
		//mapping(int:string) lvLimit = f_cur_skill->query_performs_level_limit_all(); 
		//有时候很奇怪，这个方法找不到，所以要判断下这个方法，如果存在再执行，否则则返回0，不检查级别
		mapping(int:string) lvLimit = f_cur_skill->query_performs_level_limit_all?f_cur_skill->query_performs_level_limit_all():0;                                         
		if(lvLimit && sizeof(lvLimit))//该技能有等级限制
		{
			//第一种情况：技能有熟练度，使用得越多级别越高，这种技能只有一个等级限制
			if(sizeof(lvLimit) == 1){ //只有一个级别的技能
				if(this_object()->query_level()<lvLimit[1])
				{
					string stmp = "你尚未达到"+lvLimit[1]+"级，无法使用该技能。\n";
					tell_object(this_object(),stmp);
					return;
				}
			}
			else{//第二种情况；技能分为几个等级，每个等级对应的lv要求不同，某个级别不能使用，则自动判断其能否使用较低的级别，反复判断直到最低级别；
				for(int i=sizeof(lvLimit);i>0;i--)
				{
					if(this_object()->query_level>=lvLimit[i])
					{
						can_skill_level = i;
					}
					else if(i == 1)//玩家连最低一级的要求都没有达到，则无法使用该技能。
					{
						string stmp = "你尚未达到"+lvLimit[1]+"级，无法使用该技能。\n";
						tell_object(this_object(),stmp);
						return;
					}
				}
			}
		}

		//判断有这种技能
		string mofa_type=f_cur_skill->s_skill_type; //得到魔法类型
		//再判断是否有足够的法力施放该技能
		int skill_level=(int)(this_object()->skills[name][0]);
		//werror("===========skill_level:"+skill_level+"\n");
		if(skill_level>can_skill_level&&can_skill_level>0)
			skill_level=can_skill_level;
		//werror("===========275 skill_level:"+skill_level+"\n");
		int s_cast = f_cur_skill->query_performs_cast(skill_level);
		if(s_cast<=this_object()->get_cur_mofa()){
			//有足够的法力
			int s_cold = this_object()->f_skills[name];//技能的冷却时间
			int s_cold_del = 0;//因技能而减少的冷却时间
			int s_cold_add = 0;//因技能而延长的冷却时间
			if(this_object()->query_buff("70_skill_buff",0)=="lieyanzhuoshao"||this_object()->query_buff("70_skill_buff",0)=="bingci"){
				s_cold_del = this_object()->query_buff("70_skill_buff",1);
				s_cold -= s_cold_del;
			}
			if(this_object()->query_debuff("70_skill_curse",0)=="cuidu"){
				s_cold_add = 1;
				s_cold += s_cold_add;
			}
			if(s_cold < 0)
				s_cold = 0;
			//首先判断是否是各职业有特殊效果技能，由liaocheng于08/01/16添加
			if(mofa_type == "spec"){
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//更新该技能冷却时间,没在表里的则是添加
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					if(name == "xinhunzhuanhua" || name == "xinhunzhuanhua2"){
						//剑仙的心魂转化
						int life_tmp;
						if(name == "xinhunzhuanhua")
							life_tmp = this_object()->get_cur_mofa()*3+this_object()->get_cur_life();
						else if(name == "xinhunzhuanhua2")
							life_tmp = this_object()->get_cur_mofa()*7/2+this_object()->get_cur_life();
						if(life_tmp > this_object()->life_max)
							life_tmp = this_object()->life_max;
						this_object()->set_mofa(0);
						this_object()->set_life(life_tmp);
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
						s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
						tell_object(this_object(),s);
						tell_object(enemy,s1);
						//产生仇恨值
						int hate=(int)(100*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);
					}

					else if(name == "fashukuangchao" || name == "shishabenneng" || name == "fashukuangchao2" || name == "shishabenneng2"){
						//羽士的法术狂潮，诛仙的嗜血本能
						//记录buff的类型
						this_object()->set_buff("buff2",0,f_cur_skill->s_curse_type);
						//记录buff的值
						int tmp_int=f_cur_skill->query_performs_attack(skill_level);
						if(name == "shishabenneng"){
							tmp_int=this_object()->life_max*2/5;
							this_object()->f_skills = ([]);
							this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
						}
						else if(name == "shishabenneng2"){
							tmp_int=this_object()->life_max*1/2;
							this_object()->f_skills = ([]);
							this_object()->f_skills[name] = f_cur_skill->s_delayTime+1;
						}
						this_object()->set_buff("buff2",1,tmp_int);
						//记录buff的持续时间
						this_object()->set_buff("buff2",2,f_cur_skill->query_s_lasttime(skill_level));

						//产生仇恨值,buff的仇恨暂时定为10
						int hate=(int)(10*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "你施放了"+f_cur_skill->query_name_cn()+ "(等级"+skill_level+")";
						s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

					}
					else if(name == "xueranjiangshan" || name == "xueranjiangshan2"){
						//狂妖的血染江山
						//先看是否有主手武器，没有就不能攻击
						mapping items = this_object()->query_equip();//[string:object]
						if(!items["single_main_weapon"]&&!items["double_main_weapon"])
						{
							s += "该技能需要装备主手武器才能施放。";
							tell_object(this_object(),s+"\n");
							return;
						}
						//等级压制
						int difflevel = enemy->query_level()-this_object()->query_level();
						if(difflevel<0)
							difflevel=0;
						int myhitte= this_object()->query_if_hitte();
						int h = (int)(myhitte-difflevel*5);
						if(h<30)
							h=30;
						if(random(100)<=h){
							//命中啦 ~
							int s_phy_damage;
							int life_left;
							if(name == "xueranjiangshan"){
								s_phy_damage = this_object()->get_cur_life()*3/5;
								life_left = this_object()->get_cur_life()/2;
							}
							else if(name == "xueranjiangshan2"){
								s_phy_damage = this_object()->get_cur_life()*65/100;
								life_left = this_object()->get_cur_life()*55/100;
							}
							string s_name_cn = f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
							this_object()->set_life(life_left);
							if(this_object()->weapon_type=="double_main")
								attack(s_phy_damage,0,"double_main",s_name_cn,f_cur_skill->query_name());
							else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
								attack(s_phy_damage,0,"single_main",s_name_cn,f_cur_skill->query_name());
						}
						else{
							//未命中	
							s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但未命中对方。";
							s1 += this_object()->query_name_cn()+"施放"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但未击中你。"; 
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");
						}
					}
					else if(name == "shenzhishufu" || name == "shenzhishufu2"){
						//巫妖的神之束缚
						//等级压制
						int difflevel = enemy->query_level()-this_object()->query_level();          
						if(difflevel<0)
							difflevel=0;
						int myhitte= this_object()->query_if_hitte();
						int h = (int)(myhitte-difflevel*5);
						if(h<30)
							h=30;
						if(random(100)<=h){ //命中啦~
							//记录诅咒的类型
							enemy->set_debuff("curse2",0,f_cur_skill->s_curse_type);
							//记录诅咒的值
							enemy->set_debuff("curse2",1,f_cur_skill->query_performs_attack(skill_level));
							//记录诅咒的持续时间
							enemy->set_debuff("curse2",2,f_cur_skill->query_s_lasttime(skill_level));

							//产生仇恨值,curse的仇恨暂时定为20
							int hate=(int)(20*skills_hate["test"]/100);
							enemy->flush_targets(this_object(),hate);

							s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
							s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");

							//战斗中击中对方，减攻击者武器磨损
							this_object()->reduce_fight_wield_weapon(1);
							//战斗中被攻击者击中，减防具磨损
							enemy->reduce_fight_wear_armor(1);
						}
						else { //未命中
							s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但被对方抵抗了。";
							s1 += this_object()->query_name_cn()+"对你施放"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但被你抵抗了";
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");
						}
					}
					else if(name == "jinchanmeiying" || name == "jinchanmeiying2"){
						//影鬼的金蝉魅影
						array(object) enemys = this_object()->get_all_targets();
						s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
						if(enemys && sizeof(enemys)){
							for(int i=0;i<sizeof(enemys);i++){
								object target = enemys[i];
								tell_object(target,s1+"\n");
								target->clean_targets(this_object());
							}
						}
						this_object()->_clean_fight();
						this_object()->f_skills = ([]);
						this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
						this_object()->hind = 1;
						if(name == "jinchanmeiying2"){
							this_object()->set_buff("spec_attack_buff",0,f_cur_skill->s_curse_type);
							int tmp_int=f_cur_skill->query_performs_attack(1);
							this_object()->set_buff("spec_attack_buff",1,tmp_int);
							this_object()->set_buff("spec_attack_buff",2,f_cur_skill->s_lasttime);
						}
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
						tell_object(this_object(),s+"\n");
						this_object()->command("look");
					}
					return;
				}
				else{
					//该使用过的技能未冷却,提示并返回
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			//70级的各职业特殊技能
			else if(mofa_type == "70_spec"){
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//更新该技能冷却时间,没在表里的则是添加
					if(name == "fanzhuanyiji")
						this_object()->f_skills = ([]);
					this_object()->f_skills[name] = f_cur_skill->s_delayTime+1;
					this_object()->set_buff("70_skill_buff",0,name);
					this_object()->set_buff("70_skill_buff",1,f_cur_skill->effect_value);
					this_object()->set_buff("70_skill_buff",2,f_cur_skill->s_lasttime);
					if(name == "baofengfeixue" || name == "cuidu"){
						enemy->set_debuff("70_skill_curse",0,name);
						this_object()->set_debuff("70_skill_curse",1,f_cur_skill->effect_value);
						enemy->set_debuff("70_skill_curse",2,f_cur_skill->s_lasttime);
					}
					s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
					s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")\n";
					tell_object(this_object(),s);
					tell_object(enemy,s1);
					//产生仇恨值
					int hate=(int)(100*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);
					return;
				}
				else{
					//该使用过的技能未冷却,提示并返回
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			//判断是物理还是法术技能
			/*   法术攻击技能     */
			else if(mofa_type!="phy"&&mofa_type!="dot"&&mofa_type!="curse"&&mofa_type!="buff"){
				//诛仙70技能的法术免疫效果
				if(enemy->query_buff("70_skill_buff",0)=="bingci"){
					string stmp = "【仙】冰刺效果，对法术伤害免疫(还余"+enemy->query_buff("70_skill_buff",2)+"s)\n";
					tell_object(this_object(),stmp);
					stmp = "【仙】冰刺效果，你免疫了对方的一次法术攻击(还余"+enemy->query_buff("70_skill_buff",2)+"s)\n";
					tell_object(enemy,stmp);
					return;
				}
				//判定该技能冷却时间的判定
				//得到释放技能表，看有无记录，如果有，看冷却时间到了没有
				int mofa_a_low=0; //法术攻击的下限
				int mofa_a_high=0; //法术攻击的上限
				int mofa_a=0; //取得法术攻击的随即值
				int mofa_defend=0; //敌人的魔法抗性
				int fact_mofa_a=0; //最终的法术伤害
				int mofachuantou_add=0;//魔法穿透值
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//更新该技能冷却时间,没在表里的则是添加
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					//法术伤害计算公式，还有减免公式
					//等级压制
					int difflevel = enemy->query_level()-this_object()->query_level();
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<=h){
						//命中啦 ~
						//得到法术技能的伤害随即值
						mofa_a_low = f_cur_skill->query_performs_mofa_attack_low(skill_level);	
						mofa_a_high = f_cur_skill->query_performs_mofa_attack_high(skill_level);
						mofa_a = random(mofa_a_high-mofa_a_low+1)+mofa_a_low;
						//再加上装备属性带来的法术伤害提升
						//智力也会提高法伤由liaocheng于07/4/16添加
						//职业调整 caijie 08/12/03
						if(this_object()->query_profeId()=="yushi"||this_object()->query_profeId()=="wuyao"){
							mofa_a += this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think()*7/2);
						}
						else
							mofa_a +=this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think()*5/2);
						if(this_object()->query_buff("buff2",0)=="all_mofa_attack"){
							mofa_a = mofa_a*3/2;
						}
						//计算出相对应的敌人的魔法抗性
						switch(mofa_type) {
							case "huo_mofa_attack":
								mofa_defend = enemy->query_equip_add("huoyan_defend");
							break;
							case "bing_mofa_attack":
								mofa_defend = enemy->query_equip_add("bingshuang_defend");
							break;
							case "feng_mofa_attack":
								//巫妖70技能的风刃法术加成效果
								if(this_object()->query_buff("70_skill_buff",0)=="baofengfeixue")
									mofa_a += mofa_a/2;
								mofa_defend = enemy->query_equip_add("fengren_defend");
							break;
							case "du_mofa_attack":
								mofa_defend = enemy->query_equip_add("du_defend");
							break;
							default :
							mofa_defend = 0;
							break;
						}
						mofa_defend += enemy->query_equip_add("all_mofa_defend");
						//计算装备所有的魔法穿透值
						mofachuantou_add=this_object()->query_equip_add("mofachuantou_add");
						//最后获得实际的魔法伤害值
						fact_mofa_a=mofa_a-(int)(mofa_a*mofa_defend/400);
						fact_mofa_a+=mofachuantou_add;//增加魔法穿透的攻击数值到最重结果中
						//判断暴击
						int b = this_object()->query_if_baoji();
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						s1+=this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						if(b){
							//暴击啦 ~
							fact_mofa_a=(int)fact_mofa_a*150/100;
							s += "，产生了暴击效果！";
							s1 += "，产生了暴击效果！";

						}

						//在这儿加入buff的魔法盾吸收伤害liaocheng 07/4/9
						int attack_fact = fact_mofa_a;
						string absorb_desc = "";
						if(enemy->query_buff("buff",0)=="absorb"){
							if((int)enemy->query_buff("buff",1) >= fact_mofa_a){
								int remain = (int)enemy->query_buff("buff",1) - fact_mofa_a;
								attack_fact= 0;
								absorb_desc = "(被吸收)";
								if(remain <= 0)
									enemy->clean_buff("buff");
								else
									enemy->set_buff("buff",1,remain);
							}
							else{
								attack_fact = fact_mofa_a - (int)enemy->query_buff("buff",1); 
								absorb_desc = "("+enemy->query_buff("buff",1)+"点被吸收)";
								enemy->clean_buff("buff");
							}
						}
						if(enemy->query_buff("buff2",0)=="absorb"){
							if((int)enemy->query_buff("buff2",1) >= fact_mofa_a){
								int remain = (int)enemy->query_buff("buff2",1) - fact_mofa_a;
								attack_fact= 0;
								absorb_desc = "(被吸收)";
								if(remain <= 0)
									enemy->clean_buff("buff2");
								else
									enemy->set_buff("buff2",1,remain);
							}
							else{
								attack_fact = fact_mofa_a - (int)enemy->query_buff("buff",1); 
								absorb_desc = "("+enemy->query_buff("buff2",1)+"点被吸收)";
								enemy->clean_buff("buff2");
							}
						}
						//如果魔法穿透大于零，则要在前端提示给玩家
						string chuantou_desc = "";
						if(mofachuantou_add>0){
							chuantou_desc = "【"+mofachuantou_add+" 点法术穿透】";
						}
						s += "造成了 " +fact_mofa_a+ " 点伤害！"+absorb_desc+chuantou_desc+"\n";
						s1 += "造成了 " +fact_mofa_a+ " 点伤害！"+absorb_desc+chuantou_desc+"\n";
						tell_object(this_object(),s);
						tell_object(enemy,s1);

						//产生仇恨值
						int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());	
						//生命减取 
						int life_damage = enemy->get_cur_life()-attack_fact;
						if(life_damage<=0){
							//敌人死亡，则把敌人从仇恨列表中清除
							this_object()->clean_targets(enemy);
							//在这里加入死亡处理,killing判断是杀戮还是决斗
							if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
								enemy->set_life(1);
								tell_object(this_object(),"你在决斗中战胜了 "+enemy->query_name_cn()+" ！\n");
								tell_object(enemy,this_object()->query_name_cn()+"在决斗中战胜了你！\n");
								enemy->_clean_fight();
								_clean_fight();
								enemy=0;
							}
							else{
								enemy->fight_die();
								enemy=0;
							}
							return;
						}
						enemy->set_life(life_damage);
						//if(this_object()->is("player")){
						//战斗中击中对方，减攻击者武器磨损
						this_object()->reduce_fight_wield_weapon(1);
						//战斗中被攻击者击中，减防具磨损
						enemy->reduce_fight_wear_armor(1);
						//}
					}
					else{
						//未命中	
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但被对方抵抗了。";
						s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+"，但被你抵抗了";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());	
					}
					return;
				}
				else{
					//该使用过的技能未冷却,提示并返回
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*   物理攻击技能     */
			else if(f_cur_skill->s_skill_type=="phy"){
				//werror("===========skill_level:"+skill_level+"\n");
				string s_name_cn=f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
				//先看是否有主手武器，没有就不能攻击
				mapping items = this_object()->query_equip();//[string:object]
				if(!items["single_main_weapon"]&&!items["double_main_weapon"])
				{
					s += "该技能需要装备主手武器才能施放。";
					tell_object(this_object(),s+"\n");
					return;
				}
				//判定该技能冷却时间的判定
				//判断冷却时间
				int s_phy_damage = f_cur_skill->query_performs_attack(skill_level);
				int s_weapon_add = f_cur_skill->query_performs_per(skill_level);
				if(s_cold <= 1){
					//该技不在表中或者冷却，
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					//物理技能攻击走attack流程，熟练度提高也在那里进行计算
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					//等级压制
					int difflevel = enemy->query_level()-this_object()->query_level();
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<=h){
						//命中啦 ~
						if(this_object()->weapon_type=="double_main")
							attack(s_phy_damage,s_weapon_add,"double_main",s_name_cn,f_cur_skill->query_name());
						else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
							attack(s_phy_damage,s_weapon_add,"single_main",s_name_cn,f_cur_skill->query_name());
					}
					else{
						//未命中	
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但未命中对方。";
						s1 += this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但未击中你。"; 
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());	
					}
					return;
				}
				else{
					//该使用过的技能未冷却,提示并返回
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*    施放的是dot技能    */
			else if(f_cur_skill->s_skill_type=="dot"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					//等级压制
					int difflevel = enemy->query_level()-this_object()->query_level();          
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<=h){ //命中啦~
						//记录dot技能的名字
						enemy->set_debuff("dot",0,name);
						//记录dot的每秒伤害
						enemy->set_debuff("dot",1,f_cur_skill->query_performs_attack(skill_level));
						//记录dot剩余时间
						enemy->set_debuff("dot",2,f_cur_skill->query_s_lasttime(skill_level));

						//产生仇恨值,dot的仇恨暂时定为20
						int hate=(int)(20*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

						//if(this_object()->is("player")){
						//战斗中击中对方，减攻击者武器磨损
						this_object()->reduce_fight_wield_weapon(1);
						//战斗中被攻击者击中，减防具磨损
						enemy->reduce_fight_wear_armor(1);
						//}
					}
					else { //未命中
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但被对方抵抗了。";
						s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但被你抵抗了";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());
						return;
					}
				}
				else {
					//技能还未冷却
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*      施放的是诅咒技能     */
			else if(f_cur_skill->s_skill_type=="curse"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					//等级压制
					int difflevel = enemy->query_level()-this_object()->query_level();          
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<=h){ //命中啦~
						//记录诅咒的类型
						enemy->set_debuff("curse",0,f_cur_skill->s_curse_type);
						//记录诅咒的值
						enemy->set_debuff("curse",1,f_cur_skill->query_performs_attack(skill_level));
						//记录诅咒的持续时间
						enemy->set_debuff("curse",2,f_cur_skill->query_s_lasttime(skill_level));

						//产生仇恨值,curse的仇恨暂时定为20
						int hate=(int)(20*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());

						//战斗中击中对方，减攻击者武器磨损
						this_object()->reduce_fight_wield_weapon(1);
						//战斗中被攻击者击中，减防具磨损
						enemy->reduce_fight_wear_armor(1);
					}
					else { //未命中
						s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+"), 但被对方抵抗了。";
						s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"(等级"+skill_level+")，但被你抵抗了";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
						skills_level_check(f_cur_skill->query_name());
						return;
					}
				}
				else {
					//未冷却
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*    施放的增益魔法    */
			else if(f_cur_skill->s_skill_type=="buff"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;

					//记录buff的类型
					this_object()->set_buff("buff",0,f_cur_skill->s_curse_type);
					//记录buff的值
					int tmp_int=f_cur_skill->query_performs_attack(skill_level);
					if(f_cur_skill->s_curse_type == "absorb"){
						if(this_object()->query_profeId()=="wuyao"||this_object()->query_profeId()=="yushi"){
							tmp_int += (int)(this_object()->query_think()*3);
						}
						else
							tmp_int += (int)(this_object()->query_think()*3/2);
					}
					this_object()->set_buff("buff",1,tmp_int);
					//记录buff的持续时间
					this_object()->set_buff("buff",2,f_cur_skill->query_s_lasttime(skill_level));

					//产生仇恨值,buff的仇恨暂时定为10
					int hate=(int)(10*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);

					s += "你施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
					s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")";
					tell_object(this_object(),s+"\n");
					tell_object(enemy,s1+"\n");
					//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
					//这里排除了狂妖的冲动技能
					if(f_cur_skill->query_name() != "chongdong")
						skills_level_check(f_cur_skill->query_name());
					return;
				}
				else {
					//未冷却
					s += "该技能还需要"+(s_cold-1)+"秒冷却时间,无法使用。";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
		}
		else {
			//无足够的法力
			s += "你的仙力不够，无法施放"+f_cur_skill->query_name_cn()+"(等级"+skill_level+")。";
			tell_object(this_object(),s+"\n");
			return;
		}
	}
	else {
		//没有这种技能
		string stmp = "你要施放什么技能？";
		tell_object(this_object(),stmp+"\n");
		return;
	}
}

//boss技能释放
void boss_perform(string name){
	//怪死亡判断......
	if(enemy==0)
		return;
	object f_cur_skill;//当前使用技能对象
	string s = "";//面向自己的战斗描述
	string s1=""; //面向敌人的战斗描述
	f_cur_skill = (object)MUD_SKILLSD[name];
	if(f_cur_skill){
		//首先判断有这种技能
		//再判断是否有足够的法力施放该技能
		string mofa_type=f_cur_skill->s_skill_type; //得到魔法类型
		//有足够的法力
		//判断是物理还是法术技能
		/*   法术攻击技能     */
		if(mofa_type!="phy"&&mofa_type!="dot"&&mofa_type!="curse"&&mofa_type!="buff"){
			int mofa_a_low=0; //法术攻击的下限
			int mofa_a_high=0; //法术攻击的上限
			int mofa_a=0; //取得法术攻击的随即值
			int mofa_defend=0; //敌人的魔法抗性
			int fact_mofa_a=0; //最终的法术伤害
			int myhitte= this_object()->query_if_hitte();
			//命中啦 ~
			//得到法术技能的伤害随即值
			mofa_a_low = f_cur_skill->query_performs_mofa_attack_low();	
			mofa_a_high = f_cur_skill->query_performs_mofa_attack_high();
			mofa_a = random(mofa_a_high-mofa_a_low+1)+mofa_a_low;
			//再加上装备属性带来的法术伤害提升
			//智力也会提高法伤由liaocheng于07/4/16添加
			mofa_a +=this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think());
			if(f_cur_skill->is_aoe){
				array(object) enemys;
				//是aoe魔法
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						if(enemys[i]){
							if(myhitte<0)
								myhitte=0;
							if(random(100)<=myhitte){
								//计算出相对应的敌人的魔法抗性
								switch(mofa_type) {
									case "huo_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("huoyan_defend");
									break;
									case "bing_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("bingshuang_defend");
									break;
									case "feng_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("fengren_defend");
									break;
									case "du_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("du_defend");
									break;
									default :
									mofa_defend = 0;
									break;
								}
								mofa_defend += enemys[i]->query_equip_add("all_mofa_defend");
								//最后获得实际的魔法伤害值
								fact_mofa_a=mofa_a-(int)(mofa_a*mofa_defend/400);
								//判断暴击
								int b = this_object()->query_if_baoji();
								s1+=this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn();
								if(b){
									//暴击啦 ~
									fact_mofa_a=(int)fact_mofa_a*150/100;
									s1 += "，产生了暴击效果！";

								}

								//在这儿加入buff的魔法盾吸收伤害liaocheng 07/4/9
								int	attack_fact = fact_mofa_a;
								string absorb_desc = "";
								if(enemys[i]->query_buff("buff",0)=="absorb"){
									if((int)enemys[i]->query_buff("buff",1) >= fact_mofa_a){
										int remain = (int)enemys[i]->query_buff("buff",1) - fact_mofa_a;
										attack_fact= 0;
										absorb_desc = "(被吸收)";
										if(remain <= 0)
											enemys[i]->clean_buff("buff");
										else
											enemys[i]->set_buff("buff",1,remain);
									}
									else{
										attack_fact = fact_mofa_a - (int)enemys[i]->query_buff("buff",1); 
										absorb_desc = "("+enemys[i]->query_buff("buff",1)+"点被吸收)";
										enemys[i]->clean_buff("buff");
									}
								}
								if(enemys[i]->query_buff("buff2",0)=="absorb"){
									if((int)enemys[i]->query_buff("buff2",1) >= fact_mofa_a){
										int remain = (int)enemys[i]->query_buff("buff2",1) - fact_mofa_a;
										attack_fact= 0;
										absorb_desc = "(被吸收)";
										if(remain <= 0)
											enemys[i]->clean_buff("buff2");
										else
											enemys[i]->set_buff("buff2",1,remain);
									}
									else{
										attack_fact = fact_mofa_a - (int)enemys[i]->query_buff("buff2",1); 
										absorb_desc = "("+enemys[i]->query_buff("buff2",1)+"点被吸收)";
										enemys[i]->clean_buff("buff2");
									}
								}
								s1 += "对你造成了 " +fact_mofa_a+ " 点伤害！"+absorb_desc+"\n";
								tell_object(enemys[i],s1);

								//产生仇恨值
								int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
								enemys[i]->flush_targets(this_object(),hate);

								//生命减取 
								int life_damage = enemys[i]->get_cur_life()-attack_fact;
								if(life_damage<=0){
									//敌人死亡，则把敌人从仇恨列表中清除
									this_object()->clean_targets(enemys[i]);
									enemys[i]->fight_die();
								}
								else{
									enemys[i]->set_life(life_damage);
									enemy->reduce_fight_wear_armor(1);
								}
							}
							else{
								//未命中
								s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
								tell_object(enemys[i],s1+"\n");
							}
						}
					}
				}
				return;
			}
			//不是aoe，则走原来的路线
			if(myhitte<0)
				myhitte=0;
			if(random(100)<=myhitte){
				switch(mofa_type) {
					case "huo_mofa_attack":
						mofa_defend = enemy->query_equip_add("huoyan_defend");
					break;
					case "bing_mofa_attack":
						mofa_defend = enemy->query_equip_add("bingshuang_defend");
					break;
					case "feng_mofa_attack":
						mofa_defend = enemy->query_equip_add("fengren_defend");
					break;
					case "du_mofa_attack":
						mofa_defend = enemy->query_equip_add("du_defend");
					break;
					default:
					mofa_defend = 0;
					break;
				}
				mofa_defend += enemy->query_equip_add("all_mofa_defend");
				//最后获得实际的魔法伤害值
				fact_mofa_a=mofa_a-(int)(mofa_a*mofa_defend/400);
				//判断暴击
				int b = this_object()->query_if_baoji();
				s1+=this_object()->query_name_cn()+"对你施放"+f_cur_skill->query_name_cn();
				if(b){
					//暴击啦 ~
					fact_mofa_a=(int)fact_mofa_a*150/100;
					s1 += "，产生了暴击效果！";

				}

				//在这儿加入buff的魔法盾吸收伤害liaocheng 07/4/9
				int	attack_fact = fact_mofa_a;
				string absorb_desc = "";
				if(enemy->query_buff("buff",0)=="absorb"){
					if((int)enemy->query_buff("buff",1) >= fact_mofa_a){
						int remain = (int)enemy->query_buff("buff",1) - fact_mofa_a;
						attack_fact= 0;
						absorb_desc = "(被吸收)";
						if(remain <= 0)
							enemy->clean_buff("buff");
						else
							enemy->set_buff("buff",1,remain);
					}
					else{
						attack_fact = fact_mofa_a - (int)enemy->query_buff("buff",1); 
						absorb_desc = "("+enemy->query_buff("buff",1)+"点被吸收)";
						enemy->clean_buff("buff");
					}
				}
				if(enemy->query_buff("buff2",0)=="absorb"){
					if((int)enemy->query_buff("buff2",1) >= fact_mofa_a){
						int remain = (int)enemy->query_buff("buff2",1) - fact_mofa_a;
						attack_fact= 0;
						absorb_desc = "(被吸收)";
						if(remain <= 0)
							enemy->clean_buff("buff2");
						else
							enemy->set_buff("buff2",1,remain);
					}
					else{
						attack_fact = fact_mofa_a - (int)enemy->query_buff("buff2",1); 
						absorb_desc = "("+enemy->query_buff("buff2",1)+"点被吸收)";
						enemy->clean_buff("buff2");
					}
				}
				s1 += "造成了 " +fact_mofa_a+ " 点伤害！"+absorb_desc+"\n";
				tell_object(enemy,s1);

				//产生仇恨值
				int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
				enemy->flush_targets(this_object(),hate);

				//生命减取 
				int life_damage = enemy->get_cur_life()-attack_fact;
				if(life_damage<=0){
					//敌人死亡，则把敌人从仇恨列表中清除
					this_object()->clean_targets(enemy);
					//在这里加入死亡处理,killing判断是杀戮还是决斗
					if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
						enemy->set_life(1);
						tell_object(this_object(),"你在决斗中战胜了 "+enemy->query_name_cn()+" ！\n");
						tell_object(enemy,this_object()->query_name_cn()+"在决斗中战胜了你！\n");
						enemy->_clean_fight();
						_clean_fight();
						enemy=0;
					}
					else{
						enemy->fight_die();
						enemy=0;
					}
					return;
				}
				enemy->set_life(life_damage);
				//战斗中被攻击者击中，减防具磨损
				enemy->reduce_fight_wear_armor(1);
			}
			else{
				//未命中	
				s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
				tell_object(enemy,s1+"\n");
			}
			return;
		}
		//   --- 物理攻击技能 ---    
		else if(f_cur_skill->s_skill_type=="phy"){
			string s_name_cn=f_cur_skill->query_name_cn();
			//判断冷却时间
			int s_phy_damage = f_cur_skill->query_performs_attack();
			int s_weapon_add = f_cur_skill->query_performs_per();
			//该技不在表中或者冷却，
			//物理技能攻击走attack流程，熟练度提高也在那里进行计算
			//等级压制
			int myhitte= this_object()->query_if_hitte();
			if(myhitte<0)
				myhitte=0;
			if(random(100)<=myhitte){
				//命中啦 ~
				//if(this_object()->weapon_type=="double_main")
				attack(s_phy_damage,s_weapon_add,"double_main",s_name_cn,f_cur_skill->query_name());
				//else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
				//	attack(s_phy_damage,s_weapon_add,"single_main",s_name_cn,f_cur_skill->query_name());

			}
			else{
				//未命中	
				s1 += this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn()+"，但未击中你。"; 
				tell_object(enemy,s1+"\n");
			}
			return;
		}
		//  ---  施放的是dot技能 ---
		else if(f_cur_skill->s_skill_type=="dot"){
			if(f_cur_skill->is_aoe){
				//是aoe魔法
				array(object) enemys;
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						int myhitte= this_object()->query_if_hitte();
						if(myhitte<0)
							myhitte=0;
						if(random(100)<=myhitte){   //命中啦~
							//记录dot技能的名字
							enemys[i]->set_debuff("dot",0,name);
							//记录dot的每秒伤害
							enemys[i]->set_debuff("dot",1,f_cur_skill->query_performs_attack());
							//记录dot剩余时间
							enemys[i]->set_debuff("dot",2,f_cur_skill->query_s_lasttime());

							//产生仇恨值,dot的仇恨暂时定为20
							int hate=(int)(20*skills_hate["test"]/100);
							enemys[i]->flush_targets(this_object(),hate);
							s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn();
							tell_object(enemys[i],s1+"\n");

							//战斗中被攻击者击中，减防具磨损
							enemys[i]->reduce_fight_wear_armor(1);
						}
						else { //未命中
							s1 += this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
							tell_object(enemys[i],s1+"\n");
						}
					}
				}
				return;
			}
			//单一路线
			int myhitte= this_object()->query_if_hitte();
			if(myhitte<0)
				myhitte=0;
			if(random(100)<=myhitte){   //命中啦~
				//记录dot技能的名字
				enemy->set_debuff("dot",0,name);
				//记录dot的每秒伤害
				enemy->set_debuff("dot",1,f_cur_skill->query_performs_attack());
				//记录dot剩余时间
				enemy->set_debuff("dot",2,f_cur_skill->query_s_lasttime());

				//产生仇恨值,dot的仇恨暂时定为20
				int hate=(int)(20*skills_hate["test"]/100);
				enemy->flush_targets(this_object(),hate);

				s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn();
				tell_object(enemy,s1+"\n");

				//战斗中被攻击者击中，减防具磨损
				enemy->reduce_fight_wear_armor(1);
			}
			else { //未命中
				s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
				tell_object(enemy,s1+"\n");
				return;
			}
		}
		//    ---  施放的是诅咒技能  ---
		else if(f_cur_skill->s_skill_type=="curse"){
			if(f_cur_skill->is_aoe){
				//是aoe魔法
				array(object) enemys;
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						int myhitte= this_object()->query_if_hitte();
						if(myhitte<0)
							myhitte=0;
						if(random(100)<=myhitte){ //命中啦~
							//记录诅咒的类型
							enemys[i]->set_debuff("curse",0,f_cur_skill->s_curse_type);
							//记录诅咒的值
							enemys[i]->set_debuff("curse",1,f_cur_skill->query_performs_attack());
							//记录诅咒的持续时间
							enemys[i]->set_debuff("curse",2,f_cur_skill->query_s_lasttime());

							//产生仇恨值,curse的仇恨暂时定为20
							int hate=(int)(20*skills_hate["test"]/100);
							enemys[i]->flush_targets(this_object(),hate);

							s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn();
							tell_object(enemys[i],s1+"\n");

							//战斗中被攻击者击中，减防具磨损
							enemys[i]->reduce_fight_wear_armor(1);
						}
						else { //未命中
							s1 += this_object()->query_name_cn()+"施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
							tell_object(enemys[i],s1+"\n");
						}
					}
					return;
				}
				//单一路线
				int myhitte= this_object()->query_if_hitte();
				if(myhitte<0)
					myhitte=0;
				if(random(100)<=myhitte){ //命中啦~
					//记录诅咒的类型
					enemy->set_debuff("curse",0,f_cur_skill->s_curse_type);
					//记录诅咒的值
					enemy->set_debuff("curse",1,f_cur_skill->query_performs_attack());
					//记录诅咒的持续时间
					enemy->set_debuff("curse",2,f_cur_skill->query_s_lasttime());

					//产生仇恨值,curse的仇恨暂时定为20
					int hate=(int)(20*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);

					s1 += this_object()->query_name_cn()+"对你施放了"+f_cur_skill->query_name_cn();
					tell_object(enemy,s1+"\n");
					//战斗中被攻击者击中，减防具磨损
					enemy->reduce_fight_wear_armor(1);
				}
				else { //未命中
					s1 += this_object()->query_name_cn()+"对你施放 "+f_cur_skill->query_name_cn()+"，但被你抵抗了";
					tell_object(enemy,s1+"\n");
				}
			}
			return;
		}
		//  ---  施放的增益魔法 ---
		else if(f_cur_skill->s_skill_type=="buff"){
			//记录buff的类型
			this_object()->set_buff("buff",0,f_cur_skill->s_curse_type);
			//记录buff的值
			this_object()->set_buff("buff",1,f_cur_skill->query_performs_attack());
			//记录buff的持续时间
			this_object()->set_buff("buff",2,f_cur_skill->query_s_lasttime());

			//产生仇恨值,buff的仇恨暂时定为10
			int hate=(int)(10*skills_hate["test"]/100);
			enemy->flush_targets(this_object(),hate);

			s1 += this_object()->query_name_cn()+"施放了"+f_cur_skill->query_name_cn();
			tell_object(enemy,s1+"\n");
			return;
		}
	}
	else {
		//没有这种技能
		werror("-----error boss_perform the skill "+name+" is not exist------\n");
		return;
	}
}


//战斗核心算法,普通攻击或者施放物理攻击技能时调用的接口
private void attack(int skill_add,int skill_add_per,string type,string skill_name_cn,void|string name_skill){
	if(enemy==0){
		return;
	}
	string fight_action_desc="";
	//本次攻击成功后的最终伤害值
	int attack_a = 0;
	//如果有魔法盾buff，则为吸收后的伤害
	int attack_fact = 0;

	int self=this_object()->query_base_damage(); //得到自身攻击力
	int add=0; //得到附加武器伤害
	int add_per=0; //得到增加武器伤害百分比
	int h;
	//首先判断攻击者的命中计算：攻击者的命中率+装备的附加命中+技能的命中(可能是100%命中技能)
	if(skill_name_cn!=""){
		h=100; //物理技能攻击，在perform()里已经作了等级压制，这里不需走普攻的命中判断
	}
	else{
		int hitte_a = this_object()->query_if_hitte();//mudlib/inherit/feature/char.pike中接口
		int difflevel = enemy->query_level()-this_object()->query_level(); 
		if(difflevel<0)
			difflevel=0;
		h = (int)(hitte_a-difflevel*5);
		if(this_object()->is_both_weapons) //双武器命中的惩罚
			h -= 10;
		if(h<30)
			h=30;
	}
	//只有攻击者命中了，才需要进行下一步计算	
	if(random(100)<h){
		//闪避计算：计算被攻击者的闪避率+装备的闪避	
		int dodge_e = enemy->query_if_dodge();
		//只有被攻击者未能闪避，才需要进行下一步计算
		int dodgechuantou_add=this_object()->query_equip_add("dodgechuantou_add");
		//当被闪避掉以后，则判断是否无视闪避，计算闪避穿透的值，如果随机到几率 则重置闪避
		string dodgechuantou_desc="";
		if(dodge_e==1 && dodgechuantou_add>0 && random(100)<=dodgechuantou_add){
			dodge_e=0;//虽然躲掉了，但又被拉回来了，因为无视闪避生效。
			dodgechuantou_desc="\n(闪避穿透生效，无视对方闪避技能，你的攻击命中 【"+enemy->query_name_cn()+"】)\n";
		}
		if(dodge_e==0){

			//在这里添加武器的魔法伤害附加
			//
			///////////////////////////////

			//if(this_object()->is("player")){	
			//战斗中击中对方，减攻击者武器磨损
			this_object()->reduce_fight_wield_weapon(1);
			//战斗中被攻击者击中，减防具磨损
			enemy->reduce_fight_wear_armor(1);
			//}
			////////////////攻击者伤害计算//////////////////////////////////////
			//1.玩家的物理伤害(玩家伤害上下限之间的一个随机数值)
			if(type=="double_main" || type=="single_main") { //玩家装备的是主手武器
				//得到附加武器伤害
				add=this_object()->main_attack_attri_add+skill_add; 
				//得到增加武器伤害百分比
				//add_per=add+(add*this_object()->main_attack_attri_add_per*10)/100+skill_add_per; 
				add_per=this_object()->main_attack_attri_add_per*10+skill_add_per;//正确的公式
				attack_weapon = this_object()->query_main_equiped_attack();//mudlib/inherit/feature/attack.pike中定义的接口

				//描述
				if(fight_desc_arg_main=="beast"||fight_desc_arg_main=="bird"||fight_desc_arg_main=="fish"||fight_desc_arg_main=="amphibian"||fight_desc_arg_main=="bugs")
					fight_action_desc=query_fight_desc(fight_desc_arg_main);
				else {
					if(skill_name_cn=="")
						fight_action_desc=this_object()->cur_main_weapon_name+"，"+query_fight_desc(fight_desc_arg_main);
					else
						fight_action_desc=this_object()->cur_main_weapon_name;
				}
			}

			else if(type=="other") {
				//得到附加武器伤害
				add=this_object()->other_attack_attri_add+skill_add;
				//得到增加武器伤害百分比
				//add_per=add+(add*this_object()->other_attack_attri_add_per*10)/100+skill_add_per; 
				add_per=this_object()->other_attack_attri_add_per*10+skill_add_per;//正确的公式	
				attack_weapon = this_object()->query_other_equiped_attack();
				if(skill_name_cn=="")
					fight_action_desc = this_object()->cur_other_weapon_name+"，"+query_fight_desc(fight_desc_arg_other);
				else 
					fight_action_desc=this_object()->cur_main_weapon_name;
			}

			//得到未暴击前的总攻击伤害,尽量避免不必要的浮点运算
			int total_attack=0;
			if(add_per) 
				total_attack = attack_weapon+(int)(attack_weapon*add_per/100)+add+self;
			else 
				total_attack = attack_weapon+add+self;

			//npc攻击力调整，除以3
			if(this_object()->is("npc")){
				total_attack = total_attack/3;
			}
			//3.计算是否有暴击，如果有，计算加成暴击率之后的攻击值=所有攻击值总和*暴击/100	
			int baoji_a = this_object()->query_if_baoji(enemy);//返回一个整数值，为%的分子形式提供
			if(baoji_a==1){
				total_attack = (int)((total_attack)*150/100);
				int renxing = enemy->query_equip_add("renxing");
				if(renxing){
				//如果对方有韧性，则每40点韧性减少2%被暴击后的伤害，计算公式为：实际攻击值=暴击后的攻击值 - 暴击后的攻击 * (韧性/40) * 2%;为了尽量小的减少误差，故把公式转化为 实际攻击值=暴击后的攻击值 - (暴击后的攻击 * 韧性 *2×)/(40*100)  added by caijie 08/12/04
					total_attack -= (int)((total_attack * renxing * 2)/(40*100));
				}
			}
			////////////////加上被攻击者防御计算得到最终物理伤害值attack_a/////////////////////
			defend = enemy->query_defend_power();
			
			
			int division = this_object()->query_level()*120;//重新启用这个算法；
			if(this_object()->query_level()<70){
				division=8000;//保持之前的默认值
			}
			string u_profe = this_object()->query_profeId();
			if(u_profe=="yinggui"){//对影鬼的物理攻击加以修正，对方的防御分母扩大4倍，一般对方都有1万多防御
			//由于法师的魔法伤害是在此之后额外加的，多以对影鬼等物理攻击的职业做了加成。
				division=this_object()->query_level()*450;
				//werror("===========wuyaoxiuzheng:\n");
			}
			//werror("=======================division:"+division+" u_profe:"+u_profe+"\n");
			//werror("=======================enemy defend:"+defend+"\n");
			//新增加的属性 物理穿透，无视防御，直接加载最终结果上
			int wulichuantou_add=this_object()->query_equip_add("wulichuantou_add");
			attack_a = (total_attack - (int)(defend*total_attack)/division);
			attack_a+=wulichuantou_add;//增加物理穿透
			if(name_skill && skill_name_cn != "" && name_skill != "xueranjiangshan" && name_skill != "xueranjiangshan2") 
				attack_a = attack_a*3/2;//为了玩家能够接受，技能攻击加强1.5倍
			//技能的伤害百分比buff在这儿添加，由liaocheng于080827添加
			int per_tmp;
			if(this_object()->query_buff("spec_attack_buff",0) != "none"){
				per_tmp = this_object()->query_buff("spec_attack_buff",1);
			}
			if(this_object()->query_buff("70_skill_buff",0) == "lieshanmengji"){
				per_tmp += this_object()->query_buff("70_skill_buff",1);
			}
			if(per_tmp)
				attack_a += total_attack*per_tmp/100;
			//减少伤害的技能在这儿添加
			if(enemy->query_buff("70_skill_buff") == "baofengfeixue")
				attack_a = attack_a*70/100;
			//剑仙70级技能伤害反弹
			string reflect_desc = "";
			if(enemy->query_buff("70_skill_buff",0) == "fanzhuanyiji"){
				int attack_reflect = attack_a*30/100;
				attack_a = attack_a - attack_reflect;
				int life_left = this_object()->get_cur_life()-attack_reflect;
				if(life_left<0)
					life_left = 0;
				this_object()->set_life(life_left);
				reflect_desc = "("+attack_reflect+"被反弹)";
			}
			//再在这儿加入武器附加的魔法伤害(如+3火焰伤害)
			attack_huoyan_add = get_attack_mofa_add("huoyan_defend",this_object()->huo_add,enemy);
			attack_bingshuang_add = get_attack_mofa_add("bingshuang_defend",this_object()->bing_add,enemy);
			attack_fengren_add = get_attack_mofa_add("fengren_defend",this_object()->feng_add,enemy);
			attack_dusu_add = get_attack_mofa_add("dusu_defend",this_object()->du_add,enemy);
			//影鬼70级毒素伤害提高的效果
			if(this_object()->query_buff("70_skill_buff",0)=="cuidu")
				attack_dusu_add += attack_dusu_add/2;

			attack_a += attack_huoyan_add+attack_bingshuang_add+attack_fengren_add+attack_dusu_add;
			//现在的attack_a就是最终的伤害值
			if (attack_a<=0)
				attack_a=random(5);

			//在这儿加入buff的魔法盾吸收伤害liaocheng 07/4/9
			attack_fact = attack_a;
			string absorb_desc = "";
			if(enemy->query_buff("buff",0)=="absorb"){
				if((int)enemy->query_buff("buff",1) >= attack_a){
					int remain = (int)enemy->query_buff("buff",1) - attack_a;
					attack_fact = 0;
					absorb_desc = "(被吸收)";
					if(remain <= 0)
						enemy->clean_buff("buff");
					else
						enemy->set_buff("buff",1,remain);
				}
				else{
					attack_fact = attack_a - (int)enemy->query_buff("buff",1); 
					absorb_desc = "("+enemy->query_buff("buff",1)+"点被吸收)";
					enemy->clean_buff("buff");
				}
			}
			if(enemy->query_buff("buff2",0)=="absorb"){
				if((int)enemy->query_buff("buff2",1) >= attack_a){
					int remain = (int)enemy->query_buff("buff2",1) - attack_a;
					attack_fact = 0;
					absorb_desc = "(被吸收)";
					if(remain <= 0)
						enemy->clean_buff("buff2");
					else
						enemy->set_buff("buff2",1,remain);
				}
				else{
					attack_fact = attack_a - (int)enemy->query_buff("buff2",1); 
					absorb_desc = "("+enemy->query_buff("buff2",1)+"点被吸收)";
					enemy->clean_buff("buff2");
				}
			}
			//如果物理穿透大于零，则要在前端提示给玩家
			string chuantou_desc = "";
			if(wulichuantou_add>0){
				chuantou_desc = "【"+wulichuantou_add+" 点物理穿透】";
			}
			//在这里产生威胁值
			int hate=(int)(attack_a*skills_hate["test"]/100);
			enemy->flush_targets(this_object(),hate);
			if(!enemy->in_combat)
				enemy->_fight(this_object());
			////////////////////////战斗描述///////////////////////////////////////////////
			if(baoji_a==1) {
				if(skill_name_cn==""){
					tell_object(this_object(),"你紧握"+fight_action_desc+"，产生暴击效果，对"+enemy->query_name_cn()+"造成了"+attack_a+"点伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"，对你的攻击产生暴击效果，造成了"+attack_a+"点伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
				}
				else {
					tell_object(this_object(),"你紧握"+fight_action_desc+"施展"+skill_name_cn+"，产生暴击效果，对"+enemy->query_name_cn()+"造成了"+attack_a+"点伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"施展"+skill_name_cn+"，对你的攻击产生暴击效果，造成了"+attack_a+"点伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
					skills_level_check(name_skill);
				}
			}
			else {
				if(skill_name_cn==""){
					tell_object(this_object(),"你紧握"+fight_action_desc+"，对"+enemy->query_name_cn()+"造成了"+attack_a+"点伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"，对你造成了"+attack_a+"点伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//tell_object(enemy,this_object()->query_name_cn()+"紧握"+fight_action_desc+"，对你造成了"+attack_a+"点伤害"+absorb_desc+"\n");
				}
				else {
					tell_object(this_object(),"你紧握"+fight_action_desc+"施展"+skill_name_cn+"，对"+enemy->query_name_cn()+"造成了"+attack_a+"点伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+"施展"+skill_name_cn+"，对你造成了"+attack_a+"点伤害"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//熟练度提高,需要对方等级和自己相当，才会提升技能熟练度
					if(name_skill != "xueranjiangshan")
						skills_level_check(name_skill);
				}
			}
			int life_damage = enemy->get_cur_life()-attack_fact;
			if(life_damage<=0){
				//敌人死亡，则把敌人从仇恨列表中清除
				this_object()->clean_targets(enemy);
				//在这里加入死亡处理,killing判断是杀戮还是决斗
				if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
					enemy->set_life(1);
					tell_object(this_object(),"你在决斗中战胜了 "+enemy->query_name_cn()+" ！\n");
					tell_object(enemy,this_object()->query_name_cn()+"在决斗中战胜了你！\n");
					enemy->_clean_fight();
					_clean_fight();
				}
				else
					enemy->fight_die();
				enemy=0;
				return;
			}
			enemy->set_life(life_damage);
		}
		//攻击者命中对方，但被对方闪避了
		else{
			if(skill_name_cn==""){
				tell_object(this_object(),"你的这次攻击被对方闪避了过去!\n");
				tell_object(enemy,"你躲闪开了"+this_object()->query_name_cn()+"的这次攻击.\n");
			}
			else {
				tell_object(this_object(),"你的"+skill_name_cn+"被对方闪避了过去!\n");
				tell_object(enemy,"你躲闪开了"+this_object()->query_name_cn()+"的"+skill_name_cn+".\n");
			}
		}
	}
	//攻击者本次攻击没有命中
	else{
		if(skill_name_cn==""){
			tell_object(this_object(),"你的攻击没有击中对方!\n");
			tell_object(enemy,this_object()->query_name_cn()+"没有击中你。\n");
		}
		else {
			tell_object(this_object(),"你的"+skill_name_cn+"没有击中对方!\n");
			tell_object(enemy,this_object()->query_name_cn()+"的"+skill_name_cn+"没有击中你.\n");
		}
	}
}
//验证该perform是否能用
private int validate_perform(string arg){
	return 0;
}
private void heart_beat_action(){
	//在这儿也添加死亡处理过程，是为了处理由于dot而死亡的情况，dot是在自己的心跳中减去自己的血，
	//要是血减为零了，则表示自己死亡，但不能在自己的心跳中通过语句this_object()->fight_die()来处
	//理死亡，这样后台会报错。因此只有在敌人每次心跳时检查自己的血量，然后敌人调用
	//enemy->fight_die()来完成自己的死亡处理
	if(enemy&&enemy->get_cur_life()<=0&&enemy->in_combat){
		if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
			enemy->set_life(1);
			tell_object(this_object(),"你在决斗中战胜了 "+enemy->query_name_cn()+" ！\n");
			tell_object(enemy,this_object()->query_name_cn()+"在决斗中战胜了你！\n");
			enemy->_clean_fight();
			_clean_fight();
			enemy=0;
		}
		else{
			enemy->fight_die();
			enemy = 0;
		}
		return;
	}
	//自己死亡后将不作出任何动作，等待死亡处理
	//if(enemy&&this_object()->get_cur_life()<=0)
	//	return;

	enemy=this_object()->get_target(); //这句位置不对，要琢磨下
	if(enemy==0){
		//这个地方必须作处理，否则会出现在战斗状态下无法退出的问题。。。。
		_clean_fight();
		return;
	}
	else if(environment(this_object())!=environment(enemy)){
		if(this_object()->if_in_targets(enemy))
			this_object()->clean_targets(enemy);
		if(this_object()->if_targets_null())
			_clean_fight();
		return;
	}
	else{
		this_object()->timeCount++;
		if(this_object()->timeCold>0)
			this_object()->timeCold--;
		if(this_object()->eat_timeCold>0)
			this_object()->eat_timeCold--;
		//一般技能冷却时间
		if(this_object()->get_cur_life()>0&&this_object()->get_cur_life()<this_object()->life_max)
			this_object()->set_life(this_object()->get_cur_life()+this_object()->rase_life);
		if(this_object()->get_cur_mofa()>0&&this_object()->get_cur_mofa()<this_object()->mofa_max)
			this_object()->set_mofa(this_object()->get_cur_mofa()+this_object()->rase_mofa);
		if(this_object()->f_skills&&sizeof(this_object()->f_skills)){
			foreach(indices(this_object()->f_skills),string index){
				if(index&&sizeof(index)){
					this_object()->f_skills[index]--;
					if(this_object()->f_skills[index]<1)
						this_object()->f_skills[index]=1;
				}
			}
		}
		/////////////////////////////////////////////////////////
		//
		//在这儿可以读取自己身上的debuff映射表，来影响自身的状态
		//
		/////////////////////////////////////////////////////////
		//如果身上有dot状态
		if(this_object()->query_debuff("dot",0)!="none"){
			//掉血
			int tmp_life=this_object()->get_cur_life()-this_object()->query_debuff("dot",1);
			if(tmp_life<=0){
				this_object()->set_life(0);
				//敌人死亡，则把敌人从仇恨列表中清除
				enemy->clean_targets(this_object());
				return;
			}
			else {
				//持续时间减1
				this_object()->set_life(tmp_life);
				int dot_time=this_object()->query_debuff("dot",2)-1; 
				if(dot_time<=0) //dot持续时间结束，则去除dot状态
					this_object()->clean_debuff("dot");
				else
					this_object()->set_debuff("dot",2,dot_time);
			}
		}
		//如果身上有诅咒状态
		if(this_object()->query_debuff("curse",0)!="none"){
			int curse_time=this_object()->query_debuff("curse",2)-1;
			if(curse_time<=0){
				this_object()->clean_debuff("curse");
			}
			else
				this_object()->set_debuff("curse",2,curse_time);
		}
		if(this_object()->query_debuff("curse2",0)!="none"){
			int curse_time=this_object()->query_debuff("curse2",2)-1;
			if(curse_time<=0){
				this_object()->clean_debuff("curse2");
			}
			else
				this_object()->set_debuff("curse2",2,curse_time);
		}
		//如果身上有buff状态
		if(this_object()->query_buff("buff",0)!="none"){
			int buff_time=this_object()->query_buff("buff",2)-1;
			if(buff_time<=0)
				this_object()->clean_buff("buff");
			else
				this_object()->set_buff("buff",2,buff_time);
		}
		if(this_object()->query_buff("buff2",0)!="none"){
			int buff_time=this_object()->query_buff("buff2",2)-1;
			if(buff_time<=0)
				this_object()->clean_buff("buff2");
			else
				this_object()->set_buff("buff2",2,buff_time);
		}

		//在这里处理增益和降速诅咒的影响
		this_object()->attack_speed_main=this_object()->raw_attack_speed_main;	
		this_object()->attack_speed_other=this_object()->raw_attack_speed_other;
		if(this_object()->query_buff("buff",0)=="speed"){
			this_object()->attack_speed_main-=this_object()->query_buff("buff",1);
			this_object()->attack_speed_other-=this_object()->query_buff("buff",1);
			if(this_object()->attack_speed_main<=0)
				this_object()->attack_speed_main = 1;
			if(this_object()->attack_speed_other<=0)
				this_object()->attack_speed_other = 1;
		}
		if(this_object()->query_debuff("curse",0)=="speed"){
			this_object()->attack_speed_main+=this_object()->query_debuff("curse",1);
			this_object()->attack_speed_other+=this_object()->query_debuff("curse",1);
		}
		///////////////////////////////////////////////////////////////////////
		//               end
		///////////////////////////////////////////////////////////////////////
	}
	if(!in_combat)
		return;
	string cmd,arg;
	if(action&&sscanf(action,"%s %s",cmd,arg)==0)
		cmd=action;
	if(!present(enemy->name,environment(this_object()),0,this_object())){
		if(this_object()->if_in_targets(enemy))
			this_object()->clean_targets(enemy);
	}
	else if(cmd=="escape"){ 
		escape();
	}
	else if(cmd=="perform"){
		perform(arg);
	}
	//	else if(cmd=="surrender"){
	//		surrender(arg);
	//	}
	else{
		//boss技能攻击，liaocheng于07/6/18添加
		if(this_object()->_boss){
			foreach(indices(this_object()->boss_skills),string time_str){
				array(string) tmp_arr = time_str/"/";
				int first_time = (int)tmp_arr[0];
				int s_time = (int)tmp_arr[1];
				if(this_object()->timeCount==first_time || this_object()->timeCount%s_time == 0){
					boss_perform(this_object()->boss_skills[time_str]);
				}
			}
		}
		//////////////////////////////////////

		//设置自动释放主动技能	
		if(this_object()->skills_enable!=""&&this_object()->skills_enable_colddown!=0){
			if(autoPerforming==1){
				autoPerforming = 0;	
				perform(this_object()->skills_enable);
			}
			else if((this_object()->timeCount%this_object()->skills_enable_colddown)==0){
				perform(this_object()->skills_enable);
			}
		}
		//双手都拿武器
		if(this_object()->weapon_type=="both"){
			//判定时间
			if((this_object()->timeCount%this_object()->attack_speed_main)==0&&(this_object()->timeCount%this_object()->attack_speed_other)==0){
				attack(0,0,"single_main","");
				if(enemy!=0)
					attack(0,0,"other","");
			}
			else if((this_object()->timeCount==1)||((this_object()->timeCount%this_object()->attack_speed_main)==0)){
				attack(0,0,"single_main","");
			}
			else if((this_object()->timeCount%this_object()->attack_speed_other)==0){
				attack(0,0,"other","");
			}
		}
		else if(this_object()->weapon_type=="double_main"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_main==0){
				attack(0,0,"double_main","");
			}
		}
		else if(this_object()->weapon_type=="single_main"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_main==0){
				attack(0,0,"single_main","");
			}
		}
		else if(this_object()->weapon_type=="other"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_other==0){
				attack(0,0,"other","");
			}
		}
		else if(this_object()->weapon_type=="none"){
			attack(0,0,"single_main","");
		}
		if(enemy && environment(this_object())==environment(enemy))
			if(enemy->first_fight == 0 || !enemy->in_combat){
				enemy->_fight(this_object());
				enemy->first_fight = 1;
			}
	}
	set_action("attack");
}

void set_action(string _action){
	action=_action;
}

int _fight(object _enemy){
	if(this_object()->hind == 1) 
		this_object()->hind = 0;
	if(this_object()->query_buff("spec",0) == "hind"){
		this_object()->clean_buff("spec");
		m_delete(this_object()["/danyao"],"spec");
	}
	if(!in_combat){ //如果自己在非战斗状态，则是刚开始战斗，需要得到战斗快照
		this_object()->sucide = 0;
		enemy=_enemy;
		if(this_object()->is("npc")){
			//如果是城主,受到攻击会发出通告
			if(this_object()->query_npc_type()=="city_lord"){
				object env = environment(this_object());
				string city_name = env->query_belong_to();
				string city_name_cn = "";
				if(city_name=="xiqicheng")
					city_name_cn = "西岐城";
				else if(city_name=="chaogecheng")
					city_name_cn = "朝歌城";
				string notice = "战况！"+city_name_cn+"，"+this_object()->query_name_cn()+"遭到了攻击！\n";
				CITYD->notice_update(notice);
			}		
			//组队记录
			this_object()->term_who_fight_npc = enemy->query_term();
			//谁先开始的攻击，掉落物品属于谁
			this_object()->who_fight_npc = enemy->query_name();
		}
		//敌人的仇恨列表中加入自己
		this_object()->flush_targets(enemy,1); //初始仇恨值为1
		in_combat=1;
		action="attack";
		//初始化战斗快照
		//当前战斗玩家装备武器的类型,速度
		this_object()->timeCount=0;//战斗时间计数
		this_object()->timeCold=0; //法术公共冷却时间
		this_object()->eat_timeCold=0; //法术公共冷却时间
		this_object()->rase_life=this_object()->query_equip_add("rase_life_add"); //战斗生命回复
		this_object()->rase_mofa=this_object()->query_equip_add("rase_mofa_add"); //战斗魔法回复
		this_object()->is_both_weapons = 0;  //是否为双武器
		this_object()->cur_main_weapon_name ="";//主手武器名
		this_object()->cur_other_weapon_name = "";//副手武器名
		this_object()->weapon_type = "";//武器类型,主,副,双手
		this_object()->attack_speed_main = 0;//主手速度
		this_object()->attack_speed_other = 0;//副手速度
		this_object()->raw_attack_speed_main = 0;//主手速度
		this_object()->raw_attack_speed_other = 0;//副手速度
		this_object()->main_attack_attri_add=0; //主手武器附加的武器伤害 
		this_object()->main_attack_attri_add_per=0; //主手武器增加的武器伤害百分比
		this_object()->other_attack_attri_add=0; //副手.. 
		this_object()->other_attack_attri_add_per=0; //副手..
		//主手附加魔法伤害初始化
		this_object()->huo_add=this_object()->query_equip_add("attack_huoyan");
		this_object()->bing_add=this_object()->query_equip_add("attack_bingshuang");
		this_object()->feng_add=this_object()->query_equip_add("attack_fengren");
		this_object()->du_add=this_object()->query_equip_add("attack_dusu");
		this_object()->spec_add=0;//this_object()->query_equip_add("attack_spec");

		//技能战斗快照20070131////////////////////////////
		//([skill_name:skill_limit_time])
		//this_object()->f_skills = ([]);
		//初始化debuff映射表
		/*
		   this_object()->set_debuff("dot",0,"none");
		   this_object()->set_debuff("dot",1,0);
		   this_object()->set_debuff("dot",2,0);
		   this_object()->set_debuff("curse",0,"none");
		   this_object()->set_debuff("curse",1,0);
		   this_object()->set_debuff("curse",2,0);
		//初始化buff映射表
		this_object()->set_buff("buff",0,"none");
		this_object()->set_buff("buff",1,0);
		this_object()->set_buff("buff",2,0);
		 */
		//描述
		fight_desc_arg_main=query_fight_type();
		items = this_object()->query_equip();//[string:object]
		if(items["single_main_weapon"]&&items["single_other_weapon"]){
			this_object()->is_both_weapons = 1;
			this_object()->weapon_type = "both";//这里的weapon_type是指武器的装备情况
			//获得武器的攻速
			this_object()->raw_attack_speed_main = items["single_main_weapon"]->query_speed_power();	
			this_object()->raw_attack_speed_other = items["single_other_weapon"]->query_speed_power();	
			//获得武器的名字
			this_object()->cur_main_weapon_name = items["single_main_weapon"]->query_name_cn();
			this_object()->cur_other_weapon_name = items["single_other_weapon"]->query_name_cn();
			//获得武器的伤害附加(附加属性)
			//伤害附加
			this_object()->set_attack_attri_add("main",items["single_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add("other",items["single_other_weapon"]->query_attack_add());
			//伤害百分比附加
			this_object()->set_attack_attri_add_per("main",items["single_main_weapon"]->query_weapon_attack_add());
			this_object()->set_attack_attri_add_per("other",items["single_other_weapon"]->query_weapon_attack_add());

			//获得武器所属大类：jian，dao，qiang等等
			if(fight_desc_arg_main=="") {
				fight_desc_arg_main = items["single_main_weapon"]->query_item_weapon_type();
				fight_desc_arg_other = items["single_other_weapon"]->query_item_weapon_type();
			}
		}
		else if(items["double_main_weapon"]){
			this_object()->weapon_type = "double_main";
			this_object()->raw_attack_speed_main = items["double_main_weapon"]->query_speed_power();
			this_object()->cur_main_weapon_name = items["double_main_weapon"]->query_name_cn();
			//主手双手伤害附加
			this_object()->set_attack_attri_add("main",items["double_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("main",items["double_main_weapon"]->query_weapon_attack_add());

			//描述
			if(fight_desc_arg_main=="")
				fight_desc_arg_main = items["double_main_weapon"]->query_item_weapon_type();
		}
		else if(items["single_main_weapon"]){
			this_object()->weapon_type = "single_main";
			this_object()->raw_attack_speed_main = items["single_main_weapon"]->query_speed_power();
			this_object()->cur_main_weapon_name = items["single_main_weapon"]->query_name_cn();
			//主手单手武器伤害附加
			this_object()->set_attack_attri_add("main",items["single_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("main",items["single_main_weapon"]->query_weapon_attack_add());

			if(fight_desc_arg_main=="")
				fight_desc_arg_main = items["single_main_weapon"]->query_item_weapon_type();
		}
		else if(items["single_other_weapon"]){
			this_object()->weapon_type = "other";
			this_object()->raw_attack_speed_other = items["single_other_weapon"]->query_speed_power();
			this_object()->cur_other_weapon_name = items["single_other_weapon"]->query_name_cn();
			//副手伤害附加
			this_object()->set_attack_attri_add("other",items["single_other_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("other",items["single_other_weapon"]->query_weapon_attack_add());

			//描述
			if(fight_desc_arg_main=="")
				fight_desc_arg_other = items["single_other_weapon"]->query_item_weapon_type();
		}
		else{
			this_object()->weapon_type = "none";
			this_object()->raw_attack_speed_main = 1; 
			this_object()->cur_main_weapon_name = "抡起拳头";
			if(fight_desc_arg_main=="")
				fight_desc_arg_main = "none";
		}
		//自动释放的技能
		object sk;
		if(this_object()->skills_enable&&sizeof(this_object()->skills_enable)){
			autoPerforming = 1;
			sk = (object)MUD_SKILLSD[this_object()->skills_enable];
			this_object()->skills_enable_colddown = sk->query_s_delayTime()+1;
		}
	}
	else{ //已处于战斗状态了，则把对方加入到自己的仇恨列表中 
		this_object()->flush_targets(_enemy,1);
	}
	//开始战斗心跳
	if(query_heart_beat()==0){
		set_heart_beat(1);
		tmp_heart_beat=1;
	}
}

//由liaocheng于 07/1/30添加
//this_object()->用于设置char.pike中战斗快照的各种魔法附加伤害
int get_attack_mofa_add(string type,int attack,object enemy){
	int tmp1,tmp2;
	if(attack){
		if((tmp1=enemy->query_equip_add(type))||(tmp2=enemy->query_equip_add("all_mofa_defend")))
			return attack-(int)(attack*(tmp1+tmp2)/400);
		else 
			return attack;
	}
	else return 0;
}

int kill(string|object _enemy,int count){
	object ob=present(_enemy,environment(this_object()),count,this_object());
	if(ob){
		if(!in_combat)//{
			killing=1;
		_fight(ob);
		if(ob->first_fight == 1)
			ob->_fight(this_object());
		//ob->kill_notify(this_object());
		return 1;
		//}
		//else
		//	return 0;
	}
}
int fight(string|object _enemy,int count,int flag){
	object ob=present(_enemy,environment(this_object()),count,this_object());
	if(ob){
		if(ob->in_combat){
			tell_object(this_object(),"你要切磋的人正在战斗中，请稍候再试。\n[返回:look]\n");
			return 0;
		}
		if(flag){
			//接受挑战者执行
			tell_object(ob,this_object()->query_name_cn()+"接受了你的挑战。\n");
			//设置决斗标示，因为帮战要求，由liaocheng于08/08/30添加 
			ob->kill_flag = 0;
			this_object()->kill_flag = 0;

			_fight(ob);
			ob->_fight(this_object());
			return 1;
		}
		else{
			//挑战发起者执行
			tell_object(this_object(),"你向"+ob->query_name_cn()+"发起了决斗邀请，请在原地等待对方的同意。\n[返回:look]\n");
			tell_object(ob,this_object()->query_name_cn()+"想和你决斗，如果愿意接受请接受挑战。[接受挑战:fight "+this_object()->query_name()+" "+count+" 1]\n[返回:look]\n");
		}

	}
	else
		tell_object(this_object(),"你要切磋的人不在当前场景，请跟他处于同一场景进行切磋。\n[返回:look]\n");
	return 0;
}
//固定显示当前攻击者和被攻击者生命法力状况
	string query_cur_life(){
		if(enemy==0)
			return "";
		string s = "";
		if(in_combat&&enemy!=0){
			//这里的生命显示
			s += "生命:"+this_object()->get_cur_life()+" | 法力:"+this_object()->get_cur_mofa()+"\n";
			//s += "生命:"+(this_object()->get_cur_life()==0?1:this_object()->get_cur_life())+" | 法力:"+this_object()->get_cur_mofa()+"\n";
			s += "--------\n";
			//s += "对方生命:"+(enemy->get_cur_life()==0?1:enemy->get_cur_life())+" | 对方目标:"+enemy->get_target_name()+"\n";
			s += "对方生命:"+enemy->get_cur_life()+" | 对方目标:"+enemy->get_target_name()+"\n";
			s += "--------\n";
		}
		return s;
	}
string query_fighting_msg(){
	string s = this_object()->drain_catch_tell(0,6);
	if(enemy==0){
		s+= "战斗结束了。\n[返回:look]\n";
	}
	return s;
}
string query_status(){
	string s = "";
	string more = "\n";
	if(this_object()->red_flag && environment(this_object())->query_room_type()=="city")
		more = "(可杀戮)\n";
	if(this_object()->in_combat && enemy)
		s += "交战中（"+this_object()->get_target_name()+"）";
	else
		s += "游荡中";
	return s+more;
}
/*	void attack_notify(object who){
	if(enemy==0)
	_fight(who);
	else if(who!=enemy)
	if(random(100)<50) enemy=who;
	}
	void kill_notify(object who){
	if(enemy==0)
	_fight(who);
	killing=1;
//tell_object(enemy,MUD_EMOTED->filter(killing_msg+"\n",this_object(),enemy,enemy));
}
 */
private string initer=(this_object()->add_heart_beat(heart_beat_action,1),"");
