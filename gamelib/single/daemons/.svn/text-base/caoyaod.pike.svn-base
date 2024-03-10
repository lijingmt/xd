//草药的守护程序，主要负责建立和维护游戏中草药的信息表，包括草药的刷新个数，刷新时间，草药出现的地图等级，草药的出产物等，并且还要负责草药在游戏世界的刷新
//
//核心数据结构:
//1.草药信息表:
// class caoyao; 打算采用类来记录草药的信息 
//
// 下面这个mapping作为备用方案
// mapping(string:array(mixed)) caoyao_m = 
//   (["tongcaoyao":({"草药名",刷新数量,刷新时间(以分钟为单位),地图最低等级，地图最高等级，需要熟练度})
//                    [0]     [1]           [2]                 [3]            [4]          [5]
//       ...
//   ])
//2.草药产出物表，该表记录玩家采药时，可能获得的物品，虽然采药一般不会获得其他物品，但接口还是留在这儿:
// mapping(string:mapping(string:int)) get_m = 
//   (["tongcaoyao":(["tongcaoyaoshi":100,"xuanhuangshi":10,]),
//                     出产物名  :  概率
//      ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/caoyao.csv中的内容来建立的。
//
//由liaocheng于07/5/25开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define CAOYAO_CSV ROOT "/gamelib/data/material/caoyao.csv" //草药物列表
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下
#define ROOM_PATH ROOT "/gamelib/d/" //房间根目录
//#define FLUSH_TIME 900
//草药的刷新时间比较多样性，这也是这个守护模块的难点
//#define FLUSH_TIME 120 //测试用，循环执行flush_caoyao()的时间间隔
#define FLUSH_TIME 900 //正式用，15分钟为一单位
#define MAX_TIME 360  //刷新时间最长的草药的刷新时间

class caoyao
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

private mapping(string:caoyao) caoyaoMap = ([]); //物品信息总表
private mapping(string:int) caoyaoNeed = ([]); //记录目前需要刷的草药数量
private mapping(string:array) quick_flush = ([]); //快速刷草药,在固定地点刷出草药,在caoyao_flush中被赋值
//([caoyao_name:({time,房间1,房间2,房间3....})])
private mapping(int:array(string)) caoyao_flush_time = ([]);//以刷新时间为索引的映射表,时间为15分钟的倍数
//([15:({caoyao1,caoyao2}),
//  30:({caoyao3,caoyao5}), 
// ...
//  ])
private int flush_count = 0;

void create()
{
	load_csv();
	flush_caoyao();
	//call_out(flush_caoyao,FLUSH_TIME);
}

void load_csv()
{
	caoyaoMap = ([]);
	caoyaoNeed = ([]);
	caoyao_flush_time = ([]);
	string caoyaoData = Stdio.read_file(CAOYAO_CSV);
	array(string) lines = caoyaoData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			caoyao tmpCaoyao = caoyao();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 8){
				tmpCaoyao->name_cn = columns[1];
				tmpCaoyao->nums = (int)columns[2];
				tmpCaoyao->flush_time = (int)columns[3];
				//写入到刷新时间表中
				if(caoyao_flush_time[tmpCaoyao->flush_time] == 0)
					caoyao_flush_time[tmpCaoyao->flush_time] = ({columns[0]});
				else
					caoyao_flush_time[tmpCaoyao->flush_time] += ({columns[0]});
				tmpCaoyao->mLevel_min = (int)columns[4];
				tmpCaoyao->mLevel_max = (int)columns[5];
				tmpCaoyao->skill_level = (int)columns[6];
				array(string) tmpGets = columns[7]/"|";
				foreach(tmpGets,string eachget){
					if(eachget && sizeof(eachget)){
						array(string) tmp = eachget/":";
						int prob = (int)tmp[1];
						tmpCaoyao->get_m += ([tmp[0]:prob]);
					}
				}
				if(caoyaoMap[columns[0]] == 0)
					caoyaoMap[columns[0]] = tmpCaoyao;
				caoyaoNeed[columns[0]] = (int)columns[2];
			}
			else
				werror("------size of columns wrong in load_csv() of caoyaod.pike------\n");
		}
	}
	else 
		werror("------read caoyao.csv wrong in gamelib/single/daemon/caoyaod.pike------\n");
}


//刷新草药的接口
void flush_caoyao()
{
	flush_count += 15; //刷新时间是15的倍数
	string now=ctime(time());
	foreach(indices(caoyao_flush_time),int time){
		if(flush_count%time == 0){
		//到刷新时间了
			array(string) tmp_flush = caoyao_flush_time[time];
			if(tmp_flush && sizeof(tmp_flush)){
				int size = sizeof(tmp_flush);
				for(int i=0;i<size;i++){
					string caoyaoname = tmp_flush[i];
					if(caoyaoNeed[caoyaoname]){
						int need_num = caoyaoNeed[caoyaoname];
						Stdio.append_file(ROOT+"/log/flush_caoyao.log",now[0..sizeof(now)-2]+":此次刷新 "+caoyaoname+" "+need_num+"株\n");
						caoyao tempCaoyao = caoyaoMap[caoyaoname];
						int roomlev_h = tempCaoyao->mLevel_max;
						int roomlev_l = tempCaoyao->mLevel_min;
						for(int j=0;j<need_num;j++){
							int roomlev = roomlev_l+random(roomlev_h-roomlev_l+1);
							string room = ROOMLEVELD->query_room(roomlev);
							if(room != ""){
								object caoyao_ob = clone(MATERIAL_PATH+caoyaoname);
								if(caoyao_ob){
									Stdio.append_file(ROOT+"/log/flush_caoyao.log",now[0..sizeof(now)-2]+":"+tempCaoyao->name_cn+"("+room+")\n");
									caoyao_ob->move(ROOM_PATH+room);
									caoyaoNeed[caoyaoname]--;
								}
								else
									werror("------can't flush caoyao : "+caoyaoname+"------\n");
							}
							//else
							//	werror("------get room wrong with roomlevel = "+roomlev+"------\n");
						}
					}
				}
			}
			Stdio.append_file(ROOT+"/log/flush_caoyao.log","----------------------------\n");
		}
	}
	if(flush_count >= MAX_TIME)
		flush_count = 0;
	call_out(flush_caoyao,FLUSH_TIME);
}

//获得需要采药熟练度的接口
int query_need_level(string name)
{
	caoyao tempCaoyao = caoyaoMap[name];
	if(tempCaoyao){
		return tempCaoyao->skill_level;	
	}
	else 
		return -1;

}

//获得出产物映射表的接口
mapping(string:int) query_get_m(string name)
{
	mapping(string:int) m_rtn = ([]);
	caoyao tempCaoyao = caoyaoMap[name];
	if(tempCaoyao && sizeof(tempCaoyao->get_m)){
		m_rtn = tempCaoyao->get_m;
	}
	return m_rtn;
}

//草药被挖了后要设置待刷新草药的数量
void set_flush_num(string name)
{
	if(!caoyaoNeed[name])
		caoyaoNeed[name] = 1;
	else
		caoyaoNeed[name]++;
}
