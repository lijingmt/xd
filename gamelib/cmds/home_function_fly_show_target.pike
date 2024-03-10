#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "\n\n";
	if(HOMED->if_have_home(me->query_name()))
	{
		string targetPath = room->flyTarget;
		if(targetPath)
		{
			object targetRoom = 0;
			mixed err = catch{
				targetRoom = clone(targetPath);
			};
			if(!err && targetRoom){
				s += "��Ŀǰ�����ķ����ǣ�"+ targetRoom->query_name_cn()+"\n";
				s += "�����Ҫ�ı�������䣬�������ӻ����˴������µĴ��������\n";
				array(string) tmp = targetPath/("gamelib/d/");
				string roomPath = tmp[1];
				s += "[ȷ�ϴ���:qge74hye "+ roomPath +"]\n";
			}
			else
			{
				s +=  "���ڴ�����̫�ȶ�����ʱδ�ܷ�����Ĵ���Ŀ�ĵأ��������ʣ�����ͷ���ϵ��\n";
			}
		}
		else
		{
			s += "����δָ��������ķ��䡣\n";
			s += "���Ƚ�����Ҫ���͵ķ��䣬Ȼ��ʹ�� '�������'ʵ�ֹ�����������ɷ������͡�\n";
			s += "����ӷ���ʱ��������ѻ��һ�Ŵ�������������Ҫ�ı�������䣬�������ӻ����˴������µĴ��������\n";
		}
	}
	else
	{
		s += "�����ڻ�û�м�԰��������ɸò���\n";

	}
	s += "\n[����:look]\n";
	write(s);
	return 1;
}
