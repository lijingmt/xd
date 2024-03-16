#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//��������ʯ�ƹ�ҳ��

int main()
{
	object me = this_player();
	int level = 0;//��ҵ�ǰ�ȼ�
	int yushi_num = 0;//�ɻ�õı�ʯ��
	int yushi_flag = 0;//��ȡ��ʯ�ı�־λ
	int yushi_level = 0;//�����ж��û��ܷ�����ʯ�ı�־λ
	string desc="";
	level = me->query_level();
	yushi_flag = me->query_yushi_flag();
	desc += "�𾴵���ң�����ǰ��Ϸ��ɫ�ĵȼ�Ϊ"+level+"����";
	if(level >= 1){
		//desc += "�Ѿ���������ȡ������-50��\n";
		desc += "���ͻ�Ѿ�ֹͣ�ˣ��뷵�ء�\n";
		desc += "[������Ϸ:look]\n";
		write(desc);
		return 1;
	}

	int n = level/5;//�жϸõȼ����û����Ի�ö�����ʯ
	switch(n)
	{
		case 0:
			desc += "��δ�ﵽ��ȡ��ʯ��Ҫ�󣬼��������ɣ�\n";
			break;
		case 1:
			yushi_num = 1;
			break;
		case 2:
			yushi_num = 5;
			break;
		case 3:
			yushi_num = 10;
			break;
		case 4:
			yushi_num = 15;
			break;
		case 5..7:
			yushi_num = 20;
			break;
		case 8..10:
			yushi_num = 30;
			break;
		default:
			break;
	}

	if(0!=n)//����ҵȼ�������5��ʱ�Ž�����һ������
	{
		if(yushi_flag<5*n)
		{
			if(yushi_num<20)
				desc += "������ȡ" +yushi_num+ "������\n";
			else
				desc += "������ȡ" + yushi_num/10 +"����Ե��\n";
			desc += "[��ȡ��ʯ:tuiguang_get_yushi "+yushi_num+"]\n";
		}
		else
		{
			if(level<50)
				desc += "����ȡ����ʯ������δ�ﵽ�´���ȡ�ļ��𣬼���������!\n";
			else
				desc += "�Ѿ���ȡ����ʯ��\n" ;
		}
	}
	desc += "[������Ϸ:look]\n";
	write(desc);
	return 1;
}
