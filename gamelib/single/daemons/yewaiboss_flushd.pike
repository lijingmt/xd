//控制野外boss在游戏世界中的刷新
//由caijie开始设计于08/05/21


#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define BOSSROOM_CSV ROOT+"/gamelib/data/ywboss_room.csv"  //野外boss刷新地点列表
#define BOSS_PATH ROOT+"/gamelib/clone/npc/boss/"  //所有野外boss都放在该目录下
#define ROOM_PATH ROOT+"/gamelib/d/" //房间根目录
#define FLUSH_TIME 43200 //刷新间隔时间


private mapping(string:int) boss_die_time = ([]); //记录boss的死亡时间，以boss名称为索引
private mapping(string:array(string)) room_name = ([]);//记录可刷boss的房间列表, 如([taorong:({kunlunshan/fenxianlu,..})])
//private array(string) new_boss = ({});//记录要刷新的boss


void create()
{
	load_csv();
	flush_boss();
}

void load_csv()
{
	boss_die_time = ([]);
	room_name = ([]);
	string bossData = Stdio.read_file(BOSSROOM_CSV);
	array(string) lines = bossData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/",";
			if(sizeof(columns)>=2){
				array(string) tmpRoom = columns[1]/"|";
				if(!room_name[columns[0]]){
					room_name[columns[0]] = tmpRoom;
				}
				boss_die_time[columns[0]]=0;
			}
			else {
				werror("------size of columns wrong in load_csv() of yewaiboss_flushd.pike------\n");
			}
		}
	}
	else {
		werror("------read ywboss_room.csv wrong in gamelib/single/daemon/yewaiboss_flushd.pike------\n");
	}
}


//记录boss死亡时间
void get_boss_die_time(string bossName)
{
	int dieTime = time();
	if(!boss_die_time){
		boss_die_time = ([]);
	}
	boss_die_time[bossName] = dieTime;
}


//刷新boss接口
void flush_boss()
{
	//以死亡列表为标准判断该boss是否要刷新，开始建表时所有boss的死亡时间为0，如果列表中存在boss，则检查该boss的死亡时间
	//若死亡时间为零或者时间相差大于12小时则把boss刷到地图中，否则否则不做任何处理，当boss被刷到地图中后死亡列表中boss的相应信息也被删除，
	array(string) boss = indices(boss_die_time);
	string now=ctime(time());
	if(boss){
		foreach(boss,string eachboss){
			if(boss_die_time[eachboss]==0||(time() - boss_die_time[eachboss])>=FLUSH_TIME){
				object boss_ob = clone(BOSS_PATH + eachboss);
				if(boss_ob){
					int room_num = sizeof(room_name[eachboss]);
					if(room_num){
						int i = random(room_num);
						string room = room_name[eachboss][i];
						object room_ob = (object)(ROOM_PATH+room);
						if(room!=""){
							boss_ob->move(ROOM_PATH + room);
							m_delete(boss_die_time,eachboss);
							Stdio.append_file(ROOT+"/log/flush_boss.log",now[0..sizeof(now)-2]+":flush:"+eachboss+" in "+room+"\n");
						}
						else 
							werror("----------that is no right room---------\n");
					}
					else 
						werror("-------the mathod find_room in roomLeveld.pike must be wrong!---\n");
				}
			}
		}
	}
	call_out(flush_boss,1800);//半个小时检查一次
	//call_out(flush_boss,30);
}


//分配房间
/*
string allocate(string route,int room_num){
	int i = random(room_num);
	int flag = 0;
	string room = room_name[route][i];
	object room_ob = (object)(ROOM_PATH+room);
	array(object) all_npc = all_inventory(room_ob);
	foreach(all_npc,object ob){
		if(ob->_boss==3){
			allocate(route,room_num);
			flag = 1;
			break;
		}
		else flag = 0;
	}
	if(flag==0){
		return room;
	}
}
*/

