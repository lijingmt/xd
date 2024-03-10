#define ROOTDIR "./"
int main(int argc, array(string) argv){
mapping(string:string) templates =([]);
//白色物品基本属性信息///////////////////////////////////////////////
templates["include"]="#include <globals.h>\n#include <gamelib/include/gamelib.h>\n";
templates["head"]="void create(){\n\tname=object_name(this_object());\n";
templates["物品名"]="\tname_cn=\"$1\";\n";
templates["单位"]="\tunit=\"$1\";\n";
templates["物品图片"]="\tpicture=name;\n";
templates["描述"]="\tdesc=\"$1\\n\";\n";
templates["物品当前耐久"]="\titem_cur_dura=$1;\n";
templates["物品耐久上限"]="\titem_dura=$1;\n";
templates["复数物品单位"]="\tamount=1;\n";
//继承类型////
templates["食品"]="inherit WAP_FOOD;\n";
templates["饮料"]="inherit WAP_WATER;\n";
templates["防具"]="inherit WAP_ARMOR;\n";
templates["武器"]="inherit WAP_WEAPON;\n";
templates["首饰"]="inherit WAP_JEWELRY;\n";
templates["饰物"]="inherit WAP_DECORATE;\n";
templates["其他"]="inherit WAP_ITEM;\n";
templates["复数物品"]="inherit WAP_COMBINE_ITEM;\n";
/////////////
templates["物品类别"]="\tset_item_type(\"$1\");\n";
templates["武器物品类别"]="\tset_item_weapon_type(\"$1\");\n";
templates["物品类别下的类型"]="\tset_item_kind(\"$1\");\n";
/////////////
templates["物品力量要求"]="\tset_item_strLimit($1);\n";
templates["物品敏捷要求"]="\tset_item_dexLimit($1);\n";
templates["物品智力要求"]="\tset_item_thinkLimit($1);\n";
////////////
templates["是否唯一"]="\tset_item_only($1);\n";
templates["是否可装备"]="\tset_item_canEquip($1);\n";
templates["是否可以丢弃"]="\tset_item_canDrop($1);\n";
templates["是否可以捡起"]="\tset_item_canGet($1);\n";
templates["是否可以交易"]="\tset_item_canTrade($1);\n";
templates["是否可以赠送"]="\tset_item_canSend($1);\n";
templates["是否任务物品"]="\tset_item_task($1);\n";
templates["是否能存储仓库银行"]="\tset_item_canStorage($1);\n";
templates["玩家自己的标志"]="\tset_item_playerDesc(\"$1\");\n";
///////////
templates["价值"]="\tset_value($1);\n";
///////////
templates["物品防御力"]="\tset_equip_defend($1);\n";
templates["武器攻击下限"]="\tset_attack_power($1);\n";
templates["武器攻击上限"]="\tset_attack_power_limit($1);\n";
templates["武器速度"]="\tset_speed_power($1);\n";
///////////
templates["物品装备需要等级"]="\tset_item_canLevel($1);\n";
templates["物品装备职业限制"]="\tset_item_profeLimit(\"$1\");\n";
templates["物品装备需要技能"]="\tset_item_skill(\"$1\");\n";
//物品等级中文描述
templates["武器位置描述"]="\tif(query_item_kind()==\"single_main_weapon\")\n\t\tdesc+=\"(主手)\\n\";\n\telse if(query_item_kind()==\"single_other_weapon\")\n\t\tdesc+=\"(副手)\\n\";\n\telse if(query_item_kind()==\"double_main_weapon\")\n\t\tdesc+=\"(双手)\\n\";\n";
////////////////////////////////////////////////////////////
//附加属性信息//////////////////////////////////////////////
templates["附加力量"]="\tset_str_add($1);\n";
templates["附加敏捷"]="\tset_dex_add($1);\n";
templates["附加智力"]="\tset_think_add($1);\n";
templates["附加全属性"]="\tset_all_add($1);\n";

templates["附加闪避"]="\tset_dodge_add($1);\n";
templates["附加暴击"]="\tset_doub_add($1);\n";
templates["附加命中"]="\tset_hitte_add($1);\n";
templates["附加幸运"]="\tset_lunck_add($1);\n";

templates["附加武器伤害"]="\tset_attack_add($1);\n";
templates["附加吸收伤害"]="\tset_recive_add($1);\n";
templates["附加反弹伤害"]="\tset_back_add($1);\n";
templates["附加武器攻击力增加百分比"]="\tset_weapon_attack_add($1);\n";
templates["附加防御力"]="\tset_defend_add($1);\n";
templates["附加耐久度"]="\tset_dura_add($1);\n";

templates["是否永不磨损"]="\tset_item_canDura($1);\n";

templates["附加生命"]="\tset_life_add($1);\n";
templates["附加法力"]="\tset_mofa_add($1);\n";
templates["附加生命恢复增加"]="\tset_rase_life_add($1);\n";
templates["附加法力恢复增加"]="\tset_rase_mofa_add($1);\n";

templates["附加火系法术伤害"]="\tset_huo_mofa_attack_add($1);\n";
templates["附加冰系法术伤害"]="\tset_bing_mofa_attack_add($1);\n";
templates["附加风系法术伤害"]="\tset_feng_mofa_attack_add($1);\n";
templates["附加毒系法术伤害"]="\tset_du_mofa_attack_add($1);\n";
templates["附加特殊法术伤害"]="\tset_spec_mofa_attack_add($1);\n";
templates["附加全系法术伤害"]="\tset_mofa_all_add($1);\n";

templates["附加火焰攻击力"]="\tset_attack_huoyan_add($1);\n";
templates["附加冰霜攻击力"]="\tset_attack_bingshuang_add($1);\n";
templates["附加风刃攻击力"]="\tset_attack_fengren_add($1);\n";
templates["附加毒素攻击力"]="\tset_attack_dusu_add($1);\n";
templates["附加特殊攻击力"]="\tset_attack_spec_add($1);\n";

templates["附加火焰抗性"]="\tset_huoyan_defend_add($1);\n";
templates["附加冰霜抗性"]="\tset_bingshuang_defend_add($1);\n";
templates["附加风刃抗性"]="\tset_fengren_defend_add($1);\n";
templates["附加毒素抗性"]="\tset_dusu_defend_add($1);\n";
templates["附加全法术抗性"]="\tset_all_mofa_defend_add($1);\n";

templates["需要荣誉值"]="\tset_need_honer($1);\n";
templates["红色凹槽"]="\tset_aocao_max(\"red\",$1);\n";
templates["黄色凹槽"]="\tset_aocao_max(\"yellow\",$1);\n";
templates["蓝色凹槽"]="\tset_aocao_max(\"blue\",$1);\n";
templates["韧性"]="\tset_renxing($1);\n";
//templates["获得方式"]="\tset_need_honer($1);\n";

templates["foot"]="}\n";
////////////////////////////////////////////////////////////
	//判断输入参数合法性///////////////////////////////////////
	if(argc==2){
		if(search(argv[argc-1],".csv")!=-1)
			write("需要处理的文档名称为："+argv[argc-1]+"\n");	
		else{
			write("需要处理的文档名称为："+argv[argc-1]+"\n");	
			write("但是该文件并非一个合法的csv处理文档，请返回检查!\n");
			return 0;
		}
	}
	else{
		write("参数错误，请返回检查！\n");	
		return 0;
	}
	//判断输入参数合法性///////////////////////////////////////
	//白色物品基本属性//////////////	
	array(string) all_lines;
	array(string) line_values;
	string all_data=Stdio.read_file(ROOTDIR+argv[1]);
	all_lines=all_data/"\r\n";
	mapping configs = ([]);
	
	string tempString;
	array tempArray;
	for(int i=1;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		line_values=all_lines[i]/",";
		write("生成物品:"+line_values[1]+" 目录:"+line_values[0]+"\n");
		//基本属性设置字段开始/////////////////////////////////////////////////////////////////	
		configs["文件名"]=line_values[0];//该物品物理文件名称路径
		configs["物品名"]=line_values[1];//该物品中文名称
		configs["单位"]=line_values[2];//该物品单位名称
		configs["物品图片"]=line_values[3];//该物品图片地址
		configs["描述"]=line_values[4];//该物品中文描述
		configs["物品当前耐久"]=line_values[5];
		configs["物品耐久上限"]=line_values[6];
		configs["类型"]=line_values[7];
		configs["物品类别"]=line_values[8];//single_weapon,double_weapon,armor,jewelry.decato....
		configs["武器物品类别"]=line_values[9];//jian,dao,qiang,gun,.....
		configs["物品类别下的类型"]=line_values[10];//single_main_weapon,...neck,ring,...
		configs["物品力量要求"]=line_values[11];
		configs["物品敏捷要求"]=line_values[12];
		configs["物品智力要求"]=line_values[13];
		configs["是否唯一"]=line_values[14];
		configs["是否可装备"]=line_values[15];
		configs["是否可以丢弃"]=line_values[16];
		configs["是否可以捡起"]=line_values[17];
		configs["是否可以交易"]=line_values[18];
		configs["是否可以赠送"]=line_values[19];
		configs["是否任务物品"]=line_values[20];
		configs["是否能存储仓库银行"]=line_values[21];
		configs["玩家自己的标志"]=line_values[22];
		configs["价值"]=line_values[23];
		configs["物品防御力"]=line_values[24];
		configs["武器攻击下限"]=line_values[25];
		configs["武器攻击上限"]=line_values[26];
		configs["武器速度"]=line_values[27];
		configs["物品装备需要等级"]=line_values[28];
		configs["物品装备职业限制"]=line_values[29];
		configs["物品装备需要技能"]=line_values[30];
		//基本属性设置字段完毕/////////////////////////////////////////////////////////////////	
		
		//附加属性设置字段开始/////////////////////////////////////////////////////////////////	
		configs["附加力量"]=line_values[31];
		configs["附加敏捷"]=line_values[32];
		configs["附加智力"]=line_values[33];
		configs["附加全属性"]=line_values[34];
		configs["附加闪避"]=line_values[35];
		configs["附加暴击"]=line_values[36];
		configs["附加命中"]=line_values[37];
		configs["附加幸运"]=line_values[38];
		configs["附加武器伤害"]=line_values[39];
		configs["附加吸收伤害"]=line_values[40];
		configs["附加反弹伤害"]=line_values[41];
		configs["附加武器攻击力增加百分比"]=line_values[42];
		configs["附加防御力"]=line_values[43];
		configs["附加耐久度"]=line_values[44];
		configs["是否永不磨损"]=line_values[45];
		configs["附加生命"]=line_values[46];
		configs["附加法力"]=line_values[47];
		configs["附加生命恢复增加"]=line_values[48];
		configs["附加法力恢复增加"]=line_values[49];
		configs["附加火系法术伤害"]=line_values[50];
		configs["附加冰系法术伤害"]=line_values[51];
		configs["附加风系法术伤害"]=line_values[52];
		configs["附加毒系法术伤害"]=line_values[53];
		configs["附加特殊法术伤害"]=line_values[54];
		configs["附加全系法术伤害"]=line_values[55];
		configs["附加火焰攻击力"]=line_values[56];
		configs["附加冰霜攻击力"]=line_values[57];
		configs["附加风刃攻击力"]=line_values[58];
		configs["附加毒素攻击力"]=line_values[59];
		configs["附加特殊攻击力"]=line_values[60];
		configs["附加火焰抗性"]=line_values[61];
		configs["附加冰霜抗性"]=line_values[62];
		configs["附加风刃抗性"]=line_values[63];
		configs["附加毒素抗性"]=line_values[64];
		configs["附加全法术抗性"]=line_values[65];
		
		configs["需要荣誉值"]=line_values[66];
		configs["获得方式"]=line_values[67];
		configs["红色凹槽"]=line_values[68];
		configs["黄色凹槽"]=line_values[69];
		configs["蓝色凹槽"]=line_values[70];
		configs["韧性"]=line_values[71];
		
		//附加属性设置字段完毕/////////////////////////////////////////////////////////////////	
		
		writeFile+=templates["include"];//头文件信息
		//物品继承信息//////////////////////////////////////
		if(configs["类型"]!=""){
			if(configs["类型"]=="食品")
				writeFile+=templates["食品"];
			if(configs["类型"]=="饮料")
				writeFile+=templates["饮料"];
			if(configs["类型"]=="防具")
				writeFile+=templates["防具"];
			if(configs["类型"]=="武器")
				writeFile+=templates["武器"];
			if(configs["类型"]=="首饰")
				writeFile+=templates["首饰"];
			if(configs["类型"]=="饰物")
				writeFile+=templates["饰物"];
			if(configs["类型"]=="复数物品")
				writeFile+=templates["复数物品"];
		}
		else
			writeFile+=templates["其他"];
		//物品create()方法头部//////////////////////////////////////
		writeFile+=templates["head"];
		//物品中文名称/////////////////////////
		writeFile+=replace(templates["物品名"],"$1",configs["物品名"]);
		//物品中文单位/////////////////////////
		if(configs["单位"]!="")
			writeFile+=replace(templates["单位"],"$1",configs["单位"]);
		//物品图片标示/////////////////////////
		if(configs["物品图片"]!="")
			writeFile+=replace(templates["物品图片"],"$1",configs["物品图片"]);
		//如果是复数物品的话，加入计量单位
		if(configs["类型"]=="复数物品")
            writeFile+=templates["复数物品单位"];
		//物品中文描述/////////////////////////
		writeFile+=replace(templates["描述"],"$1",configs["描述"]);
		//物品当前耐久/////////////////////////
		if(configs["物品当前耐久"]!="")
			writeFile+=replace(templates["物品当前耐久"],"$1",configs["物品当前耐久"]);
		//物品耐久上限/////////////////////////
		if(configs["物品耐久上限"]!="")
			writeFile+=replace(templates["物品耐久上限"],"$1",configs["物品耐久上限"]);
		//物品类别/////////////////////////////
		if(configs["物品类别"]!=""){
			string tmp = (string)configs["物品类别"];
			if(tmp=="单手武器")
				writeFile+=replace(templates["物品类别"],"$1","single_weapon");
			if(tmp=="双手武器")
				writeFile+=replace(templates["物品类别"],"$1","double_weapon");
			if(tmp=="防具")
				writeFile+=replace(templates["物品类别"],"$1","armor");
			if(tmp=="首饰")
				writeFile+=replace(templates["物品类别"],"$1","jewelry");
			if(tmp=="饰物")
				writeFile+=replace(templates["物品类别"],"$1","decorate");
			if(tmp=="食品")
				writeFile+=replace(templates["物品类别"],"$1","food");
			if(tmp=="饮料")
				writeFile+=replace(templates["物品类别"],"$1","water");
		}
		//武器物品类别/////////////////////////
		if(configs["武器物品类别"]!=""){
			string tmp = (string)configs["武器物品类别"];
			if(tmp=="剑")
				writeFile+=replace(templates["武器物品类别"],"$1","jian");
			if(tmp=="刀")
				writeFile+=replace(templates["武器物品类别"],"$1","dao");
			if(tmp=="枪")
				writeFile+=replace(templates["武器物品类别"],"$1","qiang");
			if(tmp=="棍")
				writeFile+=replace(templates["武器物品类别"],"$1","gun");
			if(tmp=="杖")
				writeFile+=replace(templates["武器物品类别"],"$1","zhang");
			if(tmp=="锤")
				writeFile+=replace(templates["武器物品类别"],"$1","chui");
			if(tmp=="斧")
				writeFile+=replace(templates["武器物品类别"],"$1","fu");
			if(tmp=="匕")
				writeFile+=replace(templates["武器物品类别"],"$1","bi");
		}
		//物品类别下的类型/////////////////////
		if(configs["物品类别下的类型"]!=""){
			string tmp = (string)configs["物品类别下的类型"];
			//防具，首饰，饰物定义
			mapping(string:int) m1 = ([
				"头盔":1,
				"盔甲":2,
				"腕甲":3,
				"手套":4,
				"裤子":5,
				"鞋子":6,
				
				"戒指":7,
				"项链":8,
				"手镯":9,
				
				"披风":10,
				"挂件":11,
				"携带物":12,
				
				"双手主手武器":13,
				"单手主手武器":14,
				"单手副手武器":15
			]);
			mapping(int:string) m2 = ([
				1:"armor_head",
				2:"armor_cloth",
				3:"armor_waste",
				4:"armor_hand",
				5:"armor_thou",
				6:"armor_shoes",
				
				7:"jewelry_ring",
				8:"jewelry_neck",
				9:"jewelry_bangle",
				
				10:"decorate_manteau",
				11:"decorate_thing",
				12:"decorate_tool",
					
				13:"double_main_weapon",
				14:"single_main_weapon",
				15:"single_other_weapon"
			]);
			writeFile+=replace(templates["物品类别下的类型"],"$1",(string)m2[(int)m1[tmp]]);
		}
		//物品力量要求/////////////////////////
		if(configs["物品力量要求"]!="")
			writeFile+=replace(templates["物品力量要求"],"$1",configs["物品力量要求"]);
		//物品敏捷要求/////////////////////////
		if(configs["物品敏捷要求"]!="")
			writeFile+=replace(templates["物品敏捷要求"],"$1",configs["物品敏捷要求"]);
		//物品智力要求/////////////////////////
		if(configs["物品智力要求"]!="")
			writeFile+=replace(templates["物品智力要求"],"$1",configs["物品智力要求"]);
		//是否唯一/////////////////////////////
		if(configs["是否唯一"]!="")
			writeFile+=replace(templates["是否唯一"],"$1",configs["是否唯一"]);
		//是否可装备/////////////////////////
		if(configs["是否可装备"]!="")
			writeFile+=replace(templates["是否可装备"],"$1",configs["是否可装备"]);
		//是否可以丢弃/////////////////////////
		if(configs["是否可以丢弃"]!="")
			writeFile+=replace(templates["是否可以丢弃"],"$1",configs["是否可以丢弃"]);
		//是否可以捡起/////////////////////////
		if(configs["是否可以捡起"]!="")
			writeFile+=replace(templates["是否可以捡起"],"$1",configs["是否可以捡起"]);
		//是否可以交易/////////////////////////
		if(configs["是否可以交易"]!="")
			writeFile+=replace(templates["是否可以交易"],"$1",configs["是否可以交易"]);
		//是否可以赠送/////////////////////////
		if(configs["是否可以赠送"]!="")
			writeFile+=replace(templates["是否可以赠送"],"$1",configs["是否可以赠送"]);
		//是否任务物品/////////////////////////
		//if(configs["是否任务物品"]!="")
		//	writeFile+=replace(templates["是否任务物品"],"$1",configs["是否任务物品"]);
		//是否能存储仓库银行/////////////////////////
		if(configs["是否能存储仓库银行"]!="")
			writeFile+=replace(templates["是否能存储仓库银行"],"$1",configs["是否能存储仓库银行"]);
		//玩家自己的标志/////////////////////////////
		if(configs["玩家自己的标志"]!="")
			writeFile+=replace(templates["玩家自己的标志"],"$1",configs["玩家自己的标志"]);
		//价值///////////////////////////////////////
		if(configs["价值"]!="")
			writeFile+=replace(templates["价值"],"$1",configs["价值"]);
		//物品防御力/////////////////////////////////
		if(configs["物品防御力"]!="")
			writeFile+=replace(templates["物品防御力"],"$1",configs["物品防御力"]);
		//武器攻击下限///////////////////////////////
		if(configs["武器攻击下限"]!="")
			writeFile+=replace(templates["武器攻击下限"],"$1",configs["武器攻击下限"]);
		//武器攻击上限///////////////////////////////
		if(configs["武器攻击上限"]!="")
			writeFile+=replace(templates["武器攻击上限"],"$1",configs["武器攻击上限"]);
		//武器速度///////////////////////////////////
		if(configs["武器速度"]!="")
			writeFile+=replace(templates["武器速度"],"$1",configs["武器速度"]);
		//物品装备需要等级///////////////////////////////////
		if(configs["物品装备需要等级"]!="")
			writeFile+=replace(templates["物品装备需要等级"],"$1",configs["物品装备需要等级"]);
		//物品装备职业限制///////////////////////////////////
		if(configs["物品装备职业限制"]!=""){
			string limit = (string)configs["物品装备职业限制"];
			array(string) arr;
			if(limit&&sizeof(limit))
				arr = limit/"|";
			if(arr&&sizeof(arr)){
				foreach(arr,string index){
					if(index=="1")
						index="jianxian";
					if(index=="2")
						index="yushi";
					if(index=="3")
						index="zhuxian";
					if(index=="4")
						index="kuangyao";
					if(index=="5")
						index="wuyao";
					if(index=="6")
						index="yinggui";
					writeFile+=replace(templates["物品装备职业限制"],"$1",index);
				}
			}
		}
		//物品装备需要技能///////////////////////////////////
		if(configs["物品装备需要技能"]!="")
			writeFile+=replace(templates["物品装备需要技能"],"$1",configs["物品装备需要技能"]);
		//物品位置描述//////////////////////////////////////
		if(configs["武器物品类别"]!="")
			writeFile+=templates["武器位置描述"];
		//附加属性设置字段开始/////////////////////////////////////////////////////////////////	
		if(configs["附加力量"]!="")
			writeFile+=replace(templates["附加力量"],"$1",configs["附加力量"]);
		if(configs["附加敏捷"]!="")
			writeFile+=replace(templates["附加敏捷"],"$1",configs["附加敏捷"]);
		if(configs["附加智力"]!="")
			writeFile+=replace(templates["附加智力"],"$1",configs["附加智力"]);
		if(configs["附加全属性"]!="")
			writeFile+=replace(templates["附加全属性"],"$1",configs["附加全属性"]);
		if(configs["附加闪避"]!="")
			writeFile+=replace(templates["附加闪避"],"$1",configs["附加闪避"]);
		if(configs["附加暴击"]!="")
			writeFile+=replace(templates["附加暴击"],"$1",configs["附加暴击"]);
		if(configs["附加命中"]!="")
			writeFile+=replace(templates["附加命中"],"$1",configs["附加命中"]);
		if(configs["附加幸运"]!="")
			writeFile+=replace(templates["附加幸运"],"$1",configs["附加幸运"]);
		if(configs["附加武器伤害"]!="")
			writeFile+=replace(templates["附加武器伤害"],"$1",configs["附加武器伤害"]);
		if(configs["附加吸收伤害"]!="")
			writeFile+=replace(templates["附加吸收伤害"],"$1",configs["附加吸收伤害"]);
		if(configs["附加反弹伤害"]!="")
			writeFile+=replace(templates["附加反弹伤害"],"$1",configs["附加反弹伤害"]);
		if(configs["附加武器攻击力增加百分比"]!="")
			writeFile+=replace(templates["附加武器攻击力增加百分比"],"$1",configs["附加武器攻击力增加百分比"]);
		if(configs["附加防御力"]!="")
			writeFile+=replace(templates["附加防御力"],"$1",configs["附加防御力"]);
		if(configs["附加耐久度"]!="")
			writeFile+=replace(templates["附加耐久度"],"$1",configs["附加耐久度"]);
		if(configs["是否永不磨损"]!="")
			writeFile+=replace(templates["是否永不磨损"],"$1",configs["是否永不磨损"]);
		if(configs["附加生命"]!="")
			writeFile+=replace(templates["附加生命"],"$1",configs["附加生命"]);
		if(configs["附加法力"]!="")
			writeFile+=replace(templates["附加法力"],"$1",configs["附加法力"]);
		if(configs["附加生命恢复增加"]!="")
			writeFile+=replace(templates["附加生命恢复增加"],"$1",configs["附加生命恢复增加"]);
		if(configs["附加法力恢复增加"]!="")
			writeFile+=replace(templates["附加法力恢复增加"],"$1",configs["附加法力恢复增加"]);
		if(configs["附加火系法术伤害"]!="")
			writeFile+=replace(templates["附加火系法术伤害"],"$1",configs["附加火系法术伤害"]);
		if(configs["附加冰系法术伤害"]!="")
			writeFile+=replace(templates["附加冰系法术伤害"],"$1",configs["附加冰系法术伤害"]);
		if(configs["附加风系法术伤害"]!="")
			writeFile+=replace(templates["附加风系法术伤害"],"$1",configs["附加风系法术伤害"]);
		if(configs["附加毒系法术伤害"]!="")
			writeFile+=replace(templates["附加毒系法术伤害"],"$1",configs["附加毒系法术伤害"]);
		if(configs["附加特殊法术伤害"]!="")
			writeFile+=replace(templates["附加特殊法术伤害"],"$1",configs["附加特殊法术伤害"]);
		if(configs["附加全系法术伤害"]!="")
			writeFile+=replace(templates["附加全系法术伤害"],"$1",configs["附加全系法术伤害"]);
		if(configs["附加火焰攻击力"]!="")
			writeFile+=replace(templates["附加火焰攻击力"],"$1",configs["附加火焰攻击力"]);
		if(configs["附加冰霜攻击力"]!="")
			writeFile+=replace(templates["附加冰霜攻击力"],"$1",configs["附加冰霜攻击力"]);
		if(configs["附加风刃攻击力"]!="")
			writeFile+=replace(templates["附加风刃攻击力"],"$1",configs["附加风刃攻击力"]);
		if(configs["附加毒素攻击力"]!="")
			writeFile+=replace(templates["附加毒素攻击力"],"$1",configs["附加毒素攻击力"]);
		if(configs["附加特殊攻击力"]!="")
			writeFile+=replace(templates["附加特殊攻击力"],"$1",configs["附加特殊攻击力"]);
		if(configs["附加火焰抗性"]!="")
			writeFile+=replace(templates["附加火焰抗性"],"$1",configs["附加火焰抗性"]);
		if(configs["附加冰霜抗性"]!="")
			writeFile+=replace(templates["附加冰霜抗性"],"$1",configs["附加冰霜抗性"]);
		if(configs["附加风刃抗性"]!="")
			writeFile+=replace(templates["附加风刃抗性"],"$1",configs["附加风刃抗性"]);
		if(configs["附加毒素抗性"]!="")
			writeFile+=replace(templates["附加毒素抗性"],"$1",configs["附加毒素抗性"]);
		if(configs["附加全法术抗性"]!="")
			writeFile+=replace(templates["附加全法术抗性"],"$1",configs["附加全法术抗性"]);
		
		if(configs["获得方式"]!=""){
			if(configs["获得方式"]=="honer"){
				writeFile+="\tset_item_from(\"honer\");\n";
				if(configs["需要荣誉值"]!="")
					writeFile+=replace(templates["需要荣誉值"],"$1",configs["需要荣誉值"]);
			}	
			else if(configs["获得方式"]=="duanzao")
					writeFile+="\tset_item_from(\"duanzao\");\n";
			else if(configs["获得方式"]=="task")
					writeFile+="\tset_item_from(\"task\");\n";
			else if(configs["获得方式"]=="boss")
					writeFile+="\tset_item_from(\"boss\");\n";
		}
		if(configs["红色凹槽"]!="")
			writeFile+=replace(templates["红色凹槽"],"$1",configs["红色凹槽"]);
		if(configs["黄色凹槽"]!="")
			writeFile+=replace(templates["黄色凹槽"],"$1",configs["黄色凹槽"]);
		if(configs["蓝色凹槽"]!="")
			writeFile+=replace(templates["蓝色凹槽"],"$1",configs["蓝色凹槽"]);
		if(configs["韧性"]!="")
			writeFile+=replace(templates["韧性"],"$1",configs["韧性"]);
		//附加属性设置字段完毕/////////////////////////////////////////////////////////////////	
	
		//create()方法尾部
		writeFile+=templates["foot"];
		
		//写入文件	
		array dir = configs["文件名"]/"/";
		if(!Stdio.exist(ROOTDIR+dir[0]))
			mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+dir[0]+"/"+dir[1],writeFile);
		//werror(" write item path="+ROOTDIR+dir[0]+"/"+dir[1]+"\n");
	}
	return 1;
}
