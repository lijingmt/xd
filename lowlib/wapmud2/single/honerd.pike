/* lowlib/wapmud2/single/honerd.pike
 * 荣誉系统管理类
 * gamelib/clone/user.pike中添加
	int honerpt=荣誉值
	int honerlv=荣誉等级 
 * 荣誉系统守护进程
 * @author calvin 
 * $Date: 2007/03/29 17:26:40 $
 */

/*
一天内多次击杀同一个目标，荣誉值的获得会递减，第一次为100%获得荣誉，
第二次为75%，第三次为50%，第四次以后无荣誉
需要在玩家身上设置一个动态映射表,记录每次被那一个玩家杀死，记录他的id和次数
超过上面的限制，荣誉值递减，一天一共1440分钟,即便10分钟被不同的玩家杀一次，一天
也就144个记录就够了
下面的数据放置在用户me["/plus/daily/honer_map"]中
并在gamelib/single/daemons/userd.pike中的日检查中，每天更新置空
me["/plus/daily/honer_map"]=([])//mapping(string:string);
([用户id:用户杀戮自己标志-a为1次，b为2次，c为3次，d为4次无荣誉])
*/
#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_DAEMON;
#define FILE_PATH "/gamelib/data/honer/levellist"

//荣誉系统映射表：
//0|0|平民|平民
//1|200|门徒|教徒
//......
//12|409600|天尊|教主
private mapping(int:array) honer_list=([]);
//等级对应荣誉经验值的array
private array(int) honer_exp = ({819200,409600,204800,102400,51200,25600,12800,6400,3200,1600,800,400,0});

void create(){
	honer_list=([]);
	string strlist = "";
	//加载荣誉映射表
	strlist = Stdio.read_file(ROOT+FILE_PATH);
	array title = ({});
	if(strlist&&sizeof(strlist)){
		title = strlist/"\n";
		title -= ({""});	
	}
	if(title&&sizeof(title)){
		foreach(title,string cont){
			array(string) arrt1 = cont/"|";
			arrt1 -= ({""});
			int index = 0;
			string t1 = (string)arrt1[0];
			sscanf(t1,"%d",index);
			string t2 = (string)arrt1[1]+"|"+(string)arrt1[2]+"|"+(string)arrt1[3];
			array arrt2 = t2/"|";
			arrt2 -= ({""});
			honer_list[index] = arrt2;
		}
	}
	/*
	string prts = "";
	foreach(indices(honer_list),int index){
		prts += "等级:"+index+"\n";
		foreach(honer_list[index],string tmp){
			prts += tmp+"|";
		}
		prts += "--------\n";
	}
	werror(prts);
	*/
}
//得到荣誉级别对应描述对象
array query_honer_m(int hlevel)
{
	array atmp = ({});
	atmp = (array)honer_list[hlevel];		
	return atmp;
}
//得到荣誉级别对应称谓
//200|门徒|教徒
//......
//409600|天尊|教主
string query_honer_level_desc(int hlevel, string rid)
{
	string honerDesc = "";
	array atmp = ({});
	atmp = (array)honer_list[hlevel];
	if(rid=="human")
		honerDesc += (string)atmp[1];//人类
	else if(rid=="monst")
		honerDesc += (string)atmp[2];//妖魔
	return honerDesc;
}
//得到荣誉级别对应需要的荣誉点
//1|200|门徒|教徒
//......
//12|409600|天尊|教主
int query_honer_level_point(int level)
{
	int honerPoint = 0;
	array atmp = ({});
	atmp = (array)honer_list[level];
	string need_pt = (string)atmp[0];
	sscanf(need_pt,"%d",honerPoint);
	return honerPoint;
}
//得到荣誉点对应荣誉级别
//1  200|门徒|教徒
//12  409600|天尊|教主
int query_honer_point_level(int hpoint)
{
	int honerlevel = 0;
	foreach(indices(honer_list),int level){
		array atmp = ({});
		atmp = (array)honer_list[level];
		string pt = (string)atmp[0];
		int cur_pt = 0;
		sscanf(pt,"%d",cur_pt);
		if(hpoint>cur_pt){
			honerlevel = level+1;	
			break;
		}
	}
	return honerlevel;
}
//刷新荣誉点对应荣誉级别
int flush_honer_level(int hpoint,int hlevel){
	int honerlevel = 0;
	for(int i=0;i<sizeof(honer_exp);i++){
		if(hpoint>=honer_exp[i]){
			honerlevel = 12-i;
			break;
		}
	}
	return honerlevel;
	/*
	int honerlevel = 0;
	foreach(indices(honer_list),int level){
		array atmp = ({});
		atmp = (array)honer_list[level];
		string pt = (string)atmp[0];
		int cur_pt = 0;
		sscanf(pt,"%d",cur_pt);
		if(hlevel<level&&hpoint>cur_pt)
			honerlevel++;
	}
	return honerlevel;
	*/
}
//玩家被杀荣誉接口，记录信息在玩家信息中，并将会在gamelib/single/daemons/userd.pike中，每天清空一次
//有荣誉，就返回给杀人者荣誉，否则处理完之后返回 0 
//me["/plus/daily/honer_map"]=([])//mapping(string:string);
//([用户id:用户杀戮自己标志-a为1次，b为2次，c为3次，d为4次无荣誉])
//一天内多次击杀同一个目标，荣誉值的获得会递减，第一次为100%获得荣誉，
//第二次为75%，第三次为50%，第四次以后无荣誉
//团队杀人，一个房间内的平均分配荣誉值
int honer_killed(object enemy,object who){
	if(!who||!enemy){
		//werror("\n    who||enemy is null return 0    \n");
		return 0;
	}
	//不管获得荣誉与否，调用者为杀人者，将其杀人数++
	enemy->killcount++;
	int gain_honer = 0;//击杀者应得荣誉值
	int flag = 1;
	if(who["/plus/daily/honer_map"]&&sizeof(who["/plus/daily/honer_map"])){
		//werror("\n    "++"    \n");
		//轮训看击杀者是否在曾经击杀过该玩家的映射表中
		foreach(indices(who["/plus/daily/honer_map"]),string enemyid){
			//被该敌对玩家有过击杀记录，看记录次数，得到应给的荣誉值
			if(enemyid == enemy->query_name()){
				//werror("\n   enemyid=enemy->name= "+enemy->query_name()+"    \n");
				string htype = (string)who["/plus/daily/honer_map"][enemyid]; 
				//werror("\n   htype=["+htype+"]    \n");
				if(htype=="a"){
					gain_honer = query_gain_honer(enemy,who,1);
					//给了击杀者荣誉点之后，需要将击杀记录增加到下一个等级
					who["/plus/daily/honer_map"][enemy->query_name()] = "b";
				}
				else if(htype=="b"){
					gain_honer = query_gain_honer(enemy,who,2);
					who["/plus/daily/honer_map"][enemy->query_name()] = "c";
				}
				else if(htype=="c"){
					gain_honer = query_gain_honer(enemy,who,3);
					who["/plus/daily/honer_map"][enemy->query_name()] = "d";
				}
				else if(htype=="d"){
					gain_honer = 0;	
					who["/plus/daily/honer_map"][enemy->query_name()] = "d";
				}
				flag = 0;//被击杀记录中有敌人的纪录
				break;
			}
		}
		//该玩家第一次被敌人击杀，记录击杀者到映射表，并给击杀者应得荣誉值
		if(flag){
			who["/plus/daily/honer_map"][enemy->query_name()] = "a";
			gain_honer = query_gain_honer(enemy,who,1);
		}
	}
	else{
		who["/plus/daily/honer_map"][enemy->query_name()] = "a";
		gain_honer = query_gain_honer(enemy,who,1);
	}
	return gain_honer;
}
//根据杀人者和被杀者荣誉等级和本身等级，返回杀人者应得荣誉值
//击杀相同阵营玩家获得荣誉值=被杀玩家等级+荣誉级别*10
//击杀不同阵营玩家获得荣誉值=被击杀者等级+被击杀者荣誉级别*20
//荣誉值在小队的分配方式上为按照人数直接平均分配
private int query_gain_honer(object enemy,object who, int diff){
	int gain = 0;
	int level = who->query_level();
	int hlevel = who->honerlv;
	int base = 1;
	if(enemy->query_raceId()==who->query_raceId()){
		//相同阵营
		base = level + hlevel*10;
	}
	else if(enemy->query_raceId()!=who->query_raceId()){
		//不同阵营
		base = level + hlevel*20;
	}
	switch(diff){
		case 1:
			gain = base;
			break;
		case 2:
			gain = base*75/100;
			break;
		case 3:
			gain = base*50/100;
			break;
		case 4:
			gain = 0;
			break;
	}
	return gain;
}

//玩家被杀获得轮回值接口，记录信息在玩家信息中，并将会在gamelib/single/daemons/userd.pike中，每天清空一次
//有轮回值，就返回给杀人者轮回值，否则处理完之后返回 0 
//me->get_once_day["lunhui_map"]=([])//mapping(string:string);
//([用户id:用户杀戮自己标志-a为1次，b为2次，c为3次，d为4次无轮回])
//一天内多次击杀同一个目标，轮回值的获得会递减，第一次为100%获得轮回，
//第二次为75%，第三次为50%，第四次以后无轮回
//团队杀人，一个房间内的平均分配轮回值
int lunhui_killed(object enemy,object who){
	if(!who||!enemy){
		//werror("\n    who||enemy is null return 0    \n");
		return 0;
	}
	//不管获得轮回与否，调用者为杀人者，将其杀人数++
	int gain_lunhui = 0;//击杀者应得轮回值
	int flag = 1;
	if(who->get_once_day["lunhui_map"]&&sizeof(who->get_once_day["lunhui_map"])){
		//werror("\n    "++"    \n");
		//轮训看击杀者是否在曾经击杀过该玩家的映射表中
		foreach(indices(who->get_once_day["lunhui_map"]),string enemyid){
			//被该敌对玩家有过击杀记录，看记录次数，得到应给的轮回值
			if(enemyid == enemy->query_name()){
				//werror("\n   enemyid=enemy->name= "+enemy->query_name()+"    \n");
				string htype = (string)who->get_once_day["lunhui_map"][enemyid]; 
				//werror("\n   htype=["+htype+"]    \n");
				if(htype=="a"){
					gain_lunhui = query_gain_lunhui(enemy,who,1);
					//给了击杀者轮回点之后，需要将击杀记录增加到下一个等级
					who->get_once_day["lunhui_map"][enemy->query_name()] = "b";
				}
				else if(htype=="b"){
					gain_lunhui = query_gain_lunhui(enemy,who,2);
					who->get_once_day["lunhui_map"][enemy->query_name()] = "c";
				}
				else if(htype=="c"){
					gain_lunhui = query_gain_lunhui(enemy,who,3);
					who->get_once_day["lunhui_map"][enemy->query_name()] = "d";
				}
				else if(htype=="d"){
					gain_lunhui = 0;	
					who->get_once_day["lunhui_map"][enemy->query_name()] = "d";
				}
				flag = 0;//被击杀记录中有敌人的纪录
				break;
			}
		}
		//该玩家第一次被敌人击杀，记录击杀者到映射表，并给击杀者应得轮回值
		if(flag){
			who->get_once_day["lunhui_map"][enemy->query_name()] = "a";
			gain_lunhui = query_gain_lunhui(enemy,who,1);
		}
	}
	else{
		who->get_once_day["lunhui_map"]=([]);
		who->get_once_day["lunhui_map"][enemy->query_name()] = "a";
		gain_lunhui = query_gain_lunhui(enemy,who,1);
	}
	return gain_lunhui;
}
//根据杀人者和被杀者轮回等级和本身等级，返回杀人者应得轮回值
//击杀魔界玩家获得轮回值=所杀玩家等级/10+所杀玩家荣誉等级;
//击杀仙界玩家获得轮回值=-(所杀玩家等级/10+所杀玩家荣誉等级);
//轮回值在小队的分配方式上为按照人数直接平均分配
private int query_gain_lunhui(object enemy,object who, int diff){
	int gain = 0;
	int level = who->query_level();
	int hlevel = who->honerlv;
	int base = 0;
	base = level/10 + hlevel;
	switch(diff){
		case 1:
			gain = base;
			break;
		case 2:
			gain = (int)(base*75/100);
			break;
		case 3:
			gain = (int)(base*50/100);
			break;
		case 4:
			gain = 0;
			break;
	}
	return gain;
}
