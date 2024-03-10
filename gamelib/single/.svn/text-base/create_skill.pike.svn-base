#define ROOT "./"
int main(int argc, array(string) argv){
	mapping(string:string) templates =([]);
//头部信息
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit MUD_SKILL;\ninherit WAP_F_VIEW_PICTURE;\nmapping(int:int) performs_attack=([]);\nmapping(int:int) performs_per=([]);\nmapping(int:int) performs_cast=([]);\narray(string) skill_type=({});\nmapping(int:array(int)) performs_mofa_attack=([]);\nmapping(int:string) performs_desc=([]);\n";

templates["head"]="void create(){\n\tname=object_name(this_object());\n";

templates["技能名称"]="\tname_cn=\"$1\";\n";
templates["技能描述"]="\tdesc=\"$1\";\n";
templates["技能图片"]="\tpicture=name;\n";
templates["技能类别"]="\ts_type=\"$1\";\n";
templates["技能类型"]="\ts_skill_type=\"$1\";\n";
templates["技能冷却时间"]="\ts_delayTime=$1;\n";
templates["技能持续伤害时间"]="\ts_lasttime=$1;\n";
templates["技能诅咒对方属性类型"]="\ts_curse_type=\"$1\";\n";

templates["物理技能伤害"]="\tperforms_attack[$1]=$2;\n";
templates["物理技能伤害增加百分比"]="\tperforms_per[$1]=$2;\n";
templates["技能耗费法力"]="\tperforms_cast[$1]=$2;\n";
templates["技能职业学习限制"]="\tskill_type+=({\"$1\"});\n";
templates["法术技能伤害"]="\tperforms_mofa_attack[$1]=({$2,$3});\n";//上下限

templates["技能等级描述"]="\tperforms_desc[$1]=\"$2\";\n";//上下限
templates["foot"]="}\n";

templates["物理技能伤害fun_head"]="int query_performs_attack(int level){\n\t";
templates["物理技能伤害fun_content"]="if(!level)\n\t\treturn 0;\n\tif(performs_attack&&sizeof(performs_attack))\n\t\treturn (int)performs_attack[level];\n\telse\n\t\treturn 0;\n";
templates["物理技能伤害fun_foot"]="}\n";

templates["物理技能伤害增加百分比fun_head"]="int query_performs_per(int level){\n\t";
templates["物理技能伤害增加百分比fun_content"]="if(!level)\n\t\treturn 0;\n\tif(performs_per&&sizeof(performs_per))\n\t\treturn (int)performs_per[level];\n\telse\n\t\treturn 0;\n";
templates["物理技能伤害增加百分比fun_foot"]="}\n";

templates["技能耗费法力fun_head"]="int query_performs_cast(int level){\n\t";
templates["技能耗费法力fun_content"]="\tif(!level)\n\t\treturn 0;\n\tif(performs_cast&&sizeof(performs_cast))\n\t\treturn (int)performs_cast[level];\n\telse\n\t\treturn 0;\n";
templates["技能耗费法力fun_foot"]="}\n";

templates["法术技能伤害上限fun_head"]="int query_performs_mofa_attack_high(int level){\n\t";
templates["法术技能伤害上限fun_content"]="if(!level)\n\t\treturn 0;\n\tif(performs_mofa_attack&&sizeof(performs_mofa_attack))\n\t\treturn (int)performs_mofa_attack[level][1];\n\telse\n\t\treturn 0;\n";
templates["法术技能伤害上限fun_foot"]="}\n";

templates["法术技能伤害下限fun_head"]="int query_performs_mofa_attack_low(int level){\n\t";
templates["法术技能伤害下限fun_content"]="if(!level)\n\t\treturn 0;\n\tif(performs_mofa_attack&&sizeof(performs_mofa_attack))\n\t\treturn (int)performs_mofa_attack[level][0];\n\telse\n\t\treturn 0;\n";
templates["法术技能伤害下限fun_foot"]="}\n";

templates["技能等级描述fun_head"]="string query_performs_desc(int level){\n\t";
templates["技能等级描述fun_content"]="if(!level)\n\t\treturn \"\";\n\tif(performs_desc&&sizeof(performs_desc))\n\t\treturn (string)performs_desc[level];\n\telse\n\t\treturn \"\";\n";
templates["技能等级描述fun_foot"]="}\n";
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

	array(string) all_lines;
	array(string) line_values;

	string all_data=Stdio.read_file(ROOT+argv[1]);

	string centerLine = "\n";
	all_lines = all_data/"\r\n";
	mapping configs = ([]);

	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=1;i<sizeof(all_lines);i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		/*
		if(sizeof(line_values)<500){
			for (int j = sizeof(line_values);j<20;j++)
			{
				line_values+=({""});
			}
		}
		*/
		if(line_values[0]==""){
			continue;
		}
		write(line_values[1]+":\n\n");
		configs["文件名"]=line_values[0];
		configs["技能名称"]=line_values[1];
		configs["技能描述"]=line_values[2];
		configs["技能图片"]=line_values[3];
		configs["技能类别"]=line_values[4];
		configs["技能类型"]=line_values[5];
		configs["技能冷却时间"]=line_values[6];
		configs["技能持续伤害时间"]=line_values[7];
		configs["技能诅咒对方属性类型"]=line_values[8];
		configs["物理技能伤害"]=line_values[9];
		configs["物理技能伤害增加百分比"]=line_values[10];
		configs["技能耗费法力"]=line_values[11];
		configs["技能职业学习限制"]=line_values[12];
		configs["法术技能伤害"]=line_values[13];
		configs["技能等级描述"]=line_values[14];
		
		writeFile+=templates["include"];
		writeFile+=templates["head"];

		writeFile+=replace(templates["技能名称"],"$1",configs["技能名称"]);
		write("技能名称****"+configs["技能名称"]+"****\n");
		writeFile+=replace(templates["技能描述"],"$1",configs["技能描述"]);
		write("技能描述****"+configs["技能描述"]+"****\n");

		if(configs["技能图片"]!=""){
			writeFile+=templates["技能图片"];
		}
		if(configs["技能类别"]!=""){
			write("技能类别****"+configs["技能类别"]+"****\n");
			string tmp = (string)configs["技能类别"];
			string s = "";
			if(tmp=="主动")
				s = "zhudong";
			else if(tmp=="被动")
				s = "beidong";
			writeFile+=replace(templates["技能类别"],"$1",s);
		}
		if(configs["技能类型"]!=""){
			write("技能类型****"+configs["技能类型"]+"****\n");
			string tmp = (string)configs["技能类型"];
			string s = "";
			mapping(string:string) m = ([
				"火":"huo_mofa_attack",
				"冰":"bing_mofa_attack",
				"风":"feng_mofa_attack",
				"毒":"du_mofa_attack",
				"持续":"dot",
				"诅咒":"curse",
				"物理":"phy",
				"增益":"buff"
			]);
			s = (string)m[tmp];
			writeFile+=replace(templates["技能类型"],"$1",s);
		}
		if(configs["技能冷却时间"]!=""){
			write("技能冷却时间****"+configs["技能冷却时间"]+"****\n");
			writeFile+=replace(templates["技能冷却时间"],"$1",configs["技能冷却时间"]);
		}
		if(configs["技能持续伤害时间"]!=""){
			write("技能持续伤害时间****"+configs["技能持续伤害时间"]+"****\n");
			writeFile+=replace(templates["技能持续伤害时间"],"$1",configs["技能持续伤害时间"]);
		}
		if(configs["技能诅咒对方属性类型"]!=""){
			write("技能诅咒对方属性类型****"+configs["技能诅咒对方属性类型"]+"****\n");
			string tmp = (string)configs["技能诅咒对方属性类型"];
			string s = "";
			mapping(string:string) m = ([
				"力":"str",
				"敏":"dex",
				"智":"think",
				"全属性":"all",
				"火":"huoyan_defend",
				"冰":"bingshuang_defend",
				"风":"fengren_defend",
				"毒":"dusu_defend",
				"全法术":"all_mofa_defend",
				"速度":"speed",
				"防御力":"defend",
				"命中":"hitte",
				"爆击":"doub",
				"闪避":"dodge",
				"攻速":"speed",
				"吸收伤害":"absorb",
				"增强法力":"add_mana"
			]);
			s = (string)m[tmp];
			writeFile+=replace(templates["技能诅咒对方属性类型"],"$1",s);
		}
		if(configs["物理技能伤害"]!=""){
			write("物理技能伤害****"+configs["物理技能伤害"]+"****\n");
			array arr = configs["物理技能伤害"][1..sizeof(configs["物理技能伤害"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["物理技能伤害"],"$1",""+k);
				writeFile+=replace(tmps,"$2",arr[j]);
			}
		}
		if(configs["物理技能伤害增加百分比"]!=""){
			write("物理技能伤害增加百分比****"+configs["物理技能伤害增加百分比"]+"****\n");
			array arr = configs["物理技能伤害增加百分比"][1..sizeof(configs["物理技能伤害增加百分比"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["物理技能伤害增加百分比"],"$1",""+k);
				writeFile+=replace(tmps,"$2",arr[j]);
			}
		}
		if(configs["技能耗费法力"]!=""){
			write("技能耗费法力****"+configs["技能耗费法力"]+"****\n");
			array arr = configs["技能耗费法力"][1..sizeof(configs["技能耗费法力"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["技能耗费法力"],"$1",""+k);
				writeFile+=replace(tmps,"$2",arr[j]);
			}
		}
		if(configs["技能职业学习限制"]!=""){
			write("技能职业学习限制****"+configs["技能职业学习限制"]+"****\n");
			array arr = configs["技能职业学习限制"]/"\n";
			mapping(string:string) m=([
				"剑仙":"jianxian",
				"羽士":"yushi",
				"诛仙":"zhuxian",
				"狂妖":"kuangyao",
				"巫妖":"wuyao",
				"影鬼":"yinggui"
			]);
			for(int j=0;j<sizeof(arr);j++){
				writeFile+=replace(templates["技能职业学习限制"],"$1",(string)m[arr[j]]);
			}
		}
		if(configs["法术技能伤害"]!=""){
			write("法术技能伤害****"+configs["法术技能伤害"]+"****\n");
			array arr = configs["法术技能伤害"][1..sizeof(configs["法术技能伤害"])-2]/"\n";
			for(int i=0;i<sizeof(arr);i++)
				write("["+arr[i]+"]\n");
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				array tmp = arr[j]/":";
				tmps = replace(templates["法术技能伤害"],"$1",""+k); 
				tmps = replace(tmps,"$2",(string)tmp[0]); 
				writeFile+=replace(tmps,"$3",(string)tmp[1]);
			}
		}
		if(configs["技能等级描述"]!=""){
			array arr = configs["技能等级描述"][1..sizeof(configs["技能等级描述"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["技能等级描述"],"$1",""+k);
				writeFile+=replace(tmps,"$2",(string)arr[j]);
			}
		}

		writeFile+=templates["foot"];
		writeFile+=templates["物理技能伤害fun_head"];
		writeFile+=templates["物理技能伤害fun_content"];
		writeFile+=templates["物理技能伤害fun_foot"];
		writeFile+=templates["物理技能伤害增加百分比fun_head"];
		writeFile+=templates["物理技能伤害增加百分比fun_content"];
		writeFile+=templates["物理技能伤害增加百分比fun_foot"];
		writeFile+=templates["技能耗费法力fun_head"];
		writeFile+=templates["技能耗费法力fun_content"];
		writeFile+=templates["技能耗费法力fun_foot"];
		writeFile+=templates["法术技能伤害上限fun_head"];
		writeFile+=templates["法术技能伤害上限fun_content"];
		writeFile+=templates["法术技能伤害上限fun_foot"];
		writeFile+=templates["法术技能伤害下限fun_head"];
		writeFile+=templates["法术技能伤害下限fun_content"];
		writeFile+=templates["法术技能伤害下限fun_foot"];
		writeFile+=templates["技能等级描述fun_head"];
		writeFile+=templates["技能等级描述fun_content"];
		writeFile+=templates["技能等级描述fun_foot"];
		Stdio.write_file(ROOT+configs["文件名"],writeFile);
	}
	return 1;
}
