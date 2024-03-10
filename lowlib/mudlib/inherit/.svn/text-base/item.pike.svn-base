#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_BASE;
inherit LOW_F_DBASE;
inherit MUD_F_HEARTBEAT;
static mapping(int:string) m_rareLevel = ([
	0:"",
	1:"【优良】",
	2:"【优良】",
	3:"【精制】",
	4:"【精制】",
	5:"【神炼】",
	6:"【天降】",
	7:"【幻化】"
]);
//物品通用继承的基本属性
private string item_type;//物品类别：武器weapon(单双手,single_weapon,double_weapon)防具armor首饰jewelry饰物decorat消耗品food等
string query_item_type(){return item_type;}
void set_item_type(string s){ item_type= s;}

private string item_weapon_type;//武器类物品详细分别：剑sword，刀blade,棍,xxx
string query_item_weapon_type(){return item_weapon_type;}
void set_item_weapon_type(string s){ item_weapon_type= s;}

private int item_level=0;//物品自身等级，和物品装备需要限制的等级要求无关
int query_item_level(){return item_level;}
void set_item_level(int a){ item_level= a;}

private int item_strLimit=0;//装备物品需要的属性限制，比如力量需要30点，智力需要10点等等。
int query_item_strLimit(){return item_strLimit;}
void set_item_strLimit(int a){ item_strLimit= a;}

private int item_dexLimit=0;//装备物品需要的属性限制，比如力量需要30点，智力需要10点等等。
int query_item_dexLimit(){return item_dexLimit;}
void set_item_dexLimit(int a){ item_dexLimit= a;}

private int item_thinkLimit=0;//装备物品需要的属性限制，比如力量需要30点，智力需要10点等等。
int query_item_thinkLimit(){return item_thinkLimit;}
void set_item_thinkLimit(int a){ item_thinkLimit= a;}

private int item_rareLevel=0;//物品稀有程度，分为5个等级,1-2个附加属性为1->精，3-4个附加属性为2->天...5->幻
int query_item_rareLevel(){return item_rareLevel;}
void set_item_rareLevel(int a){ item_rareLevel= a;}

string query_rare_level(){
	return m_rareLevel[item_rareLevel]; 
}

//物品的来源
//目前来源有："boss"，"task"，"honer"，"duanzao"
private string item_from="";
void set_item_from(string s){item_from=s;}
string query_item_from(){return item_from;}

//物品需要多少荣誉值购买 ，主要针对荣誉物品
private int need_honer=0;
void set_need_honer(int a){need_honer=a;}
int query_need_honer(){return need_honer;}


private int item_save=1;//是否唯一物品，只能携带或装备一个
int query_item_save(){return item_save;}
void set_item_save(int a){ item_save= a;}

private int item_only=0;//是否唯一物品，只能携带或装备一个
int query_item_only(){return item_only;}
void set_item_only(int a){ item_only= a;}

private int item_canDura=1;//是否会被磨损的标志，比如戒指项链和任务物品等不会磨损
int query_item_canDura(){return item_canDura;}
void set_item_canDura(int a){ item_canDura= a;}

private int item_canEquip=1;//物品可否装备，比如任务物品，没有完成之前是不可装备的，等等
int query_item_canEquip(){return item_canEquip;}
void set_item_canEquip(int a){ item_canEquip= a;}

private int item_canDrop=1;//物品是否可以丢弃
int query_item_canDrop(){return item_canDrop;}
void set_item_canDrop(int a){ item_canDrop= a;}

private int item_canGet=0;//物品是否可以检起
int query_item_canGet(){return item_canGet;}
void set_item_canGet(int a){ item_canGet= a;}

private int item_canTrade=1;//物品是否可以交易
int query_item_canTrade(){return item_canTrade;}
void set_item_canTrade(int a){ item_canTrade= a;}

private int item_canSend=1;//物品是否可以赠送
int query_item_canSend(){return item_canSend;}
void set_item_canSend(int a){ item_canSend= a;}

private int item_task=0;//物品是否是任务物品
int query_item_task(){return item_task;}
void set_item_task(int a){ item_task= a;}

private int item_canStorage=1;//物品是否可以存储仓库或者银行中
int query_item_canStorage(){return item_canStorage;}
void set_item_canStorage(int a){ item_canStorage= a;}

string item_playerDesc;//可以增加玩家自己标志的物品
string item_whoCanGet;//增加玩家打怪掉落物品标示，用于掉装保护 2007-0302 by calvin
int item_TimewhoCanGet;//增加玩家打怪掉落物品时间控制，用于掉装保护 2007-0302 by calvin

int amount=1;//数量
int max_count=STACK_NUM;//该种物品每组数量上限
static string unit="个";//单位
string query_unit(){ return unit;}


static int value;//价值
int query_value(){return value;}
void set_value(int a){ value= a;}

private int weight;//重量
int query_weight(){return weight;}
void set_weight(int s){ weight= s;}

static string status;//状态
string query_status(){return status;}
void set_status(string s){ status= s;}

static int add_luck = 0;//增加的幸运值，锻造时宝石需用这个
int query_add_luck(){return add_luck;}
void set_add_luck(int s){ add_luck = s;}

int is_item(){return 1;}

string query_short(){
	string s="";
	if(status){
		s="<"+status+">";
	}
	return "一"+unit+::query_name_cn()+s;
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
//新属性08/11/26////////////////////////////////
int red_aocao = 0;//红色空闲凹槽
int blue_aocao = 0;//蓝色空闲凹槽
int yellow_aocao = 0;//黄色空闲凹槽
int red_aocao_max = 0;//红色凹槽
int blue_aocao_max = 0;//蓝色凹槽
int yellow_aocao_max = 0;//黄色凹槽
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

//获得相对应空闲凹槽的数量
int query_aocao(string color){
	int num = 0;
	switch(color){
		case "blue": num = blue_aocao;//蓝色
			     break;
		case "red" : num = red_aocao;//红色
			     break;
		case "yellow":num = yellow_aocao;//黄色凹槽
			     break;
		case "all" : num = blue_aocao + red_aocao + yellow_aocao;//所有凹槽
			     break;
	}
	return num;
}
//获得相对应凹槽的数量
int query_aocao_max(string color){
	object ob=this_object();
	int num = 0;
	switch(color){
		case "blue": num = ob->blue_aocao_max;//蓝色
			     break;
		case "red" : num = ob->red_aocao_max;//红色
			     break;
		case "yellow":num = ob->yellow_aocao_max;//黄色凹槽
			     break;
		case "all" : num = ob->blue_aocao_max + ob->red_aocao_max + ob->yellow_aocao_max;//所有凹槽
			     break;
	}
	return num;
}

array(string) red_baoshi = ({}); //红色宝石
array(string) blue_baoshi = ({}); //蓝色宝石
array(string) yellow_baoshi = ({}); //黄色宝石

void set_baoshi(string color,object baoshi_ob,void|int ind){
	object ob = this_object();
	string baoshi = file_name(baoshi_ob)-ITEM_PATH;
	baoshi = (baoshi/"#")[0];//获得宝石的文件路径，如baoshi/pshongchuoshi
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

//通过id查找相对应的宝石，返回文件名,如：baoshi/slhuangshuiyu
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

//获得宝石
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

//判断该装备是否有相对应颜色的凹槽
int query_if_aocao(string s){
	object ob = this_object();
	if(ob->query_aocao_max(s))
		return 1;
	else
		return 0;
}
//end 08/11/26
