#!/usr/local/bin/pike
/*****************************************************************************************
 * ���ػ�������Ҫ��ʵ���ɵ����ѶĲ�װ������
 * �������ݽṹ����Ҫ��5���ȼ���װ���б����л������˿ɹ��Ĳ��ĸ���num
 *   array(array(mixed)) items1_10 = ({({name,name_cn,num}),...});
 *   array(array(mixed)) items11_20 = ({({name,name_cn,num}),...});
 *   array(array(mixed)) items21_30 = ({({name,name_cn,num}),...});
 *   array(array(mixed)) items31_40 = ({({name,name_cn,num}),...});
 *   array(array(mixed)) items41_50 = ({({name,name_cn,num}),...});
 * Auther��liaocheng
 * Date��07/11/23 ��ʼ��Ʊ�д
 ********************************************************************************************/
#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define FLUSH_TIME 21600
#define FLUSH_NUM 3
#define MAX_LEV 55 //��ߵ�װ���ȼ�

private static array(array(mixed)) items1_10 = ({});
private static array(array(mixed)) items11_20 = ({});
private static array(array(mixed)) items21_30 = ({});
private static array(array(mixed)) items31_40 = ({});
private static array(array(mixed)) items41_50 = ({});
private static array(array(mixed)) items51_60 = ({});
int half_price = 0;//��ʶ��۵���Ʒ��Χ


void create()
{
	flush_dubo_items();
}

//ˢ�¿ɹ��Ĳ�����Ʒ����,Ҳ��������5����Ʒ�б�
void flush_dubo_items()
{
	items1_10 = ({});
	items11_20 = ({});
	items21_30 = ({});
	items31_40 = ({});
	items41_50 = ({});
	items51_60 = ({});
	half_price = random(6)+1;
	for(int i=1;i<=MAX_LEV;i++){
		string name = ITEMSD->query_dubo_items(i,1);
		if(name == "")
			continue;
		object ob;
		mixed err = catch{
			ob = (object)(ITEM_PATH+name);
		};
		if(!err && ob){
			string name_cn = ob->query_name_cn();
			if(i>=1 && i<=10)
				items1_10 += ({({name,name_cn,FLUSH_NUM})});
			else if(i>=11 && i<=20)
				items11_20 += ({({name,name_cn,FLUSH_NUM})});
			else if(i>=21 && i<=30)
				items21_30 += ({({name,name_cn,FLUSH_NUM})});
			else if(i>=31 && i<=40)
				items31_40 += ({({name,name_cn,FLUSH_NUM})});
			else if(i>=41 && i<=50)
				items41_50 += ({({name,name_cn,FLUSH_NUM})});
			else if(i>=51 && i<=60)
				items51_60 += ({({name,name_cn,FLUSH_NUM})});
		}
	}
	call_out(flush_dubo_items,FLUSH_TIME);
	return;
}

//���ĳ�ȼ���Χ��װ���б�
//������range =1��ʾ1-10��װ����=2��ʾ11-20��װ��������
string query_dubo_items(int range)
{
	string s_rtn = "";
	mapping(int:array) range_m = ([1:items1_10,2:items11_20,3:items21_30,4:items31_40,5:items41_50,6:items51_60]);
	if(range>=1 || range<=6){
		array(array(mixed)) items_tmp = range_m[range];
		if(items_tmp && sizeof(items_tmp)){
			for(int i=0;i<sizeof(items_tmp);i++){
				array tmp_arr = items_tmp[i];
				if(sizeof(tmp_arr)==3){
					int remain = (int)tmp_arr[2];
					string re_s = "����"+remain;
					if(remain<=0)
						re_s = "������";
					s_rtn += "["+tmp_arr[1]+":dubo_item_detail "+tmp_arr[0]+" "+i+" "+range+"]("+re_s+")\n";
				}
			}
		}
	}
	if(s_rtn == "")
		s_rtn = "��δ����\n";
	return s_rtn;
}

//�鿴ָ���Ŀɹ��Ĳ�����Ʒ����
int can_dubo_num(string item_name,int index,int range)
{
	int num = 0;
	mapping(int:array) range_m = ([1:items1_10,2:items11_20,3:items21_30,4:items31_40,5:items41_50,6:items51_60]);
	array(array(mixed)) items_tmp = range_m[range];
	if(items_tmp && sizeof(items_tmp)){
		array item_arr = items_tmp[index];
		if(item_name == item_arr[0])
			num = (int)item_arr[2];
	}
	return num;
}

//��ҶĲ��������ÿɹ��Ĳ���Ʒ�ĸ���
void set_dubo_num(string item_name,int index,int range)
{
	mapping(int:array) range_m = ([1:items1_10,2:items11_20,3:items21_30,4:items31_40,5:items41_50,6:items51_60]);
	array(array(mixed)) items_tmp = range_m[range];
	if(items_tmp && sizeof(items_tmp)){
		array item_arr = items_tmp[index];
		if(item_name == item_arr[0]){
			int num = (int)item_arr[2];
			if(num>0)
				item_arr[2] = num-1;
		}
	}
}

//��ѯ���װ���Ľӿ�
int query_half_price()
{
	return half_price;
}
