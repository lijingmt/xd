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
		
		writeFile += "#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit GAMELIB_ROOM;\nstring room_race=\"third\";\n";//ͷ�ļ���Ϣ
		writeFile += "void create(){\n\tobject room = this_object();\n\tname=object_name(this_object());\n";//��Ʒcreate()����ͷ��
		//��Ʒ��������/////////////////////////
		writeFile += "\tname_cn=" + "\"" +tempArray[1]+"\";\n";
		writeFile += "\tdesc=" + "\""+tempArray[2]+"\\n\";\n";
		writeFile += "\tset_level_limit("+tempArray[3]+");\n";
		writeFile += "\tset_used_times(" + tempArray[4]+");\n";
		writeFile += "\tset_priceYushi(" +tempArray[5]+");\n";
		writeFile += "\tset_buff_kind(\""+ tempArray[6]+"\");\n";
		writeFile += "\tset_buff_type(\""+ tempArray[7]+"\");\n";
		writeFile += "\tset_buff_value("+ tempArray[8]+");\n";
		writeFile += "\tset_effect_time("+ tempArray[9]+");\n";
		writeFile += "\tset_wait_time("+ tempArray[10]+");\n";
		writeFile += "\tset_oprate_desc(\""+ tempArray[13]+"\");\n";
		writeFile += "}\n";
		writeFile += "string query_links(){\n\tstring tmp=\"\";\n\tobject room = this_object();\n\ttmp += \"������\"+room->query_roomNameCn()+\"\\n\\n\\n\\n\";\n";
		writeFile += "\ttmp += \""+tempArray[11]+"\\n\";\n";
		writeFile += "\ttmp += \"["+tempArray[12]+":exercise "+tempArray[0]+" 0]\\n\";\n";
		writeFile += "\ttmp += \"[����:home_function_room_list]\\n\";\n\treturn tmp;\n}\n";
		
		array dir = tempArray[0]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+tempArray[0],writeFile);
	}
	return 1;
}
