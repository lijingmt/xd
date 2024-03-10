#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_DAEMON;
//游戏中金钱系统守护进程
void create()
{
}
//得到掉落通用金钱描述
string query_other_money_cn(int m){
	string rs = "";
	if(m>=100){
		int b = m/100;
		int lf = m - b*100; 
		rs += b +"金 ";
		if(lf!=0)
			rs += lf +"银";
	}
	else
		rs += m +"银";
	return rs;
}
//得到买卖通用金钱描述
string query_store_money_cn(int m){
	string rs = "";
	if(m>=100){
		int b = m/100;
		int lf = m - b*100; 
		rs += b +"金";
		if(lf!=0)
			rs += lf +"银";
	}
	else
		rs += m +"银";
	return rs;
}

//得到供排行显示的金钱描述
//由liaocheng于07/09/04添加
string query_money_for_paihang(int m){
	string rs = "";
	int b = m/100;
	rs += b + "金";
	return rs;
}
