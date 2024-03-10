#define ROOTDIR "./"
//#include <command.h>
int main(int argc, array(string) argv){
mapping(string:string) templates =([]);

//����������ҩ�б�
mapping(string:string) all_lines_attributeLimit=([]);

//��ҩ����������Ϣ///////////////////////////////////////////////
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_DANYAO;\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";
templates["��Ʒ��"]="\tname_cn=\"$1\";\n";
templates["��λ"]="\tunit=\"$1\";\n";
templates["��ƷͼƬ"]="\tpicture=\"$1\";\n";
templates["����"]="\tdesc=\"$1\\n\";\n";
/////////////
templates["ҩ�����"]="\tset_danyao_kind(\"$1\");\n";
templates["ҩ��Ч������"]="\tset_danyao_type(\"$1\");\n";
templates["ҩ��Ч��ֵ"]="\tset_effect_value($1);\n";
templates["ҩ�����ʱ��"]="\tset_danyao_timedelay($1);\n";
////////////
templates["�Ƿ���Զ���"]="\tset_item_canDrop($1);\n";
templates["�Ƿ���Լ���"]="\tset_item_canGet($1);\n";
templates["�Ƿ���Խ���"]="\tset_item_canTrade($1);\n";
templates["�Ƿ��������"]="\tset_item_canSend($1);\n";
templates["�Ƿ��ܴ洢�ֿ�����"]="\tset_item_canStorage($1);\n";
templates["��������"]="\tset_for_material(\"$1\");\n";
///////////
//templates["�ҵĵȼ�����"]="\tset_home_level($1);\n";
//templates["�ɲ���Ҫ����ֵ"]="\tset_spr_need($1);\n";
///////////
templates["foot"]="}\n";
////////////////////////////////////////////////////////////
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
	//�ж���������Ϸ���///////////////////////////////////////
	//��ɫ��Ʒ��������//////////////	
	array(string) all_lines;
	array(string) line_values;
	mapping (int:string) item_level_index=([]);//��ɫ��Ʒ���յȼ��������� ����:1|1tmj,1tiejian,1xuezi,1kuijia......
	string all_data=Stdio.read_file(ROOTDIR+argv[1]);
	all_lines=all_data/"\r\n";
	mapping configs = ([]);
	mapping attributeLimit_configs = ([]);
	
	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=1;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		write("������Ʒ:"+line_values[1]+" �ļ�:"+line_values[0]+"\n");
		//�������������ֶο�ʼ/////////////////////////////////////////////////////////////////	
		configs["�ļ���"]=line_values[0];//����Ʒ�����ļ�����·��
		configs["��Ʒ��"]=line_values[1];//����Ʒ��������
		configs["��λ"]=line_values[2];//����Ʒ��λ����
		configs["��ƷͼƬ"]=line_values[3];//����ƷͼƬ��ַ
		configs["����"]=line_values[4];//����Ʒ��������
		configs["ҩ�����"]=line_values[5];
		configs["ҩ��Ч������"]=line_values[6];
		configs["ҩ��Ч��ֵ"]=line_values[7];
		configs["ҩ�����ʱ��"]=line_values[8];//ҩ�����ʱ��
		configs["�Ƿ���Զ���"]=line_values[9];
		configs["�Ƿ���Լ���"]=line_values[10];
		configs["�Ƿ���Խ���"]=line_values[11];
		configs["�Ƿ��������"]=line_values[12];
		configs["�Ƿ��ܴ洢�ֿ�����"]=line_values[13];
		configs["��������"]=line_values[14];
		//configs["�ҵĵȼ�����"]=line_values[14];
		//configs["�ɲ���Ҫ����ֵ"]=line_values[15];
		//�������������ֶ����/////////////////////////////////////////////////////////////////	
		writeFile+=templates["include"];//ͷ�ļ���Ϣ
		//��Ʒcreate()����ͷ��//////////////////////////////////////
		writeFile+=templates["head"];
		//��Ʒ��������/////////////////////////
		writeFile+=replace(templates["��Ʒ��"],"$1",configs["��Ʒ��"]);
		//��Ʒ���ĵ�λ/////////////////////////
		if(configs["��λ"]!="")
			writeFile+=replace(templates["��λ"],"$1",configs["��λ"]);
		//��ƷͼƬ��ʾ/////////////////////////
		if(configs["��ƷͼƬ"]!=""){
			string picture = (string)(configs["�ļ���"]/"/")[1];
			writeFile+=replace(templates["��ƷͼƬ"],"$1",picture);
		}
		//��Ʒ��������/////////////////////////
		writeFile+=replace(templates["����"],"$1",configs["����"]);
		//ҩ�����/////////////////////////
		if(configs["ҩ�����"]!="")
			writeFile+=replace(templates["ҩ�����"],"$1",configs["ҩ�����"]);
		//ҩ��Ч������/////////////////////////
		if(configs["ҩ��Ч������"]!="")
			writeFile+=replace(templates["ҩ��Ч������"],"$1",configs["ҩ��Ч������"]);
		//ҩ��Ч��ֵ/////////////////////////////
		
		if(configs["ҩ��Ч��ֵ"]!="")
			writeFile+=replace(templates["ҩ��Ч��ֵ"],"$1",configs["ҩ��Ч��ֵ"]);
		//ҩ�����ʱ��/////////////////////////
		if(configs["ҩ�����ʱ��"]!="")
			writeFile+=replace(templates["ҩ�����ʱ��"],"$1",configs["ҩ�����ʱ��"]);
		//�Ƿ���Զ���/////////////////////////
		if(configs["�Ƿ���Զ���"]!="")
			writeFile+=replace(templates["�Ƿ���Զ���"],"$1",configs["�Ƿ���Զ���"]);
		//�Ƿ���Լ���/////////////////////////
		if(configs["�Ƿ���Լ���"]!="")
			writeFile+=replace(templates["�Ƿ���Լ���"],"$1",configs["�Ƿ���Լ���"]);
		//�Ƿ���Խ���/////////////////////////
		if(configs["�Ƿ���Խ���"]!="")
			writeFile+=replace(templates["�Ƿ���Խ���"],"$1",configs["�Ƿ���Խ���"]);
		//�Ƿ��������/////////////////////////
		if(configs["�Ƿ��������"]!="")
			writeFile+=replace(templates["�Ƿ��������"],"$1",configs["�Ƿ��������"]);
		//�Ƿ��ܴ洢�ֿ�����/////////////////////////
		if(configs["�Ƿ��ܴ洢�ֿ�����"]!="")
			writeFile+=replace(templates["�Ƿ��ܴ洢�ֿ�����"],"$1",configs["�Ƿ��ܴ洢�ֿ�����"]);
		//��������////////////////////////
		if(configs["��������"]!="")
			writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		/*
		//�ҵĵȼ�����/////////////////////////////
		if(configs["�ҵĵȼ�����"]!="")
			writeFile+=replace(templates["�ҵĵȼ�����"],"$1",configs["�ҵĵȼ�����"]);
		//�ɲ���Ҫ����ֵ///////////////////////////////////////
		if(configs["�ɲ���Ҫ����ֵ"]!="")
			writeFile+=replace(templates["�ɲ���Ҫ����ֵ"],"$1",configs["�ɲ���Ҫ����ֵ"]);
		*/
		//create()����β��
		writeFile+=templates["foot"];
		//���ɸð�ɫ��Ʒ�ļ�
		array dir = configs["�ļ���"]/"/";
		if(!Stdio.exist(ROOTDIR+dir[0]))
			mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+configs["�ļ���"],writeFile);
	}
	return 1;
}
