//该算法负责生成副业所需材料的文件
#define ROOTDIR "./"
//#define ROOTDIR ROOT "/gamelib/clone/item/material/"
int main(int argc, array(string) argv){
mapping(string:string) templates =([]);

//所有生成白物品列表
mapping(string:string) all_lines_attributeLimit=([]);

//白色物品基本属性信息///////////////////////////////////////////////
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_SOURCE;\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";
templates["物品名"]="\tname_cn=\"$1\";\n";
templates["单位"]="\tunit=\"$1\";\n";
templates["描述"]="\tdesc=\"$1\\n\";\n";
//templates["价值"]="\tvalue=$1;\n";
//templates["性质"]="\tamount=1;\n\tpicture=name;\n\tset_item_canEquip(0);\n\tset_item_canDrop(1);\n\tset_item_canGet(1);\n\tset_item_canTrade(1);\n\tset_item_canSend(1);\n\tset_item_canStorage(1);\n";
templates["性质"]="\tamount=1;\n\tset_item_canEquip(0);\n\tset_item_canDrop(1);\n\tset_item_canGet(1);\n\tset_item_canTrade(1);\n\tset_item_canSend(1);\n\tset_item_canStorage(1);\n";
templates["材料类型"]="\tset_source_type(\"$1\");\n";
//templates["幸运附加作用"]="\tset_add_luck($1);\n";
templates["foot"]="}\n";
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
	string all_data=Stdio.read_file(ROOTDIR+argv[1]);
	all_lines=all_data/"\r\n";
	mapping configs = ([]);
	
	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=0;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		write("生成物品:"+line_values[1]+" 目录:"+line_values[0]+"\n");
		//基本属性设置字段开始/////////////////////////////////////////////////////////////////	
		configs["文件名"]=line_values[0];//该物品物理文件名称路径
		configs["物品名"]=line_values[1];//该物品中文名称
		configs["描述"]=line_values[2];//该物品中文描述
		configs["单位"]=line_values[3];//该物品单位名称
		//configs["价值"]=line_values[4];//该物品价值
		configs["材料类型"]=line_values[4];//该物品的材料类型
		//configs["附加作用"]=line_values[6];//该物品的附加作用
		
		writeFile+=templates["include"];//头文件信息
		//物品create()方法头部//////////////////////////////////////
		writeFile+=templates["head"];
		//物品中文名称/////////////////////////
		writeFile+=replace(templates["物品名"],"$1",configs["物品名"]);
		//物品中文单位/////////////////////////
		if(configs["单位"] != "")
			writeFile+=replace(templates["单位"],"$1",configs["单位"]);
		//物品中文描述/////////////////////////
		if(configs["描述"] != "")
			writeFile+=replace(templates["描述"],"$1",configs["描述"]);
			/*
		if(configs["价值"] != "")
			writeFile+=replace(templates["价值"],"$1",configs["价值"]);
		*/
		writeFile+=templates["性质"];	
		if(configs["材料类型"] != "")
			writeFile+=replace(templates["材料类型"],"$1",configs["材料类型"]);
		if(configs["材料类型"] == "baoshi" || configs["材料类型"] == "moxian")
			writeFile+=replace(templates["幸运附加作用"],"$1",configs["附加作用"]);
		writeFile+=templates["foot"];
		//生成该物品文件
		//array dir = configs["文件名"]/"/";
		//if(!Stdio.exist(ROOTDIR+dir[0]))
		//	mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+configs["文件名"],writeFile);
	}
	return 1;
}
