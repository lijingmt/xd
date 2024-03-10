#define ROOT "./"
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
templates["性别"]="\tsex=\"$1\";\n";
templates["性别描述"]="\tgender=\"$1\";\n";
templates["性别称谓"]="\tpronoun=\"$1\";\n";
templates["图片"]="\tpicture=\"$1\";\n";
templates["等级"]="\t_npcLevel=$1;\n";
//设置方法是固定写入的
templates["设置方法"]="\tsetup_npc();\n";
//其他附加属性
templates["自动升级"]="\t_levelup=$1;\n";
templates["精英怪"]="\t_meritocrat=$1;\n";
templates["boss怪"]="\t_boss=$1;\n";
templates["稀有怪"]="\t_rare=$1;\n";
templates["可驯服"]="\t_domestication=$1;\n";
templates["自动调整等级"]="\t_autolevel=$1;\n";
templates["任务npc"]="\t_tasknpc=$1;\n";
templates["主动攻击"]="\t_killauto=$1;\n";
templates["技能"]="\t_skillsable=$1;\n";
templates["忠诚度"]="\t_troth=$1;\n";
templates["随机话语"]="\t_randomwords=\"$1\";\n";
templates["可以装备物品"]="\t_equiped=$1;\n";
templates["刷新时间"]="\t_flushtime=$1;\n";
templates["仇恨值"]="\t_hate=$1;\n";
templates["狂暴"]="\t_fury=$1;\n";
templates["回血回蓝系数"]="\t_recovery=$1;\n";
templates["随机走动"]="\tadd_heart_beat(randomGo,60);\n\tset_heart_beat(1);\n";
templates["随机走动f"]="void randomGo(){\n\tmixed err=catch{\n\tif(query_in_combat()==1) return;\n\tif(this_object()->is(\"item\")) return;\n\tobject env = environment(this_object());\n\tarray exits = indices(env -> exits);\n\tstring go = exits[random(sizeof(exits))];\n\tstring goRoom = env -> exits[go];\n\tarray goRoomArea = goRoom/\"/\";\n\tstring thisRoom = (file_name(env)/\"#\")[0];\n\tarray thisRoomArea = thisRoom/\"/\";\n\tif(goRoomArea[sizeof(goRoomArea)-2]!=thisRoomArea[sizeof(thisRoomArea)-2]) return;\n\tthis_object()->command(\"leave \"+go);\n\t};\n\tif(err) return;\n}\n";
templates["foot"]="}\n";
templates["随机语"]="string query_words(){\n\tstring s = ::query_words();\n\ts += TASKD->query_words(this_player(),this_object());\n\treturn s;\n}\n";
templates["附加链接"]="string query_links(void|int count){\n\treturn ::query_links(count);\n}\n";
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
	string all_data=Stdio.read_file(ROOT+argv[1]);

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
		configs["阵营"]=line_values[3];
		configs["职业"]=line_values[4];
		configs["性别"]=line_values[5];
		configs["图片"]=line_values[6];
		configs["等级"]=line_values[7];
		configs["自动升级"]=line_values[8];
		configs["精英怪"]=line_values[9];
		configs["boss怪"]=line_values[10];
		configs["稀有怪"]=line_values[11];
		configs["可驯服"]=line_values[12];
		configs["自动调整等级"]=line_values[13];
		configs["任务npc"]=line_values[14];
		configs["主动攻击"]=line_values[15];
		configs["技能"]=line_values[16];
		configs["忠诚度"]=line_values[17];
		configs["随机话语"]=line_values[18];
		configs["可以装备物品"]=line_values[19];
		configs["刷新时间"]=line_values[20];
		configs["仇恨值"]=line_values[21];
		configs["狂暴"]=line_values[22];
		configs["回血回蓝系数"]=line_values[23];
		configs["随机走动"]=line_values[24];
		
		writeFile+=templates["include"];
		writeFile+=templates["head"];

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
		if(configs["性别"]!=""){
			string tmpsex = (string)configs["性别"];	
			if(tmpsex=="男")
				writeFile+=replace(templates["性别"],"$1","male");
			else if(tmpsex=="女")
				writeFile+=replace(templates["性别"],"$1","female");
			
			string tmp = (string)configs["职业"];	
			if(tmp=="人形")
			{
				if(tmpsex=="男"){
					writeFile+=replace(templates["性别描述"],"$1","男");
					writeFile+=replace(templates["性别称谓"],"$1","他");
				}
				else if(tmpsex=="女"){
					writeFile+=replace(templates["性别描述"],"$1","女");
					writeFile+=replace(templates["性别称谓"],"$1","她");
				}
			}
			else if(tmp=="野兽"||tmp=="飞禽"||tmp=="鱼"||tmp=="两栖动物"||tmp=="昆虫")
			{
				if(tmpsex=="男"){
					writeFile+=replace(templates["性别描述"],"$1","雄");
					writeFile+=replace(templates["性别称谓"],"$1","它");
				}
				else if(tmpsex=="女"){
					writeFile+=replace(templates["性别描述"],"$1","雌");
					writeFile+=replace(templates["性别称谓"],"$1","它");
				}
			}
		}
		if(configs["图片"]!=""){
				mapping(string:string) m = ([
					"人形":"humanlike",
					"野兽":"beast",
					"飞禽":"bird",
					"鱼":"fish",
					"两栖动物":"amphibian",
					"昆虫":"bugs"
				]);
				writeFile+=replace(templates["图片"],"$1",m[(string)configs["职业"]]+"_"+ (((string)configs["性别"])=="男"?"male":"female") );
		}
		if(configs["等级"]!=""){
				writeFile+=replace(templates["等级"],"$1",configs["等级"]);
				//writeFile+=replace(templates["名称"],"$1",configs["名称"]+"("+configs["等级"]+")");	
				writeFile+=replace(templates["名称"],"$1",configs["名称"]);	
		}
		
		if(configs["自动升级"]!="")
				writeFile+=replace(templates["自动升级"],"$1",configs["自动升级"]);
		if(configs["精英怪"]!="")
				writeFile+=replace(templates["精英怪"],"$1",configs["精英怪"]);
		if(configs["boss怪"]!="")
				writeFile+=replace(templates["boss怪"],"$1",configs["boss怪"]);
		if(configs["稀有怪"]!="")
				writeFile+=replace(templates["稀有怪"],"$1",configs["稀有怪"]);
		if(configs["可驯服"]!="")
				writeFile+=replace(templates["可驯服"],"$1",configs["可驯服"]);
		if(configs["自动调整等级"]!="")
				writeFile+=replace(templates["自动调整等级"],"$1",configs["自动调整等级"]);
		if(configs["任务npc"]!="")
				writeFile+=replace(templates["任务npc"],"$1",configs["任务npc"]);
		if(configs["主动攻击"]!="")
				writeFile+=replace(templates["主动攻击"],"$1",configs["主动攻击"]);
		if(configs["技能"]!="")
				writeFile+=replace(templates["技能"],"$1",configs["技能"]);
		if(configs["忠诚度"]!="")
				writeFile+=replace(templates["忠诚度"],"$1",configs["忠诚度"]);
		if(configs["随机话语"]!="")
				writeFile+=replace(templates["随机话语"],"$1",configs["随机话语"]);
		if(configs["可以装备物品"]!="")
				writeFile+=replace(templates["可以装备物品"],"$1",configs["可以装备物品"]);
		if(configs["刷新时间"]!="")
				writeFile+=replace(templates["刷新时间"],"$1",configs["刷新时间"]);
		if(configs["仇恨值"]!="")
				writeFile+=replace(templates["仇恨值"],"$1",configs["仇恨值"]);
		if(configs["狂暴"]!="")
				writeFile+=replace(templates["狂暴"],"$1",configs["狂暴"]);
		if(configs["回血回蓝系数"]!="")
				writeFile+=replace(templates["回血回蓝系数"],"$1",configs["回血回蓝系数"]);
		
		//以上属性确定之后，需要自动设置该属性npc
		writeFile+=templates["设置方法"];
		
		if(configs["随机走动"]!="")
			writeFile+=templates["随机走动"];
		writeFile+=templates["foot"];
		if(configs["随机走动"]!="")
			writeFile+=templates["随机走动f"];
		writeFile+=templates["随机语"];
		writeFile+=templates["附加链接"];
		writeFile+=templates["死亡处理"];
		array dir = configs["文件名"]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOT+dir[0]);
		Stdio.write_file(ROOT+configs["文件名"],writeFile);
	}
	return 1;
}
