//矿物的守护程序，主要负责建立和维护游戏中矿物的信息表，包括矿物的刷新个数，刷新时间，矿物出现的地图等级，矿物的出产物等，并且还要负责矿物在游戏世界的刷新
//
//核心数据结构:
//1.矿物信息表:
// class kuang; 打算采用类来记录矿的信息 
//
// 下面这个mapping作为备用方案
// mapping(string:array(mixed)) kuang_m = 
//   (["tongkuang":({"铜矿",刷新数量,刷新时间(以分钟为单位),地图最低等级，地图最高等级，需要熟练度})
//                    [0]     [1]           [2]                 [3]            [4]          [5]
//       ...
//   ])
//2.矿物产出物表，该表记录玩家挖取矿物时，可能获得的物品:
// mapping(string:mapping(string:int)) get_m = 
//   (["tongkuang":(["tongkuangshi":100,"xuanhuangshi":10,]),
//                     出产物名  :  概率
//      ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/kuangwu.csv中的内容来建立的。
//
//由liaocheng于07/5/23开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define KUANG_CSV ROOT "/gamelib/data/material/kuangwu.csv" //矿物列表
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下
#define ROOM_PATH ROOT "/gamelib/d/" //房间根目录
//#define FLUSH_TIME 900
#define FLUSH_TIME 43200
//#define QUICK_TIME 900
#define QUICK_TIME 1020

class kuang
{
	//string name; //[0]文件名
	string name_cn;//[1]中文名
	int nums;//[2]刷新总数量
	int flush_time;//[3]刷新时间
	int mLevel_min;//[4]地图等级下限
	int mLevel_max;//[5]地图等级上限
	int skill_level;//[6]技能熟练度限制
	mapping(string:int) get_m = ([]); //[7]出产物品映射表
}

private mapping(string:kuang) kuangMap = ([]); //物品信息总表
private mapping(string:int) kuangNeed = ([]); //记录目前需要刷的矿数量
private mapping(string:array) quick_flush = ([]); //快速刷矿,在固定地点刷出矿,在玩家挖矿时别写入，
//([kuang_name:({房间1,房间2,房间3....})])

void create()
{
	load_csv();
	flush_kuang();
	//call_out(flush_kuang,FLUSH_TIME);
	call_out(quick_flush_kuang,QUICK_TIME);
}


void load_csv()
{
	kuangMap = ([]);
	kuangNeed = ([]);
	string kuangData = Stdio.read_file(KUANG_CSV);
	array(string) lines = kuangData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			kuang tmpKuang = kuang();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 8){
				tmpKuang->name_cn = columns[1];
				tmpKuang->nums = (int)columns[2];
				tmpKuang->flush_time = (int)columns[3];
				tmpKuang->mLevel_min = (int)columns[4];
				tmpKuang->mLevel_max = (int)columns[5];
				tmpKuang->skill_level = (int)columns[6];
				array(string) tmpGets = columns[7]/"|";
				foreach(tmpGets,string eachget){
					if(eachget && sizeof(eachget)){
						array(string) tmp = eachget/":";
						int prob = (int)tmp[1];
						tmpKuang->get_m += ([tmp[0]:prob]);
					}
				}
				if(kuangMap[columns[0]] == 0)
					kuangMap[columns[0]] = tmpKuang;
				kuangNeed[columns[0]] = (int)columns[2];
			}
			else
				werror("------size of columns wrong in load_csv() of kuangd.pike------\n");
		}
	}
	else 
		werror("------read kuang.csv wrong in gamelib/single/daemon/kuangd.pike------\n");
}


//刷新矿的接口
void flush_kuang()
{
	foreach(indices(kuangNeed),string kuangname){
		int need_num = kuangNeed[kuangname];
		if(need_num > 0){
		//需要刷矿
			string s_log = "";
			string now=ctime(time());
			kuang tempKuang = kuangMap[kuangname];
			int roomlev_h = tempKuang->mLevel_max;
			int roomlev_l = tempKuang->mLevel_min;
			for(int i=0;i<need_num;i++){
				int roomlev = roomlev_l+random(roomlev_h-roomlev_l+1);
				string room = ROOMLEVELD->query_room(roomlev);
				if(room != ""){
					object kuang_ob;
					object room_ob;
					mixed err = catch{
						kuang_ob = clone(MATERIAL_PATH+kuangname);
						room_ob = (object)(ROOM_PATH+room);
					};
					if(kuang_ob && room_ob && !err){
						//Stdio.append_file(ROOT+"/log/flush_kuang.log",now[0..sizeof(now)-2]+":"+tempKuang->name_cn+"("+room+")\n");
						s_log += now[0..sizeof(now)-2]+":"+tempKuang->name_cn+"("+room+")\n";
						kuang_ob->move(ROOM_PATH+room);
						kuangNeed[kuangname]--;
					}
					else
						werror("------can't flush kuang : "+kuangname+"------\n");
				}
			}
			if(s_log != "")
				Stdio.append_file(ROOT+"/log/flush_kuang.log",s_log+"----------------------------\n");
		}
	}
	quick_flush = ([]); //清空矿物的快速刷新
	call_out(flush_kuang,FLUSH_TIME);
}

void quick_flush_kuang()
{
	if(sizeof(quick_flush)>0){
		foreach(indices(quick_flush),string name){
			int size = sizeof(quick_flush[name]);
			if(size>0){
				array(string) tmp = quick_flush[name];
				for(int i=0;i<size;i++){
					string room = tmp[i];
					object ob = clone(MATERIAL_PATH+name);
					ob->move(ROOM_PATH+room);
					kuangNeed[name]--;
					string now=ctime(time());
					Stdio.append_file(ROOT+"/log/flush_kuang.log",now[0..sizeof(now)-2]+":quick_flush:"+ob->query_name_cn()+"("+room+")\n----------------------\n");
				}
			}
		}
		quick_flush = ([]);
	}
	call_out(quick_flush_kuang,QUICK_TIME);
}

//获得需要采矿熟练度的接口
int query_need_level(string name)
{
	kuang tempKuang = kuangMap[name];
	if(tempKuang){
		return tempKuang->skill_level;	
	}
	else 
		return -1;

}

//获得出产物映射表的接口
mapping(string:int) query_get_m(string name)
{
	mapping(string:int) m_rtn = ([]);
	kuang tempKuang = kuangMap[name];
	if(tempKuang && sizeof(tempKuang->get_m)){
		m_rtn = tempKuang->get_m;
	}
	return m_rtn;
}

//矿被挖了后要设置待刷新矿的数量
void set_flush_num(string name,string room)
{
	if(!kuangNeed[name])
		kuangNeed[name] = 1;
	else
		kuangNeed[name]++;
	if(quick_flush == ([]))
		quick_flush[name] = ({room});
	else if(quick_flush[name] == 0)
		quick_flush[name] = ({room});
	else
		quick_flush[name] += ({room});
}
