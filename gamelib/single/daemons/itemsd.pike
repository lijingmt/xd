#!/usr/local/bin/pike
/*****************************************************************************************
 * 此守护程序主要是用于仙道掉落装备，这是个测试程序，从文件中读入数据，然后存储到程序定义的
 * mapping中，守护程序还提供关于游戏装备掉落的所有接口。
 * 涉及到的文件:
 * 1.普通白物品索引文件: *****************************************
 *		                 * 1|1taomujian,1caoxie,...........,     *
 *	        		     * 2|2tiejian,2tongjian,...........,     * 
 *	   	        	     *	.							         *
 *			             *	.						 	   	     *
 *			             *  .                                    *
 *			             *****************************************
 *	 特殊物品的索引文件也采用上面的数据格式,特殊物品包括技能书，特定的装备等
 *
 * 2.已生成物品文件，每个白物品都有一个与之对应的同名文件，用于记录已生成的有属性的物品名称：
 *   1taomujian:*********************         1caoxie:********************
 *              *1taomujian12458ac..*                 *1caoxie124212.....*
 *              *1taomujian245adr...*                 *1caoxie254134.....*
 *              *       .           *                 *        .         *
 *              *       .           *                 *        .         *
 *              *       .           *                 *        .         *
 *              *********************                 ********************
 *
 * 3.物品属性约束文件，该文件记录装备与它可能出现的属性以及属性取值范围：
 *               *****************************************
 *               *1taomujian|str:1:3,dex:1:3,......      *
 *               *1caoxie|str:1:2,dex:1:2,......         *
 *               *  .                                    *
 *               *  .                                    *
 *               *****************************************
 *
 *
 *
 *  //evan added 2008.06.17
 * 4.世界范围里掉落的特殊物品文件，该文件记录世界掉落物品的名称、物品文件存储位置以及掉率：
 *               *****************************************
 *               * 1,冰蓝宝石|yushi/binglanyushi|2,      *
 *               * 2,紫晶玉石|yushi/zijinyushi|2,        *
 *               *  .                                    *
 *               *  .                                    *
 *               *****************************************
 *  定义了一个新的mapping，用来存储该文件中的数据。
 *  mapping(int:string) worlddrop_item_list = ([1:冰蓝宝石|yushi/binglanyushi|2,2:紫晶玉石|yushi/zijinyushi|2,....])
 *
 *  //end of evan added 2008.06.17*
 *
 *
 *
 *
 *
 * 我们就有四个mapping来存储对应上面三种文件的数据
 * 1. mapping(int:array(string)) item_list = ([
 *        1:({"1taomujian","1caoxie",...}),
 *        2:({"2tiejian",.....}),
 *           .
 *           .
 *    ])
 *   
 *   mapping(int:array(string)) spec_item_list = ([
 *		  1:({"fuji","lanyaozhan",....}),
 *           .
 *			 .
 *   ])
 *
 *
 * 3.mapping(item_attributes = ([
 *        "1taomujian":({"str:1:3","dex:1:3",....}),
 *        "1caoxie":({"str:1:2","dex:1:2",.....}),
 *           .
 *           .
 *   ])
 *
 * Auther：liaocheng
 * Date：07/1/19
 *       07/1/22 第一次修改完成了三个读入文件数据的内部接口
 *		 07/2/7 添加了特殊物品的掉落，还有金钱的掉落
 *		        特殊物品属性是固定的,所以较掉落普通装备的算法,没有了产生随机属性这一步
 * Edit:08/06/17 添加了世界掉落物品的相关操作 evan added 2008.06.17
 ********************************************************************************************/
#include <globals.h>
#include <gamelib/include/gamelib.h>
//#include <mudlib/include/mudlib.h>

inherit LOW_DAEMON;
//inherit MUD_F_ITEMS;


//#define READ_FILE_PATH  DATA_ROOT "items/"
#define FILE_PATH ROOT "/gamelib/data/" //世界掉落列表

//由liaocheng于07/2/7添加，用于记录特殊物品的映射表
private mapping(int:array(string)) spec_item_list = ([]);
///////////////07/2/7

//记录所有白色装备的映射表
private mapping(int:array(string)) item_list = ([]);

// 新月套装使用独立稀有池。底版仍登记在 orgItems.list 供动态装备
// 生成器复用，但绝不能混进对应等级的普通白装池。
private array(string) newmoon_item_list = ({});
private mapping(string:array(string)) newmoon_profession_templates = ([]);
private mapping(string:array(string)) newmoon_focus_templates = ([]);
private int enabled_newmoon_collection_count = 6;
private int newmoon_drop_denominator = 300000;
private array(mapping(string:mixed)) newmoon_collection_catalog = ({
	(["id":"newmoon","name":"新月","quality":"稀世","rank":1,
		"min_level":69,"min_affixes":1,"weight":300]),
	(["id":"starshine","name":"曜星","quality":"绝世","rank":2,
		"min_level":90,"min_affixes":2,"weight":100]),
	(["id":"firmament","name":"天穹","quality":"传说","rank":3,
		"min_level":110,"min_affixes":3,"weight":30]),
	(["id":"greatvoid","name":"太虚","quality":"神话","rank":4,
		"min_level":130,"min_affixes":4,"weight":10]),
	(["id":"primordial","name":"太初","quality":"太古","rank":5,
		"min_level":160,"min_affixes":5,"weight":3]),
	(["id":"huanji","name":"寰极","quality":"至尊","rank":6,
		"min_level":200,"min_affixes":6,"weight":1]),
});

//记录白色装备允许出现属性的映射表
private mapping(string:array(string)) item_attributes = ([]);

//十一职业大神传承仅通过70级以上怪物极低概率掉落。
//总掉率为37/10000000，三十七本等概率，即单本长期均值约1/10000000。
private array(string) hidden_skill_books = ({
	"book/wanjianguizong",
	"book/taiqingjianyu",
	"book/pozhenjianyi",
	"book/taixulingyun",
	"book/wanlingchaosheng",
	"book/sixiangfengjin",
	"book/jiutianleiyin",
	"book/taiyixuanguang",
	"book/bingpochanshen",
	"book/zhutianwujie",
	"book/tianshajianyi",
	"book/wuyingfenghou",
	"book/xuemoshijie",
	"book/shurakuangyi",
	"book/xuehailieshang",
	"book/huangquanwudu",
	"book/wanxiangshihun",
	"book/jiuyouduzhang",
	"book/wuyingjuemie",
	"book/jiuyouguibu",
	"book/liudaozhangmu",
	"book/wanshanchaogong",
	"book/buzhouzhenji",
	"book/tiandichengbi",
	"book/xinghezhuiluo",
	"book/zhoutianjingzhi",
	"book/wanxiangxingbi",
	"book/cixinpudu",
	"book/huimingtianlu",
	"book/wanmuxinchun",
	"book/liuhehuichun",
	"book/wuxiangguixu",
	"book/wuxianghunyuan",
	"book/wuxiangwuji",
	"book/taijiguixu",
	"book/taijihunyuan",
	"book/taijiwuji",
});
private int hidden_skill_min_level = 70;
private int hidden_skill_drop_rate = 37;
private int hidden_skill_drop_denominator = 10000000;

//用于生成物品文件后缀的映射表,现在暂时未用上
private mapping(string:int) postfix_map = ([
		"str_add"                    :0,
		"dex_add"                    :1,
		"think_add"                  :2,
		"all_add"					 :3,
		"dodge_add"					 :4,
		"doub_add"					 :5,
		"hitte_add"					 :6,
		"lunck_add"					 :7,
		"attack_add"				 :8,
		"recive_add"				 :9,
		"back_add"					 :10,
		"weapon_attack_add"			 :11,
		"defend_add"				 :12,
		"dura_add"					 :13,
		"item_canDura"				 :14,
		"life_add"					 :15,
		"mofa_add"					 :16,
		"rase_life_add"				 :17,
		"rase_mofa_add"				 :18,
		"huo_mofa_attack_add"		 :19,
		"bing_mofa_attack_add"		 :20,
		"feng_mofa_attack_add"		 :21,
		"du_mofa_attack_add"		 :22,
		"spec_mofa_attack_add"		 :23,
		"mofa_all_add"				 :24,
		"attack_huoyan_add"			 :25,
		"attack_bingshuang_add"		 :26,
		"attack_fengren_add"		 :27,
		"attack_dusu_add"			 :28,
		"attack_spec_add"			 :29,
		"huoyan_defend_add"			 :30,
		"bingshuang_defend_add"		 :31,
		"fengren_defend_add"		 :32,
		"dusu_defend_add"			 :33,
		"all_mofa_defend_add"		 :34
]);

//字母-数值映射表, 采用ascii码
private mapping(int:int) char_value = ([
		1		:49,
		2		:50,
		3		:51,
		4		:52,
		5		:53,
		6		:54,
		7		:55,
		8		:56,
		9		:57,
		10		:97,
		11		:98,
		12		:99,
		13		:100,
		14		:101,
		15		:102,
		16		:103,
		17		:104,
		18		:105,
		19		:106,
		20		:107,
		21		:108,
		22		:109,
		23		:110,
		24		:111,
		25		:112,
		26		:113,
		27		:114,
		28		:115,
		29		:116,
		30		:117,
		31		:118,
		32		:119,
		33		:120,
		34		:121,
		35		:122,
		36              :65,
		37              :66,
		38              :67,
		39              :68,
		40              :69,
		41              :70,
		42              :71,
		43              :72,
		44              :73,
		45              :74,
		46              :75,
		47              :76,
		48              :77,
		49              :78,
		50              :79,
		51              :80,
		52              :81,
		53              :82,
		54              :83,
		55              :84,
		56              :85,
		57              :86,
		58              :87,
		59              :88,
		60              :89,
		61              :90
]);

//特殊掉落，主要针对于节日的特殊掉落
//由liaocheng于07/09/24添加，25为中秋节
private array(string) spec_arr = ({});
//private array(string) spec_arr = ({"zhongqiuyuebing/qiaokeli","zhongqiuyuebing/bingqilin","zhongqiuyuebing/haixian","zhongqiuyuebing/zhenai","zhongqiuyuebing/zhenqing","zhongqiuyuebing/fuman","zhongqiuyuebing/dafuman"});



//世界掉落物品列表 evan added 2008.06.18
private mapping(string:string) worlddrop_item_list = ([]);

//加载task_world_drop.csv，写入worlddrop_item_list映射表中
private int ReadFile_worlddrop_item_list(string filename)
{
	//werror("=====  Worlddrop_Item_list start!  ====\n");
	string strTmp = Stdio.read_file(filename);
	if(strTmp){
		array(string) lines = strTmp/"\r\n";
		if(lines&&sizeof(lines)){
			lines=lines-({""});
			foreach(lines,string eachline){
				array(string) column = eachline/",";
				if(column[1])
				worlddrop_item_list[column[0]] = column[1];
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	else 
		//werror("===== Error! file not exist =====\n");
		return 0;
}
//end of evan added 2008.06.17





//内部接口，被create()调用，用于读入白物品文件列表数据，存在item_list映射表中
private int ReadFile_item_list(string filename)
{
	//werror("=====  Item_list Start!  ====\n");
	string strTmp=Stdio.read_file(filename);
	if(strTmp){
		//以每一行为单位分割文件数据
		array(string) lines = strTmp/"\n";
		//这里碰到些问题，已换行符分割后得到的lines中元素个数要多出一个，最后一个为空，这将会导致后面代码tmp[1]出错
		//因此解决方法是增加了一个判断条件sizeof(eachline)不为空
		if(lines&&sizeof(lines)){
			//对每一行进行处理
			foreach(lines, string eachline){
				if(eachline&&sizeof(eachline)){
					//分割出物品等级和物品名称，tmp[0]为等级，tmp[1]为名称
					array(string)tmp = eachline/"|";
					//然后分割出每个装备的名称，这主要是为了将有属性物品列表文件读入内存
					array(string) itemnames=tmp[1]/",";
					array(string) ordinary=({});
					foreach(itemnames-({""}),string itemname){
						if(search(itemname,"69xinyue")!=-1)
							newmoon_item_list+=({itemname});
						else
							ordinary+=({itemname});
					}
					//记录在普通 item_list 映射中；仅含新月套装的登记行
					//不会创建空池，从而保持上线前该等级“无普通底版”的行为。
					if(sizeof(ordinary))
						item_list[(int)tmp[0]]=ordinary;
				}
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	//werror("===== Error! file not exist =====\n");
	return 0;
}

int query_newmoon_equipment_drop_denominator()
{
	return newmoon_drop_denominator;
}

int query_enabled_newmoon_collection_count()
{
	return enabled_newmoon_collection_count;
}

array(mapping(string:mixed)) query_newmoon_collection_catalog()
{
	return copy_value(newmoon_collection_catalog[
		..enabled_newmoon_collection_count-1]);
}

int query_newmoon_equipment_template_count()
{
	return sizeof(newmoon_item_list);
}

/**
 * 返回某职业十件“新月”底版的稳定路径。幻境任务只领取现有套装，
 * 不另造一套数值公式；路径排序保证断线重试仍指向同一件奖励。
 */
array(string) query_newmoon_base_templates_for_profession(string profession_id)
{
	if(profession_id=="zhaoming")
		return ({
			"weapon/69xinyuezhaomingjian/69xinyuezhaomingjian",
			"armor/69xinyuezhaomingguan/69xinyuezhaomingguan",
			"armor/69xinyuezhaomingyi/69xinyuezhaomingyi",
			"armor/69xinyuezhaomingshou/69xinyuezhaomingshou",
			"armor/69xinyuezhaomingwan/69xinyuezhaomingwan",
			"armor/69xinyuezhaomingku/69xinyuezhaomingku",
			"armor/69xinyuezhaominglv/69xinyuezhaominglv",
			"jewelry/69xinyuezhaomingjie/69xinyuezhaomingjie",
			"jewelry/69xinyuezhaomingshuo/69xinyuezhaomingshuo",
			"jewelry/69xinyuezhaomingpei/69xinyuezhaomingpei",
		});
	array(string) cached = newmoon_profession_templates[profession_id];
	array(string) result = ({});
	if(arrayp(cached) && sizeof(cached)==10)
		return cached+({});
	foreach(newmoon_item_list,string item_name){
		object item;
		mixed err = catch{ item=clone(ITEM_PATH+item_name); };
		if(!err && item &&
		   functionp(item->query_newmoon_resonance_profession) &&
		   functionp(item->query_newmoon_collection_id) &&
		   (string)item->query_newmoon_resonance_profession()==profession_id &&
		   (string)item->query_newmoon_collection_id()=="newmoon")
			result += ({item_name});
		if(item)
			destruct(item);
	}
	sort(result);
	if(sizeof(result)==10)
		newmoon_profession_templates[profession_id] = result+({});
	return result;
}

/**
 * 八十一章后的掉落定向只缩小一次已经合法命中的新月模板池。
 * 它不改变掉率、品质权重、词缀数量，也不会在组队掉落中替全队指定
 * 某一人的职业。结果按职业与槽位缓存，避免稀有掉落时重复克隆。
 */
array(string) query_newmoon_drop_templates_for_player(object player)
{
	mixed focus_err;
	string focus;
	string profession;
	string cache_key;
	array(string) profession_templates;
	array(string) focused = ({});
	if(!player)
		return newmoon_item_list+({});
	// 掉落定向是可选体验；支线旧档或模块异常时必须退回完整模板池，
	// 不能让一次已经命中的合法装备掉落中断NPC死亡结算。
	focus_err = catch{
		focus = ILLUSION_JOURNEYD->query_newmoon_drop_focus(player);
	};
	if(focus_err || !stringp(focus) || focus==""){
		if(focus_err)
			werror("[NEWMOON_DROP] 套装定向查询异常，已使用公共池: user=%s error=%s\n",
				functionp(player->query_name) ? (string)player->query_name() : "",
				describe_error(focus_err));
		focus = "all";
	}
	profession = functionp(player->query_profeId) ?
		(string)player->query_profeId() : "";
	if(focus=="all" || profession=="")
		return newmoon_item_list+({});
	cache_key = profession+"|"+focus;
	if(arrayp(newmoon_focus_templates[cache_key]) &&
	   sizeof(newmoon_focus_templates[cache_key])==1)
		return newmoon_focus_templates[cache_key]+({});
	profession_templates = query_newmoon_base_templates_for_profession(
		profession);
	foreach(profession_templates,string item_name){
		object item;
		mixed err = catch{ item=clone(ITEM_PATH+item_name); };
		if(!err && item && functionp(item->query_item_kind) &&
		   (string)item->query_item_kind()==focus)
			focused += ({item_name});
		if(item)
			destruct(item);
	}
	if(sizeof(focused)==1)
		newmoon_focus_templates[cache_key] = focused+({});
	return sizeof(focused)==1 ? focused : newmoon_item_list+({});
}

mapping(string:mixed) query_newmoon_collection_for_roll(int npclevel,int roll)
{
	int cursor=0;
	if(roll<1 || roll>newmoon_drop_denominator ||
	   sizeof(newmoon_item_list)!=120)
		return ([]);
	for(int index=enabled_newmoon_collection_count-1;index>=0;index--){
		mapping collection=newmoon_collection_catalog[index];
		cursor+=(int)collection["weight"];
		if(roll<=cursor)
			return npclevel>=(int)collection["min_level"] ?
				copy_value(collection) : ([]);
	}
	return ([]);
}

mapping(string:mixed) query_newmoon_collection_for_difficulty_roll(
	int npclevel,int roll,int difficulty_level)
{
	int percent=PERSONAL_DIFFICULTYD->
		query_set_drop_percent_for_level(difficulty_level);
	int adjusted_roll;
	if(percent<100)
		percent=100;
	adjusted_roll=max(1,(roll*100+percent-1)/percent);
	return query_newmoon_collection_for_roll(npclevel,adjusted_roll);
}

string query_newmoon_collection_id_for_roll(int npclevel,int roll)
{
	mapping collection=query_newmoon_collection_for_roll(npclevel,roll);
	return (string)(collection["id"] || "");
}

int can_drop_newmoon_equipment(int npclevel,int roll)
{
	return sizeof(query_newmoon_collection_for_roll(npclevel,roll))>0;
}

private mapping(string:mixed) query_newmoon_collection_for_item(object item)
{
	string collection_id;
	if(!item || !functionp(item->query_newmoon_collection_id) ||
	   !functionp(item->query_newmoon_resonance_profession) ||
	   item->query_newmoon_resonance_profession()=="")
		return ([]);
	collection_id=(string)item->query_newmoon_collection_id();
	foreach(newmoon_collection_catalog,mapping collection)
		if((string)collection["id"]==collection_id)
			return copy_value(collection);
	return ([]);
}

//由liaocheng于07/2/7添加，内部接口，被create()调用，用于读入特殊物品文件索引到spec_item_list映射表
private int ReadFile_spec_item_list(string filename)
{
	//werror("=====  Spec_Item_list Start!  ====\n");
	string strTmp=Stdio.read_file(filename);
	if(strTmp){
		//以每一行为单位分割文件数据
		array(string) lines = strTmp/"\n";
		if(lines&&sizeof(lines)){
			//对每一行进行处理
			foreach(lines, string eachline){
				if(eachline&&sizeof(eachline)){
					//分割出物品等级和物品名称，tmp[0]为等级，tmp[1]为名称
					array(string)tmp = eachline/"|";
					//然后分割出每个装备的名称，这主要是为了将有属性物品列表文件读入内存
					array(string) itemnames=tmp[1]/",";
					//记录在item_list映射中
					spec_item_list[(int)tmp[0]]=itemnames-({""});//copy_value(itemnames);
				}
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	//werror("===== Error! file not exist =====\n");
	return 0;
}

//内部接口，被create()调用，用于读入物品属性约束文件数据，存于item_attributes映射表中
private int ReadFile_item_attributes(string filename)
{
	//werror("=====  Item_attributes Start!  ====\n");
	string strTmp=Stdio.read_file(filename);
	if(strTmp){
		//先按行分割
		array(string) lines=strTmp/"\n";
		//对每一行又根据"|"分割
		foreach(lines, string eachline){
			if(eachline&&sizeof(eachline)){
				array(string) tmp=eachline/"|";
				//对tmp[1]进行","分割
				array(string) attributes=tmp[1]/",";
				//记录在item_attributes映射表里
				item_attributes[tmp[0]]=attributes-({""});//copy_value(attributes);
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	else 
		werror("===== Error! file not exist =====\n");
	return 0;
}

//内部接口，被create()调用，用于读入boss掉落物品列表，存于boss_items映射表中
//读入的文件是.csv  格式为：
//bossname，item
private int ReadFile_boss_items(string filename)
{
	return 0;
}

//外部接口，由fight_die()调用，为装备掉落的的接口
object get_item(int npclevel,int playerlevel,int playerluck,
	void|int personal_difficulty_level,void|object focus_player)
{
	string item_rawname=""; //白装备名称,包含了一个路径。如weapon/1taomujian
	array(string) itemsallow=({}); //等级范围类允许物品列表
	object ret_item; //最后生成并返回的装备
	int a=npclevel-1; //概率算法的一个因子
	int b=101-npclevel; //第二个因子

	//判断是否掉落白色物品
	int pro = 10000;
	int itemlevel=get_item_level(npclevel); //调用了获得物品等级的接口

	if(npclevel>73){
		itemlevel=get_item_level(random(63)+10);//支持超过73以上的装备，如果超过70级按照10-73级的装备模板区随机选一个级别的装备，作为原始模板
		//werror("=========itemlevel:"+itemlevel+"\n");
		a=72;//装备稀有度的因子按照73级npc的等级来，保持之前的概率分布
		b=35;//极品10万分之4
		pro = 50000;//掉率为50%
	}

	//在gamelib/data/orgItems.list表中，73级的装备为洞穴装备，洞穴装备的掉率为80%
	if(itemlevel>=73){
		pro = 50000;//掉率为50%，由于现在是动态npc掉率设置为50%
	}
	if(npclevel <= 10)
		pro = 20000;
	if((random(100000)+1)<=pro){ //获得白物品的概率xxxxxxxxxxx
		if(itemlevel==0)
			return 0;
		int newmoon_roll=random(query_newmoon_equipment_drop_denominator())+1;
		mapping newmoon_collection=
			query_newmoon_collection_for_difficulty_roll(npclevel,
				newmoon_roll,personal_difficulty_level);
		if(sizeof(newmoon_collection)){
			array(string) drop_templates=
				query_newmoon_drop_templates_for_player(focus_player);
			item_rawname=drop_templates[random(sizeof(drop_templates))];
			itemlevel=69;
		}
		else{
			itemsallow=item_list[itemlevel];
			if(!itemsallow)
				return 0;
			item_rawname=itemsallow[random(sizeof(itemsallow))];
		}
		//werror("============item_rawname:"+item_rawname+"\n");
		//判断掉落的物品是否有属性
		//掉落的属性概率xxxxxxxxxxx
		int seven = (int)(120-a*2+playerluck*b*0.01);
		int six = (int)(180-a*3+playerluck*b*0.05);
		int five = (int)(280-a*4+playerluck*b*0.1);
		int four = (int)(420-a*5+playerluck*b*0.2);
		int three = (int)((600-a*8)*5+playerluck*b*0.5);
		//int three = (int)((1200-a*8)*5+playerluck*b*0.5);
		int two = (int)((820-a*12)*10+playerluck*b*0.7);
		//int two = (int)((1640-a*12)*10+playerluck*b*0.7);
		int one = (int)((1080-a*16)*20+playerluck*b*1);
		//int one = (int)((2160-a*16)*20+playerluck*b*1);
		int ran=random(100000)+1;
		int attribute_count=1;
		if(ran<=seven) attribute_count=7;
		else if(ran<=six) attribute_count=6;
		else if(ran<=five) attribute_count=5;
		else if(ran<=four) attribute_count=4;
		else if(ran<=three) attribute_count=3;
		else if(ran<=two) attribute_count=2;
		else if(ran<=one) attribute_count=1;
		if(sizeof(newmoon_collection))
			attribute_count=max(attribute_count,
				(int)newmoon_collection["min_affixes"]);
		//get_attributes_item最后两项为原始装备的等级，以及目标NPC等级
		ret_item=get_attributes_item(item_rawname,attribute_count,itemlevel,
			npclevel,0,newmoon_collection);

		return ret_item;
	}
	else	
		return 0;
}


//外部接口，由fight_die()调用，为装备掉落的的接口
object get_item_from_rawname(int npclevel,int playerlevel,int playerluck,
	string item_rawname,void|int original_item_level)
{
	array(string) itemsallow=({}); //等级范围类允许物品列表
	object ret_item; //最后生成并返回的装备
	int a=npclevel-1; //概率算法的一个因子
	int b=101-npclevel; //第二个因子

	//判断是否掉落白色物品
	int pro = 10000;
	// 明确指定模板时必须使用货架索引中的真实等级。旧逻辑又按目标
	// 等级随机一次“原始等级”，会让低级模板以错误倍率生成属性。
	int itemlevel=original_item_level>0 ? original_item_level :
		get_item_level(npclevel); //调用了获得物品等级的接口

	if(npclevel>73){
		if(original_item_level<=0)
			itemlevel=get_item_level(random(63)+10);//兼容非货架旧调用
		//werror("=========itemlevel:"+itemlevel+"\n");
		a=72;//装备稀有度的因子按照73级npc的等级来，保持之前的概率分布
		b=35;//极品10万分之4
		pro = 50000;//掉率为50%
	}

	//在gamelib/data/orgItems.list表中，73级的装备为洞穴装备，洞穴装备的掉率为80%
	if(itemlevel>=73){
		pro = 50000;//掉率为50%，由于现在是动态npc掉率设置为50%
	}
	if(npclevel <= 10)
		pro = 20000;
	if((random(100000)+1)<=pro){ //获得白物品的概率xxxxxxxxxxx
		if(itemlevel==0)
			return 0;
		itemsallow=item_list[itemlevel]; 
		if(!itemsallow){
			return 0;
		}
		
		//item_rawname=itemsallow[random(sizeof(itemsallow))]; //在这里获得了白色物品的名字
		//werror("============item_rawname:"+item_rawname+"\n");
		//判断掉落的物品是否有属性
		//掉落的属性概率xxxxxxxxxxx
		int seven = (int)(120-a*2+playerluck*b*0.01);
		int six = (int)(180-a*3+playerluck*b*0.05);
		int five = (int)(280-a*4+playerluck*b*0.1);
		int four = (int)(420-a*5+playerluck*b*0.2);
		int three = (int)((600-a*8)*5+playerluck*b*0.5);
		//int three = (int)((1200-a*8)*5+playerluck*b*0.5);
		int two = (int)((820-a*12)*10+playerluck*b*0.7);
		//int two = (int)((1640-a*12)*10+playerluck*b*0.7);
		int one = (int)((1080-a*16)*20+playerluck*b*1);
		//int one = (int)((2160-a*16)*20+playerluck*b*1);
		int ran=random(100000)+1;
		//get_attributes_item最后两项为原始装备的等级，以及目标NPC等级
		if(ran<=seven)
			ret_item=get_attributes_item(item_rawname,7,itemlevel,npclevel); //调用了获得属性物品的核心接口
		else if(ran<=six)
			ret_item=get_attributes_item(item_rawname,6,itemlevel,npclevel); //调用了获得属性物品的核心接口
		else if(ran<=five)
			ret_item=get_attributes_item(item_rawname,5,itemlevel,npclevel); //调用了获得属性物品的核心接口
		else if(ran<=four)
			ret_item=get_attributes_item(item_rawname,4,itemlevel,npclevel); //调用了获得属性物品的核心接口
		else if(ran<=three)
			ret_item=get_attributes_item(item_rawname,3,itemlevel,npclevel); //调用了获得属性物品的核心接口
		else if(ran<=two)
			ret_item=get_attributes_item(item_rawname,2,itemlevel,npclevel); //调用了获得属性物品的核心接口
		else if(ran<=one)
			ret_item=get_attributes_item(item_rawname,1,itemlevel,npclevel); //调用了获得属性物品的核心接口
		else
			ret_item=get_attributes_item(item_rawname,1,itemlevel,npclevel); 
			//ret_item=clone(ITEM_PATH+item_rawname); //产生白物品

		return ret_item;
	}
	else	
		return 0;
}
int query_hidden_skill_book_count()
{
	return sizeof(hidden_skill_books);
}
string query_hidden_skill_book(int index)
{
	if(index < 0 || index >= sizeof(hidden_skill_books))
		return "";
	return hidden_skill_books[index];
}
int query_hidden_skill_min_level()
{
	return hidden_skill_min_level;
}
int query_hidden_skill_drop_rate()
{
	return hidden_skill_drop_rate;
}
int query_hidden_skill_drop_denominator()
{
	return hidden_skill_drop_denominator;
}
int can_drop_hidden_skill_book(int npclevel,int roll)
{
	if(npclevel < hidden_skill_min_level)
		return 0;
	if(roll < 1 || roll > hidden_skill_drop_rate)
		return 0;
	return 1;
}
object get_hidden_skill_book(int npclevel)
{
	int roll = random(query_hidden_skill_drop_denominator())+1;
	if(!can_drop_hidden_skill_book(npclevel,roll))
		return 0;
	string item_name =
		hidden_skill_books[random(sizeof(hidden_skill_books))];
	return clone(ITEM_PATH+item_name);
}

int query_ancient_skill_book_count()
{
	return sizeof(ANCIENT_SKILLD->query_all_skill_ids());
}

int query_ancient_skill_min_level()
{
	return ANCIENT_SKILLD->query_minimum_npc_level();
}

int query_ancient_skill_drop_denominator()
{
	return ANCIENT_SKILLD->query_drop_denominator();
}

int query_ancient_skill_total_weight()
{
	return ANCIENT_SKILLD->query_total_drop_weight();
}

int can_drop_ancient_skill_book(int npclevel,int roll)
{
	if(npclevel<query_ancient_skill_min_level())
		return 0;
	return roll>=1 && roll<=query_ancient_skill_total_weight();
}

object get_ancient_skill_book(int npclevel)
{
	int roll = random(query_ancient_skill_drop_denominator())+1;
	string item_name;
	if(!can_drop_ancient_skill_book(npclevel,roll))
		return 0;
	item_name = ANCIENT_SKILLD->query_weighted_book(roll);
	if(item_name=="")
		return 0;
	return clone(ITEM_PATH+item_name);
}
//外部接口，由fight_die()调用，为世界掉落装备的的接口
int can_monster_drop_box(string item_name)
{
	if(!item_name || item_name=="")
		return 0;
	return search(item_name,"baoxiang/")!=0;
}

object get_worlddrop_item(int npclevel,int playerlevel)
{
	object ret_item;     //最后返回的装备

	//判断是否掉落物品
	int pro = 1000;

	int num = sizeof(worlddrop_item_list);//世界掉落物品的总数量
	//werror("========= 【debug】 the num of item is:" + num +" ======\n");
	int i = random(num);//取其中的一个
	//werror("========= 【debug】 now we are going to the :" + i +" item======\n");
	string item_tmp = worlddrop_item_list[(string)i];
	//werror("========= 【debug】 String of item is:" + item_tmp +" ======\n");
	array(string) column = item_tmp/"|";
	string item_name = column[1];//物品存放位置
	int item_rate = (int)column[2];//掉率
	// 怪物/挂机世界掉落永久禁止产出任何宝箱。旧世界池中的圣诞
	// 宝箱和未来误配的精金宝箱都能间接产出玉石，不能依赖把权重
	// 写成0（下方历史算法使用 <=，0仍有一次命中）。充值赠送和
	// 管理员发放走独立、可审计的入口，不受这里影响。
	if(!can_monster_drop_box(item_name))
		return 0;
	if(random(1000)<=item_rate)
	{
		//werror("========= 【debug】i am going to clone item！======\n");
		ret_item = clone(ITEM_PATH+item_name); //产生该物品
		return ret_item;
	}
	else	
		return 0;
}
//获得特殊物品的等级
private int get_spec_item_level(int level)
{
	int levelbase;//levellimit;
	if(level==1||level==2)
		return 1+random(2);
	else {
		levelbase=level-2;
		if(levelbase>0){ 
			int item_level = levelbase+random(5);
			while(!(spec_item_list[item_level] && sizeof(spec_item_list[item_level]))){
				item_level--;
				if(item_level <= 0){
			    	    item_level = 0;
				    break;
			   	}
			}
			return item_level;
		}
		else {
			//werror("something wrong in get_spec_item_level!\n");
			return 0;
		}
	}
}
//外部接口，用于掉落特殊物品，
//rare_drop_percent：击杀者个人难度档的稀有掉率倍率（100为中性）。
object get_spec_item(int npclevel,int playerlevel,int playerluck,
	void|int rare_drop_percent)
{
	string spec_item_name=""; //特殊物品名称
	array(string) spec_itemsallow=({}); //等级范围类允许特殊物品列表
	object ret_spec_item; //最后生成并返回的装备
	//int a=npclevel-1; //概率算法的一个因子
	//int b=101-npclevel; //第二个因子

	//判断是否掉落白色物品
	//获得特殊物品的概率在这儿xxxxxxxxxxx
	//int got_it = 100000;
	int got_it = 1000;
	int itemlevel=get_spec_item_level(npclevel); //调用了获得物品等级的接口
	if(rare_drop_percent<100 || rare_drop_percent>400)
		rare_drop_percent = 100;
	if(npclevel > 0){
		int tmp = (int)npclevel/10;
		if(tmp == 0)
			tmp = 1;
		got_it = (int)1000/tmp;
		if(npclevel==70)got_it=got_it/2;//调整70级技能书的掉率
		if(npclevel>=71){
			if(itemlevel==72){
			//朴素宝石的掉率
				got_it = 500;
			}
			if(itemlevel==73){
			//闪亮宝石的掉率
				got_it = 100;
			}
			if(npclevel > 73){//如果动态npc的等级超过73，则说明没有可用的技能书掉落了，则随机任何一个以前的技能书等级，掉落技能书
				itemlevel = random(74);
				//got_it=100000;//测试用，未来要屏蔽掉
			}
		}
	}
	if((random(100000)+1)<=got_it*rare_drop_percent/100) {
		//werror("------spec_item_level="+itemlevel+"----\n");
		if(itemlevel==0||itemlevel==1) //没有一级的特殊物品
			return 0;
		spec_itemsallow=spec_item_list[itemlevel]; 
		if(!spec_itemsallow){
			return 0;
		}
		spec_item_name=spec_itemsallow[random(sizeof(spec_itemsallow))]; //在这里获得了物品的名字
		if(spec_item_name!=""){
			ret_spec_item=clone(ITEM_PATH+spec_item_name);
			if(ret_spec_item){
				if((ret_spec_item->query_name()=="pshuangshuiyu"&&random(100000)>=300)||(ret_spec_item->query_name()=="slhuangshuiyu"&&random(100000)>50)){
				//朴素黄水玉掉率0.3%，闪亮黄水玉掉率0.05%
					return 0;
				}
			}
			return ret_spec_item;
		}
		else{
			return 0;
		}
	}
	else
		return 0;
}

//外部接口，用于掉落任务物品
//第一个参数为要掉落的任务物品,如other/yezhutui，直接为文件路径名
//第二个参数为掉落的概率，如80 表示概率为80%
object get_task_item(string item_path_name,int prob)
{
	object rtn;
	if(prob<0)
		prob = 0;
	if(Stdio.exist(ITEM_PATH+item_path_name)){
		if(random(100)<=prob){
			rtn=clone(ITEM_PATH+item_path_name);
			return rtn;
		}
		else
			return 0;
	}
	else {
		return 0;
	}
}

//外部接口，玩家赌博装备时调用
//动态装备，等级大于73的时候，按照73的模版，动态生成高于73等级的装备
object dubo_item(int itemlevel,string item,int playerluck)
{
	string item_rawname=item; //白装备名称,包含了一个路径。如weapon/1taomujian/1taomujian
	array(string) itemsallow=({}); //等级范围类允许物品列表
	object ret_item; //最后生成并返回的装备
	int a=itemlevel-1; //概率算法的一个因子
	int b=101-itemlevel; //第二个因子

	//没有考虑清楚，下次在考虑
	object tmp_ob=clone(ITEM_PATH+item_rawname);
	int orginal_level=itemlevel;
	if(tmp_ob){
		orginal_level=tmp_ob->query_item_canLevel();
	}
	if(itemlevel>73){
		orginal_level=73;
		a=72;//装备稀有度的因子按照73级npc的等级来，保持之前的概率分布
		b=35;//极品10万分之4
	}

	//一定会赌到白色物品
	if((random(100000)+1)<=100000) {
		//判断赌博的物品是否有属性
		//赌博的属性概率xxxxxxxxxxx
		int seven = (int)(120*3-a*2+playerluck*b*0.01)/2;
		int six = (int)(180*3-a*3+playerluck*b*0.05)/2;
		int five = (int)(280*3-a*4+playerluck*b*0.1)/2;
		int four = (int)(420*3-a*5+playerluck*b*0.2)/2;
		int three = (int)((600*3-a*8)*5+playerluck*b*0.5)/2;
		int two = (int)((820*3-a*12)*10+playerluck*b*0.7)/2;
		int one = (int)((1080*3-a*16)*20+playerluck*b*1)/2;

		int ran=random(100000)+1;
		if(ran<=seven)
			ret_item=get_attributes_item(item_rawname,7,orginal_level,itemlevel); //调用了获得属性物品的核心接口
		else if(ran<=six)
			ret_item=get_attributes_item(item_rawname,6,orginal_level,itemlevel); //调用了获得属性物品的核心接口
		else if(ran<=five)
			ret_item=get_attributes_item(item_rawname,5,orginal_level,itemlevel); //调用了获得属性物品的核心接口
		else if(ran<=four)
			ret_item=get_attributes_item(item_rawname,4,orginal_level,itemlevel); //调用了获得属性物品的核心接口
		else if(ran<=three)
			ret_item=get_attributes_item(item_rawname,3,orginal_level,itemlevel); //调用了获得属性物品的核心接口
		else if(ran<=two)
			ret_item=get_attributes_item(item_rawname,2,orginal_level,itemlevel); //调用了获得属性物品的核心接口
		else if(ran<=one)
			ret_item=get_attributes_item(item_rawname,1,orginal_level,itemlevel); //调用了获得属性物品的核心接口
		else
			ret_item=get_attributes_item(item_rawname,1,orginal_level,itemlevel);
			//ret_item=clone(ITEM_PATH+item_rawname); //产生白物品

		return ret_item;
	}
	else	
		return 0;
}

//外部接口，由赌博的房间调用
//参数fg由liaocheng于07/11/26添加，用于判断是付费赌博还是一般赌博，付费赌博将会出现宝石和魔线
string query_dubo_items(int level,void|int fg)
{
	string rtn="";
	array(string) dubo_itemsallow=({}); //等级范围类允许物品列表
	if(level<=73)
		dubo_itemsallow=copy_value(item_list[level]);//用copy_value()是为了防止下面对dubo_itemsallow的操作影响到item_list 
	else{
		//int random_level=random(73);
		//if(random_level==0) random_level=73;
		dubo_itemsallow=copy_value(item_list[73]);//超过73级的，因为表里面没有，就得到1-73级的装备了，用来生成高等级装备的模板 
	}
		
	if(fg && fg == 1){
		if(level == 9)
			dubo_itemsallow += ({"material/xuanhuangshi","material/mx_mojinsi"});
		else if(level == 17)
			dubo_itemsallow += ({"material/maoyanshi","material/mx_huaxuesi"});
		else if(level == 29) 
			dubo_itemsallow += ({"material/xiehupo","material/mx_raohunsi"});
		else if(level == 37)                                                            
			dubo_itemsallow += ({"material/yufeicui","material/mx_tiancansi"});     
		else if(level == 49)                                                            
			dubo_itemsallow += ({"material/jingangzuan","material/mx_chanbaosi"});  
	}
	if(dubo_itemsallow&&sizeof(dubo_itemsallow)){
		rtn=dubo_itemsallow[random(sizeof(dubo_itemsallow))];
	}
	return rtn;
}

//获得节日特殊物品掉落的接口 
//由liaocheng于07/09/24添加
//由lizhangyang于07/12/20依据07年圣诞活动细节修改
object get_spec_item_for_holiday(void|int level)
{
	// 节日宝箱会间接开出碎玉。常驻挂机环境下禁止怪物投放所有
	// 此类箱子；节日若要重开，必须新增有期限且可审计的活动入口。
	return 0;
	/*
	object ob_rtn;
	int ran = 10;
	//非节日，改为万分之一
	if(random(100000) <= ran){
		if(level){
			int i = 1;
			if(level>=1 && level<=10) i=1;
			else if(level>10 && level<=20) i=2;
			else if(level>20 && level<=30) i=3;
			else if(level>30 && level<=40) i=4;
			else if(level>40 && level<=50) i=5;
			else if(level>50 && level<=60) i=6;
			else if(level>60) i=7;
			mixed err = catch{
				ob_rtn = clone(ITEM_PATH+"/baoxiang/chr_bx_"+i);
			};
			if(err){
				ob_rtn = 0;
			}
			return ob_rtn;
		}
	}
	return 0;
	*/
	/*
	int ran = 10;
	if(random(10000) <= ran){
		string spec_name = "jinsibaoshidai";
		mixed err = catch{
			ob_rtn = clone(ITEM_PATH+"/baoxiang/"+spec_name);
		};
		if(err){
			ob_rtn = 0;
		}
		return ob_rtn;
	}
	else
		return 0;
	//array(string) zongzi = ({"nuomizongzi","xianrouzongzi","xiaozaozongzi","lvdouzongzi","danhuangzongzi","babaozongzi","boluozongzi",});
	//08年国庆活动
	array(int) rand = ({14,12,10,8,6,4,2});//X级十字章对应的掉率,如1级对应的是rand[0],即j+1级对应的是rand[j]
	//array(int) rand = ({100,100,100,100,100,100,100});//X级十字章对应的掉率,如1级对应的是rand[0],即j+1级对应的是rand[j]
	int j = random(7);
	int ran = random(100);
	if(ran < rand[j]){
		//int i = random(sizeof(zongzi));
		//string zongzi_name = zongzi[i];
		string zongzi_name = "bossdrop/shizizhang"+(string)(j+1);//获得X级十字章的文件名
		mixed err = catch{
			ob_rtn = clone(ITEM_PATH + zongzi_name);
		};
		if(!err){
			return ob_rtn;
		}
	}
	else 
		return 0;
	*/
}

//内部接口，被get_item()调用，获得物品等级
//怪物掉落物品等级算法为，1-3级怪掉落1级物品，n级怪(n>3)掉落n-3或者n-2级的装备
private int get_item_level(int level)
{
	int levelbase;//levellimit;
	if(level==1||level==2)
		return 1+random(2);
	else {
		levelbase=level-2;
		if(levelbase>0){ 
			int item_level = levelbase+random(5);
			while(!(item_list[item_level] && sizeof(item_list[item_level]))){
				item_level--;
				if(item_level <= 0){
			    	    item_level = 0;
				    break;
			   	}
			}
			return item_level;
		}
		else {
			werror("something wrong in get_item_level!\n");
			return 0;
		}
	}
}
float get_item_rate_add(int level){
	float ret=1.01;
	switch(level){
		case 71..80:
			ret=1.1;
			break;
		case 81..90:
			ret=1.3;
			break;
		case 91..100:
			ret=1.5;
			break;
		case 101..120:
			ret=1.7;
			break;
		case 121..140:
			ret=1.9;
			break;
		case 141..160:
			ret=2.1;
			break;
		case 161..190:
			ret=2.3;
			break;
		case 191..230:
			ret=2.5;
			break;
		case 231..280:
			ret=2.7;
			break;
		case 281..330:
			ret=3.0;
			break;
		case 331..380:
			ret=3.3;
			break;
		case 381..430:
			ret=3.6;
			break;
		case 431..480:
			ret=4.0;
			break;
		case 481..500:
			ret=4.5;
			break;
		case 501..:
			ret=5.0;
			break;
	}
	return ret;
}
string get_item_name_prefix(int level, void|object ob){
	string ret="";
	switch(level){
		case 71..80:
			ret="欲界-";
			break;
		case 81..90:
			ret="色界-";
			break;
		case 91..100:
			ret="无色界-";
			break;
		case 101..120:
			ret="离三界-初阶-";
			break;
		case 121..140:
			ret="离三界-中阶-";
			break;
		case 141..160:
			ret="离三界-高阶-";
			break;
		case 161..190:
			ret="破虚境-";
			break;
		case 191..230:
			ret="渡劫境-";
			break;
		case 231..280:
			ret="天仙境-";
			break;
		case 281..330:
			ret="金仙境-";
			break;
		case 331..380:
			ret="太乙境-";
			break;
		case 381..430:
			ret="混元境-";
			break;
		case 431..480:
			ret="大罗境-";
			break;
		case 481..500:
			ret="大道境-";
			break;
		case 501..:
			ret="超凡境-";
			break;
	};
	if(ob && level == -1){
		// 按优先级从高到低检测，避免匹配到错误的境界
		if(search(ob->query_name_cn(), "大道境-") !=-1)
			ret="大道境-";
		else if(search(ob->query_name_cn(), "大罗境-") !=-1)
			ret="大罗境-";
		else if(search(ob->query_name_cn(), "混元境-") !=-1)
			ret="混元境-";
		else if(search(ob->query_name_cn(), "太乙境-") !=-1)
			ret="太乙境-";
		else if(search(ob->query_name_cn(), "金仙境-") !=-1)
			ret="金仙境-";
		else if(search(ob->query_name_cn(), "天仙境-") !=-1)
			ret="天仙境-";
		else if(search(ob->query_name_cn(), "渡劫境-") !=-1)
			ret="渡劫境-";
		else if(search(ob->query_name_cn(), "破虚境-") !=-1)
			ret="破虚境-";
		else if(search(ob->query_name_cn(), "离三界-高阶-") !=-1)
			ret="离三界-高阶-";
		else if(search(ob->query_name_cn(), "离三界-中阶-") !=-1)
			ret="离三界-中阶-";
		else if(search(ob->query_name_cn(), "离三界-初阶-") !=-1)
			ret="离三界-初阶-";
		else if(search(ob->query_name_cn(), "离三界-") !=-1)
			ret="离三界-";  // 兼容旧装备
		else if(search(ob->query_name_cn(), "无色界-") !=-1)
			ret="无色界-";
		else if(search(ob->query_name_cn(), "色界-") !=-1)
			ret="色界-";
		else if(search(ob->query_name_cn(), "欲界-") !=-1)
			ret="欲界-";

	}
	//werror("========get_item_name_prefixret:"+ret+"\n");
	return ret;
}
//内部接口，被get_item()调用，为物品掉落的核心算法，主要完成下面几件事：
//1.获取随即属性附加，并生成完整的物品名称
//2.检查是否已生成过这种物品，如果是，则直接从已存在的物品文件clone一个返回给调用者
//  如果不是，要生成相应的物品文件，并将文件写回，最后从该文件clone一个
//	返回给调用者
// 核心，重点：本方法是扩展后的方法，可以生成73级以上的装备，计算差额随机的方式 浮动各个数据，其中73级内的是在系统内固定写死的，73以上的则自动生成
// 核心重点： orginal_level为73级以前的原始装备等级，target_item_level则为目标生成的高于73级以上的装备，用差额来计算浮动数字
//如果想回到原来的文件，在本文件目录下面存了一个备份的itemsd.pike 可以直接拷贝，本动态装备只涉及到本文件，没有修改其他部分，请放心替换
// 生产映射目录可能残留由旧版本或中断写入生成的不完整装备源码。
// clone() 成功不代表它一定继承了完整装备接口；掉落心跳必须先验证，
// 否则一次坏文件就会在 NPC 死亡结算中触发 Attempt to call NULL。
int dynamic_equipment_level_api_valid(object item)
{
	return item &&
		functionp(item->query_item_canLevel) &&
		functionp(item->set_item_canLevel);
}

// 第二层防御（复用路径）：把低阶底版实例的每条属性钳回约束表上限
// 的500倍。既用于复用旧生成文件，也供回收矫正复用。
private void clamp_low_tier_instance(object item,string orgitem)
{
	array(string) entries=item_attributes[orgitem];
	foreach(entries || ({}),string entry){
		array(string) pair=entry/":";
		int limit;
		mixed reader;
		mixed writer;
		int value;
		if(sizeof(pair)>=3 && sscanf(pair[2],"%d",limit)==1 && limit>0){
			reader=item["query_"+pair[0]];
			writer=item["set_"+pair[0]];
			if(functionp(reader) && functionp(writer)){
				value=(int)call_function(reader);
				if(value>limit*5000)
					call_function(writer,limit*5000);
			}
		}
	}
}

private object get_attributes_item(string orgitem,int num,
	int|void orginal_level,int|void target_item_level,void|object item_ob,
	void|mapping newmoon_collection,void|int reroll_floor)
{
	//werror("=============711 num:"+num+"\n");
	int count; //物品要生成的附加属性的个数
	int size; //该物品允许可能出现的属性的个数
	int base,limit,value; //属性的取值范围和最后的确定取值
	int exist_flag=0; //是否已存在的标记
	string attri_name=""; //属性名称
	string item_name=""; //完整的物品名称
	string attri=""; //属性名:n:m 字符串
	string writetmp=""; //追加的附加属性暂时存在这儿
	string writeback=""; //回写到新物品文件中的数据
	array(string) tmp_attri=({}); //临时存储用
	array(string) exist_item_names=({}); //已存在文件列表
	array(string) attri_allow=copy_value(item_attributes[orgitem]); //得到该物品允许出现的属性列表
	object rtn_ob; //接口的返回
	float rate=1.01;// 计算73以上装备的增长率，初始化为1
	//werror("=====orginal_level "+orginal_level+"\n");
	//werror("=====target_item_level "+target_item_level+"\n");
	int flag_no_level = 0;
	if (target_item_level == -1){
		flag_no_level = 1;
		target_item_level = this_player()->query_level();
	}
	if(target_item_level&&orginal_level){
		int difference=target_item_level-orginal_level;//生成目标装备等级和原始装备的等级之差
		if(difference<0) difference=0;
		else{
			if(orginal_level<=65){
				// 洗炼保底：资源型重掷只在[70%,100%]区间取样，杜绝
				// “越洗越差”；怪物掉落仍保持原始均匀分布。
				if(reroll_floor)
					difference=difference*7/10+
						random(difference*3/10+1);
				else
					difference=random(difference);//原始装备小于65的话，增长率保持线性增长
			}
			else{
				// 洗炼保底：高阶底版重掷落在[140%,200%]区间。
				if(reroll_floor)
					difference=difference*7/5+
						random(difference*3/5+1);
				else
					difference=random(difference+difference);//随机增长率，最大可以达到差额的增长率
			}
		}
		rate=((float)(orginal_level+difference))/(float)orginal_level;//增加武器属性的增长率
		if(rate==0) rate=1.01;

	}

	rate=rate*get_item_rate_add(target_item_level);//设置几个等级的门槛，跨过去了有加成1.1 1.3 1.5 1.7
	//werror("=========rate:"+rate+"\n");
	string postfix="00000000000000000000000000000000000";//初始化文件后缀

	size=sizeof(attri_allow);
	count=size<num?size:num;
	writetmp="    set_item_rareLevel("+count+");\n"; //设置新物品的稀有等级

	if(attri_allow&&size) {
		for(int i=1;i<=count;i++) {
			attri=attri_allow[random(size)];

			if(attri&&sizeof(attri)) {
				//werror("------------attri="+attri+"---------\n");
				tmp_attri=attri/":";
				attri_name=(string)tmp_attri[0];
				//取得属性范围的下限
				sscanf((string)tmp_attri[1],"%d",base);
				//取得属性范围的上限
				if(sizeof(tmp_attri) >= 3)
					sscanf((string)tmp_attri[2],"%d",limit);
				else
					limit = base;
				value=base>=limit?limit:(base+random(limit-base+1)); //得到附加属性的确值
				//werror("---------value="+value+"-----------\n");
				if(rate>1)
					value=(int)(value*rate);//按照等级差来设定目标生成装备的数值加成，差值100等级，则提升一倍
				// 数值整备：碰撞修复后新装备回到诚实公式（几百点），
				// 与玩家手中旧装备（几千~几万）断层。按目标等级整体
				// 放大新生成属性，恢复到旧装备的量级。
				if(target_item_level>=200)
					value*=20;
				else if(target_item_level>=100)
					value*=12;
				else if(target_item_level>=50)
					value*=6;
				// 第二层防御：低阶底版的单条属性绝对值不超过其约束表
				// 上限的5000倍（数值整备后合法量级）——高于一切合法生成路径（含随机商店按顶级
				// 玩家等级动态生成），任何调用方传入失控目标等级都会被
				// 就地钳制，从源头掐灭百万级数值。
				if(orginal_level && orginal_level<65 &&
				   value>limit*5000)
					value=limit*5000;
				writetmp+="    set_"+attri_name+"("+value+");\n"; //设置新物品的附加属性
				// 大数值(≥62)不在字母表：把数值本身编进后缀，保证
				// 数值→文件名一一对应。旧版统一替换成'_'会让不同
				// 数值碰撞成同一文件，重掷复用旧文件时高属性被悄悄
				// 换成低属性（越洗越差的根源）。字母表字符不含'_'
				// 和','，旧文件名不会被新编码误命中。
				if(char_value[value]>0)
					postfix[postfix_map[attri_name]]=
						char_value[value];//根据属性修改文件后缀
				else{
					int slot_pos=postfix_map[attri_name];
					string before=slot_pos>0 ?
						postfix[0..slot_pos-1] : "";
					postfix=before+sprintf("_%d,",value)+
						postfix[slot_pos+1..];
				}
				//werror("=========char_value[value] "+char_value[value]+" value"+value+"\n");
				attri_allow-=({attri});
				size--;
			}
			else {
				werror("something wrong with attri in get_attributes_item()\n");
			}
		}
		writetmp+="    name_cn=query_rare_level()+\""+get_item_name_prefix(target_item_level, item_ob)+"\"+name_cn;\n}";
		//werror("=====add attri:\n"+writetmp+"\n");
		//到这里，我们就获得了物品的后缀名，以及需要回写的数据，接下来就是完成前面指出的第二件事
		//orgitem="/weapon/70shelingzhang/70shelingzhang";
		item_name=orgitem+postfix; //得到了完整的物品文件名
		// 只要目标等级与原模板不同，就把等级写进文件名。否则同一低级
		// 模板在不同等级生成但属性后缀相同，会误复用先生成者的攻防值，
		// 形成低级装备跨等级刷属性和货架所见非所得。
		if(target_item_level>73 || target_item_level!=orginal_level)
			item_name=orgitem+postfix+"_"+target_item_level; //得到了完整的物品文件名,大于73的后面加后缀等级
		if(mappingp(newmoon_collection) && sizeof(newmoon_collection) &&
		   (int)newmoon_collection["rank"]>1)
			item_name+="_nm"+(string)(int)newmoon_collection["rank"];
		

		if(Stdio.exist(ITEM_PATH+item_name)){
			mixed err = catch{
				rtn_ob=clone(ITEM_PATH+item_name);
			};
			if(err){
				werror("[ITEMSD][DYNAMIC_EQUIPMENT_CLONE_FAILED] path=%O error=%s\n",
					item_name,describe_error(err));
				rtn_ob=0;
			}
			// 第二层防御（复用路径）：低阶底版的已生成文件可能来自
			// 历史失控生成；复用时对实例属性做同样的上限钳制，防止
			// 同名旧文件复活百万数值。
			if(rtn_ob && orginal_level && orginal_level<65)
				clamp_low_tier_instance(rtn_ob,orgitem);
			if(rtn_ob && !dynamic_equipment_level_api_valid(rtn_ob)){
				werror("[ITEMSD][DYNAMIC_EQUIPMENT_REJECT] path=%O "
					"reason=missing_level_api\n",item_name);
				destruct(rtn_ob);
				return 0;
			}
			// 生产映射目录可能残留旧版本生成的-1模板。保留原文件供
			// 老装备按原数据加载，但普通新掉落实例必须恢复真实等级。
			if(rtn_ob && !flag_no_level && target_item_level>0 &&
			   rtn_ob->query_item_canLevel()<0)
				rtn_ob->set_item_canLevel(target_item_level);
			// 即使装备已存在，也要检查并添加中立玩家职业
			if(rtn_ob) {
				if(mappingp(newmoon_collection) && sizeof(newmoon_collection) &&
				   functionp(rtn_ob->set_newmoon_collection) &&
				   !rtn_ob->set_newmoon_collection(
					(string)newmoon_collection["id"])){
					destruct(rtn_ob);
					return 0;
				}
				array(string) profs = rtn_ob->query_item_profeLimit();
				if(profs && sizeof(profs) > 0 && search(profs, "fangshi") == -1) {
					rtn_ob->set_item_profeLimit("fangshi");
				}
				if(profs && sizeof(profs) > 0 && search(profs, "zhenyue") == -1)
					rtn_ob->set_item_profeLimit("zhenyue");
				if(profs && sizeof(profs) > 0 && search(profs, "tianxiang") == -1)
					rtn_ob->set_item_profeLimit("tianxiang");
				if(profs && sizeof(profs) > 0 && search(profs, "lingyi") == -1)
					rtn_ob->set_item_profeLimit("lingyi");
			}
			return (rtn_ob);
		}
		else{ //如果不存在，则要做很多麻烦的事情
			//生成新的物品文件数据
			//werror("============writetmp:\n"+writetmp+"\n");
			string|zero item_pinyin_name=0;//获得装备的原始拼音名字，为了设置图片
			mixed err1=catch{
				item_pinyin_name=(orgitem/"/")[1];
			};
			if(err1){
				item_pinyin_name=0;
			}
			//werror("==========pinname:"+item_pinyin_name+"\n");
			string orgfile=Stdio.read_file(ITEM_PATH+orgitem);
			if(orgfile&&sizeof(orgfile)) {
				array(string) orgfilelines=orgfile/"\n";
				orgfilelines-=({""});
				orgfilelines-=({"}"});//先把源文件的最后一个括号去掉
				array(string)  writetmplines=writetmp/"\n";//把临时的这个变成数组，这个数组最后一位是右括号}
				// writetmp 追加行的数值已经是最终值（roll阶段乘过rate并
				// 过上限钳制）。历史bug让这些行再落入模板行缩放逻辑被二
				// 次相乘，rate平方正是百万级属性的根源；必须整体跳过。
				int appended_from=sizeof(orgfilelines);
				orgfilelines+=writetmplines;//最后再把两个数组加一起
				int sizelines=sizeof(orgfilelines);

				//if(orgfilelines[sizelines-1])
					//orgfilelines[sizelines-1]=writetmp; //在这里追加新文件的附加属性

				array(string) aocao_color=({"yellow","red","blue"});//随机凹槽的颜色
				//写回到文件
				for(int k=0; k<sizelines; k++) {
					if(k>=appended_from){
						writeback+=orgfilelines[k]+"\n";
						continue;
					}
					//werror("============821writeback+=orgfilelines[k] "+orgfilelines[k]+" index:"+search(orgfilelines[k],"set_attack_power_limit")+"\n");
					// 读取原有文件的防御值和攻击值以及攻击最大值，重置
					if(rate>1 && search(orgfilelines[k],"set_item_canLevel")!=-1){
						if(flag_no_level == 1){
							// 只兼容旧无等级装备明确传入-1后的炼化；普通掉落、
							// 神秘商店和熔炼不再随机生成无等级装备。
							writeback+="    set_item_canLevel(-1);\n"; //设置新物品的的穿戴等级
						}else{
							writeback+="    set_item_canLevel("+target_item_level+");\n"; //设置新物品的的穿戴等级
						}
						
						int aocao_num=random(3)+1;//生成1-3的数字
						if(random(1000)<2)	aocao_num=4;	
						if(random(10000)<2)	aocao_num=5;
						//werror("===============aocao num:"+aocao_num+"\n");
						//50%的几率打入凹槽
						if(random(100)>50 && search(orgfile,"set_color(")==-1 && search(orgfile,"set_aocao_max")==-1)//宝石类的不能打孔，如果装备已经有凹槽，则不在这里设置凹槽	
						{
							//werror("===============887 aocao num:"+aocao_num+"\n");
							writeback+="    set_aocao_max(\""+aocao_color[random(sizeof(aocao_color))]+"\","+aocao_num+");\n"; //设置新物品的的穿戴等级
						}		
						continue;					
					}else if(rate>1 &&search(orgfilelines[k],"set_aocao_max")!=-1 ){
						int aocao_num=random(3)+1;//生成1-3的数字
						if(random(1000)<2)	aocao_num=4;	
						if(random(10000)<2)	aocao_num=5;
						if(search(orgfile,"set_color(")==-1){//判断不是宝石类的
							writeback+="    set_aocao_max(\""+aocao_color[random(sizeof(aocao_color))]+"\","+aocao_num+");\n"; //设置新物品的的穿戴等级
						}
						else{
							writeback+=orgfilelines[k]+"\n";
						}
					}else
					if(rate>1 && search(orgfilelines[k],"set_equip_defend")!=-1){
						int set_equip_defend=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_equip_defend(%d);",nothing,set_equip_defend);
						if(set_equip_defend){
							set_equip_defend=(int)(set_equip_defend*rate);
							writeback+="    set_equip_defend("+set_equip_defend+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}
						
					}else if(rate>1 &&search(orgfilelines[k],"set_attack_power")!=-1 &&search(orgfilelines[k],"set_attack_power_limit")==-1){
						int attack_power=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_attack_power(%d);",nothing,attack_power);
						if(attack_power){
							attack_power=(int)(attack_power*rate);
							writeback+="    set_attack_power("+attack_power+");\n";
						}
						else{
							writeback+=orgfilelines[k]+"\n";
						}
					}else if(rate>1 && search(orgfilelines[k],"set_attack_power_limit")!=-1){
						//werror("===============set_attack_power_limit:"+orgfilelines[k]+"\n");
						int set_attack_power_limit=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_attack_power_limit(%d);",nothing,set_attack_power_limit);
						if(set_attack_power_limit){
							set_attack_power_limit=(int)(set_attack_power_limit*rate);
							writeback+="    set_attack_power_limit("+set_attack_power_limit+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}
					}else if(rate>1 &&search(orgfilelines[k],"set_dodge_add")!=-1){
						int set_dodge_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dodge_add(%d);",nothing,set_dodge_add);
						if(set_dodge_add){
							set_dodge_add=(int)(set_dodge_add*rate);
							if(set_dodge_add>=8)set_dodge_add=8;//闪避最大20
							writeback+="    set_dodge_add("+set_dodge_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}					
					}else if(rate>1 &&search(orgfilelines[k],"set_str_add")!=-1){
						int set_str_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_str_add(%d);",nothing,set_str_add);
						if(set_str_add){
							set_str_add=(int)(set_str_add*rate);
							writeback+="    set_str_add("+set_str_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}
						
					}else if(rate>1 &&search(orgfilelines[k],"set_doub_add")!=-1){
						int set_doub_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_doub_add(%d);",nothing,set_doub_add);
						if(set_doub_add){
							set_doub_add=(int)(set_doub_add*rate);
							if(set_doub_add>=20)set_doub_add=20;//暴击最大提高20%
							writeback+="    set_doub_add("+set_doub_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_life_add")!=-1){
						int set_life_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_life_add(%d);",nothing,set_life_add);
						if(set_life_add){
							set_life_add=(int)(set_life_add*rate);
							writeback+="    set_life_add("+set_life_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_rase_life_add")!=-1){
						int set_rase_life_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_rase_life_add(%d);",nothing,set_rase_life_add);
						if(set_rase_life_add){
							set_rase_life_add=(int)(set_rase_life_add*rate);
							writeback+="    set_rase_life_add("+set_rase_life_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_dex_add")!=-1){
						int set_dex_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dex_add(%d);",nothing,set_dex_add);
						if(set_dex_add){
							set_dex_add=(int)(set_dex_add*rate);
							writeback+="    set_dex_add("+set_dex_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_think_add")!=-1){
						int set_think_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_think_add(%d);",nothing,set_think_add);
						if(set_think_add){
							set_think_add=(int)(set_think_add*rate);
							writeback+="    set_think_add("+set_think_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_hitte_add")!=-1){
						int set_hitte_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_hitte_add(%d);",nothing,set_hitte_add);
						if(set_hitte_add){
							set_hitte_add=(int)(set_hitte_add*rate);
							if(set_hitte_add>=20)set_hitte_add=20;//命中率极限20%
							writeback+="    set_hitte_add("+set_hitte_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_lunck_add")!=-1){
						int set_lunck_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_lunck_add(%d);",nothing,set_lunck_add);
						if(set_lunck_add){
							set_lunck_add=(int)(set_lunck_add*rate);
							writeback+="    set_lunck_add("+set_lunck_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_bingshuang_defend_add")!=-1){
						int set_bingshuang_defend_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_bingshuang_defend_add(%d);",nothing,set_bingshuang_defend_add);
						if(set_bingshuang_defend_add){
							set_bingshuang_defend_add=(int)(set_bingshuang_defend_add*rate);
							writeback+="    set_bingshuang_defend_add("+set_bingshuang_defend_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_huoyan_defend_add")!=-1){
						int set_huoyan_defend_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_huoyan_defend_add(%d);",nothing,set_huoyan_defend_add);
						if(set_huoyan_defend_add){
							set_huoyan_defend_add=(int)(set_huoyan_defend_add*rate);
							writeback+="    set_huoyan_defend_add("+set_huoyan_defend_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_fengren_defend_add")!=-1){
						int set_fengren_defend_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_fengren_defend_add(%d);",nothing,set_fengren_defend_add);
						if(set_fengren_defend_add){
							set_fengren_defend_add=(int)(set_fengren_defend_add*rate);
							writeback+="    set_fengren_defend_add("+set_fengren_defend_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_dusu_defend_add")!=-1){
						int set_dusu_defend_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dusu_defend_add(%d);",nothing,set_dusu_defend_add);
						if(set_dusu_defend_add){
							set_dusu_defend_add=(int)(set_dusu_defend_add*rate);
							writeback+="    set_dusu_defend_add("+set_dusu_defend_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}else if(rate>1 &&search(orgfilelines[k],"set_wulichuantou_add")!=-1){
						int set_wulichuantou_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_wulichuantou_add(%d);",nothing,set_wulichuantou_add);
						if(set_wulichuantou_add){
							set_wulichuantou_add=(int)(set_wulichuantou_add*rate);
							writeback+="    set_wulichuantou_add("+set_wulichuantou_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_dodgechuantou_add")!=-1){//闪避属性扫描
						int set_dodgechuantou_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dodgechuantou_add(%d);",nothing,set_dodgechuantou_add);
						if(set_dodgechuantou_add){
							set_dodgechuantou_add=(int)(set_dodgechuantou_add*rate);
							writeback+="    set_dodgechuantou_add("+set_dodgechuantou_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_mofachuantou_add")!=-1){
						int set_mofachuantou_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_mofachuantou_add(%d);",nothing,set_mofachuantou_add);
						if(set_mofachuantou_add){
							set_mofachuantou_add=(int)(set_mofachuantou_add*rate);
							writeback+="    set_mofachuantou_add("+set_mofachuantou_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}else if(rate>1 && search(orgfilelines[k],"picture=name")!=-1 &&item_pinyin_name){
						//werror("=======write picture as pinyin name:"+item_pinyin_name+"\n");
						writeback+="    picture=\""+item_pinyin_name+"\";\n";
					}
					else if(search(orgfilelines[k],"set_item_profeLimit(")!=-1){
						// 捕获所有职业限制设置行，保持原样
						writeback+=orgfilelines[k]+"\n";
					}
					else{
						//werror("===============nothing found in file setup default:"+orgfilelines[k]+"\n");
						writeback+=orgfilelines[k]+"\n";
					}
					
				}
				//werror("====item_name:\n"+item_name+"\n");
				//werror("====:\n"+writeback+"\n");

				// 自动为所有生成的装备添加方士职业支持
				// 检查writeback中是否已经包含fangshi
				if(search(writeback, "set_item_profeLimit") != -1) {
					if(search(writeback, "set_item_profeLimit(\"fangshi\")") == -1) {
						// 在文件结束前 } 之前插入
						int last_brace = search(writeback, "\n}\n");
						if(last_brace == -1) {
							last_brace = search(writeback, "}\n");
						}
						if(last_brace != -1) {
							writeback = writeback[..last_brace-1] + "    set_item_profeLimit(\"fangshi\");\n" + writeback[last_brace..];
						}
					}
				}
				if(search(writeback, "set_item_profeLimit") != -1 &&
				   search(writeback, "set_item_profeLimit(\"zhenyue\")") == -1) {
					int last_brace = search(writeback, "\n}\n");
					if(last_brace == -1)
						last_brace = search(writeback, "}\n");
					if(last_brace != -1)
						writeback = writeback[..last_brace-1] +
							"    set_item_profeLimit(\"zhenyue\");\n" +
							writeback[last_brace..];
				}
				if(search(writeback, "set_item_profeLimit") != -1 &&
				   search(writeback, "set_item_profeLimit(\"tianxiang\")") == -1) {
					int last_brace = search(writeback, "\n}\n");
					if(last_brace == -1)
						last_brace = search(writeback, "}\n");
					if(last_brace != -1)
						writeback = writeback[..last_brace-1] +
							"    set_item_profeLimit(\"tianxiang\");\n" +
							writeback[last_brace..];
				}
				if(search(writeback, "set_item_profeLimit") != -1 &&
				   search(writeback, "set_item_profeLimit(\"lingyi\")") == -1) {
					int last_brace = search(writeback, "\n}\n");
					if(last_brace == -1)
						last_brace = search(writeback, "}\n");
					if(last_brace != -1)
						writeback = writeback[..last_brace-1] +
							"    set_item_profeLimit(\"lingyi\");\n" +
							writeback[last_brace..];
				}
				if(mappingp(newmoon_collection) && sizeof(newmoon_collection) &&
				   (int)newmoon_collection["rank"]>1){
					int last_brace=search(writeback,"\n}\n");
					if(last_brace==-1)
						last_brace=search(writeback,"}\n");
					if(last_brace!=-1)
						writeback=writeback[..last_brace-1]+
							"    set_newmoon_collection(\""+
							(string)newmoon_collection["id"]+"\");\n"+
							writeback[last_brace..];
				}

				int write_flag=write_item_file(ITEM_PATH+item_name,writeback);

				//从写回的文件中clone一个该物品返回
				if(Stdio.exist(ITEM_PATH+item_name)&&write_flag==1){
					string new_item_path = ITEM_PATH+item_name;
					program p = compile_file(new_item_path);
					//加入到当前进程的master中的programs中
					if(p){
						foreach(indices(master()->programs),string s){
							if(master()->programs[s]==p){//如果存在，去掉旧的
								//werror("****该新物品已经在影射中=["+new_item_path+"]****\n");
								m_delete(master()->programs,p);
							}
						}
						//将新生成对象加入master的总对象影射中
						master()->programs[new_item_path]=p;
						rtn_ob=clone(p);
						if(rtn_ob && mappingp(newmoon_collection) &&
						   sizeof(newmoon_collection) &&
						   functionp(rtn_ob->set_newmoon_collection) &&
						   !rtn_ob->set_newmoon_collection(
							(string)newmoon_collection["id"])){
							destruct(rtn_ob);
							rtn_ob=0;
						}
					}
					//werror("$$$$$$$$$$$$$$$$创建新物品结束$$$$$$$$$$$$$$$$$$$$\n");
					if(!rtn_ob){
						return 0;
						//werror("	clone新物品给玩家失败了。\n");
					}
					else
						//werror("	已成功clone了这个新的物品给玩家。\n");
						return rtn_ob;
				}
				else
					return 0;
			}
			else {
				//werror("read file "+ITEM_PATH+orgitem+" wrong!!\n");
				return 0;
			}
		}
	}
	else {
		//werror("something wrong with attri_allow in get_attributes_item()\n");
		return 0;
	}
}

protected void create()
{
	//werror("==========  [ITEMSD start!]  =========\n");
	//读入普通物品的索引文件
	if(!ReadFile_item_list(FILE_PATH+"orgItems.list")){
		//werror("=====  Item_list end!  ====\n");
		exit(1);
	}

	//读入特殊物品的索引文件
	if(!ReadFile_spec_item_list(FILE_PATH+"specItems.list")){
		//werror("=====  Spc_Item_list end!  ====\n");
		exit(1);
	}

	//读入普通物品属性约束索引文件
	if(!ReadFile_item_attributes(FILE_PATH+"allItems.list")){
		//werror("=====  Item_attributes end!  ====\n");
		exit(1);
	}

	//读取世界掉落物品 evan added 2008.08.17
	if(!ReadFile_worlddrop_item_list(FILE_PATH+"worlddrop_item.list")){
		//werror("=====  Worlddrop_Item_list end!  ====\n");
		exit(1);
	}
	//end of evan added 2008.08.17
	//werror("==========  [ITEMSD end!]  =========\n");
}


//熔炼物品时被调用
//当熔炼目标装备大于73是，则按照73的装备模版出，增加增量属性到目标等级，见get_item(方法)
object get_ronglian_item(int itemlevel,int playerluck)
{
	string item_rawname=""; //白装备名称,包含了一个路径。如weapon/1taomujian
	array(string) itemsallow=({}); //等级范围类允许物品列表
	object ret_item; //最后生成并返回的装备
	int a=itemlevel-1; //概率算法的一个因子
	int b=101-itemlevel; //第二个因子

	int orgitem_level=itemlevel;
	if(itemlevel>73){
		orgitem_level=73;//支持超过73以上的装备，如果超过70级按照70级的装备模板区增量增加
		a=72;//装备稀有度的因子按照73级npc的等级来，保持之前的概率分布
		b=35;//极品10万分之4
	}
	//werror("============orgitem_level:"+orgitem_level+"\n");
	//werror("============itemlevel:"+itemlevel+"\n");
	//判断是否掉落白色物品
	itemsallow=itemlevel>73?item_list[73]:item_list[itemlevel]; //大于73按照73的模版出装备
	if(!itemsallow){
		//werror("----Caution:get itemlevel=0 in get_ronglian_item()!----\n");
		return 0;
	}
	item_rawname=itemsallow[random(sizeof(itemsallow))]; //在这里获得了白色物品的名字
	//判断掉落的物品是否有属性
	//掉落的属性概率xxxxxxxxxxx
	int seven = (int)(120-a*2+playerluck*b*0.01);
	int six = (int)(180-a*3+playerluck*b*0.05);
	int five = (int)(280-a*4+playerluck*b*0.1);
	int four = (int)(420-a*5+playerluck*b*0.2);
	int three = (int)((600-a*8)*5+playerluck*b*0.5);
	int two = (int)((820-a*12)*10+playerluck*b*0.7);
	int one = (int)((1080-a*16)*20+playerluck*b*1);

	int ran=random(100000)+1;
	if(ran<=seven)
		ret_item=get_attributes_item(item_rawname,7,orgitem_level,itemlevel); //调用了获得属性物品的核心接口
	else if(ran<=six)
		ret_item=get_attributes_item(item_rawname,6,orgitem_level,itemlevel); //调用了获得属性物品的核心接口
	else if(ran<=five)
		ret_item=get_attributes_item(item_rawname,5,orgitem_level,itemlevel); //调用了获得属性物品的核心接口
	else if(ran<=four)
		ret_item=get_attributes_item(item_rawname,4,orgitem_level,itemlevel); //调用了获得属性物品的核心接口
	else if(ran<=three)
		ret_item=get_attributes_item(item_rawname,3,orgitem_level,itemlevel); //调用了获得属性物品的核心接口
	else if(ran<=two)
		ret_item=get_attributes_item(item_rawname,2,orgitem_level,itemlevel); //调用了获得属性物品的核心接口
	else if(ran<=one)
		ret_item=get_attributes_item(item_rawname,1,orgitem_level,itemlevel); //调用了获得属性物品的核心接口
	else
		ret_item=get_attributes_item(item_rawname,1,orgitem_level,itemlevel); //调用了获得属性物品的核心接口
		//ret_item=clone(ITEM_PATH+item_rawname); //产生白物品

	return ret_item;
}

//炼化物品（用玉石转化装备属性）调用的接口
//这个接口也是获得num属性指定装备的接口
object get_convert_item(string item_rawname,int num,int|void orginal_level,int|void item_level, void|object item_ob)
{
	mapping newmoon_collection=query_newmoon_collection_for_item(item_ob);
	// 炼化/兑换都是玩家消耗资源的重掷，走保底区间。
	object ret_item = get_attributes_item(item_rawname,num,orginal_level,
		item_level,item_ob,newmoon_collection,1);//生成目标itemlevel大于70级的装备
	return ret_item;
}

// 返回炼化装备真正的白装底版路径。
// 动态装备与新月套装可能复用旧图片，图片只能用于显示，不能再作为底版身份。
// 优先从对象实际程序路径还原同目录底版；仅为历史特殊对象保留图片回退。
string query_convert_item_rawname(object item)
{
	string path;
	string relative;
	string candidate;
	string item_type;
	string picture;
	array(string) parts;
	if(!item || !can_equip(item))
		return "";
	path=(file_name(item)/"#")[0];
	if(has_prefix(path,ITEM_PATH)){
		relative=path[sizeof(ITEM_PATH)..];
		parts=relative/"/";
		if(sizeof(parts)>=3){
			parts[sizeof(parts)-1]=parts[sizeof(parts)-2];
			candidate=parts*"/";
			if(Stdio.exist(ITEM_PATH+candidate))
				return candidate;
		}
	}
	item_type=(string)item->query_item_type();
	if(item_type=="single_weapon" || item_type=="double_weapon")
		item_type="weapon";
	picture=(string)item->query_picture();
	if(item_type!="" && picture!=""){
		candidate=item_type+"/"+picture+"/"+picture;
		if(Stdio.exist(ITEM_PATH+candidate))
			return candidate;
	}
	return "";
}

//根据参数level随机给出一个与level相近的装备名
string get_itemname_on_level(int level)
{
	string item_name = "";
	int itemlevel=get_item_level(level); //调用了获得物品等级的接口
	array(string) itemsallow=({}); //等级范围类允许物品列表
	itemsallow=item_list[itemlevel];
	if(itemsallow && sizeof(itemsallow)){
		item_name=itemsallow[random(sizeof(itemsallow))]; //在这里获得了白色物品的名字
	}
	return item_name;
}

/** 回收矫正用：底版路径的模板档位（文件名前缀数字，如1duanmugun=1）。 */
int query_base_template_tier(string base_path)
{
	string basename;
	string digits="";
	int tier;
	array(string) parts=base_path/"/";
	if(!sizeof(parts))
		return 0;
	basename=parts[sizeof(parts)-1];
	for(int i=0;i<sizeof(basename);i++){
		int one=basename[i];
		if(one<'0' || one>'9')
			break;
		digits+=basename[i..i];
	}
	tier=(int)digits;
	if(tier<0 || tier>1000)
		return 0;
	return tier;
}

/** 回收矫正用：底版每条属性的合法上限（约束表上限×500，高于一切
 合法生成路径）。返回 属性名:上限 映射。 */
mapping(string:int) query_base_attribute_caps(string base_path)
{
	mapping(string:int) caps=([]);
	array(string) entries=item_attributes[base_path];
	foreach(entries || ({}),string entry){
		array(string) pair=entry/":";
		int limit;
		if(sizeof(pair)>=3 && sscanf(pair[2],"%d",limit)==1 &&
		   limit>0)
			caps[pair[0]]=limit*5000;
	}
	return caps;
}

private array(string) abnormal_gear_attack_defense_attrs=({
	"attack_add","defend_add","weapon_attack_add","spec_mofa_attack_add",
	"wulichuantou_add","mofachuantou_add","huo_mofa_attack_add",
	"feng_mofa_attack_add","bing_mofa_attack_add","du_mofa_attack_add",
	"attack_huoyan_add","attack_fengren_add","attack_dusu_add",
	"attack_bingshuang_add","huoyan_defend_add","fengren_defend_add",
	"dusu_defend_add","bingshuang_defend_add","all_mofa_defend_add",
});

/** 异常装备统一分类：0=正常；1=历史爆炸装（低阶底版单条属性超过
 约束表上限500倍）；2=超出千级合法峰值10倍的上限装（含无法解析
 底版但攻防族属性超过265000绝对线的装备）。随身登录回收、仓库
 回收必须共用本分类，防止阈值漂移。 */
int query_abnormal_gear_class(object item)
{
	string base;
	mapping(string:int) caps;
	int tier;
	int over_cap=0;
	if(!item || !functionp(item->query_item_rareLevel))
		return 0;
	base=query_convert_item_rawname(item);
	if(base!=""){
		caps=query_base_attribute_caps(base);
		tier=query_base_template_tier(base);
		foreach(sort(indices(caps)),string attr){
			mixed reader=item["query_"+attr];
			int value;
			if(!functionp(reader))
				continue;
			value=(int)call_function(reader);
			if(value>caps[attr]*10)
				return 2;
			if(value>caps[attr])
				over_cap=1;
		}
		if(over_cap && tier>=1 && tier<65)
			return 1;
		return 0;
	}
	foreach(abnormal_gear_attack_defense_attrs,string attr){
		mixed reader=item["query_"+attr];
		int value;
		if(!functionp(reader))
			continue;
		value=(int)call_function(reader);
		if(value>265000)
			return 2;
	}
	return 0;
}

/** 仓库条目只保存物品文件路径；按文件克隆后走同一分类。
 生成后的装备文件不再改写，结果按路径缓存，避免每次登录重复克隆。
 返回0=正常，1/2同 query_abnormal_gear_class。 */
private mapping(string:int) abnormal_gear_file_cache=([]);

int query_abnormal_gear_class_by_file(void|string relative)
{
	object item;
	mixed err;
	array(string) tmp;
	int result;
	if(!relative || relative=="")
		return 0;
	tmp=relative/"item/";
	if(sizeof(tmp)==2)
		relative=tmp[1];
	if(zero_type(abnormal_gear_file_cache[relative])==0)
		return abnormal_gear_file_cache[relative];
	err=catch{ item=clone(ITEM_PATH+relative); };
	if(err || !item){
		if(item)
			destruct(item);
		abnormal_gear_file_cache[relative]=0;
		return 0;
	}
	result=query_abnormal_gear_class(item);
	destruct(item);
	abnormal_gear_file_cache[relative]=result;
	return result;
}


//判断物品是否是意见装备（武器、护甲、饰品等，即可以装备在身上的物品）
int can_equip(object ob)
{
	int re = 0;
	if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry")
		re =1;
	return re;
}

// 炼化玉石费用的唯一权威公式；保持历史数值不变。
int query_convert_equip_yushi_cost(object item)
{
	int level;
	if(!item || !item->query_item_canLevel)
		return 0;
	level=(int)item->query_item_canLevel();
	switch(level){
		case 1..10: return 2;
		case 11..20: return 4;
		case 21..30: return 6;
		case 31..40: return 8;
		default: return 10;
	}
}



//购买物品的接口
//由caijie添加于2008/6/24
private int buy_inventory_amount(object player,string item_name)
{
	int amount;
	foreach(all_inventory(player),object one)
		if(one && one->query_name()==item_name)
			amount+=one->is("combine_item") ? (int)one->amount : 1;
	return amount;
}

string buy_items(object item,void|int yushi,void|int yushi_level,int money)
{
	object me = this_player();
	string s = "";
	if(!me || !item || yushi<0 || money<0 || me->if_over_load(item))
		return "商品无效或背包已满\n";
	int have_money = me->query_account();
	if(have_money<money){
		s += "黄金不够\n";
		return s ;
	}
	if(yushi){
		int unit_value = YUSHID->get_yushi_value(yushi_level);
		if(unit_value <= 0){
			s += "玉石价格有误\n";
			return s;
		}
		int yushi_value = yushi*unit_value;
		if(!YUSHID->have_enough_yushi(me,yushi_value)){
			s += "玉石不够\n";
			return s;
		}
		int before_wallet=ACCOUNT_WALLETD->query_balance(me);
		int before_physical=YUSHID->query_physical_all_num(me);
		if(!YUSHID->pay_yushi(me,yushi_value)){
			s += "玉石扣除失败，请稍后再试\n";
			return s;
		}
		me->del_account(money);
		int amount=item->is("combine_item") ? (int)item->amount : 1;
		string bought_name=(string)item->query_name();
		int before=buy_inventory_amount(me,bought_name);
		int delivered;
		if(item->is("combine_item")){
			item->move_player((string)me->query_name());
			delivered=buy_inventory_amount(me,bought_name)-
				before==amount;
		}
		else
			delivered=item->move(me)==1 && environment(item)==me;
		if(!delivered){
			if(money)
				me->add_account(money);
			if(!YUSHID->rollback_yushi_payment(me,before_wallet,
			   before_physical,"item_purchase_delivery_failed"))
				return "商品发放和退款异常，请立即联系客服\n";
			return "商品发放失败，费用已退回\n";
		}
		s += "购买成功！\n";
		return s;
	}
	me->del_account(money);
	if(item->move(me)!=1 || environment(item)!=me){
		if(money)
			me->add_account(money);
		return "商品发放失败，费用已退回\n";
	}
	s += "购买成功！\n";
	return s;
}


/**********************************
 *方法描述：列出同种物品
 *参数：playe:玩家   kind：物品类型   
 *      cmd:要调用的指令  name:另一个物品的名称
 *author:caijie
 *Date : 2008/08/25
 *********************************/
//string daoju_list(object player,string cmd,string kind,string name)
string daoju_list(object player,string cmd,string kind)
{
	string s = "";
	array(object) all_ob = all_inventory(player);
	foreach(all_ob,object ob){
		if(ob->query_item_type()==kind){
			string ob_namecn = ob->query_short();
			/*
			string path = file_name(ob);
			string file_name = path - ITEM_PATH;
			array(string) file = file_name/"#";
			string ob_name = file[0];
			*/
			string ob_name = ob->query_name();
			s += "["+ob_namecn+":"+cmd+" "+ob_name+"]\n";
		}
	}
	return s;
}
/*判断玩家身上是否有足够多的某种物品
变量      player 玩家
          itemName 物品名
          num 需要的数量 （如果不输入，则默认为1）
返回说明  0:没有该物品
          1:有该物品，且数量足够
	  2:有该物品，但数量不够
 */
int if_have_enough(object player,string itemName,void|int num)
{
	int re = 0;
	int numTmp = 0;
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_name()== itemName ){
			numTmp += ob->amount;
			re = 1;
		}
	}
	if(num)
	{
		if(numTmp<num) 
			return 2;//数目不够
		else
			return 1;
	}
	else
	return re;

}

private string safe_newmoon_binding_log_field(string value)
{
	string result=value || "";
	result=replace(result,"\r"," ");
	result=replace(result,"\n"," ");
	result=replace(result,"|","/");
	if(sizeof(result)>240)
		result=result[..239];
	return result;
}

private void append_newmoon_binding_log(string line)
{
	mixed log_error=catch{
		Stdio.append_file(ROOT+"/log/newmoon_item_binding.log",line);
	};
	if(log_error)
		werror("[NEWMOON_BINDING] audit log write failed: %s\n",
			describe_error(log_error));
}

string query_player_account_owner(object player)
{
	string owner="";
	int test_owner;
	if(!player || !functionp(player->is) || !player->is("player") ||
	   !functionp(player->query_name))
		return "";
	if(functionp(player->query_account_owner))
		owner=(string)player->query_account_owner();
	if(owner=="")
		owner=(string)player->query_name();
	if(sizeof(owner)<2 || sizeof(owner)>64)
		return "";
	test_owner=has_prefix(owner,"__testunit_") && has_suffix(owner,"__");
	for(int index=0;index<sizeof(owner);index++){
		int one=owner[index];
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || (test_owner && one=='_'))
			continue;
		return "";
	}
	return owner;
}

private string new_newmoon_binding_id(object item,object player,
	string owner,string reason)
{
	object hash=Crypto.SHA256();
	hash->update(owner+"|"+(string)player->query_name()+"|"+
		(file_name(item)/"#")[0]+"|"+reason+"|"+(string)time()+"|"+
		String.string2hex(Crypto.Random.random_string(16)));
	return String.string2hex(hash->digest());
}

/**
 * Return 2 for a new binding, 1 for non-New-Moon/already same-account, and 0
 * for invalid input or an ownership conflict.
 */
int bind_newmoon_item_to_player(object item,object player,string reason)
{
	string owner;
	string current_owner;
	string binding_id;
	int bound_at;
	if(!item)
		return 0;
	if(!functionp(item->query_newmoon_resonance_profession) ||
	   (string)item->query_newmoon_resonance_profession()=="")
		return 1;
	owner=query_player_account_owner(player);
	if(owner=="" || !functionp(item->is_newmoon_binding_reason) ||
	   !item->is_newmoon_binding_reason(reason) ||
	   !functionp(item->apply_newmoon_account_binding))
		return 0;
	current_owner=functionp(item->query_newmoon_account_bind_owner) ?
		(string)item->query_newmoon_account_bind_owner() : "";
	if(current_owner!=""){
		if(current_owner!=owner)
			return 0;
		if(!item->apply_newmoon_account_binding(owner,
		   (string)item->query_newmoon_account_bind_reason(),
		   (int)item->query_newmoon_account_bind_time(),
		   (string)item->query_newmoon_account_bind_id()))
			return 0;
		return 1;
	}
	bound_at=time();
	binding_id=new_newmoon_binding_id(item,player,owner,reason);
	if(!item->apply_newmoon_account_binding(owner,reason,bound_at,binding_id))
		return 0;
	append_newmoon_binding_log(
		(string)bound_at+"|bind|id="+binding_id+"|account="+
		safe_newmoon_binding_log_field(owner)+"|character="+
		safe_newmoon_binding_log_field((string)player->query_name())+
		"|reason="+reason+"|item="+
		safe_newmoon_binding_log_field((file_name(item)/"#")[0])+"|name="+
		safe_newmoon_binding_log_field((string)item->query_name_cn())+"\n");
	return 2;
}

int rollback_newmoon_item_binding(object item,object player,string binding_id)
{
	string owner=query_player_account_owner(player);
	if(owner=="" || !item ||
	   !functionp(item->rollback_newmoon_account_binding))
		return 0;
	if(!item->rollback_newmoon_account_binding(owner,binding_id))
		return 0;
	append_newmoon_binding_log(
		(string)time()+"|rollback|id="+
		safe_newmoon_binding_log_field(binding_id)+"|account="+
		safe_newmoon_binding_log_field(owner)+"|character="+
		safe_newmoon_binding_log_field((string)player->query_name())+"\n");
	return 1;
}

int bind_equipped_newmoon_items(object player,string reason)
{
	mapping equipped;
	array(object) seen=({});
	int newly_bound=0;
	if(!player || !functionp(player->query_equip))
		return 0;
	equipped=player->query_equip();
	if(!mappingp(equipped))
		return 0;
	foreach(values(equipped),object item){
		int status;
		if(!item || search(seen,item)!=-1)
			continue;
		seen+=({item});
		status=bind_newmoon_item_to_player(item,player,reason);
		if(status==2)
			newly_bound++;
	}
	return newly_bound;
}

int newmoon_item_cross_account_blocked(object item)
{
	return item && functionp(item->query_newmoon_account_bound) &&
		(int)item->query_newmoon_account_bound()==1;
}

/** Fail closed when an account-bound New Moon instance reaches the wrong user. */
int newmoon_item_usable_by_player(object item,object player)
{
	string owner;
	string player_owner;
	if(!item || !functionp(item->query_newmoon_resonance_profession) ||
	   (string)item->query_newmoon_resonance_profession()=="")
		return 1;
	player_owner=query_player_account_owner(player);
	if(player_owner=="")
		return 0;
	owner=functionp(item->query_newmoon_account_bind_owner) ?
		(string)item->query_newmoon_account_bind_owner() : "";
	return owner=="" || owner==player_owner;
}
