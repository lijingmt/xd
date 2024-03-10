#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	int sale_id = 0;
	int flag = 0;
	sscanf(arg,"%d %d",sale_id,flag);
	string s = "";

	mapping(string:mixed) sale_info = AUCTIOND->query_sale_info(sale_id);

	if(!sizeof(sale_info))
		s += "�治���ɣ�����Ʒ�ո��Ѿ�������ȥ�������Ѿ������ˣ��´μǵö���Ѹ�ٵ�\n";
	else{
		string goods_filename = sale_info["goods_filename"];
		int convert_count = (int)sale_info["convert_count"];
		object obj_item = clone(goods_filename);
		if(obj_item){
			s += obj_item->query_name_cn()+"\n";
			s += obj_item->query_picture_url()+"\n";
			s += obj_item->query_desc()+"\n";
			if(obj_item->profe_read_limit)
				s+="ְҵ��"+obj_item->profe_read_limit+"\n";
			if(obj_item->is("equip")){
				obj_item->set_convert_count(convert_count);
				s += obj_item->query_content()+"\n";
			}
			s += "�����ˣ�"+sale_info["saler_name"]+"\n";
			string buyer_name = "����";
			string cur_value_s = MUD_MONEYD->query_other_money_cn((int)sale_info["cur_value"]);
			if(sale_info["buy_flag"]) //���˾���
				buyer_name = sale_info["winner_name"];
			s += "��ǰ�ۣ�"+cur_value_s+"\n";
			s += "�����ˣ�"+buyer_name+"\n";
			int end_value = (int)sale_info["end_value"];
			string end_value_s = MUD_MONEYD->query_other_money_cn(end_value);
			if(!end_value)
				end_value_s = "��";
			s += "һ�ڼۣ�"+end_value_s+"\n";
			int iopen_time = (int)sale_info["iopen_time"];
			string iopen_time_desc = AUCTIOND->get_time_desc(iopen_time);
			s += "ʣ��ʱ�䣺"+iopen_time_desc+"\n";
			if(flag == 0){
				//�쿴���������Ķ���
				if(me->sid != "5dwap"){
					s += "[ֱ�Ӿ���:vendue_vie_buy 1 "+sale_id+"]\n" ;
					s += "[���뾺�ļ�:vendue_vie_buy 2 "+sale_id+"]\n";
					if(end_value)
						s += "[һ�ڼ۹���:vendue_vie_buy 3 "+sale_id+"]";
				}
				else
					s += "\n���������ο����棬�޷�������Ʒ\n";
			}
			else if(flag == 1)
				s += "[ȡ������:vendue_cancel "+sale_id+"]\n";
		}
		else
			s += "��Ҫ�������Ʒ��������\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
