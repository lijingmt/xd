//掉落制皮，织布材料的怪刷新守护程序，主要负责建立和维护游戏中这种特殊怪的信息表，包括怪物的刷新个数，刷新时间，怪物出现的地图等级，并且还要负责怪物在游戏世界的刷新
//
//核心数据结构:
//1.怪物信息表:
// class vicenpc; 打算采用类来记录怪物的信息 
//
// 下面这个mapping作为备用方案
// mapping(string:array(mixed)) vicenpc_m = 
//   (["tongvicenpc":({"怪物名",刷新数量,刷新时间(以分钟为单位),地图最低等级，地图最高等级，需要熟练度})
//                    [0]     [1]           [2]                 [3]            [4]          [5]
//       ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/vicenpc.csv中的内容来建立的。
//
//由liaocheng于07/10/22开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define VICENPC_CSV ROOT "/gamelib/data/material/vicenpc.csv" //怪物物列表
#define VICENPC_PATH ROOT "/gamelib/clone/npc/vice_npc/" //所有这类物品文件都放在此目录下
#define ROOM_PATH ROOT "/gamelib/d/" //房间根目录
//#define FLUSH_TIME 900
//怪物的刷新时间比较多样性，这也是这个守护模块的难点
//#define FLUSH_TIME 120 //测试用，循环执行flush_vicenpc()的时间间隔
#define FLUSH_TIME 900 //正式用，15分钟为一单位
#define MAX_TIME 360  //刷新时间最长的怪物的刷新时间

class vicenpc
{
	//string name; //[0]文件名
	string name_cn;//[1]中文名
	int nums;//[2]刷新总数量
	int flush_time;//[3]刷新时间
	int mLevel_min;//[4]地图等级下限
	int mLevel_max;//[5]地图等级上限
}

private mapping(string:vicenpc) vicenpcMap = ([]); //物品信息总表
private mapping(string:int) vicenpcNeed = ([]); //记录目前需要刷的怪物数量
private mapping(int:array(string)) vicenpc_flush_time = ([]);//以刷新时间为索引的映射表,时间为15分钟的倍数
//([15:({vicenpc1,vicenpc2}),
//  30:({vicenpc3,vicenpc5}), 
// ...
//  ])
private int flush_count = 0;

void create()
{
	load_csv();
	flush_vicenpc();
//	call_out(flush_vicenpc,FLUSH_TIME);
}

void load_csv()
{
	vicenpcMap = ([]);
	vicenpcNeed = ([]);
	vicenpc_flush_time = ([]);
	string vicenpcData = Stdio.read_file(VICENPC_CSV);
	array(string) lines = vicenpcData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			vicenpc tmpVicenpc = vicenpc();
			array(string) columns = eachline/",";
			if(sizeof(columns) >= 6){
				tmpVicenpc->name_cn = columns[1];
				tmpVicenpc->nums = (int)columns[2];
				tmpVicenpc->flush_time = (int)columns[3];
				//写入到刷新时间表中
				if(vicenpc_flush_time[tmpVicenpc->flush_time] == 0)
					vicenpc_flush_time[tmpVicenpc->flush_time] = ({columns[0]});
				else
					vicenpc_flush_time[tmpVicenpc->flush_time] += ({columns[0]});
				tmpVicenpc->mLevel_min = (int)columns[4];
				tmpVicenpc->mLevel_max = (int)columns[5];
				if(vicenpcMap[columns[0]] == 0)
					vicenpcMap[columns[0]] = tmpVicenpc;
				vicenpcNeed[columns[0]] = (int)columns[2];
			}
			else
				werror("------size of columns wrong in load_csv() of viceflushd.pike------\n");
		}
	}
	else 
		werror("------read vicenpc.csv wrong in gamelib/single/daemon/viceflushd.pike------\n");
}


//刷新怪物的接口
void flush_vicenpc()
{
	flush_count += 15; //刷新时间是15的倍数
	string now=ctime(time());
	foreach(indices(vicenpc_flush_time),int time){
		if(flush_count%time == 0){
		//到刷新时间了
			array(string) tmp_flush = vicenpc_flush_time[time];
			if(tmp_flush && sizeof(tmp_flush)){
				int size = sizeof(tmp_flush);
				for(int i=0;i<size;i++){
					string vicenpcname = tmp_flush[i];
					if(vicenpcNeed[vicenpcname]){
						int need_num = vicenpcNeed[vicenpcname];
						Stdio.append_file(ROOT+"/log/flush_vicenpc.log",now[0..sizeof(now)-2]+":flush "+vicenpcname+" "+need_num+"\n");
						vicenpc tempVicenpc = vicenpcMap[vicenpcname];
						int roomlev_h = tempVicenpc->mLevel_max;
						int roomlev_l = tempVicenpc->mLevel_min;
						for(int j=0;j<need_num;j++){
							int roomlev = roomlev_l+random(roomlev_h-roomlev_l+1);
							string room = ROOMLEVELD->query_room(roomlev);
							if(room != ""){
								object vicenpc_ob = clone(VICENPC_PATH+vicenpcname);
								if(vicenpc_ob){
									Stdio.append_file(ROOT+"/log/flush_vicenpc.log",now[0..sizeof(now)-2]+":"+tempVicenpc->name_cn+"("+room+")\n");
									vicenpc_ob->move(ROOM_PATH+room);
									vicenpcNeed[vicenpcname]--;
								}
								else
									werror("------can't flush vicenpc : "+vicenpcname+"------\n");
							}
							//else
							//	werror("------get room wrong with roomlevel = "+roomlev+"------\n");
						}
					}
				}
			}
			Stdio.append_file(ROOT+"/log/flush_vicenpc.log","----------------------------\n");
		}
	}
	if(flush_count >= MAX_TIME)
		flush_count = 0;
	call_out(flush_vicenpc,FLUSH_TIME);
}

//怪物被挖了后要设置待刷新怪物的数量
void set_flush_num(string name)
{
	if(!vicenpcNeed[name])
		vicenpcNeed[name] = 1;
	else
		vicenpcNeed[name]++;
}
