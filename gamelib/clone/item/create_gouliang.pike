#define ROOTDIR "./"
int main(int argc, array(string) argv){
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
	array(string) all_lines;
	array(string) line_values;
	mapping (int:string) item_level_index=([]);
	string all_data=Stdio.read_file(ROOTDIR+argv[1]);
	all_lines=all_data/"\r\n";
	
	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=1;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		tempArray = all_lines[i]/",";
		
		writeFile += "#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_FEED;\n";//ͷ�ļ���Ϣ
		writeFile += "void create(){\n\tname=object_name(this_object());\n";//��Ʒcreate()����ͷ��
		//��Ʒ��������/////////////////////////
		writeFile += "\tname_cn=" + "\"" +tempArray[1]+"\";\n";
		writeFile += "\tunit=" + "\""+tempArray[2]+"\";\n";
		writeFile += "\tpicture=name;\n";
		writeFile += "\tdesc=" + "\""+tempArray[3]+"\\n\";\n";
		writeFile += "\tamount=1;\n"; 
		writeFile += "\tvalue=100;\n\tset_item_canDrop(1);\n\tset_item_canGet(1);\n\tset_item_canTrade(1);\n\tset_item_canSend(1);\n\tset_item_canStorage(1);\n";
		writeFile += "\tset_life_add(" + tempArray[4]+");\n";
		writeFile += "\tset_str_add(" +tempArray[5]+");\n";
		writeFile += "\tset_think_add("+ tempArray[6]+");\n";
		writeFile += "\tset_dex_add("+ tempArray[7]+");\n";
		writeFile += "\tset_item_type(\"feed\");\n";
		writeFile += "}";
		
		array dir = tempArray[0]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+tempArray[0],writeFile);
	}
	return 1;
}
