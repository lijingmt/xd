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
private static mapping(int:array(string)) spec_item_list = ([]);
///////////////07/2/7

//记录所有白色装备的映射表
private static mapping(int:array(string)) item_list = ([]);

//记录白色装备允许出现属性的映射表
private static mapping(string:array(string)) item_attributes = ([]);

//用于生成物品文件后缀的映射表,现在暂时未用上
private static mapping(string:int) postfix_map = ([
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
private static mapping(int:int) char_value = ([
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
private static mapping(string:string) worlddrop_item_list = ([]);

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
					//记录在item_list映射中
					item_list[(int)tmp[0]]=itemnames-({""});//copy_value(itemnames);
				}
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	//werror("===== Error! file not exist =====\n");
	return 0;
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
object get_item(int npclevel,int playerlevel,int playerluck)
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
		itemsallow=item_list[itemlevel]; 
		if(!itemsallow){
			return 0;
		}
		
		item_rawname=itemsallow[random(sizeof(itemsallow))]; //在这里获得了白色物品的名字
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


//外部接口，由fight_die()调用，为世界掉落装备的的接口
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
object get_spec_item(int npclevel,int playerlevel,int playerluck)
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
		}
	}
	if((random(100000)+1)<=got_it) {
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
	//return 0;//关闭活动
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
			//werror("something wrong in get_item_level!\n");
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
		case 101..:
			ret=1.7;
			break;
	}
	return ret;
}
string get_item_name_prefix(int level){
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
		case 101..:
			ret="离三界-";
			break;
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
private object get_attributes_item(string orgitem,int num,int|void orginal_level,int|void target_item_level)
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
	if(target_item_level&&orginal_level){
		int difference=target_item_level-orginal_level;//生成目标装备等级和原始装备的等级之差
		if(difference<0) difference=0;
		else{
			if(orginal_level<=65)
				difference=random(difference);//原始装备小于65的话，增长率保持线性增长
			else{
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
				writetmp+="    set_"+attri_name+"("+value+");\n"; //设置新物品的附加属性
				postfix[postfix_map[attri_name]]=char_value[value];//根据属性修改文件后缀
				if(char_value[value]==0){
					postfix[postfix_map[attri_name]]=95;//如果不在字母表，则用_替代 95代表 下划线 _
				}
				//werror("=========char_value[value] "+char_value[value]+" value"+value+"\n");
				attri_allow-=({attri});
				size--;
			}
			else {
				werror("something wrong with attri in get_attributes_item()\n");
			}
		}
		writetmp+="    name_cn=query_rare_level()+\""+get_item_name_prefix(target_item_level)+"\"+name_cn;\n}";
		//werror("=====add attri:\n"+writetmp+"\n");
		//到这里，我们就获得了物品的后缀名，以及需要回写的数据，接下来就是完成前面指出的第二件事
		//orgitem="/weapon/70shelingzhang/70shelingzhang";
		item_name=orgitem+postfix; //得到了完整的物品文件名
		if(target_item_level>73)//这里之所以不用postfix，他超出了文件名最大长度，存储出现问题,暂时放postfix等以后解决
			item_name=orgitem+postfix+"_"+target_item_level; //得到了完整的物品文件名,大于73的后面加后缀等级
		

		if(Stdio.exist(ITEM_PATH+item_name)){
			mixed err = catch{
				rtn_ob=clone(ITEM_PATH+item_name);
			};
			if(err)
				rtn_ob=0;
			return (rtn_ob);
		}
		else{ //如果不存在，则要做很多麻烦的事情
			//生成新的物品文件数据
			//werror("============writetmp:\n"+writetmp+"\n");
			string item_pinyin_name=0;//获得装备的原始拼音名字，为了设置图片
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
				orgfilelines+=writetmplines;//最后再把两个数组加一起
				int sizelines=sizeof(orgfilelines);
				
				//if(orgfilelines[sizelines-1])
					//orgfilelines[sizelines-1]=writetmp; //在这里追加新文件的附加属性

				array(string) aocao_color=({"yellow","red","blue"});//随机凹槽的颜色
				//写回到文件
				for(int k=0; k<sizelines; k++) {
					//werror("============821writeback+=orgfilelines[k] "+orgfilelines[k]+" index:"+search(orgfilelines[k],"set_attack_power_limit")+"\n");
					// 读取原有文件的防御值和攻击值以及攻击最大值，重置
					if(rate>1 && search(orgfilelines[k],"set_item_canLevel")!=-1){
						if(random(10000)<=1){
							//万分之2的几率出现无等级需求的装备
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
					else{
						//werror("===============nothing found in file setup default:"+orgfilelines[k]+"\n");
						writeback+=orgfilelines[k]+"\n";
					}
					
				}
				//werror("====item_name:\n"+item_name+"\n");
				//werror("====:\n"+writeback+"\n");
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

void create()
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
object get_convert_item(string item_rawname,int num,int|void orginal_level,int|void item_level)
{
	object ret_item = get_attributes_item(item_rawname,num,orginal_level,item_level);//生成目标itemlevel大于70级的装备
	return ret_item;
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


//判断物品是否是意见装备（武器、护甲、饰品等，即可以装备在身上的物品）
int can_equip(object ob)
{
	int re = 0;
	if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry")
		re =1;
	return re;
}



//购买物品的接口
//由caijie添加于2008/6/24
string buy_items(object item,void|int yushi,void|int yushi_level,int money)
{
	object me = this_player();
	string s = "";
	int have_money = me->query_account();
	if(have_money<money){
		s += "黄金不够\n";
		return s ;
	}
	if(yushi){
		int have_yushi = YUSHID->query_yushi_num(me,yushi_level);
		if(have_yushi<yushi){
			s += "玉石不够\n";
			return s;
		}
		string yushi_name = YUSHID->get_yushi_name(yushi_level);
		me->remove_combine_item(yushi_name,yushi);
	}
	me->del_account(money);
	item->move(me);
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

