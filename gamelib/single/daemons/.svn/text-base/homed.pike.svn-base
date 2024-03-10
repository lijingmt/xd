/**
  家园系统
  
  @author evan 
  2008/08/18
  
 【数据结构】
     家园的设计中，最难以理解的就是房间的树形结构，希望以下的说明能对你有所帮助：
          1、家园中，"地产"被划分为4层结构，按照范围从大到小依次是：区域(area)、地段(slot)、公寓(flat)、房间(home);
	  2、各级"地产"定义及相互关系
	     区域(area)：最大的地产单位，不同的区域，其在作物养成方面的特性不通，详情参见 /gamelib/etc/home/map_area 中的设定；
	     地段(slot)：一个区域包括若干地段。不通地段中玩家可培养的作物数量不同，详情参见 /gamelib/etc/home/map_slot 中的设定；
	     公寓(flat)：一个地段中包含若干栋公寓，每栋公寓是一定数量"房间"的集合，设置公寓主要是为了防止一个地段中有过多的"房间"，                          从而引起玩家查找的不便；
	     家(home)：最小的地产单位，每个玩家都可以拥有一个home(其中可能包含若干房间)，家园的各项功能都home中实现。
	  3、文件的存放
	     (1) 所有家园的房间文件都存放在 gamelib/d/home 文件夹下；
             (2) 例：在 home/xd/qianxuehu/qianxuemen/lei/001 中，存放了一个home的相关信息。
	             其中：         xd：为将来可能出现的合区预留
		             qianxuehu：区域(area)名
			    qianxuemen：地段(slot)名
			           lei：公寓(flat)名
			           001：家园(home)编号
	 4、数据操作(增、删、改、查、保存等)
	    (1)保存家园信息的文件一共有两个，都位于gamelib/etc/home文件夹中。
	           a.detail_home  记录了每个家园(home)的详细信息；
		   b.map_home     记录了所有家园的占用情况(已被占用\未被占用)；
	    (2)数据的读取与使用
	           当游戏启动时，
 【方法说明】
 
 */


#include <globals.h>
#include <gamelib/include/gamelib.h>
#include <wapmud2/include/wapmud2.h>
#define AREA_MAP  "/gamelib/etc/home/map_area"                               //区域总表
#define SLOT_MAP  "/gamelib/etc/home/map_slot"                               //地段总表
#define FLAT_MAP  "/gamelib/etc/home/map_flat"                               //公寓总表
#define ROOM_MAP  "/gamelib/etc/home/map_home"                               //家总表
#define LEVEL_MAP  "/gamelib/etc/home/map_level"                             //等级总表
#define DROP_MAP  "/gamelib/etc/home/map_drop"                               //掉落信息
#define INFANCY_MAP  "/gamelib/etc/home/map_infancy"                         //npc贩卖的种子、小动物等
#define HOME_INFO  "/gamelib/etc/home/detail_home"                           //家详细信息
#define SHOPRCM_MAP  "/gamelib/etc/home/shop_recommend"                      //店铺推荐信息

#define COMM_FEE 0.1                                                         //转让手续费 房价的10%
#define DEPR_FEE 0.2                                                         //房产变卖折旧费 房价的20%
#define ROOMS ({"door","main","ore","animal","plant"})                       //每个home中所有的房间
#define ROOMS_CN ({"门厅","前厅","矿山","牧场","花园"})                      //每个home中所有的房间的中文名
#define FUNCTION_ROOMS ({"feitianxiaowu","piaoxiangxiaoxie","liangongcaolu","shujuanxuanshi","lingguangxiaozhu","yanshouxiaoxie","yanfaxiaoxie","lidaoxiaozhu","liufaxiaozhu","shuxianggelou","lingyunxuanshi","piaoyingcaolu","manlicaowu","fengxuezhai"}) //功能房间
#define FUNCTION_ROOMS_CN ({"飞天小屋","飘香小谢","练功草庐","书卷轩室","灵光小筑","延寿小榭","延法小榭","力道小筑","流法小筑","书香阁楼","灵韵轩室","飘影草庐","蛮力草屋","风雪斋"})                                     //功能房间中文名
#define SHOP ({"sijiaxiaodian"}) 				//店铺 caijie
#define SHOP_CN ({"私家小店"})                  		//店铺中文名 caijie
#define ROOM_PATH ROOT "/gamelib/d/home/template/"                           //home中房间模板所在位置
#define LIFE_PATH ROOT "/gamelib/clone/item/home/grown"                      //所有"生命"文件所在位置
#define TIME_SAPCE 600                                                       //每10分钟将内存中的数据写入到文件中

#define LIFE_TYPE  ({"ore","plant","animal"})                                //生物的种类
//#define SPEED_UNIT 2                                                       //生物生长速度为每2秒提高xxx点
#define SPEED_UNIT 1200                                                      //生物生长速度为每1200秒提高xxx点
#define SPEED_UP   5                                                         //特殊地段生物生长速度提高5%
#define REPEAT_RATE 30                                                       //重复采集的几率
#define DEFAULT_TANWEI 7						     //默认摊位数量
#define DEFAULT_SHOP_S "0#0#0#0#0#0#"					     //默认摊位初始化信息
#define DELAY_TIME  7							     //存放在领取中心的物品的期限
#define DAY  24*3600							     //一天的时间，以秒为单位
#define TANWEI_MAX  10							     //最大摊位数 30个 caijie 081117
//#define DAY  1800							     //一天的时间，以秒为单位

inherit LOW_DAEMON;

class area{    //区域
	int id = 0;
	string name = "";
	string nameCn = "";
	int extraYushi = 0;             //特殊地段附加 玉石
	int extraMoney = 0;             //特殊地段附加 金钱
	array(string) slots = ({});     //包含的地段
	string desc = "";               //相关描述
	array(string) speedUpList= ({});//加速生长作物类型列表
}
class slot{    //地段
	int id =0;                   
	string name = ""; 
	string nameCn = "";
	string areaName = "";           //所属区域名
	int lv = 0;                     //地段等级
	string desc = "";               //相关描述
	int homeNum = 0;                //该地段中，每个公寓(flat)中可容纳的家园(home)数量
	int yushi = 0;                  //该地段家园售价(玉石)
	int money = 0;                  //该地段家园售价(黄金)
}
class flat{    //公寓
	int id = 0;
	string name = "";
	string nameCn = "";
	array(string) homes = ({});     //该公寓中的所有家园(home)
}
class home{    //家园
	string homeId = "";             //家园的唯一标示，形式是"xd/qianxuehu/qianxuemen/lei/001"；
	string masterId = "";           //主人的ID
	string masterName = "";         //主人中文名
	int lv = 0;                     //家园等级
	string customName = "";         //主人自定义的家园名称
	string customDesc = "";         //主人自定义的家园描述
	int priceYushi = 0;             //家园售价(玉石)
	int priceMoney = 0;             //家园售价(黄金)
	string areaName = "";           //所属区域(area)名称
	string slotName = "";           //所属地段(slot)名称
	string flatName = "";           //所属公寓(flat)名称
	string flatPath = "";           //公寓(flat)路径  形式是""/gamelib/d/home/xd/qianxuehu/qianxuemen/lei"
	int isUsed = 0;                 //被使用标示
	array(string) allowedUser = ({});                   //允许进入的玩家列表(暂未使用)
	mapping(string:int) rooms = ([]);                   //家园中房间列表
	mapping(string:home) roomMap = ([]);                //暂未使用
	string roomName = "";                               
	string roomNameCn = "";
	mapping (string:mapping(int:object)) lifes = ([]);//记录了所有的"作物"信息
	string door = "";
	string dog = "";
	array(string) userIn = ({});//房间中的玩家
	array(string) functionRoom = ({});//功能房间
	string flyTarget = "";//"飞天小屋"的目的地
	mapping(int:string) shop = ([]); //记录店铺信息 caijie 081106
}
class level{  //家等级
	int lv = 0;
	string desc = "";
	int yushi = 0;
	int money = 0;
	int homeNum = 0;
}
class homeList{//家使用情况
	string name = "";
	string slotName = "";//所属地段
	string flatName = "";//所属公寓
	int isUsed =0;
	string masterId = "";
}
class shopRcmList{//店铺推荐 added by caijie 08/11/18
	string path = "";//家园路径
	string masterId = "";//店主Id
	string masterNameCN = "";//店主中文名
	int rcmTime = 0;	//推荐时间
	int rcmTimeDelay = 0;	//推荐期限
}
private mapping(string:area) areaMap = ([]);                                 // 区域总表
private mapping(string:slot) slotMap = ([]);                                 // 地段总表
private mapping(string:flat) flatMap = ([]);                                 // 公寓总表
private mapping(string:homeList) homeMap = ([]);                             // 家使用情况总表
private mapping(int:level) levelMap = ([]);                                  // 等级总表

private mapping(string:home) homeDetail = ([]);                              //家园详细信息【主人id/home】 (最重要的一个mapping)

private mapping(string:string) masterMap=([]);                               //【房间/主人id】 对应表
private mapping(string:shopRcmList) shopRcmMap=([]);                         //【房间/店铺推荐】 对应表,该表中的店铺为推荐且不过期店铺

private mapping(string:mapping(string:object)) existHome = ([]);             //已经在内存中存在的home列表
private mapping(string:mapping(string:int)) dropMap =([]);                   //养成模块的 掉落清单 格式 (生物名:(掉落物品:掉落几率))
private mapping(string:array(mixed)) infancyMap = ([]);                      //npc贩卖的种子、矿源、小动物

private mapping(int:int) timeDelay = ([1:0,3:3,7:5,]);		//物品出售期限及对应的所得税

void create(){
	werror("============== HOMED start  ===============\n");
	init_level();
	init_area();
	init_slot();
	init_flat();
	init_homeMap();
	init_home();
	init_dropMap();
	init_infancy();
	init_shopRcmMap();
	flush_shopRcm_list(1);
	call_out(store_all_info,TIME_SAPCE);
	werror("==============  HOMED end  ===============\n\n");
}

//读取店铺推荐列表到内存当中 08/11/18
void init_shopRcmMap(){
	string path = "";//家园路径
	string masterId = "";//店主Id
	string masterNameCN = "";//店主中文名
	int rcmTime = 0;	//推荐时间
	int rcmTimeDelay = 0;	//推荐期限
	string strtips = Stdio.read_file(ROOT + SHOPRCM_MAP);              //得到房间等级列表
	array(string) map_tmp = ({});
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== [home] sorry, i did not get the File: gamelib/etc/home/map_shop_recommend =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			shopRcmList shopRcmTmp = shopRcmList();
			sscanf(map_tmp[i],"%s|%s|%s|%d|%d",path,masterId,masterNameCN,rcmTime,rcmTimeDelay);
			shopRcmTmp->path = path;
			shopRcmTmp->masterId = masterId;
			shopRcmTmp->masterNameCN = masterNameCN;
			shopRcmTmp->rcmTime = rcmTime;
			shopRcmTmp->rcmTimeDelay = rcmTimeDelay;
			shopRcmMap[path] = shopRcmTmp;
		}
	}
}
/*
方法描述：初始化【房间等级】列表levelMap
 */
void init_level()
{
	werror("===== [home] start to init level  =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	int lv = 0;
	string desc = "";
	int yushi = 0;
	int money = 0;
	int homeNum = 0;

	strtips = Stdio.read_file(ROOT + LEVEL_MAP);              //得到房间等级列表
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== [home] sorry, i did not get the File: gamelib/etc/home/map_level =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			level levelTmp = level();
			sscanf(map_tmp[i],"%d|%s|%d|%d|%d",lv,desc,yushi,money,homeNum);
			levelTmp->lv = lv;
			levelTmp->desc = desc;
			levelTmp->yushi = yushi;
			levelTmp->money = money;
			levelTmp->homeNum = homeNum;
			levelMap[lv] = levelTmp;
		}
		werror("===== [home] init level completed! =====\n");
	}
	return;
}
/*
方法描述：初始化【区域】列表 areaMap
 */
void init_area()
{
	werror("===== [home] start to init area  =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	int id = 0;
	string areaName = "";
	string areaNameCn = "";
	int extraYushi = 0;
	int extraMoney = 0;
	string slotList = "";
	string desc = "";
	string speedUp = "";
	strtips = Stdio.read_file(ROOT + AREA_MAP);              //得到区域信息
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== [home] sorry, i did not get the File: gamelib/etc/home/area =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			area areaTmp = area();
			sscanf(map_tmp[i],"%d|%s|%s|%d|%d|%s|%s|%s",id,areaName,areaNameCn,extraYushi,extraMoney,slotList,desc,speedUp);
			areaTmp->id = id;
			areaTmp->name = areaName;
			areaTmp->nameCn = areaNameCn;
			areaTmp->extraYushi = extraYushi;
			areaTmp->extraMoney = extraMoney;
			areaTmp->slots = slotList/","-({""});;
			areaTmp->desc = desc;
			areaTmp->speedUpList  = speedUp/","-({""});
			areaMap[areaName] = areaTmp;
		}
		werror("===== [home] init area completed! =====\n");
	}
	return;
}

/*
方法描述：初始化【地段】列表 slotMap
 */
void init_slot()
{
	werror("===== [home] start to init slot =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	int id = 0;
	string areaName = "";
	string name = "";
	string nameCn = "";
	int lv = 0;
	string desc = "";
	int homeNum = 0;
	int yushi = 0;
	int money = 0;

	strtips = Stdio.read_file(ROOT + SLOT_MAP);              //得到地段信息
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_slot =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++){
			slot slotTmp = slot();
			level levelTmp = level();
			area areaTmp = area();

			sscanf(map_tmp[i],"%d|%s|%s|%d|%s",id,name,nameCn,lv,areaName);
			slotTmp->id = id;
			slotTmp->name = name;
			slotTmp->nameCn = nameCn;
			slotTmp->lv = lv;
			slotTmp->areaName = areaName;
			levelTmp = levelMap[lv];      //地段等级
			areaTmp = areaMap[areaName];  //地段所在区域
			slotTmp->desc = levelTmp->desc;
			slotTmp->homeNum = levelTmp->homeNum;
			slotTmp->yushi = levelTmp->yushi + areaTmp->extraYushi;
			slotTmp->money = levelTmp->money + areaTmp->extraMoney;
                        slotMap[name] = slotTmp;
		}
	}
	werror("===== [home] init slot completed! =====\n");
}

/*
方法描述：初始化【公寓】列表 flatMap
 */
void init_flat()
{
	werror("===== [home] start to init flat =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	int id = 0;
	string name = "";
	string nameCn = "";

	strtips = Stdio.read_file(ROOT + FLAT_MAP);              //得到公寓信息
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_flat =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			flat flatTmp = flat();
			sscanf(map_tmp[i],"%d|%s|%s",id,name,nameCn);
			flatTmp->id = id;
			flatTmp->name = name;
			flatTmp->nameCn = nameCn;
                        flatMap[name] = flatTmp;
		}
	}
	werror("===== [home] init flat completed! =====\n");
}
/*
方法描述：初始化【家园占用情况】列表 homeMap
 */
void init_homeMap()
{
	werror("===== [home] start to init homeList =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	string name = "";
	string slotName = "";
	string flatName = "";
	int isUsed = 0;	
	string masterId = "";

	strtips = Stdio.read_file(ROOT + ROOM_MAP);              //得到房间使用信息列表
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_home =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			homeList homeListTmp = homeList();
			sscanf(map_tmp[i],"%s|%s|%s|%d|%s",name,slotName,flatName,isUsed,masterId);
			homeListTmp->name = name;
			homeListTmp->isUsed = isUsed;
			homeListTmp->slotName = slotName;
			homeListTmp->flatName = flatName;
			if(isUsed) {
				homeListTmp->masterId = masterId;
				masterMap[name] = masterId;                 //【房间/主人id】 对应表
			}
			homeMap[name] = homeListTmp;
		}
	}
	werror("===== [home] init homeList completed! =====\n");
}

/*
方法描述：初始化【养成模块掉落】列表 dropMap
 */
void init_dropMap()
{
	werror("===== [home] start to init dropMap =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	string lifeName = "";
	string goods = "";
	string goodsName = "";
	int dropRate = 0;
	string goodsStr = "";
	array(string) goodsArr = ({});
	
	strtips = Stdio.read_file(ROOT + DROP_MAP);              //得到掉落信息
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_drop =====\n");

	int num = sizeof(map_tmp);
	if(num>0)
	{
		for(int i=1;i<num;i++)
		{
			sscanf(map_tmp[i],"%s,%s",lifeName,goodsStr);
			goodsArr = goodsStr/"|"-({""});
			array(string) tmp = lifeName/"/"-({""});
			lifeName = tmp[1];

			mapping(string:int) goodsMap = ([]);
			for(int i=0;i<sizeof(goodsArr);i++)
			{
				goods = goodsArr[i];
				sscanf(goods,"%s %d",goodsName,dropRate);
				goodsMap[goodsName]=dropRate;
			}
			dropMap[lifeName] = goodsMap;
		}
	}
	werror("===== [home] init dropMap completed! =====\n");
}

/*
方法描述：初始化【种子】列表 infancyMap  该列表主要是提供给 "种子购买"模块使用
 */
void init_infancy()
{
	werror("===== [home] start to init infancy =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	string infancyPath = "";
	string infancyType = "";
	string infancyName = "";
	int yushi = 0;
	int money = 0;
	
	strtips = Stdio.read_file(ROOT + INFANCY_MAP);              //得到掉落信息
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_infancy =====\n");

	int num = sizeof(map_tmp);
	if(num>0)
	{
		array tmp = ({});
		for(int i=1;i<num;i++)
		{
			array infos = ({"","",0,0});
			sscanf(map_tmp[i],"%s,%s,%d,%d",infancyPath,infancyName,yushi,money);
			tmp = infancyPath/"/";
			infancyType = tmp[0];//得到物品种类
			infos[0] = infancyPath;//物品路径
			infos[1] = infancyType;//物品种类
			infos[2] = yushi;//所需玉石
			infos[3] = money;//所需金钱
			infancyMap[infancyName] = infos;
		}
	}
	werror("===== [home] init map_infancy completed! =====\n");
}
/*
方法描述：初始化【家园详细】列表 detailHome
        这是最重要的一个mapping，其中记录的所有home的详细信息。
 */
void init_home()
{
	werror("===== [home] start to init home!  =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	
	string homeId = "";
	string masterId = "";
	string masterName = "";
	string customName = "";
	string customDesc = "";
	string allowedUserTmp = "";
	string ore = "";//矿物
	string animal = "";//动物
	string plant = "";//植物
	string door = "";//门信息
	string dog = "";//看门狗信息
	string userInTmp = "";//home中的玩家	
	string functionRoom = "";//已经有的功能房间
	string flyTarget = "";//"飞天小屋"的目的地
	string shop = "";     //店铺信息 caijie 081106
	strtips = Stdio.read_file(ROOT + HOME_INFO);              //得到房间信息
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/detail_home =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		string areaName = "";
		string slotName = "";
		string flatName = "";
		for(int i=1;i<num;i++)
		{
			mapping(string:mapping(int:object)) lifes = ([]);
			home homeTmp = home();                                //初始化一个home对象
			homeList homeListTmp = homeList();
			flat flatTmp = flat();
			slot slotTmp = slot();
			area areaTmp = area();
			//房间名|主人ID|主人名|房间名|房间描述|允许列表|矿石|动物|植物|门|狗|房间中玩家|功能房间|飞天小屋的目的地|私家小店 
			sscanf(map_tmp[i],"%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|",homeId,masterId,masterName,customName,customDesc,allowedUserTmp,ore,animal,plant,door,dog,userInTmp,functionRoom,flyTarget,shop);
			homeTmp->homeId = homeId;
			homeTmp->masterId = masterId;
			homeTmp->masterName = masterName;
			homeTmp->customName = customName;
			homeTmp->customDesc = customDesc;
			homeTmp->allowedUser = allowedUserTmp/"," - ({""});
			homeTmp->userIn = userInTmp/"," - ({""});
			
			lifes["ore"]= init_lifes(ore,"ore");               //初始化矿物
			lifes["animal"]= init_lifes(animal,"animal");      //初始化动物
			lifes["plant"]= init_lifes(plant,"plant");         //初始化植物
			homeTmp->lifes = lifes;
			
			homeTmp->door = door;//门信息
			homeTmp->dog = dog;//看门狗信息
			homeTmp->functionRoom = functionRoom/"," - ({""});//功能房间
			homeTmp->flyTarget = flyTarget;
			homeTmp->shop = init_shop(shop);
			
			//以下的属性值通过"home-flat-slot-area"相互关联得到，在detail_home中并没有以下这些值
			homeListTmp = homeMap[homeId];             //通过homeId得到homeList对象，该对象包括home的基本信息
			homeTmp->flatName = homeListTmp->flatName; //该home对应的flat
                        slotName = homeListTmp->slotName;          //该home对应的slot
			homeTmp->slotName = slotName;

			slotTmp = slotMap[slotName];               //得到名字为slotName的slot对象
			homeTmp->areaName = slotTmp->areaName;     //通过slot对象得到该home对应的area
			homeTmp->priceYushi = slotTmp->yushi;      //通过slot对象得到该home的价格（玉）
			homeTmp->priceMoney = slotTmp->money;      //通过slot对象得到该home的价格（金）
			homeTmp->lv = slotTmp->lv;                 //通过slot对象得到该home的等级
			homeDetail[masterId] = homeTmp;
		}
		werror("===== [home] init home completed! =====\n");
	}
}

/*
描述：初始化一个家园(home)中，某一类生物(植物、动物、矿物)      
参数：lifes 生物名称
      lifeType 生物类型
返回: mapping(int:object) 所有生物对象组成的mapping, int是同类生物的排列序号
 */
mapping(int:object) init_lifes(string lifes,string lifeType)
{
	mapping(int:object) re = ([]);
	array(string) lifeList = lifes/",";
	lifeList = lifeList - ({""});
	int num = sizeof(lifeList);
	int need_life = 0;                 //成熟还需要的生命值
	int speed = 0;                     //生长速度
	string lifeName = "";
	int deadTime = 0;                  //成熟的时间
	for(int i=0;i<num;i++)
	{
		sscanf(lifeList[i],"%s/%d/%d/",lifeName,deadTime,speed);
		if(lifeName!="0")
		{
			string new_life_path = LIFE_PATH+"/"+lifeType+"/"+lifeName;         //"生物"文件路径
			object life = 0;
				mixed err =catch{
					life = clone(new_life_path);                        //得到这个生物
				};
			if(!err&& life){
				if(time()>=deadTime){ //如果当前时间已经晚于成熟时间，则生物的当前生命 = 生物成熟时的生命
					life->set_current_life(life->query_final_life()); 
				}
				else
				{
					need_life = speed*(deadTime-time())/SPEED_UNIT;     //计算生命成熟还需要多少点生命
					life->set_current_life(life->query_final_life()-need_life);//设置生物的当前生命
				}
				life->set_grow_speed(speed);       //设置生物的生长速度
				life->set_dead_time(deadTime);     //设置生物的成熟时间
				re[i] = life;
			}
			else
			{
				re[i] = 0;
			}
		}
		else{
			re[i] = 0;
		}
	}
	return re;
}

/*
   描述：显示一个slot中所有的flat
   变量：slotName   slot的名称
   返回：re 带链接的所有flat的列表
 */
string display_flats(string slotName)
{
	string re = "";
	slot st = slotMap[slotName];                   //得到需要的地段(slot)对象
	string slotNameCn = st->nameCn;
	re +="  请选择你要进入的四合院:\n";
	array(string) flatsName = indices(flatMap);    //所有的公寓(flat)名称  风/雷/露/霜/雾/霰/雪
	flatsName = sort(flatsName);
	int num = sizeof(flatsName);
	string tmpName = "";
	for(int i=0;i<num-1;i++)
	{
		tmpName = flatsName[i];
		re += "["+slotNameCn+"-" + flatMap[tmpName]->nameCn +":home_display_home "+ slotName +" "+tmpName +" 0]\n";
	}
	return re;
}
/*
描述：显示一个flat中所有的home          (该方法被home_display_home.pike所调用)
变量：slotName  该flat所在slot的名称
      flatName  flat的名称
      backFlag  是否是从某个home中返回到该页面的标识
返回：re 带链接的所有home的列表
 */
string display_homes(string slotName,string flatName,int backFlag)
{
	string re = "";
	object me = this_player();
	slot st = slotMap[slotName];           //当前公寓(flat)所在地段(slot)对象
	string areaName = st->areaName;        //当前公寓(flat)所在区域(area)名
	int homeNum = st->homeNum;             //当前公寓(flat)中的房间数
	string homeName = "";
	string homePath = GAME_NAME_S + "/" + areaName +"/"+ slotName +"/"+ flatName +"/"; //当前公寓的路径
	re += " 安置在这里的家有:\n";
	for(int i=1;i<=homeNum;i++)
	{
		homeName = homePath + (string)i;
		homeList rl = homeMap[homeName];              //home是否被使用的列表
		if(rl->isUsed){  //如果已被使用，添加进入链接
			home ro = homeDetail[rl->masterId];   //该home的详细信息
			re += "【" + ro->customName + "】(" + ro->masterName + "的家)";
			re += " [进入:home_view "+ homeName +"]\n";
		}
		else//未被使用
		{
			re += "【" + i +"号房】(空闲)\n";
		}
	}
	if(backFlag)//玩家是从某个房间中返回到这个页面的，则要做相关处理，主要是清除玩家在原home中的相关记录
	{
		clear_user(me); //清除相关记录
		//将玩家move到对应的slot中
		string slotPath = ROOT + "/gamelib/d/home/" +GAME_NAME_S + "/" + areaName +"/"+ slotName;
		me->move(slotPath); 
	}
	return re;
}

/* 描述：清除玩家正处于某个home中的相关信息
   参数:
   返回:
*/
void clear_user(object player)
{
	object env = environment(this_player());//当前所在房间
	string areaName = env->query_areaName();
	string slotName = env->query_slotName();
	//任务1、将玩家身上的inhome_pos设置为"";
	player->inhome_pos="";
	//任务2、将玩家从home的userIn字段中去掉；
	del_user(player->query_name());
}

//判断某个home中是否没有在线的玩家
int is_cleared(string homeName)
{
	string masterId = query_masterId_by_path(homeName);
	home he = homeDetail[masterId];
	array(string) userIn = he->userIn;
	if(sizeof(userIn)==0)//如果列表为空，则说明home中没有人
	{
		return 1;
	}
	else
	{
		foreach(userIn,string user)
		{
			if(find_player(user)) //只要找到一个在线的玩家，则说明home中有人
			return 0;
		}
		return 1;//如果列表中的玩家都不在线，也认为home中没有人
	}
}
/*
   方法描述：通过主人ID，得到家园名 (玩家自定义的名称)
   变量：masterId  家园主人的ID
   返回值：home的玩家自定义名称  
 */
string query_homeName_by_masterId(string masterId)
{
	home he = homeDetail[masterId];
	return he->customName;
}

/*
方法描述：初始化home的所有房间文件
变量：path home对应的path(唯一标识)
返回值：home中的第一个房间文件
 */
object query_home_by_path(string path)
{
	string masterId = query_masterId_by_path(path);
	return query_home_by_masterId(masterId);
}

/*
方法描述：初始化某个home中所有房间文件
变量：masterId   home主人Id
返回值：home中的第一个房间文件(door)
 */
object query_home_by_masterId(string masterId)
{
	if (homeDetail[masterId])                                 //该房间已经被使用(防止home变卖之后，玩家从四合院进入时出错)
	{
		home he = homeDetail[masterId];                   //home的信息 
		if(!existHome[masterId])                          //内存中没有该对象,则初始化这个home的所有信息
		{
			int num = sizeof(ROOMS);                  //每个home中可能包括多个房间
			for(int i=0;i<num;i++){
				object room; 
				string new_room_path = ROOM_PATH+ROOMS[i];//房间文件路径
				mixed err = catch{
					room=clone(new_room_path);
				};
				if(!err && room){
					room->set_roomName(ROOMS[i]);
					room->set_roomNameCn(ROOMS_CN[i]); 
					init_room(room,he);                        //初始化每个房间中的信息
					string roomName = room->query_name();
					if(i==0)
						existHome[masterId] = ([roomName:room]);
					else
						existHome[masterId] += ([roomName:room]);
				}
			}
			
			int f_num = sizeof(FUNCTION_ROOMS);                  //每个home中可能包括多个功能房间
			for(int fi=0;fi<f_num;fi++){
				object f_room; 
				string new_f_room_path = ROOM_PATH+"function/"+FUNCTION_ROOMS[fi];//房间文件路径
				mixed err = catch{
					f_room=clone(new_f_room_path);
				};
				if(!err && f_room){
					f_room->set_roomName(FUNCTION_ROOMS[fi]);
					f_room->set_roomNameCn(FUNCTION_ROOMS_CN[fi]); 
					init_room(f_room,he);                        //初始化每个房间中的信息
					string roomName = f_room->query_name();
					existHome[masterId] += ([roomName:f_room]);
				}
			}

			int s_num = sizeof(SHOP);
			for(int si=0;si<s_num;si++){
				object shop;
				mixed err = catch{
					shop = clone(ROOM_PATH+"shop/"+SHOP[si]);
				};
				if(!err && shop){
					shop->set_roomName(SHOP[si]);
					shop->set_roomNameCn(SHOP_CN[si]);
					init_room(shop,he);
					string roomName = shop->query_name();
					existHome[masterId] += ([roomName:shop]);
				}
			}
		}
		mapping(string:object) allRooms = existHome[masterId];
		return allRooms["door"];//返回door这个房间
	}
	else
		return 0;
}
//得到家园中的某个房间对象
object query_room_by_masterId(string masterId,string room_name)
{
	if (homeDetail[masterId])                                 //该房间已经被使用(防止home变卖之后，玩家从四合院进入时出错)
	{
		home he = homeDetail[masterId];                   //home的信息 
		if(!existHome[masterId])                          //内存中没有该对象
		{
			int num = sizeof(ROOMS);                  //每个home中可能包括多个房间
			for(int i=0;i<num;i++){
				object room; 
				string new_room_path = ROOM_PATH+ROOMS[i];//房间文件路径
				mixed err = catch{
					room=clone(new_room_path);
				};
				if(!err && room){
					room->set_roomName(ROOMS[i]);
					room->set_roomNameCn(ROOMS_CN[i]); 
					init_room(room,he);                        //初始化每个房间中的信息
					string roomName = room->query_name();
					if(i==0)
						existHome[masterId] = ([roomName:room]);
					else
						existHome[masterId] += ([roomName:room]);
				}
			}
			int f_num = sizeof(FUNCTION_ROOMS);                  //每个home中可能包括多个功能房间
			for(int fi=0;fi<f_num;fi++){
				object f_room; 
				string new_f_room_path = ROOM_PATH+"function/"+FUNCTION_ROOMS[fi];//房间文件路径
				mixed err = catch{
					f_room=clone(new_f_room_path);
				};
				if(!err && f_room){
					f_room->set_roomName(FUNCTION_ROOMS[fi]);
					f_room->set_roomNameCn(FUNCTION_ROOMS_CN[fi]); 
					init_room(f_room,he);                        //初始化每个房间中的信息
					string roomName = f_room->query_name();
					existHome[masterId] += ([roomName:f_room]);
				}
			}

			int s_num = sizeof(SHOP);
			for(int si=0;si<s_num;si++){
				object shop;
				mixed err = catch{
					shop = clone(ROOM_PATH+"shop/"+SHOP[si]);
				};
				if(!err && shop){
					shop->set_roomName(SHOP[si]);
					shop->set_roomNameCn(SHOP_CN[si]);
					init_room(shop,he);
					string roomName = shop->query_name();
					existHome[masterId] += ([roomName:shop]);
				}
			}
		}
		mapping(string:object) allRooms = existHome[masterId];
		return allRooms[room_name];//返回room_name这个房间
	}
	else
		return 0;
}
//初始化家园中的房间
void init_room(object room,home he)
{
	room->set_room_type("home");
	room->name_cn = he->customName + "("+he->masterName+"的家)";
	room->set_flatPath(query_flatPath(he));
	room->set_homeId(he->homeId);
	room->set_masterId(he->masterId);
	room->set_masterName(he->masterName);
	room->set_customName(he->customName);
	room->set_customDesc(he->customDesc);
	room->set_allowedUser(he->allowedUser);
	room->set_priceYushi(he->priceYushi);
	room->set_priceMoney(he->priceMoney);
	room->set_areaName(he->areaName);
	room->set_slotName(he->slotName);
	room->set_flatName(he->flatName);
	room->set_lifes(he->lifes);
	room->set_door(he->door);
	room->set_dog(he->dog);
	room->set_userIn(he->userIn);
	room->set_functionRoom(he->functionRoom);
	room->set_flyTarget(he->flyTarget);
	room->set_homeLv(he->lv);
	/*
	if(is_have_dog(room)&&room->query_name()=="main"){
		init_dog(room);
	}
	mapping(string:mapping(int:object)) allLifes = he->lifes;
	  mapping(int:object) lifes = allLifes["ore"];
	  for(int i=0;i<sizeof(lifes);i++){
	  object ob = lifes[1];
	  if(ob&&ob!=0)
	  {
	  ob->move(room);
	  }
	  }*/
}
//初始化狗
void init_dog(object room)
{
	if(is_have_dog(room)){
		string st = room->query_dog();
		array tmp = st/",";
		object dog = clone(NPC_PATH+tmp[1]);
		if((int)tmp[2]<45000){
			dog->set_base_life(45250);
		}
		else
			dog->set_base_life((int)tmp[2]);
		dog->set_life(dog->query_life_max());
		dog->set_str((int)tmp[3]);
		dog->set_think((int)tmp[4]);
		dog->set_dex((int)tmp[5]);
		dog->set_feed_time((int)tmp[6]);
		dog->move(room);
	}
}
//返回某个房间。
object query_room(string roomName,string homeId)
{
	object env = environment(this_player());//当前所在房间
	if(env->query_room_type() == "home")//防止玩家使用"返回"按钮带来的错误
	{
		if(env->query_homeId() == homeId)//防止玩家通过"返回"按钮返回到其他玩家的房间
		{
			string path = env->query_homeId();
			string masterId = query_masterId_by_path(path);
			mapping(string:object) allRooms = existHome[masterId];
			//werror("===== masterId = "+ masterId +"=========\n");
			if(allRooms){
			//	werror("===== i am in =========\n");
				return allRooms[roomName];//返回需要的房间
			}
			else
				return 0;
		}
		else
			return 0;
	}
	else
		return 0;
}


/*
   方法描述：通过home的路径，得到主人的Id
   变量：path  home的路径
   返回值：string home主人Id
 */
string query_masterId_by_path(string path)
{
	string re = "";
	homeList rl = homeMap[path];
	if(rl)
		re = rl->masterId;
	return re;
}


/*
   方法描述：area中的banner
   变量：areaName  该area的名称
   返回值：string banner
 */
string banner_area(string areaName)
{
	string re = "";
	area aa = areaMap[areaName];
	re += aa->nameCn + "地皮选择\n\n";
	re += "[地质特性:home_query_area_desc "+ areaName +"]\n";
	return re;
}
/*
   方法描述：slot中的banner
   变量：slotName  该flat所在slot的名称
   返回值：string banner
 */
string banner_slot(string slotName)
{
	string re = "";
	slot st = slotMap[slotName];
	re += "修建在这里的家，" + st->desc + "\n\n";
	return re;
}
/*
   方法描述：flat中的banner
   变量：slotName  该flat所在slot的名称
   flatName  flat的名称
   返回值：string banner
 */
string banner_flat(string slotName,string flatName)
{
	string re = "";
	slot st = slotMap[slotName];
	flat ft = flatMap[flatName];
	re += st->nameCn + "-" + ft->nameCn+ "\n\n";
	return re;
}
/*
   方法描述：得到某个area的desc
   变量：areaName  area名称
   返回值：string  area对应的desc
 */
string query_area_desc(string areaName)
{
	area aa = areaMap[areaName];
	return aa->desc;
}
/*
   方法描述：得到某个slot的path
   变量：slotName  slot名称
   返回值：string  该slot对应的文件路径
 */
string query_slotPath(string slotName)
{
	slot st = slot();
	st = slotMap[slotName];
	return "home/"+ GAME_NAME_S +"/"+ st->areaName +"/"+ slotName;
}
/*
   方法描述：得到某个home对应的flatPath
   变量：he  home对象
   返回值：string  该home对应的flatPath
 */
string query_flatPath(home he)
{
	string areaName = he->areaName;
	string slotName = he->slotName;
	string flatName = he->flatName;
	return "/gamelib/d/home/"+GAME_NAME_S+"/"+areaName+"/"+slotName+"/"+flatName;
}
/*
   方法描述：列出某个area中所有的slot，用于"地皮购买"功能模块
   变量：areaName  area名称
   返回值：string  area对应的slot的名称及相关链接
 */
string query_slot_for_sale(string areaName)
{
	string re = "";
	area aa = areaMap[areaName];
	array(string) slots = aa->slots; 
	string slotName = "";
	int num = sizeof(slots);
	for(int i=0;i<num;i++)
	{
		slotName = slots[i];
		slot st = slotMap[slotName];
		re += "["+ st->nameCn +":"+ "home_purchase_flat_list "+ slotName +"]\n";
	}
	return re;
}
/*
   方法描述：列出某个solt中所有的flat，用于"地皮购买"功能模块
   变量：slotName  solt名称
   返回值：string  solt对应的flat的名称及相关链接
 */
string query_flat_for_sale(string slotName)
{
	string re = "";
	slot st = slotMap[slotName];
	string slotNameCn = st->nameCn;
	re += "本地段家园的等级为:"+ st->lv +"级\n";
	re += "本地段的价格是："+ YUSHID->get_yushi_for_desc(st->yushi)+ " "+st->money+"黄金\n";
	re +=" 请选择你喜爱的四合院:\n";
	array(string) flatsName = indices(flatMap);
	flatsName = sort(flatsName);
	int num = sizeof(flatsName);
	string tmpName = "";
	for(int i=0;i<num-1;i++)
	{
		tmpName = flatsName[i];
		re += "["+slotNameCn+"-" + flatMap[tmpName]->nameCn +":home_purchase_home_list "+ slotName +" "+tmpName +"]\n";
	}
	return re;
}
/*
   方法描述：列出某个slot中一个flat包含的所有home，用于"地皮购买"功能模块
   变量：slotName  slot名称
   flatName  flat名称
   返回值：string  flat对应的home的名称及相关链接
 */
string query_home_for_sale(string slotName,string flatName)
{
	string re = "";
	slot st = slotMap[slotName];
	string areaName = st->areaName;
	int homeNum = st->homeNum;
	string homeName = "";
	string homePath = GAME_NAME_S + "/" + areaName +"/"+ slotName +"/"+ flatName +"/"; 
	re += " 安置在这里的家有:\n";
	for(int i=1;i<=homeNum;i++)
	{
		homeName = homePath + (string)i;
		homeList rl = homeMap[homeName];
		if(rl->isUsed){
			home ro = homeDetail[rl->masterId];
			re += "【" + ro->customName + "】(" + ro->masterName + "的家)\n";
		}
		else
		{
			re += "【" + i +"号房】(空闲)";
			re += " [购买:home_purchase_confirm "+ slotName +" "+flatName +" "+ homeName +"]\n";
		}
	}
	return re;
}
/*
   方法描述：玩家购买home成功之后的相关操作
   变量：homeName home名称
   faltName
   slotName
 */
void build_new_home(string homeName,string flatName,string slotName)
{
	int re = 0;
	object player = this_player();                                               //主人
	flat ft = flatMap[flatName];                                                 //home对应的flat
	slot st = slotMap[slotName];                                                 //home对应的slot
	//homeDetail
	home he = home();                                                            //家详细信息
	he->homeId = homeName;
	he->masterId = player->query_name();                                               //主人id
	he->masterName = player->query_name_cn();                                          //主人姓名
	he->lv = st->lv;                                                                   //房间等级
	he->customName = player->query_name_cn()+"之家";                                   //自定义房间名
	he->customDesc = "这是"+player->query_name_cn()+"的家";                            //自定义房间描述
	he->priceYushi = st->yushi;                                                        //房间价格-玉石
	he->priceMoney = st->money;                                                        //房间价格-金钱
	he->areaName = st->areaName;                                                       //所在area名称
	he->slotName = st->name;                                                           //所在slot名称
	he->flatName = ft->name;                                                           //所在flat名称
	he->flatPath = "";                                                                 //所在flat路径
	he->isUsed = 1;                                                                    //使用标识
	he->allowedUser = ({});                                                            //允许进入的玩家id列表

	mapping(string:mapping(int:object)) lifes = ([]);                                  //家园中的"生物"
	mapping(int:object) tmp_ore = ([]);
	mapping(int:object) tmp_plant = ([]);
	mapping(int:object) tmp_animal = ([]);
	int num = st->lv;                                                                  //家的等级决定了可以种植几种"生物"
	for(int i=0;i<num;i++)                                                             //得到空地
	{
		tmp_ore[i]=0;
		tmp_plant[i]=0;
		tmp_animal[i]=0;
	}
	lifes["ore"]= tmp_ore;                                                             //初始化矿物
	lifes["animal"]= tmp_plant;                                                        //初始化动物
	lifes["plant"]= tmp_animal;                                                        //初始化植物
	he->lifes = lifes;                                                                 //生物设置 done

	he->door = "";                                                                     //门信息
	he->dog = "";                                                                      //看门狗信息


	homeDetail[player->query_name()] = he;                                            
	//homeList
	homeList hl = homeMap[homeName];                                                   //家使用情况
	hl->isUsed = 1;
	hl->masterId = player->query_name();
	homeMap[homeName] = hl;

	//masterMap
	masterMap[homeName] = player->query_name();                                        //【房间/主人id】 对应表
	player->set_home_path(homeName);                                                   //改变玩家身上的home_path 字段
}
/*
   方法描述：通过slot名得到其对应的area名
   变量：slotName  slot名称
   返回值：string  flat对应的area的名称
 */
string query_area_by_slot(string slotName)
{
	return slotMap[slotName]->areaName;
}
/*
   方法描述：通过slot名得到其对应所需玉石数目
   变量：slotName  slot名称
   返回值：int  flat对应的玉石数目
 */
int query_yushi_by_slot(string slotName){
	return slotMap[slotName]->yushi;
}
/*
   方法描述：通过slot名得到其对应所需金钱数目
   变量：slotName  slot名称
   返回值：int  flat对应的金钱数目
 */
int query_money_by_slot(string slotName)
{
	return slotMap[slotName]->money;
}

//判断某个玩家是否已经有房产
int if_have_home(string playerName)
{
	string tmp = search(masterMap,playerName);
	if(tmp&&tmp!="")
		return 1;
	return 0;
}


//判断、提示房屋变卖的相关信息
string query_sell_info()
{
	object me = this_player();
	string re = "";
	home he = homeDetail[me->query_name()];
	if(he){
		float yushi_f = he->priceYushi - he->priceYushi*DEPR_FEE;
		float money_f = he->priceMoney - he->priceMoney*DEPR_FEE;
		int yushi = (int) yushi_f;
		int money = (int) money_f;
		slot st = slotMap[he->slotName];
		string slotNameCn = st->nameCn;
		re += "\n 确认要变卖位于"+ slotNameCn +"的地产吗？\n";
		re += "变卖将会得到"+ YUSHID->get_yushi_for_desc(yushi)+" "+ money +"金\n\n";
		re += "[确认:home_sell_confirm "+he->homeId+ " "+ yushi + " " + money +"]\n";
		re += "[取消:look]\n";
	}
	else
		re += "你还没有地产，空手套白狼在这里可行不通，如有疑问，请与客服联系\n";
	return re;
}

//确认"变卖"房产后的相关操作 
string sell_confirm(string homeName,int yushi,int money)
{
	string re = "";
	object me = this_player();
	if(if_have_home(me->query_name()))//防止用户刷点
	{
		mixed tmp = m_delete(homeDetail,me->query_name());//删除房间的详细信息
		mixed tmp2 = m_delete(masterMap,homeName);//删除masterMap中对应的信息
		mixed tmp3 = m_delete(existHome,me->query_name());//删除existHome中对应的信息
		mixed tmp4 = m_delete(shopRcmMap,homeName);   //删除shopRcmMap中对应的信息
		homeList hl = homeMap[homeName];
		if(hl->isUsed){
			hl->isUsed = 0;//修改map_home中的信息，在内存中对应的是homeList这个Mapping。
			hl->masterId = "";
		}

		homeMap[homeName] = hl;
		me->set_home_path(""); //改变玩家身上的home_path字段
		//支付玉石和钱
		int  rt = YUSHID->give_yushi(me,yushi);
		if(rt)
		{
			re += "你得到了:\n";
			re += YUSHID->get_yushi_for_desc(yushi);
			me->account += money*100;
			re += "和"+money+"金\n";
			string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_sell]["+homeName+"][][1][-"+yushi+"][0]\n";
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);  

		}
		else{
			re = "系统好像有点忙，如果你没有得到玉石和金钱，请与客服联系\n";
		}
	}
	else
	{
		re = "你现在没有地产。\n";

	}
	//支付结束
	return re;	
}



/*
   方法描述：判断玩家是否是房间的主人
   变量：player    需要查询的玩家
   homeName  房间名
   返回值：
   0 不是房间主人
   1 是房间主人
 */
int is_master(string homeName)
{
	object me = this_player();
	if(me->query_name() == masterMap[homeName])
		return 1;
	return 0;
}

//得到main房间中通向其房间的链接列表
string query_room_links(string homeName)
{
	object env = environment(this_player());//当前所在房间
	string nowRoomName = env->query_name();
	string re = "";
	for(int i =0;i<5;i++)
	{
		string roomName = ROOMS[i];
		if(roomName != nowRoomName ){
			re += "===>["+ ROOMS_CN[i] +":home_move "+ROOMS[i]+"]<===\n";
		}
	}
	if(is_master(env->homeId))
			re += "==>[神秘禁地:home_function_room_list]<==\n";
	return re; 
}
//得到功能房间的链接列表
string query_function_room_links()
{
	string re = "\n你可以前往的位置有:\n";
	object env = environment(this_player());//当前所在房间
	if(env->query_room_type() =="home")
	{
		int num = sizeof(FUNCTION_ROOMS);
		int myRoomNum = sizeof(env->query_functionRoom());
		if(myRoomNum){
			for(int i =0;i<num;i++)
			{
				string roomName = FUNCTION_ROOMS[i];
				if(if_have_function_room(roomName))
				re += "===【["+ FUNCTION_ROOMS_CN[i] +":home_move "+ FUNCTION_ROOMS[i]+"]】===\n";
			}
		}
		else
		{
			re = "这里没有任何特殊的功能房间。\n";
			if(is_master(env->query_homeId()))
			{
				re += "[添加功能房间:home_functionroom_buy_list]";
			}
		}
	}
	else
		re = "\n你不在正确的位置。\n";
	return re; 
}
//可供购买的功能房间列表
string query_function_room_for_sale(string kind){
	string re = "请选择你要添加的房间:\n";
	object me = this_player();
	object env = environment(this_player());//当前所在房间
	string roomPath = env->query_homeId();
	re += "【注意：同一类型房间获得的属性加成不能叠加，请慎重选择】\n\n";
	re += get_kind_links(kind,"home_functionroom_buy_list");
	if(env->query_room_type() =="home"&&is_master(roomPath))
	{
		int num = sizeof(FUNCTION_ROOMS);
		int flag = 0;
		for(int i =0;i<num;i++)
		{
			string roomName = FUNCTION_ROOMS[i];
			if(!if_have_function_room(roomName)){ //如果该玩家家中没有这个功能房间，则显示在添加列表中
				object f_room = (object)(ROOM_PATH+"function/"+FUNCTION_ROOMS[i]);
				if(f_room->query_buff_kind()==kind){
					re += "["+ FUNCTION_ROOMS_CN[i] +":home_functionroom_buy_detail "+ FUNCTION_ROOMS[i]+"](需要"+f_room->query_level_limit()+"级家园)\n";
					flag ++;
				}
			}
		}
		if(!flag)
		re += "你已经添加了该类属性的所有房间，我们很快将会推出更多的新房间，敬请期待。\n";
	}
	else
		re = "你不在正确的位置。\n";
	return re;
}
//判断家园中是否有名为roomName的功能房间
int if_have_function_room(string roomName)
{
	int re = 0;
	object env = environment(this_player());//当前所在房间
	array(string) allFuncRoom = env->query_functionRoom();
	for(int i=0;i<sizeof(allFuncRoom);i++){
		if(allFuncRoom[i] == roomName)
		re = 1;
	}
	return re;
}
//添加功能房间
int add_function_room(string roomName)
{
	int re = 0;
	object room = environment(this_player());                  //当前所在房间
	string masterId = room->query_masterId();                  //房间主人ID
	array(string) functionRooms = room->query_functionRoom(); //已有的功能房间
	
	int num = sizeof(functionRooms);
	if(search(functionRooms,roomName) == -1)                        //如果该home中没有这个需要添加的room
	{
		//任务1、修改这个home中每个room的functionRooms属性
		mapping allRooms = existHome[masterId];            //得到这个home中的所有room
		if(allRooms){
			foreach(sort(indices(allRooms)),string room)    //修复所有room的functionRooms属性
			{
				object tmp = allRooms[room];
				tmp->functionRoom+=({roomName});
			}
			//任务2、修改homeDetail中相关的信息
			home he = homeDetail[masterId];
			he->functionRoom += ({roomName});
			//任务3、如果添加的是"飞天小屋"，则要赠送一颗"传送神符"。
			if(roomName =="feitianxiaowu")
			{

				string path = ITEM_PATH + "/home/others/chuansongshenfu";
				object chuansongshenfu = 0;
				mixed err = catch{
					chuansongshenfu = clone(path);
				};
				if(!err && chuansongshenfu){
					chuansongshenfu->move_player(this_player()->query_name());           //得到物品
				}
			}
			return 1;//添加成功
		}
		else
		{
			return 0;//出错了，请与客服联系（在这里，就会出现扣了玉，但是没加上房间的情况，这种可能一般是不会出现的）
		}
	}
	else{
		return 0;//已经有该功能房间，不用重复添加
	}
}

string set_fly_target(object me,object room)
{
	string re = "";
	string masterId = me->query_name();
	string roomName = file_name(room);
	if(if_have_home(me->query_name()))
	{
		if(ITEMSD->if_have_enough(me,"chuansongshenfu"))
		{
			mapping allRooms = existHome[masterId];            //得到这个home中的所有room
			if(allRooms){
				foreach(sort(indices(allRooms)),string ro)    //修复所有room的fly_target属性
				{
					object tmp = allRooms[ro];
					tmp->flyTarget = roomName;
				}
				home he = homeDetail[masterId];
				he->flyTarget = roomName;

				me->remove_combine_item("chuansongshenfu",1);//扣除传送神符 
				re ="恭喜，你已成功将"+room->query_name_cn()+ "与家园联系起来，你可以从飞天小屋直接传送到这里。\n";
			}
			else
			{
				re = "你家的地契出现了异常，请与客服联系。\n";//出错了，请与客服联系
			}
		}
		else
		{
			re = "你没有传送神符，可以去杂货商人处购买。\n";
		}
	}
	else
		re = "你现在还没有家园，不能完成该操作\n";
	return re; 
}


//得到某个房间所有生物和空地
string query_all_lifes(string type)
{
	object env = environment(this_player());              //当前所在房间
	string re = "";
	string homeId = env->query_homeId();
	string masterId = query_masterId_by_path(homeId);
	home he = homeDetail[masterId]; 
	mapping lifes = he->lifes;                            //所有的"生物"信息
	//werror("=== [query_all_lifes] type ="+ type+"===\n");
	mapping reLifes = lifes[type];                        //需要的种类（矿、动物、植物）

	array lifesList = sort(indices(reLifes));
	int lifeNum = he->lv;                                 //房间的等级决定了可以种植多少种作物
	int num = sizeof(reLifes);                            //用户信息中，作物的总数
	if(lifeNum<num) num = lifeNum;                        //如果用户的作物数超过了房间的上限制，则取房间上限作为返回的作物数目

	for(int i =0;i<num;i++)
	{
		int ind = lifesList[i];
		object o = reLifes[ind];
		if(o){
			re += "["+o->query_name_cn()+":home_life_detail "+ type +" " + i +"]\n";
		}
		else
		{
			re += "[一块空地:home_life_add "+type+" "+i+"]\n";
		}
	}
	return re;
}
//得到某个生物的详细信息
//lifeType  矿  植物  动物
//ind  所在位置
string query_life_detail(string lifeType,int ind)
{
	object me = this_player();
	object room = environment(me);
	mapping(string:mapping(int:object)) allLifes = room->query_lifes();
	mapping(int:object) lifes = allLifes[lifeType];
	object ob = lifes[ind];
	string re = "";
	if(ob&&ob!=0)
	{
		re += ob->query_name_cn()+"\n";
		re += ob->query_picture_url()+"\n";
		re += "汇聚度:"+ob->query_current_life()+"/"+ob->query_final_life()+"\n";
		re +="[摧毁:home_life_cancel_submit "+ lifeType +" "+ ind +"]  ";
		re +="[替换:home_life_replace_submit "+ lifeType +" "+ ind+"]\n";
		if(ob->query_current_life()>=ob->query_final_life())
			re +="[采集:home_life_get "+ lifeType +" "+ ind +"]  ";
	}
	else
	{
		re += "你要操作的物品并不存在!\n";
	}
	re +="[返回:home_move "+lifeType+"]";
	return re;
}

//得到infancy列表
string query_life_addList(string lifeType,int ind)
{
	mapping(string:int) name_count=([]);
	object player = this_player();
	array(object) all_obj = all_inventory(player);
	string fullType = "home_infancy_" + lifeType;
	string re = "";
	string reTmp= "";
	int haveItem = 0;
	foreach(all_obj,object ob){
		if(ob->query_item_type()== fullType){
			reTmp += "["+ ob->query_name_cn() +":home_life_add_submit "+ob->query_name()+" "+ lifeType +" " + ind + " "+ name_count[ob->query_name()]+"](x"+ob->amount +")\n";
			name_count[ob->query_name()]++;
			haveItem = 1;
		}
	}
	if(haveItem)
	{
		re += "请选择你要使用的物品:\n" + reTmp;
	}
	else{
		re += "你没有可以在此使用的物品。\n";
	}
	re += "\n[返回:home_move "+lifeType+"]";
	return re;
}

//展示infancy详细信息
string query_infancy_detail(string infancyName,string lifeType,int ind,int count)
{
	object player = this_player();
	object ob = present(infancyName,player,count);
	object room = environment(player);             //当前所在房间 
	string re = "";
	re += ob->query_name_cn()+"(x"+ob->amount+")\n";
	re += ob->query_picture_url()+"\n";
	re += ob->query_desc()+"\n";
	re += ob->query_harvest_desc()+"\n";
	re += "需要家园等级:"+ob->query_homeLevel_limit();
	re +="\n[确认:home_life_add_confirm "+ob->query_name()+" "+ lifeType +" "+ ind +" " + count +"]\n";
	re +="[返回:home_life_add " +lifeType+" "+ ind +"\n]";
	return re;
}

//新增加一种"生物"，需要完成3项工作：
//1、在该房间的lifes属性中增加这个生物的相关信息；（页面显示使用）
//2、在homeDetail这个mapping中，增加这个生物的相关信息；（保存数据使用）
//3、移除玩家身上相应的 infancy 物品
string life_add(string infancyName,string lifeType,int ind,int count)
{
	object player = this_player();
	string re = "";
	object room = environment(player);             //当前所在房间 
	string masterId = room->query_masterId();      //房间主人ID
	string areaName = room->query_areaName();      //房间所在area 名称
	string infancyType = room->query_name();       //房间名，决定了"生物"的种类
	if(is_master(room->query_homeId()))            //判断玩家是否是房间的主人
	{
		object infancy = present(infancyName,player,count);    //需要消耗的物品
		int roomLevel = get_home_level(player->query_name());
		int levelNeed = infancy->query_homeLevel_limit();
		if(roomLevel && levelNeed && roomLevel>=levelNeed)
		{
			string lifePath = ITEM_PATH + infancy->query_grownItem_path();//"生物"文件存放路径  ITEM_PATH　＋　/home/grown/....

			mapping lifeInRoom = room->query_lifes();        //任务1 在该房间的lifes属性中增加这个生物的相关信息；
			mapping lifeInRoomTmp = lifeInRoom[lifeType];    //   先得到家园中所有的生物，再得到特定类型的生物

			home he = homeDetail[masterId];                  //任务2 在homeDetail这个mapping中，增加这个生物的相关信息
			mapping lifes = he->lifes;                       //   得到对应的mapping
			mapping lifeTmp = lifes[lifeType];

			object newLife = init_new_lifes(lifePath,areaName,infancyType);//生成这个新的生物
			if(newLife != 0){
				lifeInRoomTmp[ind]=newLife;                      //任务1 done 
				lifeTmp[ind] =newLife;                           //任务2 done
				player->remove_combine_item(infancyName,1);      //任务3 done
				re += "恭喜，你已经在家园中成功添加了"+newLife->query_name_cn()+"\n";
			}
			else
			{
				re += "抱歉，由于气候原因，添加失败了，请返回重试！\n";
			}
		}
		else
		{
			re += "抱歉，"+ infancy->query_name_cn()+"需要"+ levelNeed+"级以上的家园才能使用，你的家园等级只有"+ roomLevel +"级。\n";
		}
	}
	else
	{
		re += "你不是房间的主人或者你不在正确的位置\n";
	}
	re += "[返回:home_move "+ infancyType +"]\n";
	return re;
}
//初始化某个生物
//1、生成这个物品
//2、依据不同的地段信息，设置该生物的成熟时间
object init_new_lifes(string lifePath,string areaName,string infancyType)
{
	object newLife = 0;
	area aa = areaMap[areaName];
	mixed err = catch{
		newLife=clone(lifePath);
	};
	if(!err && newLife){
		newLife->set_current_life(0);//当前生命
		int speed = newLife->query_grow_speed();
		//生长速度	
		array(string) tmp = aa->speedUpList;
		for(int i =0;i<sizeof(tmp);i++)
		{
			if(infancyType==tmp[i])
				speed += speed*SPEED_UP/100;//特殊地段的生长速度提高。
		}
		newLife->set_grow_speed(speed);
		//成熟时间
		int lifeTime = newLife->query_final_life()*SPEED_UNIT/speed;//生长所需总时间
		newLife->set_dead_time(time()+lifeTime);
	}
	else
	{
		newLife = 0;
	}
	return newLife;
}
//收获的时候到了
//需要完成3项工作 1、给予玩家相应的物品
//                2、修改room对象的lifes属性(即：采集后，该生物将会消失)
//                3、修改homeDetail这个mapping中相关的信息
string life_get(string lifeType,int ind)
{
	object player = this_player();
	object room = environment(player);
	mapping(string:mapping(int:object)) allLifes = room->query_lifes();
	mapping(int:object) lifes = allLifes[lifeType];
	object ob = lifes[ind];//得到这个需要收获的"生物"
	string re = "";
	string goodsDesc = "";
	if(ob&&ob!=0&&ob->query_final_life()==ob->query_current_life())
	{
		goodsDesc = give_items(ob);                                //为玩家添加相应的物品，并得到相应的描述信息
		re += "恭喜，你获得了 "+goodsDesc+"\n";                    //任务1 done
		re += if_have_viceskill(lifeType,player);		   //如果有相对应的技能，则提高该技能熟练度 added by caijie 081104
		//特殊的房间中的生物，在收获之后，原生物有一定几率不消失。
		object room = environment(player);                         //当前所在房间
		string areaName = room->query_areaName();                  
		area aa = areaMap[areaName];
		array(string) tmp = aa->speedUpList;                       //该区域中，所有 加速生长/可重复采集 生物类型
		int canRepeat = 0;                                         //是否可以重复采集的标志位
		for(int i =0;i<sizeof(tmp);i++)
		{
			if(lifeType==tmp[i]&&REPEAT_RATE>random(100))      //能重复采集
			{
				canRepeat =1;
			}
		}
		if(canRepeat)
		{
			re += ob->query_name_cn()+"并没有消失\n";          //重复采集，不用清除相关信息
		}
		else{
			clear_life(lifeType,ind);                          //清除该生物的相关信息 任务2、3  done
			re += ob->query_name_cn()+"消失了\n";
		}
	}
	else
	{
		re += "你要操作的物品并不存在或者尚为成熟。\n";
	}
	re +="[返回:home_move "+lifeType+"]";
	return re;
}

//查询玩家是否有相对应的技能 added by caijie 081104
//参数：lifeType 家园物品种类，如:ore、plant..  me：玩家
string if_have_viceskill(string lifeType,object me){
	string type = "";
	string s = "";
	switch(lifeType){
		case "ore": type = "caikuang";
			    break;
		case "plant":type = "caiyao";
			    break;
	}
	if(type!="" && me->vice_skills[type]){
	//有技能
		array(int) skill = me->vice_skills[type];
		int now_lev = skill[0];
		if(now_lev < skill[2]){
			int update_need = (int)(now_lev/5);
			skill[1]++;
			if(skill[1]>=update_need){
				skill[0]++;
				skill[1]=0;
				s += "你的采矿熟练度提高到了"+(now_lev+1)+"级\n";
			}
		}
	}
	return s;
}
//清除某个生物的相关信息
void clear_life(string lifeType,int ind)
{
	object room = environment(this_player());                       //当前所在房间
	string masterId = room->query_masterId();
	mapping lifeInRoom = room->query_lifes();                       //任务1 在该房间的lifes属性中删除这个生物的相关信息；
	mapping lifeInRoomTmp = lifeInRoom[lifeType];                   //   得到对应的mapping

	home he = homeDetail[masterId];                                 //任务2 在homeDetail这个mapping中，删除这个生物的相关信息
	mapping lifes = he->lifes;                                      //   得到对应的mapping
	mapping lifeTmp = lifes[lifeType];

	lifeInRoomTmp[ind]=0;                                           //任务1 done 
	lifeTmp[ind] =0;                                                //任务2 done
}

//玩家在对生物进行采集后，得到相应的物品
//参数：进行采集的生物
//返回: 玩家得到的物品描述
string give_items(object ob)
{
	object me = this_player();
	string goodsName = "";
	string goodsPath = "";
	string goodsDesc = "";
	int dropRate = 0;
	mapping goodsMap = dropMap[ob->query_name()];                                      //掉落列表
	array goodsArr = indices(goodsMap);                                                //该物品对应的所有掉落
	for(int i=0;i<sizeof(goodsArr);i++)                                                //遍历每个可能掉落的物品
	{
		goodsName = goodsArr[i];
		dropRate = goodsMap[goodsName];
		if(dropRate>=random(100))                                                  //一定几率掉落物品
		{
			goodsPath = ITEM_PATH + goodsName;
			object goods = 0;
			mixed err = catch{
				goods=clone(goodsPath);
			};
			if(!err && goods){
				goodsDesc += goods->query_name_cn() + " ";                 //添加描述
				goods->move_player(this_player()->query_name());           //得到物品
			}
		}
	}
	string log = "["+MUD_TIMESD->get_mysql_timedesc()+"]["+me->query_name()+"]["+goodsDesc +"]\n"; 
	Stdio.append_file(ROOT+"/log/home/drop/drop"+MUD_TIMESD->get_year_month_day()+".log",log);
	return goodsDesc;
}
//取消对某个生物的培育
string life_cancel(string lifeType,int ind)
{
	string re = "";
	object player = this_player();
	object room = environment(player);
	mapping(string:mapping(int:object)) allLifes = room->query_lifes();
	mapping(int:object) lifes = allLifes[lifeType];
	object ob = lifes[ind];
	re +="你成功摧毁了"+ob->query_name_cn()+"\n";
	clear_life(lifeType,ind);
	re +="[返回:home_move " +lifeType+ "]\n";
	return re;
}
//得到某一类infancy的列表链接
string query_infancy(string infancyType)
{
	string re = "\n";
	switch(infancyType){
		case "ore":
			re += "[植物:home_shop_item_list plant]|[动物:home_shop_item_list animal]|矿物\n";
		break;
		case "plant":
			re += "植物|[动物:home_shop_item_list animal]|[矿物:home_shop_item_list ore]\n";
		break;
		case "animal":
			re += "[植物:home_shop_item_list plant]|动物|[矿物:home_shop_item_list ore]\n";
		break;
	}
	foreach(sort(indices(infancyMap)),string infancyName)
	{
		array tmp = infancyMap[infancyName];
		if(tmp[1] == infancyType)
		{
			re += "["+ infancyName+":home_shop_item_detail "+ tmp[0] +" "+ tmp[2]+" "+tmp[3]+" 0]\n";
		}
	}
	return re;
}

//为家园重命名
string reset_home_name(string name)
{
	object player = this_player();
	object room = environment(player);
	string masterId = room->query_masterId();
	name = BROADCASTD->words_filter(name);//过滤敏感词汇  
	//room->set_name_cn(name);
	//room->set_customName(name);             //改变 room中的属性，用于页面显示
	mapping allRooms = existHome[player->query_name()];
	int num = sizeof(ROOMS);                //home中所有的房间
	for(int i=0;i<num;i++){
		object roomTmp;                 //改变所有room中的属性，用于页面显示 
		string roomName = ROOMS[i];
		roomTmp = allRooms[roomName];
		roomTmp->set_name_cn(name);
		roomTmp->set_customName(name);
	}
	home he = home();                       //改变 homeDetail中的信息，用于保存
	he = homeDetail[masterId];
	he->customName = name;
	return name;
}
//重写家园的自定义描述
string reset_home_desc(string desc)
{
	object player = this_player();
	object room = environment(player);
	string masterId = room->query_masterId();
	desc = BROADCASTD->words_filter(desc);      //过滤敏感词汇  
	//room->set_customDesc(desc);               //改变 room中的属性，用于页面显示

	mapping allRooms = existHome[player->query_name()];
	int num = sizeof(ROOMS);                    //home中所有的房间
	for(int i=0;i<num;i++){
		object roomTmp;                     //改变所有room中的属性，用于页面显示 
		string roomName = ROOMS[i];
		roomTmp = allRooms[roomName];
		roomTmp->set_customDesc(desc);
	}
	home he = home();                           //改变 homeDetail中的信息，用于保存
	he = homeDetail[masterId];
	he->customDesc = desc;
	return desc;
}
//添加玩家在某个房间的记录信息 即 userIn 这个字段
//userId 
void add_user(string userId)
{
	object player = this_player();                    //当前玩家
	object room = environment(player);                //进入的home
	string masterId = room->query_masterId();         //home主人的Id

	mapping allRooms = existHome[masterId];
	int num = sizeof(ROOMS);                          //home中所有的房间
	for(int i=0;i<num;i++){
		string roomName = ROOMS[i];               //遍历所有的房间
		object roomTmp = allRooms[roomName];      //得到某个房间对象
		if( search(roomTmp->userIn,userId) == -1) //search的结果为-1,说明userId在这个array中不存在
		{
			roomTmp->userIn += ({userId});
		}
	}
	home he = homeDetail[masterId];                   //改变 homeDetail中的信息，用于保存
	if(search(he->userIn,userId) == -1 )
	{
		he->userIn += ({userId});
	}
}

//删除玩家在某个房间的记录信息 即 userIn 这个字段
void del_user(string userId)
{
	object player = this_player();
	object room = environment(player);
	string masterId = room->query_masterId();

	mapping allRooms = existHome[masterId];
	int num = sizeof(ROOMS);                //home中所有的房间
	for(int i=0;i<num;i++){
		object roomTmp;                 //改变所有room中的属性，用于页面显示 
		string roomName = ROOMS[i];
		roomTmp = allRooms[roomName];
		roomTmp->userIn -= ({userId});
	}
	home he = home();                       //改变 homeDetail中的信息，用于保存
	he = homeDetail[masterId];
	he->userIn -= ({userId});
}

//保存门信息 默认只有房主才能进行此操作
void save_door(string doorInfo)
{
	object player = this_player();
	object door_room = environment(player);
	//object room = query_home_by_masterId(me->query_name());
	string masterId = door_room->query_masterId();
	object main_room = query_room_by_masterId(masterId,"main");
	door_room->set_door(doorInfo);                   //改变 door中的属性，用于页面显示
	main_room->set_door(doorInfo);                   //改变 main中的属性，用于页面显示
	home he = home();                                //改变 homeDetail中的信息，用于保存
	he = homeDetail[masterId];
	he->door = doorInfo;
}
//保存看门狗信息 默认只有房主才能进行次操作 
//存储结构："1,vice_npc/huoyunquan,生命，力量，智力，敏捷，喂养时间"(第一次存储的时间为成功买狗的时间)
void save_dog(string dogInfo,string masterId)
{
	object door_room = query_room_by_masterId(masterId,"door");
	object main_room = query_room_by_masterId(masterId,"main");
	door_room->set_dog(dogInfo);                    //改变 door中的属性，用于页面显示
	main_room->set_dog(dogInfo);                    //改变 main中的属性，用于页面显示
	home he = home();                               //改变 homeDetail中的信息，用于保存
	he = homeDetail[masterId];
	he->dog = dogInfo;
}

//保存所有的信息
void store_all_info(void|int fg){
	string he_s = "房间名|主人ID|主人名|房间名|房间描述|允许列表|矿石|动物|植物|门信息|看门狗信息|home中玩家|功能房间|飞天小屋目的地|店铺信息"+"\n";
	foreach(sort(indices(homeDetail)),string masterId)
	{
		home he = homeDetail[masterId];
		he_s += he->homeId +"|";
		he_s += he->masterId+ "|";
		he_s += he->masterName+ "|";
		he_s += he->customName+ "|";
		he_s += he->customDesc+ "|";
		//允许列表
		array(string) au = he->allowedUser;
		for(int i=0;i<sizeof(au);i++)
		{
			he_s += au[i]+",";
		}
		he_s += "|";

		//养殖信息
		mapping(string:mapping(int:object)) lifes = he->lifes;
		array(string) lifeTypes = ({"ore","animal","plant"});//按顺序存储各种作物的信息
		for(int i=0;i<sizeof(lifeTypes);i++)
		{
			string lifeTpye = lifeTypes[i];

			mapping(int:object) lifeTmp = lifes[lifeTpye];
			array lifeTmpList = sort(indices(lifeTmp));
			int lifeNum = sizeof(lifeTmpList);
			int numLimit = he->lv;                   //房间的等级也就是每个房间可以养成的作物数
			if(lifeNum>numLimit) lifeNum = numLimit; //如果用户的作物数超过了房间的上限，则取房间上限作为保存的作物数目
			for(int i =0;i<numLimit;i++)
			{
				int ind = lifeTmpList[i];
				object o = lifeTmp[ind];
				if(o){
					he_s += o->query_name() + "/";
					he_s += o->query_dead_time() +"/";
					he_s += o->query_grow_speed() + "/";
					he_s += ",";
				}
				else
				{
					he_s += "0/";
					he_s += "0/";
					he_s += "0/";
					he_s += ",";
				}

			}
			he_s += "|";
		}
		//养殖信息 done

		he_s += he->door + "|";  //门信息
		he_s += he->dog + "|";   //看门狗信息


		//房间中的玩家列表
		array(string) ui = he->userIn;
		for(int i=0;i<sizeof(ui);i++)
		{
			he_s += ui[i]+",";
		}
		he_s += "|";
		array(string) fr = he->functionRoom;
		for(int i=0;i<sizeof(fr);i++)
		{
			he_s += fr[i]+",";
		}
		he_s += "|";

		he_s += he->flyTarget;//"飞天小屋"的目的地
		he_s += "|";
		//店铺信息
		mapping(int:string) shopTmp = he->shop;
		int shopNum = sizeof(shopTmp);
		array(int) shopList = sort(indices(shopTmp));
		for(int i=0;i<shopNum;i++){
			int ind = shopList[i];
			he_s += shopTmp[ind]+",";
		}
		he_s += "|";
		he_s += "\n";
	}
	Stdio.write_file(ROOT+HOME_INFO,he_s);
	//map_home
	string hem_s = "path|所属地段|所属公寓|使用与否|主人ID"+"\n";
	foreach(sort(indices(homeMap)),string roomId)
	{
		homeList hl = homeMap[roomId];				
		hem_s += hl->name + "|";
		hem_s += hl->slotName + "|";
		hem_s += hl->flatName + "|";
		hem_s += hl->isUsed + "|";
		if(hl->masterId!="")
		{
			hem_s += hl->masterId;
		}
		hem_s += "\n";
	}
	Stdio.write_file(ROOT+ROOM_MAP,hem_s);

	//shop_recommend
	string her_s = "path|主人ID|主人名称|推荐时间|推荐期限"+"\n";
	foreach(sort(indices(shopRcmMap)),string homeId)
	{
		shopRcmList tmp = shopRcmMap[homeId];
		her_s += tmp->path+"|"+tmp->masterId+"|"+tmp->masterNameCN+"|"+tmp->rcmTime+"|"+tmp->rcmTimeDelay+"\n";
	}
	Stdio.write_file(ROOT+SHOPRCM_MAP,her_s);

	if(!fg)
		call_out(store_all_info,TIME_SAPCE);
}


/*初始化所有的home。
  void load_all_homes(){
  foreach(sort(indices(homeDetail)),string masterId){
  home he = homeDetail[masterId];                   //home的信息 
  int num = sizeof(ROOMS);                          //每个home中可能包括多个房间
  for(int i=0;i<num;i++){
  object room; 
  string new_room_path = ROOM_PATH+ROOMS[i];//房间文件路径
  program p = compile_file(new_room_path);
  if(p){
  master()->programs[new_room_path]=p;
  room=clone(p);
  }
  if(room){
  init_room(room,he);                        //初始化每个房间中的信息
  string roomName = room->query_name();
  if(i==0)
  existHome[masterId] = ([roomName:room]);
  else
  existHome[masterId] += ([roomName:room]);
  }
  }
  }
  }
 */

/*
   方法描述：判断玩家是否在房间的allowed名单中
   变量：
   player    需要查询的玩家
   homeName  房间名
   返回值：
   0 不在名单中
   1 在名单中
   int is_allowedUser(object player,string homeName)

		he_s += "\n";
	}
	Stdio.write_file(ROOT+HOME_INFO,he_s);
	//map_home
	string hem_s = "path|所属地段|所属公寓|使用与否|主人ID"+"\n";
	foreach(sort(indices(homeMap)),string roomId)
	{
		homeList hl = homeMap[roomId];				
		hem_s += hl->name + "|";
		hem_s += hl->slotName + "|";
		hem_s += hl->flatName + "|";
		hem_s += hl->isUsed + "|";
		if(hl->masterId!="")
		{
			hem_s += hl->masterId;
		}
		hem_s += "\n";
	}
	Stdio.write_file(ROOT+ROOM_MAP,hem_s);
	if(!fg)
		call_out(store_all_info,TIME_SAPCE);
}
 */


//用于门给master传话
void give_master_msg(object room,object player,string content)
{
	//object sender = find_object("paimaishi");
	int remove_flag = 0;
	string recver_name = room->masterId;
	object to = find_player(recver_name);
	if(!to){
		to = player->load_player(recver_name);
		remove_flag = 1;
	}
	if(to && (!remove_flag)){
		content += "[赶紧回家:home_view "+ to->home_path +"]  [不管他:look]\n";
		tell_object(to,content);
	}
	if(remove_flag){
		//content += "[赶紧回家:home_view "+ to->home_path +"]  [不管他:look]\n";
		to->recieve_mail("baojinqi","安全警报器",recver_name,to->query_name_cn(),"",content);
		to->remove();
	}
}
/*
//检查该房间是否有狗
//返回值：1 有狗且是活的
	  2 有狗但死了
	  0 没狗
*/
int is_have_dog(object room){
	string st = room->query_dog();
	if(st!=""){
		array(string) animal = st/",";
		if(animal[0]=="1"){
			return 1;
		}
		if(animal[0]=="0"){
			return 2;
		}
	}
	return 0;
}

/*
  查询玩家是否还能再增加功能房间
  参数  masterId：家园主人id
  返回值：1 可以继续购买
  	  0 已达到限制，不能再购买
  author: caijie 
  date:08/10/28
*/
int if_can_buy_functionroom(string masterId){
	int re = 0;
	object env = environment(this_player());//当前所在房间
	array(string) allFuncRoom = env->query_functionRoom();
	int count = sizeof(allFuncRoom);//获得当前玩家已经购买了的功能房间数
	int homeLv = get_home_level(masterId);	//获得玩家所拥有的家园的等级
	//家园所允许增加的功能房间数量 = 家园等级 + 4 （如1级家园最多能购买5个功能房间，2级可以增加6个，以此类推...）
	if(homeLv && (count - homeLv)>=4){
		re = 1;
	}
	return re;
}

//获得家园等级 added by caijie 08/10/28
int get_home_level(string masterId){
	home he = homeDetail[masterId];
	if(he){
		return he->lv;
	}
	else 
		return 0;
}

//获得购买链接描述
string get_kind_links(string kind,string cmds){
	string s = "";
	switch(kind){
		case "home_base":
			s += "基础类|[幸运类:"+cmds+" home_luck]|[伤害类:"+cmds+" home_attack]|[传送类:"+cmds+" home_fly]|\n[抗法类:"+cmds+" home_defend]\n";
			break;
		case "home_luck":
			s += "[基础类:"+cmds+" home_base]|幸运类|[伤害类:"+cmds+" home_attack]|[传送类:"+cmds+" home_fly]|\n[抗法类:"+cmds+" home_defend]\n";
			break;
		case "home_attack":
			s += "[基础类:"+cmds+" home_base]|[幸运类:"+cmds+" home_luck]|伤害类|[传送类:"+cmds+" home_fly]|\n[抗法类:"+cmds+" home_defend]\n";
			break;
		case "home_fly":
			s += "[基础类:"+cmds+" home_base]|[幸运类:"+cmds+" home_luck]|[伤害类:"+cmds+" home_attack]|传送类|\n[抗法类:"+cmds+" home_defend]\n";
			break;
		case "home_defend":
			s += "[基础类:"+cmds+" home_base]|[幸运类:"+cmds+" home_luck]|[伤害类:"+cmds+" home_attack]|[传送类:"+cmds+" home_fly]|\n抗法类\n";
			break;
	}
	s += "--------\n";
	return s;
}


//列出玩家可变卖的功能房间
string get_sell_functionroom_list(string kind){
	object me = this_player();
	string s = "";
	int flag = 0;
	object env = environment(me);
	array(string) allFuncRoom = env->query_functionRoom();
	int count = sizeof(allFuncRoom);//获得当前玩家已经购买了的功能房间数
	s += get_kind_links(kind,"home_functionroom_remind");
	if(count){
		for(int i=0;i<count;i++){
			object f_room = (object)(ROOM_PATH+"function/"+allFuncRoom[i]);
			if(f_room->query_buff_kind()==kind){
				s += "["+f_room->query_name_cn()+":home_functionroom_sell_detail "+allFuncRoom[i]+"]\n";
				flag ++;
			}
		}
		if(!flag){
			s += "抱歉，你没有这类房间\n";
		}
	}
	else {
		s += "你还没有功能房间，空手套白狼在这里可行不通\n";
	}
	return s;
}

//变卖功能房间信息
string query_sell_functionroom_info(string room_name){
	object me = this_player();
	string s = "";
	object f_room = (object)(ROOM_PATH+"function/"+room_name);
	int yushi = f_room->query_priceYushi();
	yushi = (int)(yushi - yushi*DEPR_FEE);
	s += "\n 确认要变卖"+ f_room->query_name_cn() +"吗？\n";
	s += "变卖将会得到"+ YUSHID->get_yushi_for_desc(yushi)+"\n\n";
	s += "[确认:home_sell_functionroom_confirm "+room_name+ " "+ yushi + " 0]\n";
	s += "[取消:look]\n";
	return s;
}
//确认“变卖”后后的相关操作
int sell_function_room(string roomName,int yushi,int money)
{
	int re = 0;
	object me = this_player();
	object room = environment(me);                  //当前所在房间
	string masterId = room->query_masterId();                  //房间主人ID
	array(string) functionRooms = room->query_functionRoom(); //已有的功能房间
	
	int num = sizeof(functionRooms);
	if(search(functionRooms,roomName)!=-1)                        //如果该home中有这个room
	{
		//任务1、修改这个home中每个room的functionRooms属性
		mapping allRooms = existHome[masterId];            //得到这个home中的所有room
		if(allRooms){
			foreach(sort(indices(allRooms)),string room)    //修复所有room的functionRooms属性
			{
				object tmp = allRooms[room];
				tmp->functionRoom -= ({roomName});
			}
			//任务2、修改homeDetail中相关的信息
			home he = homeDetail[masterId];
			he->functionRoom -= ({roomName});
			//支付玉石和钱
			int  rt = YUSHID->give_yushi(me,yushi);
			if(rt)
			{
				if(money){
					me->account += money*100;
				}
				string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_sell]["+roomName+"][][1][-"+yushi+"][0]\n";
				Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);  

			}
			return 1;//删除成功
		}
		else
		{
			return 0;//出错了，请与客服联系（在这里，就会出现扣了玉，但是没加上房间的情况，这种可能一般是不会出现的）
		}
	}
	else{
		return 0;//没有该功能房间，不能删除
	}
}
//add end
//获得家园位置的闻之描述
string query_home_pos(string masterId)
{
	string re = "";
	home he = homeDetail[masterId];
	if(he)
	{
		string areaName = he->areaName;
		string slotName = he->slotName;
		string flatName = he->flatName;
		string areaNameCn = areaMap[areaName]->nameCn;
		string slotNameCn = slotMap[slotName]->nameCn;
		string flatNameCn = flatMap[flatName]->nameCn;
		re += areaNameCn +"-"+slotNameCn+"-"+flatNameCn+"\n";
	}
	else
		re = "(地契似乎出现了一些问题，官府正在调查。)\n";
	return re;
}

//私家小店的相关接口 店铺信息记录在detail_home文件里，记录格式：若摊位没有摆放物品则为"0",否则为:物品文件路径|开始摆放时间|摆放期限|价格|是否到期标志（0为没到期，1为已到期）
//added by caijie 08/11/05
//方法描述：添加店铺许可信息
void add_shop_license(string masterId,string roomName){
	mapping(int:string) shopLicense = ([]);
	for(int i=1;i<=DEFAULT_TANWEI;i++){
		shopLicense[i] = DEFAULT_SHOP_S;
	}
	home he = home();                           //改变 homeDetail中的信息，用于保存
	he = homeDetail[masterId];
	he->shop = shopLicense;
}


//判断是否购买了店铺许可
//返回值：1、已经购买   0、还没购买
int if_have_shopLicense(string masterId){
	home he = homeDetail[masterId];
	mapping(int:string) shopList = he->shop;
	if(sizeof(shopList)){
		return 1;
	}
	else 
		return 0;
}

void flush_flag(object player){
	object env = environment(this_player());              //当前所在房间
	string re = "";
	string homeId = env->query_homeId();
	string masterId = query_masterId_by_path(homeId);
	home he = homeDetail[masterId]; 
	mapping shop = he->shop;                            //得到店铺信息
	array shopList = sort(indices(shop));
	int num = sizeof(shop);                            //用户信息中，摊位的总数
	for(int i =0;i<num;i++){
		int ind = shopList[i];
		string shop_s = shop[ind];
		if(shop_s!=DEFAULT_SHOP_S){
			array(string) shopInfo= shop_s/"#";
			if(shopInfo[4]=="0"){
				int deadline = (int)shopInfo[1] + (int)shopInfo[2]*DAY;//到期时间，以秒为单位
				string time_s = TIMESD->get_remainTime_desc(deadline);
				if(time_s==""){
					//过期
					shopInfo[4]="1";
					he->shop[ind] = shopInfo[0]+"#"+shopInfo[1]+"#"+shopInfo[2]+"#"+shopInfo[3]+"#"+shopInfo[4]+"#"+shopInfo[5]+"#";
				}
			}
			else {
				int deadline = (int)shopInfo[1] + ((int)shopInfo[2]+DELAY_TIME)*DAY;//到期时间，以秒为单位
				string time_s = TIMESD->get_remainTime_desc(deadline);
				if(time_s==""){
					//领取中心的物品，超过存放期限，则系统自动回收
					shopInfo[4]="1";
					he->shop[ind] = DEFAULT_SHOP_S;
				}
			}
		}
	}
}
//店铺里所出售的物品的信息
string query_shop_items()
{
	flush_flag(this_player());
	object env = environment(this_player());              //当前所在房间
	string re = "";
	string homeId = env->query_homeId();
	string masterId = query_masterId_by_path(homeId);
	home he = homeDetail[masterId]; 
	mapping shop = he->shop;                            //得到店铺信息
	array shopList = sort(indices(shop));
	int num = sizeof(shop);                            //用户信息中，摊位的总数
	for(int i =0;i<num;i++)
	{
		int ind = shopList[i];
		string shop_s = shop[ind];
		if(shop_s!=DEFAULT_SHOP_S){
			array(string) shopInfo= shop_s/"#";
			string sellStatus = shopInfo[4];
			if(sellStatus=="0"){
			//非过期物品
				int deadline = (int)shopInfo[1] + (int)shopInfo[2]*DAY;//到期时间，以秒为单位
				string time_s = TIMESD->get_remainTime_desc(deadline);
				object itemTmp = (object)(ITEM_PATH + shopInfo[0]);
				array(string) price = shopInfo[3]/":";
				if(price[1]=="1"){ //玉石标价
					re += "[摊位"+ind+"："+itemTmp->query_name_cn()+":home_buy_shopItem_detail "+masterId+" "+price[0]+" "+price[1]+" "+ind+" "+shopInfo[2]+"]|"+YUSHID->get_yushi_for_desc((int)price[0])+"|剩余"+time_s+"\n";
				}
				else if (price[1]=="0"){ //黄金标价
					re += "[摊位"+ind+"："+itemTmp->query_name_cn()+":home_buy_shopItem_detail "+masterId+" "+price[0]+" "+price[1]+" "+ind+" "+shopInfo[2]+"]|"+MUD_MONEYD->query_store_money_cn((int)price[0])+"|剩余"+time_s+"\n";
				}
			}
			else if(sellStatus=="1"){
				//过期物品
				object itemTmp = (object)(ITEM_PATH + shopInfo[0]);
				if(HOMED->is_master(homeId))
					re += "摊位"+ind+"："+itemTmp->query_name_cn()+"(过期，请到领取中心领取)\n";
				else
					re += "摊位"+ind+"：无\n";
			}
			else if(sellStatus=="2"){
				//物品被卖出
				if(HOMED->is_master(homeId))
					re += "摊位"+ind+"：该摊位上的物品已卖出，\n到服务中心领取您所得到的金钱或玉\n";
				else
					re += "摊位"+ind+"：无\n";
			}
		}
		else
		{
			if(HOMED->is_master(homeId))
				re += "[摊位"+ind+":home_add_shopItem "+ind+"]：无\n";
			else
				re += "摊位"+ind+"：无\n";
		}
	}
	if(HOMED->is_master(homeId)&&num){
		re += "\n\n[服务中心:home_shop_service_center "+masterId+"]\n";
		re += "[增加摊位:home_add_tanwei]\n";
	}
	return re;
}
//初始化店铺信息
mapping(int:string) init_shop(string shop_s){
	mapping(int:string) shopList = ([]);
	if(sizeof(shop_s)){
		array(string) eachInfo = shop_s/",";
		//werror("----shop_num="+sizeof(eachInfo)+"--\n");
		for(int i=0;i<sizeof(eachInfo)-1;i++){
			shopList[i+1] = eachInfo[i];
		}
	}
	return shopList;
}

//获得出售期限清单
string get_time_delay_list(string itemName,int shopId,string cmds){
	string s = "";
	array(int) delay = sort(indices(timeDelay));
	int num = sizeof(timeDelay);
	for(int i=0;i<num;i++){
		s += "["+delay[i]+"天:"+cmds+" "+itemName+" "+shopId+" "+delay[i]+"](征收"+timeDelay[delay[i]]+"%所得税)\n";
	}
	return s;
}

//获得出售所征收的所得税率
int get_tax(int time){
	return timeDelay[time];
}

//摆摊，保存所要出售的物品
void save_shopItem(string masterId,void|string shopInfo,int ind){
	home he = homeDetail[masterId];
	if(shopInfo == ""){
		shopInfo = DEFAULT_SHOP_S;
	}
	//mapping tmp = he->shop;
	//tmp[ind] = shopInfo;

	he->shop[ind] = shopInfo;
}

//列出可领取的物品
string get_past_time_items(string masterId){
	home he = homeDetail[masterId];
	mapping shopList = he->shop;
	int num = sizeof(shopList);
	array shopId = indices(shopList);
	string s = "";
	int fg = 0;//是否有可领取的过期物品，非零唯有，零为没有
	for(int i=0;i<num;i++){
		int ind = shopId[i];
		string shop_s = shopList[ind];
		if(shop_s!=DEFAULT_SHOP_S){
			array shopInfo = shop_s/"#";
			string sellStatus = shopInfo[4];
			if(sellStatus=="1"){
				object item = (object)(ITEM_PATH+shopInfo[0]);
				/*
				if(time_s==""){
					s += "存放在此的"+item->query_name_cn()+"超过了7天已经被系统自动回收\n";
					he->shop[ind] = DEFAULT_SHOP_S;
				}
				*/
				s += item->query_name_cn()+"-[领取:home_get_pass_time_item "+ind+"]\n";
				fg ++;
			}
			else if(sellStatus=="2"){
				//金钱或玉
				array price = shopInfo[3]/":"; 
				int tax = get_tax((int)shopInfo[2]);
				object item = (object)(ITEM_PATH+shopInfo[0]);
				int getYu = (int)price[0]*(100-tax)/100;
				if(price[1]=="1"){
					s += "您出售"+item->query_name_cn()+"获得"+YUSHID->get_yushi_for_desc((int)price[0])+"扣除"+tax+"%的所得税，您可[领取"+YUSHID->get_yushi_for_desc(getYu)+":home_get_pass_time_item "+ind+"]\n";
				}
				else if(price[1]=="0"){
					s += "您出售"+item->query_name_cn()+"获得"+MUD_MONEYD->query_store_money_cn((int)price[0])+"扣除"+tax+"%的所得税，您可[领取"+MUD_MONEYD->query_store_money_cn(getYu)+":home_get_pass_time_item "+ind+"]\n";
				}
				fg ++;
			}
		}
	}
	if(!fg){
		s += "您目前并没有物品寄存在这里\n";
	}
	return s;
}

//获得要领取的物品
int get_pass_time_ob(object me,int ind){
	string masterId = me->query_name();
	home he = homeDetail[masterId];
	mapping shopList = he->shop;
	string s_log = "";
	string c_log = "";
	string itemName = "";
	int yushiToRecord = 0;
	int moneyToRecord = 0;
	if(sizeof(shopList)){
		string shopTmp = shopList[ind];
		if(shopTmp!=DEFAULT_SHOP_S){
			object item;
			array shop = shopTmp/"#";
			string now=ctime(time());
			string sellStatus = shop[4];
			mixed err = catch{
				item = clone(ITEM_PATH+shop[0]);
			};
			if(!err&&item){
				itemName = item->query_name_cn();
			}
			if(sellStatus=="1"){
				if(!err&&item){
					s_log += masterId+"领回"+item->query_name_cn()+"数量："+shop[5];
					Stdio.append_file(ROOT+"/log/home/passtime_item.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					if(item->is("combine_item")){
						item->amount = (int)shop[5];
						item->move_player(masterId);
						return 1;
					}
					else {
						item->move(me);
						return 1;
					}
				}
			}
			else if(sellStatus=="2"){
				int tax = get_tax((int)shop[2]);
				array price = shop[3]/":";
				int getYu = (int)price[0]*(100-tax)/100;
				if(price[1]=="1"){
					int getResult = YUSHID->give_yushi(me,getYu);
					yushiToRecord = (int)price[0] - getYu;
					if(getResult){
						s_log = masterId+"领回"+YUSHID->give_yushi(me,getYu);
						Stdio.append_file(ROOT+"/log/home/passtime_item.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
						c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_shop_sell][]["+itemName+"][1]["+ yushiToRecord  +"][0]\n";
						Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log); 
					}
					return getResult;
				}
				else if(price[1]=="0"){
					me->account += getYu;
					moneyToRecord = (int)price[0] - getYu;
					s_log = masterId+"领回"+shop[5]+"银";
					Stdio.append_file(ROOT+"/log/home/passtime_item.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_shop_sell][]["+itemName+"][1]["+ moneyToRecord  +"][0]\n";
					Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_money_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
					return 1;
				}
			}
		}
	}
	return 0;
}

//返回相对应的物品，针对购买者,或者是取消摆摊
object get_shop_item(string masterId,int ind){
	home he = homeDetail[masterId];
	mapping shopList = he->shop;
	if(sizeof(shopList)){
		string shopTmp = shopList[ind];
		if(shopTmp!=DEFAULT_SHOP_S){
			object item;
			array shop = shopTmp/"#";
			if(shop[4]=="0"){
				mixed err = catch{
					item = clone(ITEM_PATH+shop[0]);
				};
				if(!err&&item){
					if(item->is("combine_item")){
						item->amount = (int)shop[5];
					}
					return item;
				}
			}
		}
	}
	return 0;
}

//改变标志位
int change_flag(string masterId,int shopId,int flag){
	if(if_have_shopLicense(masterId)){
		home he = homeDetail[masterId];
		mapping shopList = he->shop;
		string shopTmp = shopList[shopId];
		if(shopTmp!=DEFAULT_SHOP_S){
			array shopInfo = shopTmp/"#";
			shopInfo[4]=flag;
			he->shop[shopId] = shopInfo[0]+"#"+shopInfo[1]+"#"+shopInfo[2]+"#"+shopInfo[3]+"#"+shopInfo[4]+"#"+shopInfo[5]+"#";
			return 1;
		}
	}
	return 0;
}


//获得一个摊位上出售物品的数量
int get_shopItem_num(string masterId,int shopId){
	home he = homeDetail[masterId];
	mapping shopList = he->shop;
	string shopTmp = shopList[shopId];
	return (int)(shopTmp/"#")[5];
}

//获得玩家当前已经拥有的摊位数量 added by caijie 08/11/17
int query_tanwei_count(string masterId){
	home he = homeDetail[masterId];
	return sizeof(he->shop);
}

//获得不同等级家园的摊位上限 added by caijie 08/11/17
int query_tanwei_up(string masterId){
	int homeLv = get_home_level(masterId);  //获得玩家所拥有的家园的等级
	int tanwei_up = 10;
	if(homeLv>1){
		tanwei_up += homeLv*8;
	}
	return tanwei_up;
}

//检查店铺推荐是否过期 1是 0否
int if_shopRcm_pass(string homePath){
	shopRcmList shop = shopRcmMap[homePath];
	int rcmTime = shop->rcmTime;
	int rcmTimeDelay = shop->rcmTimeDelay;
	int deadline = shop->rcmTime + rcmTimeDelay * DAY;
	string time_s = TIMESD->get_remainTime_desc(deadline);
	//werror("----homePath="+homePath+"---deadline="+deadline+"---time="+time()+"--time_s="+time_s+"\n");
	if(time_s==""){
		//过期
		return 1;
	}
	else 
		return 0;
}

//刷新店铺推荐列表,每天晚上12点刷新一次
void flush_shopRcm_list(void|int flag){
	if(shopRcmMap){
		array(string) shopRcmA = indices(shopRcmMap);
		foreach(shopRcmA,string path){
			if(if_shopRcm_pass(path)){
				mixed tmp = m_delete(shopRcmMap,path);
				object to = find_player(tmp->masterId);
				int remove_flag = 0;
				if(!to){
					array list=users(1);
					object helper; //随机找个在线的玩家，以调用load_player()来将未在线的玩家载入内存
					for(int j=0;j<sizeof(list);j++){
						helper = list[j];
						if(helper)
							break;
					}
					to = helper->load_player(tmp->masterId);
					remove_flag = 1;
				}
				if(to){
					tell_object(to,"你的店铺推荐已经停止\n[继续推荐:home_shop_recommend]\n");
				}
				if(remove_flag)
					to->remove();
			}
		}
		if(flag){
			mapping(string:int) now_time = localtime(time());
			int now_mday = now_time["mday"];
			int now_mon = now_time["mon"];
			int now_year = now_time["year"];
			int next_time = mktime(59,59,23,now_mday,now_mon,now_year);
			int need_time = next_time-time();
			call_out(flush_shopRcm_list,need_time);
		}
		else{
			call_out(flush_shopRcm_list,DAY);
		}
	}
}

//列出所有推荐的店铺
string query_shopRcm_list(){
	string s = "";
	array(string) shopRcmA = indices(shopRcmMap);
	foreach(shopRcmA,string path){
		shopRcmList tmp = shopRcmMap[path];
		s += "["+tmp->masterNameCN+"的私家小店:home_view "+path+"]\n";
	}
	return s;
}

//店铺是否已经推荐 1是，0否
int if_shop_rcmed(string homeId){
	if(search(indices(shopRcmMap),homeId)!=-1){
		return 1;
	}
	else 
		return 0;
}

//把新推荐的店铺加入到列表中
void add_shop_recommend(object player,string homeId,int delay){
	if(!shopRcmMap[homeId]){
		shopRcmList tmp = shopRcmList();
		tmp->path = homeId;
		tmp->masterId = player->query_name();
		tmp->masterNameCN = player->query_name_cn();
		tmp->rcmTime = time();
		tmp->rcmTimeDelay = delay;
		shopRcmMap[homeId] = tmp;
	}
}

//通过主人Id，得到家园Id
string query_homeId_by_masterId(string masterId){
	string tmp = search(masterMap,masterId);
	return tmp;
}
