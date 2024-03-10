//$创建城池战场房间的方法，liaocheng 于 07/08/26 完成最终版本

#define ROOT "./"
int main(int argc, array(string) argv){

	mapping(string:string) templates =([]);

//头部信息
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\n";

templates["head"]="void create(){\n\tname=object_name(this_object());\n\tset_room_type(\"city\");\n";

templates["地点名"]="\tname_cn=\"$1\";\n";

templates["描述"]="\tdesc=\"$1\\n\";\n";

templates["出口"]="\texits[\"$1\"]=ROOT \"/gamelib/d/$2\";\n";

templates["所属城池"]="\tset_belong_to(\"$1\");\n";
templates["查询占领"]="\tstring tmp_s = CITYD->query_captured(\"$1\");\n";
templates["攻城房间"]="\tif(tmp_s == \"monst\"){\n\t\troom_race=\"monst\";\n\t\tname_cn += \"(妖魔占领)\";$1\n\t\tforeach(flush_monst,string item){\n\t\t\tif(item && sizeof(item))\n\t\t\t\tadd_items(({ROOT \"/gamelib/clone/npc/\"+item}));\n\t\t}\n\t}\n\telse if(tmp_s == \"human\"){\n\t\troom_race=\"human\";\n\t\tname_cn += \"(人类占领)\";$2\n\t\tforeach(flush_human,string item){\n\t\t\tif(item && sizeof(item))\n\t\t\t\tadd_items(({ROOT \"/gamelib/clone/npc/\"+item}));\n\t\t}\n\t}\n";
templates["添加守卫"]="\n\t\tguarded_exits[\"$1\"]=\"$2\";\n\t\tadd_items(({ROOT \"/gamelib/clone/npc/$3\"}));";
templates["查询占领"]="\tstring tmp_s = CITYD->query_captured(\"$1\");\n";

templates["妖族刷npc"]="array(string) flush_monst = ({$1});\n";
templates["仙族刷npc"]="array(string) flush_human = ({$1});\n";
templates["普通npc"]="\tadd_items(({ROOT \"/gamelib/clone/npc/$1\"}));\n";

templates["房间阵营"]="string room_race=\"$1\";\n";
templates["房间等级"]="static int room_level=$1;\n";

templates["foot"]="}\n";

templates["房间"]="inherit WAP_ROOM;\n";

templates["和平"]="int is_peaceful()\n{\n\treturn 1;\n}\n";

	array(string) all_lines;
	array(string) line_values;
	
	//记录房间等级所用
	string room_level_lists = "";
	//记录房间等级所用

	string all_data=Stdio.read_file(ROOT+argv[1]);

	all_lines=all_data/"\r\n";
	mapping configs = ([]);

	mapping links = ([]);//存在的连接

	mapping unlinks = ([]); //不存在的连接

	string tempString;
	array tempArray;
	int tempInt = 0;
	write("total num:"+sizeof(all_lines)+"\n");
	for(int i=1;i<sizeof(all_lines);i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		if(sizeof(line_values)<50){
			for (int j = sizeof(line_values);j<30;j++)
			{
				line_values+=({""});
			}
		}
		configs["文件名"]=line_values[0];
		if(configs["文件名"]==""){
			continue;
		}
		write(line_values[1]+":\n\n");
		links[configs["文件名"]]="1";
		if(unlinks[configs["文件名"]]){//存在于空连接，删除
			m_delete(unlinks,configs["文件名"]);
		}

		configs["地点名"]=line_values[1];
		configs["描述"]=line_values[2];
		if(configs["描述"][0..0]=="\"") configs["描述"]=configs["描述"][1..sizeof(configs["描述"])-2];
		configs["所属城池"]=line_values[3];
		configs["东"]=line_values[4];
		configs["南"]=line_values[5];
		configs["西"]=line_values[6];
		configs["北"]=line_values[7];
		configs["是否为攻城房间"]=line_values[8];
		configs["普通npc"]=line_values[9];
		configs["妖魔看守"]=line_values[10];
		configs["仙族看守"]=line_values[11];
		configs["妖族刷npc"]=line_values[12];
		configs["仙族刷npc"]=line_values[13];
		configs["和平"]=line_values[14];
		configs["房间阵营"]=line_values[15];
		configs["房间等级"]=line_values[16];

		writeFile+=templates["include"];
		writeFile+=templates["房间"];
		if(configs["房间阵营"]!=""){
			if(configs["房间阵营"]=="人类")
				writeFile+=replace(templates["房间阵营"],"$1","human");
			if(configs["房间阵营"]=="妖魔")
				writeFile+=replace(templates["房间阵营"],"$1","monst");
			if(configs["房间阵营"]=="中立")
				writeFile+=replace(templates["房间阵营"],"$1","third");
		}
		if(configs["房间等级"]!=""){
			writeFile+=replace(templates["房间等级"],"$1",configs["房间等级"]);
			room_level_lists += configs["房间等级"]+"|"+configs["文件名"]+"|"+configs["地点名"]+"\n";
		}
		if(configs["是否为攻城房间"]!=""){
			array(string) tmp_arr = configs["妖族刷npc"]/"|";
			string tmp_str = "";
			for(int i=0;i<sizeof(tmp_arr);i++){
				tmp_str += "\""+tmp_arr[i]+"\",";
			}
			writeFile+=replace(templates["妖族刷npc"],"$1",tmp_str);
			tmp_arr = configs["仙族刷npc"]/"|";
			tmp_str = "";
			for(int i=0;i<sizeof(tmp_arr);i++){
				tmp_str += "\""+tmp_arr[i]+"\",";
			}
			writeFile+=replace(templates["仙族刷npc"],"$1",tmp_str);
		}
		writeFile+=templates["head"];

		writeFile+=replace(templates["地点名"],"$1",configs["地点名"]);
		writeFile+=replace(templates["描述"],"$1",configs["描述"]);
		writeFile+=replace(templates["所属城池"],"$1",configs["所属城池"]);
		//writeFile+=replace(templates["描述"],"$1","");
		if(configs["东"]!=""){
			tempString=replace(templates["出口"],"$1","east");
			writeFile+=replace(tempString,"$2",configs["东"]);
			
			if(!links[configs["东"]]){
				unlinks[configs["东"]]=configs["文件名"]+"东";
			}
		}
		if(configs["南"]!=""){
			tempString=replace(templates["出口"],"$1","south");
			writeFile+=replace(tempString,"$2",configs["南"]);
			if(!links[configs["南"]]){
				unlinks[configs["南"]]=configs["文件名"]+"南";
			}
		}
		if(configs["西"]!=""){
			tempString=replace(templates["出口"],"$1","west");
			writeFile+=replace(tempString,"$2",configs["西"]);
			if(!links[configs["西"]]){
				unlinks[configs["西"]]=configs["文件名"]+"西";
			}
		}
		if(configs["北"]!=""){
			tempString=replace(templates["出口"],"$1","north");
			writeFile+=replace(tempString,"$2",configs["北"]);
			if(!links[configs["北"]]){
				unlinks[configs["北"]]=configs["文件名"]+"北";
			}
		}
		if(configs["是否为攻城房间"]!=""){
			writeFile+=replace(templates["查询占领"],"$1",configs["所属城池"]);
			//这里加入条件刷新
			string g_tmp1 = "";
			string g_tmp2 = "";
			string g_all1 = "";
			string g_all2 = "";
			if(configs["妖魔看守"]!=""){
				array(string) m_all = configs["妖魔看守"]/":";
				for(int i=0;i<sizeof(m_all);i++){
					array(string) m_arr = m_all[i]/"|";
					array(string) m_arr2 = m_arr[0]/"/";
					g_tmp1 = replace(templates["添加守卫"],"$1",m_arr[1]);
					g_tmp1 = replace(g_tmp1,"$2",m_arr2[1]);
					g_tmp1 = replace(g_tmp1,"$3",m_arr[0]);
					g_all1 += g_tmp1;
				}
			}
			if(configs["仙族看守"]!=""){
				array(string) h_all = configs["仙族看守"]/":";
				for(int i=0;i<sizeof(h_all);i++){
					array(string) h_arr = h_all[i]/"|";
					array(string) h_arr2 = h_arr[0]/"/";
					g_tmp2 = replace(templates["添加守卫"],"$1",h_arr[1]);
					g_tmp2 = replace(g_tmp2,"$2",h_arr2[1]);
					g_tmp2 = replace(g_tmp2,"$3",h_arr[0]);
					g_all2 += g_tmp2;
				}
			}
			string s_all = replace(templates["攻城房间"],"$1",g_all1);
			s_all = replace(s_all,"$2",g_all2);
			writeFile += s_all;
		}
		if(configs["普通npc"]!=""){
			array(string) n_arr = configs["普通npc"]/"|";
			string n_str = "";
			for(int i=0;i<sizeof(n_arr);i++){
				n_str += replace(templates["普通npc"],"$1",n_arr[i]);
			}
			writeFile += n_str;
		}

		writeFile+=templates["foot"];

		if(configs["和平"]!=""){
			writeFile+=templates["和平"];
		}

		array dir = configs["文件名"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOT+dir[0]);
		Stdio.write_file(ROOT+configs["文件名"],writeFile);
	}
	//Stdio.append_file("/usr/local/games/usrdata/room_level_test.log",room_level_lists);
	string log = "以下连接可能存在问题：\n\n";
	if(sizeof(unlinks)){
		array t = indices(unlinks);
		for(int i=0;i<sizeof(t);i++){
			log+="文件"+unlinks[t[i]]+":"+t[i]+"\n\n";
		}
		write(log);
		//Stdio.append_file(ROOT+"create_wrong_log.log",log);
	}
	return 1;
}
