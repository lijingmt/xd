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

int set_toolbar(string name,int num,int flag)
{
	if(name != "" && num<TOOLBAR_NUM){
		toolbar_key[num]=([name:flag]);
		return 1;
	}
	else
		return 0;
}
int clean_toolbar(int num)
{
	if(num<TOOLBAR_NUM){
		toolbar_key[num]=(["none":0]);
		return 1;
	}
	else
		return 0;
}
mapping(string:int) query_toolbar(int a)
{
	mapping(string:int) tmp = ([]);
	tmp = toolbar_key[a];
	return tmp;	
}
string query_toolbar_cn()
{
	string s = "";
	int used = 0;
	for(int i=0;i<TOOLBAR_NUM;i++){
		foreach(indices(toolbar_key[i]),string name){
			if(toolbar_key[i][name]==0){
				/*s += "无";
				if(i!=2)
					s += "|";
				*/
				break;
			}
			else{
				used ++;
				if(toolbar_key[i][name]==1){
					s += "["+MUD_SKILLSD[name]->query_name_cn()+":use_toolbar "+i+"]";
					if(i!=TOOLBAR_NUM-1)
						s += "|";
					break;
				}
				else if(toolbar_key[i][name]==2){
					object food = clone(FOOD_PATH+name); 
					if(food){
						s += "["+food->query_name_cn()+":use_toolbar "+i+"]";
						if(i!=TOOLBAR_NUM-1)
							s += "|";
						break;
					}
				}
				else if(toolbar_key[i][name]==3){
					object water = clone(WATER_PATH+name);
					if(water){
						s += "["+water->query_name_cn()+":use_toolbar "+i+"]";
						if(i!=TOOLBAR_NUM-1)
							s += "|";
						break;
					}
				}
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
static mapping(string:array(mixed)) debuff=([
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
static mapping(string:array(mixed)) buff = ([
		"buff":({"none",0,0}),
		"buff2":({"none",0,0}),
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

void reset_buff(){
	clean_buff("buff");
	clean_buff("buff2");
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
object first_target;//记录第一仇恨目标
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
	object tmp_ob=0;
	if(targets){
		//轮询仇恨列表，得到最到仇恨第一的目标
		foreach(indices(targets),object ob) {
			if(targets[ob]>max){
				tmp_ob=ob;
				max=targets[ob];
			}
		}
		first_target=tmp_ob;
		return tmp_ob;
	}
	return 0;
}

array(object) get_all_targets()
{
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
	if(ob&&targets[ob])
		m_delete(targets,ob);
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

//种族id:种族中文名(其实就是两个对立阵营)//////////////////////////
string raceId;
read_write(raceId);
static array(string) raceKindList=({"human","monst","third"});
static array(string) raceNameList=({"人类","妖魔","中立"});
static mapping(string:string) races=([
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
static array(string) profeKindList=({"jianxian","yushi","zhuxian","kuangyao","wuyao","yinggui","humanlike","beast","bird","fish","amphibian","bugs","dog"});
static array(string) profeNameList=({"剑仙","羽士","诛仙","狂妖","巫妖","影鬼","人形","野兽","飞禽","鱼","两栖动物","昆虫","狗"});
static mapping(string:string) profes=([
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
		profeKindList[12]:profeNameList[12]
		]);
////////////////阵营/////////////////////////////////////////////////
string query_race_cn(string rid){
	return races[rid];
}
///////////////职业&npc种类/////////////////////////////////////////////////
string query_profe_cn(string pid){
	return profes[pid]; 
}
//武器种类定义
static mapping(string:int) rnt_wield = ([
		"double_main_weapon" : 2,
		"single_main_weapon" : 3,
		"single_other_weapon": 4
		]);
//防具，首饰，饰物种类定义
static mapping(string:int) rnt = ([
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
	return result+query_base_str()+query_base_all();
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
	return result+query_base_think()+query_base_all();
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
	return result+query_base_dex()+query_base_all();
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
static string unconscious_msg;
private string wake_up_msg;
static multiset(string) status=(<>);
read_write(status);
static string doing_status;
read_write(doing_status);

int is_item(){
	return doing_status=="昏迷不醒";
}
int is_character(){
	return doing_status!="昏迷不醒";
}
private void wake_up(void|int notShowMSG)
{
	doing_status=0;
	object env=environment(this_object());
	if(living(env)){
		object env1=environment(env);
		this_object()->move(env1);
	}
	if(!notShowMSG) MUD_EMOTED->emote(wake_up_msg,this_object(),0);
	enable_commands();
}
void unconscious()
{
	doing_status="昏迷不醒";
	unconscious_msg="你现在昏迷不醒。\n";
	wake_up_msg="$N慢慢苏醒过来。\n";
	disable_commands();
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

	call_out(wake_up,10);
}

//Evan 22008.11.21 为了实现玩家主动从sleep状态醒来。
void sleep_for_learn(int time)                                                                                                      
{   
	doing_status="修炼中";
	unconscious_msg="你现在正在闭关修炼\n[查看修炼情况:_break_then_auto_learn_check]\n[中断修炼:_break_then_auto_learn_end_submit]\n";      
	wake_up_msg="$N修炼完成了\n";
	disable_commands();
	call_out(wake_up,time*60);//参数的单位是"分"，这里要换算成秒
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
	call_out(wake_up,need_time);
}
//求命中率=攻击者命中率+装备附加命中+技能命中(可能100%)
//由liaocheng于07/1/8添加，用于判断是否命中
int query_if_hitte(){
	float h;
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
	pInt = (int)p;
	if(pInt>=random(100))
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
	if(bInt>=random(100))
		return 1;
	else 
		return 0;
}
//char的心跳为1分钟
private string initer=(enable_commands(),this_object()->add_heart_beat(heart_beat,30),"");
