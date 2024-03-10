#define ROOTDIR "./"
//#include <command.h>
#define ROOT "/usr/local/games/xiand"
int main(int argc, array(string) argv){
mapping(string:string) templates =([]);
//�������ɰ���Ʒ�б�
mapping(string:string) all_lines_attributeLimit=([]);
////////////
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_BOOK;\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";
templates["picture"]="\tpicture=name;\n";
templates["��Ʒ����"]="\tname_cn=\"$1\";\n";
templates["��λ"]="\tunit=\"��\";\n";
templates["����"]="\tdesc=\"$1\\n\";\n";
///////////
templates["����"]="\tset_item_canDrop(1);\n";
templates["����"]="\tset_item_canGet(1);\n";
templates["����"]="\tset_item_canTrade(1);\n";
templates["����"]="\tset_item_canSend(1);\n";
templates["�ֿ�"]="\tset_item_canStorage(1);\n";
templates["�䷽���"]="\tset_peifang_kind(\"$1\");\n";
templates["��Ʒ����"]="\tset_peifang_type(\"$1\");\n";
templates["���"]="\tpeifang_id=$1;\n";
templates["��Ʒ�ȼ�"]="\tlevel_limit=$1;\n";
templates["��Ҫ���ܵȼ�"]="\tviceskill_level=$1;\n";
templates["foot"]="}\n";
////////////////////////////////////////////////////////////
templates["����"]="int read(){\n\tint result=::duanzao_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
templates["����"]="int read(){\n\tint result=::liandan_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
templates["�÷�"]="int read(){\n\tint result=::caifeng_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
templates["�Ƽ�"]="int read(){\n\tint result=::zhijia_read();\n\tif(read_flag==0){\n\t\tremove();\n\t}\n\treturn result;\n}\n";
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
	for(int i=0;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		write("������Ʒ:"+line_values[3]+" Ŀ¼:"+line_values[5]+"\n");
		//�������������ֶο�ʼ/////////////////////////////////////////////////////////////////	
		configs["���"]=line_values[0];
		configs["�䷽���"]=line_values[1];
		configs["��Ʒ����"]=line_values[2];
		configs["��Ʒ����"]=line_values[3];
		configs["����"]=line_values[4];
		configs["�ļ���"]=line_values[5];
		configs["��Ʒ�ȼ�"]=line_values[6];
		configs["��Ҫ���ܵȼ�"]=line_values[7];
		//�������������ֶ����/////////////////////////////////////////////////////////////////	
		writeFile+=templates["include"];//ͷ�ļ���Ϣ
		//��Ʒcreate()����ͷ��//////////////////////////////////////
		writeFile+=templates["head"];
		writeFile+=replace(templates["��Ʒ����"],"$1",configs["��Ʒ����"]);
		writeFile+=templates["��λ"];
		writeFile+=templates["picture"];
		//��Ʒ��������/////////////////////////
		writeFile+=replace(templates["����"],"$1",configs["����"]);
		///////////////////////////////////	
		writeFile+=templates["����"];
		writeFile+=templates["����"];
		writeFile+=templates["����"];
		writeFile+=templates["����"];
		writeFile+=templates["�ֿ�"];
		////////////////////////////////////	
		if(configs["�䷽���"]!=""){
			writeFile+=replace(templates["�䷽���"],"$1",configs["�䷽���"]);
			writeFile+=replace(templates["��Ʒ����"],"$1",configs["��Ʒ����"]);
		}
		if(configs["���"]!="")
			writeFile+=replace(templates["���"],"$1",configs["���"]);
		if(configs["��Ʒ�ȼ�"]!="")
			writeFile+=replace(templates["��Ʒ�ȼ�"],"$1",configs["��Ʒ�ȼ�"]);
		if(configs["��Ҫ���ܵȼ�"]!="")
			writeFile+=replace(templates["��Ҫ���ܵȼ�"],"$1",configs["��Ҫ���ܵȼ�"]);
		if(configs["��Ʒ�ȼ�"]!=""){
			string itemLevel = (string)configs["��Ʒ�ȼ�"];
			string stmpname = configs["�ļ���"];
			if(!all_lines_attributeLimit[itemLevel])
				all_lines_attributeLimit[itemLevel] = "";
			all_lines_attributeLimit[itemLevel] += stmpname+",";
		}
		//create()����β��
		writeFile+=templates["foot"];
		//�Ķ�����
		if(configs["�䷽���"]!=""){
			if(configs["�䷽���"]=="duanzao")
				writeFile+=templates["����"];
			if(configs["�䷽���"]=="liandan")
				writeFile+=templates["����"];
			if(configs["�䷽���"]=="caifeng")
				writeFile+=templates["�÷�"];
			if(configs["�䷽���"]=="zhijia")
				writeFile+=templates["�Ƽ�"];
		}
		//д���ļ�	
		array dir = configs["�ļ���"]/"/";
		if(!Stdio.exist(ROOTDIR+dir[1]))
			mkdir(ROOTDIR+dir[1]);
		//werror(ROOTDIR+dir[0]+"/"+dir[1]+"\n");
		Stdio.write_file(ROOTDIR+dir[1]+"/"+dir[2],writeFile);
	}
	//�������ɼ������б�,���յȼ�д�뼼�����ɱ���
	string itemPath = ROOT + "/gamelib/data/";
	if(!Stdio.exist(itemPath)) 
		mkdir(itemPath);
	string contList = "";
	if(all_lines_attributeLimit&&sizeof(all_lines_attributeLimit)){
		foreach(sort(indices(all_lines_attributeLimit)), string index)
			contList += index + "|" + all_lines_attributeLimit[index]+"\n";	
	}
	//write(itemPath+"/peifang_Items.list"+"\n");
	//write(contList+"\n");
	Stdio.append_file(itemPath+"/peifang.list",contList);
	return 1;
}
