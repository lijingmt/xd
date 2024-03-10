//$Revision: 1.19 $ $Date: 2003/10/17 10:05:12 $

#define ROOT "./"

int main(int argc, array(string) argv){

	mapping(string:string) templates =([]);

//头部信息
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\n";

templates["head"]="inherit WAP_ROOM;\nint clear = 0;\nvoid create(){\n\tname=object_name(this_object());\n\tset_room_type(\"fb\");\n";

templates["地点名"]="\tname_cn=\"$1\";\n";

templates["描述"]="\tdesc=\"$1\\n\";\n";

templates["人"]="\tadd_items(({ROOT \"/gamelib/clone/npc/$1\"}));\n";

templates["foot"]="}\n";

templates["房间"]="inherit WAP_ROOM;\n";

	array(string) all_lines;
	array(string) line_values;
	
	//记录房间等级所用

	string all_data=Stdio.read_file(ROOT+argv[1]);

	all_lines=all_data/"\r\n";
	mapping configs = ([]);

	string tempString;
	array tempArray;
	int tempInt = 0;
	write("total num:"+sizeof(all_lines)+"\n");
	for(int i=1;i<sizeof(all_lines);i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		if(sizeof(line_values)>9){
			string fb_name = line_values[0];
			configs["文件名"]=line_values[1];
			if(configs["文件名"]==""){
				continue;
			}
			write(line_values[1]+":\n\n");

			configs["地点名"]=line_values[2];
			configs["描述"]=line_values[3];
			if(configs["描述"][0..0]=="\"") configs["描述"]=configs["描述"][1..sizeof(configs["描述"])-2];
			int room_num = (int)line_values[4];
			string have_exist = line_values[5];
			configs["人"]=line_values[6];
			string back = line_values[7];
			string forward = line_values[8];

			writeFile+=templates["include"];

			writeFile+=templates["head"];

			writeFile+=replace(templates["地点名"],"$1",configs["地点名"]);
			writeFile+=replace(templates["描述"],"$1",configs["描述"]);

			if(configs["人"]!=""){
				tempArray = configs["人"][1..sizeof(configs["人"])-2]/"\n";
				if(sizeof(tempArray)==1){
					tempArray[0]=configs["人"];
				}
				for(int j=0;j<sizeof(tempArray);j++){
					writeFile+=replace(templates["人"],"$1",tempArray[j]);
				}
			}

			writeFile+=templates["foot"];

			string tmp_s = "string query_links(){\n\tobject player=this_player();\n\tstring tmp=\"\";\n";
			if(back != "")
				tmp_s += "\ttmp += \"[去往"+back+":fb_entry "+fb_name+" "+(room_num-1)+" 1]\\n\";\n";
			if(forward != "")
				tmp_s += "\tif(check_if_clear() == 1)\n\t\ttmp += \"[去往"+forward+":fb_entry "+fb_name+" "+(room_num+1)+" 1]\\n\";\n\telse\n\t\ttmp += \"去往"+forward+"\\n\";\n";
			if(have_exist != "")
				tmp_s += "\ttmp += \"[离开幻境:fb_leave "+fb_name+"]\\n\";\n";
			tmp_s += "\treturn tmp;\n}\n";

			tmp_s += "int check_if_clear(){\n\tif(clear == 1)\n\t\treturn 1;\n\tarray(object) all_obj = all_inventory(this_object());\n\tforeach(all_obj,object ob){\n\t\tif(ob->is(\"npc\")){\n\t\t\tclear = 0;\n\t\t\tbreak;\n\t\t}\n\t\telse\n\t\t\tclear = 1;\n\t}\n\treturn clear;\n}"; 
			writeFile+=tmp_s;

			array dir = configs["文件名"]/"/";
			if(!Stdio.exist(dir[0])) mkdir(ROOT+dir[0]);
			Stdio.write_file(ROOT+configs["文件名"],writeFile);
		}
	}
	return 1;
}
