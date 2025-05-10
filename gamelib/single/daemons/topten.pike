#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define SAVEPATH ROOT "/gamelib/data/topten.s"
#define RANGE 100
#define NAME 0
#define NAMECN 1
#define VALUE 2
mapping(string:int) grade_mapping=([]);//name:viplevel
mapping m_tops = ([]);

void try_top(string name,string namecn,string key,int value)
{
	if(!m_tops[key])
	{
		m_tops[key] = ({({name,namecn,value}),});
		return;
	}
	for(int i = 0;i < sizeof(m_tops[key]);i++)
	{
		if(m_tops[key][i][NAME] == name)
		{
			m_tops[key] = m_tops[key][..i-1] + m_tops[key][i+1..];
			break;
		}
	}
	int pos = sizeof(m_tops[key]);
	for(int i = sizeof(m_tops[key]) - 1 ;i >= 0;i--)
	{
		if(value > m_tops[key][i][VALUE])
		{
			pos = i;
		}
	}
	if( pos < RANGE )
	{
		m_tops[key] = m_tops[key][..pos-1] + ({({name,namecn,value})}) + m_tops[key][pos..];
		m_tops[key] = m_tops[key][..RANGE-1];
	}
	object player=find_player(name);
	if(player)
		_update_grade(find_player(name));//更新vip彩色名字系统字典
	return;
}

//更新vip彩色名字系统字典
void _update_grade(object ob)
{	
	int my_grade = ob->query_vip_flag();
	//werror("============_update_grade my_grade:"+my_grade+" \n");
	//werror("============_update_grade ob->name_cn:"+ob->name_cn+" \n");
	grade_mapping[ob->name_cn]=my_grade;
	//werror("============_update_grade grade_mapping[ob->name_cn]:"+grade_mapping[ob->name_cn]+" \n");
}
mapping(string:int) get_grade_mapping(){
	return grade_mapping;
}
//更新vip彩色名字系统字典

array get_top(string key,int range)
{
	return m_tops[key][..range];
}

void create()
{
	load();
	remove_call_out(auto_save);
	call_out(auto_save,60);
}
void auto_save()//存储进程
{
	save();
	call_out(auto_save,600);
}
void save()
{
	os_save(this_object(),SAVEPATH);
}
void load()
{
	os_load(this_object(),SAVEPATH);
}
string get_game_area(){
	mixed err = catch{
		return GAME_AREA[2..];
	};
	if(err){
		return "";
	}
}
