#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ�����䷽�Ͳ��ϣ����ڲ���
int main(string arg)
{
	string s = "";
	object me=this_player();
	object ob ;
	if(!arg){
		s += "�����������������õ�����Ʒ�ļ���,\n";
		s += "��������ļ���ǰ�水����������Ӧ��Ŀ¼,\n";
		s += "·���б����£�\n";
		s += "���ϣ�material/\n�����䷽��peifang/liandan/\n�����䷽��peifang/duanzao/\n�Ƽ��䷽��peifang/zhijia/\n";
		s += "�÷��䷽��peifang/caifeng/\n";
		s += "�ɼ���԰ֲ��õ��Ĳ��ϣ�home/mature/plant/\n";
		s += "[string nm:...]\n";
		s += "[submit �ύ:test_get_item ...]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		string fileName = "";
		sscanf(arg,"nm=%s",fileName);
		string nameCn = "";
		mixed err = catch{
			ob = clone(ITEM_PATH+fileName);
		};
		if(!err&&ob){
			nameCn = ob->query_name_cn();
			if(ob->is("combine_item")){
				ob->amount = 20;
				nameCn = ob->query_short();
			}
			ob->move(me);
			s += "������"+nameCn+"\n";
		}
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
