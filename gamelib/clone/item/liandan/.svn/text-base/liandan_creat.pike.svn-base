#define ROOTDIR "./"
int main(int argc, array(string) argv){
	mapping(string:string) templates =([]);
	//所有生成白物品列表
	mapping(string:string) all_lines_attributeLimit=([]);
	////////////
	templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_DANYAO;\n";
	templates["head"]="void create(){\n\tname=object_name(this_object());\n";
	templates["丹药名"]="\tname_cn=\"$1\";\n";
	templates["单位"]="\tunit=\"$1\";\n";
	templates["物品图片"]="\tpicture=name;\n";
	templates["描述"]="\tdesc=\"$1\\n\";\n";
	///////////
	templates["是否可以丢弃"]="\tset_item_canDrop($1);\n";
	templates["是否可以捡起"]="\tset_item_canGet($1);\n";
	templates["是否可以交易"]="\tset_item_canTrade($1);\n";
	templates["是否可以赠送"]="\tset_item_canSend($1);\n";
	templates["是否可以存储"]="\tset_item_canStorage($1);\n";
	templates["丹药大类"]="\tset_danyao_kind(\"$1\");\n";
	templates["丹药效果类型"]="\tset_danyao_type(\"$1\");\n";
	templates["丹药效果值"]="\tset_effect_value($1);\n";
	templates["效果持续时间"]="\tset_danyao_timedelay($1);\n";
	templates["丹药使用等级"]="\tset_item_level($1);\n";
	///////////
	templates["价值"]="\tvalue=$1;\n";
	///////////
	templates["foot"]="}\n";
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
	for(int i=1;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		write("生成物品:"+line_values[1]+" 目录:"+line_values[0]+"\n");
		//基本属性设置字段开始/////////////////////////////////////////////////////////////////	
		configs["文件名"]=line_values[0];//该物品物理文件名称路径
		configs["丹药名"]=line_values[1];//该物品中文名称
		configs["单位"]=line_values[2];//该物品单位名称
		configs["物品图片"]=line_values[3];//该物品图片地址
		configs["描述"]=line_values[4];//该物品中文描述
		configs["丹药大类"]= line_values[5];
		configs["丹药效果类型"]=line_values[6];
		configs["丹药效果值"]=line_values[7];
		configs["效果持续时间"]=line_values[8];
		configs["是否可以装备"]=line_values[9];
		configs["是否可以丢弃"]=line_values[10];
		configs["是否可以捡起"]=line_values[11];
		configs["是否可以交易"]=line_values[12];
		configs["是否可以赠送"]=line_values[13];
		configs["是否可以存储"]=line_values[14];
		configs["价值"]=line_values[15];
		configs["丹药使用等级"]=line_values[16];

		//基本属性设置字段完毕///////////////////////////////////////////////////////	
		writeFile+=templates["include"];//头文件信息
		//物品create()方法头部//////////////////////////////////////
		writeFile+=templates["head"];
		//物品中文名称/////////////////////////
		writeFile+=replace(templates["丹药名"],"$1",configs["丹药名"]);
		//物品中文描述/////////////////////////
		writeFile+=replace(templates["描述"],"$1",configs["描述"]);
		//物品单位/////////////////////////
		if(configs["单位"]!="")
			writeFile+=replace(templates["单位"],"$1",configs["单位"]);
		//物品图片标示/////////////////////////
		if(configs["物品图片"]!="")
			writeFile+=templates["物品图片"];
		//是否可以丢弃/////////////////////////
		if(configs["是否可以丢弃"]!="")
			writeFile+=replace(templates["是否可以丢弃"],"$1",configs["是否可以丢弃"]);
		//是否可以捡起/////////////////////////
		if(configs["是否可以捡起"]!="")
			writeFile+=replace(templates["是否可以捡起"],"$1",configs["是否可以捡起"]);
		//是否可以交易/////////////////////////
		if(configs["是否可以交易"]!="")
			writeFile+=replace(templates["是否可以交易"],"$1",configs["是否可以交易"]);
		//是否可以赠送/////////////////////////
		if(configs["是否可以赠送"]!="")
			writeFile+=replace(templates["是否可以赠送"],"$1",configs["是否可以赠送"]);
		//是否能存储仓库银行/////////////////////////
		if(configs["是否可以存储"]!="")
			writeFile+=replace(templates["是否可以存储"],"$1",configs["是否可以存储"]);
		//丹药大类/////////////////////////
		if(configs["丹药大类"]!="")
			writeFile+=replace(templates["丹药大类"],"$1",configs["丹药大类"]);
		//丹药效果类型/////////////////////////
		if(configs["丹药效果类型"]!="")
			writeFile+=replace(templates["丹药效果类型"],"$1",configs["丹药效果类型"]);
		//丹药效果值/////////////////////////
		if(configs["丹药效果值"]!="")
			writeFile+=replace(templates["丹药效果值"],"$1",configs["丹药效果值"]);
		//效果持续时间/////////////////////////
		if(configs["效果持续时间"]!="")
			writeFile+=replace(templates["效果持续时间"],"$1",configs["效果持续时间"]);
		//物品使用等级/////////////////////////
		if(configs["丹药使用等级"]!="")
			writeFile+=replace(templates["丹药使用等级"],"$1",configs["丹药使用等级"]);

		string stmpname = configs["文件名"];

		//create()方法尾部
		writeFile+=templates["foot"];

		array dir = configs["文件名"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+configs["文件名"],writeFile);
	}
	return 1;
}
