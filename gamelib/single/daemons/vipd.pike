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

protected void create(){
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
 * 返回仍在有效期内的会员等级。会员标志和到期时间必须同时有效，
 * 避免旧存档残留 vip_flag 绕过等级突破限制。
 */
int query_active_vip_level(object player)
{
	int level = 0;
	if(!player || !functionp(player->query_vip_flag) ||
	   !functionp(player->query_vip_end_time))
		return 0;
	if(!get_vip_state(player))
		return 0;
	level = (int)player->query_vip_flag();
	if(level<1)
		return 0;
	if(level>VIP_MAX_LEVEL)
		level = VIP_MAX_LEVEL;
	return level;
}

//普通玩家120级封顶；每提高一级有效VIP，等级上限增加20级。
int query_vip_level_limit(int vip_level)
{
	if(vip_level<0)
		vip_level = 0;
	if(vip_level>VIP_MAX_LEVEL)
		vip_level = VIP_MAX_LEVEL;
	return NORMAL_MAX_LEVEL+vip_level*VIP_LEVEL_LIMIT_STEP;
}

int query_player_level_limit(object player)
{
	return query_vip_level_limit(query_active_vip_level(player));
}

string get_level_limit_des(object player)
{
	int vip_level = query_active_vip_level(player);
	int level_limit = query_vip_level_limit(vip_level);
	int player_level = player && functionp(player->query_level) ?
		(int)player->query_level() : 0;
	string re = "等级突破：普通玩家上限"+NORMAL_MAX_LEVEL+
		"级，每提高一级有效VIP，上限增加"+
		VIP_LEVEL_LIMIT_STEP+"级。\n";
	if(vip_level>0){
		re += "当前VIP"+vip_level+"有效，当前等级上限为"+
			level_limit+"级。\n";
		if(player_level>=level_limit)
			re += "你已达到当前会员等级上限，提高VIP等级后可继续突破。\n";
	}
	else if(player_level>NORMAL_MAX_LEVEL)
		re += "你已达到的高等级会保留；当前VIP无效，重新开通后才可继续升级。\n";
	else
		re += "当前没有有效VIP，达到"+NORMAL_MAX_LEVEL+
			"级后将停止获得升级经验。\n";
	return re;
}

//返回开通、升一档或钻石续费所需的最小碎玉价值，供引导页判断是否显示捐赠入口。
int query_level_limit_next_cost(object player)
{
	int vip_level = query_active_vip_level(player);
	int cost = 0;
	if(vip_level<=0)
		return get_vip_cost(1)*10;
	if(vip_level<VIP_MAX_LEVEL){
		cost = get_vip_cost(vip_level+1)-get_vip_cost(vip_level);
		int state = get_vip_state(player);
		if(state==2 || state==3)
			cost = cost*6/10;
		return cost*10;
	}
	return get_vip_cost(vip_level)*9;
}

string get_level_limit_action_links(object player)
{
	int vip_level = query_active_vip_level(player);
	string re = "";
	if(vip_level>0){
		if(vip_level<VIP_MAX_LEVEL)
			re += "[升级VIP提高等级上限:vip_service_upgrade_list]\n";
		re += "[续费保持等级突破:vip_service_extend_detail]\n";
	}
	else
		re += "[开通VIP突破等级:vip_service_app_list]\n";
	int need_yushi = query_level_limit_next_cost(player);
	if(need_yushi>0 && !YUSHID->have_enough_yushi(player,need_yushi))
		re += "[玉石不足？捐赠获取仙玉:add_szx_fee]\n";
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
				if(vip_level<VIP_MAX_LEVEL)
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
	record_account_vip(player,level,endTime);
	if(PROFESSIONVIPD->is_supported_profession(player->query_profeId()))
		PROFESSIONVIPD->record_membership_state(player);
	return endTime;
}

// ===== 账号级会员镜像：同一注册账号的全部人物共享最高档有效会员 =====
// 购买/续费写账号记录；登录对账把账号最高档同步到人物存档。读取路径
// 仍是人物自己的 vip 标志，热路径零额外开销。

private string normalize_vip_account_id(string account_id)
{
	account_id = lower_case(String.trim_all_whites(account_id || ""));
	if(sizeof(account_id)<2 || sizeof(account_id)>64)
		return "";
	for(int i=0;i<sizeof(account_id);i++){
		int one = account_id[i];
		if((one>='a' && one<='z') || (one>='0' && one<='9'))
			continue;
		return "";
	}
	return account_id;
}

private string vip_account_file_path(string account_id)
{
	account_id = normalize_vip_account_id(account_id);
	if(account_id=="")
		return "";
	return DATA_ROOT+"accounts/"+account_id[sizeof(account_id)-2..]+
		"/"+account_id+".vip.json";
}

private mapping(string:mixed)|zero load_vip_account_record(string path)
{
	string raw;
	mapping(string:mixed) record;
	if(path=="" || !file_stat(path) || file_stat(path)->size>4096)
		return 0;
	raw = Stdio.read_file(path);
	if(!raw || raw=="")
		return 0;
	mixed err=catch{
		record = Standards.JSON.decode(raw);
	};
	if(err || !mappingp(record) || (int)record["version"]!=1 ||
	   normalize_vip_account_id((string)record["account_id"])=="" ||
	   !intp(record["level"]) || (int)record["level"]<0 ||
	   (int)record["level"]>VIP_MAX_LEVEL ||
	   !intp(record["end_time"]) || (int)record["end_time"]<0 ||
	   !intp(record["revision"]) || (int)record["revision"]<0)
		return 0;
	return record;
}

private mapping(string:object)|zero acquire_vip_account_lock(string path)
{
	object file;
	object file_key;
	mixed lock_error;
	if(path=="")
		return 0;
	Stdio.mkdirhier(dirname(path));
	file = Stdio.File();
	if(!file->open(path+".lock","wca"))
		return 0;
	lock_error = catch{ file_key=file->lock(); };
	if(lock_error || !file_key){
		file->close();
		return 0;
	}
	return (["file":file,"key":file_key]);
}

private void release_vip_account_lock(
	mapping(string:object)|zero lock_data)
{
	if(!lock_data)
		return;
	if(lock_data["key"])
		destruct(lock_data["key"]);
	if(lock_data["file"])
		lock_data["file"]->close();
}

private int persist_vip_account_record(string path,
	mapping(string:mixed) record)
{
	string temp_path = path+".tmp."+time()+"."+random(1000000);
	mixed err=catch{
		Stdio.write_file(temp_path,Standards.JSON.encode(record));
	};
	if(err)
		return 0;
	err=catch{ mv(temp_path,path); };
	if(err){
		rm(temp_path);
		return 0;
	}
	return 1;
}

/** 购买/续费后记录账号最高档会员；跨Worker用文件锁串行化。 */
int record_account_vip(object player,int level,int end_time)
{
	string account_id;
	string path;
	mapping(string:object)|zero lock_data;
	mapping(string:mixed) record;
	int changed = 0;
	if(!player || !functionp(player->query_account_owner) ||
	   level<1 || level>VIP_MAX_LEVEL || end_time<=time())
		return 0;
	account_id = (string)player->query_account_owner();
	if(account_id=="" && functionp(player->query_name))
		account_id = (string)player->query_name();
	path = vip_account_file_path(account_id);
	if(path=="")
		return 0;
	lock_data = acquire_vip_account_lock(path);
	if(!lock_data)
		return 0;
	record = load_vip_account_record(path);
	if(!record)
		record = (["version":1,"account_id":
			normalize_vip_account_id(account_id),"revision":0,
			"level":0,"end_time":0,"updated_at":0]);
	if(level>(int)record["level"] ||
	   (level==(int)record["level"] && end_time>(int)record["end_time"])){
		record["level"] = level;
		record["end_time"] = end_time;
		record["revision"] = (int)record["revision"]+1;
		record["updated_at"] = time();
		changed = persist_vip_account_record(path,record);
	}
	release_vip_account_lock(lock_data);
	return changed;
}

/** 登录对账：账号最高档有效会员同步到本人物；人物自身更高时回写账号。 */
int reconcile_account_vip(object player)
{
	string account_id;
	string path;
	mapping(string:mixed)|zero record;
	int level;
	int end_time;
	int my_level;
	int my_end;
	if(!player || !functionp(player->query_account_owner) ||
	   !functionp(player->set_vip_flag))
		return 0;
	account_id = (string)player->query_account_owner();
	if(account_id=="" && functionp(player->query_name))
		account_id = (string)player->query_name();
	path = vip_account_file_path(account_id);
	if(path=="")
		return 0;
	record = load_vip_account_record(path);
	my_level = (int)player->query_vip_flag();
	my_end = (int)player->query_vip_end_time();
	if(!record){
		if(my_level>=1 && my_end>time())
			return record_account_vip(player,my_level,my_end);
		return 0;
	}
	level = (int)record["level"];
	end_time = (int)record["end_time"];
	if(level<1 || end_time<=time())
		return 0;
	if(level>my_level || (level==my_level && end_time>my_end)){
		player->set_vip_flag(level);
		player->set_vip_end_time(end_time);
		return 1;
	}
	if(my_level>level && my_end>time())
		return record_account_vip(player,my_level,my_end);
	return 0;
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

// 会员商品路径、等级和价格必须来自服务端目录，不能信任确认链接参数。
int is_free_good(string name,int level)
{
	if(level<1 || level>VIP_MAX_LEVEL || !vip_free_list[level])
		return 0;
	return has_value(vip_free_list[level],name);
}

int is_off_good(string name,int level)
{
	if(level<1 || level>VIP_MAX_LEVEL || !vip_off_list[level])
		return 0;
	return has_value(vip_off_list[level],name);
}

int query_off_good_price(string name,int level)
{
	int price;
	if(!is_off_good(name,level) || !goods_price_map[name] ||
	   !vip_off_map[level])
		return -1;
	price=goods_price_map[name]*vip_off_map[level]/10;
	// 低单价商品遇到3至4折时整数除法可能得到0；付费目录不能产生
	// 零价成交，最低仍收1枚碎玉。
	return price>0 ? price : 1;
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
方法描述：得到某会员等级某分类的全部免费物品路径（一键领取用）
 */
array(string) query_free_goods_paths(int lv,string sub)
{
	array(string) result = ({});
	array(string) tmp_good_list = vip_free_list[lv];
	string sub_tmp = sub;
	if(!arrayp(tmp_good_list))
		return result;
	if(sub=="baoshi")
		sub_tmp="yushi";
	for(int i=0;i<sizeof(tmp_good_list);i++)
	{
		array(string) tmp = tmp_good_list[i]/"/";
		if(tmp && tmp[0]==sub_tmp)
			result += ({tmp_good_list[i]});
	}
	return result;
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
			price = query_off_good_price(tmp_good_list[i],lv);
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
	int mylv = query_active_vip_level(player);
	if(!mylv)                                  //不是会员
		return 0;
	if(mylv<lv)                                //会员级别不够
		return 1;
	if(query_vip_good_backpack_capacity(player,goods)<=0)
		return 2;
	if(query_off_good_inventory_amount(player,goods)>=
	   (int)player->query_max_yao())
		return 3;
	return re;
}

// 免费会员物品也按实际堆叠总数计算剩余额度，供批量领取在写背包前
// 一次性校验。上限继续沿用各VIP等级既有 query_max_yao() 规则。
int query_free_good_remaining(object player,object goods,int lv)
{
	int maximum;
	int remaining;
	if(!player || !goods || query_active_vip_level(player)<lv)
		return 0;
	maximum=(int)player->query_max_yao();
	remaining=maximum-query_off_good_inventory_amount(player,goods);
	return remaining>0 ? remaining : 0;
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
	int mylv = query_active_vip_level(player);
	if(!mylv)                                  //不是会员
		return 0;
	if(mylv<lv)                                //会员级别不够
		return 1;
	if(query_vip_good_backpack_capacity(player,goods)<=0)
		return 2;
	if(query_off_good_remaining(player,goods,lv)<=0)
		return 3;
	return re;
}

// 批量购买在扣玉前证明整个订单都能装下；已有同来源堆叠的空位也算
// 容量，不能因背包格已满而误拒绝本可合并的一瓶药。
int query_vip_good_backpack_capacity(object player,object goods)
{
	array(object) items;
	int free_slots;
	int maximum;
	int capacity;
	string goods_name;
	if(!player || !goods)
		return 0;
	items=all_inventory(player);
	free_slots=(int)player->query_beibao_size()-sizeof(items);
	if(!goods->is("combine_item"))
		return free_slots>0 ? free_slots : 0;
	maximum=(int)goods->max_count;
	if(maximum<1)
		return 0;
	goods_name=(string)goods->query_name();
	foreach(items,object item)
		if(item && item->is("combine_item") &&
		   (string)item->query_name()==goods_name &&
		   (int)item->query_toVip()==1 && (int)item->amount>=0 &&
		   (int)item->amount<maximum)
			capacity+=maximum-(int)item->amount;
	if(free_slots>0)
		capacity+=free_slots*maximum;
	return capacity;
}

// 同名会员商品可能因历史堆叠上限分成多组，必须累计判断，不能只看
// 任意一组的 amount，否则拆成多个堆叠即可绕过随身数量上限。
int query_off_good_inventory_amount(object player,object goods)
{
	int amount;
	string goods_name;
	if(!player || !goods)
		return 0;
	goods_name = (string)goods->query_name();
	foreach(all_inventory(player),object item){
		if(!item || (string)item->query_name()!=goods_name ||
		   (int)item->query_toVip()!=1)
			continue;
		amount += item->is("combine_item") ? (int)item->amount : 1;
	}
	return amount;
}

int query_off_good_remaining(object player,object goods,int lv)
{
	int maximum=999;
	int remaining;
	if(!player || !goods || query_active_vip_level(player)<lv)
		return 0;
	remaining = maximum-query_off_good_inventory_amount(player,goods);
	return remaining>0 ? remaining : 0;
}
/*
   方法描述：不能领取的说明信息
   变量：state 领取结果
   返回值：string 直接用于页面显示
 */
string if_can_get_offly_desc(int state,int lv,string name)
{
	string re = "";
	int paid_goods_max=999;
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
			
			re +="相同会员特卖物品可随身携带最多"+
				(string)paid_goods_max+"个，用完再来购买吧！\n";
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
