#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	string item_name = "";
	int count,flag;
	string tmp = ITEMSD->daoju_list(me,"equip_xiangqian_confirm "+arg,"baoshi");//�г���ұ��������еı�ʯ
	if(tmp!=""){
	//�б�ʯ
		sscanf(arg,"%s %d %d",item_name,count,flag);
		object item = present(item_name,me,count);
		s += item->query_name_cn()+"\n";;
		s += item->query_picture_url()+"\n"+item->query_desc()+"\n";
		s += item->query_content()+"\n";
		s += "--------\n\n";
		s += "��ѡ����Ҫ��Ƕ�ı�ʯ��\n";
		s += "\n";
		s += tmp;
	}
	else{
	//û��ʯ
		s += "��û�б�ʯ�����ܰ�����Ƕ\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
