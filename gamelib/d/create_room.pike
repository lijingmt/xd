//$Revision: 1.19 $ $Date: 2003/10/17 10:05:12 $
//这个生成算法是适用于作图软件生成的地图导表的
//liaocheng于07/08/16修改
#define ROOT "./"
#define DATA_ROOT "/usr/local/games/usrdata"
int main(int argc, array(string) argv){

	mapping(string:string) templates =([]);

//头部信息
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\n";

templates["head"]="void create(){\n\tname=object_name(this_object());\n";

templates["地点名"]="\tname_cn=\"$1\";\n";

templates["描述"]="\tdesc=\"$1\\n\";\n";

templates["房间类型"]="\tset_room_type(\"$1\");\n";

templates["出口"]="\texits[\"$1\"]=ROOT \"/gamelib/d/$2\";\n";

//templates["门"]="\tclosed_exits[\"$1\"]=1;\n";
templates["门"]="\tdesc+=\"[走出洞穴:qge74hye \"+\"$1\"+\"]\\n\";\n";

templates["钥匙"]="\tclosed_exits[\"$1\"]=(program)(expand_symlinks(\"$2\",ROOT+\"/gamelib/clone/item\"));\n";

templates["看守"]="\tguarded_exits[\"$1\"]=(program)(expand_symlinks(\"$2\",ROOT+\"/gamelib/clone/npc\"));\n";

templates["看守语"]="\tguard_msg=\"$1\";\n";

templates["人"]="\tadd_items(({ROOT \"/gamelib/clone/npc/$1\"}));\n";

templates["店主"]="\tset_boss(ROOT \"/gamelib/clone/npc/$1\");\n";

templates["物"]="\tadd_items(({ROOT \"/gamelib/clone/item/$1\"}));\n";

templates["杂货铺"]="\tlinks=\"[卖东西:inventory_sell]\\n\";\n";
templates["铁匠铺"]="\tlinks=\"[修理装备:repair]\\n\";\n\tlinks+=\"[修理所有装备:repair_all]\\n\";\n\tlinks+=\"[锻造:viceskill_duanzao_list m_weapon]|[熔解:viceskill_rongjie_list]|[熔炼:viceskill_ronglian_list 0]\\n\";\n";
templates["是复活点"]=/*"string query_links(){\n\tobject player=this_player();\n\tstring tmp="";\n\tif(player->query_raceId()==room_race){\n\t\ttmp+=\"[休息:sleep]\\n\";\n*/"\n\t\tobject env=environment(player);\n\t\tstring cur_pos=file_name(env)-ROOT;\n\t\tif(player->relife){\n\t\t\tif(player->relife!=cur_pos)\n\t\t\t\ttmp+=\"[设置复活点:relife \"+cur_pos+\"]\\n\";\n\t\t}\n\t\telse\n\t\t\ttmp+=\"[设置复活点:relife \"+cur_pos+\"]\\n\";\n";//\t}\n}";

templates["额外连接"]="\tlinks=\"$1\";\n";

templates["房间阵营"]="string room_race=\"$1\";\n";
templates["房间等级"]="static int room_level=$1;\n";

templates["foot"]="}\n";

templates["房间"]="inherit WAP_ROOM;\n";

templates["钱庄"]="inherit WAP_BANK;\n";

templates["商店"]="inherit WAP_STORE;\n";

templates["和平"]="int is_peaceful()\n{\n\treturn 1;\n}\n";
//templates["和平"]="\n";

templates["休息室"]="int is_bedroom()\n{\n\treturn 1;\n}\nstring query_links(){\n\tobject player=this_player();\n\tstring tmp=\"\""";\n\tif(player->query_raceId()==room_race || room_race == \"third\"){\n\t\ttmp+=\"[休息:sleep]\\n\";\n\t$1\t}\n\treturn tmp;\n}\n";

//templates["当铺"]="int is_pawnshop()\n{\n\treturn 1;\n}\n";

templates["添加指令"]="\nadd_action($1,\"$1\");\n";

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
		configs["东"]=line_values[3];
		configs["南"]=line_values[4];
		configs["西"]=line_values[5];
		configs["北"]=line_values[6];
		configs["门"]=line_values[7];
		configs["钥匙"]=line_values[9];
		configs["止"]=line_values[10];
		configs["看守"]=line_values[11];
		configs["看守语"]=line_values[12];
		configs["人"]=line_values[13];
		configs["物"]=line_values[14];
		configs["是复活点"]=line_values[15];
		configs["休息室"]=line_values[16];
		configs["和平"]=line_values[17];
		configs["杂货铺"]=line_values[18];
		configs["铁匠铺"]=line_values[19];
		configs["当铺"]="";//line_values[20];
		configs["钱庄"]="";//line_values[21];
		configs["额外连接"]=line_values[22];
		//configs["添加指令"]=line_values[23];
		//configs["附加函数"]=line_values[21];
		configs["房间阵营"]=line_values[23];
		configs["房间等级"]=line_values[24];
		configs["房间类型"]=line_values[25];
		//configs[""]=line_values[22];

		writeFile+=templates["include"];

	
		/*if(configs["钱庄"]!="" && configs["钱庄"]!="0"){
			writeFile+=templates["钱庄"];
		}
		else{
			if((configs["杂货铺"]!=""&&configs["杂货铺"]!="0")||(configs["当铺"]!=""&&configs["当铺"]!="0")){
				writeFile+=templates["商店"];
			}
			else{*/
		writeFile+=templates["房间"];
			//}
		//}
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
			if((int)configs["房间等级"] < 10000)
				room_level_lists += configs["房间等级"]+"|"+configs["文件名"]+"|"+configs["地点名"]+"\n";
		}
		writeFile+=templates["head"];

		writeFile+=replace(templates["地点名"],"$1",configs["地点名"]);
		writeFile+=replace(templates["描述"],"$1",configs["描述"]);
		//writeFile+=replace(templates["描述"],"$1","");
		if(configs["房间类型"] && configs["房间类型"]!=""){
			writeFile+=replace(templates["房间类型"],"$1",configs["房间类型"]);
		}
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

		if(configs["门"]!=""){
			writeFile+=replace(templates["门"],"$1",configs["门"]);
			/*
			if(configs["钥匙"]!=""){
				tempString=replace(templates["钥匙"],"$1",configs["门"]);
				writeFile+=replace(tempString,"$2",configs["钥匙"]);
			}
			else{
				writeFile+=replace(templates["门"],"$1",configs["门"]);
			}
			*/
		}

		if(configs["止"]!=""&&configs["看守"]!=""){
			tempString=replace(templates["看守"],"$1",configs["止"]);
			writeFile+=replace(tempString,"$2",configs["看守"]);
		}

		if(configs["看守语"]!=""){
			writeFile+=replace(templates["看守语"],"$1",configs["看守语"]);
		}

		if(configs["人"]!=""){
			//werror("----config = "+configs["人"]+"----\n");
			if(sizeof(configs["人"]/"\"") > 1)
				configs["人"]=(configs["人"]/"\"")[1];
			tempArray = configs["人"]/"\n";//[0..sizeof(configs["人"])-1]/"\n";
			if(sizeof(tempArray)==1){
				tempArray[0]=configs["人"];
			}
			for(int j=0;j<sizeof(tempArray);j++){
				//if(j==0&&((configs["杂货铺"]!=""&&configs["杂货铺"]!="0")||(configs["当铺"]!=""&&configs["当铺"]!="0"))){
				//	writeFile+=replace(templates["店主"],"$1",tempArray[j]);
				//	continue;
				//}
				if(tempArray[j] != "" && sizeof(tempArray[j]))
					writeFile+=replace(templates["人"],"$1",tempArray[j]);
			}
		}

		if(configs["物"]!=""){
			tempArray = configs["物"][1..sizeof(configs["物"])-2]/"\n";
			if(sizeof(tempArray)==1){
				tempArray[0]=configs["物"];
			}
			for(int j=0;j<sizeof(tempArray);j++){
				writeFile+=replace(templates["物"],"$1",tempArray[j]);
			}
		}
		
		if(configs["杂货铺"]=="1"){
			writeFile+=templates["杂货铺"];
		}
		if(configs["铁匠铺"]=="1"){
			writeFile+=templates["铁匠铺"];
		}

		//if(configs["额外连接"]!=""){
		//	writeFile+=replace(templates["额外连接"],"$1",configs["额外连接"]);
		//}
		

		writeFile+=templates["foot"];

		if(configs["和平"]!="" && configs["和平"]!="0"){
			writeFile+=templates["和平"];
		}

		if(configs["是复活点"]!="" && configs["是复活点"]!="0"){
			string t=templates["休息室"];
			writeFile+=replace(templates["休息室"],"$1",templates["是复活点"]);
		}
		else if(configs["休息室"]!="" && configs["休息室"]!="0")
			writeFile+=replace(templates["休息室"],"$1","");
		/*
		if(configs["当铺"]!=""){
			writeFile+=templates["当铺"];
		}
		if(configs["添加指令"]!=""){
			writeFile+="void init(){\n";
			tempArray = configs["添加指令"][1..sizeof(configs["添加指令"])-2]/"\n";
			if(sizeof(tempArray)==1){
				tempArray[0]=configs["添加指令"];
			}
			for(int j=0;j<sizeof(tempArray);j++){
				writeFile+=replace(templates["添加指令"],"$1",tempArray[j]);
			}
			writeFile+="}\n";
		}
		if(configs["附加函数"]!=""){
			tempString=replace(configs["附加函数"][1..sizeof(configs["附加函数"])-2],"/，",",");
			writeFile+=replace(tempString,"\"\"","\"");
		}
		*/
		array dir = configs["文件名"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOT+dir[0]);
		Stdio.write_file(ROOT+configs["文件名"],writeFile);
	}
	
	Stdio.append_file(DATA_ROOT+"/room_level.log",room_level_lists);
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
