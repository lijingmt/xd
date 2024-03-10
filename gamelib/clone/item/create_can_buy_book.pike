#define ROOTDIR "./"
int main(int argc, array(string) argv){
mapping(string:string) templates =([]);
//�������ɰ���Ʒ�б�
mapping(string:string) all_lines_attributeLimit=([]);
////////////
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_BOOK;\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";
templates["����"]="\tname_cn=\"$1\";\n";
templates["��λ"]="\tunit=\"$1\";\n";
templates["��ƷͼƬ"]="\tpicture=name;\n";
templates["����"]="\tdesc=\"$1\\n\";\n";
///////////
templates["�Ƿ��װ��"]="\tset_item_canEquip($1);\n";
templates["�Ƿ���Զ���"]="\tset_item_canDrop($1);\n";
templates["�Ƿ���Լ���"]="\tset_item_canGet($1);\n";
templates["�Ƿ���Խ���"]="\tset_item_canTrade($1);\n";
templates["�Ƿ��������"]="\tset_item_canSend($1);\n";
templates["�Ƿ�������Ʒ"]="\tset_item_task($1);\n";
templates["�Ƿ��ܴ洢�ֿ�����"]="\tset_item_canStorage($1);\n";
templates["����Լ��ı�־"]="\tset_item_playerDesc(\"$1\");\n";
///////////
templates["��ֵ"]="\tvalue=$1;\n";
///////////
templates["��������"]="\tskill_bname=\"$1\";\n";
templates["ѧϰ���ܵȼ�����"]="\tlevel_limit=$1;\n";
templates["ѧϰ����ְҵ����"]="\tprofe_read_limit=\"$1\";\n";
templates["�������ܼ���"]="\tbeidong_level=$1;\n";
templates["��Ҫ��ʯ"]="\tneed_yushi=$1;\n";
templates["��Ҫ��Ǯ"]="\tneed_money=$1;\n";
///////////
templates["foot"]="}\n";
////////////////////////////////////////////////////////////
templates["�����Ķ�����"]="int read(){\n\tint result=::read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
templates["�����Ķ�����"]="int read(){\n\tint result=::beidong_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
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
	
	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=1;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		//write("������Ʒ:"+line_values[1]+" Ŀ¼:"+line_values[0]+"\n");
		write(" Ŀ¼:"+line_values[0]+":"+line_values[1]+"\n");
		//�������������ֶο�ʼ/////////////////////////////////////////////////////////////////	
		configs["�ļ���"]=line_values[0];//����Ʒ�����ļ�����·��
		configs["����"]=line_values[1];//����Ʒ��������
		configs["��λ"]=line_values[2];//����Ʒ��λ����
		configs["��ƷͼƬ"]=line_values[3];//����ƷͼƬ��ַ
		configs["����"]=line_values[4];//����Ʒ��������
		configs["�Ƿ���Զ���"]=line_values[5];
		configs["�Ƿ���Լ���"]=line_values[6];
		configs["�Ƿ���Խ���"]=line_values[7];
		configs["�Ƿ��������"]=line_values[8];
		configs["�Ƿ�������Ʒ"]=line_values[9];
		configs["�Ƿ��ܴ洢�ֿ�����"]=line_values[10];
		configs["����Լ��ı�־"]=line_values[11];
		configs["��ֵ"]=line_values[12];
		
		configs["��������"]=line_values[13];
		configs["ѧϰ���ܵȼ�����"]=line_values[14];
		configs["ѧϰ����ְҵ����"]=line_values[15];
		configs["��Ҫ��ʯ"]=line_values[16];
		configs["��Ҫ��Ǯ"]=line_values[17];
		configs["�������ܼ���"]=line_values[18];
		//�������������ֶ����/////////////////////////////////////////////////////////////////	
		writeFile+=templates["include"];//ͷ�ļ���Ϣ
		//��Ʒcreate()����ͷ��//////////////////////////////////////
		writeFile+=templates["head"];
		//��Ʒ��������/////////////////////////
		writeFile+=replace(templates["����"],"$1",configs["����"]);
		//��Ʒ���ĵ�λ/////////////////////////
		if(configs["��λ"]!="")
			writeFile+=replace(templates["��λ"],"$1",configs["��λ"]);
		//��ƷͼƬ��ʾ/////////////////////////
		if(configs["��ƷͼƬ"]!="")
			writeFile+=templates["��ƷͼƬ"];
		//��Ʒ��������/////////////////////////
		writeFile+=replace(templates["����"],"$1",configs["����"]);
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
		//�Ƿ�������Ʒ/////////////////////////
		if(configs["�Ƿ�������Ʒ"]!="")
			writeFile+=replace(templates["�Ƿ�������Ʒ"],"$1",configs["�Ƿ�������Ʒ"]);
		//�Ƿ��ܴ洢�ֿ�����/////////////////////////
		if(configs["�Ƿ��ܴ洢�ֿ�����"]!="")
			writeFile+=replace(templates["�Ƿ��ܴ洢�ֿ�����"],"$1",configs["�Ƿ��ܴ洢�ֿ�����"]);
		//����Լ��ı�־/////////////////////////////
		if(configs["����Լ��ı�־"]!="")
			writeFile+=replace(templates["����Լ��ı�־"],"$1",configs["����Լ��ı�־"]);
		//��ֵ///////////////////////////////////////
		if(configs["��ֵ"]!="")
			writeFile+=replace(templates["��ֵ"],"$1",configs["��ֵ"]);
		//��������///////////////////////////////////////
		if(configs["��������"]!="")
			writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		//ѧϰ���ܵȼ�����/////////////////////////////////
		if(configs["ѧϰ���ܵȼ�����"]!=""){
			writeFile+=replace(templates["ѧϰ���ܵȼ�����"],"$1",configs["ѧϰ���ܵȼ�����"]);
			string itemLevel = (string)configs["ѧϰ���ܵȼ�����"];
			string stmpname = configs["�ļ���"];
			if(!all_lines_attributeLimit[itemLevel])
				all_lines_attributeLimit[itemLevel] = "";
			all_lines_attributeLimit[itemLevel] += stmpname+",";
		}
		//ѧϰ����ְҵ����/////////////////////////////////
		if(configs["ѧϰ����ְҵ����"]!="")
			writeFile+=replace(templates["ѧϰ����ְҵ����"],"$1",configs["ѧϰ����ְҵ����"]);
		//�������ܼ���/////////////////////////////////
		if(configs["�������ܼ���"]!="")
			writeFile+=replace(templates["�������ܼ���"],"$1",configs["�������ܼ���"]);
		//��������Ҫ����ʯ����////////////////////////////////////
		if(configs["��Ҫ��ʯ"]!="")
			writeFile+=replace(templates["��Ҫ��ʯ"],"$1",configs["��Ҫ��ʯ"]);
		//��������Ҫ�Ľ�Ǯ///////////////////////////
		if(configs["��Ҫ��ʯ"]!="")
			writeFile+=replace(templates["��Ҫ��Ǯ"],"$1",configs["��Ҫ��Ǯ"]);
		//create()����β��
		writeFile+=templates["foot"];
		//�Ķ�����,��Ϊ����������ͱ���������,���ֲ�ͬ����Ķ��ӿ�
		if(configs["�������ܼ���"]!="")
			writeFile+=templates["�����Ķ�����"];
		else
			writeFile+=templates["�����Ķ�����"];
		//���ɸü�����
		array dir = configs["�ļ���"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+configs["�ļ���"],writeFile);
	}
	return 1;
}
