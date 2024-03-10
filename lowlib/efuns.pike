#include "lowlib.h"

#define MASTER master()
#define ENABLE_WERROR 1
int next_id;
mapping(object:int) objids;
mapping(object:array(object)) inv_map;
mapping(object:object) env_map;
mapping(object:mapping(string:array(function))) action_map; //([cmd:fun])
mapping(object:array(array)) action_array; //({cmd,fun})
mapping heart_beats;//([object:({interval,left})]);
mixed fail_str;
string ROOT;


//! 扩展符号连接，如果prefix+"/"+s所指代的文件是一个符号连接，则返回该符号连接所连向的文件，不做递归解析。
string expand_symlinks(string s,void|string prefix)
{
	if(prefix==0){
		prefix="/";
	}
	if(Stdio.is_link(prefix+"/"+s)){
		string ret=combine_path(dirname(prefix+"/"+s),System.readlink(prefix+"/"+s));
		return ret;
	}
	return prefix+"/"+s;
}

//! 从数组a中删除下标为n的元素，返回删除后的数组。
array a_delete(array a,int n)
{
	array left;
	array right;
	if(n>=0&&n<sizeof(a)){
		left=a[0..n-1];
		right=a[n+1..];
		if(left==0){
			left=({});
		}
		if(right==0){
			right==({});
		}
		return left+right;
	}
	return a;
}

//! 在数组a的下标为n的元素前面插入值为data的元素，返回插入后的数组。
array a_insert(array a,int n,mixed data)
{
	array left;
	array right;
	if(n>=0&&n<sizeof(a)){
		left=a[0..n-1];
		right=a[n..];
		if(left==0){
			left=({});
		}
		if(right==0){
			right==({});
		}
		return left+({data})+right;
	}
	return a;
}

//! 在数组a中依次删除数组b中的元素，b中出现一次删除一次。
array a_sub(array a,array b)
{
	foreach(b,mixed c){
		int n=search(a,c);
		if(n!=-1){
			a=a_delete(a,n);
		}
	}
	return a;
}

//! 返回调用当前函数的对象。已废止。
object previous_object()
{
	int e;
	array(array(mixed)) trace;
	object o,ret;
	trace=backtrace();
	o=function_object(trace[-2][2]);
	for(e=sizeof(trace)-3;e>=0;e--)
	{
		if(!trace[e][2]) continue;
		ret=function_object(trace[e][2]);
		if(o!=ret) return ret;
	}
	return 0;
}


mixed command_call(object ob,function f,mixed ... args)
{
//	werror(file_name(this_object())+" call "+file_name(function_object(f))+"->"+function_name(f)+"\n");
	object old=this_player();
	set_this_player(ob);
	alarm(3);
	mixed ret;
	mixed err=catch{
		ret=f(@args);
	};
	alarm(0);
	if(err){
		master()->handle_error(err);
	}
	set_this_player(old);
	return ret;
}

//! 返回在线用户对象列表，如果all为真返回所有用户列表
array(object) users(void|int all)
{
	return CONND->query_users(all);
}
//add by calvin 20061107
//!用户掉线之后删除用户对象在列表中 
void del_users()
{
	object cur_me = this_player();
	if(cur_me)
	{
		CONND->erase_users(cur_me);		
	}
}
//add by calvin 20061107

//! 将字符串s发送给除了当前用户(this_player)以外的所有对象
void shout(string s)
{
	array(object) a=users(1);
	for(int i=0;i<sizeof(a);i++){
		tell_object(a[i],s);
	}
}

//! 寻找文件名file指代的对象，如果对象未被装入，装入并返回该对象并如果对象早已装载，直接返回该对象，出错返回0。
object load_object(string|object file)
{
	object ob;
	mixed err=catch{
		ob=(object)file;
	};
	if(err==0){
		return ob;
	}
	else{
		master()->handle_error(err);
		return 0;
	}
}

int exec(object dest,object me)//don't call this inside pikenv_command()
{
	if(CONND->query_conn(dest)){
		//werror("Can't exec a interactive user.\n");
		return 0;
	}
	else{
		object ob=CONND->query_conn(me);
		ob->set_user(dest);
		CONND->set_conn(dest,ob);
		if(CONND->query_this_player()==me)
			CONND->set_this_player(dest);
		return 1;
	}
}
void tell_object(object dest,string s,void|string channel)
{
	object ob=CONND->query_conn(dest);
	if(ob)
		ob->write(s);
	else if(dest["catch_tell"])
		dest->catch_tell(s,channel);
}
object this_player()
{
	return CONND->query_this_player();
}
void set_this_player(void|object dest)
{
	if(dest==0){
		dest=previous_object();
	}
	CONND->set_this_player(dest);
}
void printf(string fmt,mixed ... args)
{
	write(sprintf(fmt,@args));
}
void write(mixed s,mixed...args)
{
	if(s==0){
		s="0";
	}
	object ob;//=CONND->query_conn(p);
	string deta=(string)s;
//	if(ob==0){
		ob=CONND->query_conn(CONND->query_this_player());
//	}
	if(args&&sizeof(args)){
		if(ob)
			ob->write(sprintf(s,@args));
//		else
//			Stdio.stdout->write(sprintf(s,@args));
	}
	else{
		if(ob)
			ob->write(s);
//		else
//			Stdio.stdout->write(s);
	}
}
/*
string read_file(string file,void|int start_line,void|int n)
{
	string data;
	if(n)
		data=Stdio.read_file(file,start_line,n);
	else if(start_line)
		data=Stdio.read_file(file,start_line);
	else
		data=Stdio.read_file(file);
	return data;
}
int write_file(string file,string data,void|int overwrite)
{
	if(!overwrite){
		int n=Stdio.write_file(file,data);
		if(n==sizeof(data))
			return 1;
		else
			return 0;
	}
	else{
		object f=Stdio.FILE(file,"wct");
		int n=f->write(data);
		int err=f->close();
		if(n==sizeof(data)&&!err){
			return 1;
		}
		else{
			return 0;
		}
			
	}
}
*/
int write_item_file(string file,string data,void|int overwrite)
{
	if(!overwrite){//创建新文件
		int n=Stdio.write_file(file,data);
		if(n==sizeof(data))
			return 1;
		else
			return 0;
	}
	else{//覆盖文件
		object f=Stdio.FILE(file,"wct");
		int n=f->write(data);
		int err=f->close();
		if(n==sizeof(data)&&!err){
			return 1;
		}
		else{
			return 0;
		}
	}
}
void cat(string file)
{
	write(Stdio.read_file(file));
}
static private string filterout(string s)
{
	string out="";
	for(int i=0;i<sizeof(s);i++){
		switch(s[i]){
		case '\0':
			out+="\\000";
			break;
		case '\"':
			out+="\\\"";
			break;
		case '\'':
			out+="\\\'";
			break;
		case '\\':
			out+="\\\\";
			break;
		case '\r':
			out+="\\r";
			break;
		case '\n':
			out+="\\n";
			break;
		case '\t':
			out+="\\t";
			break;
		case '\b':
			out+="\\b";
			break;
		case '\f':
			out+="\\f";
			break;
		default:
			out+=s[i..i];
			break;
		}
	}
	return out;
}

string pikenv_encode_value(mixed v,void|int save_zero)
{
	if(intp(v)||floatp(v)){
		return (string)v;
	}
	else if(stringp(v)){
		return "\""+filterout(v)+"\"";
	}
	else if(arrayp(v)){
		string out="({";
		for(int i=0;i<sizeof(v);i++){
			out+=pikenv_encode_value(v[i])+",";
		}
		out+="})";
		return out;
	}
	else if(mappingp(v)){
		string out="([";
		array a=indices(v);
		for(int i=0;i<sizeof(a);i++){
			out+=pikenv_encode_value(a[i])+":"+pikenv_encode_value(v[a[i]])+",";
		}
		out+="])";
		return out;
	}
	else if(multisetp(v)){
		string out="(<";
		array a=indices(v);
		for(int i=0;i<sizeof(a);i++){
			out+=pikenv_encode_value(a[i])+",";
		}
		out+=">)";
		return out;
	}
	else if(objectp(v)){
		return "0 ";///* object:"+file_name(v)+" */
/*		string out;
		object this=v;
		string s;
		if(sscanf(file_name(this),"%s#%*d",s)==0)
			s=file_name(this);
		if(s[0..sizeof(ROOT)-1]==ROOT){
			s=s[sizeof(ROOT)..];
			if(sizeof(s)==0||s[0]!='/'){
				s="/"+s;
			}
			s="~"+s;
		}
		out="#"+s+"\n";
		array a=indices(this);
		for(int i=0;i<sizeof(a);i++){
			if(object_variablep(this,a[i])){
				if(this[a[i]]!=0||save_zero)
					out+=(a[i]+" "+pikenv_encode_value(this[a[i]])+"\n");
			}
//			else if(save_zero){
//				out+=(a[i]+" "+pikenv_encode_value(0)+"\n");
//			}
		}
		return out;*/
	}
	return 0;
}

/*static private array pikenv_internal_decode_value(string v)//return ({ mixed value, string rest})
{
	v=String.trim_all_whites(v);
	if(sizeof(v)==0){
		return 0;
	}
	else if(v[0]>'0'&&v[0]<'9'&&v[0]=='+'||v[0]=='-'){
		int n;
		sscanf("%d",n);
		return ({n,0});
	}
	else if(v[0]=="\""){
	}
}*/

mixed pikenv_decode_value(string v)
{
	if(sizeof(v)>0&&v[0]=='#'){
		
	}else{
		string code="mixed decode(){return "+v+";}";
		program p=compile(code);
		object t=p();
		return t->decode();
	}
}

string pikenv_relative_path(string s)
{
	if(s[0..sizeof(ROOT)-1]==ROOT){
		s=s[sizeof(ROOT)..];
		if(sizeof(s)==0||s[0]!='/'){
			s="/"+s;
		}
		s="~"+s;
	}
	return s;
}

string pikenv_save_object(object ob,void|int save_zero)
{
	string out;
	object this=ob;
	string s;
	if(sscanf(file_name(this),"%s#%*d",s)==0)
		s=file_name(this);
	s=pikenv_relative_path(s);
	out="#"+s+"\n";
	array a=indices(this);
	for(int i=0;i<sizeof(a);i++){
		if(object_variablep(this,a[i])){
			if(this->`[]){
				if(this->`[](a[i],2)!=0||save_zero)
					out+=(a[i]+" "+pikenv_encode_value(this->`[](a[i],2))+"\n");
			}
			else{
				if(this[a[i]]!=0||save_zero)
					out+=(a[i]+" "+pikenv_encode_value(this[a[i]])+"\n");
			}
		}
	}
	return out;
}
//删除账号身上比较大的字段,再进行存储 
//该方法在正常存储失败时才被调用
//Evan add 2008-10-27
string pikenv_save_object_without_inbox(object ob,void|int save_zero)
{
	string out;
	object this=ob;
	if(ob->inbox&&ob->inbox!=({}))
		ob->inbox = ({});
	if(ob->msgs&&ob->msgs!=([]))
		ob->msgs = ([]);
	if(ob->msg_history&&ob->msg_history!="")
		ob->msg_history = "";

	string s;
	if(sscanf(file_name(this),"%s#%*d",s)==0)
		s=file_name(this);
	s=pikenv_relative_path(s);
	out="#"+s+"\n";
	array a=indices(this);
	for(int i=0;i<sizeof(a);i++){
		if(object_variablep(this,a[i])){
			if(this->`[]){
				if(this->`[](a[i],2)!=0||save_zero)
					out+=(a[i]+" "+pikenv_encode_value(this->`[](a[i],2))+"\n");
			}
			else{
				if(this[a[i]]!=0||save_zero)
					out+=(a[i]+" "+pikenv_encode_value(this[a[i]])+"\n");
			}
		}
	}
	return out;
}
int pikenv_restore_object(object ob,string v, void|int skip_empty)
{
//	werror("try restore from "+v+"\n");
	object this=ob;
	array(string) d=v/"\n";
	array a=indices(this);
	//mapping m=([]);
//	werror("sizeof(d)="+sizeof(d)+"\n");
	for(int i=0;i<sizeof(d);i++){
		string s;
		s=d[i];
		if(sizeof(s)&&s[0]!='#'){
			string name,data;
			if(sscanf(s,"%s %s",name,data)==2){
				//m[name]=decode(data);
				if(object_variablep(this,name)){
//					werror("restore "+name+" to "+data+"\n");
//					`[]=(this,name,pikenv_decode_value(data),2);
					if(this->`[]=)
						this->`[]=(name,pikenv_decode_value(data),2);
					else
						this[name]=pikenv_decode_value(data);
					if(!skip_empty)
						a-=({name});
				}
			}
		}
	}
	if(!skip_empty){
		for(int i=0;i<sizeof(a);i++){
			if(object_variablep(this,a[i])){
				if(a[i]=="living_time"){
					//werror("living_time=%d\n",this["living_time"]);
				}
//				werror("restore "+a[i]+" to 0\n");
				if(this->`[]=)
					this->`[]=(a[i],0,2);
				else
					this[a[i]]=0;
				if(a[i]=="living_time"){
					//werror("living_time=%d\n",this["living_time"]);
				}
			}
		}
	}
	return 1;//XXX: return 0 on error
}


int save_object(string file,void|int save_zero)                                                                                     
{
	object this=previous_object();
	if(!this)
		return 0;

	int re = 0;
	int re1 = 0;
	mixed err =catch{                                                                                   
		re = Stdio.write_file(file,pikenv_save_object(this,save_zero));
	};
	if(err || re==-1){ //如果存储出错，则把inbox msg msg_history 这几个字段清空后再做一次存储尝试
		werror("\n["+get_mysql_timedesc()+"][name:"+ this->name +"][Something wrong when store infos]\n");
		werror("========== THE INFO TO BE RECORD IS:\n" + pikenv_save_object(this,save_zero) +"\n\n");
		string msg =  "["+ get_mysql_timedesc()+"][name:"+ this->name +"][Something wrong when store infos]\n";
		mixed err1 =catch{                                                                                   
			re1 = Stdio.write_file(file,pikenv_save_object_without_inbox(this,save_zero));
		};
		werror("========== re1 = "+re1+"========\n");
		if(err1 || re1 ==-1){
			msg += "["+ get_mysql_timedesc()+"][name:"+ this->name +"][And i can not fix this]\n";
			Stdio.append_file("/usr/local/games/xiand9/log/tmp.log",msg);
			return 0;
		}
		else
		{
			msg += "["+ get_mysql_timedesc()+"][name:"+ this->name +"][Fortunately, i have fixed this buy remove INBOX]\n";
			Stdio.append_file("/usr/local/games/xiand9/log/tmp.log",msg);
			return re1;
		}
	}
	else
	{
		//Stdio.append_file("/home/hezuo/tx_ljx/log/tmp.log","[everything is OK when store infos]\n");
		return re;
	}
	//return Stdio.write_file(file,pikenv_save_object(this,save_zero));
}


string get_mysql_timedesc(){
	string s_mon,s_day;
	string s_hour,s_min,s_sec;
	int day,mon,year,hour,min,sec;
	mapping now_time = localtime(time());
	day = now_time["mday"];
	mon = now_time["mon"]+1;
	year = now_time["year"]+1900;
	hour = now_time["hour"];
	min = now_time["min"];
	sec = now_time["sec"];
	if(mon<10) s_mon = "0"+mon;
	else s_mon = (string)mon;
	if(day<10) s_day = "0"+day;
	else s_day = (string)day;
	if(hour<10) s_hour = "0"+hour;
	else s_hour = (string)hour;
	if(min<10) s_min = "0"+min;
	else s_min = (string)min;
	if(sec<10) s_sec = "0"+sec;
	else s_sec = (string)sec;
	return ""+year+"-"+s_mon+"-"+s_day+" "+s_hour+":"+s_min+":"+s_sec;
}



int sql_save_object(object db,string tab,string key,void|int save_zero)
{
	object this=previous_object();
	if(!this)
		return 0;
	tab=db->quote(tab);
	string v=pikenv_save_object(this,save_zero);
	array data=db->query("select * from "+tab+" where SQLKEY=:SQLKEY",([":SQLKEY":key]));
	if(data==0||sizeof(data)==0){
		//		werror("insert...\n"+key+"\n"+v+"\n");
		db->query("insert into "+tab+" (SQLKEY) values(:SQLKEY)",([":SQLKEY":key]) );
		data=db->query("select * from "+tab+" where SQLKEY=:SQLKEY",([":SQLKEY":key]));
	}
	array a=indices(this);
	mapping m=([]);
	array cols=({});
	int i;
	for(i=0;i<sizeof(a);i++){
		if(object_variablep(this,a[i])){
			//werror(""+sizeof(data)+"\n");
			//werror(""+sizeof(data[0])+"\n");
			//werror(""+sizeof(a)+"\n");
			//			werror(""+sizeof(data[0][upper_case(a[i])])+"\n");
			if(!zero_type(data[0][upper_case(a[i])])){
				m+=([ ":"+upper_case(a[i]) : pikenv_encode_value(this[a[i]]) ]);
				cols+=({upper_case(a[i])});
			}
		}
	}
//	werror("save data:"+v+"\n");
	string sql="update "+tab+" set SQLDATA=:SQLDATA";
	for(i=0;i<sizeof(cols);i++){
		sql+=",";
		sql+=cols[i]+"=:"+cols[i];
	}
	sql+=" where SQLKEY=:SQLKEY";
	m+=([":SQLKEY":key,":SQLDATA":v]);
//	werror(sizeof(m)+"\n");
	db->query(sql,m);
	return 1;
}

int sql_restore_object(object db,string tab,string key, void|int skip_empty)
{
	object this=previous_object();
	if(!this)
		return 0;
	array data=db->query("select SQLDATA from "+tab+" where SQLKEY=:SQLKEY",([":SQLKEY":key]));
//	werror(data[0]["SQLDATA"]);
	if(data==0||sizeof(data)==0||data[0]["SQLDATA"]==0){
		return 0;
	}
	return pikenv_restore_object(this,data[0]["SQLDATA"],skip_empty);
}


int restore_object(string file, void|int skip_empty,void|object this)
{
	if(!this)
		this=previous_object();
	if(!this)
		return 0;
	string v=Stdio.read_file(file);
	if(v)
		return pikenv_restore_object(this,v,skip_empty);
	else
		return 0;
}
object find_object(string|program prog,void|int load)
{
	program p=(program)prog;
	if(p==0){
		//werror("find_object: not a program\n");
		return 0;
	}
	object ob=MASTER->objects[p];
	if(!ob&&load)
		ob=(object)prog;
	return ob;
}
int member_array(mixed item, array|string arr, void|int start ) 
{
	if(start){
		return start+search(arr[start..],item);
	}
	else{
		return search(arr,item);
	}
}

int getoid(object ob)
{
	if(objids[ob]==0){
		objids[ob]=next_id++;
	}
	return objids[ob];
}
string file_name(void|object|program ob)
{
	program p;
	if(ob==0)
		ob=previous_object();
	if(programp(ob)){
		p=ob;
	}
	else if(objectp(ob)){
		p=object_program(ob);
	}
	string name=search(MASTER->programs,p);
/*	array(string) a=indices(MASTER->programs);
	for(int i=0;i<sizeof(a);i++){
		write(a[i]+"\n");
		if(MASTER->programs[a[i]]==p){
			name=a[i];
			write("found\n");
		}
	}
	werror("name="+name+"\n");*/
	if(programp(ob)){
		return name;
	}
	else{
		if(MASTER->objects[p]==ob){
			return name;
		}
		else{
			return name+"#"+getoid(ob);
		}
	}
}
int visible(object ob,void|object who)
{
	if(!ob)
		return 0;
	if(!who)
		return 1;
	if(ob["invisible"]&&ob->invisible(who)){
		return 0;
	}
	return 1;
}
array(object) _all_inventory(void|object ob,void|object looker)
{
	if(!ob){
		ob=previous_object();
	}
	if(!inv_map[ob]){
		inv_map[ob]=({});
	}
	if(!looker){
		return filter(inv_map[ob],objectp);
	}
	return filter(inv_map[ob],visible,looker);
}
array(object) all_inventory(void|object ob,void|object looker)
{
	if(!ob){
		ob=previous_object();
	}
	if(looker&&looker["_all_inventory"]){
		return looker->_all_inventory(ob);
	}
	return _all_inventory(ob,looker);
}

object environment(void|object ob)
{
	if(!ob){
		ob=previous_object();
	}
	return env_map[ob];
}
void move_object(string|object dest)
{
	if(stringp(dest)){
		dest=(object)dest;
	}
	object o=previous_object();
	if(inv_map[dest]==0){
		inv_map[dest]=({});
	}
	if(search(inv_map[dest],o)==-1){
		inv_map[dest]+=({o});
		object env=env_map[o];
		if(env&&inv_map[env]){
			inv_map[env]-=({o});
			if(sizeof(inv_map[env])==0){
				m_delete(inv_map,env);
			}
		}
		env_map[o]=dest;
	}
	//mapping(object:mapping(string:array(function))) action_map; //([cmd:fun])
	mapping m=action_map[o];
	if(m){
		array all=indices(m);
		for(int i=0;i<sizeof(all);i++){
			foreach(m[all[i]],function f){
				object owner=function_object(f);
				if(!f||(owner!=o&&owner!=environment(o)&&
						!_present(owner,o)&&(environment(o)==0||!_present(owner,environment(o))))){
					m_delete(m,all[i]);
				}
			}
		}
	}
	array a=action_array[o];
	if(a){
		array b=({});
		for(int i=0;i<sizeof(a);i++){
			object owner=function_object(a[i][1]);
			if(!a[i][1]||(owner!=o&&owner!=environment(o)&&
					!_present(owner,o)&&(environment(o)==0||!_present(owner,environment(o))))){
				b+=({a[i]});
			}
		}
		action_array[o]-=b;
	}
	array(object) all=all_inventory(dest);
	if(o["init"]){
		for(int i=0;i<sizeof(all);i++){
			if(living(all[i])){
				command_call(all[i],o["init"]);
			}
		}
	}
	if(living(o)){
		for(int i=0;i<sizeof(all);i++){
			if(all[i]!=o&&all[i]["init"]){
				command_call(o,all[i]["init"]);
			}
		}
	}
	//if(living(o)){
	if(living(o) && o->is("character") && !o->is("npc")){
		if(dest["init"]){
			command_call(o,dest["init"]);
		}
	}
}

int receive(string s)
{
	object p=previous_object();
	object ob=CONND->query_conn(p);
	if(ob==0){
		return 0;
	}
	if(ob)
		ob->write(s);
	return 1;
}
void shutdown(void|int e)
{
	exit(e);
}
array(object) children(string name)
	//XXX: bad performance
{
	program p=(program)name;
	array(object) a=({});
	for(object o=next_object();o;o=next_object(o)){
		if(object_program(o)==p){
			a+=({o});
		}
	}
	return a;
}
object _present(string|object|program thing,void|object ob,void|int n,void|object looker)
{
	array(object) a;
	if(!looker){
		looker=this_player();
	}
	if(ob){
		a=_all_inventory(ob,looker);
	}
	else{
		ob=previous_object();
		a=_all_inventory(ob,looker);
		if(environment(ob)){
			a+=_all_inventory(environment(ob),looker);
		}
	}
	if(objectp(thing)){
		if(search(a,thing)!=-1){
			return thing;
		}
	}
	else{
		for(int i=0;i<sizeof(a);i++){
			if(programp(thing)){
				if(Program.inherits(object_program(a[i]),thing)){
					if(n==0)
						return a[i];
					else
						n--;
				}
			}else{
				if(a[i]["id"]){
					if(a[i]->id(thing)){
						if(n==0)
							return a[i];
						else
							n--;
					}
				}
			}
		}
	}
	return 0;
}
object present(string|object|program thing,void|object ob,void|int n,void|object looker)
{
	array(object) a;
	if(!looker){
		looker=this_player();
	}
	if(ob){
		a=all_inventory(ob,looker);
	}
	else{
		ob=previous_object();
		a=all_inventory(ob,looker);
		if(environment(ob)){
			a+=all_inventory(environment(ob),looker);
		}
	}
	if(objectp(thing)){
		if(search(a,thing)!=-1){
			return thing;
		}
	}
	else{
		for(int i=0;i<sizeof(a);i++){
			if(programp(thing)){
				if(Program.inherits(object_program(a[i]),thing)){
					if(n==0)
						return a[i];
					else
						n--;
				}
			}else{
				if(a[i]["id"]){
					if(a[i]->id(thing)){
						if(n==0)
							return a[i];
						else
							n--;
					}
				}
			}
		}
	}
	return 0;
}
void say(string s,void|object|array(object) except,void|object me)
{
	if(objectp(except)){
		except=({except});
	}else if(except==0){
		except=({});
	}
	array(object) a;
	object o=me;
	if(!o){
		o=this_player();
	}
	if(!o){
//		write("no this_player\n");
		o=previous_object();
	}
	if(environment(o)==0){
//		werror("no env\n");
	}
	if(all_inventory(o)==0){
//		werror("no inv\n");
	}
	a=({environment(o)})+all_inventory(environment(o))+all_inventory(o)-except;
	for(int i=0;i<sizeof(a);i++){
		tell_object(a[i],s);
	}
}
void input_to(string|function fun, void|int is_passwd1_noskip2, mixed ... args)//XXX:is_passwd1_noskip2 not supported
{
	object conn=CONND->query_conn(CONND->query_this_player());
	if(conn)
		conn->input_to(fun,is_passwd1_noskip2,@args);
}
void update(string file)
{
	object obj;
	int found=0;
	if (obj = find_object(file)) {
//		werror("found\n");
		//name=file_name(obj);
//		werror(file_name(obj));
//		m_delete(master()->objects,search(master()->objects,obj));
		destruct(obj);
		found=1;
	}
	program p=(program)(file);
	if(p){
		m_delete(master()->programs,search(master()->programs,p));
	}
	else{
		foreach(indices(master()->programs),string s){
			if(master()->programs[s]==0){
				m_delete(master()->programs,s);
				//werror("m_delete: "+s+"\n");
			}
		}
	}
	if(found)
		load_object(file);
}
//add_action("command_hook", "", 1);
void add_action(string|function fun,string|array(string) cmd, void|int match_lead_if_1_verb_equ_xerb_if_2)
{
	//array(array(mixed)) trace;
	object caller=this_player();
	/*trace=backtrace();
	for(int i=sizeof(trace)-1;i>0;i--){
		if(function_name(trace[i][2])=="init"){
			caller=function_object(trace[i-1][2]);
			break;
		}
	}*/
	object owner=previous_object();
	if(stringp(cmd)){
		cmd=({cmd});
	}
	if(stringp(fun)){
		if(owner[fun]==0){
			werror("no such function '%s'.\n",fun);
		}
		fun=owner[fun];
	}
	else if(fun==0)
		werror("no such function.\n");
	if(fun!=0){
		//mapping(object:mapping(string:array(function))) action_map; //([cmd:fun])
		if(action_map[caller]==0){
			action_map[caller]=([]);
		}
		if(action_array[caller]==0){
			action_array[caller]=({});
		}
		if(!match_lead_if_1_verb_equ_xerb_if_2){
			for(int i=0;i<sizeof(cmd);i++){
				if(action_map[caller][cmd[i]]){
					if(search(action_map[caller][cmd[i]],fun)==-1)
						action_map[caller][cmd[i]]+=({fun});
				}else{
					action_map[caller][cmd[i]]=({fun});
				}
			}
		}
		else{
			for(int i=0;i<sizeof(cmd);i++){
				int flag=0;
				for(int j=0;j<sizeof(action_array[caller]);j++)
					if(action_array[caller][j][0]==cmd[i]){
						flag=1;
						break;
					}
				if(!flag)
					action_array[caller]+=({ ({cmd[i],fun,match_lead_if_1_verb_equ_xerb_if_2}) });
			}
		}
	}
}

mapping(object:int) living_map;
mapping(string:object) living_names;
array(object) livings()
{
	return filter(indices(living_map),objectp);
}
int living(object ob)
{
	return living_map[ob];
}

void enable_commands()
{
	object this=previous_object();
	living_map[this]=1;
}
object find_player(string name)
{
	return living_names[name];
}



int str_is_excepted(string str)
{
	array exceptions = ({"_break_then","_explorer"});//以这两个字符串开头的指令，即时玩家不再living状态，也可以执行他们。
	int num = sizeof(exceptions);
	for(int n =0;n<num;n++)
	{
		string tmp = exceptions[n];
		if((str-tmp)!=str)
			return 1;
	}
	int re = 0;
}

string action_verb;
int command(string|function str,void|object this)//XXX:Execute the command 'str' for this_object(), as if the player had typed the command in. command() returns a numeric value roughly to the driver's "evaluation cost"; this number is only an approximation. If you need precise benchmarks, try time_expression() instead. 
{
	if(this==0)
		this=previous_object();
	if(str==0)
		return 0;
	if(!living(this)){
		if(!str_is_excepted(str))
		{
			if(this["UNCONSCIOUS"]){
				tell_object(this,this["UNCONSCIOUS"]);
			}
			return 0;
		}
	}
	//werror(replace(this->name_cn+" command: "+str+"\n",(["%":"%%"])));
	string cmd,args;
	if(stringp(str)){
		if(this["process_command"]){
			string s=this->process_command(str);
			str=s;
		}
		if(str==0){
			return 0;
		}
		if(sscanf(str,"%s %s",cmd,args)!=2)
			cmd=str;
		action_verb=cmd;
	}
	function f;
	if(functionp(str)){
		f=str;
		if(command_call(this,f)){
			action_verb=0;
			fail_str=0;
			return 0;
		}
	}
	else{
		if(action_map[this]==0){
			action_map[this]=([]);
		}
		//werror("====in efuns.pike command->cmd:"+cmd+"====\n");
		if(action_map[this][cmd]){
			foreach(action_map[this][cmd],f){
				if(command_call(this,f,args)){
					action_verb=0;
					fail_str=0;
					return 0;
				}
			}
		}
		else{
			action_verb=cmd;
			if(action_array[this]==0){
				action_array[this]=({});
			}
			//		werror("sizeof(action_array[this])="+sizeof(action_array[this])+"\n");
			for(int i=0;i<sizeof(action_array[this]);i++){
				string v=action_array[this][i][0];
				int n=sizeof(v)-1;
				//			werror(n+"\n");
				if(n<0||cmd[0..n]==v){
					if(action_array[this][i][2]==1){
						action_verb=cmd;
					}
					else{
						action_verb=cmd[sizeof(v)..];
					}
					f=action_array[this][i][1];
					if(f&&function_object(f)&&command_call(this,f,args)){
						action_verb=0;
						//				werror("return2\n");
						fail_str=0;
						return 0;
					}
				}
			}
		}
	}
//	werror("command: what?\n");
	if(fail_str){
		if(functionp(fail_str)){
			tell_object(this,fail_str());
		}
		else{
			tell_object(this,fail_str);
		}
		fail_str=0;
	}
	else{
		if(cmd!="what"){
			return command("what "+str,this);
		}
	}
	return 0;
}


string query_verb()
{
	return action_verb;
}

int notify_fail(string|function str)
{
	fail_str=str;
	return 0;
}


void disable_commands()//XXX: Makes a living object non-living; add_action()s have no effects and, if the object is interactive, disallows the user from typing in commands other than for an input_to(). disable_commands() always returns 0. 
{
	object this=previous_object();
	m_delete(living_map,this);
}

void set_living_name(string name)
{
	object this=previous_object();
	living_names[name]=this;
}

string pikenv_path(string path)
{
	if(sizeof(path)>0&&path[0]=='~'){
		return Stdio.append_path(ROOT,path[1..]);
	}
	return Stdio.append_path("/",path);
}

mapping(object:object) player_filter;

void set_filter(object f)
{
	object ob=CONND->query_conn(this_player());
	if(ob){
		ob->filter=f;
	}
	else{
		werror("no connection attached with this player.\n");
	}
//	if(this_player())
//		player_filter[this_player()]=f;
}

void flush_filter()
{
	object ob=CONND->query_conn(this_player());
	if(ob){
		ob->close();
	}
}

object query_filter()
{
	object ob=CONND->query_conn(this_player());
	if(ob){
		return ob->filter;
	}
//	return player_filter[this_player];
}

void kill_filter()
{
	object ob=CONND->query_conn(this_player());
	if(ob){
		ob->filter=0;
	}
	else{
		werror("no connection attached with this player.\n");
	}
//	m_delete(player_filter,this_player());
}


void set_heart_beat(int interval)
{
	object ob=previous_object();
	if(interval==0){
		m_delete(heart_beats,ob);
	}
	else{
		heart_beats[ob]=({interval,0});
	}
}

int query_heart_beat()
{
	object ob=previous_object();
	array a=heart_beats[ob];
	if(a)
		return a[0];
	else
		return 0;
}

string object_name(void|object ob)
{
	if(ob==0){
		ob=previous_object();
	}
	return (basename(file_name(ob))/"#")[0];
}


private void heart_beat()
{
	foreach(indices(heart_beats),object ob){
		if(ob&&ob["heart_beat"]&&heart_beats[ob]){
			//如果在一次heart_beat中某对象调用了set_heart_beat(0)就会出现heart_beats[ob]==0的情况。
			heart_beats[ob][1]++;
			if(heart_beats[ob][1]==heart_beats[ob][0]){
				heart_beats[ob][1]=0;
				mixed err=catch{
					ob->heart_beat();
				};
				if(err){
					master()->handle_error(err);
				}
			}
		}
	}
	call_out(heart_beat,2);
}

private void _destruct(void|object ob)
{
	if(ob){
		array(object) inventory=all_inventory(ob);
		if(inventory){
			for(int i=0;i<sizeof(inventory);i++){
				if(inventory[i]["move_or_destruct"])
					inventory[i]->move_or_destruct(environment(ob));
				else if(inventory[i]["remove"]){
					inventory[i]->remove();
				}
				else{
					destruct(inventory[i]);
				}
			}
			m_delete(inv_map,ob);
		}
	}	
	object ob_env = env_map[ob];
	if(ob_env&&inv_map[ob_env]){
		inv_map[ob_env]-=({ob});
		//werror("dest %O ok!!!\n",ob->name);
		if(!sizeof(inv_map[ob_env]))
			m_delete(inv_map,ob_env);
	}	
	destruct(ob);
}

object new(string|program|function path,mixed ... args)
{
	if(stringp(path))
		return ((program)path)(@args);
	else 
		return path(@args);
}
object clone(string|program|function path,mixed ... args)
{
	if(stringp(path))
		return ((program)path)(@args);
	else 
		return path(@args);
}
object clone_item(string|program|function path,mixed ... args)
{
	if(stringp(path)){
		program p = compile_file(path);
		object rt = p();
		if(rt)
			return rt; 
	}
	else{
		if(objectp(path)){
			return path;
		}
		else if(programp(path)){
			return path(@args);
		}
	}
	return 0;
}

private void on_alarm(int n)
{
//	ualarm(1000);//some time master.pike catch and ignore the exceptions.
	master()->handle_error(({"Too long evaluation. \n",backtrace()}),"WARNING");
}
string logfile_postfix=".log";
void werror(string msg, mixed ...  args)
{
	if(ENABLE_WERROR){
		array(array(mixed)) trace;
		trace=backtrace();
		string data=msg;
		catch{
			data=sprintf(msg,@args);
		};
		Stdio.append_file(ROOT+"/log/stderr."+logfile_postfix,trace[-2][0]+":"+trace[-2][1]+":"+data);
	}
}

string http_encode_string_7bits(string in)
{
	string s=Protocols.HTTP.http_encode_string(in);
	string out="";
	for(int i=0;i<sizeof(s);i++){
		if(s[i]<0||s[i]>127){
			out+=sprintf("%%%x",s[i]);
		}
		else{
			out+=s[i..i];
		}
	}
	return out;
}
#define SIGALRM 14
void create(void|string _logfile_prefix)
{
	if(_logfile_prefix)
		logfile_postfix=_logfile_prefix;
	signal(SIGALRM,on_alarm);
	action_map=set_weak_flag(([]),Pike.WEAK_INDICES);
	action_array=set_weak_flag(([]),Pike.WEAK_INDICES);
	living_map=set_weak_flag(([]),Pike.WEAK_INDICES);
	living_names=set_weak_flag(([]),Pike.WEAK_VALUES);
	heart_beats=set_weak_flag(([]),Pike.WEAK_INDICES);
	player_filter=set_weak_flag(([]),Pike.WEAK_INDICES);


	inv_map=([]);
	env_map=([]);
	objids=set_weak_flag(([]),Pike.WEAK);
	next_id=1;
	array f=indices(this_object());
	int i;
	for(i=0;i<sizeof(f);i++){
		if(f[i]!="create")
			add_constant(f[i],this_object()[f[i]]);
	}
	add_constant("destruct",_destruct);
	add_constant("explode",`/);
	add_constant("implode",`*);
	//	add_constant("file_size",Stdio.file_size);
	call_out(heart_beat,2);
}
