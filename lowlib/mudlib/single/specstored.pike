#include <globals.h>
#include <mudlib/include/mudlib.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;


//private	mapping(string:object) m_goods = ([]);
private mapping(int:mapping(string:object)) goods_list=([]);//[物品等级:([该等级物品id:物品对象])]
private mapping(int:mapping(string:object)) goods_list_normal=([]);//[物品等级:([该等级物品id:物品对象])]
private mapping(string:mapping(string:mixed)) player_offers=([]);
private int offer_nonce;
#define SPEC_OFFER_TTL 600
#define SPEC_OFFER_PLAYER_LIMIT 4096

private string normalized_offer_userid(object player)
{
	string userid;
	if(!player)
		return "";
	userid=lower_case((string)player->query_name());
	if(userid=="" || sizeof(userid)>80)
		return "";
	return userid;
}

private string create_offer_token(string userid,string item_name,int fee)
{
	object hash=Crypto.SHA256();
	offer_nonce++;
	hash->update(userid+"|"+item_name+"|"+fee+"|"+time()+"|"+
		offer_nonce+"|"+random(0x7fffffff));
	return String.string2hex(hash->digest());
}

private void prune_player_offers()
{
	array(string) userids=indices(player_offers);
	int now=time();
	for(int i=0;i<sizeof(userids);i++){
		mapping(string:mixed) shelf=player_offers[userids[i]];
		if(!shelf || (int)shelf["consumed"] ||
		   now-(int)shelf["created"]>SPEC_OFFER_TTL)
			m_delete(player_offers,userids[i]);
	}
	while(sizeof(player_offers)>=SPEC_OFFER_PLAYER_LIMIT){
		string oldest_user="";
		int oldest_time=now+1;
		foreach(indices(player_offers),string userid){
			int created=(int)player_offers[userid]["created"];
			if(created<oldest_time){
				oldest_time=created;
				oldest_user=userid;
			}
		}
		if(oldest_user=="")
			break;
		m_delete(player_offers,oldest_user);
	}
}

private void begin_player_offer_refresh(object player)
{
	string userid=normalized_offer_userid(player);
	if(userid=="")
		return;
	prune_player_offers();
	player_offers[userid]=(["created":time(),"consumed":0,"items":([])]);
}

private string register_offer(object player,string item_name,int fee)
{
	string userid=normalized_offer_userid(player);
	mapping(string:mixed) shelf;
	mapping items;
	string token;
	if(userid=="" || item_name=="" || fee<0 || fee>1000000)
		return "";
	shelf=player_offers[userid];
	if(!shelf || time()-(int)shelf["created"]>SPEC_OFFER_TTL){
		begin_player_offer_refresh(player);
		shelf=player_offers[userid];
	}
	items=shelf["items"];
	token=create_offer_token(userid,item_name,fee);
	items[token]=(["name":item_name,"fee":fee,"reserved":0]);
	return token;
}

private string register_selected_offer_link(object player,string link)
{
	string prefix;
	string item_name;
	int fee;
	string token;
	string old_command;
	if(!link || sscanf(link,"%s:buy_detail_spec %s %d]",prefix,
	   item_name,fee)!=3)
		return link;
	token=register_offer(player,item_name,fee);
	if(token=="")
		return "";
	old_command="buy_detail_spec "+item_name+" "+fee+"]";
	return replace(link,old_command,old_command[..sizeof(old_command)-2]+
		" "+token+"]");
}

mapping(string:mixed) query_player_offer(object player,string item_name,
	string token)
{
	string userid=normalized_offer_userid(player);
	mapping(string:mixed) shelf;
	mapping offer;
	if(userid=="" || !token || sizeof(token)!=64 || item_name=="")
		return ([]);
	shelf=player_offers[userid];
	if(!shelf || (int)shelf["consumed"] ||
	   time()-(int)shelf["created"]>SPEC_OFFER_TTL ||
	   !mappingp(shelf["items"]))
		return ([]);
	offer=((mapping)shelf["items"])[token];
	if(!offer || (string)offer["name"]!=item_name ||
	   (int)offer["reserved"])
		return ([]);
	return copy_value(offer);
}

mapping(string:mixed) reserve_player_offer(object player,string item_name,
	string token)
{
	string userid=normalized_offer_userid(player);
	mapping(string:mixed) offer=query_player_offer(player,item_name,token);
	if(!sizeof(offer))
		return ([]);
	((mapping)player_offers[userid]["items"])[token]["reserved"]=1;
	return offer;
}

void release_player_offer(object player,string token)
{
	string userid=normalized_offer_userid(player);
	mapping(string:mixed) shelf=player_offers[userid];
	if(userid!="" && shelf && mappingp(shelf["items"]) &&
	   mappingp(((mapping)shelf["items"])[token]))
		((mapping)shelf["items"])[token]["reserved"]=0;
}

int consume_player_offer(object player,string token)
{
	string userid=normalized_offer_userid(player);
	mapping(string:mixed) shelf=player_offers[userid];
	mapping offer;
	if(userid=="" || !shelf || (int)shelf["consumed"] ||
	   !mappingp(shelf["items"]))
		return 0;
	offer=((mapping)shelf["items"])[token];
	if(!offer || !(int)offer["reserved"])
		return 0;
	shelf["consumed"]=1;
	m_delete(player_offers,userid);
	return 1;
}

string issue_test_offer(object player,string item_name,int fee)
{
	string userid=normalized_offer_userid(player);
	if(getenv("XIAND_RUN_TESTUNIT")!="1" ||
	   search(userid,"testunit")==-1)
		return "";
	begin_player_offer_refresh(player);
	return register_offer(player,item_name,fee);
}

//游戏中商店买卖守护进程
protected void create()
{
	//从/usr/local/games/usrdata0/items/orgItems.list读取原始白物品列表
	//然后根据物品等级，做一个影射，按照商店等级不同，卖的物品等级也不同
	//读入普通物品的索引文件
	if(!get_item_list(GAME_BASE_DATA_ROOT+"specItems.list")){
		werror("------------ReadFile_spec_item_list--------\n ReadFile_spec_item_list error!!\n");
		exit(1);
	}

	if(!get_item_list_normal(GAME_BASE_DATA_ROOT+"orgItems.list")){
		werror("------------ReadFile_org_item_list--------\n ReadFile_org_item_list error!!\n");
		exit(1);
	}
}
string random_list(int|void type){
	string ret = "";
	object player=this_player();
	begin_player_offer_refresh(player);
	for(int i = 0; i< 10; i++){
		string t = query_goods_list(random(71)+1);
		if(t !=""){
			array(string) arr = t/"\n";
			string selected=register_selected_offer_link(player,
				arr[random(sizeof(arr))]);
			if(selected!="")
				ret += selected+"\n";
		}		
	}
	if(type == 1){
		ret+="\n----------\n";
		for(int i = 0; i< 10; i++){
			string t = query_goods_list_normal(random(71)+1);
			int max_count = 0;
			while(t==""){
				t = query_goods_list_normal(random(71)+1);
				max_count++;
				if(max_count >10) break;
			}
			if(t !=""){
				array(string) arr = t/"\n";
				string selected=register_selected_offer_link(player,
					arr[random(sizeof(arr))]);
				if(selected!="")
					ret += selected+"\n";
			}		
		}
	}
	return ret;
}
string query_goods_list(int store_level)//根据商店等级不同，返回不同等级的商品列表
{
	string rst = "";
	if(store_level>0){
		if(goods_list&&sizeof(goods_list)){
			foreach(sort(indices(goods_list)),int itemsLevel){
				//得到传过来的属于该等级物品购买信息和连接指令
				if(itemsLevel&&itemsLevel==store_level){
					//得到当前等级的物品列表影射
					mapping(string:object) m_t = (mapping)goods_list[store_level];
					if(m_t&&sizeof(m_t)){
						string tmp = "";
						foreach(indices(m_t),string items){
							if(items&&sizeof(items)){
								object obt = (object)m_t[items];
								if(obt){
									int fee = random(1000000);
									tmp += "["+(string)obt->query_name_cn()+"("+MUD_MONEYD->query_store_money_cn(fee)+"):buy_detail_spec "+items+" "+fee+"]\n";
								}
							}
						}
						rst += tmp;
					}
				}
			}
		}
	}
	return rst;
}
//内部接口，被create()调用，用于读入白物品文件列表数据，存在item_list映射表中
private int get_item_list(string filename)
{
	string strTmp=Stdio.read_file(filename);
	if(strTmp){
		//以每一行为单位分割文件数据
		array(string) lines = strTmp/"\n";
		//这里碰到些问题，已换行符分割后得到的lines中元素个数要多出一个，最后一个为空，这将会导致后面代码tmp[1]出错
		//因此解决方法是增加了一个判断条件sizeof(eachline)不为空
		if(lines&&sizeof(lines)){
			//对每一行进行处理
			//比如：
			//3|weapon/3tiejian,weapon/3potongjian,weapon/3canpodezhongjian,jewelry/3huangtongjiezhi,
			foreach(lines, string eachline){
				if(eachline&&sizeof(eachline)){
					//分割出物品等级和物品名称，tmp[0]为等级，tmp[1]为名称
					array(string)tmp = eachline/"|";
					int g_level = (int)tmp[0];//该行物品等级
					array(string) itemnames=tmp[1]/",";//该等级下所有物品名字:weapon/3tiejian,weapon/3potongjian,...
					//处理每一行的所有物品，并存储对象到主存储结构goods_list中
					mapping(string:object) m_goods = ([]);
					foreach(itemnames,string index){
						object obg;
						if(index&&sizeof(index)){
							//obg = clone(ITEM_PATH+index);
							obg = clone_item(ITEM_PATH+index);
						}
						if(obg){
							m_goods[index] = obg;	
						}
					}
					if(m_goods)
						goods_list[g_level] = m_goods;
				}
			}
		}
		return 1;
	}
	return 0;
}
string query_goods_list_normal(int store_level)//根据商店等级不同，返回不同等级的商品列表
{
	string rst = "";
	object me = this_player();
	if(store_level>0){
		if(goods_list_normal&&sizeof(goods_list_normal)){
			foreach(sort(indices(goods_list_normal)),int itemsLevel){
				//得到传过来的属于该等级物品购买信息和连接指令
				if(itemsLevel&&itemsLevel==store_level){
					//得到当前等级的物品列表影射
					mapping(string:object) m_t = (mapping)goods_list_normal[store_level];
					if(m_t&&sizeof(m_t)){
						string tmp = "";
						foreach(indices(m_t),string items){
							if(items&&sizeof(items)){
								//object obt = (object)m_t[items];
								int pro_add= random(3000);

								//随机生成装备
								object obt = ITEMSD->get_item_from_rawname(me->query_level(), me->query_level(), me->query_lunck()+pro_add,items);

								if(obt){
									mixed err = catch{
										string file_name = file_name(obt);
										string real_name = file_name - (ROOT+"/gamelib/clone/item/");
										//werror("===========real_name1:"+real_name+"\n");
										real_name= (real_name/"#")[0];
										//werror("===========real_name2:"+real_name+"\n");
										int fee = random(1000000);
										tmp += "["+(string)obt->query_name_cn()+"("+MUD_MONEYD->query_store_money_cn(fee)+"):buy_detail_spec "+real_name+" "+fee+"]\n";
									};
									if(err) werror("======generate items error\n");
									
								}
							}
						}
						rst += tmp;
					}
				}
			}
		}
	}
	return rst;
}
//内部接口，被create()调用，用于读入白物品文件列表数据，存在item_list映射表中
private int get_item_list_normal(string filename)
{
	string strTmp=Stdio.read_file(filename);
	if(strTmp){
		//以每一行为单位分割文件数据
		array(string) lines = strTmp/"\n";
		//这里碰到些问题，已换行符分割后得到的lines中元素个数要多出一个，最后一个为空，这将会导致后面代码tmp[1]出错
		//因此解决方法是增加了一个判断条件sizeof(eachline)不为空
		if(lines&&sizeof(lines)){
			//对每一行进行处理
			//比如：
			//3|weapon/3tiejian,weapon/3potongjian,weapon/3canpodezhongjian,jewelry/3huangtongjiezhi,
			foreach(lines, string eachline){
				if(eachline&&sizeof(eachline)){
					//分割出物品等级和物品名称，tmp[0]为等级，tmp[1]为名称
					array(string)tmp = eachline/"|";
					int g_level = (int)tmp[0];//该行物品等级
					array(string) itemnames=tmp[1]/",";//该等级下所有物品名字:weapon/3tiejian,weapon/3potongjian,...
					//处理每一行的所有物品，并存储对象到主存储结构goods_list中
					mapping(string:object) m_goods = ([]);
					foreach(itemnames,string index){
						object obg;
						if(index&&sizeof(index)){
							//obg = clone(ITEM_PATH+index);
							obg = clone_item(ITEM_PATH+index);
						}
						if(obg){
							m_goods[index] = obg;	
						}
					}
					if(m_goods)
						goods_list_normal[g_level] = m_goods;
				}
			}
		}
		return 1;
	}
	return 0;
}
