#define ROOTDIR "./"
int main(int argc, array(string) argv){
mapping(string:string) templates =([]);

//�������ɰ���Ʒ�б�
mapping(string:string) all_lines_attributeLimit=([]);

//��ɫ��Ʒ����������Ϣ///////////////////////////////////////////////
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_COMBINE_ITEM;\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";
templates["��Ʒ��"]="\tname_cn=\"$1\";\n";
templates["��λ"]="\tunit=\"$1\";\n";
templates["����"]="\tdesc=\"$1(������Ʒ)\\n\";\n";
templates["����"]="\tamount=1;\n\t//picture=name;\n\tset_item_task(1);\n\tset_item_canEquip(0);\n\tset_item_canDrop(1);\n\tset_item_canGet(1);\n\tset_item_canTrade(1);\n\tset_item_canSend(1);\n\tset_item_canStorage(1);\n";
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
	string all_data=Stdio.read_file(ROOTDIR+argv[1]);
	all_lines=all_data/"\r\n";
	mapping configs = ([]);
	
	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=0;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		write("������Ʒ:"+line_values[1]+" Ŀ¼:"+line_values[0]+"\n");
		//�������������ֶο�ʼ/////////////////////////////////////////////////////////////////	
		configs["�ļ���"]=line_values[0];//����Ʒ�����ļ�����·��
		configs["��Ʒ��"]=line_values[1];//����Ʒ��������
		configs["��λ"]=line_values[3];//����Ʒ��λ����
		configs["����"]=line_values[4];//����Ʒ��������
		
		writeFile+=templates["include"];//ͷ�ļ���Ϣ
		//��Ʒcreate()����ͷ��//////////////////////////////////////
		writeFile+=templates["head"];
		//��Ʒ��������/////////////////////////
		writeFile+=replace(templates["��Ʒ��"],"$1",configs["��Ʒ��"]);
		//��Ʒ���ĵ�λ/////////////////////////
		if(configs["��λ"]!="")
			writeFile+=replace(templates["��λ"],"$1",configs["��λ"]);
		//��Ʒ��������/////////////////////////
		if(configs["����"] =="" || configs["����"] == "������Ʒ")
			writeFile+=replace(templates["����"],"$1",configs["��Ʒ��"]);
		else
			writeFile+=replace(templates["����"],"$1",configs["����"]);
		writeFile+=templates["����"];	
		writeFile+=templates["foot"];
		//���ɸ���Ʒ�ļ�
		array dir = configs["�ļ���"]/"/";
		if(!Stdio.exist(ROOTDIR+dir[0]))
			mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+configs["�ļ���"],writeFile);
	}
	return 1;
}
