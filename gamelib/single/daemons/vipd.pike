/**
  会员系统
  
  @author evan 
  2008/07/16
  
 【数据结构】
 
 【方法说明】
  get_vip_state()       返回当前玩家的vip状态；
  get_vip_state_des()   返回当前玩家的vip状态描述和相应链接；
 
 */
#include <globals.h>
#include <gamelib/include/gamelib.h>
#define VIP_LIST "/gamelib/data/vip_list"                //会员分级列表文件
#define VIP_GOODS_LIST "/gamelib/data/vip_goods_list"    //会员商品列表文件
#define GOODS_PRICE_LIST "/gamelib/data/goods_price_list"  //商品价格列表文件
#define VIP_TIME 3600*24*30		                        //会员时长         3600*24*30 目前是一个月
#define OFF_TIME 3600*24*15		                        //优惠升级时间     3600*24*15 会员时长的一半
#define ALEART_TIME 3600*24*3		                        //即将到期报警时间 3600*24*3 暂定为3天
#define ITEM_MAX_NUM 5		                        //会员物品累计上限(同一件会员物品只能有 ITEM_MAX_NUM 件)
inherit LOW_DAEMON;
private mapping(int:string) vip_name_map=([]);          //会员【等级/名称】 对应表
private mapping(int:string) vip_desc_map=([]);          //会员【等级/描述】 对应表
private mapping(int:int) vip_cost_map=([]);             //会员【等级/价格】 对应表

private mapping(int:int) vip_off_map=([]);                  //会员【等级/折扣】 对应表
private mapping(int:array(string)) vip_off_list=([]);   //会员【等级/打折物品】 对应表
private mapping(int:array(string)) vip_free_list=([]);  //会员【等级/免费物品】 对应表

private mapping(string:int) goods_price_map =([]);          //【货物/价格】列表

void create(){
	werror("==========  [VIPD start!]   ==========\n");
	array(string) vip_map_tmp = ({});
	string strtips = "";
	int vipLevel = 0;       //会员等级
	string vipName = "";        //会员等级名称
	string vipDesc = "";        //会员等级描述
	int vipCost = 0;            //对应的玉石数
	
	strtips = Stdio.read_file(ROOT+VIP_LIST); //得到会员等级列表
	if(strtips&&sizeof(strtips)){
		vip_map_tmp = strtips/"\n";
		vip_map_tmp -= ({""});	
	}
	else
		werror("===== Error! file not exist: vip_list =====\n");
	int num = sizeof(vip_map_tmp);
	if(num>1)
	{
		for(int i=0;i<num;i++)
		{
			sscanf(vip_map_tmp[i],"%d|%s|%d|%s",vipLevel,vipName,vipCost,vipDesc);
			vip_name_map[vipLevel] = vipName;
			vip_cost_map[vipLevel] = vipCost;
			vip_desc_map[vipLevel] = vipDesc;
		}
		werror("====== set vip_mapping completed! =====\n");
	}

	int vipOff = 0;
	string vipOffList = "";
	string vipFreeList = "";
	strtips = Stdio.read_file(ROOT+VIP_GOODS_LIST); //得到会员商品列表
	if(strtips&&sizeof(strtips)){
		vip_map_tmp = strtips/"\n";
		vip_map_tmp -= ({""});	
	}
	else
		werror("===== Error! file not exist: vip_goods_list =====\n");
	num = sizeof(vip_map_tmp);
	if(num>1)
	{
		for(int i=0;i<num;i++)
		{
			sscanf(vip_map_tmp[i],"%s|%d|%d|%s|%s|",vipName,vipLevel,vipOff,vipOffList,vipFreeList);
			vip_off_map[vipLevel] = vipOff;
			vip_off_list[vipLevel] = vipOffList/",";
			vip_free_list[vipLevel] = vipFreeList/",";
		}
		werror("====== set vip_goods_mapping completed! =====\n");
	}

	int price = 0;
	string goodsName = "";
	strtips = Stdio.read_file(ROOT+GOODS_PRICE_LIST); //得到商品价格列表
	if(strtips&&sizeof(strtips)){
		vip_map_tmp = strtips/"\n";
		vip_map_tmp -= ({""});	
	}
	else
		werror("===== Error! file not exist: goods_price_list =====\n");
	num = sizeof(vip_map_tmp);
	if(num>1)
	{
		for(int i=0;i<num;i++)
		{
			sscanf(vip_map_tmp[i],"%s|%d",goodsName,price);
			goods_price_map[goodsName] = price;
		}
		werror("====== set goods_price_mapping completed! =====\n");
	}
	werror("==========  [VIPD end!]  ==========\n");
}

/*
方法描述：得到玩家当前的vip状态
    变量：player    需要查询的玩家
  返回值：0: 不是vip会员
          1：正常状态
	  2：升级优惠状态
	  3：即将到期状态
 */
int get_vip_state(object player)
{
	int re = 0;
	if(player->query_vip_flag()) //是会员
	{
		re = 1;             //正常状态
		int reTime =  player->query_vip_end_time() - time();
		if(reTime<OFF_TIME&&reTime>ALEART_TIME) 
			re = 2;     //打折状态
		if(reTime<ALEART_TIME&&reTime>=0)
			re = 3;     //即将到期状态
		if(reTime<0){
			player->set_vip_flag(0);//改变其会员状态标志位
			re = 0;     //不再是VIP会员
		}
	}
	return re;
}
/*
方法描述：得到玩家当前的vip状态对应的描述和链接
    变量：player    需要查询的玩家
  返回值：string re 各种状态下对应的描述和链接
 */
string get_vip_state_des(object player)
{
	int state = get_vip_state(player);
	string re = "";
	if(state)
	{
		int vip_level = player->query_vip_flag();
		int end_time_s = player->query_vip_end_time();
		string vip_name = vip_name_map[vip_level];
		string end_time = TIMESD->get_user_year_to_second(end_time_s);
		re += "尊敬的"+player->query_name_cn()+",你现在是"+vip_name+",你的会员资格将在仙道时间"+end_time+"过期。\n";
		switch(state){
			case 1:
				break;
			case 2:
				re += "你的会员期限已经过半，此时升级会员资格，将享受升级费用6折优惠。\n";
				break;
			case 3:
				re += "你的会员资格即将到期，此时续费将享受费用9折优惠。\n";
				break;
		}
				re += "[会员升级:vip_service_upgrade_list]\n";
				re += "[会员续费:vip_service_extend_detail]\n";
	}else
	{
		re +="你还不是我们的会员，赶快加入到会员的大家庭中，享受尊贵的会员特权吧\n\n"; 
		re += "[申请入会:vip_service_app_list]\n";
	}
	return re;
}

/*
方法描述：得到玩家当前的vip状态对应的描述(不含链接)
    变量：player    需要查询的玩家
  返回值：string re 各种状态下对应的描述
 */
string get_vip_state_des_withoutlink(object player)
{
	int state = get_vip_state(player);
	string re = "";
	if(state)
	{
		int vip_level = player->query_vip_flag();
		int end_time_s = player->query_vip_end_time();
		string vip_name = vip_name_map[vip_level];
		string end_time = TIMESD->get_user_year_to_second(end_time_s);
		re += "尊敬的"+player->query_name_cn()+",你现在是"+vip_name+",你的会员资格将在仙道时间"+end_time+"过期。\n";
		switch(state){
			case 1:
				break;
			case 2:
				re += "你的会员期限已经过半，此时升级会员资格，将享受升级费用6折优惠。\n";
				break;
			case 3:
				re += "你的会员资格即将到期，此时续费将享受费用9折优惠。\n";
				break;
		}
	}
	else
	{
		re +="你还不是我们的会员，赶快加入到会员的大家庭中，享受尊贵的会员特权吧\n\n"; 
	}
	return re;
}
/*
方法描述：申请成为会员\会员续费
    变量：player    玩家
          level     等级
  返回值：会员到期时间
 */
int give_vip_to(object player,int level)
{
	int endTime = 0;
	if(!player->query_vip_flag())//目前不是会员，则申请成为会员
	{
		player->set_vip_flag(level);
		endTime = time()+VIP_TIME;
	}
	else//目前已经是会员，则续费。
	{
		endTime = player->query_vip_end_time()+VIP_TIME;
	}
	player->set_vip_end_time(endTime);
	player->add_vip_history(endTime,level);
	return endTime;
}

/*
方法描述：得到玩家的会员等级名称
    变量：level    玩家VIP等级
  返回值：该等级的名称
 */
string get_vip_name(int level)
{
	return vip_name_map[level];
}
/*
方法描述：得到会员等级需要的玉石
    变量：level    VIP等级
  返回值：该等级对应需要的玉石
 */
int get_vip_cost(int level)
{
	return vip_cost_map[level];
}
/*
方法描述：得到会员等级对应的描述
    变量：level    VIP等级
  返回值：该等级对应需要的玉石
 */
string get_vip_desc(int level)
{
	return vip_desc_map[level];
}
/*
方法描述：得到会员等级对应折扣
    变量：level    VIP等级
  返回值：该等级对应需要的折扣
 */
int get_vip_off(int level)
{
	return vip_off_map[level];
}
/*
方法描述：得到会员商品对应的价格
    变量：name    商品名
  返回值：该商品对应需要的碎玉数目
 */
int get_goods_price(string name)
{
	return goods_price_map[name];
}
/*
方法描述：得到会员【等级\名称】列表
 */
mapping get_vip_name_map()
{
	return vip_name_map;
}
/*
方法描述：得到会员【等级\价格】列表
 */
mapping get_vip_cost_map()
{
	return vip_cost_map;
}
/*
方法描述：得到会员【等级\描述】列表
 */
mapping get_vip_desc_map()
{
	return vip_desc_map;
}
/*
方法描述：得到会员【等级\折扣】列表
 */
mapping get_vip_off_map()
{
	return vip_off_map;
}
/*
方法描述：得到商品【名称\价格】列表
 */
mapping get_goods_price_map()
{
	return goods_price_map;
}
/*
方法描述：得到vip免费货物列表
    变量：sub  二级文件夹名(teyao,yushi......)
          lv   会员等级
  返回值：string 直接用于页面显示
 */
string display_free_goods(string sub,int lv)
{
	string re = "";
	array(string) tmp_good_list = vip_free_list[lv];//该会员等级对应的所有免费物品
	array(string) tmp = ({});
	string sub_tmp = sub;
	if(sub=="baoshi")sub_tmp="yushi";//玉石和宝石统一放置在yushi这个文件夹中，所以要特殊处理一下。
	object tmp_ob;//用于得到每个物品的名字的临时对象
	for(int i=0;i<sizeof(tmp_good_list);i++)
	{
		tmp = tmp_good_list[i]/"/";//得到文件所在目录，也就是物品的分类
		if(tmp&&tmp[0]==sub_tmp)//是我们需要的那一类物品
		{
			tmp_ob = clone(ITEM_PATH+tmp_good_list[i]);
			tmp_ob->set_toVip(1);
			re += "["+tmp_ob->query_name_cn()+":vip_myzone_free_detail "+ tmp_good_list[i] +" "+lv+"]\n";
		}
	}
	return re;
}
/*
方法描述：得到vip打折货物列表
    变量：sub  二级文件夹名(teyao,yushi......)
          lv   会员等级
  返回值：string 直接用于页面显示
 */
string display_off_goods(string sub,int lv)
{
	string re = "";
	array(string) tmp_good_list = vip_off_list[lv];//该会员等级对应的所有打折物品
	array(string) tmp = ({});
	int price = 0;
	re += vip_name_map[lv]+"购买下列商品，享受"+ vip_off_map[lv] +"折优惠\n\n";
	string sub_tmp = sub;
	if(sub=="baoshi")sub_tmp="yushi";//玉石和宝石统一放置在yushi这个文件夹中，所以要特殊处理一下。
	object tmp_ob;//用于得到每个物品的名字的临时对象
	for(int i=0;i<sizeof(tmp_good_list);i++)
	{
		tmp = tmp_good_list[i]/"/";//得到文件所在目录，也就是物品的分类
		if(tmp&&tmp[0]==sub_tmp)//是我们需要的那一类物品
		{
			tmp_ob = clone(ITEM_PATH+tmp_good_list[i]);
			tmp_ob->set_toVip(1);
			price = goods_price_map[tmp_good_list[i]] * vip_off_map[lv]/10;//打折后的价格
			re += "["+tmp_ob->query_name_cn()+":vip_myzone_off_detail "+tmp_good_list[i]+" "+lv+" "+price+"]\n";
		}
	}
	return re;
}
/*
方法描述：判断是否能免费领取物品
    变量：me    当前玩家
          goods 物品
          lv    物品所需会员等级
  返回值：0: 不是会员
  	  1：级别不够
          2：包裹已满
	  3：该类物品已到数目上限
	  4：可以领取
 */
int if_can_get_freely(object player,object goods,int lv)
{
	int re = 4;
	int mylv = player->query_vip_flag(); 
	int vip_max_yao=player->query_max_yao();     
	if(!mylv)                                  //不是会员
		return 0;
	if(mylv<lv)                                //会员级别不够
		return 1;
	if(player->if_over_load(goods))            //包裹已满
		return 2;

	array(object) items=all_inventory(player);//判断是否已经超过会员物品数上限
	foreach(items, object tmp){
		if(goods->query_name()==tmp->query_name()&&tmp->toVip == 1){
			if(tmp->amount>=vip_max_yao){
				return 3;           //已经达到上线
			}
			else
				continue;
		}
	} 
	return re;
}
/*
   方法描述：不能领取的说明信息
   变量：state 领取结果
   返回值：string 直接用于页面显示
 */
string if_can_get_freely_desc(int state,int lv,string name)
{
	string re = "";
	int vip_max_yao=this_player()->query_max_yao();
	switch(state){
		case 0:
			re +="抱歉，你还不是会员或者会员资格已经到期，赶快加入到会员的大家庭中，享受尊贵的会员特权！\n\n"; 
			re += "[申请入会:vip_service_app_list]\n";
			break;
		case 1:	
			re +="抱歉，该物品需要"+get_vip_name(lv)+"才能免费领取，请升级你的会员资格\n";
			re += "[会员升级:vip_service_upgrade_list]\n";
			break;
		case 2:
			re += "你的包裹已经满了！\n";
			break;
		case 3:
			re +="相同会员物品只能随身携带最多"+(string)vip_max_yao+"个，用完再来取吧！\n";
			break;
		case 4:
			re +="恭喜，你获得了"+name+"\n";
			break;
		default:
			re += "系统有点累了，等等再来吧！\n";
			break;
	}
	return re;
}
/*
方法描述：判断是否能购买打折物品
    变量：me    当前玩家
          goods 物品
          lv    物品所需会员等级
  返回值：0: 不是会员
  	  1：级别不够
          2：包裹已满
	  3：该类物品已到数目上限
	  4：可以领取
 */
int if_can_get_offly(object player,object goods,int lv)
{
	int re = 4;
	int mylv = player->query_vip_flag(); 
	int vip_max_yao=player->query_max_yao();     
	if(!mylv)                                  //不是会员
		return 0;
	if(mylv<lv)                                //会员级别不够
		return 1;
	if(player->if_over_load(goods))            //包裹已满
		return 2;

	array(object) items=all_inventory(player);//判断是否已经超过会员物品数上限
	foreach(items, object tmp){
		if(goods->query_name()==tmp->query_name()&&tmp->toVip == 1){			
			if(tmp->amount>=vip_max_yao){
				return 3;           //已经达到上线
			}
			else
				continue;
		}
	} 
	return re;
}
/*
   方法描述：不能领取的说明信息
   变量：state 领取结果
   返回值：string 直接用于页面显示
 */
string if_can_get_offly_desc(int state,int lv,string name)
{
	string re = "";
	int vip_max_yao=this_player()->query_max_yao();
	switch(state){
		case 0:
			re +="抱歉，你还不是会员或者会员资格已经到期，赶快加入到会员的大家庭中，享受尊贵的会员特权！\n\n"; 
			re += "[申请入会:vip_service_app_list]\n";
			break;
		case 1:	
			re +="抱歉，该折扣需要"+get_vip_name(lv)+"才能享受，请升级你的会员资格\n";
			re += "[会员升级:vip_service_upgrade_list]\n";
			break;
		case 2:
			re += "你的包裹已经满了！\n";
			break;
		case 3:
			
			re +="相同会员物品只能随身携带最多"+(string)vip_max_yao+"个，用完再来取吧！\n";
			break;
		case 4:
			//re +="恭喜，你获得了"+name+"\n";
			break;
		default:
			re += "系统有点累了，等等再来吧！\n";
			break;
	}
	return re;
}
