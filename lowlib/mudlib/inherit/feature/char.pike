#include <globals.h>
#include <mudlib/include/mudlib.h>
#include <gamelib/include/gamelib.h>
#define SKILL_PATH ROOT "/gamelib/single/skills/"
#define FOOD_PATH ROOT "/gamelib/clone/item/food/"
#define WATER_PATH ROOT "/gamelib/clone/item/water/"
#define TOOLBAR_NUM 6
string who_fight_npc;
string term_who_fight_npc;



//跟随系统，由liaocheng于07/09/21添加
array(string) follow_me = ({});
string follow = "";

//快捷键系统，由liaocheng于07/04/16添加
//3个快捷栏属性 1-技能　2-食物 3-水 0-没有
//array toolbar = ({
array(mapping(string:int)) toolbar_key = ({});

// 快捷栏可能早于技能商店被打开；重启后按人物真实已学技能安全补载。
private object|zero query_toolbar_skill_object(string name)
{
	object|zero skill = 0;
	mixed load_err = 0;
	if(!name || name=="" || sizeof(name)>64 ||
	   search(name,"/")!=-1 || search(name,"..")!=-1 ||
	   !skills || !skills[name] || (int)skills[name][0]<=0)
		return 0;
	skill = MUD_SKILLSD[name];
	if(!skill){
		load_err = catch {
			skill = (object)(SKILL_PATH+name);
		};
		if(load_err)
			skill = 0;
	}
	return skill;
}

private int valid_toolbar_entry_name(string name)
{
	return !!name && name!="" && sizeof(name)<=64 &&
		search(name,"/")==-1 && search(name,"..")==-1;
}

private void ensure_toolbar_slots()
{
	while(sizeof(toolbar_key)<TOOLBAR_NUM)
		toolbar_key += ({(["none":0])});
	for(int i=0;i<TOOLBAR_NUM;i++)
		if(!mappingp(toolbar_key[i]))
			toolbar_key[i] = (["none":0]);
}

/**
 * 快捷栏配置页、战斗栏和设置命令共用同一套安全解析。
 * 返回空字符串表示旧档案中的对象已失效；调用方必须允许玩家取消配置。
 */
string query_toolbar_entry_name(string name,int flag)
{
	object|zero entry = 0;
	string display_name = "";
	mixed err = 0;
	if(!valid_toolbar_entry_name(name))
		return "";
	if(flag==1){
		entry = query_toolbar_skill_object(name);
		if(entry)
			display_name = (string)entry->query_name_cn();
		return display_name;
	}
	if(flag==2)
		err = catch { entry = clone(FOOD_PATH+name); };
	else if(flag==3)
		err = catch { entry = clone(WATER_PATH+name); };
	else
		return "";
	if(!err && entry)
		display_name = (string)entry->query_name_cn();
	if(entry)
		destruct(entry);
	return display_name;
}

int set_toolbar(string name,int num,int flag)
{
	if(valid_toolbar_entry_name(name) && num>=0 && num<TOOLBAR_NUM &&
	   flag>=1 && flag<=3){
		ensure_toolbar_slots();
		toolbar_key[num]=([name:flag]);
		return 1;
	}
	else
		return 0;
}
int clean_toolbar(int num)
{
	if(num>=0 && num<TOOLBAR_NUM){
		ensure_toolbar_slots();
		toolbar_key[num]=(["none":0]);
		return 1;
	}
	else
		return 0;
}
mapping(string:int) query_toolbar(int a)
{
	mapping(string:int) tmp = ([]);
	if(a<0 || a>=TOOLBAR_NUM)
		return tmp;
	ensure_toolbar_slots();
	tmp = toolbar_key[a];
	return tmp;	
}
string query_toolbar_cn()
{
	string s = "";
	int used = 0;
	for(int i=0;i<TOOLBAR_NUM;i++){
		mapping(string:int) toolbar_entry = query_toolbar(i);
		foreach(indices(toolbar_entry),string name){
			if(toolbar_entry[name]==0){
				/*s += "无";
				if(i!=2)
					s += "|";
				*/
				break;
			}
			else{
				used ++;
				string display_name = query_toolbar_entry_name(name,
					(int)toolbar_entry[name]);
				if(display_name!=""){
					s += "["+display_name+":use_toolbar "+i+"]";
					if(i!=TOOLBAR_NUM-1)
						s += "|";
				}
				break;
			}
		}
		//if(used == 3)//每3个一换行
		//	s +="|\n";
	}
	return s;
}
array(mapping(string:int)) query_toolbar_all()
{
	array(mapping(string:int)) tmp = ({});
	ensure_toolbar_slots();
	tmp = toolbar_key;
	return tmp;
}
string view_things_toolbar(int num)
{
	string s = "";
	array(object) items=all_inventory(this_object());                                          
	if(items&&sizeof(items)){
		foreach(items,object item){
			if(item->query_item_type()=="food") 
				s += "[("+item->amount+")"+item->query_name_cn()+":toolbar_set "+num+" "+item->query_name()+" 2]\n";
			if(item->query_item_type()=="water") 
				s += "[("+item->amount+")"+item->query_name_cn()+":toolbar_set "+num+" "+item->query_name()+" 3]\n";
			//if(item->query_danyao_type()=="sucide") 
			//	s += "[("+item->amount+")"+item->query_name_cn()+":toolbar_set "+num+" "+item->query_name()+" 4]\n";
		}
	}
	return s;
}

//用户兴奋剂系统////////////////////////////
//兴奋剂提高属性类型：({提高点数，持续时间，当前时间})
//将会在char的心跳和fight的心跳和察看身体状态的时候调用检查接口
//并判断时间限制，做出处理
//mapping(string:array) high_med = ([
//		"high_str":({0,0,0}),
//		"high_dex":({0,0,0})
//		]);
//用户兴奋剂系统////////////////////////////
//用户金钱系统////////////////////////////
//实际钱存储形式
int _account = 0;
//得到钱总数
int query_account(){
	return this_object()->_account;
}
	void set_account(int a){
		if(a>=0)
			this_object()->_account = a;
		else
			this_object()->_account = 0;
	}
//金钱存取控制，表现层
	int query_gold(){
		if(query_account()>0)
			return query_account()/100;
		else
			return 0;
	}
	int query_silver(){
		if(query_account()>0)
			return query_account()-(query_account()/100)*100;
		else
			return 0;
	}
//得到钱描述
string query_money_cn(){
	string rs = "";
	rs += "金："+query_gold()+"\n";
	rs += "银："+query_silver();
	return rs;
}
//增加钱总数
	void add_account(int add){
		if(add>=0)
			set_account(query_account()+add);
		if(query_account()<=0)
			set_account(0);
	}
//减少钱总数
	void del_account(int del){
		if(del>=0)
			set_account(query_account()-del);
		if(query_account()<=0)
			set_account(0);
	}
//支付钱
int pay_money(int val){
	if(val>query_account()){
		return 0;//身上金钱不够支付
	}
	else{
		del_account(val);
		return 1;//可以支付,并完成支付
	}
}
//增加钱
void add_money(int val){
	if(val>=0){
		add_account(val);
	}
}
//交易时候，钱的判断和提示
	int trade_money_judge(int val){
		if(val>query_account())
			return 0;//身上金钱不够支付
		else
			return 1;//可以支付
	}
//用户金钱系统////////////////////////////

//用户技能系统////////////////////////////
mapping(string:array) skills=([]);//([skill_name:({skill_level,skill_point})])
string skills_enable = "";//skill_name
int skills_enable_colddown = 0;

//用户辅助技能系统///////////////////////
//liaocheng于07/5/23添加
mapping(string:array) vice_skills=([]);
//临时的材料:个数映射表
mapping(string:int) material_m=([]);
//临时的锻造宝石加入信息表
mapping(string:array) baoshi_add=([]);
//熔炼的信息表
mapping(int:array) ronglian_list=([]);

//技能战斗快照20070131////////////////////////////
mapping(string:int) f_skills=([]);//([skill_name:skill_limit_time])
//战斗快照变量////////////////////////////
//在战斗中不变的属性可以放在这儿
int timeCold; //法术攻击的公共冷却时间
int timeCount;//战斗时间计数，
int eat_timeCold;//食用药物的冷却时间
int rase_life;//战斗生命回复
int rase_mofa;//战斗魔法回复
int is_both_weapons;//是否是双武器，用作命中惩罚liaocheng于07/4/16添加
string weapon_type;
string cur_main_weapon_name;
string cur_other_weapon_name;
int attack_speed_main;//主手速度,受到减速诅咒的影响
int attack_speed_other;//副手速度，受到减速诅咒的影响
int raw_attack_speed_main;//原始的主手速度，保持不变，
int raw_attack_speed_other;//原始的副手速度，保持不变
int main_attack_attri_add; //主手武器附加的武器伤害
int main_attack_attri_add_per; //主手武器增加的武器伤害百分比
int other_attack_attri_add; //副手.. 
int other_attack_attri_add_per; //副手..
//下面的是武器附加的魔法攻击造成的伤害(其值是已经处理了抗性带来的削弱的结果)，主要是由mudlib2/inher
// it/feature/fight.pike中attack()方法调用。另外，处理抗性的削弱是在attack()方法中调用get_attack_
// mofa_add()实现的
int huo_add;
int bing_add;
int feng_add;
int du_add;
int spec_add;

//玩家对敌人施放的减益魔法都会在玩家自身的debuff映射表里记录
// 格式为：debuff=([
//						"dot":({string name,int damage,int time_remain})
//						"curse":({string type,int value,int time_remain,})
//				  ])
//格式是固定的
//以后可以扩展几个curse或者dot状态
protected mapping(string:array(mixed)) debuff=([
		"dot":({"none",0,0}),
		"curse":({"none",0,0}),
		"curse2":({"none",0,0}),
		"70_skill_curse":({"none",0,0})
		]);

mixed query_debuff(string s,int n){
	return debuff[s][n];
}

void set_debuff(string s,int n,mixed val){
	debuff[s][n]=val;
}

void clean_debuff(string s){
	debuff[s][0]="none";
	debuff[s][1]=0;
	debuff[s][2]=0;
}

//增益魔法表，与debuff的curse是相反的
//格式: buff = ([
//					"buff":({string type,int value,int time_record})
//			   ])
protected mapping(string:array(mixed)) buff = ([
		"buff":({"none",0,0}),
		"buff2":({"none",0,0}),
		"team_guard":({"none",0,0}),
		"attri_base":({"none",0,0}),
		"attri_vice":({"none",0,0}),
		"attri_defend":({"none",0,0}),
		"attri_attack":({"none",0,0}),
		"attri_exp":({"none",0,0}), 
		"attri_honer":({"none",0,0}),
		"attri_luck":({"none",0,0}),
		"spec":({"none",0,0}),
		"te_exp":({"none",0,0}), 
		"te_honer":({"none",0,0}),
		"te_luck":({"none",0,0}),
		"te_attack":({"none",0,0}), 
		"te_vice":({"none",0,0}),
		"te_base":({"none",0,0}),
		"te_defend":({"none",0,0}),
		"spec_attack_buff":({"none",0,0}),
		"70_skill_buff":({"none",0,0}),
		"mianzhan":({"none",0,0}),    //免战
		"home_attack":({"none",0,0}),         //攻击力                all
		"home_luck":({"none",0,0}),           //幸运                  luck
		"home_base":({"none",0,0}),           //基本属性              luck
		"home_defend":({"none",0,0}),           //基本属性              luck
		]);

mixed query_buff(string s,int n){
	return buff[s][n];
}

void set_buff(string s,int n,mixed val){
	buff[s][n]=val;
}

void clean_buff(string s){
	buff[s][0]="none";
	buff[s][1]=0;
	buff[s][2]=0;
}

// 镇越的队伍护盾使用独立槽位，不覆盖队友已有的职业增益。
int apply_team_guard(int shield,int duration){
	if(shield<=0 || duration<=0 || get_cur_life()<=0)
		return 0;
	if(query_buff("team_guard",0)=="absorb" &&
	   (int)query_buff("team_guard",1)>=shield)
		return 0;
	set_buff("team_guard",0,"absorb");
	set_buff("team_guard",1,shield);
	set_buff("team_guard",2,duration);
	return 1;
}

int absorb_team_guard_damage(int damage){
	int shield;
	int absorbed;
	if(damage<=0 || query_buff("team_guard",0)!="absorb")
		return damage;
	shield = (int)query_buff("team_guard",1);
	if(shield<=0){
		clean_buff("team_guard");
		return damage;
	}
	absorbed = shield>=damage ? damage : shield;
	shield -= absorbed;
	damage -= absorbed;
	if(shield<=0)
		clean_buff("team_guard");
	else
		set_buff("team_guard",1,shield);
	tell_object(this_object(),"【越】山河壁为你吸收了"+absorbed+"点伤害。\n");
	return damage;
}

// 天象星痕是短时、只存在于当前战斗场景的服务端资源。
// 最多三层，15秒未刷新即失效；切换房间、离线或战斗结束都会清理。
int query_tianxiang_star_marks(){
	int marks;
	if(query_profeId()!="tianxiang")
		return 0;
	if((int)this_object()["/tmp/tianxiang_star_expire"]<=time())
		return 0;
	marks = (int)this_object()["/tmp/tianxiang_star_marks"];
	if(marks<0)
		marks = 0;
	if(marks>3)
		marks = 3;
	return marks;
}

int add_tianxiang_star_marks(int amount){
	int marks;
	if(query_profeId()!="tianxiang" || amount<=0)
		return 0;
	marks = query_tianxiang_star_marks()+amount;
	if(marks>3)
		marks = 3;
	this_object()["/tmp/tianxiang_star_marks"] = marks;
	this_object()["/tmp/tianxiang_star_expire"] = time()+15;
	return marks;
}

int consume_tianxiang_star_marks(){
	int marks = query_tianxiang_star_marks();
	clean_tianxiang_star_marks();
	return marks;
}

void clean_tianxiang_star_marks(){
	this_object()->m_delete_foruser("/tmp/tianxiang_star_marks");
	this_object()->m_delete_foruser("/tmp/tianxiang_star_expire");
}

// 灵医药契是短时、服务端持有的治疗资源。最多三层，二十秒未刷新失效。
int query_lingyi_medicine_pacts(){
	int pacts;
	if(query_profeId()!="lingyi")
		return 0;
	if((int)this_object()["/tmp/lingyi_medicine_pact_expire"]<=time())
		return 0;
	pacts = (int)this_object()["/tmp/lingyi_medicine_pacts"];
	if(pacts<0)
		pacts = 0;
	if(pacts>3)
		pacts = 3;
	return pacts;
}

int add_lingyi_medicine_pacts(int amount){
	int pacts;
	if(query_profeId()!="lingyi" || amount<=0)
		return 0;
	pacts = query_lingyi_medicine_pacts()+amount;
	if(pacts>3)
		pacts = 3;
	this_object()["/tmp/lingyi_medicine_pacts"] = pacts;
	this_object()["/tmp/lingyi_medicine_pact_expire"] = time()+20;
	return pacts;
}

int consume_lingyi_medicine_pacts(){
	int pacts = query_lingyi_medicine_pacts();
	clean_lingyi_medicine_pacts();
	return pacts;
}

void clean_lingyi_medicine_pacts(){
	this_object()->m_delete_foruser("/tmp/lingyi_medicine_pacts");
	this_object()->m_delete_foruser("/tmp/lingyi_medicine_pact_expire");
}

// 群攻战果只保存在当前人物对象内，既不写存档，也不接受客户端输入。
// 技能结束后保留十秒，让战斗小窗在最后一个目标死亡、战斗态清除后仍能展示。
private mapping(string:mixed) recent_aoe_battle_report = ([]);
private object|zero recent_aoe_battle_room = 0;
private int recent_aoe_battle_expire = 0;

private int can_record_recent_aoe_battle(){
	return search(({"lingyi","wuxiang","taiji"}),query_profeId())!=-1;
}

void clear_recent_aoe_battle_report(){
	recent_aoe_battle_report = ([]);
	recent_aoe_battle_room = 0;
	recent_aoe_battle_expire = 0;
}

void begin_recent_aoe_battle_report(string skill_name,string skill_name_cn){
	if(!can_record_recent_aoe_battle() || !environment(this_object())){
		clear_recent_aoe_battle_report();
		return;
	}
	recent_aoe_battle_report = ([
		"skill":skill_name || "",
		"skill_name":skill_name_cn || "群体技能",
		"targets":({}),
	]);
	recent_aoe_battle_room = environment(this_object());
	recent_aoe_battle_expire = time()+10;
}

void record_recent_aoe_battle_target(object target,int damage,int hit,
	int defeated,void|int revived){
	array(mapping) targets;
	int hp = 0;
	int hp_max = 0;
	if(!target || !recent_aoe_battle_report ||
	   recent_aoe_battle_expire<=time() ||
	   recent_aoe_battle_room!=environment(this_object()))
		return;
	targets = recent_aoe_battle_report["targets"];
	if(!targets)
		targets = ({});
	if(functionp(target->get_cur_life))
		hp = target->get_cur_life();
	if(functionp(target->query_life_max))
		hp_max = target->query_life_max();
	if(hp<0)
		hp = 0;
	targets += ({ ([
		"name":functionp(target->query_name) ? target->query_name() : "",
		"name_cn":functionp(target->query_name_cn) ?
			target->query_name_cn() : "未知目标",
		"hp":hp,
		"hp_max":hp_max,
		"damage":damage>0 ? damage : 0,
		"hit":hit ? 1 : 0,
		"defeated":defeated ? 1 : 0,
		"revived":revived ? 1 : 0,
	]) });
	recent_aoe_battle_report["targets"] = targets;
}

mapping(string:mixed) query_recent_aoe_battle_report(){
	mapping(string:mixed) result = ([]);
	array(mapping) targets = ({});
	if(!can_record_recent_aoe_battle() || !recent_aoe_battle_report ||
	   recent_aoe_battle_expire<=time() ||
	   !recent_aoe_battle_room ||
	   recent_aoe_battle_room!=environment(this_object()))
		return result;
	foreach((array(mapping))recent_aoe_battle_report["targets"],mapping target)
		targets += ({ target+([]) });
	result["skill"] = recent_aoe_battle_report["skill"];
	result["skill_name"] = recent_aoe_battle_report["skill_name"];
	result["targets"] = targets;
	result["remaining"] = recent_aoe_battle_expire-time();
	return result;
}

private int query_lingyi_revive_day_key(){
	mapping(string:int) now_time = localtime(time());
	return ((int)now_time["year"])*1000+(int)now_time["yday"];
}

// 新职业技能是五段制；达到第五段即为100%掌握。白名单既不接受人物
// 存档伪造的技能名，也避免HTTP状态只读查询期间按需加载技能对象。
private array(string) lingyi_mastery_skill_names = ({
	"lingzhen","yaoli","huichun","muxi","qingxin","huxin",
	"lingyu","huayu","yaowutianluo","yulu","baicaojue","ganlin",
	"xuming","cixinpudu","huimingtianlu","wanmuxinchun",
	"liuhehuichun",
});

int query_lingyi_mastered_skill_count(){
	int mastered = 0;
	if(query_profeId()!="lingyi" || !skills)
		return 0;
	foreach(lingyi_mastery_skill_names,string name){
		mixed learned = skills[name];
		if(arrayp(learned) && sizeof(learned) && (int)learned[0]>=5)
			mastered++;
	}
	return mastered;
}

int query_lingyi_auto_revive_max(){
	int mastered = query_lingyi_mastered_skill_count();
	if(mastered>=12)
		return 3;
	if(mastered>=8)
		return 2;
	if(mastered>=5)
		return 1;
	return 0;
}

int query_lingyi_auto_revive_used(){
	if(query_profeId()!="lingyi" ||
	   (int)this_object()["/plus/lingyi/revive_day_key"]!=
	   query_lingyi_revive_day_key())
		return 0;
	int used = (int)this_object()["/plus/lingyi/revive_used"];
	if(used<0)
		used = 0;
	return used;
}

int query_lingyi_auto_revive_remaining(){
	int remaining = query_lingyi_auto_revive_max()-
		query_lingyi_auto_revive_used();
	return remaining>0 ? remaining : 0;
}

mapping(string:int) query_lingyi_auto_revive_status(){
	int mastered = query_lingyi_mastered_skill_count();
	int maximum = query_lingyi_auto_revive_max();
	int used = query_lingyi_auto_revive_used();
	return ([
		"mastered":mastered,
		"unlock_need":5,
		"maximum":maximum,
		"used":used>maximum ? maximum : used,
		"remaining":maximum>used ? maximum-used : 0,
		"unlocked":maximum>0 ? 1 : 0,
	]);
}

// 只在人物真正进入死亡结算时调用。成功返回1，调用者必须立即停止后续
// 击杀奖励、经验/耐久惩罚、召唤清理和回城流程。
int try_lingyi_auto_revive(object killer){
	object env = environment(this_object());
	int maximum;
	int used;
	int life_restore;
	int mofa_restore;
	if(query_profeId()!="lingyi" || !this_object()->is("player") ||
	   !killer || !objectp(killer) || !env ||
	   environment(killer)!=env || this_object()->get_cur_life()>0 ||
	   !LOGICALZONED->can_action("combat",this_object(),killer) ||
	   this_object()->is("ghost") ||
	   this_object()->sucide || this_object()["/tmp/lingyi/revive_running"])
		return 0;
	if(functionp(env->query_room_type) && env->query_room_type()=="city")
		return 0;
	// 切磋只分胜负，不消耗每日复苏次数。
	if(functionp(killer->is) && killer->is("player") &&
	   this_object()->kill_flag==0 && killer->kill_flag==0)
		return 0;
	maximum = query_lingyi_auto_revive_max();
	used = query_lingyi_auto_revive_used();
	if(maximum<=0 || used>=maximum)
		return 0;
	this_object()["/tmp/lingyi/revive_running"] = 1;
	this_object()["/plus/lingyi/revive_day_key"] =
		query_lingyi_revive_day_key();
	// 先消费再恢复；后续任何提示或日志错误都不会复制次数。
	this_object()["/plus/lingyi/revive_used"] = used+1;
	this_object()->_clean_fight();
	if(killer && objectp(killer) && functionp(killer->clean_targets))
		killer->clean_targets(this_object());
	life_restore = this_object()->query_life_max()*25/100;
	mofa_restore = this_object()->query_mofa_max()*20/100;
	if(life_restore<1)
		life_restore = 1;
	if(mofa_restore<1)
		mofa_restore = 1;
	this_object()->set_life(life_restore);
	this_object()->set_mofa(mofa_restore);
	// 生命恢复完成后先解除重入锁；无连接的测试人物或日志
	// 文件故障不得把人物卡在“正在复苏”状态。
	this_object()->m_delete_foruser("/tmp/lingyi/revive_running");
	catch {
		foreach(all_inventory(env),object observer){
			if(observer && functionp(observer->is) && observer->is("player"))
				tell_object(observer,"【医】"+this_object()->query_name_cn()+
					"触发百炼复苏，在死亡前稳住生机（今日剩余"+
					query_lingyi_auto_revive_remaining()+"次）。\n");
		}
	};
	catch {
		string now = ctime(time());
		Stdio.append_file(ROOT+"/log/lingyi_revive.log",
			now[0..sizeof(now)-2]+"|"+this_object()->query_name()+
			"|killer="+killer->query_name()+"|used="+(used+1)+
			"|max="+maximum+"\n");
	};
	return 1;
}

// 无相心法（被动）：基于基础三系属性，让最高项的 50%
// 加成给非最高项。仅在结算（query_str/dex/think）时即时计算；不写入 base_save、
// 不参与装备穿戴门槛、不参与技能前置。最高项本身不加成，避免超过专精职业上限。
int query_balanced_heart_boost_percent(){
	int expires = (int)this_object()["/tmp/balanced/heart_expires"];
	int boost;
	if(expires<=time()){
		this_object()->m_delete_foruser("/tmp/balanced/heart_boost");
		this_object()->m_delete_foruser("/tmp/balanced/heart_expires");
		return 0;
	}
	boost = (int)this_object()["/tmp/balanced/heart_boost"];
	if(boost<0)
		return 0;
	if(boost>10)
		return 10;
	return boost;
}

int apply_balanced_heart_boost(int boost,int duration){
	string profe = query_profeId();
	if((profe!="wuxiang" && profe!="taiji") || boost<=0 || duration<=0)
		return 0;
	if(boost>10)
		boost = 10;
	this_object()["/tmp/balanced/heart_boost"] = boost;
	this_object()["/tmp/balanced/heart_expires"] = time()+duration;
	return 1;
}

int query_balanced_attr_percent(){
	int expires = (int)this_object()["/tmp/balanced/attr_expires"];
	int percent;
	if(expires<=time()){
		this_object()->m_delete_foruser("/tmp/balanced/attr_percent");
		this_object()->m_delete_foruser("/tmp/balanced/attr_expires");
		return 0;
	}
	percent = (int)this_object()["/tmp/balanced/attr_percent"];
	if(percent<0)
		return 0;
	if(percent>40)
		return 40;
	return percent;
}

int apply_balanced_attr_percent(int percent,int duration){
	string profe = query_profeId();
	if((profe!="wuxiang" && profe!="taiji") || percent<=0 || duration<=0)
		return 0;
	if(percent>40)
		percent = 40;
	if(query_balanced_attr_percent()>percent)
		return 0;
	this_object()["/tmp/balanced/attr_percent"] = percent;
	this_object()["/tmp/balanced/attr_expires"] = time()+duration;
	return 1;
}

int query_balanced_attr_bonus(int current){
	int percent = query_balanced_attr_percent();
	if(current<=0 || percent<=0)
		return 0;
	return current*percent/100;
}

int query_wuxiang_heart_bonus(string attr){
	int s_v;
	int d_v;
	int t_v;
	int highest;
	int current;
	int heart_percent = 50+query_balanced_heart_boost_percent();
	if(!functionp(this_object()->query_profeId) ||
	   this_object()->query_profeId()!="wuxiang")
		return 0;
	s_v = _str > 0 ? _str : 0;
	d_v = _dex > 0 ? _dex : 0;
	t_v = _think > 0 ? _think : 0;
	highest = s_v;
	if(d_v > highest)
		highest = d_v;
	if(t_v > highest)
		highest = t_v;
	if(highest <= 0)
		return 0;
	// 隐藏职业升级时三项基础值同步；完全相等时必须让心法生效，
	// 否则无相从 1 级到满级都永远得到 0 加成。
	if(s_v==d_v && d_v==t_v)
		return highest*heart_percent/100;
	if(attr=="str")
		current = s_v;
	else if(attr=="dex")
		current = d_v;
	else if(attr=="think")
		current = t_v;
	else
		return 0;
	if(current >= highest)
		return 0;
	return highest*heart_percent/100;
}

// 太极心法（被动）：基于基础三系属性，让最高项的 65% 加成给非最高项
// （vs 无相 50%）。同样只在结算时即时计算，不参与装备/技能前置。
int query_taiji_heart_bonus(string attr){
	int s_v;
	int d_v;
	int t_v;
	int highest;
	int current;
	int heart_percent = 65+query_balanced_heart_boost_percent();
	if(!functionp(this_object()->query_profeId) ||
	   this_object()->query_profeId()!="taiji")
		return 0;
	s_v = _str > 0 ? _str : 0;
	d_v = _dex > 0 ? _dex : 0;
	t_v = _think > 0 ? _think : 0;
	highest = s_v;
	if(d_v > highest)
		highest = d_v;
	if(t_v > highest)
		highest = t_v;
	if(highest <= 0)
		return 0;
	// 太极同样是三项同步成长；完全相等时按对称心法结算三项。
	if(s_v==d_v && d_v==t_v)
		return highest*heart_percent/100;
	if(attr=="str")
		current = s_v;
	else if(attr=="dex")
		current = d_v;
	else if(attr=="think")
		current = t_v;
	else
		return 0;
	if(current >= highest)
		return 0;
	return highest*heart_percent/100;
}
string query_wuxiang_avatar_day_key()
{
	string now = ctime(time());
	string mon = now[4..6];
	string day = now[8..9];
	if(day[0]==' ')
		day = day[1..];
	return mon+day;
}
int query_wuxiang_avatar_used()
{
	string day_key = query_wuxiang_avatar_day_key();
	if((string)this_object()["/plus/wuxiang/avatar_day_key"] != day_key)
		return 0;
	return (int)this_object()["/plus/wuxiang/avatar_used"];
}
int try_wuxiang_avatar_revive(object killer){
	object env = environment(this_object());
	int life_restore;
	if(query_profeId()!="wuxiang" || !this_object()->is("player") ||
	   !killer || !objectp(killer) || !env ||
	   environment(killer)!=env || this_object()->get_cur_life()>0 ||
	   !LOGICALZONED->can_action("combat",this_object(),killer) ||
	   this_object()->is("ghost") ||
	   this_object()->sucide || this_object()["/tmp/wuxiang/avatar_running"])
		return 0;
	if((int)this_object()->query_level() < 120)
		return 0;
	if(functionp(env->query_room_type) && env->query_room_type()=="city")
		return 0;
	if(functionp(killer->is) && killer->is("player") &&
	   this_object()->kill_flag==0 && killer->kill_flag==0)
		return 0;
	if(query_wuxiang_avatar_used() >= 1)
		return 0;
	this_object()["/tmp/wuxiang/avatar_running"] = 1;
	this_object()["/plus/wuxiang/avatar_day_key"] =
		query_wuxiang_avatar_day_key();
	this_object()["/plus/wuxiang/avatar_used"] =
		query_wuxiang_avatar_used()+1;
	this_object()->_clean_fight();
	if(killer && objectp(killer) && functionp(killer->clean_targets))
		killer->clean_targets(this_object());
	life_restore = this_object()->query_life_max()*25/100;
	if(life_restore<1)
		life_restore = 1;
	this_object()->set_life(life_restore);
	this_object()->m_delete_foruser("/tmp/wuxiang/avatar_running");
	catch {
		foreach(all_inventory(env),object observer){
			if(observer && functionp(observer->is) && observer->is("player"))
				tell_object(observer,"【无】"+this_object()->query_name_cn()+
					"触发无相化身，在死亡前化险为夷（今日已用完）。\n");
		};
	};
	catch {
		string now = ctime(time());
		Stdio.append_file(ROOT+"/log/wuxiang_avatar.log",
			now[0..sizeof(now)-2]+"|"+this_object()->query_name()+
			"|killer="+killer->query_name()+"\n");
	};
	return 1;
}

// === 太极·生生不息（被动自复活）===
// 5 分钟冷却（timestamp），致命伤自动触发，恢复 30% 生命。
// PVP 可触发（与无相化身不同，太极的 PVP 豁免更宽：仅自杀/已是鬼魂/城内不触发）。
int query_taiji_self_revive_cooldown(){ return 300; }  // 5 分钟
int query_taiji_self_revive_remaining(){
	int last = (int)this_object()["/plus/taiji/self_revive_at"];
	if(last <= 0)
		return 0;
	int elapsed = time() - last;
	int cd = query_taiji_self_revive_cooldown();
	if(elapsed >= cd)
		return 0;
	return cd - elapsed;
}
int try_taiji_self_revive(object killer){
	object env = environment(this_object());
	int life_restore;
	if(query_profeId()!="taiji" || !this_object()->is("player") ||
	   !killer || !objectp(killer) || !env ||
	   environment(killer)!=env || this_object()->get_cur_life()>0 ||
	   !LOGICALZONED->can_action("combat",this_object(),killer) ||
	   this_object()->is("ghost") ||
	   this_object()->sucide || this_object()["/tmp/taiji/self_revive_running"])
		return 0;
	if((int)this_object()->query_level() < 1)
		return 0;
	if(functionp(env->query_room_type) && env->query_room_type()=="city")
		return 0;
	// 5 分钟冷却（timestamp 而非 day-key，与无相化身每日刷新不同）
	if(query_taiji_self_revive_remaining() > 0)
		return 0;
	this_object()["/tmp/taiji/self_revive_running"] = 1;
	this_object()["/plus/taiji/self_revive_at"] = time();
	this_object()->_clean_fight();
	if(killer && objectp(killer) && functionp(killer->clean_targets))
		killer->clean_targets(this_object());
	life_restore = this_object()->query_life_max()*30/100;
	if(life_restore<1)
		life_restore = 1;
	this_object()->set_life(life_restore);
	this_object()->m_delete_foruser("/tmp/taiji/self_revive_running");
	catch {
		foreach(all_inventory(env),object observer){
			if(observer && functionp(observer->is) && observer->is("player"))
				tell_object(observer,"【极】"+this_object()->query_name_cn()+
					"触发太极·生生不息，在死亡边缘逆转重生（5 分钟内不能再触发）。\n");
		};
	};
	catch {
		string now = ctime(time());
		Stdio.append_file(ROOT+"/log/taiji_revive.log",
			now[0..sizeof(now)-2]+"|self|"+this_object()->query_name()+
			"|killer="+killer->query_name()+"\n");
	};
	return 1;
}

// === 太极·复阴（主动复活同房同队鬼魂队友）===
// 由 taiji_fuyin 命令调用。独立 5 分钟冷却（与自复活互不干扰）。
int query_taiji_team_revive_cooldown(){ return 300; }
int query_taiji_team_revive_remaining(){
	int last = (int)this_object()["/plus/taiji/team_revive_at"];
	if(last <= 0)
		return 0;
	int elapsed = time() - last;
	int cd = query_taiji_team_revive_cooldown();
	if(elapsed >= cd)
		return 0;
	return cd - elapsed;
}
int try_taiji_team_revive(object caster, object target){
	object env_c;
	object env_t;
	string team_c;
	string team_t;
	int life_restore;
	if(!caster || !target || !objectp(caster) || !objectp(target))
		return 0;
	if(caster->query_profeId()!="taiji" || !caster->is("player"))
		return 0;
	if(!target->is("player") || !target->is("ghost"))
		return 0;
	env_c = environment(caster);
	env_t = environment(target);
	if(!env_c || env_c != env_t)
		return 0;
	// 必须是同队伍
	team_c = (string)caster->query_term();
	team_t = (string)target->query_term();
	if(team_c == "" || team_c == "noterm" || team_c != team_t)
		return 0;
	// 不能复活自己（自复活走 try_taiji_self_revive）
	if(caster == target)
		return 0;
	if(query_taiji_team_revive_remaining_cast(caster) > 0)
		return 0;
	// 先恢复目标并验证状态，成功后才消费冷却。
	life_restore = target->query_life_max()*50/100;
	if(life_restore<1)
		life_restore = 1;
	mixed revive_err = catch {
		target->set_life(life_restore);
		target->relive();
	};
	if(revive_err || target->get_cur_life()<1 || target->is("ghost"))
		return 0;
	caster["/plus/taiji/team_revive_at"] = time();
	catch {
		foreach(all_inventory(env_c),object observer){
			if(observer && functionp(observer->is) && observer->is("player"))
				tell_object(observer,"【极】"+caster->query_name_cn()+
					"施展太极·复阴，"+target->query_name_cn()+
					"自幽冥归来（5 分钟内不能再施）。\n");
		};
	};
	catch {
		string now = ctime(time());
		Stdio.append_file(ROOT+"/log/taiji_revive.log",
			now[0..sizeof(now)-2]+"|team|caster="+caster->query_name()+
			"|target="+target->query_name()+"\n");
	};
	return 1;
}
int query_taiji_team_revive_remaining_cast(object caster){
	int last;
	if(!caster)
		return 0;
	last = (int)caster["/plus/taiji/team_revive_at"];
	if(last <= 0)
		return 0;
	int elapsed = time() - last;
	int cd = query_taiji_team_revive_cooldown();
	if(elapsed >= cd)
		return 0;
	return cd - elapsed;
}
void reset_buff(){
	clean_buff("buff");
	clean_buff("buff2");
	clean_buff("team_guard");
	clean_buff("attri_base");
	clean_buff("attri_vice");
	clean_buff("attri_defend");
	clean_buff("attri_attack");
	clean_buff("attri_exp");
	clean_buff("attri_luck");
	clean_buff("attri_honer");
	clean_buff("spec");
}

//并提供相应的接口.供fight.pike中_fight()方法调用
//由liaocheng于07/1/29添加
//供外部调用的设置main_attack_attri_add和other_attack_attri_add成员变量的接口
void set_attack_attri_add(string type,int val)
{
	if(type=="main") {
		main_attack_attri_add=val;
	}
	else if(type=="other") {
		other_attack_attri_add=val;
	}
}

//供外部调用的设置main_attack_attri_add_per和other_attack_attri_add_per成员变量的接口
void set_attack_attri_add_per(string type, int val)
{
	if(type=="main") {
		main_attack_attri_add_per=val;
	}
	else if(type=="other") {
		other_attack_attri_add_per=val;
	}
}
//////////////////////////////////////////

//由liaocheng于07/3/1添加
//仇恨系统///////////////////////////////
object|zero first_target;//记录第一仇恨目标
mapping(object:int) targets =([]); //仇恨列表，npc和玩家都会有，但处理过程却是不同的
//接口，用于重值仇恨列表，也就是仇恨列表清零
void reset_targets()  
{
	first_target=0;
	targets=([]);
}
//接口，用于更新仇恨列表,没在仇恨列表的则加入，在仇恨列表的则改变其仇恨值
void flush_targets(object ob, int val)
{
	if(ob&&val>0){
		//如果不在仇恨列表，则加入
		if(targets[ob]==0) 
			targets[ob]=val;
		//在，则改变其仇恨值
		else 
			targets[ob]+=val;
	}
}
//接口，用于获得攻击目标
//返回object表示有目标，并且已设置为first_target
//返回0表示已经没有目标
object get_target()
{
	int max=0;
	object|zero tmp_ob=0;
	array(object) stale_targets=({});
	object|zero current_room=environment(this_object());
	if(targets){
		// 只从同房间存活目标中选择，移动或死亡目标在本轮清理。
		foreach(indices(targets),object ob) {
			if(!ob || ob->get_cur_life()<=0 || !current_room ||
			   environment(ob)!=current_room){
				stale_targets += ({ob});
			}
			else if(targets[ob]>max){
				tmp_ob=ob;
				max=targets[ob];
			}
		}
		foreach(stale_targets,object stale)
			m_delete(targets,stale);
		first_target=tmp_ob;
		return tmp_ob;
	}
	return 0;
}

array(object) get_all_targets()
{
	// 与单目标选择共享清理规则，防止 AOE 继续命中已死亡或已换房目标。
	get_target();
	array(object) rtn = sort(indices(targets));
	if(rtn && sizeof(rtn))
		return rtn;
	else
		return 0;
}
//接口，用于返回是否targets为空
//返回1，表示targets为空了
//返回0，表示targets不为空
int if_targets_null()
{
	int n=sizeof(targets);
	if(n==0)
		return 1;
	else return 0;
}
//接口，用于检查对象是否在targets中
//返回1：在
//	  0：不在
int if_in_targets(object ob)
{
	if(ob&&targets[ob])
		return 1;
	else 
		return 0;
}
//接口，用于清除仇恨列表中的某项
void clean_targets(object ob)
{
	if(ob&&targets[ob]){
		m_delete(targets,ob);
		if(first_target==ob)
			first_target=0;
	}
}

//接口，用于显示怪物的目标
string get_target_name()
{
	object ob=first_target;
	if(ob){
		return ob->query_name_cn();
	}
	else 
		return "";
}
//////////////////////////////////////////////////
string leave_direction;//离开房间或者逃跑的路线
//还有部分通用的方法调用
int gameage;//年龄
read_write(gameage);
string nickname;//昵称
read_write(nickname);
int bangid;
int hind;
int can_spec;//学习特殊技能的标示，如影鬼的隐遁，剑仙的御剑术
int sucide; //判断是否是嗑药自杀的
string fb_id;//暂时记录副本id
int set_pic_ok;//记录玩家是否已更换过头像
string roomchatid;
int first_fight;
int life;//生命值，为0时死亡
int life_max;//最大生命值，人物生命值最大限制，与级别和属性变化运算
int mofa;//法力值，释放技能所需要的数值
int mofa_max;//法力最大值，释放技能所需要的数值的最大值，动态运算变化
int _str;//力量，随级别提升而变化，物品也有此属性
int _dex;//敏捷，随级别提升而变化，物品也有此属性
int _think;//智力，随级别提升而变化，物品也有此属性
int _lunck;//幸运，随级别提升而变化
int _appear;//容貌值，随级别提升而变化，或者物品装饰改变
////////////////////////////////////////////////
string kind_cn;
string unit;
string gender;//性别描述:男,女,雄,雌,公,母
string pronoun;//性别称谓:他,她,它
string sex;//图片显示Key值，male,female
int disabled_login;//是否被屏蔽登陆
int disabled_post;//是否被屏蔽发言
int disabled_action;//是否被屏蔽作命令动作

int can_speak;//是否可以沟通
int can_kill;//是否可以杀戮
int can_fight;//是否可以切磋
int can_get_skin;//是否可扒皮
int can_cut;//是否可以将尸体切割，以便作任务物品或合成装备道具等
string attitude;//性格：主动狂暴，或者和平
int red_flag;//红名，成战中使用

//新加精力系统，用来控制自动战斗
int jingli = 100;
int query_jingli(){return jingli;}
void set_jingli(int value){
	if(value<=0)
		value = 0;
	else if(value>=100)
		value = 100;
	jingli = value;
}
//新加精力系统，用来控制自动战斗

//种族id:种族中文名(其实就是两个对立阵营)//////////////////////////
string raceId;
read_write(raceId);
protected array(string) raceKindList=({"human","monst","third"});
protected array(string) raceNameList=({"人类","妖魔","中立"});
protected mapping(string:string) races=([
		raceKindList[0]:raceNameList[0],
		raceKindList[1]:raceNameList[1],
		raceKindList[2]:raceNameList[2]
		]);
/////////////////////////////////////////////////////////////////////
// 职业id:职业中文名
//人类职业：jianxian:剑仙 yushi:羽士 zhuxian:诛仙
//妖魔职业：kuangyao:狂妖 wuyao:巫妖 yinggui:影鬼
//npc职业->相当于npc的类别：人形：humanlike 野兽：beast 飞禽：bird
//鱼：fish 两栖动物：amphibian 昆虫：bugs
string profeId;
read_write(profeId);
protected array(string) profeKindList=({"jianxian","yushi","zhuxian","kuangyao","wuyao","yinggui","fangshi","zhenyue","tianxiang","lingyi","wuxiang","taiji","humanlike","beast","bird","fish","amphibian","bugs","dog"});
protected array(string) profeNameList=({"剑仙","羽士","诛仙","狂妖","巫妖","影鬼","方士","镇越","天象","灵医","无相","太极","人形","野兽","飞禽","鱼","两栖动物","昆虫","狗"});
protected mapping(string:string) profes=([
		profeKindList[0]:profeNameList[0],
		profeKindList[1]:profeNameList[1],
		profeKindList[2]:profeNameList[2],
		profeKindList[3]:profeNameList[3],
		profeKindList[4]:profeNameList[4],
		profeKindList[5]:profeNameList[5],
		profeKindList[6]:profeNameList[6],
		profeKindList[7]:profeNameList[7],
		profeKindList[8]:profeNameList[8],
		profeKindList[9]:profeNameList[9],
		profeKindList[10]:profeNameList[10],
		profeKindList[11]:profeNameList[11],
		profeKindList[12]:profeNameList[12],
		profeKindList[13]:profeNameList[13],
		profeKindList[14]:profeNameList[14],
		profeKindList[15]:profeNameList[15],
		profeKindList[16]:profeNameList[16],
		profeKindList[17]:profeNameList[17],
		profeKindList[18]:profeNameList[18]
		]);
////////////////阵营/////////////////////////////////////////////////
string query_race_cn(string rid){
	return races[rid];
}

int query_threat_for(object ob)
{
	if(!ob || !targets[ob])
		return 0;
	return targets[ob];
}

int query_max_threat()
{
	int result = 0;
	object|zero current_room = environment(this_object());
	foreach(indices(targets),object target){
		if(target && target->get_cur_life()>0 && current_room &&
		   environment(target)==current_room && targets[target]>result)
			result = targets[target];
	}
	return result;
}

// 只允许同房间存活角色成为当前目标；在最高仇恨上追加而非写入魔数。
int force_target(object ob,int bonus)
{
	int forced_threat;
	if(!ob || ob==this_object() || ob->get_cur_life()<=0 ||
	   !environment(this_object()) ||
	   environment(ob)!=environment(this_object()))
		return 0;
	if(bonus<1)
		bonus = 1;
	forced_threat = query_max_threat()+bonus;
	targets[ob] = forced_threat;
	first_target = ob;
	return forced_threat;
}
// 中立职业可以使用仙、妖两边的公共设施；老职业仍受本阵营限制。
int can_use_room_race(string target_race){
	if(raceId=="third")
		return target_race=="human" ||
			target_race=="monst" ||
			target_race=="third";
	return raceId==target_race;
}
int can_change_faction(){
	return raceId=="human" || raceId=="monst";
}
// 中立职业可与仙、妖两边玩家组队、交易和交流；仙妖之间仍保持敌对隔离。
int can_socialize_with(object target){
	if(!target)
		return 0;
	return raceId==target->query_raceId() ||
		raceId=="third" ||
		target->query_raceId()=="third";
}
///////////////职业&npc种类/////////////////////////////////////////////////
string query_profe_cn(string pid){
	return profes[pid];
}
//武器种类定义
protected mapping(string:int) rnt_wield = ([
		"double_main_weapon" : 2,
		"single_main_weapon" : 3,
		"single_other_weapon": 4
		]);
//防具，首饰，饰物种类定义
protected mapping(string:int) rnt = ([
		"armor_head" : 2,
		"armor_cloth" : 3,
		"armor_waste" : 4,
		"armor_hand" : 5,
		"armor_thou" : 6,
		"armor_shoes": 7,
		"jewelry_ring" : 8,
		"jewelry_neck" : 9,
		"jewelry_bangle" :10,
		"decorate_manteau" : 11,
		"decorate_thing" : 12,
		"decorate_tool" : 13
		]);
//穿戴物品
private mapping equip=([]);
mapping query_equip(){
	return equip;
}
string query_short(){
	string s="";
	if(this_object()->is("npc")&&this_object()->_boss)
		s += "［首领］";
	else if(this_object()->is("npc")&&this_object()->_meritocrat)
		s += "［精英］";
	if(this_object()->is("npc")&&this_object()->_npcLevel>=1)
		return s + this_object()->query_name_cn()+"("+this_object()->_npcLevel+")";
	else
		return s + this_object()->query_name_cn();
}
string query_nick(){
	return "";
}
string query_pronoun(void|object looker){
	if(this_object()->is("npc")){
		if(this_object()->pronoun)
			return this_object()->pronoun;
		else
			return "不明";
	}
	else{
		if(this_object()==looker)
			return "你";
		if(!this_object()->sex)
			return "未知";
		if(this_object()->sex=="male")
			return "他";
		else if(this_object()->sex=="female")
			return "她";
	}
}
string query_gender(){
	if(this_object()->is("npc")){
		if(this_object()->gender)
			return this_object()->gender;
		else
			return "不明";
	}
	else{
		if(this_object()->sex=="male")
			return "男";
		else if(this_object()->sex=="female")
			return "女";
		else
			return "不明";
	}
}
//心跳计费系统//////////////////////////////
int user_fee;
int query_user_fee(){
	//return this_object()->user_fee;
	return user_fee;
}
void set_user_fee(int a){
	//this_object()->user_fee = a;
	user_fee = a;
}
//取出剩余小时数
int query_user_hour(){
	return query_user_fee()/60;
}
//取出剩余分钟数
int query_user_mint(){
	return query_user_fee()%60;
}
private void heart_beat()
{
	//每半分钟扣点一点，一小时为120点
	if(this_object()->query_user_fee())
		this_object()->set_user_fee(this_object()->query_user_fee()-1);	
	else
		this_object()->set_user_fee(0);	
	//每1分钟回血一次，为最大生命值的1/20，超过就补满
	if(this_object()->is("npc")){
		if(this_object()->in_combat)
			return;//npc不能在战斗中自动回血
		//npc不再战斗状态中，但是被攻击过血不是满血，立刻补满
		else{
			if(this_object()->life<this_object()->query_life_max())
				this_object()->life=this_object()->query_life_max();
		}
	}
	//玩家不在战斗中才能回血
	if(life<query_life_max()&&!this_object()->in_combat){
		int add=query_life_max()/10;
		if(life+add>query_life_max())
			add=query_life_max()-life;
		life+=add;
	}
	//每1分钟回蓝一次，为最大仙力值的1/10，超过就补满
	if(mofa<query_mofa_max()){
		int add=query_mofa_max()/10;
		if(mofa+add>query_mofa_max()){
			add=query_mofa_max()-mofa;
		}
		mofa+=add;
	}
	//丹药效果计时
	if(this_object()["/danyao"] && sizeof(this_object()["/danyao"])>0){
		foreach(indices(this_object()["/danyao"]),string kind){
			if(buff[kind][0] != "none"){
				buff[kind][2]--;
				if(kind=="te_exp"||kind=="te_honer"||kind=="te_luck")
					this_object()["/teyao/"+kind][2]--;
			}
			if(buff[kind][2] <= 0){
				if(kind == "spec") 
					this_object()->hind = 0;
				clean_buff(kind);
				m_delete(this_object()["/danyao"],kind);
			}
		}
	}
	//特药的效果                                                                            
	if(this_object()["/teyao"] && sizeof(this_object()["/teyao"])>0){
		foreach(indices(this_object()["/teyao"]),string kind){
			if(buff[kind][0] != "none"){
				buff[kind][2]--;                                                
				this_object()["/teyao/"+kind][2]--;                             
			}
			if(buff[kind][2] <= 0){
				clean_buff(kind);
				m_delete(this_object()["/teyao"],kind);
			}
		}
	}
	//homeBuff计时
	if(this_object()["/homeBuff"] && sizeof(this_object()["/homeBuff"])>0){
		foreach(indices(this_object()["/homeBuff"]),string kind){
			if(buff[kind][0] != "none"){
				buff[kind][2]--;
				if(kind=="home_luck"||kind=="home_attack"||kind=="home_base")
					this_object()["/homeBuff/"+kind][2]--;
			}
			if(buff[kind][2] <= 0){
				clean_buff(kind);
				m_delete(this_object()["/homeBuff"],kind);
			}
		}
	}
	//鎏金石效果计时
	if(this_object()->ljs_time&&this_object()->ljs_time>0){
		this_object()->ljs_time --;
	}
}
void set_life(int ulife){
	life = ulife;
}
int get_cur_life(){
	return life;
}
int query_life_max(){
	//血最大值是根据力量算出的一个随力量而变化的值
	life_max=this_object()->query_str()*10+query_base_life()+query_equip_add("life")+this_object()->query_level()*50;
	if(buff["attri_defend"][0] == "life_max")
		life_max += buff["attri_defend"][1];
	if(buff["te_defend"][0] == "life_max")
		life_max += buff["te_defend"][1];
	if(buff["buff"][0] == "life_max")
		life_max += buff["buff"][1];
	if(buff["home_base"][0] == "life"||buff["home_base"][0] == "lifAndMage")
		life_max += buff["home_base"][1];
	if(this_object()->life > life_max)
		this_object()->life = life_max;
	return life_max;
}
//liaocheng 于07/08/07添加，用于解决由set_base_life()调整后的血量不能立即生效的问题
//在npc被创建时调用
void flush_life(){
	this_object()->life = this_object()->query_life_max();
}

void set_mofa(int umofa){
	mofa = umofa;
}
int get_cur_mofa(){
	return mofa;
}
int query_mofa_max(){ //仙力最大值是根据当前智力而变化的值
	mofa_max = this_object()->query_think()*10 + query_equip_add("mofa");
	if(buff["attri_defend"][0] == "mofa_max"){
		mofa_max += buff["attri_defend"][1];
	}
	if(buff["home_base"][0] == "lifAndMage"||buff["home_base"][0] == "mofa_max")
		mofa_max += buff["home_base"][1];
	if(this_object()->mofa >= mofa_max)
		this_object()->mofa = mofa_max;
	return mofa_max;
}

//对于力敏智属性来说，分三部分，一是人物成长的基本属性，二是人物被动技能的加成，三是装备的加成。如:_str代表人物成长的基本力量，base_str和base_all代表被动技能的加成，装备的加成通过query_equip_add("str")和query_equip_add("all")来获得
void set_str(int str){
	_str = str;
}
int get_cur_str(){
	return _str+base_str+base_all;
}
int query_str(){
	int result = 0;
	int equip_str = query_equip_add("str")+query_equip_add("all");//得到所有装备附加的力量值，以后将扩展到特殊物品和药品等
	result = _str + equip_str;
	//技能buff加成
	if(buff["buff"][0]=="str"||buff["buff"][0]=="all")
		result+=buff["buff"][1];
	//嗑药加成
	if(buff["attri_base"][0]=="str")
		result+=buff["attri_base"][1];
	if(buff["te_base"][0]=="str")
		result+=buff["te_base"][1];
	if(buff["home_base"][0]=="str")
		result+=buff["home_base"][1];
	//诅咒的减益
	if(debuff["curse"][0]=="str"||debuff["curse"][0]=="all"){
		result-=debuff["curse"][1];
		if(result<0)
			result=0;
	}
	result += query_base_str()+query_base_all()+
		query_wuxiang_heart_bonus("str")+query_taiji_heart_bonus("str");
	return result+query_balanced_attr_bonus(result);
}
void set_think(int think){
	_think = think;
}
int get_cur_think(){
	return _think+base_think+base_all;
}
int query_think(){
	int result = 0;
	int equip_think = query_equip_add("think")+query_equip_add("all");//得到所有装备附加的智力值，以后将扩展到特殊物品和药品等
	result = _think + equip_think;
	//buff技能加成
	if(buff["buff"][0]=="think"||buff["buff"][0]=="all")
		result+=buff["buff"][1];
	//嗑药加成
	if(buff["attri_base"][0]=="think")
		result+=buff["attri_base"][1];
	if(buff["te_base"][0]=="think")
		result+=buff["te_base"][1];
	if(buff["home_base"][0]=="think")
		result+=buff["home_base"][1];
	//诅咒减益
	if(debuff["curse"][0]=="think"||debuff["curse"][0]=="all"){
		result-=debuff["curse"][1];
		if(result<0)
			result=0;
	}
	result += query_base_think()+query_base_all()+
		query_wuxiang_heart_bonus("think")+query_taiji_heart_bonus("think");
	return result+query_balanced_attr_bonus(result);
}
void set_dex(int dex){
	_dex = dex;
}
int get_cur_dex(){
	return _dex+base_dex+base_all;
}
int query_dex(){
	int result = 0;
	int equip_dex = query_equip_add("dex")+query_equip_add("all");//得到所有装备附加的敏捷值，以后将扩展到特殊物品和药品等
	result = _dex + equip_dex;
	//buff技能加成
	if(buff["buff"][0]=="dex"||buff["buff"][0]=="all")
		result+=buff["buff"][1];
	//嗑药加成
	if(buff["attri_base"][0]=="dex")
		result+=buff["attri_base"][1];
	if(buff["te_base"][0]=="dex")
		result+=buff["te_base"][1];
	if(buff["home_base"][0]=="dex")
		result+=buff["home_base"][1];
	//诅咒减益
	if(debuff["curse"][0]=="dex"||debuff["curse"][0]=="all"){
		result-=debuff["curse"][1];
		if(result<0)
			result=0;
	}
	result += query_base_dex()+query_base_all()+
		query_wuxiang_heart_bonus("dex")+query_taiji_heart_bonus("dex");
	return result+query_balanced_attr_bonus(result);
}
//add by calvin 0409/////////////////////////////////////////
//被动技能增加的属性的永久快照 防御力defend,命中hitte,爆击baoji,闪避dodge
//新加基本属性
int base_str;
int query_base_str(){return base_str;}
void set_base_str(int a){base_str = a;}
int base_think;
int query_base_think(){return base_think;}
void set_base_think(int a){base_think = a;}
int base_dex;
int query_base_dex(){return base_dex;}
void set_base_dex(int a){base_dex = a;}
int base_all;
int query_base_all(){return base_all;}
void set_base_all(int a){base_all = a;}
int base_life;
int query_base_life(){return base_life;}
void set_base_life(int a){base_life = a;}
//新加基本属性
int base_defend;
int base_hitte;
int base_baoji;
int base_dodge;
////defend
int query_base_defend(){return base_defend;}
void set_base_defend(int a){base_defend = a;}
////hitte
int query_base_hitte(){return base_hitte;}
void set_base_hitte(int a){base_hitte = a;}
////baoji
int query_base_baoji(){return base_baoji;}
void set_base_baoji(int a){base_baoji = a;}
////dodge
int query_base_dodge(){return base_dodge;}
void set_base_dodge(int a){base_dodge = a;}
//////////////////////////////////////////////////////////////////
void set_lunck(int lunck){
	_lunck = lunck;
}
int get_cur_lunck(){
	return _lunck;
}
int query_lunck(){
	int result = 0;
	int equip_lunck = query_equip_add("lunck");//得到所有装备附加的敏捷值，以后将扩展到特殊物品和药品等
	result = _lunck + equip_lunck;
	int te_lunck = this_object()->query_buff("te_luck",1);//特药
        if(te_lunck)
        	result += te_lunck;
	int home_lunck = this_object()->query_buff("home_luck",1);//家园buff
        if(home_lunck)
        	result += home_lunck;
	int attri_lunck = this_object()->query_buff("attri_luck",1);//丹药buff
        if(attri_lunck)
        	result += attri_lunck;
	return result;
}
/////////////////////////
string query_appear_cn(){
	if(_appear==0){
		_appear=20;
	}
	return MUD_APPEARANCED(this_object()->sex,_appear);
}
//战斗中武器击中对方，减武器磨损
void reduce_fight_wield_weapon(int power){
	if(this_object()->is("npc"))
		return;
	if(power<=0)
		return;
	foreach(indices(equip),string s){
		object ob=equip[s];
		if(ob&&(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"))
			ob->reduce_power(power);
	}
}
//战斗中被对方击中，减防具磨损
void reduce_fight_wear_armor(int power){
	if(this_object()->is("npc"))
		return;
	if(power<=0)
		return;
	foreach(indices(equip),string s){
		object ob=equip[s];
		if(ob&&ob->query_item_type()=="armor")
			ob->reduce_power(power);
	}
}
//得到身上装备物品中增加的额外属性
//由liaocheng于07/1/19修改，添加了arg=="attack_huoyan","attack_bingshuang","attack_fengren","attack_dusu","attack_spec".以及各魔法抗性 属性查询，总共有35种附加属性
int query_equip_add(string arg){
	int power=0;
	if(!arg)
		return power;
	switch(arg) {
		case "str": //力量附加
			foreach(indices(equip),string s){
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_str_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_str_add();
						}
					}
				}
			}
		break;
		case "dex": //敏捷附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_dex_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_dex_add();
						}
					}
				}
			}
		break;
		case "think": //智力附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_think_add();
	//				werror("----count="+ob->query_if_aocao("all")+"---baoshi_num="+sizeof(ob->query_baoshi("all"))+"-\n");
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_think_add();
						}
					}
				}
			}
		break;
		case "lunck": //幸运附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_lunck_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_lunck_add();
						}
					}
				}
			}
		break;
		case "life": //生命附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_life_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_life_add();
						}
					}
				}
			}
		break;
		case "mofa": //法力附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_mofa_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_mofa_add();
						}
					}
				}
			}
		break;
		case "dodge": //闪避附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_dodge_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_dodge_add();
						}
					}
				}
			}
		break;
		case "hitte": //命中附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_hitte_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_hitte_add();
						}
					}
				}
			}
		break;
		case "doub": //暴击附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_doub_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_doub_add();
						}
					}
				}
			}
		break;
		case "attack": //武器伤害附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_attack_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_add();
						}
					}
				}
			}
		break;
		case "attack_all": //武器伤害附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_attack_all_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_all_add();
						}
					}
				}
			}
		break;
		case "weapon_attack": //武器增加伤害百分比
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_weapon_attack_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_weapon_attack_add();
						}
					}
				}
			}
		break;
		case "rase_life_add": //生命恢复附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_rase_life_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_rase_life_add();
						}
					}
				}
			}
		break;
		case "rase_mofa_add": //魔法恢复附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_rase_mofa_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_rase_mofa_add();
						}
					}
				}
			}
		break;
		case "recive": //吸收伤害附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_recive_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_recive_add();
						}
					}
				}
			}
		break;
		case "back": //反弹伤害附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_back_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_back_add();
						}
					}
				}
			}
		break;
		case "base_attack_main": //主手攻击力附加下限
			foreach(indices(equip),string s){
				object ob=equip[s];
				if(ob&&(ob->query_item_kind()=="single_main_weapon"||ob->query_item_kind()=="double_main_weapon")&&ob->item_cur_dura>0){
					power+=ob->query_attack_power();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_power();
						}
					}
				}
			}
		break;
		case "base_attack_other": //副手攻击力附加下限
			foreach(indices(equip),string s) {
				object ob=equip[s];
				if(ob&&ob->query_item_kind()=="single_other_weapon"&&ob->item_cur_dura>0){
					power+=ob->query_attack_power();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_power();
						}
					}
				}
			}
		break;
		case "limit_attack_main"://主手攻击力附加上限
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&(ob->query_item_kind()=="single_main_weapon"||ob->query_item_kind()=="double_main_weapon")&&ob->item_cur_dura>0){
					power+=ob->query_attack_power_limit();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_power_limit();
						}
					}
				}
			}
		break;
		case "limit_attack_other": //副手攻击力附加上限
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->query_item_kind()=="single_other_weapon"&&ob->item_cur_dura>0){
					power+=ob->query_attack_power_limit();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_power_limit();
						}
					}
				}
			}
		break;
		case "defend": //防御力附加
			int shuiyu_num = 0;
			foreach(indices(equip),string s){
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_equip_defend();
					//增加镶嵌宝石的附加属性
					int baoshi_power = 0;
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
						//对黄水玉系列宝石做处理，即每个玩家所穿戴的装备中，镶嵌的黄水玉系列宝石最多只能有4个，当黄水玉系列宝石的总数超过4个的时候就自动脱下该镶嵌有黄水玉的装备
							if(tmp->query_name()=="pshuangshuiyu"||tmp->query_name()=="slhuangshuiyu"||tmp->query_name()=="jinghuangshuiyu"){
								shuiyu_num ++;
							}
							if(shuiyu_num>4){
								//黄水玉数量超过4颗，脱掉，并扣除该装备所增加的防御力
								power -= ob->query_equip_defend();
								this_player()->unwear(ob);
								baoshi_power = 0;
							}
							else
								 baoshi_power+=tmp->query_defend_add();
						}
					}
					power+=baoshi_power;
				}
			}
		break;
		case "speed_main": //主手武器速度
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&(ob->query_item_kind()=="single_main_weapon"||ob->query_item_kind()=="double_main_weapon")&&ob->item_cur_dura>0){
					power+=ob->query_speed_power();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_speed_power();
						}
					}
				}
			}
		break;
		case "speed_other": //副手武器速度
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->query_item_kind()=="single_other_weapon"&&ob->item_cur_dura>0){
					power+=ob->query_speed_power();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_speed_power();
						}
					}
				}
			}
		break;

		case "huo_mofa_attack": //火焰法术伤害增加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_huo_mofa_attack_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_huo_mofa_attack_add();
						}
					}
				}
			}
		break;
		case "bing_mofa_attack": //冰霜法术伤害增加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_bing_mofa_attack_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_bing_mofa_attack_add();
						}
					}
				}
			}
		break;
		case "feng_mofa_attack":  //风刃法术伤害增加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_feng_mofa_attack_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_feng_mofa_attack_add();
						}
					}
				}
			}
		break;
		case "du_mofa_attack": //毒素法术伤害增加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_du_mofa_attack_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_du_mofa_attack_add();
						}
					}
				}
			}
		break;
		case "spec_mofa_attack": //特殊法术伤害增加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_spec_attack_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_spec_attack_add();
						}
					}
				}
			}
		break;
		case "mofa_all": //全部法术伤害增加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_mofa_all_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_mofa_all_add();
						}
					}
				}
				if(buff["attri_attack"][0] == "all_mofa_attack")
					power += buff["attri_attack"][1];
				if(buff["te_attack"][0] == "all_mofa_attack")
					power += buff["te_attack"][1];
				if(buff["home_attack"][0] == "all_attack"||buff["home_attack"][0] == "all_mofa_attack")
					power += buff["home_attack"][1];
			}
		break;
		//在这加入火焰附加伤害等,获得除武器外所有的魔法附加伤害
		case "attack_huoyan": //附加火焰伤害
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_attack_huoyan_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_huoyan_add();
						}
					}
				}
			}
		break;
		case "attack_bingshuang": //附加冰霜伤害
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_attack_bingshuang_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_bingshuang_add();
						}
					}
				}
			}
		break;
		case "attack_fengren": //附加风刃伤害
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_attack_fengren_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_fengren_add();
						}
					}
				}
			}
		break;
		case "attack_dusu": //附加毒素伤害
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_attack_dusu_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_attack_dusu_add();
						}
					}
				}
			}
		break;

		case "all": //全部属性增加
			foreach(indices(equip),string s){
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_all_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_all_add();
						}
					}
				}
			}
		break;
		case "huoyan_defend": //火焰抗性附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_huoyan_defend_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_huoyan_defend_add();
						}
					}
				}
			}
		//在这里处理增益和降低抗性诅咒的影响
		if(buff["buff"][0]=="huoyan_defend"||buff["buff"][0]=="all_mofa_defend")
			power+=buff["buff"][1];
		if(buff["attri_defend"][0]=="huoyan_defend"||buff["attri_defend"][0]=="all_mofa_defend")
			power+=buff["attri_defend"][1];
		if(buff["te_defend"][0]=="huoyan_defend"||buff["te_defend"][0]=="all_mofa_defend")
			power+=buff["te_defend"][1];
		if(buff["home_defend"][0]=="huoyan_defend"||buff["home_defend"][0]=="all_mofa_defend")
			power+=buff["home_defend"][1];
		if(debuff["curse"][0]=="huoyan_defend"||debuff["curse"][0]=="all_mofa_defend"){
			power-=debuff["curse"][1];
			if(power<0)
				power=0;
		}
		break;
		case "bingshuang_defend": //冰霜抗性附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_bingshuang_defend_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_bingshuang_defend_add();
						}
					}
				}
			}
		//在这里处理增益和降低抗性诅咒的影响
		if(buff["buff"][0]=="bingshuang_defend"||buff["buff"][0]=="all_mofa_defend")
			power+=buff["buff"][1];
		if(buff["attri_defend"][0]=="bingshuang_defend"||buff["attri_defend"][0]=="all_mofa_defend")
			power+=buff["attri_defend"][1];
		if(buff["te_defend"][0]=="bingshuang_defend"||buff["te_defend"][0]=="all_mofa_defend")
			power+=buff["te_defend"][1];
		if(buff["home_defend"][0]=="bingshuang_defend"||buff["home_defend"][0]=="all_mofa_defend")
			power+=buff["home_defend"][1];
		if(debuff["curse"][0]=="bingshuang_defend"||debuff["curse"][0]=="all_mofa_defend"){
			power-=debuff["curse"][1];
			if(power<0)
				power=0;
		}
		break;
		case "fengren_defend": //风刃抗性附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_fengren_defend_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_fengren_defend_add();
						}
					}
				}
			}
		//在这里处理增益和降低抗性诅咒的影响
		if(buff["buff"][0]=="fengren_defend"||buff["buff"][0]=="all_mofa_defend")
			power+=buff["buff"][1];
		if(buff["attri_defend"][0]=="fengren_defend"||buff["attri_defend"][0]=="all_mofa_defend")
			power+=buff["attri_defend"][1];
		if(buff["te_defend"][0]=="fengren_defend"||buff["te_defend"][0]=="all_mofa_defend")
			power+=buff["te_defend"][1];
		if(buff["home_defend"][0]=="fengren_defend"||buff["home_defend"][0]=="all_mofa_defend")
			power+=buff["home_defend"][1];
		if(debuff["curse"][0]=="fengren_defend"||debuff["curse"][0]=="all_mofa_defend"){
			power-=debuff["curse"][1];
			if(power<0)
				power=0;
		}
		break;
		case "dusu_defend": //毒素抗性附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_dusu_defend_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_dusu_defend_add();
						}
					}
				}
			}
		//在这里处理增益和降低抗性诅咒的影响
		if(buff["buff"][0]=="dusu_defend"||buff["buff"][0]=="all_mofa_defend")
			power+=buff["buff"][1];
		if(buff["attri_defend"][0]=="dusu_defend"||buff["attri_defend"][0]=="all_mofa_defend")
			power+=buff["attri_defend"][1];
		if(buff["te_defend"][0]=="dusu_defend"||buff["te_defend"][0]=="all_mofa_defend")
			power+=buff["te_defend"][1];
		if(buff["home_defend"][0]=="dusu_defend"||buff["home_defend"][0]=="all_mofa_defend")
			power+=buff["home_defend"][1];
		if(debuff["curse"][0]=="dusu_defend"||debuff["curse"][0]=="all_mofa_defend"){
			power-=debuff["curse"][1];
			if(power<0)
				power=0;
		}
		break;
		case "all_mofa_defend": //全法术抗性附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_all_mofa_defend_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_all_mofa_defend_add();
						}
					}
				}
			}
		break;
		case "renxing": //韧性附加
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_renxing();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_renxing();
						}
					}
				}
			}
		break;
		case "wulichuantou_add": //物理穿透，一点提供一点无视防御伤害
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_wulichuantou_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_wulichuantou_add();
						}
					}
				}
			}
			
		break;
		case "mofachuantou_add": //法术穿透，一点提供一点无视防御伤害
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_mofachuantou_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_mofachuantou_add();
						}
					}
				}
			}
			
		break;
		case "dodgechuantou_add": //闪避穿透按千分点保存，结算时区分普攻40%和技能60%
			foreach(indices(equip),string s){                                                       
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_dodgechuantou_add();
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
							 power+=tmp->query_dodgechuantou_add();
						}
					}
				}
			}
			if(power>600)power=600;//主动物理技能最高无视闪避60%
		break;
		default :
		return 0;
	}
	return power;
}

//丹药的属性加成,主要是用于ui的显示
//由liaocheng于07/6/6日添加
int query_danyao_add(string kind,string type)
{
	if(buff[kind][0] == type)
		return buff[kind][1];
	else 
		return 0;
}

//装载
int wield(object weapon){
	object ob=present(weapon,this_object());
	//必须是可装载的物品is_equip()
	if(ob&&ob->is("equip")){
		//物品装配类型=item.pike->item_kind
		//双手武器-item_kind=double_main_weapon必须在主手
		//单手武器-item_kind=single_main_weapon主手,必须主手，
		//单手武器-item_kind=single_other_weapon副手，必须副手
		//要是身上没有装备任何武器，则直接装备上
		if(equip["double_main_weapon"]==0&&equip["single_main_weapon"]==0&&equip["single_other_weapon"]==0){
			equip[ob->item_kind]=ob;
			ob->equiped=1;
			return rnt_wield[ob->item_kind];
		}
		//若是已装备了同类型的武器，则先卸载掉已装备的武器
		if(equip[ob->item_kind]!=0)
			unwield(equip[ob->item_kind]);	
		//若要装备上的武器是双手，则直接装备上，并卸载可能已装备上的主副手的武器
		if(ob->item_kind=="double_main_weapon")
		{
			equip["double_main_weapon"]=ob;
			ob->equiped=1;
			if(equip["single_main_weapon"]!=0)
			{
				equip["single_main_weapon"]->equiped=0;
				m_delete(equip,"single_main_weapon");
			}
			if(equip["single_other_weapon"]!=0)
			{
				equip["single_other_weapon"]->equiped=0;
				m_delete(equip,"single_other_weapon");
			}
			return rnt_wield[ob->item_kind];
		}
		//若要装备上的武器是单手，则直接装备上，并卸载可能已装备上的双手武器
		if(ob->item_kind=="single_main_weapon"||ob->item_kind=="single_other_weapon")
		{
			equip[ob->item_kind]=ob;
			ob->equiped=1;
			if(equip["double_main_weapon"]!=0)
			{
				equip["double_main_weapon"]->equiped=0;
				m_delete(equip,"double_main_weapon");
			}
			return rnt_wield[ob->item_kind];
		}
	}
	return 0;
}
//卸载
int unwield(void|object weapon)
{
	if(equip[weapon->item_kind]){
		if(weapon==0||weapon==equip[weapon->item_kind]){
			equip[weapon->item_kind]->equiped=0;
			m_delete(equip,weapon->item_kind);
			return 1;
		}
	}
	return 0;
}
//穿戴
int wear(object armor)
{
	//物品穿戴类型=item.pike->item_kind
	//item_kind=armor_head      防具中的头盔
	//item_kind=armor_cloth     防具中的衣服
	//item_kind=armor_waste     防具中的手腕
	//item_kind=armor_hand      防具中的手套
	//item_kind=armor_thou      防具中的裤子
	//item_kind=armor_shoes     防具中的鞋子
	//item_kind=jewelry_ring    首饰中的戒指
	//item_kind=jewelry_neck    首饰中的项链
	//item_kind=jewelry_bangle  首饰中的手镯
	//item_kind=decorate_manteau 饰物中的披风
	//item_kind=decorate_thing   饰物中的挂件
	//item_kind=decorate_tool    饰物中的携带物
	object ob=present(armor,this_object());
	if(ob&&ob->is("equip")){
		//已穿戴，则脱下已穿戴的再穿戴上新的
		if(equip[ob->item_kind]!=0)
		{
			unwear(equip[ob->item_kind]);
			equip[ob->item_kind]=ob;
			ob->equiped=1;
			return rnt[ob->item_kind];
		}
		//未穿戴同类东西直接穿戴
		else
		{
			equip[ob->item_kind]=ob;
			ob->equiped=1;
			return rnt[ob->item_kind];
		}
	}
	return 0;
}
int unwear(void|object ob)
{
	if(equip[ob->item_kind])
	{
		if(ob==0||ob==equip[ob->item_kind])
		{
			equip[ob->item_kind]->equiped=0;
			m_delete(equip,ob->item_kind);
			return 1;
		}
	}
	return 0;
}
//角色昏迷,休息状态处理///////////////////////////////////////
string unconscious_msg;
read_write(unconscious_msg);
string wake_up_msg;
read_write(wake_up_msg);
protected multiset(string) status=(<>);
read_write(status);
string doing_status;
read_write(doing_status);
// Commands-disabled activity is not fully represented by doing_status alone:
// Pike cancels object call_outs when a player is reconstructed on another map
// worker or after a restart. Persist the absolute deadline and rebuild exactly
// one wake-up timer after setup, without extending the original duration.
int doing_status_until;
read_write(doing_status_until);

private int valid_persistent_doing_status(string value)
{
	return has_value(({"昏迷不醒","睡眠中","修炼中"}),value);
}

int query_doing_status_remaining()
{
	int remaining = doing_status_until-time();
	return remaining>0 ? remaining : 0;
}

/** Restore paid training with exact saved seconds instead of rounding minutes. */
int resume_paid_training_activity(int remaining)
{
	if(remaining<1 || remaining>20*366*24*60*60)
		return 0;
	doing_status="修炼中";
	unconscious_msg="你现在正在闭关修炼\n[查看修炼情况:_break_then_auto_learn_check]\n[中断修炼:_break_then_auto_learn_end_submit]\n";
	wake_up_msg="$N修炼完成了\n";
	doing_status_until=time()+remaining;
	remove_call_out(wake_up);
	disable_commands();
	call_out(wake_up,remaining);
	return 1;
}

/** Rebuild a lost object-local wake-up callout from the durable deadline. */
int restore_persistent_activity_state()
{
	int remaining;
	if(!doing_status || doing_status=="")
		return 0;
	remaining = query_doing_status_remaining();
	// Twenty years covers accumulated historical paid training duration
	// while still
	// failing closed if a damaged archive attempts to disable commands forever.
	if(!valid_persistent_doing_status(doing_status) || remaining<1 ||
	   remaining>20*366*24*60*60){
		remove_call_out(wake_up);
		doing_status=0;
		doing_status_until=0;
		unconscious_msg=0;
		wake_up_msg=0;
		enable_commands();
		return 0;
	}
	if(!unconscious_msg || unconscious_msg==""){
		if(doing_status=="昏迷不醒")
			unconscious_msg="你现在昏迷不醒。\n";
		else if(doing_status=="睡眠中")
			unconscious_msg="你正在休息。\n";
		else
			unconscious_msg="你现在正在闭关修炼。\n";
	}
	if(!wake_up_msg || wake_up_msg==""){
		if(doing_status=="昏迷不醒")
			wake_up_msg="$N慢慢苏醒过来。\n";
		else if(doing_status=="睡眠中")
			wake_up_msg="$N睡醒了。\n";
		else
			wake_up_msg="$N修炼完成了。\n";
	}
	remove_call_out(wake_up);
	disable_commands();
	call_out(wake_up,remaining);
	return 1;
}

int is_item(){
	return doing_status=="昏迷不醒";
}
int is_character(){
	return doing_status!="昏迷不醒";
}
private void wake_up(void|int notShowMSG)
{
	doing_status=0;
	doing_status_until=0;
	object env=environment(this_object());
	if(living(env)){
		object env1=environment(env);
		this_object()->move(env1);
	}
	if(!notShowMSG && wake_up_msg)
		MUD_EMOTED->emote(wake_up_msg,this_object(),0);
	unconscious_msg=0;
	wake_up_msg=0;
	enable_commands();
}
void unconscious()
{
	doing_status="昏迷不醒";
	unconscious_msg="你现在昏迷不醒。\n";
	wake_up_msg="$N慢慢苏醒过来。\n";
	disable_commands();
	doing_status_until=time()+60;
	remove_call_out(wake_up);
	call_out(wake_up,60);
}
void die(){
	if(is_item()){
		remove_call_out(wake_up);
		wake_up(1);
	}
}
void sleep()
{
	doing_status="睡眠中";
	unconscious_msg="你开始休息，来恢复一定的生命和法力。\n";
	wake_up_msg="$N睡醒了。\n";
	disable_commands();
	//休息恢复生命法力
	this_object()->life=this_object()->life_max;
	this_object()->mofa=this_object()->mofa_max;

	doing_status_until=time()+10;
	remove_call_out(wake_up);
	call_out(wake_up,10);
}

//Evan 22008.11.21 为了实现玩家主动从sleep状态醒来。
void sleep_for_learn(int minutes)
{
	if(minutes<1 || minutes>10000000)
		return;
	doing_status="修炼中";
	unconscious_msg="你现在正在闭关修炼\n[查看修炼情况:_break_then_auto_learn_check]\n[中断修炼:_break_then_auto_learn_end_submit]\n";      
	wake_up_msg="$N修炼完成了\n";
	disable_commands();
	doing_status_until=time()+minutes*60;
	remove_call_out(wake_up);
	call_out(wake_up,minutes*60);//参数的单位是"分"，这里要换算成秒
}  

void wakeup_from_auto_learn()                                                                                                       
{
	wake_up();
}
//end of evan added 20081121

void exercise(object room)
{
	doing_status="修炼中";
	object player = this_player();
	string name_cn = room->query_name_cn();
	string kind = room->query_buff_kind();
	string type = room->query_buff_type();
	int effect_value = room->query_buff_value();
	int timedelay = room->query_effect_time();
	int need_time = room->query_wait_time();
	unconscious_msg = room->query_oprate_desc() + "(需要持续"+need_time/60+"分钟)\n";
	player->set_buff(kind,0,type);
	player->set_buff(kind,1,effect_value);
	player->set_buff(kind,2,timedelay/60);//由于char.pike中是以1min为一心跳
	player["/homeBuff/"+kind] = ({type,effect_value,timedelay/60,name_cn});   

	wake_up_msg="$N修炼完成了。\n";
	disable_commands();
	doing_status_until=time()+need_time;
	remove_call_out(wake_up);
	call_out(wake_up,need_time);
}
//求命中率=攻击者命中率+装备附加命中+技能命中(可能100%)
//由liaocheng于07/1/8添加，用于判断是否命中
int query_if_hitte(){
	float h;
	int hitte_percent_reduce;
	//int hInt;
	h = this_object()->query_phy_hitte();
	if(buff["buff"][0]=="hitte")
		h += buff["buff"][1];
	if(buff["attri_vice"][0]=="hitte")
		h += buff["attri_vice"][1];
	if(debuff["curse"][0]=="hitte"){
		//werror("-----"+this_object()->query_name_cn()+" get the curse of hitte "+debuff["curse"][1]+"------\n");
		h -= debuff["curse"][1];//获得玩家的命中率
		if(h<0)
			h=0;
	}
	if(h>99)
		h=99.0;
	// 太古诅咒必须在命中率99封顶后按比例生效。若在封顶前从十万级
	// 原始命中扣除，任何固定值或普通百分比最终仍会被封回99。
	if(debuff["curse"][0]=="hitte_percent"){
		hitte_percent_reduce=debuff["curse"][1];
		if(hitte_percent_reduce<0)
			hitte_percent_reduce=0;
		if(hitte_percent_reduce>70)
			hitte_percent_reduce=70;
		h=h*(100-hitte_percent_reduce)/100;
	}
	return (int)h;
	/*	hInt = (int)(h*100);
		if(hInt>=random(10000))//恭喜你，命中了
		return 1;
		else
		return 0;//恭喜你，未击中
	 */
}
//由liaocheng于07/1/8添加，用于判断是否躲闪攻击
int query_if_dodge(){
	float p;
	int pInt;
	p = this_object()->query_phy_dodge();
	if(buff["buff"][0]=="dodge")
		p += buff["buff"][1];
	if(buff["attri_vice"][0]=="dodge")
		p += buff["attri_vice"][1];
	if(debuff["curse"][0]=="dodge"){
		p -= debuff["curse"][1];
		if(p<0)
			p = 0;
	}
	if(p>75)
		p=75.0;
	pInt = (int)p;
	if(pInt>0 && random(100)<pInt)
		return 1;//恭喜你，你躲过了
	else
		return 0;//也恭喜你，你中标了

}
int query_if_baoji(void|object enemy){
	float b;
	int bInt;
	b = this_object()->query_phy_baoji();
	if(buff["buff"][0]=="doub")
		b += buff["buff"][1];
	if(buff["attri_vice"][0]=="doub")
		b += buff["attri_vice"][1];
	if(buff["te_vice"][0]=="doub")
		b += buff["te_vice"][1];
	if(debuff["curse"][0]=="doub"){
		b -= debuff["curse"][1];
		if(b<0)
			b=0;
	}
	//影鬼70技能暴击效果
	if(this_object()->hind && buff["70_skill_buff"][0] == "cuidu" && buff["70_skill_buff"][1]){
		b += buff["70_skill_buff"][1];
		buff["70_skill_buff"][1] = 0;
	}
	//计算对方是否有韧性，每40点韧性减少1%普通伤害的暴击机会
	if(enemy){
		float renxing = enemy->query_equip_add("renxing");
		if(renxing>0.0){
			b = b - renxing/40.0;
		}
	}
	bInt = (int)b;
	if(bInt>0 && random(100)<bInt)
		return 1;
	else 
		return 0;
}
//char的心跳为1分钟
private string initer=(enable_commands(),this_object()->add_heart_beat(heart_beat,30),"");
