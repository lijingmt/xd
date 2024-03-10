#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_BASE;
inherit LOW_F_DBASE;
inherit MUD_F_HEARTBEAT;
static mapping(int:string) m_rareLevel = ([
	0:"",
	1:"��������",
	2:"��������",
	3:"�����ơ�",
	4:"�����ơ�",
	5:"��������",
	6:"���콵��",
	7:"���û���"
]);
//��Ʒͨ�ü̳еĻ�������
private string item_type;//��Ʒ�������weapon(��˫��,single_weapon,double_weapon)����armor����jewelry����decorat����Ʒfood��
string query_item_type(){return item_type;}
void set_item_type(string s){ item_type= s;}

private string item_weapon_type;//��������Ʒ��ϸ�ֱ𣺽�sword����blade,��,xxx
string query_item_weapon_type(){return item_weapon_type;}
void set_item_weapon_type(string s){ item_weapon_type= s;}

private int item_level=0;//��Ʒ����ȼ�������Ʒװ����Ҫ���Ƶĵȼ�Ҫ���޹�
int query_item_level(){return item_level;}
void set_item_level(int a){ item_level= a;}

private int item_strLimit=0;//װ����Ʒ��Ҫ���������ƣ�����������Ҫ30�㣬������Ҫ10��ȵȡ�
int query_item_strLimit(){return item_strLimit;}
void set_item_strLimit(int a){ item_strLimit= a;}

private int item_dexLimit=0;//װ����Ʒ��Ҫ���������ƣ�����������Ҫ30�㣬������Ҫ10��ȵȡ�
int query_item_dexLimit(){return item_dexLimit;}
void set_item_dexLimit(int a){ item_dexLimit= a;}

private int item_thinkLimit=0;//װ����Ʒ��Ҫ���������ƣ�����������Ҫ30�㣬������Ҫ10��ȵȡ�
int query_item_thinkLimit(){return item_thinkLimit;}
void set_item_thinkLimit(int a){ item_thinkLimit= a;}

private int item_rareLevel=0;//��Ʒϡ�г̶ȣ���Ϊ5���ȼ�,1-2����������Ϊ1->����3-4����������Ϊ2->��...5->��
int query_item_rareLevel(){return item_rareLevel;}
void set_item_rareLevel(int a){ item_rareLevel= a;}

string query_rare_level(){
	return m_rareLevel[item_rareLevel]; 
}

//��Ʒ����Դ
//Ŀǰ��Դ�У�"boss"��"task"��"honer"��"duanzao"
private string item_from="";
void set_item_from(string s){item_from=s;}
string query_item_from(){return item_from;}

//��Ʒ��Ҫ��������ֵ���� ����Ҫ���������Ʒ
private int need_honer=0;
void set_need_honer(int a){need_honer=a;}
int query_need_honer(){return need_honer;}


private int item_save=1;//�Ƿ�Ψһ��Ʒ��ֻ��Я����װ��һ��
int query_item_save(){return item_save;}
void set_item_save(int a){ item_save= a;}

private int item_only=0;//�Ƿ�Ψһ��Ʒ��ֻ��Я����װ��һ��
int query_item_only(){return item_only;}
void set_item_only(int a){ item_only= a;}

private int item_canDura=1;//�Ƿ�ᱻĥ��ı�־�������ָ������������Ʒ�Ȳ���ĥ��
int query_item_canDura(){return item_canDura;}
void set_item_canDura(int a){ item_canDura= a;}

private int item_canEquip=1;//��Ʒ�ɷ�װ��������������Ʒ��û�����֮ǰ�ǲ���װ���ģ��ȵ�
int query_item_canEquip(){return item_canEquip;}
void set_item_canEquip(int a){ item_canEquip= a;}

private int item_canDrop=1;//��Ʒ�Ƿ���Զ���
int query_item_canDrop(){return item_canDrop;}
void set_item_canDrop(int a){ item_canDrop= a;}

private int item_canGet=0;//��Ʒ�Ƿ���Լ���
int query_item_canGet(){return item_canGet;}
void set_item_canGet(int a){ item_canGet= a;}

private int item_canTrade=1;//��Ʒ�Ƿ���Խ���
int query_item_canTrade(){return item_canTrade;}
void set_item_canTrade(int a){ item_canTrade= a;}

private int item_canSend=1;//��Ʒ�Ƿ��������
int query_item_canSend(){return item_canSend;}
void set_item_canSend(int a){ item_canSend= a;}

private int item_task=0;//��Ʒ�Ƿ���������Ʒ
int query_item_task(){return item_task;}
void set_item_task(int a){ item_task= a;}

private int item_canStorage=1;//��Ʒ�Ƿ���Դ洢�ֿ����������
int query_item_canStorage(){return item_canStorage;}
void set_item_canStorage(int a){ item_canStorage= a;}

string item_playerDesc;//������������Լ���־����Ʒ
string item_whoCanGet;//������Ҵ�ֵ�����Ʒ��ʾ�����ڵ�װ���� 2007-0302 by calvin
int item_TimewhoCanGet;//������Ҵ�ֵ�����Ʒʱ����ƣ����ڵ�װ���� 2007-0302 by calvin

int amount=1;//����
int max_count=STACK_NUM;//������Ʒÿ����������
static string unit="��";//��λ
string query_unit(){ return unit;}


static int value;//��ֵ
int query_value(){return value;}
void set_value(int a){ value= a;}

private int weight;//����
int query_weight(){return weight;}
void set_weight(int s){ weight= s;}

static string status;//״̬
string query_status(){return status;}
void set_status(string s){ status= s;}

static int add_luck = 0;//���ӵ�����ֵ������ʱ��ʯ�������
int query_add_luck(){return add_luck;}
void set_add_luck(int s){ add_luck = s;}

int is_item(){return 1;}

string query_short(){
	string s="";
	if(status){
		s="<"+status+">";
	}
	return "һ"+unit+::query_name_cn()+s;
}
void remove(void|int judgement){
	if(judgement){
		object env=environment(this_object());
		if(!env||(env&&env->is("room"))) 
			::remove();
		else 
			return;
	}
	else
		::remove();
}
int is_combine_item()
{
	return 0;
}
//������08/11/26////////////////////////////////
int red_aocao = 0;//��ɫ���а���
int blue_aocao = 0;//��ɫ���а���
int yellow_aocao = 0;//��ɫ���а���
int red_aocao_max = 0;//��ɫ����
int blue_aocao_max = 0;//��ɫ����
int yellow_aocao_max = 0;//��ɫ����
void set_aocao(string color,int num){ 
	switch(color){
		case "blue": blue_aocao = num;
			     break;
		case "red" : red_aocao = num;
			     break;
		case "yellow":yellow_aocao = num;
			     break;
	}
}
void set_aocao_max(string color,int num){ 
	switch(color){
		case "blue": blue_aocao_max = blue_aocao = num;
			     break;
		case "red" : red_aocao_max =red_aocao= num;
			     break;
		case "yellow":yellow_aocao_max = yellow_aocao = num;
			     break;
	}
}

//������Ӧ���а��۵�����
int query_aocao(string color){
	int num = 0;
	switch(color){
		case "blue": num = blue_aocao;//��ɫ
			     break;
		case "red" : num = red_aocao;//��ɫ
			     break;
		case "yellow":num = yellow_aocao;//��ɫ����
			     break;
		case "all" : num = blue_aocao + red_aocao + yellow_aocao;//���а���
			     break;
	}
	return num;
}
//������Ӧ���۵�����
int query_aocao_max(string color){
	object ob=this_object();
	int num = 0;
	switch(color){
		case "blue": num = ob->blue_aocao_max;//��ɫ
			     break;
		case "red" : num = ob->red_aocao_max;//��ɫ
			     break;
		case "yellow":num = ob->yellow_aocao_max;//��ɫ����
			     break;
		case "all" : num = ob->blue_aocao_max + ob->red_aocao_max + ob->yellow_aocao_max;//���а���
			     break;
	}
	return num;
}

array(string) red_baoshi = ({}); //��ɫ��ʯ
array(string) blue_baoshi = ({}); //��ɫ��ʯ
array(string) yellow_baoshi = ({}); //��ɫ��ʯ

void set_baoshi(string color,object baoshi_ob,void|int ind){
	object ob = this_object();
	string baoshi = file_name(baoshi_ob)-ITEM_PATH;
	baoshi = (baoshi/"#")[0];//��ñ�ʯ���ļ�·������baoshi/pshongchuoshi
	switch(color){
		case "blue":
			if(!ob->blue_baoshi){ ob->blue_baoshi = ({});}
			//else if(!sizeof(blue_baoshi)){ blue_baoshi += ({s});}
			if(!ind){
				ob->blue_baoshi += ({baoshi});
			}
			else{
				int num = sizeof(ob->blue_baoshi);
				if(ind<=num){
					ob->blue_baoshi[ind-1]=baoshi;
				}
			}
			break;
		case "red":
			if(!ob->red_baoshi){ ob->red_baoshi = ({});}
			if(!ind){
				ob->red_baoshi += ({baoshi});
			}
			else{
				int num = sizeof(ob->red_baoshi);
				if(ind<=num){
					ob->red_baoshi[ind-1]=baoshi;
				}
			}
			break;
		case "yellow":
			if(!ob->yellow_baoshi){ ob->yellow_baoshi = ({});}
			if(!ind){
				ob->yellow_baoshi += ({baoshi});
			}
			else{
				int num = sizeof(ob->yellow_baoshi);
				if(ind<=num){
					ob->yellow_baoshi[ind-1]=baoshi;
				}
			}
			break;
	}
}

//ͨ��id�������Ӧ�ı�ʯ�������ļ���,�磺baoshi/slhuangshuiyu
string query_baoshi_by_id(string color,int id){
	object ob = this_object();
	string baoshi_name = "";
	switch(color){
		case "blue": 
			if(id<sizeof(ob->blue_baoshi)){
				baoshi_name = ob->blue_baoshi[id];
			}
			break;
		case "yellow": 
			if(id<sizeof(ob->yellow_baoshi)){
				baoshi_name = ob->yellow_baoshi[id];
			}
			break;
		case "red": 
			if(id<sizeof(ob->red_baoshi)){
				baoshi_name = ob->red_baoshi[id];
			}
			break;
	}
	//werror("---baoshi_name="+baoshi_name+"--\n");
	return baoshi_name;
}

//��ñ�ʯ
array(object) query_baoshi(string color){
	object ob = this_object();
	array(object) baoshi_ob = ({});
	switch(color){
		case "blue": 
			//blue_baoshi_ob = ({});
			if(ob->blue_baoshi && sizeof(ob->blue_baoshi)){
				foreach(ob->blue_baoshi,string eachName){
					object ob_tmp = (object)(ITEM_PATH+eachName);
					baoshi_ob += ({ob_tmp});
				}
			}
			break;
		case "red" : 
			if(ob->red_baoshi && sizeof(ob->red_baoshi)){
				foreach(ob->red_baoshi,string eachName){
					object ob_tmp = (object)(ITEM_PATH+eachName);
					baoshi_ob += ({ob_tmp});
				}
			}
			break;
		case "yellow":
			//yellow_baoshi_ob = ({});
			if(ob->yellow_baoshi && sizeof(ob->yellow_baoshi)){
				foreach(ob->yellow_baoshi,string eachName){
					object ob_tmp = (object)(ITEM_PATH+eachName);
					baoshi_ob += ({ob_tmp});
				}
			}    
			break;
		case "all" :
			if(ob->query_baoshi("blue")){
				baoshi_ob += ob->query_baoshi("blue");
			}
			if(ob->query_baoshi("red")){
				baoshi_ob += ob->query_baoshi("red");
			}
			if(ob->query_baoshi("yellow")){
				baoshi_ob += ob->query_baoshi("yellow");
			}
			break;
	}
	if(sizeof(baoshi_ob))
		return baoshi_ob;
	else 
		return 0;
}

//�жϸ�װ���Ƿ������Ӧ��ɫ�İ���
int query_if_aocao(string s){
	object ob = this_object();
	if(ob->query_aocao_max(s))
		return 1;
	else
		return 0;
}
//end 08/11/26
