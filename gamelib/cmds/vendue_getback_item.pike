#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	//������ʽΪgoods_filename count convert_count id
	string goods_filename = "";
	int count = 1;
	int convert_count = 0;
	int id = 0;
	sscanf(arg,"%s %d %d %d",goods_filename,count,convert_count,id);
	string s_rtn = "";
	
	//����Ʒ�������
	object goods = clone(goods_filename);
	mixed err = catch{
		goods = clone(goods_filename);
	};
	if(count <=0 )
		count = 1;
	if(goods && !err){
		//added by caijie 08/10/08
		if(this_player()->if_over_load(goods)){
			s_rtn += "�Բ������ı���������������װ�¸������Ʒ\n";
			s_rtn += "[����:look]\n";
			write(s_rtn);
			return 1;
		}
		//add end
		if(AUCTIOND->finish_getback(id)){ 
			//ȷ��û�б���ȡ��
			if(goods->is_combine_item())
				goods->amount = count;
			if(goods->is("equip") && convert_count)
				goods->set_convert_count(convert_count);
			s_rtn += "����ȡ��"+goods->query_name_cn()+"\n";
			if(goods->is("combine_item"))
				goods->move_player(this_player()->query_name());
			else
				goods->move(this_player());
		}
		else
			s_rtn += "���۸�������Щ��ʵ�ˣ����Ѿ���ȡ���������\n";
	}
	else
		s_rtn += "�޷���ȡ���������ƺ��е�æ��������\n";
	s_rtn += "[����:look]\n";
	write(s_rtn);
	return 1;
}
