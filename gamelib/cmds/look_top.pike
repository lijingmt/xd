#include <command.h>
#include <gamelib/include/gamelib.h>
#include <gamelib.h>

#define RANGE 100
#define NAME 0
#define NAMECN 1
#define VALUE 2
#define PAGELEN 10
int main(string arg)
{
	object me = this_player();
	string act,value,re="";
	//re += "[��¼:record list 1]|[����:friend list 1]|[����:guild]|[����:onlineuser]|���а�\n";
	if(!arg)
		arg = "start";
	//look_top list �ȼ� 1
	sscanf(arg,"%s %s",act,value);
	//----------------------
	string zhenying="���ɡ�";
	if(me->query_raceId()=="monst")
		zhenying="������";
	string topname = me->query_name_cn()+"("+me->query_level()+"��)"+zhenying;

	TOPTEN->try_top(me->query_name(),topname,"�ȼ�",me->query_level());
	TOPTEN->try_top(me->query_name(),topname,"����",me->query_account());
	if(me->query_raceId()=="monst")
		TOPTEN->try_top(me->query_name(),topname,"����",me->killcount);
	else if(me->query_raceId()=="human"){
		TOPTEN->try_top(me->query_name(),topname,"����",me->killcount);
	}
	/*
	TOPTEN->try_top(me->query_name(),topname,"����",me->query_fight_attack());
	TOPTEN->try_top(me->query_name(),topname,"����",me->query_defend_power());
	TOPTEN->try_top(me->query_name(),topname,"����",(int)me->query_phy_dodge());
	TOPTEN->try_top(me->query_name(),topname,"�м�",(int)me->query_phy_parry());
	TOPTEN->try_top(me->query_name(),topname,"����",(int)me->query_phy_hitte());
	TOPTEN->try_top(me->query_name(),topname,"����",(int)me->query_phy_baoji());
	*/
	TOPTEN->try_top(me->query_name(),topname+"("+me->all_fee+")("+me->name+")","����",(int)me->all_fee);
	//string powers = MANAGERD->checkpower(me->name);
	//if(powers=="admin"||powers=="assist")
	//	TOPTEN->try_top(me->query_name(),topname,"����",(int)me->history_tongbao);
	//----------------------
	switch(act)
	{
		case "list":
		string type;
		int page;
		type = value;
		sscanf(value,"%s %d",type,page);
		re += "��"+type+"���а�\n";
		array record = TOPTEN->get_top(type,RANGE);
		string lr = "";
		for(int i=(page-1)*PAGELEN;i<sizeof(record)&&i<(page-1)*PAGELEN+PAGELEN;i++)
                {
                        lr += sprintf("��%d��|%s\n",i+1,record[i][NAMECN]);
                }
 		if(lr&&sizeof(lr)){
			re += lr;
			re += "��";
			for(int i=1;i<=sizeof(record)/PAGELEN+1;i++)
			{
				if(i==page)
					re += i;
				else
                                	re += sprintf("[%d:look_top list %s %d]",i,type,i);
					//re += sprintf("[%d:record list %d]",i,i);
			}
			re += "ҳ\n";
		}
		else
			re += "������ؼ�¼��\n";
                re += "[�����ϼ�:look_top]\n";
              	break;
		case "start":
		default:
		re += "�����а�\n";
		re += "----------------\n";
		re += "[�ȼ����а�:look_top list �ȼ� 1]\n";
		re += "[�������а�:look_top list ���� 1]\n";
		re += "[�������а�:look_top list ���� 1]\n";
		re += "[�������а�:look_top list ���� 1]\n";
		/*
		re += "[�������а�:look_top list ���� 1]\n";
		re += "[�������а�:look_top list ���� 1]\n";
		re += "[�������а�:look_top list ���� 1]\n";
		re += "[�м����а�:look_top list �м� 1]\n";
		re += "[�������а�:look_top list ���� 1]\n";
		re += "[�������а�:look_top list ���� 1]\n";
		*/
		string powers = MANAGERD->checkpower(me->name);
		if(powers=="admin"||powers=="assist")
			re += "[�������а�:look_top list ���� 1]\n";
		re += "----------------\n";
		break;
	}
	re += "[������Ϸ:look]\n";
	write(re);
	return 1;
}
