//����ע���û��������ĳ���
//
//�������ݽṹ:
//1.��ע���û���: array names_regged
//2.�����û���:array names_reserved
//
//�����ṹͨ����ȡROOT/gamelib/etc/regname��reserved_names�����ļ���
//
//��liaocheng��08/06/02��ʼ��ƿ���

#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define REGNAME ROOT "/gamelib/etc/regname" //��ע���û����ļ�
#define RESERVED_NAMES ROOT "/gamelib/etc/reserved_names" //��ע���û����ļ�

private array names_regged = ({});
private array names_reserved = ({});

void create()
{
	names_regged = ({});
	names_reserved = ({});
	load_infos();
}

void load_infos()
{
	string regData = Stdio.read_file(REGNAME);
	array(string) lines = regData/"\n";
	if(lines && sizeof(lines)){
		names_regged = lines-({""});
	}
	else 
		werror("------null in regname------\n");
	string reservData = Stdio.read_file(RESERVED_NAMES);
	lines = reservData/"\n";
	if(lines && sizeof(lines)){
		names_reserved = lines-({""});
	}
	else 
		werror("------null in reserved_names------\n");
	return;
}

//�ж��Ƿ������������Ƶ�
//����1-���� 0-ͨ��
int is_name_reserved(string name)
{
	foreach(names_reserved,string name_tmp){
		if(name_tmp == name)
			return 1;
	}
	return 0;
}

//�ж��Ƿ������ѱ�ע��
//����1-��ע�� 0-δע��
int is_name_regged(string name)
{
	foreach(names_regged,string name_tmp){
		if(name_tmp == name)
			return 1;
	}
	return 0;
}

//ȡ���ֺ󣬼�¼������
void reg_name(string name)
{
	if(name && name != ""){
		names_regged += ({name});
		Stdio.append_file(REGNAME,name+"\n");
	}
	return;
}

//�ж�������ַ����Ƿ�ֻ������ĸ������ 
//0 �� ; 1 ��
//add by caijie 080812
int is_psw(string psw)
{
	for(int i=0;i<sizeof(psw);i++){
		if(psw[i]>='a'&&psw[i]<='z'||psw[i]>='A'&&psw[i]<='Z'||psw[i]>='0'&&psw[i]<='9'){
			return 1;
		}
		else 
			return 0;
	}
}
