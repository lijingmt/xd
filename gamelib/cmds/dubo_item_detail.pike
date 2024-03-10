#include <command.h>
#include <gamelib/include/gamelib.h>
//�鿴ָ���Ķ�װװ��
//arg = item_name index range
int main(string arg)
{
	object me = this_player();
	object item;
	string item_name = "";
	int index;
	int range;
	int type = 0;//�Ĳ���Ʒ�����£�0-װ����1-����
	sscanf(arg,"%s %d %d",item_name,index,range);
	string s = "�����������Ʒ�Ǻ����޵ģ��������٣�\n";
	mixed err = catch{
		item = (object)(ITEM_PATH+item_name);
	};
	if(!err && item){
		s += item->query_name_cn()+"\n";
		s += item->query_picture_url()+"\n";
		s += item->query_desc()+"\n";
		if(!item->is_combine_item())
			s += item->query_content()+"\n";
		s += "��Ҫ��";
		int item_level = 0;
		if(item->is_combine_item()==1 && (item->query_for_material()=="baoshi"||item->query_for_material()=="moxian")){
			item_level = item->query_item_level();
			type = 1;
		}
		else
			item_level = item->query_item_canLevel();
		int half = DUBOD->query_half_price();                                           
		if(item_level <= half*10 && item_level >= (half*10-9))                          
			item_level = item_level/2;                                              
		if(item_level <= 0)                                                             
			item_level = 1;
		int need_xianyuan = 0;
		int need_suiyu = 0;
		if(item_level>0 && item_level<100){
			need_xianyuan = item_level/10;
			need_suiyu = item_level%10;
		}
		if(need_xianyuan)
			s += need_xianyuan+"������Ե�� ";
		if(need_suiyu)
			s += need_suiyu+"��������\n";
		else
			s += "\n";
		s += "[��һ��:dubo_item_confirm "+item_name+" "+index+" "+range+" "+item_level+" "+type+"]\n";
	}
	else
		s += "����Ʒ�ƺ�����Щ����\n";
	s += "[����:dubo_items_list "+range+"]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
