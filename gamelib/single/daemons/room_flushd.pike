//控制对房间添加不同功能的刷新
//由caijie开始设计于08/11/24


#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

#define ROOM_PATH ROOT "/gamelib/d/"
#define FLUSH_TIME 900	//刷新时间间隔，15min
private mapping(string:array) exitMap = (["penglaihuanjing/yueyingchanglu":({"dongxue/dlxrukou","dongxue/dlx1","dongxue/dlx2","dongxue/dxl3","dongxue/dlx4","dongxue/dlx5","dongxue/dlx6","dongxue/dlx7","dongxue/dlx8","dongxue/dlx9","dongxue/dlx10","dongxue/dlx11","dongxue/dlx12","dongxue/dlx13","dongxue/dlx14","dongxue/dlx15","dongxue/dlx16","dongxue/dlx17","dongxue/dlx18","dongxue/dlx19","dongxue/dlx20","dongxue/dlx21","dongxue/dlx22","dongxue/dlx23","dongxue/dlxdiceng","dongxue/tldrukou","dongxue/tld1","dongxue/tld2","dongxue/tld3","dongxue/tld4","dongxue/tld5","dongxue/tld6","dongxue/tld7","dongxue/tld8","dongxue/tld9","dongxue/tld10","dongxue/tld11","dongxue/tld12","dongxue/tld13","dongxue/tld14","dongxue/tld15","dongxue/tld16","dongxue/tld17","dongxue/tld18","dongxue/tld19","dongxue/tld20","dongxue/tld21","dongxue/tld22","dongxue/tld23","dongxue/tlddiceng"}),]);//记录可以刷出出口的房间文件，包括2级目录,以出口为索引
private mapping(string:string) roomMap = ([]);//记录上一次进行操作的的房间([出口:房间名])

void create()
{
	flush_exit();
}

//为洞穴刷新出口，每隔1小时刷新一次
void flush_exit()
{
	int num = sizeof(exitMap); 
	if(num){
		foreach(indices(exitMap),string eachexit){
			array tmp = exitMap[eachexit];//获得可以刷出出口链接的房间名
			//随机获得一个房间名
			int id = random(sizeof(tmp));
			string roomName = tmp[id];
			object room = (object)(ROOM_PATH + roomName);
			room->desc += "\n[【走出洞穴】:qge74hye "+eachexit+"]\n";//给房间添加出口链接
			//删除原来房间里的出口
			if(sizeof(roomMap)&&sizeof(roomMap[eachexit])){
				string roomTmp = m_delete(roomMap,eachexit);
				object ob = (object)(ROOM_PATH + roomTmp);
				ob->desc -= "\n[【走出洞穴】:qge74hye "+eachexit+"]\n";
			}
			//werror("----exit_link="+room->query_desc()+"--roomName="+room->query_name_cn()+"--\n");
			//记录被刷出出口链接的房间
			roomMap[eachexit] = roomName;
		}
	}
	call_out(flush_exit,FLUSH_TIME);
}
