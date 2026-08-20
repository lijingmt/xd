/**************************************************************************************************************
 *地图搜索控制进程
 *由caijie写于2008/12/25
 *玩家点击地图后, 显示东南西北四个方向的房间最多5个
 ***************************************************************************************************************/


#include <globals.h>
#include <gamelib/include/gamelib.h>
#define NUM 5//当前房间的相邻房间的个数

// ==================== 飞行费用配置 ====================
// 单位：文（100文 = 1金）
// 修改后需要重载mapd守护进程生效

// ┌─────────────┬───────────┬──────────────┐
// │  会员等级   │   名称    │   飞行费用   │
// ├─────────────┼───────────┼──────────────┤
private mapping(int:int) vip_fly_fee_config = ([
    0: 0,        // │     0      │  非会员   │  按等级计算   │
    1: 15000,    // │     1      │  水晶会员 │  固定1.5万    │  (150金)
    2: 10000,    // │     2      │  黄金会员 │  固定1万      │  (100金)
    3: 7500,     // │     3      │  白金会员 │  固定7500     │  (75金)
    4: 5000,     // │     4      │  钻石会员 │  固定5千      │  (50金)
	// VIP5-8只增量开放等级与挂机额度，飞行权益沿用钻石档，避免
	// 未配置键被当成0后意外回退到高额的按等级费用。
	5: 5000,
	6: 5000,
	7: 5000,
	8: 5000,
]);
// └─────────────┴───────────┴──────────────┘

// 等级费用采用连续阶梯，避免50级从20金突然跳到10万金。
// 0-9:1金，10-19:10金，20-49:20金，50-69:50金，
// 70-99:200金，100-149:500金，150-199:1000金，200+:2000金。
private int get_level_fee(int level) {
    if(level < 10) return 100;
    if(level < 20) return 1000;
    if(level < 50) return 2000;
    if(level < 70) return 5000;
    if(level < 100) return 20000;
    if(level < 150) return 50000;
    if(level < 200) return 100000;
    return 200000;
}

// 地图目录和幻境直飞共用服务端费用计算，客户端不能自行指定费用。
int query_player_fly_fee(object me)
{
	int vip_level;
	int vip_fee;
	int level_fee;
	if(!me)
		return 0;
	vip_level = me->query_vip_flag() || 0;
	vip_fee = vip_fly_fee_config[vip_level];
	level_fee = get_level_fee(me->query_level());
	if(vip_fee==0 || level_fee<vip_fee)
		return level_fee;
	return vip_fee;
}

// 最终费用 = min(VIP费用, 等级费用)，取两者中较低的
// ====================================================

private mapping(string:mapping(string:string)) all_map = ([]);
/*
	map=([当前房间英文名:(["east":向东方向的第1个房间-向东方向的第1个房间-...-向东方向的第5个房间,"west":"...","south":"...","north":"..."]),...]);
*/
mapping(string:mapping(string:string)) all_map_list= ([]);
private int is_hidden_map_room_path(string room_path)
{
	return FBD->is_fb_room_path(room_path) ||
		has_prefix(room_path,"timed_event/") ||
		has_prefix(room_path,"/gamelib/d/timed_event/") ||
		has_prefix(room_path,ROOT+"/gamelib/d/timed_event/");
}
mapping(string:string) pinyin_to_cn = ([
	"dongxue":"洞穴",
	"beihai":"北海",
	"jinaodao":"金鳌岛",
	"waihai":"外海",
	"penglaihuanjing":"蓬莱幻境",
	"jiuxiaojiejing":"九霄界境",
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
protected void create()
{
	load_all_map();
}
mapping query_cache_status()
{
	int room_count = 0;
	foreach(indices(all_map_list),string block)
		room_count += sizeof(all_map_list[block] || ([]));
	return ([
		"mode":"resident_map_index",
		"blocks":sizeof(all_map_list),
		"rooms":room_count,
		"direction_entries":sizeof(all_map),
	]);
}
string get_all_map_list(){
	string s="";
	array(string) block_list = indices(all_map_list);
	foreach(block_list,string block){
		foreach(indices(all_map_list[block]),string name_cn ){
			string room_path = all_map_list[block][name_cn];
			if(!is_hidden_map_room_path(room_path))
				s+="["+block+"|"+name_cn+":qge74hye "+room_path+"]\n";
		}
		
	}
	return s;
}
string get_all_kinds_map(){
	string s="";
	array(string) block_list = sort(indices(all_map_list));
	object me = this_player();
	if(!me)
		return s;
	int level = me->query_level();
	int fee = query_player_fly_fee(me);
	string fee_cn = MUD_MONEYD->query_store_money_cn(fee);
	int cross_zone_admin = MANAGERD->is_cross_zone_admin(me->query_name());
	foreach(block_list,string block){
		if(pinyin_to_cn[block] && all_map_list[block] &&
		   sizeof(all_map_list[block])){
			if(block=="jiuxiaojiejing" &&
			   level<ENDGAME_MAP_MIN_LEVEL &&
			   !cross_zone_admin){
				s += "九霄界境（"+ENDGAME_MAP_MIN_LEVEL+
					"级开放）\n";
				continue;
			}
			s+="[支付"+fee_cn+"飞到 "+pinyin_to_cn[block]+":map_display "+block+" "+fee+"]\n";
		}

	}
	return s;
}
string get_sub_map_list(string block){
	string s="";
	if(!all_map_list[block])
		return s;
	foreach(indices(all_map_list[block]),string name_cn ){
		string room_path = all_map_list[block][name_cn];
		if(name_cn!="" && !is_hidden_map_room_path(room_path))
			s+="[飞到："+name_cn+":qge74hye "+room_path+"]\n";
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
			string room_path = block+"/"+realroom;
			string room_file = ROOT+"/gamelib/d/"+block+"/"+realroom;
			Stdio.Stat room_stat = file_stat(room_file);
			if(is_hidden_map_room_path(room_path))
				continue;
			if(!room_stat || room_stat->isdir)
				continue;
			mixed err=catch{
				ob = (object)room_file;
			};
			if(err)
				werror("[MAPD] room catalog load failed: "+block+"/"+
					realroom+"\n");
			if(ob){
				sub_map[ob->name_cn] = room_path;
			}
		}
		all_map_list[block] = sub_map;
	}

}


//查询当前房间的direction方向的下一个房间
object query_next_room(object this_room,string direction){
	object room;
	string room_path;
	if(!this_room || !mappingp(this_room->exits))
		return 0;
	room_path = (this_room->exits)[direction];
	if(room_path&&sizeof(room_path)){
		mixed err = catch{
			room = find_object(room_path);
			if(!room && search(room_path,"#")==-1)
				room = (object)room_path;
		};
	}
	return room;
}

string query_map(object pre_room){
	string room_key = object_name(pre_room);
	if(room_key=="")
		room_key = pre_room->query_name();
	int clone_suffix = search(room_key,"#");
	if(clone_suffix>0)
		room_key = room_key[..clone_suffix-1];
	mapping map_tmp = all_map[room_key];
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
				if(!all_map[room_key]){
					all_map[room_key]=([]);
				}
				if(!all_map[room_key][direction]){
					all_map[room_key][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_key][direction] += "-"+next_room->query_name_cn();
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
				if(!all_map[room_key]){
					all_map[room_key]=([]);
				}
				if(!all_map[room_key][direction]){
					all_map[room_key][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_key][direction] += "-"+next_room->query_name_cn();
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
				if(!all_map[room_key]){
					all_map[room_key]=([]);
				}
				if(!all_map[room_key][direction]){
					all_map[room_key][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_key][direction] += "-"+next_room->query_name_cn();
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
				if(!all_map[room_key]){
					all_map[room_key]=([]);
				}
				if(!all_map[room_key][direction]){
					all_map[room_key][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_key][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
	}
	return s;
}
