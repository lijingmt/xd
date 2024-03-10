#define ROOTDIR "./"
int main(int argc, array(string) argv){
mapping(string:string) templates =([]);
//所有生成白物品列表
mapping(string:string) all_lines_attributeLimit=([]);
////////////
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_BOOK;\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";
templates["书名"]="\tname_cn=\"$1\";\n";
templates["单位"]="\tunit=\"$1\";\n";
templates["物品图片"]="\tpicture=name;\n";
templates["描述"]="\tdesc=\"$1\\n\";\n";
///////////
templates["是否可装备"]="\tset_item_canEquip($1);\n";
templates["是否可以丢弃"]="\tset_item_canDrop($1);\n";
templates["是否可以捡起"]="\tset_item_canGet($1);\n";
templates["是否可以交易"]="\tset_item_canTrade($1);\n";
templates["是否可以赠送"]="\tset_item_canSend($1);\n";
templates["是否任务物品"]="\tset_item_task($1);\n";
templates["是否能存储仓库银行"]="\tset_item_canStorage($1);\n";
templates["玩家自己的标志"]="\tset_item_playerDesc(\"$1\");\n";
///////////
templates["价值"]="\tvalue=$1;\n";
///////////
templates["技能名称"]="\tskill_bname=\"$1\";\n";
templates["学习技能等级限制"]="\tlevel_limit=$1;\n";
templates["学习技能职业限制"]="\tprofe_read_limit=\"$1\";\n";
templates["被动技能级别"]="\tbeidong_level=$1;\n";
templates["需要玉石"]="\tneed_yushi=$1;\n";
templates["需要金钱"]="\tneed_money=$1;\n";
///////////
templates["foot"]="}\n";
////////////////////////////////////////////////////////////
templates["主动阅读处理"]="int read(){\n\tint result=::read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
templates["被动阅读处理"]="int read(){\n\tint result=::beidong_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
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
	for(int i=1;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		//write("生成物品:"+line_values[1]+" 目录:"+line_values[0]+"\n");
		write(" 目录:"+line_values[0]+":"+line_values[1]+"\n");
		//基本属性设置字段开始/////////////////////////////////////////////////////////////////	
		configs["文件名"]=line_values[0];//该物品物理文件名称路径
		configs["书名"]=line_values[1];//该物品中文名称
		configs["单位"]=line_values[2];//该物品单位名称
		configs["物品图片"]=line_values[3];//该物品图片地址
		configs["描述"]=line_values[4];//该物品中文描述
		configs["是否可以丢弃"]=line_values[5];
		configs["是否可以捡起"]=line_values[6];
		configs["是否可以交易"]=line_values[7];
		configs["是否可以赠送"]=line_values[8];
		configs["是否任务物品"]=line_values[9];
		configs["是否能存储仓库银行"]=line_values[10];
		configs["玩家自己的标志"]=line_values[11];
		configs["价值"]=line_values[12];
		
		configs["技能名称"]=line_values[13];
		configs["学习技能等级限制"]=line_values[14];
		configs["学习技能职业限制"]=line_values[15];
		configs["需要玉石"]=line_values[16];
		configs["需要金钱"]=line_values[17];
		configs["被动技能级别"]=line_values[18];
		//基本属性设置字段完毕/////////////////////////////////////////////////////////////////	
		writeFile+=templates["include"];//头文件信息
		//物品create()方法头部//////////////////////////////////////
		writeFile+=templates["head"];
		//物品中文名称/////////////////////////
		writeFile+=replace(templates["书名"],"$1",configs["书名"]);
		//物品中文单位/////////////////////////
		if(configs["单位"]!="")
			writeFile+=replace(templates["单位"],"$1",configs["单位"]);
		//物品图片标示/////////////////////////
		if(configs["物品图片"]!="")
			writeFile+=templates["物品图片"];
		//物品中文描述/////////////////////////
		writeFile+=replace(templates["描述"],"$1",configs["描述"]);
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
		//是否任务物品/////////////////////////
		if(configs["是否任务物品"]!="")
			writeFile+=replace(templates["是否任务物品"],"$1",configs["是否任务物品"]);
		//是否能存储仓库银行/////////////////////////
		if(configs["是否能存储仓库银行"]!="")
			writeFile+=replace(templates["是否能存储仓库银行"],"$1",configs["是否能存储仓库银行"]);
		//玩家自己的标志/////////////////////////////
		if(configs["玩家自己的标志"]!="")
			writeFile+=replace(templates["玩家自己的标志"],"$1",configs["玩家自己的标志"]);
		//价值///////////////////////////////////////
		if(configs["价值"]!="")
			writeFile+=replace(templates["价值"],"$1",configs["价值"]);
		//技能名称///////////////////////////////////////
		if(configs["技能名称"]!="")
			writeFile+=replace(templates["技能名称"],"$1",configs["技能名称"]);
		//学习技能等级限制/////////////////////////////////
		if(configs["学习技能等级限制"]!=""){
			writeFile+=replace(templates["学习技能等级限制"],"$1",configs["学习技能等级限制"]);
			string itemLevel = (string)configs["学习技能等级限制"];
			string stmpname = configs["文件名"];
			if(!all_lines_attributeLimit[itemLevel])
				all_lines_attributeLimit[itemLevel] = "";
			all_lines_attributeLimit[itemLevel] += stmpname+",";
		}
		//学习技能职业限制/////////////////////////////////
		if(configs["学习技能职业限制"]!="")
			writeFile+=replace(templates["学习技能职业限制"],"$1",configs["学习技能职业限制"]);
		//被动技能级别/////////////////////////////////
		if(configs["被动技能级别"]!="")
			writeFile+=replace(templates["被动技能级别"],"$1",configs["被动技能级别"]);
		//购买所需要的玉石数量////////////////////////////////////
		if(configs["需要玉石"]!="")
			writeFile+=replace(templates["需要玉石"],"$1",configs["需要玉石"]);
		//购买所需要的金钱///////////////////////////
		if(configs["需要玉石"]!="")
			writeFile+=replace(templates["需要金钱"],"$1",configs["需要金钱"]);
		//create()方法尾部
		writeFile+=templates["foot"];
		//阅读处理,分为主动技能书和被动技能书,两种不同书的阅读接口
		if(configs["被动技能级别"]!="")
			writeFile+=templates["被动阅读处理"];
		else
			writeFile+=templates["主动阅读处理"];
		//生成该技能书
		array dir = configs["文件名"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+configs["文件名"],writeFile);
	}
	return 1;
}
