//管理注册用户中文名的程序
//
//核心数据结构:
//1.已注册用户名: array names_regged
//2.限制用户名:array names_reserved
//
//上述结构通过读取ROOT/gamelib/etc/regname和reserved_names两个文件。
//
//由liaocheng于08/06/02开始设计开发

#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define REGNAME ROOT "/gamelib/etc/regname" //已注册用户名文件
#define RESERVED_NAMES ROOT "/gamelib/etc/reserved_names" //已注册用户名文件

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

//判断是否名字是受限制的
//返回1-受限 0-通过
int is_name_reserved(string name)
{
	foreach(names_reserved,string name_tmp){
		if(name_tmp == name)
			return 1;
	}
	return 0;
}

//判断是否名字已被注册
//返回1-已注册 0-未注册
int is_name_regged(string name)
{
	foreach(names_regged,string name_tmp){
		if(name_tmp == name)
			return 1;
	}
	return 0;
}

//取名字后，记录该名字
void reg_name(string name)
{
	if(name && name != ""){
		names_regged += ({name});
		Stdio.append_file(REGNAME,name+"\n");
	}
	return;
}

//判断输入的字符串是否只包含字母和数字 
//0 否 ; 1 是
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
