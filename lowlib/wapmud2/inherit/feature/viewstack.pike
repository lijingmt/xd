#include <globals.h>
#include <wapmud2/include/wapmud2.h>
private object init_view;
private mixed init_view_arg;
private array viewstack=({});
private mapping spliter=([]);
private int combat_flag=1;
mapping query_spliter(){
	return spliter;
}
void push_view(function f,mixed...args){
	viewstack=({({f,args})})+viewstack;
}
void pop_view(){
	viewstack=a_delete(viewstack,0);
}
void write_view_tmp(void|object|function f,void|mixed...args){
	object env = environment(this_object());
	if(!combat_flag&&!this_object()->in_combat)
		combat_flag=1;
	if(this_object()->in_combat&&combat_flag){
		f=WAP_VIEWD["/fight"];
		reset_view(WAP_VIEWD["/fight"]);
		spliter["footer"]="";
		combat_flag=0;
	}
	spliter["header"]="";
	if(env&&env->is("room"))
		spliter["text"]=env->query_arrive_msg(this_object()->name)+f(@args);
	else
		spliter["text"]=f(@args);
	if(sizeof(viewstack)>1){
		spliter["footer"]="";
		if(viewstack[0][0]->cacheable)
			spliter["footer"]="[返回:flushview]\n[返回游戏:look]";
		else
			spliter["footer"]="[返回:flushview]\n[返回游戏:look]";
	}
	this_object()->command("_explorer _player/spliter");
}
void write_view(void|object|function f,void|mixed...args){
	object env = environment(this_object());
	if(init_view==0)
		init_view=WAP_VIEWD["/init"];
	if(!combat_flag&&!this_object()->in_combat)
		combat_flag=1;
	if(this_object()->in_combat&&combat_flag){
		reset_view(WAP_VIEWD["/fight"]);
		f=0;
		combat_flag=0;
	}
	//////////////////////触发随机奖励界面时，要强制通过输入验证码，才能解除该界面
	if(this_object()["/plus/random_rcd"]==1){
		reset_view(WAP_VIEWD["/modal_award"]);//随机奖励界面
		f=0;
	}
	//////////////////////触发随机奖励界面时，要强制通过输入验证码，才能解除该界面
	if(sizeof(viewstack)==0)
		push_view(init_view,init_view_arg);
	if(f)
		push_view(f,@args);
	if(!viewstack[0][0]->cacheable)
		this_object()->reset_hidden();
	spliter["header"]="";
	if(env&&env->is("room"))
		spliter["text"]=env->query_arrive_msg(this_object()->name)+viewstack[0][0](@(viewstack[0][1]));
	else
		spliter["text"]=viewstack[0][0](@(viewstack[0][1]));
	spliter["footer"]="";
	if(sizeof(viewstack)>1){
		if(viewstack[0][0]->cacheable)
			spliter["footer"]="[返回:popview]\n[返回游戏:look]";
		else
			spliter["footer"]="[返回:popview]\n[返回游戏:look]";
	}
	this_object()->command("_explorer _player/spliter");
}
void reset_view(void|object|function f,void|mixed...args){
	viewstack=({});
	if(f){
		init_view=f;
		init_view_arg=args;
		push_view(f,@args);
	}
}
