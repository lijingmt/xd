#include <globals.h>
#include <mudlib/include/mudlib.h>
#include <gamelib/include/gamelib.h>
#define SKILL_PATH ROOT "/gamelib/single/skills/"
#define FOOD_PATH ROOT "/gamelib/clone/item/food/"
#define WATER_PATH ROOT "/gamelib/clone/item/water/"
#define TOOLBAR_NUM 6
string who_fight_npc;
string term_who_fight_npc;



//����ϵͳ����liaocheng��07/09/21���
array(string) follow_me = ({});
string follow = "";

//��ݼ�ϵͳ����liaocheng��07/04/16���
//3����������� 1-���ܡ�2-ʳ�� 3-ˮ 0-û��
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
				/*s += "��";
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
		//if(used == 3)//ÿ3��һ����
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

//�û��˷ܼ�ϵͳ////////////////////////////
//�˷ܼ�����������ͣ�({��ߵ���������ʱ�䣬��ǰʱ��})
//������char��������fight�������Ͳ쿴����״̬��ʱ����ü��ӿ�
//���ж�ʱ�����ƣ���������
//mapping(string:array) high_med = ([
//		"high_str":({0,0,0}),
//		"high_dex":({0,0,0})
//		]);
//�û��˷ܼ�ϵͳ////////////////////////////
//�û���Ǯϵͳ////////////////////////////
//ʵ��Ǯ�洢��ʽ
int _account = 0;
//�õ�Ǯ����
int query_account(){
	return this_object()->_account;
}
	void set_account(int a){
		if(a>=0)
			this_object()->_account = a;
		else
			this_object()->_account = 0;
	}
//��Ǯ��ȡ���ƣ����ֲ�
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
//�õ�Ǯ����
string query_money_cn(){
	string rs = "";
	rs += "��"+query_gold()+"\n";
	rs += "����"+query_silver();
	return rs;
}
//����Ǯ����
	void add_account(int add){
		if(add>=0)
			set_account(query_account()+add);
		if(query_account()<=0)
			set_account(0);
	}
//����Ǯ����
	void del_account(int del){
		if(del>=0)
			set_account(query_account()-del);
		if(query_account()<=0)
			set_account(0);
	}
//֧��Ǯ
int pay_money(int val){
	if(val>query_account()){
		return 0;//���Ͻ�Ǯ����֧��
	}
	else{
		del_account(val);
		return 1;//����֧��,�����֧��
	}
}
//����Ǯ
void add_money(int val){
	if(val>=0){
		add_account(val);
	}
}
//����ʱ��Ǯ���жϺ���ʾ
	int trade_money_judge(int val){
		if(val>query_account())
			return 0;//���Ͻ�Ǯ����֧��
		else
			return 1;//����֧��
	}
//�û���Ǯϵͳ////////////////////////////

//�û�����ϵͳ////////////////////////////
mapping(string:array) skills=([]);//([skill_name:({skill_level,skill_point})])
string skills_enable = "";//skill_name
int skills_enable_colddown = 0;

//�û���������ϵͳ///////////////////////
//liaocheng��07/5/23���
mapping(string:array) vice_skills=([]);
//��ʱ�Ĳ���:����ӳ���
mapping(string:int) material_m=([]);
//��ʱ�Ķ��챦ʯ������Ϣ��
mapping(string:array) baoshi_add=([]);
//��������Ϣ��
mapping(int:array) ronglian_list=([]);

//����ս������20070131////////////////////////////
mapping(string:int) f_skills=([]);//([skill_name:skill_limit_time])
//ս�����ձ���////////////////////////////
//��ս���в�������Կ��Է������
int timeCold; //���������Ĺ�����ȴʱ��
int timeCount;//ս��ʱ�������
int eat_timeCold;//ʳ��ҩ�����ȴʱ��
int rase_life;//ս�������ظ�
int rase_mofa;//ս��ħ���ظ�
int is_both_weapons;//�Ƿ���˫�������������гͷ�liaocheng��07/4/16���
string weapon_type;
string cur_main_weapon_name;
string cur_other_weapon_name;
int attack_speed_main;//�����ٶ�,�ܵ����������Ӱ��
int attack_speed_other;//�����ٶȣ��ܵ����������Ӱ��
int raw_attack_speed_main;//ԭʼ�������ٶȣ����ֲ��䣬
int raw_attack_speed_other;//ԭʼ�ĸ����ٶȣ����ֲ���
int main_attack_attri_add; //�����������ӵ������˺�
int main_attack_attri_add_per; //�����������ӵ������˺��ٷֱ�
int other_attack_attri_add; //����.. 
int other_attack_attri_add_per; //����..
//��������������ӵ�ħ��������ɵ��˺�(��ֵ���Ѿ������˿��Դ����������Ľ��)����Ҫ����mudlib2/inher
// it/feature/fight.pike��attack()�������á����⣬�����Ե���������attack()�����е���get_attack_
// mofa_add()ʵ�ֵ�
int huo_add;
int bing_add;
int feng_add;
int du_add;
int spec_add;

//��ҶԵ���ʩ�ŵļ���ħ����������������debuffӳ������¼
// ��ʽΪ��debuff=([
//						"dot":({string name,int damage,int time_remain})
//						"curse":({string type,int value,int time_remain,})
//				  ])
//��ʽ�ǹ̶���
//�Ժ������չ����curse����dot״̬
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

//����ħ������debuff��curse���෴��
//��ʽ: buff = ([
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
		"mianzhan":({"none",0,0}),    //��ս
		"home_attack":({"none",0,0}),         //������                all
		"home_luck":({"none",0,0}),           //����                  luck
		"home_base":({"none",0,0}),           //��������              luck
		"home_defend":({"none",0,0}),           //��������              luck
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

//���ṩ��Ӧ�Ľӿ�.��fight.pike��_fight()��������
//��liaocheng��07/1/29���
//���ⲿ���õ�����main_attack_attri_add��other_attack_attri_add��Ա�����Ľӿ�
void set_attack_attri_add(string type,int val)
{
	if(type=="main") {
		main_attack_attri_add=val;
	}
	else if(type=="other") {
		other_attack_attri_add=val;
	}
}

//���ⲿ���õ�����main_attack_attri_add_per��other_attack_attri_add_per��Ա�����Ľӿ�
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

//��liaocheng��07/3/1���
//���ϵͳ///////////////////////////////
object first_target;//��¼��һ���Ŀ��
mapping(object:int) targets =([]); //����б�npc����Ҷ����У����������ȴ�ǲ�ͬ��
//�ӿڣ�������ֵ����б�Ҳ���ǳ���б�����
void reset_targets()  
{
	first_target=0;
	targets=([]);
}
//�ӿڣ����ڸ��³���б�,û�ڳ���б������룬�ڳ���б����ı�����ֵ
void flush_targets(object ob, int val)
{
	if(ob&&val>0){
		//������ڳ���б������
		if(targets[ob]==0) 
			targets[ob]=val;
		//�ڣ���ı�����ֵ
		else 
			targets[ob]+=val;
	}
}
//�ӿڣ����ڻ�ù���Ŀ��
//����object��ʾ��Ŀ�꣬����������Ϊfirst_target
//����0��ʾ�Ѿ�û��Ŀ��
object get_target()
{
	int max=0;
	object tmp_ob=0;
	if(targets){
		//��ѯ����б��õ����޵�һ��Ŀ��
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
//�ӿڣ����ڷ����Ƿ�targetsΪ��
//����1����ʾtargetsΪ����
//����0����ʾtargets��Ϊ��
int if_targets_null()
{
	int n=sizeof(targets);
	if(n==0)
		return 1;
	else return 0;
}
//�ӿڣ����ڼ������Ƿ���targets��
//����1����
//	  0������
int if_in_targets(object ob)
{
	if(ob&&targets[ob])
		return 1;
	else 
		return 0;
}
//�ӿڣ������������б��е�ĳ��
void clean_targets(object ob)
{
	if(ob&&targets[ob])
		m_delete(targets,ob);
}

//�ӿڣ�������ʾ�����Ŀ��
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
string leave_direction;//�뿪����������ܵ�·��
//���в���ͨ�õķ�������
int gameage;//����
read_write(gameage);
string nickname;//�ǳ�
read_write(nickname);
int bangid;
int hind;
int can_spec;//ѧϰ���⼼�ܵı�ʾ����Ӱ������ݣ����ɵ�������
int sucide; //�ж��Ƿ����ҩ��ɱ��
string fb_id;//��ʱ��¼����id
int set_pic_ok;//��¼����Ƿ��Ѹ�����ͷ��
string roomchatid;
int first_fight;
int life;//����ֵ��Ϊ0ʱ����
int life_max;//�������ֵ����������ֵ������ƣ��뼶������Ա仯����
int mofa;//����ֵ���ͷż�������Ҫ����ֵ
int mofa_max;//�������ֵ���ͷż�������Ҫ����ֵ�����ֵ����̬����仯
int _str;//�������漶���������仯����ƷҲ�д�����
int _dex;//���ݣ��漶���������仯����ƷҲ�д�����
int _think;//�������漶���������仯����ƷҲ�д�����
int _lunck;//���ˣ��漶���������仯
int _appear;//��òֵ���漶���������仯��������Ʒװ�θı�
////////////////////////////////////////////////
string kind_cn;
string unit;
string gender;//�Ա�����:��,Ů,��,��,��,ĸ
string pronoun;//�Ա��ν:��,��,��
string sex;//ͼƬ��ʾKeyֵ��male,female
int disabled_login;//�Ƿ����ε�½
int disabled_post;//�Ƿ����η���
int disabled_action;//�Ƿ������������

int can_speak;//�Ƿ���Թ�ͨ
int can_kill;//�Ƿ����ɱ¾
int can_fight;//�Ƿ�����д�
int can_get_skin;//�Ƿ�ɰ�Ƥ
int can_cut;//�Ƿ���Խ�ʬ���и�Ա���������Ʒ��ϳ�װ�����ߵ�
string attitude;//�Ը������񱩣����ߺ�ƽ
int red_flag;//��������ս��ʹ��

//����id:����������(��ʵ��������������Ӫ)//////////////////////////
string raceId;
read_write(raceId);
static array(string) raceKindList=({"human","monst","third"});
static array(string) raceNameList=({"����","��ħ","����"});
static mapping(string:string) races=([
		raceKindList[0]:raceNameList[0],
		raceKindList[1]:raceNameList[1],
		raceKindList[2]:raceNameList[2]
		]);
/////////////////////////////////////////////////////////////////////
// ְҵid:ְҵ������
//����ְҵ��jianxian:���� yushi:��ʿ zhuxian:����
//��ħְҵ��kuangyao:���� wuyao:���� yinggui:Ӱ��
//npcְҵ->�൱��npc��������Σ�humanlike Ұ�ޣ�beast ���ݣ�bird
//�㣺fish ���ܶ��amphibian ���棺bugs
string profeId;
read_write(profeId);
static array(string) profeKindList=({"jianxian","yushi","zhuxian","kuangyao","wuyao","yinggui","humanlike","beast","bird","fish","amphibian","bugs","dog"});
static array(string) profeNameList=({"����","��ʿ","����","����","����","Ӱ��","����","Ұ��","����","��","���ܶ���","����","��"});
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
////////////////��Ӫ/////////////////////////////////////////////////
string query_race_cn(string rid){
	return races[rid];
}
///////////////ְҵ&npc����/////////////////////////////////////////////////
string query_profe_cn(string pid){
	return profes[pid]; 
}
//�������ඨ��
static mapping(string:int) rnt_wield = ([
		"double_main_weapon" : 2,
		"single_main_weapon" : 3,
		"single_other_weapon": 4
		]);
//���ߣ����Σ��������ඨ��
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
//������Ʒ
private mapping equip=([]);
mapping query_equip(){
	return equip;
}
string query_short(){
	string s="";
	if(this_object()->is("npc")&&this_object()->_boss)
		s += "�������";
	else if(this_object()->is("npc")&&this_object()->_meritocrat)
		s += "�۾�Ӣ��";
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
			return "����";
	}
	else{
		if(this_object()==looker)
			return "��";
		if(!this_object()->sex)
			return "δ֪";
		if(this_object()->sex=="male")
			return "��";
		else if(this_object()->sex=="female")
			return "��";
	}
}
string query_gender(){
	if(this_object()->is("npc")){
		if(this_object()->gender)
			return this_object()->gender;
		else
			return "����";
	}
	else{
		if(this_object()->sex=="male")
			return "��";
		else if(this_object()->sex=="female")
			return "Ů";
		else
			return "����";
	}
}
//�����Ʒ�ϵͳ//////////////////////////////
int user_fee;
int query_user_fee(){
	//return this_object()->user_fee;
	return user_fee;
}
void set_user_fee(int a){
	//this_object()->user_fee = a;
	user_fee = a;
}
//ȡ��ʣ��Сʱ��
int query_user_hour(){
	return query_user_fee()/60;
}
//ȡ��ʣ�������
int query_user_mint(){
	return query_user_fee()%60;
}
private void heart_beat()
{
	//ÿ����ӿ۵�һ�㣬һСʱΪ120��
	if(this_object()->query_user_fee())
		this_object()->set_user_fee(this_object()->query_user_fee()-1);	
	else
		this_object()->set_user_fee(0);	
	//ÿ1���ӻ�Ѫһ�Σ�Ϊ�������ֵ��1/20�������Ͳ���
	if(this_object()->is("npc")){
		if(this_object()->in_combat)
			return;//npc������ս�����Զ���Ѫ
		//npc����ս��״̬�У����Ǳ�������Ѫ������Ѫ�����̲���
		else{
			if(this_object()->life<this_object()->query_life_max())
				this_object()->life=this_object()->query_life_max();
		}
	}
	//��Ҳ���ս���в��ܻ�Ѫ
	if(life<query_life_max()&&!this_object()->in_combat){
		int add=query_life_max()/10;
		if(life+add>query_life_max())
			add=query_life_max()-life;
		life+=add;
	}
	//ÿ1���ӻ���һ�Σ�Ϊ�������ֵ��1/10�������Ͳ���
	if(mofa<query_mofa_max()){
		int add=query_mofa_max()/10;
		if(mofa+add>query_mofa_max()){
			add=query_mofa_max()-mofa;
		}
		mofa+=add;
	}
	//��ҩЧ����ʱ
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
	//��ҩ��Ч��                                                                            
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
	//homeBuff��ʱ
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
	//�̽�ʯЧ����ʱ
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
	//Ѫ���ֵ�Ǹ������������һ�����������仯��ֵ
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
//liaocheng ��07/08/07��ӣ����ڽ����set_base_life()�������Ѫ������������Ч������
//��npc������ʱ����
void flush_life(){
	this_object()->life = this_object()->query_life_max();
}

void set_mofa(int umofa){
	mofa = umofa;
}
int get_cur_mofa(){
	return mofa;
}
int query_mofa_max(){ //�������ֵ�Ǹ��ݵ�ǰ�������仯��ֵ
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

//����������������˵���������֣�һ������ɳ��Ļ������ԣ��������ﱻ�����ܵļӳɣ�����װ���ļӳɡ���:_str��������ɳ��Ļ���������base_str��base_all���������ܵļӳɣ�װ���ļӳ�ͨ��query_equip_add("str")��query_equip_add("all")�����
void set_str(int str){
	_str = str;
}
int get_cur_str(){
	return _str+base_str+base_all;
}
int query_str(){
	int result = 0;
	int equip_str = query_equip_add("str")+query_equip_add("all");//�õ�����װ�����ӵ�����ֵ���Ժ���չ��������Ʒ��ҩƷ��
	result = _str + equip_str;
	//����buff�ӳ�
	if(buff["buff"][0]=="str"||buff["buff"][0]=="all")
		result+=buff["buff"][1];
	//�ҩ�ӳ�
	if(buff["attri_base"][0]=="str")
		result+=buff["attri_base"][1];
	if(buff["te_base"][0]=="str")
		result+=buff["te_base"][1];
	if(buff["home_base"][0]=="str")
		result+=buff["home_base"][1];
	//����ļ���
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
	int equip_think = query_equip_add("think")+query_equip_add("all");//�õ�����װ�����ӵ�����ֵ���Ժ���չ��������Ʒ��ҩƷ��
	result = _think + equip_think;
	//buff���ܼӳ�
	if(buff["buff"][0]=="think"||buff["buff"][0]=="all")
		result+=buff["buff"][1];
	//�ҩ�ӳ�
	if(buff["attri_base"][0]=="think")
		result+=buff["attri_base"][1];
	if(buff["te_base"][0]=="think")
		result+=buff["te_base"][1];
	if(buff["home_base"][0]=="think")
		result+=buff["home_base"][1];
	//�������
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
	int equip_dex = query_equip_add("dex")+query_equip_add("all");//�õ�����װ�����ӵ�����ֵ���Ժ���չ��������Ʒ��ҩƷ��
	result = _dex + equip_dex;
	//buff���ܼӳ�
	if(buff["buff"][0]=="dex"||buff["buff"][0]=="all")
		result+=buff["buff"][1];
	//�ҩ�ӳ�
	if(buff["attri_base"][0]=="dex")
		result+=buff["attri_base"][1];
	if(buff["te_base"][0]=="dex")
		result+=buff["te_base"][1];
	if(buff["home_base"][0]=="dex")
		result+=buff["home_base"][1];
	//�������
	if(debuff["curse"][0]=="dex"||debuff["curse"][0]=="all"){
		result-=debuff["curse"][1];
		if(result<0)
			result=0;
	}
	return result+query_base_dex()+query_base_all();
}
//add by calvin 0409/////////////////////////////////////////
//�����������ӵ����Ե����ÿ��� ������defend,����hitte,����baoji,����dodge
//�¼ӻ�������
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
//�¼ӻ�������
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
	int equip_lunck = query_equip_add("lunck");//�õ�����װ�����ӵ�����ֵ���Ժ���չ��������Ʒ��ҩƷ��
	result = _lunck + equip_lunck;
	int te_lunck = this_object()->query_buff("te_luck",1);//��ҩ
        if(te_lunck)
        	result += te_lunck;
	int home_lunck = this_object()->query_buff("home_luck",1);//��԰buff
        if(home_lunck)
        	result += home_lunck;
	int attri_lunck = this_object()->query_buff("attri_luck",1);//��ҩbuff
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
//ս�����������жԷ���������ĥ��
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
//ս���б��Է����У�������ĥ��
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
//�õ�����װ����Ʒ�����ӵĶ�������
//��liaocheng��07/1/19�޸ģ������arg=="attack_huoyan","attack_bingshuang","attack_fengren","attack_dusu","attack_spec".�Լ���ħ������ ���Բ�ѯ���ܹ���35�ָ�������
int query_equip_add(string arg){
	int power=0;
	if(!arg)
		return power;
	switch(arg) {
		case "str": //��������
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
		case "dex": //���ݸ���
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
		case "think": //��������
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
		case "lunck": //���˸���
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
		case "life": //��������
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
		case "mofa": //��������
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
		case "dodge": //���ܸ���
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
		case "hitte": //���и���
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
		case "doub": //��������
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
		case "attack": //�����˺�����
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
		case "weapon_attack": //���������˺��ٷֱ�
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
		case "rase_life_add": //�����ָ�����
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
		case "rase_mofa_add": //ħ���ָ�����
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
		case "recive": //�����˺�����
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
		case "back": //�����˺�����
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
		case "base_attack_main": //���ֹ�������������
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
		case "base_attack_other": //���ֹ�������������
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
		case "limit_attack_main"://���ֹ�������������
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
		case "limit_attack_other": //���ֹ�������������
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
		case "defend": //����������
			int shuiyu_num = 0;
			foreach(indices(equip),string s){
				object ob=equip[s];
				if(ob&&ob->item_cur_dura>0){
					power+=ob->query_equip_defend();
					//������Ƕ��ʯ�ĸ�������
					int baoshi_power = 0;
					if(ob->query_if_aocao("all")&&ob->query_baoshi("all")){
						foreach(ob->query_baoshi("all"),object tmp){
						//�Ի�ˮ��ϵ�б�ʯ��������ÿ�������������װ���У���Ƕ�Ļ�ˮ��ϵ�б�ʯ���ֻ����4��������ˮ��ϵ�б�ʯ����������4����ʱ����Զ����¸���Ƕ�л�ˮ���װ��
							if(tmp->query_name()=="pshuangshuiyu"||tmp->query_name()=="slhuangshuiyu"||tmp->query_name()=="jinghuangshuiyu"){
								shuiyu_num ++;
							}
							if(shuiyu_num>4){
								//��ˮ����������4�ţ��ѵ������۳���װ�������ӵķ�����
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
		case "speed_main": //���������ٶ�
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
		case "speed_other": //���������ٶ�
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

		case "huo_mofa_attack": //���淨���˺�����
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
		case "bing_mofa_attack": //��˪�����˺�����
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
		case "feng_mofa_attack":  //���з����˺�����
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
		case "du_mofa_attack": //���ط����˺�����
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
		case "spec_mofa_attack": //���ⷨ���˺�����
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
		case "mofa_all": //ȫ�������˺�����
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
		//���������渽���˺���,��ó����������е�ħ�������˺�
		case "attack_huoyan": //���ӻ����˺�
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
		case "attack_bingshuang": //���ӱ�˪�˺�
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
		case "attack_fengren": //���ӷ����˺�
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
		case "attack_dusu": //���Ӷ����˺�
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

		case "all": //ȫ����������
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
		case "huoyan_defend": //���濹�Ը���
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
		//�����ﴦ������ͽ��Ϳ��������Ӱ��
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
		case "bingshuang_defend": //��˪���Ը���
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
		//�����ﴦ������ͽ��Ϳ��������Ӱ��
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
		case "fengren_defend": //���п��Ը���
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
		//�����ﴦ������ͽ��Ϳ��������Ӱ��
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
		case "dusu_defend": //���ؿ��Ը���
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
		//�����ﴦ������ͽ��Ϳ��������Ӱ��
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
		case "all_mofa_defend": //ȫ�������Ը���
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
		case "renxing": //���Ը���
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

//��ҩ�����Լӳ�,��Ҫ������ui����ʾ
//��liaocheng��07/6/6�����
int query_danyao_add(string kind,string type)
{
	if(buff[kind][0] == type)
		return buff[kind][1];
	else 
		return 0;
}

//װ��
int wield(object weapon){
	object ob=present(weapon,this_object());
	//�����ǿ�װ�ص���Ʒis_equip()
	if(ob&&ob->is("equip")){
		//��Ʒװ������=item.pike->item_kind
		//˫������-item_kind=double_main_weapon����������
		//��������-item_kind=single_main_weapon����,�������֣�
		//��������-item_kind=single_other_weapon���֣����븱��
		//Ҫ������û��װ���κ���������ֱ��װ����
		if(equip["double_main_weapon"]==0&&equip["single_main_weapon"]==0&&equip["single_other_weapon"]==0){
			equip[ob->item_kind]=ob;
			ob->equiped=1;
			return rnt_wield[ob->item_kind];
		}
		//������װ����ͬ���͵�����������ж�ص���װ��������
		if(equip[ob->item_kind]!=0)
			unwield(equip[ob->item_kind]);	
		//��Ҫװ���ϵ�������˫�֣���ֱ��װ���ϣ���ж�ؿ�����װ���ϵ������ֵ�����
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
		//��Ҫװ���ϵ������ǵ��֣���ֱ��װ���ϣ���ж�ؿ�����װ���ϵ�˫������
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
//ж��
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
//����
int wear(object armor)
{
	//��Ʒ��������=item.pike->item_kind
	//item_kind=armor_head      �����е�ͷ��
	//item_kind=armor_cloth     �����е��·�
	//item_kind=armor_waste     �����е�����
	//item_kind=armor_hand      �����е�����
	//item_kind=armor_thou      �����еĿ���
	//item_kind=armor_shoes     �����е�Ь��
	//item_kind=jewelry_ring    �����еĽ�ָ
	//item_kind=jewelry_neck    �����е�����
	//item_kind=jewelry_bangle  �����е�����
	//item_kind=decorate_manteau �����е�����
	//item_kind=decorate_thing   �����еĹҼ�
	//item_kind=decorate_tool    �����е�Я����
	object ob=present(armor,this_object());
	if(ob&&ob->is("equip")){
		//�Ѵ������������Ѵ������ٴ������µ�
		if(equip[ob->item_kind]!=0)
		{
			unwear(equip[ob->item_kind]);
			equip[ob->item_kind]=ob;
			ob->equiped=1;
			return rnt[ob->item_kind];
		}
		//δ����ͬ�ණ��ֱ�Ӵ���
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
//��ɫ����,��Ϣ״̬����///////////////////////////////////////
static string unconscious_msg;
private string wake_up_msg;
static multiset(string) status=(<>);
read_write(status);
static string doing_status;
read_write(doing_status);

int is_item(){
	return doing_status=="���Բ���";
}
int is_character(){
	return doing_status!="���Բ���";
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
	doing_status="���Բ���";
	unconscious_msg="�����ڻ��Բ��ѡ�\n";
	wake_up_msg="$N�������ѹ�����\n";
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
	doing_status="˯����";
	unconscious_msg="�㿪ʼ��Ϣ�����ָ�һ���������ͷ�����\n";
	wake_up_msg="$N˯���ˡ�\n";
	disable_commands();
	//��Ϣ�ָ���������
	this_object()->life=this_object()->life_max;
	this_object()->mofa=this_object()->mofa_max;

	call_out(wake_up,10);
}

//Evan 22008.11.21 Ϊ��ʵ�����������sleep״̬������
void sleep_for_learn(int time)                                                                                                      
{   
	doing_status="������";
	unconscious_msg="���������ڱչ�����\n[�鿴�������:_break_then_auto_learn_check]\n[�ж�����:_break_then_auto_learn_end_submit]\n";      
	wake_up_msg="$N���������\n";
	disable_commands();
	call_out(wake_up,time*60);//�����ĵ�λ��"��"������Ҫ�������
}  

void wakeup_from_auto_learn()                                                                                                       
{
	wake_up();
}
//end of evan added 20081121

void exercise(object room)
{
	doing_status="������";
	object player = this_player();
	string name_cn = room->query_name_cn();
	string kind = room->query_buff_kind();
	string type = room->query_buff_type();
	int effect_value = room->query_buff_value();
	int timedelay = room->query_effect_time();
	int need_time = room->query_wait_time();
	unconscious_msg = room->query_oprate_desc() + "(��Ҫ����"+need_time/60+"����)\n";
	player->set_buff(kind,0,type);
	player->set_buff(kind,1,effect_value);
	player->set_buff(kind,2,timedelay/60);//����char.pike������1minΪһ����
	player["/homeBuff/"+kind] = ({type,effect_value,timedelay/60,name_cn});   

	wake_up_msg="$N��������ˡ�\n";
	disable_commands();
	call_out(wake_up,need_time);
}
//��������=������������+װ����������+��������(����100%)
//��liaocheng��07/1/8��ӣ������ж��Ƿ�����
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
		h -= debuff["curse"][1];//�����ҵ�������
		if(h<0)
			h=0;
	}
	return (int)h;
	/*	hInt = (int)(h*100);
		if(hInt>=random(10000))//��ϲ�㣬������
		return 1;
		else
		return 0;//��ϲ�㣬δ����
	 */
}
//��liaocheng��07/1/8��ӣ������ж��Ƿ��������
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
		return 1;//��ϲ�㣬������
	else
		return 0;//Ҳ��ϲ�㣬���б���

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
	//Ӱ��70���ܱ���Ч��
	if(this_object()->hind && buff["70_skill_buff"][0] == "cuidu" && buff["70_skill_buff"][1]){
		b += buff["70_skill_buff"][1];
		buff["70_skill_buff"][1] = 0;
	}
	//����Է��Ƿ������ԣ�ÿ40�����Լ���1%��ͨ�˺��ı�������
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
//char������Ϊ1����
private string initer=(enable_commands(),this_object()->add_heart_beat(heart_beat,30),"");
