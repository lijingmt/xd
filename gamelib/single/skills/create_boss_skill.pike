#define ROOT "./"
int main(int argc, array(string) argv){
	mapping(string:string) templates =([]);
//ͷ����Ϣ
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit MUD_SKILL;\ninherit WAP_F_VIEW_PICTURE;\nint performs_attack;\nint performs_per;\narray(string) skill_type=({});\narray(int) performs_mofa_attack=({});\n";

templates["head"]="void create(){\n\tname=object_name(this_object());\n\tboss_skill = 1;\n";

templates["��������"]="\tname_cn=\"$1\";\n";
templates["Ⱥ�幥��"]="\tis_aoe=$1;\n";
templates["��������"]="\ts_skill_type=\"$1\";\n";
templates["������ȴʱ��"]="\ts_delayTime=$1;\n";
templates["���ܳ����˺�ʱ��"]="\ts_lasttime=$1;\n";
templates["��������Է���������"]="\ts_curse_type=\"$1\";\n";

templates["�������˺�"]="\tperforms_attack=$1;\n";
templates["�������˺����Ӱٷֱ�"]="\tperforms_per=$1;\n";
templates["���������˺�"]="\tperforms_mofa_attack=({$1,$2});\n";//������

templates["foot"]="}\n";

templates["�������˺�fun_head"]="int query_performs_attack(){\n\t";
templates["�������˺�fun_content"]="return (int)performs_attack;\n";
templates["�������˺�fun_foot"]="}\n";

templates["�������˺����Ӱٷֱ�fun_head"]="int query_performs_per(){\n\t";
templates["�������˺����Ӱٷֱ�fun_content"]="return (int)performs_per;\n";
templates["�������˺����Ӱٷֱ�fun_foot"]="}\n";


templates["���������˺�����fun_head"]="int query_performs_mofa_attack_high(){\n\t";
templates["���������˺�����fun_content"]="if(performs_mofa_attack&&sizeof(performs_mofa_attack))\n\t\treturn (int)performs_mofa_attack[1];\n\telse\n\t\treturn 0;\n";
templates["���������˺�����fun_foot"]="}\n";

templates["���������˺�����fun_head"]="int query_performs_mofa_attack_low(){\n\t";
templates["���������˺�����fun_content"]="if(performs_mofa_attack&&sizeof(performs_mofa_attack))\n\t\treturn (int)performs_mofa_attack[0];\n\telse\n\t\treturn 0;\n";
templates["���������˺�����fun_foot"]="}\n";

	//�ж���������Ϸ���///////////////////////////////////////
	if(argc==2){
		if(search(argv[argc-1],".csv")!=-1)
			write("��Ҫ������ĵ�����Ϊ��"+argv[argc-1]+"\n");	
		else{
			write("��Ҫ������ĵ�����Ϊ��"+argv[argc-1]+"\n");	
			write("���Ǹ��ļ�����һ���Ϸ���csv�����ĵ����뷵�ؼ��!\n");
			return 0;
		}
	}
	else{
		write("���������뷵�ؼ�飡\n");	
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
		configs["�ļ���"]=line_values[0];
		configs["��������"]=line_values[1];
		configs["Ⱥ�幥��"]=line_values[2];
		configs["��������"]=line_values[3];
		configs["������ȴʱ��"]=line_values[4];
		configs["���ܳ����˺�ʱ��"]=line_values[5];
		configs["��������Է���������"]=line_values[6];
		configs["�������˺�"]=line_values[7];
		configs["�������˺����Ӱٷֱ�"]=line_values[8];
		configs["���������˺�"]=line_values[9];
		
		writeFile+=templates["include"];
		writeFile+=templates["head"];

		writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		write("��������****"+configs["��������"]+"****\n");

		if(configs["��������"]!=""){
			write("��������****"+configs["��������"]+"****\n");
			string tmp = (string)configs["��������"];
			string s = "";
			mapping(string:string) m = ([
				"��":"huo_mofa_attack",
				"��":"bing_mofa_attack",
				"��":"feng_mofa_attack",
				"��":"du_mofa_attack",
				"����":"dot",
				"����":"curse",
				"����":"phy",
				"����":"buff"
			]);
			s = (string)m[tmp];
			writeFile+=replace(templates["��������"],"$1",s);
		}
		if(configs["Ⱥ�幥��"]!=""){
			writeFile+=replace(templates["Ⱥ�幥��"],"$1",configs["Ⱥ�幥��"]);
		}
		if(configs["������ȴʱ��"]!=""){
			write("������ȴʱ��****"+configs["������ȴʱ��"]+"****\n");
			writeFile+=replace(templates["������ȴʱ��"],"$1",configs["������ȴʱ��"]);
		}
		if(configs["���ܳ����˺�ʱ��"]!=""){
			write("���ܳ����˺�ʱ��****"+configs["���ܳ����˺�ʱ��"]+"****\n");
			writeFile+=replace(templates["���ܳ����˺�ʱ��"],"$1",configs["���ܳ����˺�ʱ��"]);
		}
		if(configs["��������Է���������"]!=""){
			write("��������Է���������****"+configs["��������Է���������"]+"****\n");
			string tmp = (string)configs["��������Է���������"];
			string s = "";
			mapping(string:string) m = ([
				"��":"str",
				"��":"dex",
				"��":"think",
				"ȫ����":"all",
				"��":"huoyan_defend",
				"��":"bingshuang_defend",
				"��":"fengren_defend",
				"��":"dusu_defend",
				"ȫ����":"all_mofa_defend",
				"�ٶ�":"speed",
				"������":"defend",
				"����":"hitte",
				"����":"doub",
				"����":"dodge",
				"����":"speed",
				"�����˺�":"absorb",
				"��ǿ����":"add_mana"
			]);
			s = (string)m[tmp];
			writeFile+=replace(templates["��������Է���������"],"$1",s);
		}
		if(configs["�������˺�"]!=""){
			write("�������˺�****"+configs["�������˺�"]+"****\n");
				writeFile+= replace(templates["�������˺�"],"$1",configs["�������˺�"]);
		}
		if(configs["�������˺����Ӱٷֱ�"]!=""){
			write("�������˺����Ӱٷֱ�****"+configs["�������˺����Ӱٷֱ�"]+"****\n");
				writeFile+= replace(templates["�������˺����Ӱٷֱ�"],"$1",configs["�������˺����Ӱٷֱ�"]);
		}
		
		if(configs["���������˺�"]!=""){
			write("���������˺�****"+configs["���������˺�"]+"****\n");
			array tmp = configs["���������˺�"]/":";
			string tmps = "";
			tmps = replace(templates["���������˺�"],"$1",(string)tmp[0]); 
			writeFile+=replace(tmps,"$2",(string)tmp[1]);
		}

		writeFile+=templates["foot"];
		writeFile+=templates["�������˺�fun_head"];
		writeFile+=templates["�������˺�fun_content"];
		writeFile+=templates["�������˺�fun_foot"];
		writeFile+=templates["�������˺����Ӱٷֱ�fun_head"];
		writeFile+=templates["�������˺����Ӱٷֱ�fun_content"];
		writeFile+=templates["�������˺����Ӱٷֱ�fun_foot"];
		writeFile+=templates["���������˺�����fun_head"];
		writeFile+=templates["���������˺�����fun_content"];
		writeFile+=templates["���������˺�����fun_foot"];
		writeFile+=templates["���������˺�����fun_head"];
		writeFile+=templates["���������˺�����fun_content"];
		writeFile+=templates["���������˺�����fun_foot"];
		Stdio.write_file(ROOT+configs["�ļ���"],writeFile);
	}
	return 1;
}
