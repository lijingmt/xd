/**************************************************************************************************************
 *��ͼ�������ƽ���
 *��caijieд��2008/12/25
 *��ҵ����ͼ��, ��ʾ���������ĸ�����ķ������5��
 ***************************************************************************************************************/


#include <globals.h>
#include <gamelib/include/gamelib.h>
#define NUM 5//��ǰ��������ڷ���ĸ���

private mapping(string:mapping(string:string)) all_map = ([]);
/*
	map=([��ǰ����Ӣ����:(["east":�򶫷���ĵ�1������-�򶫷���ĵ�1������-...-�򶫷���ĵ�5������,"west":"...","south":"...","north":"..."]),...]);
*/
mapping(string:mapping(string:string)) all_map_list= ([]);
mapping(string:string) pinyin_to_cn = ([
	"dongxue":"��Ѩ",
	"beihai":"����",
	"jinaodao":"������",
	"waihai":"�⺣",
	"penglaihuanjing":"�����þ�",
	"bawangbao":"��������",
	"plshuige":"����ˮ��",
	"fuxishan":"����ɽ",
	"huangjiazhuang":"�Ƽ�ׯ",
	"jiulongdao":"������",
	"yeguangxiagu":"ҹ��Ͽ��",
	"liangjinghu":"������",
	"shierxianjin":"ʮ���ɾ�",
	"chaogewaicheng":"�������",
	"liefengcun":"�����",
	"jadhuanjing":"���þ�",
	"minglingzhihai":"ڤ��֮��",
	"chaogecheng":"�����",
	"klshuanjing":"�����ɾ�",
	"donghai":"����",
	"qingshuilindi":"��ˮ�ֵ�",
	"jiangjunmu":"����Ĺ",
	"muye":"��ҵ",
	"yunshuixianjing":"��ˮ�ɾ�",
	"liuguangpingyuan":"����ƽԭ",
	"shanyaohaiwan":"��ҫ����",
	"paimh":"������",
	"xiqiwaicheng":"������",
	"huanyecun":"��ҹ��",
	"jadhuanjingwaicheng":"�𻯴�",
	"yunraotiangong":"�����칬",
	"fushoushan":"����ɽ",
	"nanhai":"�Ϻ�",
	"wugongdong":"��򼶴",
	"mihuandao":"�Իõ�",
	"bwmk":"ħ����Ѩ",
	"kunlunshan":"����ɽ",
	"jingyushanzhuang":"����ɽׯ",
	"youanzaoze":"�İ�����",
	"klshuanjingwaicheng":"�����ɾ����",
	"bishuitan":"��ˮ̶",
	"shierxianjing":"ʮ���ɾ�",
	"xiqicheng":"��᪳�",
	"mf":"ڤ��",
	"tianyecheng":"��Ұ��",
	"guangmaoyuan":"����԰",
	"autolearn":"������",
	"chenjichaoze":"��������",
	"huyaodong":"������",
	"huangyuan":"��ԭ",
	"jiaolong":"����",
	"konglingshangu":"����ɽ��",
	"kulougang":"���ø�",
	"langhaodongxue":"�Ǻ���Ѩ",
	"liehuoying":"�һ�Ӫ",
	"lvxue":"��Ѫ�þ�",
	"ninggedian":"�����",
	"plxianjing":"�����ɾ�",
	"sigumudi":"����Ĺ��",
	"wujinchangqiao":"�޾�����",
	"xihai":"����",
	"xinnian_fb":"���޸���",
	"yandigu":"�׵۹�",
	"yl":"�׵۹�",
	"youanzhaoze":"�İ�����",
	"yandigu":"�ɻ��ŵ�",
	"zhongnanshan":"����ɽ",
	"congxianzhen":"������",
	"dwgy":"����ʯ��",
	"lvxie":"��Ѫ��",


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
			s+="[֧��"+fee_cn+"�ɵ� "+pinyin_to_cn[block]+":map_display "+block+" "+fee+"]\n";
		}	

	}
	return s;
}
string get_sub_map_list(string block){
	string s="";
	foreach(indices(all_map_list[block]),string name_cn ){
		if(name_cn!="")
		s+="[�ɵ���"+name_cn+":qge74hye "+all_map_list[block][name_cn]+"]\n";
	}
	return s;
}
void load_all_map(){
	array(string) map_index_list = get_dir(ROOT + "/gamelib/d/");
	foreach(map_index_list,string block){
		mapping(string:string) sub_map =([]);// �������֣��Ͷ�Ӧ�ķ���·��
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


//��ѯ��ǰ�����direction�������һ������
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
			s += "������"+dire_desc+"\n";
		}
		dire_desc = map_tmp["west"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "������"+dire_desc+"\n";
		}
		dire_desc = map_tmp["east"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "������"+dire_desc+"\n";
		}
		dire_desc = map_tmp["south"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "�ϡ���"+dire_desc+"\n";
		}
	}
	else{
		//��������
		object next_room,tmp_room;
		string direction = "north";
		//��
		s += "������";
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
		s += "������";
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
		s += "������";
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
		s += "�ϡ���";
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
