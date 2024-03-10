//副业系统的测试模块，主要用于测试人员获得副业系统的配方信息
//

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下
#define PEIFANG_CSV ROOT "/gamelib/data/material/peifang.csv" //矿物列表

private mapping(int:array(string)) duanzao_pf = ([]);
private mapping(int:array(string)) liandan_pf = ([]);
private mapping(int:array(string)) caifeng_pf = ([]);
private mapping(int:array(string)) zhijia_pf = ([]);

void create()
{
	get_pf();
}

void get_pf()
{
	werror("==========  [PEIFANGD start!]  =========\n");
	duanzao_pf = ([]);
	liandan_pf = ([]);
	caifeng_pf = ([]);
	zhijia_pf = ([]);
	string peifangData = Stdio.read_file(PEIFANG_CSV);
	array(string) lines = peifangData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/",";
			if(sizeof(columns) == 8){
				string type = columns[1];
				string name_cn = columns[3];
				int level = (int)columns[6];
				array(string) tmp = columns[5]/"/";
				string in = name_cn +":"+tmp[2];
				if(type == "duanzao"){
					if(duanzao_pf[level] == 0)
						duanzao_pf[level] = ({in});
					else 
						duanzao_pf[level] += ({in});
				}
				else if(type == "liandan"){
					if(liandan_pf[level] == 0)
						liandan_pf[level] = ({in});
					else 
						liandan_pf[level] += ({in});
				}
				else if(type == "caifeng"){
					if(caifeng_pf[level] == 0)
						caifeng_pf[level] = ({in});
					else 
						caifeng_pf[level] += ({in});
				}
				else if(type == "zhijia"){
					if(zhijia_pf[level] == 0)
						zhijia_pf[level] = ({in});
					else 
						zhijia_pf[level] += ({in});
				}
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [PEIFANGD end!]  =========\n");
}

//主要是返回购买锻造配方的列表，可按等级来分
string query_duanzao_peifang_list(int levmin,void|int levmax)
{
	string s_rtn = "";
	if(levmax){
		foreach(sort(indices(duanzao_pf)),int level){
			if(level >= levmin && level <= levmax){
				array(string) tmp = duanzao_pf[level];
				foreach(tmp,string pf){
					array(string) tmp2 = pf/":";
					s_rtn += "["+tmp2[0]+":viceskill_peifang_buy duanzao "+tmp2[1]+" 0]\n";
				}
			}
		}
	}
	else{
		array(string) tmp = duanzao_pf[levmin];
		foreach(tmp,string pf){
			array(string) tmp2 = pf/":";
			s_rtn += "["+tmp2[0]+":viceskill_peifang_buy duanzao "+tmp2[1]+" 0]\n";
		}
	}
	return s_rtn;
}

string query_liandan_peifang_list(int levmin,void|int levmax)
{
	string s_rtn = "";
	if(levmax){
		foreach(sort(indices(liandan_pf)),int level){
			if(level >= levmin && level <= levmax){
				array(string) tmp = liandan_pf[level];
				foreach(tmp,string pf){
					array(string) tmp2 = pf/":";
					s_rtn += "["+tmp2[0]+":viceskill_peifang_buy liandan "+tmp2[1]+" 0]\n";
				}
			}
		}
	}
	else{
		array(string) tmp = liandan_pf[levmin];
		foreach(tmp,string pf){
			array(string) tmp2 = pf/":";
			s_rtn += "["+tmp2[0]+":viceskill_peifang_buy liandan "+tmp2[1]+" 0]\n";
		}
	}
	return s_rtn;
}

string query_caifeng_peifang_list(int levmin,void|int levmax)
{
	string s_rtn = "";
	if(levmax){
		foreach(sort(indices(caifeng_pf)),int level){
			if(level >= levmin && level <= levmax){
				array(string) tmp = caifeng_pf[level];
				foreach(tmp,string pf){
					array(string) tmp2 = pf/":";
					s_rtn += "["+tmp2[0]+":viceskill_peifang_buy caifeng "+tmp2[1]+" 0]\n";
				}
			}
		}
	}
	else{
		array(string) tmp = caifeng_pf[levmin];
		foreach(tmp,string pf){
			array(string) tmp2 = pf/":";
			s_rtn += "["+tmp2[0]+":viceskill_peifang_buy caifeng "+tmp2[1]+" 0]\n";
		}
	}
	return s_rtn;
}

string query_zhijia_peifang_list(int levmin,void|int levmax)
{
	string s_rtn = "";
	if(levmax){
		foreach(sort(indices(zhijia_pf)),int level){
			if(level >= levmin && level <= levmax){
				array(string) tmp = zhijia_pf[level];
				foreach(tmp,string pf){
					array(string) tmp2 = pf/":";
					s_rtn += "["+tmp2[0]+":viceskill_peifang_buy zhijia "+tmp2[1]+" 0]\n";
				}
			}
		}
	}
	else{
		array(string) tmp = zhijia_pf[levmin];
		foreach(tmp,string pf){
			array(string) tmp2 = pf/":";
			s_rtn += "["+tmp2[0]+":viceskill_peifang_buy zhijia "+tmp2[1]+" 0]\n";
		}
	}
	return s_rtn;
}
