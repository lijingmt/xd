#include <command.h>
#include <gamelib/include/gamelib.h>
// �һ�ȷ��ҳ��
int main(string arg)
{
	string s = "";
	object me = this_player();
	string type = "";  //�һ�����
	string typeDes = "";//�һ�������������
	string yushi_s = "";
	int yushi = 0;     //���ʹ�õ���ʯ��Ŀ
	int time = 0;      //�����ӵ�ʱ��
	int myTime = 0;    //ԭ�е�ʱ��
	int timeTotal = 0; //��ʱ��
	int myYushi = YUSHID->query_yushi_num(me,1);   //������ϵ�������Ŀ
	sscanf(arg,"%s %s",type,yushi_s);
	sscanf(yushi_s,"no=%d",yushi);
	if(yushi>0)
	{
		if(me->query_level() <70)
		{
			if(myYushi>=yushi)
			{
				if(type == "xiuchan"){
					time = yushi*3;       //������1����3����
					myTime = me->query_auto_learn_xiuchan();
					typeDes = "����";
				}
				else if(type == "dazuo"){
					time = yushi*12;     //������1����12����;
					myTime = me->query_auto_learn_dazuo();
					typeDes = "����";
				}
				if(myTime) //��������ʣ��� �һ� ʱ�䣬�������ʼ �һ� �����ӡ�
				{
					s += "�㵱ǰ��ʣ��"+typeDes+"ʱ��"+myTime+"����\n";
				}
				s += "ȷ��Ҫ����"+yushi+"����������"+ time +"����"+typeDes+"ʱ����\n";
				timeTotal = time + myTime;
				s += "[ȷ��:auto_learn_confirm "+type+" "+timeTotal+" "+yushi+"]\n";
				s += "\n[��������:auto_learn_set "+type+"]\n";
			}
			else
			{
				s += "��û���㹻���������ǿɲ��ṩ���˷���\n";
				s += "\n[����:look]\n";
			}
		}
		else
		{
			s += "���Ѿ�����70���ˣ����ܽ��и��������\n";
			s += "\n[����:look]\n";
		}
	}
	else
	{
		s += "�����������������0������\n";
		s += "\n[��������:auto_learn_set "+type+"]\n";
	}
	write(s);
	return 1;
}
