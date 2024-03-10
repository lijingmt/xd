#include <command.h>
#include <gamelib/include/gamelib.h>
#define	PAGE_LENGTH 10

int main(string arg)
{
	object me = this_player();
	int pageNum = 0;                                                                                                     
	if(arg&&sizeof(arg))
		sscanf(arg,"%d",pageNum);
	string s = "[��������Ʒ:inventory_vendue]\n";
	if(me->sid == "5dwap") 
		s = "���������ο����棬�޷����������Ʒ\n";
	array(mapping(string:mixed)) result = AUCTIOND->query_my_sale_infos(me->name);
	s += "--------\n";
	s += "��������������Ʒ\n";
	s += "����|�ȼ�|��ǰ��|һ�ڼ�|\n";

	int item_length = sizeof(result);
	if(!item_length){
		s += "��\n";
	}
	int startPos = pageNum*PAGE_LENGTH;
	int endPos = (pageNum+1)*PAGE_LENGTH;
	if(endPos > item_length)
		endPos = item_length;

	for(int i = startPos; i < endPos; i++)
	{
		mapping(string:mixed) tempMap = result[i];
		int id = (int)tempMap["sale_id"];// ���������
		string name_cn = tempMap["goods_name_cn"]; //���������Ʒ��		
		int level = (int)tempMap["goods_level"]; //�����Ʒ�ȼ�
		string cur_value = MUD_MONEYD->query_other_money_cn((int)tempMap["cur_value"]); //��õ�ǰ����
		int end_value_int = (int)tempMap["end_value"];
		string end_value = "";
		if(end_value_int == 0)
			end_value = "��";
		else 
			end_value = MUD_MONEYD->query_other_money_cn(end_value_int);
		s += "["+name_cn+":vendue_goods_info "+id+" 1]x"+tempMap["goods_count"]+"|"+level+"|"+cur_value+"|"+end_value+"|\n";
	}

	if(endPos < item_length)
		s += "[��һҳ:vendue_mygoods_list " + (pageNum+1) + "]\n";
	if(pageNum>0)                                                                                                        
		s += "[��һҳ:vendue_mygoods_list " + (pageNum-1) + "]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
