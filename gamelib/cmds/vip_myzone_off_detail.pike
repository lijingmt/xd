#include <command.h>
#include <gamelib/include/gamelib.h>
//�г�������Ʒ�ľ�����Ϣ

int main(string arg)
{
	object me = this_player();
	string goods_name = "";//��Ʒ�ļ���
	int lv = 0;//��Ҫ�Ļ�Ա�ȼ�
	int price = 0;//�õȼ��±���Ʒ�ļ۸�
	string s = "";
	sscanf(arg,"%s %d %d",goods_name,lv,price);
	array(string) tmp = ({});
	string type = "baoshi";                         //Ĭ�ϵ���Ʒ����
	tmp = goods_name/"/";                           //�õ��ļ�����Ŀ¼��Ҳ������Ʒ�ķ���
	if(tmp)                                  
	{
		type=tmp[0];
	}
	object goods;
	mixed err = catch{
		goods = (object)(ITEM_PATH + goods_name);
	};
	if(!err && goods){
		goods ->set_toVip(1);
		s += goods->query_name_cn()+"��\n";
		s += goods->query_picture_url()+"\n ";
		s += goods->query_desc()+"\n";
		s += "--------\n";
		s += VIPD->get_vip_name(lv)+"��������"+ VIPD->get_vip_off(lv) +"���Ż�,����"+YUSHID->get_yushi_for_desc(price)+"\n\n";
		s += "[ȷ������:vip_myzone_off_confirm " + goods_name + " "+ lv +" "+ price +"]\n";
	}
	else
		s += "�ⶫ�������Ѿ������ˣ����������ɣ�\n";
	s += "[����:vip_myzone_off_list "+ type +" "+ lv +"]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
