#include <command.h>
#include <gamelib/include/gamelib.h>
#define ASK "txonline/data/ask1.csv" 
#define USER_REPLY  ROOT "log/reply1.csv" 

int main(string arg)
{
	object me = this_player();
	string s = "";
	string type = "";//�ʾ��ʶ
	int totalQue = 0;//���ʾ��ܹ��е���������
	sscanf(arg,"%s %d",type,totalQue);
	//type��ʾ���ʾ����Ƿ��ʾ��磺�Բμӹ���һ���ʾ�������¼Ϊme["/diaochaFlag][1]==1
	if(!me["/diaochaFlag"]){
		me["/diaochaFlag"] = ([]);
		if(!me["/diaochaFlag"][type]){
			me["/diaochaFlag"][type] = 0;
		}
	}
	if(me["/diaochaFlag"][type]==1){
		s = "���Ѿ������ɵ��ʾ�����ˣ�ÿλ��������ʾ�һ�Σ��뷵�ء�\n \n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		me["/diaochaTmp"] = ""; 
		s = "�ɵ��ʾ���飺\nÿλ��������ʾ�һ�Σ��������Ļش��ʾ��е����⣬���ɻ������ҩƷ�����齱����\n";
		s += DIAOCHAD->get_question(type,1,"diaocha_detail",totalQue);
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
}


