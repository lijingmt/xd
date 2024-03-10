#define ROOT "./"
int main(int argc, array(string) argv){
	mapping(string:string) templates =([]);
//ͷ����Ϣ
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit MUD_SKILL;\ninherit WAP_F_VIEW_PICTURE;\nmapping(int:int) performs_attack=([]);\nmapping(int:int) performs_per=([]);\nmapping(int:int) performs_cast=([]);\narray(string) skill_type=({});\nmapping(int:array(int)) performs_mofa_attack=([]);\nmapping(int:string) performs_desc=([]);\n";

templates["head"]="void create(){\n\tname=object_name(this_object());\n";

templates["��������"]="\tname_cn=\"$1\";\n";
templates["��������"]="\tdesc=\"$1\";\n";
templates["����ͼƬ"]="\tpicture=name;\n";
templates["�������"]="\ts_type=\"$1\";\n";
templates["��������"]="\ts_skill_type=\"$1\";\n";
templates["������ȴʱ��"]="\ts_delayTime=$1;\n";
templates["���ܳ����˺�ʱ��"]="\ts_lasttime=$1;\n";
templates["��������Է���������"]="\ts_curse_type=\"$1\";\n";

templates["�������˺�"]="\tperforms_attack[$1]=$2;\n";
templates["�������˺����Ӱٷֱ�"]="\tperforms_per[$1]=$2;\n";
templates["���ܺķѷ���"]="\tperforms_cast[$1]=$2;\n";
templates["����ְҵѧϰ����"]="\tskill_type+=({\"$1\"});\n";
templates["���������˺�"]="\tperforms_mofa_attack[$1]=({$2,$3});\n";//������

templates["���ܵȼ�����"]="\tperforms_desc[$1]=\"$2\";\n";//������
templates["foot"]="}\n";

templates["�������˺�fun_head"]="int query_performs_attack(int level){\n\t";
templates["�������˺�fun_content"]="if(!level)\n\t\treturn 0;\n\tif(performs_attack&&sizeof(performs_attack))\n\t\treturn (int)performs_attack[level];\n\telse\n\t\treturn 0;\n";
templates["�������˺�fun_foot"]="}\n";

templates["�������˺����Ӱٷֱ�fun_head"]="int query_performs_per(int level){\n\t";
templates["�������˺����Ӱٷֱ�fun_content"]="if(!level)\n\t\treturn 0;\n\tif(performs_per&&sizeof(performs_per))\n\t\treturn (int)performs_per[level];\n\telse\n\t\treturn 0;\n";
templates["�������˺����Ӱٷֱ�fun_foot"]="}\n";

templates["���ܺķѷ���fun_head"]="int query_performs_cast(int level){\n\t";
templates["���ܺķѷ���fun_content"]="\tif(!level)\n\t\treturn 0;\n\tif(performs_cast&&sizeof(performs_cast))\n\t\treturn (int)performs_cast[level];\n\telse\n\t\treturn 0;\n";
templates["���ܺķѷ���fun_foot"]="}\n";

templates["���������˺�����fun_head"]="int query_performs_mofa_attack_high(int level){\n\t";
templates["���������˺�����fun_content"]="if(!level)\n\t\treturn 0;\n\tif(performs_mofa_attack&&sizeof(performs_mofa_attack))\n\t\treturn (int)performs_mofa_attack[level][1];\n\telse\n\t\treturn 0;\n";
templates["���������˺�����fun_foot"]="}\n";

templates["���������˺�����fun_head"]="int query_performs_mofa_attack_low(int level){\n\t";
templates["���������˺�����fun_content"]="if(!level)\n\t\treturn 0;\n\tif(performs_mofa_attack&&sizeof(performs_mofa_attack))\n\t\treturn (int)performs_mofa_attack[level][0];\n\telse\n\t\treturn 0;\n";
templates["���������˺�����fun_foot"]="}\n";

templates["���ܵȼ�����fun_head"]="string query_performs_desc(int level){\n\t";
templates["���ܵȼ�����fun_content"]="if(!level)\n\t\treturn \"\";\n\tif(performs_desc&&sizeof(performs_desc))\n\t\treturn (string)performs_desc[level];\n\telse\n\t\treturn \"\";\n";
templates["���ܵȼ�����fun_foot"]="}\n";
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
		configs["�ļ���"]=line_values[0];
		configs["��������"]=line_values[1];
		configs["��������"]=line_values[2];
		configs["����ͼƬ"]=line_values[3];
		configs["�������"]=line_values[4];
		configs["��������"]=line_values[5];
		configs["������ȴʱ��"]=line_values[6];
		configs["���ܳ����˺�ʱ��"]=line_values[7];
		configs["��������Է���������"]=line_values[8];
		configs["�������˺�"]=line_values[9];
		configs["�������˺����Ӱٷֱ�"]=line_values[10];
		configs["���ܺķѷ���"]=line_values[11];
		configs["����ְҵѧϰ����"]=line_values[12];
		configs["���������˺�"]=line_values[13];
		configs["���ܵȼ�����"]=line_values[14];
		
		writeFile+=templates["include"];
		writeFile+=templates["head"];

		writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		write("��������****"+configs["��������"]+"****\n");
		writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		write("��������****"+configs["��������"]+"****\n");

		if(configs["����ͼƬ"]!=""){
			writeFile+=templates["����ͼƬ"];
		}
		if(configs["�������"]!=""){
			write("�������****"+configs["�������"]+"****\n");
			string tmp = (string)configs["�������"];
			string s = "";
			if(tmp=="����")
				s = "zhudong";
			else if(tmp=="����")
				s = "beidong";
			writeFile+=replace(templates["�������"],"$1",s);
		}
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
			array arr = configs["�������˺�"][1..sizeof(configs["�������˺�"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["�������˺�"],"$1",""+k);
				writeFile+=replace(tmps,"$2",arr[j]);
			}
		}
		if(configs["�������˺����Ӱٷֱ�"]!=""){
			write("�������˺����Ӱٷֱ�****"+configs["�������˺����Ӱٷֱ�"]+"****\n");
			array arr = configs["�������˺����Ӱٷֱ�"][1..sizeof(configs["�������˺����Ӱٷֱ�"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["�������˺����Ӱٷֱ�"],"$1",""+k);
				writeFile+=replace(tmps,"$2",arr[j]);
			}
		}
		if(configs["���ܺķѷ���"]!=""){
			write("���ܺķѷ���****"+configs["���ܺķѷ���"]+"****\n");
			array arr = configs["���ܺķѷ���"][1..sizeof(configs["���ܺķѷ���"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["���ܺķѷ���"],"$1",""+k);
				writeFile+=replace(tmps,"$2",arr[j]);
			}
		}
		if(configs["����ְҵѧϰ����"]!=""){
			write("����ְҵѧϰ����****"+configs["����ְҵѧϰ����"]+"****\n");
			array arr = configs["����ְҵѧϰ����"]/"\n";
			mapping(string:string) m=([
				"����":"jianxian",
				"��ʿ":"yushi",
				"����":"zhuxian",
				"����":"kuangyao",
				"����":"wuyao",
				"Ӱ��":"yinggui"
			]);
			for(int j=0;j<sizeof(arr);j++){
				writeFile+=replace(templates["����ְҵѧϰ����"],"$1",(string)m[arr[j]]);
			}
		}
		if(configs["���������˺�"]!=""){
			write("���������˺�****"+configs["���������˺�"]+"****\n");
			array arr = configs["���������˺�"][1..sizeof(configs["���������˺�"])-2]/"\n";
			for(int i=0;i<sizeof(arr);i++)
				write("["+arr[i]+"]\n");
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				array tmp = arr[j]/":";
				tmps = replace(templates["���������˺�"],"$1",""+k); 
				tmps = replace(tmps,"$2",(string)tmp[0]); 
				writeFile+=replace(tmps,"$3",(string)tmp[1]);
			}
		}
		if(configs["���ܵȼ�����"]!=""){
			array arr = configs["���ܵȼ�����"][1..sizeof(configs["���ܵȼ�����"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["���ܵȼ�����"],"$1",""+k);
				writeFile+=replace(tmps,"$2",(string)arr[j]);
			}
		}

		writeFile+=templates["foot"];
		writeFile+=templates["�������˺�fun_head"];
		writeFile+=templates["�������˺�fun_content"];
		writeFile+=templates["�������˺�fun_foot"];
		writeFile+=templates["�������˺����Ӱٷֱ�fun_head"];
		writeFile+=templates["�������˺����Ӱٷֱ�fun_content"];
		writeFile+=templates["�������˺����Ӱٷֱ�fun_foot"];
		writeFile+=templates["���ܺķѷ���fun_head"];
		writeFile+=templates["���ܺķѷ���fun_content"];
		writeFile+=templates["���ܺķѷ���fun_foot"];
		writeFile+=templates["���������˺�����fun_head"];
		writeFile+=templates["���������˺�����fun_content"];
		writeFile+=templates["���������˺�����fun_foot"];
		writeFile+=templates["���������˺�����fun_head"];
		writeFile+=templates["���������˺�����fun_content"];
		writeFile+=templates["���������˺�����fun_foot"];
		writeFile+=templates["���ܵȼ�����fun_head"];
		writeFile+=templates["���ܵȼ�����fun_content"];
		writeFile+=templates["���ܵȼ�����fun_foot"];
		Stdio.write_file(ROOT+configs["�ļ���"],writeFile);
	}
	return 1;
}
