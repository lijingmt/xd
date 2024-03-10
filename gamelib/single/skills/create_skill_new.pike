#define ROOT "./"
int main(int argc, array(string) argv){
	mapping(string:string) templates =([]);
//ͷ����Ϣ
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_SKILL;\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";

templates["��������"]="\tname_cn=\"$1\";\n";
templates["��������"]="\tdesc=\"$1\";\n";
templates["����ͼƬ"]="\tpicture=name;\n";
templates["�������"]="\ts_type=\"$1\";\n";
templates["��������"]="\ts_skill_type=\"$1\";\n";
templates["������ȴʱ��"]="\ts_delayTime=$1;\n";
templates["���ܳ����˺�ʱ��"]="\ts_lasttime=$1;\n";
templates["����/��������"]="\ts_curse_type=\"$1\";\n";

templates["�������˺�"]="\tperforms_attack[$1]=$2;\n";//���䡢����ħ����Ч��ֵҲ����һ������
templates["�������˺����Ӱٷֱ�"]="\tperforms_per[$1]=$2;\n";
templates["���ܺķѷ���"]="\tperforms_cast[$1]=$2;\n";
templates["����ְҵѧϰ����"]="\tskill_type+=({\"$1\"});\n";
templates["���������˺�"]="\tperforms_mofa_attack[$1]=({$2,$3});\n";//������

templates["���ܵȼ�����"]="\tperforms_level_limit[$1]=$2;\n";//                         
templates["���ܵȼ�����"]="\tperforms_desc[$1]=\"$2\";\n";//��ͬ����Ĺ�������
templates["foot"]="}\n";


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
	configs["��������"]=line_values[2];
	configs["����ͼƬ"]=line_values[3];
	configs["�������"]=line_values[4];
	configs["��������"]=line_values[5];
	configs["������ȴʱ��"]=line_values[6];
	configs["���ܳ����˺�ʱ��"]=line_values[7];
	configs["����/��������"]=line_values[8];
	configs["�������˺�"]=line_values[9];
	configs["�������˺����Ӱٷֱ�"]=line_values[10];
	configs["���ܺķѷ���"]=line_values[11];
	configs["����ְҵѧϰ����"]=line_values[12];
	configs["���������˺�"]=line_values[13];
	configs["���ܵȼ�����"]=line_values[14];
	write("line 14 = "+ line_values[14] +"\n");
	configs["���ܵȼ�����"]=line_values[15];

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
	if(configs["����/��������"]!=""){
		write("����/��������****"+configs["����/��������"]+"****\n");
		string tmp = (string)configs["����/��������"];
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
		writeFile+=replace(templates["����/��������"],"$1",s);
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
		if(sizeof(configs["���ܵȼ�����"])>2)
		{
			write("i am in \n");
			array arr = configs["���ܵȼ�����"][1..sizeof(configs["���ܵȼ�����"])-2]/"\n";
			string tmps = "";
			for(int j=0;j<sizeof(arr);j++){
				int k = j+1;
				tmps = replace(templates["���ܵȼ�����"],"$1",""+k);
				writeFile+=replace(tmps,"$2",arr[j]);
			}
		}
		else
		{
			string tmps = "";
			tmps = replace(templates["���ܵȼ�����"],"$1","1");
			writeFile+=replace(tmps,"$2",configs["���ܵȼ�����"]);
			
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
	Stdio.write_file(ROOT+configs["�ļ���"],writeFile);
}
return 1;
}
