/***************************************************************
 *问卷调查守护进程
 *************************************************************/


#include <globals.h>
#include <gamelib/include/gamelib.h>
class question{
	string type;
	int serialNum;
	string title;
	array(string) answer;
}

/*
questionnaire映射表阿拉伯数字为索引，数组信息包括问卷类型、问题序号、问题以及问题选项，其中设置问卷类型这个选项是为了扩展使
用，即当同时出现两份以上调查问卷时，可以用问卷类型来区分
如:
questionnaire = ([1:({    1   ，   A    ，您的性别：， 男性  ，   女性，...}),...])
			问卷类型，问题序号，问题题目，问题选项1，问题选项2，...
*/
private mapping(int:question) questionnaire = ([]);
#define QUE_FILE ROOT "/gamelib/data/questionnaire.csv"

void create()
{
	load_file();
}

void load_file()
{
	questionnaire = ([]);
	string questionData = Stdio.read_file(QUE_FILE);
	array(string) lines = questionData/"\r\n";
	int id = 1;
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/",";
			question queTmp = question();
			if(sizeof(columns)){
				queTmp->type = columns[0];
				queTmp->serialNum = (int)columns[1];
				queTmp->title = columns[2];
				queTmp->answer = columns[3..(sizeof(columns)-1)];
				questionnaire[id] = queTmp;
				id ++;
			}
			else 
				werror("====string eachline maybe nuul=======\n");
		}
	}
	else 
		werror("=====read questionnaire.csv wrong in gamelib/data/questionnaire.csv====\n");
}


/*
 方法描述：获得问题题目以及问题选项
 参数：type  问卷类型
       num   序号
       cmd   需要调用的命令
*/
string get_question(string type,int num,string cmd,int total_num)
{
	array(int) tmp = sort(indices(questionnaire));
	string s = "";
	//问卷存在
	if(sizeof(tmp)){
		foreach(tmp,int eachIndex){
			question tmpQue = questionnaire[eachIndex];
			if(tmpQue){
			//werror("--tmpQue->type="+tmpQue->type+"--type="+type+"--\n");
				if(tmpQue->type==type&&tmpQue->serialNum==num){
			//werror("--tmpQue->num="+tmpQue->serialNum+"--num="+num+"--\n");
					s += tmpQue->title+"\n";
					array option = tmpQue->answer;
					for(int i=0;i<sizeof(option);i++){
						s += "["+option[i]+":"+cmd+" "+type+" "+num+" "+option[i]+" "+total_num+"]\n";
					}
				}
			}
			else s += "该问题不存在\n";
		}
	}
	else s += "问卷调查已结束\n";
	return s ;
}

/*
 答完问卷后获得的奖励
 type 问卷类型
 player 当前玩家
*/
string gain_reward(string type,object player)
{
	int level = player->query_level();
	object item_ob;
	string s = "";
	switch(type){
		case "A": {
			if(level>0&&level<=15){
				player->current_exp += 50;
				item_ob = clone(ITEM_PATH+"teyao/qinxinlu");
				item_ob->move_player(player->query_name());
				s += "50点经验和1瓶沁心露\n";
			}
			else if(level>=16&&level<=30){
				player->current_exp += 500;
				item_ob = clone(ITEM_PATH+"teyao/qinxinlu");
				item_ob->move_player(player->query_name());
				s += "500点经验和1瓶沁心露\n";
			}
			else if(level>=31&&level<=50){
				player->current_exp += 5000;
				item_ob = clone(ITEM_PATH+"teyao/qinxinlu");
				item_ob->move_player(player->query_name());
				s += "5000点经验和1瓶沁心露\n";
			}
			else if(level>=51&&level<=60){
				player->current_exp += 7000;
				item_ob = clone(ITEM_PATH+"teyao/qinxinlu");
				item_ob->move_player(player->query_name());
				s += "7000点经验和1瓶沁心露\n";
			}
			else if(level>=61&&level<=69){
				player->current_exp += 8000;
				item_ob = clone(ITEM_PATH+"teyao/qinxinlu");
				item_ob->move_player(player->query_name());
				s += "8000点经验和1瓶沁心露\n";
			}
			else if(level==70){
				item_ob = clone(ITEM_PATH+"teyao/tianhuojiu");
				item_ob->amount = 3;
				object ob2 = clone(ITEM_PATH+"teyao/yingzhiwan");
				ob2->amount = 3;
				item_ob->move_player(player->query_name());
				ob2->move_player(player->query_name());
				s += "3个【特】天火酒，3颗莹芷丸\n";
			}
			player->query_if_levelup();
			if(player->query_levelFlag())
				s += "你的等级提升到了 "+player->query_level()+" 级！\n";	
			break;
		}
	}
	return s;
}
