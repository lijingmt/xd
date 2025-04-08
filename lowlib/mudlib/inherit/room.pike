#include <globals.h>
#include <mudlib/include/mudlib.h>
#include <gamelib/include/gamelib.h>
#define LEAVE_TIME 20 //�뿪����ʱ��
inherit LOW_BASE;
inherit LOW_F_DBASE;
inherit MUD_F_INIT;
inherit MUD_F_ITEMS;

mapping exits=([]);//(["west":ROOT+"/wapmud2/d/someroom"])
mapping closed_exits=([]);//([string DIRECTORY:int|string|program|object KEY])
mapping opened_exits=([]);//([string DIRECTORY:int|string|program|object KEY])
mapping hidden_exits=([]);//([string DIRECTORY:string|program|object KEY_OBJECT])
mapping switch_exits=([]);//([string DIRECTORY:({({string VAR,int VAL_MIN,int VAL_MAX,string DEST})})])
mapping guarded_exits=([]);//([string DIRECTORY:string|program|object GUARDER])
int reset_interval=30;
private mapping leaveMSG=([]);//��¼������Ϣ([string userid:array({���������,�뿪����,ʱ��,(<���������id>)})])
private mapping remainMSG=([]);//�÷����ʣ����Ϣ([int ʱ��:string ��Ϣ,<���������id>])
private mapping arriveMSG=([]);//�÷����������Ϣ([int ʱ��:string ��Ϣ,<���������id>])
string guard_msg;
string get_guard_msg(object guarder,string dir){
	if(guard_msg)
		return guard_msg;
	else
		return guarder->name_cn+"��ס�����ȥ·��";
}
int is_room(){
	return 1;
}
//override item��ĺ�����������̬����npc�ĵȼ�
int dongtai_npc_start_level=50;


void add_items(array(string|program) _items){
	object me= this_player();
	object env=environment(me);
	foreach(_items,string|program s){
		int adjust=0;//ˢ��npc�������������ǵ�����������3��		
		//werror("----add_items -> player=["+me->name+"]----\n");
		if(me->gamelevel=="putong") adjust=0;
		else if(me->gamelevel=="emeng") adjust=5;
		else if(me->gamelevel=="diyu") adjust=10;
		object t_ob = 0;
		object ob=0;
		mixed err=catch{
			//�ȼ�����50�����ϲſ�����̬NPC
			int fb_status = FBD->query_fb_memebers(me->fb_id,me->query_name());//0 Ϊ�Ǹ�����1Ϊ����
			//int fb_status = search(fb_arr,this_object()->name);
			//werror("======fb_status "+fb_status +"\n");
			if(env->is_peaceful()!=1&&me->query_level()>=dongtai_npc_start_level && fb_status == 0)
				t_ob=MUD_ROOMD->get_npc_level(s-ROOT,me->query_level()+adjust);//�����ļ��������npc�����ٸ����Ӧ�ȼ�/ǿ��
		};
		if(!err&&t_ob) ob=t_ob;
		else ob=new(s);
		/////////////////////////////////////
		//object ob=new(s);
		//��̬����npc�ȼ�
		//ob->_npcLevel=this_player()->query_level();
		//ob->setup_npc();
		//��̬����npc�ȼ�
		//werror("===========add items npc:"+file_name(ob)+"\n");
		//({�ڴ�Ψһ�������ڴ��еĿ����������ˢ��ʱ�䣬��ǰʱ��})
		items+=({({((program)s),ob,ob->_flushtime,time()})});
		ob->move(this_object());
	}
}
/*
�˷����ع�override�˵ײ��reset times��ÿ���û����뷿�䣬����������������鷿���npc

���䴥����try_reset����ҽ��뷿��ʱ�������������ϴ����ò�ֵ30��󣬴���reset_items�������ټ���Ƿ��ǵ�һ���������ң��ٵ�������npc�ȼ�Ϊ��ҵȼ�
���ԣ���ʵ���԰Ѳ�ֵ30��ȥ����ֻҪ��ҽ��룬�ʹ�����reset_items����
����30��������
 */

void reset_items()
{
	::reset_items();//���õײ��reset����
	object me= this_player();
	//werror("----reset_items -> player=["+me->name+"]----\n");
	//�ȼ�����50�����ϲſ�����̬NPC
	int fb_status = FBD->query_fb_memebers(me->fb_id,me->query_name());
	//werror("======fb_status "+fb_status +"\n");
	if(me->query_level()>=dongtai_npc_start_level && fb_status == 0){
		MUD_ROOMD->refresh_room_npc_to_currentlevel(me);//��̬ˢ�µ�ǰҪȥ��Ŀ�귿��npclevel Ϊ��ҵĵȼ�
	}
	
	////werror("===reset to refresh room npc to current me level\n");
}
private int last_reset;
private void try_reset(){
	//�˴�������30���ӵļ������ˢnpc��ˢ�¼��ʱ�䣬Ҳ����˵��ֻҪ����ҽ�����ͷһ����30�룬�Ϳ���ˢ��ncp
	if(time()-last_reset>reset_interval){
		last_reset=time();
		reset_items();
		if(this_object()->is("store")){
			this_object()->reset_boss();
		}
		closed_exits+=opened_exits;
		opened_exits=([]);
	}
}
/*
 * ����һ���뿪��¼
 * object user �뿪����
 */
void addLeaveInfo(object user){
	leaveMSG+=([user->name:({user->name_cn,user->leave_direction,time(),(<>)})]);
}
/*
* �������뿪��Ϣ��ɾ��������Ϣ
*/
void trimLeaveInfo(){
	array names = indices(leaveMSG);
	foreach(names,string name){
		array t = leaveMSG[name];
		if(t[2]<time()-LEAVE_TIME){
			m_delete(leaveMSG,name);
		}
	}
	while(sizeof(leaveMSG)>3){//�����ʾ3����Ϣ
		array names = indices(leaveMSG);
		string deleteName="";
		int time = 0;
		foreach(names,string name){
			array t = leaveMSG[name];
			if(t[2]>time){
				deleteName = name;
			}
		}
		m_delete(leaveMSG,deleteName);
	}
}
//ɾ�����û����뿪��Ϣ
void deleteLeaveInfo(string name){
		m_delete(leaveMSG,name);
}
//��ʾ������뿪��Ϣ
string query_leave(string username){
	trimLeaveInfo();
	string returnString="";
	array names = indices(leaveMSG);
	foreach(names,string name){
		array t = leaveMSG[name];
		if(t[3][username]) continue;
		leaveMSG[name][3]+=(<username>);
		returnString+=t[0]+"��"+(["east":"��","west":"��","north":"��","south":"��"])[t[1]]+"�뿪��\n";
	}
	return returnString;
}
/*
 * ����һ����Ϣ
*/
void addRemainMSG(string msg,multiset except){
		remainMSG+=([gethrtime():({msg,except})]);
}
/**
* �õ�ʣ����Ϣ�Ĵ�С
*/
private int getRemainMSGSize(){
	array names = indices(remainMSG);
	int size=0;
	foreach(names,int name){
		size+=sizeof(remainMSG[name][0]);
	}
	return size;
}
/*
 * �������뿪��Ϣ��ɾ��������Ϣ
*/
void trimRemainMSG(){
	array names = indices(remainMSG);
		foreach(names,int name){
			if(name/1000000<time()-LEAVE_TIME){
				m_delete(remainMSG,name);
			}
		}
	while(sizeof(remainMSG)>2){//���2����Ϣ
		array names = indices(remainMSG);
		int deleteName=0;
		int time = 0;
		foreach(names,int name){
			if(name>time){
				deleteName = name;
			}
		}
		m_delete(remainMSG,deleteName);
	}
}
//��ʾ���µ�������Ϣ
string query_remain_msg(string username){
	trimRemainMSG();
	string returnMSG="";
	array names = indices(remainMSG);
	foreach(names,int name){
		if(remainMSG[name][1][username]) continue;
		remainMSG[name][1]+=(<username>);
		returnMSG+=remainMSG[name][0]+"\n";
	}
	return returnMSG;
}
/*
* ����һ��������Ϣ
*/
void addArriveMSG(object user){
		arriveMSG+=([user->name:({user->name_cn,time(),(<user->name>)})]);
}
/*
* �������뿪��Ϣ��ɾ��������Ϣ
*/
void trimArriveMSG(){
	array names = indices(arriveMSG);
		foreach(names,int name){
			if(arriveMSG[name][1]<time()-10){
				m_delete(arriveMSG,name);
			}
		}
		while(sizeof(arriveMSG)>3){//�����ʾ3����Ϣ
		array names = indices(arriveMSG);
		int deleteName=0;
		int time = 0;
		foreach(names,int name){
			if(arriveMSG[name][1]>time){
				deleteName = name;
			}
		}
		m_delete(arriveMSG,deleteName);
	}
}
//��ʾ���µ�������Ϣ
string query_arrive_msg(string username){
	trimArriveMSG();
	string returnMSG="";
	array names = indices(arriveMSG);
	foreach(names,int name){
		if(arriveMSG[name][2][username]) continue;
		arriveMSG[name][2]+=(<username>);
		returnMSG+=arriveMSG[name][0]+"���������\n";
	}
	return returnMSG;
}
//ɾ�����û����뿪��Ϣ
void deleteArriveInfo(string name){
		m_delete(arriveMSG,name);
}
private string initer=(add_init(try_reset),"");
