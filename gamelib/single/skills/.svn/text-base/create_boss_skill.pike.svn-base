#define ROOT "./"
int main(int argc, array(string) argv){
	mapping(string:string) templates =([]);
//头部信息
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit MUD_SKILL;\ninherit WAP_F_VIEW_PICTURE;\nint performs_attack;\nint performs_per;\narray(string) skill_type=({});\narray(int) performs_mofa_attack=({});\n";

templates["head"]="void create(){\n\tname=object_name(this_object());\n\tboss_skill = 1;\n";

templates["技能名称"]="\tname_cn=\"$1\";\n";
templates["群体攻击"]="\tis_aoe=$1;\n";
templates["技能类型"]="\ts_skill_type=\"$1\";\n";
templates["技能冷却时间"]="\ts_delayTime=$1;\n";
templates["技能持续伤害时间"]="\ts_lasttime=$1;\n";
templates["技能诅咒对方属性类型"]="\ts_curse_type=\"$1\";\n";

templates["物理技能伤害"]="\tperforms_attack=$1;\n";
templates["物理技能伤害增加百分比"]="\tperforms_per=$1;\n";
templates["法术技能伤害"]="\tperforms_mofa_attack=({$1,$2});\n";//上下限

templates["foot"]="}\n";

templates["物理技能伤害fun_head"]="int query_performs_attack(){\n\t";
templates["物理技能伤害fun_content"]="return (int)performs_attack;\n";
templates["物理技能伤害fun_foot"]="}\n";

templates["物理技能伤害增加百分比fun_head"]="int query_performs_per(){\n\t";
templates["物理技能伤害增加百分比fun_content"]="return (int)performs_per;\n";
templates["物理技能伤害增加百分比fun_foot"]="}\n";


templates["法术技能伤害上限fun_head"]="int query_performs_mofa_attack_high(){\n\t";
templates["法术技能伤害上限fun_content"]="if(performs_mofa_attack&&sizeof(performs_mofa_attack))\n\t\treturn (int)performs_mofa_attack[1];\n\telse\n\t\treturn 0;\n";
templates["法术技能伤害上限fun_foot"]="}\n";

templates["法术技能伤害下限fun_head"]="int query_performs_mofa_attack_low(){\n\t";
templates["法术技能伤害下限fun_content"]="if(performs_mofa_attack&&sizeof(performs_mofa_attack))\n\t\treturn (int)performs_mofa_attack[0];\n\telse\n\t\treturn 0;\n";
templates["法术技能伤害下限fun_foot"]="}\n";

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
		if(line_values[0]==""){
			continue;
		}
		write(line_values[1]+":\n\n");
		configs["文件名"]=line_values[0];
		configs["技能名称"]=line_values[1];
		configs["群体攻击"]=line_values[2];
		configs["技能类型"]=line_values[3];
		configs["技能冷却时间"]=line_values[4];
		configs["技能持续伤害时间"]=line_values[5];
		configs["技能诅咒对方属性类型"]=line_values[6];
		configs["物理技能伤害"]=line_values[7];
		configs["物理技能伤害增加百分比"]=line_values[8];
		configs["法术技能伤害"]=line_values[9];
		
		writeFile+=templates["include"];
		writeFile+=templates["head"];

		writeFile+=replace(templates["技能名称"],"$1",configs["技能名称"]);
		write("技能名称****"+configs["技能名称"]+"****\n");

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
		if(configs["群体攻击"]!=""){
			writeFile+=replace(templates["群体攻击"],"$1",configs["群体攻击"]);
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
				writeFile+= replace(templates["物理技能伤害"],"$1",configs["物理技能伤害"]);
		}
		if(configs["物理技能伤害增加百分比"]!=""){
			write("物理技能伤害增加百分比****"+configs["物理技能伤害增加百分比"]+"****\n");
				writeFile+= replace(templates["物理技能伤害增加百分比"],"$1",configs["物理技能伤害增加百分比"]);
		}
		
		if(configs["法术技能伤害"]!=""){
			write("法术技能伤害****"+configs["法术技能伤害"]+"****\n");
			array tmp = configs["法术技能伤害"]/":";
			string tmps = "";
			tmps = replace(templates["法术技能伤害"],"$1",(string)tmp[0]); 
			writeFile+=replace(tmps,"$2",(string)tmp[1]);
		}

		writeFile+=templates["foot"];
		writeFile+=templates["物理技能伤害fun_head"];
		writeFile+=templates["物理技能伤害fun_content"];
		writeFile+=templates["物理技能伤害fun_foot"];
		writeFile+=templates["物理技能伤害增加百分比fun_head"];
		writeFile+=templates["物理技能伤害增加百分比fun_content"];
		writeFile+=templates["物理技能伤害增加百分比fun_foot"];
		writeFile+=templates["法术技能伤害上限fun_head"];
		writeFile+=templates["法术技能伤害上限fun_content"];
		writeFile+=templates["法术技能伤害上限fun_foot"];
		writeFile+=templates["法术技能伤害下限fun_head"];
		writeFile+=templates["法术技能伤害下限fun_content"];
		writeFile+=templates["法术技能伤害下限fun_foot"];
		Stdio.write_file(ROOT+configs["文件名"],writeFile);
	}
	return 1;
}
