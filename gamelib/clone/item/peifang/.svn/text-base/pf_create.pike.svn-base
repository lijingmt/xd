#define ROOTDIR "./"
//#include <command.h>
#define ROOT "/usr/local/games/xiand"
int main(int argc, array(string) argv){
mapping(string:string) templates =([]);
//所有生成白物品列表
mapping(string:string) all_lines_attributeLimit=([]);
////////////
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_BOOK;\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";
templates["picture"]="\tpicture=name;\n";
templates["物品名称"]="\tname_cn=\"$1\";\n";
templates["单位"]="\tunit=\"本\";\n";
templates["描述"]="\tdesc=\"$1\\n\";\n";
///////////
templates["丢弃"]="\tset_item_canDrop(1);\n";
templates["捡起"]="\tset_item_canGet(1);\n";
templates["交易"]="\tset_item_canTrade(1);\n";
templates["赠送"]="\tset_item_canSend(1);\n";
templates["仓库"]="\tset_item_canStorage(1);\n";
templates["配方类别"]="\tset_peifang_kind(\"$1\");\n";
templates["物品种类"]="\tset_peifang_type(\"$1\");\n";
templates["序号"]="\tpeifang_id=$1;\n";
templates["物品等级"]="\tlevel_limit=$1;\n";
templates["需要技能等级"]="\tviceskill_level=$1;\n";
templates["foot"]="}\n";
////////////////////////////////////////////////////////////
templates["锻造"]="int read(){\n\tint result=::duanzao_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
templates["炼丹"]="int read(){\n\tint result=::liandan_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
templates["裁缝"]="int read(){\n\tint result=::caifeng_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
templates["制甲"]="int read(){\n\tint result=::zhijia_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
////////////////////////////////////////////////////////////
	//判断输入参数合法性///////////////////////////////////////
	if(argc==2){
		if(search(argv[argc-1],".csv")!=-1)
			write("需要处理的文档名称为："+argv[argc-1]+"\n");	
		else{
			write("需要处理的文档名称为："+argv[argc-1]+"\n");	
			write("但是该文件并非一个合法的csv处理文档，请返回检查!\n");
			return 0;
		}
	}
	else{
		write("参数错误，请返回检查！\n");	
		return 0;
	}
	//判断输入参数合法性///////////////////////////////////////
	//白色物品基本属性//////////////	
	array(string) all_lines;
	array(string) line_values;
	mapping (int:string) item_level_index=([]);//白色物品按照等级的索引表 比如:1|1tmj,1tiejian,1xuezi,1kuijia......
	string all_data=Stdio.read_file(ROOTDIR+argv[1]);
	all_lines=all_data/"\r\n";
	mapping configs = ([]);
	
	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=0;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		write("生成物品:"+line_values[3]+" 目录:"+line_values[5]+"\n");
		//基本属性设置字段开始/////////////////////////////////////////////////////////////////	
		configs["序号"]=line_values[0];
		configs["配方类别"]=line_values[1];
		configs["物品种类"]=line_values[2];
		configs["物品名称"]=line_values[3];
		configs["描述"]=line_values[4];
		configs["文件名"]=line_values[5];
		configs["物品等级"]=line_values[6];
		configs["需要技能等级"]=line_values[7];
		//基本属性设置字段完毕/////////////////////////////////////////////////////////////////	
		writeFile+=templates["include"];//头文件信息
		//物品create()方法头部//////////////////////////////////////
		writeFile+=templates["head"];
		writeFile+=replace(templates["物品名称"],"$1",configs["物品名称"]);
		writeFile+=templates["单位"];
		writeFile+=templates["picture"];
		//物品中文描述/////////////////////////
		writeFile+=replace(templates["描述"],"$1",configs["描述"]);
		///////////////////////////////////	
		writeFile+=templates["丢弃"];
		writeFile+=templates["捡起"];
		writeFile+=templates["交易"];
		writeFile+=templates["赠送"];
		writeFile+=templates["仓库"];
		////////////////////////////////////	
		if(configs["配方类别"]!=""){
			writeFile+=replace(templates["配方类别"],"$1",configs["配方类别"]);
			writeFile+=replace(templates["物品种类"],"$1",configs["物品种类"]);
		}
		if(configs["序号"]!="")
			writeFile+=replace(templates["序号"],"$1",configs["序号"]);
		if(configs["物品等级"]!="")
			writeFile+=replace(templates["物品等级"],"$1",configs["物品等级"]);
		if(configs["需要技能等级"]!="")
			writeFile+=replace(templates["需要技能等级"],"$1",configs["需要技能等级"]);
		if(configs["物品等级"]!=""){
			string itemLevel = (string)configs["物品等级"];
			string stmpname = configs["文件名"];
			if(!all_lines_attributeLimit[itemLevel])
				all_lines_attributeLimit[itemLevel] = "";
			all_lines_attributeLimit[itemLevel] += stmpname+",";
		}
		//create()方法尾部
		writeFile+=templates["foot"];
		//阅读处理
		if(configs["配方类别"]!=""){
			if(configs["配方类别"]=="duanzao")
				writeFile+=templates["锻造"];
			if(configs["配方类别"]=="liandan")
				writeFile+=templates["炼丹"];
			if(configs["配方类别"]=="caifeng")
				writeFile+=templates["裁缝"];
			if(configs["配方类别"]=="zhijia")
				writeFile+=templates["制甲"];
		}
		//写入文件	
		array dir = configs["文件名"]/"/";
		if(!Stdio.exist(ROOTDIR+dir[1]))
			mkdir(ROOTDIR+dir[1]);
		//werror(ROOTDIR+dir[0]+"/"+dir[1]+"\n");
		Stdio.write_file(ROOTDIR+dir[1]+"/"+dir[2],writeFile);
	}
	//所有生成技能书列表,按照等级写入技能生成表中
	string itemPath = ROOT + "/gamelib/data/";
	if(!Stdio.exist(itemPath)) 
		mkdir(itemPath);
	string contList = "";
	if(all_lines_attributeLimit&&sizeof(all_lines_attributeLimit)){
		foreach(sort(indices(all_lines_attributeLimit)), string index)
			contList += index + "|" + all_lines_attributeLimit[index]+"\n";	
	}
	//write(itemPath+"/peifang_Items.list"+"\n");
	//write(contList+"\n");
	Stdio.append_file(itemPath+"/peifang.list",contList);
	return 1;
}
