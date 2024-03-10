//#include <command.h> 
#define ROOTDIR "./"

int main(int argc, array(string) argv){
mapping(string:string) templates =([]);
//头部信息
templates["include"]="#include <gamelib/include/gamelib.h>\n";
//基本属性
templates["head"]="inherit GAMELIB_NPC;\nvoid create(){\n\tname=object_name(this_object());\n";
templates["名称"]="\tname_cn=\"$1\";\n";
templates["描述"]="\tdesc=\"$1\\n\";\n";
templates["阵营"]="\tset_raceId(\"$1\");\n";
templates["职业"]="\tset_profeId(\"$1\");\n";
templates["图片"]="\tpicture=\"$1\";\n";
templates["等级"]="\t_npcLevel=$1;\n";
templates["刷新时间"]="\t_flushtime=$1;\n";
templates["身份"]="\tset_npc_type(\"$1\");\n";
//其他附加属性
templates["附加智力"]="\tset_base_think($1);\n";
templates["附加敏捷"]="\tset_base_dex($1);\n";
templates["附加力量"]="\tset_base_str($1);\n";
templates["附加生命"]="\tset_base_life($1);\n";
templates["附加暴击"]="\tset_base_baoji($1);\n";
templates["附加命中"]="\tset_base_hitte($1);\n";
templates["附加闪避"]="\tset_base_dodge($1);\n";
templates["装备列表"]= "\tarray(string) equip_list=({$1});\n";
templates["穿装备"]= "\tforeach(equip_list,string equip){\n\t\tobject ob=clone(ITEM_PATH+equip);\n\t\tif(ob){\n\t\t\tob->move(this_object());\n\t\t\tif(ob->query_item_type() != \"armor\")\n\t\t\t\tthis_object()->wield(ob);\n\t\t\telse\n\t\t\t\tthis_object()->wear(ob);\n\t\t}\n\t}\n";
templates["技能列表"]="\tboss_skills=([$1]);\n";
//设置方法是固定写入的
templates["设置方法"]="\tsetup_npc();\n\tset_heart_beat(1);\n}\n";
templates["主动攻击"]="void init()\n{\n\tif(this_player()->query_raceId() != this_object()->query_raceId() && this_player()->hind == 0){\n\t\tstring s = this_object()->query_name_cn()+\"：$1\\n\";\n\t\ttell_object(this_player(),s);\n\t\tif(!this_object()->in_combat){\n\t\t\tthis_object()->flush_life();\n\t\t\tthis_object()->kill(this_player()->query_name(),0);\n\t\t}\n\t\telse\n\t\t\tthis_object()->flush_targets(this_player(),1);\n\t}\n}\n";
templates["随机语"]="string query_words(){\n\tstring s = ::query_words();\n\ts += TASKD->query_words(this_player(),this_object());\n\treturn s;\n}\n";
templates["附加链接"]="string query_links(void|int count){\n\treturn ::query_links(count);\n}\n";
//templates["死亡处理"]="void fight_die(){\n\t::fight_die();\n}\n";
templates["死亡处理"]="void fight_die(){\n\t::fight_die();\n}\n";

	//判断输入参数合法性///////////////////////////////////////
	if(argc==2){
		if(search(argv[argc-1],".csv")!=-1)
			write("需要处理的npc文档名称为："+argv[argc-1]+"\n");	
		else{
			write("需要处理的npc文档名称为："+argv[argc-1]+"\n");	
			write("但是该文件并非一个合法的csv处理文档，请返回检查!\n");
			return 0;
		}
	}
	else{
		write("参数错误，请返回检查！\n");	
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
		write("生成npc:"+line_values[1]+" 目录:"+line_values[0]+"\n");
		configs["文件名"]=line_values[0];
		configs["名称"]=line_values[1];
		configs["描述"]=line_values[2];
		configs["身份"]=line_values[3];
		configs["说话"]=line_values[4];
		configs["阵营"]=line_values[5];
		configs["职业"]=line_values[6];
		configs["图片"]=line_values[7];
		configs["刷新时间"]=line_values[8];
		configs["等级"]=line_values[9];
		configs["附加智力"]=line_values[10];
		configs["附加敏捷"]=line_values[11];
		configs["附加力量"]=line_values[12];
		configs["附加生命"]=line_values[13];
		configs["附加暴击"]=line_values[14];
		configs["附加命中"]=line_values[15];
		configs["附加闪避"]=line_values[16];
		configs["主动攻击"]=line_values[17];
		configs["装备列表"]=line_values[18];
		configs["技能列表"]=line_values[19];
		
		writeFile+=templates["include"];
		writeFile+=templates["head"];

		writeFile+=replace(templates["名称"],"$1",configs["名称"]);
		writeFile+=replace(templates["描述"],"$1",configs["描述"]);
		if(configs["阵营"]!=""){
			string tmp = (string)configs["阵营"];	
			if(tmp=="人类")
				writeFile+=replace(templates["阵营"],"$1","human");
			else if(tmp=="妖魔")
				writeFile+=replace(templates["阵营"],"$1","monst");
			else if(tmp=="中立")
				writeFile+=replace(templates["阵营"],"$1","third");
		}
		if(configs["职业"]!=""){
			string tmp = (string)configs["职业"];	
			if(tmp=="人形")
				writeFile+=replace(templates["职业"],"$1","humanlike");
			if(tmp=="野兽")
				writeFile+=replace(templates["职业"],"$1","beast");
			if(tmp=="飞禽")
				writeFile+=replace(templates["职业"],"$1","bird");
			if(tmp=="鱼")
				writeFile+=replace(templates["职业"],"$1","fish");
			if(tmp=="两栖动物")
				writeFile+=replace(templates["职业"],"$1","amphibian");
			if(tmp=="昆虫")
				writeFile+=replace(templates["职业"],"$1","bugs");
		}

		if(configs["图片"]!=""){
			writeFile+=replace(templates["图片"],"$1",configs["图片"]);
		}
		if(configs["等级"]!=""){
			writeFile+=replace(templates["等级"],"$1",configs["等级"]);
		}
		if(configs["身份"]!="")
			writeFile+=replace(templates["身份"],"$1",configs["身份"]);
		if(configs["刷新时间"]!="")
			writeFile+=replace(templates["刷新时间"],"$1",configs["刷新时间"]);

		if(configs["附加智力"]!="")
			writeFile+=replace(templates["附加智力"],"$1",configs["附加智力"]);
		if(configs["附加敏捷"]!="")
			writeFile+=replace(templates["附加敏捷"],"$1",configs["附加敏捷"]);
		if(configs["附加力量"]!="")
			writeFile+=replace(templates["附加力量"],"$1",configs["附加力量"]);
		if(configs["附加生命"]!=""){
			writeFile+=replace(templates["附加生命"],"$1",configs["附加生命"]);
			writeFile+="\tthis_object()->flush_life();\n";
		}
		if(configs["附加暴击"]!="")
			writeFile+=replace(templates["附加暴击"],"$1",configs["附加暴击"]);
		if(configs["附加命中"]!="")
			writeFile+=replace(templates["附加命中"],"$1",configs["附加命中"]);
		if(configs["附加闪避"]!="")
			writeFile+=replace(templates["附加闪避"],"$1",configs["附加闪避"]);
		if(configs["装备列表"]!=""){
			array(string) tmp_arr = configs["装备列表"]/"|";
			string tmp_str = "";
			for(int i=0;i<sizeof(tmp_arr);i++){
				tmp_str += "\""+tmp_arr[i]+"\",";
			}
			writeFile+=replace(templates["装备列表"],"$1",tmp_str);
			writeFile+=templates["穿装备"];
		}
		if(configs["技能列表"]!=""){
			array(string) tmp_arr = configs["技能列表"]/"|";
			string tmp_str = "";
			for(int i=0;i<sizeof(tmp_arr);i++){
				array(string) tmp_arr2 = tmp_arr[i]/":";
				tmp_str += "\""+tmp_arr2[0]+"\":\""+tmp_arr2[1]+"\",";
			}
			writeFile+=replace(templates["技能列表"],"$1",tmp_str);
		}
		writeFile+=templates["设置方法"];
		if(configs["主动攻击"]!="")
			writeFile+=replace(templates["主动攻击"],"$1",configs["说话"]);

		writeFile+=templates["随机语"];
		writeFile+=templates["附加链接"];
		writeFile+=templates["死亡处理"];
		array dir = configs["文件名"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+configs["文件名"],writeFile);
	}
	return 1;
}
