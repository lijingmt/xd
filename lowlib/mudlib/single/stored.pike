#include <globals.h>
#include <mudlib/include/mudlib.h>

inherit LOW_DAEMON;


//private	mapping(string:object) m_goods = ([]);
private mapping(int:mapping(string:object)) goods_list=([]);//[物品等级:([该等级物品id:物品对象])]

//游戏中商店买卖守护进程
void create()
{
	//从/usr/local/games/usrdata0/items/orgItems.list读取原始白物品列表
	//然后根据物品等级，做一个影射，按照商店等级不同，卖的物品等级也不同
	//读入普通物品的索引文件
	if(!get_item_list(GAME_BASE_DATA_ROOT+"orgItems.list")){
		werror("------------ReadFile_item_list--------\n ReadFile_item_list error!!\n");
		exit(1);
	}
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
								if(obt)
									tmp += "["+(string)obt->query_name_cn()+"("+MUD_MONEYD->query_store_money_cn((int)obt->query_item_canLevel()*50)+"):buy_detail "+items+"]\n";
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
