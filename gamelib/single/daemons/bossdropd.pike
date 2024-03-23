//boss掉落的守护程序，主要负责boss死亡后的装备物品掉落
//
//核心数据结构:
//1.定义了一个掉落列表的类 : droplist
//  droplist里有两个掉落数组，一个为装备的掉落数组 item_arr; 一个为材料配方的掉落数字 other_arr
//
//  每个boss都对应一个掉落列表类,从而形成一个总的boss掉落映射表
// mapping(string:droplist) bossdrop_m
//
//上述结构都是通过读取ROOT/gamelib/data/bossdrop.csv中的内容来建立的。
//
//由liaocheng于07/6/20开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define BOSSDROP_CSV ROOT "/gamelib/data/bossdrop.csv" //boss掉落列表

class droplist
{
	array(string) item_arr;//装备的掉落数组
	array(string) other_arr;//材料配方的掉落数组
	string spec_item;//100%掉落的特殊物品，比如霸王魔窟的boss会掉落霸王徽记
}

private mapping(string:droplist) bossdrop_m = ([]); //boss掉落总表

void create()
{
	load_csv();
}


void load_csv()
{
	werror("==========  [BOSSDROPD start!]  =========\n");
	bossdrop_m = ([]);
	string bossdropData = Stdio.read_file(BOSSDROP_CSV);
	array(string) lines = bossdropData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			droplist tmpBossdrop = droplist();
			array(string) columns = eachline/",";
			if(sizeof(columns) >= 4){
				string boss_name = columns[0];
				tmpBossdrop->item_arr = columns[1]/"|";
				tmpBossdrop->other_arr = columns[2]/"|";
				tmpBossdrop->spec_item = columns[3];
				if(bossdrop_m[boss_name] == 0)
					bossdrop_m[boss_name] = tmpBossdrop;
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [BOSSDROPD end!]  =========\n");
}

//获取boss特殊物品，如霸王魔窟boss的霸王徽记
//由lioacheng于07/12/11添加                                                                     
string get_bossdrop_specitem(string boss_name)
{
	droplist tmplist = bossdrop_m[boss_name];
	if(tmplist && sizeof(tmplist)){
		if(tmplist->spec_item)
			return(tmplist->spec_item);
		else
			return "";
	}
	else
		return "";
}

//获得原始物品的升级等级的，升级属性的物品
string get_org_converted_level(string orgitem,int boss_level){
		//orgitem="jewelry/49xingmangzhihuan";
		//werror("================orgitem:"+orgitem+"\n");
		//以下则处理比较麻烦的生成物品流程
		string item_pinyin_name=0;
		mixed err1=catch{
			item_pinyin_name=(orgitem/"/")[1];
		};
		if(err1){
			item_pinyin_name=0;
		}
		
		object ob=0;
		int org_level=boss_level;
		mixed err= catch{ob=clone(ITEM_PATH+orgitem);};
		if(!err && ob)
		{
			org_level=ob->query_item_canLevel();
			if(org_level>=boss_level)
				return orgitem;
		}
		string item_name=orgitem+"_c_"+random(100000)+"_"+boss_level;
		werror("=========92 item_name:"+item_name+"\n");
		float rate=1.01;// 计算50级以上装备的增长率，初始化为1
		if(org_level&&boss_level){
			int difference=boss_level-org_level;//生成目标装备等级和原始装备的等级之差
			if(difference<0) difference=0;
			else{
				difference=random(difference+difference);//随机增长率，最大可以达到差额的增长率
			}
			rate=((float)(org_level+difference))/(float)org_level;//增加武器属性的增长率
		}
		werror("=========102 rate:"+rate+"\n");
		//生成新的物品文件数据
		string writeback="";
		string orgfile=Stdio.read_file(ITEM_PATH+orgitem);
		if(orgfile&&sizeof(orgfile)) {
			array(string) orgfilelines=orgfile/"\n";
			orgfilelines-=({""});
			int sizelines=sizeof(orgfilelines);

			array(string) aocao_color=({"yellow","red","blue"});
			//写回到文件
			for(int k=0; k<sizelines; k++) {
				// 读取原有文件的防御值和攻击值以及攻击最大值，重置
				if(rate>1 && search(orgfilelines[k],"set_item_canLevel")!=-1){
					if(random(10000)<=1){
						//万分之2的几率出现无等级需求的装备
						writeback+="    set_item_canLevel(-1);\n"; //设置新物品的的穿戴等级
					}else{
						writeback+="    set_item_canLevel("+boss_level+");\n"; //设置新物品的的穿戴等级
					}
					
					int aocao_num=random(3)+1;//生成1-3的数字
					if(random(1000)<2)	aocao_num=4;	
					if(random(10000)<2)	aocao_num=5;
					if(random(100)>50 && search(orgfile,"set_color(")==-1 && search(orgfile,"set_aocao_max")==-1)//宝石类的不能打孔，如果装备已经有凹槽，则不在这里设置凹槽			
						writeback+="    set_aocao_max(\""+aocao_color[random(sizeof(aocao_color))]+"\","+aocao_num+");\n"; //设置新物品的的穿戴等级

					continue;					
				}else if(rate>1 && search(orgfilelines[k],"picture=name")!=-1 &&item_pinyin_name){
					werror("=======write picture as pinyin name:"+item_pinyin_name+"\n");
					writeback+="    picture=\""+item_pinyin_name+"\";\n";
				}else if(rate>1 &&search(orgfilelines[k],"set_aocao_max")!=-1 ){
					int aocao_num=random(3)+1;//生成1-3的数字
					if(random(1000)<2)	aocao_num=4;	
					if(random(10000)<2)	aocao_num=5;
					if(search(orgfile,"set_color(")==-1){//判断不是宝石类的
						writeback+="    set_aocao_max(\""+aocao_color[random(sizeof(aocao_color))]+"\","+aocao_num+");\n"; //设置新物品的的穿戴等级
					}
					else{
						writeback+=orgfilelines[k]+"\n";
					}
				}else
				if(rate>1 && search(orgfilelines[k],"set_equip_defend")!=-1){
					int set_equip_defend=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_equip_defend(%d);",nothing,set_equip_defend);
					if(set_equip_defend){
						set_equip_defend=(int)(set_equip_defend*rate);
						writeback+="    set_equip_defend("+set_equip_defend+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}
					
				}else if(rate>1 &&search(orgfilelines[k],"set_attack_power")!=-1 && search(orgfilelines[k],"set_attack_power_limit")==-1){
					int attack_power=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_attack_power(%d);",nothing,attack_power);
					if(attack_power){
						attack_power=(int)(attack_power*rate);
						writeback+="    set_attack_power("+attack_power+");\n";
					}
					else{
						writeback+=orgfilelines[k]+"\n";
					}
				}else if(rate>1 &&search(orgfilelines[k],"set_attack_power_limit")!=-1){
					int set_attack_power_limit=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_attack_power_limit(%d);",nothing,set_attack_power_limit);
					if(set_attack_power_limit){
						set_attack_power_limit=(int)(set_attack_power_limit*rate);
						writeback+="    set_attack_power_limit("+set_attack_power_limit+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}
					
				}else if(rate>1 &&search(orgfilelines[k],"set_dodge_add")!=-1){
					int set_dodge_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_dodge_add(%d);",nothing,set_dodge_add);
					if(set_dodge_add){
						set_dodge_add=(int)(set_dodge_add*rate);
						if(set_dodge_add>=20)set_dodge_add=20;//闪避最大20
						writeback+="    set_dodge_add("+set_dodge_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}
					
				}else if(rate>1 &&search(orgfilelines[k],"set_str_add")!=-1){
					int set_str_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_str_add(%d);",nothing,set_str_add);
					if(set_str_add){
						set_str_add=(int)(set_str_add*rate);
						writeback+="    set_str_add("+set_str_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}
					
				}else if(rate>1 &&search(orgfilelines[k],"set_doub_add")!=-1){
					int set_doub_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_doub_add(%d);",nothing,set_doub_add);
					if(set_doub_add){
						set_doub_add=(int)(set_doub_add*rate);
						if(set_doub_add>=20)set_doub_add=20;//暴击最大提高20%
						writeback+="    set_doub_add("+set_doub_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_life_add")!=-1){
					int set_life_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_life_add(%d);",nothing,set_life_add);
					if(set_life_add){
						set_life_add=(int)(set_life_add*rate);
						writeback+="    set_life_add("+set_life_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_rase_life_add")!=-1){
					int set_rase_life_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_rase_life_add(%d);",nothing,set_rase_life_add);
					if(set_rase_life_add){
						set_rase_life_add=(int)(set_rase_life_add*rate);
						writeback+="    set_rase_life_add("+set_rase_life_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_dex_add")!=-1){
					int set_dex_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_dex_add(%d);",nothing,set_dex_add);
					if(set_dex_add){
						set_dex_add=(int)(set_dex_add*rate);
						writeback+="    set_dex_add("+set_dex_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_think_add")!=-1){
					int set_think_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_think_add(%d);",nothing,set_think_add);
					if(set_think_add){
						set_think_add=(int)(set_think_add*rate);
						writeback+="    set_think_add("+set_think_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_hitte_add")!=-1){
					int set_hitte_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_hitte_add(%d);",nothing,set_hitte_add);
					if(set_hitte_add){
						set_hitte_add=(int)(set_hitte_add*rate);
						if(set_hitte_add>=20)set_hitte_add=20;//命中率极限20%
						writeback+="    set_hitte_add("+set_hitte_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_lunck_add")!=-1){
					int set_lunck_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_lunck_add(%d);",nothing,set_lunck_add);
					if(set_lunck_add){
						set_lunck_add=(int)(set_lunck_add*rate);
						writeback+="    set_lunck_add("+set_lunck_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_bingshuang_defend_add")!=-1){
					int set_bingshuang_defend_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_bingshuang_defend_add(%d);",nothing,set_bingshuang_defend_add);
					if(set_bingshuang_defend_add){
						set_bingshuang_defend_add=(int)(set_bingshuang_defend_add*rate);
						writeback+="    set_bingshuang_defend_add("+set_bingshuang_defend_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_huoyan_defend_add")!=-1){
					int set_huoyan_defend_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_huoyan_defend_add(%d);",nothing,set_huoyan_defend_add);
					if(set_huoyan_defend_add){
						set_huoyan_defend_add=(int)(set_huoyan_defend_add*rate);
						writeback+="    set_huoyan_defend_add("+set_huoyan_defend_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_fengren_defend_add")!=-1){
					int set_fengren_defend_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_fengren_defend_add(%d);",nothing,set_fengren_defend_add);
					if(set_fengren_defend_add){
						set_fengren_defend_add=(int)(set_fengren_defend_add*rate);
						writeback+="    set_fengren_defend_add("+set_fengren_defend_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_dusu_defend_add")!=-1){
					int set_dusu_defend_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_dusu_defend_add(%d);",nothing,set_dusu_defend_add);
					if(set_dusu_defend_add){
						set_dusu_defend_add=(int)(set_dusu_defend_add*rate);
						writeback+="    set_dusu_defend_add("+set_dusu_defend_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}	
				else if(rate>1 &&search(orgfilelines[k],"set_mofa_all_add")!=-1){
					int set_mofa_all_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_mofa_all_add(%d);",nothing,set_mofa_all_add);
					if(set_mofa_all_add){
						set_mofa_all_add=(int)(set_mofa_all_add*rate);
						writeback+="    set_mofa_all_add("+set_mofa_all_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_attack_all_add")!=-1){
					int set_attack_all_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_attack_all_add(%d);",nothing,set_attack_all_add);
					if(set_attack_all_add){
						set_attack_all_add=(int)(set_attack_all_add*rate);
						writeback+="    set_attack_all_add("+set_attack_all_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}else if(rate>1 &&search(orgfilelines[k],"set_wulichuantou_add")!=-1){
					int set_wulichuantou_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_wulichuantou_add(%d);",nothing,set_wulichuantou_add);
					if(set_wulichuantou_add){
						set_wulichuantou_add=(int)(set_wulichuantou_add*rate);
						writeback+="    set_wulichuantou_add("+set_wulichuantou_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_mofachuantou_add")!=-1){
					int set_mofachuantou_add=0;
					string nothing;
					sscanf(orgfilelines[k],"%sset_mofachuantou_add(%d);",nothing,set_mofachuantou_add);
					if(set_mofachuantou_add){
						set_mofachuantou_add=(int)(set_mofachuantou_add*rate);
						writeback+="    set_mofachuantou_add("+set_mofachuantou_add+");\n";
					}else{
						writeback+=orgfilelines[k]+"\n";
					}						
				}
				else if(rate>1 &&search(orgfilelines[k],"set_dodgechuantou_add")!=-1){//闪避属性扫描
						int set_dodgechuantou_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dodgechuantou_add(%d);",nothing,set_dodgechuantou_add);
						if(set_dodgechuantou_add){
							set_dodgechuantou_add=(int)(set_dodgechuantou_add*rate);
							writeback+="    set_dodgechuantou_add("+set_dodgechuantou_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
				else{
					writeback+=orgfilelines[k]+"\n";
				}
	/**
	set_item_profeLimit("jianxian");
	set_item_profeLimit("yushi");
	set_item_profeLimit("zhuxian");
	set_item_profeLimit("kuangyao");
	set_item_profeLimit("wuyao");
	set_item_profeLimit("yinggui");
	set_str_add(45);
	set_dex_add(45);
	set_think_add(45);
	set_doub_add(3);
	set_hitte_add(3);
	set_lunck_add(60);
	set_bingshuang_defend_add(35);
	set_huoyan_defend_add(20);
	set_fengren_defend_add(20);
	set_dusu_defend_add(20);
	*/
			}
			int write_flag=write_item_file(ITEM_PATH+item_name,writeback);
		werror("=========212 item_name:"+item_name+" write_flag "+write_flag+"\n");
			//从写回的文件中clone一个该物品返回
			if(Stdio.exist(ITEM_PATH+item_name)&&write_flag==1){
				string new_item_path = ITEM_PATH+item_name;
				program p = compile_file(new_item_path);
				object rtn_ob;
				//加入到当前进程的master中的programs中
				if(p){
					foreach(indices(master()->programs),string s){
						if(master()->programs[s]==p){//如果存在，去掉旧的
							//werror("****该新物品已经在影射中=["+new_item_path+"]****\n");
							m_delete(master()->programs,p);
						}
					}
					//将新生成对象加入master的总对象影射中
					//master()->programs[new_item_path]=p;
					rtn_ob=clone(p);
				}
				//werror("$$$$$$$$$$$$$$$$创建新物品结束$$$$$$$$$$$$$$$$$$$$\n");
				if(!rtn_ob){
					return "";
					werror("	clone新物品给玩家失败了。\n");
				}
				else
					//werror("	已成功clone了这个新的物品给玩家。\n");
					
					rtn_ob->remove();
					werror("=========212 item_name:"+item_name+" \n");
					return item_name;
					//return rtn_ob;
			}
			else
				return "";
		}
		else {
			werror("read file "+ITEM_PATH+orgitem+" wrong!!\n");
			return "";
	}
	//end 创建文件结束
}
//获得掉落的装备,并将其转化为高于原物品等级的物品，例如原始文件物品等级是50，而可以将其转为70级的同样的物品，属性等比例增加
string get_bossdrop_item_level(string boss_name,int boss_level)
{
	droplist tmplist = bossdrop_m[boss_name];
	if(tmplist && sizeof(tmplist)){
		return get_org_converted_level(tmplist->item_arr[random(sizeof(tmplist->item_arr))],boss_level);
	}
	else
		return "";
}
//获得掉落的装备
string get_bossdrop_item(string boss_name)
{
	droplist tmplist = bossdrop_m[boss_name];
	if(tmplist && sizeof(tmplist)){
		return(tmplist->item_arr[random(sizeof(tmplist->item_arr))]);
	}
	else
		return "";
}

//获得掉落的其他东西
string get_bossdrop_other(string boss_name)
{
	droplist tmplist = bossdrop_m[boss_name];
	if(tmplist && sizeof(tmplist)){
		return(tmplist->other_arr[random(sizeof(tmplist->other_arr))]);
	}
	else
		return "";
}

//获得掉落装备的个数
int get_drop_nums()
{
	int drop_num = 1;
	int np = random(100);
	if(np<10)
		drop_num = 3;
	else if(np<30)
		drop_num = 2;
	return drop_num;
}
