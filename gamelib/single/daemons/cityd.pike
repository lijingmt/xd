//阵营级城池的守护程序，主要负责城池的归属，进入城池的判断，城池npc的刷新，城池的攻防管理以及系统通告
//
//核心数据结构:
//1.城池信息表:
// class city; 
//
// mapping(string:city) cityMap 
//
//
//上述结构都是通过读取ROOT/gamelib/data/city.csv中的内容来建立的。
//
//由liaocheng于07/7/17开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define CITY_INFO ROOT "/gamelib/etc/city.info" //城池信息
#define ROOM_PATH ROOT "/gamelib/d/" //房间根目录
#define NOTICE ROOT "/gamelib/etc/servermsg" //公告
#define STORYD_P ROOT "/gamelib/single/daemons/storyd.pike" //公告
#define SAVE_TIME 3600
//#define SAVE_TIME 120 //测试用
#define CLEAN_TIME 120
#define GIVE_BACK 259200 //三天归还城池
//#define GIVE_BACK 120 //三天归还城池,测试用
#define TEMP_ENV ROOT+"/gamelib/d/congxianzhen/xiaomuwu"

class city
{
	//string name; //[0]文件名
	string name_cn;//[1]中文名
	string captured;//[2]被哪个阵营所占领"human" or "monst"
	string rest_room;//[4]死亡后的传送房间
	array(string) need_flush=({});//城战中需要刷新的房间列表,主要是攻城的房间，复活点，仙阵需要根据占领情况而改变的房间等
	int return_time;//记录被占领后的归还时间
}

private mapping(string:city) cityMap = ([]); //物品信息总表

private array(string) city_list = ({"xiqicheng","chaogecheng","tianyecheng","jadhuanjing","klshuanjing",});

private mapping(string:string) city_name_m = (["xiqicheng":"西岐城","chaogecheng":"朝歌城","tianyecheng":"天野城","jadhuanjing":"金鳌岛幻境","klshuanjing":"玉虚宫幻境",]);
private mapping(string:string) race_name_m = (["human":"人类","monst":"妖魔",]);

private mixed xiqi_call_out;//用来记录西岐城自动归还调用call_out返回id
private mixed chaoge_call_out;//用来记录朝歌城自动归还调用call_out返回id
private mixed kls_call_out;//用来记录玉虚宫幻境自动归还调用call_out返回id
private mixed jad_call_out;//用来记录金鳌岛幻境自动归还调用call_out返回id

void create()
{
	load_city_info();
	Stdio.write_file(NOTICE,"");
	give_back_city("xiqicheng","monst");
	give_back_city("chaogecheng","human");
	give_back_city("jadhuanjing","human");
	give_back_city("klshuanjing","monst");
	call_out(save_city_info,SAVE_TIME);
}


void load_city_info()
{
	werror("==========  [CITYD start!]  =========\n");
	cityMap = ([]);
	string cityData = Stdio.read_file(CITY_INFO);
	array(string) lines = cityData/"\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			city tmpCity = city();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 6){
				tmpCity->name_cn = columns[1];
				tmpCity->captured = columns[2];
				tmpCity->rest_room = columns[4];
				tmpCity->return_time = (int)columns[5];
				tmpCity->need_flush = copy_value(columns[3]/"|");
				if(cityMap[columns[0]] == 0)
					cityMap[columns[0]] = tmpCity;
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [CITYD end!]  =========\n");
}

void save_city_info(void|int fg)
{
	string now=ctime(time());
	string writeBack = "";
	foreach(city_list,string city_name){
		if(city_name && sizeof(city_name)){
			city tmp_city = cityMap[city_name];
			if(tmp_city){
				writeBack += city_name+","+tmp_city->name_cn+","+tmp_city->captured+",";
				array(string) tmp_arr = tmp_city->need_flush;
				if(tmp_arr && sizeof(tmp_arr)){
					for(int i=0;i<sizeof(tmp_arr);i++){
						writeBack += tmp_arr[i];
						if(i<sizeof(tmp_arr)-1)
							writeBack += "|";
					}
				}
				writeBack += ","+tmp_city->rest_room+","+tmp_city->return_time+"\n";
			}
		}
	}
	mixed err=catch
	{
		Stdio.write_file(CITY_INFO,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/city.log",now[0..sizeof(now)-2]+":rewrite city.info failed\n");
	}
	if(!fg)
		call_out(save_city_info,SAVE_TIME);
}

string query_captured(string city_name)
{
	city tmp_city = cityMap[city_name];
	if(tmp_city){
		return tmp_city->captured;
	}
	else
		return "";
}

int capture_city(string city_name,string race,string notice)
{
	city tmp_city = cityMap[city_name];
	if(tmp_city){
		tmp_city->captured = race;
		if(city_name=="xiqicheng"&&race=="human"){
			tmp_city->return_time = 0;
			if(find_call_out(xiqi_call_out))
				remove_call_out(xiqi_call_out);
		}
		else if(city_name=="chaogecheng"&&race=="monst"){
			tmp_city->return_time = 0;
			if(find_call_out(chaoge_call_out))
				remove_call_out(chaoge_call_out);
		}
		else if(city_name=="klshuanjing"&&race=="human"){
			tmp_city->return_time = 0;
			if(find_call_out(kls_call_out))
				remove_call_out(kls_call_out);
		}
		else if(city_name=="jadhuanjing"&&race=="monst"){
			tmp_city->return_time = 0;
			if(find_call_out(jad_call_out))
				remove_call_out(jad_call_out);
		}
		flush_city(city_name);
		notice_update(notice);
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/city_captured.log",now[0..sizeof(now)-2]+":"+notice+"\n");
		return 1;
	}
	return 0;
}

//自动归还城池
//city_name：城池名，race：攻占方的阵营
void give_back_city(string city_name,string race)
{
	string notice = "";
	string city_name_cn = query_city_namecn(city_name);
	string owner = "monst";
	string owner_cn = "妖魔";
	if(race == "monst"){
		owner = "human";
		owner_cn = "人类";
	}
	city tmp_city = cityMap[city_name];
	if(tmp_city && tmp_city->return_time>0){
		int time_remain = tmp_city->return_time - time();
		if(time_remain > 0){
			if(city_name=="chaogecheng"){
				if(find_call_out(chaoge_call_out))
					remove_call_out(chaoge_call_out);
				chaoge_call_out = call_out(capture_city,time_remain,city_name,owner,notice);
			}
			else if(city_name=="xiqicheng"){
				if(find_call_out(xiqi_call_out))
					remove_call_out(xiqi_call_out);
				xiqi_call_out = call_out(capture_city,time_remain,city_name,owner,notice);
			}
			else if(city_name=="klshuanjing"){
				if(find_call_out(kls_call_out))
					remove_call_out(kls_call_out);
				kls_call_out = call_out(capture_city,time_remain,city_name,owner,notice);
			}
			else if(city_name=="jadhuanjing"){
				if(find_call_out(jad_call_out))
					remove_call_out(jad_call_out);
				jad_call_out = call_out(capture_city,time_remain,city_name,owner,notice);
			}
		}
		else{
			notice = "战况："+city_name_cn+"已自动归还给"+owner_cn+"阵营\n";
			capture_city(city_name,owner,notice);
		}
	}
	return;
}

//设置自动归还的时间
void set_giveback_time(string city_name)
{
	city tmp_city = cityMap[city_name];
	if(tmp_city){
		tmp_city->return_time = time()+GIVE_BACK;
	}
	return;
}

//清除自动归还的时间，主要用于在归还期内夺回城池
void clean_giveback_time(string city_name)
{
	city tmp_city = cityMap[city_name];
	if(tmp_city){
		tmp_city->return_time = 0;
	}
	return;
}

void flush_city(string city_name)
{
	city tmp_city = cityMap[city_name];
	if(tmp_city){
		array(string) tmp_arr = tmp_city->need_flush;
		foreach(tmp_arr,string room){
			if(room && sizeof(room)){
				string file = ROOM_PATH+room;
				city_update(file);
			}
		}
	}
}

int city_update(string file)
{
	object obj,env,usr;
	array oblist;
	object ob;
	mixed err1 = catch{
		ob = find_object(file);
	};
	if(err1){
		return 0;
	}
	if(ob && ob->is_room){
		env = find_object(TEMP_ENV);
		oblist = all_inventory(ob);
		if(!env) env = load_object(TEMP_ENV);
		if(!env){
			werror("----- city_update wrong TEMP_ENV not exist!!-----\n");
			return 1;
		}
		foreach(oblist,usr){
			if( (usr->is_character && !usr->is_npc) || usr->query_name()=="bingfusuipian")//player move to kezhan
			{
				usr->move(env);
			}
			else{//remove npc&items
				oblist-=({usr});
				usr->remove();
			}
		}
	}
	mixed err=catch{
		compile_file(file);
	};
	if(err){
		werror("----- city_update wrong with compile_file(file)!!-----\n");
		return 1;
	}
	update(file);//defined in efuns
	env = find_object(file);
	if(env && env->is_room && sizeof(oblist)){
		foreach(oblist,usr){
			if( (usr->is_character && !usr->is_npc) || usr->query_name()=="bingfusuipian")
			{
				usr->move(env);
			}
		}
	}
	return 1;
}

int notice_update(string s)
{
	Stdio.write_file(NOTICE,s);
	update_storyd();
	if(find_call_out(notice_clean))
		remove_call_out(notice_clean);
	call_out(notice_clean,CLEAN_TIME);
	return 1;
}

void notice_clean()
{
	string writeTo = "";
	Stdio.write_file(NOTICE,writeTo);
	update_storyd();
}

void update_storyd()
{
	mixed err=catch{
		compile_file(STORYD_P);
	};
	if(err){
		werror("----- notice_update wrong with compile_file(file)!!-----\n");
		return;
	}
	update(STORYD_P);//defined in efuns
	return;
}

string query_city_namecn(string city_name)
{
	if(city_name_m[city_name])
		return city_name_m[city_name];
	else
		return "";
}
string query_rest_room(string city_name)
{
	city tmp_city = cityMap[city_name];
	if(tmp_city && sizeof(tmp_city))
		return ROOM_PATH+tmp_city->rest_room;
	else
		return "";
} 
