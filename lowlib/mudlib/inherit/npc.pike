#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_BASE;
inherit LOW_F_DBASE;
inherit LOW_F_CMDS;
inherit MUD_F_HEARTBEAT;

inherit MUD_F_CHAR;//生物角色继承属性
inherit MUD_F_ATTACK;//npc战斗属性计算

//////////npc的新添加各种属性////////////////////////////////////////////////////
int _npcLevel;//等级
read_write(_npcLevel);
int _costom_npc_life;//自定义该npc生命值
int _costom_npc_mofa;//自定义该npc法力值
int _levelup;//是否可以自动升级
read_write(_levelup);
int _meritocrat;//是否精英怪
read_write(_meritocrat);
int _boss;//是否boss怪
read_write(_boss);
int _rare;//是否稀有怪
read_write(_rare);
int _domestication;//是否可以驯服
read_write(_domestication);
int _autolevel;//自动调整等级,和攻击他的玩家等级相同
read_write(_autolevel);
int _tasknpc;//是否任务类型npc
read_write(_tasknpc);
int _killauto;//是否自动杀戮,主动攻击类型npc
read_write(_killauto);
int _skillsable;//是否拥有技能
read_write(_skillsable);
int _troth;//忠诚度
read_write(_troth);
string _randomwords;//随机话语
read_write(_randomwords);
int _equiped;//是否可以装备武器
read_write(_equiped);
int _flushtime;//刷新时间
read_write(_flushtime);
int _hate;//仇恨值
read_write(_hate);
private array(string) _fightwith;//仇人记忆
private array(string) _fight_now;//杀戮该Npc的当前玩家列表，然后根据仇恨值来确定攻击哪一个
int _fury;//狂暴几率
read_write(_fury);
int _recovery;//怪物回血设置
read_write(_recovery);
int feed_time;//喂养时间

//在城战中分类npc liaocheng于07/07/27添加                                                           
string _type = "";
void set_npc_type(string s){
	_type = s;
}
string query_npc_type(){
	return _type;
}

void set_feed_time(int f_time){
	feed_time = f_time;
}
int query_feed_time(){
	return feed_time;
}

void setup_npc(){
	if(this_object()->query_raceId()=="human"&&this_object()->query_profeId()=="humanlike"){
		kind_cn = "人类";
		unit = "位";
		//gender = "男性";
	}
	else if(this_object()->query_raceId()=="monst"&&this_object()->query_profeId()=="humanlike"){
		kind_cn = "妖魔";
		unit = "位";
		//gender = "男性";
	}
	else if(this_object()->query_profeId()=="beast"){
		kind_cn = "野兽";
		unit = "只";
		//gender = "雄性";
	}
	else if(this_object()->query_profeId()=="bird"){
		kind_cn = "飞禽";
		unit = "只";
		//gender = "雄性";
	}
	else if(this_object()->query_profeId()=="fish"){
		kind_cn = "鱼";
		unit = "条";
		//gender = "雄性";
	}
	else if(this_object()->query_profeId()=="bugs"){
		kind_cn = "昆虫";
		unit = "只";
		//gender = "雄性";
	}
	else if(this_object()->query_profeId()=="amphibian"){
		kind_cn = "两栖动物";
		unit = "只";
		//gender = "雄性";
	}
	else if(this_object()->query_profeId()=="dog"){
		kind_cn = "狗";
		unit = "只";
		//gender = "雄性";
	}
	//得到该等级的npc基本属性值
	npc_level_define();
}
//该方法自动根据npc类型和等级，生成该Npc基本属性值
void npc_level_define(){
	int npcLevel = _npcLevel-1;
	//npc类型，等级不同，得到的基本属性计算公式也不同
	string u_profe = this_object()->query_profeId();
	if(u_profe){
		int i_profe = m_profe[u_profe];
		switch(i_profe){
			////////////////////////////////////////////////////	
			case 7://人形 包括人类和妖魔
				{
					//初始值
					_str = 3;//力量
					_dex = 6;//敏捷
					_think = 6;//智力
					_lunck = 0;//幸运
					_appear = 20;//容貌
					//力量算法////////////////////
					int need = 0;
					for(int i=0; i<=npcLevel; i++)
						need += 3+(int)(i/10);
					_str += need;
					//十级以下怪力量/2
					//if(npcLevel<=9)
					//	_str = _str/2;
					//力量算法////////////////////
					_dex += npcLevel;//敏捷算法 + 装备的物品附加敏捷总和
					_think += npcLevel*4;//智力算法 + 装备的物品附加智力总和
					_lunck = 0;//幸运算法 + 装备的物品附加幸运总和
					_appear = 20;//容貌
				}
				break;
				////////////////////////////////////////////////////	
			case 8://野兽
				{
					//初始值
					_str = 6;//力量
					_dex = 2;//敏捷
					_think = 2;//智力
					_lunck = 0;//幸运
					_appear = 20;//容貌
					//力量算法////////////////////
					int need = 0;
					for(int i=0; i<=npcLevel; i++)
						need += 4+(int)(i/10);	
					_str += need;
					//十级以下怪力量/2
					//if(npcLevel<=9)
					//	_str = _str/2;
					//力量算法////////////////////
					_dex += npcLevel;//敏捷算法 + 装备的物品附加敏捷总和
					_think += npcLevel*2;//智力算法 + 装备的物品附加智力总和
					_lunck = 0;//幸运算法 + 装备的物品附加幸运总和
					_appear = 20;//容貌
				}
				break;
				////////////////////////////////////////////////////	
			case 9://飞禽
				{
					//初始值
					_str = 3;//力量
					_dex = 12;//敏捷
					_think = 4;//智力
					_lunck = 0;//幸运
					_appear = 20;//容貌
					//力量算法////////////////////
					int need = 0;
					for(int i=0; i<=npcLevel; i++)
						need += 3+(int)(i/10);	
					_str += need;
					//十级以下怪力量/2
					//if(npcLevel<=9)
					//	_str = _str/2;
					//力量算法////////////////////
					_dex += npcLevel*4;//敏捷算法 + 装备的物品附加敏捷总和
					_think += npcLevel;//智力算法 + 装备的物品附加智力总和
					_lunck = 0;//幸运算法 + 装备的物品附加幸运总和
					_appear = 20;//容貌
				}
				break;
				////////////////////////////////////////////////////	
			case 10://鱼
				{
					//初始值
					_str = 3;//力量
					_dex = 12;//敏捷
					_think = 4;//智力
					_lunck = 0;//幸运
					_appear = 20;//容貌
					//力量算法////////////////////
					int need = 0;
					for(int i=0; i<=npcLevel; i++)
						need += 3+(int)(i/10);	
					_str += need;
					//十级以下怪力量/2
					//if(npcLevel<=9)
					//	_str = _str/2;
					_dex += npcLevel*4;//敏捷算法 + 装备的物品附加敏捷总和
					_think += npcLevel;//智力算法 + 装备的物品附加智力总和
					_lunck = 0;//幸运算法 + 装备的物品附加幸运总和
					_appear = 20;//容貌
				}
				break;
				////////////////////////////////////////////////////	
			case 11://两栖动物
				{
					//初始值
					_str = 3;//力量
					_dex = 12;//敏捷
					_think = 4;//智力
					_lunck = 0;//幸运
					_appear = 20;//容貌
					//力量算法////////////////////
					int need = 0;
					for(int i=0; i<=npcLevel; i++)
						need += 3+(int)(i/10);	
					_str += need;
					//十级以下怪力量/2
					//if(npcLevel<=9)
					//	_str = _str/2;
					_dex += npcLevel*4;//敏捷算法 + 装备的物品附加敏捷总和
					_think += npcLevel;//智力算法 + 装备的物品附加智力总和
					_lunck = 0;//幸运算法 + 装备的物品附加幸运总和
					_appear = 20;//容貌
				}
				break;
				////////////////////////////////////////////////////	
			case 12://虫类
				{
					//初始值
					_str = 3;//力量
					_dex = 12;//敏捷
					_think = 4;//智力
					_lunck = 0;//幸运
					_appear = 20;//容貌
					//力量算法////////////////////
					int need = 0;
					for(int i=0; i<=npcLevel; i++)
						need += 3+(int)(i/10);	
					_str += need;
					//十级以下怪力量/2
					//if(npcLevel<=9)
					//	_str = _str/2;
					_dex += npcLevel*4;//敏捷算法 + 装备的物品附加敏捷总和
					_think += npcLevel;//智力算法 + 装备的物品附加智力总和
					_lunck = 0;//幸运算法 + 装备的物品附加幸运总和
					_appear = 20;//容貌

					//set_str(_str);
				}
				break;
				////////////////////////////////////////////////////	
				/*
			case 13://看门狗
				{
					_costom_npc_life = 3000;
					_str = 30;
					_think = 30;
					_dex = 30;
				}
				break;
				*/
		}

		//精英怪和boss怪的处理，分别是精英*2,boss*3
		if(_meritocrat==1){
			_str = _str*3;
			_dex = _dex*3;//敏捷
			_think = _think*3;//智力
		}
		else if(_boss==1){
			_str = _str*6;
			_dex = _dex*6;//敏捷
			_think = _think*6;//智力
		}
		life = _str*10;//生命=生命上限
		life_max = life;
		mofa = _think*10;//法力=法力上限
		mofa_max = mofa;
		//如果自定义了该npc的生命值，返回自定义生命值
		if(_costom_npc_life!=0)
			life=life_max=_costom_npc_life;
		if(_costom_npc_mofa!=0)
			mofa=mofa_max=_costom_npc_mofa;
	}
}
int is_npc(){
	return 1;
}
int query_level(){
	return _npcLevel==0?1:_npcLevel;
}
//重载char.pike中的性别描述和性别称谓
	string query_pronoun(void|object looker){
		if(pronoun)
			return pronoun;
		else
			return "不明";
	}
	string query_gender(){
		if(gender)
			return gender;
		else
			return "不明";
	}

