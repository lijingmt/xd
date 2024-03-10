/**************************************************************************************************************
 *购买物品守护模块
 *由caijie写于2008/7/3
 *把可购买的物品列入的"/usr/local/games/usrdata/items/can_buy_item.list"文件中，其中该列表包括
 * 物品类别、物品文件名、        等级限制、职业限制、物品中文名、需要的玉石及玉石等级           和  需要的黄金，
 *如：book  book/liejiajianfeng     9      jianxian  【诅】裂甲剑风  5:1(5为玉石数量，1为玉石等级)  50
 *此守护模块主要是把可购买物品及上面提到的性质列入到映射表buy_item_list中，然后应用到购买物品和列出可购买的物品清单接口中
 ***************************************************************************************************************/
#include <globals.h>
#include <gamelib/include/gamelib.h>


#define ITEM_PATH  ROOT "/gamelib/clone/item/"
#define BOOK_LIST  ROOT "/gamelib/data/can_buy_book_list.csv" //替换路径
#define FLUSH_TIME 24*3600	//24小时刷新一次
#define PACKAGE_EXP ROOT "/gamelib/data/package_expand.csv"

class buy_item
{
	string item_type;//[0]物品类别，如：书，肥料，丹药
	string file;//[1]物品文件名
	int level;//[2]学习技能等级限制
	string zhiye;//[3]学习技能职业限制,剑仙:jianxian 羽士:yushi 诛仙:zhuxian 巫妖：wuyao 狂妖:kuangyao 影鬼:yinggui 人类:human 妖魔:monst 所有职业:all
	string name_cn;//[4]技能书的中文名
	int need_yushi;//[5]需要的碎玉
	//int yushi_level;
	int need_money;//[6]需要的黄金
	int num;	//可购买的数量 080903 cai
}


private static mapping(string:buy_item) buy_item_list = ([]);
private static mapping(string:buy_item) high_level_book = ([]);
private static mapping(string:array) book_on = ([]);
private static mapping(string:array(array(int))) package = ([]);

void create(){
	load_list();
	start_book();
	load_pac_file();
}

void load_list()
{
	buy_item_list = ([]);
	string liandanData = Stdio.read_file(BOOK_LIST);
	array(string) lines = liandanData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			buy_item tmpBuy = buy_item();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 8){
				tmpBuy->item_type = columns[0];
				tmpBuy->file = columns[1];
				tmpBuy->level = (int)columns[2];
				tmpBuy->zhiye = columns[3];
				tmpBuy->name_cn = columns[4];
				//array(string) tmpYu = columns[5]/":";//tmpYu[0]需要玉石的数量，tmpYu[1]玉石等级
				//tmpBuy->need_yushi = (int)tmpYu[0];
				tmpBuy->need_yushi = (int)columns[5];
				//tmpBuy->yushi_level = (int)tmpYu[1];
				tmpBuy->need_money = (int)columns[6];
				tmpBuy->num = (int)columns[7];
				if(columns[1]!=""){
					if(tmpBuy->level>=60){
						if(high_level_book[columns[1]]==0)
							high_level_book[columns[1]]=tmpBuy;
					}
					else{
						if(buy_item_list[columns[1]]==0)                     //080903
							buy_item_list[columns[1]] = tmpBuy;
					}
				}
			}
			else 
				 werror("------size of columns wrong in load_csv() of buyd.pike------\n");
		}
	}
	else 
		werror("------read can_buy_item.list wrong in gamelib/single/daemon/buyd.pike------\n");
}

//加载仓库扩充信息文件
void load_pac_file()
{
	package = ([]);
	string liandanData = Stdio.read_file(PACKAGE_EXP);
	array(string) lines = liandanData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array columns = eachline/"|";
			if(sizeof(columns)==3){
				if(!package[columns[0]]){
					package[columns[0]] = ({({(int)columns[1],(int)columns[2]})});
				}
				else{
					package[columns[0]] += ({({(int)columns[1],(int)columns[2]})});
				}
			}
			else
				werror("------size of columns wrong in load_pac_file() of buyd.pike------\n");
		}
	}
	else 
		werror("------read package_expand.csv wrong in gamelib/single/daemon/buyd.pike------\n");
}


//列出物品清单调用接口
//以物品类型（如：书、肥料等等）和职业限制做识别，
string get_buy_item_list(string item_type,string zhiye){
	object me = this_player();
	string s = "";
	foreach(sort(indices(buy_item_list)),string eachbook){
		buy_item tmpAtt = buy_item_list[eachbook];
		if(tmpAtt->item_type==item_type&&tmpAtt->zhiye==zhiye){
			if(tmpAtt->level==0)
				s += "["+tmpAtt->name_cn+":buy_items "+item_type+" "+zhiye+" "+eachbook+" "+tmpAtt->need_yushi+" "+tmpAtt->need_money+" 0]\n";
			else 
				s += "["+tmpAtt->name_cn+":buy_items "+item_type+" "+zhiye+" "+eachbook+" "+tmpAtt->need_yushi+" "+tmpAtt->need_money+" 0]("+tmpAtt->level+"级)\n";
		}
	}
	return s;
}


//利用玉石和黄金购买物品的接口
string buy_items(string item_name,string item_type)
{
	object me = this_player();
	object item;
	string s = "";
	buy_item tmp = buy_item_list[item_name];
	int money = (tmp->need_money)*100;//购买物品需要的黄金
	int yushi = tmp->need_yushi;//购买物品需要的玉石
	int have_money = me->query_account();//玩家身上带有的金钱
	string item_namecn = "";
	if(have_money<money){
		s += "黄金不够\n";
		return s ;
	}
	if(!YUSHID->have_enough_yushi(me,yushi)){
		s += "玉石不够\n";
		return s;
	}
	if(me->if_over_easy_load()){
		s += "您的背包已满，去清理一下再来吧\n";
		return s;
	}
	mixed err = catch{
		item = clone(ITEM_PATH+tmp->file);
		item_namecn = item->query_name_cn();
	};
	if(!err&&item){
		YUSHID->pay_yushi(me,yushi);
		me->del_account(money);
		if(item->is_combine_item()){
			item->move_player(me->query_name());
		}
		else
			item->move(me);
		string consume_time = MUD_TIMESD->get_mysql_timedesc();
		int cost_reb=yushi;
		string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"]["+item_type+"]["+item_name+"]["+item_namecn+"][1]["+cost_reb+"][0]\n";
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
		s += "购买成功！\n";
	}
	return s;
}

//显示物品信息调用接口
string item_view(string item_name,int need_yushi,int need_money){
	string s = "";
	object item_ob = (object)(ITEM_PATH+item_name);
	s += item_ob->query_name_cn()+"\n";
	s += item_ob->query_picture_url()+"\n"+item_ob->query_desc()+"\n";
	if(item_ob->profe_read_limit||item_ob->level_limit)
		s += "要求职业: "+item_ob->profe_read_limit+"\n"+"要求等级: "+item_ob->level_limit+"\n";
	s += "\n";
	s += "价格:"+YUSHID->get_yushi_for_desc(need_yushi);
	if(need_money){
		s += ", "+need_money+"黄金";
	}
	s += "\n";
	return s;
}

/*
   方法描述：通过玉石和钱购买物品
   变量：player    玩家
         suiyu_num 需要的碎玉数量
	 money     需要的钱的数量(银的数量 = 金的数量*100)
	 flag      标识所交易的物品是否要装到背包里，0或空表示否 1是
   返回值：
         0: 支付失败 玉石不足
	 1：支付失败 金钱不足
	 2：支付失败 空间不足
	 3：支付成功
	 4: 系统错误
   author Evan 2008.07.25
 */
int do_trade(object player,int suiyu_num,int money,void|int flag)
{
	if(flag){
		if(player->if_over_easy_load()){
			return 2;                                                         
		}
	}
	if(!YUSHID->have_enough_yushi(player,suiyu_num)){
		return 0;
	}
	if(player->query_account()<money){
		return 1;
	}
	//如果没有出现上述错误，则正式开始实现交易
	if(YUSHID->pay_yushi(player,suiyu_num))//扣除玉石
	{
		if(money){
			player->del_account(money);//扣除相应的钱
		}
	}
	else{
		return 4;
	}
	return 3;
}


//列出可购买的高级技能书 080903 
string get_book()
{
	string s = "";
	string name,name_cn;
	int num,need_yushi;
	if(book_on && sizeof(book_on)){
		array tmp = indices(book_on);
		int size = sizeof(tmp);
		for(int i=0;i<size;i++){
			name = tmp[i];
			name_cn = book_on[name][0];
			num = book_on[name][1];
			need_yushi = book_on[name][2];
			s += "["+name_cn+":yushi_buy_hlbook_detail "+name+" "+need_yushi+"](剩余"+num+"本)\n";
		}
	}
	return s;
}

//加载可购买的高级技能书 080903
void start_book()
{
	book_on = ([]);
	array(string) book = indices(high_level_book);
	int size = sizeof(book);
	int i = random(size);
	int j = random(size);
	//werror("=size="+size+"========what's wrong with start_book???=i="+i+"==j="+j+"==\n");
	while(j==i){
		j = random(size);
	//werror("==========what's wrong with start_book???=======\n");
		if(j!=i) 
			break;
	}
	//werror("==========what's wrong with start_book???=======\n");
	book_on[book[i]] = query_hl_book_info(book[i]);
	book_on[book[j]] = query_hl_book_info(book[j]) ;
	call_out(start_book,FLUSH_TIME);
}


//返回物品信息({name,name_cn,num,yushi})  080903

array query_hl_book_info(string name)
{
	string name_cn = "";
	int num = 0;
	int need_yushi = 0;
	array a = ({});
	if(high_level_book && sizeof(high_level_book)){
		name_cn = high_level_book[name]->name_cn;
		num = high_level_book[name]->num;
		need_yushi = high_level_book[name]->need_yushi;
		a += ({name_cn,num,need_yushi});
	}
	return a;
}


//设置技能书的剩余数量
void set_book_num(string name,int num)
{
	array bc = book_on[name];
	if(bc && sizeof(bc)){
		int have_num = (int)bc[1];
		if(have_num>=num){
			bc[1] = have_num - num;
			book_on[name][1]=bc[1];
		}
	}
}

int query_book_num(string name)
{
	array bc = book_on[name];
	if(bc && sizeof(bc)){
		int num = bc[1];
		if(num>0)
			return bc[1];
		else 
			return 0;
	}
}

//列出可购买的背包或仓库清单
//type==beibao cangku
string get_pac_list(string type,string cmd)
{
	string tmp_s = "";
	string s = "";
	if(type=="beibao") tmp_s += "格背包";
	if(type=="cangku") tmp_s += "格仓库";
	if(package){
		array(array) tmp = package[type];
		int size = sizeof(tmp);
		//werror("---size of tmp="+size+"----\n");
		if(size){
			for(int i=0;i<size;i++){
			//werror("------i="+i+"---tmp[i][0]="+sizeof(tmp[i])+"---\n");
				s += "[购买"+tmp[i][0]+tmp_s+":"+cmd+" "+type+" "+tmp[i][0]+" "+tmp[i][1]+" 0](需要"+YUSHID->get_yushi_for_desc(tmp[i][1])+")\n";
			}
		}
		else 
			s += "我们这部卖这样的物品\n";
	}
	return s;
}


//查询已经购买了的背包或者仓库的数量
//参数: type="beibao" or "cangku" 
//      player 玩家
int query_cangku_num(object player,string type)
{
	int cangku_num = 0;
	array a_tmp = query_all_pac_kind(player,type);
	if(sizeof(a_tmp)){
		for(int i=0;i<sizeof(a_tmp);i++){
			cangku_num += player->package_expand[type][a_tmp[i]];
		}
	}
	return cangku_num;
}

//获得玩家身上已有的背包或仓库品种 type = "beibao" or "cangku"
//本来想写到user.pike里，但是由于不是正常重启
array(int) query_all_pac_kind(object player,string type)
{
	array a_tmp = ({});
	if(player->package_expand){
		if(player->package_expand[type] && sizeof(player->package_expand[type])){
			mapping m_tmp = player->package_expand[type];//player->package_expand=(["beibao":([背包品种:对应个数]),])
			a_tmp = indices(m_tmp);
		}
	}
	return a_tmp;
}
//获得可替换的背包或仓库的列表
string get_pac_replace_list(object player,string type,int replace_size)
{
	string s = "";
	string tmp_s = "";
	int need_yushi = 0;
	if(type=="beibao")tmp_s+="背包";
	if(type=="cangku")tmp_s+="仓库";
	array a_tmp = query_all_pac_kind(player,type);
	array(array) p_tmp = package[type];
	if(sizeof(a_tmp)){
		mapping m_tmp = player->package_expand[type];
		for(int i=0;i<sizeof(a_tmp);i++){
			if(a_tmp[i]<replace_size&&a_tmp[i]>0){
				need_yushi = query_pac_price(type,replace_size) - query_pac_price(type,a_tmp[i]);
				//参数：类型+替换前的背包大小+要想替换的背包大小+差价
				s += m_tmp[a_tmp[i]]+"个"+a_tmp[i]+"格"+tmp_s+" [替换:user_package_replace_detail "+type+" "+a_tmp[i]+" "+replace_size+" "+need_yushi+"]\n";
			}
		}
	}
	return s;
}


//查看背包的价格
int query_pac_price(string type,int pac_size)
{
	array(array) p_tmp = package[type];
	int p_price = 0;
	if(sizeof(p_tmp)){
		for(int i=0;i<sizeof(p_tmp);i++){
			if(p_tmp[i][0]==pac_size){
				p_price = p_tmp[i][1];
				return p_price;
			}
		}
	}
	return p_price;
}
