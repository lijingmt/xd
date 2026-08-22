#include <globals.h>
#include <mudlib/include/mudlib.h>
// 平衡过渡期全局怪物强度（低层文件不能依赖gamelib.h，按fight.pike
// 先例使用本地define）。
// 平衡过渡期：怪物出生生命乘全局系数。Worker 不预加载守护进程，
// 因此直接读 JSON 配置文件（30 秒 TTL 缓存），无文件时默认 2%。
private int transition_life_cache=0;
private int transition_life_cached_at;
private int transition_life_file_mtime;

private int transition_query_life_percent()
{
	int now=time();
	int mtime;
	Stdio.Stat stat=file_stat(ROOT+"/data_xiand/balance_transition.json");
	mtime=stat ? (int)stat->mtime : 0;
	if(transition_life_cached_at && now-transition_life_cached_at<30 &&
	   mtime==transition_life_file_mtime)
		return transition_life_cache;
	transition_life_cached_at=now;
	transition_life_file_mtime=mtime;
	transition_life_cache=100;
	if(mtime){
		mixed err=catch{
			mapping record=Standards.JSON.decode(
				Stdio.read_file(ROOT+
					"/data_xiand/balance_transition.json"));
			if(mappingp(record))
				transition_life_cache=(int)record["life_percent"];
		};
		if(err)
			transition_life_cache=100;
	}
	else
		transition_life_cache=2;
	if(transition_life_cache<1 || transition_life_cache>200)
		transition_life_cache=100;
	return transition_life_cache;
}

private int transition_scaled_life(int raw_life)
{
	if(raw_life<=0)
		return raw_life;
	return raw_life*transition_query_life_percent()/100;
}

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
int _team_required_boss;//是否需要 3 人以上队伍才能挑战的硬 Boss
read_write(_team_required_boss);
int _team_required_min_size;//最少队伍人数，默认 3
read_write(_team_required_min_size);
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
int _fury;//狂暴几率
read_write(_fury);
int _recovery;//怪物回血设置
read_write(_recovery);
int feed_time;//喂养时间

// 动态怪历史上会把玩家物防倍率同时乘到怪物力量，力量又直接参与
// 怪物物防，导致物理职业承担一层法系没有的玩家属性反向缩放。
// 这里只记录动态缩放本身；怪物生命、攻击和实际力量仍保持旧值。
private int dynamic_npc_physical_defense_scale = 1000;
private int dynamic_npc_physical_defense_enabled = 0;

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
	dynamic_npc_physical_defense_scale = 1000;
	dynamic_npc_physical_defense_enabled = 0;
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
			case 8://人形 包括人类和妖魔
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
			case 9://野兽
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
			case 10://飞禽
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
			case 11://鱼
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
			case 12://两栖动物
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
			case 13://虫类
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
			case 14://看门狗
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
		life=life_max=transition_scaled_life(life);
	}
}
void setup_npc_dongtai(object player){
	dynamic_npc_physical_defense_scale = 1000;
	dynamic_npc_physical_defense_enabled = 1;
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
	npc_level_define_dongtai(player);
}

// 动态怪在 100 级以前保持原始属性，120 级以后仍使用历史的
// player_defense^0.3 整数倍率。101-119 级只负责平滑衔接两端，
// 避免 100->101 级时普通怪属性突然跳成数倍或数十倍。
int query_dynamic_npc_defense_scale(int npc_level,int player_defense){
	int target_multiplier;
	int target_scale;
	int transition_level;
	float transition_ratio;
	if(npc_level<=100)
		return 1000;
	if(player_defense<0)
		player_defense = 0;
	target_multiplier = (int)pow(player_defense,0.3);
	if(target_multiplier<1)
		target_multiplier = 1;
	target_scale = target_multiplier*1000;
	if(npc_level>=120)
		return target_scale;
	transition_level = npc_level-100;
	transition_ratio = (float)transition_level/(float)20;
	return (int)(pow((float)target_multiplier,transition_ratio)*1000);
}

// 101-121 级玩家处在战力衔接带，怪物战斗属性仍在 120 级恢复历史
// 倍率，但生命值延后到 122 级才恢复。这样只降低战斗时长，不改变
// 命中、伤害、奖励、自定义血量及 122 级以后的既有数值。
int query_dynamic_npc_life_scale(int npc_level,int player_defense){
	int target_multiplier;
	int target_scale;
	int transition_level;
	float transition_ratio;
	if(npc_level<=100)
		return 1000;
	if(player_defense<0)
		player_defense = 0;
	target_multiplier = (int)pow(player_defense,0.3);
	if(target_multiplier<1)
		target_multiplier = 1;
	target_scale = target_multiplier*1000;
	if(npc_level>=122)
		return target_scale;
	transition_level = npc_level-100;
	transition_ratio = (float)transition_level/(float)22;
	return (int)(pow((float)target_multiplier,transition_ratio)*1000);
}

int query_dynamic_npc_physical_defense_enabled(){
	return dynamic_npc_physical_defense_enabled;
}

int query_dynamic_npc_physical_defense_scale_applied(){
	return dynamic_npc_physical_defense_scale;
}

// 只归一化由动态怪倍率放大的力量物防。装备、基础防御、Buff 与
// 诅咒仍按原数值结算，因此不会绕过装备系统或改变控制技能效果。
int query_player_facing_physical_defense(){
	int current_defense;
	int strength_defense;
	int normalized_strength_defense;
	int strength_multiplier = 1;
	string profession;
	if(!dynamic_npc_physical_defense_enabled || _boss ||
	   dynamic_npc_physical_defense_scale<=1000)
		return this_object()->query_defend_power();
	profession = this_object()->query_profeId();
	if(profession=="beast" || profession=="bird" ||
	   profession=="fish" || profession=="amphibian" ||
	   profession=="bugs" || profession=="dog")
		strength_multiplier = 2;
	current_defense = this_object()->query_defend_power();
	strength_defense = _str*strength_multiplier;
	normalized_strength_defense = _str*1000/
		dynamic_npc_physical_defense_scale*strength_multiplier;
	current_defense = current_defense-strength_defense+
		normalized_strength_defense;
	if(current_defense<0)
		current_defense = 0;
	return current_defense;
}

//该方法自动根据npc类型和等级，生成该Npc基本属性值,给动态地图使用
void npc_level_define_dongtai(object player){
	int npcLevel = _npcLevel-1;
	//npc类型，等级不同，得到的基本属性计算公式也不同
	string u_profe = this_object()->query_profeId();
	if(u_profe){
		int i_profe = m_profe[u_profe];
		switch(i_profe){
			////////////////////////////////////////////////////	
			case 8://人形 包括人类和妖魔
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
			case 9://野兽
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
			case 10://飞禽
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
			case 11://鱼
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
			case 12://两栖动物
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
			case 13://虫类
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
			case 14://看门狗
				{
					_costom_npc_life = 3000;
					_str = 30;
					_think = 30;
					_dex = 30;
				}
				break;
				*/
		}

		int player_defense = 0;
		if(player && functionp(player->query_defend_power))
			player_defense = player->query_defend_power();
		int defense_scale = query_dynamic_npc_defense_scale(
			_npcLevel,player_defense);
		dynamic_npc_physical_defense_scale = defense_scale;
		int life_scale = query_dynamic_npc_life_scale(
			_npcLevel,player_defense);
		int life_strength = _str*life_scale/1000;
		_str = _str*defense_scale/1000;
		_dex = _dex*defense_scale/1000;//敏捷
		_think = _think*defense_scale/1000;//智力
		_lunck = defense_scale/100;//幸运
		//精英怪和boss怪的处理，分别是精英*2,boss*3
		if(_meritocrat==1){
			_str = _str*3;
			_dex = _dex*3;//敏捷
			_think = _think*3;//智力
			life_strength = life_strength*3;
		}
		else if(_boss==1){
			_str = _str*6;
			_dex = _dex*6;//敏捷
			_think = _think*6;//智力
			life_strength = life_strength*6;
		}
		life = life_strength*10;//生命=生命上限
		life_max = life;
		mofa = _think*10;//法力=法力上限
		mofa_max = mofa;
		//如果自定义了该npc的生命值，返回自定义生命值
		if(_costom_npc_life!=0)
			life=life_max=_costom_npc_life;
		if(_costom_npc_mofa!=0)
			mofa=mofa_max=_costom_npc_mofa;
		life=life_max=transition_scaled_life(life);
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

// === 团队挑战硬 Boss 的辅助接口 ===
// 由 Boss NPC 在 create() 中调用 set_team_required_boss(1) 启用。
// 启用后，fight.pike 在 attack() 进入时校验 first_target 的队伍人数；
// 不足最小值时 Boss 直接 reset_targets 并离场，避免被单人单挑。

int is_team_required_boss(){
    return _team_required_boss==1;
}

void set_team_required_boss(int flag){
    _team_required_boss = flag;
}

int query_team_required_min_size(){
    if(_team_required_min_size<1)
        return 4;
    return _team_required_min_size;
}

void set_team_required_min_size(int n){
    if(n<1) n = 1;
    if(n>10) n = 10;
    _team_required_min_size = n;
}

// 计算当前房间内属于 first_target 队伍且存活的玩家数量。
// 用于 team_required_boss 的准入校验。
int count_first_target_team_in_room(){
    object room;
    object first;
    string team_id;
    int alive = 0;
    first = this_object()->first_target;
    if(!first || !functionp(first->query_term))
        return 0;
    team_id = (string)first->query_term();
    if(team_id=="" || team_id=="noterm")
        return 0;
    room = environment(this_object());
    if(!room)
        return 0;
    foreach(all_inventory(room),object ob){
        if(ob && ob->is && ob->is("player") &&
           (string)ob->query_term()==team_id &&
           ob->get_cur_life()>0)
            alive++;
    }
    return alive;
}
