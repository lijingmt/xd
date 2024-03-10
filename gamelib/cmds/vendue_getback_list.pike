#include <command.h>  
#include <gamelib/include/gamelib.h>
#define	PAGE_LENGTH 10

int main(string arg)
{
	object me = this_player();
	int pageNum = 0;
	string s = "";
	s += "��Ŵ˴��Ľ�Ǯ����Ʒ����7����ȡ�ߣ����ⱻ���ǻ��գ��Խ����ս�ڼ���Դ��ȱ���⡣\n";
	if(arg&&sizeof(arg))
		sscanf(arg,"%d",pageNum);
	//��Ϊ���һ�ÿ�ȡ�ص���Դ
	array(mapping(string:mixed)) as_saler = AUCTIOND->query_getback_as_saler(me->query_name());
	//��Ϊ��һ�ÿ�ȡ�ص���Դ
	array(mapping(string:mixed)) as_buyer = AUCTIOND->query_getback_as_buyer(me->query_name());
	int item_length1 = sizeof(as_saler);
	int item_length2 = sizeof(as_buyer);
	int item_length = item_length1 + item_length2;
	if(!item_length)
		s += "��\n";
	int startPos = pageNum*PAGE_LENGTH;
	int endPos = (pageNum+1)*PAGE_LENGTH;
	if(endPos > item_length)
		endPos = item_length;
	
	for(int i = startPos; i < endPos; i++)
	{
		mapping(string:mixed) tmpMap = ([]);
		if(i<item_length1){
			tmpMap = as_saler[i];
			int id = (int)tmpMap["id"];
			//����ȡ�ض����Ŀ�����1.����ʧ�� rltflag==0 
			//                    2.�����ɹ� rltflag==2
			//                    3.ȡ������ rltflag==3
			//1.����ʧ�ܣ����� 3.ȡ��������������������Ʒ���ظ����
			if((int)tmpMap["rltflag"]==0 || (int)tmpMap["rltflag"]==3){
				object goods = clone(tmpMap["goods"]);
				if(goods){
					string goods_name_cn = goods->query_name_cn();
					int count = (int)tmpMap["count"];
					int convert_count = (int)tmpMap["convert_count"];
					if((int)tmpMap["rltflag"]==0)
						s += "["+goods_name_cn+":vendue_inv_other "+tmpMap["goods"]+" "+convert_count+"]x"+count+"(����ʧ��)-[��ȡ:vendue_getback_item "+tmpMap["goods"]+" "+count+" "+convert_count+" "+id+"]\n";
					else
						s += "["+goods_name_cn+":vendue_inv_other "+tmpMap["goods"]+" "+convert_count+"]x"+count+"(����ȡ��)-[��ȡ:vendue_getback_item "+tmpMap["goods"]+" "+count+" "+convert_count+" "+id+"]\n";
				}
			}
			//2.�����ɹ�����Ǯ���ظ����
			else if((int)tmpMap["rltflag"]==2){
				int money_num2 = (int)tmpMap["money"];
				object goods2 = clone(tmpMap["goods"]);
				if(goods2){
					string goods2_name_cn = goods2->query_name_cn();
					int count2 = (int)tmpMap["count"];
					int convert_count2 = (int)tmpMap["convert_count"];
					string money_str = MUD_MONEYD->query_other_money_cn(money_num2);
					s += money_str+"(����["+goods2_name_cn+":vendue_inv_other "+tmpMap["goods"]+" "+convert_count2+"]x"+count2+"�ɹ�)-[��ȡ:vendue_getback_money "+money_num2+" "+id+"]\n";
				}
			}
		}
		else{
		    //����ȡ�ض����Ŀ�����:1.����ʧ�� rltflag==1
			//                     2.���ĳɹ� rltflag==2
			tmpMap = as_buyer[i-item_length1];
			int id = (int)tmpMap["id"];
			//1.����ʧ�ܣ�����ҵľ��۷������
			if((int)tmpMap["rltflag"] == 1){
				int money_num1 = (int)tmpMap["money"];
				object goods1 = clone(tmpMap["goods"]);
				if(goods1){
					string goods1_name_cn = goods1->query_name_cn();
					string money_str1 = MUD_MONEYD->query_other_money_cn(money_num1);
					int convert_count3 = (int)tmpMap["convert_count"];
					s += money_str1+"(����["+goods1_name_cn+":vendue_inv_other "+tmpMap["goods"]+" "+convert_count3+"]ʧ��)-[��ȡ:vendue_getback_money "+money_num1+" "+id+"]\n";
				
				}
			}
			//2.���ĳɹ�������Ʒ�������
			else if((int)tmpMap["rltflag"] == 2){
				object goods4 = clone(tmpMap["goods"]);
				if(goods4){
					string goods4_name_cn = goods4->query_name_cn();
					int count4 = (int)tmpMap["count"];
					int convert_count4 = (int)tmpMap["convert_count"];
					s += "["+goods4_name_cn+":vendue_inv_other "+tmpMap["goods"]+" "+convert_count4+"]x"+count4+"(���ĳɹ�)-[��ȡ:vendue_getback_item "+tmpMap["goods"]+" "+count4+" "+convert_count4+" "+id+"]\n";
				}
			} 
		}
	}
	if(endPos < item_length) 
		s += "[��һҳ:vendue_getback_list " +(pageNum+1) + "]\n";
	if(pageNum>0) 
		s += "[��һҳ:vendue_getback_list " + (pageNum-1) + "]\n";

	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
