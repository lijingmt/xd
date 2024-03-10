//帮战和帮派排行榜守护程序，维护帮战的主要数据结构，算法。帮派的排行也在这里
//
//核心数据结构:
//1.帮战登记信息表，在表上的帮派可以在中立地区互相杀戮:
// mapping(int:int) bangzhan;//bangid:1 
//
//2.帮派排行表
// 
//
//上述结构将回写到ROOT/gamelib/data/bangzhan.info以保存信息。
//
//由liaocheng于07/8/27开始设计开发

#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_DAEMON;
#define BANGZHAN_INFO ROOT "/gamelib/etc/bangzhan.info" //帮战信息
#define SAVE_TIME 3600
#define UPDATE_TIME 86400 //更新时间间隔为24小时

private mapping(int:int) Bangzhan = ([]); //帮战登记表
private array(int) top_list = ({});//帮排行数组
private int open_fg = 1; //标识是否开放帮战幻境，1-开放，0-不开放


void create()
{
	load_bangzhan_info();
	update_bang_toplist(1);
	if(sizeof(top_list) && Bangzhan[top_list[0]]==1)
		open_fg = 0;

	mapping(string:int) now_time = localtime(time());
	int now_mday = now_time["mday"];
	int now_mon = now_time["mon"];
	int now_year = now_time["year"];
	//得到启动后第一次自动更新排行榜的时间
	int update_time = mktime(60,59,23,now_mday,now_mon,now_year);
	//由此获得距离现在还有多少时间更新
	int need_time = update_time - time();
	call_out(update_bang_toplist,need_time);

	call_out(save_bangzhan_info,SAVE_TIME);
}

void load_bangzhan_info()
{
	werror("------load bangzhan.info in gamelib/single/daemon/bangzhand.pike------\n");
	Bangzhan = ([]);
	string bzData = Stdio.read_file(BANGZHAN_INFO);
	array(string) lines = bzData/"\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/":";
			if(sizeof(columns) == 2){
				Bangzhan[(int)columns[0]] = (int)columns[1];
			}
			else
				werror("------size of columns wrong in load_load_bangzhan_info() of bangzhand.pike------\n");
		}
	}
	else 
		werror("------read bangzhan.info null in gamelib/single/daemon/bangzhand.pike------\n");
}

void save_bangzhan_info(void|int fg)
{
	string now=ctime(time());
	string writeBack = "";
	foreach(indices(Bangzhan),int bangid){
		if(bangid)
			writeBack += bangid+":"+Bangzhan[bangid]+"\n";
	}
	mixed err=catch
	{
		Stdio.write_file(BANGZHAN_INFO,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/bangzhan.log",now[0..sizeof(now)-2]+":rewrite bangzhan.info failed\n");
	}
	if(!fg)
		call_out(save_bangzhan_info,SAVE_TIME);
}

//申请加入帮战的接口
//参数为bangid
//返回  1-成功 2-重复申请 0-帮派错误
int add_new_bang(int bangid)
{
	if(BANGD->if_is_bang(bangid)){
		if(Bangzhan[bangid])
			return 2;
		else{
			Bangzhan[bangid]=1;
			string now=ctime(time());
			string s_log = "：<"+BANGD->query_bang_name(bangid)+">("+bangid+")加入了帮战！\n";
			Stdio.append_file(ROOT+"/log/bangzhan.log",now[0..sizeof(now)-2]+s_log);
			return 1;
		}
	}
	else
		return 0;
}

//退出帮战的接口
//参数为bangid
//返回  1-成功 2-不在帮战中 0-帮派错误
int quit_bangzhan(int bangid)
{
	if(Bangzhan[bangid]){
		m_delete(Bangzhan,bangid);
		string now=ctime(time());
		string s_log = "：<"+BANGD->query_bang_name(bangid)+">("+bangid+")退出了帮战！\n";
		Stdio.append_file(ROOT+"/log/bangzhan.log",now[0..sizeof(now)-2]+s_log);
		return 1;
	}
	else
		return 2;
}

//判断是否在帮站列表中的接口
//参数：bangid
//返回：0-不在 1-在
int if_in_bangzhan(int bangid)
{
	if(Bangzhan[bangid])
		return 1;
	else
		return 0;
}

//获得参与帮战的帮派列表
//返回：帮派id组成的数组
array(int) query_bangzhan_list()
{
	array(int) rtn = ({});
	rtn = sort(indices(Bangzhan));
	if(rtn && sizeof(rtn))
		return rtn;
	else 
		return 0;
}

//判断是否在帮战之中
//参数：敌人的bangid , 自己的bangid
//返回：1-在  0-不在
int is_in_bangzhan(int bangid1,int bangid2)
{
	if(bangid1 == bangid2)
		return 0;
	if(Bangzhan[bangid1] && Bangzhan[bangid2])
		return 1;
	else
		return 0;
}

//帮获得霸气的接口
//参数：敌人object,自己(死亡者的)object
//返回：获得的霸气值
int get_baqi(object enemy,object me)
{
	if(!me||!enemy||me->query_level()<25){
		return 0;
	}
	int gain_baqi = 0;
	int flag = 1;
	if(enemy["/plus/daily/honer_map"]&&sizeof(enemy["/plus/daily/honer_map"])){
		//轮训看击杀者是否在曾经击杀过该玩家的映射表中
		foreach(indices(enemy["/plus/daily/honer_map"]),string enemyid){
			//被该敌对玩家有过击杀记录，看记录次数，得到应给的霸气值
			if(enemyid == me->query_name()){
				string htype = (string)enemy["/plus/daily/honer_map"][enemyid]; 
				if(htype=="a"){
					gain_baqi = (int)(me->query_level()*3/4);
					//给了击杀者霸气值之后，需要将击杀记录增加到下一个等级
					enemy["/plus/daily/honer_map"][me->query_name()] = "b";
				}
				else if(htype=="b"){
					gain_baqi = (int)(me->query_level()*1/2);
					enemy["/plus/daily/honer_map"][me->query_name()] = "c";
				}
				else if(htype=="c"){
					gain_baqi = (int)(me->query_level()*1/4);
					enemy["/plus/daily/honer_map"][me->query_name()] = "d";
				}
				else if(htype=="d"){
					gain_baqi = 0;	
					enemy["/plus/daily/honer_map"][me->query_name()] = "d";
				}
				flag = 0;//被击杀记录中有敌人的纪录
				break;
			}
		}
		//该玩家第一次被敌人击杀，记录击杀者到映射表，并给击杀者应得荣誉值
		if(flag){
			enemy["/plus/daily/honer_map"][me->query_name()] = "a";
			gain_baqi = me->query_level();
		}
	}
	else{
		enemy["/plus/daily/honer_map"][me->query_name()] = "a";
		gain_baqi = me->query_level();
	}
	if(gain_baqi && Bangzhan[enemy->bangid]){
		if(enemy->query_raceId() != me->query_raceId())                                                   
			gain_baqi = gain_baqi*3;
		Bangzhan[enemy->bangid] += gain_baqi;
	}
	return gain_baqi;
}

//获得排行的帮派id数组接口
array(int) get_top_list()
{
	return top_list;
}

//对帮派进行排序的接口
void update_bang_toplist(void|int fg)
{
	top_list = indices(Bangzhan);
	if(top_list && sizeof(top_list)){
		quick_sort(top_list,0,sizeof(top_list)-1);
		string now=ctime(time());
		string s_log = "：开始更新排行榜\n";
		Stdio.append_file(ROOT+"/log/bangzhan.log",now[0..sizeof(now)-2]+s_log);
	}
	if(!fg){
		open_fg++;
		call_out(update_bang_toplist,UPDATE_TIME);
	}
	return;
}
void quick_sort(array arr,int left,int right)
{
	int l = left;
	int r = right;
	int pos = get_pos(arr,l,r);
	if(pos >= 0){
		int pos_val = Bangzhan[arr[pos]];
		while(l < r){
			while(Bangzhan[arr[l]] >= pos_val)
				l++;
			while(Bangzhan[arr[r]] < pos_val)
				r--;
			if(l < r){
				int tmp = arr[l];
				arr[l] = arr[r];
				arr[r] = tmp;
				l++;
				r--;
			}
			else
				break;
		}
		quick_sort(arr,left,r);
		quick_sort(arr,l,right);
	}
}
int get_pos(array arr,int l,int r)
{
	int rtn = l+1;
	while(rtn <= r){
		if(Bangzhan[arr[rtn]] > Bangzhan[arr[l]])
			return rtn;
		else if(Bangzhan[arr[rtn]] < Bangzhan[arr[l]])
			return l;
		else rtn++;
	}
	return -1;
}

//获得帮霸气的接口
int query_bang_baqi(int bangid)
{
	if(Bangzhan[bangid])
		return Bangzhan[bangid];
	else
		return 0;
}

//获得指定排名的帮id
int query_top_bang(int no)
{
	int i = no-1;
	if(top_list[i])
		return top_list[i];
	else
		return 0;
}

//重置各个帮的霸气，开始新一轮的帮战                                                                              
void bangzhan_restart()
{
	foreach(indices(Bangzhan),int bangid){
		if(bangid)
			Bangzhan[bangid] = 1;
	}
	return;
}

//查询帮战幻境开放标识
int query_open_fg()
{
	return open_fg;
}
