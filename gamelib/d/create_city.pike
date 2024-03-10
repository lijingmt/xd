//$�����ǳ�ս������ķ�����liaocheng �� 07/08/26 ������հ汾

#define ROOT "./"
int main(int argc, array(string) argv){

	mapping(string:string) templates =([]);

//ͷ����Ϣ
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\n";

templates["head"]="void create(){\n\tname=object_name(this_object());\n\tset_room_type(\"city\");\n";

templates["�ص���"]="\tname_cn=\"$1\";\n";

templates["����"]="\tdesc=\"$1\\n\";\n";

templates["����"]="\texits[\"$1\"]=ROOT \"/gamelib/d/$2\";\n";

templates["�����ǳ�"]="\tset_belong_to(\"$1\");\n";
templates["��ѯռ��"]="\tstring tmp_s = CITYD->query_captured(\"$1\");\n";
templates["���Ƿ���"]="\tif(tmp_s == \"monst\"){\n\t\troom_race=\"monst\";\n\t\tname_cn += \"(��ħռ��)\";$1\n\t\tforeach(flush_monst,string item){\n\t\t\tif(item && sizeof(item))\n\t\t\t\tadd_items(({ROOT \"/gamelib/clone/npc/\"+item}));\n\t\t}\n\t}\n\telse if(tmp_s == \"human\"){\n\t\troom_race=\"human\";\n\t\tname_cn += \"(����ռ��)\";$2\n\t\tforeach(flush_human,string item){\n\t\t\tif(item && sizeof(item))\n\t\t\t\tadd_items(({ROOT \"/gamelib/clone/npc/\"+item}));\n\t\t}\n\t}\n";
templates["�������"]="\n\t\tguarded_exits[\"$1\"]=\"$2\";\n\t\tadd_items(({ROOT \"/gamelib/clone/npc/$3\"}));";
templates["��ѯռ��"]="\tstring tmp_s = CITYD->query_captured(\"$1\");\n";

templates["����ˢnpc"]="array(string) flush_monst = ({$1});\n";
templates["����ˢnpc"]="array(string) flush_human = ({$1});\n";
templates["��ͨnpc"]="\tadd_items(({ROOT \"/gamelib/clone/npc/$1\"}));\n";

templates["������Ӫ"]="string room_race=\"$1\";\n";
templates["����ȼ�"]="static int room_level=$1;\n";

templates["foot"]="}\n";

templates["����"]="inherit WAP_ROOM;\n";

templates["��ƽ"]="int is_peaceful()\n{\n\treturn 1;\n}\n";

	array(string) all_lines;
	array(string) line_values;
	
	//��¼����ȼ�����
	string room_level_lists = "";
	//��¼����ȼ�����

	string all_data=Stdio.read_file(ROOT+argv[1]);

	all_lines=all_data/"\r\n";
	mapping configs = ([]);

	mapping links = ([]);//���ڵ�����

	mapping unlinks = ([]); //�����ڵ�����

	string tempString;
	array tempArray;
	int tempInt = 0;
	write("total num:"+sizeof(all_lines)+"\n");
	for(int i=1;i<sizeof(all_lines);i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		if(sizeof(line_values)<50){
			for (int j = sizeof(line_values);j<30;j++)
			{
				line_values+=({""});
			}
		}
		configs["�ļ���"]=line_values[0];
		if(configs["�ļ���"]==""){
			continue;
		}
		write(line_values[1]+":\n\n");
		links[configs["�ļ���"]]="1";
		if(unlinks[configs["�ļ���"]]){//�����ڿ����ӣ�ɾ��
			m_delete(unlinks,configs["�ļ���"]);
		}

		configs["�ص���"]=line_values[1];
		configs["����"]=line_values[2];
		if(configs["����"][0..0]=="\"") configs["����"]=configs["����"][1..sizeof(configs["����"])-2];
		configs["�����ǳ�"]=line_values[3];
		configs["��"]=line_values[4];
		configs["��"]=line_values[5];
		configs["��"]=line_values[6];
		configs["��"]=line_values[7];
		configs["�Ƿ�Ϊ���Ƿ���"]=line_values[8];
		configs["��ͨnpc"]=line_values[9];
		configs["��ħ����"]=line_values[10];
		configs["���忴��"]=line_values[11];
		configs["����ˢnpc"]=line_values[12];
		configs["����ˢnpc"]=line_values[13];
		configs["��ƽ"]=line_values[14];
		configs["������Ӫ"]=line_values[15];
		configs["����ȼ�"]=line_values[16];

		writeFile+=templates["include"];
		writeFile+=templates["����"];
		if(configs["������Ӫ"]!=""){
			if(configs["������Ӫ"]=="����")
				writeFile+=replace(templates["������Ӫ"],"$1","human");
			if(configs["������Ӫ"]=="��ħ")
				writeFile+=replace(templates["������Ӫ"],"$1","monst");
			if(configs["������Ӫ"]=="����")
				writeFile+=replace(templates["������Ӫ"],"$1","third");
		}
		if(configs["����ȼ�"]!=""){
			writeFile+=replace(templates["����ȼ�"],"$1",configs["����ȼ�"]);
			room_level_lists += configs["����ȼ�"]+"|"+configs["�ļ���"]+"|"+configs["�ص���"]+"\n";
		}
		if(configs["�Ƿ�Ϊ���Ƿ���"]!=""){
			array(string) tmp_arr = configs["����ˢnpc"]/"|";
			string tmp_str = "";
			for(int i=0;i<sizeof(tmp_arr);i++){
				tmp_str += "\""+tmp_arr[i]+"\",";
			}
			writeFile+=replace(templates["����ˢnpc"],"$1",tmp_str);
			tmp_arr = configs["����ˢnpc"]/"|";
			tmp_str = "";
			for(int i=0;i<sizeof(tmp_arr);i++){
				tmp_str += "\""+tmp_arr[i]+"\",";
			}
			writeFile+=replace(templates["����ˢnpc"],"$1",tmp_str);
		}
		writeFile+=templates["head"];

		writeFile+=replace(templates["�ص���"],"$1",configs["�ص���"]);
		writeFile+=replace(templates["����"],"$1",configs["����"]);
		writeFile+=replace(templates["�����ǳ�"],"$1",configs["�����ǳ�"]);
		//writeFile+=replace(templates["����"],"$1","");
		if(configs["��"]!=""){
			tempString=replace(templates["����"],"$1","east");
			writeFile+=replace(tempString,"$2",configs["��"]);
			
			if(!links[configs["��"]]){
				unlinks[configs["��"]]=configs["�ļ���"]+"��";
			}
		}
		if(configs["��"]!=""){
			tempString=replace(templates["����"],"$1","south");
			writeFile+=replace(tempString,"$2",configs["��"]);
			if(!links[configs["��"]]){
				unlinks[configs["��"]]=configs["�ļ���"]+"��";
			}
		}
		if(configs["��"]!=""){
			tempString=replace(templates["����"],"$1","west");
			writeFile+=replace(tempString,"$2",configs["��"]);
			if(!links[configs["��"]]){
				unlinks[configs["��"]]=configs["�ļ���"]+"��";
			}
		}
		if(configs["��"]!=""){
			tempString=replace(templates["����"],"$1","north");
			writeFile+=replace(tempString,"$2",configs["��"]);
			if(!links[configs["��"]]){
				unlinks[configs["��"]]=configs["�ļ���"]+"��";
			}
		}
		if(configs["�Ƿ�Ϊ���Ƿ���"]!=""){
			writeFile+=replace(templates["��ѯռ��"],"$1",configs["�����ǳ�"]);
			//�����������ˢ��
			string g_tmp1 = "";
			string g_tmp2 = "";
			string g_all1 = "";
			string g_all2 = "";
			if(configs["��ħ����"]!=""){
				array(string) m_all = configs["��ħ����"]/":";
				for(int i=0;i<sizeof(m_all);i++){
					array(string) m_arr = m_all[i]/"|";
					array(string) m_arr2 = m_arr[0]/"/";
					g_tmp1 = replace(templates["�������"],"$1",m_arr[1]);
					g_tmp1 = replace(g_tmp1,"$2",m_arr2[1]);
					g_tmp1 = replace(g_tmp1,"$3",m_arr[0]);
					g_all1 += g_tmp1;
				}
			}
			if(configs["���忴��"]!=""){
				array(string) h_all = configs["���忴��"]/":";
				for(int i=0;i<sizeof(h_all);i++){
					array(string) h_arr = h_all[i]/"|";
					array(string) h_arr2 = h_arr[0]/"/";
					g_tmp2 = replace(templates["�������"],"$1",h_arr[1]);
					g_tmp2 = replace(g_tmp2,"$2",h_arr2[1]);
					g_tmp2 = replace(g_tmp2,"$3",h_arr[0]);
					g_all2 += g_tmp2;
				}
			}
			string s_all = replace(templates["���Ƿ���"],"$1",g_all1);
			s_all = replace(s_all,"$2",g_all2);
			writeFile += s_all;
		}
		if(configs["��ͨnpc"]!=""){
			array(string) n_arr = configs["��ͨnpc"]/"|";
			string n_str = "";
			for(int i=0;i<sizeof(n_arr);i++){
				n_str += replace(templates["��ͨnpc"],"$1",n_arr[i]);
			}
			writeFile += n_str;
		}

		writeFile+=templates["foot"];

		if(configs["��ƽ"]!=""){
			writeFile+=templates["��ƽ"];
		}

		array dir = configs["�ļ���"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOT+dir[0]);
		Stdio.write_file(ROOT+configs["�ļ���"],writeFile);
	}
	//Stdio.append_file("/usr/local/games/usrdata/room_level_test.log",room_level_lists);
	string log = "�������ӿ��ܴ������⣺\n\n";
	if(sizeof(unlinks)){
		array t = indices(unlinks);
		for(int i=0;i<sizeof(t);i++){
			log+="�ļ�"+unlinks[t[i]]+":"+t[i]+"\n\n";
		}
		write(log);
		//Stdio.append_file(ROOT+"create_wrong_log.log",log);
	}
	return 1;
}
