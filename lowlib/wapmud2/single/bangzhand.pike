//��ս�Ͱ������а��ػ�����ά����ս����Ҫ���ݽṹ���㷨�����ɵ�����Ҳ������
//
//�������ݽṹ:
//1.��ս�Ǽ���Ϣ���ڱ��ϵİ��ɿ�����������������ɱ¾:
// mapping(int:int) bangzhan;//bangid:1 
//
//2.�������б�
// 
//
//�����ṹ����д��ROOT/gamelib/data/bangzhan.info�Ա�����Ϣ��
//
//��liaocheng��07/8/27��ʼ��ƿ���

#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_DAEMON;
#define BANGZHAN_INFO ROOT "/gamelib/etc/bangzhan.info" //��ս��Ϣ
#define SAVE_TIME 3600
#define UPDATE_TIME 86400 //����ʱ����Ϊ24Сʱ

private mapping(int:int) Bangzhan = ([]); //��ս�ǼǱ�
private array(int) top_list = ({});//����������
private int open_fg = 1; //��ʶ�Ƿ񿪷Ű�ս�þ���1-���ţ�0-������


void create()
{
	load_bangzhan_info();
	update_bang_toplist(1);
	if(sizeof(top_list) && Bangzhan[top_list[0]]==1)
		open_fg = 0;

	mapping(string:int) now_time = localtime(time());
	int now_mday = now_time["mday"];
	int now_mon = now_time["mon"];
	int now_year = now_time["year"];
	//�õ��������һ���Զ��������а��ʱ��
	int update_time = mktime(60,59,23,now_mday,now_mon,now_year);
	//�ɴ˻�þ������ڻ��ж���ʱ�����
	int need_time = update_time - time();
	call_out(update_bang_toplist,need_time);

	call_out(save_bangzhan_info,SAVE_TIME);
}

void load_bangzhan_info()
{
	werror("------load bangzhan.info in gamelib/single/daemon/bangzhand.pike------\n");
	Bangzhan = ([]);
	string bzData = Stdio.read_file(BANGZHAN_INFO);
	array(string) lines = bzData/"\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/":";
			if(sizeof(columns) == 2){
				Bangzhan[(int)columns[0]] = (int)columns[1];
			}
			else
				werror("------size of columns wrong in load_load_bangzhan_info() of bangzhand.pike------\n");
		}
	}
	else 
		werror("------read bangzhan.info null in gamelib/single/daemon/bangzhand.pike------\n");
}

void save_bangzhan_info(void|int fg)
{
	string now=ctime(time());
	string writeBack = "";
	foreach(indices(Bangzhan),int bangid){
		if(bangid)
			writeBack += bangid+":"+Bangzhan[bangid]+"\n";
	}
	mixed err=catch
	{
		Stdio.write_file(BANGZHAN_INFO,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/bangzhan.log",now[0..sizeof(now)-2]+":rewrite bangzhan.info failed\n");
	}
	if(!fg)
		call_out(save_bangzhan_info,SAVE_TIME);
}

//��������ս�Ľӿ�
//����Ϊbangid
//����  1-�ɹ� 2-�ظ����� 0-���ɴ���
int add_new_bang(int bangid)
{
	if(BANGD->if_is_bang(bangid)){
		if(Bangzhan[bangid])
			return 2;
		else{
			Bangzhan[bangid]=1;
			string now=ctime(time());
			string s_log = "��<"+BANGD->query_bang_name(bangid)+">("+bangid+")�����˰�ս��\n";
			Stdio.append_file(ROOT+"/log/bangzhan.log",now[0..sizeof(now)-2]+s_log);
			return 1;
		}
	}
	else
		return 0;
}

//�˳���ս�Ľӿ�
//����Ϊbangid
//����  1-�ɹ� 2-���ڰ�ս�� 0-���ɴ���
int quit_bangzhan(int bangid)
{
	if(Bangzhan[bangid]){
		m_delete(Bangzhan,bangid);
		string now=ctime(time());
		string s_log = "��<"+BANGD->query_bang_name(bangid)+">("+bangid+")�˳��˰�ս��\n";
		Stdio.append_file(ROOT+"/log/bangzhan.log",now[0..sizeof(now)-2]+s_log);
		return 1;
	}
	else
		return 2;
}

//�ж��Ƿ��ڰ�վ�б��еĽӿ�
//������bangid
//���أ�0-���� 1-��
int if_in_bangzhan(int bangid)
{
	if(Bangzhan[bangid])
		return 1;
	else
		return 0;
}

//��ò����ս�İ����б�
//���أ�����id��ɵ�����
array(int) query_bangzhan_list()
{
	array(int) rtn = ({});
	rtn = sort(indices(Bangzhan));
	if(rtn && sizeof(rtn))
		return rtn;
	else 
		return 0;
}

//�ж��Ƿ��ڰ�ս֮��
//���������˵�bangid , �Լ���bangid
//���أ�1-��  0-����
int is_in_bangzhan(int bangid1,int bangid2)
{
	if(bangid1 == bangid2)
		return 0;
	if(Bangzhan[bangid1] && Bangzhan[bangid2])
		return 1;
	else
		return 0;
}

//���ð����Ľӿ�
//����������object,�Լ�(�����ߵ�)object
//���أ���õİ���ֵ
int get_baqi(object enemy,object me)
{
	if(!me||!enemy||me->query_level()<25){
		return 0;
	}
	int gain_baqi = 0;
	int flag = 1;
	if(enemy["/plus/daily/honer_map"]&&sizeof(enemy["/plus/daily/honer_map"])){
		//��ѵ����ɱ���Ƿ���������ɱ������ҵ�ӳ�����
		foreach(indices(enemy["/plus/daily/honer_map"]),string enemyid){
			//���õж�����й���ɱ��¼������¼�������õ�Ӧ���İ���ֵ
			if(enemyid == me->query_name()){
				string htype = (string)enemy["/plus/daily/honer_map"][enemyid]; 
				if(htype=="a"){
					gain_baqi = (int)(me->query_level()*3/4);
					//���˻�ɱ�߰���ֵ֮����Ҫ����ɱ��¼���ӵ���һ���ȼ�
					enemy["/plus/daily/honer_map"][me->query_name()] = "b";
				}
				else if(htype=="b"){
					gain_baqi = (int)(me->query_level()*1/2);
					enemy["/plus/daily/honer_map"][me->query_name()] = "c";
				}
				else if(htype=="c"){
					gain_baqi = (int)(me->query_level()*1/4);
					enemy["/plus/daily/honer_map"][me->query_name()] = "d";
				}
				else if(htype=="d"){
					gain_baqi = 0;	
					enemy["/plus/daily/honer_map"][me->query_name()] = "d";
				}
				flag = 0;//����ɱ��¼���е��˵ļ�¼
				break;
			}
		}
		//����ҵ�һ�α����˻�ɱ����¼��ɱ�ߵ�ӳ���������ɱ��Ӧ������ֵ
		if(flag){
			enemy["/plus/daily/honer_map"][me->query_name()] = "a";
			gain_baqi = me->query_level();
		}
	}
	else{
		enemy["/plus/daily/honer_map"][me->query_name()] = "a";
		gain_baqi = me->query_level();
	}
	if(gain_baqi && Bangzhan[enemy->bangid]){
		if(enemy->query_raceId() != me->query_raceId())                                                   
			gain_baqi = gain_baqi*3;
		Bangzhan[enemy->bangid] += gain_baqi;
	}
	return gain_baqi;
}

//������еİ���id����ӿ�
array(int) get_top_list()
{
	return top_list;
}

//�԰��ɽ�������Ľӿ�
void update_bang_toplist(void|int fg)
{
	top_list = indices(Bangzhan);
	if(top_list && sizeof(top_list)){
		quick_sort(top_list,0,sizeof(top_list)-1);
		string now=ctime(time());
		string s_log = "����ʼ�������а�\n";
		Stdio.append_file(ROOT+"/log/bangzhan.log",now[0..sizeof(now)-2]+s_log);
	}
	if(!fg){
		open_fg++;
		call_out(update_bang_toplist,UPDATE_TIME);
	}
	return;
}
void quick_sort(array arr,int left,int right)
{
	int l = left;
	int r = right;
	int pos = get_pos(arr,l,r);
	if(pos >= 0){
		int pos_val = Bangzhan[arr[pos]];
		while(l < r){
			while(Bangzhan[arr[l]] >= pos_val)
				l++;
			while(Bangzhan[arr[r]] < pos_val)
				r--;
			if(l < r){
				int tmp = arr[l];
				arr[l] = arr[r];
				arr[r] = tmp;
				l++;
				r--;
			}
			else
				break;
		}
		quick_sort(arr,left,r);
		quick_sort(arr,l,right);
	}
}
int get_pos(array arr,int l,int r)
{
	int rtn = l+1;
	while(rtn <= r){
		if(Bangzhan[arr[rtn]] > Bangzhan[arr[l]])
			return rtn;
		else if(Bangzhan[arr[rtn]] < Bangzhan[arr[l]])
			return l;
		else rtn++;
	}
	return -1;
}

//��ð�����Ľӿ�
int query_bang_baqi(int bangid)
{
	if(Bangzhan[bangid])
		return Bangzhan[bangid];
	else
		return 0;
}

//���ָ�������İ�id
int query_top_bang(int no)
{
	int i = no-1;
	if(top_list[i])
		return top_list[i];
	else
		return 0;
}

//���ø�����İ�������ʼ��һ�ֵİ�ս                                                                              
void bangzhan_restart()
{
	foreach(indices(Bangzhan),int bangid){
		if(bangid)
			Bangzhan[bangid] = 1;
	}
	return;
}

//��ѯ��ս�þ����ű�ʶ
int query_open_fg()
{
	return open_fg;
}
