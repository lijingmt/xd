//#include <command.h> 
#define ROOTDIR "./"

int main(int argc, array(string) argv){
mapping(string:string) templates =([]);
//ͷ����Ϣ
templates["include"]="#include <gamelib/include/gamelib.h>\n";
//��������
templates["head"]="inherit GAMELIB_NPC;\nvoid create(){\n\tname=object_name(this_object());\n";
templates["����"]="\tname_cn=\"$1\";\n";
templates["����"]="\tdesc=\"$1\\n\";\n";
templates["��Ӫ"]="\tset_raceId(\"$1\");\n";
templates["ְҵ"]="\tset_profeId(\"$1\");\n";
templates["ͼƬ"]="\tpicture=\"$1\";\n";
templates["�ȼ�"]="\t_npcLevel=$1;\n";
templates["ˢ��ʱ��"]="\t_flushtime=$1;\n";
templates["���"]="\tset_npc_type(\"$1\");\n";
//������������
templates["��������"]="\tset_base_think($1);\n";
templates["��������"]="\tset_base_dex($1);\n";
templates["��������"]="\tset_base_str($1);\n";
templates["��������"]="\tset_base_life($1);\n";
templates["���ӱ���"]="\tset_base_baoji($1);\n";
templates["��������"]="\tset_base_hitte($1);\n";
templates["��������"]="\tset_base_dodge($1);\n";
templates["װ���б�"]= "\tarray(string) equip_list=({$1});\n";
templates["��װ��"]= "\tforeach(equip_list,string equip){\n\t\tobject ob=clone(ITEM_PATH+equip);\n\t\tif(ob){\n\t\t\tob->move(this_object());\n\t\t\tif(ob->query_item_type() != \"armor\")\n\t\t\t\tthis_object()->wield(ob);\n\t\t\telse\n\t\t\t\tthis_object()->wear(ob);\n\t\t}\n\t}\n";
templates["�����б�"]="\tboss_skills=([$1]);\n";
//���÷����ǹ̶�д���
templates["���÷���"]="\tsetup_npc();\n\tset_heart_beat(1);\n}\n";
templates["��������"]="void init()\n{\n\tif(this_player()->query_raceId() != this_object()->query_raceId() && this_player()->hind == 0){\n\t\tstring s = this_object()->query_name_cn()+\"��$1\\n\";\n\t\ttell_object(this_player(),s);\n\t\tif(!this_object()->in_combat){\n\t\t\tthis_object()->flush_life();\n\t\t\tthis_object()->kill(this_player()->query_name(),0);\n\t\t}\n\t\telse\n\t\t\tthis_object()->flush_targets(this_player(),1);\n\t}\n}\n";
templates["�����"]="string query_words(){\n\tstring s = ::query_words();\n\ts += TASKD->query_words(this_player(),this_object());\n\treturn s;\n}\n";
templates["��������"]="string query_links(void|int count){\n\treturn ::query_links(count);\n}\n";
//templates["��������"]="void fight_die(){\n\t::fight_die();\n}\n";
templates["��������"]="void fight_die(){\n\t::fight_die();\n}\n";

	//�ж���������Ϸ���///////////////////////////////////////
	if(argc==2){
		if(search(argv[argc-1],".csv")!=-1)
			write("��Ҫ�����npc�ĵ�����Ϊ��"+argv[argc-1]+"\n");	
		else{
			write("��Ҫ�����npc�ĵ�����Ϊ��"+argv[argc-1]+"\n");	
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
	string centerLine = "\n";
	string all_data=Stdio.read_file(ROOTDIR+argv[1]);

	all_lines=all_data/"\r\n";

	mapping configs = ([]);

	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=1;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		write("����npc:"+line_values[1]+" Ŀ¼:"+line_values[0]+"\n");
		configs["�ļ���"]=line_values[0];
		configs["����"]=line_values[1];
		configs["����"]=line_values[2];
		configs["���"]=line_values[3];
		configs["˵��"]=line_values[4];
		configs["��Ӫ"]=line_values[5];
		configs["ְҵ"]=line_values[6];
		configs["ͼƬ"]=line_values[7];
		configs["ˢ��ʱ��"]=line_values[8];
		configs["�ȼ�"]=line_values[9];
		configs["��������"]=line_values[10];
		configs["��������"]=line_values[11];
		configs["��������"]=line_values[12];
		configs["��������"]=line_values[13];
		configs["���ӱ���"]=line_values[14];
		configs["��������"]=line_values[15];
		configs["��������"]=line_values[16];
		configs["��������"]=line_values[17];
		configs["װ���б�"]=line_values[18];
		configs["�����б�"]=line_values[19];
		
		writeFile+=templates["include"];
		writeFile+=templates["head"];

		writeFile+=replace(templates["����"],"$1",configs["����"]);
		writeFile+=replace(templates["����"],"$1",configs["����"]);
		if(configs["��Ӫ"]!=""){
			string tmp = (string)configs["��Ӫ"];	
			if(tmp=="����")
				writeFile+=replace(templates["��Ӫ"],"$1","human");
			else if(tmp=="��ħ")
				writeFile+=replace(templates["��Ӫ"],"$1","monst");
			else if(tmp=="����")
				writeFile+=replace(templates["��Ӫ"],"$1","third");
		}
		if(configs["ְҵ"]!=""){
			string tmp = (string)configs["ְҵ"];	
			if(tmp=="����")
				writeFile+=replace(templates["ְҵ"],"$1","humanlike");
			if(tmp=="Ұ��")
				writeFile+=replace(templates["ְҵ"],"$1","beast");
			if(tmp=="����")
				writeFile+=replace(templates["ְҵ"],"$1","bird");
			if(tmp=="��")
				writeFile+=replace(templates["ְҵ"],"$1","fish");
			if(tmp=="���ܶ���")
				writeFile+=replace(templates["ְҵ"],"$1","amphibian");
			if(tmp=="����")
				writeFile+=replace(templates["ְҵ"],"$1","bugs");
		}

		if(configs["ͼƬ"]!=""){
			writeFile+=replace(templates["ͼƬ"],"$1",configs["ͼƬ"]);
		}
		if(configs["�ȼ�"]!=""){
			writeFile+=replace(templates["�ȼ�"],"$1",configs["�ȼ�"]);
		}
		if(configs["���"]!="")
			writeFile+=replace(templates["���"],"$1",configs["���"]);
		if(configs["ˢ��ʱ��"]!="")
			writeFile+=replace(templates["ˢ��ʱ��"],"$1",configs["ˢ��ʱ��"]);

		if(configs["��������"]!="")
			writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		if(configs["��������"]!="")
			writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		if(configs["��������"]!="")
			writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		if(configs["��������"]!=""){
			writeFile+=replace(templates["��������"],"$1",configs["��������"]);
			writeFile+="\tthis_object()->flush_life();\n";
		}
		if(configs["���ӱ���"]!="")
			writeFile+=replace(templates["���ӱ���"],"$1",configs["���ӱ���"]);
		if(configs["��������"]!="")
			writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		if(configs["��������"]!="")
			writeFile+=replace(templates["��������"],"$1",configs["��������"]);
		if(configs["װ���б�"]!=""){
			array(string) tmp_arr = configs["װ���б�"]/"|";
			string tmp_str = "";
			for(int i=0;i<sizeof(tmp_arr);i++){
				tmp_str += "\""+tmp_arr[i]+"\",";
			}
			writeFile+=replace(templates["װ���б�"],"$1",tmp_str);
			writeFile+=templates["��װ��"];
		}
		if(configs["�����б�"]!=""){
			array(string) tmp_arr = configs["�����б�"]/"|";
			string tmp_str = "";
			for(int i=0;i<sizeof(tmp_arr);i++){
				array(string) tmp_arr2 = tmp_arr[i]/":";
				tmp_str += "\""+tmp_arr2[0]+"\":\""+tmp_arr2[1]+"\",";
			}
			writeFile+=replace(templates["�����б�"],"$1",tmp_str);
		}
		writeFile+=templates["���÷���"];
		if(configs["��������"]!="")
			writeFile+=replace(templates["��������"],"$1",configs["˵��"]);

		writeFile+=templates["�����"];
		writeFile+=templates["��������"];
		writeFile+=templates["��������"];
		array dir = configs["�ļ���"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+configs["�ļ���"],writeFile);
	}
	return 1;
}
