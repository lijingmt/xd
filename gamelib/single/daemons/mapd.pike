/**************************************************************************************************************
 *地图搜索控制进程
 *由caijie写于2008/12/25
 *玩家点击地图后, 显示东南西北四个方向的房间最多5个
 ***************************************************************************************************************/


#include <globals.h>
#include <gamelib/include/gamelib.h>
#define NUM 5//当前房间的相邻房间的个数

private mapping(string:mapping(string:string)) all_map = ([]);
/*
	map=([当前房间英文名:(["east":向东方向的第1个房间-向东方向的第1个房间-...-向东方向的第5个房间,"west":"...","south":"...","north":"..."]),...]);
*/
mapping(string:mapping(string:string)) all_map_list= ([]);
mapping(string:string) pinyin_to_cn = ([
	"dongxue":"洞穴",
	"beihai":"北海",
	"jinaodao":"金鳌岛",
	"waihai":"外海",
	"penglaihuanjing":"蓬莱幻境",
	"bawangbao":"霸王暗巷",
	"plshuige":"蓬莱水阁",
	"fuxishan":"伏羲山",
	"huangjiazhuang":"黄家庄",
	"jiulongdao":"九龙岛",
	"yeguangxiagu":"夜光峡谷",
	"liangjinghu":"两镜湖",
	"shierxianjin":"十二仙境",
	"chaogewaicheng":"朝歌外城",
	"liefengcun":"冽风村",
	"jadhuanjing":"翡翠幻境",
	"minglingzhihai":"冥灵之海",
	"chaogecheng":"朝歌城",
	"klshuanjing":"昆仑仙境",
	"donghai":"东海",
	"qingshuilindi":"清水林地",
	"jiangjunmu":"将军墓",
	"muye":"牧业",
	"yunshuixianjing":"云水仙境",
	"liuguangpingyuan":"流光平原",
	"shanyaohaiwan":"闪耀海湾",
	"paimh":"拍卖行",
	"xiqiwaicheng":"西岐外城",
	"huanyecun":"幻夜村",
	"jadhuanjingwaicheng":"羽化村",
	"yunraotiangong":"云绕天宫",
	"fushoushan":"福寿山",
	"nanhai":"南海",
	"wugongdong":"蜈蚣洞",
	"mihuandao":"迷幻岛",
	"bwmk":"魔王巢穴",
	"kunlunshan":"昆仑山",
	"jingyushanzhuang":"静语山庄",
	"youanzaoze":"幽暗沼泽",
	"klshuanjingwaicheng":"昆仑仙境外城",
	"bishuitan":"碧水潭",
	"shierxianjing":"十二仙境",
	"xiqicheng":"西岐城",
	"mf":"冥府",
	"tianyecheng":"天野城",
	"guangmaoyuan":"广袤园",
	"autolearn":"打坐区",
	"chenjichaoze":"沉寂沼泽",
	"huyaodong":"狐妖洞",
	"huangyuan":"荒原",
	"jiaolong":"蛟龙",
	"konglingshangu":"空灵山谷",
	"kulougang":"骷髅港",
	"langhaodongxue":"狼嚎洞穴",
	"liehuoying":"烈火营",
	"lvxue":"绿血幻境",
	"ninggedian":"宁歌殿",
	"plxianjing":"蓬莱仙境",
	"sigumudi":"死谷墓地",
	"wujinchangqiao":"无尽长桥",
	"xihai":"西海",
	"xinnian_fb":"年兽副本",
	"yandigu":"炎帝谷",
	"yl":"炎帝谷",
	"youanzhaoze":"幽暗沼泽",
	"yandigu":"飞花古道",
	"zhongnanshan":"终南山",
	"congxianzhen":"从仙镇",
	"dwgy":"鬼王石门",
	"lvxie":"绿血洞",


]);
void create()
{
	load_all_map();
}
string get_all_map_list(){
	string s="";
	array(string) block_list = indices(all_map_list);
	foreach(block_list,string block){
		foreach(indices(all_map_list[block]),string name_cn ){
			s+="["+block+"|"+name_cn+":qge74hye "+all_map_list[block][name_cn]+"]\n";
		}
		
	}
	return s;
}
string get_all_kinds_map(){
	string s="";
	array(string) block_list = sort(indices(all_map_list));
	foreach(block_list,string block){
		if(pinyin_to_cn[block]){
			int fee = 1000000;
			if(this_player()->query_level()>100)	
				fee = 10000000;	
			else if(this_player()->query_level()>50){
				fee = 1000000;	
			}else{
				fee = 1000;
			}
			string fee_cn =MUD_MONEYD->query_store_money_cn(fee);
			s+="[支付"+fee_cn+"飞到 "+pinyin_to_cn[block]+":map_display "+block+" "+fee+"]\n";
		}	

	}
	return s;
}
string get_sub_map_list(string block){
	string s="";
	foreach(indices(all_map_list[block]),string name_cn ){
		if(name_cn!="")
		s+="[飞到："+name_cn+":qge74hye "+all_map_list[block][name_cn]+"]\n";
	}
	return s;
}
void load_all_map(){
	array(string) map_index_list = get_dir(ROOT + "/gamelib/d/");
	foreach(map_index_list,string block){
		mapping(string:string) sub_map =([]);// 中文名字，和对应的房间路径
		array(string) sub_map_index_list = get_dir(ROOT + "/gamelib/d/"+block);
		if(!sub_map_index_list) continue;
		foreach(sub_map_index_list,string realroom){
			object ob;
			werror("=======try to load room:"+realroom+"\n");
			mixed err=catch{
				ob = (object)(ROOT + "/gamelib/d/"+block+"/"+realroom);
			};
			if(err)werror("=======try to load room error:"+realroom+"\n");
			if(ob){
				sub_map[ob->name_cn] = block+"/"+realroom;
				werror("=======load map:"+ob->name_cn + ":"+sub_map[ob->name_cn]+"\n");
			}
		}
		all_map_list[block] = sub_map;
	}

}


//查询当前房间的direction方向的下一个房间
object query_next_room(object this_room,string direction){
	object room;
	string room_path = (this_room->exits)[direction];
	if(room_path&&sizeof(room_path)){
		mixed err = catch{
			room = clone(room_path);
		};
	}
	return room;
}

string query_map(object pre_room){
	string room_name = pre_room->query_name();
	mapping map_tmp = all_map[room_name];
	string s = "";
	if(map_tmp&&sizeof(map_tmp)){
		string dire_desc = map_tmp["north"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "北↑："+dire_desc+"\n";
		}
		dire_desc = map_tmp["west"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "西←："+dire_desc+"\n";
		}
		dire_desc = map_tmp["east"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "东→："+dire_desc+"\n";
		}
		dire_desc = map_tmp["south"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "南↓："+dire_desc+"\n";
		}
	}
	else{
		//进行搜索
		object next_room,tmp_room;
		string direction = "north";
		//北
		s += "北↑：";
		tmp_room = pre_room;
		for(int i=0;i<NUM;i++){
			next_room = query_next_room(tmp_room,direction);
			if(!next_room){
				break;
			}
			else{
				if(!all_map[room_name]){
					all_map[room_name]=([]);
				}
				if(!all_map[room_name][direction]){
					all_map[room_name][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_name][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
		direction = "west";
		s += "西←：";
		tmp_room = pre_room;
		for(int i=0;i<NUM;i++){
			next_room = query_next_room(tmp_room,direction);
			if(!next_room){
				break;
			}
			else{
				if(!all_map[room_name]){
					all_map[room_name]=([]);
				}
				if(!all_map[room_name][direction]){
					all_map[room_name][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_name][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
		direction = "east";
		s += "东→：";
		tmp_room = pre_room;
		for(int i=0;i<NUM;i++){
			next_room = query_next_room(tmp_room,direction);
			if(!next_room){
				break;
			}
			else{
				if(!all_map[room_name]){
					all_map[room_name]=([]);
				}
				if(!all_map[room_name][direction]){
					all_map[room_name][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_name][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
		direction = "south";
		s += "南↓：";
		tmp_room = pre_room;
		for(int i=0;i<NUM;i++){
			next_room = query_next_room(tmp_room,direction);
			if(!next_room){
				break;
			}
			else{
				if(!all_map[room_name]){
					all_map[room_name]=([]);
				}
				if(!all_map[room_name][direction]){
					all_map[room_name][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_name][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
	}
	return s;
}
