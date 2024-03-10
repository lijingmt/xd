#include <command.h>
#include <gamelib/include/gamelib.h>
#define ADVICE ROOT "/gamelib/etc/advice.csv" 
//#define USER_ASK  ROOT "log/user_ask.log" 

int main(string arg)
{
	string type = "";
	string content = "";
	string s = "";
	int n = 0;
	object me = this_player();
	if(!arg){
		s = "客服电话：(010)58621742（早9点到晚6点）、13810324684（节假日期间）\n您可以在此留下您宝贵的建议与游戏疑问，您的支持就是我们工作的动力！（字数限制为5-125个字符)\n";
		s += "[string ad:...]\n";
		s += "[submit 提交建议:diaocha_advice ask ...]";   
//		s += "[察看历史问题回复:user_ask askRecord]";
	}
	else{
		if(sscanf(arg,"%s %s",type,content)==2 && type=="ask"){
			array a=content/"=";
			object me = this_player();
			string question = "";
			if(a[0]=="ad"){
				int flag = 1;
				question = a[1];
				if(sizeof(question)<5){
					s = "您输入的字符个数小于5，请返回重新输入。\n";
					flag = 0;
				}
				else {
					for(int i=0;i<sizeof(question);i++){
						if( question[i]>='a'&&question[i]<='z'||question[i]>='A'&&question[i]<='Z'||question[i]>='0'&&question[i]<='9'){
							s = "您输入的是单纯的字符啊？请正确输入所提交的内容！请返回重新提问。\n";  
							flag = 0;
						}
						else{
							flag = 1;
							break;
						}
					}
				}
				if(flag){
					string newQue = String.trim_whites(question);
					if(newQue==me["/tmp/asked"]){
						s = "您已提交过相同的建议或问题了，我们会尽快处理的，不必重复提交。请返回。\n";
					}
					else{
						s = "谢谢您提出的宝贵建议！如果您的建议被我们采纳，我们将会给予您一定的奖励！\n";
						me["/tmp/asked"]=String.trim_whites(question);
						string now=ctime(time());
						//游戏区,答卷时间,游戏帐号,游戏昵称,用户问题
						Stdio.append_file(ADVICE,GAME_NAME+","+now[0..sizeof(now)-2]+","+me->name+","+me->name_cn+","+question+",\n");
					}
				}
			}
			s += "\n[返回:game_detail]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	s += "\n[返回:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
